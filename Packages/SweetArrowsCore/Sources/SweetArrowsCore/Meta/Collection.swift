import Foundation

// MARK: Sticker album

/// The sticker album: four pages of six candy stickers. A good run (100+ points) drops one sticker.
/// A full page pays a gift; a copy you already have turns into a few coins.
public enum StickerAlbum {
    public static let pages = 4
    public static let perPage = 6
    public static var count: Int { pages * perPage }
    /// A run needs this many points to drop a sticker.
    public static let minScore = 100
    public static let duplicateCoins = 5
    /// The last stickers on a page are rarer.
    public static let weights = [5, 5, 4, 3, 2, 1]
    public static let pageReward = Reward(coins: 150, boosters: [.hint: 1, .hammer: 1, .slowDown: 1])
    public static let albumReward = Reward(coins: 1000, boosters: [.hint: 3, .hammer: 3, .slowDown: 3])

    public static func page(of sticker: Int) -> Int { sticker / perPage }

    public static func stickers(onPage page: Int) -> Range<Int> { (page * perPage)..<((page + 1) * perPage) }

    /// Rare stickers: the last one on each page.
    public static func isRare(_ sticker: Int) -> Bool { sticker % perPage == perPage - 1 }

    /// Picks a sticker for a roll in 0..<1.
    static func pick(roll: Double) -> Int {
        let total = weights.reduce(0, +) * pages
        var left = Int(min(max(roll, 0), 0.999_999) * Double(total))
        for sticker in 0..<count {
            left -= weights[sticker % perPage]
            if left < 0 { return sticker }
        }
        return count - 1
    }
}

/// What one run dropped into the album.
public struct StickerDrop: Hashable, Sendable {
    public var sticker: Int
    public var isNew: Bool
    /// The page this sticker completed, if any.
    public var completedPage: Int?
    public var completedAlbum: Bool
    /// Coins for a copy, or the page (and album) gift.
    public var reward: Reward
}

public struct StickerCollection: Hashable, Codable, Sendable {
    /// Copies per sticker id.
    public var copies: [Int: Int] = [:]

    public init() {}

    public func has(_ sticker: Int) -> Bool { (copies[sticker] ?? 0) > 0 }

    public var owned: Int { (0..<StickerAlbum.count).filter(has).count }

    public func isComplete(page: Int) -> Bool { StickerAlbum.stickers(onPage: page).allSatisfy(has) }

    public var isComplete: Bool { owned == StickerAlbum.count }

    /// Adds the sticker for `roll`, works out the gift and returns what happened (the caller pays the reward).
    mutating func add(roll: Double) -> StickerDrop {
        let sticker = StickerAlbum.pick(roll: roll)
        let isNew = !has(sticker)
        copies[sticker, default: 0] += 1
        guard isNew else {
            return StickerDrop(
                sticker: sticker, isNew: false, completedPage: nil, completedAlbum: false,
                reward: Reward(coins: StickerAlbum.duplicateCoins)
            )
        }
        let page = StickerAlbum.page(of: sticker)
        let pageDone = isComplete(page: page)
        var reward = pageDone ? StickerAlbum.pageReward : Reward()
        if isComplete { reward = reward + StickerAlbum.albumReward }
        return StickerDrop(
            sticker: sticker, isNew: true, completedPage: pageDone ? page : nil, completedAlbum: isComplete,
            reward: reward
        )
    }

    func merged(with other: StickerCollection) -> StickerCollection {
        var result = self
        result.copies = copies.merging(other.copies) { max($0, $1) }
        return result
    }
}

// MARK: Season path

/// A free reward path that runs four weeks. Every run's XP also counts as season points;
/// each tier reached unlocks a gift to collect. A new season starts empty.
public struct SeasonPass: Hashable, Codable, Sendable {
    public static let lengthInDays = 28
    public static let tiers = 20
    public static let pointsPerTier = 120

    public static func season(for day: Int) -> Int { day >= 0 ? day / lengthInDays : (day + 1) / lengthInDays - 1 }

    public static func daysLeft(today: Int) -> Int {
        (season(for: today) + 1) * lengthInDays - today
    }

    /// The gift for a tier (1-based): coins, with boosters every fifth tier and a big final gift.
    public static func reward(tier: Int) -> Reward {
        if tier == tiers {
            return Reward(coins: 500, boosters: [.hint: 2, .hammer: 2, .slowDown: 2])
        }
        if tier.isMultiple(of: 5) {
            return Reward(coins: 60 + 5 * tier, boosters: [.hint: 1, .hammer: 1, .slowDown: 1])
        }
        let boosterTiers: [Int: Booster] = [3: .hint, 7: .hammer, 12: .slowDown, 17: .hammer]
        if let booster = boosterTiers[tier] { return Reward(coins: 20, boosters: [booster: 1]) }
        return Reward(coins: 30 + 5 * tier)
    }

