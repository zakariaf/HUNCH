public import SwiftUI

public import Tokens

extension Color {
    /// The one bridge from a token to SwiftUI.
    ///
    /// **`.sRGB` is pinned and is the whole point of this file.** Every ratio in `palette.md`
    /// and every assertion in `ContrastTests` is sRGB relative luminance. A
    /// `Color(.displayP3, …)` constructor with these same three numbers produces a *different*
    /// colour and moves every one of those ratios, with no test noticing — because the tests
    /// live in `HunchCore`, which has no `Color` at all.
    public nonisolated init(_ rgb: RGB8) {
        self.init(
            .sRGB,
            red: Double(rgb.red) / 255,
            green: Double(rgb.green) / 255,
            blue: Double(rgb.blue) / 255,
            opacity: 1
        )
    }

    /// Register-preserving overloads. `AccentColor` and `HueColor` are distinct types in
    /// `Tokens` precisely so that crossing them will not compile; taking them separately here
    /// keeps that property true at the SwiftUI boundary instead of laundering both through
    /// `RGB8` and losing it.
    nonisolated init(_ accent: AccentColor) { self.init(accent.rgb) }

    nonisolated init(_ hue: HueColor) { self.init(hue.rgb) }
}
