import SpriteKit
import SwiftUI
import SweetArrowsCore

/// The main game, slide & match: tap a candy to slide it along its arrow, line up three of a color
/// to pop them. Candies keep arriving, faster and faster, until the board is full.
struct EndlessView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: SlideSession?
    @State private var scene: SlideScene?
    @State private var showResult = false
    @State private var offerRevive = false
    /// What the finished run earned (shown on the result card).
    @State private var outcome: RunOutcome?
    @State private var stageBanner: Int?
    /// The hammer waits for the player to pick a candy.
    @State private var choosingCandy = false

    private static let boosterBarHeight: CGFloat = 66
    private static let bannerHeight: CGFloat = 68

    private var showsBanner: Bool { model.showsBanner }

    /// Room the scene keeps free under the board: booster bar, and the banner when it shows.
    private var bottomInset: CGFloat {
        Self.boosterBarHeight + 16 + (showsBanner ? Self.bannerHeight : 0)
    }

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
                    if model.save.progress.endlessRuns < 2, session.run.popped == 0 {
                        Text("Tap a candy to slide it. Line up 3 of a color!")
                            .font(Theme.body(16))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.85)))
                            .accessibilityIdentifier("slideHelp")
                    }
                    if let stage = stageBanner {
                        Text("Speed \(stage + 1)!")
                            .font(Theme.heading())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.heart))
                            .transition(.scale.combined(with: .opacity))
                    }
                    if choosingCandy {
                        Text("Tap a candy to smash it")
                            .font(Theme.body(16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.ink.opacity(0.85)))
                    }
                    Spacer()
                    BoosterBar(
                        progress: model.save.progress,
                        adReady: model.ads.isRewardedReady,
                        enabled: !session.isOver && !showResult && !offerRevive,
                        active: choosingCandy ? .hammer : nil,
                        use: useBooster
                    )
                    .frame(height: Self.boosterBarHeight)
                    .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.7)).padding(.horizontal, -8))
                    .accessibilityIdentifier("boosterBar")
                    if showsBanner {
                        // Owner's choice: a banner under the board, kept clear of the booster buttons.
                        BannerAdView(adUnitID: model.ads.bannerAdUnitID)
                            .padding(.top, 8)
                            .padding(.horizontal, -16)
                    }
                }
                .padding(.horizontal)
                if offerRevive {
                    ReviveCard(score: session.score, onRevive: revive, onDecline: finishRun)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                if showResult, let outcome {
                    RunResultCard(outcome: outcome, onAgain: playAgain, onHome: leave)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showResult)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: offerRevive)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: stageBanner)
        .toolbar(.hidden, for: .navigationBar)
        .task { if session == nil { load() } }
        .onChange(of: session?.boardVersion) { _, _ in scene?.rebuild() }
        .onChange(of: session?.isOver) { _, over in
            if over == true { runEnded() }
        }
        .onChange(of: session?.isSlowedDown) { _, slowed in scene?.showSlowDown(slowed == true) }
        .onChange(of: showsBanner) { _, _ in scene?.bottomInset = bottomInset }
        .onDisappear { model.audio.playMusic(.menu) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session?.release("background") } else { session?.hold("background") }
        }
    }

    private func load() {
        let progress = model.save.progress
        let newSession = SlideSession()
        let newScene = SlideScene(
            session: newSession, haptics: model.haptics, audio: model.audio,
            colorBlind: progress.settings.colorBlind, boardStyle: progress.board, candyStyle: progress.candyStyle,
            backdrop: progress.backdrop
        )
        newScene.topInset = 132
        newScene.bottomInset = bottomInset
        newScene.showsTutorialHand = progress.endlessRuns < 2
        newSession.onEvent = { [weak newScene] event in
            switch event {
            case .warn(let pending): newScene?.showWarning(pending)
            case .spawned(let piece): newScene?.spawn(piece)
            case .boardFull: newScene?.boardFull()
            case .stageUp(let stage): showStage(stage)
            }
        }
        session = newSession
        scene = newScene
        model.analytics.log(.endlessStart)
        model.audio.playMusic(.calm)
        newSession.start()
    }

    private func showStage(_ stage: Int) {
        stageBanner = stage
        model.audio.playCombo(min(stage + 1, 8))
        // The music gets livelier every two speed stages.
        model.audio.playMusic(.game(stage: stage))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if stageBanner == stage { stageBanner = nil }
        }
    }

    /// The board filled up: first the one-time "keep going" offer, then the run is counted.
    private func runEnded() {
        guard let session, !showResult, !offerRevive else { return }
        let canRevive = session.canRevive && model.ads.isRewardedReady
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            if canRevive { offerRevive = true } else { finishRun() }
        }
    }

    /// Counts the run (once): best score, coins, streak, missions, XP and level rewards.
    private func finishRun() {
        guard let session, outcome == nil else { return }
        offerRevive = false
        let run = session.run
        let today = model.today
        var result: RunOutcome?
        model.save.update { result = $0.recordRun(run.summary, today: today) }
        outcome = result
        model.gameCenter.submitEndlessScore(run.score)
        model.reportAchievements(after: run)
        model.analytics.log(.endlessOver(score: run.score, seconds: Int(run.elapsed), stage: run.stage))
        model.ads.levelFinished(won: true)
        if result?.newRecord == true || result?.levelRewards.isEmpty == false {
            scene?.celebrate()
            model.haptics.success()
            model.audio.play(.win)
        }
        showResult = true
    }

    private func revive() {
        Task { @MainActor in
            guard let session, await model.ads.showRewarded(reason: .revive) else { return }
            model.analytics.log(.boosterUsed(type: "endless_revive", source: "ad"))
            offerRevive = false
            session.revive()
        }
    }

    private func playAgain() {
        showResult = false
        outcome = nil
        model.ads.maybeShowInterstitial(afterLevel: model.save.progress.endlessRuns)
        session?.restart()
        model.audio.playMusic(.calm)
        model.analytics.log(.endlessStart)
    }

    // MARK: Boosters

    private func useBooster(_ booster: Booster) {
        guard let session else { return }
        let viaAd = !model.save.progress.canAfford(booster)
        if booster == .hammer {
            guard !choosingCandy else {
                cancelHammer()
                return
            }
            // Pay only once a candy has actually been picked.
            choosingCandy = true
            scene?.onCandySelected = { id in
                Task { @MainActor in
                    choosingCandy = false
                    guard !session.isOver, await pay(for: .hammer, viaAd: viaAd) else { return }
                    scene?.smashed(id)
                    session.smash(id)
                }
            }
            return
        }
        cancelHammer()
        Task { @MainActor in
            if booster == .hint {
                // Only pay when there is something to show.
                guard let id = session.hint() else {
                    model.haptics.bonk()
                    return
                }
                guard await pay(for: .hint, viaAd: viaAd) else { return }
                scene?.highlight(id)
            } else {
                guard await pay(for: booster, viaAd: viaAd) else { return }
                session.slowDown()
            }
        }
    }

    private func pay(for booster: Booster, viaAd: Bool) async -> Bool {
        guard viaAd else {
            guard model.save.spend(booster) else { return false }
            model.analytics.log(.boosterUsed(type: booster.rawValue, source: "coins"))
            return true
        }
        let reason: RewardReason = switch booster {
        case .hint: .hint
        case .hammer: .hammer
        case .slowDown: .slowDown
        }
        session?.hold("ad")
        defer { session?.release("ad") }
        guard await model.ads.showRewarded(reason: reason) else { return false }
        model.analytics.log(.boosterUsed(type: booster.rawValue, source: "ad"))
        return true
    }

    private func cancelHammer() {
        choosingCandy = false
        scene?.onCandySelected = nil
    }

    private func leave() {
        session?.hold("leaving")
        model.audio.playMusic(.menu)
        if !model.path.isEmpty { model.path.removeLast() }
    }
}

