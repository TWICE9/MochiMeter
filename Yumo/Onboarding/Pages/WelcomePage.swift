//
//  WelcomePage.swift
//  Yumo
//

import SwiftUI
import SwiftData
import AuthenticationServices
import Auth
import GoogleSignIn

struct WelcomePage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    var onFinish: () -> Void
    @State private var isSigningIn = false
    @State private var syncMessage = "Signing you in..."
    @State private var showEmailSignIn = false

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        ZStack {
            VStack(spacing: 30) {
                Spacer()

                Text("Welcome to MochiMeter")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)

                Text("Your personal health and nutrition tracker")
                    .font(.title3)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                // Get Started button
                Button {
                    flowManager.goNext()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("AppSecondaryAccent"))
                        .cornerRadius(16)
                }

                // Divider
                HStack {
                    Rectangle()
                        .fill(OnboardingTheme.divider(colorScheme))
                        .frame(height: 1)
                    Text("or")
                        .foregroundColor(OnboardingTheme.mutedText(colorScheme))
                        .font(.subheadline)
                    Rectangle()
                        .fill(OnboardingTheme.divider(colorScheme))
                        .frame(height: 1)
                }

                // Sign in for returning users
                VStack(spacing: 12) {
                    Text("Already have an account?")
                        .foregroundColor(secondaryText)
                        .font(.subheadline)

                    SignInWithAppleButtonView(
                        onRequest: { request in
                            let nonce = randomNonceString()
                            authManager.appleSignInNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        },
                        onCompletion: { authorization in
                            Task {
                                await MainActor.run {
                                    isSigningIn = true
                                    syncMessage = "Signing you in..."
                                }

                                await authManager.handleAppleAuthorization(authorization)
                                guard let user = authManager.currentUser else {
                                    await MainActor.run {
                                        isSigningIn = false
                                    }
                                    return
                                }

                                await authManager.completeSignIn(user: user, modelContext: modelContext)
                                let profileDownloaded = await authManager.downloadAndSyncProfile(modelContext: modelContext)

                                if profileDownloaded {
                                    let userId = user.id.uuidString
                                    await MainActor.run {
                                        syncMessage = "Syncing your data..."
                                    }
                                    await CloudSyncManager.shared.performFullSync(
                                        userId: userId,
                                        context: modelContext
                                    ) { step in
                                        await MainActor.run {
                                            syncMessage = step == .complete ? "All caught up!" : step.label
                                        }
                                    }

                                    // Existing user → finish onboarding and enter app
                                    await MainActor.run {
                                        isSigningIn = false
                                        onFinish()
                                    }
                                } else {
                                    // New user or no profile found → show message then continue onboarding
                                    await MainActor.run {
                                        syncMessage = "Welcome! Let's set up your profile..."
                                    }
                                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                                    await MainActor.run {
                                        isSigningIn = false
                                        flowManager.goNext()
                                    }
                                }
                            }
                        }
                    )
                    .frame(height: 50)

                    // Sign in with Google
                    GoogleSignInButtonView(
                        onSuccess: { idToken, accessToken, fullName in
                            Task {
                                await MainActor.run {
                                    isSigningIn = true
                                    syncMessage = "Signing you in..."
                                }

                                do {
                                    try await authManager.signInWithGoogle(
                                        idToken: idToken,
                                        accessToken: accessToken,
                                        fullName: fullName
                                    )

                                    guard let user = authManager.currentUser else {
                                        await MainActor.run {
                                            isSigningIn = false
                                        }
                                        return
                                    }

                                    await authManager.completeSignIn(user: user, modelContext: modelContext)
                                    let profileDownloaded = await authManager.downloadAndSyncProfile(modelContext: modelContext)

                                    if profileDownloaded {
                                        let userId = user.id.uuidString
                                        await MainActor.run {
                                            syncMessage = "Syncing your data..."
                                        }
                                        await CloudSyncManager.shared.performFullSync(
                                            userId: userId,
                                            context: modelContext
                                        ) { step in
                                            await MainActor.run {
                                                syncMessage = step == .complete ? "All caught up!" : step.label
                                            }
                                        }

                                        await MainActor.run {
                                            isSigningIn = false
                                            onFinish()
                                        }
                                    } else {
                                        // New user or no profile found → show message then continue onboarding
                                        await MainActor.run {
                                            syncMessage = "Welcome! Let's set up your profile..."
                                        }
                                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                                        await MainActor.run {
                                            isSigningIn = false
                                            flowManager.goNext()
                                        }
                                    }
                                } catch {
                                    print("🔵 Google Sign-In failed: \(error.localizedDescription)")
                                    await MainActor.run {
                                        isSigningIn = false
                                    }
                                }
                            }
                        },
                        onError: { error in
                            print("🔵 Google Sign-In error: \(error.localizedDescription)")
                        }
                    )
                    .frame(height: 50)

                    // Sign in with Email
                    Button {
                        showEmailSignIn = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Sign in with Email")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(primaryText.opacity(0.1))
                        .foregroundStyle(primaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(primaryText.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(30)
            .disabled(isSigningIn)
            .sheet(isPresented: $showEmailSignIn) {
                EmailAuthView(
                    isSignUp: false,
                    userName: nil,
                    onSuccess: {
                        Task {
                            await MainActor.run {
                                isSigningIn = true
                                syncMessage = "Signing you in..."
                            }

                            guard let user = authManager.currentUser else {
                                await MainActor.run {
                                    isSigningIn = false
                                }
                                return
                            }

                            await authManager.completeSignIn(user: user, modelContext: modelContext)
                            let profileDownloaded = await authManager.downloadAndSyncProfile(modelContext: modelContext)

                            if profileDownloaded {
                                let userId = user.id.uuidString
                                await MainActor.run {
                                    syncMessage = "Syncing your data..."
                                }
                                await CloudSyncManager.shared.performFullSync(
                                    userId: userId,
                                    context: modelContext
                                ) { step in
                                    await MainActor.run {
                                        syncMessage = step == .complete ? "All caught up!" : step.label
                                    }
                                }

                                await MainActor.run {
                                    isSigningIn = false
                                    onFinish()
                                }
                            } else {
                                // New user or no profile found → show message then continue onboarding
                                await MainActor.run {
                                    syncMessage = "Welcome! Let's set up your profile..."
                                }
                                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                                await MainActor.run {
                                    isSigningIn = false
                                    flowManager.goNext()
                                }
                            }
                        }
                    }
                )
            }

            if isSigningIn {
                SyncProgressOverlay(
                    message: syncMessage
                )
            }
        }
    }
}
