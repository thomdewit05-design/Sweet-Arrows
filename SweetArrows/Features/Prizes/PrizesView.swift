import SwiftUI
import SweetArrowsCore

/// Everything to collect besides coins: the sticker album, the season path and the weekly tournament.
struct PrizesView: View {
    enum Tab: Hashable { case season, album, tournament }

    @Environment(AppModel.self) private var model
    @State var tab: Tab = .season

    var body: some View {
        let progress = model.save.progress
        ScrollView {
            VStack(spacing: 16) {
                Picker(selection: $tab) {
                    Text("Season").tag(Tab.season)
                    Text("Album").tag(Tab.album)
                    Text("Tournament").tag(Tab.tournament)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("prizesTabs")
                switch tab {
                case .season: SeasonPathView(progress: progress, today: model.today, claim: claim)
                case .album: StickerAlbumView(stickers: progress.stickers)
                case .tournament:
                    TournamentView(tournament: progress.tournament, today: model.today) {
                        model.gameCenter.showLeaderboards()
                    }
                }
            }
            .padding()
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tab)
        }
        .background(CandySkyBackground(colors: [Color(hex: 0xFFE3B8), Color(hex: 0xFFD6E6), Color(hex: 0xE4D9FF)]))
        .safeAreaInset(edge: .bottom) {
            if model.showsBanner {
                BannerAdView(adUnitID: model.ads.bannerAdUnitID)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { CoinBadge(coins: progress.coins) }
        }
        .navigationTitle(Text("Prizes"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func claim(_ tier: Int) {
        let today = model.today
        var reward: Reward?
        model.save.update { reward = $0.claimSeasonTier(tier, today: today) }
        guard reward != nil else { return }
        model.haptics.success()
        model.audio.play(.coin)
    }
}

// MARK: Season

private struct SeasonPathView: View {
    let progress: PlayerProgress
    let today: Int
    let claim: (Int) -> Void

    var body: some View {
        let season = progress.season
        let tier = season.tier(today: today)
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack {
                    Label("Season path", systemImage: "flag.checkered")
                        .font(Theme.heading())
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(SeasonPass.daysLeft(today: today)) days left")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                HStack(spacing: 10) {
                    LevelBadge(level: tier, size: 40)
                    XPBar(
                        fraction: Double(season.pointsIntoTier(today: today)) / Double(SeasonPass.pointsPerTier),
                        height: 12
                    )
                    Text("\(season.pointsIntoTier(today: today))/\(SeasonPass.pointsPerTier)")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }
                Text("Every run's XP fills the path. Free gifts for everyone, no purchase needed.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .candyCard()
            .popIn()
            ForEach(1...SeasonPass.tiers, id: \.self) { step in
                SeasonTierRow(
                    tier: step, reward: SeasonPass.reward(tier: step), reached: step <= tier,
                    claimed: season.isClaimed(step, today: today)
                ) { claim(step) }
            }
        }
    }
}

private struct SeasonTierRow: View {
    let tier: Int
    let reward: Reward
    let reached: Bool
    let claimed: Bool
    let claim: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(tier)")
                .font(Theme.heading(17))
                .foregroundStyle(reached ? .white : Theme.inkSoft)
                .frame(width: 38, height: 38)
                .background(Circle().fill(reached ? Theme.heart : Color.white.opacity(0.7)))
            RewardLabel(reward: reward, big: tier.isMultiple(of: 5))
            Spacer()
            if claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: 0x3DDC97))
                    .accessibilityLabel(Text("Collected"))
            } else if reached {
                Button("Collect", action: claim)
                    .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97), compact: true))
                    .shineSweep(every: 3)
                    .accessibilityIdentifier("collectTier\(tier)")
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityLabel(Text("Locked"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(reached ? 0.95 : 0.6))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold, lineWidth: tier.isMultiple(of: 5) ? 2 : 0))
        )
    }
}

/// Coins and boosters of a reward, in one line.
struct RewardLabel: View {
    let reward: Reward
    var big = false

    var body: some View {
        HStack(spacing: 8) {
            if reward.coins > 0 {
                Label("\(reward.coins)", systemImage: "circle.fill")
                    .foregroundStyle(Theme.ink)
            }
            ForEach(Booster.allCases.filter { (reward.boosters[$0] ?? 0) > 0 }, id: \.self) { booster in
                Label("\(reward.boosters[booster] ?? 0)", systemImage: booster.icon)
                    .foregroundStyle(Theme.heart)
            }
        }
        .font(Theme.heading(big ? 17 : 15))
        .monospacedDigit()
    }
}

// MARK: Album

/// One sticker: a round candy badge with a picture, grey until found.
struct StickerBadge: View {
    let sticker: Int
    var owned = true
    var size: CGFloat = 70

    static let symbols = [
        "birthday.cake.fill", "cup.and.saucer.fill", "gift.fill", "heart.fill", "balloon.fill", "crown.fill",
        "leaf.fill", "carrot.fill", "tree.fill", "camera.macro", "sun.max.fill", "rainbow",
        "drop.fill", "snowflake", "fish.fill", "sailboat.fill", "water.waves", "tortoise.fill",
        "moon.stars.fill", "star.fill", "sparkles", "cloud.moon.fill", "moon.fill", "star.circle.fill",
    ]
    static let pageColors: [Color] = [Color(hex: 0xFF5C8A), Color(hex: 0x3DDC97), Color(hex: 0x4CC9F0), Color(hex: 0xA259FF)]

