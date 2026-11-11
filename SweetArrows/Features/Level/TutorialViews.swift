import SwiftUI
import SweetArrowsCore

// MARK: - Tutorial

/// Jelly's one-line tips for the first levels. No walls of text: the hand on the board does the rest.
struct TutorialTip {
    let text: LocalizedStringKey

    init?(level: Int, tutorial: Bool) {
        guard tutorial else { return nil }
        switch level {
        case 1: text = "Tap a candy: it flies off where its arrow points!"
        case 2: text = "Something in the way? Start with the candy in front."
        case 3: text = "Three of the same in the jar go pop!"
        default: return nil
        }
    }
}

struct JellyTipView: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            JellyView(size: 46)
            Text(text)
                .font(Theme.body(16))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .shadow(color: Theme.ink.opacity(0.12), radius: 4, y: 2)
                )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown once at the start of a world: what its new element does.
struct ElementIntroCard: View {
    let element: BoardElement
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("New!")
                    .font(Theme.body(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.heart))
                JellyView(size: 64)
                Text(element.localizedName)
                    .font(Theme.title(28))
                    .foregroundStyle(Theme.ink)
                Text(element.rule)
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                Button("Got it", action: dismiss)
                    .buttonStyle(CandyButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
            .padding()
        }
    }
}

extension BoardElement {
    /// One-line rule for the intro card.
    var rule: LocalizedStringKey {
        switch self {
        case .pole: "Lollipop poles never move. Candies have to go around them."
        case .chocolateBar: "Chocolate bars are two cells long and fly as one."
        case .wrapped: "Wrapped sweets hide their color until their path is clear."
        case .caramel: "Caramel needs two taps: the first cracks it, the second sends it flying."
        case .iced: "Iced candies stay frozen until a neighbour leaves the board."
        case .rotating: "Spinners turn their arrow a quarter turn after every move."
        case .mirror: "Bumpers bend a flying candy a quarter turn. Chocolate bars can't take the bend."
        case .lock: "Locked candies open once the candy with the key has left the board."
        case .bomb: "A bomb takes its neighbours with it. They don't go into the jar."
        case .colorChanger: "Color changers switch to the next color after every move. Time your tap!"
        }
    }
}
