//
//  AnalyticsManager.swift
//  Yumo
//
//  Centralized analytics tracking using PostHog
//  Tracks user events, screen views, and user properties
//

import Foundation
import PostHog

/// Centralized analytics manager for tracking user behavior
@MainActor
final class AnalyticsManager {
    
    static let shared = AnalyticsManager()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Initialize PostHog with API key and configuration
    func configure() {
        let config = PostHogConfig(
            apiKey: "phc_q1pibqai4usvV8DJTCJrmQVpS5pk6jYqI2VAKDVsAfT",
            host: "https://us.i.posthog.com"
        )
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.debug = false // Set to true for debugging
        
        PostHogSDK.shared.setup(config)
        
        #if DEBUG
        print("📊 PostHog analytics initialized")
        #endif
    }
    
    // MARK: - User Identification
    
    /// Identify a user after sign-in
    func identify(userId: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.identify(userId, userProperties: properties)
        
        #if DEBUG
        print("📊 Identified user: \(userId)")
        #endif
    }
    
    /// Reset user identity on sign-out
    func reset() {
        PostHogSDK.shared.reset()
        
        #if DEBUG
        print("📊 Analytics reset (user signed out)")
        #endif
    }
    
    /// Set user properties (e.g., premium status, goals)
    func setUserProperties(_ properties: [String: Any]) {
        PostHogSDK.shared.capture("$set", properties: ["$set": properties])
    }
    
    // MARK: - Screen Tracking
    
    /// Track screen view
    func trackScreen(_ screenName: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.screen(screenName, properties: properties)
    }
    
    // MARK: - Event Tracking
    
    /// Track a custom event
    func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
        
        #if DEBUG
        print("📊 Event: \(event.rawValue) \(properties ?? [:])")
        #endif
    }
    
    // MARK: - Convenience Methods
    
    /// Track food logged
    func trackFoodLogged(name: String, calories: Double, source: FoodLogSource) {
        track(.foodLogged, properties: [
            "food_name": name,
            "calories": calories,
            "source": source.rawValue
        ])
    }
    
    /// Track water logged
    func trackWaterLogged(amountML: Double) {
        track(.waterLogged, properties: [
            "amount_ml": amountML
        ])
    }
    
    /// Track weight logged
    func trackWeightLogged(weightKg: Double) {
        track(.weightLogged, properties: [
            "weight_kg": weightKg
        ])
    }
    
    /// Track fast started
    func trackFastStarted(goalHours: Double) {
        track(.fastStarted, properties: [
            "goal_hours": goalHours
        ])
    }
    
    /// Track fast ended
    func trackFastEnded(durationHours: Double, completed: Bool) {
        track(.fastEnded, properties: [
            "duration_hours": durationHours,
            "completed": completed
        ])
    }
    
    /// Track recipe created
    func trackRecipeCreated(name: String, ingredientCount: Int) {
        track(.recipeCreated, properties: [
            "recipe_name": name,
            "ingredient_count": ingredientCount
        ])
    }
    
    /// Track barcode scanned
    func trackBarcodeScanned(found: Bool, barcode: String? = nil) {
        track(.barcodeScanned, properties: [
            "found": found,
            "barcode": barcode ?? ""
        ])
    }
    
    /// Track AI scan used
    func trackAIScanUsed(success: Bool, itemsDetected: Int) {
        track(.aiScanUsed, properties: [
            "success": success,
            "items_detected": itemsDetected
        ])
    }
    
    /// Track search performed
    func trackSearchPerformed(query: String, resultCount: Int) {
        track(.searchPerformed, properties: [
            "query_length": query.count,
            "result_count": resultCount
        ])
    }
    
    /// Track onboarding step
    func trackOnboardingStep(step: Int, stepName: String) {
        track(.onboardingStep, properties: [
            "step": step,
            "step_name": stepName
        ])
    }
    
    /// Track onboarding completed
    func trackOnboardingCompleted(signedIn: Bool, authMethod: String?) {
        track(.onboardingCompleted, properties: [
            "signed_in": signedIn,
            "auth_method": authMethod ?? "none"
        ])
    }
    
    /// Track sign-in
    func trackSignIn(method: AuthMethod) {
        track(.signedIn, properties: [
            "method": method.rawValue
        ])
    }
    
    /// Track sign-out
    func trackSignOut() {
        track(.signedOut)
    }
    
    /// Track paywall viewed
    func trackPaywallViewed(trigger: String) {
        track(.paywallViewed, properties: [
            "trigger": trigger
        ])
    }
    
    /// Track subscription purchased
    func trackSubscriptionPurchased(plan: String) {
        track(.subscriptionPurchased, properties: [
            "plan": plan
        ])
    }
    
    /// Track feature used
    func trackFeatureUsed(_ feature: AppFeature) {
        track(.featureUsed, properties: [
            "feature": feature.rawValue
        ])
    }
    
    /// Track error occurred
    func trackError(_ error: String, context: String) {
        track(.errorOccurred, properties: [
            "error": error,
            "context": context
        ])
    }
}

// MARK: - Analytics Event Types

enum AnalyticsEvent: String {
    // Core Actions
    case foodLogged = "food_logged"
    case foodDeleted = "food_deleted"
    case foodEdited = "food_edited"
    case waterLogged = "water_logged"
    case weightLogged = "weight_logged"
    case fastStarted = "fast_started"
    case fastEnded = "fast_ended"
    case recipeCreated = "recipe_created"
    case recipeLogged = "recipe_logged"
    case reminderCreated = "reminder_created"
    
    // Scanning & Search
    case barcodeScanned = "barcode_scanned"
    case aiScanUsed = "ai_scan_used"
    case searchPerformed = "search_performed"
    case quickMealUsed = "quick_meal_used"
    
    // Onboarding & Auth
    case onboardingStep = "onboarding_step"
    case onboardingCompleted = "onboarding_completed"
    case signedIn = "signed_in"
    case signedOut = "signed_out"
    
    // Premium & Monetization
    case paywallViewed = "paywall_viewed"
    case paywallDismissed = "paywall_dismissed"
    case subscriptionPurchased = "subscription_purchased"
    case freeTrialStarted = "free_trial_started"
    
    // Features
    case featureUsed = "feature_used"
    case reportViewed = "report_viewed"
    case widgetConfigured = "widget_configured"
    case settingsChanged = "settings_changed"
    
    // Sync & Cloud
    case syncStarted = "sync_started"
    case syncCompleted = "sync_completed"
    case syncFailed = "sync_failed"
    
    // Errors
    case errorOccurred = "error_occurred"
}

// MARK: - Supporting Enums

enum FoodLogSource: String {
    case search = "search"
    case barcode = "barcode"
    case aiScan = "ai_scan"
    case quickMeal = "quick_meal"
    case recipe = "recipe"
    case manual = "manual"
    case history = "history"
}

enum AuthMethod: String {
    case apple = "apple"
    case google = "google"
    case email = "email"
}

enum AppFeature: String {
    case waterTracker = "water_tracker"
    case fastingTracker = "fasting_tracker"
    case weightTracker = "weight_tracker"
    case recipes = "recipes"
    case reports = "reports"
    case aiScan = "ai_scan"
    case barcodeScanner = "barcode_scanner"
    case quickMeal = "quick_meal"
    case nutritionLabel = "nutrition_label"
    case reminders = "reminders"
    case lockScreenWidget = "lock_screen_widget"
    case homeScreenWidget = "home_screen_widget"
}
