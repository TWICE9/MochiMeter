//
//  ThemeSelectionPage.swift
//  Yumo
//

import SwiftUI

struct ThemeSelectionPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        OnboardingQuestionView(
            question: "Choose Your Mochi Theme",
            subtitle: "Pick your favorite mochi flavor to personalize the app",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 30) {
                themeGrid
                
                Spacer().frame(height: 20)
                
                ContinueButton(
                    title: "Continue",
                    isEnabled: !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
    }
    
    private var themeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(MochiTheme.allCases, id: \.self) { theme in
                MochiThemeButton(
                    theme: theme,
                    isSelected: themeManager.currentTheme == theme,
                    action: {
                        let haptic = UIImpactFeedbackGenerator(style: .medium)
                        haptic.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            themeManager.currentTheme = theme
                        }
                    }
                )
                .frame(height: 120)
            }
        }
    }
}
