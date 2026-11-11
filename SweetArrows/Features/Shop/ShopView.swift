import SwiftUI

/// The shop arrives in phase 5 (coins, cosmetics) and phase 7 (Remove Ads, VIP, coin packs).
struct ShopView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            CoinBadge(coins: model.save.progress.coins)
            JellyView(size: 90)
            Text("The candy shop opens soon")
                .font(Theme.heading())
                .foregroundStyle(Theme.ink)
            Text("Spend your coins on hints, undos and new candy styles.")
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle(Text("Shop"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ShopView() }
        .environment(AppModel.preview())
}
