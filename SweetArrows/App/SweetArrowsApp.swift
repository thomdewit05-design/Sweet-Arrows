import SwiftUI

@main
struct SweetArrowsApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { model.analytics.log(.sessionStart) }
        }
    }
}

/// Navigation root: Home, with Map, Level, Shop and Settings pushed on top.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .map: MapView()
                    case .level(let id): LevelView(levelID: id)
                    case .shop: ShopView()
                    case .settings: SettingsView()
                    case .dailyReward: DailyRewardView()
                    }
                }
        }
        .tint(Theme.heart)
    }
}
