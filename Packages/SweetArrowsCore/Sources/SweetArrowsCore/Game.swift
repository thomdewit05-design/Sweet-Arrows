/// Something a moving candy can run into.
public enum Obstacle: Hashable, Sendable {
    case candy(Int)
    case pole(GridPoint)
    /// Chocolate bars cannot turn on a bumper.
    case mirror(GridPoint)
}

/// The way a candy would travel along its arrow, bending on bumpers.
public struct Trace: Hashable, Sendable {
    /// Cells the candy's anchor passes through, in order (not including its start cell).
    public var route: [GridPoint]
    /// Direction the candy has when it leaves the board (or hits something).
    public var finalDirection: Direction
    /// What it runs into, or nil when it reaches the edge.
    public var obstacle: Obstacle?

    public var isClear: Bool { obstacle == nil }
}

/// Result of looking along a candy's arrow.
public enum PathCheck: Hashable, Sendable {
    /// Free all the way off the board; `exitDistance` is the number of cells to leave it.
    case clear(exitDistance: Int)
    /// `distance` free cells before running into `obstacle`.
    case blocked(obstacle: Obstacle, distance: Int)

    public var isClear: Bool {
        if case .clear = self { return true }
        return false
    }
}

public enum LossReason: Hashable, Sendable {
    case bagFull
    case outOfHearts
    case outOfTime
    /// Endless mode: no free cell left for a new candy.
    case boardFull
}

public enum GameStatus: Hashable, Sendable {
    case playing
    case won
    case lost(LossReason)

    public var isOver: Bool { self != .playing }
}

/// A candy that is still on the board, with its live state.
public struct CandyState: Hashable, Sendable, Identifiable {
    public let candy: Candy
    public var direction: Direction
    /// Current color (color changers cycle through the level's colors).
    public var color: CandyColor
    public var caramelIntact: Bool
    public var frozen: Bool
    /// False while a wrapped candy still hides its color.
    public var revealed: Bool
    /// True while a locked candy waits for its key.
    public var locked: Bool

    public var id: Int { candy.id }
    public var cells: [GridPoint] { candy.cells }

    init(_ candy: Candy, keysOnBoard: Bool) {
        self.candy = candy
        direction = candy.direction
        color = candy.color
        caramelIntact = candy.has(.caramel)
        frozen = candy.has(.iced)
        revealed = !candy.has(.wrapped)
        locked = candy.has(.locked) && keysOnBoard
    }

    /// A candy shown outside a level (the slide game draws its pieces with the same art).
    public init(displaying candy: Candy) {
        self.init(candy, keysOnBoard: false)
    }
}

public struct Launch: Hashable, Sendable {
    public var candyID: Int
    public var color: CandyColor
    public var direction: Direction
    public var exitDistance: Int
    /// Cells the candy flies through (turns on bumpers), ending at the edge.
    public var route: [GridPoint]
    public var bag: Bag.Insertion
}

public struct Bounce: Hashable, Sendable {
    public var candyID: Int
    public var direction: Direction
    public var obstacle: Obstacle
    public var distance: Int
    public var heartLost: Bool
}

public enum TapResult: Hashable, Sendable {
    /// Left the board and went into the bag.
    case launched(Launch)
    /// First tap on caramel: the shell cracks, the candy stays.
    case crackedCaramel(candyID: Int)
    /// Hit something and bounced back.
    case bounced(Bounce)
    /// Tapped an iced candy: nothing happens.
    case frozen(candyID: Int)
    /// Tapped a locked candy while its key is still on the board: nothing happens.
    case locked(candyID: Int)
    /// Game over or unknown candy.
    case ignored
}

/// Everything that changed because of one action, so the scene can animate it.
public struct MoveReport: Hashable, Sendable {
    public var result: TapResult
    /// Rotating candies whose arrow turned, with their new direction.
    public var rotated: [Int: Direction] = [:]
    /// Color changers with their new color.
    public var recolored: [Int: CandyColor] = [:]
    /// Candies whose ice melted.
    public var melted: [Int] = []
    /// Wrapped candies that showed their color.
    public var revealed: [Int] = []
    /// Candies a bomb took off the board.
    public var exploded: [Int] = []
    /// Locked candies that opened because the last key left.
    public var unlocked: [Int] = []
    public var status: GameStatus

    public var countsAsMove: Bool {
        switch result {
        case .launched, .crackedCaramel: true
        case .bounced, .frozen, .locked, .ignored: false
        }
    }
}

/// The rules of Sweet Arrows. Pure value type: no UI, no randomness, no clock
/// (the app tells the game when time is up).
public struct Game: Sendable {
    public let level: Level
    /// Endless mode: an empty board is not a win, bounces cost no hearts, candies keep arriving.
    public let endless: Bool
    public private(set) var candies: [Int: CandyState]
    public private(set) var bag: Bag
    public private(set) var hearts: Int
    public private(set) var moves: Int
    public private(set) var status: GameStatus
    private var history: [Snapshot] = []
    private let poles: Set<GridPoint>
    private let mirrors: [GridPoint: Mirror]
    private let palette: [CandyColor]

