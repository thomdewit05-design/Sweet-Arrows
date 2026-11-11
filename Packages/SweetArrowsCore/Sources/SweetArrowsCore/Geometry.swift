/// A cell on the board. `x` is the column (0 = left), `y` the row (0 = top).
public struct GridPoint: Hashable, Codable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public static func + (lhs: GridPoint, rhs: Direction) -> GridPoint {
        GridPoint(lhs.x + rhs.dx, lhs.y + rhs.dy)
    }

    public static func += (lhs: inout GridPoint, rhs: Direction) {
        lhs = lhs + rhs
    }

    public var neighbors: [GridPoint] {
        Direction.allCases.map { self + $0 }
    }

    public var description: String { "(\(x),\(y))" }

    // Compact JSON: [x, y]
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Int.self)
        y = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

/// The direction an arrow points to. Rotation is always clockwise.
public enum Direction: String, CaseIterable, Codable, Sendable {
    case up, right, down, left

    public var dx: Int {
        switch self {
        case .left: -1
        case .right: 1
        case .up, .down: 0
        }
    }

    public var dy: Int {
        switch self {
        case .up: -1
        case .down: 1
        case .left, .right: 0
        }
    }

    /// Index in clockwise order, starting at `.up`.
    public var index: Int {
        switch self {
        case .up: 0
        case .right: 1
        case .down: 2
        case .left: 3
        }
    }

    public init(index: Int) {
        let all: [Direction] = [.up, .right, .down, .left]
        self = all[((index % 4) + 4) % 4]
    }

    /// Rotated clockwise by `quarterTurns` quarter turns (negative = counterclockwise).
    public func rotated(by quarterTurns: Int) -> Direction {
        Direction(index: index + quarterTurns)
    }
}
