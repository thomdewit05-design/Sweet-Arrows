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
