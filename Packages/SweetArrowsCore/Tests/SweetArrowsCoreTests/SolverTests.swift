import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Solver")
struct SolverTests {
    private func analysis(_ level: Level) -> Solver.Analysis? {
        if case .solved(let a) = Solver(level: level).solve() { return a }
        return nil
    }

    /// Plays the solver's solution through the real rules and checks it wins without a bounce.
    private func replay(_ level: Level, _ solution: [Int]) -> Bool {
        var game = Game(level: level)
        for id in solution {
            let report = game.tap(id)
            guard report.countsAsMove else { return false }
        }
        return game.status == .won
    }

    @Test func solvesSimpleChain() throws {
        let level = makeLevel([">s >s >s"])
        let a = try #require(analysis(level))
        #expect(a.solution == [3, 2, 1])
        #expect(a.pitfalls == 0)
        #expect(a.solutions == 1)
        #expect(replay(level, a.solution))
    }

    @Test func deadlockIsUnsolvable() {
        // Two candies facing each other can never leave.
        let level = makeLevel([">s <s ^s"])
        guard case .unsolvable = Solver(level: level).solve() else {
            Issue.record("expected unsolvable")
            return
        }
    }

    @Test func poleTrapIsUnsolvable() {
        let level = makeLevel([">s # ^s ^s"])
        guard case .unsolvable = Solver(level: level).solve() else {
            Issue.record("expected unsolvable")
            return
        }
    }

    @Test func bagOverflowIsUnsolvable() {
        // Bag of 3 and the only order forces three different colors in at once.
        let level = makeLevel(
            [">s >l >m >s >l >m >s >l >m"].map { $0 },
            bag: 3
        )
        // Order is forced right-to-left: m, l, s -> 3 different colors = full.
        guard case .unsolvable = Solver(level: level).solve() else {
            Issue.record("expected unsolvable")
            return
        }
    }

    @Test func countsPitfalls() throws {
        // Free candies: s s l l s l in a row of up-arrows, bag of 3.
        // Taking s, l first leaves 1 slot: any non-matching third color loses.
        let level = makeLevel(["^s ^l ^m ^s ^l ^m ^s ^l ^m"], bag: 3)
        let a = try #require(analysis(level))
        #expect(a.pitfalls > 0)
        #expect(a.peakBag <= 2)
        #expect(replay(level, a.solution))
    }

    @Test func handlesCaramelRotatingIceAndBars() throws {
        let candies = [
            Candy(id: 1, color: .mint, position: GridPoint(0, 0), direction: .up, features: [.caramel]),
            Candy(id: 2, color: .mint, position: GridPoint(1, 0), direction: .up),
            Candy(id: 3, color: .mint, position: GridPoint(1, 1), direction: .left, features: [.rotating]),
            Candy(id: 4, color: .lemon, position: GridPoint(0, 1), direction: .up, features: [.iced]),
            Candy(id: 5, color: .lemon, position: GridPoint(0, 2), direction: .down, bar: .horizontal),
            Candy(id: 6, color: .lemon, position: GridPoint(2, 0), direction: .right, features: [.wrapped]),
        ]
        let level = Level(id: 1, width: 3, height: 3, candies: candies)
        try level.validate()
        let a = try #require(analysis(level))
        #expect(a.solution.count == 7)  // 6 candies + 1 caramel crack
        #expect(replay(level, a.solution))
    }

    @Test func hintFromMidGame() throws {
        let level = makeLevel(["^s ^l ^m ^s ^l ^m ^s ^l ^m"], bag: 3)
        var game = Game(level: level)
        game.tap(1)  // strawberry in bag
        let hint = try #require(Solver(game: game, configuration: .hint).nextMove())
        game.tap(hint)
        #expect(game.status == .playing)
        // Following hints wins.
        while game.status == .playing {
            let next = try #require(Solver(game: game, configuration: .hint).nextMove())
            game.tap(next)
        }
        #expect(game.status == .won)
    }

    @Test func noHintWhenLost() {
        let level = makeLevel(["^s ^l ^m ^s ^l ^m ^s ^l ^m"], bag: 4)
        var game = Game(level: level)
        game.tap(1); game.tap(2)  // s l in a bag of 4
        // Taking mint now leaves one slot and loses on the next tap; the hint must avoid it.
        let hint = Solver(game: game, configuration: .hint).nextMove()
        #expect(hint != nil)
        #expect(hint.map { game.candies[$0]?.color } != .mint)
        let dead = makeLevel([">s <s ^s"])
        #expect(Solver(level: dead, configuration: .hint).nextMove() == nil)
    }

