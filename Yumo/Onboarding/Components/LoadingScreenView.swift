//
//  LoadingScreenView.swift
//  Yumo
//

import SwiftUI

struct LoadingScreenView: View {
    @State private var progress: Double = 0.0
    @State private var currentMessage = "Analyzing your profile..."
    let onComplete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    let messages = [
        (0.0, "Analyzing your profile..."),
        (0.25, "Calculating metabolic rate..."),
        (0.50, "Determining nutrition goals..."),
        (0.75, "Creating your personalized plan...")
    ]

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let mutedText = OnboardingTheme.mutedText(colorScheme)
        let strokeColor = OnboardingTheme.cardStroke(colorScheme)

        VStack(spacing: 40) {
            Spacer()

            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(strokeColor, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color("AppSecondaryAccent"), lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryText)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: progress)
            }

            // Message
            Text(currentMessage)
                .font(.headline)
                .foregroundColor(mutedText)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.3), value: currentMessage)

            Spacer()
        }
        .onAppear {
            startLoading()
        }
    }

    private func startLoading() {
        // Animate progress from 0 to 1 over 4.5 seconds
        let totalDuration = 4.5
        let delay = totalDuration / 100.0

        for i in 0...100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay * Double(i)) {
                withAnimation {
                    progress = Double(i) / 100.0

                    // Update message based on progress
                    if progress >= 0.75 {
                        currentMessage = messages[3].1
                    } else if progress >= 0.50 {
                        currentMessage = messages[2].1
                    } else if progress >= 0.25 {
                        currentMessage = messages[1].1
                    }

                    // Auto-advance when complete
                    if i == 100 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onComplete()
                        }
                    }
                }
            }
        }
    }
}
