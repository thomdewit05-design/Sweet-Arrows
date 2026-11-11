import Foundation
import Observation
import SweetArrowsCore

/// Bridges the pure rules (`Game`) to SwiftUI and SpriteKit for one level attempt.
/// SwiftUI observes it for hearts/status; the scene draws from it and animates move reports.
@MainActor
@Observable
final class GameSession {
    let level: Level
    private(set) var game: Game
    private(set) var startedAt = Date()
    /// Bumped whenever the board must be redrawn from scratch (undo, restart, boosters).
    private(set) var boardVersion = 0
    /// Candy the hint booster points at.
    private(set) var hintedCandy: Int?
    /// Pops in a row (for the rising xylophone tone). A bounce, or three launches
    /// without a pop, start the run again.
    private(set) var comboStep = 0
    private var launchesSincePop = 0

    // MARK: Clock
    /// Seconds left on the clock (nil = no clock). Starts at the first tap.
    private(set) var remaining: Double?
    private(set) var clockStarted = false
    /// Reasons the clock is held (result card, intro card, app in background...).
    private var holds = Set<String>()
    @ObservationIgnored private var lastTick: Date?
    @ObservationIgnored private var ticking = false

    init(level: Level) {
        self.level = level
        game = Game(level: level)
        remaining = level.timeLimit.map(Double.init)
    }

    /// Whole seconds to show (rounded up, so "0" only appears when time is really up).
    var secondsLeft: Int? { remaining.map { Int($0.rounded(.up)) } }
    var clockIsRunning: Bool { clockStarted && holds.isEmpty && status == .playing && (remaining ?? 0) > 0 }

    /// Stops the clock for a reason; it runs again once every hold is released.
    func holdClock(_ reason: String) {
        tick()
        holds.insert(reason)
    }

    func releaseClock(_ reason: String) {
        holds.remove(reason)
        lastTick = Date()
        startTicking()
    }

    /// Continue offer after the clock ran out.
    func addTime(_ seconds: Int) {
        guard remaining != nil else { return }
        remaining = (remaining ?? 0) + Double(seconds)
        game.continueAfterTimeout()
        lastTick = Date()
        startTicking()
    }

    private func startClockIfNeeded() {
        guard remaining != nil, !clockStarted else { return }
        clockStarted = true
        lastTick = Date()
        startTicking()
    }

    private func startTicking() {
        guard !ticking, clockIsRunning else { return }
        ticking = true
        Task { [weak self] in
            while let self, self.clockIsRunning {
                try? await Task.sleep(for: .milliseconds(200))
                self.tick()
            }
            self?.ticking = false
        }
    }

    private func tick() {
        let now = Date()
        defer { lastTick = now }
        guard clockIsRunning, let last = lastTick, let left = remaining else { return }
        let next = max(left - now.timeIntervalSince(last), 0)
        remaining = next
        if next <= 0 { game.timeRanOut() }
    }

    var hearts: Int { game.hearts }
    var status: GameStatus { game.status }
    var canUndo: Bool { game.canUndo && status != .won }
    var moves: Int { game.moves }

    /// 3 stars without a bounce, 2 after one, 1 otherwise. Tutorial levels always give 3.
    var stars: Int {
        if level.tutorial { return 3 }
        let lost = level.hearts - game.hearts
        return max(1, 3 - lost)
    }

    var secondsPlayed: Int { Int(Date().timeIntervalSince(startedAt)) }

    // MARK: Actions

    func tap(_ id: Int) -> MoveReport {
        hintedCandy = nil
        startClockIfNeeded()
        let report = game.tap(id)
        switch report.result {
        case .launched(let launch) where launch.bag.didPop:
            comboStep += 1
            launchesSincePop = 0
        case .launched:
            launchesSincePop += 1
            if launchesSincePop >= 3 { comboStep = 0 }
        case .bounced:
            comboStep = 0
            launchesSincePop = 0
        case .crackedCaramel, .frozen, .locked, .ignored:
            break
        }
        return report
    }

    func undo() {
        guard game.undo() else { return }
        hintedCandy = nil
        boardVersion += 1
    }

    func restart() {
        game = Game(level: level)
        comboStep = 0
        launchesSincePop = 0
        remaining = level.timeLimit.map(Double.init)
        clockStarted = false
        startedAt = Date()
        hintedCandy = nil
        boardVersion += 1
    }

    func addBagSlot() {
        game.addBagSlot()
        boardVersion += 1
    }

    func addHearts(_ count: Int) {
        game.addHearts(count)
    }

    func removeCandy(_ id: Int) {
        guard game.removeCandy(id) != nil else { return }
        boardVersion += 1
    }

    /// Asks the solver for a safe next tap.
    func hint() -> Int? {
        let move = Solver(game: game, configuration: .hint).nextMove()
        hintedCandy = move
        return move
    }
}
