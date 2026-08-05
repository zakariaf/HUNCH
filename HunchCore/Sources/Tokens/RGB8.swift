import Foundation

/// An 8-bit-per-channel **sRGB** colour. The only colour representation in `HunchCore`.
/// §13.2's ratios are sRGB relative luminance; the SwiftUI adapter must pin `.sRGB`,
/// because a Display P3 constructor moves every ratio in `palette.md`.
public struct RGB8: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

extension RGB8 {
    /// `RGB8(hex: 0x0B0A08)` — the spelling §13.2 uses, so a row can be read across.
    /// Legal in `Prim.swift` and nowhere else: `check-source-hygiene.sh` check 9 fails
    /// on a hex literal anywhere outside `HunchCore/Sources/Tokens/`.
    public init(hex: UInt32) {
        self.init(
            red: UInt8((hex >> 16) & 0xFF),
            green: UInt8((hex >> 8) & 0xFF),
            blue: UInt8(hex & 0xFF)
        )
    }

    public var hex: UInt32 { UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue) }

    /// WCAG 2.1 relative luminance, sRGB.
    public var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let s = Double(channel) / 255
            return s <= 0.040_45 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.1 contrast ratio, 1.0 … 21.0. Symmetric, so order does not matter.
    public func contrastRatio(against other: RGB8) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
