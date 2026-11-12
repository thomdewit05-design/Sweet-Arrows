import SwiftUI
import UIKit
import SweetArrowsCore

/// Offered once per run when the board fills up, before anything is counted.
struct ReviveCard: View {
    let score: Int
    let onRevive: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                JellyView(size: 64)
                Text("The board is full!")
                    .font(Theme.title(28))
                    .foregroundStyle(Theme.ink)
                Text("\(score)")
                    .font(Theme.title(48))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("Keep going? A third of the candies disappears.")
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                Button(action: onRevive) {
                    Label("Keep going", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
                .shineSweep(every: 2)
                .accessibilityIdentifier("reviveButton")
                Button("No thanks", action: onDecline)
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityIdentifier("declineReviveButton")
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
            .padding()
        }
    }
}

/// After a run: score, XP towards the next level, level-up rewards, finished missions and coins.
struct RunResultCard: View {
    let outcome: RunOutcome
    let onAgain: () -> Void
    let onHome: () -> Void
    @State private var filled = false

    private var summary: RunSummary { outcome.summary }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text(outcome.newRecord ? "New record!" : "The board is full!")
                        .font(Theme.title(28))
                        .foregroundStyle(outcome.newRecord ? Theme.heart : Theme.ink)
                        .multilineTextAlignment(.center)
                    RollingNumber(value: summary.score, countUp: true, duration: 1.0)
                        .font(Theme.title(56))
                        .foregroundStyle(outcome.newRecord ? Theme.heart : Theme.ink)
                        .accessibilityIdentifier("resultScore")
                        .overlay {
                            if outcome.newRecord { ConfettiBurst() }
                        }
                    recordLine
                        .popIn(delay: 0.5)
                    levelBlock
                        .popIn(delay: 0.6)
                    ForEach(Array(outcome.levelRewards.enumerated()), id: \.element.level) { index, reward in
                        LevelUpRow(reward: reward)
                            .popIn(delay: 0.9 + Double(index) * 0.15)
                            .overlay { ConfettiBurst(pieces: 18) }
                    }
                    if !outcome.finishedMissions.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(outcome.finishedMissions.enumerated()), id: \.element.kind) { index, mission in
                                MissionRow(mission: mission, compact: true)
                                    .popIn(delay: 1.1 + Double(index) * 0.12)
                            }
                            if outcome.allMissionsDone, outcome.missionReward.coins > 0 {
                                Label("All missions done: bonus!", systemImage: "gift.fill")
                                    .font(Theme.heading(15))
                                    .foregroundStyle(Theme.heart)
                            }
                        }
                    }
                    if outcome.totalCoins > 0 {
                        CoinBadge(coins: outcome.totalCoins, countUp: true)
                            .popIn(delay: 1.3)
                    }
                    Button("Play again", action: onAgain)
                        .buttonStyle(CandyButtonStyle())
                        .shineSweep()
                        .accessibilityIdentifier("playAgainButton")
                        .popIn(delay: 0.4)
                    ShareScoreButton(
                        score: summary.score, level: outcome.levelAfter, streak: outcome.streak,
                        newRecord: outcome.newRecord
                    )
                    .popIn(delay: 0.5)
                    Button("Home", action: onHome)
                        .font(Theme.body())
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(24)
                .frame(maxWidth: 360)
                .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
                .padding()
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.3)) { filled = true }
        }
    }

    @ViewBuilder private var recordLine: some View {
        if outcome.newRecord {
            if outcome.previousBest > 0 {
                Text("Old record \(outcome.previousBest)")
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
            }
        } else {
            let missing = outcome.previousBest - summary.score
            Text("Only \(missing) points short of your record")
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
    }

    private var levelBlock: some View {
        VStack(spacing: 6) {
            HStack {
                LevelBadge(level: outcome.levelAfter, size: 34)
                Text("Level \(outcome.levelAfter)")
                    .font(Theme.heading(18))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("+\(outcome.xpGained) XP")
                    .font(Theme.heading(16))
                    .foregroundStyle(Color(hex: 0x5B6CFF))
            }
            XPBar(fraction: filled ? Double(outcome.xpIntoLevel) / Double(max(outcome.xpForLevel, 1)) : 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white))
    }
}

/// "Level 3! +70 coins · new backdrop".
struct LevelUpRow: View {
    let reward: LevelReward
    @State private var pop = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.gold)
                .scaleEffect(pop ? 1 : 0.3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Level \(reward.level)!")
                    .font(Theme.heading(17))
                    .foregroundStyle(.white)
                Group {
                    if let unlock = reward.unlock {
                        Text("+\(reward.reward.coins) coins · new backdrop: \(Text(unlock.localizedName))")
                    } else if !reward.reward.boosters.isEmpty {
                        Text("+\(reward.reward.coins) coins · 1 of every booster")
                    } else {
                        Text("+\(reward.reward.coins) coins")
                    }
                }
                .font(Theme.body(13))
                .foregroundStyle(.white.opacity(0.95))
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(
            colors: [Color(hex: 0xA259FF), Color(hex: 0xFF5C8A)], startPoint: .leading, endPoint: .trailing
        )))
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.5)) { pop = true } }
    }
}

