//
//  WeightGoalPage.swift
//  Yumo
//

import SwiftUI

struct WeightGoalPage: View {
    @Bindable var flowManager: OnboardingFlowManager

    let goalOptions: [(GoalType, String)] = [
        (.lose, "⚖️"),
        (.maintain, "🎯"),
        (.gain, "💪")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "What's your goal?",
            subtitle: nil,
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(goalOptions, id: \.0) { goal, emoji in
                    SelectionCard(
                        title: goal.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.weightGoal == goal,
                        action: {
                            guard !flowManager.isNavigating else { return }
                            flowManager.weightGoal = goal
                            // Auto-advance after short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                guard !flowManager.isNavigating else { return }
                                flowManager.goNext()
                            }
                        }
                    )
                }
            }
        }
    }
}
