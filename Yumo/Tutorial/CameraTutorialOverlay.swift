// Tutorial/CameraTutorialOverlay.swift

import SwiftUI
import Combine

/// Manages the camera-specific tutorial state
@MainActor
class CameraTutorialManager: ObservableObject {
    static let shared = CameraTutorialManager()
    
    @Published var isShowingTutorial = false
    @Published var currentStepIndex = 0
    
    @AppStorage("hasSeenCameraTutorial") var hasSeenCameraTutorial = false
    
    // Steps for camera tutorial
    enum CameraStep: Int, CaseIterable {
        case aiScan = 0
        case barcode = 1
        
        var title: String {
            switch self {
            case .aiScan: return "✨ AI Food Scanner"
            case .barcode: return "📊 Barcode Scanner"
            }
        }
        
        var message: String {
            switch self {
            case .aiScan:
                return "Point your camera at any meal and tap the shutter. AI will automatically identify foods and calculate nutrition. This is a premium feature!"
            case .barcode:
                return "Packaged food? Just point the camera at the barcode — it'll scan automatically with no extra taps."
            }
        }
        
        var icon: String {
            switch self {
            case .aiScan: return "sparkles"
            case .barcode: return "barcode.viewfinder"
            }
        }
    }
    
    var currentStep: CameraStep? {
        CameraStep(rawValue: currentStepIndex)
    }
    
    var isLastStep: Bool {
        currentStepIndex >= CameraStep.allCases.count - 1
    }
    
    func startTutorial() {
        guard !hasSeenCameraTutorial else { return }
        currentStepIndex = 0
        isShowingTutorial = true
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
    
    func skipTutorial() {
        completeTutorial()
    }
    
    func completeTutorial() {
        withAnimation(.easeOut(duration: 0.3)) {
            isShowingTutorial = false
        }
        hasSeenCameraTutorial = true
    }
    
    func resetTutorial() {
        hasSeenCameraTutorial = false
        currentStepIndex = 0
    }
}

/// Overlay for camera tutorial with step cards
struct CameraTutorialOverlay: View {
    @ObservedObject var tutorialManager = CameraTutorialManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    /// Callback when step changes (for mode switching)
    var onStepChange: ((CameraTutorialManager.CameraStep) -> Void)?
    
    @State private var cardOpacity: Double = 0
    @State private var cardOffset: CGFloat = 50
    
    private var primaryColor: Color {
        Color("AppPrimaryAccent")
    }
    
    private var secondaryColor: Color {
        Color("AppSecondaryAccent")
    }
    
    var body: some View {
        if tutorialManager.isShowingTutorial, let step = tutorialManager.currentStep {
            ZStack {
                // Semi-transparent background (lighter than main tutorial)
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        tutorialManager.nextStep()
                        notifyStepChange()
                    }
                
                
                // Tutorial Card - Centered on screen
                VStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: step.icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: primaryColor.opacity(0.4), radius: 12, y: 6)
                    
                    // Title
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    // Message
                    Text(step.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(CameraTutorialManager.CameraStep.allCases, id: \.rawValue) { s in
                            Circle()
                                .fill(s == step ? secondaryColor : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Buttons
                    HStack(spacing: 16) {
                        Button {
                            tutorialManager.skipTutorial()
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                        
                        Button {
                            tutorialManager.nextStep()
                            notifyStepChange()
                        } label: {
                            Text(tutorialManager.isLastStep ? "Got it!" : "Next")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [primaryColor, secondaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(white: 0.12))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                )
                .padding(.horizontal, 24)
                .offset(y: cardOffset)
                .opacity(cardOpacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cardOpacity = 1
                    cardOffset = 0
                }
            }
            .onChange(of: tutorialManager.currentStepIndex) { _, _ in
                // Animate card transition
                withAnimation(.easeOut(duration: 0.15)) {
                    cardOpacity = 0.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        cardOpacity = 1
                    }
                }
            }
        }
    }
    
    private func notifyStepChange() {
        if let step = tutorialManager.currentStep {
            onStepChange?(step)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraTutorialOverlay()
    }
    .onAppear {
        CameraTutorialManager.shared.hasSeenCameraTutorial = false
        CameraTutorialManager.shared.startTutorial()
    }
}
