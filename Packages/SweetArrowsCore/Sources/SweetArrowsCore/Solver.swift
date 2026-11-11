/// Proves a level can be won without bouncing and without filling the bag,
/// and measures how tricky it is.
///
/// A state is: which candies are on the board, which caramels are cracked, what is in the jar
/// and how many moves were made (rotating arrows and color changers follow the move count).
/// Ice melts once a neighbour is gone and locks open once every key is gone, so those follow
/// from the board itself.
public struct Solver: Sendable {
    public struct Configuration: Sendable {
        /// Maximum number of distinct states to expand before giving up.
        public var nodeBudget: Int
        /// Stop counting solutions above this number.
        public var solutionCap: Int
        /// Separate budget for counting solutions (can be much larger than finding one).
        public var countingBudget: Int

        public init(nodeBudget: Int = 1_500_000, solutionCap: Int = 10_000, countingBudget: Int = 400_000) {
            self.nodeBudget = nodeBudget
            self.solutionCap = solutionCap
            self.countingBudget = countingBudget
        }

        public static let hint = Configuration(nodeBudget: 150_000, solutionCap: 1, countingBudget: 0)
    }

    public enum Outcome: Sendable {
        case solved(Analysis)
        case unsolvable
        /// Budget ran out before a proof either way.
        case unknown
    }

    public struct Analysis: Sendable, Hashable {
        /// Candy ids to tap, in order (caramel candies appear twice).
        public var solution: [Int]
        public var pitfalls: Int
        public var solutions: Int
        public var solutionsCapped: Bool
        public var peakBag: Int
        public var statesExplored: Int
    }

    struct Key: Hashable {
        var present: UInt64
        var cracked: UInt64
        /// 3 bits per color: candies of that color in the jar (0...2).
        var bag: UInt32
        var moves: UInt16
    }

    // Static description, indices 0..<n.
    private let ids: [Int]
    private let baseColor: [Int]
    private let baseDirection: [Int]
    private let rotating: UInt64
    private let changer: UInt64
    private let bombs: UInt64
    private let keys: UInt64
    private let lockedAtRoot: UInt64
    private let caramel: UInt64           // caramel still intact at the root
    private let frozenAtRoot: UInt64
    private let neighbours: [UInt64]
    private let rays: [[UInt64]]          // [candy][direction] -> candies in the way
    private let rayBlocked: [[Bool]]      // [candy][direction] -> hits a pole, or a bar hits a bumper
    private let rootPresent: UInt64
    private let rootBag: UInt32
    private let rootMoves: Int
    private let palette: [Int]            // color indices a changer cycles through
    private let capacity: Int
    private let configuration: Configuration

    // MARK: Setup

    public init(level: Level, configuration: Configuration = Configuration()) {
        self.init(game: Game(level: level), configuration: configuration)
    }

    /// Solves from the current position of a game in progress (used for hints).
    public init(game: Game, configuration: Configuration = Configuration()) {
        let states = game.remainingCandies
        precondition(states.count <= 64, "Solver supports at most 64 candies")
        self.configuration = configuration
        ids = states.map(\.id)
        baseColor = states.map(\.color.index)
        baseDirection = states.map(\.direction.index)
        capacity = game.bag.capacity
        rootMoves = 0
        palette = game.level.changerPalette.map(\.index)
        var bag: UInt32 = 0
        for color in CandyColor.allCases {
            bag |= UInt32(game.bag.count(of: color) % Bag.matchCount) << UInt32(color.index * 3)
        }
        rootBag = bag

        var owner: [GridPoint: Int] = [:]
        for (i, state) in states.enumerated() {
            for cell in state.cells { owner[cell] = i }
        }

        var rotating: UInt64 = 0, changer: UInt64 = 0, bombs: UInt64 = 0, keys: UInt64 = 0
        var locked: UInt64 = 0, caramel: UInt64 = 0, frozen: UInt64 = 0
        var neighbours = [UInt64](repeating: 0, count: states.count)
        var rays = [[UInt64]](repeating: [0, 0, 0, 0], count: states.count)
        var blocked = [[Bool]](repeating: [false, false, false, false], count: states.count)

        for (i, state) in states.enumerated() {
            let bit = UInt64(1) << UInt64(i)
            if state.candy.has(.rotating) { rotating |= bit }
            if state.candy.has(.colorChanger) { changer |= bit }
            if state.candy.has(.bomb) { bombs |= bit }
            if state.candy.has(.key) { keys |= bit }
            if state.locked { locked |= bit }
            if state.caramelIntact { caramel |= bit }
            if state.frozen { frozen |= bit }
            for cell in state.cells {
                for n in cell.neighbors {
                    if let j = owner[n], j != i { neighbours[i] |= UInt64(1) << UInt64(j) }
                }
            }
            for direction in Direction.allCases {
                let (mask, stop) = Solver.ray(
                    for: state, direction: direction, level: game.level, owner: owner, me: i
                )
                rays[i][direction.index] = mask
                blocked[i][direction.index] = stop
            }
        }
        self.rotating = rotating
        self.changer = changer
        self.bombs = bombs
        self.keys = keys
        lockedAtRoot = locked
        self.caramel = caramel
        frozenAtRoot = frozen
        self.neighbours = neighbours
        self.rays = rays
        rayBlocked = blocked
        rootPresent = states.isEmpty ? 0 : (states.count == 64 ? ~0 : (UInt64(1) << UInt64(states.count)) - 1)
    }

