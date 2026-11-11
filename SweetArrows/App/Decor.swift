import SwiftUI
import SweetArrowsCore

/// Bright candy-sky background with slowly floating sweets, shared by the menus.
struct CandySkyBackground: View {
    var colors: [Color] = [Color(hex: 0x7FD8FF), Color(hex: 0xB9A4FF), Color(hex: 0xFFB3D1)]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fixed layout so the sky looks the same every time.
    private static let sweets: [(x: CGFloat, y: CGFloat, size: CGFloat, color: UInt32, shape: Int, speed: Double)] = [
        (0.08, 0.12, 34, 0xFFD23F, 1, 9), (0.86, 0.08, 26, 0x3DDC97, 0, 11), (0.18, 0.42, 22, 0x5B6CFF, 2, 13),
        (0.92, 0.36, 30, 0xFF9F1C, 0, 10), (0.06, 0.72, 28, 0xA259FF, 2, 12), (0.82, 0.66, 24, 0xFFD23F, 1, 8),
        (0.5, 0.04, 18, 0xFF5C8A, 0, 14), (0.32, 0.9, 26, 0x3DDC97, 1, 10), (0.7, 0.92, 20, 0x5B6CFF, 2, 12),
        (0.95, 0.88, 18, 0xFF5C8A, 0, 9),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [.white.opacity(0.45), .clear], center: .init(x: 0.5, y: 0.3),
                               startRadius: 10, endRadius: proxy.size.width * 0.8)
                ForEach(Array(Self.sweets.enumerated()), id: \.offset) { _, sweet in
                    FloatingSweet(size: sweet.size, color: Color(hex: sweet.color), shape: sweet.shape,
                                  speed: sweet.speed, still: reduceMotion)
                        .position(x: proxy.size.width * sweet.x, y: proxy.size.height * sweet.y)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct FloatingSweet: View {
    let size: CGFloat
    let color: Color
    let shape: Int
    let speed: Double
    let still: Bool
    @State private var up = false

    var body: some View {
        Group {
            switch shape {
            case 1: StarShape().fill(color)
            case 2: RoundedRectangle(cornerRadius: size * 0.2).fill(color).rotationEffect(.degrees(45))
                    .scaleEffect(0.75)
            default: Circle().fill(color)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().fill(.white.opacity(0.55)).frame(width: size * 0.25).offset(x: -size * 0.14, y: -size * 0.16))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .opacity(0.85)
        .offset(y: up ? -14 : 14)
        .rotationEffect(.degrees(up ? 8 : -8))
        .animation(still ? nil : .easeInOut(duration: speed / 3).repeatForever(autoreverses: true), value: up)
        .onAppear { up = true }
    }
}

/// White rounded card with a soft shadow, used for panels on the candy sky.
struct CandyCard: ViewModifier {
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white.opacity(0.92))
                    .shadow(color: Theme.ink.opacity(0.12), radius: 8, y: 4)
            )
    }
}

extension View {
    func candyCard(padding: CGFloat = 14) -> some View { modifier(CandyCard(padding: padding)) }
}
