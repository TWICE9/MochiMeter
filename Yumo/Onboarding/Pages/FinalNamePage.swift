//
//  FinalNamePage.swift
//  Yumo
//
//  This is the NamePage shown at the END of onboarding (after SignInPage).
//  It only appears if the user didn't sign in with Apple/Google (which provide names).
//  When user enters their name and taps Continue, onboarding completes.
//

import SwiftUI
import SwiftData
import Auth

struct FinalNamePage: View {
    @Bindable var flowManager: OnboardingFlowManager
    var authManager: AuthManager
    var modelContext: ModelContext
    var onFinish: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isNameFocused: Bool
    @State private var isFinishing = false

    private let maxNameLength = 50

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color("AppSecondaryAccent"))
            
            Text("What's your name?")
                .font(.title).bold()
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)
            
            Text("We'll use this to personalize your experience")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
            
            Spacer().frame(height: 20)
            
            VStack(spacing: 8) {
                TextField("Enter your name", text: $flowManager.name)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(OnboardingTheme.cardBackground(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                    )
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onChange(of: flowManager.name) { _, newValue in
                        // Enforce max character limit
                        if newValue.count > maxNameLength {
                            flowManager.name = String(newValue.prefix(maxNameLength))
                        }
                    }
                    .onSubmit {
                        guard canProceed, !isFinishing else { return }
                        completeOnboarding()
                    }

                // Character count indicator
                HStack {
                    if trimmedName.isEmpty {
                        Text("Name is required")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    Spacer()
                    Text("\(flowManager.name.count)/\(maxNameLength)")
                        .font(.caption)
                        .foregroundStyle(
                            flowManager.name.count >= maxNameLength
                                ? .orange
                                : OnboardingTheme.secondaryText(colorScheme)
                        )
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                HStack {
                    if isFinishing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("Complete Setup")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canProceed ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                .cornerRadius(16)
            }
            .disabled(!canProceed || isFinishing)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 30)
        }
        .onAppear {
            // FAIL-SAFE: If we already have a valid name (from Sign in with Apple),
            // immediately complete onboarding. This shouldn't normally happen since
            // SignInPage should skip to completion, but just in case.
            let trimmedName = flowManager.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty && trimmedName != "User" {
                print("✅ [FinalNamePage] Name already provided: \(trimmedName) - completing immediately")
                completeOnboarding()
                return
            }
            
            // Clear default "User" if still set
            if flowManager.name == "User" {
                flowManager.name = ""
            }
            // Focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }

    private var trimmedName: String {
        flowManager.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canProceed: Bool {
        !trimmedName.isEmpty
    }
    
    private func completeOnboarding() {
        guard canProceed, !isFinishing else { return }
        isFinishing = true
        
        // Trim whitespace before saving
        flowManager.name = trimmedName
        
        Task {
            await finishOnboarding()
            await MainActor.run {
                onFinish()
            }
        }
    }
    
    private func finishOnboarding() async {
        print("🏁 [FinalNamePage] finishOnboarding called")
        print("🏁 [FinalNamePage] flowManager.name = '\(flowManager.name)'")
        let goalsToSave = flowManager.buildUserGoals()

        // Set userId if signed in
        if let user = authManager.currentUser {
            print("🏁 [FinalNamePage] User is signed in: \(user.id)")
            goalsToSave.userId = user.id.uuidString.lowercased()
        } else {
            print("🏁 [FinalNamePage] No user signed in")
        }

        modelContext.insert(goalsToSave)
        try? modelContext.save()
        print("🏁 [FinalNamePage] Goals saved locally")

        // Upload to cloud if signed in
        if authManager.currentUser != nil {
            print("🏁 [FinalNamePage] Starting cloud upload...")
            await authManager.uploadOnboardingToCloud(goals: goalsToSave)
            print("🏁 [FinalNamePage] Cloud upload completed")
        }
    }
}
