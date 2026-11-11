import Foundation
import Testing
@testable import SweetArrows
import SweetArrowsCore

@MainActor
@Suite("App")
struct AppTests {
    @Test func bundleShipsAllLevelsAndTheyDecode() throws {
        let library = LevelLibrary()
        #expect(library.count >= 300)
        for id in 1...library.count {
            let level = try #require(library.level(id), "level \(id) missing")
            #expect(level.id == id)
            #expect(level.stats != nil, "level \(id) was not approved by the solver")
        }
        #expect(library.level(1)?.tutorial == true)
        #expect(library.level(library.count + 1) == nil)
    }

    @Test func saveServiceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let save = SaveService(url: url)
        save.recordWin(level: 1, stars: 2, coins: 10)
        save.recordWin(level: 1, stars: 3, coins: 10)
        save.update { $0.settings.music = false }

        let reloaded = SaveService(url: url)
        #expect(reloaded.progress.completedLevel == 1)
        #expect(reloaded.progress.stars[1] == 3)
        #expect(reloaded.progress.coins == 20)
        #expect(reloaded.progress.winStreak == 2)
        #expect(reloaded.progress.settings.music == false)
        #expect(reloaded.progress.isUnlocked(2))
        #expect(!reloaded.progress.isUnlocked(3))

        reloaded.recordLoss()
        #expect(reloaded.progress.winStreak == 0)
    }

    @Test func sessionStarsFollowHearts() throws {
        let level = try #require(LevelLibrary().level(11))
        let session = GameSession(level: level)
        #expect(session.stars == 3)
        // Play the stored solution: no bounces, so three stars.
        for id in level.stats?.solution ?? [] { _ = session.tap(id) }
        #expect(session.status == .won)
        #expect(session.stars == 3)
        session.restart()
        #expect(session.status == .playing)
        #expect(session.moves == 0)
    }

    @Test func comboRisesWithPopsAndResetsOnBounce() throws {
        let level = Level(id: 99, width: 4, height: 3, candies: [
            Candy(id: 1, color: .mint, position: GridPoint(0, 0), direction: .up),
            Candy(id: 2, color: .mint, position: GridPoint(1, 0), direction: .up),
            Candy(id: 3, color: .mint, position: GridPoint(2, 0), direction: .up),
            Candy(id: 4, color: .lemon, position: GridPoint(0, 2), direction: .right),
            Candy(id: 5, color: .lemon, position: GridPoint(3, 2), direction: .left),
            Candy(id: 6, color: .lemon, position: GridPoint(3, 1), direction: .up),
        ])
        let session = GameSession(level: level)
        _ = session.tap(1)
        _ = session.tap(2)
        #expect(session.comboStep == 0)
        _ = session.tap(3)
        #expect(session.comboStep == 1)
        _ = session.tap(4)  // bounces into candy 5
        #expect(session.comboStep == 0)
    }

    @Test func remoteConfigKeysMatchThePlan() {
        let keys = Set(RemoteValues.Key.allCases.map(\.rawValue))
        #expect(keys == [
            "interstitial_min_level", "interstitial_level_gap", "interstitial_min_seconds",
            "rewarded_daily_cap", "banner_enabled", "app_open_enabled", "starter_pack_level", "level_overrides",
        ])
        let defaults = RemoteValues()
        #expect(defaults.interstitialMinLevel == 8)
        #expect(defaults.interstitialLevelGap == 2)
    }

    @Test func levelOverridesApply() {
        let model = AppModel.preview()
        #expect(model.level(1)?.bagCapacity == 5)
    }
}
