public import SwiftUI

public import Glyphs
public import Tokens

// `nonisolated` throughout: the Modules package takes .defaultIsolation(MainActor.self), but
// GlyphRenderer is deliberately nonisolated so a `swift test` suite with no main actor can
// exercise it (geometry.md §4). These are pure value conversions and belong on no actor.
extension RGB8 {
    /// Shorthand for the `.sRGB`-pinned bridge. Every drawing site says `.color`, and the
    /// pin lives in exactly one place (`RGB8+Color.swift`).
    public nonisolated var color: Color { Color(self) }
}

extension HueColor {
    public nonisolated var color: Color { Color(self) }
}

extension AccentColor {
    public nonisolated var color: Color { Color(self) }
}

extension Palette.Hue {
    /// `Tokens` is a leaf and deliberately does not depend on `Glyphs`, so the mapping from
    /// the model's hue to the palette's lives here — one four-arm switch, which is what §4 of
    /// `geometry.md` traded a package dependency edge for.
    public nonisolated subscript(hue: Glyph.Hue) -> HueColor {
        switch hue {
        case .amber: amber
        case .teal: teal
        case .frost: frost
        case .rose: rose
        }
    }
}
