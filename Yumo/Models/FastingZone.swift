// Models/FastingZone.swift

import SwiftUI // Needed for Color

// ⭐️ FIX: Removed the .feeding case and set .anabolic as the default start ⭐️
enum FastingZone: CaseIterable {
    case anabolic, catabolic, fatBurning, ketosis, autophagy
    
    /// The hour at which this zone *starts*
    var startHour: Double {
        switch self {
        case .anabolic: 0
        case .catabolic: 4
        case .fatBurning: 12
        case .ketosis: 18
        case .autophagy: 24
        }
    }
    
    var name: String {
        switch self {
        case .anabolic: "Anabolic (0-4h)"
        case .catabolic: "Catabolic (4-12h)"
        case .fatBurning: "Fat Burning (12-18h)"
        case .ketosis: "Ketosis (18-24h)"
        case .autophagy: "Autophagy (24h+)"
        }
    }
    
    var description: String {
        switch self {
        case .anabolic: "Your body is digesting and absorbing nutrients from your last meal."
        case .catabolic: "Your body has finished digesting and is now running on stored fuel (glycogen)."
        case .fatBurning: "Your glycogen stores are running low. Your body is starting to burn fat for fuel."
        case .ketosis: "You are in a metabolic state of ketosis, primarily burning fat for energy."
        case .autophagy: "Cellular cleanup (autophagy) is ramping up, recycling old components."
        }
    }
    
    var color: Color {
        switch self {
        case .anabolic: .blue
        case .catabolic: .cyan
        case .fatBurning: .green
        case .ketosis: .orange
        case .autophagy: .pink
        }
    }
    
    // Helper to get all zones in order, from longest to shortest
    static var allZones: [FastingZone] {
        FastingZone.allCases.sorted { $0.startHour > $1.startHour }
    }
}
