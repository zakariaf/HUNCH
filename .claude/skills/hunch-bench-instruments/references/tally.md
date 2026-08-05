# tally.md — the aggregate tile, and the one tile that does not fit at AX1

Contents: [1 Geometry, and the AX1 overflow](#1-geometry-and-the-ax1-overflow) ·
[2 The two modes](#2-the-two-modes) · [3 States](#3-states) · [4 SwiftUI](#4-swiftui) ·
[5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `TallyView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`. **L2:** `C.Tally`.
The rank ramp and the counter dial: `ramp.md` — instances 6 and 7 of seven. The attribute rows:
`attribute-header.md` §5. The frame: `rule-tile.md`.

---

## 1. Geometry, and the AX1 overflow

A Tally occupies the **whole Bench** and has no coupler (§4.2): 291 × 332 pt inside the SE
reference, with the Assay in its 64 pt trailing column.

Four bands, `Space.s8` apart:

| Band | Height at 1.0× | Content |
|---|---|---|
| attribute column | 200 | four attribute headers, 44 × 44, stacked, 8 pt gutters — `4 × 44 + 3 × 8` |
| rank ramp | 44 | headerless ramp, `multi`; the column above plays the header's role |
| counter dial | 44 | 5 stops (2 in parity mode) |
| comb toggle | in the dial band, trailing | 44 × 44, mode switch |

`200 + 8 + 44 + 8 + 44 = 304` pt inside 332. **At `env.artScale = 1.35` that becomes 410 pt and
overflows the 332 pt Bench region by 78 pt** — and §12.8 puts art scale at the 1.35 ceiling from
`accessibility1`, one category *before* §13.11's single-rail pager engages at AX2. So the Tally is
the one tile with a real gap between the two rules.

**Ruling: above `artScale > 1.2` the attribute column packs 2 × 2 instead of 4 × 1.** New stack is
`96 + 8 + 44 + 8 + 44 = 200` pt, and `200 × 1.35 = 270 < 332`. The counted/uncounted state is
per-header and survives the reflow untouched; nothing else moves. Confirm it in the snapshot gallery
before shipping — this is arithmetic, and the gallery is what turns arithmetic into a raster.

The counter dial's stop width is derived, never pinned, because 5 stops must each clear 44 pt:

```swift
extension C.Tally {
    public static let attributeRow = C.Size(width: 44, height: 44)
    public static let bandGutter = Space.s8
    public static let combToggle = C.Size(width: 44, height: 44)
    /// Above this art scale the four attribute rows pack 2 × 2 (`tally.md` §1).
    public static let columnWrapScale = 1.2

    /// 5 stops in count mode, 2 in parity mode. Floored at the hit target.
    public static func counterStopWidth(content: Double, stops: Int, gutter: Double) -> Double {
        max(Space.targetMin, (content - Double(stops - 1) * gutter) / Double(stops))
    }
}
```

At `content = 291`, `stops = 5`, `gutter = 6`: 53.4 pt, comfortably over the 44 pt floor. In parity
mode, 142.5 pt — the two stops are enormous, which is correct: *even* and *odd* are the whole
control.

---

## 2. The two modes

*"The four attribute headers in a column, each toggleable in or out of the counted set (minimum
three), sharing one 4-stop rank ramp; below it a counter dial, a 5-stop track with the same
tap-a-cell verb, meaning 'the number of counted attributes whose rank is in the ramp lies in this
set.' A two-tooth comb toggle switches the tile to parity mode, where the dial collapses to two
cells: even / odd."* (§4.2)

| Mode | Dial | Meaning |
|---|---|---|
| **count** | 5 stops, `0 … 4`, `multi` | how many counted attributes have a rank in the rank ramp |
| **parity** | 2 stops, even / odd, `multi` | the parity of that same number |

The comb toggle is **a two-tooth comb**, drawn — not a switch, not a segmented control, not a label.
Two teeth is the picture of the parity partition (two classes), and it is the only new mark on this
tile. It draws in `stroke.primary` at `weight.body`, in a 24 pt mark box inside its 44 pt hit rect,
matching the wedge's proportion (`wedge.md` §1).

**Minimum three counted attributes.** Below three the aggregate is degenerate, so the third counted
header is `.notEnabled` while keeping its full drawing — the constraint has to be *visible*, not
enforced by a tap that silently does nothing. The predicate lives in `HunchCore`
(`RuleTile.Tally.canUncount(_:)`), not in the view.

---

## 3. States

| Part | States |
|---|---|
| attribute row | **counted** · **uncounted** (ramp's unlit treatment: ink drop **and** the diagonal hatch) · **counted, locked** (`.notEnabled`, at the minimum) |
| rank ramp | the ramp states of `ramp.md` §3, including **inert** when empty or full |
| counter dial | the same, with `stops = 5` or `2`; inert when empty or full |
| comb toggle | **count** · **parity**, `.isSelected` when parity |
| tile | the six of `rule-tile.md` §3 |

A Tally bars the Seal when the rank ramp or the dial is inert, or when fewer than three attributes
are counted (§4.3, via `SealBar`). One predicate, in core, shared with the rail pulse.

---

## 4. SwiftUI

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

struct TallyView: View {
    let env: RenderEnv
    let tally: RuleTile.Tally      // HunchCore: counted, ranks, counts, isParityMode
    let metrics: RampView.Metrics
    let isReadOnly: Bool
    let onToggleCounted: (Glyph.Attribute) -> Void
    let onToggleRank: (Int) -> Void
    let onToggleCount: (Int) -> Void
    let onToggleParity: () -> Void

    private var wrapsColumn: Bool { env.artScale > C.Tally.columnWrapScale }

    var body: some View {
        VStack(alignment: .leading, spacing: C.Tally.bandGutter) {
            attributeColumn
            RampView(
                env: env, attribute: nil, admitted: tally.ranks, mode: .multi,
                metrics: metrics, isReadOnly: isReadOnly, onToggle: onToggleRank)
            .accessibilityLabel(Loc.tallyRank)

            HStack(spacing: C.Tally.bandGutter) {
                RampView(
                    env: env, attribute: nil, admitted: tally.counts,
                    mode: .stops(tally.isParityMode ? 2 : 5),
                    metrics: metrics, isReadOnly: isReadOnly, onToggle: onToggleCount)
                .accessibilityLabel(Loc.tallyCount)

                Button(action: onToggleParity) {
                    CombShape().stroke(
                        env.palette.stroke.primary.color, lineWidth: env.weight(.body))
                }
                .buttonStyle(.plain)
                .frame(
                    width: C.Tally.combToggle.width * env.artScale,
                    height: C.Tally.combToggle.height * env.artScale)
                .disabled(isReadOnly)
                .accessibilityLabel(Loc.parityToggle)
                .accessibilityAddTraits(tally.isParityMode ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var attributeColumn: some View {
        let rows = Glyph.Attribute.allCases            // canonical fill → shape → pips → hue
        if wrapsColumn {
            Grid(horizontalSpacing: C.Tally.bandGutter, verticalSpacing: C.Tally.bandGutter) {
                GridRow { attributeRow(rows[0]); attributeRow(rows[1]) }
                GridRow { attributeRow(rows[2]); attributeRow(rows[3]) }
            }
        } else {
            VStack(alignment: .leading, spacing: C.Tally.bandGutter) {
                ForEach(rows, id: \.self, content: attributeRow)
            }
        }
    }
}
```

`Glyph.Attribute.allCases` is declared in canonical `fill → shape → pips → hue` order in
`HunchCore/Sources/Glyphs/Glyph.swift`, so the column order, the Dial's row order, the VoiceOver
label order and the serialisation order are all one declaration (§2). Never sort it at a call site.

---

## 5. VoiceOver

§13.10:

| Element | Traits | Label | Value |
|---|---|---|---|
| attribute toggle | `.button` `.isSelected` | the attribute name | `"counted"` / `"not counted"` |
| rank ramp | container | `"Rank"` | `"admits three, four"` |
| counter dial | `.adjustable` | `"Count"` | `"admits 0, 2 and 3"` |
| comb toggle | `.button` `.isSelected` | `"Parity"` | `"even and odd"` / off |

- The counter dial is the app's only `.adjustable` control besides the throat: increment and
  decrement move the *focused stop*, and a double-tap toggles it. Without `.adjustable` a five-stop
  track is five swipes to cross.
- A locked counted attribute keeps its label and gains `.notEnabled`, with the reason in its value —
  `"counted, at the minimum"` — because a control that refuses without saying why is worse in audio
  than on screen, where the drawing at least shows the state.
- The Tally contributes to the Bench container's narration through `LawNarrator`; it never narrates
  itself.

---

## 6. Reduce Motion

| Normal | `isReduceMotionEnabled` |
|---|---|
| dial collapses 5 → 2 stops when parity engages, `Dur.micro` | the two dial drawings **crossfade** in place over `Dur.reduceMotionSwap`; no cells slide |
| attribute column reflow 4 × 1 → 2 × 2 at the wrap scale | instant; the reflow follows a system setting change, not a user action, so it is never animated |
| a cell's lit/unlit crossfade | unchanged |

Nothing on a Tally translates, scales or rotates in either mode.

---

## 7. High Contrast

- The attribute column is the densest stack of `attribute-header.md` §3 marks in the app; at the
  flat `+0.5` pt the **shape** header's four concentric silhouettes are the first thing to close up.
  Its ring insets are fractions of `R`, not fixed points, precisely so this case survives.
- Uncounted rows take the ramp's own substitutions — `C.Ramp.cellUnlitInk(in:)` and
  `C.Ramp.cancelHatchWeight(in:)` — which terminate resolution and are never also offset.
- No hue appears in a Tally's chrome; the rank ramp is a ramp over **ranks**, not over an
  attribute's values, so it has no hue cells to collapse — which makes the Tally the one tile whose
  High Contrast rendering is unambiguous by construction.

---

## 8. Wrong

- **Assuming the Tally fits at every text size.** It does not: 304 × 1.35 = 410 pt against a 332 pt
  region. §1's 2 × 2 wrap is the fix, and skipping it clips the counter dial off the bottom of the
  Bench for every `accessibility1` player.
- **Pinning the counter dial's stop width.** Derive it, and floor it at 44 pt — 5 stops across
  291 pt is only 53 pt, so a pinned 60 would overflow and a pinned 40 would break the hit floor.
- **A `Toggle`, a `Picker` or a segmented control for parity.** They are text-shaped system
  components on a surface with zero text. The comb is drawn.
- **Enforcing the minimum-three rule with a silent no-op.** Lock the third header visibly, with
  `.notEnabled` and a reason in the VoiceOver value.
- **Sorting the attribute column.** `Glyph.Attribute.allCases` is canonical order (§2), everywhere
  and forever.
- **A second rank ramp, one per counted attribute.** There is exactly one shared rank ramp (§4.2);
  four would express a law the grammar cannot parse.
- **Animating the reflow.** It follows a system setting, not a tap; animating a settings-driven
  layout change is motion the player did not ask for.
- **Putting a Tally beside a coupler or a second rail.** Whole-Bench tile (§4.2).
