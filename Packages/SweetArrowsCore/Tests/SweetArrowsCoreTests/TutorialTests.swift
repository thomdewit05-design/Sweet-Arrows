import Testing
@testable import SweetArrowsCore

@Suite("Tutorial")
struct TutorialTests {
    @Test func theThreeStepsWorkOnTheBoard() {
        var game = Tutorial.board()
        #expect(game.matchedIDs().isEmpty)
        #expect(Tutorial.step(of: game) == .slide)
        #expect(Tutorial.target(for: .slide) == Tutorial.slider)

        let first = game.tap(Tutorial.slider)
        #expect(first.popped == [1, 2, Tutorial.slider])
        #expect(Tutorial.step(of: game) == .turn)

        let second = game.tap(Tutorial.turner)
        #expect(second.move == .turned(id: Tutorial.turner, to: .down))
        #expect(Tutorial.step(of: game) == .match)

        let third = game.tap(Tutorial.turner)
        #expect(third.popped == [4, 5, Tutorial.turner])
        #expect(third.clearedBoard)
        #expect(Tutorial.step(of: game) == .finished)
        #expect(Tutorial.target(for: .finished) == nil)
    }

    @Test func nothingArrivesUnlessTheClockRuns() {
        let game = Tutorial.board()
        #expect(game.pending == nil)
        #expect(game.pieces.count == 6)
    }
}

@Suite("Showcase board")
struct ShowcaseTests {
    @Test func oneTapMakesASugarRush() {
        var game = SlideGame.showcase()
        #expect(game.comboIsLive)
        #expect(game.stage == 5)
        let report = game.tap(SlideGame.showcaseMover)
        #expect(report.popped.count == 5)
        #expect(report.combo == 5)
        #expect(report.celebration == 4)
        #expect(game.score > 3140)
    }

    @Test func theBoardHasNoLinesYet() {
        let game = SlideGame.showcase()
        for piece in game.sortedPieces where piece.kind == .normal {
            let right = (1...2).compactMap { game.piece(at: GridPoint(piece.position.x + $0, piece.position.y)) }
            let down = (1...2).compactMap { game.piece(at: GridPoint(piece.position.x, piece.position.y + $0)) }
            #expect(!(right.count == 2 && right.allSatisfy { $0.color == piece.color && $0.kind == .normal }))
            #expect(!(down.count == 2 && down.allSatisfy { $0.color == piece.color && $0.kind == .normal }))
        }
    }
}
