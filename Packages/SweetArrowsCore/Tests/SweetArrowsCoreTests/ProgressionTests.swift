import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Progression")
struct ProgressionTests {
    @Test func levelsFromXP() {
        #expect(PlayerLevel.level(forXP: 0) == 1)
        #expect(PlayerLevel.level(forXP: 99) == 1)
        #expect(PlayerLevel.level(forXP: 100) == 2)
        #expect(PlayerLevel.xpIntoLevel(forXP: 130) == 30)
        #expect(PlayerLevel.xpToNext(2) == 140)
        #expect(PlayerLevel.level(forXP: 240) == 3)
        #expect(PlayerLevel.xp(for: RunSummary(score: 1000, boardClears: 1)) == 20 + 40 + 15)
    }

    @Test func levelRewards() {
        let three = PlayerLevel.reward(for: 3)
        #expect(three.reward.coins == 70)
        #expect(three.unlock == .iceCreamBay)
        let five = PlayerLevel.reward(for: 5)
        #expect(five.reward.boosters[.hammer] == 1)
        #expect(five.unlock == nil)
        #expect(PlayerLevel.reward(for: 15).unlock == .starryNight)
    }

    @Test func aRunGivesXPLevelsAndUnlocks() {
        var progress = PlayerProgress()
        let outcome = progress.recordRun(RunSummary(score: 6000, popped: 40), today: 10)
        #expect(outcome.xpGained == 260)
        #expect(outcome.levelBefore == 1)
        #expect(outcome.levelAfter == 3)
        #expect(outcome.levelRewards.map(\.level) == [2, 3])
        #expect(progress.ownedCosmetics.contains(.iceCreamBay))
        #expect(outcome.xpIntoLevel == 20)
        #expect(outcome.xpForLevel == 180)
        #expect(outcome.streak == 1)
        let extras = (outcome.sticker?.reward.coins ?? 0) + outcome.trophies.map(\.reward.coins).reduce(0, +)
        #expect(outcome.totalCoins == 240 + outcome.missionReward.coins + 60 + 70 + extras)
        #expect(progress.coins == outcome.totalCoins)
        progress.equip(.iceCreamBay)
        #expect(progress.backdrop == .iceCreamBay)
    }

    @Test func missionsAreTheSameForADayAndDifferent() {
        let a = DailyMissions.make(day: 40, level: 1)
        #expect(a == DailyMissions.make(day: 40, level: 1))
        #expect(a.count == 3)
        #expect(Set(a.map(\.kind)).count == 3)
        #expect(a.allSatisfy { $0.kind.minimumLevel <= 1 })
        let days = (0..<20).map { DailyMissions.make(day: $0, level: 1).map(\.kind) }
        #expect(Set(days.map { $0.map(\.rawValue).joined() }).count > 5)
        let later = DailyMissions.make(day: 40, level: 21)
        #expect(later.allSatisfy { $0.coins == 80 })
    }

    @Test func missionsCountRunsAndPayOnce() {
        var missions = DailyMissions()
        missions.day = 3
        missions.missions = [
            Mission(kind: .popCandies, target: 30, coins: 40),
            Mission(kind: .score, target: 800, coins: 40),
            Mission(kind: .runs, target: 2, coins: 40),
        ]
        let first = missions.record(RunSummary(score: 500, popped: 20))
        #expect(first.finished.isEmpty)
        #expect(missions.missions[0].progress == 20)
        #expect(missions.missions[1].progress == 500)
        let second = missions.record(RunSummary(score: 900, popped: 15))
        #expect(second.finished.map(\.kind) == [.popCandies, .score, .runs])
        #expect(second.reward.coins == 120 + DailyMissions.allDoneBonus.coins)
        #expect(second.reward.boosters[.hint] == 1)
        #expect(missions.allDone)
        let third = missions.record(RunSummary(score: 5000, popped: 99))
        #expect(third.finished.isEmpty)
        #expect(third.reward.coins == 0)
    }

