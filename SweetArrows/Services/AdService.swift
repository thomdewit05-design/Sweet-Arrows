import Foundation

/// Why the player watches a rewarded ad. Logged with every ad.
enum RewardReason: String, Sendable {
    case extraSlot = "extra_slot"
    case undo
    case removeCandy = "remove_candy"
    case hint
    case doubleCoins = "double_coins"
    case extraHearts = "extra_hearts"
    case dailyRewardDouble = "daily_reward_double"
}

/// All ad logic lives behind this protocol. The game only ever calls
/// `showRewarded(reason:)` and `maybeShowInterstitial(afterLevel:)`.
/// The Google Mobile Ads implementation (with frequency caps from ConfigService) comes in phase 6.
@MainActor
protocol AdService: AnyObject {
    var isRewardedReady: Bool { get }
    /// Shows a rewarded ad. Returns true when the reward was earned.
    func showRewarded(reason: RewardReason) async -> Bool
    func maybeShowInterstitial(afterLevel level: Int)
}

/// Placeholder until phase 6. In Debug builds rewards are granted straight away
/// so the continue/booster flows can be tested; Release builds offer no ads yet.
@MainActor
final class PlaceholderAdService: AdService {
    var isRewardedReady: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    func showRewarded(reason: RewardReason) async -> Bool {
        #if DEBUG
        print("🎬 [debug] rewarded ad skipped, reward granted: \(reason.rawValue)")
        return true
        #else
        return false
        #endif
    }

    func maybeShowInterstitial(afterLevel level: Int) {}
}
