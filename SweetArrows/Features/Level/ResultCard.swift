import SwiftUI
import SweetArrowsCore

// MARK: - Result card

struct ResultCard: View {
    let session: GameSession
    let coins: Int
    let totalCoins: Int
    let audio: AudioService
    let adReady: Bool
    let canAffordSlot: Bool
    let slotsInStock: Int
    let hasNext: Bool
    /// Daily puzzle result to share, Wordle-style.
    let shareText: String?
    let onNext: () -> Void
    let onRetry: () -> Void
    let onUndo: () -> Void
    let onExtraSlot: () -> Void
    let onExtraSlotAd: () -> Void
    let onExtraHearts: () -> Void
    let onExtraTime: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 18) {
                switch session.status {
                case .won: won
                case .lost(.bagFull): bagFull
                case .lost(.outOfHearts): outOfHearts
                case .lost(.outOfTime): outOfTime
                case .playing, .lost(.boardFull): EmptyView()
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
            .padding()
        }
        .accessibilityIdentifier("resultCard")
    }

    @State private var shownStars = 0
    @State private var shownCoins = 0
    @State private var flyingCoins = false

    @ViewBuilder private var won: some View {
        JellyView(size: 70)
        Text("Sweet!")
            .font(Theme.title())
            .foregroundStyle(Theme.ink)
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(index < shownStars ? Theme.gold : Theme.inkSoft.opacity(0.25))
                    .scaleEffect(index < shownStars ? 1 : 0.6)
                    .rotationEffect(.degrees(index < shownStars ? 0 : -30))
                    .animation(.spring(response: 0.35, dampingFraction: 0.45), value: shownStars)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(session.stars) stars"))
        ZStack {
            CoinBadge(coins: totalCoins - coins + shownCoins)
            // Coins fly up from the stars into the counter.
            ForEach(0..<min(coins, 8), id: \.self) { index in
                Circle()
                    .fill(Theme.gold)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .frame(width: 18, height: 18)
                    .offset(x: CGFloat(index - 4) * 9, y: flyingCoins ? 0 : -60)
                    .opacity(flyingCoins ? 0 : 1)
                    .animation(.easeIn(duration: 0.45).delay(Double(index) * 0.06), value: flyingCoins)
                    .accessibilityHidden(true)
            }
            .opacity(shownStars >= session.stars && coins > 0 ? 1 : 0)
        }
        .task { await celebrate() }
        if hasNext {
            Button("Next level", action: onNext)
                .buttonStyle(CandyButtonStyle())
                .accessibilityIdentifier("nextLevelButton")
        }
        if let shareText {
            ShareLink(item: shareText) {
                Label("Share result", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x5B6CFF)))
        }
        Button("Home", action: onHome)
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
    }

    /// Stars land one by one, then the coins count up.
    private func celebrate() async {
        guard session.status == .won, shownStars == 0 else { return }
        for star in 1...max(session.stars, 1) {
            try? await Task.sleep(for: .milliseconds(320))
            shownStars = star
            audio.play(.star)
        }
        guard coins > 0 else { return }
        try? await Task.sleep(for: .milliseconds(200))
        flyingCoins = true
        let steps = min(coins, 10)
        for step in 1...steps {
            try? await Task.sleep(for: .milliseconds(60))
            shownCoins = coins * step / steps
            if step.isMultiple(of: 2) { audio.play(.coin) }
        }
    }

    @ViewBuilder private var bagFull: some View {
        Text("The jar is full!")
            .font(Theme.title(28))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
        Text("Get one more slot and keep going.")
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        if canAffordSlot {
            Button(action: onExtraSlot) {
                if slotsInStock > 0 {
                    Label("Extra slot (\(slotsInStock))", systemImage: "plus.circle.fill")
                } else {
                    Label("Extra slot · \(Booster.extraSlot.price)", systemImage: "circle.fill")
                }
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
        }
        if adReady {
            Button(action: onExtraSlotAd) {
                Label("Extra slot", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0xFF9F1C)))
        }
        if session.canUndo {
            Button(action: onUndo) {
                Label("Undo last move", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x5B6CFF)))
        }
        Button("Try again", action: onRetry)
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
    }

    @ViewBuilder private var outOfTime: some View {
        Image(systemName: "timer")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(Theme.heart)
        Text("Time's up!")
            .font(Theme.title(28))
            .foregroundStyle(Theme.ink)
        Text("So close. Want 15 more seconds?")
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        if adReady {
            Button(action: onExtraTime) {
                Label("+15 seconds", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
            .accessibilityIdentifier("extraTimeButton")
        }
        Button("Try again", action: onRetry)
            .buttonStyle(CandyButtonStyle())
    }

    @ViewBuilder private var outOfHearts: some View {
        Text("Out of hearts")
            .font(Theme.title(28))
            .foregroundStyle(Theme.ink)
        Text("Bounced too often. Want three more hearts?")
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        if adReady {
            Button(action: onExtraHearts) {
                Label("3 hearts", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
        }
        Button("Try again", action: onRetry)
            .buttonStyle(CandyButtonStyle())
    }
}
