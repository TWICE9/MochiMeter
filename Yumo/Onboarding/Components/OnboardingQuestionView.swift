//
//  OnboardingQuestionView.swift
//  Yumo
//

import SwiftUI

struct OnboardingQuestionView<Content: View, Footer: View>: View {
    let question: String
    let subtitle: String?
    let progress: Double
    let canGoBack: Bool
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer
    @Environment(\.colorScheme) private var colorScheme

    // Convenience initializer for no footer
    init(
        question: String,
        subtitle: String?,
        progress: Double,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Footer == EmptyView {
        self.question = question
        self.subtitle = subtitle
        self.progress = progress
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.content = content
        self.footer = { EmptyView() }
    }
    
    // Full initializer with footer
    init(
        question: String,
        subtitle: String?,
        progress: Double,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.question = question
        self.subtitle = subtitle
        self.progress = progress
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.content = content
        self.footer = footer
    }

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let mutedText = OnboardingTheme.mutedText(colorScheme)

        VStack(spacing: 0) {
            // Progress bar
            OnboardingProgressBar(progress: progress)
                .padding(.horizontal, 24)
                .padding(.top, 20)

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
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // Question
                    VStack(spacing: 8) {
                        Text(question)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                            .multilineTextAlignment(.center)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(mutedText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 16)

                    // Custom content
                    content()
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            
            // Pinned footer (always visible at bottom)
            footer()
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        // iPad: center the whole onboarding column instead of stretching edge-to-edge.
        // No-op on iPhone (compact width).
        .readableContentColumn(560)
    }
}
