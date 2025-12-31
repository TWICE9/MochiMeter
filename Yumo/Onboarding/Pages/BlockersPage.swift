//
//  BlockersPage.swift
//  Yumo
//

import SwiftUI

struct BlockersPage: View {
    @Bindable var flowManager: OnboardingFlowManager

    let blockerOptions: [(Blocker, String)] = [
        (.lackOfConsistency, "🔄"),
        (.unhealthyEatingHabits, "🍔"),
        (.lackOfSupport, "🤝"),
        (.busySchedule, "⏰"),
        (.lackOfMealInspo, "💡")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "What's stopping you from reaching your goals?",
            subtitle: "Select all that apply",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 10) {
                ForEach(blockerOptions, id: \.0) { blocker, emoji in
                    CompactSelectionCard(
                        title: blocker.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.selectedBlockers.contains(blocker),
                        action: {
                            if flowManager.selectedBlockers.contains(blocker) {
                                flowManager.selectedBlockers.remove(blocker)
                            } else {
                                flowManager.selectedBlockers.insert(blocker)
                            }
                        }
                    )
                }
            }
        } footer: {
            ContinueButton(
                title: "Continue",
                isEnabled: flowManager.canProceed() && !flowManager.isNavigating,
                action: { flowManager.goNext() }
            )
        }
    }
}

// MARK: - Compact Selection Card for smaller screens
struct CompactSelectionCard: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let cardBackground = OnboardingTheme.cardBackground(colorScheme)
        let strokeColor = OnboardingTheme.cardStroke(colorScheme)

        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 28))
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color("AppSecondaryAccent"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ?
                        Color("AppSecondaryAccent").opacity(0.2) :
                        cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ?
                                Color("AppSecondaryAccent") :
                                strokeColor, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
