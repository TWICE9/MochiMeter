// Tutorial/WelcomeOverlay.swift

import SwiftUI

/// The initial welcome overlay shown before the tutorial begins
struct WelcomeOverlay: View {
    @ObservedObject var tutorialManager: TutorialManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50
    
    private var primaryColor: Color {
        Color("AppPrimaryAccent")
    }
    
    private var secondaryColor: Color {
        Color("AppSecondaryAccent")
    }
    
    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo / App Icon area
                VStack(spacing: 20) {
                    // App logo
                    Image(colorScheme == .dark ? "LogoDarkMode" : "LogoHS")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: primaryColor.opacity(0.5), radius: 20, y: 10)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                    VStack(spacing: 8) {
                        Text("Welcome to MochiMeter!")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Let's take a quick tour of the app")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .opacity(contentOpacity)
                }
                
                Spacer()
                
                // Feature highlights
                VStack(spacing: 16) {
                    FeatureRow(icon: "camera.fill", title: "AI Food Scanning", description: "Snap a photo to instantly log meals")
                    FeatureRow(icon: "sparkles", title: "Quick Text Logging", description: "Type what you ate for fast tracking")
                    FeatureRow(icon: "chart.bar.fill", title: "Progress Reports", description: "Visualize your nutrition journey")
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        tutorialManager.startTutorialFromWelcome()
                    } label: {
                        Text("Start Tour")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Button {
                        tutorialManager.skipTutorial()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .offset(y: buttonOffset)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                contentOpacity = 1.0
                buttonOffset = 0
            }
        }
    }
}

// MARK: - Feature Row Component

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color("AppPrimaryAccent"), Color("AppSecondaryAccent")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    WelcomeOverlay(tutorialManager: TutorialManager.shared)
}
