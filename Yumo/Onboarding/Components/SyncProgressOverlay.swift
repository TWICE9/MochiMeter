//
//  SyncProgressOverlay.swift
//  Yumo
//

import SwiftUI

struct SyncProgressOverlay: View {
    var message: String
    @State private var isSpinning = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let strokeColor = OnboardingTheme.cardStroke(colorScheme)
        let cardBackground = OnboardingTheme.cardBackground(colorScheme)

        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(strokeColor, lineWidth: 8)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(Color("AppSecondaryAccent"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)
                }

                Text(message)
                    .font(.headline)
                    .foregroundColor(primaryText)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .id(message)
            }
            .padding(24)
            .background(cardBackground)
            .cornerRadius(20)
            .padding(.horizontal, 24)
        }
        .onAppear {
            isSpinning = true
        }
        .transition(.opacity)
    }
}
