//
//  OnboardingProgressBar.swift
//  Yumo
//

import SwiftUI

struct OnboardingProgressBar: View {
    let progress: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(OnboardingTheme.progressTrack(colorScheme))
                    .frame(height: 4)

                // Progress fill with animation
                Rectangle()
                    .fill(Color("AppSecondaryAccent"))
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.spring(duration: 0.4), value: progress)
            }
        }
        .frame(height: 4)
    }
}
