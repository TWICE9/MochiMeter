//
//  RunningWelcomePage.swift
//  Yumo
//

import SwiftUI

struct RunningWelcomePage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)

        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Image(systemName: "figure.run")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(Color.purple)
                }

                Text("Let's build your running plan")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(primary)
                    .multilineTextAlignment(.center)

                Text("A few quick questions to understand your goals, your availability, and where you are today. Takes under a minute.")
                    .font(.body)
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 24)

            Spacer()

            ContinueButton(
                title: "Get Started",
                isEnabled: !flowManager.isNavigating,
                action: { flowManager.goNext() }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
