import Foundation

/// Values that can be changed from Firebase Remote Config without an app update.
/// The defaults below are used offline and until Remote Config is wired up (phase 7).
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
}

@MainActor
protocol ConfigService: AnyObject {
    var values: RemoteValues { get }
    func refresh() async
}

/// Local defaults only.
@MainActor
final class LocalConfigService: ConfigService {
    private(set) var values = RemoteValues()
    func refresh() async {}
}
