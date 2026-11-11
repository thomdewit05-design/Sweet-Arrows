import Foundation
import SweetArrowsCore

/// Builds levels that are solvable by construction, then lets the solver measure them.
///
/// Construction works backwards: candies are placed in reverse removal order, and every new
/// candy must have a free path to the edge past the candies already placed. Reversing the
/// placement order therefore gives a winning order. Colors are then dealt along that order
/// so the jar never overflows, and ice/caramel/rotation are only added where that order allows.
public struct Generator: Sendable {
    public struct Parameters: Sendable, Hashable {
        public var width: Int
        public var height: Int
        public var candies: Int
        public var colors: Int
        public var bagCapacity: Int = 5
        /// Highest jar fill allowed along the built-in solution (< bagCapacity).
        public var bagLimit: Int
        public var poles: Int = 0
        public var bars: Int = 0
        public var caramel: Double = 0
        public var rotating: Double = 0
        public var iced: Double = 0
        public var wrapped: Double = 0
        public var mirrors: Int = 0
        public var bomb: Double = 0
        public var colorChanger: Double = 0
        /// Chance the level has a key; candies removed after it may then be locked.
        public var keyChance: Double = 0
        public var locked: Double = 0
        /// 0 = scattered, higher = candies huddle together (more blocking).
        public var clumping: Double = 2

        public init(width: Int, height: Int, candies: Int, colors: Int, bagLimit: Int) {
            self.width = width
            self.height = height
            self.candies = candies
            self.colors = colors
            self.bagLimit = bagLimit
        }
    }

    public var solverConfiguration: Solver.Configuration
    public var attempts: Int
    public var tolerance: Double

    public init(
        solverConfiguration: Solver.Configuration = .init(),
        attempts: Int = 60,
        tolerance: Double = 5
    ) {
        self.solverConfiguration = solverConfiguration
        self.attempts = attempts
        self.tolerance = tolerance
    }

    // MARK: Level from a plan

    /// Generates the level for `plan`, reproducibly from `seed`.
    public func level(for plan: Curve.Plan, seed: UInt64) -> Level? {
        var rng = SplitMix64(seed: seed &+ UInt64(plan.id) &* 0x2545_F491_4F6C_DD1D)
        var knob = plan.target
        var best: (level: Level, error: Double)?

        for _ in 0..<attempts {
            let params = parameters(knob: knob, plan: plan, rng: &rng)
            guard var candidate = build(params, id: plan.id, rng: &rng) else { continue }
            if let featured = plan.featured, !candidate.elements.contains(featured) { continue }
            candidate.hard = plan.slot == .hard
            guard let approved = Difficulty.approve(candidate, configuration: solverConfiguration),
                  let stats = approved.stats
            else { continue }
            let error = stats.difficulty - plan.target
            if best == nil || abs(error) < best!.error {
                best = (approved, abs(error))
            }
            if abs(error) <= tolerance { break }
            // Steer: too easy -> push the knob up, too hard -> down.
            knob = min(max(knob - error * 0.6, 2), 100)
        }
        return best?.level
    }

    /// Maps one difficulty "knob" (0–100) to concrete board parameters, with some randomness.
    func parameters(knob: Double, plan: Curve.Plan, rng: inout SplitMix64) -> Parameters {
        let k = min(max(knob, 0), 100) / 100
        let jitter = { (spread: Double, rng: inout SplitMix64) -> Double in (rng.unit() * 2 - 1) * spread }

        let sizeT = min(max(k * 1.35 + jitter(0.12, &rng), 0), 1)
        let width = min(Level.maxWidth, 4 + Int((sizeT * 3).rounded()))
        let height = min(Level.maxHeight, 5 + Int((sizeT * 4).rounded()))
        let density = min(0.42 + 0.3 * k + jitter(0.06, &rng), 0.78)
        let maxCandies = min(Int(Double(width * height) * density), 60)
        let candies = max(6, maxCandies / 3 * 3)

        var colors = 2 + Int((k * 4.6 + jitter(0.7, &rng)).rounded())
        colors = min(max(colors, 2), CandyColor.allCases.count, candies / 3)

        var params = Parameters(
            width: width, height: height, candies: candies, colors: colors,
            bagLimit: min(4, max(2, 2 + Int((k * 2.6 + jitter(0.5, &rng)).rounded())))
        )
        params.clumping = 1 + k * 3

        let allowed = Set(plan.elements)
        func amount(_ element: BoardElement, base: Double) -> Double {
            guard allowed.contains(element) else { return 0 }
            let boost = plan.featured == element ? 1.8 : 1
            return base * boost * (0.6 + rng.unit() * 0.8)
        }
        if allowed.contains(.pole) {
            params.poles = plan.featured == .pole ? 1 + Int(rng.next() % 3) : Int(rng.next() % 3)
        }
        if allowed.contains(.chocolateBar) {
            params.bars = plan.featured == .chocolateBar ? 1 + Int(rng.next() % 3) : Int(rng.next() % 3)
        }
        params.wrapped = amount(.wrapped, base: 0.14)
        params.caramel = amount(.caramel, base: 0.10)
        params.iced = amount(.iced, base: 0.10)
        params.rotating = amount(.rotating, base: 0.06)
        if allowed.contains(.mirror) {
            params.mirrors = plan.featured == .mirror ? 1 + Int(rng.next() % 3) : Int(rng.next() % 3)
        }
        params.bomb = amount(.bomb, base: 0.07)
        params.colorChanger = amount(.colorChanger, base: 0.07)
        if allowed.contains(.lock) {
            params.keyChance = plan.featured == .lock ? 1 : 0.4
            params.locked = 0.22 + rng.unit() * 0.15
        }
        return params
    }

