//
//  ContinueButton.swift
//  Yumo
//

import SwiftUI

struct ContinueButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let disabledText = OnboardingTheme.mutedText(colorScheme)
        let disabledBackground = OnboardingTheme.cardBackground(colorScheme)

        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isEnabled ? .black : disabledText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEnabled ?
                            Color("AppSecondaryAccent") :
                            disabledBackground)
                )
        }
        .disabled(!isEnabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}
