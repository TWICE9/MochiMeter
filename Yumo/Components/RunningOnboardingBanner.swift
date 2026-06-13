//
//  RunningOnboardingBanner.swift
//  Yumo
//

import SwiftUI

/// Dismissible banner that prompts the user to complete running onboarding.
/// Shown on the activity screen when no `RunningProfile` exists (or onboarding
/// is incomplete). Tapping triggers the onboarding sheet via `onStart`.
struct RunningOnboardingBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    var onStart: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        let primaryText = colorScheme == .dark ? Color.white : Color(red: 32/255, green: 32/255, blue: 38/255)
        let secondaryText = colorScheme == .dark ? Color.white.opacity(0.75) : Color(red: 100/255, green: 100/255, blue: 110/255)

        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onStart()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.runAccent.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.run")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.runAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set up your running plan")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(primaryText)
                        .lineLimit(1)
                    Text("Personalized, adaptive, takes under a minute.")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(secondaryText.opacity(0.8))

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(secondaryText)
                        .padding(6)
                        .background(Circle().fill(Color.gray.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.runAccent.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                Color.runAccent.opacity(colorScheme == .dark ? 0.10 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.runAccent.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