    /// Candies on the route of `state` flying in `direction` (bending on bumpers),
    /// and whether the route is blocked for good (a pole, or a bar meeting a bumper, or a loop).
    private static func ray(
        for state: CandyState, direction start: Direction, level: Level, owner: [GridPoint: Int], me: Int
    ) -> (UInt64, Bool) {
        let poles = Set(level.poles)
        let mirrors = Dictionary(level.mirrors.map { ($0.position, $0) }, uniquingKeysWith: { a, _ in a })
        let isBar = state.cells.count > 1
        let offsets = state.cells.map { GridPoint($0.x - state.cells[0].x, $0.y - state.cells[0].y) }
        var anchor = state.cells[0]
        var direction = start
        var mask: UInt64 = 0
        for _ in 0..<((level.width + level.height) * 4) {
            anchor = anchor + direction
            let footprint = offsets.map { GridPoint(anchor.x + $0.x, anchor.y + $0.y) }.filter(level.contains)
            if footprint.isEmpty { return (mask, false) }
            for cell in footprint where !state.cells.contains(cell) {
                if poles.contains(cell) { return (mask, true) }
                if isBar, mirrors[cell] != nil { return (mask, true) }
                if let j = owner[cell], j != me { mask |= UInt64(1) << UInt64(j) }
            }
            if !isBar, let mirror = mirrors[anchor] { direction = mirror.deflect(direction) }
        }
        return (mask, true)
    }

    // MARK: Public API

    public func solve() -> Outcome {
        let search = Search(solver: self, budget: configuration.nodeBudget)
        let root = rootKey
        guard let rootSolvable = search.solvable(root) else { return .unknown }
        guard rootSolvable else { return .unsolvable }

        // Follow solvable children to build the solution and count pitfalls on the way.
        var state = root
        var solution: [Int] = []
        var pitfalls = 0
        var peakBag = bagFill(root.bag)
        while state.present != 0 {
            var next: Key?
            for move in moves(from: state) {
                guard let child = move.child else {
                    pitfalls += 1  // fills the bag: an immediate loss
                    continue
                }
                guard let ok = search.solvable(child) else { return .unknown }
                if ok {
                    if next == nil {
                        next = child
                        solution.append(ids[move.index])
                    }
                } else {
                    pitfalls += 1
                }
            }
            guard let chosen = next else { return .unknown }
            state = chosen
            peakBag = max(peakBag, bagFill(state.bag))
        }

        var solutions = 1
        var capped = false
        if configuration.countingBudget > 0 {
            let counter = Counter(solver: self, search: search, budget: configuration.countingBudget)
            if let count = counter.count(root) {
                solutions = count
                capped = count >= configuration.solutionCap
            } else {
                solutions = configuration.solutionCap
                capped = true
            }
        }
        return .solved(Analysis(
            solution: solution, pitfalls: pitfalls, solutions: solutions,
            solutionsCapped: capped, peakBag: peakBag, statesExplored: search.explored
        ))
    }

    /// A safe next tap, or nil if the position cannot be won (or is too big to search).
    public func nextMove() -> Int? {
        let search = Search(solver: self, budget: configuration.nodeBudget)
        let root = rootKey
        guard search.solvable(root) == true else { return nil }
        for move in moves(from: root) {
            if let child = move.child, search.solvable(child) == true { return ids[move.index] }
        }
        return nil
    }

    private var rootKey: Key {
        Key(present: rootPresent, cracked: 0, bag: rootBag, moves: UInt16(rootMoves))
    }

    // MARK: Rules on masks

    struct Move {
        var index: Int
        /// nil when the move fills the bag.
        var child: Key?
        var popsTriple: Bool
        var joinsBag: Bool
    }

    private func bagCount(_ bag: UInt32, color c: Int) -> Int {
        Int((bag >> UInt32(c * 3)) & 0b111)
    }

    private func bagFill(_ bag: UInt32) -> Int {
        (0..<CandyColor.allCases.count).reduce(0) { $0 + bagCount(bag, color: $1) }
    }

    private func direction(of i: Int, in state: Key) -> Int {
        let bit = UInt64(1) << UInt64(i)
        if rotating & bit == 0 { return baseDirection[i] }
        return (baseDirection[i] + Int(state.moves)) % 4
    }

    private func color(of i: Int, in state: Key) -> Int {
        let bit = UInt64(1) << UInt64(i)
        guard changer & bit != 0, palette.count > 1, let start = palette.firstIndex(of: baseColor[i]) else {
            return baseColor[i]
        }
        return palette[(start + Int(state.moves)) % palette.count]
    }

    private func isFrozen(_ i: Int, present: UInt64) -> Bool {
        let bit = UInt64(1) << UInt64(i)
        guard frozenAtRoot & bit != 0 else { return false }
        return neighbours[i] & rootPresent & ~present == 0
    }

