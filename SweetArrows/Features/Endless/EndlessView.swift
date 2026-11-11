import SpriteKit
import SwiftUI
import SweetArrowsCore

/// The main game: candies keep arriving, faster and faster, until the board or the jar is full.
struct EndlessView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: EndlessSession?
    @State private var scene: GameScene?
    @State private var showResult = false
    @State private var newRecord = false
    @State private var coinsEarned = 0
    @State private var stageBanner: Int?

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            if let session, let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .id(ObjectIdentifier(scene))
                    .ignoresSafeArea()
                    .accessibilityIdentifier("board")
                VStack(spacing: 8) {
                    EndlessHUD(session: session, best: model.save.progress.endlessBest, back: leave)
                    if let stage = stageBanner {
                        Text("Speed \(stage + 1)!")
                            .font(Theme.heading())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.heart))
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.horizontal)
                if showResult {
                    EndlessResultCard(
                        score: session.score,
                        best: model.save.progress.endlessBest,
                        newRecord: newRecord,
                        coins: coinsEarned,
                        reason: session.status,
                        canRevive: session.canRevive && model.ads.isRewardedReady,
                        onRevive: revive,
                        onAgain: playAgain,
                        onHome: leave
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showResult)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: stageBanner)
        .toolbar(.hidden, for: .navigationBar)
        .task { if session == nil { load() } }
        .onChange(of: session?.boardVersion) { _, _ in scene?.rebuild() }
        .onChange(of: session?.status) { _, status in
            if let status, status.isOver { runEnded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session?.release("background") } else { session?.hold("background") }
        }
    }

    private func load() {
        let progress = model.save.progress
        let newSession = EndlessSession()
        let newScene = GameScene(
            session: newSession, haptics: model.haptics, audio: model.audio,
            colorBlind: progress.settings.colorBlind, boardStyle: progress.board, candyStyle: progress.candyStyle
        )
        newScene.topInset = 132
        newSession.onEvent = { [weak newScene] event in
            switch event {
            case .warn(let pending): newScene?.showWarning(pending)
            case .spawned(let state): newScene?.spawn(state)
            case .boardFull: newScene?.boardFull()
            case .stageUp(let stage): showStage(stage)
            }
        }
        session = newSession
        scene = newScene
        model.analytics.log(.endlessStart)
        newSession.start()
    }

    private func showStage(_ stage: Int) {
        stageBanner = stage
        model.audio.playCombo(min(stage + 1, 8))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if stageBanner == stage { stageBanner = nil }
        }
    }

    private func runEnded() {
        guard let session, !showResult else { return }
        let run = session.run
        coinsEarned = run.coinsEarned
        var record = false
        model.save.update { record = $0.recordEndless(score: run.score, coins: run.coinsEarned) }
        newRecord = record
        model.gameCenter.submitEndlessScore(run.score)
        model.analytics.log(.endlessOver(score: run.score, seconds: Int(run.elapsed), stage: run.stage))
        model.ads.levelFinished(won: true)
        if record {
            scene?.celebrate()
            model.haptics.success()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            showResult = true
        }
    }

    private func revive() {
        Task { @MainActor in
            guard let session, await model.ads.showRewarded(reason: .extraSlot) else { return }
            model.analytics.log(.boosterUsed(type: "endless_revive", source: "ad"))
            showResult = false
            session.revive()
        }
    }

    private func playAgain() {
        showResult = false
        newRecord = false
        model.ads.maybeShowInterstitial(afterLevel: max(model.save.progress.endlessRuns + 7, 1))
        session?.restart()
        model.analytics.log(.endlessStart)
    }

    private func leave() {
        session?.hold("leaving")
        if !model.path.isEmpty { model.path.removeLast() }
    }
}

private struct EndlessHUD: View {
    let session: EndlessSession
    let best: Int
    let back: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            RoundIconButton(systemName: "chevron.left", label: "Back", action: back)
                .accessibilityIdentifier("backButton")
            Spacer()
            VStack(spacing: 0) {
                Text("\(session.score)")
                    .font(Theme.title(40))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: session.score)
                    .accessibilityIdentifier("score")
                Text("Best \(max(best, session.score))")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "hare.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("\(session.stage + 1)")
                    .font(Theme.heading(16))
            }
            .foregroundStyle(Theme.heart)
            .frame(width: 48)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Speed \(session.stage + 1)!"))
        }
        .padding(.top, 4)
    }
}

private struct EndlessResultCard: View {
    let score: Int
    let best: Int
    let newRecord: Bool
    let coins: Int
    let reason: GameStatus
    let canRevive: Bool
    let onRevive: () -> Void
    let onAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                JellyView(size: 64)
                Text(newRecord ? "New record!" : (reason == .lost(.bagFull) ? "The jar is full!" : "The board is full!"))
                    .font(Theme.title(28))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("\(score)")
                    .font(Theme.title(56))
                    .foregroundStyle(newRecord ? Theme.heart : Theme.ink)
                    .monospacedDigit()
                Text("Best \(best)")
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
                if coins > 0 { CoinBadge(coins: coins) }
                if canRevive {
                    Button(action: onRevive) {
                        Label("Keep going", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
                    .accessibilityIdentifier("reviveButton")
                }
                Button("Play again", action: onAgain)
                    .buttonStyle(CandyButtonStyle())
                    .accessibilityIdentifier("playAgainButton")
                Button("Home", action: onHome)
                    .font(Theme.body())
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
            .padding()
        }
    }
}
