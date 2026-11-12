/// The lucky wheel: one free spin a day, and up to two more a day by watching an ad.
public struct LuckyWheel: Hashable, Codable, Sendable {
    public struct Segment: Hashable, Sendable {
        public var reward: Reward
        /// Relative chance of landing here.
        public var weight: Int
        public var isJackpot: Bool
    }

    /// The eight segments, in clockwise order from the top.
    public static let segments: [Segment] = [
        Segment(reward: Reward(coins: 20), weight: 24, isJackpot: false),
        Segment(reward: Reward(boosters: [.hint: 1]), weight: 15, isJackpot: false),
        Segment(reward: Reward(coins: 50), weight: 20, isJackpot: false),
        Segment(reward: Reward(boosters: [.hammer: 1]), weight: 10, isJackpot: false),
        Segment(reward: Reward(coins: 100), weight: 11, isJackpot: false),
        Segment(reward: Reward(boosters: [.slowDown: 1]), weight: 9, isJackpot: false),
        Segment(reward: Reward(coins: 250), weight: 7, isJackpot: false),
        Segment(reward: Reward(coins: 500, boosters: [.hint: 1, .hammer: 1, .slowDown: 1]), weight: 4, isJackpot: true),
    ]

    public static let adSpinsPerDay = 2

    public var lastFreeSpinDay: Int?
    public var adSpinDay: Int?
    public var adSpinsUsed = 0

    public init() {}

    public func hasFreeSpin(today: Int) -> Bool { lastFreeSpinDay != today }

    public func adSpinsLeft(today: Int) -> Int {
        adSpinDay == today ? max(LuckyWheel.adSpinsPerDay - adSpinsUsed, 0) : LuckyWheel.adSpinsPerDay
    }

    /// Picks a segment by weight. `roll` is a number in 0..<1.
    public static func segment(for roll: Double) -> Int {
        let total = segments.map(\.weight).reduce(0, +)
        var target = Int(min(max(roll, 0), 0.999_999) * Double(total))
        for (index, segment) in segments.enumerated() {
            if target < segment.weight { return index }
            target -= segment.weight
        }
        return segments.count - 1
    }

    /// Uses up a spin (the free one first, otherwise an ad spin). Returns the segment, or nil when no spin is left.
    public mutating func spin(today: Int, viaAd: Bool, roll: Double) -> Int? {
        if viaAd {
            guard adSpinsLeft(today: today) > 0 else { return nil }
            if adSpinDay != today {
                adSpinDay = today
                adSpinsUsed = 0
            }
            adSpinsUsed += 1
        } else {
            guard hasFreeSpin(today: today) else { return nil }
            lastFreeSpinDay = today
        }
        return LuckyWheel.segment(for: roll)
    }
}
