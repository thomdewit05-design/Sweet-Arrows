/// What one run did. Feeds XP, daily missions, achievements and the result card.
public struct RunSummary: Hashable, Codable, Sendable {
    public var score: Int
    public var popped: Int
    public var bestCombo: Int
    /// 0-based speed stage reached.
    public var stage: Int
    public var bombs: Int
    public var rainbows: Int
    public var stones: Int
    public var boardClears: Int
    /// Most candies in one line-up.
    public var biggestPop: Int
    public var seconds: Int

    public init(
        score: Int = 0, popped: Int = 0, bestCombo: Int = 0, stage: Int = 0, bombs: Int = 0, rainbows: Int = 0,
        stones: Int = 0, boardClears: Int = 0, biggestPop: Int = 0, seconds: Int = 0
    ) {
        self.score = score
        self.popped = popped
        self.bestCombo = bestCombo
        self.stage = stage
        self.bombs = bombs
        self.rainbows = rainbows
        self.stones = stones
        self.boardClears = boardClears
        self.biggestPop = biggestPop
        self.seconds = seconds
    }

    /// Coins straight from the score.
    public var coins: Int { score / 25 }
}

// MARK: Player level

/// Player level from XP. Every run gives XP; every level gives coins, and some levels unlock a backdrop
/// or a booster pack.
public enum PlayerLevel {
    /// XP needed to go from `level` to `level + 1`.
    public static func xpToNext(_ level: Int) -> Int { 100 + 40 * (max(level, 1) - 1) }

    /// Level (1-based) for a total amount of XP.
    public static func level(forXP xp: Int) -> Int {
        var level = 1
        var left = xp
        while left >= xpToNext(level) {
            left -= xpToNext(level)
            level += 1
        }
        return level
    }

    /// XP already earned inside the current level.
    public static func xpIntoLevel(forXP xp: Int) -> Int {
        var level = 1
        var left = xp
        while left >= xpToNext(level) {
            left -= xpToNext(level)
            level += 1
        }
        return left
    }

    /// XP for a run: a base for playing, more for points and empty boards.
    public static func xp(for run: RunSummary) -> Int {
        20 + run.score / 25 + 15 * run.boardClears
    }

    /// The reward for reaching `level`.
    public static func reward(for level: Int) -> LevelReward {
        var reward = Reward(coins: 40 + 10 * level)
        if level.isMultiple(of: 5) {
            for booster in Booster.allCases { reward.boosters[booster, default: 0] += 1 }
        }
        let unlock = Cosmetic.allCases.first { $0.unlockLevel == level }
        return LevelReward(level: level, reward: reward, unlock: unlock)
    }
}

public struct LevelReward: Hashable, Sendable {
    public var level: Int
    public var reward: Reward
    /// A backdrop that comes free with this level.
    public var unlock: Cosmetic?
}

// MARK: Daily missions

public enum MissionKind: String, Codable, CaseIterable, Sendable {
    case score, popCandies, combo, bombs, stones, rainbows, runs, bigPop, speed

    /// Cumulative over the day (add every run) or a best in one run.
    public var isCumulative: Bool {
        switch self {
        case .popCandies, .bombs, .stones, .rainbows, .runs: true
        case .score, .combo, .bigPop, .speed: false
        }
    }

    /// Kinds that need special candies show up once the player has a few levels.
    var minimumLevel: Int {
        switch self {
        case .stones, .speed: 3
        case .rainbows: 5
        default: 1
        }
    }

    /// Target for a player level tier (0...4).
    func target(tier: Int) -> Int {
        let table: [Int] = switch self {
        case .score: [600, 1200, 2000, 3200, 5000]
        case .popCandies: [30, 50, 80, 120, 160]
        case .combo: [3, 3, 4, 4, 5]
        case .bombs: [1, 2, 3, 4, 5]
        case .stones: [2, 3, 5, 7, 9]
        case .rainbows: [1, 1, 2, 2, 3]
        case .runs: [2, 3, 3, 4, 5]
        case .bigPop: [4, 4, 5, 5, 5]
        case .speed: [3, 4, 5, 6, 7]
        }
        return table[min(max(tier, 0), table.count - 1)]
    }

