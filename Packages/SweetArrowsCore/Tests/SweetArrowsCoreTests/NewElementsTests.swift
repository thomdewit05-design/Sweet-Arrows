import Testing
@testable import SweetArrowsCore

@Suite("Bumpers, bombs, color changers, locks and the clock")
struct NewElementsTests {
    private func solved(_ level: Level) -> Solver.Analysis? {
        if case .solved(let a) = Solver(level: level).solve() { return a }
        return nil
    }

    private func replayWins(_ level: Level, _ solution: [Int]) -> Bool {
        var game = Game(level: level)
        for id in solution where !game.tap(id).countsAsMove { return false }
        return game.status == .won
    }

    // MARK: Bumpers

    @Test func bumperBendsTheCandy() throws {
        // Candy at (0,1) flies right into a "/" bumper at (2,1) and turns up.
        var level = makeLevel([".  .  .", ">s .  .", ".  .  ."])
        level.mirrors = [Mirror(GridPoint(2, 1), .slash)]
        var game = Game(level: level)
        let launch = try #require(game.tap(1).result.launched)
        #expect(launch.route == [GridPoint(1, 1), GridPoint(2, 1), GridPoint(2, 0), GridPoint(2, -1)])
    }

    @Test func candyAfterTheTurnBlocks() {
        // After turning up at (2,1) the way is blocked by a candy at (2,0).
        // Candy 1 is the lemon at (2,0), candy 2 the strawberry at (0,1).
        var level = makeLevel([".  .  ^l", ">s .  .", ".  .  ."])
        level.mirrors = [Mirror(GridPoint(2, 1), .slash)]
        var game = Game(level: level)
        #expect(game.tap(2).result.bounced?.obstacle == .candy(1))
        #expect(game.tap(1).result.launched != nil)
        #expect(game.tap(2).result.launched != nil)
    }

    @Test func barsCannotTurn() {
        var level = Level(id: 1, width: 4, height: 2, candies: [
            Candy(id: 1, color: .mint, position: GridPoint(0, 0), direction: .right, bar: .horizontal),
        ])
        level.mirrors = [Mirror(GridPoint(3, 0), .backslash)]
        var game = Game(level: level)
        #expect(game.tap(1).result.bounced?.obstacle == .mirror(GridPoint(3, 0)))
    }

    @Test func mirrorDeflectionTable() {
        let slash = Mirror(GridPoint(0, 0), .slash)
        let back = Mirror(GridPoint(0, 0), .backslash)
        #expect(slash.deflect(.up) == .right)
        #expect(slash.deflect(.left) == .down)
        #expect(back.deflect(.up) == .left)
        #expect(back.deflect(.right) == .down)
    }

    @Test func solverFollowsBumpers() throws {
        var level = makeLevel([".  .  ^l .", ">s .  .  .", ".  ^l ^s ^l", ".  ^s ^s ."])
        level.mirrors = [Mirror(GridPoint(2, 1), .slash)]
        let a = try #require(solved(level))
        #expect(replayWins(level, a.solution))
    }

    // MARK: Bombs

    @Test func bombClearsNeighboursWithoutFillingTheJar() throws {
        let level = makeLevel([".  .  .", "<m ^s >g", ".  vb ."], features: [2: [.bomb]])
        var game = Game(level: level)
        let report = game.tap(2)
        #expect(report.result.launched != nil)
        #expect(report.exploded == [1, 3, 4])
        #expect(game.candies.isEmpty)
        #expect(game.bag.slots == [.strawberry])
        #expect(report.status == .won)
    }

    @Test func solverUsesBombs() throws {
        // Without the bomb the two lemons block each other; the bomb takes one of them away.
        let level = makeLevel([">l <l ^s", ".  .  ."], features: [3: [.bomb]])
        let a = try #require(solved(level))
        #expect(replayWins(level, a.solution))
    }

    // MARK: Color changers

