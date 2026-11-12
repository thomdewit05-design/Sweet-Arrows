import SwiftUI

@main
struct SweetArrowsApp: App {
    @State private var model = AppModel.live()
    @State private var backgroundedAt: Date?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    model.analytics.log(.sessionStart)
                    model.gameCenter.authenticate()
                    await model.startConsentAndAds()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        backgroundedAt = Date()
                        model.planReminders()
                    case .active:
                        if let away = backgroundedAt { model.ads.maybeShowAppOpen(awaySince: away) }
                        backgroundedAt = nil
                    default:
                        break
                    }
                }
        }
    }
}

/// Navigation root: Home, with the game, Shop and Settings pushed on top.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .play(let mode): EndlessView(mode: mode)
                    case .shop: ShopView()
                    case .prizes: PrizesView()
                    case .settings: SettingsView()
                    case .dailyReward: DailyRewardView()
                    }
                }
        }
        .tint(Theme.heart)
    }
}
