/// A reward: coins and/or boosters.
public struct Reward: Hashable, Codable, Sendable {
    public var coins: Int
    public var boosters: [Booster: Int]

    public init(coins: Int = 0, boosters: [Booster: Int] = [:]) {
        self.coins = coins
        self.boosters = boosters
    }

    public func doubled() -> Reward {
        Reward(coins: coins * 2, boosters: boosters.mapValues { $0 * 2 })
    }
}

/// The 7-day daily reward. Days are local calendar day numbers (see `DayNumber`).
/// Missing a day starts the row again at day 1; after day 7 it starts over too.
public struct DailyRewardState: Hashable, Codable, Sendable {
    public static let rewards: [Reward] = [
        Reward(coins: 20),
        Reward(coins: 30),
        Reward(boosters: [.hint: 1]),
        Reward(coins: 50),
        Reward(boosters: [.removeCandy: 1]),
        Reward(coins: 80),
        Reward(coins: 100, boosters: [.extraSlot: 1]),
    ]

    /// Day number of the last claim.
    public var lastClaimDay: Int?
    /// 1...7: which reward was claimed last.
    public var lastClaimedStep: Int

    public init(lastClaimDay: Int? = nil, lastClaimedStep: Int = 0) {
        self.lastClaimDay = lastClaimDay
        self.lastClaimedStep = lastClaimedStep
    }

    /// The step (1...7) that can be claimed today, or nil if today's reward is already taken.
    public func claimableStep(today: Int) -> Int? {
        guard let last = lastClaimDay else { return 1 }
        if today == last { return nil }
        if today == last + 1 { return lastClaimedStep % 7 + 1 }
        return 1  // missed a day (or the clock went backwards): start over
    }

    /// Claims today's reward. Returns nil if it was already claimed.
    public mutating func claim(today: Int) -> (step: Int, reward: Reward)? {
        guard let step = claimableStep(today: today) else { return nil }
        lastClaimDay = today
        lastClaimedStep = step
        return (step, DailyRewardState.rewards[step - 1])
    }
}

/// Converts dates to local calendar day numbers, so "a new day" follows the player's midnight.
public enum DayNumber {
    /// Days since 1 January 2026 for the given calendar date.
    public static func from(year: Int, month: Int, day: Int) -> Int {
        daysFromCivil(year: year, month: month, day: day) - daysFromCivil(year: 2026, month: 1, day: 1)
    }

    // Howard Hinnant's days_from_civil: exact for the proleptic Gregorian calendar.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe
    }
}
