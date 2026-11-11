import Foundation

/// Player settings, stored with the progress.
public struct GameSettings: Codable, Equatable, Sendable {
    public var sound = true
    public var music = true
    public var haptics = true
    public var colorBlind = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        music = try c.decodeIfPresent(Bool.self, forKey: .music) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        colorBlind = try c.decodeIfPresent(Bool.self, forKey: .colorBlind) ?? false
    }

    private enum CodingKeys: String, CodingKey { case sound, music, haptics, colorBlind }
}

/// Everything we keep about the player. Saved after every level and synced through iCloud.
/// Decoding tolerates missing keys, so older saves keep working when fields are added.
public struct PlayerProgress: Codable, Equatable, Sendable {
    /// Highest level completed (0 = none yet).
    public var completedLevel = 0
    /// Best stars per level id (1–3).
    public var stars: [Int: Int] = [:]
    public var coins = 0
    public var winStreak = 0
    public var bestWinStreak = 0
    public var boosters = BoosterInventory()
    public var dailyReward = DailyRewardState()
    public var dailyPuzzle = DailyPuzzleState()
    public var ownedCosmetics: Set<Cosmetic> = [.woodCounter, .classicCandy]
    public var board: Cosmetic = .woodCounter
    public var candyStyle: Cosmetic = .classicCandy
    /// World elements whose intro card the player has seen.
    public var seenElements: Set<BoardElement> = []
    public var settings = GameSettings()
    /// When this copy last changed (used to pick a winner when iCloud copies disagree).
    public var updatedAt = Date(timeIntervalSince1970: 0)

    public init() {}

    public var nextLevel: Int { completedLevel + 1 }
    public var totalStars: Int { stars.values.reduce(0, +) }

    public func isUnlocked(_ level: Int) -> Bool { level <= nextLevel }

    /// The daily reward and the shop appear after level 5 (PLAN.md, onboarding).
    public var showsMetaFeatures: Bool { completedLevel >= 5 }

    // MARK: Changes

    /// Records a won level and returns the coins earned.
    @discardableResult
    public mutating func recordWin(level: Int, stars newStars: Int) -> Int {
        completedLevel = max(completedLevel, level)
        stars[level] = max(stars[level] ?? 0, newStars)
        winStreak += 1
        bestWinStreak = max(bestWinStreak, winStreak)
        let earned = Economy.coins(forStars: newStars, winStreak: winStreak)
        coins += earned
        return earned
    }

    public mutating func recordLoss() {
        winStreak = 0
    }

    public mutating func apply(_ reward: Reward) {
        coins += reward.coins
        for (booster, amount) in reward.boosters { boosters.add(booster, amount) }
    }

    /// Uses a booster from stock, or buys it with coins. Returns false if neither is possible.
    public mutating func spend(_ booster: Booster) -> Bool {
        if boosters[booster] > 0 {
            boosters[booster] -= 1
            return true
        }
        guard coins >= booster.price else { return false }
        coins -= booster.price
        return true
    }

    public func canAfford(_ booster: Booster) -> Bool {
        boosters[booster] > 0 || coins >= booster.price
    }

    /// Buys a cosmetic with coins. Returns false if already owned or too expensive.
    public mutating func buy(_ item: Cosmetic) -> Bool {
        guard !ownedCosmetics.contains(item), coins >= item.price else { return false }
        coins -= item.price
        ownedCosmetics.insert(item)
        return true
    }

    public mutating func equip(_ item: Cosmetic) {
        guard ownedCosmetics.contains(item) else { return }
        switch item.kind {
        case .board: board = item
        case .candyStyle: candyStyle = item
        }
    }

    // MARK: iCloud merge

    /// Combines two copies of the progress (this device and iCloud) without losing anything earned:
    /// levels, stars, cosmetics and daily results are united; the wallet (coins, boosters),
    /// streaks and settings come from the copy that changed most recently.
    public func merged(with other: PlayerProgress) -> PlayerProgress {
        let selfIsNewer = updatedAt >= other.updatedAt
        let newer = selfIsNewer ? self : other
        let older = selfIsNewer ? other : self
        var result = newer
        result.completedLevel = max(completedLevel, other.completedLevel)
        result.stars = stars.merging(other.stars) { max($0, $1) }
        result.bestWinStreak = max(bestWinStreak, other.bestWinStreak)
        result.ownedCosmetics = ownedCosmetics.union(other.ownedCosmetics)
        result.seenElements = seenElements.union(other.seenElements)

        var daily = newer.dailyPuzzle
        for (day, entry) in older.dailyPuzzle.results {
            if let mine = daily.results[day], !entry.isBetter(than: mine) { continue }
            daily.results[day] = entry
        }
        daily.bestStreak = max(dailyPuzzle.bestStreak, other.dailyPuzzle.bestStreak)
        result.dailyPuzzle = daily
        result.updatedAt = max(updatedAt, other.updatedAt)
        return result
    }

    // MARK: Codable (tolerant)

    private enum CodingKeys: String, CodingKey {
        case completedLevel, stars, coins, winStreak, bestWinStreak, boosters, dailyReward, dailyPuzzle
        case ownedCosmetics, board, candyStyle, seenElements, settings, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completedLevel = try c.decodeIfPresent(Int.self, forKey: .completedLevel) ?? 0
        stars = try c.decodeIfPresent([Int: Int].self, forKey: .stars) ?? [:]
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        winStreak = try c.decodeIfPresent(Int.self, forKey: .winStreak) ?? 0
        bestWinStreak = try c.decodeIfPresent(Int.self, forKey: .bestWinStreak) ?? winStreak
        boosters = try c.decodeIfPresent(BoosterInventory.self, forKey: .boosters) ?? BoosterInventory()
        dailyReward = try c.decodeIfPresent(DailyRewardState.self, forKey: .dailyReward) ?? DailyRewardState()
        dailyPuzzle = try c.decodeIfPresent(DailyPuzzleState.self, forKey: .dailyPuzzle) ?? DailyPuzzleState()
        ownedCosmetics = try c.decodeIfPresent(Set<Cosmetic>.self, forKey: .ownedCosmetics) ?? [.woodCounter, .classicCandy]
        board = try c.decodeIfPresent(Cosmetic.self, forKey: .board) ?? .woodCounter
        candyStyle = try c.decodeIfPresent(Cosmetic.self, forKey: .candyStyle) ?? .classicCandy
        seenElements = try c.decodeIfPresent(Set<BoardElement>.self, forKey: .seenElements) ?? []
        settings = try c.decodeIfPresent(GameSettings.self, forKey: .settings) ?? GameSettings()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
    }
}
