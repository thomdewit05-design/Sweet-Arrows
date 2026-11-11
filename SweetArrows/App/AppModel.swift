import Observation
import SwiftUI
import SweetArrowsCore

enum Route: Hashable {
    case map
    case level(Int)
    /// The daily puzzle of a given day number.
    case daily(Int)
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
            save: isUITest
                ? SaveService(url: nil)
                : SaveService(url: SaveService.defaultURL, cloud: NSUbiquitousKeyValueStore.default),
            levels: LevelLibrary(),
            config: LocalConfigService(),
            analytics: FirebaseAnalyticsService(),
            ads: PlaceholderAdService(),
            consent: PlaceholderConsentService(),
            purchases: PlaceholderPurchaseService(),
            gameCenter: isUITest ? OfflineGameCenterService() : GameKitService(),
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
            gameCenter: OfflineGameCenterService(),
            audio: SilentAudioService(),
            haptics: UIKitHapticsService()
        )
    }

    var settings: GameSettings { save.progress.settings }

    /// Today as a local calendar day number (a new day starts at the player's midnight).
    var today: Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return DayNumber.from(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    func dailyPuzzleNumber(day: Int) -> Int {
        DailyPuzzleState.puzzleNumber(day: day, poolSize: levels.dailyCount)
    }

    /// Reports the achievements the current progress has earned (cheap; Game Center ignores repeats).
    func reportAchievements() {
        let progress = save.progress
        if progress.completedLevel >= 1 { gameCenter.report(.firstWin) }
        if progress.completedLevel >= 10 { gameCenter.report(.tutorialDone) }
        for world in World.all where progress.completedLevel >= world.lastLevel {
            if let achievement = Achievement.world(world.id) { gameCenter.report(achievement) }
        }
        if progress.totalStars >= 100 { gameCenter.report(.stars100) }
        if progress.dailyPuzzle.bestStreak >= 7 { gameCenter.report(.dailyStreak7) }
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
