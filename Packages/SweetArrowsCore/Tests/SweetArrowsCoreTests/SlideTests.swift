import Testing
@testable import SweetArrowsCore

@Suite("Slide & match")
struct SlideTests {
    private typealias Piece = SlideGame.Piece

    private func small(_ width: Int = 5, _ height: Int = 5) -> SlideGame.Settings {
        var settings = SlideGame.Settings()
        settings.width = width
        settings.height = height
        return settings
    }

    @Test func slidesUntilTheEdge() {
        var game = SlideGame(pieces: [Piece(id: 1, color: .mint, direction: .right, position: GridPoint(0, 2))],
                             settings: small())
        let report = game.tap(1)
        #expect(report.move == .slid(id: 1, from: GridPoint(0, 2), to: GridPoint(4, 2)))
        #expect(game.piece(at: GridPoint(4, 2))?.id == 1)
        #expect(game.piece(at: GridPoint(0, 2)) == nil)
        #expect(!report.didPop)
        #expect(game.moves == 1)
    }

    @Test func stopsInFrontOfAnotherCandy() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .down, position: GridPoint(1, 0)),
            Piece(id: 2, color: .lemon, direction: .up, position: GridPoint(1, 3)),
        ], settings: small())
        #expect(game.destination(of: game.pieces[1]!) == GridPoint(1, 2))
        _ = game.tap(1)
        #expect(game.piece(at: GridPoint(1, 2))?.id == 1)
    }

    @Test func blockedCandyTurnsItsArrow() {
        var game = SlideGame(pieces: [Piece(id: 1, color: .mint, direction: .up, position: GridPoint(2, 0))],
                             settings: small())
        let report = game.tap(1)
        #expect(report.move == .turned(id: 1, to: .right))
        #expect(game.pieces[1]?.direction == .right)
        #expect(game.pieces[1]?.position == GridPoint(2, 0))
    }

    @Test func threeInARowPop() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .grape, direction: .left, position: GridPoint(0, 4)),
            Piece(id: 2, color: .grape, direction: .left, position: GridPoint(1, 4)),
            Piece(id: 3, color: .grape, direction: .down, position: GridPoint(2, 0)),
            Piece(id: 4, color: .mint, direction: .up, position: GridPoint(4, 0)),
        ], settings: small())
        let report = game.tap(3)
        #expect(report.popped == [1, 2, 3])
        #expect(report.combo == 1)
        #expect(report.points == 30)
        #expect(game.score == 30)
        #expect(game.popped == 3)
        #expect(game.pieces.keys.sorted() == [4])
    }

    @Test func longerLinesAndCombosScoreMore() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .lemon, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .lemon, direction: .up, position: GridPoint(1, 4)),
            Piece(id: 3, color: .lemon, direction: .up, position: GridPoint(3, 4)),
            Piece(id: 4, color: .lemon, direction: .down, position: GridPoint(2, 0)),
            Piece(id: 5, color: .mint, direction: .left, position: GridPoint(4, 0)),
            Piece(id: 6, color: .mint, direction: .left, position: GridPoint(4, 1)),
            Piece(id: 7, color: .mint, direction: .up, position: GridPoint(3, 2)),
            Piece(id: 8, color: .orange, direction: .up, position: GridPoint(0, 0)),
        ], settings: small())
        let first = game.tap(4)
        #expect(first.popped == [1, 2, 3, 4])
        #expect(first.points == 10 * 4 + 20)
        // Mint at (3,2) slides up to (3,0)... next to (4,0)? No: it lands at (3,0), row 0 has 8, _, _, 7, 5.
        let second = game.tap(7)
        #expect(second.move == .slid(id: 7, from: GridPoint(3, 2), to: GridPoint(3, 0)))
        #expect(!second.didPop)
        _ = game.tap(6)  // (4,1) slides left to (0,1)
        #expect(game.pieces[6]?.position == GridPoint(0, 1))
    }

    @Test func comboGrowsWithinTheWindow() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(4, 3)),
            Piece(id: 2, color: .mint, direction: .up, position: GridPoint(4, 4)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(4, 0)),
            Piece(id: 4, color: .lemon, direction: .up, position: GridPoint(0, 3)),
            Piece(id: 5, color: .lemon, direction: .up, position: GridPoint(1, 3)),
            Piece(id: 6, color: .lemon, direction: .down, position: GridPoint(2, 0)),
            Piece(id: 7, color: .grape, direction: .up, position: GridPoint(2, 4)),
        ], settings: small())
        let first = game.tap(6)
        #expect(first.popped == [4, 5, 6])
        #expect(first.combo == 1)
        let second = game.tap(3)
        #expect(second.popped == [1, 2, 3])
        #expect(second.combo == 2)
        #expect(second.points == 60)
        #expect(game.bestCombo == 2)
    }

    @Test func clearingTheBoardGivesABonus() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .mint, direction: .up, position: GridPoint(1, 4)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(2, 0)),
        ], settings: small())
        let report = game.tap(3)
        #expect(report.clearedBoard)
        #expect(report.points == 130)
    }

    @Test func bombsBlowUpTheirNeighboursAndStonesBreak() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .mint, direction: .up, kind: .bomb, position: GridPoint(1, 4)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(2, 0)),
            Piece(id: 4, color: .lemon, direction: .up, position: GridPoint(1, 3)),
            Piece(id: 5, color: .grape, direction: .up, kind: .stone, position: GridPoint(3, 4)),
            Piece(id: 6, color: .orange, direction: .up, position: GridPoint(4, 0)),
        ], settings: small())
        let report = game.tap(3)
        #expect(report.popped == [1, 2, 3])
        #expect(report.exploded == [4])
        #expect(report.brokenStones == [5])
        #expect(game.pieces.keys.sorted() == [6])
    }

    @Test func stonesCannotMoveOrMatch() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, kind: .stone, position: GridPoint(0, 4)),
            Piece(id: 2, color: .mint, direction: .up, position: GridPoint(1, 4)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(2, 0)),
        ], settings: small())
        #expect(game.tap(1).move == .ignored)
        #expect(!game.tap(3).didPop)
        #expect(game.tap(99).move == .ignored)
    }

    @Test func rainbowsCountAsEveryColorButNotAlone() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .lemon, direction: .up, kind: .rainbow, position: GridPoint(1, 4)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(2, 0)),
        ], settings: small())
        #expect(game.tap(3).popped == [1, 2, 3])

        let rainbows = SlideGame(pieces: (0..<3).map {
            Piece(id: $0 + 1, color: .mint, direction: .up, kind: .rainbow, position: GridPoint($0, 4))
        }, settings: small())
        #expect(rainbows.matchedIDs().isEmpty)
    }

    @Test func celebrationGrowsWithTheMove() {
        typealias Report = SlideGame.Report
        #expect(Report(move: .ignored).celebration == 0)
        #expect(Report(move: .ignored, popped: [1, 2, 3], combo: 1).celebration == 1)
        #expect(Report(move: .ignored, popped: [1, 2, 3, 4], combo: 1).celebration == 2)
        #expect(Report(move: .ignored, popped: [1, 2, 3], combo: 2).celebration == 2)
        #expect(Report(move: .ignored, popped: [1, 2, 3], exploded: [4], combo: 1).celebration == 3)
        #expect(Report(move: .ignored, popped: [1, 2, 3], combo: 3).celebration == 3)
        #expect(Report(move: .ignored, popped: [1, 2, 3], combo: 5).celebration == 4)
        #expect(Report(move: .ignored, popped: [1, 2, 3], combo: 1, clearedBoard: true).celebration == 5)
    }

    @Test func comboStaysLiveForAFewSeconds() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .mint, direction: .up, position: GridPoint(1, 4)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(2, 0)),
            Piece(id: 4, color: .grape, direction: .up, position: GridPoint(4, 0)),
        ], settings: small())
        #expect(!game.comboIsLive)
        _ = game.tap(3)
        #expect(game.comboIsLive)
        _ = game.advance(by: 3.5)
        #expect(!game.comboIsLive)
    }

    @Test func hintFindsAPoppingSlide() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .mint, direction: .up, position: GridPoint(1, 4)),
            Piece(id: 4, color: .lemon, direction: .up, position: GridPoint(4, 2)),
            Piece(id: 3, color: .mint, direction: .down, position: GridPoint(2, 0)),
        ], settings: small())
        #expect(game.hint() == 3)
        _ = game.tap(3)
        #expect(game.hint() == nil)
    }

    @Test func hammerRemovesAnything() {
        var game = SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, kind: .stone, position: GridPoint(0, 4)),
        ], settings: small())
        let first = game.smash(1)
        let again = game.smash(1)
        #expect(first)
        #expect(!again)
        #expect(game.pieces.isEmpty)
        #expect(game.score == 0)
    }

    @Test func slowDownHalvesTheArrivalSpeed() {
        var normal = SlideGame(pieces: [], settings: small())
        var slowed = normal
        slowed.slowDown(for: 10)
        #expect(slowed.isSlowedDown)
        var normalSpawns = 0
        var slowSpawns = 0
        for _ in 0..<40 {
            normalSpawns += normal.advance(by: 0.25).filter { if case .spawned = $0 { true } else { false } }.count
            slowSpawns += slowed.advance(by: 0.25).filter { if case .spawned = $0 { true } else { false } }.count
        }
        #expect(normalSpawns >= 3)
        #expect(slowSpawns < normalSpawns)
        #expect(!slowed.isSlowedDown)
    }

    @Test func startsWithAFairBoardWithoutLines() {
        let game = SlideGame(seed: 7)
        #expect(game.pieces.count == 5)
        #expect(game.matchedIDs().isEmpty)
        #expect(game.colorCount == 3)
        #expect(game.unlockedKinds.isEmpty)
        #expect(game.status == .playing)
    }

    @Test func candiesKeepArrivingUntilTheBoardIsFull() {
        var game = SlideGame(seed: 3)
        var spawned = 0
        var warned = 0
        var full = false
        for _ in 0..<4000 where !full {
            for event in game.advance(by: 0.25) {
                switch event {
                case .spawned: spawned += 1
                case .warn: warned += 1
                case .boardFull: full = true
                case .stageUp: break
                }
            }
            #expect(game.matchedIDs().isEmpty)
        }
        #expect(full)
        #expect(game.isOver)
        #expect(spawned == game.width * game.height - game.settings.startCandies)  // fills every free cell
        #expect(warned >= spawned)
        #expect(game.advance(by: 1).isEmpty)
        #expect(game.tap(game.sortedPieces[0].id).move == .ignored)
    }

    @Test func reviveClearsPartOfTheBoardOnce() {
        var game = SlideGame(seed: 4)
        while !game.isOver { _ = game.advance(by: 0.5) }
        let before = game.pieces.count
        #expect(game.canRevive)
        let removed = game.revive()
        #expect(removed.count >= before / 3)
        #expect(game.pieces.count == before - removed.count)
        #expect(game.status == .playing)
        #expect(!game.canRevive)
        #expect(game.revive().isEmpty)
    }

    @Test func playingThroughStagesSpeedsUp() {
        var settings = SlideGame.Settings()
        settings.popsPerStage = 3
        var game = SlideGame(seed: 5, settings: settings)
        var stages: [Int] = []
        var taps = 0
        while !game.isOver, taps < 3000 {
            // Greedy player: tap the first candy whose slide makes a line, otherwise any movable one.
            let movable = game.sortedPieces.filter(\.canMove)
            let good = movable.first { piece in
                var trial = game
                return trial.tap(piece.id).didPop
            }
            if let id = (good ?? movable.first)?.id { _ = game.tap(id) }
            taps += 1
            for event in game.advance(by: 0.6) {
                if case .stageUp(let stage) = event { stages.append(stage) }
            }
        }
        #expect(game.score > 0)
        #expect(!stages.isEmpty)
        #expect(game.interval < game.settings.startInterval)
        #expect(game.colorCount == 4)  // capped at maxColors on the small board
        #expect(game.unlockedKinds.contains(.bomb))
        #expect(game.coinsEarned == game.score / 25)
    }
}
