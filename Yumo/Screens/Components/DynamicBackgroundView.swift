import SwiftUI

struct DynamicBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 244/255, green: 245/255, blue: 247/255)
    }

    var body: some View {
        backgroundColor.ignoresSafeArea()
    }
}
