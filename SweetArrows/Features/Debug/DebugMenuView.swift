#if DEBUG
import SwiftUI
import SweetArrowsCore

/// Only in Debug builds: skip levels, add coins and boosters, and test the ad rules.
struct DebugMenuView: View {
    @Environment(AppModel.self) private var model
    @State private var targetLevel = 1

    var body: some View {
        let progress = model.save.progress
        Form {
            Section("Progress") {
                LabeledContent("Completed level", value: "\(progress.completedLevel)")
                Stepper("Jump to level \(targetLevel)", value: $targetLevel, in: 1...max(model.levels.count, 1))
                Button("Unlock up to level \(targetLevel)") {
                    model.save.update { $0.completedLevel = targetLevel - 1 }
                }
                Button("Play level \(targetLevel)") { model.path.append(.level(targetLevel)) }
                Button("Reset progress", role: .destructive) {
                    model.save.update { $0 = PlayerProgress() }
                }
            }
            Section("Wallet") {
                LabeledContent("Coins", value: "\(progress.coins)")
                Button("+1,000 coins") { model.save.update { $0.coins += 1000 } }
                Button("+5 of every booster") {
                    model.save.update { progress in
                        for booster in Booster.allCases { progress.boosters.add(booster, 5) }
                    }
                }
            }
            Section("Daily") {
                Button("Daily reward available again") {
                    model.save.update { $0.dailyReward.lastClaimDay = (model.today - 1) }
                }
                Button("Forget today's daily puzzle") {
                    let today = model.today
                    model.save.update { $0.dailyPuzzle.results[today] = nil }
                }
                Button("Starter pack available again") { model.save.update { $0.starterPackBought = false } }
            }
            Section {
                let limits = model.config.values.adLimits
                LabeledContent("Interstitial from level", value: "\(limits.interstitialMinLevel)")
                LabeledContent("Interstitial every", value: "\(limits.interstitialLevelGap) levels")
                LabeledContent("Interstitial gap", value: "\(Int(limits.interstitialMinSeconds)) s")
                LabeledContent("Rewarded per day", value: "\(limits.rewardedDailyCap)")
                LabeledContent("Rewarded ready", value: model.ads.isRewardedReady ? "yes" : "no")
                LabeledContent("Banner allowed", value: model.ads.canShowBanner ? "yes" : "no")
                LabeledContent("Consent allows ads", value: model.consent.canRequestAds ? "yes" : "no")
                LabeledContent("Remove Ads / VIP", value: "\(model.purchases.hasRemovedAds) / \(model.purchases.isVIP)")
                Button("Reset ad history") { UserDefaults.standard.removeObject(forKey: "adHistory.v1") }
                Button("Show interstitial now (if allowed)") {
                    model.ads.levelFinished(won: true)
                    model.ads.levelFinished(won: true)
                    model.ads.maybeShowInterstitial(afterLevel: max(progress.completedLevel, limits.interstitialMinLevel))
                }
                Button("Privacy options form") { Task { await model.consent.presentPrivacyOptions() } }
            } header: {
                Text(verbatim: "Ads")
            } footer: {
                Text(verbatim: "Ad history resets fully after an app restart.")
            }
        }
        .navigationTitle(Text(verbatim: "Debug"))
        .onAppear { targetLevel = max(progress.nextLevel, 1) }
    }
}
#endif
