# render-env.md — the seven axes and the resolution order

Contents: [1 The seven axes](#1-the-seven-axes) · [2 The resolution order](#2-the-resolution-order) ·
[3 Derived predicates](#3-derived-predicates) · [4 Wiring it from the app](#4-wiring-it-from-the-app) ·
[5 Testing it](#5-testing-it) · [6 What RenderEnv is not](#6-what-renderenv-is-not)

---

## 1. The seven axes

`RenderEnv` is an **axis, not a layer**. HUNCH's tokens are not constants — High Contrast rewrites
hues, Bold Text scales strokes, Reduce Transparency kills bloom, Dynamic Type scales art — so every
L1 and L2 accessor is a *function* of this record. Any scheme that models variation as "modes"
loses four of the seven.

| Axis | Type | What it changes | Stage |
|---|---|---|---|
| `theme` | `.dark` / `.light` / `.highContrast` | every colour; the depth model; bloom bed; scanline; the `+0.5` stroke offset; the hue → `stroke.primary` substitution | 1 and 3 |
| `isBoldTextEnabled` | `Bool` | stroke weights ×1.25; type weights +1 notch | 2 |
| `isReduceTransparencyEnabled` | `Bool` | bloom off; shader off; scrim 0.60 + blur → 0.85 flat; every material becomes opaque `ground.raised` | 1 |
| `isReduceMotionEnabled` | `Bool` | durations substitute; shader `t` frozen at 0 | 1 |
| `isDifferentiateWithoutColorEnabled` | `Bool` | *no token changes.* Adds geometry: ring gaps double, counterexample rings take distinct dashes | — |
| `isLowPowerModeEnabled` | `Bool` | bloom off; shader off; haptic patterns over 0.4 s suppressed | 1 |
| `typeMultiplier` | `Double` | art lengths, via `artScale`, clamped at 1.35 | outside the chain |

`isDifferentiateWithoutColorEnabled` is in the record even though it moves no value, because the
component skills need it and because a seven-axis record that silently dropped an axis would be the
exact failure this design exists to prevent.

`RenderEnv` is a `Hashable, Sendable` value with defaulted initialiser parameters, and it is
**injected, never global**. The composition root builds one; views receive it. There is no
`RenderEnv.current`, and a `static var` holding one would be both a singleton and a data race.

---

## 2. The resolution order

The GDD never states it. §13.11 gives Bold Text a ×1.25 and High Contrast a +0.5 pt and says both
can be on. This is the ruling.

```
1. SELECT     theme picks the value; High Contrast substitutions land here
2. SCALE      Bold Text:  strokes × 1.25   ·   type weights + 1 notch (clamp at bold)
3. OFFSET     High Contrast: strokes + 0.5 pt, flat
4. DERIVE     geometric relationships from the resolved value: keyline + 1.0, halo × 3
```

In one expression, and this is the whole of it:

```swift
public func resolved(in env: RenderEnv) -> Double {
    let scaled = base * (env.isBoldTextEnabled && respondsToBoldText ? 1.25 : 1)
    return scaled + (env.theme == .highContrast ? 0.5 : 0)
}
```

**`weight.body` with both on is `3.0 × 1.25 + 0.5 = 4.25`.** It is not `(3.0 + 0.5) × 1.25 = 4.375`.

Three reasons, in decreasing order of force:

1. **§13.11's worked values pin the multiplication to the base.** It states `hairline` 0.5 → 0.625
   and `bodySm` 1.5 → 1.875. Both are `base × 1.25` exactly. Adding first would give 1.25 and 2.5.
2. **A flat offset that got multiplied would stop being flat.** §13.11 says High Contrast adds
   "+0.5 pt" — one number, for every weight. Under multiply-last it silently becomes +0.625, and
   the two settings stop being independent: turning Bold Text on would change what High Contrast
   means.
3. **The ladder must stay a ladder.** Both orders happen to preserve monotonicity here, but only
   multiply-first keeps the *ratios* between adjacent weights identical under Bold Text alone, which
   is what makes the scale still read as one scale.

**Substitution beats modification.** Where §13.11 states an explicit High Contrast value, that value
terminates resolution and is never also scaled or offset:

| Substitution | Value | Not |
|---|---|---|
| `hue.*` under High Contrast | `stroke.primary` | a re-lit hue |
| unlit ramp cell ink | 0.40 | 0.25 + anything |
| cancel hatch weight | 2.0 pt | 1.0 + 0.5 = 1.5, or 2.0 + 0.5 = 2.5 |
| index stroke length | `0.409 · S` | `0.273 · S` × anything |

**Dynamic Type is not in the chain.** `env.artScale` = `min(max(typeMultiplier, 1), 1.35)` multiplies
*lengths* at the drawing site — the glyph box `S`, Assay cell size, the Profile's `R0`. It never
multiplies a weight. Weight already has an axis (Bold Text), and Dynamic Type reaches weight exactly
once, through geometry: `S` selects the regime, `S < 48 → weight.bodySm`. Scaling the weight as well
would compound the two and make a Bold Text player at AX2 draw a 5.5 pt stroke on a 1.35×-larger
glyph — heavier twice.

**Stage 4 is not a token.** `keyline = resolved + 1.0` and `halo = resolved × 3` are geometric
relationships: the keyline must show 0.5 pt on each side of the hue, and the halo must be three
times whatever it doubles. They are computed from the resolved value and are never themselves
scaled or offset.

---

## 3. Derived predicates

Read these; never re-derive them at a call site, and never branch on `theme` where a predicate
exists. A predicate is the mechanism that stops eight files disagreeing about what Reduce
Transparency means.

| Predicate | True when | Note |
|---|---|---|
| `artScale` | — | `min(max(typeMultiplier, 1), 1.35)`. Lengths only. |
| `palette` | — | `Palette(theme:)`. The only way to read a colour. |
| `weight(_:)` / `type(_:)` | — | the resolved value. `StrokeWeight.body` alone is unresolved. |
| `isBloomEnabled` | not Reduce Transparency, not High Contrast, not Low Power | pass B, the widened halo. **The `S ≥ 32` gate is geometry** and is applied by the glyph renderer. |
| `isBloomBedEnabled` | `isBloomEnabled` **and** theme is dark | pass A, the blurred region clone — the app's only offscreen layer. Never in light: `light-theme.md` §4. |
| `isShaderEnabled` | not Reduce Transparency, not High Contrast, not Low Power | §13.6's `amt` |
| `isScanlineEnabled` | `isShaderEnabled` **and** theme is dark | the `scan` term only; grain and vignette stay in light |
| `isShaderTimeFrozen` | Reduce Motion | §13.6's `t = 0` |
| `isImpressionDepthEnabled` | theme is light | depth by impression, not by a ground step |

---

## 4. Wiring it from the app

`HunchCore` has no `UIAccessibility` to read, which is the point: the record is data, the reading is
app-layer, and every test constructs the record directly. One reader view builds it once; nothing
below reads a system flag.

```swift
// Modules/Sources/HunchUI/RenderEnvReader.swift
import SwiftUI

@MainActor
struct RenderEnvReader<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.legibilityWeight) private var legibilityWeight
    @ScaledMetric(relativeTo: .body) private var typeUnit: CGFloat = 1

    let preference: ThemePreference
    let isDarkerSystemColorsEnabled: Bool     // UIAccessibility; passed in, not read here
    let isLowPowerModeEnabled: Bool           // ProcessInfo; passed in, not read here
    @ViewBuilder let content: (RenderEnv) -> Content

    var body: some View {
        content(
            RenderEnv(
                theme: preference.theme(
                    colorScheme: colorScheme,
                    isDarkerSystemColorsEnabled: isDarkerSystemColorsEnabled),
                isReduceMotionEnabled: reduceMotion,
                isReduceTransparencyEnabled: reduceTransparency,
                isBoldTextEnabled: legibilityWeight == .bold,
                isDifferentiateWithoutColorEnabled: differentiateWithoutColor,
                isLowPowerModeEnabled: isLowPowerModeEnabled,
                typeMultiplier: Double(typeUnit)
            )
        )
    }
}
```

Four things that are easy to get wrong here:

- **There is no `\.accessibilityBoldText`.** SwiftUI exposes Bold Text as
  `\.legibilityWeight == .bold`. Reaching for `UIAccessibility.isBoldTextEnabled` in a view means
  wiring a notification observer for a value SwiftUI already invalidates on.
- **`@ScaledMetric(relativeTo: .body) var typeUnit = 1` *is* the type multiplier.** It is the only
  way to get the numeric scale factor; `\.dynamicTypeSize` is an ordinal category, not a number.
- **`isDarkerSystemColorsEnabled` and `isLowPowerModeEnabled` are passed in**, from the composition
  root, because neither is in SwiftUI's environment and both need a notification observer
  (`UIAccessibility.darkerSystemColorsStatusDidChangeNotification`,
  `.NSProcessInfoPowerStateDidChange`). Reading them inside the view would give a value that never
  updates.
- **Theme preference beats system state, except that `isDarkerSystemColorsEnabled` forces High
  Contrast only when the player has made no explicit choice** — §13.2. That is why the mapping is a
  method on `ThemePreference` and not an `if` in the view.

The colour adapter is three lines, and `.sRGB` is load-bearing:

```swift
extension RGB8 {
    /// `.sRGB` is not optional: every ratio in `palette.md` is sRGB relative luminance,
    /// and a Display P3 constructor moves all of them with no test noticing.
    var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
extension AccentColor { var color: Color { rgb.color } }
extension HueColor { var color: Color { rgb.color } }
```

---

## 5. Testing it

`RenderEnv` is a value with a defaulted initialiser, so every case is one line and no simulator is
involved — which is how the whole matrix fits inside the 10-second `swift test` budget.

```swift
@Test(arguments: RenderEnv.Theme.allCases)
func hueCollapsesToPrimaryUnderHighContrastOnly(theme: RenderEnv.Theme) {
    let p = Palette(theme: theme)
    if theme == .highContrast {
        #expect(p.hue.amber.rgb == p.stroke.primary)
    } else {
        #expect(p.hue.amber.rgb == Prim.okabeItoAmber)
    }
}
```

The full snapshot matrix — every §3 component × every state × 3 themes × {normal, Bold Text, Reduce
Motion}, plus greyscale — is the DEBUG snapshot gallery, and it belongs to `hunch-swift-testing`.
This skill's tests assert the *arithmetic*: `tokens-swift-layout.md` §6.

---

## 6. What RenderEnv is not

- **Not a place for game state.** Band, mode, phase, probe count and the current law are not
  render environment. If a value changes during a round, it is not here.
- **Not a layer.** It does not sit between L1 and L2; it is the argument both take.
- **Not a cache.** `Palette(theme:)` is a handful of struct copies with no allocation; building one
  per draw is free. A memoised palette is a mutable global waiting to happen.
- **Not the place to add an eighth axis** without a stated reason. Seven is the set §13.11 actually
  gives us, and each one earns its place by moving a value or gating a pass.
