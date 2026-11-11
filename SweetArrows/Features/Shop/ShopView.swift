import StoreKit
import SwiftUI
import SweetArrowsCore

/// Coins, boosters and looks, plus the real-money offers: VIP, Remove Ads, coin packs and the starter pack.
struct ShopView: View {
    @Environment(AppModel.self) private var model
    @State private var showVIP = false
    @State private var busy = false

    var body: some View {
        let progress = model.save.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    JellyView(size: 54)
                    Spacer()
                    CoinBadge(coins: progress.coins)
                }
                section("Without ads") {
                    VIPCard(isVIP: model.purchases.isVIP) { showVIP = true }
                    if !model.purchases.hasRemovedAds && !model.purchases.isVIP {
                        StoreRow(
                            icon: "nosign", title: "Remove Ads",
                            subtitle: "No more interstitials, banners or app-open ads. Rewarded stays optional.",
                            price: model.purchases.products[.removeAds]?.displayPrice
                        ) { buy(.removeAds) }
                    }
                }
                if model.showsStarterPack {
                    section("Starter pack") {
                        StoreRow(
                            icon: "gift.fill", title: "Starter pack",
                            subtitle: "1,000 coins and 3 of every booster. Only once.",
                            price: model.purchases.products[.starterPack]?.displayPrice
                        ) { buy(.starterPack) }
                    }
                }
                section("Coins") {
                    ForEach(StoreProduct.coinPacks, id: \.self) { pack in
                        StoreRow(
                            icon: "circle.fill", title: "\(pack.reward?.coins ?? 0) coins", subtitle: nil,
                            price: model.purchases.products[pack]?.displayPrice
                        ) { buy(pack) }
                    }
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
                Button("Restore purchases") {
                    Task { await model.purchases.restorePurchases() }
                }
                .font(Theme.body(15))
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .disabled(busy)
        .sheet(isPresented: $showVIP) {
            VIPStoreSheet {
                await model.purchases.refreshEntitlements()
                model.grantVIPBonusIfNeeded()
                showVIP = false
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.ads.canShowBanner {
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
    }

    private func cosmeticsGrid(_ kind: Cosmetic.Kind, progress: PlayerProgress) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Cosmetic.items(of: kind).filter { !$0.vipOnly || model.purchases.isVIP }, id: \.self) { item in
                CosmeticCard(
                    item: item,
                    owned: progress.ownedCosmetics.contains(item) || item.vipOnly,
                    equipped: progress.board == item || progress.candyStyle == item,
                    affordable: progress.coins >= item.price
                ) { tapped(item) }
            }
        }
    }

    private func buy(_ product: StoreProduct) {
        busy = true
        Task { @MainActor in
            if await model.purchases.purchase(product) {
                model.audio.play(.coin)
                model.haptics.success()
                model.grantVIPBonusIfNeeded()
            }
            busy = false
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
        let isVIP = model.purchases.isVIP
        if model.save.progress.ownedCosmetics.contains(item) || item.vipOnly {
            model.save.update { $0.equip(item, isVIP: isVIP) }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 70)
                Text(item.localizedName)
                    .font(Theme.heading(15))
                    .foregroundStyle(Theme.ink)
                Group {
                    if equipped {
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
        .disabled(!owned && !affordable)
        .opacity(!owned && !affordable ? 0.55 : 1)
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
        }
    }
}

/// The VIP subscription sheet (StoreKit's SubscriptionStoreView with our own header).
private struct VIPStoreSheet: View {
    let purchased: @MainActor () async -> Void

    var body: some View {
        SubscriptionStoreView(productIDs: StoreProduct.vipGroup.map(\.rawValue), marketingContent: {
            VIPHeader()
        })
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .onInAppPurchaseCompletion { _, _ in
            await purchased()
        }
    }
}

private struct VIPHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            JellyView(size: 70)
            Text("Sweet Arrows VIP")
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
            Text("No ads · 3 free hints every day · golden candy style · rewards without watching")
                .font(Theme.body())
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct VIPCard: View {
    let isVIP: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isVIP ? "You are VIP" : "Sweet Arrows VIP")
                        .font(Theme.heading(18))
                        .foregroundStyle(.white)
                    Text("No ads, daily hints and more. 3 days free.")
                        .font(Theme.body(13))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(
                colors: [Color(hex: 0xA259FF), Color(hex: 0xFF5C8A)], startPoint: .leading, endPoint: .trailing
            )))
        }
    }
}

private struct StoreRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let price: String?
    let buy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(icon == "circle.fill" ? Theme.gold : Theme.ink)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.heading(17))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            Button(action: buy) {
                Text(price ?? "…")
                    .font(Theme.heading(15))
            }
            .buttonStyle(CandyButtonStyle(color: Color(hex: 0x3DDC97)))
            .disabled(price == nil)
        }
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
        case .goldenCandy: "Golden (VIP)"
        }
    }
}
