import SwiftUI

// Small, reusable menu animations. All of them stay still when Reduce Motion is on.

/// Pops a view in (from a little lower, smaller and transparent) when it appears, after `delay`.
struct PopIn: ViewModifier {
    var delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            .offset(y: shown || reduceMotion ? 0 : 24)
            .onAppear {
                guard !shown else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) { shown = true }
            }
    }
}

/// A band of light that sweeps across a capsule-shaped view every few seconds (for the big buttons).
struct ShineSweep: ViewModifier {
    var every: Double = 3.2
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.35)
                            .rotationEffect(.degrees(20))
                            .offset(x: phase * proxy.size.width * 1.4)
                    }
                    .mask(Capsule())
                    .allowsHitTesting(false)
                }
            }
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    phase = -1
                    withAnimation(.easeInOut(duration: 0.9)) { phase = 1 }
                    try? await Task.sleep(for: .seconds(every))
                }
            }
    }
}

extension View {
    func popIn(delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
    func shineSweep(every: Double = 3.2) -> some View { modifier(ShineSweep(every: every)) }
}

/// A number that rolls to its value; with `countUp` it counts up from zero when it first appears.
struct RollingNumber: View {
    let value: Int
    var countUp = false
    var duration: Double = 0.9
    @State private var shown = 0
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(shown)")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                guard !started else { return }
                started = true
                guard countUp, !reduceMotion, value > 0 else {
                    shown = value
                    return
                }
                Task { @MainActor in
                    let steps = 24
                    for step in 1...steps {
                        try? await Task.sleep(for: .seconds(duration / Double(steps)))
                        withAnimation(.snappy(duration: 0.08)) { shown = value * step / steps }
                    }
                    shown = value
                }
            }
            .onChange(of: value) { _, new in
                withAnimation(.spring(response: 0.35)) { shown = new }
            }
            .accessibilityLabel(Text("\(value)"))
    }
}

/// A one-off burst of candy-colored confetti (for claimed rewards and level-ups).
struct ConfettiBurst: View {
    var pieces = 26
    @State private var fired = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let colors: [Color] = [
        Color(hex: 0xFF5C8A), Color(hex: 0xFFD23F), Color(hex: 0x3DDC97), Color(hex: 0x5B6CFF), Color(hex: 0xA259FF),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<(reduceMotion ? 0 : pieces), id: \.self) { index in
                let angle = Double(index) / Double(pieces) * 2 * .pi
                let distance = CGFloat(70 + (index * 37) % 60)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.colors[index % Self.colors.count])
                    .frame(width: 7, height: 11)
                    .rotationEffect(.degrees(fired ? Double(index * 47) : 0))
                    .offset(x: fired ? cos(angle) * distance : 0, y: fired ? sin(angle) * distance + 30 : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { fired = true }
        }
    }
}

/// Plain button that squishes a little when pressed (cards, tiles).
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
