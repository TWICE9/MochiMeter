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
import os.signpost

private let appSignposter = OSSignposter(subsystem: "com.yumo.perf", category: "YumoApp")

// MARK: - Deep Link Manager
@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingPasswordResetURL: URL?
    @Published var shouldDismissAuthSheets = false
    @Published var showScanner = false // New flag for QuickScan

    func handleURL(_ url: URL) {
        print("🔗 DeepLinkManager received URL:")
        print("   Full URL: \(url.absoluteString)")

        // 1. Handle QuickScan (yumo://scan or similar)
        if url.host == "scan" || url.absoluteString.contains("scan") {
            print("📷 Detected QuickScan URL")
            // Small delay to ensure view hierarchy is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showScanner = true
            }
            return
        }

        // 2. Handle Password Reset (mochimeter://reset-password)
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

        // Register for remote push notifications if already authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        // Request App Tracking Transparency for AdMob
        // We delay slightly to not conflict with other launch alerts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("🆔 Tracking auth status: \(status.rawValue)")
                // Initialise AdMob after ATT resolves so it knows the consent state.
                DispatchQueue.main.async {
                    AdManager.shared.initializeAds()
                }
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

    // MARK: - Remote Notifications (APNs)

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📲 APNs device token: \(token)")
        Task {
            await DeviceTokenManager.shared.saveToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
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

    // StoreKit manager for premium subscriptions
    @StateObject private var storeKitManager = StoreKitManager.shared

    // Deep link manager
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Theme manager for mochi colors
    @StateObject private var themeManager = ThemeManager()
    
    // Ad manager for AdMob
    @StateObject private var adManager = AdManager.shared

    // Tab Router (Hoisted to App level for deep link access)
    @StateObject private var tabRouter = TabRouter()

    // Fasting manager global instance to prevent 1-second invalidations in MainTabView
    @StateObject private var fastingManager = FastingManager()

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
                        .environmentObject(storeKitManager)
                        .environmentObject(deepLinkManager)
                        .environmentObject(themeManager)
                        .environmentObject(adManager)
                        .environmentObject(tabRouter)
                        .environmentObject(fastingManager)
                        .modelContainer(container)
                        // Removed nested onOpenURL (moved to top level)
                        .withTutorialOverlay() // Tutorial system
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                } else {
                    LaunchScreen()
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                }
            }
            .scrollIndicators(.hidden)
            // Handle deep links at the WindowGroup level to catch them during LaunchScreen
            .onOpenURL { url in
                print("🔗 YumoApp onOpenURL received: \(url.absoluteString)")
                deepLinkManager.handleURL(url)
            }
            // Initialize App Services
            .task {
                let launchState = appSignposter.beginInterval("launchTask")
                defer { appSignposter.endInterval("launchTask", launchState) }

                // 1. Configure StoreKit (premium status already loaded from cache in StoreKitManager.init())
                // AdMob init is deferred to the background task below — not needed on first frame.
                storeKitManager.configure()

                // 2. Essential startup tasks (must complete before showing app)
                // Apply appearance (UI/MainActor) - fast, local DB
                let appearanceState = appSignposter.beginInterval("applyUserAppearanceMode")
                await applyUserAppearanceMode()
                appSignposter.endInterval("applyUserAppearanceMode", appearanceState)
                
                // 3. Sync data BEFORE showing the home screen so it appears with fresh content.
                // Running these during the launch screen prevents the ~1s post-launch re-render
                // that was caused by FoodLogCreated notifications firing after the home screen appeared.
                //
                // Safety net: race the syncs against a 3-second timeout so a slow or offline
                // network never leaves the user stuck on the launch screen. If the timeout wins,
                // the syncs continue in the background task below and the home screen appears
                // with cached/local data instead.
                let mainContext = container.mainContext
                let syncRaceState = appSignposter.beginInterval("launchSyncRace")
                await withTaskGroup(of: Void.self) { group in
                    // Task A: do the actual syncs
                    group.addTask { @MainActor in
                        let syncState = appSignposter.beginInterval("CloudFoodSyncManager.syncOnAppLaunch")
                        await CloudFoodSyncManager.shared.syncOnAppLaunch(context: mainContext)
                        appSignposter.endInterval("CloudFoodSyncManager.syncOnAppLaunch", syncState)

                        let pendingState = appSignposter.beginInterval("PendingAnalysisSync.syncCompletedAnalyses")
                        await PendingAnalysisSync.shared.syncCompletedAnalyses(modelContext: mainContext)
                        appSignposter.endInterval("PendingAnalysisSync.syncCompletedAnalyses", pendingState)
                    }
                    // Task B: 1-second maximum wait — if sync is slow, launch screen no longer stalls;
                    // remaining work continues in the post-ready background task below.
                    group.addTask {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    // Whichever finishes first (sync or timeout) unblocks the launch screen
                    await group.next()
                    group.cancelAll()
                }
                appSignposter.endInterval("launchSyncRace", syncRaceState)
                
                // 4. Signal app is ready - data is already fresh (or timed-out and will finish in background)
                withAnimation {
                    isAppReady = true
                }
                
                // 5. Truly background tasks AFTER app is shown (non-blocking, no UI impact)
                Task {

                    // Verify premium status in background (updates cache if changed)
                    await storeKitManager.checkPremiumStatus()
                    
                    // Setup Fasting Manager
                    await MainActor.run {
                        fastingManager.setup(context: container.mainContext)
                    }
                    
                    // Pre-warm HealthKit cache for users who've finished onboarding (runs
                    // silently if already authorized). Skipped during onboarding so a brand-new
                    // user isn't shown the HealthKit permission dialog the instant the app
                    // launches — that request belongs on the onboarding HealthKit screen, which
                    // asks for it when the user taps "Connect".
                    if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                        await HealthKitManager.shared.prefetchAllData()
                    }
                    
                    // Start realtime polling for in-session AI analysis updates
                    await PendingAnalysisSync.shared.startListening(modelContext: container.mainContext)
                    
                    // Daily sync
                    await CloudFoodSyncManager.shared.syncOncePerDay(context: container.mainContext)

                    // Running plan + logged runs cold-launch sync. Runs in the background so
                    // it never blocks app start, but ensures multi-device users see plan/session
                    // edits made elsewhere without having to sign out and back in.
                    if let userId = authManager.currentUser?.id.uuidString.lowercased() {
                        await CloudSyncManager.shared.syncRunningProfile(userId: userId, context: container.mainContext)
                        await CloudSyncManager.shared.syncRunningPlans(userId: userId, context: container.mainContext)
                        await FitnessService.shared.fetchRuns()

                        // Phase 2 plan adaptation: passively check whether
                        // the runner has fallen behind or pulled ahead of the
                        // plan, and auto-adjust if so. Server enforces a 7-day
                        // cooldown so this is safe to call on every launch.
                        // Must run AFTER syncRunningPlans so the latest
                        // session completion data is local.
                        await RunningPlanAdaptationDetector.runIfNeeded(context: container.mainContext)

                        // Refresh the rolling 14-day window of session-specific
                        // reminders. Each launch nudges out anything completed
                        // and adds the next-window-edge sessions. Runs after
                        // adaptation so any modified sessions get fresh nudges.
                        await RunningWorkoutReminderScheduler.refresh(context: container.mainContext)
                    }

                    // Migration checks
                    await migrateWeeklyWeightChangeKg()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isAppReady {
                print("🔄 App became active, checking for background analyses...")
                Task {
                    await PendingAnalysisSync.shared.syncCompletedAnalyses(modelContext: container.mainContext)
                    // Start realtime listening for instant updates while app is open
                    await PendingAnalysisSync.shared.startListening(modelContext: container.mainContext)
                }
            } else if newPhase == .background {
                // Stop realtime listening when app goes to background to save resources
                Task {
                    await PendingAnalysisSync.shared.stopListening()
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
            
            // Sync with StoreKit Manager so new windows inherit this
            storeKitManager.setAppearance(style)

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
