import SwiftUI
import SweetArrowsCore
import UIKit

/// Colors and fonts of the candy shop. All UI colors come from here.
enum Theme {
    static let cream = Color(hex: 0xFFF4E6)
    static let counter = Color(hex: 0xE9B98A)        // wooden counter
    static let counterEdge = Color(hex: 0xC98F5E)
    static let ink = Color(hex: 0x4A2C2A)            // chocolate brown text
    static let inkSoft = Color(hex: 0x8A6A5C)
    static let jar = Color(hex: 0xDDF3FF)
    static let heart = Color(hex: 0xFF5C8A)
    static let gold = Color(hex: 0xFFC233)

    static func color(_ candy: CandyColor) -> Color { Color(hex: candy.hex) }

    // MARK: Fonts (Fredoka, scales with Dynamic Type)

    static func title(_ size: CGFloat = 34) -> Font {
        .custom("Fredoka-Bold", size: size, relativeTo: .largeTitle)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .custom("Fredoka-SemiBold", size: size, relativeTo: .title2)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .custom("Fredoka-Medium", size: size, relativeTo: .body)
    }

    /// Fixed-size font for SpriteKit labels.
    static let spriteFontName = "Fredoka-Bold"
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Color {
    /// Blends towards `other` by `amount` (0...1); works on iOS 17.
    func mixed(with other: Color, amount: CGFloat) -> Color {
        Color(uiColor: UIColor(self).mixed(with: UIColor(other), amount: amount))
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static func candy(_ color: CandyColor) -> UIColor { UIColor(hex: color.hex) }
}

/// Big, squishy candy button used across menus.
struct CandyButtonStyle: ButtonStyle {
    var color: Color = Theme.heart
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading())
            .foregroundStyle(foreground)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                ZStack {
                    // A darker "side" under the button gives it a squishy 3D look.
                    Capsule()
                        .fill(color.mixed(with: .black, amount: 0.22))
                        .offset(y: configuration.isPressed ? 1 : 5)
                    Capsule()
                        .fill(LinearGradient(colors: [color.mixed(with: .white, amount: 0.18), color],
                                             startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(.white.opacity(0.35))
                        .frame(height: 10)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            )
            .shadow(color: color.opacity(0.35), radius: 6, y: 4)
            .offset(y: configuration.isPressed ? 4 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Round icon button (back, undo, settings).
struct RoundIconButton: View {
    let systemName: String
    let label: LocalizedStringKey
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 48, height: 48)
                .background(Circle().fill(.white).shadow(color: Theme.ink.opacity(0.15), radius: 4, y: 2))
        }
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }
}
