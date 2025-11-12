// Helpers/ScaleEffectOnPress.swift

import SwiftUI

struct ScaleEffectOnPress: ViewModifier {
    @GestureState private var isPressing = false
    var scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressing ? scale : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressing)
            
            // ⭐️ FIX: Changed from DragGesture to LongPressGesture ⭐️
            // This gesture will not fight with the ScrollView's drag gesture.
            .gesture(
                LongPressGesture(minimumDuration: 0.01)
                    .updating($isPressing) { currentState, gestureState, _ in
                        // As soon as the gesture is recognized (after 0.01s),
                        // this sets isPressing to true.
                        gestureState = currentState
                    }
            )
    }
}
