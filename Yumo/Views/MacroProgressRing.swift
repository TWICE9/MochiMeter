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
        guard goal > 0 else { return 0.0 }
        return min(current / goal, 1.0)
    }

    private var isOverGoal: Bool {
        current > goal
    }

    // Adaptive text color
    private var adaptiveTextColor: Color {
        colorScheme == .light ? Color("AppTextPrimary") : Color("AppTextPrimary")
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
    
    // Select blob shape based on macro name
    private func blobShape() -> AnyShape {
        switch macroName {
        case "Protein":
            return AnyShape(BlobShape())
        case "Carbs":
            return AnyShape(BlobShape2())
        case "Fat":
            return AnyShape(BlobShape3())
        default:
            return AnyShape(BlobShape())
        }
    }
    
    var body: some View {
        VStack(spacing: isLargeRing ? 10 : 8) {
            ZStack {
                // Mochi Blob Container (Background)
                blobShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: ringSize, height: ringSize)
                    .overlay(
                        blobShape()
                            .stroke(Color.white.opacity(colorScheme == .light ? 0.4 : 0.15), lineWidth: 2)
                    )
                
                // Filled Mochi Blob (Bottom-to-top fill)
                GeometryReader { geometry in
                    let fillHeight = geometry.size.height * progress
                    
                    blobShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.9),
                                    color
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .mask(
                            Rectangle()
                                .frame(height: fillHeight)
                                .offset(y: geometry.size.height - fillHeight)
                        )
                }
                .frame(width: ringSize, height: ringSize)
                
                // Glossy Highlight (mochi shine)
                blobShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 5,
                            endRadius: ringSize * 0.5
                        )
                    )
                    .frame(width: ringSize, height: ringSize)
                    .blendMode(.overlay)
                
                // Overflow indicator (pulsing glow)
                if showOverflow && isOverGoal {
                    blobShape()
                        .stroke(Color.red.opacity(0.6), lineWidth: 3)
                        .frame(width: ringSize + 4, height: ringSize + 4)
                        .scaleEffect(1.05)
                }

                // Center Label
                VStack(spacing: isLargeRing ? 2 : 0) {
                    Text("\(Int(current))")
                        .font(valueFontSize)
                        .foregroundStyle(textColor)
                        .shadow(color: textShadowColor, radius: 2, y: 1)

                    Text("g")
                        .font(unitFontSize)
                        .foregroundStyle(textColor.opacity(0.9))
                        .shadow(color: textShadowColor, radius: 2, y: 1)
                }
            }

            // Macro Name Label
            Text(macroName)
                .font(labelFontSize)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
    
    // Adaptive text color - dark grey in light mode, white in dark mode
    private var textColor: Color {
        if showOverflow && isOverGoal {
            return .red
        }
        // Always use dark text in light mode for readability
        if colorScheme == .light {
            return Color(red: 0.2, green: 0.2, blue: 0.2)
        }
        return .white
    }
    
    private var textShadowColor: Color {
        // Light shadow in light mode, dark shadow in dark mode
        if colorScheme == .light {
            return Color.white.opacity(0.5)
        }
        return Color.black.opacity(0.3)
    }
}

// MARK: - AnyShape Wrapper
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
