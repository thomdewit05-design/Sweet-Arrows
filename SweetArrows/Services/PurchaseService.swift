import Foundation
import Observation
import StoreKit
import SweetArrowsCore

/// In-app products. Create the same ids in App Store Connect (see docs/STATUS.md).
enum StoreProduct: String, CaseIterable, Sendable {
    case removeAds = "com.lucthomasdewit.sweetarrows.removeads"
    case vipWeekly = "com.lucthomasdewit.sweetarrows.vip.weekly"
    case vipMonthly = "com.lucthomasdewit.sweetarrows.vip.monthly"
    case coinsSmall = "com.lucthomasdewit.sweetarrows.coins.500"
    case coinsMedium = "com.lucthomasdewit.sweetarrows.coins.1500"
    case coinsLarge = "com.lucthomasdewit.sweetarrows.coins.4000"
    case coinsHuge = "com.lucthomasdewit.sweetarrows.coins.10000"
    case starterPack = "com.lucthomasdewit.sweetarrows.starterpack"

    static let vipGroup: [StoreProduct] = [.vipWeekly, .vipMonthly]
    static let coinPacks: [StoreProduct] = [.coinsSmall, .coinsMedium, .coinsLarge, .coinsHuge]

    /// What a consumable gives.
    var reward: Reward? {
        switch self {
        case .coinsSmall: Reward(coins: 500)
        case .coinsMedium: Reward(coins: 1500)
        case .coinsLarge: Reward(coins: 4000)
        case .coinsHuge: Reward(coins: 10_000)
        case .starterPack: Reward(coins: 1000, boosters: [.hint: 3, .removeCandy: 3, .extraSlot: 3])
        case .removeAds, .vipWeekly, .vipMonthly: nil
        }
    }
}

/// StoreKit 2 purchases: Remove Ads, VIP subscription, coin packs, starter pack.
@MainActor
protocol PurchaseService: AnyObject {
    var hasRemovedAds: Bool { get }
    var isVIP: Bool { get }
    var products: [StoreProduct: Product] { get }
    func loadProducts() async
    /// Returns true when the purchase went through.
    func purchase(_ product: StoreProduct) async -> Bool
    func restorePurchases() async
    func refreshEntitlements() async
}

@MainActor
@Observable
final class StoreKitPurchaseService: PurchaseService {
    private(set) var hasRemovedAds: Bool
    private(set) var isVIP: Bool
    private(set) var products: [StoreProduct: Product] = [:]
    private let save: SaveService
    private let analytics: AnalyticsService
    @ObservationIgnored private var updates: Task<Void, Never>?
    private static let cacheKey = "entitlements.v1"

    init(save: SaveService, analytics: AnalyticsService) {
        self.save = save
        self.analytics = analytics
        // Cached so ads stay off at launch, even offline, before StoreKit answers.
        let cached = UserDefaults.standard.stringArray(forKey: Self.cacheKey) ?? []
        hasRemovedAds = cached.contains("removeAds")
        isVIP = cached.contains("vip")
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: StoreProduct.allCases.map(\.rawValue)) else { return }
        var map: [StoreProduct: Product] = [:]
        for product in loaded {
            if let id = StoreProduct(rawValue: product.id) { map[id] = product }
        }
        products = map
    }

    func purchase(_ item: StoreProduct) async -> Bool {
        guard let product = products[item] else { return false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                return await handle(verification)
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var removeAds = false
        var vip = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  let item = StoreProduct(rawValue: transaction.productID)
            else { continue }
            if item == .removeAds { removeAds = true }
            if StoreProduct.vipGroup.contains(item) { vip = true }
        }
        hasRemovedAds = removeAds
        isVIP = vip
        var cache: [String] = []
        if removeAds { cache.append("removeAds") }
        if vip { cache.append("vip") }
        UserDefaults.standard.set(cache, forKey: Self.cacheKey)
    }

    /// Grants a verified transaction exactly once, then finishes it.
    @discardableResult
    private func handle(_ verification: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = verification,
              let item = StoreProduct(rawValue: transaction.productID)
        else { return false }
        if let reward = item.reward, transaction.revocationDate == nil {
            save.update { progress in
                progress.apply(reward)
                if item == .starterPack { progress.starterPackBought = true }
            }
        }
        await transaction.finish()
        await refreshEntitlements()
        let price = products[item]?.price ?? 0
        analytics.log(.purchase(product: item.rawValue, price: NSDecimalNumber(decimal: price).doubleValue))
        if StoreProduct.vipGroup.contains(item) { analytics.log(.subscriptionStart(product: item.rawValue)) }
        return true
    }
}

/// No store: previews, tests and UI tests.
@MainActor
final class PlaceholderPurchaseService: PurchaseService {
    var hasRemovedAds = false
    var isVIP = false
    let products: [StoreProduct: Product] = [:]
    func loadProducts() async {}
    func purchase(_ product: StoreProduct) async -> Bool { false }
    func restorePurchases() async {}
    func refreshEntitlements() async {}
}
