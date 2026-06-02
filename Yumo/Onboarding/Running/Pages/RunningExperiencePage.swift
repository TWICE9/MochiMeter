//
//  RunningExperiencePage.swift
//  Yumo
//

import SwiftUI

struct RunningExperiencePage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    private let options: [(RunningExperience, String)] = [
        (.never, "🌱"),
        (.beginner, "👟"),
        (.intermediate, "🏃"),
        (.advanced, "⚡️")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "How would you describe your running?",
            subtitle: "We'll tune your plan to where you are today.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(options, id: \.0) { level, emoji in
                    RunningExperienceCard(
                        level: level,
                        emoji: emoji,
                        isSelected: flowManager.experience == level
                    ) {
                        flowManager.experience = level
                    }
                }

                Spacer().frame(height: 12)

                ContinueButton(
                    title: "Continue",
                    isEnabled: !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
    }
}

private struct RunningExperienceCard: View {
    let level: RunningExperience
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 36))

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(primary)
                    Text(level.subtitle)
                        .font(.subheadline)
                        .foregroundColor(muted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("AppSecondaryAccent"))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color("AppSecondaryAccent").opacity(0.2) : background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color("AppSecondaryAccent") : stroke, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
