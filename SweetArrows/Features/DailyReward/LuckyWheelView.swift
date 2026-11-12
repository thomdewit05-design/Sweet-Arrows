import SwiftUI
import SweetArrowsCore

/// The lucky wheel: a free spin a day, two more with an ad. The wheel spins a few turns, slows down
/// with ticking haptics and lands on the prize the rules picked.
struct LuckyWheelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var won: Int?

    private static let colors: [UInt32] = [0xFF5C8A, 0xFFD23F, 0x3DDC97, 0x5B6CFF, 0xFF9F1C, 0xA259FF, 0x7FD8FF, 0xFFC233]

    var body: some View {
        let wheel = model.save.progress.wheel
        let today = model.today
        VStack(spacing: 18) {
            Text("Lucky wheel")
                .font(Theme.title(30))
                .foregroundStyle(Theme.ink)
            ZStack(alignment: .top) {
                wheelFace
                    .rotationEffect(.degrees(rotation))
                    .frame(width: 280, height: 280)
                pointer
                    .offset(y: -10)
            }
            .frame(height: 300)

            if let won {
                prizeText(LuckyWheel.segments[won])
                    .popIn()
                    .overlay { if LuckyWheel.segments[won].isJackpot { ConfettiBurst(pieces: 36) } }
            }

            if wheel.hasFreeSpin(today: today) {
                Button {
                    spin(viaAd: false)
                } label: {
                    Label("Spin for free", systemImage: "sparkles")
                }
                .buttonStyle(CandyButtonStyle())
                .shineSweep(every: 2.4)
                .disabled(spinning)
                .accessibilityIdentifier("freeSpinButton")
            } else if wheel.adSpinsLeft(today: today) > 0, model.ads.isRewardedReady {
                Button {
                    Task { @MainActor in
                        guard await model.ads.showRewarded(reason: .wheel) else { return }
                        spin(viaAd: true)
                    }
                } label: {
                    Label("Spin again (\(wheel.adSpinsLeft(today: today)))", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(CandyButtonStyle(color: Color(hex: 0xFF9F1C)))
                .disabled(spinning)
            } else {
                Text("Come back tomorrow!")
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
            }
            Button("Close") { dismiss() }
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
                .disabled(spinning)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
    }

    private var wheelFace: some View {
        let count = LuckyWheel.segments.count
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                WheelSlice(index: index, count: count)
                    .fill(Color(hex: Self.colors[index % Self.colors.count]))
                WheelSlice(index: index, count: count)
                    .stroke(.white, lineWidth: 3)
                prizeIcon(LuckyWheel.segments[index])
                    .rotationEffect(.degrees(Double(index) * 360 / Double(count)))
            }
            Circle().stroke(Color(hex: 0xFFC233), lineWidth: 10)
            Circle().fill(.white).frame(width: 54, height: 54)
                .overlay(Image(systemName: "star.fill").foregroundStyle(Theme.gold).font(.system(size: 24)))
                .shadow(color: Theme.ink.opacity(0.2), radius: 4, y: 2)
        }
        .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 6)
    }

    /// The prize drawn near the rim of its slice (rotated with the slice).
    private func prizeIcon(_ segment: LuckyWheel.Segment) -> some View {
        VStack(spacing: 2) {
            if segment.isJackpot {
                Image(systemName: "crown.fill").font(.system(size: 20, weight: .bold))
                Text("500").font(Theme.heading(14))
            } else if segment.reward.coins > 0 {
                Image(systemName: "circle.fill").font(.system(size: 14)).foregroundStyle(Theme.gold)
                Text("\(segment.reward.coins)").font(Theme.heading(15))
            } else if let booster = segment.reward.boosters.keys.first {
                Image(systemName: booster.icon).font(.system(size: 20, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .shadow(color: Theme.ink.opacity(0.4), radius: 1, y: 1)
        .offset(y: -95)
    }

    private var pointer: some View {
        Triangle()
            .fill(Theme.ink)
            .frame(width: 30, height: 34)
            .overlay(Triangle().fill(Theme.heart).frame(width: 20, height: 22).offset(y: -3))
            .rotationEffect(.degrees(180))
            .shadow(color: Theme.ink.opacity(0.3), radius: 3, y: 2)
    }

    @ViewBuilder private func prizeText(_ segment: LuckyWheel.Segment) -> some View {
        Group {
            if segment.isJackpot {
                Text("Jackpot! 500 coins and every booster")
            } else if segment.reward.coins > 0 {
                Text("+\(segment.reward.coins) coins")
            } else if let booster = segment.reward.boosters.keys.first {
                Text("+1 \(Text(booster.localizedName))")
            }
        }
        .font(Theme.heading(20))
        .foregroundStyle(Theme.heart)
        .multilineTextAlignment(.center)
    }

    private func spin(viaAd: Bool) {
        guard !spinning else { return }
        let today = model.today
        var landed: Int?
        model.save.update { landed = $0.spinWheel(today: today, viaAd: viaAd, roll: Double.random(in: 0..<1)) }
        guard let index = landed else { return }
        won = nil
        spinning = true
        let slice = 360.0 / Double(LuckyWheel.segments.count)
        // Bring the chosen slice under the pointer at the top, after five full turns.
        let current = rotation.truncatingRemainder(dividingBy: 360)
        let target = rotation - current + 360 * 5 + (360 - Double(index) * slice)
        let duration = 3.6
        withAnimation(.timingCurve(0.15, 0.85, 0.25, 1, duration: duration)) { rotation = target }
        tick(duration: duration)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            spinning = false
            won = index
            model.audio.play(LuckyWheel.segments[index].isJackpot ? .win : .coin)
            model.haptics.success()
        }
    }

    /// Ticks that slow down with the wheel.
    private func tick(duration: Double) {
        Task { @MainActor in
            var gap = 0.05
            var elapsed = 0.0
            while elapsed < duration - 0.2 {
                model.haptics.tap()
                try? await Task.sleep(for: .seconds(gap))
                elapsed += gap
                gap *= 1.12
            }
        }
    }
}

private struct WheelSlice: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let slice = 360.0 / Double(count)
        // Slice 0 is centred at the top.
        let start = Angle.degrees(-90 - slice / 2 + Double(index) * slice)
        let end = Angle.degrees(-90 + slice / 2 + Double(index) * slice)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
