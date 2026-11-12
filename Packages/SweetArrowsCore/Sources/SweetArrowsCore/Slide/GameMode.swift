/// The ways to play. All use the same slide & match rules on the 5x5 board.
public enum GameMode: String, Codable, CaseIterable, Sendable {
    /// Endless, faster and faster (the main game).
    case classic
    /// One board a day, the same for everyone, with its own leaderboard.
    case daily
    /// No clock: one new candy after every move.
    case zen
    /// Sixty seconds, fast candies, as many points as you can.
    case blitz

    public var settings: SlideGame.Settings {
        var settings = SlideGame.Settings()
        switch self {
        case .classic, .daily:
            break
        case .zen:
            settings.spawnsPerMove = true
            settings.startCandies = 6
            settings.startInterval = 1_000_000  // never: candies come with moves
        case .blitz:
            settings.timeLimit = 60
            settings.startCandies = 6
            settings.startInterval = 1.8
            settings.fastestInterval = 0.8
            settings.popsPerStage = 8
        }
        return settings
    }

    /// A paid "keep going" makes no sense against the clock or on the shared daily board.
    public var allowsRevive: Bool { self == .classic || self == .zen }

    /// Classic and Zen runs are kept when the player leaves; Daily and Blitz always start fresh.
    public var canBeResumed: Bool { self == .classic || self == .zen }

    /// The same seed for everyone on a calendar day.
    public static func dailySeed(day: Int) -> UInt64 {
        UInt64(bitPattern: Int64(day)) &* 0x9E37_79B9_7F4A_7C15 &+ 0x5EED
    }

    /// A new game in this mode.
    public static func newGame(_ mode: GameMode, today: Int, seed: UInt64) -> SlideGame {
        SlideGame(seed: mode == .daily ? dailySeed(day: today) : seed, settings: mode.settings)
    }
}

/// Today's daily challenge: best score and how often it was played.
public struct DailyChallengeState: Hashable, Codable, Sendable {
    public var day: Int?
    public var best = 0
    public var plays = 0

    public init() {}

    public func best(today: Int) -> Int { day == today ? best : 0 }

    mutating func record(score: Int, today: Int) -> Bool {
        if day != today {
            day = today
            best = 0
            plays = 0
        }
        plays += 1
        guard score > best else { return false }
        best = score
        return true
    }
}
