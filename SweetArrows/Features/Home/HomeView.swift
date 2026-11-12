import SwiftUI
import SweetArrowsCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showDailyReward = false
    @State private var showTrackingPrimer = false
    @State private var askReminders = false
    @State private var showWheel = false

    @State private var pulse = false

    /// How much room the home screen gets: the largest layout that fits is used, so it never needs scrolling.
    private enum Density { case regular, compact, tiny }

    var body: some View {
        ZStack {
            CandySkyBackground()
            ViewThatFits(in: .vertical) {
                content(.regular)
                content(.compact)
                content(.tiny)
            }
            .padding(.horizontal)
        }
        .safeAreaInset(edge: .bottom) {
            if model.showsBanner {
                BannerAdView(adUnitID: model.ads.bannerAdUnitID)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Get a daily reminder?", isPresented: $askReminders) {
            Button("Yes, please") { Task { await model.setReminders(true) } }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("At most one a day: when your missions are ready or your streak is about to end.")
        }
        .sheet(isPresented: $showWheel) {
            LuckyWheelView()
                .presentationDetents([.large])
        }
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
            pulse = true
            let today = model.today
            if model.save.progress.missions.day != today {
                model.save.update { $0.refreshMissions(today: today) }
            }
            let progress = model.save.progress
            // App Tracking Transparency: only after a few runs, with our own explanation first.
            if progress.endlessRuns >= 2, model.consent.needsTrackingPrompt {
                showTrackingPrimer = true
            // Daily reward pops up once a day, after the first runs (never at the very first start).
            } else if progress.showsMetaFeatures, progress.dailyReward.claimableStep(today: model.today) != nil {
                showDailyReward = true
            } else if progress.endlessRuns >= 4, !progress.settings.reminders,
                      !UserDefaults.standard.bool(forKey: "askedReminders") {
                // Asked once, after a few runs, when nothing else pops up.
                UserDefaults.standard.set(true, forKey: "askedReminders")
                askReminders = true
            }
        }
    }

    private func content(_ density: Density) -> some View {
        let progress = model.save.progress
        let spacing: CGFloat = switch density {
        case .regular: 18
        case .compact: 12
        case .tiny: 8
        }
        return VStack(spacing: spacing) {
            topBar(progress)
                .popIn(delay: 0)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                if density != .tiny {
                    JellyView(size: density == .regular ? 104 : 72)
                        .padding(.bottom, 6)
                }
                Text(verbatim: "Sweet Arrows")
                    .font(Theme.title(density == .regular ? 44 : (density == .compact ? 36 : 30)))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 0, x: 0, y: 3)
                if density != .tiny {
                    Text("Tap, slide, pop the sweets")
                        .font(Theme.body(density == .regular ? 17 : 15))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: Theme.ink.opacity(0.25), radius: 2, y: 1)
                }
            }
            .popIn(delay: 0.08)

            statsRow(progress)
                .popIn(delay: 0.16)

            Button {
                model.path.append(.endless)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(Theme.title(density == .regular ? 30 : 26))
                    .frame(maxWidth: 260)
                    .padding(.vertical, density == .regular ? 6 : 2)
            }
            .buttonStyle(CandyButtonStyle())
            .shineSweep()
            .scaleEffect(pulse ? 1.04 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .accessibilityIdentifier("playButton")
            .popIn(delay: 0.24)

            if !progress.missions.missions.isEmpty {
                missionsCard(progress.missions, compact: density != .regular)
                    .popIn(delay: 0.32)
            }

            if progress.showsMetaFeatures {
                metaButtons(progress)
                    .popIn(delay: 0.4)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.bottom, density == .regular ? 16 : 8)
    }

    private func metaButtons(_ progress: PlayerProgress) -> some View {
        let giftReady = progress.dailyReward.claimableStep(today: model.today) != nil
        return HStack(spacing: 10) {
            Button {
                model.path.append(.shop)
            } label: {
                Label("Shop", systemImage: "bag.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97), compact: true))
            .accessibilityIdentifier("shopButton")
            Button {
                showDailyReward = true
            } label: {
                Label("Gift", systemImage: "gift.fill")
                    .symbolEffect(.pulse, isActive: giftReady)
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0xFF9F1C), compact: true))
            .overlay(alignment: .topTrailing) {
                if giftReady {
                    Circle().fill(Theme.heart).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }
            .accessibilityIdentifier("giftButton")
            Button {
                showWheel = true
            } label: {
                Label("Spin", systemImage: "sparkles")
                    .symbolEffect(.pulse, isActive: progress.wheel.hasFreeSpin(today: model.today))
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0xA259FF), compact: true))
            .overlay(alignment: .topTrailing) {
                if progress.wheel.hasFreeSpin(today: model.today) {
                    Circle().fill(Theme.heart).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }
            .accessibilityIdentifier("wheelButton")
        }
    }

    private func topBar(_ progress: PlayerProgress) -> some View {
        HStack(spacing: 10) {
            LevelBadge(level: progress.level, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text("Level \(progress.level)")
                    .font(Theme.heading(16))
                    .foregroundStyle(Theme.ink)
                XPBar(fraction: Double(progress.xpIntoLevel) / Double(max(progress.xpForLevel, 1)), height: 10)
                    .frame(width: 110)
            }
            Spacer()
            CoinBadge(coins: progress.coins)
            RoundIconButton(systemName: "gearshape.fill", label: "Settings") {
                model.path.append(.settings)
            }
        }
        .padding(.top, 4)
    }

    private func statsRow(_ progress: PlayerProgress) -> some View {
        HStack(spacing: 10) {
            StatChip(icon: "trophy.fill", tint: Theme.gold, value: "\(progress.endlessBest)", label: "Best")
            StatChip(icon: "flame.fill", tint: Color(hex: 0xFF9F1C),
                     value: "\(progress.streak.current(today: model.today))", label: "Days in a row")
        }
    }

    private func missionsCard(_ missions: DailyMissions, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack {
                Label("Daily missions", systemImage: "checklist")
                    .font(Theme.heading(18))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(missions.missions.filter(\.isDone).count)/\(missions.missions.count)")
                    .font(Theme.heading(15))
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(missions.missions, id: \.kind) { mission in
                MissionRow(mission: mission, compact: compact)
            }
            if compact {
                EmptyView()
            } else if missions.allDone {
                Label("All done! Come back tomorrow for new missions.", systemImage: "party.popper.fill")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.heart)
            } else {
                Text("Finish all three for a bonus gift")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .candyCard(padding: compact ? 10 : 14)
        .accessibilityIdentifier("missionsCard")
    }
}

