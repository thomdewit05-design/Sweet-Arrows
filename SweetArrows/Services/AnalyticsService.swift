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
    case levelStart(level: Int)
    case levelComplete(level: Int, moves: Int, seconds: Int, stars: Int)
    case levelFail(level: Int, reason: String, moves: Int)
    case levelQuit(level: Int, moves: Int)
    case boosterUsed(type: String, source: String)
    case tutorialStep(step: Int)
    case dailyRewardClaimed(day: Int, doubled: Bool)
    case storeOpen
    case cosmeticBought(item: String, price: Int)
    case adOfferShown(reason: String)
    case adOfferAccepted(reason: String)
    case adImpression(format: String, network: String, value: Double, currency: String)

    var name: String {
        switch self {
        case .sessionStart: "session_start"
        case .levelStart: "level_start"
        case .levelComplete: "level_complete"
        case .levelFail: "level_fail"
        case .levelQuit: "level_quit"
        case .boosterUsed: "booster_used"
        case .tutorialStep: "tutorial_step"
        case .dailyRewardClaimed: "daily_reward_claimed"
        case .storeOpen: "store_open"
        case .cosmeticBought: "cosmetic_bought"
        case .adOfferShown: "ad_offer_shown"
        case .adOfferAccepted: "ad_offer_accepted"
        case .adImpression: "ad_impression"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .sessionStart: [:]
        case .levelStart(let level): ["level": "\(level)"]
        case let .levelComplete(level, moves, seconds, stars):
            ["level": "\(level)", "moves": "\(moves)", "seconds": "\(seconds)", "stars": "\(stars)"]
        case let .levelFail(level, reason, moves): ["level": "\(level)", "reason": reason, "moves": "\(moves)"]
        case let .levelQuit(level, moves): ["level": "\(level)", "moves": "\(moves)"]
        case let .boosterUsed(type, source): ["type": type, "source": source]
        case .tutorialStep(let step): ["step": "\(step)"]
        case let .dailyRewardClaimed(day, doubled): ["day": "\(day)", "doubled": doubled ? "1" : "0"]
        case .storeOpen: [:]
        case let .cosmeticBought(item, price): ["item": item, "price": "\(price)"]
        case .adOfferShown(let reason), .adOfferAccepted(let reason): ["reason": reason]
        case let .adImpression(format, network, value, currency):
            ["format": format, "network": network, "value": String(value), "currency": currency]
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