    // MARK: Construction

    /// One attempt at building a level. Returns nil if the random choices painted it into a corner.
    public func build(_ p: Parameters, id: Int, rng: inout SplitMix64) -> Level? {
        let n = p.candies
        guard n % 3 == 0, n >= 3, p.colors >= 1, p.colors * 3 <= n else { return nil }

        var occupied = Array(repeating: Array(repeating: false, count: p.width), count: p.height)
        func inside(_ c: GridPoint) -> Bool { c.x >= 0 && c.y >= 0 && c.x < p.width && c.y < p.height }

        // Poles first, away from the very edge so they actually get in the way.
        var poles: [GridPoint] = []
        for _ in 0..<p.poles {
            for _ in 0..<20 {
                let c = GridPoint(1 + Int(rng.next() % UInt64(max(p.width - 2, 1))),
                                  1 + Int(rng.next() % UInt64(max(p.height - 2, 1))))
                if inside(c), !occupied[c.y][c.x] {
                    occupied[c.y][c.x] = true
                    poles.append(c)
                    break
                }
            }
        }

        // Candy-cane bumpers on free interior cells.
        var mirrors: [GridPoint: Mirror] = [:]
        for _ in 0..<p.mirrors {
            for _ in 0..<20 {
                let c = GridPoint(1 + Int(rng.next() % UInt64(max(p.width - 2, 1))),
                                  1 + Int(rng.next() % UInt64(max(p.height - 2, 1))))
                if inside(c), !occupied[c.y][c.x] {
                    occupied[c.y][c.x] = true
                    mirrors[c] = Mirror(c, rng.chance(0.5) ? .slash : .backslash)
                    break
                }
            }
        }

        // Decide per removal slot: caramel? rotating? bar? (slot 0 = removed first)
        var isCaramel = (0..<n).map { _ in rng.chance(p.caramel) }
        let isRotating = (0..<n).map { i in !isCaramel[i] && rng.chance(p.rotating) }
        var isBar = Array(repeating: false, count: n)
        for _ in 0..<p.bars {
            isBar[Int(rng.next() % UInt64(n))] = true
        }
        for i in 0..<n where isBar[i] && isRotating[i] { isCaramel[i] = false }

        // Moves made before slot k is launched (its own caramel crack included).
        var movesBefore = Array(repeating: 0, count: n)
        var total = 0
        for k in 0..<n {
            movesBefore[k] = total + (isCaramel[k] ? 1 : 0)
            total += isCaramel[k] ? 2 : 1
        }

        // Same route rules as Game.trace: single candies bend on bumpers, bars stop at them.
        func rayIsFree(from cells: [GridPoint], _ start: Direction) -> Bool {
            if cells.count == 1 {
                var c = cells[0]
                var d = start
                for _ in 0..<((p.width + p.height) * 4) {
                    c += d
                    guard inside(c) else { return true }
                    if let mirror = mirrors[c] {
                        d = mirror.deflect(d)
                        continue
                    }
                    if occupied[c.y][c.x] { return false }
                }
                return false
            }
            for cell in cells {
                var c = cell + start
                while inside(c) {
                    if !cells.contains(c), occupied[c.y][c.x] { return false }
                    c += start
                }
            }
            return true
        }

        // Place in reverse removal order.
        var placed: [(cells: [GridPoint], flight: Direction, slot: Int)] = []
        for k in stride(from: n - 1, through: 0, by: -1) {
            var options: [(cells: [GridPoint], d: Direction, weight: Double)] = []
            for y in 0..<p.height {
                for x in 0..<p.width {
                    let anchor = GridPoint(x, y)
                    let shapes: [[GridPoint]] = isBar[k]
                        ? [[anchor, GridPoint(x + 1, y)], [anchor, GridPoint(x, y + 1)]]
                        : [[anchor]]
                    for cells in shapes where cells.allSatisfy({ inside($0) && !occupied[$0.y][$0.x] }) {
                        let touching = cells.flatMap(\.neighbors).filter { inside($0) && occupied[$0.y][$0.x] }.count
                        let weight = pow(Double(touching + 1), p.clumping)
                        for d in Direction.allCases where rayIsFree(from: cells, d) {
                            options.append((cells, d, weight))
                        }
                    }
                }
            }
            guard !options.isEmpty else { return nil }
            let totalWeight = options.reduce(0) { $0 + $1.weight }
            var pick = rng.unit() * totalWeight
            var chosen = options[options.count - 1]
            for option in options {
                pick -= option.weight
                if pick <= 0 {
                    chosen = option
                    break
                }
            }
            for cell in chosen.cells { occupied[cell.y][cell.x] = true }
            placed.append((chosen.cells, chosen.d, k))
        }
        placed.reverse()  // placed[k] is now removal slot k

        guard let colors = dealColors(count: n, colors: p.colors, bagLimit: min(p.bagLimit, p.bagCapacity - 1), rng: &rng)
        else { return nil }

        // Color changers start on the color that turns into the dealt one by their launch.
        let palette = Array(Set(colors)).sorted()
        // A key early in the built-in order; candies after it may be locked.
        let keySlot: Int? = rng.chance(p.keyChance) && n >= 6 ? Int(rng.next() % UInt64(max(n / 3, 1))) : nil

        // Ice only where a neighbour leaves earlier in the built-in order.
        var owner: [GridPoint: Int] = [:]
        for (k, item) in placed.enumerated() { for cell in item.cells { owner[cell] = k } }
        var candies: [Candy] = []
        var hasChanger = false
        for (k, item) in placed.enumerated() {
            var features = Set<CandyFeature>()
            if isCaramel[k] { features.insert(.caramel) }
            if isRotating[k] { features.insert(.rotating) }
            if rng.chance(p.wrapped) { features.insert(.wrapped) }
            let freedEarlier = item.cells.flatMap(\.neighbors).contains { owner[$0].map { $0 < k } ?? false }
            if freedEarlier, !isCaramel[k], rng.chance(p.iced) { features.insert(.iced) }
            if k == keySlot { features.insert(.key) }
            if let keySlot, k > keySlot, !features.contains(.iced), rng.chance(p.locked) { features.insert(.locked) }
            if !isCaramel[k], item.cells.count == 1, rng.chance(p.bomb) { features.insert(.bomb) }

            var color = colors[k]
            if palette.count > 1, item.cells.count == 1, !features.contains(.bomb), rng.chance(p.colorChanger) {
                features.insert(.colorChanger)
                hasChanger = true
                let index = palette.firstIndex(of: color)!
                color = palette[((index - movesBefore[k]) % palette.count + palette.count) % palette.count]
            }

            let start = isRotating[k] ? item.flight.rotated(by: -movesBefore[k]) : item.flight
            let anchor = item.cells.min { ($0.y, $0.x) < ($1.y, $1.x) }!
            let bar: Axis? = item.cells.count == 2 ? (item.cells[0].y == item.cells[1].y ? .horizontal : .vertical) : nil
            candies.append(Candy(id: 0, color: color, position: anchor, direction: start, bar: bar, features: features))
        }
        // Number candies in reading order so ids look tidy in the editor and the report.
        candies.sort { ($0.position.y, $0.position.x) < ($1.position.y, $1.position.x) }
        for i in candies.indices { candies[i].id = i + 1 }

        return Level(
            id: id, width: p.width, height: p.height, bagCapacity: p.bagCapacity,
            candies: candies, poles: poles.sorted { ($0.y, $0.x) < ($1.y, $1.x) },
            mirrors: mirrors.values.sorted { ($0.position.y, $0.position.x) < ($1.position.y, $1.position.x) },
            changerColors: hasChanger ? palette : nil
        )
    }

