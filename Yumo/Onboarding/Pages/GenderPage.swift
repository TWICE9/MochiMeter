//
//  GenderPage.swift
//  Yumo
//

import SwiftUI

struct GenderPage: View {
    @Bindable var flowManager: OnboardingFlowManager

    let genderOptions: [(Gender, String)] = [
        (.male, "👨"),
        (.female, "👩"),
        (.preferNotToSay, "🙂")
    ]

    var body: some View {
        OnboardingQuestionView(
            question: "What's your gender?",
            subtitle: "This helps us calculate your calorie goals",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 12) {
                ForEach(genderOptions, id: \.0) { gender, emoji in
                    SelectionCard(
                        title: gender.rawValue,
                        emoji: emoji,
                        isSelected: flowManager.gender == gender,
                        action: {
                            guard !flowManager.isNavigating else { return }
                            flowManager.gender = gender
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
