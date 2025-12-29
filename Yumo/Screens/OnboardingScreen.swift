// Screens/OnboardingScreen.swift

import SwiftUI

struct OnboardingScreen: View {
    var onFinish: () -> Void
    
    var body: some View {
        // Redirect to the new onboarding implementation
        NewOnboardingScreen(onFinish: onFinish)
    }
}
