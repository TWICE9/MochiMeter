// Views/FrostedGlassContainer.swift

import SwiftUI

struct FrostedGlassContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let content: Content
    private let clipsContent: Bool
    
    private let borderRadius: CGFloat = 20.0
    private let padding: CGFloat = 16.0
    
    init(clipsContent: Bool = true, @ViewBuilder content: () -> Content) {
        self.clipsContent = clipsContent
        self.content = content()
    }
    
    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: borderRadius)
    }
    
    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color("AppCardBackground"))
        } else {
            return AnyShapeStyle(Color.white)
        }
    }

    @ViewBuilder
    var body: some View {
        let base = ZStack {
            containerShape
                .fill(colorScheme == .dark ? AnyShapeStyle(Color("AppCardBackground")) : AnyShapeStyle(Color.white))

            // The content
            content
                .padding(padding)
        }
        .contentShape(containerShape)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: colorScheme == .dark ? 0 : 6, y: colorScheme == .dark ? 0 : 3)
        // Flatten the card's contents (background fill + shadow + clip +
        // every child layer with its own shape/fill/border/material) into
        // a single offscreen render pass per card. Without this each
        // FrostedGlassContainer was contributing ~30 individual offscreen
        // passes on the GPU, which added up to "Potentially expensive
        // render, 420 offscreen passes" hitches whenever many cards were
        // visible during scroll. Per-card cost: 1 pass instead of ~30.
        .compositingGroup()

        if clipsContent {
            base
                .clipShape(containerShape)
        } else {
            base
        }
    }
}
