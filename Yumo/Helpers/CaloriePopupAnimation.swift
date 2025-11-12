// Helpers/CaloriePopupAnimation.swift

import SwiftUI

struct CaloriePopupAnimation: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            // Main calorie notification (center, near main ring)
            FloatingNotification(
                value: calories,
                label: "kcal",
                color: Color("AppPrimaryAccent"),
                delay: 0,
                offsetX: 0,
                startY: -120  // Position near top of main calorie ring
            )

            // Protein notification (left, near protein ring)
            FloatingNotification(
                value: protein,
                label: "protein",
                color: .pink,
                delay: 0.15,
                offsetX: -90,   // Left macro ring position
                startY: 60      // Position below main ring where macro rings are
            )

            // Carbs notification (center, near carbs ring)
            FloatingNotification(
                value: carbs,
                label: "carbs",
                color: Color("AppSecondaryAccent"),
                delay: 0.3,
                offsetX: 0,     // Center macro ring position
                startY: 60      // Position below main ring where macro rings are
            )

            // Fat notification (right, near fat ring)
            FloatingNotification(
                value: fat,
                label: "fat",
                color: .orange,
                delay: 0.45,
                offsetX: 90,    // Right macro ring position
                startY: 60      // Position below main ring where macro rings are
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                isShowing = false
            }
        }
    }
}

struct FloatingNotification: View {
    let value: Double
    let label: String
    let color: Color
    let delay: Double
    let offsetX: CGFloat
    let startY: CGFloat

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        HStack(spacing: 6) {
            Text("+\(Int(value))")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(color, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.6), radius: 8, x: 0, y: 4)
        )
        .offset(x: offsetX, y: startY + offsetY)
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Bounce in and fade out quickly
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    opacity = 1
                    scale = 1.1
                }

                // Fade away quickly while maintaining position
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        opacity = 0
                        scale = 0.9
                    }
                }
            }
        }
    }
}

