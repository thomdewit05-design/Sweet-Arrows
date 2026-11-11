import SwiftUI
import SweetArrowsCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showDailyReward = false
    @State private var showTrackingPrimer = false

    var body: some View {
        let progress = model.save.progress
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    CoinBadge(coins: progress.coins)
                    Spacer()
                    RoundIconButton(systemName: "gearshape.fill", label: "Settings") {
                        model.path.append(.settings)
                    }
                }
                .padding(.horizontal)

                Spacer()
                JellyView(size: 120)
                VStack(spacing: 4) {
                    Text(verbatim: "Sweet Arrows")
                        .font(Theme.title(44))
                        .foregroundStyle(Theme.ink)
                    Text("Tap, slide, pop the sweets")
                        .font(Theme.body())
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()

                Button {
                    model.path.append(.endless)
                } label: {
                    VStack(spacing: 2) {
                        Text("Play")
                        if progress.endlessBest > 0 {
                            Text("Best \(progress.endlessBest)")
                                .font(Theme.body(15))
                                .opacity(0.9)
                        }
                    }
                    .frame(maxWidth: 240)
                }
                .buttonStyle(CandyButtonStyle())
                .accessibilityIdentifier("playButton")

                if progress.showsMetaFeatures {
                    Button("Shop") { model.path.append(.shop) }
                        .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
                        .accessibilityIdentifier("shopButton")
                }
                Spacer().frame(height: 24)
            }
            .padding(.vertical)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showDailyReward) {
            DailyRewardView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTrackingPrimer) {
            TrackingPrimerView {
                showTrackingPrimer = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    await model.consent.requestTracking()
                }
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .onAppear {
            let progress = model.save.progress
            // App Tracking Transparency: only after a few runs, with our own explanation first.
            if progress.endlessRuns >= 2, model.consent.needsTrackingPrompt {
                showTrackingPrimer = true
            // Daily reward pops up once a day, after the first runs (never at the very first start).
            } else if progress.showsMetaFeatures, progress.dailyReward.claimableStep(today: model.today) != nil {
                showDailyReward = true
            }
        }
    }
}

struct CoinBadge: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.gold)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 2))
            Text("\(coins)")
                .font(Theme.heading(18))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white).shadow(color: Theme.ink.opacity(0.12), radius: 4, y: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(coins) coins"))
    }
}

/// The mascot from the app icon: a smiling lemon star candy that gently squishes.
struct JellyView: View {
    var size: CGFloat = 100
    @State private var squish = false

    var body: some View {
        ZStack {
            StarShape()
                .fill(.white)
                .frame(width: size * 1.12, height: size * 1.12)
            StarShape()
                .fill(LinearGradient(
                    colors: [Color(hex: 0xFFE27A), Color(hex: 0xF2C230)], startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size, height: size)
            Ellipse()
                .fill(.white.opacity(0.55))
                .frame(width: size * 0.2, height: size * 0.09)
                .offset(x: -size * 0.04, y: -size * 0.2)
            HStack(spacing: size * 0.09) {
                eye
                eye
            }
            .offset(y: size * 0.02)
            HStack(spacing: size * 0.32) {
                cheek
                cheek
            }
            .offset(y: size * 0.11)
            Capsule()
                .fill(Color(hex: 0x6E1E32))
                .frame(width: size * 0.13, height: size * 0.05)
                .offset(y: size * 0.15)
        }
        .scaleEffect(x: squish ? 1.05 : 1, y: squish ? 0.95 : 1, anchor: .bottom)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: squish)
        .onAppear { squish = true }
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Ellipse()
            .fill(.white)
            .frame(width: size * 0.12, height: size * 0.15)
            .overlay(
                Ellipse()
                    .fill(Theme.ink)
                    .frame(width: size * 0.08, height: size * 0.1)
                    .offset(x: size * 0.006, y: size * 0.012)
            )
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(hex: 0xFF96AF))
            .frame(width: size * 0.09, height: size * 0.045)
    }
}

/// Five-point star with softly rounded tips.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.5
        var points: [CGPoint] = []
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = Double(i) * .pi / 5 - .pi / 2
            points.append(CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
        }
        var path = Path()
        let corner = outer * 0.12
        for i in points.indices {
            let previous = points[(i + points.count - 1) % points.count]
            let current = points[i]
            let next = points[(i + 1) % points.count]
            let start = Self.point(from: current, toward: previous, distance: corner)
            let end = Self.point(from: current, toward: next, distance: corner)
            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }

    private static func point(from a: CGPoint, toward b: CGPoint, distance: CGFloat) -> CGPoint {
        let length = max(hypot(b.x - a.x, b.y - a.y), 0.001)
        return CGPoint(x: a.x + (b.x - a.x) / length * distance, y: a.y + (b.y - a.y) / length * distance)
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(AppModel.preview())
}
