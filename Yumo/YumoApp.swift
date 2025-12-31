//
//  YumoApp.swift
//

import SwiftUI
import SwiftData
import UserNotifications
import Combine
import GoogleSignIn
import Auth
import AppTrackingTransparency

// MARK: - Deep Link Manager
@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingPasswordResetURL: URL?
    @Published var shouldDismissAuthSheets = false

    func handleURL(_ url: URL) {
        print("🔗 DeepLinkManager received URL:")
        print("   Full URL: \(url.absoluteString)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")

        if url.scheme == "mochimeter" {
            let urlString = url.absoluteString.lowercased()
            if urlString.contains("reset-password") || url.host == "reset-password" {
                // First, signal that auth sheets should dismiss
                shouldDismissAuthSheets = true
                // Then set the URL after a small delay to allow sheets to dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.pendingPasswordResetURL = url
                    print("🔐 Password reset URL stored in DeepLinkManager")
                }
            }
        }
    }

    func clearDismissFlag() {
        shouldDismissAuthSheets = false
    }
}

// MARK: - NOTIFICATION DELEGATE
class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    let delegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        UNUserNotificationCenter.current().delegate = delegate

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("🔔 Notification permission granted.")
            } else if let error = error {
                print("⚠️ Notification permission error:", error.localizedDescription)
            }
        }
        
        // Request App Tracking Transparency for AdMob
        // We delay slightly to not conflict with other launch alerts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("🆔 Tracking auth status: \(status.rawValue)")
            }
        }

        // Configure Google Sign-In
        configureGoogleSignIn()
        
        // Initialize PostHog Analytics
        AnalyticsManager.shared.configure()

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle Google Sign-In callback URL
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Let Google Sign-In handle its URLs
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        // Return false for other URLs so SwiftUI's onOpenURL can handle them
        return false
    }

    private func configureGoogleSignIn() {
        // Read client ID from Info.plist
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            print("⚠️ Google Sign-In: GIDClientID not found in Info.plist")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("🔵 Google Sign-In configured with client ID")
    }
}



// MARK: - MAIN APP
@main
struct YumoApp: App {

    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self)
    var appDelegate

    // Shared app-wide AuthManager instance
    @StateObject private var authManager = AuthManager.shared

    // Superwall manager for premium subscriptions
    @StateObject private var superwallManager = SuperwallManager.shared

    // Deep link manager
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Theme manager for mochi colors
    @StateObject private var themeManager = ThemeManager()
    
    // Ad manager for AdMob
    @StateObject private var adManager = AdManager.shared

    // Shared SwiftData container using App Group storage
    let container: ModelContainer = SharedModelContainer.create()

    // State to track if app launch/initialization is complete
    @State private var isAppReady = false
    
    // Track scene phase for background/foreground detection
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isAppReady {
                    ContentView()
                        .id(authManager.currentUser?.id)
                        .environmentObject(authManager)
                        .environmentObject(superwallManager)
                        .environmentObject(deepLinkManager)
                        .environmentObject(themeManager)
                        .environmentObject(adManager)
                        .modelContainer(container)
                        // Handle deep links at App level
                        .onOpenURL { url in
                            print("🔗 YumoApp onOpenURL received: \(url.absoluteString)")
                            deepLinkManager.handleURL(url)
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                } else {
                    LaunchScreen()
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                }
            }
            // Initialize App Services
            .task {
                // 1. Configure Superwall & AdMob (Synchronous, fast)
                superwallManager.configure()
                adManager.initializeAds()
                
                // 2. Async Initializations
                // We run this sequentially to avoid Swift 6 concurrency issues with MainActor-isolated properties (like ModelContext)
                
                // Check premium status (Network)
                await superwallManager.checkPremiumStatus()
                
                // Apply appearance (UI/MainActor)
                await applyUserAppearanceMode()
                
                // Sync cloud → device (Database/MainActor)
                await CloudFoodSyncManager.shared.syncOnAppLaunch(context: container.mainContext)
                
                // Sync any pending AI analyses that completed while app was closed
                await PendingAnalysisSync.shared.syncCompletedAnalyses(modelContext: container.mainContext)
                
                // 3. Background tasks (fire and forget)
                Task {
                    await CloudFoodSyncManager.shared.syncOncePerDay(context: container.mainContext)
                }

                // 4. Migration checks
                await migrateWeeklyWeightChangeKg()
                
                // 5. Artificial minimum delay to prevent jarring flash
                try? await Task.sleep(nanoseconds: 1_200_000_000)

                // 6. Signal app is ready
                withAnimation {
                    isAppReady = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isAppReady {
                print("🔄 App became active, checking for background analyses...")
                Task {
                    await PendingAnalysisSync.shared.syncCompletedAnalyses(modelContext: container.mainContext)
                }
            }
        }
    }

    // Apply the user's saved appearance mode
    private func applyUserAppearanceMode() async {
        guard let goals = await UserScopedQuery.fetchUserGoals(context: container.mainContext) else {
            return
        }

        await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

            let style: UIUserInterfaceStyle
            switch goals.appearanceMode {
            case .system: style = .unspecified
            case .light: style = .light
            case .dark: style = .dark
            }
            
            // Sync with Superwall Manager so new windows inherit this
            superwallManager.setAppearance(style)

            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    // Migrate existing users who have weeklyWeightChangeKg = 0 (default before feature existed)
    private func migrateWeeklyWeightChangeKg() async {
        guard let goals = await UserScopedQuery.fetchUserGoals(context: container.mainContext) else {
            return
        }

        // If weeklyWeightChangeKg is 0 or below minimum, set to default 0.5
        if goals.weeklyWeightChangeKg < 0.1 {
            await MainActor.run {
                goals.weeklyWeightChangeKg = 0.5
                try? container.mainContext.save()
                print("📊 Migrated weeklyWeightChangeKg to default 0.5 for existing user")
            }
        }
    }
}
