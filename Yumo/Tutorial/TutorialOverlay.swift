// Tutorial/TutorialOverlay.swift

import SwiftUI

/// The main tutorial overlay that shows either the welcome screen or coach marks
struct TutorialOverlay: View {
    @ObservedObject private var tutorialManager = TutorialManager.shared
    
    var body: some View {
        ZStack {
            if tutorialManager.isShowingTutorial {
                if tutorialManager.isShowingWelcome {
                    // Show welcome page first
                    WelcomeOverlay(tutorialManager: tutorialManager)
                        .transition(.opacity)
                } else if let currentStep = tutorialManager.currentStep {
                    // Show coach mark for current step
                    CoachMarkOverlay(tutorialManager: tutorialManager, step: currentStep)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tutorialManager.isShowingTutorial)
        .animation(.easeInOut(duration: 0.3), value: tutorialManager.isShowingWelcome)
        .animation(.easeInOut(duration: 0.3), value: tutorialManager.currentStepIndex)
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    /// Adds the tutorial overlay system to this view and collects target frames
    func withTutorialOverlay() -> some View {
        self
            .onPreferenceChange(TutorialTargetPreferenceKey.self) { frames in
                Task { @MainActor in
                    for (id, frame) in frames {
                        TutorialManager.shared.updateTargetFrame(id: id, frame: frame)
                    }
                }
            }
            .overlay {
                TutorialOverlay()
            }
    }
}
