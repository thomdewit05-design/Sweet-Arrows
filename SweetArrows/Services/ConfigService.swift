import Foundation
import SweetArrowsCore
#if canImport(FirebaseRemoteConfig)
import FirebaseCore
import FirebaseRemoteConfig
#endif

/// Values that can be changed from Firebase Remote Config without an app update.
/// The defaults below are used offline and when Firebase is not configured.
struct RemoteValues: Equatable, Sendable {
    var interstitialMinLevel = 8
    var interstitialLevelGap = 2
    var interstitialMinSeconds = 90
    var rewardedDailyCap = 20
    var bannerEnabled = true
    var appOpenEnabled = false
    var starterPackLevel = 15
    /// Per-level overrides, e.g. a bigger jar for a level with too many quitters.
    var levelOverrides: [Int: LevelOverride] = [:]

    struct LevelOverride: Equatable, Sendable, Codable {
        var bagCapacity: Int?
        var hearts: Int?
    }

    /// The ad rules as `AdPolicy` uses them.
    var adLimits: AdLimits {
        var limits = AdLimits()
        limits.interstitialMinLevel = interstitialMinLevel
        limits.interstitialLevelGap = interstitialLevelGap
        limits.interstitialMinSeconds = TimeInterval(interstitialMinSeconds)
        limits.rewardedDailyCap = rewardedDailyCap
        limits.bannerEnabled = bannerEnabled
        limits.appOpenEnabled = appOpenEnabled
        return limits
    }

    /// Remote Config keys, exactly as named in docs/PLAN.md.
    enum Key: String, CaseIterable {
        case interstitialMinLevel = "interstitial_min_level"
        case interstitialLevelGap = "interstitial_level_gap"
        case interstitialMinSeconds = "interstitial_min_seconds"
        case rewardedDailyCap = "rewarded_daily_cap"
        case bannerEnabled = "banner_enabled"
        case appOpenEnabled = "app_open_enabled"
        case starterPackLevel = "starter_pack_level"
        case levelOverrides = "level_overrides"
    }

    /// Defaults as Remote Config wants them.
    var asDefaults: [String: NSObject] {
        [
            Key.interstitialMinLevel.rawValue: NSNumber(value: interstitialMinLevel),
            Key.interstitialLevelGap.rawValue: NSNumber(value: interstitialLevelGap),
            Key.interstitialMinSeconds.rawValue: NSNumber(value: interstitialMinSeconds),
            Key.rewardedDailyCap.rawValue: NSNumber(value: rewardedDailyCap),
            Key.bannerEnabled.rawValue: NSNumber(value: bannerEnabled),
            Key.appOpenEnabled.rawValue: NSNumber(value: appOpenEnabled),
            Key.starterPackLevel.rawValue: NSNumber(value: starterPackLevel),
            Key.levelOverrides.rawValue: "{}" as NSString,
        ]
    }

    /// Parses `level_overrides`, e.g. {"23": {"bagCapacity": 6}, "41": {"hearts": 4}}.
    static func parseOverrides(_ json: String) -> [Int: LevelOverride] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: LevelOverride].self, from: data)
        else { return [:] }
        var result: [Int: LevelOverride] = [:]
        for (key, value) in raw {
            if let level = Int(key) { result[level] = value }
        }
        return result
    }
}

@MainActor
protocol ConfigService: AnyObject {
    var values: RemoteValues { get }
    /// Called whenever new values were activated.
    var onChange: ((RemoteValues) -> Void)? { get set }
    func refresh() async
}

/// Local defaults only.
@MainActor
final class LocalConfigService: ConfigService {
    private(set) var values = RemoteValues()
    var onChange: ((RemoteValues) -> Void)?
    func refresh() async {}
}

/// Firebase Remote Config (A/B tests run on these same keys from the Firebase console).
/// Falls back to the local defaults when there is no GoogleService-Info.plist or no network.
@MainActor
final class FirebaseConfigService: ConfigService {
    private(set) var values = RemoteValues()
    var onChange: ((RemoteValues) -> Void)?

    func refresh() async {
        #if canImport(FirebaseRemoteConfig)
        guard FirebaseApp.app() != nil else { return }
        let config = RemoteConfig.remoteConfig()
        config.setDefaults(RemoteValues().asDefaults)
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            config.fetchAndActivate { _, _ in done.resume() }
        }
        apply(config)
        #endif
    }

    #if canImport(FirebaseRemoteConfig)
    private func apply(_ config: RemoteConfig) {
        func int(_ key: RemoteValues.Key) -> Int { config.configValue(forKey: key.rawValue).numberValue.intValue }
        func bool(_ key: RemoteValues.Key) -> Bool { config.configValue(forKey: key.rawValue).boolValue }
        var next = RemoteValues()
        next.interstitialMinLevel = int(.interstitialMinLevel)
        next.interstitialLevelGap = int(.interstitialLevelGap)
        next.interstitialMinSeconds = int(.interstitialMinSeconds)
        next.rewardedDailyCap = int(.rewardedDailyCap)
        next.bannerEnabled = bool(.bannerEnabled)
        next.appOpenEnabled = bool(.appOpenEnabled)
        next.starterPackLevel = int(.starterPackLevel)
        let overrides: String? = config.configValue(forKey: RemoteValues.Key.levelOverrides.rawValue).stringValue
        next.levelOverrides = RemoteValues.parseOverrides(overrides ?? "{}")
        values = next
        onChange?(next)
    }
    #endif
}
