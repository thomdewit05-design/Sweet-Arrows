import Testing
@testable import SweetArrowsCore

@Suite("Endless mode")
struct EndlessTests {
    @Test func startsWithAFairBoard() {
        let run = EndlessGame(seed: 1)
        #expect(run.game.candies.count == 8)
        #expect(run.status == .playing)
        #expect(run.stage == 0)
        #expect(run.colorCount == 3)
    }

    @Test func candiesKeepArrivingUntilTheBoardIsFull() {
        var run = EndlessGame(seed: 2)
        var spawned = 0
        var warned = 0
        var full = false
        for _ in 0..<2000 where !full {
            for event in run.advance(by: 0.25) {
                switch event {
                case .spawned: spawned += 1
                case .warn: warned += 1
                case .boardFull: full = true
                case .stageUp: break
                }
            }
        }
        #expect(full)
        #expect(run.status == .lost(.boardFull))
        #expect(spawned > 20)
        #expect(warned >= spawned)
        #expect(run.advance(by: 1).isEmpty)
    }

    @Test func everyBoardStaysSolvableIgnoringTheJar() {
        var run = EndlessGame(seed: 3)
        for _ in 0..<400 {
            _ = run.advance(by: 0.5)
            if run.isOver { break }
            // A fair board: some candy can always leave.
            let movable = run.game.remainingCandies.contains { run.game.trace(for: $0).isClear }
            #expect(movable || run.game.candies.isEmpty)
        }
    }

    @Test func scoringPopsAndCombos() {
        var run = EndlessGame(seed: 4)
        var popped = false
        // Play greedily: tap any candy whose route is clear.
        for _ in 0..<300 where !run.isOver {
            if let free = run.game.remainingCandies.first(where: { run.game.trace(for: $0).isClear }) {
                let report = run.tap(free.id)
                if case .launched(let launch) = report.result, launch.bag.didPop { popped = true }
            }
            _ = run.advance(by: 0.6)
        }
        #expect(run.score > 0)
        if popped { #expect(run.pops > 0 && run.bestCombo >= 1) }
    }

    @Test func gettingFasterAndRicher() {
        var run = EndlessGame(seed: 5)
        let slow = run.interval
        #expect(run.unlockedFeatures.isEmpty)
        // Pretend we are far into a run.
        for _ in 0..<1000 where !run.isOver {
            if let free = run.game.remainingCandies.first(where: { run.game.trace(for: $0).isClear }) {
                _ = run.tap(free.id)
            }
            _ = run.advance(by: 0.3)
        }
        if run.stage >= 3 {
            #expect(run.interval < slow)
            #expect(run.colorCount > 3)
            #expect(run.unlockedFeatures.contains(.bomb))
        }
    }

    @Test func reviveOnce() {
        var run = EndlessGame(seed: 6)
        while !run.isOver { _ = run.advance(by: 0.5) }
        let before = run.game.candies.count
        #expect(run.canRevive)
        let removed = run.revive()
        #expect(!removed.isEmpty)
        #expect(run.status == .playing)
        #expect(run.game.candies.count == before - removed.count)
        #expect(run.game.bag.isEmpty)
        #expect(!run.canRevive)
    }

    @Test func emptyBoardIsNotAWinInEndless() {
        var run = EndlessGame(seed: 7)
        var guardCount = 0
        while !run.game.candies.isEmpty, guardCount < 200, !run.isOver {
            guardCount += 1
            guard let free = run.game.remainingCandies.first(where: { run.game.trace(for: $0).isClear }) else { break }
            _ = run.tap(free.id)
        }
        #expect(run.status != .won)
    }

    @Test func bouncesCostNoHearts() {
        var game = Game(level: Level(id: 0, width: 3, height: 1, candies: []), endless: true)
        game.spawn(Candy(id: 1, color: .mint, position: GridPoint(0, 0), direction: .right))
        game.spawn(Candy(id: 2, color: .mint, position: GridPoint(2, 0), direction: .left))
        let hearts = game.hearts
        #expect(game.tap(1).result.bounced?.heartLost == false)
        #expect(game.hearts == hearts)
        #expect(game.spawn(Candy(id: 3, color: .mint, position: GridPoint(0, 0), direction: .up)) == nil)
    }

    @Test func sameSeedSameRun() {
        var a = EndlessGame(seed: 42)
        var b = EndlessGame(seed: 42)
        for _ in 0..<40 {
            #expect(a.advance(by: 0.5) == b.advance(by: 0.5))
        }
        #expect(a.game.remainingCandies == b.game.remainingCandies)
    }
}
