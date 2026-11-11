import Observation
import SwiftUI
import SweetArrowsCore

enum Route: Hashable {
    /// The game (slide & match).
    case endless
    case shop
    case settings
    case dailyReward
}

/// App-wide state: navigation plus every service. Injected through the environment.
@MainActor
@Observable
final class AppModel {
    var path: [Route] = []

    let save: SaveService
    let config: ConfigService
    let analytics: AnalyticsService
    let ads: AdService
    let consent: ConsentService
    let purchases: PurchaseService
    let gameCenter: GameCenterService
    let audio: AudioService
    let haptics: HapticsService

    init(
        save: SaveService,
        config: ConfigService,
        analytics: AnalyticsService,
        ads: AdService,
        consent: ConsentService,
        purchases: PurchaseService,
        gameCenter: GameCenterService,
        audio: AudioService,
        haptics: HapticsService
    ) {
        self.save = save
        self.config = config
        self.analytics = analytics
        self.ads = ads
        self.consent = consent
        self.purchases = purchases
        self.gameCenter = gameCenter
        self.audio = audio
        self.haptics = haptics
        applySettings()
    }

    /// The real app.
    static func live() -> AppModel {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let save = isUITest
            ? SaveService(url: nil)
            : SaveService(url: SaveService.defaultURL, cloud: NSUbiquitousKeyValueStore.default)
        let analytics = FirebaseAnalyticsService()
        let config: ConfigService = isUITest ? LocalConfigService() : FirebaseConfigService()
        let consent: ConsentService = isUITest ? PlaceholderConsentService() : GoogleConsentService()
        let purchases: PurchaseService = isUITest
            ? PlaceholderPurchaseService()
            : StoreKitPurchaseService(save: save, analytics: analytics)
        let ads: AdService = isUITest
            ? PlaceholderAdService()
            : GoogleAdService(
                consent: consent, analytics: analytics, save: save, purchases: purchases,
                today: { AppModel.currentDay() }
            )
        ads.updateLimits(config.values.adLimits)
        config.onChange = { [weak ads] values in ads?.updateLimits(values.adLimits) }
        return AppModel(
            save: save,
            config: config,
            analytics: analytics,
            ads: ads,
            consent: consent,
            purchases: purchases,
            gameCenter: isUITest ? OfflineGameCenterService() : GameKitService(),
            audio: SoundEffectsService(),
            haptics: CoreHapticsService()
        )
    }

    /// In-memory app for previews and tests.
    static func preview() -> AppModel {
        AppModel(
            save: SaveService(url: nil),
            config: LocalConfigService(),
            analytics: FirebaseAnalyticsService(),
            ads: PlaceholderAdService(),
            consent: PlaceholderConsentService(),
            purchases: PlaceholderPurchaseService(),
            gameCenter: OfflineGameCenterService(),
            audio: SilentAudioService(),
            haptics: UIKitHapticsService()
        )
    }

    var settings: GameSettings { save.progress.settings }

    /// Today as a local calendar day number (a new day starts at the player's midnight).
    var today: Int { Self.currentDay() }

    static func currentDay() -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return DayNumber.from(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// First start: GDPR consent (UMP), then the ad SDK. ATT is asked later, after a few runs.
    func startConsentAndAds() async {
        await config.refresh()
        await consent.gatherConsent()
        ads.start()
        await purchases.refreshEntitlements()
        grantVIPBonusIfNeeded()
    }

    /// VIP perk: three free hints a day.
    func grantVIPBonusIfNeeded() {
        guard purchases.isVIP else { return }
        let day = today
        save.update { _ = $0.grantVIPBonus(today: day) }
    }

    /// Whether the starter pack offer should be visible.
    var showsStarterPack: Bool {
        save.progress.showsStarterPack(afterRuns: config.values.starterPackLevel)
    }

    /// Reports the achievements a finished run earned (cheap; Game Center ignores repeats).
    func reportAchievements(after run: SlideGame) {
        let progress = save.progress
        if run.popped > 0 { gameCenter.report(.firstPop) }
        if progress.endlessBest >= 1000 { gameCenter.report(.score1000) }
        if progress.endlessBest >= 5000 { gameCenter.report(.score5000) }
        if run.bestCombo >= 5 { gameCenter.report(.combo5) }
        if run.stage + 1 >= 10 { gameCenter.report(.speed10) }
        if progress.endlessRuns >= 50 { gameCenter.report(.runs50) }
    }

    func updateSettings(_ change: (inout GameSettings) -> Void) {
        save.update { change(&$0.settings) }
        applySettings()
    }

    private func applySettings() {
        let settings = save.progress.settings
        audio.soundEnabled = settings.sound
        audio.musicEnabled = settings.music
        haptics.enabled = settings.haptics
    }
}
