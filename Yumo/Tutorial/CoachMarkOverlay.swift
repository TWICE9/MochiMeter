// Tutorial/CoachMarkOverlay.swift

import SwiftUI

/// Creates a spotlight overlay that highlights a specific area of the screen
struct CoachMarkOverlay: View {
    @ObservedObject var tutorialManager: TutorialManager
    @Environment(\.colorScheme) private var colorScheme
    
    let step: TutorialStep
    
    @State private var contentOpacity: Double = 0
    
    private var primaryColor: Color {
        Color("AppPrimaryAccent")
    }
    
    private var secondaryColor: Color {
        Color("AppSecondaryAccent")
    }
    
    var body: some View {
        ZStack {
            // Darkened background with spotlight cutout
            SpotlightOverlay(targetFrame: step.targetFrame, cornerRadius: 16)
                .ignoresSafeArea()
                .onTapGesture {
                    // Tapping outside advances to next step
                    tutorialManager.nextStep()
                }
            
            // Tooltip content - positioned to not overlap spotlight
            tooltipView
                .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                contentOpacity = 1.0
            }
        }
    }
    
    @ViewBuilder
    private var tooltipView: some View {
        let tooltipPosition = calculateTooltipPosition()
        
        VStack(alignment: .leading, spacing: 12) {
            // Arrow pointing to target (if applicable)
            if step.arrowDirection == .down {
                arrowIndicator
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(step.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Progress and navigation
            HStack {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<tutorialManager.steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == tutorialManager.currentStepIndex ? primaryColor : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Skip button
                Button {
                    tutorialManager.skipTutorial()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                // Next/Done button
                Button {
                    tutorialManager.nextStep()
                } label: {
                    Text(tutorialManager.isLastStep ? "Done" : "Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
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
            
            // Arrow pointing to target (if applicable)
            if step.arrowDirection == .up {
                arrowIndicator
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.15))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .frame(maxWidth: 320)
        .position(x: tooltipPosition.x, y: tooltipPosition.y)
    }
    
    private var arrowIndicator: some View {
        Image(systemName: "triangle.fill")
            .font(.caption)
            .foregroundStyle(
                LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    private func calculateTooltipPosition() -> CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let tooltipHeight: CGFloat = 180 // Approximate height
        let padding: CGFloat = 24
        
        let x = screenWidth / 2 // Center horizontally
        var y: CGFloat
        
        // Is the target in the top or bottom half of the screen?
        let targetCenterY = step.targetFrame.midY
        let isTargetInBottomHalf = targetCenterY > screenHeight / 2
        
        if isTargetInBottomHalf {
            // Target is in bottom half - place tooltip at top
            y = min(step.targetFrame.minY - tooltipHeight / 2 - padding, screenHeight / 3)
        } else {
            // Target is in top half - place tooltip at bottom
            y = max(step.targetFrame.maxY + tooltipHeight / 2 + padding, screenHeight * 2 / 3)
        }
        
        // Keep tooltip within safe bounds
        y = max(tooltipHeight / 2 + 60, min(screenHeight - tooltipHeight / 2 - 40, y))
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Spotlight Mask Shape

struct SpotlightMask: Shape {
    var targetFrame: CGRect
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        // Main rectangle covering the entire screen
        var path = Path(rect)
        
        // Create the spotlight cutout with padding
        let spotlightRect = targetFrame.insetBy(dx: -8, dy: -8)
        
        // Add rounded rect path for the cutout
        path.addRoundedRect(in: spotlightRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        return path
    }
}

// MARK: - Spotlight View (using even-odd fill rule)

struct SpotlightOverlay: View {
    let targetFrame: CGRect
    let cornerRadius: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // Fill entire screen with dark overlay
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.8))
            )
            
            // Cut out the spotlight area using blendMode
            let spotlightRect = targetFrame.insetBy(dx: -8, dy: -8)
            let spotlightPath = RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: spotlightRect)
            
            context.blendMode = .destinationOut
            context.fill(spotlightPath, with: .color(.white))
        }
        .compositingGroup()
    }
}

