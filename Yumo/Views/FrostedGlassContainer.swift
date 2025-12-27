// Views/FrostedGlassContainer.swift

import SwiftUI

struct FrostedGlassContainer<Content: View>: View {
    let content: Content
    private let clipsContent: Bool
    
    private let borderRadius: CGFloat = 20.0
    private let padding: CGFloat = 16.0
    private let borderColor = Color.white.opacity(0.2)
    
    init(clipsContent: Bool = true, @ViewBuilder content: () -> Content) {
        self.clipsContent = clipsContent
        self.content = content()
    }
    
    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: borderRadius)
    }
    
    @ViewBuilder
    var body: some View {
        let base = ZStack {
            containerShape
                .fill(.ultraThinMaterial)
            
            // ⭐️ REMOVED ⭐️
            // The semi-transparent white overlay is gone
            
            // The content
            content
                .padding(padding)
        }
        .contentShape(containerShape)
        
        if clipsContent {
            base
                .clipShape(containerShape)
        } else {
            base
        }
    }
}
