/// Things to buy with coins that only change the look.
public enum Cosmetic: String, CaseIterable, Codable, Sendable {
    // Board (counter) styles
    case woodCounter, mintMarble, strawberryCheck, midnightCandy
    // Candy styles
    case classicCandy, pastelCandy, sparkleCandy
    /// VIP members only.
    case goldenCandy

    public enum Kind: String, Sendable {
        case board, candyStyle
    }

    public var kind: Kind {
        switch self {
        case .woodCounter, .mintMarble, .strawberryCheck, .midnightCandy: .board
        case .classicCandy, .pastelCandy, .sparkleCandy, .goldenCandy: .candyStyle
        }
    }

    /// 0 = owned from the start.
    public var price: Int {
        switch self {
        case .woodCounter, .classicCandy, .goldenCandy: 0
        case .mintMarble: 300
        case .strawberryCheck: 400
        case .midnightCandy: 800
        case .pastelCandy: 350
        case .sparkleCandy: 600
        }
    }

    public var vipOnly: Bool { self == .goldenCandy }

    public static func defaultItem(for kind: Kind) -> Cosmetic {
        kind == .board ? .woodCounter : .classicCandy
    }

    public static func items(of kind: Kind) -> [Cosmetic] {
        allCases.filter { $0.kind == kind }
    }
}
