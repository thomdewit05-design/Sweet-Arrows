/// Something a moving candy can run into.
public enum Obstacle: Hashable, Sendable {
    case candy(Int)
    case pole(GridPoint)
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
    public var caramelIntact: Bool
    public var frozen: Bool
    /// False while a wrapped candy still hides its color.
    public var revealed: Bool

    public var id: Int { candy.id }
    public var color: CandyColor { candy.color }
    public var cells: [GridPoint] { candy.cells }

    init(_ candy: Candy) {
        self.candy = candy
        direction = candy.direction
        caramelIntact = candy.has(.caramel)
        frozen = candy.has(.iced)
        revealed = !candy.has(.wrapped)
    }
}

public struct Launch: Hashable, Sendable {
    public var candyID: Int
    public var color: CandyColor
    public var direction: Direction
    public var exitDistance: Int
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
    /// Game over or unknown candy.
    case ignored
}

/// Everything that changed because of one action, so the scene can animate it.
public struct MoveReport: Hashable, Sendable {
    public var result: TapResult
    /// Rotating candies whose arrow turned, with their new direction.
    public var rotated: [Int: Direction] = [:]
    /// Candies whose ice melted.
    public var melted: [Int] = []
    /// Wrapped candies that showed their color.
    public var revealed: [Int] = []
    public var status: GameStatus

    public var countsAsMove: Bool {
        switch result {
        case .launched, .crackedCaramel: true
        case .bounced, .frozen, .ignored: false
        }
    }
}

/// The rules of Sweet Arrows. Pure value type: no UI, no randomness.
public struct Game: Sendable {
    public let level: Level
    public private(set) var candies: [Int: CandyState]
    public private(set) var bag: Bag
    public private(set) var hearts: Int
    public private(set) var moves: Int
    public private(set) var status: GameStatus
    private var history: [Snapshot] = []
    private let poles: Set<GridPoint>

    private struct Snapshot: Sendable {
        var candies: [Int: CandyState]
        var bag: Bag
        var moves: Int
    }

    public init(level: Level) {
        self.level = level
        candies = Dictionary(uniqueKeysWithValues: level.candies.map { ($0.id, CandyState($0)) })
        bag = Bag(capacity: level.bagCapacity)
        hearts = level.hearts
        moves = 0
        status = level.candies.isEmpty ? .won : .playing
        poles = Set(level.poles)
        _ = refreshReveals()
    }

    // MARK: Queries

    /// Candies still on the board, in level order.
    public var remainingCandies: [CandyState] {
        level.candies.compactMap { candies[$0.id] }
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
        return path(for: state, direction: state.direction)
    }

    func path(for state: CandyState, direction: Direction) -> PathCheck {
        var nearest: (Obstacle, Int)?
        var exit = 0
        for cell in state.cells {
            var p = cell + direction
            var steps = 0
            while level.contains(p) {
                if !state.cells.contains(p), let hit = obstacle(at: p, ignoring: state.id) {
                    if nearest == nil || steps < nearest!.1 { nearest = (hit, steps) }
                    break
                }
                steps += 1
                p = p + direction
            }
            exit = max(exit, steps + 1)
        }
        if let nearest { return .blocked(obstacle: nearest.0, distance: nearest.1) }
        return .clear(exitDistance: exit)
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
        switch path(for: state, direction: state.direction) {
        case .blocked(let obstacle, let distance):
            let heartLost = !level.tutorial
            if heartLost {
                hearts -= 1
                if hearts <= 0 { status = .lost(.outOfHearts) }
            }
            let bounce = Bounce(
                candyID: id, direction: state.direction, obstacle: obstacle,
                distance: distance, heartLost: heartLost
            )
            return MoveReport(result: .bounced(bounce), status: status)

        case .clear(let exitDistance):
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
                    exitDistance: exitDistance, bag: insertion
                )
                report = MoveReport(result: .launched(launch), status: status)
                report.melted = melt(around: state)
            }
            moves += 1
            report.rotated = rotateSpinners()
            report.revealed = refreshReveals()
            updateStatus()
            report.status = status
            return report
        }
    }

    /// Takes back the last successful move. Hearts are not refunded.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        candies = last.candies
        bag = last.bag
        moves = last.moves
        status = hearts > 0 ? .playing : .lost(.outOfHearts)
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
        report.revealed = refreshReveals()
        if status == .lost(.bagFull) { status = .playing }
        updateStatus()
        report.status = status
        return report
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

    private mutating func rotateSpinners() -> [Int: Direction] {
        var rotated: [Int: Direction] = [:]
        for (id, state) in candies where state.candy.has(.rotating) {
            let next = state.direction.rotated(by: 1)
            candies[id]?.direction = next
            rotated[id] = next
        }
        return rotated
    }

    private mutating func refreshReveals() -> [Int] {
        var revealed: [Int] = []
        for (id, state) in candies where !state.revealed {
            if path(for: state, direction: state.direction).isClear {
                candies[id]?.revealed = true
                revealed.append(id)
            }
        }
        return revealed.sorted()
    }

    private mutating func updateStatus() {
        if candies.isEmpty {
            status = .won
        } else if bag.isFull {
            status = .lost(.bagFull)
        }
    }
}
