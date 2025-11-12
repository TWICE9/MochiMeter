//
//  SelectionCard.swift
//  Yumo
//

import SwiftUI

struct SelectionCard: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let cardBackground = OnboardingTheme.cardBackground(colorScheme)
        let strokeColor = OnboardingTheme.cardStroke(colorScheme)

        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 40))
                }

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("AppSecondaryAccent"))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ?
                        Color("AppSecondaryAccent").opacity(0.2) :
                        cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ?
                                Color("AppSecondaryAccent") :
                                strokeColor, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
