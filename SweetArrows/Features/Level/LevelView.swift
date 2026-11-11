import SpriteKit
import SwiftUI
import SweetArrowsCore

/// What is being played: a campaign level or the daily puzzle of a given day.
enum PlayMode: Hashable {
    case campaign(Int)
    case daily(day: Int)

    var campaignLevel: Int? {
        if case .campaign(let id) = self { return id }
        return nil
    }
}

/// One level: the SpriteKit board with a SwiftUI HUD, boosters and the win/lose card on top.
struct LevelView: View {
    let mode: PlayMode

    @Environment(AppModel.self) private var model
    @State private var session: GameSession?
    @State private var scene: GameScene?
    @State private var showResult = false
    @State private var coinsEarned = 0
    @State private var choosingCandyToRemove = false
    @State private var introElement: BoardElement?
    @State private var lastDailyResult: DailyResult?

    /// Space below the booster bar that the scene uses for the jar.
    private static let jarSpace: CGFloat = 24 + 96 + 10
    private static let boosterBarHeight: CGFloat = 66

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            if let session, let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, debugOptions: Self.spriteDebugOptions)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("board")
                overlay(session)
                    .padding(.horizontal)
                if let element = introElement {
                    ElementIntroCard(element: element) {
                        model.save.update { $0.seenElements.insert(element) }
                        introElement = nil
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                if showResult {
                    resultCard(session)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: introElement)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: mode) { load() }
        .onChange(of: session?.boardVersion) { _, _ in scene?.rebuild() }
        .onChange(of: session?.status) { _, status in
            if let status { statusChanged(status) }
        }
    }

    private func overlay(_ session: GameSession) -> some View {
        VStack(spacing: 8) {
            LevelHUD(title: title, session: session, back: leave, undo: { session.undo() })
            if let tip = TutorialTip(level: mode.campaignLevel ?? 0, tutorial: session.level.tutorial),
               session.status == .playing {
                JellyTipView(text: tip.text)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if choosingCandyToRemove {
                JellyTipView(text: "Tap the candy you want to remove.")
                    .onTapGesture { cancelRemoval() }
            }
            Spacer()
            if showsBoosters(session.level) {
                BoosterBar(
                    progress: model.save.progress,
                    adReady: model.ads.isRewardedReady,
                    enabled: session.status == .playing && !choosingCandyToRemove,
                    canAddSlot: session.game.bag.capacity < Bag.maxCapacity,
                    use: { useBooster($0) }
                )
                .frame(height: Self.boosterBarHeight)
            }
            Spacer().frame(height: Self.jarSpace)
        }
    }

    private func resultCard(_ session: GameSession) -> some View {
        ResultCard(
            session: session,
            coins: coinsEarned,
            totalCoins: model.save.progress.coins,
            audio: model.audio,
            adReady: model.ads.isRewardedReady,
            canAffordSlot: model.save.progress.canAfford(.extraSlot),
            slotsInStock: model.save.progress.boosters[.extraSlot],
            hasNext: hasNextLevel,
            shareText: shareText,
            onNext: goToNextLevel,
            onRetry: { retry(session) },
            onUndo: {
                session.undo()
                showResult = false
            },
            onExtraSlot: { useBooster(.extraSlot, viaAd: false) },
            onExtraSlotAd: { useBooster(.extraSlot, viaAd: true) },
            onExtraHearts: { continueWithHearts(session) },
            onHome: leave
        )
    }

    /// FPS and node count on screen in Debug builds, to check the 60 fps goal on a real device.
    private static var spriteDebugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }

    /// Boosters stay hidden during the first tutorial levels.
    private func showsBoosters(_ level: Level) -> Bool {
        !level.tutorial || (mode.campaignLevel ?? 0) > 5
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .campaign(let id): "Level \(id)"
        case .daily: "Daily puzzle"
        }
    }

    private var hasNextLevel: Bool {
        guard let id = mode.campaignLevel else { return false }
        return id < model.levels.count
    }

    private var shareText: String? {
        guard case .daily(let day) = mode, let result = lastDailyResult else { return nil }
        return DailyPuzzleState.shareText(
            puzzle: day + 1, result: result,
            streak: model.save.progress.dailyPuzzle.currentStreak(today: day)
        )
    }

    // MARK: Flow

    private func load() {
        showResult = false
        choosingCandyToRemove = false
        lastDailyResult = nil
        let level: Level? = switch mode {
        case .campaign(let id): model.level(id)
        case .daily(let day): model.levels.dailyPuzzle(model.dailyPuzzleNumber(day: day))
        }
        guard let level else {
            session = nil
            scene = nil
            return
        }
        let progress = model.save.progress
        let newSession = GameSession(level: level)
        let newScene = GameScene(
            session: newSession, haptics: model.haptics, audio: model.audio,
            colorBlind: progress.settings.colorBlind,
            boardStyle: progress.board, candyStyle: progress.candyStyle
        )
        let id = mode.campaignLevel ?? 0
        let hasTip = TutorialTip(level: id, tutorial: level.tutorial) != nil
        newScene.topInset = hasTip ? 188 : 124
        newScene.boosterBarHeight = showsBoosters(level) ? Self.boosterBarHeight : 0
        if hasTip { model.analytics.log(.tutorialStep(step: id)) }
        session = newSession
        scene = newScene

        // A world's first level introduces its new element once.
        let world = World.forLevel(id)
        if mode.campaignLevel != nil, id == world.firstLevel, let element = world.newElement,
           !progress.seenElements.contains(element) {
            introElement = element
        } else {
            introElement = nil
        }
        model.analytics.log(.levelStart(level: level.id))
    }

    private func statusChanged(_ status: GameStatus) {
        guard let session else { return }
        switch status {
        case .playing:
            showResult = false
            return
        case .won:
            switch mode {
            case .campaign(let id):
                coinsEarned = model.save.recordWin(level: id, stars: session.stars)
                model.ads.levelFinished(won: true)
                if id <= 3 { model.analytics.log(.tutorialStep(step: id * 10)) }
            case .daily(let day):
                let result = DailyResult(taps: session.moves, seconds: session.secondsPlayed, stars: session.stars)
                lastDailyResult = result
                coinsEarned = model.save.recordDaily(result, day: day)
                model.gameCenter.submitDailyTime(seconds: result.seconds)
            }
            model.reportAchievements()
            model.analytics.log(.levelComplete(
                level: session.level.id, moves: session.moves, seconds: session.secondsPlayed, stars: session.stars
            ))
            model.haptics.success()
            model.audio.play(.win)
        case .lost(let reason):
            if mode.campaignLevel != nil { model.ads.levelFinished(won: false) }
            if model.ads.isRewardedReady { model.analytics.log(.adOfferShown(reason: "continue")) }
            model.analytics.log(.levelFail(
                level: session.level.id, reason: reason == .bagFull ? "bag_full" : "out_of_hearts", moves: session.moves
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
            model.analytics.log(.levelQuit(level: session.level.id, moves: session.moves))
        }
        if !model.path.isEmpty { model.path.removeLast() }
    }

    private func goToNextLevel() {
        guard let id = mode.campaignLevel else { return }
        model.ads.maybeShowInterstitial(afterLevel: id)
        guard !model.path.isEmpty else { return }
        model.path[model.path.count - 1] = .level(id + 1)
    }

    private func retry(_ session: GameSession) {
        if session.status.isOver, session.status != .won, mode.campaignLevel != nil { model.save.recordLoss() }
        showResult = false
        session.restart()
        model.analytics.log(.levelStart(level: session.level.id))
    }

    // MARK: Boosters

    private func useBooster(_ booster: Booster) {
        useBooster(booster, viaAd: !model.save.progress.canAfford(booster))
    }

    /// Pays with stock/coins or a rewarded ad, then applies the booster.
    private func useBooster(_ booster: Booster, viaAd: Bool) {
        guard let session else { return }
        if booster == .removeCandy {
            // Pay only once a candy has actually been picked.
            choosingCandyToRemove = true
            scene?.onCandySelected = { id in
                Task { @MainActor in
                    guard await pay(for: .removeCandy, viaAd: viaAd) else {
                        cancelRemoval()
                        return
                    }
                    choosingCandyToRemove = false
                    session.removeCandy(id)
                }
            }
            return
        }
        Task { @MainActor in
            guard await pay(for: booster, viaAd: viaAd) else { return }
            switch booster {
            case .extraSlot:
                session.addBagSlot()
                showResult = false
            case .hint:
                if session.hint() != nil { scene?.showHint() }
            case .removeCandy:
                break
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
        case .extraSlot: .extraSlot
        case .hint: .hint
        case .removeCandy: .removeCandy
        }
        guard await model.ads.showRewarded(reason: reason) else { return false }
        model.analytics.log(.boosterUsed(type: booster.rawValue, source: "ad"))
        return true
    }

    private func cancelRemoval() {
        choosingCandyToRemove = false
        scene?.onCandySelected = nil
    }

    private func continueWithHearts(_ session: GameSession) {
        Task { @MainActor in
            guard await model.ads.showRewarded(reason: .extraHearts) else { return }
            model.analytics.log(.boosterUsed(type: "extra_hearts", source: "ad"))
            session.addHearts(3)
            showResult = false
        }
    }
}
