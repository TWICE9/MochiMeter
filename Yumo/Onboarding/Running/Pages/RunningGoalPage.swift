//
//  RunningGoalPage.swift
//  Yumo
//

import SwiftUI

struct RunningGoalPage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager

    private let goals: [(RunningGoalType, String)] = [
        (.generalFitness, "💪"),
        (.loseWeight, "🔥"),
        (.buildDistance, "🛣️"),
        (.improvePace, "⏱️"),
        (.trainForRace, "🏁")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "What's your main running goal?",
            subtitle: "Pick the one that matters most right now.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(goals, id: \.0) { goal, emoji in
                    SelectionCard(
                        title: goal.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.primaryGoal == goal,
                        action: { flowManager.primaryGoal = goal }
                    )
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
