import Foundation

/// StoreKit 2 purchases: Remove Ads, VIP subscription, coin packs. Implemented in phase 7.
@MainActor
protocol PurchaseService: AnyObject {
    var hasRemovedAds: Bool { get }
    var isVIP: Bool { get }
    func restorePurchases() async
}

@MainActor
final class PlaceholderPurchaseService: PurchaseService {
    private(set) var hasRemovedAds = false
    private(set) var isVIP = false
    func restorePurchases() async {}
}
