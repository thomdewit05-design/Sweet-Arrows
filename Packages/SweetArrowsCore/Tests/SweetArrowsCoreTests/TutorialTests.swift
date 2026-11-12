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
