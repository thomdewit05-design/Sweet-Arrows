/// One finished daily puzzle.
public struct DailyResult: Hashable, Codable, Sendable {
    public var taps: Int
    public var seconds: Int
    public var stars: Int

    public init(taps: Int, seconds: Int, stars: Int) {
        self.taps = taps
        self.seconds = seconds
        self.stars = stars
    }

    /// Better = more stars, then fewer seconds.
    public func isBetter(than other: DailyResult) -> Bool {
        if stars != other.stars { return stars > other.stars }
        return seconds < other.seconds
    }
}

/// The daily puzzle: one solver-approved puzzle per day, the same for everyone.
public struct DailyPuzzleState: Hashable, Codable, Sendable {
    /// Best result per day number.
    public var results: [Int: DailyResult]
    public var streak: Int
    public var bestStreak: Int
    public var lastCompletedDay: Int?

    public init(results: [Int: DailyResult] = [:], streak: Int = 0, bestStreak: Int = 0, lastCompletedDay: Int? = nil) {
        self.results = results
        self.streak = streak
        self.bestStreak = bestStreak
        self.lastCompletedDay = lastCompletedDay
    }

    /// Which puzzle file to play on a given day (the pool repeats after `poolSize` days).
    public static func puzzleNumber(day: Int, poolSize: Int) -> Int {
        guard poolSize > 0 else { return 1 }
        return ((day % poolSize) + poolSize) % poolSize + 1
    }

    public func isCompleted(day: Int) -> Bool { results[day] != nil }

    /// Streak as shown today: still alive if the last completion was today or yesterday.
    public func currentStreak(today: Int) -> Int {
        guard let last = lastCompletedDay, today - last <= 1 else { return 0 }
        return streak
    }

    /// Records a win. Returns true when it was the first completion of that day.
    @discardableResult
    public mutating func record(_ result: DailyResult, day: Int) -> Bool {
        let first = results[day] == nil
        if let best = results[day], !result.isBetter(than: best) {
            // keep the best
        } else {
            results[day] = result
        }
        guard first else { return false }
        if let last = lastCompletedDay, day == last + 1 {
            streak += 1
        } else if lastCompletedDay != day {
            streak = 1
        }
        lastCompletedDay = max(lastCompletedDay ?? day, day)
        bestStreak = max(bestStreak, streak)
        return true
    }

    /// Wordle-style text to share: no spoilers, just how it went.
    public static func shareText(puzzle: Int, result: DailyResult, streak: Int) -> String {
        let stars = String(repeating: "⭐", count: result.stars) + String(repeating: "▫️", count: max(3 - result.stars, 0))
        let minutes = result.seconds / 60, seconds = result.seconds % 60
        let time = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
        return "Sweet Arrows Daily #\(puzzle) 🍬\n\(stars)  \(result.taps) taps · \(time)" + (streak > 1 ? " · 🔥\(streak)" : "")
    }
}
