import Foundation
import SweetArrowsCore

/// Demo mode for App Store screenshots, only with the UI-test launch arguments:
/// `-uiTesting -demo` fills the account like a player a few weeks in, and the game opens on the
/// showcase board; `-demoResult` also opens straight on a finished record run.
enum Demo {
    static var isOn: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-uiTesting") && arguments.contains("-demo")
    }

    static var showsResult: Bool { isOn && ProcessInfo.processInfo.arguments.contains("-demoResult") }

    /// The record run shown on the result card: a new best, level 15 and the last Starry night sticker.
    static let resultRun = RunSummary(
        score: 5210, popped: 64, bestCombo: 6, stage: 6, bombs: 3, rainbows: 2, stones: 1, boardClears: 1,
        biggestPop: 5, seconds: 236
    )
    /// Lands on sticker 23, the last one of the Starry night page.
    static let resultStickerRoll = 0.995

    static func fill(_ progress: inout PlayerProgress, today: Int) {
        progress.coins = 2480
        progress.boosters[.hint] = 3
        progress.boosters[.hammer] = 2
        progress.boosters[.slowDown] = 1
        progress.xp = 4980  // level 14, close to 15
        progress.endlessBest = 4860
        progress.endlessRuns = 47
        progress.modeBests = [.zen: 3920, .blitz: 2150]
        progress.dailyChallenge.day = today
        progress.dailyChallenge.best = 1840
        progress.dailyChallenge.plays = 2
        progress.streak.lastDay = today
        progress.streak.current = 12
        progress.streak.best = 15
        progress.dailyReward = DailyRewardState(lastClaimDay: today, lastClaimedStep: 3)
        progress.ownedCosmetics.formUnion([.iceCreamBay, .chocolateRiver, .cottonSky, .mintMarble, .pastelCandy])

        progress.refreshMissions(today: today)
        for index in progress.missions.missions.indices {
            let target = progress.missions.missions[index].target
            progress.missions.missions[index].progress = [target, target * 2 / 3, target / 4][min(index, 2)]
        }

        let missing: Set<Int> = [4, 5, 10, 11, 16, 17, 23]
        for sticker in 0..<StickerAlbum.count where !missing.contains(sticker) {
            progress.stickers.copies[sticker] = [1: 3, 7: 2, 13: 2][sticker] ?? 1
        }

        progress.season.season = SeasonPass.season(for: today)
        progress.season.points = 7 * SeasonPass.pointsPerTier + 60
        progress.season.claimed = [1, 2, 3, 4, 5]

        progress.tournament.week = WeeklyTournament.week(for: today)
        progress.tournament.best = 3240
    }
}
