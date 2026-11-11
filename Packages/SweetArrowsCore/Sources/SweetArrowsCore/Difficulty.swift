import Foundation

/// Turns a level and its solver analysis into one number from 0 (trivial) to 100 (brutal).
///
/// Difficulty = board size + number of colors + how many tempting moves are traps
/// + how full the bag gets + how many special elements are in play.
public enum Difficulty {
    public static func score(level: Level, analysis: Solver.Analysis) -> Double {
        let candies = Double(level.candies.count)
        let colors = Double(Set(level.candies.map(\.color)).count)
        let length = Double(max(analysis.solution.count, 1))

        let size = min(candies / 54, 1) * 25
        let palette = max(colors - 1, 0) / 5 * 15
        let traps = min(Double(analysis.pitfalls) / length / 1.2, 1) * 30
        let tightness = Double(analysis.peakBag) / Double(max(level.bagCapacity - 1, 1)) * 15
        let elements = min(Double(level.elements.count) * 3, 15)
        // Few solutions = less room for error.
        let narrow: Double = analysis.solutionsCapped ? 0 : max(0, 1 - log10(Double(max(analysis.solutions, 1))) / 4) * 5
        // Tighter bags make everything harder.
        let bag = Double(max(5 - level.bagCapacity, 0)) * 3

        let total = size + palette + traps + tightness + elements + narrow + bag
        return (min(max(total, 0), 100) * 10).rounded() / 10
    }

    /// `level` with solver stats filled in, or nil if the solver cannot approve it.
    public static func approve(_ level: Level, configuration: Solver.Configuration = .init()) -> Level? {
        guard (try? level.validate()) != nil else { return nil }
        guard case .solved(let analysis) = Solver(level: level, configuration: configuration).solve() else {
            return nil
        }
        var approved = level
        approved.stats = LevelStats(
            solutionLength: analysis.solution.count,
            pitfalls: analysis.pitfalls,
            solutions: analysis.solutions,
            solutionsCapped: analysis.solutionsCapped,
            peakBag: analysis.peakBag,
            difficulty: score(level: level, analysis: analysis),
            solution: analysis.solution
        )
        return approved
    }
}
