/// Boosters the player can use during a level.
public enum Booster: String, CaseIterable, Codable, Sendable {
    /// One more slot in the jar for this level.
    case extraSlot
    /// Points at a safe next tap.
    case hint
    /// Takes one candy off the board without putting it in the jar.
    case removeCandy

    /// Price in coins when the player has none in stock.
    public var price: Int {
        switch self {
        case .hint: 60
        case .removeCandy: 90
        case .extraSlot: 120
        }
    }
}

/// Coins and boosters, all in one place so the balance can be tuned.
public enum Economy {
    /// Coins for winning a level.
    public static let levelReward = 10
    /// Extra coins from the third win in a row onwards.
    public static let streakBonus = 5
    public static let streakBonusFrom = 3
    /// Extra coins per star above one.
    public static let starBonus = 2
    /// Coins for finishing the daily puzzle.
    public static let dailyPuzzleReward = 40

    /// Coins for a won level, given the win streak *including* this win.
    public static func coins(forStars stars: Int, winStreak: Int) -> Int {
        levelReward + max(stars - 1, 0) * starBonus + (winStreak >= streakBonusFrom ? streakBonus : 0)
    }
}

/// Boosters in stock.
public struct BoosterInventory: Hashable, Codable, Sendable {
    public var counts: [Booster: Int]

    public init(counts: [Booster: Int] = [:]) {
        self.counts = counts
    }

    public subscript(booster: Booster) -> Int {
        get { counts[booster] ?? 0 }
        set { counts[booster] = max(newValue, 0) }
    }

    public mutating func add(_ booster: Booster, _ amount: Int = 1) {
        self[booster] += amount
    }
}
