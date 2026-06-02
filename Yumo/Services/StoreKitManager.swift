//
//  StoreKitManager.swift
//  Yumo
//
//  Native StoreKit 2 subscription manager - replaces Superwall
//

import Foundation
import Combine
import StoreKit
import Supabase
import UIKit

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // MARK: - Product IDs
    static let monthlyProductID = "MonthlySub"
    static let yearlyProductID = "YearlySub"

    // MARK: - Published State
    @Published var isPremium: Bool = false
    @Published var isLoadingPremiumStatus: Bool = false
    @Published var products: [Product] = []
    @Published var purchaseError: String?
    @Published var isPurchasing: Bool = false

    // Track current UI style preference
    var currentAppearance: UIUserInterfaceStyle = .unspecified

    // Supabase premium override (for manual grants / family sharing)
    private var supabasePremium: Bool = false

    // Transaction listener task
    private var transactionListener: Task<Void, Never>?

    // MARK: - Caching
    private let premiumCacheKey = "cached_is_premium"

    private var cachedPremiumStatus: Bool {
        get { UserDefaults.standard.bool(forKey: premiumCacheKey) }
        set { UserDefaults.standard.set(newValue, forKey: premiumCacheKey) }
    }

    // MARK: - Computed Helpers
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    // MARK: - Init
    private init() {
        self.isPremium = cachedPremiumStatus
        #if DEBUG
        print("🔐 Loaded cached premium status: \(isPremium)")
        #endif
    }

    // MARK: - Configure (call on app launch)
    func configure() {
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
        }

        #if DEBUG
        print("🛒 StoreKit configured")
        #endif
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [
                Self.monthlyProductID,
                Self.yearlyProductID
            ])
            self.products = storeProducts.sorted { $0.price < $1.price }
            #if DEBUG
            print("🛒 Loaded \(storeProducts.count) products")
            for p in storeProducts {
                print("   → \(p.id): \(p.displayPrice)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to load products: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Transaction verification failed"
                    isPurchasing = false
                    return false
                }
                await transaction.finish()
                await checkPremiumStatus()
                isPurchasing = false
                return true

            case .userCancelled:
                #if DEBUG
                print("🛒 User cancelled purchase")
                #endif
                isPurchasing = false
                return false

            case .pending:
                #if DEBUG
                print("🛒 Purchase pending (ask to buy, etc.)")
                #endif
                isPurchasing = false
                return false

            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            #if DEBUG
            print("❌ Purchase failed: \(error.localizedDescription)")
            #endif
            isPurchasing = false
            return false
        }
    }

    // MARK: - Check Premium Status
    func checkPremiumStatus() async {
        isLoadingPremiumStatus = true

        // Check Supabase override first
        await checkSupabasePremium()

        // Check StoreKit entitlements
        var storeKitActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.monthlyProductID ||
                   transaction.productID == Self.yearlyProductID {
                    storeKitActive = true
                    break
                }
            }
        }

        let newStatus = storeKitActive || supabasePremium
        self.isPremium = newStatus
        self.cachedPremiumStatus = newStatus

        #if DEBUG
        print("🔐 Premium status updated: \(newStatus) (StoreKit: \(storeKitActive), Supabase: \(supabasePremium))")
        #endif

        isLoadingPremiumStatus = false
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkPremiumStatus()
        } catch {
            #if DEBUG
            print("❌ Restore failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Reset (on sign out)
    func reset() {
        self.isPremium = false
        self.supabasePremium = false
        self.cachedPremiumStatus = false
        #if DEBUG
        print("🔐 StoreKit state and cache reset")
        #endif
    }

    // MARK: - Show Paywall
    func showPaywall() {
        NotificationCenter.default.post(name: .showPaywall, object: nil)
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.checkPremiumStatus()
                }
            }
        }
    }

    // MARK: - Supabase Premium Override
    private func checkSupabasePremium() async {
        do {
            guard let session = try? await supabase.auth.session else {
                supabasePremium = false
                return
            }

            let userId = session.user.id

            let response = try await supabase.database
                .from("profiles")
                .select("is_premium")
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()

            struct PremiumResponse: Decodable {
                let is_premium: Bool?
            }

            let decoded = try JSONDecoder().decode(PremiumResponse.self, from: response.data)
            supabasePremium = decoded.is_premium ?? false

        } catch {
            supabasePremium = false
            #if DEBUG
            print("Could not check Supabase premium: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Appearance Helper
extension StoreKitManager {
    func setAppearance(_ style: UIUserInterfaceStyle) {
        self.currentAppearance = style
        applyAppearanceToAllWindows()
    }

    private func applyAppearanceToAllWindows() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = currentAppearance
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
}
