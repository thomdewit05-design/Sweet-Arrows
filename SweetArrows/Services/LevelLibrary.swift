import Foundation
import SweetArrowsCore

/// Loads the solver-approved levels shipped in Resources/levels and the daily puzzles in Resources/daily.
@MainActor
final class LevelLibrary {
    let count: Int
    let dailyCount: Int
    private let bundle: Bundle
    private var cache: [String: Level] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        count = bundle.urls(forResourcesWithExtension: "json", subdirectory: "levels")?.count ?? 0
        dailyCount = bundle.urls(forResourcesWithExtension: "json", subdirectory: "daily")?.count ?? 0
    }

    func level(_ id: Int) -> Level? {
        load("level-" + String(format: "%03d", id), folder: "levels")
    }

    /// Daily puzzle number `number` (1...dailyCount).
    func dailyPuzzle(_ number: Int) -> Level? {
        load("daily-" + String(format: "%03d", number), folder: "daily")
    }

    private func load(_ name: String, folder: String) -> Level? {
        if let cached = cache[name] { return cached }
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: folder),
              let data = try? Data(contentsOf: url),
              let level = try? Level.decode(from: data)
        else { return nil }
        cache[name] = level
        return level
    }
}
