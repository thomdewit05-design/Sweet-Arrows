import Foundation
import Observation
import SweetArrowsCore

/// One endless run: drives the clock, forwards new candies to the scene and keeps the score.
@MainActor
@Observable
final class EndlessSession: BoardSession {
    private(set) var run: EndlessGame
    private(set) var hintedCandy: Int?
    /// Bumped when the board must be redrawn from scratch (revive, new run).
    private(set) var boardVersion = 0
    @ObservationIgnored var onEvent: ((EndlessGame.Event) -> Void)?
    @ObservationIgnored private var holds = Set<String>()
    @ObservationIgnored private var ticking = false
    @ObservationIgnored private var lastTick = Date()

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        run = EndlessGame(seed: seed)
    }

    var level: Level { run.game.level }
    var game: Game { run.game }
    var status: GameStatus { run.status }
    var comboStep: Int { run.combo }
    var score: Int { run.score }
    var stage: Int { run.stage }

    func tap(_ id: Int) -> MoveReport {
        startIfNeeded()
        return run.tap(id)
    }

    // MARK: Clock

    /// Candies start arriving once the player is looking at the board.
    func start() {
        startIfNeeded()
    }

    func hold(_ reason: String) { holds.insert(reason) }

    func release(_ reason: String) {
        holds.remove(reason)
        lastTick = Date()
        startIfNeeded()
    }

    private var running: Bool { holds.isEmpty && run.status == .playing }

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
        run = EndlessGame(seed: UInt64.random(in: 1...UInt64.max))
        boardVersion += 1
        lastTick = Date()
        startIfNeeded()
    }
}
