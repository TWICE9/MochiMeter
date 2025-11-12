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
                // Side by side scrollers
                HStack(spacing: 20) {
                    // Height Picker
                    VStack {
                        Text("Height")
                            .font(.caption)
                            .foregroundColor(OnboardingTheme.mutedText(colorScheme))

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
                    }

                    // Weight Picker
                    VStack {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(OnboardingTheme.mutedText(colorScheme))

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
                    }
                }
                .onChange(of: flowManager.weightWhole) { _, _ in
                    flowManager.updateWeightFromPickers()
                }
                .onChange(of: flowManager.weightDecimal) { _, _ in
                    flowManager.updateWeightFromPickers()
                }

                Spacer().frame(height: 20)

                ContinueButton(
                    title: "Continue",
                    isEnabled: flowManager.canProceed(for: 5),
                    action: { flowManager.goNext() }
                )
            }
        }
    }
}
