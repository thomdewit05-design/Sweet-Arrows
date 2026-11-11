import SwiftUI

/// Daily reward with a 7-day streak. Shown from level 5 onwards; built in phase 5.
struct DailyRewardView: View {
    var body: some View {
        VStack(spacing: 16) {
            JellyView(size: 90)
            Text("Daily reward")
                .font(Theme.heading())
                .foregroundStyle(Theme.ink)
            Text("Come back every day for sweeter rewards.")
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
    }
}
