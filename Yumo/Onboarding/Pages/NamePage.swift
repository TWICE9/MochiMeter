//
//  NamePage.swift
//  Yumo
//

import SwiftUI

struct NamePage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isNameFocused: Bool

    private let maxNameLength = 50

    var body: some View {
        OnboardingQuestionView(
            question: "What's your name?",
            subtitle: "We'll use this to personalize your experience",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 24) {
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
                        .submitLabel(.continue)
                        .onChange(of: flowManager.name) { _, newValue in
                            // Enforce max character limit
                            if newValue.count > maxNameLength {
                                flowManager.name = String(newValue.prefix(maxNameLength))
                            }
                        }
                        .onSubmit {
                            guard canProceed, !flowManager.isNavigating else { return }
                            // Trim whitespace before proceeding
                            flowManager.name = trimmedName
                            flowManager.goNext()
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

                Spacer().frame(height: 20)

                ContinueButton(
                    title: "Continue",
                    isEnabled: canProceed && !flowManager.isNavigating
                ) {
                    // Trim whitespace before proceeding
                    flowManager.name = trimmedName
                    flowManager.goNext()
                }
            }
        }
        .onAppear {
            // FAIL-SAFE: If we already have a valid name (from Sign in with Apple),
            // immediately skip this page. Apple requires that we don't ask for name
            // if it was already provided by the Authentication Services framework.
            let trimmedName = flowManager.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty && trimmedName != "User" {
                print("✅ [NamePage] Skipping - name already provided: \(trimmedName)")
                // Skip to next page immediately
                DispatchQueue.main.async {
                    if !flowManager.isNavigating {
                        flowManager.goNext()
                    }
                }
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
}
