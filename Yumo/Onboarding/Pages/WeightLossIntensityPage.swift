//
//  WeightLossIntensityPage.swift
//  Yumo
//

import SwiftUI

struct WeightLossIntensityPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    // Slider range: 0.1 to 1.0 kg per week (internal always in kg)
    private let minRateKg: Double = 0.1
    private let maxRateKg: Double = 1.0
    
    // Conversion factor: 1 kg = 2.20462 lbs
    private let kgToLbs: Double = 2.20462
    
    // Check if using imperial
    private var isImperial: Bool {
        flowManager.unitSystem == .imperial
    }
    
    // Display values for slider (in user's preferred unit)
    private var displayValue: Double {
        isImperial ? flowManager.weeklyWeightChangeKg * kgToLbs : flowManager.weeklyWeightChangeKg
    }
    
    private var displayMinRate: Double {
        isImperial ? minRateKg * kgToLbs : minRateKg
    }
    
    private var displayMaxRate: Double {
        isImperial ? maxRateKg * kgToLbs : maxRateKg
    }
    
    private var unitLabel: String {
        isImperial ? "lbs" : "kg"
    }
    
    private var displayStep: Double {
        isImperial ? 0.1 : 0.05
    }

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

    // Intensity label (based on kg value for consistency)
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
    
    // Formatted display string with unit
    private var formattedWeightChange: String {
        if isImperial {
            return String(format: "%.1f lbs", displayValue)
        } else {
            return String(format: "%.2f kg", flowManager.weeklyWeightChangeKg)
        }
    }

    var body: some View {
        OnboardingQuestionView(
            question: "How fast do you want to reach your goal?",
            subtitle: "Choose your weight loss pace",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 16) {
                // Current selection display
                VStack(spacing: 4) {
                    Text(formattedWeightChange)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(intensityColor)

                    Text("per week")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)

                    // Intensity badge
                    Text(intensityLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(intensityColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)

                // Slider (always operates in kg internally)
                VStack(spacing: 8) {
                    Slider(
                        value: $flowManager.weeklyWeightChangeKg,
                        in: minRateKg...maxRateKg,
                        step: 0.05
                    )
                    .tint(intensityColor)

                    // Min/Max labels (in user's unit)
                    HStack {
                        Text(String(format: isImperial ? "%.1f lbs" : "%.1f kg", displayMinRate))
                            .font(.caption2)
                            .foregroundStyle(mutedText)
                        Spacer()
                        Text(String(format: isImperial ? "%.1f lbs" : "%.1f kg", displayMaxRate))
                            .font(.caption2)
                            .foregroundStyle(mutedText)
                    }
                }

                // Goal Date (full width)
                HStack {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundStyle(Color("AppSecondaryAccent"))
                    Text("Goal Date")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    Spacer()
                    Text(formattedEndDate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(OnboardingTheme.cardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                )

                // Duration & Deficit (side by side)
                HStack(spacing: 8) {

                    // Duration
                    VStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.body)
                            .foregroundStyle(Color("AppSecondaryAccent"))
                        Text("\(weeksUntilGoal) weeks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(OnboardingTheme.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                    )

                    // Daily deficit
                    VStack(spacing: 2) {
                        Image(systemName: "flame")
                            .font(.body)
                            .foregroundStyle(intensityColor)
                        Text("\(dailyDeficit) cal/day")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(OnboardingTheme.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                    )
                }

                // Recommendation text
                if flowManager.weeklyWeightChangeKg >= 0.85 {
                    Text("A deficit of 1kg/week is intense. Consider a gentler pace.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
        } footer: {
            ContinueButton(title: "Continue", isEnabled: !flowManager.isNavigating) {
                flowManager.goNext()
            }
        }
    }
}
