//
//  ActivityLevelPage.swift
//  Yumo
//

import SwiftUI

struct ActivityLevelPage: View {
    @Bindable var flowManager: OnboardingFlowManager

    let activityOptions: [(ActivityLevel, String)] = [
        (.lowActivity, "🛋️"),
        (.moderateActivity, "🏃"),
        (.highActivity, "💪")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "How often do you work out?",
            subtitle: "This helps us determine your activity level",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(activityOptions, id: \.0) { level, emoji in
                    SelectionCard(
                        title: level.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.activityLevel == level,
                        action: {
                            flowManager.activityLevel = level
                            // Auto-advance after short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                flowManager.goNext()
                            }
                        }
                    )
                }
            }
        }
    }
}
