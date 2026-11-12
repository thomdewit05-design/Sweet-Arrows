import Foundation
import Testing
@testable import SweetArrows
import SweetArrowsCore

@MainActor
@Suite("App")
struct AppTests {
    @Test func saveServiceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let save = SaveService(url: url)
        save.update { _ = $0.recordRun(RunSummary(score: 450), today: 1) }
        save.update { $0.settings.music = false }

        let reloaded = SaveService(url: url)
        #expect(reloaded.progress.endlessBest == 450)
        #expect(reloaded.progress.endlessRuns == 1)
        #expect(reloaded.progress.coins >= 18)
        #expect(reloaded.progress.xp > 0)
        #expect(reloaded.progress.settings.music == false)
    }

    @Test func iCloudCopiesAreMerged() {
        let cloud = FakeCloud()
        let phone = SaveService(url: nil, cloud: cloud)
        phone.update { _ = $0.recordRun(RunSummary(score: 300), today: 1) }

        // A second device starts empty and picks up the iCloud copy.
        let tablet = SaveService(url: nil, cloud: cloud)
        #expect(tablet.progress.endlessBest == 300)

        tablet.update { _ = $0.recordRun(RunSummary(score: 700), today: 1) }
        phone.pullFromCloud()
        #expect(phone.progress.endlessBest == 700)
        #expect(phone.progress.endlessRuns == 2)
    }

    @Test func shopSellsGoldenCandyForCoins() {
        let save = SaveService(url: nil)
        save.update { $0.coins = 2000 }
        var bought = false
        save.update { bought = $0.buy(.goldenCandy) }
        #expect(bought)
        save.update { $0.equip(.goldenCandy) }
        #expect(save.progress.candyStyle == .goldenCandy)
        #expect(save.progress.coins == 500)
    }

    @Test func musicGetsLivelierWithSpeed() {
        #expect(MusicTrack.game(stage: 0) == .calm)
        #expect(MusicTrack.game(stage: 1) == .calm)
        #expect(MusicTrack.game(stage: 2) == .groove)
        #expect(MusicTrack.game(stage: 4) == .bright)
        #expect(MusicTrack.game(stage: 6) == .rush)
        #expect(MusicTrack.game(stage: 20) == .rush)
        // every track ships with the app
        for track in MusicTrack.allCases {
            #expect(Bundle.main.url(forResource: track.rawValue, withExtension: "wav") != nil, "\(track) missing")
        }
    }

    @Test func boostersCostCoins() {
        let save = SaveService(url: nil)
        #expect(!save.spend(.hint))
        save.update { $0.coins = 100 }
        #expect(save.spend(.hint))
        #expect(save.progress.coins == 100 - Booster.hint.price)
    }

    @Test func slideSessionPlaysAndRestarts() {
        let session = SlideSession(seed: 9)
        #expect(session.run.pieces.count == 5)
        #expect(session.score == 0)
        let movable = session.run.sortedPieces.first { $0.canMove }
        if let piece = movable {
            let report = session.tap(piece.id)
            #expect(report.move != .ignored)
        }
        session.slowDown()
        #expect(session.isSlowedDown)
        if let any = session.run.sortedPieces.first {
            #expect(session.smash(any.id))
        }
        session.hold("test")
        session.restart()
        #expect(session.score == 0)
        #expect(!session.isOver)
        #expect(session.run.pieces.count == 5)
    }

    @Test func endlessRecordIsSaved() {
        let save = SaveService(url: nil)
        var record = false
        save.update { record = $0.recordRun(RunSummary(score: 120), today: 1).newRecord }
        #expect(record)
        #expect(save.progress.endlessBest == 120)
        save.update { record = $0.recordRun(RunSummary(score: 80), today: 1).newRecord }
        #expect(!record)
        #expect(save.progress.endlessRuns == 2)
        #expect(save.progress.coins >= 20)
        #expect(save.progress.streak.current == 1)
    }

    @Test func widgetLinksOpenTheRightScreen() {
        let link = { (text: String) in AppModel.route(for: URL(string: text)!) }
        #expect(link("sweetarrows://play/daily") == .play(.daily))
        #expect(link("sweetarrows://play/blitz") == .play(.blitz))
        #expect(link("sweetarrows://play") == .play(.classic))
        #expect(link("sweetarrows://prizes") == .prizes)
        #expect(link("sweetarrows://play/unknown") == nil)
        #expect(link("https://example.com/play/daily") == nil)
    }

    @Test func remoteConfigKeysMatchThePlan() {
        let keys = Set(RemoteValues.Key.allCases.map(\.rawValue))
        #expect(keys == [
            "interstitial_min_level", "interstitial_level_gap", "interstitial_min_seconds",
            "rewarded_daily_cap", "banner_enabled", "banner_from_level", "app_open_enabled",
        ])
        let defaults = RemoteValues()
        #expect(defaults.interstitialMinLevel == 4)
        #expect(defaults.interstitialLevelGap == 2)
        #expect(defaults.adLimits.adsFromLevel == 2)
        #expect(defaults.adLimits.bannerFromLevel == 0)
    }
}

@MainActor
final class FakeCloud: CloudKeyValueStore {
    private var storage: [String: Data] = [:]
    func data(forKey key: String) -> Data? { storage[key] }
    func set(_ data: Data?, forKey key: String) { storage[key] = data }
    func synchronize() -> Bool { true }
}
