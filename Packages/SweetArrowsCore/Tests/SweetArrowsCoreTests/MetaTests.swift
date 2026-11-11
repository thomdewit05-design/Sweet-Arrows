import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Economy & boosters")
struct EconomyTests {
    @Test func coinsForAWin() {
        #expect(Economy.coins(forStars: 1, winStreak: 1) == 10)
        #expect(Economy.coins(forStars: 3, winStreak: 1) == 14)
        #expect(Economy.coins(forStars: 3, winStreak: 3) == 19)
    }

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
        #expect(!progress.canAfford(.extraSlot))
        #expect(progress.coins == 40)
    }

    @Test func winsAndStreaks() {
        var progress = PlayerProgress()
        progress.recordWin(level: 1, stars: 2)
        progress.recordWin(level: 2, stars: 3)
        let third = progress.recordWin(level: 3, stars: 1)
        #expect(third == 15)
        #expect(progress.completedLevel == 3)
        #expect(progress.bestWinStreak == 3)
        progress.recordLoss()
        #expect(progress.winStreak == 0)
        progress.recordWin(level: 1, stars: 1)
        #expect(progress.stars[1] == 2)  // keeps the best
        #expect(progress.completedLevel == 3)
        #expect(!progress.showsMetaFeatures)
        progress.completedLevel = 5
        #expect(progress.showsMetaFeatures)
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
        #expect(progress.boosters[.extraSlot] == 2)
    }

    @Test func dayNumbers() {
        #expect(DayNumber.from(year: 2026, month: 1, day: 1) == 0)
        #expect(DayNumber.from(year: 2026, month: 3, day: 1) == 59)
        #expect(DayNumber.from(year: 2027, month: 1, day: 1) == 365)
        #expect(DayNumber.from(year: 2028, month: 3, day: 1) - DayNumber.from(year: 2028, month: 2, day: 28) == 2)
    }
}

@Suite("Daily puzzle")
struct DailyPuzzleTests {
    @Test func streakAndBest() {
        var state = DailyPuzzleState()
        let result8 = state.record(DailyResult(taps: 20, seconds: 90, stars: 2), day: 5)
        #expect(result8)
        let result9 = state.record(DailyResult(taps: 22, seconds: 80, stars: 3), day: 6)
        #expect(result9)
        #expect(state.streak == 2)
        let result10 = state.record(DailyResult(taps: 18, seconds: 40, stars: 3), day: 6)
        #expect(!result10)
        #expect(state.results[6]?.seconds == 40)
        let result11 = state.record(DailyResult(taps: 30, seconds: 300, stars: 1), day: 6)
        #expect(!result11)
        #expect(state.results[6]?.seconds == 40)
        #expect(state.currentStreak(today: 7) == 2)
        #expect(state.currentStreak(today: 8) == 0)
        let result12 = state.record(DailyResult(taps: 20, seconds: 60, stars: 3), day: 9)
        #expect(result12)
        #expect(state.streak == 1)
        #expect(state.bestStreak == 2)
    }

    @Test func poolWrapsAround() {
        #expect(DailyPuzzleState.puzzleNumber(day: 0, poolSize: 365) == 1)
        #expect(DailyPuzzleState.puzzleNumber(day: 365, poolSize: 365) == 1)
        #expect(DailyPuzzleState.puzzleNumber(day: -1, poolSize: 365) == 365)
    }

    @Test func shareText() {
        let text = DailyPuzzleState.shareText(puzzle: 12, result: DailyResult(taps: 24, seconds: 75, stars: 2), streak: 3)
        #expect(text.contains("#12"))
        #expect(text.contains("⭐⭐▫️"))
        #expect(text.contains("1m 15s"))
        #expect(text.contains("🔥3"))
    }
}

@Suite("Progress sync")
struct ProgressSyncTests {
    @Test func mergeKeepsEverythingEarned() {
        var phone = PlayerProgress()
        phone.completedLevel = 40
        phone.stars = [1: 3, 2: 1]
        phone.coins = 500
        phone.ownedCosmetics.insert(.mintMarble)
        phone.dailyPuzzle.record(DailyResult(taps: 10, seconds: 50, stars: 3), day: 3)
        phone.updatedAt = Date(timeIntervalSince1970: 1000)

        var tablet = PlayerProgress()
        tablet.completedLevel = 25
        tablet.stars = [2: 3, 3: 2]
        tablet.coins = 120
        tablet.ownedCosmetics.insert(.pastelCandy)
        tablet.dailyPuzzle.record(DailyResult(taps: 12, seconds: 70, stars: 3), day: 4)
        tablet.updatedAt = Date(timeIntervalSince1970: 2000)

        let merged = phone.merged(with: tablet)
        #expect(merged.completedLevel == 40)
        #expect(merged.stars == [1: 3, 2: 3, 3: 2])
        #expect(merged.coins == 120)  // wallet from the newest copy
        #expect(merged.ownedCosmetics.isSuperset(of: [.mintMarble, .pastelCandy]))
        #expect(merged.dailyPuzzle.results.keys.sorted() == [3, 4])
        #expect(merged.updatedAt == Date(timeIntervalSince1970: 2000))
        #expect(tablet.merged(with: phone) == merged)
    }

    @Test func oldSavesStillDecode() throws {
        let json = #"{"completedLevel":7,"stars":{"1":3,"2":2},"coins":55,"winStreak":2,"settings":{"music":false}}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        #expect(progress.completedLevel == 7)
        #expect(progress.stars == [1: 3, 2: 2])
        #expect(progress.settings.music == false)
        #expect(progress.settings.sound == true)
        #expect(progress.board == .woodCounter)
        #expect(progress.bestWinStreak == 2)
    }

    @Test func roundTrip() throws {
        var progress = PlayerProgress()
        progress.boosters.add(.removeCandy, 2)
        progress.seenElements = [.caramel]
        _ = progress.dailyReward.claim(today: 3)
        let data = try JSONEncoder().encode(progress)
        #expect(try JSONDecoder().decode(PlayerProgress.self, from: data) == progress)
    }
}