    private struct Snapshot: Sendable {
        var candies: [Int: CandyState]
        var bag: Bag
        var moves: Int
    }

    public init(level: Level, endless: Bool = false) {
        self.level = level
        self.endless = endless
        let keys = level.candies.contains { $0.has(.key) }
        candies = Dictionary(uniqueKeysWithValues: level.candies.map { ($0.id, CandyState($0, keysOnBoard: keys)) })
        bag = Bag(capacity: level.bagCapacity)
        hearts = level.hearts
        moves = 0
        status = level.candies.isEmpty && !endless ? .won : .playing
        poles = Set(level.poles)
        mirrors = Dictionary(level.mirrors.map { ($0.position, $0) }, uniquingKeysWith: { first, _ in first })
        palette = level.changerPalette
        _ = refreshReveals()
    }

    // MARK: Queries

    /// Candies still on the board, in level order.
    public var remainingCandies: [CandyState] {
        // Endless candies arrive later and are not in the level file: order them by id.
        if endless { return candies.values.sorted { $0.id < $1.id } }
        return level.candies.compactMap { candies[$0.id] }
    }

    public var canUndo: Bool { !history.isEmpty }

    public func candy(at point: GridPoint) -> CandyState? {
        candies.values.first { $0.cells.contains(point) }
    }

    public func obstacle(at point: GridPoint, ignoring id: Int? = nil) -> Obstacle? {
        if poles.contains(point) { return .pole(point) }
        for state in candies.values where state.id != id && state.cells.contains(point) {
            return .candy(state.id)
        }
        return nil
    }

    /// Looks along the candy's current arrow.
    public func path(for id: Int) -> PathCheck? {
        guard let state = candies[id] else { return nil }
        let trace = trace(for: state)
        if let obstacle = trace.obstacle { return .blocked(obstacle: obstacle, distance: trace.route.count) }
        return .clear(exitDistance: trace.route.count)
    }

    /// Follows the arrow (and bumpers) until the candy leaves the board or hits something.
    public func trace(for state: CandyState) -> Trace {
        var direction = state.direction
        var route: [GridPoint] = []
        let isBar = state.cells.count > 1
        var offsets = state.cells.map { GridPoint($0.x - state.cells[0].x, $0.y - state.cells[0].y) }
        if isBar { offsets = offsets.filter { $0 != GridPoint(0, 0) } }
        var anchor = state.cells[0]
        let limit = (level.width + level.height) * 4
        for _ in 0..<limit {
            anchor += direction
            // Every cell of the candy at its new position.
            let footprint = [anchor] + (isBar ? offsets.map { GridPoint(anchor.x + $0.x, anchor.y + $0.y) } : [])
            let inside = footprint.filter(level.contains)
            if inside.isEmpty {
                route.append(anchor)
                return Trace(route: route, finalDirection: direction, obstacle: nil)
            }
            for cell in inside where !state.cells.contains(cell) {
                if let hit = obstacle(at: cell, ignoring: state.id) {
                    return Trace(route: route, finalDirection: direction, obstacle: hit)
                }
                if isBar, mirrors[cell] != nil {
                    return Trace(route: route, finalDirection: direction, obstacle: .mirror(cell))
                }
            }
            route.append(anchor)
            if !isBar, let mirror = mirrors[anchor] {
                direction = mirror.deflect(direction)
            }
        }
        // Went round in circles between bumpers: treat as stuck.
        return Trace(route: route, finalDirection: direction, obstacle: .mirror(anchor))
    }

    // MARK: Actions

    @discardableResult
    public mutating func tap(_ id: Int) -> MoveReport {
        guard status == .playing, let state = candies[id] else {
            return MoveReport(result: .ignored, status: status)
        }
        if state.frozen {
            return MoveReport(result: .frozen(candyID: id), status: status)
        }
        if state.locked {
            return MoveReport(result: .locked(candyID: id), status: status)
        }
        let trace = trace(for: state)
        if let obstacle = trace.obstacle {
            let heartLost = !level.tutorial && !endless
            if heartLost {
                hearts -= 1
                if hearts <= 0 { status = .lost(.outOfHearts) }
            }
            let bounce = Bounce(
                candyID: id, direction: state.direction, obstacle: obstacle,
                distance: trace.route.count, heartLost: heartLost
            )
            return MoveReport(result: .bounced(bounce), status: status)
        }

        history.append(Snapshot(candies: candies, bag: bag, moves: moves))
        var report: MoveReport
        if state.caramelIntact {
            candies[id]?.caramelIntact = false
            report = MoveReport(result: .crackedCaramel(candyID: id), status: status)
        } else {
            candies[id] = nil
            let insertion = bag.insert(state.color)
            let launch = Launch(
                candyID: id, color: state.color, direction: state.direction,
                exitDistance: trace.route.count, route: trace.route, bag: insertion
            )
            report = MoveReport(result: .launched(launch), status: status)
            var removed = [state]
            if state.candy.has(.bomb) {
                let around = Set(state.cells.flatMap(\.neighbors))
                let victims = candies.values.filter { $0.cells.contains(where: around.contains) }
                for victim in victims { candies[victim.id] = nil }
                report.exploded = victims.map(\.id).sorted()
                removed += victims
            }
            report.melted = removed.flatMap { melt(around: $0) }.sorted()
            report.unlocked = unlockIfKeysGone()
        }
        moves += 1
        report.rotated = rotateSpinners()
        report.recolored = cycleColors()
        report.revealed = refreshReveals()
        updateStatus()
        report.status = status
        return report
    }