    public var season: Int?
    public var points = 0
    public var claimed: Set<Int> = []

    public init() {}

    /// Starts over when a new season has begun.
    public mutating func refresh(today: Int) {
        let current = Self.season(for: today)
        guard season != current else { return }
        season = current
        points = 0
        claimed = []
    }

    public func points(today: Int) -> Int { season == Self.season(for: today) ? points : 0 }

    /// Tiers reached this season (0...tiers).
    public func tier(today: Int) -> Int { min(points(today: today) / Self.pointsPerTier, Self.tiers) }

    /// Points into the next tier.
    public func pointsIntoTier(today: Int) -> Int {
        tier(today: today) == Self.tiers ? Self.pointsPerTier : points(today: today) % Self.pointsPerTier
    }

    public func claimable(today: Int) -> [Int] {
        let reached = tier(today: today)
        guard reached > 0 else { return [] }
        let claimedNow = season == Self.season(for: today) ? claimed : []
        return (1...reached).filter { !claimedNow.contains($0) }
    }

    public func isClaimed(_ tier: Int, today: Int) -> Bool {
        season == Self.season(for: today) && claimed.contains(tier)
    }

    /// Adds points; returns the tiers newly reached.
    mutating func add(_ gained: Int, today: Int) -> ClosedRange<Int>? {
        refresh(today: today)
        let before = tier(today: today)
        points += max(gained, 0)
        let after = tier(today: today)
        return after > before ? (before + 1)...after : nil
    }

    /// Marks a reached tier as collected and returns its gift (nil if not reached or already collected).
    mutating func claim(_ tier: Int, today: Int) -> Reward? {
        refresh(today: today)
        guard tier >= 1, tier <= self.tier(today: today), claimed.insert(tier).inserted else { return nil }
        return Self.reward(tier: tier)
    }
}

// MARK: Weekly tournament

/// A Monday-to-Sunday contest on the classic board. The week's best score climbs a ladder of
/// trophies (each paid once a week); the score also goes to a weekly Game Center leaderboard.
public struct WeeklyTournament: Hashable, Codable, Sendable {
    public enum Trophy: Int, CaseIterable, Codable, Sendable {
        case bronze, silver, gold, diamond

        public var score: Int {
            switch self {
            case .bronze: 500
            case .silver: 1500
            case .gold: 3000
            case .diamond: 6000
            }
        }

        public var reward: Reward {
            switch self {
            case .bronze: Reward(coins: 50)
            case .silver: Reward(coins: 100, boosters: [.hint: 1])
            case .gold: Reward(coins: 200, boosters: [.hammer: 1, .slowDown: 1])
            case .diamond: Reward(coins: 400, boosters: [.hint: 2, .hammer: 2, .slowDown: 2])
            }
        }
    }

    /// Day 0 (1 January 2026) is a Thursday, so weeks start on Monday at day 4.
    public static func week(for day: Int) -> Int {
        let shifted = day + 3
        return shifted >= 0 ? shifted / 7 : (shifted + 1) / 7 - 1
    }

    public static func daysLeft(today: Int) -> Int { (week(for: today) + 1) * 7 - 3 - today }

    public var week: Int?
    public var best = 0

    public init() {}

    public func best(today: Int) -> Int { week == Self.week(for: today) ? best : 0 }

    /// Trophies won this week.
    public func trophies(today: Int) -> [Trophy] {
        let score = best(today: today)
        return Trophy.allCases.filter { score >= $0.score }
    }

    /// The next trophy to aim for, if any.
    public func nextTrophy(today: Int) -> Trophy? {
        let score = best(today: today)
        return Trophy.allCases.first { score < $0.score }
    }

    /// Records a classic run; returns the trophies newly won (the caller pays their rewards).
    mutating func record(score: Int, today: Int) -> [Trophy] {
        let current = Self.week(for: today)
        if week != current {
            week = current
            best = 0
        }
        let before = trophies(today: today)
        best = max(best, score)
        return trophies(today: today).filter { !before.contains($0) }
    }
}

public extension Reward {
    static func + (lhs: Reward, rhs: Reward) -> Reward {
        Reward(coins: lhs.coins + rhs.coins, boosters: lhs.boosters.merging(rhs.boosters, uniquingKeysWith: +))
    }
}
