//
//  GoalsToAccomplishPage.swift
//  Yumo
//

import SwiftUI

struct GoalsToAccomplishPage: View {
    @Bindable var flowManager: OnboardingFlowManager

    let goalOptions: [(GoalToAccomplish, String)] = [
        (.eatHealthier, "🥗"),
        (.boostEnergy, "⚡️"),
        (.stayMotivated, "🎯"),
        (.feelBetter, "😊")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "What do you want to accomplish?",
            subtitle: "Select all that apply",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(goalOptions, id: \.0) { goal, emoji in
                    SelectionCard(
                        title: goal.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.selectedGoalsToAccomplish.contains(goal),
                        action: {
                            if flowManager.selectedGoalsToAccomplish.contains(goal) {
                                flowManager.selectedGoalsToAccomplish.remove(goal)
                            } else {
                                flowManager.selectedGoalsToAccomplish.insert(goal)
                            }
                        }
                    )
                }

                Spacer().frame(height: 20)

                ContinueButton(
                    title: "Continue",
                    isEnabled: flowManager.canProceed() && !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
    }
}
