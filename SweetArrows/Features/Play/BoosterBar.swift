import SwiftUI
import SweetArrowsCore

/// Hint, hammer and slow-down under the board. Shows stock, the coin price or a video badge.
struct BoosterBar: View {
    let progress: PlayerProgress
    let adReady: Bool
    let enabled: Bool
    /// The booster waiting for the player to pick a candy (hammer), shown highlighted.
    var active: Booster?
    let use: (Booster) -> Void

    var body: some View {
        HStack(spacing: 14) {
            button(.hint, icon: "lightbulb.fill", label: "Hint")
            button(.hammer, icon: "hammer.fill", label: "Hammer")
            button(.slowDown, icon: "tortoise.fill", label: "Slow down")
        }
        .frame(maxWidth: .infinity)
    }

    private func button(_ booster: Booster, icon: String, label: LocalizedStringKey) -> some View {
        let stock = progress.boosters[booster]
        let affordable = progress.canAfford(booster)
        let usable = enabled && (affordable || adReady)
        return Button {
            use(booster)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .symbolEffect(.bounce, value: stock)
                    .symbolEffect(.pulse, isActive: active == booster)
                    .frame(width: 52, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(active == booster ? Theme.gold : .white)
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
        .buttonStyle(SquishButtonStyle())
        .disabled(!usable)
        .opacity(usable ? 1 : 0.45)
        .accessibilityLabel(Text(label))
    }
}
