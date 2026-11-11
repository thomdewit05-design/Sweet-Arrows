import SwiftUI
import SweetArrowsCore

/// Spend the coins earned by playing on boosters and new looks. No real-money purchases.
struct ShopView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.save.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    JellyView(size: 54)
                    Spacer()
                    CoinBadge(coins: progress.coins)
                }
                section("Boosters") {
                    ForEach(Booster.allCases, id: \.self) { booster in
                        BoosterRow(booster: booster, stock: progress.boosters[booster],
                                   affordable: progress.coins >= booster.price) {
                            buyBooster(booster)
                        }
                    }
                }
                section("Counters") {
                    cosmeticsGrid(.board, progress: progress)
                }
                section("Candy styles") {
                    cosmeticsGrid(.candyStyle, progress: progress)
                }
                section("Backdrops") {
                    Text("A new backdrop comes free at levels 3, 6, 10 and 15.")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                    cosmeticsGrid(.backdrop, progress: progress)
                }
            }
            .padding()
        }
        .background(CandySkyBackground(colors: [Color(hex: 0xBDEBFF), Color(hex: 0xE4D9FF), Color(hex: 0xFFD6E6)]))
        .safeAreaInset(edge: .bottom) {
            if model.showsBanner {
                BannerAdView(adUnitID: model.ads.bannerAdUnitID)
            }
        }
        .navigationTitle(Text("Shop"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.analytics.log(.storeOpen) }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.heading())
                .foregroundStyle(Theme.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .candyCard()
    }

    private func cosmeticsGrid(_ kind: Cosmetic.Kind, progress: PlayerProgress) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Cosmetic.items(of: kind), id: \.self) { item in
                CosmeticCard(
                    item: item,
                    owned: progress.ownedCosmetics.contains(item),
                    equipped: progress.board == item || progress.candyStyle == item || progress.backdrop == item,
                    affordable: progress.coins >= item.price,
                    lockedUntil: item.unlockLevel.flatMap { $0 > progress.level ? $0 : nil }
                ) { tapped(item) }
            }
        }
    }

    private func buyBooster(_ booster: Booster) {
        var bought = false
        model.save.update { progress in
            guard progress.coins >= booster.price else { return }
            progress.coins -= booster.price
            progress.boosters.add(booster)
            bought = true
        }
        if bought {
            model.audio.play(.coin)
            model.haptics.tap()
        }
    }

    private func tapped(_ item: Cosmetic) {
        if model.save.progress.ownedCosmetics.contains(item) {
            model.save.update { $0.equip(item) }
            model.haptics.tap()
            return
        }
        var bought = false
        model.save.update { progress in
            bought = progress.buy(item)
            if bought { progress.equip(item) }
        }
        if bought {
            model.audio.play(.coin)
            model.haptics.success()
            model.analytics.log(.cosmeticBought(item: item.rawValue, price: item.price))
        }
    }
}

private struct BoosterRow: View {
    let booster: Booster
    let stock: Int
    let affordable: Bool
    let buy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: booster.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(booster.localizedName)
                    .font(Theme.heading(17))
                    .foregroundStyle(Theme.ink)
                Text("In stock: \(stock)")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Button(action: buy) {
                Label("\(booster.price)", systemImage: "circle.fill")
                    .font(Theme.heading(16))
            }
            .buttonStyle(CandyButtonStyle(color: Theme.gold, foreground: Theme.ink))
            .disabled(!affordable)
            .opacity(affordable ? 1 : 0.45)
        }
    }
}

private struct CosmeticCard: View {
    let item: Cosmetic
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    /// Backdrops not reached yet: the level that unlocks them.
    var lockedUntil: Int?
    let action: () -> Void

    private var usable: Bool { lockedUntil == nil && (owned || affordable) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 70)
                Text(item.localizedName)
                    .font(Theme.heading(15))
                    .foregroundStyle(Theme.ink)
                Group {
                    if let level = lockedUntil {
                        Label("Level \(level)", systemImage: "lock.fill")
                    } else if equipped {
                        Label("In use", systemImage: "checkmark.circle.fill")
                    } else if owned {
                        Text("Use")
                    } else {
                        Label("\(item.price)", systemImage: "circle.fill")
                    }
                }
                .font(Theme.body(13))
                .foregroundStyle(equipped ? Color(hex: 0x3DDC97) : Theme.inkSoft)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(equipped ? Theme.heart : .clear, lineWidth: 3))
            )
        }
        .disabled(!usable)
        .opacity(usable ? 1 : 0.55)
    }

    @ViewBuilder private var preview: some View {
        switch item.kind {
        case .board:
            let palette = BoardPalette(item)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: palette.fill))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: palette.edge), lineWidth: 4))
        case .candyStyle:
            HStack(spacing: 6) {
                ForEach([CandyColor.strawberry, .lemon, .blueberry], id: \.self) { color in
                    Circle()
                        .fill(item == .pastelCandy ? Theme.color(color).opacity(0.6) : Theme.color(color))
                        .overlay(Circle().stroke(
                            item == .goldenCandy ? Theme.gold : .white,
                            lineWidth: item == .goldenCandy ? 3 : 2
                        ))
                        .overlay(alignment: .topTrailing) {
                            if item == .sparkleCandy {
                                Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 30, height: 30)
                }
            }
        case .backdrop:
            Image(uiImage: BackdropArt.image(for: item, size: CGSize(width: 120, height: 70)))
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension Cosmetic {
    var localizedName: LocalizedStringKey {
        switch self {
        case .woodCounter: "Wooden counter"
        case .mintMarble: "Mint marble"
        case .strawberryCheck: "Strawberry check"
        case .midnightCandy: "Midnight candy"
        case .classicCandy: "Classic"
        case .pastelCandy: "Pastel"
        case .sparkleCandy: "Sparkle"
        case .goldenCandy: "Golden"
        case .candyMeadow: "Candy meadow"
        case .iceCreamBay: "Ice cream bay"
        case .chocolateRiver: "Chocolate river"
        case .cottonSky: "Cotton candy sky"
        case .starryNight: "Starry night"
        }
    }
}
