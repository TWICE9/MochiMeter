//
//  DietTypePage.swift
//  Yumo
//

import SwiftUI

struct DietTypePage: View {
    @Bindable var flowManager: OnboardingFlowManager

    let dietOptions: [(DietType, String)] = [
        (.regular, "🍽️"),
        (.pescatarian, "🐟"),
        (.vegetarian, "🥗"),
        (.vegan, "🌱")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "Do you follow a specific diet?",
            subtitle: nil,
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(dietOptions, id: \.0) { diet, emoji in
                    SelectionCard(
                        title: diet.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.dietType == diet,
                        action: {
                            flowManager.dietType = diet
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