/// Small white pill with an icon, a number and a label.
struct StatChip: View {
    let icon: String
    let tint: Color
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(Theme.heading(18))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text(label)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .candyCard(padding: 10)
        .accessibilityElement(children: .combine)
    }
}

struct CoinBadge: View {
    let coins: Int
    /// Count up from zero when it appears (result cards).
    var countUp = false
    @State private var bump = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.gold)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .rotation3DEffect(.degrees(bump ? 360 : 0), axis: (x: 0, y: 1, z: 0))
            RollingNumber(value: coins, countUp: countUp)
                .font(Theme.heading(18))
                .foregroundStyle(Theme.ink)
        }
        .scaleEffect(bump ? 1.15 : 1)
        .onChange(of: coins) { old, new in
            guard new > old else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bump = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.spring(response: 0.3)) { bump = false }
            }
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
    @State private var blink = false
    @State private var wiggle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let artwork = UIImage(named: "mascot") {
            // Real artwork, when it has been added to the asset catalog.
            Image(uiImage: artwork)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.15, height: size * 1.15)
                .scaleEffect(x: squish ? 1.05 : 1, y: squish ? 0.95 : 1, anchor: .bottom)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: squish)
                .onAppear { squish = true }
                .accessibilityHidden(true)
        } else {
            drawnStar
        }
    }

    private var drawnStar: some View {
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
        .rotationEffect(.degrees(wiggle ? 12 : 0))
        .onAppear { squish = true }
        .onTapGesture { poke() }
        .task { await blinkLoop() }
        .accessibilityHidden(true)
    }

    /// Blinks every few seconds.
    private func blinkLoop() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...4.5)))
            withAnimation(.easeInOut(duration: 0.08)) { blink = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.08)) { blink = false }
        }
    }

    /// A happy wiggle when tapped.
    private func poke() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.3)) { wiggle = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { wiggle = false }
        }
    }

    private var eye: some View {
        Ellipse()
            .fill(.white)
            .frame(width: size * 0.12, height: size * 0.15)
            .scaleEffect(y: blink ? 0.1 : 1)
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
