import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Ad rules")
struct AdPolicyTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func policy(levelsSince: Int = 5) -> AdPolicy {
        var policy = AdPolicy()
        policy.history.levelsSinceInterstitial = levelsSince
        return policy
    }

    @Test func noInterstitialBeforeLevel8() {
        #expect(!policy().canShowInterstitial(afterLevel: 7, won: true, now: t0))
        #expect(policy().canShowInterstitial(afterLevel: 8, won: true, now: t0))
    }

    @Test func neverAfterALostLevelOrWithRemoveAds() {
        #expect(!policy().canShowInterstitial(afterLevel: 20, won: false, now: t0))
    }

    @Test func atMostOnePerTwoLevelsAnd90SecondsApart() {
        var p = policy()
        p.interstitialShown(at: t0)
        p.levelFinished()
        #expect(!p.canShowInterstitial(afterLevel: 20, won: true, now: t0.addingTimeInterval(300)))
        p.levelFinished()
        #expect(p.canShowInterstitial(afterLevel: 21, won: true, now: t0.addingTimeInterval(300)))
        #expect(!p.canShowInterstitial(afterLevel: 21, won: true, now: t0.addingTimeInterval(60)))
    }

    @Test func neverRightAfterARewardedAd() {
        var p = policy()
        p.rewardedShown(at: t0, today: 1)
        #expect(!p.canShowInterstitial(afterLevel: 20, won: true, now: t0.addingTimeInterval(30)))
        #expect(p.canShowInterstitial(afterLevel: 20, won: true, now: t0.addingTimeInterval(200)))
    }

    @Test func rewardedDailyCapAndOnboarding() {
        var p = AdPolicy()
        #expect(!p.canShowRewarded(completedLevel: 2, today: 1))
        #expect(p.canShowRewarded(completedLevel: 3, today: 1))
        for _ in 0..<20 { p.rewardedShown(at: t0, today: 1) }
        #expect(!p.canShowRewarded(completedLevel: 50, today: 1))
        #expect(p.canShowRewarded(completedLevel: 50, today: 2))
        p.rewardedShown(at: t0, today: 2)
        #expect(p.rewardedCount(today: 2) == 1)
    }

    @Test func appOpenRules() {
        var p = AdPolicy(history: AdHistory(installDay: 10))
        let away = t0.addingTimeInterval(-5 * 3600)
        #expect(!p.canShowAppOpen(awaySince: away, now: t0, today: 11, completedLevel: 20))  // off by default
        p.limits.appOpenEnabled = true
        #expect(!p.canShowAppOpen(awaySince: away, now: t0, today: 10, completedLevel: 20))  // day 1
        #expect(p.canShowAppOpen(awaySince: away, now: t0, today: 11, completedLevel: 20))
        let shortly = t0.addingTimeInterval(-3600)
        #expect(!p.canShowAppOpen(awaySince: shortly, now: t0, today: 11, completedLevel: 20))
    }

    @Test func banner() {
        var p = AdPolicy()
        #expect(p.canShowBanner(completedLevel: 0))  // from the first run
        p.limits.bannerFromLevel = 2
        #expect(!p.canShowBanner(completedLevel: 1))
        #expect(p.canShowBanner(completedLevel: 3))
        p.limits.bannerEnabled = false
        #expect(!p.canShowBanner(completedLevel: 30))
    }
}