    /// Deals colors along the removal order so the jar never holds more than `bagLimit`.
    func dealColors(count n: Int, colors k: Int, bagLimit: Int, rng: inout SplitMix64) -> [CandyColor]? {
        let palette = Array(CandyColor.allCases.shuffled(using: &rng).prefix(k))
        // Every color gets at least one triple; the rest are spread at random.
        var triples = Array(repeating: 1, count: k)
        for _ in 0..<(n / 3 - k) { triples[Int(rng.next() % UInt64(k))] += 1 }

        // Randomised depth-first search with backtracking, so tight limits still find an order.
        var remaining = triples.map { $0 * 3 }
        var bag = Array(repeating: 0, count: k)
        var sequence: [Int] = []
        var budget = 20_000

        func extend() -> Bool {
            if sequence.count == n { return true }
            budget -= 1
            if budget < 0 { return false }
            let fill = bag.reduce(0, +)
            var options = (0..<k).filter { c in
                guard remaining[c] > 0 else { return false }
                let after = bag[c] == 2 ? fill - 2 : fill + 1
                return after <= bagLimit
            }
            options.shuffle(using: &rng)
            for c in options {
                remaining[c] -= 1
                let before = bag[c]
                bag[c] = (bag[c] + 1) % 3
                sequence.append(c)
                if extend() { return true }
                sequence.removeLast()
                bag[c] = before
                remaining[c] += 1
            }
            return false
        }
        if extend() { return sequence.map { palette[$0] } }
        return nil
    }
}
