import Foundation
import SweetArrowsCore
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Why the player watches a rewarded ad. Logged with every ad.
enum RewardReason: String, Sendable {
    case extraSlot = "extra_slot"
    case undo
    case removeCandy = "remove_candy"
    case hint
    case doubleCoins = "double_coins"
    case extraHearts = "extra_hearts"
    case extraTime = "extra_time"
    case dailyRewardDouble = "daily_reward_double"
}

/// All ad logic lives behind this protocol. The game calls `showRewarded(reason:)`,
/// `levelFinished(won:)` and `maybeShowInterstitial(afterLevel:)`; the rules live in `AdPolicy`.
@MainActor
protocol AdService: AnyObject {
    var isRewardedReady: Bool { get }
    var canShowBanner: Bool { get }
    var bannerAdUnitID: String { get }
    /// Starts the SDK once consent allows it.
    func start()
    func updateLimits(_ limits: AdLimits)
    /// Shows a rewarded ad. Returns true when the reward was earned.
    func showRewarded(reason: RewardReason) async -> Bool
    func levelFinished(won: Bool)
    func maybeShowInterstitial(afterLevel level: Int)
    func maybeShowAppOpen(awaySince: Date)
}

/// Ad unit ids from Info.plist (filled from the xcconfig: Google's test ids in Debug,
/// your own ids from Config/Secrets.xcconfig in Release).
struct AdUnitIDs: Sendable {
    var rewarded: String
    var interstitial: String
    var banner: String
    var appOpen: String

    static let test = AdUnitIDs(
        rewarded: "ca-app-pub-3940256099942544/1712485313",
        interstitial: "ca-app-pub-3940256099942544/4411468910",
        banner: "ca-app-pub-3940256099942544/2435281174",
        appOpen: "ca-app-pub-3940256099942544/5575463023"
    )

    static func fromInfoPlist(_ bundle: Bundle = .main) -> AdUnitIDs {
        func value(_ key: String, _ fallback: String) -> String {
            let raw = bundle.object(forInfoDictionaryKey: key) as? String ?? ""
            return raw.hasPrefix("ca-app-pub-") ? raw : fallback
        }
        return AdUnitIDs(
            rewarded: value("SAAdUnitRewarded", test.rewarded),
            interstitial: value("SAAdUnitInterstitial", test.interstitial),
            banner: value("SAAdUnitBanner", test.banner),
            appOpen: value("SAAdUnitAppOpen", test.appOpen)
        )
    }
}

/// Google Mobile Ads (AdMob) with the frequency caps from `AdPolicy`.
/// Ads are preloaded; when none is ready, the ad buttons are greyed out instead of failing.
@MainActor
final class GoogleAdService: NSObject, AdService {
    private var policy: AdPolicy
    private let ids: AdUnitIDs
    private let consent: ConsentService
    private let analytics: AnalyticsService
    private let save: SaveService
    private let purchases: PurchaseService
    private let today: () -> Int
    private var started = false
    private static let historyKey = "adHistory.v1"

    #if canImport(GoogleMobileAds)
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var appOpen: AppOpenAd?
    #endif
    private var rewardContinuation: CheckedContinuation<Bool, Never>?
    private var rewardEarned = false
    private var pendingReason: RewardReason?

    init(
        ids: AdUnitIDs = .fromInfoPlist(),
        consent: ConsentService,
        analytics: AnalyticsService,
        save: SaveService,
        purchases: PurchaseService,
        today: @escaping () -> Int
    ) {
        self.ids = ids
        self.consent = consent
        self.analytics = analytics
        self.save = save
        self.purchases = purchases
        self.today = today
        var history = UserDefaults.standard.data(forKey: Self.historyKey)
            .flatMap { try? JSONDecoder().decode(AdHistory.self, from: $0) } ?? AdHistory()
        if history.installDay == nil { history.installDay = today() }
        policy = AdPolicy(history: history)
        super.init()
        persistHistory()
    }

    private var adsRemoved: Bool { purchases.hasRemovedAds || purchases.isVIP }
    private var completedLevel: Int { save.progress.completedLevel }

    var canShowBanner: Bool {
        started && policy.canShowBanner(completedLevel: completedLevel, adsRemoved: adsRemoved)
    }

    var bannerAdUnitID: String { ids.banner }

    var isRewardedReady: Bool {
        // VIP members get rewarded boosters without watching.
        if purchases.isVIP { return true }
        guard policy.canShowRewarded(completedLevel: completedLevel, today: today()) else { return false }
        #if canImport(GoogleMobileAds)
        return rewarded != nil
        #else
        return false
        #endif
    }

    func updateLimits(_ limits: AdLimits) {
        policy.limits = limits
    }

    func start() {
        guard !started, consent.canRequestAds else { return }
        started = true
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        loadRewarded()
        loadInterstitial()
        loadAppOpen()
        #endif
    }

    // MARK: Rewarded

