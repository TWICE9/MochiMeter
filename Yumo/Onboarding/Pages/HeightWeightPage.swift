//
//  HeightWeightPage.swift
//  Yumo
//

import SwiftUI

struct HeightWeightPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        OnboardingQuestionView(
            question: "What's your height and weight?",
            subtitle: nil,
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 30) {
                // Unit System Picker
                Picker("Units", selection: $flowManager.unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 30)
                
                // Side by side scrollers
                HStack(spacing: 20) {
                    // Height Picker
                    VStack {
                        Text("Height")
                            .font(.caption)
                            .foregroundColor(OnboardingTheme.mutedText(colorScheme))

                        if flowManager.unitSystem == .metric {
                            // Metric: cm
                            Picker("Height", selection: $flowManager.height) {
                                ForEach(120...220, id: \.self) { cm in
                                    Text("\(cm)")
                                        .tag(Double(cm))
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 150, height: 180)

                            Text("cm")
                                .font(.caption)
                                .foregroundColor(OnboardingTheme.mutedText(colorScheme))
                        } else {
                            // Imperial: feet and inches
                            HStack(spacing: 5) {
                                Picker("Feet", selection: $flowManager.heightFeet) {
                                    ForEach(4...7, id: \.self) { feet in
                                        Text("\(feet)")
                                            .tag(feet)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70)
                                
                                Text("'")
                                    .foregroundColor(OnboardingTheme.primaryText(colorScheme))
                                
                                Picker("Inches", selection: $flowManager.heightInches) {
                                    ForEach(0...11, id: \.self) { inches in
                                        Text("\(inches)")
                                            .tag(inches)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70)
                                
                                Text("\"")
                                    .foregroundColor(OnboardingTheme.primaryText(colorScheme))
                            }
                            .frame(height: 180)
                        }
                    }

                    // Weight Picker
                    VStack {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(OnboardingTheme.mutedText(colorScheme))

                        if flowManager.unitSystem == .metric {
                            // Metric: kg with decimal
                            HStack(spacing: 5) {
                                Picker("Whole", selection: $flowManager.weightWhole) {
                                    ForEach(30...180, id: \.self) { kg in
                                        Text("\(kg)")
                                            .tag(kg)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)

                                Text(".")
                                    .foregroundColor(OnboardingTheme.primaryText(colorScheme))

                                Picker("Decimal", selection: $flowManager.weightDecimal) {
                                    ForEach(0...9, id: \.self) { dec in
                                        Text("\(dec)")
                                            .tag(dec)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60)
                            }
                            .frame(height: 180)

                            Text("kg")
                                .font(.caption)
                                .foregroundColor(OnboardingTheme.mutedText(colorScheme))
                        } else {
                            // Imperial: lbs
                            Picker("Weight", selection: $flowManager.weightLbs) {
                                ForEach(66...400, id: \.self) { lbs in
                                    Text("\(lbs)")
                                        .tag(lbs)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 150, height: 180)

                            Text("lbs")
                                .font(.caption)
                                .foregroundColor(OnboardingTheme.mutedText(colorScheme))
                        }
                    }
                }
                .onChange(of: flowManager.weightWhole) { _, _ in
                    flowManager.updateWeightFromPickers()
                }
                .onChange(of: flowManager.weightDecimal) { _, _ in
                    flowManager.updateWeightFromPickers()
                }
                .onChange(of: flowManager.weightLbs) { _, _ in
                    flowManager.updateWeightFromImperialPickers()
                }
                .onChange(of: flowManager.heightFeet) { _, _ in
                    flowManager.updateHeightFromImperialPickers()
                }
                .onChange(of: flowManager.heightInches) { _, _ in
                    flowManager.updateHeightFromImperialPickers()
                }
                .onChange(of: flowManager.unitSystem) { oldValue, newValue in
                    flowManager.convertUnitsOnChange(from: oldValue, to: newValue)
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
