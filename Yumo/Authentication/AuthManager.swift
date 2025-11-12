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
        } catch {
            print("⚠️ Error signing out:", error)
        }
    }

    // MARK: - Complete Sign In (with data migration)
    /// This should be called after successful sign-in to migrate offline data and set userId
    func completeSignIn(user: User, modelContext: ModelContext) async {
        let userId = user.id.uuidString

        // 1. Check if there's offline data to migrate
        let hasOfflineData = await DataMigrationService.shared.hasOfflineData(context: modelContext)

        if hasOfflineData {
            print("📦 Found offline data, starting migration...")
            await DataMigrationService.shared.migrateOfflineDataToUser(userId: userId, context: modelContext)
        } else {
            print("✅ No offline data to migrate")
        }

        // 2. Set the userId in UserSession (for app and widgets)
        await UserSession.shared.setUserId(userId)

        print("✅ Sign-in complete. UserId set: \(userId)")
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

            print("🍏 Logged in as: \(user.email ?? "Unknown")")

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

        print("📧 Signed up with email: \(user.email ?? "Unknown")")
    }

    // MARK: - Email Sign In
    func signInWithEmail(email: String, password: String) async throws {
        let user = try await authService.signInWithEmail(email: email, password: password)
        self.currentUser = user
        print("📧 Signed in with email: \(user.email ?? "Unknown")")
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        try await authService.resetPassword(email: email)
        print("📧 Password reset email sent to: \(email)")
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

        print("🔵 Signed in with Google: \(user.email ?? "Unknown")")
    }

    // MARK: - Upload onboarding data
    /// Called from OnboardingScreen.finishOnboarding()
    func uploadOnboardingToCloud(goals: UserGoals) async {
        guard let user = currentUser else {
            print("⚠️ Cannot sync onboarding, user not logged in (currentUser is nil)")
            return
        }

        print("📤 Starting onboarding sync for user: \(user.id) (\(user.email ?? "no email"))")

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
            let userId = user.id.uuidString
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
