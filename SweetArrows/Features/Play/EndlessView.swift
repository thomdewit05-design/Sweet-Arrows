import SpriteKit
import StoreKit
import SwiftUI
import SweetArrowsCore

/// The main game, slide & match: tap a candy to slide it along its arrow, line up three of a color
/// to pop them. Candies keep arriving, faster and faster, until the board is full.
struct EndlessView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var session: SlideSession?
    @State private var scene: SlideScene?
    @State private var showResult = false
    @State private var offerRevive = false
    @State private var paused = false
    /// The guided first game, while it runs.
    @State private var tutorialStep: Tutorial.Step?
    /// The record was beaten during this run (the banner shows once).
    @State private var recordAnnounced = false
    @State private var showRecordBanner = false
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
                    EndlessHUD(session: session, best: model.save.progress.endlessBest, pause: pause)
                    if let step = tutorialStep {
                        TutorialBubble(step: step, onStart: finishTutorial)
                    } else if model.save.progress.endlessRuns < 2, session.run.popped == 0 {
                        Text("Tap a candy to slide it. Line up 3 of a color!")
                            .font(Theme.body(16))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.85)))
                            .accessibilityIdentifier("slideHelp")
                    }
                    if showRecordBanner {
                        Label("New record!", systemImage: "trophy.fill")
                            .font(Theme.heading())
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.gold))
                            .shadow(color: Theme.gold.opacity(0.6), radius: 10)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityIdentifier("recordBanner")
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
                        enabled: !session.isOver && !showResult && !offerRevive && !paused && tutorialStep == nil,
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
                if paused {
                    PauseCard(onResume: resume, onRestart: restartFromPause, onHome: leave)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
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
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: paused)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showRecordBanner)
        .onChange(of: session?.score) { _, score in checkRecord(score ?? 0) }
        .onChange(of: session?.run.moves) { _, _ in advanceTutorial() }
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
            if phase == .active {
                session?.release("background")
            } else {
                session?.hold("background")
                session?.save()  // closing the app keeps the run
            }
        }
    }

    private func load() {
        let progress = model.save.progress
        // The very first game is the guided tutorial; otherwise continue an unfinished run if there is one.
        let saved = SavedRun.load()
        let needsTutorial = saved == nil && progress.endlessRuns == 0
            && !UserDefaults.standard.bool(forKey: Tutorial.doneKey)
            && !ProcessInfo.processInfo.arguments.contains("-uiTesting")  // UI tests go straight to a run
        let newSession: SlideSession
        if needsTutorial {
            newSession = SlideSession(resuming: Tutorial.board())
            newSession.isTutorial = true
            newSession.hold("tutorial")
        } else {
            newSession = saved.map(SlideSession.init(resuming:)) ?? SlideSession()
        }
        let newScene = SlideScene(
            session: newSession, haptics: model.haptics, audio: model.audio,
            colorBlind: progress.settings.colorBlind, boardStyle: progress.board, candyStyle: progress.candyStyle,
            backdrop: progress.backdrop
        )
        newScene.topInset = 132
        newScene.bottomInset = bottomInset
        newScene.showsTutorialHand = progress.endlessRuns < 2 && !needsTutorial
        if needsTutorial {
            tutorialStep = .slide
            newScene.guideTarget = Tutorial.target(for: .slide)
        }
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
        model.audio.playMusic(.calm)
        guard !needsTutorial else { return }
        model.analytics.log(.endlessStart)
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
        SavedRun.clear()
        let today = model.today
        var result: RunOutcome?
        model.save.update { result = $0.recordRun(run.summary, today: today) }
        outcome = result
        model.gameCenter.submitEndlessScore(run.score)
        model.reportAchievements(after: run)
        model.analytics.log(.endlessOver(score: run.score, seconds: Int(run.elapsed), stage: run.stage))
        model.ads.levelFinished(won: true)
        if result?.newRecord == true { askForReviewIfDue() }
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
        SavedRun.clear()
        recordAnnounced = false
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

    // MARK: Record

    /// A happy moment (a new record) is the right time to ask for stars: after a few runs, at most every 60 days
    /// (iOS itself also limits how often the dialog really appears).
    private func askForReviewIfDue() {
        let key = "lastReviewRequest"
        let last = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
        guard model.save.progress.endlessRuns >= 3, Date().timeIntervalSince(last) > 60 * 24 * 3600 else { return }
        UserDefaults.standard.set(Date(), forKey: key)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }

    /// The moment the score passes the best ever: banner, confetti and a happy buzz (once per run).
    private func checkRecord(_ score: Int) {
        let best = model.save.progress.endlessBest
        guard !recordAnnounced, best > 0, score > best else { return }
        recordAnnounced = true
        showRecordBanner = true
        scene?.celebrate()
        model.haptics.success()
        model.audio.play(.star)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            showRecordBanner = false
        }
    }

    // MARK: Tutorial

    /// After each tap in the tutorial, move on to the next step (once the animation has played).
    private func advanceTutorial() {
        guard tutorialStep != nil, let session else { return }
        let step = Tutorial.step(of: session.run)
        scene?.guideTarget = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard tutorialStep != nil else { return }
            tutorialStep = step
            scene?.guideTarget = Tutorial.target(for: step)
        }
    }

    /// The tutorial is done: start the real first run.
    private func finishTutorial() {
        UserDefaults.standard.set(true, forKey: Tutorial.doneKey)
        tutorialStep = nil
        session = nil
        scene = nil
        load()
    }

    // MARK: Pause

    private func pause() {
        guard let session, !session.isOver, !paused, tutorialStep == nil else { return }
        cancelHammer()
        session.hold("pause")
        session.save()
        paused = true
    }

    private func resume() {
        paused = false
        session?.release("pause")
    }

    private func restartFromPause() {
        paused = false
        recordAnnounced = false
        SavedRun.clear()
        session?.release("pause")
        session?.restart()
        model.audio.playMusic(.calm)
        model.analytics.log(.endlessStart)
    }

    private func leave() {
        session?.hold("leaving")
        session?.save()
        model.audio.playMusic(.menu)
        if !model.path.isEmpty { model.path.removeLast() }
    }
}

