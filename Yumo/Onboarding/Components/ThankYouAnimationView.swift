//
//  ThankYouAnimationView.swift
//  Yumo
//

import SwiftUI

struct ThankYouAnimationView: View {
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8
    let onComplete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)

        VStack(spacing: 30) {
            Spacer()

            Image(colorScheme == .dark ? "LogoDarkMode" : "LogoHS")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 200, maxHeight: 200)
                .opacity(opacity)
                .scaleEffect(scale)

            Text("Thank you for trying us")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
                .opacity(opacity)

            Spacer()
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(duration: 0.6)) {
                opacity = 1
                scale = 1
            }

            // Auto-advance after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                    scale = 1.2
                }

                // Call completion after fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}
