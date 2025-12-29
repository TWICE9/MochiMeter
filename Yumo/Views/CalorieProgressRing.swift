//
//  CalorieProgressRing.swift
//  Yumo
//
//  Created by Apple on 8/11/2025.
//


// Views/CalorieProgressRing.swift

import SwiftUI

struct CalorieProgressRing: View {
    let current: Double
    let goal: Double
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    // Calculate the percentage completion (clamped between 0 and 1)
    private var progress: Double {
        min(current / goal, 1.0)
    }
    
    // Determine the gradient based on whether the goal is exceeded
    private var progressGradient: LinearGradient {
        let colors = current > goal 
            ? themeManager.currentTheme.overageGradient(for: colorScheme)
            : themeManager.currentTheme.wheelGradient(for: colorScheme)
            
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Ring (Faded/Gray)
                Circle()
                    .stroke(
                        Color.white.opacity(0.15),
                        lineWidth: 18
                    )
                
                // Progress Ring
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    // Start at the top (12 o'clock)
                    .rotationEffect(.degrees(-90))
                    // Smooth, fluid animation
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
                
                // --- Display Text ---
                VStack {
                    Text("\(current, specifier: "%.0f")")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("of \(goal, specifier: "%.0f") kcal")
                        .font(.headline)
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 150, height: 150)
        }
    }
}