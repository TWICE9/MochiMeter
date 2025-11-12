// Views/FrostedGlassContainer.swift

import SwiftUI

struct FrostedGlassContainer<Content: View>: View {
    
    let content: Content
    
    private let borderRadius: CGFloat = 20.0
    private let padding: CGFloat = 16.0
    private let borderColor = Color.white.opacity(0.2)
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // The blur effect (now the main background)
            RoundedRectangle(cornerRadius: borderRadius)
                .fill(.ultraThinMaterial)
            
            // ⭐️ REMOVED ⭐️
            // The semi-transparent white overlay is gone
            
            // The content
            content
                .padding(padding)
        }
        .clipShape(RoundedRectangle(cornerRadius: borderRadius))
    }
}