    @Test func missionValues() {
        let run = RunSummary(score: 1, popped: 2, bestCombo: 3, stage: 4, bombs: 5, rainbows: 6, stones: 7, biggestPop: 8)
        let values = MissionKind.allCases.map { $0.value(in: run) }
        #expect(values == [1, 2, 3, 5, 7, 6, 1, 8, 5])
        #expect(MissionKind.allCases.allSatisfy { $0.target(tier: 9) > 0 })
    }

    @Test func newDayNewMissions() {
        var missions = DailyMissions()
        missions.refresh(today: 5, level: 1)
        let first = missions.missions
        missions.refresh(today: 5, level: 1)
        #expect(missions.missions == first)
        missions.refresh(today: 6, level: 1)
        #expect(missions.day == 6)
        #expect(!missions.bonusClaimed)
    }

    @Test func streakCountsDaysInARow() {
        var streak = PlayStreak()
        streak.played(today: 10)
        streak.played(today: 10)
        streak.played(today: 11)
        streak.played(today: 12)
        #expect(streak.current == 3)
        #expect(streak.current(today: 13) == 3)
        #expect(streak.current(today: 14) == 0)
        streak.played(today: 15)
        #expect(streak.current == 1)
        #expect(streak.best == 3)
    }

    @Test func luckyWheelSpinsOnceFreeAndTwiceByAd() {
        var progress = PlayerProgress()
        #expect(progress.wheel.hasFreeSpin(today: 3))
        let first = progress.spinWheel(today: 3, viaAd: false, roll: 0)
        #expect(first == 0)
        #expect(progress.coins == 20)
        #expect(progress.spinWheel(today: 3, viaAd: false, roll: 0) == nil)
        #expect(progress.wheel.adSpinsLeft(today: 3) == 2)
        #expect(progress.spinWheel(today: 3, viaAd: true, roll: 0.999) == 7)  // jackpot
        #expect(progress.coins == 520)
        #expect(progress.boosters[.hammer] == 1)
        #expect(progress.spinWheel(today: 3, viaAd: true, roll: 0.5) != nil)
        #expect(progress.spinWheel(today: 3, viaAd: true, roll: 0.5) == nil)
        #expect(progress.wheel.hasFreeSpin(today: 4))
        #expect(progress.wheel.adSpinsLeft(today: 4) == 2)
    }

    @Test func luckyWheelOddsFollowTheWeights() {
        var counts = Array(repeating: 0, count: LuckyWheel.segments.count)
        for i in 0..<1000 { counts[LuckyWheel.segment(for: Double(i) / 1000)] += 1 }
        let total = LuckyWheel.segments.map(\.weight).reduce(0, +)
        for (index, segment) in LuckyWheel.segments.enumerated() {
            #expect(abs(counts[index] - segment.weight * 1000 / total) <= 1)
        }
        #expect(LuckyWheel.segments.filter(\.isJackpot).count == 1)
    }

    @Test func remindersAreFewAndKind() {
        #expect(ReminderPlan.plan(streak: 0).map(\.kind) == [.missions, .missions, .comeBack])
        #expect(ReminderPlan.plan(streak: 5).first?.kind == .streak)
        #expect(ReminderPlan.plan(streak: 5).map(\.day) == [1, 2, 4])
        #expect(!GameSettings().reminders)
    }

    @Test func slideGameSummary() {
        let game = SlideGame(seed: 2)
        let summary = game.summary
        #expect(summary.score == 0)
        #expect(summary.coins == 0)
        #expect(summary.stage == 0)
    }

    @Test func oldSavesGetTheDefaultBackdrop() throws {
        let json = #"{"coins":5,"ownedCosmetics":["woodCounter","classicCandy"]}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        #expect(progress.ownedCosmetics.contains(.candyMeadow))
        #expect(progress.backdrop == .candyMeadow)
        #expect(progress.level == 1)
        #expect(Cosmetic.defaultItem(for: .backdrop) == .candyMeadow)
        #expect(Cosmetic.items(of: .backdrop).count == 5)
    }
}
