import SwiftUI
import SweetArrowsCore

/// Daily reward with a 7-day row. Missing a day starts the row again.
struct DailyRewardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var claimed: Reward?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        let state = model.save.progress.dailyReward
        let today = model.today
        let step = state.claimableStep(today: today)
        let highlighted = step ?? state.lastClaimedStep
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                JellyView(size: 56)
                VStack(alignment: .leading) {
                    Text("Daily reward")
                        .font(Theme.title(28))
                        .foregroundStyle(Theme.ink)
                    Text("Come back every day for sweeter rewards.")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...7, id: \.self) { day in
                    RewardTile(
                        day: day, reward: DailyRewardState.rewards[day - 1],
                        isToday: day == highlighted,
                        isDone: day < highlighted || (step == nil && day == highlighted)
                    )
                }
            }
            if let claimed {
                Text("+\(claimed.coins) coins").font(Theme.heading()).foregroundStyle(Theme.ink)
                    .opacity(claimed.coins > 0 ? 1 : 0)
                Button("Close") { dismiss() }
                    .buttonStyle(CandyButtonStyle())
            } else if step != nil {
                Button("Claim") { claim(double: false) }
                    .buttonStyle(CandyButtonStyle())
                    .accessibilityIdentifier("claimDailyReward")
                if model.ads.isRewardedReady {
                    Button {
                        Task { @MainActor in
                            if await model.ads.showRewarded(reason: .dailyRewardDouble) { claim(double: true) }
                        }
                    } label: {
                        Label("Double it", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(CandyButtonStyle(color: Color(hex: 0xFF9F1C)))
                }
            } else {
                Text("Come back tomorrow!")
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
    }

    private func claim(double: Bool) {
        let today = model.today
        var granted: Reward?
        model.save.update { progress in
            guard let claim = progress.dailyReward.claim(today: today) else { return }
            let final = double ? claim.reward.doubled() : claim.reward
            progress.apply(final)
            granted = final
        }
        guard let granted else { return }
        claimed = granted
        model.audio.play(.coin)
        model.haptics.success()
        model.analytics.log(.dailyRewardClaimed(day: model.save.progress.dailyReward.lastClaimedStep, doubled: double))
    }
}

private struct RewardTile: View {
    let day: Int
    let reward: Reward
    let isToday: Bool
    let isDone: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("Day \(day)")
                .font(Theme.body(12))
                .foregroundStyle(isToday ? .white : Theme.inkSoft)
            if reward.coins > 0 {
                Label("\(reward.coins)", systemImage: "circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(Theme.heading(15))
                    .foregroundStyle(isToday ? .white : Theme.ink)
            }
            ForEach(Array(reward.boosters.keys).sorted { $0.rawValue < $1.rawValue }, id: \.self) { booster in
                Image(systemName: booster.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isToday ? .white : Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(RoundedRectangle(cornerRadius: 16).fill(isToday ? Theme.heart : .white))
        .overlay(alignment: .topTrailing) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: 0x3DDC97))
                    .background(Circle().fill(.white))
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension Booster {
    var icon: String {
        switch self {
        case .hint: "lightbulb.fill"
        case .hammer: "hammer.fill"
        case .slowDown: "tortoise.fill"
        }
    }

    var localizedName: LocalizedStringKey {
        switch self {
        case .hint: "Hint"
        case .hammer: "Hammer"
        case .slowDown: "Slow down"
        }
    }
}
