//
//  OnboardingQuestionView.swift
//  Yumo
//

import SwiftUI

struct OnboardingQuestionView<Content: View>: View {
    let question: String
    let subtitle: String?
    let progress: Double
    let canGoBack: Bool
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let mutedText = OnboardingTheme.mutedText(colorScheme)

        VStack(spacing: 0) {
            // Progress bar
            OnboardingProgressBar(progress: progress)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            // Back button (left aligned)
            HStack {
                if canGoBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(primaryText)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // Question
                    VStack(spacing: 12) {
                        Text(question)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                            .multilineTextAlignment(.center)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.body)
                                .foregroundColor(mutedText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 40)

                    // Custom content
                    content()
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
    }
}
