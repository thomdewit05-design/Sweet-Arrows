/// The six candy colors. Every color also has its own shape, so the game stays
/// playable for color-blind players.
public enum CandyColor: String, CaseIterable, Codable, Sendable, Comparable {
    case strawberry  // #FF5C8A, heart
    case lemon       // #FFD23F, star
    case mint        // #3DDC97, round
    case blueberry   // #5B6CFF, diamond
    case orange      // #FF9F1C, drop
    case grape       // #A259FF, square

    public var shape: CandyShape {
        switch self {
        case .strawberry: .heart
        case .lemon: .star
        case .mint: .circle
        case .blueberry: .diamond
        case .orange: .drop
        case .grape: .square
        }
    }

    /// Palette value as 0xRRGGBB, shared by the app and tools.
    public var hex: UInt32 {
        switch self {
        case .strawberry: 0xFF5C8A
        case .lemon: 0xFFD23F
        case .mint: 0x3DDC97
        case .blueberry: 0x5B6CFF
        case .orange: 0xFF9F1C
        case .grape: 0xA259FF
        }
    }

    public var index: Int { CandyColor.allCases.firstIndex(of: self)! }

    public static func < (lhs: CandyColor, rhs: CandyColor) -> Bool { lhs.index < rhs.index }
}

public enum CandyShape: String, Sendable {
    case heart, star, circle, diamond, drop, square
}

/// Special elements that are introduced world by world.
public enum CandyFeature: String, CaseIterable, Codable, Sendable, Comparable {
    /// Needs two taps: the first cracks the caramel, the second launches it.
    case caramel
    /// The arrow turns a quarter clockwise after every move.
    case rotating
    /// Frozen until a neighbouring candy has left the board.
    case iced
    /// The color is hidden until the candy's path is clear.
    case wrapped

    public static func < (lhs: CandyFeature, rhs: CandyFeature) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// A candy as described by a level file.
public struct Candy: Hashable, Codable, Sendable, Identifiable {
    public var id: Int
    public var color: CandyColor
    /// Anchor cell. A chocolate bar extends one cell right (horizontal) or down (vertical).
    public var position: GridPoint
    public var direction: Direction
    /// `nil` for a normal one-cell candy, otherwise a two-cell chocolate bar.
    public var bar: Axis?
    public var features: Set<CandyFeature>

    public init(
        id: Int,
        color: CandyColor,
        position: GridPoint,
        direction: Direction,
        bar: Axis? = nil,
        features: Set<CandyFeature> = []
    ) {
        self.id = id
        self.color = color
        self.position = position
        self.direction = direction
        self.bar = bar
        self.features = features
    }

    public var cells: [GridPoint] {
        switch bar {
        case nil: [position]
        case .horizontal: [position, GridPoint(position.x + 1, position.y)]
        case .vertical: [position, GridPoint(position.x, position.y + 1)]
        }
    }

    public var isChocolateBar: Bool { bar != nil }
    public func has(_ feature: CandyFeature) -> Bool { features.contains(feature) }

    private enum CodingKeys: String, CodingKey {
        case id, color, position = "at", direction = "dir", bar, features
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        color = try c.decode(CandyColor.self, forKey: .color)
        position = try c.decode(GridPoint.self, forKey: .position)
        direction = try c.decode(Direction.self, forKey: .direction)
        bar = try c.decodeIfPresent(Axis.self, forKey: .bar)
        features = try c.decodeIfPresent(Set<CandyFeature>.self, forKey: .features) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(color, forKey: .color)
        try c.encode(position, forKey: .position)
        try c.encode(direction, forKey: .direction)
        try c.encodeIfPresent(bar, forKey: .bar)
        if !features.isEmpty {
            try c.encode(features.sorted(), forKey: .features)
        }
    }
}