    var body: some View {
        let color = Self.pageColors[StickerAlbum.page(of: sticker) % Self.pageColors.count]
        let rare = StickerAlbum.isRare(sticker)
        ZStack {
            Circle()
                .fill(owned
                      ? AnyShapeStyle(LinearGradient(colors: [color.opacity(0.75), color], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.gray.opacity(0.25)))
            Circle()
                .stroke(owned ? (rare ? Theme.gold : .white) : Color.gray.opacity(0.4),
                        style: StrokeStyle(lineWidth: size * 0.06, dash: owned ? [] : [4, 4]))
            Image(systemName: owned ? Self.symbols[sticker % Self.symbols.count] : "questionmark")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(owned ? .white : Color.gray.opacity(0.6))
                .shadow(color: .black.opacity(owned ? 0.2 : 0), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if owned, rare {
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(Theme.gold)
                    .shadow(radius: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(owned ? Text("Sticker \(sticker + 1)") : Text("Not found yet"))
    }
}

private struct StickerAlbumView: View {
    let stickers: StickerCollection

    private static let pageTitles: [LocalizedStringKey] = ["Sweet shop", "Fruit garden", "Ice cream bay", "Starry night"]

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("\(stickers.owned)/\(StickerAlbum.count)")
                    .font(Theme.title(34))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("Every run of 100+ points gives a sticker. A full page gives a gift!")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .candyCard()
            .popIn()
            ForEach(0..<StickerAlbum.pages, id: \.self) { page in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(Self.pageTitles[page % Self.pageTitles.count])
                            .font(Theme.heading())
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if stickers.isComplete(page: page) {
                            Label("Complete", systemImage: "checkmark.seal.fill")
                                .font(Theme.heading(14))
                                .foregroundStyle(Color(hex: 0x3DDC97))
                        } else {
                            RewardLabel(reward: StickerAlbum.pageReward)
                                .opacity(0.7)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                        ForEach(Array(StickerAlbum.stickers(onPage: page)), id: \.self) { sticker in
                            StickerBadge(sticker: sticker, owned: stickers.has(sticker))
                                .overlay(alignment: .bottomTrailing) {
                                    let copies = stickers.copies[sticker] ?? 0
                                    if copies > 1 {
                                        Text(verbatim: "×\(copies)")
                                            .font(Theme.heading(12))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .background(Capsule().fill(Theme.ink.opacity(0.8)))
                                    }
                                }
                        }
                    }
                }
                .candyCard()
                .popIn(delay: 0.05 * Double(page + 1))
            }
        }
    }
}

// MARK: Tournament

/// The trophy cup in its own colors.
struct TrophyIcon: View {
    let trophy: WeeklyTournament.Trophy
    var won = true
    var size: CGFloat = 34

    var color: Color {
        switch trophy {
        case .bronze: Color(hex: 0xCD7F32)
        case .silver: Color(hex: 0xA8B4C0)
        case .gold: Theme.gold
        case .diamond: Color(hex: 0x4CC9F0)
        }
    }

    var body: some View {
        Image(systemName: trophy == .diamond ? "diamond.fill" : "trophy.fill")
            .font(.system(size: size * 0.6, weight: .bold))
            .foregroundStyle(won ? color : Color.gray.opacity(0.4))
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.9)))
    }
}

extension WeeklyTournament.Trophy {
    var name: LocalizedStringKey {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .diamond: "Diamond"
        }
    }
}

private struct TournamentView: View {
    let tournament: WeeklyTournament
    let today: Int
    let showLeaderboards: () -> Void

    var body: some View {
        let best = tournament.best(today: today)
        let won = tournament.trophies(today: today)
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Label("Weekly tournament", systemImage: "trophy.fill")
                    .font(Theme.heading())
                    .foregroundStyle(Theme.ink)
                Text("Best this week")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                Text("\(best)")
                    .font(Theme.title(40))
                    .foregroundStyle(Theme.heart)
                    .monospacedDigit()
                if let next = tournament.nextTrophy(today: today) {
                    Text("\(next.score - best) more points for \(Text(next.name))")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.ink)
                }
                Text("Classic runs count. Ends in \(WeeklyTournament.daysLeft(today: today)) days.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .candyCard()
            .popIn()
            ForEach(WeeklyTournament.Trophy.allCases.reversed(), id: \.self) { trophy in
                HStack(spacing: 12) {
                    TrophyIcon(trophy: trophy, won: won.contains(trophy), size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trophy.name)
                            .font(Theme.heading(17))
                            .foregroundStyle(Theme.ink)
                        Text("\(trophy.score) points")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    if won.contains(trophy) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(hex: 0x3DDC97))
                    } else {
                        RewardLabel(reward: trophy.reward)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(won.contains(trophy) ? 0.95 : 0.7)))
            }
            Button(action: showLeaderboards) {
                Label("See how friends did", systemImage: "person.2.fill")
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0xA259FF), compact: true))
            .padding(.top, 4)
        }
    }
}
