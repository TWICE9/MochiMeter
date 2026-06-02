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
    // NOTE: Using production IDs
    
    #if DEBUG
    // Google's "always-fill" test banner ID — production builds use the real IDs below.
    // This is required because production ad units often have no test inventory.
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let reportsBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let activityBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let planBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    #else
    static let bannerAdUnitID = "ca-app-pub-1465033379713828/3633193401"
    static let reportsBannerAdUnitID = "ca-app-pub-1465033379713828/9647937415"
    static let activityBannerAdUnitID = "ca-app-pub-1465033379713828/1252080522"
    static let planBannerAdUnitID = "ca-app-pub-1465033379713828/4315327752"
    #endif
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    /// Initialize AdMob SDK (call this in app startup)
    func initializeAds() {
        #if DEBUG
        // Dev devices need to be registered as test devices, otherwise Google
        // returns "No ad to show". Hashes come from the AdMob SDK console log
        // on first launch ("To get test ads on this device, set: ...").
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "fa7cefa1cf5af39a9713a2d43a7bc33b"
        ]
        #endif
        MobileAds.shared.start { status in
            print("📱 AdMob initialized")
        }
    }
    
    /// Check if ads should be shown for current user
    func shouldShowAds() -> Bool {
        // Don't show ads if user is subscribed
        if StoreKitManager.shared.isPremium {
            return false
        }
        
        // Don't show during onboarding
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            return false
        }
        
        return true
    }
}
