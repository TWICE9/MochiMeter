//
//  WeightLossIntensityPage.swift
//  Yumo
//

import SwiftUI

struct WeightLossIntensityPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    // Slider range: 0.1 to 1.0 kg per week
    private let minRate: Double = 0.1
    private let maxRate: Double = 1.0

    private var primaryText: Color {
        OnboardingTheme.primaryText(colorScheme)
    }

    private var secondaryText: Color {
        OnboardingTheme.secondaryText(colorScheme)
    }

    private var mutedText: Color {
        OnboardingTheme.mutedText(colorScheme)
    }

    // Calculate estimated end date
    private var estimatedEndDate: Date? {
        let weightToLose = flowManager.weight - flowManager.targetWeight
        guard weightToLose > 0, flowManager.weeklyWeightChangeKg > 0 else { return nil }

        let weeksNeeded = weightToLose / flowManager.weeklyWeightChangeKg
        let daysNeeded = Int(ceil(weeksNeeded * 7))

        return Calendar.current.date(byAdding: .day, value: daysNeeded, to: Date())
    }

    // Format the end date nicely
    private var formattedEndDate: String {
        guard let endDate = estimatedEndDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: endDate)
    }

    // Weeks until goal
    private var weeksUntilGoal: Int {
        let weightToLose = flowManager.weight - flowManager.targetWeight
        guard weightToLose > 0, flowManager.weeklyWeightChangeKg > 0 else { return 0 }
        return Int(ceil(weightToLose / flowManager.weeklyWeightChangeKg))
    }

    // Intensity label
    private var intensityLabel: String {
        switch flowManager.weeklyWeightChangeKg {
        case 0..<0.3:
            return "Gentle"
        case 0.3..<0.6:
            return "Moderate"
        case 0.6..<0.85:
            return "Ambitious"
        default:
            return "Intense"
        }
    }

    // Intensity color
    private var intensityColor: Color {
        switch flowManager.weeklyWeightChangeKg {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return Color("AppSecondaryAccent")
        case 0.6..<0.85:
            return .orange
        default:
            return .red
        }
    }

    // Calculate daily deficit for display
    private var dailyDeficit: Int {
        Int(flowManager.weeklyWeightChangeKg * 7700 / 7)
    }

    var body: some View {
        OnboardingQuestionView(
            question: "How fast do you want to reach your goal?",
            subtitle: "Choose your weight loss pace",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 32) {
                // Current selection display
                VStack(spacing: 8) {
                    Text(String(format: "%.2f kg", flowManager.weeklyWeightChangeKg))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(intensityColor)

                    Text("per week")
                        .font(.title3)
                        .foregroundStyle(secondaryText)

                    // Intensity badge
                    Text(intensityLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(intensityColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 20)

                // Slider
                VStack(spacing: 12) {
                    Slider(
                        value: $flowManager.weeklyWeightChangeKg,
                        in: minRate...maxRate,
                        step: 0.05
                    )
                    .tint(intensityColor)

                    // Min/Max labels
                    HStack {
                        Text("0.1 kg")
                            .font(.caption)
                            .foregroundStyle(mutedText)
                        Spacer()
                        Text("1.0 kg")
                            .font(.caption)
                            .foregroundStyle(mutedText)
                    }
                }
                .padding(.horizontal)

                // Info cards
                VStack(spacing: 16) {
                    // Estimated end date card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Goal Date")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                            Text(formattedEndDate)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(primaryText)
                        }

                        Spacer()

                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(Color("AppSecondaryAccent"))
                    }
                    .padding()
                    .background(OnboardingTheme.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                    )

                    // Duration card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                            Text("\(weeksUntilGoal) weeks")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(primaryText)
                        }

                        Spacer()

                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundStyle(Color("AppSecondaryAccent"))
                    }
                    .padding()
                    .background(OnboardingTheme.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                    )

                    // Daily deficit info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Calorie Deficit")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                            Text("\(dailyDeficit) cal")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(primaryText)
                        }

                        Spacer()

                        Image(systemName: "flame")
                            .font(.title2)
                            .foregroundStyle(intensityColor)
                    }
                    .padding()
                    .background(OnboardingTheme.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                    )
                }

                // Recommendation text
                if flowManager.weeklyWeightChangeKg >= 0.85 {
                    Text("A deficit of 1kg/week is intense. Consider a gentler pace for sustainable results.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                ContinueButton(title: "Continue", isEnabled: !flowManager.isNavigating) {
                    flowManager.goNext()
                }
            }
        }
    }
}
