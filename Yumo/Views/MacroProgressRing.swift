// Views/MacroProgressRing.swift

import SwiftUI

struct MacroProgressRing: View {
    let macroName: String
    let current: Double
    let goal: Double
    let color: Color
    var lineWidth: CGFloat = 8
    var ringSize: CGFloat = 80
    
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard goal > 0 else { return 0.0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: lineWidth)
                    .frame(width: ringSize, height: ringSize)
                
                // Progress Circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color, color]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    .animation(.easeOut(duration: 1.0), value: progress)
                
                // Value Text inside ring
                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: ringSize * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                    
                    Text("g")
                        .font(.system(size: ringSize * 0.18, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            // Label below ring
            Text(macroName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(secondaryTextColor)
        }
        .padding(10) // Prevent stroke/shadow clipping
        .drawingGroup() 
        .padding(-10)
    }
    
    // Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .light ? Color(red: 0.2, green: 0.2, blue: 0.25) : .white
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .light ? Color(red: 0.5, green: 0.5, blue: 0.55) : .white.opacity(0.7)
    }
}
