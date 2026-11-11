import Observation
import SwiftUI
import SweetArrowsCore

enum Route: Hashable {
    case map
    case level(Int)
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
    let levels: LevelLibrary
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
        levels: LevelLibrary,
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
        self.levels = levels
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
        return AppModel(
            save: SaveService(url: isUITest ? nil : SaveService.defaultURL),
            levels: LevelLibrary(),
            config: LocalConfigService(),
            analytics: FirebaseAnalyticsService(),
            ads: PlaceholderAdService(),
            consent: PlaceholderConsentService(),
            purchases: PlaceholderPurchaseService(),
            gameCenter: PlaceholderGameCenterService(),
            audio: SoundEffectsService(),
            haptics: CoreHapticsService()
        )
    }

    /// In-memory app for previews and tests.
    static func preview() -> AppModel {
        AppModel(
            save: SaveService(url: nil),
            levels: LevelLibrary(),
            config: LocalConfigService(),
            analytics: FirebaseAnalyticsService(),
            ads: PlaceholderAdService(),
            consent: PlaceholderConsentService(),
            purchases: PlaceholderPurchaseService(),
            gameCenter: PlaceholderGameCenterService(),
            audio: SilentAudioService(),
            haptics: UIKitHapticsService()
        )
    }

    var settings: GameSettings { save.progress.settings }

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

    /// Level with any Remote Config override applied.
    func level(_ id: Int) -> Level? {
        guard var level = levels.level(id) else { return nil }
        if let override = config.values.levelOverrides[id] {
            if let bag = override.bagCapacity { level.bagCapacity = bag }
            if let hearts = override.hearts { level.hearts = hearts }
        }
        return level
    }
}
