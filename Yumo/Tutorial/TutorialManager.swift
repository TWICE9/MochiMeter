// Tutorial/TutorialManager.swift

import SwiftUI
import Combine

/// Defines a step in the tutorial with target frame, message, and positioning
struct TutorialStep: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let targetFrame: CGRect
    let arrowDirection: ArrowDirection
    
    enum ArrowDirection {
        case up, down, left, right, none
    }
    
    static func == (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        lhs.id == rhs.id
    }
}

/// Preference key for passing target frames up the view hierarchy
struct TutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// View modifier to mark a view as a tutorial target
struct TutorialTargetModifier: ViewModifier {
    let id: String
    @State private var frame: CGRect = .zero
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: TutorialTargetPreferenceKey.self,
                            value: [id: geo.frame(in: .global)]
                        )
                        .onAppear {
                            // Capture frame on appear for initial layout
                            DispatchQueue.main.async {
                                let newFrame = geo.frame(in: .global)
                                TutorialManager.shared.updateTargetFrame(id: id, frame: newFrame)
                            }
                        }
                }
            )
    }
}

extension View {
    /// Mark this view as a tutorial spotlight target
    func tutorialTarget(id: String) -> some View {
        modifier(TutorialTargetModifier(id: id))
    }
}

/// Manages the tutorial state and progression
@MainActor
class TutorialManager: ObservableObject {
    static let shared = TutorialManager()
    
    // MARK: - Published State
    @Published var isShowingTutorial = false
    @Published var currentStepIndex = 0
    @Published var isShowingWelcome = true
    @Published var targetFrames: [String: CGRect] = [:]
    
    // MARK: - Persisted State
    @AppStorage("hasCompletedTutorial") var hasCompletedTutorial = false
    
    // MARK: - Step Definitions (id, title, message, arrow direction)
    private var stepDefinitions: [(id: String, title: String, message: String, arrow: TutorialStep.ArrowDirection)] {
        var steps: [(id: String, title: String, message: String, arrow: TutorialStep.ArrowDirection)] = [
            (
                id: "quickMealInput",
                title: "✨ Quick Log",
                message: "Type what you ate and AI will instantly calculate the nutrition. This premium feature makes logging meals super fast!",
                arrow: .up
            )
        ]

        if #available(iOS 26, *) {
            // iOS 26: no FAB, scan is a tab — skip FAB tutorial steps
        } else {
            steps.append((
                id: "fabButton",
                title: "📸 Add Food",
                message: "Tap this button to log your meals. You can search for foods or use the AI camera scanner!",
                arrow: .up
            ))
            steps.append((
                id: "fabMenuOptions",
                title: "🍎 Two Ways to Log",
                message: "Search our database of 3M+ foods, or use AI Scan to photograph your meal and let AI do the work!",
                arrow: .down
            ))
        }

        return steps
    }
    
    /// Callback when a step requires an action (like opening the FAB menu)
    var onStepAction: ((String) -> Void)?
    
    // MARK: - Computed Steps (built from definitions + registered frames)
    var steps: [TutorialStep] {
        stepDefinitions.compactMap { def in
            guard let frame = targetFrames[def.id], frame != .zero else { return nil }
            return TutorialStep(
                id: def.id,
                title: def.title,
                message: def.message,
                targetFrame: frame,
                arrowDirection: def.arrow
            )
        }
    }
    
    var currentStep: TutorialStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex >= steps.count - 1
    }
    
    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(steps.count)
    }
    
    // MARK: - Actions
    
    func startTutorial() {
        guard !hasCompletedTutorial else { return }
        isShowingTutorial = true
        isShowingWelcome = true
        currentStepIndex = 0
    }
    
    func startTutorialFromWelcome() {
        isShowingWelcome = false
        // Steps will be shown via CoachMarkOverlay
    }
    
    func nextStep() {
        if isLastStep {
            completeTutorial()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStepIndex += 1
            }
        }
    }
    
    func previousStep() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStepIndex -= 1
        }
    }
    
    func skipTutorial() {
        completeTutorial()
    }
    
    func completeTutorial() {
        withAnimation(.easeOut(duration: 0.3)) {
            isShowingTutorial = false
            isShowingWelcome = false
        }
        hasCompletedTutorial = true
    }
    
    func resetTutorial() {
        hasCompletedTutorial = false
        currentStepIndex = 0
        isShowingWelcome = true
    }
    
    // MARK: - Frame Management
    
    func updateTargetFrame(id: String, frame: CGRect) {
        if targetFrames[id] != frame {
            targetFrames[id] = frame
        }
    }
}