    @Test func budgetExhaustionReportsUnknown() {
        let row = (0..<6).map { _ in "^s ^l ^m" }.joined(separator: " ")
        let level = makeLevel([row, row], bag: 7)
        let tiny = Solver.Configuration(nodeBudget: 3, solutionCap: 10, countingBudget: 10)
        if case .unknown = Solver(level: level, configuration: tiny).solve() {
            // expected
        } else {
            Issue.record("expected unknown with a tiny budget")
        }
    }

    @Test func solutionCountIsCapped() throws {
        let row = (0..<6).map { _ in "^s ^l ^m" }.joined(separator: " ")
        let level = makeLevel([row], bag: 7)
        let config = Solver.Configuration(nodeBudget: 100_000, solutionCap: 50, countingBudget: 100_000)
        guard case .solved(let a) = Solver(level: level, configuration: config).solve() else {
            Issue.record("expected solved")
            return
        }
        #expect(a.solutions == 50)
        #expect(a.solutionsCapped)
    }
}

@Suite("Level")
struct LevelTests {
    @Test func jsonRoundTrip() throws {
        var level = makeLevel([">s .  #", "^s ^s vl", "vl vl ."], features: [1: [.caramel, .wrapped]])
        level.candies.append(Candy(id: 99, color: .lemon, position: GridPoint(0, 3), direction: .right, bar: .horizontal))
        level.height = 4
        level.candies.removeAll { $0.id == 6 }
        let data = try level.encoded()
        let decoded = try Level.decode(from: data)
        #expect(decoded == level)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"at\""))
        #expect(!text.contains("tutorial"))
    }

    @Test func decodesMinimalJSON() throws {
        let json = #"{"id":3,"width":2,"height":1,"candies":[{"id":1,"color":"mint","at":[0,0],"dir":"left"}]}"#
        let level = try Level.decode(from: Data(json.utf8))
        #expect(level.bagCapacity == 5)
        #expect(level.hearts == 3)
        #expect(level.candies[0].features.isEmpty)
        #expect(level.poles.isEmpty)
    }

    @Test func validationCatchesProblems() {
        #expect(throws: Level.ValidationError.colorCountNotMultipleOfThree(.strawberry)) {
            try makeLevel([">s >s", ". ."]).validate()
        }
        var overlap = makeLevel(["^s ^s ^s", ". . ."])
        overlap.candies[1].position = GridPoint(0, 0)
        #expect(throws: Level.ValidationError.overlap(GridPoint(0, 0))) { try overlap.validate() }

        var outside = makeLevel(["^s ^s ^s", ". . ."])
        outside.candies[2].position = GridPoint(5, 0)
        #expect(throws: Level.ValidationError.outOfBounds(candyID: 3)) { try outside.validate() }

        let lonelyIce = makeLevel(["^s . ^s . ^s", ". . . . ."], features: [1: [.iced]])
        #expect(throws: Level.ValidationError.iceWithoutNeighbours(candyID: 1)) { try lonelyIce.validate() }

        #expect(throws: Level.ValidationError.badSize) {
            try Level(id: 1, width: 1, height: 1, candies: []).validate()
        }
    }

    @Test func elementsAreListed() {
        let level = makeLevel(["^s # ^s ^s"], features: [1: [.rotating]])
        #expect(level.elements == [.pole, .rotating])
    }

    @Test func approveFillsStats() throws {
        let level = makeLevel(["^s ^l ^m ^s ^l ^m ^s", "^l ^m . . . . ."], bag: 4)
        let approved = try #require(Difficulty.approve(level))
        let stats = try #require(approved.stats)
        #expect(stats.solutionLength == 9)
        #expect(stats.difficulty > 0 && stats.difficulty <= 100)
        #expect(Difficulty.approve(makeLevel([">s <s ^s"])) == nil)
    }
}

@Suite("Worlds")
struct WorldTests {
    @Test func levelToWorld() {
        #expect(World.number(forLevel: 1) == 1)
        #expect(World.number(forLevel: 20) == 1)
        #expect(World.number(forLevel: 21) == 2)
        #expect(World.number(forLevel: 300) == 15)
        #expect(World(id: 9).theme == .gummyGarden)
        #expect(World(id: 9).season == 2)
        #expect(World(id: 2).levels == 21...40)
    }

    @Test func elementsUnlockPerWorld() {
        #expect(World(id: 1).availableElements.isEmpty)
        #expect(World(id: 2).availableElements == [.pole])
        #expect(World(id: 2).newElement == .pole)
        #expect(World(id: 7).newElement == .rotating)
        #expect(World(id: 7).availableElements.count == 6)
        #expect(World(id: 8).newElement == nil)
        #expect(World(id: 10).availableElements.count == 6)
    }

    @Test func everyColorHasItsOwnShape() {
        #expect(Set(CandyColor.allCases.map(\.shape)).count == CandyColor.allCases.count)
    }
}
