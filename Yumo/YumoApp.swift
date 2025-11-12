//
//  YumoApp.swift
//

import SwiftUI
import SwiftData
import UserNotifications
import Combine
import GoogleSignIn

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

        // Configure Google Sign-In
        configureGoogleSignIn()

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

    // Shared SwiftData container using App Group storage
    let container: ModelContainer = SharedModelContainer.create()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(superwallManager)
                .environmentObject(deepLinkManager)
                .modelContainer(container)

                // Initialize Superwall
                .task {
                    superwallManager.configure()
                }

                // Apply user's appearance mode preference
                .task {
                    await applyUserAppearanceMode()
                }

                // Sync cloud → device on launch
                .task {
                    await CloudFoodSyncManager.shared.syncOnAppLaunch(
                        context: container.mainContext
                    )
                }

                // Daily refresh for branded foods
                .task {
                    await CloudFoodSyncManager.shared.syncOncePerDay(
                        context: container.mainContext
                    )
                }

                // Handle deep links at App level
                .onOpenURL { url in
                    print("🔗 YumoApp onOpenURL received: \(url.absoluteString)")
                    deepLinkManager.handleURL(url)
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

            for window in windowScene.windows {
                switch goals.appearanceMode {
                case .system:
                    window.overrideUserInterfaceStyle = .unspecified
                case .light:
                    window.overrideUserInterfaceStyle = .light
                case .dark:
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
    }
}
