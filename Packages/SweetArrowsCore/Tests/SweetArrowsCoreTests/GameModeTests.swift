import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Game modes")
struct GameModeTests {
    @Test func dailyIsTheSameForEveryoneOnADay() {
        let a = GameMode.newGame(.daily, today: 50, seed: 1)
        let b = GameMode.newGame(.daily, today: 50, seed: 999)
        let c = GameMode.newGame(.daily, today: 51, seed: 1)
        #expect(a.pieces == b.pieces)
        #expect(a.pieces != c.pieces)
        #expect(!GameMode.daily.allowsRevive)
        #expect(!GameMode.daily.canBeResumed)
    }

    @Test func zenBringsACandyAfterEveryMoveAndNoneWithTime() {
        var game = GameMode.newGame(.zen, today: 0, seed: 4)
        #expect(game.pieces.count == 6)
        for _ in 0..<100 { #expect(game.advance(by: 1).filter { if case .spawned = $0 { true } else { false } }.isEmpty) }
        #expect(game.pieces.count == 6)
        let piece = game.sortedPieces.first(where: \.canMove)!
        let report = game.tap(piece.id)
        #expect(report.spawned != nil)
        #expect(game.pieces.count >= 7 - report.popped.count - report.exploded.count)
        #expect(game.timeLeft == nil)
    }

    @Test func zenEndsWhenNoCellIsFree() {
        var settings = GameMode.zen.settings
        settings.width = 3
        settings.height = 3
        settings.startCandies = 0
        var game = SlideGame(pieces: [], settings: settings)
        var taps = 0
        let lone = SlideGame.Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 0))
        game = SlideGame(pieces: [lone], settings: settings)
        while !game.isOver, taps < 200 {
            if let piece = game.sortedPieces.first(where: \.canMove) { _ = game.tap(piece.id) }
            taps += 1
        }
        #expect(game.isOver)
        #expect(game.status == .boardFull)
    }

    @Test func blitzStopsAfterSixtySeconds() {
        var game = GameMode.newGame(.blitz, today: 0, seed: 2)
        #expect(game.timeLeft == 60)
        var events: [SlideGame.Event] = []
        while !game.isOver { events += game.advance(by: 0.5) }
        #expect(game.status == .timeUp || game.status == .boardFull)
        if game.status == .timeUp {
            #expect(events.last == .timeUp)
            #expect(game.timeLeft == 0)
        }
        #expect(!GameMode.blitz.allowsRevive)
    }

    @Test func bestsAreKeptPerMode() {
        var progress = PlayerProgress()
        let classic = progress.recordRun(RunSummary(score: 500), today: 7)
        let blitz = progress.recordRun(RunSummary(score: 300), today: 7, mode: .blitz)
        let daily = progress.recordRun(RunSummary(score: 200), today: 7, mode: .daily)
        let dailyAgain = progress.recordRun(RunSummary(score: 150), today: 7, mode: .daily)
        #expect(classic.newRecord)
        #expect(blitz.newRecord)
        #expect(daily.newRecord)
        #expect(!dailyAgain.newRecord)
        #expect(progress.endlessBest == 500)
        #expect(progress.best(for: .blitz, today: 7) == 300)
        #expect(progress.best(for: .zen, today: 7) == 0)
        #expect(progress.best(for: .daily, today: 7) == 200)
        #expect(progress.best(for: .daily, today: 8) == 0)
        #expect(progress.dailyChallenge.plays == 2)
        let data = try? JSONEncoder().encode(progress)
        let decoded = data.flatMap { try? JSONDecoder().decode(PlayerProgress.self, from: $0) }
        #expect(decoded?.modeBests[.blitz] == 300)
    }
}