    func showRewarded(reason: RewardReason) async -> Bool {
        analytics.log(.adOfferAccepted(reason: reason.rawValue))
        if purchases.isVIP { return true }
        #if canImport(GoogleMobileAds)
        guard isRewardedReady, let ad = rewarded, rewardContinuation == nil else { return false }
        rewarded = nil
        rewardEarned = false
        pendingReason = reason
        return await withCheckedContinuation { continuation in
            rewardContinuation = continuation
            ad.present(from: UIApplication.topViewController()) { [weak self] in
                MainActor.assumeIsolated { self?.rewardEarned = true }
            }
        }
        #else
        return false
        #endif
    }

    // MARK: Interstitial & app open

    func levelFinished(won: Bool) {
        policy.levelFinished()
        lastLevelWon = won
        persistHistory()
    }

    private var lastLevelWon = false

    func maybeShowInterstitial(afterLevel level: Int) {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitial,
              policy.canShowInterstitial(afterLevel: level, won: lastLevelWon, adsRemoved: adsRemoved, now: Date())
        else { return }
        interstitial = nil
        policy.interstitialShown(at: Date())
        persistHistory()
        ad.present(from: UIApplication.topViewController())
        #endif
    }

    func maybeShowAppOpen(awaySince: Date) {
        #if canImport(GoogleMobileAds)
        guard let ad = appOpen, policy.canShowAppOpen(
            awaySince: awaySince, now: Date(), today: today(), completedLevel: completedLevel, adsRemoved: adsRemoved
        ) else { return }
        appOpen = nil
        ad.present(from: UIApplication.topViewController())
        #endif
    }

    // MARK: Loading

    #if canImport(GoogleMobileAds)
    private func loadRewarded() {
        RewardedAd.load(with: ids.rewarded, request: Request()) { [weak self] loaded, _ in
            // Google calls this on the main thread; the ad object is only ever used there.
            nonisolated(unsafe) let ad = loaded
            MainActor.assumeIsolated {
                guard let self, let ad else { return }
                ad.fullScreenContentDelegate = self
                ad.paidEventHandler = { [weak self] value in
                    let amount = value.value.doubleValue
                    let currency = value.currencyCode
                    MainActor.assumeIsolated { self?.logImpression(format: "rewarded", value: amount, currency: currency) }
                }
                self.rewarded = ad
            }
        }
    }

    private func loadInterstitial() {
        InterstitialAd.load(with: ids.interstitial, request: Request()) { [weak self] loaded, _ in
            // Google calls this on the main thread; the ad object is only ever used there.
            nonisolated(unsafe) let ad = loaded
            MainActor.assumeIsolated {
                guard let self, let ad else { return }
                ad.fullScreenContentDelegate = self
                ad.paidEventHandler = { [weak self] value in
                    let amount = value.value.doubleValue
                    let currency = value.currencyCode
                    MainActor.assumeIsolated { self?.logImpression(format: "interstitial", value: amount, currency: currency) }
                }
                self.interstitial = ad
            }
        }
    }

    private func loadAppOpen() {
        AppOpenAd.load(with: ids.appOpen, request: Request()) { [weak self] loaded, _ in
            // Google calls this on the main thread; the ad object is only ever used there.
            nonisolated(unsafe) let ad = loaded
            MainActor.assumeIsolated {
                guard let self, let ad else { return }
                ad.fullScreenContentDelegate = self
                self.appOpen = ad
            }
        }
    }
    #endif

    private func logImpression(format: String, value: Double, currency: String) {
        analytics.log(.adImpression(format: format, network: "admob", value: value, currency: currency))
    }

    fileprivate func fullScreenAdClosed() {
        if let continuation = rewardContinuation {
            rewardContinuation = nil
            if rewardEarned {
                policy.rewardedShown(at: Date(), today: today())
                persistHistory()
            }
            continuation.resume(returning: rewardEarned)
        }
        #if canImport(GoogleMobileAds)
        if rewarded == nil { loadRewarded() }
        if interstitial == nil { loadInterstitial() }
        if appOpen == nil { loadAppOpen() }
        #endif
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(policy.history) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }
}

#if canImport(GoogleMobileAds)
extension GoogleAdService: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        MainActor.assumeIsolated { fullScreenAdClosed() }
    }

    nonisolated func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        MainActor.assumeIsolated { fullScreenAdClosed() }
    }
}
#endif

/// Used in previews, tests and UI tests. In Debug builds rewards are granted straight away
/// so the continue/booster flows can be tried without the ad SDK.
@MainActor
final class PlaceholderAdService: AdService {
    var isRewardedReady: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    let canShowBanner = false
    let bannerAdUnitID = AdUnitIDs.test.banner
    func start() {}
    func updateLimits(_ limits: AdLimits) {}

    func showRewarded(reason: RewardReason) async -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    func levelFinished(won: Bool) {}
    func maybeShowInterstitial(afterLevel level: Int) {}
    func maybeShowAppOpen(awaySince: Date) {}
}
