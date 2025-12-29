//
//  AdManager.swift
//  Yumo
//

import Foundation
import SwiftUI
import Combine
import GoogleMobileAds

class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published var isAdEnabled: Bool = true
    
    // MARK: - Ad Unit IDs
    // NOTE: Replace these with your actual Ad Unit IDs from AdMob dashboard
    #if DEBUG
    // Test IDs for development
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Test Banner
    static let reportsBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Test Banner
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Test Interstitial
    #else
    // Production IDs - REPLACE THESE WITH YOUR ACTUAL IDs
    static let bannerAdUnitID = "ca-app-pub-1465033379713828/3633193401"
    static let reportsBannerAdUnitID = "ca-app-pub-1465033379713828/9647937415"
    static let interstitialAdUnitID = "YOUR_INTERSTITIAL_AD_UNIT_ID"
    #endif
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    /// Initialize AdMob SDK (call this in app startup)
    func initializeAds() {
        MobileAds.shared.start { status in
            print("📱 AdMob initialized")
        }
    }
    
    /// Check if ads should be shown for current user
    func shouldShowAds() -> Bool {
        // Don't show ads if user is subscribed
        if SuperwallManager.shared.isPremium {
            return false
        }
        
        // Don't show during onboarding
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            return false
        }
        
        return true
    }
}
