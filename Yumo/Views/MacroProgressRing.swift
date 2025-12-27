// Views/MacroProgressRing.swift

import SwiftUI

struct MacroProgressRing: View {
    let macroName: String
    let current: Double
    let goal: Double
    let color: Color
    var lineWidth: CGFloat = 10
    var ringSize: CGFloat = 80
    var showOverflow: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        // Ensure goal is not zero to avoid NaN
        guard goal > 0 else { return 0.0 }
        return min(current / goal, 1.0)
    }

    private var overflowProgress: Double {
        guard goal > 0, current > goal else { return 0.0 }
        let overflow = (current - goal) / goal
        return min(overflow, 1.0) // Cap at 100% overflow (200% total)
    }

    private var isOverGoal: Bool {
        current > goal
    }

    // Adapt color for light/dark mode
    private var adaptiveColor: Color {
        if colorScheme == .light {
            // Use darker, more saturated colors for light mode visibility
            // Convert system colors to darker variants
            if color == .pink {
                return Color(red: 0.8, green: 0.2, blue: 0.4) // Deep pink
            } else if color == .orange {
                return Color(red: 0.9, green: 0.5, blue: 0.1) // Deep orange
            } else {
                // For custom colors (like AppSecondaryAccent), keep as is
                return color
            }
        } else {
            return color
        }
    }

    // Adaptive background ring color
    private var adaptiveBackgroundColor: Color {
        if colorScheme == .light {
            return Color("AppTextPrimary").opacity(0.1)
        } else {
            return Color("AppTextPrimary").opacity(0.1)
        }
    }

    // Adaptive text color
    private var adaptiveTextColor: Color {
        if colorScheme == .light {
            return Color("AppTextPrimary")
        } else {
            return Color("AppTextPrimary")
        }
    }

    // Adaptive font sizes based on ring size
    private var isLargeRing: Bool {
        ringSize >= 100
    }
    
    private var valueFontSize: Font {
        isLargeRing ? .title3.bold() : .headline.bold()
    }
    
    private var unitFontSize: Font {
        isLargeRing ? .subheadline : .caption
    }
    
    private var labelFontSize: Font {
        isLargeRing ? .body : .subheadline
    }
    
    var body: some View {
        VStack(spacing: isLargeRing ? 10 : 8) {
            ZStack {
                // Background Ring
                Circle()
                    .stroke(
                        adaptiveBackgroundColor,
                        lineWidth: lineWidth
                    )
                    .frame(width: ringSize, height: ringSize)

                // Base Progress Ring (0-100%)
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(
                        adaptiveColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
                    .animation(.easeOut(duration: 0.9), value: progress)

                // Overflow Ring (100%+) in red/orange (only if showOverflow is enabled)
                if showOverflow && isOverGoal {
                    Circle()
                        .trim(from: 0.0, to: overflowProgress)
                        .stroke(
                            Color.red.opacity(0.8),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                        .animation(.easeOut(duration: 0.9), value: overflowProgress)
                }

                // Center Label
                VStack(spacing: isLargeRing ? 2 : 0) {
                    Text("\(Int(current))")
                        .font(valueFontSize)
                        .foregroundStyle(showOverflow && isOverGoal ? .red : adaptiveTextColor)

                    Text("g")
                        .font(unitFontSize)
                        .foregroundStyle(adaptiveTextColor.opacity(0.7))
                }
            }

            // Macro Name Label
            Text(macroName)
                .font(labelFontSize)
                .fontWeight(.medium)
                .foregroundStyle(adaptiveColor)
        }
    }
}
