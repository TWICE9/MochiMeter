import SwiftUI

enum OnboardingTheme {
    static func baseBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color("AppTextPrimary") : .black
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        primaryText(scheme).opacity(0.8)
    }

    static func mutedText(_ scheme: ColorScheme) -> Color {
        primaryText(scheme).opacity(0.6)
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        primaryText(scheme).opacity(0.3)
    }

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.04)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08)
    }

    static func progressTrack(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }
}
