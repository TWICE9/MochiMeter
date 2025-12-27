//
//  ContentView.swift
//  Yumo
//

import SwiftUI
import AuthenticationServices
import SwiftData
import Auth
import Supabase

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    // Onboarding completion
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // NEW: Track if user skipped login
    @AppStorage("continueWithoutAccount") private var continueWithoutAccount = false

    // Feature flag for new onboarding
    @AppStorage("useNewOnboarding") private var useNewOnboarding = true

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager

    // Password reset handling (at app level so it works during onboarding too)
    @State private var showPasswordReset = false

    var body: some View {
        VStack(spacing: 0) {

            // ────────────────────────────────────────
            //  MAIN APP FLOW
            // ────────────────────────────────────────
            if !hasCompletedOnboarding {
                if useNewOnboarding {
                    NewOnboardingScreen {
                        withAnimation {
                            hasCompletedOnboarding = true
                            // Track onboarding completion
                            AnalyticsManager.shared.trackOnboardingCompleted(
                                signedIn: authManager.currentUser != nil,
                                authMethod: nil
                            )
                        }
                    }
                } else {
                    OnboardingScreen {
                        withAnimation {
                            hasCompletedOnboarding = true
                            // Track onboarding completion
                            AnalyticsManager.shared.trackOnboardingCompleted(
                                signedIn: authManager.currentUser != nil,
                                authMethod: nil
                            )
                        }
                    }
                }
            } else {
                MainTabView()
            }

            // ────────────────────────────────────────
            //  AUTH FOOTER (only after onboarding!)
            // ────────────────────────────────────────
//            if hasCompletedOnboarding {
//
//                if continueWithoutAccount == false {   // hide footer if user skipped login
//
//                    VStack(spacing: 8) {
//
//                        // LOGGED IN
//                        if let user = authManager.currentUser {
//                            Text("Signed in as: \(user.email ?? "Unknown")")
//                                .font(.footnote)
//                                .foregroundColor(.green.opacity(0.8))
//
//                            Button("Sign Out") {
//                                Task {
//                                    await authManager.signOut()
//                                }
//                            }
//                            .foregroundColor(.red)
//                            .padding(.top, 4)
//
//                        } else {
//                            // LOGGED OUT
//                            Text("You are not signed in")
//                                .font(.footnote)
//                                .foregroundColor(.red.opacity(0.8))
//
//                            //👇 Your working Apple Sign-In Button
//                            Button {
//                                authManager.beginSignInWithApple()
//                            } label: {
//                                SignInWithAppleButtonView(
//                                    onRequest: { _ in },
//                                    onCompletion: { _ in }
//                                )
//                                .frame(height: 50)
//                            }
//                        }
//                    }
//                    .padding(.vertical, 12)
//                }
//            }
        }

        // ────────────────────────────────────────
        //  CLOUD SYNC
        // ────────────────────────────────────────
        .task {
            await CloudFoodSyncManager.shared.syncOnAppLaunch(context: modelContext)
        }
        .task {
            await CloudFoodSyncManager.shared.syncOncePerDay(context: modelContext)
        }

        // ────────────────────────────────────────
        //  PASSWORD RESET DEEP LINK
        // ────────────────────────────────────────
        .onChange(of: deepLinkManager.pendingPasswordResetURL) { _, newURL in
            if newURL != nil {
                print("🔐 ContentView detected password reset URL, showing sheet")
                showPasswordReset = true
            }
        }
        .fullScreenCover(isPresented: $showPasswordReset, onDismiss: {
            // Clear the pending URL when dismissed
            deepLinkManager.pendingPasswordResetURL = nil
        }) {
            SetNewPasswordView(url: deepLinkManager.pendingPasswordResetURL)
                .environmentObject(authManager)
        }
        .onAppear {
            // Check if there's a pending password reset URL on appear
            if deepLinkManager.pendingPasswordResetURL != nil {
                print("🔐 ContentView found pending password reset URL on appear")
                showPasswordReset = true
            }
        }
    }
}
