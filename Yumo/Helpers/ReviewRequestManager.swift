//
//  ReviewRequestManager.swift
//  Yumo
//

import SwiftUI
import StoreKit

class ReviewRequestManager {
    static let shared = ReviewRequestManager()
    
    private let hasRequestedReviewKey = "hasRequestedAppReview"
    private let foodLogCountKey = "totalFoodLogsCount"
    
    private init() {}
    
    /// Call this after successfully logging a food item
    func checkAndRequestReview() {
        // Only request review once
        guard !UserDefaults.standard.bool(forKey: hasRequestedReviewKey) else {
            return
        }
        
        // Increment food log count
        let currentCount = UserDefaults.standard.integer(forKey: foodLogCountKey)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: foodLogCountKey)
        
        // Request review after first food log
        if newCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.requestReview()
            }
        }
    }
    
    private func requestReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)
        }
    }
    
    /// Reset for testing purposes
    func resetReviewRequest() {
        UserDefaults.standard.removeObject(forKey: hasRequestedReviewKey)
        UserDefaults.standard.removeObject(forKey: foodLogCountKey)
    }
}
