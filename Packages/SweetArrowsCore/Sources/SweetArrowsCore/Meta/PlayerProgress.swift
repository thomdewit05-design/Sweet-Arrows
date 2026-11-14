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
    public var ownedCosmetics: Set<Cosmetic> = [.woodCounter, .classicCandy, .candyMeadow]
    public var board: Cosmetic = .woodCounter
    public var candyStyle: Cosmetic = .classicCandy
    public var backdrop: Cosmetic = .candyMeadow
    /// Total XP; the player level follows from it.
    public var xp = 0
    public var missions = DailyMissions()
    public var streak = PlayStreak()
    /// Best score and number of runs played.
    public var endlessBest = 0
    public var endlessRuns = 0
    public var settings = GameSettings()
    /// When this copy last changed (used to pick a winner when iCloud copies disagree).
    public var updatedAt = Date(timeIntervalSince1970: 0)

    public init() {}

    /// The daily reward and the shop appear after a few runs (PLAN.md, onboarding).
    public var showsMetaFeatures: Bool { endlessRuns >= 3 }

    public var level: Int { PlayerLevel.level(forXP: xp) }
    public var xpIntoLevel: Int { PlayerLevel.xpIntoLevel(forXP: xp) }
    public var xpForLevel: Int { PlayerLevel.xpToNext(level) }

    // MARK: Changes

    /// Records a finished run: best score, coins, streak, daily missions and XP with level rewards.
    @discardableResult
    public mutating func recordRun(_ run: RunSummary, today: Int) -> RunOutcome {
        let previousBest = endlessBest
        let levelBefore = level
        endlessRuns += 1
        endlessBest = max(endlessBest, run.score)
        coins += run.coins
        streak.played(today: today)

        missions.refresh(today: today, level: levelBefore)
        let (finished, missionReward) = missions.record(run)
        apply(missionReward)

        let gained = PlayerLevel.xp(for: run)
        xp += gained
        var rewards: [LevelReward] = []
        if level > levelBefore {
            for reached in (levelBefore + 1)...level {
                let reward = PlayerLevel.reward(for: reached)
                apply(reward.reward)
                if let unlock = reward.unlock { ownedCosmetics.insert(unlock) }
                rewards.append(reward)
            }
        }
        return RunOutcome(
            summary: run, newRecord: run.score > previousBest, previousBest: previousBest, coinsFromScore: run.coins,
            xpGained: gained, levelBefore: levelBefore, levelAfter: level, xpIntoLevel: xpIntoLevel,
            xpForLevel: xpForLevel, levelRewards: rewards, finishedMissions: finished, missionReward: missionReward,
            allMissionsDone: missions.allDone, streak: streak.current
        )
    }

    /// Today's missions, freshly made on a new day (for showing them before the first run).
    public mutating func refreshMissions(today: Int) {
        missions.refresh(today: today, level: level)
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
        case .backdrop: backdrop = item
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
        result.xp = max(xp, other.xp)
        result.streak.best = max(streak.best, other.streak.best)
        result.endlessBest = max(endlessBest, other.endlessBest)
        result.endlessRuns = max(endlessRuns, other.endlessRuns)
        result.updatedAt = max(updatedAt, other.updatedAt)
        return result
    }

    // MARK: Codable (tolerant)

    private enum CodingKeys: String, CodingKey {
        case coins, boosters, dailyReward
        case ownedCosmetics, board, candyStyle, backdrop, xp, missions, streak, settings, updatedAt
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
        backdrop = try c.decodeIfPresent(Cosmetic.self, forKey: .backdrop) ?? .candyMeadow
        ownedCosmetics.insert(.candyMeadow)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        missions = try c.decodeIfPresent(DailyMissions.self, forKey: .missions) ?? DailyMissions()
        streak = try c.decodeIfPresent(PlayStreak.self, forKey: .streak) ?? PlayStreak()
        endlessBest = try c.decodeIfPresent(Int.self, forKey: .endlessBest) ?? 0
        endlessRuns = try c.decodeIfPresent(Int.self, forKey: .endlessRuns) ?? 0
        settings = try c.decodeIfPresent(GameSettings.self, forKey: .settings) ?? GameSettings()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
    }
}
