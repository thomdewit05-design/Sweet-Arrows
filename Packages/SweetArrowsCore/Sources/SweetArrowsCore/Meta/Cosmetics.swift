/// Things that only change the look: counters and candy styles are bought with coins,
/// backdrops come free with player levels.
public enum Cosmetic: String, CaseIterable, Codable, Sendable {
    // Board (counter) styles
    case woodCounter, mintMarble, strawberryCheck, midnightCandy
    // Candy styles
    case classicCandy, pastelCandy, sparkleCandy, goldenCandy
    // Backdrops behind the board, unlocked by player level
    case candyMeadow, iceCreamBay, chocolateRiver, cottonSky, starryNight

    public enum Kind: String, Sendable {
        case board, candyStyle, backdrop
    }

    public var kind: Kind {
        switch self {
        case .woodCounter, .mintMarble, .strawberryCheck, .midnightCandy: .board
        case .classicCandy, .pastelCandy, .sparkleCandy, .goldenCandy: .candyStyle
        case .candyMeadow, .iceCreamBay, .chocolateRiver, .cottonSky, .starryNight: .backdrop
        }
    }

    /// Player level that unlocks this item for free (backdrops only).
    public var unlockLevel: Int? {
        switch self {
        case .candyMeadow: 1
        case .iceCreamBay: 3
        case .chocolateRiver: 6
        case .cottonSky: 10
        case .starryNight: 15
        default: nil
        }
    }

    /// 0 = owned from the start.
    public var price: Int {
        switch self {
        case .woodCounter, .classicCandy: 0
        case .candyMeadow, .iceCreamBay, .chocolateRiver, .cottonSky, .starryNight: 0
        case .mintMarble: 300
        case .strawberryCheck: 400
        case .midnightCandy: 800
        case .pastelCandy: 350
        case .sparkleCandy: 600
        case .goldenCandy: 1500
        }
    }

    public static func defaultItem(for kind: Kind) -> Cosmetic {
        switch kind {
        case .board: .woodCounter
        case .candyStyle: .classicCandy
        case .backdrop: .candyMeadow
        }
    }

    public static func items(of kind: Kind) -> [Cosmetic] {
        allCases.filter { $0.kind == kind }
    }
}
