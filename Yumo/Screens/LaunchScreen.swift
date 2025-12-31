
import SwiftUI

struct LaunchScreen: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color("AppBackground")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Static Mochi Logo
                Image(colorScheme == .light ? "LogoHS" : "LogoDarkMode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                
                Spacer()
            }
        }
    }
}

#Preview {
    LaunchScreen()
}
