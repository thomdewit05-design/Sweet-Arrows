import Foundation

/// Consent flow: first Google UMP (EU), then App Tracking Transparency with our own pre-screen.
/// No ad is loaded before this flow has finished. Implemented in phase 6.
@MainActor
protocol ConsentService: AnyObject {
    var canRequestAds: Bool { get }
    func gatherConsent() async
    func presentPrivacyOptions() async
}

@MainActor
final class PlaceholderConsentService: ConsentService {
    private(set) var canRequestAds = false
    func gatherConsent() async {}
    func presentPrivacyOptions() async {}
}
