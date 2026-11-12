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

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        run = SlideGame(seed: seed)
    }

    /// Continues a run that was saved when the player left or closed the app.
    init(resuming saved: SlideGame) {
        run = saved
    }

    /// Writes the run to disk so it survives leaving the screen or the app being closed.
    func save() {
        if run.isOver { SavedRun.clear() } else { SavedRun.store(run) }
    }

    var score: Int { run.score }
    var stage: Int { run.stage }
    var combo: Int { run.combo }
    var isOver: Bool { run.isOver }

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

    func restart() {
        run = SlideGame(seed: UInt64.random(in: 1...UInt64.max))
        boardVersion += 1
        lastTick = Date()
        startIfNeeded()
    }
}

/// The one unfinished run, kept on this device (not in iCloud: it is only a few seconds of play).
enum SavedRun {
    private static let key = "savedRun.v1"

    static func load(defaults: UserDefaults = .standard) -> SlideGame? {
        guard let data = defaults.data(forKey: key),
              let run = try? JSONDecoder().decode(SlideGame.self, from: data), !run.isOver
        else { return nil }
        return run
    }

    static func store(_ run: SlideGame, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(run) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
