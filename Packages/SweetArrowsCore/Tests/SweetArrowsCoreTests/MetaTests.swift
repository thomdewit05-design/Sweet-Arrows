import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Economy & boosters")
struct EconomyTests {
    @Test func spendUsesStockFirstThenCoins() {
        var progress = PlayerProgress()
        progress.boosters.add(.hint)
        progress.coins = 100
        let result1 = progress.spend(.hint)
        #expect(result1)
        #expect(progress.boosters[.hint] == 0)
        #expect(progress.coins == 100)
        let result2 = progress.spend(.hint)
        #expect(result2)
        #expect(progress.coins == 40)
        let result3 = progress.spend(.hint)
        #expect(!result3)
        #expect(!progress.canAfford(.slowDown))
        #expect(progress.coins == 40)
    }

    @Test func runsAndBestScore() {
        var progress = PlayerProgress()
        let first = progress.recordRun(RunSummary(score: 300), today: 1)
        let second = progress.recordRun(RunSummary(score: 200), today: 1)
        #expect(first.newRecord)
        #expect(!second.newRecord)
        #expect(second.previousBest == 300)
        #expect(progress.endlessBest == 300)
        #expect(progress.coins >= 20)  // 12 + 8 from the scores, plus anything the missions paid
        #expect(!progress.showsMetaFeatures)
        progress.recordRun(RunSummary(score: 10), today: 1)
        #expect(progress.showsMetaFeatures)
    }

    @Test func boosterRawValuesMatchOldSaves() {
        #expect(Booster.hammer.rawValue == "removeCandy")
        #expect(Booster.slowDown.rawValue == "extraSlot")
        #expect(Booster.allCases.map(\.price) == [60, 90, 120])
    }

    @Test func cosmetics() {
        var progress = PlayerProgress()
        #expect(progress.board == .woodCounter)
        let result4 = progress.buy(.mintMarble)
        #expect(!result4)
        progress.coins = 1000
        let result5 = progress.buy(.mintMarble)
        #expect(result5)
        let result6 = progress.buy(.mintMarble)
        #expect(!result6)
        #expect(progress.coins == 700)
        progress.equip(.mintMarble)
        progress.equip(.sparkleCandy)  // not owned: ignored
        #expect(progress.board == .mintMarble)
        #expect(progress.candyStyle == .classicCandy)
        #expect(Cosmetic.items(of: .board).count == 4)
        #expect(Cosmetic.goldenCandy.price == 1500)
        #expect(Cosmetic.defaultItem(for: .candyStyle).price == 0)
    }
}

@Suite("Daily reward")
struct DailyRewardTests {
    @Test func sevenDayRow() {
        var state = DailyRewardState()
        #expect(state.claimableStep(today: 10) == 1)
        for day in 10..<17 {
            let claim = state.claim(today: day)
            #expect(claim?.step == day - 9)
            let result7 = state.claim(today: day)
            #expect(result7 == nil)  // once a day
        }
        #expect(state.claimableStep(today: 17) == 1)  // starts over after day 7
    }

    @Test func missingADayStartsOver() {
        var state = DailyRewardState()
        _ = state.claim(today: 1)
        _ = state.claim(today: 2)
        #expect(state.claimableStep(today: 4) == 1)
        #expect(state.claimableStep(today: 1) == 1)  // clock went backwards
    }

    @Test func rewardsApply() {
        var progress = PlayerProgress()
        progress.apply(DailyRewardState.rewards[6].doubled())
        #expect(progress.coins == 200)
        #expect(progress.boosters[.slowDown] == 2)
    }

    @Test func dayNumbers() {
        #expect(DayNumber.from(year: 2026, month: 1, day: 1) == 0)
        #expect(DayNumber.from(year: 2026, month: 3, day: 1) == 59)
        #expect(DayNumber.from(year: 2027, month: 1, day: 1) == 365)
        #expect(DayNumber.from(year: 2028, month: 3, day: 1) - DayNumber.from(year: 2028, month: 2, day: 28) == 2)
    }
}

@Suite("Progress sync")
struct ProgressSyncTests {
    @Test func mergeKeepsEverythingEarned() {
        var phone = PlayerProgress()
        phone.endlessBest = 900
        phone.endlessRuns = 12
        phone.coins = 500
        phone.ownedCosmetics.insert(.mintMarble)
        phone.updatedAt = Date(timeIntervalSince1970: 1000)

        var tablet = PlayerProgress()
        tablet.endlessBest = 400
        tablet.endlessRuns = 20
        tablet.coins = 120
        tablet.ownedCosmetics.insert(.pastelCandy)
        tablet.updatedAt = Date(timeIntervalSince1970: 2000)

        let merged = phone.merged(with: tablet)
        #expect(merged.endlessBest == 900)
        #expect(merged.endlessRuns == 20)
        #expect(merged.coins == 120)  // wallet from the newest copy
        #expect(merged.ownedCosmetics.isSuperset(of: [.mintMarble, .pastelCandy]))
        #expect(merged.updatedAt == Date(timeIntervalSince1970: 2000))
        #expect(tablet.merged(with: phone) == merged)
    }

    @Test func oldSavesStillDecode() throws {
        // A save from the puzzle version: level fields are ignored, the rest is kept.
        let json = #"{"completedLevel":7,"stars":{"1":3},"coins":55,"winStreak":2,"boosters":{"counts":["extraSlot",2]},"settings":{"music":false}}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        #expect(progress.coins == 55)
        #expect(progress.boosters[.slowDown] == 2)
        #expect(progress.settings.music == false)
        #expect(progress.settings.sound == true)
        #expect(progress.board == .woodCounter)
    }

    @Test func roundTrip() throws {
        var progress = PlayerProgress()
        progress.boosters.add(.hammer, 2)
        _ = progress.dailyReward.claim(today: 3)
        let data = try JSONEncoder().encode(progress)
        #expect(try JSONDecoder().decode(PlayerProgress.self, from: data) == progress)
    }
}