private struct EndlessHUD: View {
    let session: SlideSession
    let best: Int
    let back: () -> Void

    @State private var bump = false

    /// The score warms up with the combo: brown, then pink, orange and purple.
    private var scoreColor: Color {
        guard session.run.comboIsLive else { return Theme.ink }
        switch session.combo {
        case ..<2: return Theme.ink
        case 2: return Theme.heart
        case 3: return Color(hex: 0xFF9F1C)
        default: return Color(hex: 0xA259FF)
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            RoundIconButton(systemName: "chevron.left", label: "Back", action: back)
                .accessibilityIdentifier("backButton")
            Spacer()
            VStack(spacing: 0) {
                Text("\(session.score)")
                    .font(Theme.title(40))
                    .foregroundStyle(scoreColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .scaleEffect(bump ? 1.25 : 1)
                    .shadow(color: scoreColor.opacity(bump ? 0.6 : 0), radius: 8)
                    .animation(.spring(response: 0.25), value: session.score)
                    .animation(.spring(response: 0.2, dampingFraction: 0.45), value: bump)
                    .animation(.easeInOut(duration: 0.2), value: scoreColor)
                    .accessibilityIdentifier("score")
                    .onChange(of: session.score) { old, new in
                        guard new > old else { return }
                        bump = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(160))
                            bump = false
                        }
                    }
                Text("Best \(max(best, session.score))")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
            .background(Capsule().fill(.white.opacity(0.85)).shadow(color: Theme.ink.opacity(0.1), radius: 4, y: 2))
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "hare.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("\(session.stage + 1)")
                    .font(Theme.heading(16))
            }
            .foregroundStyle(Theme.heart)
            .frame(width: 48, height: 48)
            .background(Circle().fill(.white.opacity(0.85)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Speed \(session.stage + 1)!"))
        }
        .padding(.top, 4)
    }
}
