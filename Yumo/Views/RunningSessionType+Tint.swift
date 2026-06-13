//
//  RunningSessionType+Tint.swift
//  Yumo
//
//  Single source of truth for the running session-type accent colour.
//
//  These are intentionally MUTED / desaturated so the running plan cards read as gentle
//  hints of colour (a sage green for easy, a dusty blue for long, etc.) that sit nicely
//  next to the rest of the app's cards — rather than the saturated system colours
//  (.green/.orange/.red/…) that stood out and looked out of place.
//

import SwiftUI

extension RunningSessionType {
    /// Muted, theme-friendly accent for this session type. Used for the leading icon,
    /// metric chips, and "today" highlights across every running card.
    var tint: Color {
        switch self {
        case .easy, .recovery: return Color(red: 0.45, green: 0.62, blue: 0.48) // sage green
        case .long:            return Color(red: 0.42, green: 0.55, blue: 0.68) // dusty blue
        case .tempo:           return Color(red: 0.80, green: 0.58, blue: 0.38) // muted amber
        case .intervals:       return Color(red: 0.78, green: 0.49, blue: 0.46) // soft clay
        case .race:            return Color(red: 0.58, green: 0.49, blue: 0.66) // muted mauve
        case .cross:           return Color(red: 0.40, green: 0.60, blue: 0.58) // muted teal
        case .rest:            return Color(red: 0.56, green: 0.57, blue: 0.62) // soft slate
        }
    }
}

// Defined on `ShapeStyle where Self == Color` so each resolves BOTH as an explicit
// `Color.runAccent` value AND as the leading-dot shorthand in `.foregroundStyle(.runAccent)`,
// `.fill(.runDone)`, `.tint(.runBlue)`, gradient arrays, etc.
extension ShapeStyle where Self == Color {
    /// Muted brand accent for the running feature — a toned-down stand-in for the old
    /// saturated `.purple` (week badges, dots, borders, calendar icon) so the running
    /// cards read as a gentle hint rather than neon.
    static var runAccent: Color { Color(red: 0.52, green: 0.50, blue: 0.70) }  // soft periwinkle

    /// Muted "completed / positive" green — replaces the saturated `.green` used for
    /// completion checks, done counts, and logged stats.
    static var runDone: Color { Color(red: 0.44, green: 0.62, blue: 0.49) }    // soft sage

    // Muted stand-ins for the other saturated accents scattered through the running
    // feature (stat pills, progress bars, gradients, the rest-day & post-run sheets),
    // so nothing reads as neon next to the rest of the app.
    static var runBlue: Color   { Color(red: 0.42, green: 0.55, blue: 0.68) }  // dusty blue
    static var runOrange: Color { Color(red: 0.80, green: 0.58, blue: 0.38) }  // muted amber
    static var runRed: Color    { Color(red: 0.78, green: 0.49, blue: 0.46) }  // soft clay
    static var runPink: Color   { Color(red: 0.80, green: 0.52, blue: 0.60) }  // muted rose
    static var runTeal: Color   { Color(red: 0.40, green: 0.60, blue: 0.58) }  // muted teal
    static var runYellow: Color { Color(red: 0.82, green: 0.68, blue: 0.40) }  // muted gold
}
