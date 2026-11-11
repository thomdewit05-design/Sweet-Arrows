import SpriteKit
import SwiftUI
import SweetArrowsCore

/// One level: the SpriteKit board with a SwiftUI HUD and the win/lose card on top.
struct LevelView: View {
    let levelID: Int

    @Environment(AppModel.self) private var model
    @State private var session: GameSession?
    @State private var scene: GameScene?
    @State private var showResult = false
    @State private var coinsEarned = 0

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            if let session, let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("board")
                VStack(spacing: 8) {
                    LevelHUD(
                        levelID: levelID,
                        session: session,
                        back: leave,
                        undo: { session.undo() },
                        hint: { requestHint(session) }
                    )
                    Spacer()
                }
                .padding(.horizontal)
                if showResult {
                    ResultCard(
                        session: session,
                        coins: coinsEarned,
                        adReady: model.ads.isRewardedReady,
                        hasNext: levelID < model.levels.count,
                        onNext: goToNextLevel,
                        onRetry: { retry(session) },
                        onUndo: { session.undo(); showResult = false },
                        onExtraSlot: { continueWithReward(.extraSlot, session) },
                        onExtraHearts: { continueWithReward(.extraHearts, session) },
                        onHome: leave
                    )
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            } else {
                VStack(spacing: 16) {
                    Text("Level not found")
                        .font(Theme.heading())
                    Button("Back", action: leave).buttonStyle(CandyButtonStyle())
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showResult)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: levelID) { load() }
        .onChange(of: session?.boardVersion) { _, _ in scene?.rebuild() }
        .onChange(of: session?.status) { _, status in
            if let status { statusChanged(status) }
        }
    }

    // MARK: Flow

    private func load() {
        showResult = false
        guard let level = model.level(levelID) else {
            session = nil
            scene = nil
            return
        }
        let newSession = GameSession(level: level)
        let newScene = GameScene(
            session: newSession, haptics: model.haptics, audio: model.audio,
            colorBlind: model.settings.colorBlind
        )
        newScene.topInset = 124
        session = newSession
        scene = newScene
        model.analytics.log(.levelStart(level: levelID))
    }

    private func statusChanged(_ status: GameStatus) {
        guard let session else { return }
        switch status {
        case .playing:
            showResult = false
            return
        case .won:
            let streakBonus = model.save.progress.winStreak >= 2 ? 5 : 0
            coinsEarned = model.save.recordWin(level: levelID, stars: session.stars, coins: 10 + streakBonus)
            model.analytics.log(.levelComplete(
                level: levelID, moves: session.moves, seconds: session.secondsPlayed, stars: session.stars
            ))
            model.haptics.success()
            model.audio.play(.win)
        case .lost(let reason):
            model.analytics.log(.levelFail(
                level: levelID, reason: reason == .bagFull ? "bag_full" : "out_of_hearts", moves: session.moves
            ))
            model.audio.play(.lose)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            if session.status.isOver { showResult = true }
        }
    }

    private func leave() {
        if let session, session.status == .playing, session.moves > 0 {
            model.analytics.log(.levelQuit(level: levelID, moves: session.moves))
        }
        if !model.path.isEmpty { model.path.removeLast() }
    }

    private func goToNextLevel() {
        model.ads.maybeShowInterstitial(afterLevel: levelID)
        guard !model.path.isEmpty else { return }
        model.path[model.path.count - 1] = .level(levelID + 1)
    }

    private func retry(_ session: GameSession) {
        if session.status.isOver, session.status != .won { model.save.recordLoss() }
        showResult = false
        session.restart()
        model.analytics.log(.levelStart(level: levelID))
    }

    private func continueWithReward(_ reason: RewardReason, _ session: GameSession) {
        Task { @MainActor in
            guard await model.ads.showRewarded(reason: reason) else { return }
            model.analytics.log(.boosterUsed(type: reason.rawValue, source: "ad"))
            switch reason {
            case .extraSlot: session.addBagSlot()
            case .extraHearts: session.addHearts(3)
            default: break
            }
            showResult = false
        }
    }

    private func requestHint(_ session: GameSession) {
        Task { @MainActor in
            guard await model.ads.showRewarded(reason: .hint) else { return }
            model.analytics.log(.boosterUsed(type: "hint", source: "ad"))
            if session.hint() != nil { scene?.showHint() }
        }
    }
}