    @Test func colorChangerCyclesAfterEveryMove() {
        let level = makeLevel(["^s ^l ^m", "^s ^l ^m"], features: [1: [.colorChanger]])
        var game = Game(level: level)
        #expect(game.candies[1]?.color == .strawberry)
        let report = game.tap(3)
        #expect(report.recolored[1] == .lemon)
        game.tap(6)
        #expect(game.candies[1]?.color == .mint)
        game.tap(2)
        #expect(game.candies[1]?.color == .strawberry)
    }

    @Test func colorChangerUsesTheLevelPalette() {
        var level = makeLevel(["^s ^l ^m", "^s ^l ^m"], features: [1: [.colorChanger]])
        level.changerColors = [.strawberry, .grape]
        var game = Game(level: level)
        game.tap(3)
        #expect(game.candies[1]?.color == .grape)
    }

    @Test func solverTracksChangingColors() throws {
        let level = makeLevel(["^s ^l ^m ^s", "^l ^m ^s ^l ^m"].map { $0 }, bag: 4, features: [1: [.colorChanger]])
        if case .solved(let a) = Solver(level: level).solve() {
            #expect(replayWins(level, a.solution))
        }
    }

    // MARK: Locks

    @Test func lockedCandyWaitsForTheKey() {
        let level = makeLevel(["^s ^s ^s", ">l .  ."], features: [4: [.key], 1: [.locked]])
        var game = Game(level: level)
        #expect(game.tap(1).result == .locked(candyID: 1))
        #expect(game.hearts == 3)
        let report = game.tap(4)
        #expect(report.unlocked == [1])
        #expect(game.tap(1).result.launched != nil)
    }

    @Test func solverRespectsLocks() throws {
        let level = makeLevel(["^s ^s ^s", ".  ^l ^l", ".  .  ^l"], features: [1: [.locked], 2: [.locked], 6: [.key]])
        let a = try #require(solved(level))
        let keyIndex = try #require(a.solution.firstIndex(of: 6))
        #expect(a.solution.firstIndex(of: 1)! > keyIndex)
        #expect(replayWins(level, a.solution))
    }

    @Test func validationNeedsAKey() {
        let level = makeLevel(["^s ^s ^s", ". . ."], features: [1: [.locked]])
        #expect(throws: Level.ValidationError.lockWithoutKey) { try level.validate() }
    }

    // MARK: Clock

    @Test func timeRunsOut() {
        var game = Game(level: makeLevel(["^s ^s ^s", ". . ."]))
        game.tap(1)
        game.timeRanOut()
        #expect(game.status == .lost(.outOfTime))
        #expect(game.tap(2).result == .ignored)
        game.undo()
        #expect(game.status == .lost(.outOfTime))  // undo is no way around the clock
        game.continueAfterTimeout()
        #expect(game.status == .playing)
        game.tap(1)
        game.tap(2)
        game.tap(3)
        game.timeRanOut()
        #expect(game.status == .won)  // too late to lose
    }

    @Test func timeLimitRoundTrips() throws {
        var level = makeLevel(["^s ^s ^s", ". . ."])
        level.timeLimit = 45
        level.mirrors = [Mirror(GridPoint(1, 1), .backslash)]
        let decoded = try Level.decode(from: level.encoded())
        #expect(decoded.timeLimit == 45)
        #expect(decoded.mirrors == level.mirrors)
        level.timeLimit = 2
        #expect(throws: Level.ValidationError.badTimeLimit) { try level.validate() }
    }

    @Test func newElementsAreListed() {
        var level = makeLevel(["^s ^s ^s", "^l ^l ^l"], features: [1: [.bomb], 2: [.colorChanger], 3: [.key], 4: [.locked]])
        level.mirrors = [Mirror(GridPoint(0, 0), .slash)]
        #expect(level.elements == [.mirror, .lock, .bomb, .colorChanger])
    }
}
