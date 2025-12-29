//
//  AdBannerView.swift
//  Yumo
//

import SwiftUI
import GoogleMobileAds

/// SwiftUI wrapper for Google AdMob Banner
struct AdBannerView: UIViewRepresentable {
    @EnvironmentObject var adManager: AdManager
    var adUnitID: String = AdManager.bannerAdUnitID // Default to Home Banner ID
    
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = getRootViewController()
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    private func getRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.rootViewController
    }
}

/// Conditional ad banner that respects subscription status
struct ConditionalAdBanner: View {
    @EnvironmentObject var adManager: AdManager
    @EnvironmentObject var superwallManager: SuperwallManager // Observe premium status changes
    @Environment(\.colorScheme) private var colorScheme
    
    var adUnitID: String = AdManager.bannerAdUnitID
    
    var body: some View {
        // Check premium status directly from the source of truth
        if !superwallManager.isPremium && adManager.shouldShowAds() {
            VStack(spacing: 0) {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                
                AdBannerView(adUnitID: adUnitID)
                    .frame(height: 50)
                    .background(colorScheme == .dark ? Color.black : Color.white)
            }
        }
    }
}
