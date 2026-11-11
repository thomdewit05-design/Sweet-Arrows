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

/// Everything we keep about the player. Saved after every run and synced through iCloud.
/// Decoding tolerates missing keys, so older saves keep working when fields are added.
public struct PlayerProgress: Codable, Equatable, Sendable {
    public var coins = 0
    public var boosters = BoosterInventory()
    public var dailyReward = DailyRewardState()
    public var ownedCosmetics: Set<Cosmetic> = [.woodCounter, .classicCandy]
    public var board: Cosmetic = .woodCounter
    public var candyStyle: Cosmetic = .classicCandy
    public var starterPackBought = false
    /// Best score and number of runs played.
    public var endlessBest = 0
    public var endlessRuns = 0
    /// Day number on which the VIP daily hints were last given.
    public var vipBonusDay: Int?
    public var settings = GameSettings()
    /// When this copy last changed (used to pick a winner when iCloud copies disagree).
    public var updatedAt = Date(timeIntervalSince1970: 0)

    public init() {}

    /// The daily reward and the shop appear after a few runs (PLAN.md, onboarding).
    public var showsMetaFeatures: Bool { endlessRuns >= 3 }

    // MARK: Changes

    /// Records a finished run. Returns true for a new best score.
    @discardableResult
    public mutating func recordEndless(score: Int, coins: Int) -> Bool {
        endlessRuns += 1
        self.coins += coins
        guard score > endlessBest else { return false }
        endlessBest = score
        return true
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

    /// The starter pack is offered once, after `runs` runs.
    public func showsStarterPack(afterRuns runs: Int) -> Bool {
        !starterPackBought && endlessRuns >= runs
    }

    /// VIP perk: free hints once a day. Returns the number granted (0 if already given today).
    public mutating func grantVIPBonus(today: Int, hints: Int = 3) -> Int {
        guard vipBonusDay != today else { return 0 }
        vipBonusDay = today
        boosters.add(.hint, hints)
        return hints
    }

    public mutating func equip(_ item: Cosmetic, isVIP: Bool = false) {
        if item.vipOnly {
            guard isVIP else { return }
            ownedCosmetics.insert(item)
        }
        guard ownedCosmetics.contains(item) else { return }
        switch item.kind {
        case .board: board = item
        case .candyStyle: candyStyle = item
        }
    }

    // MARK: iCloud merge

    /// Combines two copies of the progress (this device and iCloud) without losing anything earned:
    /// best score, runs and cosmetics are united; the wallet (coins, boosters) and settings
    /// come from the copy that changed most recently.
    public func merged(with other: PlayerProgress) -> PlayerProgress {
        let selfIsNewer = updatedAt >= other.updatedAt
        let newer = selfIsNewer ? self : other
        var result = newer
        result.ownedCosmetics = ownedCosmetics.union(other.ownedCosmetics)
        result.starterPackBought = starterPackBought || other.starterPackBought
        result.endlessBest = max(endlessBest, other.endlessBest)
        result.endlessRuns = max(endlessRuns, other.endlessRuns)
        result.updatedAt = max(updatedAt, other.updatedAt)
        return result
    }

    // MARK: Codable (tolerant)

    private enum CodingKeys: String, CodingKey {
        case coins, boosters, dailyReward
        case ownedCosmetics, board, candyStyle, settings, updatedAt, starterPackBought, vipBonusDay
        case endlessBest, endlessRuns
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        boosters = try c.decodeIfPresent(BoosterInventory.self, forKey: .boosters) ?? BoosterInventory()
        dailyReward = try c.decodeIfPresent(DailyRewardState.self, forKey: .dailyReward) ?? DailyRewardState()
        ownedCosmetics = try c.decodeIfPresent(Set<Cosmetic>.self, forKey: .ownedCosmetics) ?? [.woodCounter, .classicCandy]
        board = try c.decodeIfPresent(Cosmetic.self, forKey: .board) ?? .woodCounter
        candyStyle = try c.decodeIfPresent(Cosmetic.self, forKey: .candyStyle) ?? .classicCandy
        starterPackBought = try c.decodeIfPresent(Bool.self, forKey: .starterPackBought) ?? false
        vipBonusDay = try c.decodeIfPresent(Int.self, forKey: .vipBonusDay)
        endlessBest = try c.decodeIfPresent(Int.self, forKey: .endlessBest) ?? 0
        endlessRuns = try c.decodeIfPresent(Int.self, forKey: .endlessRuns) ?? 0
        settings = try c.decodeIfPresent(GameSettings.self, forKey: .settings) ?? GameSettings()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
    }
}