    /// How far a run gets this mission.
    func value(in run: RunSummary) -> Int {
        switch self {
        case .score: run.score
        case .popCandies: run.popped
        case .combo: run.bestCombo
        case .bombs: run.bombs
        case .stones: run.stones
        case .rainbows: run.rainbows
        case .runs: 1
        case .bigPop: run.biggestPop
        case .speed: run.stage + 1
        }
    }
}

public struct Mission: Hashable, Codable, Sendable {
    public var kind: MissionKind
    public var target: Int
    public var coins: Int
    public var progress = 0

    public var isDone: Bool { progress >= target }
}

/// Three missions a day, the same for every player of a level tier, with a bonus for finishing all three.
public struct DailyMissions: Hashable, Codable, Sendable {
    public static let allDoneBonus = Reward(coins: 60, boosters: [.hint: 1])

    public var day: Int?
    public var missions: [Mission] = []
    public var bonusClaimed = false

    public init() {}

    public var allDone: Bool { !missions.isEmpty && missions.allSatisfy(\.isDone) }

    /// New missions on a new day.
    public mutating func refresh(today: Int, level: Int) {
        guard day != today else { return }
        day = today
        missions = DailyMissions.make(day: today, level: level)
        bonusClaimed = false
    }

    /// Adds a run. Returns the missions it finished and the coins they (and the bonus) pay.
    public mutating func record(_ run: RunSummary) -> (finished: [Mission], reward: Reward) {
        var finished: [Mission] = []
        var reward = Reward()
        for index in missions.indices where !missions[index].isDone {
            let value = missions[index].kind.value(in: run)
            if missions[index].kind.isCumulative {
                missions[index].progress += value
            } else {
                missions[index].progress = max(missions[index].progress, value)
            }
            if missions[index].isDone {
                missions[index].progress = missions[index].target
                finished.append(missions[index])
                reward.coins += missions[index].coins
            }
        }
        if allDone, !bonusClaimed {
            bonusClaimed = true
            reward.coins += DailyMissions.allDoneBonus.coins
            for (booster, amount) in DailyMissions.allDoneBonus.boosters {
                reward.boosters[booster, default: 0] += amount
            }
        }
        return (finished, reward)
    }

    /// Picks three different missions for a day; targets grow with the player level.
    public static func make(day: Int, level: Int) -> [Mission] {
        let tier = min(max(level - 1, 0) / 5, 4)
        var rng = SeededRandom(seed: UInt64(bitPattern: Int64(day)) &* 2_654_435_761 &+ 97)
        var kinds = MissionKind.allCases.filter { $0.minimumLevel <= level }
        kinds.shuffle(using: &rng)
        return kinds.prefix(3).map { Mission(kind: $0, target: $0.target(tier: tier), coins: 40 + 10 * tier) }
    }
}

// MARK: Streak

/// Days in a row with at least one run.
public struct PlayStreak: Hashable, Codable, Sendable {
    public var lastDay: Int?
    public var current = 0
    public var best = 0

    public init() {}

    public mutating func played(today: Int) {
        if lastDay == today { return }
        current = lastDay == today - 1 ? current + 1 : 1
        lastDay = today
        best = max(best, current)
    }

    /// The streak as it stands today (0 once a day was missed).
    public func current(today: Int) -> Int {
        guard let lastDay, today - lastDay <= 1 else { return 0 }
        return current
    }
}

// MARK: Run outcome

/// Everything a finished run earned, for the result card.
public struct RunOutcome: Hashable, Sendable {
    public var summary: RunSummary
    public var newRecord: Bool
    public var previousBest: Int
    public var coinsFromScore: Int
    public var xpGained: Int
    public var levelBefore: Int
    public var levelAfter: Int
    /// XP inside the level reached, and what that level needs.
    public var xpIntoLevel: Int
    public var xpForLevel: Int
    public var levelRewards: [LevelReward]
    public var finishedMissions: [Mission]
    public var missionReward: Reward
    public var allMissionsDone: Bool
    public var streak: Int

    /// All coins this run paid out.
    public var totalCoins: Int {
        coinsFromScore + missionReward.coins + levelRewards.map(\.reward.coins).reduce(0, +)
    }
}
