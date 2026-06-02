//
//  FoodAnalysisLoadingView.swift
//  Yumo
//
//  Animated loading view shown while AI analyzes a food photo.
//

import SwiftUI

// MARK: - Food Analysis Loading View

struct FoodAnalysisLoadingView: View {
    @State private var currentMessageIndex = 0
    @State private var rotation: Double = 0

    let messages = [
        "Analyzing your food...",
        "Identifying ingredients...",
        "Calculating nutrition...",
        "Estimating portion size...",
        "Finalizing results..."
    ]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Spinning loading ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color("AppPrimaryAccent"),
                                Color("AppSecondaryAccent")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                // Sparkles icon
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(Color("AppSecondaryAccent"))
                    .scaleEffect(1.1)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: rotation)
            }

            // Animated message
            Text(messages[currentMessageIndex])
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id(currentMessageIndex)

            Text("AI is working its magic ✨")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Spacer()
        }
        .onAppear {
            cycleMessages()
        }
    }

    private func cycleMessages() {
        // Slow the message cadence to ~1.5s per change
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.35)) {
                if currentMessageIndex < messages.count - 1 {
                    currentMessageIndex += 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}
