import SwiftUI
import SweetArrowsCore

// MARK: - HUD

struct LevelHUD: View {
    let title: LocalizedStringKey
    let session: GameSession
    let back: () -> Void
    let undo: () -> Void

    var body: some View {
        HStack {
            RoundIconButton(systemName: "chevron.left", label: "Back", action: back)
                .accessibilityIdentifier("backButton")
            Spacer()
            VStack(spacing: 2) {
                Text(title)
                    .font(Theme.heading())
                    .foregroundStyle(Theme.ink)
                if let seconds = session.secondsLeft {
                    ClockView(seconds: seconds, running: session.clockStarted)
                }
                if session.level.hard {
                    Text("Hard level")
                        .font(Theme.body(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.heart))
                }
            }
            Spacer()
            HeartsView(hearts: session.hearts, total: session.level.hearts, tutorial: session.level.tutorial)
            // Undo is always free.
            RoundIconButton(systemName: "arrow.uturn.backward", label: "Undo", enabled: session.canUndo, action: undo)
                .accessibilityIdentifier("undoButton")
        }
        .padding(.top, 4)
    }
}

/// Hint, remove-candy and extra-slot boosters, paid from stock, with coins or with a rewarded ad.
struct BoosterBar: View {
    let progress: PlayerProgress
    let adReady: Bool
    let enabled: Bool
    let canAddSlot: Bool
    let use: (Booster) -> Void

    var body: some View {
        HStack(spacing: 14) {
            button(.hint, icon: "lightbulb.fill", label: "Hint")
            button(.removeCandy, icon: "hand.tap.fill", label: "Remove")
            button(.extraSlot, icon: "plus.square.fill", label: "Extra slot", available: canAddSlot)
        }
        .frame(maxWidth: .infinity)
    }

    private func button(_ booster: Booster, icon: String, label: LocalizedStringKey, available: Bool = true) -> some View {
        let stock = progress.boosters[booster]
        let affordable = progress.canAfford(booster)
        let usable = enabled && available && (affordable || adReady)
        return Button {
            use(booster)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 52, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white)
                            .shadow(color: Theme.ink.opacity(0.12), radius: 3, y: 2)
                    )
                    .overlay(alignment: .topTrailing) {
                        Group {
                            if stock > 0 {
                                Text("\(stock)")
                                    .padding(.horizontal, 6)
                                    .background(Capsule().fill(Theme.heart))
                            } else if affordable {
                                Text("\(booster.price)")
                                    .padding(.horizontal, 5)
                                    .background(Capsule().fill(Theme.gold))
                            } else if adReady {
                                Image(systemName: "play.fill")
                                    .padding(4)
                                    .background(Circle().fill(Color(hex: 0xFF9F1C)))
                            }
                        }
                        .font(Theme.body(11))
                        .foregroundStyle(.white)
                        .offset(x: 8, y: -6)
                    }
                Text(label)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .disabled(!usable)
        .opacity(usable ? 1 : 0.45)
        .accessibilityLabel(Text(label))
    }
}

private struct HeartsView: View {
    let hearts: Int
    let total: Int
    let tutorial: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<max(total, hearts), id: \.self) { index in
                Image(systemName: index < hearts ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.heart)
                    .scaleEffect(index < hearts ? 1 : 0.85)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hearts)
            }
        }
        .frame(minWidth: 48, alignment: .trailing)
        .opacity(tutorial ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(hearts) hearts left"))
        .accessibilityIdentifier("hearts")
    }
}

/// The level clock. Calm until the last ten seconds, then red and pulsing.
struct ClockView: View {
    let seconds: Int
    let running: Bool

    private var urgent: Bool { running && seconds <= 10 }

    var body: some View {
        Label {
            Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60))
                .monospacedDigit()
        } icon: {
            Image(systemName: "timer")
        }
        .font(Theme.heading(17))
        .foregroundStyle(urgent ? .white : Theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(urgent ? Theme.heart : Color.white.opacity(running ? 1 : 0.6)))
        .scaleEffect(urgent && seconds % 2 == 0 ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: seconds)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(seconds) seconds left"))
        .accessibilityIdentifier("clock")
    }
}
