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

    init(level: Level) {
        self.level = level
        game = Game(level: level)
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
        return game.tap(id)
    }

    func undo() {
        guard game.undo() else { return }
        hintedCandy = nil
        boardVersion += 1
    }

    func restart() {
        game = Game(level: level)
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
