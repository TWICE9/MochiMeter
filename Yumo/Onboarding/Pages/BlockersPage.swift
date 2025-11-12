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
            VStack(spacing: 12) {
                ForEach(blockerOptions, id: \.0) { blocker, emoji in
                    SelectionCard(
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

                Spacer().frame(height: 20)

                ContinueButton(
                    title: "Continue",
                    isEnabled: flowManager.canProceed(for: 9),
                    action: { flowManager.goNext() }
                )
            }
        }
    }
}
