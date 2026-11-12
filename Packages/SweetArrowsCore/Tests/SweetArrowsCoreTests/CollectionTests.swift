import Foundation
import Testing
@testable import SweetArrowsCore

@Suite("Stickers, season and tournament")
struct CollectionTests {
    @Test func everyStickerCanDropAndRollsStayInRange() {
        let picked = Set(stride(from: 0.0, to: 1.0, by: 0.001).map(StickerAlbum.pick(roll:)))
        #expect(picked == Set(0..<StickerAlbum.count))
        #expect(StickerAlbum.pick(roll: -1) == 0)
        #expect(StickerAlbum.pick(roll: 1) == StickerAlbum.count - 1)
        #expect(StickerAlbum.isRare(5))
        #expect(!StickerAlbum.isRare(4))
        #expect(StickerAlbum.page(of: 7) == 1)
    }

    @Test func copiesPayCoinsAndFullPagesPayAGift() {
        var album = StickerCollection()
        let first = album.add(roll: 0)
        #expect(first.isNew)
        #expect(first.reward == Reward())
        let copy = album.add(roll: 0)
        #expect(!copy.isNew)
        #expect(copy.reward.coins == StickerAlbum.duplicateCoins)
        // Fill page 0 by hand except the last sticker, then drop it.
        for sticker in 1..<5 { album.copies[sticker] = 1 }
        let rareRoll = (Double(StickerAlbum.weights.dropLast().reduce(0, +)) + 0.5)
            / Double(StickerAlbum.weights.reduce(0, +) * StickerAlbum.pages)
        let last = album.add(roll: rareRoll)
        #expect(last.sticker == 5)
        #expect(last.completedPage == 0)
        #expect(last.reward == StickerAlbum.pageReward)
        #expect(album.isComplete(page: 0))
        #expect(album.owned == 6)
    }

    @Test func theLastStickerCompletesTheAlbum() {
        var album = StickerCollection()
        for sticker in 1..<StickerAlbum.count { album.copies[sticker] = 1 }
        let drop = album.add(roll: 0)
        #expect(drop.completedAlbum)
        #expect(drop.reward == StickerAlbum.pageReward + StickerAlbum.albumReward)
        #expect(album.isComplete)
    }

    @Test func seasonTiersFillUpAndResetNextSeason() {
        var pass = SeasonPass()
        #expect(pass.add(50, today: 3) == nil)
        #expect(pass.add(200, today: 3) == 1...2)
        #expect(pass.tier(today: 3) == 2)
        #expect(pass.pointsIntoTier(today: 3) == 10)
        #expect(pass.claimable(today: 3) == [1, 2])
        #expect(pass.claim(1, today: 3) == SeasonPass.reward(tier: 1))
        #expect(pass.claim(1, today: 3) == nil)
        #expect(pass.claim(3, today: 3) == nil)
        #expect(pass.isClaimed(1, today: 3))
        #expect(SeasonPass.daysLeft(today: 3) == 25)
        // A new season: nothing carries over.
        #expect(pass.tier(today: 30) == 0)
        #expect(pass.claimable(today: 30).isEmpty)
        #expect(!pass.isClaimed(1, today: 30))
        _ = pass.add(10_000, today: 30)
        #expect(pass.tier(today: 30) == SeasonPass.tiers)
        #expect(pass.pointsIntoTier(today: 30) == SeasonPass.pointsPerTier)
        #expect(SeasonPass.season(for: -1) == -1)
    }

    @Test func seasonRewardsGrowTowardsTheEnd() {
        for tier in 1...SeasonPass.tiers {
            #expect(SeasonPass.reward(tier: tier).coins > 0)
        }
        #expect(SeasonPass.reward(tier: 5).boosters.count == 3)
        #expect(SeasonPass.reward(tier: 3).boosters[.hint] == 1)
        #expect(SeasonPass.reward(tier: SeasonPass.tiers).coins == 500)
    }

    @Test func tournamentWeeksStartOnMonday() {
        // 1 January 2026 is a Thursday; Monday 5 January is day 4.
        #expect(WeeklyTournament.week(for: 3) == 0)
        #expect(WeeklyTournament.week(for: 4) == 1)
        #expect(WeeklyTournament.week(for: 10) == 1)
        #expect(WeeklyTournament.week(for: 11) == 2)
        #expect(WeeklyTournament.daysLeft(today: 4) == 7)
        #expect(WeeklyTournament.daysLeft(today: 10) == 1)
        #expect(WeeklyTournament.week(for: -5) == -1)
    }

    @Test func trophiesArePaidOncePerWeek() {
        var cup = WeeklyTournament()
        #expect(cup.record(score: 1600, today: 4) == [.bronze, .silver])
        #expect(cup.record(score: 900, today: 5).isEmpty)
        #expect(cup.nextTrophy(today: 5) == .gold)
        #expect(cup.record(score: 7000, today: 6) == [.gold, .diamond])
        #expect(cup.nextTrophy(today: 6) == nil)
        // Next week starts from zero.
        #expect(cup.best(today: 11) == 0)
        #expect(cup.record(score: 600, today: 11) == [.bronze])
    }

    @Test func runsFeedTheAlbumSeasonAndTournament() {
        var progress = PlayerProgress()
        let low = progress.recordRun(RunSummary(score: 40), today: 4, stickerRoll: 0)
        #expect(low.sticker == nil)
        let good = progress.recordRun(RunSummary(score: 1600), today: 4, stickerRoll: 0)
        #expect(good.sticker?.sticker == 0)
        #expect(good.trophies == [.bronze, .silver])
        #expect(progress.stickers.has(0))
        #expect(progress.season.points(today: 4) == low.xpGained + good.xpGained)
        let zen = progress.recordRun(RunSummary(score: 9000), today: 4, mode: .zen, stickerRoll: 0)
        #expect(zen.trophies.isEmpty)
        #expect(zen.sticker?.isNew == false)
        #expect(zen.seasonTiers != nil)
        let coins = progress.coins
        #expect(progress.claimSeasonTier(1, today: 4) == SeasonPass.reward(tier: 1))
        #expect(progress.coins == coins + SeasonPass.reward(tier: 1).coins)
        #expect(progress.claimSeasonTier(1, today: 4) == nil)
    }

    @Test func albumSurvivesSavingAndMerging() throws {
        var a = PlayerProgress()
        a.stickers.copies = [1: 2, 3: 1]
        a.season.season = 0
        a.season.points = 300
        a.tournament.week = 1
        a.tournament.best = 800
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(a))
        #expect(decoded.stickers == a.stickers)
        #expect(decoded.season == a.season)
        #expect(decoded.tournament == a.tournament)
        var b = PlayerProgress()
        b.stickers.copies = [1: 1, 7: 1]
        #expect(a.merged(with: b).stickers.copies == [1: 2, 3: 1, 7: 1])
    }
}