private struct EndlessHUD: View {
    let session: SlideSession
    let best: Int
    let pause: () -> Void

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
            RoundIconButton(systemName: "pause.fill", label: "Pause", action: pause)
                .accessibilityIdentifier("pauseButton")
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

/// Paused: carry on, start over or go home (the run is kept for next time).
private struct PauseCard: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                JellyView(size: 60)
                Text("Paused")
                    .font(Theme.title(30))
                    .foregroundStyle(Theme.ink)
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
                .accessibilityIdentifier("resumeButton")
                Button(action: onRestart) {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(CandyButtonStyle(color: Color(hex: 0xFF9F1C)))
                Button(action: onHome) {
                    Label("Home", systemImage: "house.fill")
                }
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
                .accessibilityIdentifier("backButton")
                Text("Your run is saved. Tap Play to carry on later.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.cream))
            .padding()
        }
    }
}

/// The speech bubble of the guided tutorial, one line per step, and the start button at the end.
private struct TutorialBubble: View {
    let step: Tutorial.Step
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Group {
                switch step {
                case .slide: Text("Tap the candy: it slides where its arrow points.")
                case .turn: Text("Stuck? Tap it to turn its arrow.")
                case .match: Text("Now slide it: line up 3 of a color!")
                case .finished: Text("Great! New candies keep coming. Don't let the board fill up!")
                }
            }
            .font(Theme.heading(17))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            if step == .finished {
                Button("Let's go!", action: onStart)
                    .buttonStyle(CandyButtonStyle())
                    .shineSweep(every: 2)
                    .accessibilityIdentifier("startAfterTutorial")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.95)).shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 3)
        )
        .id(step)
        .transition(.scale.combined(with: .opacity))
        .accessibilityIdentifier("tutorialBubble")
    }
}
