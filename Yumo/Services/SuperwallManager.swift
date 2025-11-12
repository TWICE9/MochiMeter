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

@MainActor
class SuperwallManager: ObservableObject {
    static let shared = SuperwallManager()

    @Published var isPremium: Bool = false
    @Published var isLoadingPremiumStatus: Bool = false

    // Track Supabase premium override separately
    private var supabasePremium: Bool = false

    private init() {}

    /// Configure Superwall on app launch
    func configure() {
        // Configure Superwall with your API key
        Superwall.configure(apiKey: "pk_qzQrt_so0H7uQKDR8dIZD")

        // Set up delegate for handling events
        Superwall.shared.delegate = self

        // Don't check premium status on launch to avoid Apple ID prompt
        // Status will be checked when user interacts with paywall

        print("✅ Superwall configured successfully")
    }

    /// Show the paywall
    func showPaywall() {
        Task {
            // Check subscription status first (only when user explicitly requests paywall)
            await checkPremiumStatus()

            // Register the placement to trigger the paywall
            Superwall.shared.register(placement: "show_paywall")
            print("💎 Paywall placement registered")
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
            print("✅ User has active Superwall subscription")
        case .inactive:
            superwallActive = false
            print("ℹ️ No active Superwall subscription")
        case .unknown:
            superwallActive = false
            print("❓ Unknown Superwall subscription status")
        @unknown default:
            superwallActive = false
            print("❓ Unhandled Superwall subscription status")
        }

        // Premium if EITHER Superwall OR Supabase says premium
        self.isPremium = superwallActive || supabasePremium

        if supabasePremium && !superwallActive {
            print("👨‍👩‍👧‍👦 Premium granted via Supabase override (family/manual)")
        }

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

            if supabasePremium {
                print("✅ Supabase premium override: TRUE")
            }

        } catch {
            // If fetch fails, don't grant premium
            supabasePremium = false
            print("ℹ️ Could not check Supabase premium: \(error.localizedDescription)")
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
        case .transactionComplete:
            print("💰 Transaction completed")
            Task { await checkPremiumStatus() }

        case .subscriptionStatusDidChange:
            print("📊 Subscription status changed")
            Task { await checkPremiumStatus() }

        case .paywallClose:
            print("🚪 Paywall closed")

        case .paywallOpen:
            print("📱 Paywall opened")

        case .paywallProductsLoadStart:
            print("🛍️ Loading products from StoreKit...")

        case .paywallProductsLoadFail(let error, _):
            print("❌ Failed to load products: \(error ?? "Unknown error")")

        case .paywallProductsLoadComplete:
            print("✅ Products loaded successfully")

        default:
            break
        }
    }

    func handleCustomPaywallAction(withName name: String) {
        print("🔧 Custom paywall action: \(name)")
    }
}
