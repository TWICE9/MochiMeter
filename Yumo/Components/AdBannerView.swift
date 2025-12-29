//
//  AdBannerView.swift
//  Yumo
//

import SwiftUI
import GoogleMobileAds

/// SwiftUI wrapper for Google AdMob Banner
struct AdBannerView: UIViewRepresentable {
    @EnvironmentObject var adManager: AdManager
    var adUnitID: String
    @Binding var isAdLoaded: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = getRootViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    private func getRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.rootViewController
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        var parent: AdBannerView
        
        init(_ parent: AdBannerView) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("🟢 AdMob Banner Loaded")
            withAnimation {
                parent.isAdLoaded = true
            }
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("🔴 AdMob Banner Failed: \(error.localizedDescription)")
            withAnimation {
                parent.isAdLoaded = false
            }
        }
    }
}

/// Conditional ad banner that respects subscription status and load state
struct ConditionalAdBanner: View {
    @EnvironmentObject var adManager: AdManager
    @EnvironmentObject var superwallManager: SuperwallManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAdLoaded = false
    
    var adUnitID: String = AdManager.bannerAdUnitID
    
    var body: some View {
        // Only show if user is NOT premium AND ads should show
        if !superwallManager.isPremium && adManager.shouldShowAds() {
            VStack(spacing: 0) {
                // Only show content if ad is actually loaded to avoid empty space
                if isAdLoaded {
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                }
                
                AdBannerView(adUnitID: adUnitID, isAdLoaded: $isAdLoaded)
                    .frame(height: isAdLoaded ? 50 : 0) // Collapse height if not loaded
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .opacity(isAdLoaded ? 1 : 0) // Fade in/out
            }
            .animation(.easeInOut, value: isAdLoaded)
        }
    }
}
