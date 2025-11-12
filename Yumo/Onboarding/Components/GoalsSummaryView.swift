//
//  GoalsSummaryView.swift
//  Yumo
//

import SwiftUI

struct GoalsSummaryView: View {
    let dailyCalories: Double
    let dailyProtein: Double
    let dailyCarbs: Double
    let dailyFat: Double
    let weightGoal: GoalType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)
        let mutedText = OnboardingTheme.mutedText(colorScheme)

        VStack(spacing: 30) {
            // Title
            Text("Your Personalized Plan")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(primaryText)

            // Encouraging message based on goal
            Text(encouragingMessage)
                .font(.body)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Main calorie goal (prominent)
            VStack(spacing: 8) {
                Text("Daily Calorie Goal")
                    .font(.headline)
                    .foregroundColor(secondaryText)

                Text("\(Int(dailyCalories))")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Color("AppSecondaryAccent"))

                Text("calories")
                    .font(.title3)
                    .foregroundColor(mutedText)
            }
            .padding(.vertical, 20)

            // Macros in cards
            HStack(spacing: 16) {
                MacroCard(title: "Protein", value: Int(dailyProtein), unit: "g", color: .blue)
                MacroCard(title: "Carbs", value: Int(dailyCarbs), unit: "g", color: .orange)
                MacroCard(title: "Fat", value: Int(dailyFat), unit: "g", color: .purple)
            }
            .padding(.horizontal)
        }
    }

    private var encouragingMessage: String {
        switch weightGoal {
        case .lose:
            return "We've created a plan to help you reach your weight loss goal safely and sustainably."
        case .maintain:
            return "We've created a balanced plan to help you maintain your current weight and feel great."
        case .gain:
            return "We've created a plan to help you build muscle and reach your strength goals."
        }
    }
}

struct MacroCard: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let mutedText = OnboardingTheme.mutedText(colorScheme)
        let cardBackground = OnboardingTheme.cardBackground(colorScheme)

        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(mutedText)

            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(unit)
                .font(.caption2)
                .foregroundColor(primaryText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
    }
}
