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
    @State private var showSignInSheet = false

    var body: some View {
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        ZStack {
            VStack(spacing: 30) {
                Spacer()

                Image(colorScheme == .dark ? "LogoDarkMode" : "LogoHS")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 120)
                    .padding(.bottom, 10)

                Text("Your personal health and nutrition tracker")
                    .font(.title3)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                // Get Started button
                Button {
                    guard !flowManager.isNavigating else { return }
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
                .disabled(flowManager.isNavigating)

                // Already have an account link
                Button {
                    showSignInSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(secondaryText)
                        Text("Sign in")
                            .foregroundColor(Color("AppSecondaryAccent"))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                
                // Terms and Privacy footer
                HStack(spacing: 4) {
                    Text("By continuing, you agree to our")
                        .font(.caption2)
                        .foregroundStyle(secondaryText.opacity(0.7))
                    
                    Link("Terms", destination: URL(string: "https://mochimeter.com.au/terms/")!)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color("AppSecondaryAccent"))
                    
                    Text("and")
                        .font(.caption2)
                        .foregroundStyle(secondaryText.opacity(0.7))
                    
                    Link("Privacy Policy", destination: URL(string: "https://mochimeter.com.au/privacy/")!)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color("AppSecondaryAccent"))
                }
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            }
            .padding(30)
            .disabled(isSigningIn)
            .sheet(isPresented: $showSignInSheet) {
                ReturningUserSignInSheet(
                    flowManager: flowManager,
                    authManager: authManager,
                    modelContext: modelContext,
                    isSigningIn: $isSigningIn,
                    syncMessage: $syncMessage,
                    onFinish: onFinish
                )
            }
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
                                let userId = user.id.uuidString.lowercased()
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

// MARK: - Returning User Sign In Sheet
struct ReturningUserSignInSheet: View {
    @Bindable var flowManager: OnboardingFlowManager
    var authManager: AuthManager
    var modelContext: ModelContext
    @Binding var isSigningIn: Bool
    @Binding var syncMessage: String
    var onFinish: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEmailSignIn = false
    
    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)
        
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundStyle(Color("AppSecondaryAccent"))
                
                Text("Welcome Back!")
                    .font(.title).bold()
                    .foregroundStyle(primaryText)
                
                Text("Sign in to sync your data across devices")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Sign in options
                VStack(spacing: 12) {
                    SignInWithAppleButtonView(
                        onRequest: { request in
                            let nonce = randomNonceString()
                            authManager.appleSignInNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        },
                        onCompletion: { authorization in
                            dismiss()
                            Task {
                                await MainActor.run {
                                    isSigningIn = true
                                    syncMessage = "Signing you in..."
                                }

                                // Extract full name from Apple credential BEFORE handling auth
                                // IMPORTANT: Apple only provides name on FIRST sign-in ever with this app.
                                // Subsequent sign-ins will have nil fullName.
                                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    print("🍎 [SIWA] Got credential, checking for fullName...")
                                    if let fullName = credential.fullName {
                                        let formatter = PersonNameComponentsFormatter()
                                        let name = formatter.string(from: fullName)
                                        print("🍎 [SIWA] fullName components: given=\(fullName.givenName ?? "nil"), family=\(fullName.familyName ?? "nil")")
                                        print("🍎 [SIWA] Formatted name: '\(name)'")
                                        if !name.isEmpty {
                                            await MainActor.run {
                                                flowManager.name = name
                                                print("🍎 [SIWA] Set flowManager.name to: '\(flowManager.name)'")
                                            }
                                        } else {
                                            print("⚠️ [SIWA] Formatted name was empty, not setting")
                                        }
                                    } else {
                                        print("⚠️ [SIWA] fullName is nil - this is a subsequent sign-in (name only provided once)")
                                    }
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
                                    let userId = user.id.uuidString.lowercased()
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
                                    await MainActor.run {
                                        syncMessage = "Welcome! Let's set up your profile..."
                                    }
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
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
                            dismiss()
                            Task {
                                await MainActor.run {
                                    isSigningIn = true
                                    syncMessage = "Signing you in..."
                                }

                                do {
                                    // Set the name from Google before sign-in completes
                                    if let name = fullName, !name.isEmpty {
                                        await MainActor.run {
                                            flowManager.name = name
                                        }
                                    }
                                    
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
                                        let userId = user.id.uuidString.lowercased()
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
                                        await MainActor.run {
                                            syncMessage = "Welcome! Let's set up your profile..."
                                        }
                                        try? await Task.sleep(nanoseconds: 1_500_000_000)
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
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(OnboardingTheme.baseBackground(colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(secondaryText)
                }
            }
            .sheet(isPresented: $showEmailSignIn) {
                EmailAuthView(
                    isSignUp: false,
                    userName: nil,
                    onSuccess: {
                        dismiss()
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
                                let userId = user.id.uuidString.lowercased()
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
                                await MainActor.run {
                                    syncMessage = "Welcome! Let's set up your profile..."
                                }
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                await MainActor.run {
                                    isSigningIn = false
                                    flowManager.goNext()
                                }
                            }
                        }
                    }
                )
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
