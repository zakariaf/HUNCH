# tokens-swift-layout.md — the authoritative Swift

Contents: [1 The file set](#1-the-file-set) · [2 Path → symbol](#2-path--symbol) ·
[3 The files](#3-the-files) · [4 The SwiftPM target](#4-the-swiftpm-target) ·
[5 The adapter](#5-the-adapter) · [6 Enforcement](#6-enforcement) ·
[7 Guide rules this satisfies](#7-guide-rules-this-satisfies)

Everything in §3 typechecks under `swiftc -swift-version 6 -strict-concurrency=complete`, together
with the SwiftUI adapter, on Swift 6.3.3. Paste it as-is.

---

## 1. The file set

```
HunchCore/Sources/Tokens/
├── RGB8.swift            struct RGB8            — the colour type, luminance, contrast
├── Prim.swift            enum Prim              — L0. Every hex in the app.
├── RenderEnv.swift       struct RenderEnv       — the seven axes and the derived predicates
├── Palette.swift         struct Palette         — L1 colour, plus AccentColor / HueColor
├── StrokeWeight.swift    struct StrokeWeight    — L1 weight and THE resolution order
├── Space.swift           enum Space             — L1 length, radius, opacity
├── TypeRole.swift        struct TypeRole        — L1 type
├── Motion.swift          enum Dur, enum Easing  — L1 time
└── C.swift               enum C                 — L2, one namespace per component
```

**Three deviations from `skill-plan.md` M1's file list, each with a reason.**

- `Type.swift` → **`TypeRole.swift`.** `enum Type` is legal Swift and unreadable: it collides
  visually with metatype syntax (`Foo.Type`) at every signature. The *token path* stays `type.*`
  because §13.4 and the scope document both call the category `type`; only the symbol changes, and
  §2's table records the one place path and symbol differ.
- `Theme.swift` → **`Palette.swift`.** `RenderEnv.Theme` is the three-case enum; `Palette` is the
  resolver. One file per top-level type, named for the type (`01 P24`, `03 W11`).
- **`RenderEnv.swift` and `RGB8.swift` are added.** M1 lists seven files and the record needs a
  home; `01 P28` bans the bin file that would otherwise absorb them.

`Space.swift` holds three caseless enums (`Space`, `Radius`, `Opacity`) rather than one type per
file. That is a deliberate `P24` deviation: all three are value-only namespaces of `Double`, none
exceeds 30 lines, and splitting them produces two files whose names carry no more information than
a `// MARK:`. `Motion.swift` holds `Dur` and `Easing` for the same reason.

---

## 2. Path → symbol

The token path is what you write in a design document, a reference file or a comment. The symbol is
what you type in Swift. Every path segment is lowerCamelCase; the symbol upper-cases each namespace
segment and leaves the leaf alone.

| Token path | Swift symbol | Note |
|---|---|---|
| `ground.base`, `ground.raised`, `ground.sunken` | `env.palette.ground.base` … | |
| `surface.cell`, `surface.cellLit` | `env.palette.surface.cell` … | |
| `stroke.primary`, `stroke.secondary`, `stroke.hairline` | `env.palette.stroke.primary` … | plain `RGB8` |
| `accent.brass`, `accent.brassPress`, `accent.cold`, `accent.coldPress` | `env.palette.accent.brass` … | `AccentColor` |
| `hue.amber`, `hue.teal`, `hue.frost`, `hue.rose` | `env.palette.hue.amber` … | `HueColor` |
| `glyph.keyline` | `env.palette.glyphKeyline` | `RGB8?` — `nil` outside light |
| `weight.hairline` … `weight.heavy` | **`env.weight(.body)`** | `StrokeWeight.body` is the *unresolved* token |
| `space.s4` … `space.s64`, `space.marginOuter` … | `Space.s16` … | |
| `radius.glyph`, `radius.chrome`, `radius.sheet` | `Radius.chrome` … | |
| `opacity.halo` … `opacity.impressionFaint` | `Opacity.halo` …, `Opacity.scrim(in: env)` | |
| `type.display` … `type.micro` | **`env.type(.numeral)`** | `TypeRole.numeral` is unresolved |
| `dur.admit` … | `Dur.admit` | `Duration`, never `Double` |
| `ease.settle` … | `Easing.settle` | |
| `c.ramp.cellUnlitInk` | `C.Ramp.cellUnlitInk(in: env)` | L2 |

**The one mismatch:** `type.*` → `TypeRole`. It is recorded here and nowhere else.

---

## 3. The files

```swift
// ─────────────────────────────────────── HunchCore/Sources/Tokens/RGB8.swift ────
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

// ─────────────────────────────────────── HunchCore/Sources/Tokens/Prim.swift ────

/// **L0.** Literals with no meaning. Never referenced from a view, a component or `C`;
/// only `Palette` and the L1 scales may name a `Prim`.
///
/// Naming: `<family><lightness>`, lightness ascending as the colour darkens. The step
/// numbers are ordinal, not perceptual. Trailing comments carry the measured luminance;
/// regenerate them with `scripts/contrast.swift`.
public enum Prim {
    // soot — the dark theme's grounds. Warm near-black, never pure.
    public static let soot950 = RGB8(hex: 0x05_05_04)  // L 0.0015
    public static let soot900 = RGB8(hex: 0x0B_0A_08)  // L 0.0031
    public static let soot850 = RGB8(hex: 0x10_0E_0A)  // L 0.0045
    public static let soot800 = RGB8(hex: 0x15_12_0D)  // L 0.0062
    public static let soot750 = RGB8(hex: 0x1C_18_11)  // L 0.0094

    // paper — the light theme's grounds. Warm laid paper, never white.
    public static let paper50 = RGB8(hex: 0xFD_FB_F6)  // L 0.9653
    public static let paper100 = RGB8(hex: 0xFB_F7_EE)  // L 0.9320
    public static let paper150 = RGB8(hex: 0xF7_F3_EA)  // L 0.8982
    public static let paper200 = RGB8(hex: 0xF4_EF_E4)  // L 0.8657
    public static let paper300 = RGB8(hex: 0xEB_E4_D5)  // L 0.7795

    // bone — the warm ink family, serving foreground in both themes.
    public static let bone100 = RGB8(hex: 0xEF_E3_D0)  // L 0.7784
    public static let bone200 = RGB8(hex: 0xD6_CD_BC)  // L 0.6159
    public static let bone450 = RGB8(hex: 0x6E_66_59)  // L 0.1354
    public static let bone500 = RGB8(hex: 0x6B_61_53)  // L 0.1230
    public static let bone700 = RGB8(hex: 0x3A_34_2B)  // L 0.0353
    public static let bone900 = RGB8(hex: 0x1A_17_12)  // L 0.0088

    // neutral — High Contrast only. Achromatic by construction.
    public static let neutral0 = RGB8(hex: 0xFF_FF_FF)  // L 1.0000
    public static let neutral400 = RGB8(hex: 0xB0_B0_B0)  // L 0.4342
    public static let neutral600 = RGB8(hex: 0x5A_5A_5A)  // L 0.1022
    public static let neutral850 = RGB8(hex: 0x14_14_14)  // L 0.0070
    public static let neutral900 = RGB8(hex: 0x0A_0A_0A)  // L 0.0030
    public static let neutral1000 = RGB8(hex: 0x00_00_00)  // L 0.0000

    // brass — the warm accent. Admit, the Seal, marks, streak.
    public static let brass200 = RGB8(hex: 0xFF_C2_4D)  // L 0.6038
    public static let brass300 = RGB8(hex: 0xC9_94_33)  // L 0.3384
    public static let brass400 = RGB8(hex: 0xC9_92_2F)  // L 0.3318
    public static let brass500 = RGB8(hex: 0x8A_64_20)  // L 0.1462
    public static let brass600 = RGB8(hex: 0x8A_5E_14)  // L 0.1346
    public static let brass800 = RGB8(hex: 0x5E_3F_0C)  // L 0.0596

    // cold — the sharp accent. Reject, strike, counterexample, barred.
    public static let cold200 = RGB8(hex: 0x7F_E9_FF)  // L 0.7001
    public static let cold300 = RGB8(hex: 0x7F_D8_E0)  // L 0.5901
    public static let cold400 = RGB8(hex: 0x4F_B8_CC)  // L 0.4030
    public static let cold500 = RGB8(hex: 0x4E_9A_A2)  // L 0.2734
    public static let cold700 = RGB8(hex: 0x0E_5F_72)  // L 0.0949
    public static let cold800 = RGB8(hex: 0x09_3F_4C)  // L 0.0413

    // Okabe–Ito, verbatim, in every theme. No lightness steps exist because these are
    // never re-lit (§13.2, §2). Source names are the published ones.
    public static let okabeItoAmber = RGB8(hex: 0xE6_9F_00)  // "orange"
    public static let okabeItoTeal = RGB8(hex: 0x00_9E_73)  // "bluish green"
    public static let okabeItoFrost = RGB8(hex: 0x56_B4_E9)  // "sky blue"
    public static let okabeItoRose = RGB8(hex: 0xCC_79_A7)  // "reddish purple"

    /// Canon's Dynamic Type art ceiling: art scales to AX2 and then freezes (§13.11).
    public static let artScaleCeiling = 1.35
    /// Bold Text's stroke multiplier (§13.11).
    public static let boldTextStrokeScale = 1.25
    /// High Contrast's flat stroke offset, in points (§13.11). Added, never multiplied.
    public static let highContrastStrokeOffset = 0.5
}

// ────────────────────────────────── HunchCore/Sources/Tokens/RenderEnv.swift ────

/// The seven axes every token resolves against. Hunch's tokens are not constants:
/// High Contrast rewrites hues, Bold Text scales strokes, Reduce Transparency kills
/// bloom, Dynamic Type scales art. A scheme that models variation as "modes" loses
/// four of these seven.
///
/// Injected, never global (`04 A29`): the composition root builds one and passes it down.
public struct RenderEnv: Hashable, Sendable {
    public enum Theme: String, CaseIterable, Hashable, Sendable, Codable {
        case dark, light, highContrast
    }

    public var theme: Theme
    public var isReduceMotionEnabled: Bool
    public var isReduceTransparencyEnabled: Bool
    public var isBoldTextEnabled: Bool
    public var isDifferentiateWithoutColorEnabled: Bool
    public var isLowPowerModeEnabled: Bool
    /// The system's Dynamic Type multiplier, unclamped. Read `artScale` to draw with it.
    public var typeMultiplier: Double

    public init(
        theme: Theme = .dark,
        isReduceMotionEnabled: Bool = false,
        isReduceTransparencyEnabled: Bool = false,
        isBoldTextEnabled: Bool = false,
        isDifferentiateWithoutColorEnabled: Bool = false,
        isLowPowerModeEnabled: Bool = false,
        typeMultiplier: Double = 1.0
    ) {
        self.theme = theme
        self.isReduceMotionEnabled = isReduceMotionEnabled
        self.isReduceTransparencyEnabled = isReduceTransparencyEnabled
        self.isBoldTextEnabled = isBoldTextEnabled
        self.isDifferentiateWithoutColorEnabled = isDifferentiateWithoutColorEnabled
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.typeMultiplier = typeMultiplier
    }
}

extension RenderEnv {
    /// Dynamic Type scales **art**, never stroke weight, and freezes at AX2 (§13.11).
    /// Weight has its own axis (Bold Text); multiplying it here would compound them.
    public var artScale: Double { min(max(typeMultiplier, 1.0), Prim.artScaleCeiling) }

    public var palette: Palette { Palette(theme: theme) }

    /// The resolved stroke weight, in points. The only resolution order in the app.
    public func weight(_ token: StrokeWeight) -> Double { token.resolved(in: self) }

    /// The resolved type role: Bold Text steps the font weight one notch.
    public func type(_ role: TypeRole) -> TypeRole { role.resolved(in: self) }

    /// Pass B, the widened low-opacity stroke. The `S >= 32` gate is geometry and
    /// belongs to the glyph renderer; this is the environment half only.
    public var isBloomEnabled: Bool {
        !isReduceTransparencyEnabled && theme != .highContrast && !isLowPowerModeEnabled
    }

    /// Pass A, the blurred bed. **Dark only** — a blurred bright mark on a light ground
    /// reads as a printing fault, not as light. The light theme gets depth from the
    /// impression, not from a bloom.
    public var isBloomBedEnabled: Bool { isBloomEnabled && theme == .dark }

    /// §13.6's `amt`.
    public var isShaderEnabled: Bool {
        !isReduceTransparencyEnabled && theme != .highContrast && !isLowPowerModeEnabled
    }

    /// The scanline term. **Dark only** — paper has no scanline.
    public var isScanlineEnabled: Bool { isShaderEnabled && theme == .dark }

    /// §13.6's `t`, frozen at 0 under Reduce Motion: static grain, no shimmer.
    public var isShaderTimeFrozen: Bool { isReduceMotionEnabled }

    /// The depth model. Dark separates panels by a ground step **and** a hairline;
    /// light separates them by an **impression**, because a 1.03–1.10 : 1 ground step is
    /// at or below the visible threshold under glare and is erased by auto-dimming.
    /// Shadows, elevation and `.ultraThinMaterial` remain forbidden in both.
    public var isImpressionDepthEnabled: Bool { theme == .light }
}

// ──────────────────────────────────── HunchCore/Sources/Tokens/Palette.swift ────

/// A colour from the **accent** register. Constructible only inside `Tokens`, so
/// `accent.*` reaching a glyph body, a ramp cell or an index stroke is a compile
/// error rather than a review note (§13.2's hard rule, made structural).
public struct AccentColor: Hashable, Sendable {
    public let rgb: RGB8
    init(_ rgb: RGB8) { self.rgb = rgb }
}

/// A colour from the **hue** register. Constructible only inside `Tokens`, so
/// `hue.*` cannot reach chrome, a rule-tile frame, a tick mark or the Seal.
/// Under High Contrast every member is `stroke.primary` — the one sanctioned
/// crossing, and it lives here rather than at a call site for exactly that reason.
public struct HueColor: Hashable, Sendable {
    public let rgb: RGB8
    init(_ rgb: RGB8) { self.rgb = rgb }
}

/// **L1 colour.** Every value is `theme`-selected; nothing here is multiplied or offset.
public struct Palette: Hashable, Sendable {
    public struct Ground: Hashable, Sendable {
        public let base: RGB8
        public let raised: RGB8
        public let sunken: RGB8
    }

    public struct Surface: Hashable, Sendable {
        public let cell: RGB8
        public let cellLit: RGB8
    }

    public struct Stroke: Hashable, Sendable {
        public let primary: RGB8
        public let secondary: RGB8
        public let hairline: RGB8
    }

    public struct Accent: Hashable, Sendable {
        public let brass: AccentColor
        public let brassPress: AccentColor
        public let cold: AccentColor
        public let coldPress: AccentColor
    }

    public struct Hue: Hashable, Sendable {
        public let amber: HueColor
        public let teal: HueColor
        public let frost: HueColor
        public let rose: HueColor
        /// Rank order 1…4 — the order §13.5 pins to index rotations 0/45/90/135°.
        public var ranked: [HueColor] { [amber, teal, frost, rose] }
    }

    public let theme: RenderEnv.Theme
    public let ground: Ground
    public let surface: Surface
    public let stroke: Stroke
    public let accent: Accent
    public let hue: Hue
    /// **Light theme only.** The `stroke.primary` keyline drawn beneath the hue at
    /// `resolvedBodyWeight + 1.0`, so the silhouette edge is 15.58 : 1 while
    /// Okabe–Ito stays verbatim (§13.2 †). `nil` in dark (worst hue 5.78 : 1, no
    /// keyline needed) and in High Contrast (hue is already `stroke.primary`).
    public let glyphKeyline: RGB8?

    public init(theme: RenderEnv.Theme) {
        self.theme = theme
        switch theme {
        case .dark:
            ground = Ground(base: Prim.soot900, raised: Prim.soot800, sunken: Prim.soot950)
            surface = Surface(cell: Prim.soot850, cellLit: Prim.soot750)
            stroke = Stroke(primary: Prim.bone100, secondary: Prim.bone500, hairline: Prim.bone700)
            accent = Accent(
                brass: AccentColor(Prim.brass400),
                brassPress: AccentColor(Prim.brass500),
                cold: AccentColor(Prim.cold300),
                coldPress: AccentColor(Prim.cold500)
            )
            hue = Hue(
                amber: HueColor(Prim.okabeItoAmber),
                teal: HueColor(Prim.okabeItoTeal),
                frost: HueColor(Prim.okabeItoFrost),
                rose: HueColor(Prim.okabeItoRose)
            )
            glyphKeyline = nil

        case .light:
            ground = Ground(base: Prim.paper200, raised: Prim.paper100, sunken: Prim.paper300)
            surface = Surface(cell: Prim.paper150, cellLit: Prim.paper50)
            stroke = Stroke(primary: Prim.bone900, secondary: Prim.bone450, hairline: Prim.bone200)
            accent = Accent(
                brass: AccentColor(Prim.brass600),
                brassPress: AccentColor(Prim.brass800),
                cold: AccentColor(Prim.cold700),
                coldPress: AccentColor(Prim.cold800)
            )
            hue = Hue(
                amber: HueColor(Prim.okabeItoAmber),
                teal: HueColor(Prim.okabeItoTeal),
                frost: HueColor(Prim.okabeItoFrost),
                rose: HueColor(Prim.okabeItoRose)
            )
            glyphKeyline = Prim.bone900

        case .highContrast:
            ground = Ground(base: Prim.neutral1000, raised: Prim.neutral900, sunken: Prim.neutral1000)
            surface = Surface(cell: Prim.neutral1000, cellLit: Prim.neutral850)
            stroke = Stroke(
                primary: Prim.neutral0, secondary: Prim.neutral400, hairline: Prim.neutral600)
            accent = Accent(
                brass: AccentColor(Prim.brass200),
                brassPress: AccentColor(Prim.brass300),
                cold: AccentColor(Prim.cold200),
                coldPress: AccentColor(Prim.cold400)
            )
            hue = Hue(
                amber: HueColor(Prim.neutral0),
                teal: HueColor(Prim.neutral0),
                frost: HueColor(Prim.neutral0),
                rose: HueColor(Prim.neutral0)
            )
            glyphKeyline = nil
        }
    }
}

// ─────────────────────────────── HunchCore/Sources/Tokens/StrokeWeight.swift ────

/// **L1 weight.** `base` is the value at Large with no accessibility setting on;
/// `respondsToBoldText` travels with the token because §13.11 scopes Bold Text by
/// *token*, not by call site, and the same token must not behave two ways at two sites.
public struct StrokeWeight: Hashable, Sendable {
    public let base: Double
    public let respondsToBoldText: Bool

    public init(base: Double, respondsToBoldText: Bool = true) {
        self.base = base
        self.respondsToBoldText = respondsToBoldText
    }

    /// **The resolution order. Multiply, then offset — never the reverse.**
    ///
    /// `body` with Bold Text and High Contrast both on is `3.0 × 1.25 + 0.5 = 4.25`,
    /// not `(3.0 + 0.5) × 1.25 = 4.375`. §13.11 gives Bold Text a multiplicative
    /// spelling with worked values that must hold (`hairline` 0.5 → 0.625) and High
    /// Contrast a flat `+0.5 pt`; a flat offset that also got multiplied would
    /// silently become `+0.625` and the two settings would stop being independent.
    public func resolved(in env: RenderEnv) -> Double {
        let scaled =
            base * (env.isBoldTextEnabled && respondsToBoldText ? Prim.boldTextStrokeScale : 1)
        return scaled + (env.theme == .highContrast ? Prim.highContrastStrokeOffset : 0)
    }
}

extension StrokeWeight {
    public static let hairline = StrokeWeight(base: 0.5)
    public static let thin = StrokeWeight(base: 1.0)
    public static let bodySm = StrokeWeight(base: 1.5)
    public static let body = StrokeWeight(base: 3.0)
    public static let heavy = StrokeWeight(base: 4.0)
}

// ────────────────────────────────────── HunchCore/Sources/Tokens/Space.swift ────

/// **L1 length, in points.** Never scaled by Dynamic Type: text grows and containers
/// reflow (§13.4, `minimumScaleFactor` 1.0), while the 4 pt grid holds. Art that does
/// scale multiplies by `env.artScale` at the drawing site.
///
/// Steps are named for their value because the scale is a grid, not a semantic ramp;
/// inventing `space.cozy` would assign meaning the GDD never assigned. Semantic
/// spacing lives at L2 (`c.settingsRow.labelInset = Space.s16`).
public enum Space {
    public static let s4 = 4.0
    public static let s8 = 8.0
    public static let s12 = 12.0
    public static let s16 = 16.0
    public static let s20 = 20.0
    public static let s24 = 24.0
    public static let s32 = 32.0
    public static let s44 = 44.0
    public static let s64 = 64.0

    public static let marginOuter = 16.0
    public static let columnContent = 343.0
    public static let targetMin = 44.0
    public static let ruleInset = 16.0
    public static let boundaryAbove = 24.0
    public static let boundaryBelow = 16.0
}

/// **L1 corner radius, in points.**
public enum Radius {
    /// Zero, always. Corner count is the `shape` channel; rounding erodes it (§13.1).
    public static let glyph = 0.0
    public static let chrome = 2.0
    /// The Bench sheet's top corners, and nothing else.
    public static let sheet = 12.0
}

/// **L1 opacity.** No multiplicative axis exists: High Contrast *substitutes* an
/// opacity, it never scales one. Component-scoped opacities live at L2.
public enum Opacity {
    public static let halo = 0.12
    public static let bloomBed = 0.35
    public static let disabled = 0.35
    public static let pressed = 0.70
    public static let scrimFlat = 0.85
    public static let scrimBlurred = 0.60

    /// The light theme's impression ladder — four concentric hairlines that press a
    /// panel into the sheet. Read only when `env.isImpressionDepthEnabled`; the
    /// geometry (weights and insets) belongs to `hunch-chrome-and-meta`.
    public static let impressionOuter = 1.00
    public static let impressionMid = 0.55
    public static let impressionInner = 0.30
    public static let impressionFaint = 0.14

    /// The Bench scrim: 0.6 α over a blur when transparency is allowed, otherwise a
    /// flat 0.85 α `ground` (§13.11).
    public static func scrim(in env: RenderEnv) -> Double {
        env.isReduceTransparencyEnabled ? scrimFlat : scrimBlurred
    }
}

// ─────────────────────────────────── HunchCore/Sources/Tokens/TypeRole.swift ────

/// **L1 type.** Seven roles, §13.4 verbatim. Tracking is stored in **em** and applied
/// as `scaledSize × trackingEm`; fixed-point tracking collapses at AX5.
public struct TypeRole: Hashable, Sendable {
    public enum Face: Hashable, Sendable { case sans, mono }
    public enum Width: Hashable, Sendable { case standard, condensed }

    public enum Weight: Int, Comparable, Hashable, Sendable {
        case regular, medium, semibold, bold

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Bold Text steps one notch and clamps at `bold` (§13.11).
        public var bolder: Weight { Weight(rawValue: rawValue + 1) ?? .bold }
    }

    /// The Dynamic Type style the role declares `relativeTo:` (§13.4).
    public enum TextStyle: Hashable, Sendable {
        case largeTitle, title2, subheadline, body, footnote, caption, caption2
    }

    public let size: Double
    public let weight: Weight
    public let width: Width
    public let trackingEm: Double
    public let face: Face
    public let textStyle: TextStyle
    /// Uppercased through `String.uppercased(with: locale)` — never a display transform
    /// and never the font's small-caps feature.
    public let isUppercased: Bool

    public func resolved(in env: RenderEnv) -> TypeRole {
        guard env.isBoldTextEnabled else { return self }
        return TypeRole(
            size: size, weight: weight.bolder, width: width, trackingEm: trackingEm,
            face: face, textStyle: textStyle, isUppercased: isUppercased)
    }

    /// Tracking in points, for a size already scaled by Dynamic Type.
    public func tracking(atScaledSize scaledSize: Double) -> Double { scaledSize * trackingEm }
}

extension TypeRole {
    public static let display = TypeRole(
        size: 28, weight: .semibold, width: .condensed, trackingEm: 0.06,
        face: .sans, textStyle: .largeTitle, isUppercased: false)
    public static let title = TypeRole(
        size: 20, weight: .semibold, width: .condensed, trackingEm: 0.08,
        face: .sans, textStyle: .title2, isUppercased: false)
    public static let section = TypeRole(
        size: 13, weight: .medium, width: .condensed, trackingEm: 0.14,
        face: .sans, textStyle: .caption, isUppercased: true)
    public static let body = TypeRole(
        size: 17, weight: .regular, width: .standard, trackingEm: 0,
        face: .sans, textStyle: .body, isUppercased: false)
    public static let caption = TypeRole(
        size: 13, weight: .regular, width: .standard, trackingEm: 0.01,
        face: .sans, textStyle: .footnote, isUppercased: false)
    /// Every number, always. SF Mono, `monospacedDigit`.
    public static let numeral = TypeRole(
        size: 15, weight: .regular, width: .standard, trackingEm: 0,
        face: .mono, textStyle: .subheadline, isUppercased: false)
    public static let micro = TypeRole(
        size: 11, weight: .medium, width: .condensed, trackingEm: 0.16,
        face: .sans, textStyle: .caption2, isUppercased: true)
}

// ───────────────────────────────────── HunchCore/Sources/Tokens/Motion.swift ────

/// **L1 duration.** `Duration`, never `Double` — a bare `260` is ambiguous between
/// milliseconds and seconds and both appear in the GDD. The adapter converts once.
public enum Dur {
    public static let tap = Duration.milliseconds(90)
    public static let micro = Duration.milliseconds(120)
    public static let ringAdmit = Duration.milliseconds(200)
    public static let ringReject = Duration.milliseconds(160)
    public static let admit = Duration.milliseconds(260)
    public static let reject = Duration.milliseconds(250)
    public static let crossfade = Duration.milliseconds(220)
    public static let push = Duration.milliseconds(280)
    public static let sheet = Duration.milliseconds(320)
    public static let zoom = Duration.milliseconds(300)
    public static let shared = Duration.milliseconds(340)
    public static let streak = Duration.milliseconds(600)
    public static let drift = Duration.milliseconds(520)
    public static let reveal = Duration.milliseconds(1840)
    public static let revealLost = Duration.milliseconds(1020)
    public static let grainReseed = Duration.milliseconds(125)
    public static let pulse = Duration.milliseconds(90)
    /// Reduce Motion substitutions (§13.7.4). Six, not two: the four below were raw
    /// numbers in canon and are L1 because each is shared by two or more components.
    /// `hunch-motion-and-feedback/references/reduce-motion.md` owns which row uses which.
    public static let reduceMotionReveal = Duration.milliseconds(260)
    public static let reduceMotionRing = Duration.milliseconds(160)
    public static let reduceMotionSwap = Duration.milliseconds(140)
    public static let reduceMotionStrike = Duration.milliseconds(180)
    public static let reduceMotionExpand = Duration.milliseconds(200)
    public static let reduceMotionMorph = Duration.milliseconds(240)
}

/// **L1 easing.** Platform-free; the adapter maps each case to a SwiftUI `Animation`.
public enum Easing: Hashable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring(response: Double, dampingFraction: Double)
}

extension Easing {
    public static let snap = Easing.spring(response: 0.18, dampingFraction: 0.90)
    /// The only overshoot in the app — 8 pt, reveal beat 2. Never on a verdict.
    public static let settle = Easing.spring(response: 0.26, dampingFraction: 0.78)
    public static let dock = Easing.spring(response: 0.30, dampingFraction: 0.85)
    public static let sheet = Easing.spring(response: 0.32, dampingFraction: 0.86)
    public static let zoom = Easing.spring(response: 0.30, dampingFraction: 0.88)
    public static let shared = Easing.spring(response: 0.34, dampingFraction: 0.86)
}

// ────────────────────────────────────────── HunchCore/Sources/Tokens/C.swift ────

/// **L2.** One namespace per row of `DESIGN-SYSTEM-SCOPE.md` §3, owned by that row's
/// skill. L2 may reference L1 and `RenderEnv`; it may never reference `Prim`, and it
/// may never hold a literal that L1 already names.
///
/// The name is one letter deliberately: it appears at every drawing call site and its
/// members are always fully qualified (`C.Ramp.inertInk`), so the letter never stands
/// alone. `DESIGN-SYSTEM-SCOPE.md` §4.1 already fixed the spelling.
///
/// Two worked examples ship here because they belong to the resolution order rather
/// than to a drawing. Everything else is appended by the component skills.
public enum C {
    /// `C.Glyph` and the model type `Glyphs.Glyph` are different modules and L2 is always
    /// written fully qualified, so there is no ambiguity at a call site.
    public enum Glyph {
        /// The silhouette weight. The size regime is a **rule**, not a token.
        public static func bodyStroke(side: Double, in env: RenderEnv) -> Double {
            env.weight(side < 48 ? .bodySm : .body)
        }

        /// The light theme's keyline weight, or `nil` where no keyline is drawn.
        /// `+1.0` is a *geometric relationship* — the keyline must show 0.5 pt on each
        /// side of the hue — so it is derived from the already-resolved weight and is
        /// never itself multiplied or offset.
        public static func keylineStroke(side: Double, in env: RenderEnv) -> Double? {
            guard env.palette.glyphKeyline != nil else { return nil }
            return bodyStroke(side: side, in: env) + 1.0
        }

        /// Pass B widens the resolved stroke ×3 (§13.5). Derived last, like the keyline.
        public static func haloStroke(side: Double, in env: RenderEnv) -> Double {
            bodyStroke(side: side, in: env) * 3
        }
    }

    public enum Ramp {
        /// §13.11 gives an explicit High Contrast value, so this is a **substitution**:
        /// it terminates resolution and is never also offset.
        public static func cellUnlitInk(in env: RenderEnv) -> Double {
            env.theme == .highContrast ? 0.40 : 0.25
        }

        public static let inertInk = 0.30

        /// 1.0 → **2.0** under High Contrast, not 1.0 + 0.5. Another substitution.
        public static func cancelHatchWeight(in env: RenderEnv) -> Double {
            env.theme == .highContrast ? 2.0 : 1.0
        }
    }
}
```

---

## 4. The SwiftPM target

`Tokens` is a **leaf with no dependencies**, which is what keeps it host-testable inside the
10-second `swift test` budget and what lets `check-source-hygiene.sh` exempt exactly one directory.

```swift
// HunchCore/Package.swift — the relevant lines only
.target(name: "Tokens"),                        // no dependencies:, deliberately
.testTarget(name: "TokensTests", dependencies: ["Tokens"]),
```

**It does not depend on `Glyphs`,** even though `Palette.Hue` mirrors `Glyph.Hue`'s four cases. The
mapping `Glyph.Hue → HueColor` is a four-arm `switch` owned by exactly one function, in
`HunchUI/GlyphCanvas.swift`, and `hunch-glyph-renderer` owns it. That is one switch against a
package dependency edge, and the edge is the more expensive of the two.

No `.defaultIsolation(MainActor.self)` on this target (`01 P17`, `05 R7`): every type here is a
`Sendable` value and nothing touches the main actor.

---

## 5. The adapter

The SwiftUI side is about forty lines and is the only code that knows SwiftUI exists: the
`RenderEnvReader` view, `RGB8.color` (with `.sRGB` pinned), `Duration.seconds` and
`Easing.animation(for:)`. All four are written out in **`render-env.md` §4** and
**`durations-and-easing.md` §§1, 3**. They are not repeated here.

---

## 6. Enforcement

### 6.1 The literal ban is a grep, not a test

A source lint cannot be a package test, because source files are not in a test bundle — the same
reason `08-APPLIED-TO-HUNCH.md` §5 makes the play-surface text check and the String Catalog check
shell scripts. So the rule *"no literal hex, no literal pt value, no literal duration in view
code"* is enforced by `Scripts/check-source-hygiene.sh`, which runs as an Xcode run-script phase
**and** in CI before anything boots a simulator.

```bash
# 9. No literal colour, dimension, opacity or duration outside the token module.
#    Owner: hunch-design-tokens. Escape hatch: a `// TOKENS-EXEMPT: <reason>` comment
#    on the line above or beside, matching check 3's convention.
literals='#[0-9A-Fa-f]{6}|Color\(red:|UIColor\(|NSColor\(|\.opacity\([0-9.]|lineWidth:[[:space:]]*[0-9.]'
literals="$literals"'|cornerRadius:[[:space:]]*[0-9.]|\.font\(\.system\(size:|duration:[[:space:]]*[0-9.]'
literals="$literals"'|Duration\.(milli|micro|nano)seconds\(|\.tracking\([0-9.]|\.blur\(radius:[[:space:]]*[0-9.]'
hits=$(
  grep -rnE "$literals" --include='*.swift' App Modules HunchCore/Sources \
    | grep -v '^HunchCore/Sources/Tokens/' \
    | cut -d: -f1,2 \
    | while IFS=: read -r file line; do
        start=$(( line > 1 ? line - 1 : 1 ))
        sed -n "${start},${line}p" "$file" | grep -q 'TOKENS-EXEMPT' || printf '%s:%s\n' "$file" "$line"
      done
)
[ -n "$hits" ] && report 'Literal value outside Tokens/ — name a token (hunch-design-tokens):' "$hits"

# 10. Register laundering — AccentColor and HueColor exist to make this a compile error,
#     and `.rgb` is the one way around them.
hits=$(grep -rnE 'HueColor\(|AccentColor\(' --include='*.swift' App Modules || true)
[ -n "$hits" ] && report 'Minting a register colour outside Tokens/ (§13.2 segregation):' "$hits"
```

Check 10 is nearly free because both initialisers are internal to `Tokens`: outside the module the
code will not compile anyway. The grep exists to catch the day someone makes one `public` "just for
previews".

### 6.2 The arithmetic is a test

`swift test`, no simulator, well inside the 10-second budget. Every value in the resolution matrix
is exact in binary (1.25 = 5/4), so `==` is correct and a tolerance would hide a real error.

```swift
// HunchCore/Tests/TokensTests/TokenArithmeticTests.swift
import Testing

@testable import Tokens

@Suite("Token arithmetic")
struct TokenArithmeticTests {

    // MARK: the resolution order

    @Test func boldTextMultipliesBeforeHighContrastAdds() {
        let both = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        #expect(both.weight(.body) == 4.25)
        #expect(both.weight(.body) != 4.375)
    }

    @Test func weightMatrixIsExactAndMonotone() {
        let rows: [(StrokeWeight, Double, Double, Double, Double)] = [
            (.hairline, 0.5, 0.625, 1.0, 1.125),
            (.thin, 1.0, 1.25, 1.5, 1.75),
            (.bodySm, 1.5, 1.875, 2.0, 2.375),
            (.body, 3.0, 3.75, 3.5, 4.25),
            (.heavy, 4.0, 5.0, 4.5, 5.5),
        ]
        let plain = RenderEnv()
        let bold = RenderEnv(isBoldTextEnabled: true)
        let contrast = RenderEnv(theme: .highContrast)
        let both = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        for (token, p, b, c, x) in rows {
            #expect(token.resolved(in: plain) == p)
            #expect(token.resolved(in: bold) == b)
            #expect(token.resolved(in: contrast) == c)
            #expect(token.resolved(in: both) == x)
        }
        for env in [plain, bold, contrast, both] {
            let ladder = [StrokeWeight.hairline, .thin, .bodySm, .body, .heavy]
                .map { $0.resolved(in: env) }
            #expect(ladder == ladder.sorted())
        }
    }

    @Test func dynamicTypeNeverReachesAStrokeWeight() {
        let ax5 = RenderEnv(typeMultiplier: 3.1)
        #expect(ax5.artScale == 1.35)
        #expect(ax5.weight(.body) == 3.0)
    }

    @Test func derivedValuesComeFromTheResolvedWeight() {
        let boldLight = RenderEnv(theme: .light, isBoldTextEnabled: true)
        #expect(C.Glyph.keylineStroke(side: 96, in: boldLight) == 4.75)   // 3.0 × 1.25 + 1.0
        #expect(C.Glyph.haloStroke(side: 96, in: boldLight) == 11.25)     // 3.75 × 3
        #expect(C.Glyph.keylineStroke(side: 96, in: RenderEnv(theme: .dark)) == nil)
    }

    @Test func highContrastSubstitutionsDoNotAlsoTakeTheOffset() {
        let hc = RenderEnv(theme: .highContrast)
        #expect(C.Ramp.cancelHatchWeight(in: hc) == 2.0)
        #expect(C.Ramp.cellUnlitInk(in: hc) == 0.40)
    }

    // MARK: the palette

    @Test(arguments: RenderEnv.Theme.allCases)
    func statebearingTokensClearTheirFloor(theme: RenderEnv.Theme) {
        let p = Palette(theme: theme)
        let g = p.ground.base
        #expect(p.stroke.primary.contrastRatio(against: g) >= 15.5)
        #expect(p.accent.brass.rgb.contrastRatio(against: g) >= 4.5)
        #expect(p.accent.cold.rgb.contrastRatio(against: g) >= 4.5)
        if theme == .highContrast {
            #expect(p.stroke.secondary.contrastRatio(against: g) >= 9.6)
            #expect(p.stroke.primary.contrastRatio(against: g) == 21.0)
        }
    }

    @Test(arguments: RenderEnv.Theme.allCases)
    func hueCollapsesOnlyUnderHighContrast(theme: RenderEnv.Theme) {
        let p = Palette(theme: theme)
        if theme == .highContrast {
            #expect(p.hue.ranked.allSatisfy { $0.rgb == p.stroke.primary })
            #expect(p.glyphKeyline == nil)
        } else {
            #expect(p.hue.amber.rgb == Prim.okabeItoAmber)
            #expect(p.hue.teal.rgb == Prim.okabeItoTeal)
            #expect(p.hue.frost.rgb == Prim.okabeItoFrost)
            #expect(p.hue.rose.rgb == Prim.okabeItoRose)
        }
    }

    @Test func theSilhouetteIsCarriedInEveryTheme() throws {
        // Dark: the hue itself carries it. Light: the keyline does. HC: hue IS primary.
        let dark = Palette(theme: .dark)
        let worstDark = dark.hue.ranked
            .map { $0.rgb.contrastRatio(against: dark.ground.base) }.min() ?? 0
        #expect(worstDark >= 4.5)

        let light = Palette(theme: .light)
        let keyline = try #require(light.glyphKeyline)
        #expect(keyline.contrastRatio(against: light.ground.base) >= 3.0)
        // …and the hue must still read as a band INSIDE the keyline, which canon
        // never measures. Worst case is teal at 5.22 : 1.
        let worstInside = light.hue.ranked.map { $0.rgb.contrastRatio(against: keyline) }.min() ?? 0
        #expect(worstInside >= 4.5)
    }

    @Test func scrimFollowsReduceTransparency() {
        #expect(Opacity.scrim(in: RenderEnv()) == 0.60)
        #expect(Opacity.scrim(in: RenderEnv(isReduceTransparencyEnabled: true)) == 0.85)
    }

    @Test func bloomBedAndScanlineAreDarkOnly() {
        #expect(RenderEnv(theme: .light).isBloomEnabled)
        #expect(!RenderEnv(theme: .light).isBloomBedEnabled)
        #expect(!RenderEnv(theme: .light).isScanlineEnabled)
        #expect(RenderEnv(theme: .light).isImpressionDepthEnabled)
        #expect(!RenderEnv(theme: .dark).isImpressionDepthEnabled)
    }
}
```

Note `throws` on the last-but-three test: `try #require(_:)` unwraps and stops the test, which is
`06 T11`'s division of labour — `#require` for the test's preconditions, `#expect` for the
assertions you came for.

### 6.3 The third leg

`scripts/check-tokens.swift` closes the loop between the two: it recomputes every ratio stated in
`palette.md`, checks each hex against `Prim.swift`, and checks every canon-marked row against
`GAME_DESIGN.md` §13.2. It is verified to fail — corrupt one ratio and one hex and it reports both
and exits 1.

Run all three from CI in this order: `check-source-hygiene.sh` (cheapest, catches the most),
`check-tokens.swift`, `swift test`.

---

## 7. Guide rules this satisfies

| Rule | How |
|---|---|
| `01 P24` / `03 W11` one top-level type per file, named for it | §1, with the two stated deviations for value-only namespaces |
| `01 P28` banned file names | no `Constants.swift`; `Prim`, `Space`, `C` name what they hold |
| `03 W16` constants in a caseless enum | `Prim`, `Space`, `Radius`, `Opacity`, `Dur`, `C` are all caseless |
| `03 W7` no access level on an extension | every `extension` here marks members, not itself |
| `03 W13` stored properties and designated inits in the primary declaration | `Palette.init(theme:)` is in the primary declaration, so the memberwise init stays internal and nothing outside `Tokens` can mint a `Palette` |
| `03 W29` never `default:` over an enum you own | `Palette.init` switches all three themes; a fourth theme breaks the build, which is the point |
| `03 W18` `let` everywhere | every token is a `let`; `RenderEnv`'s `var`s exist so the app can build one incrementally |
| `05` strict concurrency | every type is a `Sendable` value; no global mutable state, no actor, no escape hatch |
| `02 N9` / `N10` boolean naming | `is…Enabled`, positive, matching `UIAccessibility`'s own spelling |
| `02 N22` nest state types in their owner | `RenderEnv.Theme`, `TypeRole.Weight`, `Palette.Ground` |
| `04 A29` no singleton inside a tested boundary | `RenderEnv` is injected; there is no `.current` |
