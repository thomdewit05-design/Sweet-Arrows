import Foundation
import Observation
import SweetArrowsCore

/// One slide & match run: drives the clock, forwards new candies to the scene and keeps the score.
@MainActor
@Observable
final class SlideSession {
    private(set) var run: SlideGame
    /// Bumped when the board must be redrawn from scratch (revive, new run).
    private(set) var boardVersion = 0
    @ObservationIgnored var onEvent: ((SlideGame.Event) -> Void)?
    @ObservationIgnored private var holds = Set<String>()
    @ObservationIgnored private var ticking = false
    @ObservationIgnored private var lastTick = Date()

    let mode: GameMode

    init(mode: GameMode = .classic, today: Int = 0, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.mode = mode
        run = GameMode.newGame(mode, today: today, seed: seed)
    }

    /// Continues a run that was saved when the player left or closed the app.
    init(resuming saved: SlideGame, mode: GameMode = .classic) {
        self.mode = mode
        run = saved
    }

    /// The guided tutorial board: never saved and its clock never runs.
    @ObservationIgnored var isTutorial = false

    /// Writes the run to disk so it survives leaving the screen or the app being closed.
    func save() {
        guard !isTutorial, mode.canBeResumed else { return }
        if run.isOver { SavedRun.clear(mode: mode) } else { SavedRun.store(run, mode: mode) }
    }

    var score: Int { run.score }
    var stage: Int { run.stage }
    var combo: Int { run.combo }
    var isOver: Bool { run.isOver }
    /// Blitz: whole seconds left on the clock.
    var secondsLeft: Int? { run.timeLeft.map { Int($0.rounded(.up)) } }

    func tap(_ id: Int) -> SlideGame.Report {
        startIfNeeded()
        return run.tap(id)
    }

    // MARK: Boosters

    var isSlowedDown: Bool { run.isSlowedDown }

    func hint() -> Int? { run.hint() }

    @discardableResult
    func smash(_ id: Int) -> Bool { run.smash(id) }

    func slowDown() { run.slowDown(for: 15) }

    // MARK: Clock

    func start() { startIfNeeded() }

    func hold(_ reason: String) { holds.insert(reason) }

    func release(_ reason: String) {
        holds.remove(reason)
        lastTick = Date()
        startIfNeeded()
    }

    private var running: Bool { holds.isEmpty && !run.isOver }

    private func startIfNeeded() {
        guard !ticking, running else { return }
        ticking = true
        lastTick = Date()
        Task { [weak self] in
            while let self, self.running {
                try? await Task.sleep(for: .milliseconds(100))
                self.tick()
            }
            self?.ticking = false
        }
    }

    private func tick() {
        let now = Date()
        let seconds = min(now.timeIntervalSince(lastTick), 0.5)
        lastTick = now
        guard running else { return }
        for event in run.advance(by: seconds) { onEvent?(event) }
    }

    // MARK: After the run

    var canRevive: Bool { run.canRevive }

    func revive() {
        _ = run.revive()
        boardVersion += 1
        lastTick = Date()
        startIfNeeded()
    }

    func restart(today: Int = 0) {
        run = GameMode.newGame(mode, today: today, seed: UInt64.random(in: 1...UInt64.max))
        boardVersion += 1
        lastTick = Date()
        startIfNeeded()
    }
}

/// The one unfinished run, kept on this device (not in iCloud: it is only a few seconds of play).
enum SavedRun {
    private static func key(_ mode: GameMode) -> String {
        mode == .classic ? "savedRun.v1" : "savedRun.v1.\(mode.rawValue)"
    }

    static func load(mode: GameMode = .classic, defaults: UserDefaults = .standard) -> SlideGame? {
        guard mode.canBeResumed, let data = defaults.data(forKey: key(mode)),
              let run = try? JSONDecoder().decode(SlideGame.self, from: data), !run.isOver
        else { return nil }
        return run
    }

    static func store(_ run: SlideGame, mode: GameMode = .classic, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(run) else { return }
        defaults.set(data, forKey: key(mode))
    }

    static func clear(mode: GameMode = .classic, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(mode))
    }
}
