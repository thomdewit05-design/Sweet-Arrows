import SwiftUI
import SweetArrowsCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showDailyReward = false
    @State private var showTrackingPrimer = false

    var body: some View {
        let progress = model.save.progress
        let next = min(progress.nextLevel, max(model.levels.count, 1))
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

                // The main game is endless; the hand-made and generated levels live under "Puzzles".
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

                HStack(spacing: 16) {
                    Button("Puzzles") { model.path.append(.level(next)) }
                        .buttonStyle(CandyButtonStyle(color: Color(hex: 0x5B6CFF)))
                        .accessibilityIdentifier("puzzlesButton")
                    Button("Map") { model.path.append(.map) }
                        .buttonStyle(CandyButtonStyle(color: Color(hex: 0xA259FF)))
                    if progress.showsMetaFeatures {
                        Button("Shop") { model.path.append(.shop) }
                            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
                    }
                }
                if progress.showsMetaFeatures, model.levels.dailyCount > 0 {
                    DailyPuzzleCard(state: progress.dailyPuzzle, today: model.today) {
                        model.path.append(.daily(model.today))
                    }
                    .padding(.horizontal, 32)
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
            // App Tracking Transparency: only after level 3, with our own explanation first.
            if progress.completedLevel >= 3, model.consent.needsTrackingPrompt {
                showTrackingPrimer = true
            // Daily reward pops up once a day, from level 5 on (never at the very first start).
            } else if progress.showsMetaFeatures, progress.dailyReward.claimableStep(today: model.today) != nil {
                showDailyReward = true
            }
        }
    }
}

/// Today's daily puzzle: done or not, and the streak.
struct DailyPuzzleCard: View {
    let state: DailyPuzzleState
    let today: Int
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            HStack(spacing: 12) {
                Image(systemName: state.isCompleted(day: today) ? "checkmark.seal.fill" : "calendar")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(state.isCompleted(day: today) ? Color(hex: 0x3DDC97) : Theme.heart)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily puzzle")
                        .font(Theme.heading(18))
                        .foregroundStyle(Theme.ink)
                    Group {
                        if let result = state.results[today] {
                            Text("Done in \(result.seconds) s · play again for a better time")
                        } else {
                            Text("A new puzzle every day")
                        }
                    }
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                let streak = state.currentStreak(today: today)
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(Theme.heading(16))
                        .foregroundStyle(Color(hex: 0xFF9F1C))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: Theme.ink.opacity(0.1), radius: 4, y: 2))
        }
        .accessibilityIdentifier("dailyPuzzleButton")
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

/// Placeholder for the mascot Jelly until real artwork arrives: a pink gummy with big eyes.
struct JellyView: View {
    var size: CGFloat = 100
    @State private var squish = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.42)
                .fill(Theme.heart.gradient)
                .frame(width: size, height: size * 0.9)
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(.white.opacity(0.5))
                        .frame(width: size * 0.28, height: size * 0.14)
                        .rotationEffect(.degrees(-20))
                        .offset(x: size * 0.16, y: size * 0.12)
                }
            HStack(spacing: size * 0.16) {
                eye
                eye
            }
            .offset(y: -size * 0.04)
            Capsule()
                .fill(Theme.ink)
                .frame(width: size * 0.18, height: size * 0.07)
                .offset(y: size * 0.17)
        }
        .scaleEffect(x: squish ? 1.06 : 1, y: squish ? 0.94 : 1, anchor: .bottom)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: squish)
        .onAppear { squish = true }
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Circle()
            .fill(.white)
            .frame(width: size * 0.24, height: size * 0.24)
            .overlay(Circle().fill(Theme.ink).frame(width: size * 0.12).offset(x: size * 0.02, y: size * 0.02))
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(AppModel.preview())
}
