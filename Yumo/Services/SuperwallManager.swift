//
//  SuperwallManager.swift
//  Yumo
//
//  Superwall SDK configuration and management
//

import Foundation
import Combine
import SuperwallKit
import StoreKit
import Supabase
import UIKit

@MainActor
class SuperwallManager: ObservableObject {
    static let shared = SuperwallManager()

    @Published var isPremium: Bool = false
    @Published var isLoadingPremiumStatus: Bool = false
    
    // Track current UI style preference
    var currentAppearance: UIUserInterfaceStyle = .unspecified

    // Track Supabase premium override separately
    private var supabasePremium: Bool = false

    private init() {}

    /// Configure Superwall on app launch
    func configure() {
        // Configure Superwall with API key from Secrets.xcconfig
        Superwall.configure(apiKey: Secrets.superwallAPIKey)

        // Set up delegate for handling events
        Superwall.shared.delegate = self

        // Don't check premium status on launch to avoid Apple ID prompt
        // Status will be checked when user interacts with paywall

        #if DEBUG
        print("Superwall configured")
        #endif
    }

    /// Show the paywall
    func showPaywall() {
        Task {
            // Check subscription status first (only when user explicitly requests paywall)
            await checkPremiumStatus()

            // Register the placement to trigger the paywall
            Superwall.shared.register(placement: "show_paywall")
        }
    }

    /// Check if user has premium subscription (from Superwall OR Supabase override)
    func checkPremiumStatus() async {
        isLoadingPremiumStatus = true

        // Check Supabase for premium override first
        await checkSupabasePremium()

        // Check subscription status via Superwall
        let subscriptionStatus = Superwall.shared.subscriptionStatus

        let superwallActive: Bool
        switch subscriptionStatus {
        case .active:
            superwallActive = true
        case .inactive:
            superwallActive = false
        case .unknown:
            superwallActive = false
        @unknown default:
            superwallActive = false
        }

        // Premium if EITHER Superwall OR Supabase says premium
        self.isPremium = superwallActive || supabasePremium

        self.isLoadingPremiumStatus = false
    }

    /// Check Supabase for premium override (for family/manual grants)
    private func checkSupabasePremium() async {
        do {
            // Get current user ID
            guard let session = try? await supabase.auth.session else {
                supabasePremium = false
                return
            }

            let userId = session.user.id

            // Fetch is_premium from profiles table
            let response = try await supabase.database
                .from("profiles")
                .select("is_premium")
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()

            // Decode response
            struct PremiumResponse: Decodable {
                let is_premium: Bool?
            }

            let result = try JSONDecoder().decode(PremiumResponse.self, from: response.data)
            supabasePremium = result.is_premium ?? false

        } catch {
            // If fetch fails, don't grant premium
            supabasePremium = false
            #if DEBUG
            print("Could not check Supabase premium: \(error.localizedDescription)")
            #endif
        }
    }

    /// Restore purchases
    func restorePurchases() async {
        _ = await Superwall.shared.restorePurchases()
        await checkPremiumStatus()
    }
}

// MARK: - SuperwallDelegate
extension SuperwallManager: SuperwallDelegate {
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        case .paywallOpen:
            // Ensure paywall window respects the app's appearance
            Task { @MainActor in
                self.applyAppearanceToAllWindows()
            }

        case .transactionComplete:
            Task { await checkPremiumStatus() }

        case .subscriptionStatusDidChange:
            Task { await checkPremiumStatus() }

        case .paywallProductsLoadFail(let error, _):
            #if DEBUG
            print("Failed to load products: \(error ?? "Unknown error")")
            #endif

        default:
            break
        }
    }

    func handleCustomPaywallAction(withName name: String) {
        #if DEBUG
        print("Custom paywall action: \(name)")
        #endif
    }
}

// MARK: - Appearance Helper
extension SuperwallManager {
    func setAppearance(_ style: UIUserInterfaceStyle) {
        self.currentAppearance = style
        // Apply immediately in case a paywall is already open
        Task { @MainActor in
            self.applyAppearanceToAllWindows()
        }
    }

    @MainActor
    private func applyAppearanceToAllWindows() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            // Apply the stored appearance preference
            window.overrideUserInterfaceStyle = currentAppearance
        }
    }
}
