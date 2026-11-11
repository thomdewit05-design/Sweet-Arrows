import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// The events from docs/PLAN.md ("Data & LiveOps").
enum AnalyticsEvent: Equatable, Sendable {
    case sessionStart
    case boosterUsed(type: String, source: String)
    case tutorialStep(step: Int)
    case dailyRewardClaimed(day: Int, doubled: Bool)
    case storeOpen
    case cosmeticBought(item: String, price: Int)
    case adOfferShown(reason: String)
    case adOfferAccepted(reason: String)
    case adImpression(format: String, network: String, value: Double, currency: String)
    case purchase(product: String, price: Double)
    case subscriptionStart(product: String)
    case endlessStart
    case endlessOver(score: Int, seconds: Int, stage: Int)

    var name: String {
        switch self {
        case .sessionStart: "session_start"
        case .boosterUsed: "booster_used"
        case .tutorialStep: "tutorial_step"
        case .dailyRewardClaimed: "daily_reward_claimed"
        case .storeOpen: "store_open"
        case .cosmeticBought: "cosmetic_bought"
        case .adOfferShown: "ad_offer_shown"
        case .adOfferAccepted: "ad_offer_accepted"
        case .adImpression: "ad_impression"
        case .purchase: "purchase"
        case .subscriptionStart: "subscription_start"
        case .endlessStart: "endless_start"
        case .endlessOver: "endless_over"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .sessionStart: [:]
        case let .boosterUsed(type, source): ["type": type, "source": source]
        case .tutorialStep(let step): ["step": "\(step)"]
        case let .dailyRewardClaimed(day, doubled): ["day": "\(day)", "doubled": doubled ? "1" : "0"]
        case .storeOpen: [:]
        case let .cosmeticBought(item, price): ["item": item, "price": "\(price)"]
        case .adOfferShown(let reason), .adOfferAccepted(let reason): ["reason": reason]
        case let .adImpression(format, network, value, currency):
            ["format": format, "network": network, "value": String(value), "currency": currency]
        case let .purchase(product, price): ["product": product, "price": String(price)]
        case .subscriptionStart(let product): ["product": product]
        case .endlessStart: [:]
        case let .endlessOver(score, seconds, stage): ["score": "\(score)", "seconds": "\(seconds)", "stage": "\(stage)"]
        }
    }
}

@MainActor
protocol AnalyticsService: AnyObject {
    func log(_ event: AnalyticsEvent)
}

/// Sends events to Firebase when a GoogleService-Info.plist is present; otherwise logs to the console.
@MainActor
final class FirebaseAnalyticsService: AnalyticsService {
    private let firebaseEnabled: Bool

    init() {
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            if FirebaseApp.app() == nil { FirebaseApp.configure() }
            firebaseEnabled = true
        } else {
            firebaseEnabled = false
        }
        #else
        firebaseEnabled = false
        #endif
    }

    func log(_ event: AnalyticsEvent) {
        #if canImport(FirebaseAnalytics)
        if firebaseEnabled {
            Analytics.logEvent(event.name, parameters: event.parameters)
            return
        }
        #endif
        #if DEBUG
        print("📊 \(event.name) \(event.parameters)")
        #endif
    }
}
