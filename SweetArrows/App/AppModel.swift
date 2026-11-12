import Observation
import SwiftUI
import SweetArrowsCore

enum Route: Hashable {
    /// The game (slide & match) in one of its modes.
    case play(GameMode)
    case shop
    /// Sticker album, season path and weekly tournament.
    case prizes
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
    let gameCenter: GameCenterService
    let audio: AudioService
    let haptics: HapticsService

    init(
        save: SaveService,
        config: ConfigService,
        analytics: AnalyticsService,
        ads: AdService,
        consent: ConsentService,
        gameCenter: GameCenterService,
        audio: AudioService,
        haptics: HapticsService
    ) {
        self.save = save
        self.config = config
        self.analytics = analytics
        self.ads = ads
        self.consent = consent
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
        let ads: AdService = isUITest
            ? PlaceholderAdService()
            : GoogleAdService(
                consent: consent, analytics: analytics, save: save,
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
            gameCenter: OfflineGameCenterService(),
            audio: SilentAudioService(),
            haptics: UIKitHapticsService()
        )
    }

    var settings: GameSettings { save.progress.settings }

    /// Today as a local calendar day number (a new day starts at the player's midnight).
    var today: Int { Self.currentDay() }

    /// Routes for links like sweetarrows://play/daily (from the home screen widget) and sweetarrows://prizes.
    static func route(for url: URL) -> Route? {
        guard url.scheme == "sweetarrows" else { return nil }
        switch url.host() {
        case "play":
            let name = url.pathComponents.dropFirst().first ?? GameMode.classic.rawValue
            return GameMode(rawValue: name).map(Route.play)
        case "prizes": return .prizes
        case "shop": return .shop
        default: return nil
        }
    }

    /// Opens a link: back to Home first, then the screen it points to.
    func open(_ url: URL) {
        guard let route = Self.route(for: url) else { return }
        path = [route]
    }

    static func currentDay() -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return DayNumber.from(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// First start: GDPR consent (UMP), then the ad SDK. ATT is asked later, after a few runs.
    func startConsentAndAds() async {
        await config.refresh()
        await consent.gatherConsent()
        ads.start()
        adsStarted = true
    }

    /// Set once consent is done and the ad SDK runs, so screens can show the banner right away.
    private(set) var adsStarted = false

    /// Whether a banner may show at the bottom of a screen now.
    var showsBanner: Bool { adsStarted && ads.canShowBanner }

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

    /// Turns daily reminders on (asking iOS for permission first) or off.
    func setReminders(_ on: Bool) async {
        var allowed = on
        if on { allowed = await ReminderService.requestPermission() }
        updateSettings { $0.reminders = allowed }
        planReminders()
    }

    /// Plans the next reminders from the current streak (called when the app goes to the background).
    func planReminders() {
        let progress = save.progress
        ReminderService.reschedule(enabled: progress.settings.reminders, streak: progress.streak.current(today: today))
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
