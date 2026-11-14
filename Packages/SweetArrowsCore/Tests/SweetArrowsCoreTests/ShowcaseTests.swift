import Testing
@testable import SweetArrowsCore

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
