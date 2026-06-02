//
//  BarcodeScannerOverlay.swift
//  Yumo
//
//  Visual overlay components for the barcode scanning mode.
//

import SwiftUI

// MARK: - Barcode Scanner Frame Overlay

struct BarcodeScannerFrameOverlay: View {
    @State private var isAnimating = false
    
    private let frameWidth: CGFloat = 280
    private let frameHeight: CGFloat = 140
    private let cornerLength: CGFloat = 30
    private let lineWidth: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Dimmed background with cutout
            Color.black.opacity(0.4)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: frameWidth, height: frameHeight)
                                .blendMode(.destinationOut)
                        )
                )
                .ignoresSafeArea()
            
            // Scanning Frame with animated line
            ZStack {
                // Animated scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: frameWidth - 20, height: 2)
                    .offset(y: isAnimating ? 50 : -50)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .frame(width: frameWidth, height: frameHeight)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Corner Brackets

struct BarcodeScannerCorners: View {
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    let cornerLength: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Top-left corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .position(x: lineWidth / 2, y: lineWidth / 2)
            
            // Top-right corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .rotationEffect(.degrees(90))
                .position(x: frameWidth - lineWidth / 2, y: lineWidth / 2)
            
            // Bottom-left corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .rotationEffect(.degrees(-90))
                .position(x: lineWidth / 2, y: frameHeight - lineWidth / 2)
            
            // Bottom-right corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .rotationEffect(.degrees(180))
                .position(x: frameWidth - lineWidth / 2, y: frameHeight - lineWidth / 2)
        }
    }
}

// MARK: - Individual Corner Bracket

struct CornerBracket: View {
    let cornerLength: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        Path { path in
            // Horizontal line
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: cornerLength, y: 0))
            
            // Vertical line
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: cornerLength))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}
