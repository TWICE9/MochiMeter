//
//  ReadableContentColumn.swift
//  Yumo
//
//  iPad scaling: caps content to a readable, centered column on the large (regular
//  width) canvas while leaving the iPhone (compact width) layout completely unchanged.
//
//  Usage: apply to a screen's root content container, OUTSIDE its existing
//  `.padding(.horizontal, …)`:
//
//      ScrollView {
//          VStack { … }
//              .padding(.horizontal, 20)
//              .readableContentColumn()        // no-op on iPhone, centers+caps on iPad
//      }
//

import SwiftUI

struct ReadableContentColumn: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat
    let clampOnCompact: Bool

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            // iPad / regular width: center content in a readable column.
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if clampOnCompact {
            // iPhone: preserve the previous `.containerRelativeFrame(.horizontal)` behavior
            // (pins content to the scroll container width — e.g. to kill horizontal bounce).
            content
                .containerRelativeFrame(.horizontal)
        } else {
            // iPhone: leave the existing phone layout byte-for-byte unchanged.
            content
        }
    }
}

extension View {
    /// Caps content to a centered, readable column on regular-width (iPad) layouts.
    /// No effect on compact width (iPhone) unless `clampOnCompact` is set.
    /// - Parameters:
    ///   - maxWidth: the column cap on iPad. Defaults to 640 (good for feeds / reports);
    ///     use ~480–560 for forms, sheets, and onboarding.
    ///   - clampOnCompact: when true, applies `.containerRelativeFrame(.horizontal)` on
    ///     iPhone to preserve a pre-existing full-width clamp (e.g. horizontal-bounce fixes).
    func readableContentColumn(_ maxWidth: CGFloat = 640, clampOnCompact: Bool = false) -> some View {
        modifier(ReadableContentColumn(maxWidth: maxWidth, clampOnCompact: clampOnCompact))
    }
}