// MARK: - HUD

private struct LevelHUD: View {
    let levelID: Int
    let session: GameSession
    let back: () -> Void
    let undo: () -> Void
    let hint: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "Back", action: back)
                    .accessibilityIdentifier("backButton")
                Spacer()
                VStack(spacing: 2) {
                    Text("Level \(levelID)")
                        .font(Theme.heading())
                        .foregroundStyle(Theme.ink)
                    if session.level.hard {
                        Text("Hard level")
                            .font(Theme.body(13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.heart))
                    }
                }
                Spacer()
                HeartsView(hearts: session.hearts, total: session.level.hearts, tutorial: session.level.tutorial)
            }
            HStack {
                Spacer()
                RoundIconButton(systemName: "lightbulb.fill", label: "Hint", enabled: session.status == .playing, action: hint)
                RoundIconButton(systemName: "arrow.uturn.backward", label: "Undo", enabled: session.canUndo, action: undo)
                    .accessibilityIdentifier("undoButton")
            }
        }
        .padding(.top, 4)
    }
}

private struct HeartsView: View {
    let hearts: Int
    let total: Int
    let tutorial: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<max(total, hearts), id: \.self) { index in
                Image(systemName: index < hearts ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.heart)
                    .scaleEffect(index < hearts ? 1 : 0.85)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hearts)
            }
        }
        .frame(minWidth: 48, alignment: .trailing)
        .opacity(tutorial ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(hearts) hearts left"))
        .accessibilityIdentifier("hearts")
    }
}

// MARK: - Result card

private struct ResultCard: View {
    let session: GameSession
    let coins: Int
    let adReady: Bool
    let hasNext: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onUndo: () -> Void
    let onExtraSlot: () -> Void
    let onExtraHearts: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 18) {
                switch session.status {
                case .won: won
                case .lost(.bagFull): bagFull
                case .lost(.outOfHearts): outOfHearts
                case .playing: EmptyView()
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
            .padding()
        }
        .accessibilityIdentifier("resultCard")
    }

    @ViewBuilder private var won: some View {
        JellyView(size: 70)
        Text("Sweet!")
            .font(Theme.title())
            .foregroundStyle(Theme.ink)
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(index < session.stars ? Theme.gold : Theme.inkSoft.opacity(0.25))
            }
        }
        CoinBadge(coins: coins)
        if hasNext {
            Button("Next level", action: onNext)
                .buttonStyle(CandyButtonStyle())
                .accessibilityIdentifier("nextLevelButton")
        }
        Button("Home", action: onHome)
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
    }

    @ViewBuilder private var bagFull: some View {
        Text("The jar is full!")
            .font(Theme.title(28))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
        Text("Get one more slot and keep going.")
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        if adReady {
            Button(action: onExtraSlot) {
                Label("Extra slot", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
        }
        if session.canUndo {
            Button(action: onUndo) {
                Label("Undo last move", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x5B6CFF)))
        }
        Button("Try again", action: onRetry)
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
    }

    @ViewBuilder private var outOfHearts: some View {
        Text("Out of hearts")
            .font(Theme.title(28))
            .foregroundStyle(Theme.ink)
        Text("Bounced too often. Want three more hearts?")
            .font(Theme.body())
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        if adReady {
            Button(action: onExtraHearts) {
                Label("3 hearts", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
        }
        Button("Try again", action: onRetry)
            .buttonStyle(CandyButtonStyle())
    }
}
