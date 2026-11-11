import Foundation

/// Ad limits from Remote Config (with the PLAN.md defaults).
public struct AdLimits: Hashable, Codable, Sendable {
    public var interstitialMinLevel = 8
    public var interstitialLevelGap = 2
    public var interstitialMinSeconds: TimeInterval = 90
    public var rewardedDailyCap = 20
    /// No ads and no consent questions before this level is completed (except the GDPR form).
    public var adsFromLevel = 3
    public var bannerEnabled = true
    public var appOpenEnabled = false
    public var appOpenMinHoursAway: Double = 4
    /// App-open ads only from this day after install (1 = install day).
    public var appOpenFromDay = 2
    /// An interstitial never follows a rewarded ad this recently.
    public var quietAfterRewarded: TimeInterval = 120

    public init() {}
}

/// What has been shown so far, to apply the frequency caps. Persisted by the app.
public struct AdHistory: Hashable, Codable, Sendable {
    public var lastInterstitialAt: Date?
    public var levelsSinceInterstitial = 0
    public var lastRewardedAt: Date?
    public var rewardedDay: Int?
    public var rewardedCount = 0
    public var installDay: Int?

    public init(installDay: Int? = nil) {
        self.installDay = installDay
    }
}

/// The ad rules from PLAN.md as pure, testable logic. `AdService` asks it before every ad.
public struct AdPolicy: Sendable {
    public var limits: AdLimits
    public var history: AdHistory

    public init(limits: AdLimits = AdLimits(), history: AdHistory = AdHistory()) {
        self.limits = limits
        self.history = history
    }

    /// Rewarded ads are always optional; allowed after the first levels, up to the daily cap.
    public func canShowRewarded(completedLevel: Int, today: Int) -> Bool {
        guard completedLevel >= limits.adsFromLevel else { return false }
        return rewardedCount(today: today) < limits.rewardedDailyCap
    }

    public func rewardedCount(today: Int) -> Int {
        history.rewardedDay == today ? history.rewardedCount : 0
    }

    /// Between levels only: from `interstitialMinLevel`, at most one per `interstitialLevelGap` levels,
    /// at least `interstitialMinSeconds` apart, never after a lost level or right after a rewarded ad.
    public func canShowInterstitial(afterLevel level: Int, won: Bool, now: Date) -> Bool {
        guard won, level >= limits.interstitialMinLevel else { return false }
        guard history.levelsSinceInterstitial >= limits.interstitialLevelGap else { return false }
        if let last = history.lastInterstitialAt, now.timeIntervalSince(last) < limits.interstitialMinSeconds {
            return false
        }
        if let rewarded = history.lastRewardedAt, now.timeIntervalSince(rewarded) < limits.quietAfterRewarded {
            return false
        }
        return true
    }

    /// Coming back after more than `appOpenMinHoursAway` hours, from day 2, when switched on remotely.
    public func canShowAppOpen(awaySince: Date?, now: Date, today: Int, completedLevel: Int) -> Bool {
        guard limits.appOpenEnabled, completedLevel >= limits.adsFromLevel, let awaySince else {
            return false
        }
        if let install = history.installDay, today - install + 1 < limits.appOpenFromDay { return false }
        return now.timeIntervalSince(awaySince) >= limits.appOpenMinHoursAway * 3600
    }

    public func canShowBanner(completedLevel: Int) -> Bool {
        limits.bannerEnabled && completedLevel >= limits.adsFromLevel
    }

    // MARK: Recording

    /// Call after every finished level (won or lost).
    public mutating func levelFinished() {
        history.levelsSinceInterstitial += 1
    }

    public mutating func interstitialShown(at now: Date) {
        history.lastInterstitialAt = now
        history.levelsSinceInterstitial = 0
    }

    public mutating func rewardedShown(at now: Date, today: Int) {
        if history.rewardedDay != today {
            history.rewardedDay = today
            history.rewardedCount = 0
        }
        history.rewardedCount += 1
        history.lastRewardedAt = now
    }
}
