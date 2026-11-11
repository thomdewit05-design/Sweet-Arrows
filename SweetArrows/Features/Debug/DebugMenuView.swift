#if DEBUG
import SwiftUI
import SweetArrowsCore

/// Only in Debug builds: change progress, add coins and boosters, and test the ad rules.
struct DebugMenuView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.save.progress
        Form {
            Section("Progress") {
                LabeledContent("Runs played", value: "\(progress.endlessRuns)")
                LabeledContent("Best score", value: "\(progress.endlessBest)")
                Button("+5 runs (unlocks shop, daily reward, ads)") { model.save.update { $0.endlessRuns += 5 } }
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
                Button("Starter pack available again") { model.save.update { $0.starterPackBought = false } }
            }
            Section {
                let limits = model.config.values.adLimits
                LabeledContent("Interstitial from run", value: "\(limits.interstitialMinLevel)")
                LabeledContent("Interstitial every", value: "\(limits.interstitialLevelGap) runs")
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
                    model.ads.maybeShowInterstitial(afterLevel: max(progress.endlessRuns, limits.interstitialMinLevel))
                }
                Button("Privacy options form") { Task { await model.consent.presentPrivacyOptions() } }
            } header: {
                Text(verbatim: "Ads")
            } footer: {
                Text(verbatim: "Ad history resets fully after an app restart.")
            }
        }
        .navigationTitle(Text(verbatim: "Debug"))
    }
}
#endif
