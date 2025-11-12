// Helpers/DismissKeyboardModifier.swift

import SwiftUI

/// A custom ViewModifier that adds a tap gesture to any view
/// to dismiss the keyboard.
struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            // ⭐️ FIX: Use a simultaneousGesture ⭐️
            // This allows the tap to dismiss the keyboard
            // *without* stealing the tap from buttons underneath.
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            )
    }
}

// Helper extension to make it easier to call
extension View {
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardModifier())
    }
}
