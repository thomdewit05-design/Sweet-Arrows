import Foundation
import LevelGenKit
import SweetArrowsCore

// Usage:
//   swift run levelgen                       generate all levels (default 300) + report
//   swift run levelgen generate --count 300 --seed 12345
//   swift run levelgen verify                re-check every level file with the solver
//   swift run levelgen show 42               print a level as ASCII with its stats

let usage = """
usage: levelgen [generate] [--count N] [--seed N] [--out DIR] [--report FILE]
       levelgen verify [--out DIR]
       levelgen show <level> [--out DIR]
"""

func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    for _ in 0..<6 {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("project.yml").path) { return url }
        url.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

let rawArguments = Array(CommandLine.arguments.dropFirst())
let command = rawArguments.first.map { $0.hasPrefix("-") ? "generate" : $0 } ?? "generate"
let arguments = rawArguments.first == command ? Array(rawArguments.dropFirst()) : rawArguments

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let root = repositoryRoot()
let levelsDirectory = option("--out").map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent("SweetArrows/Resources/levels")
let reportFile = option("--report").map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent("docs/level-report.md")
let seed = option("--seed").flatMap { UInt64($0) } ?? LevelPack.defaultSeed
let count = option("--count").flatMap { Int($0) } ?? 300

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

switch command {
case "generate":
    let start = Date()
    do {
        let tutorial = try LevelPack.tutorial()
        print("✓ \(tutorial.count) hand-made tutorial levels approved")
        let done = Counter()
        let generated = try await LevelPack.generate(
            (tutorial.count + 1)...max(count, tutorial.count + 1), total: count, seed: seed
        ) { level in
            let n = done.increment()
            if n % 10 == 0 { print("  \(n) levels generated (last: \(level.id), difficulty \(level.stats?.difficulty ?? 0))") }
        }
        let levels = Array((tutorial + generated).prefix(count))
        let problems = LevelPack.verify(levels)
        guard problems.isEmpty else { fail(problems.joined(separator: "\n")) }
        try LevelPack.write(levels, to: levelsDirectory)
        try FileManager.default.createDirectory(
            at: reportFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Report.markdown(levels, seed: seed).write(to: reportFile, atomically: true, encoding: .utf8)
        let seconds = Int(Date().timeIntervalSince(start))
        print("✓ wrote \(levels.count) levels to \(levelsDirectory.path) in \(seconds)s")
        print("✓ report: \(reportFile.path)")
    } catch {
        fail("✗ \(error)")
    }

case "verify":
    do {
        let levels = try LevelPack.read(from: levelsDirectory)
        guard !levels.isEmpty else { fail("✗ no levels in \(levelsDirectory.path)") }
        let problems = LevelPack.verify(levels)
        guard problems.isEmpty else { fail("✗ " + problems.joined(separator: "\n✗ ")) }
        print("✓ all \(levels.count) levels pass the solver check")
    } catch {
        fail("✗ \(error)")
    }

case "show":
    guard let id = arguments.first.flatMap({ Int($0) }) else { fail(usage) }
    do {
        let url = levelsDirectory.appendingPathComponent(LevelPack.fileName(for: id))
        let level = try Level.decode(from: Data(contentsOf: url))
        print("Level \(level.id)  \(level.width)×\(level.height)  jar \(level.bagCapacity)  hearts \(level.hearts)"
            + (level.hard ? "  HARD" : "") + (level.tutorial ? "  tutorial" : ""))
        AsciiLevel.render(level).forEach { print("  " + $0) }
        if let stats = level.stats {
            print("difficulty \(stats.difficulty)  taps \(stats.solutionLength)  traps \(stats.pitfalls)  "
                + "solutions \(stats.solutionsCapped ? "≥" : "")\(stats.solutions)  peak jar \(stats.peakBag)")
            print("solution: \(stats.solution.map(String.init).joined(separator: " "))")
        }
    } catch {
        fail("✗ \(error)")
    }

default:
    fail(usage)
}

final class Counter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
