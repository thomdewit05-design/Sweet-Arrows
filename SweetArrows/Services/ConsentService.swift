import AppTrackingTransparency
import Foundation
import UIKit
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// Consent flow: first Google UMP (the GDPR form in the EEA), then App Tracking Transparency
/// behind our own friendly pre-screen. No ad is requested before UMP says it may be.
@MainActor
protocol ConsentService: AnyObject {
    var canRequestAds: Bool { get }
    /// True when iOS has not asked about tracking yet.
    var needsTrackingPrompt: Bool { get }
    /// True when the privacy options button must be offered (EEA users).
    var privacyOptionsRequired: Bool { get }
    func gatherConsent() async
    func requestTracking() async
    func presentPrivacyOptions() async
}

@MainActor
final class GoogleConsentService: ConsentService {
    var canRequestAds: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.canRequestAds
        #else
        false
        #endif
    }

    var needsTrackingPrompt: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .notDetermined
    }

    var privacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        false
        #endif
    }

    func gatherConsent() async {
        #if canImport(UserMessagingPlatform)
        let parameters = RequestParameters()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { @Sendable _ in
                onMain {
                    ConsentForm.loadAndPresentIfRequired(from: UIApplication.topViewController()) { @Sendable _ in
                        done.resume()
                    }
                }
            }
        }
        #endif
    }

    func requestTracking() async {
        guard needsTrackingPrompt else { return }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            // iOS answers on a background thread.
            ATTrackingManager.requestTrackingAuthorization { @Sendable _ in done.resume() }
        }
    }

    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            ConsentForm.presentPrivacyOptionsForm(from: UIApplication.topViewController()) { _ in
                done.resume()
            }
        }
        #endif
    }
}

/// No consent flow: previews, tests and UI tests.
@MainActor
final class PlaceholderConsentService: ConsentService {
    let canRequestAds = false
    let needsTrackingPrompt = false
    let privacyOptionsRequired = false
    func gatherConsent() async {}
    func requestTracking() async {}
    func presentPrivacyOptions() async {}
}

extension UIApplication {
    /// The view controller on top, to present ads and system forms from.
    static func topViewController() -> UIViewController? {
        let root = shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