/// Rounded progress bar in candy colors.
struct XPBar: View {
    let fraction: Double
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x5B6CFF), Color(hex: 0xA259FF), Color(hex: 0xFF5C8A)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(proxy.size.width * min(max(fraction, 0), 1), height))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.35)).frame(height: height * 0.3).padding(.horizontal, 6)
                            .padding(.top, 2)
                    }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.6), value: fraction)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(fraction * 100)) %"))
    }
}

/// The player level in a little star.
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            StarShape()
                .fill(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF2C230)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(StarShape().stroke(.white, lineWidth: max(size * 0.06, 1.5)))
            Text("\(level)")
                .font(.custom(Theme.spriteFontName, size: size * 0.36))
                .foregroundStyle(Theme.ink)
                .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(Double(level) * 360), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(level)"))
    }
}

/// One daily mission: icon, text and progress (or a tick when done).
struct MissionRow: View {
    let mission: Mission
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mission.isDone ? "checkmark.circle.fill" : mission.kind.icon)
                .symbolEffect(.bounce, value: mission.isDone)
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: compact ? 18 : 22, weight: .bold))
                .foregroundStyle(mission.isDone ? Color(hex: 0x3DDC97) : Theme.heart)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                mission.kind.description(target: mission.target)
                    .font(Theme.body(compact ? 14 : 15))
                    .foregroundStyle(Theme.ink)
                if !compact, !mission.isDone {
                    XPBar(fraction: Double(mission.progress) / Double(max(mission.target, 1)), height: 8)
                }
            }
            Spacer(minLength: 4)
            if mission.isDone {
                Text(compact ? "+\(mission.coins)" : "Done")
                    .font(Theme.heading(14))
                    .foregroundStyle(Color(hex: 0x2EB67D))
            } else {
                Text("\(mission.progress)/\(mission.target)")
                    .font(Theme.heading(13))
                    .foregroundStyle(Theme.inkSoft)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension MissionKind {
    var icon: String {
        switch self {
        case .score: "trophy.fill"
        case .popCandies: "sparkles"
        case .combo: "flame.fill"
        case .bombs: "burst.fill"
        case .stones: "hammer.fill"
        case .rainbows: "rainbow"
        case .runs: "play.fill"
        case .bigPop: "line.3.horizontal"
        case .speed: "hare.fill"
        }
    }

    func description(target: Int) -> Text {
        switch self {
        case .score: Text("Score \(target) points in one run")
        case .popCandies: Text("Pop \(target) candies")
        case .combo: Text("Reach combo ×\(target)")
        case .bombs: Text("Set off \(target) bombs")
        case .stones: Text("Break \(target) stones")
        case .rainbows: Text("Pop \(target) rainbow candies")
        case .runs: Text("Play \(target) runs")
        case .bigPop: Text("Pop \(target) in one line")
        case .speed: Text("Reach speed \(target)")
        }
    }
}

// MARK: Sharing

/// The picture that gets shared: score, level and streak on the candy sky.
struct ScoreShareCard: View {
    let score: Int
    let level: Int
    let streak: Int
    let newRecord: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x7FD8FF), Color(hex: 0xB9A4FF), Color(hex: 0xFFB3D1)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                JellyView(size: 110)
                Text(verbatim: "Sweet Arrows")
                    .font(Theme.title(40))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 0, x: 0, y: 3)
                if newRecord {
                    Label("New record!", systemImage: "trophy.fill")
                        .font(Theme.heading(22))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.gold))
                }
                Text("\(score)")
                    .font(Theme.title(84))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 0, x: 0, y: 4)
                HStack(spacing: 18) {
                    Label("Level \(level)", systemImage: "star.fill")
                    if streak > 1 {
                        Label("\(streak)", systemImage: "flame.fill")
                    }
                }
                .font(Theme.heading(22))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.85)))
                Text("Can you beat my score?")
                    .font(Theme.heading(24))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.3), radius: 2, y: 1)
            }
            .padding(30)
        }
        .frame(width: 420, height: 560)
    }
}

/// A "Share" button that renders the score card to an image and opens the share sheet.
struct ShareScoreButton: View {
    let score: Int
    let level: Int
    let streak: Int
    let newRecord: Bool
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ShareLink(
                    item: Image(uiImage: image),
                    message: Text("My score in Sweet Arrows: \(score) 🍬 Can you beat it?\n\(Links.website.absoluteString)"),
                    preview: SharePreview(Text(verbatim: "Sweet Arrows"), image: Image(uiImage: image))
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(CandyButtonStyle(color: Color(hex: 0x5B6CFF)))
                .accessibilityIdentifier("shareButton")
            }
        }
        .task { render() }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: ScoreShareCard(score: score, level: level, streak: streak, newRecord: newRecord))
        renderer.scale = 3
        image = renderer.uiImage
    }
}
