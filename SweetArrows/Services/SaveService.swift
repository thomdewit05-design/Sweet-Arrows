import Foundation
import Observation

/// Player settings, stored with the progress.
struct GameSettings: Codable, Equatable, Sendable {
    var sound = true
    var music = true
    var haptics = true
    var colorBlind = false
}

/// Everything we keep about the player. Saved after every level.
struct PlayerProgress: Codable, Equatable, Sendable {
    /// Highest level completed (0 = none yet).
    var completedLevel = 0
    /// Best stars per level id (1–3).
    var stars: [Int: Int] = [:]
    var coins = 0
    var winStreak = 0
    var settings = GameSettings()

    var nextLevel: Int { completedLevel + 1 }
    var totalStars: Int { stars.values.reduce(0, +) }

    func isUnlocked(_ level: Int) -> Bool { level <= nextLevel }
}

/// Stores progress as JSON in Application Support. iCloud sync comes in phase 5.
@MainActor
@Observable
final class SaveService {
    private(set) var progress: PlayerProgress
    private let url: URL?

    /// - Parameter url: file to use; nil keeps everything in memory (tests, previews).
    init(url: URL? = SaveService.defaultURL) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = saved
        } else {
            progress = PlayerProgress()
        }
    }

    static var defaultURL: URL? {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return folder.appendingPathComponent("progress.json")
    }

    func update(_ change: (inout PlayerProgress) -> Void) {
        change(&progress)
        persist()
    }

    /// Records a won level and returns the coins earned.
    @discardableResult
    func recordWin(level: Int, stars: Int, coins: Int) -> Int {
        update { progress in
            progress.completedLevel = max(progress.completedLevel, level)
            progress.stars[level] = max(progress.stars[level] ?? 0, stars)
            progress.winStreak += 1
            progress.coins += coins
        }
        return coins
    }

    func recordLoss() {
        update { $0.winStreak = 0 }
    }

    private func persist() {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(progress)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Could not save progress: \(error)")
        }
    }
}
