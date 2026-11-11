import SwiftUI

/// Friendly explanation shown right before the iOS tracking question (App Tracking Transparency).
struct TrackingPrimerView: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            JellyView(size: 70)
            Text("Keep Sweet Arrows free")
                .font(Theme.title(26))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Ads pay for the game. iOS will now ask if apps may track you. Allowing it shows you more relevant ads; either way you can keep playing everything.")
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button("Continue", action: next)
                .buttonStyle(CandyButtonStyle())
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
    }
}
