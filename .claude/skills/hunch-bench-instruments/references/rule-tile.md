# rule-tile.md — the abstract base of Ramp, Bridge, Fork and Tally

Contents: [1 C.Size and the L2 shape](#1-csize-and-the-l2-shape) · [2 Geometry](#2-geometry) ·
[3 States](#3-states) · [4 The rail](#4-the-rail) · [5 SwiftUI](#5-swiftui) ·
[6 VoiceOver](#6-voiceover) · [7 Reduce Motion](#7-reduce-motion) ·
[8 High Contrast](#8-high-contrast) · [9 Wrong](#9-wrong)

**Owner:** `RuleTileFrame` and `RailView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`.
**L2:** `C.RuleTile`. The four concrete classes: `ramp.md`, `bridge.md`, `fork.md`, `tally.md`.
The draft itself is core — `BenchLayout` and `RuleTile` in `HunchCore/Sources/Bench/`.

---

## 1. `C.Size` and the L2 shape

Several components need a point size. `CGSize` would pull CoreGraphics into `HunchCore/Tokens`,
which must stay Foundation-only and host-testable inside the 10-second `swift test` budget, so `C`
declares its own two-field value and the SwiftUI adapter converts:

```swift
// HunchCore/Sources/Tokens/C.swift
extension C {
    /// A size in points. Two Doubles rather than `CGSize`, so `Tokens` keeps its
    /// zero-dependency, host-testable manifest (`tokens-swift-layout.md` §4).
    public struct Size: Hashable, Sendable {
        public let width: Double
        public let height: Double
        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }
}

// Modules/Sources/HunchUI/TokenAdapters.swift — beside RGB8.color and Easing.animation(for:)
extension C.Size {
    var cgSize: CGSize { CGSize(width: width, height: height) }
}
```

`C.RuleTile`'s own members:

```swift
extension C.RuleTile {
    /// The Codex page draws the live Bench at 0.78× — 291 pt rails become 227 (§11.1).
    /// Scale the rendered tile; never re-lay it out at a second set of dimensions.
    public static let codexScale = 0.78
    public static let frameRadius = Radius.chrome
    public static let emptyRailPulse = 0.60          // → 1.00; static at 0.60 under Reduce Motion
    public static let emptyRailPulsePeriod = Duration.milliseconds(1600)
    public static let railContent = 291.0            // §4.2, the SE reference rail
}
```

---

## 2. Geometry

The Bench, SE reference (§4.2): rails occupy 291 pt of width in the region y 228–560, with the Assay
in a 64 pt trailing column. A tile fills its rail's content rect; its **height** is the tile class's
business, not this file's.

| Property | Value | Source |
|---|---|---|
| frame weight | `weight.thin` | §13.3 — a heavier line always means state |
| frame radius | `Radius.chrome` | §13.3 |
| interior | `surface.cell`, stepping to `surface.cellLit` where a part is lit | §13.2 |
| scale, live | 1.0 | §4.2 |
| scale, Codex page and Inscription | `C.RuleTile.codexScale` | §11.1 |
| scale, Dynamic Type | `× env.artScale`, ≤ 1.35, then pager | §13.11 |

**Scale is a transform, not a second layout.** `.scaleEffect(C.RuleTile.codexScale, anchor: .topLeading)`
on the composed tile keeps one drawing; laying the tile out again at 0.78 × each constant produces a
second geometry that will diverge on the first edit. The one thing scale must *not* shrink is a hit
target — and on a Codex page nothing is a hit target, which is why 0.78 is safe there and nowhere
else.

---

## 3. States

Six, shared by all four tile classes. Each has a geometry difference; colour is the second copy.

| State | When | Drawing |
|---|---|---|
| **live** | on the Bench, editable | frame `weight.thin` in `stroke.primary`; parts respond to touch |
| **read-only** | Codex page, Inscription, a depictive reuse | identical drawing, no hit targets, no press state, no focus |
| **revealing** | reveal beats 2–4 (§13.7.1) | the tile is in the gathered stack, staggered by position — the stagger and every beat duration are `hunch-motion-and-feedback/references/reveal-beats.md` §3's |
| **burnished** | a Codex page whose `burnished` flag is set (§11.3) | frame and internal strokes step `stroke.primary` → `accent.brass` — the same brass the reveal's registration beat lands on, so the state is already learned |
| **cleared** | a trailing-edge swipe emptied the rail | the tile leaves and the rail returns to **empty**; there is no lingering "cleared" drawing |
| **empty rail** | no tile placed | dashed outline at `weight.hairline`, pulsing `C.RuleTile.emptyRailPulse` → 1.0 on `C.RuleTile.emptyRailPulsePeriod` |

`burnished` is the one state that changes a colour register on chrome, and it is legal because
`accent.brass` is a **verdict** colour used here as an achievement mark, not as a status. It is
still `accent.*` on a rule-tile frame, never on a glyph inside one.

---

## 4. The rail

A rail is a slot, not a component of its own: it is the tile's container, it owns the empty state,
and it owns the clear gesture.

- **Two rails and one coupler** is the Bench's structural ceiling — `MAX_DEPTH = 2`, `MAX_LEAVES = 4`
  (§4.4). A Fork or a Tally occupies the **whole** Bench and there is no coupler (§4.2).
- **Add:** tap a palette stamp; the class goes to the next empty rail (§4.2).
- **Clear:** swipe the rail toward the **trailing** edge. The same gesture clears a suspended round
  from a mode key (§12.4) — reuse over invention.
- **Pulse:** a barred Seal press pulses the offending rail and nothing else (§4.3). Which rail is
  offending is core: `SealBar` in `HunchCore/Sources/Bench/SealBar.swift` states the reason as data,
  and the view reads it. Deciding it in the view is how the Seal and the rail end up disagreeing.

---

## 5. SwiftUI

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

/// The frame every tile class draws inside. It owns the frame, the interior and the
/// six states; it owns nothing about what the tile contains.
struct RuleTileFrame<Content: View>: View {
    enum Presentation: Hashable, Sendable { case live, readOnly, burnished }

    let env: RenderEnv
    let presentation: Presentation
    @ViewBuilder let content: Content

    private var strokeInk: Color {
        (presentation == .burnished ? env.palette.accent.brass.rgb : env.palette.stroke.primary)
            .color
    }

    var body: some View {
        content
            .padding(Space.s8)
            .background(env.palette.surface.cell.color, in: .rect(cornerRadius: Radius.chrome))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.chrome)
                    .strokeBorder(strokeInk, lineWidth: env.weight(.thin))
            }
            .allowsHitTesting(presentation != .readOnly)
    }
}

/// A rail: a tile, or the empty state and its pulse.
struct RailView: View {
    let env: RenderEnv
    let tile: RuleTile?
    let isOffending: Bool          // a barred Seal press named this rail
    let onClear: () -> Void

    var body: some View {
        Group {
            if let tile {
                RuleTileContent(env: env, tile: tile)
                    .gesture(
                        DragGesture(minimumDistance: Space.s24)
                            .onEnded { if $0.translation.width > 0 { onClear() } })
            } else {
                RoundedRectangle(cornerRadius: Radius.chrome)
                    .strokeBorder(
                        env.palette.stroke.hairline.color,
                        style: StrokeStyle(lineWidth: env.weight(.hairline), dash: [6, 4]))
                    .opacity(env.isReduceMotionEnabled ? C.RuleTile.emptyRailPulse : pulse)
            }
        }
        .modifier(RailPulse(env: env, isActive: isOffending))
    }
}
```

Two notes on the sketch. The clear gesture reads `translation.width > 0` because SwiftUI reports
layout-direction-agnostic translation in the view's own space only after the RTL flip is applied to
the container — write `leading`/`trailing` in every comment and let the mirrored layout carry the
sign, never test `left`/`right` (§12.8). And the empty-rail pulse is the **only** looping animation
on the Bench; if a second one appears, one of them is decoration and should be cut. §13.7's budget —
at most one long animation per screen state — is stated once in
`hunch-design-tokens/references/durations-and-easing.md` §2.

---

## 6. VoiceOver

| Element | Traits | Label | Value | Actions |
|---|---|---|---|---|
| rail | container | `"Rail 1"` | that rail's narration, or `"empty"` | `"Clear rail"` |
| tile | container | `"Ramp tile"` / `"Bridge tile"` / `"Fork tile"` / `"Tally tile"` | the tile's own value | — |

- A rail is a stop on the **"Rails"** rotor together with the coupler and the Seal — the rotor cuts
  a full declaration traversal from ~22 gestures to ~16 (§13.10).
- `"Clear rail"` exists as a **custom action** because the clear gesture is a swipe, and a swipe
  means something else under VoiceOver. Every gesture on the Bench needs this treatment or the
  gesture is simply unavailable.
- The whole Bench container carries the `LawNarrator`'s single sentence as its value (§13.10). That
  narrator lives in `HunchCore` and walks the draft AST; a view must never assemble a narration from
  its own tiles, because the parity test walks 10,000 laws through the narrator and would not see it.

---

## 7. Reduce Motion

Four rows of `hunch-motion-and-feedback/references/reduce-motion.md` §2 land on a rule-tile — the
**empty-rail hairline pulse** (which goes static, not fast), the **barred-Seal rail pulse**, the
**reveal's beats 2–4**, and the **Dial ↔ Bench** transition. Read the durations there.

The last one is the row that gets forgotten, and it is not a duration at all: under Reduce Motion the
Bench handle **stops being a drag affordance and becomes a plain button**, so the Bench must be
reachable with no drag anywhere in the path (§13.7.4). A substitution that only shortens the drag
still fails gate 9.

---

## 8. High Contrast

- Frames take the flat `+0.5` pt: `weight.thin` 1.0 → 1.5 through `env.weight(.thin)`.
- `surface.cell` and `surface.cellLit` collapse toward black, so the interior stops carrying the
  lit/unlit difference on its own — which is why every lit state on this surface also has a geometry
  channel (the hatch, the bar, the filled dock).
- **A burnished page under High Contrast keeps `accent.brass`**; it does not become
  `stroke.primary`. High Contrast collapses `hue.*`, never `accent.*` (§13.2), and collapsing the
  burnish would erase the state entirely.

---

## 9. Wrong

- **Re-laying a tile out at 0.78×** instead of scaling the rendered tile. Two layouts diverge on the
  first edit; `C.RuleTile.codexScale` exists so there is one.
- **Scaling a hit target.** 0.78 is safe on a Codex page because nothing there is touchable. Applying
  the same scale to a live tile puts cells under 44 pt.
- **A third rule weight.** Chrome has exactly two: `weight.hairline` for a divider,
  `weight.thin` for a tile frame. A heavier line always means state — the machined bar and the AND
  weld at `weight.heavy` (§13.3).
- **Deciding which rail is offending in the view.** `SealBar` says so, as data, in core.
- **A lingering "cleared" drawing.** Clearing returns the rail to empty; a third visual is a state
  nobody asked for and one more thing to keep in sync.
- **A second looping animation on the Bench.** §13.7's budget is one long animation per screen
  state, and the empty-rail pulse has spent it.
- **Narrating a tile from the view.** The `LawNarrator` in `HunchCore` is the only source, and the
  10,000-law parity test is what makes the narration trustworthy.
- **Adding a third rail, a nested Fork or a coupler beside a Tally.** The Bench and the grammar are
  the same language (§4.4); a third rail expresses something the grammar cannot parse and the
  backward fuzzer will find it.
