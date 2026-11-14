import Foundation
import SweetArrowsCore

/// Demo mode for App Store screenshots, only with the UI-test launch arguments:
/// `-uiTesting -demo` fills the account like a player a few weeks in and the game opens on the
/// showcase board; `-demoResult` opens straight on a finished record run; `-demoGift` leaves
/// today's daily gift waiting (so it pops up on the home screen).
enum Demo {
    static var isOn: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-uiTesting") && arguments.contains("-demo")
    }

    static var showsResult: Bool { isOn && ProcessInfo.processInfo.arguments.contains("-demoResult") }
    static var giftWaiting: Bool { isOn && ProcessInfo.processInfo.arguments.contains("-demoGift") }

    /// The record run shown on the result card: a new best and level 15.
    static let resultRun = RunSummary(
        score: 5210, popped: 64, bestCombo: 6, stage: 6, bombs: 3, rainbows: 2, stones: 1, boardClears: 1,
        biggestPop: 5, seconds: 236
    )

    static func fill(_ progress: inout PlayerProgress, today: Int) {
        progress.coins = 2480
        progress.boosters[.hint] = 3
        progress.boosters[.hammer] = 2
        progress.boosters[.slowDown] = 1
        progress.xp = 4980  // level 14, close to 15
        progress.endlessBest = 4860
        progress.endlessRuns = 47
        progress.streak.lastDay = today
        progress.streak.current = 12
        progress.streak.best = 15
        progress.dailyReward = giftWaiting
            ? DailyRewardState(lastClaimDay: today - 1, lastClaimedStep: 3)
            : DailyRewardState(lastClaimDay: today, lastClaimedStep: 3)
        progress.ownedCosmetics.formUnion([.iceCreamBay, .chocolateRiver, .cottonSky, .mintMarble, .pastelCandy])
        progress.refreshMissions(today: today)
        for index in progress.missions.missions.indices {
            let target = progress.missions.missions[index].target
            progress.missions.missions[index].progress = [target, target * 2 / 3, target / 4][min(index, 2)]
        }
    }
}
