import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Adaptive AdMob banner: in the shop and, by the owner's choice, under the game board
/// (below the booster bar, never over the board or its buttons).
struct BannerAdView: View {
    let adUnitID: String

    var body: some View {
        GeometryReader { proxy in
            BannerRepresentable(adUnitID: adUnitID, width: proxy.size.width)
        }
        .frame(height: 60)
        .background(Theme.cream)
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: max(width, 320)))
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.topViewController()
        banner.load(Request())
        return banner
        #else
        return UIView()
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
