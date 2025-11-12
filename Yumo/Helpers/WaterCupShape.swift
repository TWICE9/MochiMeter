//
//  WaterCupShape.swift
//  Yumo
//
//  Created by Apple on 8/11/2025.
//


// Helpers/WaterCupShape.swift

import SwiftUI

struct WaterCupShape: Shape {
    /// How much narrower the bottom is compared to the top (e.g., 0.55 = 55%)
    let bottomWidthRatio: CGFloat = 0.55
    /// How much the top and bottom are inset from the sides
    let inset: CGFloat = 0.05

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Calculate the coordinates for the four corners
        let topLeft = CGPoint(x: width * inset, y: 0)
        let topRight = CGPoint(x: width * (1 - inset), y: 0)
        
        let bottomWidth = width * bottomWidthRatio
        let bottomInset = (width - bottomWidth) / 2
        
        let bottomLeft = CGPoint(x: bottomInset, y: height)
        let bottomRight = CGPoint(x: width - bottomInset, y: height)

        // Draw the path
        path.move(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.addLine(to: topRight)
        path.addLine(to: topLeft)
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    WaterCupShape()
        .stroke(Color.blue, lineWidth: 3)
        .frame(width: 200, height: 300)
}