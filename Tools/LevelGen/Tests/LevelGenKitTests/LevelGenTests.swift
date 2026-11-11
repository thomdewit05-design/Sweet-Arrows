import Testing
@testable import LevelGenKit
@testable import SweetArrowsCore

@Suite("Hand-made tutorial")
struct TutorialTests {
    @Test func allTenAreApprovedAndUnlosable() throws {
        let levels = try LevelPack.tutorial()
        #expect(levels.count == 10)
        for level in levels {
            #expect(level.tutorial)
            #expect(level.stats?.pitfalls == 0)
        }
        #expect(LevelPack.verify(levels).isEmpty)
    }

    @Test func asciiRoundTrip() throws {
        let rows = [">sc .  #", "^lw vmi <br"]
        let level = try AsciiLevel.parse(rows, id: 1)
        #expect(level.candies.count == 4)
        #expect(level.poles == [GridPoint(2, 0)])
        #expect(level.candies[0].features == [.caramel])
        #expect(level.candies[3].features == [.rotating])
        let again = try AsciiLevel.parse(AsciiLevel.render(level), id: 1)
        #expect(again == level)
    }

    @Test func badTokenIsRejected() {
        #expect(throws: AsciiLevel.ParseError.self) {
            try AsciiLevel.parse(["?x"], id: 1)
        }
    }
}

@Suite("Curve")
struct CurveTests {
    @Test func sawtooth() {
        #expect(Curve.slot(for: 5) == .tutorial)
        #expect((11...14).allSatisfy { Curve.slot(for: $0) == .easy })
        #expect(Curve.slot(for: 15) == .medium)
        #expect(Curve.slot(for: 16) == .hard)
        #expect(Curve.slot(for: 17) == .easy)
    }

    @Test func risesOverTime() {
        #expect(Curve.baseline(for: 11) < Curve.baseline(for: 150))
        #expect(Curve.baseline(for: 150) < Curve.baseline(for: 300))
        let hard = Curve.plan(for: 16)
        let easy = Curve.plan(for: 17)
        #expect(hard.target > easy.target)
    }

    @Test func worldIntroFeaturesNewElement() {
        let plan = Curve.plan(for: World(id: 3).firstLevel)
        #expect(plan.featured == .chocolateBar)
        #expect(plan.slot == .easy)
    }
}

@Suite("Generator")
struct GeneratorTests {
    private let fast = Generator(
        solverConfiguration: .init(nodeBudget: 200_000, solutionCap: 1_000, countingBudget: 20_000),
        attempts: 12, tolerance: 8
    )

    @Test func buildIsSolvableByConstruction() {
        var rng = SplitMix64(seed: 42)
        var params = Generator.Parameters(width: 6, height: 7, candies: 24, colors: 4, bagLimit: 3)
        params.poles = 2
        params.bars = 2
        params.caramel = 0.15
        params.rotating = 0.1
        params.iced = 0.2
        params.wrapped = 0.2
        var built = 0
        for _ in 0..<20 {
            guard let level = fast.build(params, id: 99, rng: &rng) else { continue }
            built += 1
            #expect((try? level.validate()) != nil)
            guard case .solved = Solver(level: level, configuration: fast.solverConfiguration).solve() else {
                let map = AsciiLevel.render(level).joined(separator: "\n")
                Issue.record("built level was not proven solvable:\n\(map)")
                continue
            }
        }
        #expect(built >= 10)
    }

    @Test func deterministicForSeed() {
        let plan = Curve.plan(for: 23)
        let a = fast.level(for: plan, seed: 7)
        let b = fast.level(for: plan, seed: 7)
        #expect(a != nil)
        #expect(a == b)
    }

    @Test func featuredElementAppears() throws {
        for id in (2...7).map({ World(id: $0).firstLevel }) {
            let plan = Curve.plan(for: id)
            let level = try #require(fast.level(for: plan, seed: 1))
            #expect(level.elements.contains(plan.featured!), "level \(id) should show \(plan.featured!)")
        }
    }

    @Test func colorsNeverOverflowTheJar() throws {
        var rng = SplitMix64(seed: 3)
        for limit in 2...4 {
            let colors = try #require(fast.dealColors(count: 30, colors: 5, bagLimit: limit, rng: &rng))
            var bag = Bag(capacity: 8)
            for color in colors {
                bag.insert(color)
                #expect(bag.slots.count <= limit)
            }
            #expect(bag.isEmpty)
        }
    }

    @Test func dailyPuzzlesAreSolvableAndUseAllElements() async throws {
        let daily = try await LevelPack.generateDaily(count: 3, seed: 5, generator: fast)
        #expect(daily.map(\.id) == [100_001, 100_002, 100_003])
        #expect(LevelPack.verify(daily, daily: true).isEmpty)
        #expect(LevelPack.dailyPlan(number: 1).elements.count == 6)
        #expect(LevelPack.dailyPlan(number: 7).target > LevelPack.dailyPlan(number: 1).target)
        #expect(LevelPack.dailyFileName(for: 7) == "daily-007.json")
    }

    @Test func verifyCatchesTamperedLevels() throws {
        var levels = try LevelPack.tutorial()
        levels[1].stats?.solution.reverse()
        let problems = LevelPack.verify(levels)
        #expect(problems.contains { $0.contains("level 2") })
    }
}
