import Foundation
import SweetArrowsCore

/// Builds, writes, reads and verifies the full level set.
public enum LevelPack {
    public static let defaultSeed: UInt64 = 0x5EE7_A770_5000_0001

    public enum PackError: Error, CustomStringConvertible {
        case tutorialRejected(Int, stuck: [GridPoint])
        case tutorialCanBeLost(Int, pitfalls: Int)
        case generationFailed(Int)
        case verificationFailed([String])

        public var description: String {
            switch self {
            case let .tutorialRejected(id, stuck): "hand-made level \(id) is not solvable; stuck candies: \(stuck)"
            case let .tutorialCanBeLost(id, pitfalls): "tutorial level \(id) has \(pitfalls) losing moves"
            case .generationFailed(let id): "could not generate level \(id)"
            case .verificationFailed(let problems): "verification failed:\n" + problems.joined(separator: "\n")
            }
        }
    }

    public static func fileName(for id: Int) -> String {
        "level-" + String(format: "%03d", id) + ".json"
    }

    /// The tutorial levels, approved by the solver and checked to be unlosable.
    public static func tutorial() throws -> [Level] {
        try HandmadeLevels.levels().map { level in
            guard let approved = Difficulty.approve(level), let stats = approved.stats else {
                throw PackError.tutorialRejected(level.id, stuck: stuckCandies(level))
            }
            guard stats.pitfalls == 0 else { throw PackError.tutorialCanBeLost(level.id, pitfalls: stats.pitfalls) }
            return approved
        }
    }

    /// Candies that can never leave, ignoring the jar (for debugging hand-made levels).
    public static func stuckCandies(_ level: Level) -> [GridPoint] {
        var relaxed = level
        relaxed.bagCapacity = 8
        relaxed.candies = relaxed.candies.map { var c = $0; c.color = .mint; return c }
        var game = Game(level: relaxed)
        var progress = true
        while progress {
            progress = false
            for state in game.remainingCandies where game.path(for: state.id)?.isClear == true && !state.frozen {
                game.tap(state.id)
                progress = true
            }
        }
        return game.remainingCandies.map { $0.candy.position }
    }

    /// Generates levels `range` in parallel. Deterministic for a given seed.
    public static func generate(
        _ range: ClosedRange<Int>,
        total: Int,
        seed: UInt64 = defaultSeed,
        generator: Generator = Generator(),
        progress: (@Sendable (Level) -> Void)? = nil
    ) async throws -> [Level] {
        try await withThrowingTaskGroup(of: Level.self) { group in
            let workers = max(ProcessInfo.processInfo.activeProcessorCount, 1)
            var next = range.lowerBound
            func addTask() {
                let id = next
                next += 1
                group.addTask {
                    let plan = Curve.plan(for: id, total: total)
                    guard let level = generator.level(for: plan, seed: seed) else {
                        throw PackError.generationFailed(id)
                    }
                    progress?(level)
                    return level
                }
            }
            while next <= range.upperBound, next < range.lowerBound + workers { addTask() }
            var levels: [Level] = []
            for try await level in group {
                levels.append(level)
                if next <= range.upperBound { addTask() }
            }
            return levels.sorted { $0.id < $1.id }
        }
    }

    // MARK: Files

    public static func write(_ levels: [Level], to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in existing where name.hasPrefix("level-") && name.hasSuffix(".json") {
            try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        for level in levels {
            var data = try level.encoded(pretty: false)
            data.append(0x0A)
            try data.write(to: directory.appendingPathComponent(fileName(for: level.id)))
        }
    }

    public static func read(from directory: URL) throws -> [Level] {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("level-") && $0.hasSuffix(".json") }
            .sorted()
        return try names.map { try Level.decode(from: Data(contentsOf: directory.appendingPathComponent($0))) }
    }

    /// Re-runs the solver on every level file. Nothing ships without passing this.
    public static func verify(_ levels: [Level]) -> [String] {
        var problems: [String] = []
        let ids = levels.map(\.id)
        if !levels.isEmpty, ids != Array(1...levels.count) {
            problems.append("level ids are not 1...\(levels.count) without gaps")
        }
        for level in levels {
            do {
                try level.validate()
            } catch {
                problems.append("level \(level.id): \(error)")
                continue
            }
            guard let stats = level.stats else {
                problems.append("level \(level.id): no solver stats")
                continue
            }
            // The stored solution must win under the real rules without a single bounce.
            var game = Game(level: level)
            for id in stats.solution where game.status == .playing {
                if !game.tap(id).countsAsMove {
                    problems.append("level \(level.id): stored solution bounces at candy \(id)")
                    break
                }
            }
            if game.status != .won {
                problems.append("level \(level.id): stored solution does not win")
            }
            if level.tutorial, stats.pitfalls > 0 {
                problems.append("level \(level.id): tutorial level can be lost")
            }
        }
        return problems
    }
}
