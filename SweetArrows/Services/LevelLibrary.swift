import Foundation
import SweetArrowsCore

/// Loads the solver-approved levels shipped in Resources/levels.
@MainActor
final class LevelLibrary {
    let count: Int
    private let bundle: Bundle
    private var cache: [Int: Level] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        count = bundle.urls(forResourcesWithExtension: "json", subdirectory: "levels")?.count ?? 0
    }

    func level(_ id: Int) -> Level? {
        if let cached = cache[id] { return cached }
        let name = "level-" + String(format: "%03d", id)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "levels"),
              let data = try? Data(contentsOf: url),
              let level = try? Level.decode(from: data)
        else { return nil }
        cache[id] = level
        return level
    }
}
