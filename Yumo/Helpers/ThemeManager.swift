// Helpers/ThemeManager.swift

import SwiftUI
import Combine

enum MochiTheme: String, CaseIterable, Codable {
    case matcha = "Matcha"
    case strawberry = "Strawberry"
    case taro = "Taro"
    case mango = "Mango"
    case blueberry = "Blueberry"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .matcha: return "🍵"
        case .strawberry: return "🍓"
        case .taro: return "🍠"
        case .mango: return "🥭"
        case .blueberry: return "🫐"
        }
    }
    
    // Light mode primary color
    var primaryColor: Color {
        switch self {
        case .matcha:
            return Color(red: 0.63, green: 0.79, blue: 0.54)
        case .strawberry:
            return Color(red: 1.0, green: 0.55, blue: 0.65)
        case .taro:
            return Color(red: 0.75, green: 0.65, blue: 0.95)
        case .mango:
            return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .blueberry:
            return Color(red: 0.5, green: 0.6, blue: 0.95)
        }
    }
    
    // Light mode secondary color (lighter)
    var secondaryColor: Color {
        switch self {
        case .matcha:
            return Color(red: 0.77, green: 0.88, blue: 0.65)
        case .strawberry:
            return Color(red: 1.0, green: 0.7, blue: 0.75)
        case .taro:
            return Color(red: 0.85, green: 0.75, blue: 1.0)
        case .mango:
            return Color(red: 1.0, green: 0.92, blue: 0.6)
        case .blueberry:
            return Color(red: 0.65, green: 0.75, blue: 1.0)
        }
    }
    
    // Dark mode primary color (slightly lighter/desaturated)
    var darkPrimaryColor: Color {
        switch self {
        case .matcha:
            return Color(red: 0.72, green: 0.83, blue: 0.66)
        case .strawberry:
            return Color(red: 1.0, green: 0.7, blue: 0.75)
        case .taro:
            return Color(red: 0.75, green: 0.65, blue: 0.95)
        case .mango:
            return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .blueberry:
            return Color(red: 0.6, green: 0.7, blue: 1.0)
        }
    }
    
    // Dark mode secondary color
    var darkSecondaryColor: Color {
        switch self {
        case .matcha:
            return Color(red: 0.60, green: 0.75, blue: 0.54)
        case .strawberry:
            return Color(red: 1.0, green: 0.55, blue: 0.65)
        case .taro:
            return Color(red: 0.65, green: 0.55, blue: 0.85)
        case .mango:
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .blueberry:
            return Color(red: 0.5, green: 0.6, blue: 0.95)
        }
    }
    
    // Complementary color (opposite on color wheel) for background orbs
    var complementaryColor: Color {
        switch self {
        case .matcha: // Green -> Pink/Rose
            return Color(red: 1.0, green: 0.6, blue: 0.7)
        case .strawberry: // Pink -> Minty Green
            return Color(red: 0.5, green: 0.9, blue: 0.7)
        case .taro: // Purple -> Yellow/Gold
            return Color(red: 1.0, green: 0.9, blue: 0.5)
        case .mango: // Yellow/Orange -> Periwinkle Blue
            return Color(red: 0.6, green: 0.7, blue: 1.0)
        case .blueberry: // Blue -> Peach/Orange
            return Color(red: 1.0, green: 0.7, blue: 0.5)
        }
    }

    // Gradient for main calorie wheel (adaptive)
    func wheelGradient(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .light {
            return [secondaryColor, primaryColor, secondaryColor]
        } else {
            return [darkSecondaryColor, darkPrimaryColor, darkSecondaryColor]
        }
    }
    
    // Gradient for buttons (adaptive)
    func buttonGradient(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .light {
            return [secondaryColor, primaryColor]
        } else {
            return [darkPrimaryColor, darkSecondaryColor]
        }
    }
    
    // Gradient for when calorie goal is exceeded (linear, replacing the main ring)
    func overageGradient(for colorScheme: ColorScheme) -> [Color] {
        let baseRed = Color(red: 1.0, green: 0.3, blue: 0.3) // Bright red
        let darkRed = Color(red: 0.8, green: 0.2, blue: 0.2) // Darker red for depth
        
        let themeColor = colorScheme == .light ? primaryColor : darkPrimaryColor
        
        return [baseRed, themeColor.opacity(0.5), darkRed]
    }
    
    // Gradient for the overflow ring on HomeScreen (Angular, overlaying the main ring)
    // Starts with the theme's secondary color to blend seamlessly with the 12 o'clock position
    func overflowRingGradient(for colorScheme: ColorScheme) -> [Color] {
        let startColor = colorScheme == .light ? secondaryColor : darkSecondaryColor
        return [startColor, Color.orange, Color.red]
    }
    
    // Legacy non-adaptive properties (deprecated but kept for compatibility)
    var wheelGradient: [Color] {
        [secondaryColor, primaryColor, secondaryColor]
    }
    
    var buttonGradient: [Color] {
        [secondaryColor, primaryColor]
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: MochiTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
            // Also save to App Group for widgets
            UserDefaults(suiteName: "group.com.jesseta.yumo")?.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? MochiTheme.matcha.rawValue
        self.currentTheme = MochiTheme(rawValue: savedTheme) ?? .matcha
        // Sync to App Group on init
        UserDefaults(suiteName: "group.com.jesseta.yumo")?.set(currentTheme.rawValue, forKey: "selectedTheme")
    }
}
