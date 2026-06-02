//
//  AuthManager.swift
//  Yumo
//

import Foundation
import AuthenticationServices
import Supabase
import Auth
import Combine
import CryptoKit
import SwiftUI
import SwiftData

// MARK: - Coordinator
final class SignInWithAppleCoordinator: NSObject,
                                        ASAuthorizationControllerDelegate,
                                        ASAuthorizationControllerPresentationContextProviding {

    var onComplete: ((ASAuthorization) -> Void)?
    var onError: ((Error) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .keyWindow ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        onComplete?(authorization)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("🍎 Apple Sign-In failed:", error)
        onError?(error)
    }
}


// MARK: - Auth Manager
@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var appleSignInNonce: String = ""

    private var appleCoordinator: SignInWithAppleCoordinator?

    private let authService: AuthService
    private let userService: UserService

    init(
        authService: AuthService? = nil,
        userService: UserService? = nil
    ) {
        self.authService = authService ?? SupabaseAuthService()
        self.userService = userService ?? SupabaseUserService()

        Task { await refreshSession() }
    }

    // MARK: - Session Refresh
    func refreshSession() async {
        do {
            if let session = try await authService.currentSession() {
                self.currentUser = session.user
                
                // Identify user for analytics restoration
                let userId = session.user.id.uuidString.lowercased()
                AnalyticsManager.shared.identify(userId: userId, properties: [
                    "email": session.user.email ?? ""
                ])
                
                // Ensure OneSignal/Widgets have the ID too
                await UserSession.shared.setUserId(userId)

                // Push any pending device token
                await DeviceTokenManager.shared.savePendingTokenIfNeeded()

            } else {
                self.currentUser = nil
            }
        } catch {
            print("⚠️ Failed to refresh session:", error)
            self.currentUser = nil
        }
    }

    // MARK: - Sign Out
    func signOut() async {
        do {
            try await authService.signOut()
            self.currentUser = nil
            // Clear userId from UserSession
            await UserSession.shared.clearUserId()
            
            // Track sign-out and reset analytics identity
            AnalyticsManager.shared.trackSignOut()
            AnalyticsManager.shared.reset()
            
            // Reset Premium Status
            StoreKitManager.shared.reset()
        } catch {
            print("⚠️ Error signing out:", error)
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        try await userService.deleteAccount()
        // Clear current user after successful deletion
        self.currentUser = nil
        await UserSession.shared.clearUserId()
        AnalyticsManager.shared.reset()
        StoreKitManager.shared.reset()
    }

    // MARK: - Complete Sign In (with data migration)
    /// This should be called after successful sign-in to migrate offline data and set userId
    func completeSignIn(user: User, modelContext: ModelContext) async {
        // IMPORTANT: Supabase auth.uid() returns lowercase UUID, so we must match that format
        let userId = user.id.uuidString.lowercased()
        let uppercaseUserId = user.id.uuidString // Old format (uppercase)

        // 1. Migrate existing data from uppercase userId to lowercase (fixes case mismatch)
        await migrateUserIdCase(from: uppercaseUserId, to: userId, context: modelContext)

        // 2. Check if there's offline data to migrate
        let hasOfflineData = await DataMigrationService.shared.hasOfflineData(context: modelContext)

        if hasOfflineData {
            #if DEBUG
            print("Found offline data, starting migration...")
            #endif
            await DataMigrationService.shared.migrateOfflineDataToUser(userId: userId, context: modelContext)
        }

        // 3. Set the userId in UserSession (for app and widgets)
        await UserSession.shared.setUserId(userId)
        
        // 4. Identify user in analytics
        AnalyticsManager.shared.identify(userId: userId, properties: [
            "email": user.email ?? ""
        ])
        
        // 5. Push any pending device token now that user is logged in
        await DeviceTokenManager.shared.savePendingTokenIfNeeded()

        // 6. Check premium status for newly signed-in user
        await StoreKitManager.shared.checkPremiumStatus()
    }
    
    /// Migrates local data from uppercase userId to lowercase userId
    private func migrateUserIdCase(from oldUserId: String, to newUserId: String, context: ModelContext) async {
        guard oldUserId != newUserId else { return } // Already lowercase
        
        #if DEBUG
        print("🔄 Migrating userId from \(oldUserId) to \(newUserId)")
        #endif
        
        // Migrate food logs
        let foodPredicate = #Predicate<LoggedFood> { $0.userId == oldUserId }
        if let foodLogs = try? context.fetch(FetchDescriptor(predicate: foodPredicate)) {
            for log in foodLogs {
                log.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(foodLogs.count) food logs")
            #endif
        }
        
        // Migrate water logs
        let waterPredicate = #Predicate<LoggedWater> { $0.userId == oldUserId }
        if let waterLogs = try? context.fetch(FetchDescriptor(predicate: waterPredicate)) {
            for log in waterLogs {
                log.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(waterLogs.count) water logs")
            #endif
        }
        
        // Migrate weight logs
        let weightPredicate = #Predicate<LoggedWeight> { $0.userId == oldUserId }
        if let weightLogs = try? context.fetch(FetchDescriptor(predicate: weightPredicate)) {
            for log in weightLogs {
                log.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(weightLogs.count) weight logs")
            #endif
        }
        
        // Migrate fasting logs
        let fastingPredicate = #Predicate<FastingLog> { $0.userId == oldUserId }
        if let fastingLogs = try? context.fetch(FetchDescriptor(predicate: fastingPredicate)) {
            for log in fastingLogs {
                log.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(fastingLogs.count) fasting logs")
            #endif
        }
        
        // Migrate recipes
        let recipePredicate = #Predicate<Recipe> { $0.userId == oldUserId }
        if let recipes = try? context.fetch(FetchDescriptor(predicate: recipePredicate)) {
            for recipe in recipes {
                recipe.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(recipes.count) recipes")
            #endif
        }
        
        // Migrate reminders
        let reminderPredicate = #Predicate<Reminder> { $0.userId == oldUserId }
        if let reminders = try? context.fetch(FetchDescriptor(predicate: reminderPredicate)) {
            for reminder in reminders {
                reminder.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(reminders.count) reminders")
            #endif
        }
        
        // Migrate user goals
        let goalsPredicate = #Predicate<UserGoals> { $0.userId == oldUserId }
        if let goals = try? context.fetch(FetchDescriptor(predicate: goalsPredicate)) {
            for goal in goals {
                goal.userId = newUserId
            }
            #if DEBUG
            print("  → Migrated \(goals.count) user goals")
            #endif
        }
        
        try? context.save()
        #if DEBUG
        print("✅ userId case migration complete")
        #endif
    }

    // MARK: - Begin Apple Sign In
    func beginSignInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()

        appleSignInNonce = randomNonceString()
        request.nonce = sha256(appleSignInNonce)
        request.requestedScopes = [.fullName, .email]

        let coordinator = SignInWithAppleCoordinator()
        self.appleCoordinator = coordinator

        coordinator.onComplete = { [weak self] authorization in
            guard let self = self else { return }
            Task { await self.handleAppleAuthorization(authorization) }
        }

        coordinator.onError = { error in
            print("🍎 Apple Sign-In finished with error:", error.localizedDescription)
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }

    // MARK: - Handle Apple Credential
    func handleAppleAuthorization(_ authorization: ASAuthorization) async {

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ No AppleIDCredential returned")
            return
        }

        guard let idTokenData = credential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            print("❌ Failed to get identity token")
            return
        }

        do {
            let user = try await authService.signInWithApple(
                idToken: idToken,
                nonce: appleSignInNonce
            )

            self.currentUser = user

            // Extract full name (only on first login)
            var fullName: String? = nil
            if let components = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                fullName = formatter.string(from: components)
            }

            // Ensure basic profile
            try? await userService.ensureUserProfile(
                for: user,
                fullName: fullName
            )

            #if DEBUG
            print("Apple Sign-In successful")
            #endif

            // Note: completeSignIn() should be called from the view that has access to modelContext

        } catch {
            print("❌ Supabase Apple sign-in error:", error.localizedDescription)
        }
    }

    // MARK: - Email Sign Up
    func signUpWithEmail(email: String, password: String, fullName: String?) async throws {
        let user = try await authService.signUpWithEmail(email: email, password: password)
        self.currentUser = user

        // Ensure basic profile with name
        try? await userService.ensureUserProfile(
            for: user,
            fullName: fullName
        )

        #if DEBUG
        print("Email sign-up successful")
        #endif
    }

    // MARK: - Email Sign In
    func signInWithEmail(email: String, password: String) async throws {
        let user = try await authService.signInWithEmail(email: email, password: password)
        self.currentUser = user
        #if DEBUG
        print("Email sign-in successful")
        #endif
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        try await authService.resetPassword(email: email)
        #if DEBUG
        print("Password reset email sent")
        #endif
    }

    // MARK: - Google Sign In
    func signInWithGoogle(idToken: String, accessToken: String, fullName: String?) async throws {
        let user = try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        self.currentUser = user

        // Ensure basic profile with name
        try? await userService.ensureUserProfile(
            for: user,
            fullName: fullName
        )

        #if DEBUG
        print("Google sign-in successful")
        #endif
    }

    // MARK: - Upload onboarding data
    /// Called from OnboardingScreen.finishOnboarding()
    func uploadOnboardingToCloud(goals: UserGoals) async {
        guard let user = currentUser else {
            print("⚠️ Cannot sync onboarding, user not logged in (currentUser is nil)")
            return
        }

        #if DEBUG
        print("Starting onboarding sync...")
        #endif

        do {
            try await userService.uploadOnboardingData(
                for: user,
                goals: goals
            )

            print("✅ Synced onboarding → Supabase successfully")

        } catch {
            print("❌ Failed onboarding sync:")
            print("   Error: \(error)")
            print("   Localized: \(error.localizedDescription)")
        }
    }

    // MARK: - Download and sync profile from Supabase
    /// Downloads user profile from Supabase and populates local UserGoals
    func downloadAndSyncProfile(modelContext: ModelContext) async -> Bool {
        guard let user = currentUser else {
            print("⚠️ Cannot download profile, user not logged in")
            return false
        }

        do {
            guard let profileResponse = try await userService.downloadUserProfile(for: user) else {
                print("⚠️ No profile found for user")
                return false
            }

            // Parse the birthdate
            let birthDate: Date
            if let date = ISO8601DateFormatter().date(from: profileResponse.birthdate) {
                birthDate = date
            } else {
                print("⚠️ Failed to parse birthdate, using default")
                birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
            }

            // Parse gender
            let gender = Gender(rawValue: profileResponse.gender) ?? .male

            // Parse activity level
            let activityLevel = ActivityLevel(rawValue: profileResponse.activity_level) ?? .moderateActivity

            // Parse weight goal
            let weightGoal: GoalType
            switch profileResponse.weight_goal {
            case 0: weightGoal = .lose
            case 1: weightGoal = .maintain
            case 2: weightGoal = .gain
            default: weightGoal = .maintain
            }

            // Fetch or create user goals
            let userId = user.id.uuidString.lowercased()
            let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
            let goalsToUpdate = fetchedGoals ?? UserGoals()

            // Set userId if not already set
            if goalsToUpdate.userId == nil {
                goalsToUpdate.userId = userId
            }

            // Populate with downloaded data
            goalsToUpdate.name = profileResponse.name
            goalsToUpdate.birthDate = birthDate
            goalsToUpdate.gender = gender
            goalsToUpdate.height = Double(profileResponse.height_cm)
            goalsToUpdate.weight = profileResponse.weight_kg
            goalsToUpdate.activityLevel = activityLevel
            goalsToUpdate.weightGoal = weightGoal
            goalsToUpdate.targetWeight = profileResponse.target_weight

            goalsToUpdate.dailyCalories = Double(profileResponse.daily_calories)
            goalsToUpdate.dailyProtein = Double(profileResponse.daily_protein)
            goalsToUpdate.dailyCarbs = Double(profileResponse.daily_carbs)
            goalsToUpdate.dailyFat = Double(profileResponse.daily_fat)

            // Insert if new
            if fetchedGoals == nil {
                modelContext.insert(goalsToUpdate)
            }

            try modelContext.save()

            print("📥 Successfully synced profile from Supabase")
            return true

        } catch {
            print("❌ Failed to download profile:", error.localizedDescription)
            return false
        }
    }
}



// MARK: - Crypto Helpers
func randomNonceString(length: Int = 32) -> String {
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
        for random in randoms {
            if remainingLength == 0 { return result }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hashed = SHA256.hash(data: data)
    return hashed.map { String(format: "%02x", $0) }.joined()
}