    private func isLocked(_ i: Int, present: UInt64) -> Bool {
        let bit = UInt64(1) << UInt64(i)
        return lockedAtRoot & bit != 0 && keys & present != 0
    }

    /// Legal taps (no bounce), best-looking first.
    func moves(from state: Key) -> [Move] {
        var result: [Move] = []
        var remaining = state.present
        let nextMoves = state.moves &+ 1
        while remaining != 0 {
            let i = remaining.trailingZeroBitCount
            remaining &= remaining - 1
            let bit = UInt64(1) << UInt64(i)
            if isFrozen(i, present: state.present) || isLocked(i, present: state.present) { continue }
            let d = direction(of: i, in: state)
            if rayBlocked[i][d] || rays[i][d] & state.present != 0 { continue }

            if caramel & bit != 0, state.cracked & bit == 0 {
                let child = Key(present: state.present, cracked: state.cracked | bit, bag: state.bag, moves: nextMoves)
                result.append(Move(index: i, child: child, popsTriple: false, joinsBag: false))
                continue
            }
            let c = color(of: i, in: state)
            let inBag = bagCount(state.bag, color: c)
            let pops = inBag == Bag.matchCount - 1
            let newCount = pops ? 0 : inBag + 1
            let shift = UInt32(c * 3)
            let bag = (state.bag & ~(UInt32(0b111) << shift)) | (UInt32(newCount) << shift)
            var present = state.present & ~bit
            if bombs & bit != 0 { present &= ~neighbours[i] }
            let next = Key(present: present, cracked: state.cracked, bag: bag, moves: nextMoves)
            let fills = present != 0 && bagFill(bag) >= capacity
            result.append(Move(index: i, child: fills ? nil : next, popsTriple: pops, joinsBag: inBag > 0))
        }
        result.sort { lhs, rhs in
            if lhs.popsTriple != rhs.popsTriple { return lhs.popsTriple }
            if lhs.joinsBag != rhs.joinsBag { return lhs.joinsBag }
            return lhs.index < rhs.index
        }
        return result
    }

    /// Cheap necessary condition: ignoring the bag, can every candy still get out?
    /// Peels off candies with a clear path until nothing changes. Optimistic on purpose
    /// (bombs clear their neighbours, spinners may point anywhere), so a "no" is always right.
    func canPeel(_ state: Key) -> Bool {
        var left = state.present
        var progress = true
        while left != 0 && progress {
            progress = false
            var scan = left
            while scan != 0 {
                let i = scan.trailingZeroBitCount
                scan &= scan - 1
                let bit = UInt64(1) << UInt64(i)
                guard left & bit != 0 else { continue }
                if frozenAtRoot & bit != 0, neighbours[i] & rootPresent & ~left == 0 { continue }
                if lockedAtRoot & bit != 0, keys & left != 0 { continue }
                let free: Bool
                if rotating & bit != 0 {
                    free = (0..<4).contains { d in !rayBlocked[i][d] && rays[i][d] & left == 0 }
                } else {
                    let d = baseDirection[i]
                    free = !rayBlocked[i][d] && rays[i][d] & left == 0
                }
                if free {
                    left &= ~bit
                    if bombs & bit != 0 { left &= ~neighbours[i] }
                    progress = true
                }
            }
        }
        return left == 0
    }

    // MARK: Search

    private final class Search {
        let solver: Solver
        let budget: Int
        var memo: [Key: Bool] = [:]
        var explored = 0
        var exhausted = false

        init(solver: Solver, budget: Int) {
            self.solver = solver
            self.budget = budget
        }

        /// true / false, or nil when the budget ran out.
        func solvable(_ state: Key) -> Bool? {
            if exhausted { return nil }
            let result = visit(state)
            return exhausted ? nil : result
        }

        private func visit(_ state: Key) -> Bool {
            if state.present == 0 { return true }
            if let known = memo[state] { return known }
            if exhausted { return false }
            explored += 1
            if explored > budget {
                exhausted = true
                return false
            }
            var result = false
            if solver.canPeel(state) {
                for move in solver.moves(from: state) {
                    guard let child = move.child else { continue }
                    if visit(child) {
                        result = true
                        break
                    }
                    if exhausted { return false }
                }
            }
            memo[state] = result
            return result
        }
    }

    private final class Counter {
        let solver: Solver
        let search: Search
        let budget: Int
        var memo: [Key: Int] = [:]
        var explored = 0

        init(solver: Solver, search: Search, budget: Int) {
            self.solver = solver
            self.search = search
            self.budget = budget
        }

        func count(_ state: Key) -> Int? {
            if state.present == 0 { return 1 }
            if let known = memo[state] { return known }
            if search.memo[state] == false { return 0 }
            explored += 1
            if explored > budget { return nil }
            if !solver.canPeel(state) {
                memo[state] = 0
                return 0
            }
            var total = 0
            for move in solver.moves(from: state) {
                guard let child = move.child else { continue }
                guard let sub = count(child) else { return nil }
                total = min(total + sub, solver.configuration.solutionCap)
            }
            memo[state] = total
            return total
        }
    }
}