    /// The app calls this when the clock runs out.
    public mutating func timeRanOut() {
        guard status == .playing else { return }
        status = .lost(.outOfTime)
    }

    /// Continue offer after the clock ran out (the app adds the extra seconds).
    public mutating func continueAfterTimeout() {
        if status == .lost(.outOfTime) { status = .playing }
    }

    /// Takes back the last successful move. Hearts are not refunded.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        candies = last.candies
        bag = last.bag
        moves = last.moves
        if status != .lost(.outOfTime) {
            status = hearts > 0 ? .playing : .lost(.outOfHearts)
        }
        return true
    }

    // MARK: Boosters

    /// Booster / continue offer: one extra bag slot. Revives a game lost on a full bag.
    public mutating func addBagSlot() {
        bag.addSlot()
        if status == .lost(.bagFull), !bag.isFull { status = .playing }
    }

    /// Continue offer after running out of hearts.
    public mutating func addHearts(_ count: Int) {
        hearts += count
        if status == .lost(.outOfHearts), hearts > 0 { status = .playing }
    }

    /// Booster: takes a candy off the board without putting it in the bag.
    /// Clears the undo history, so the booster cannot be undone by accident.
    @discardableResult
    public mutating func removeCandy(_ id: Int) -> MoveReport? {
        guard let state = candies[id], status == .playing || status == .lost(.bagFull) else {
            return nil
        }
        candies[id] = nil
        history.removeAll()
        var report = MoveReport(result: .ignored, status: status)
        report.melted = melt(around: state)
        report.unlocked = unlockIfKeysGone()
        report.revealed = refreshReveals()
        if status == .lost(.bagFull) { status = .playing }
        updateStatus()
        report.status = status
        return report
    }

    // MARK: Endless mode

    /// Puts a new candy on the board. Returns nil if any of its cells is taken.
    @discardableResult
    public mutating func spawn(_ candy: Candy) -> CandyState? {
        guard endless, status == .playing, candies[candy.id] == nil,
              candy.cells.allSatisfy({ level.contains($0) && obstacle(at: $0) == nil && mirrors[$0] == nil })
        else { return nil }
        let state = CandyState(candy, keysOnBoard: false)
        candies[candy.id] = state
        _ = refreshReveals()
        return candies[candy.id]
    }

    /// Takes a candy away without any of the game's side effects (for "what if" checks).
    mutating func removeForPlanning(_ id: Int) {
        candies[id] = nil
    }

    /// Ends an endless run (the board is full).
    public mutating func endRun(_ reason: LossReason) {
        guard status == .playing else { return }
        status = .lost(reason)
    }

    /// Continue offer in endless mode: takes the given candies away, empties the jar and plays on.
    public mutating func revive(removing ids: [Int]) {
        for id in ids { candies[id] = nil }
        bag = Bag(capacity: bag.capacity)
        history.removeAll()
        status = .playing
    }

    // MARK: Internals

    private mutating func melt(around removed: CandyState) -> [Int] {
        let around = Set(removed.cells.flatMap(\.neighbors))
        var melted: [Int] = []
        for (id, state) in candies where state.frozen && state.cells.contains(where: around.contains) {
            candies[id]?.frozen = false
            melted.append(id)
        }
        return melted.sorted()
    }

    private mutating func unlockIfKeysGone() -> [Int] {
        guard !candies.values.contains(where: { $0.candy.has(.key) }) else { return [] }
        var opened: [Int] = []
        for (id, state) in candies where state.locked {
            candies[id]?.locked = false
            opened.append(id)
        }
        return opened.sorted()
    }

    private mutating func rotateSpinners() -> [Int: Direction] {
        var rotated: [Int: Direction] = [:]
        for (id, state) in candies where state.candy.has(.rotating) {
            let next = state.direction.rotated(by: 1)
            candies[id]?.direction = next
            rotated[id] = next
        }
        return rotated
    }

    private mutating func cycleColors() -> [Int: CandyColor] {
        guard palette.count > 1 else { return [:] }
        var recolored: [Int: CandyColor] = [:]
        for (id, state) in candies where state.candy.has(.colorChanger) {
            let index = palette.firstIndex(of: state.color) ?? 0
            let next = palette[(index + 1) % palette.count]
            candies[id]?.color = next
            recolored[id] = next
        }
        return recolored
    }

    private mutating func refreshReveals() -> [Int] {
        var revealed: [Int] = []
        for (id, state) in candies where !state.revealed {
            if trace(for: state).isClear {
                candies[id]?.revealed = true
                revealed.append(id)
            }
        }
        return revealed.sorted()
    }

    private mutating func updateStatus() {
        if candies.isEmpty, !endless {
            status = .won
        } else if bag.isFull {
            status = .lost(.bagFull)
        }
    }
}
