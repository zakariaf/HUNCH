# ramp.md — the atom of both UIs

Contents: [1 Seven instances, two reuses](#1-seven-interactive-instances-two-depictive-reuses) ·
[2 Geometry](#2-geometry) · [3 States and select modes](#3-states-and-select-modes) ·
[4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `RampView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`. **L2:** `C.Ramp`.
Colours, weights and opacities: `hunch-design-tokens`. The glyph-fragment inside a cell:
`hunch-glyph-renderer`. The cancel hatch and the inert slash: `hunch-shared-marks/references/cancel-hatch.md`.
The leading 44 pt: `attribute-header.md`.

---

## 1. Seven interactive instances, two depictive reuses

`DESIGN-SYSTEM-SCOPE.md` §2(b) corrects canon here: the Fork's lit and dim docks are **each** a full
ramp on the same attribute, so the Fork contributes three instances, not one. This table is the
enumeration; a call site that is not in it is either a mistake or an edit to this table.

| # | Site | Select mode | Attribute | § |
|---|---|---|---|---|
| 1 | **Dial ramp** — four on screen, one per attribute, canonical `fill → shape → pips → hue` order | `single` | fixed by row | §4.1, §6.2 |
| 2 | **Bench Ramp rule-tile** — a rail tile | `multi` | bound by its header | §4.2 |
| 3 | **Fork gate dock** — the top of the switch | `exactlyOne` | bound by its header | §4.2 |
| 4 | **Fork *then* dock** — the lit track | `multi` | same attribute as the else dock | §4.2 |
| 5 | **Fork *else* dock** — the dim track | `multi` | same attribute as the then dock | §4.2 |
| 6 | **Tally rank ramp** — one, shared by every counted attribute | `multi` | none; it ranges over ranks | §4.2 |
| 7 | **Tally counter dial** — a 5-stop track, 2 stops in parity mode | `multi`, `stops = 5 \| 2` | none; it ranges over counts | §4.2 |

Instance 7 is a ramp by *verb* and by *cell drawing*, not by attribute: same tap-a-cell action, same
cell chrome, same lit/unlit/inert states, a different stop count and no attribute header. It is
counted here so that `TallyView` cannot grow a second, divergent cell drawing — which is the only
reason the count matters at all.

**Two depictive reuses.** These are drawings of a ramp, never interactive, and they must not drift
from the real one:

- the **Codex facet bar's attribute-participation stamp** — "four ramp headers" (§11.2), owned by
  `hunch-chrome-and-meta/references/codex-page.md`, which calls `AttributeHeaderView` and never redraws it;
- the **Profile *Induction* vertex sigil** — "a ramp silhouette" (§11.11 P3), owned by
  `hunch-sigil-drawing/references/profile-vertex-sigils.md`, which must derive its silhouette from
  `C.Ramp`'s proportions rather than eyeballing them.

---

## 2. Geometry

Canon fixes the header width and the cell size. It does **not** fix the gutter inside a Bench rail;
derive it so the ramp fills its rail on both devices instead of pinning a fifth constant.

| Site | Header | Cell | Gutter | Arithmetic |
|---|---|---|---|---|
| Dial, SE 375 pt | 44 pt (45 in the column sum) | 70 × 48 | 6 pt, **between cells only** | `45 + 4 × 70 + 3 × 6 = 343` = `Space.columnContent` (§4.1, §13.3) |
| Dial, Pro Max 440 pt | 52 pt | 82 × 62 | 10 pt | `52 + 4 × 82 + 3 × 10 = 410` in 440 (§6.2) |
| Bench Ramp tile | 44 pt | 56 × 44 | derived | `gutter = (railContent − 44 − 4 × 56) / 4`, floored at `Space.s4`; the rail is 291 pt (§4.2) |
| Fork docks | 44 pt | 56 × 44 | derived, as the tile | the gate dock is the same drawing with `exactlyOne` |
| Tally rank ramp | none | 56 × 44 | derived | headerless; the column of attribute toggles sits above it |
| Codex page, read-only | ×0.78 | ×0.78 | ×0.78 | `C.RuleTile.codexScale` — scale the whole tile, never re-lay it out |

The Dial's header abuts its first cell with no gutter: the header and its four cells are **one
semantic group**, and §12.8 exempts intra-group spacing from the 8 pt inter-target floor for exactly
this reason. Between two ramps the gutter is 8 pt (SE) / 10 pt (Pro Max), which is inter-target.

**Dynamic Type.** Multiply cell and header *lengths* by `env.artScale` (≤ 1.35). At xLarge–xxxLarge
the Dial cell grows 70 × 48 → 84 × 58 and the Dial gutter tightens 6 → 4 pt at accessibility1
(§12.8). Above AX2 nothing shrinks: the Dial's four ramps scroll vertically inside y 236–508 and the
Bench becomes a single-rail pager (§13.11).

New L2 members, added to `C.swift` beside the two that already ship there:

```swift
extension C.Ramp {
    public static let dialCell = C.Size(width: 70, height: 48)        // §4.1 SE
    public static let dialCellLarge = C.Size(width: 82, height: 62)   // §6.2 Pro Max
    public static let benchCell = C.Size(width: 56, height: 44)       // §4.2
    public static let headerWidth = 44.0
    public static let headerWidthLarge = 52.0
    public static let dialGutter = 6.0
    public static let dialGutterLarge = 10.0

    /// Canon fixes the header and the cell, never this. Derived so the ramp fills its rail.
    public static func benchGutter(railContent: Double) -> Double {
        max(Space.s4, (railContent - headerWidth - 4 * benchCell.width) / 4)
    }
}
```

`C.Size` is declared in `rule-tile.md` §1.

---

## 3. States and select modes

**Cell states — four, and each carries geometry before colour.**

| Cell state | Drawing | Token |
|---|---|---|
| **lit** (admitted) | full ink, cell interior steps to `surface.cellLit` | — |
| **unlit** | ink drops **and** a diagonal cancel hatch crosses the cell | `C.Ramp.cellUnlitInk(in:)`, `C.Ramp.cancelHatchWeight(in:)` |
| **dim** | the Fork else dock only: an **admitted** cell drawn in `stroke.secondary` instead of `stroke.primary`, at full opacity and with no hatch — it is admitted *for the else branch*, not rejected | `stroke.secondary` |
| **disabled** | the whole cell at `Opacity.disabled`, no hatch, not focusable | `Opacity.disabled` |

The hatch is what makes the state readable with no colour and no brightness discrimination (§4.2);
an opacity step alone is not a state.

**"dim" is a colour-register step, not a new opacity.** Canon calls the Fork's else track dim (§4.2)
and never says how dim. Rather than mint an opacity nobody can measure, the else dock's admitted
cells draw in `stroke.secondary` — a step canon already measures (15.6 : 1 → 3.3 : 1 in dark,
15.6 → 4.9 in light, 21.0 → 9.7 under High Contrast). Its unlit cells still take
`C.Ramp.cellUnlitInk(in:)` and the hatch, so both docks read the same way internally and only the
branch differs. See `fork.md` §2.

**Ramp states — three, orthogonal to the cells.**

| Ramp state | When | Drawing |
|---|---|---|
| **inert** | `multi` and the set is empty **or** full — 2 of the 16 subsets, leaving 14 usable | whole ramp at `C.Ramp.inertInk` with **one hairline slash** across it |
| **pulsing** | this rail is the offending rail of a barred Seal press | 3 × `Dur.pulse`, `c.seal.railPulse` 0.5 → 1.0; see `seal.md` §3 |
| **read-only** | Codex page, Inscription reveal, a depictive reuse | no hit target, no focus, no press state |

**One inert state, not two.** Empty and vacuous draw identically because nobody should have to learn
the difference (§4.3). The predicate is core, not view: `RankSet.isVacuous` in
`HunchCore/Sources/Bench/RuleTile.swift`, and it is the same predicate `SealBar` uses to decide
whether the Seal is barred. Two implementations of "inert" is how the Seal and the rail end up
disagreeing.

**Select modes.**

| Mode | Rule | Inert possible |
|---|---|---|
| `single` | exactly one lit; tapping another moves the selection | no |
| `multi` | any subset; tapping toggles | yes |
| `exactlyOne` | one lit, tapping another moves it — same rule as `single`, different semantics (a *guard*, not a draft) | no |
| `multi(stops:)` | the counter dial: `stops = 5`, or `2` in parity mode | yes |

`single` and `exactlyOne` behave identically and are kept distinct because the VoiceOver value and
the narration differ, and because collapsing them would let a Dial ramp be dropped into a gate dock.

---

## 4. SwiftUI

One `Button` per cell, because §13.10 makes every cell a `.button` with `.isSelected`. A single
`Canvas` for the whole ramp would collapse five elements into one and take VoiceOver's traits with
it.

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

/// The atom of both UIs (§4.1): one drawing, seven interactive sites (`ramp.md` §1).
struct RampView: View {
    enum SelectMode: Hashable, Sendable {
        case single, multi, exactlyOne
        case stops(Int)
    }

    let env: RenderEnv
    let attribute: Glyph.Attribute?     // nil for the rank ramp and the counter dial
    let admitted: RankSet
    let mode: SelectMode
    let metrics: Metrics
    let isReadOnly: Bool
    let onToggle: (Int) -> Void

    private var isInert: Bool { mode == .multi && admitted.isVacuous }
    private var stopCount: Int { if case .stops(let n) = mode { n } else { 4 } }

    var body: some View {
        HStack(spacing: metrics.gutter) {
            if let attribute {
                AttributeHeaderView(env: env, attribute: attribute, state: .bound)
                    .frame(width: metrics.headerWidth, height: metrics.cell.height)
            }
            ForEach(0..<stopCount, id: \.self) { rank in
                Button { onToggle(rank) } label: {
                    RampCell(env: env, attribute: attribute, rank: rank, state: cellState(rank))
                }
                .buttonStyle(.plain)
                .frame(width: metrics.cell.width, height: metrics.cell.height)
                .contentShape(.rect)
                .disabled(isReadOnly)
                .accessibilityAddTraits(admitted.contains(rank: rank) ? .isSelected : [])
            }
        }
        .opacity(isInert ? C.Ramp.inertInk : 1)
        .overlay { if isInert { CancelMark.slash(env: env) } }   // hunch-shared-marks
        .accessibilityElement(children: .contain)
    }
}
```

`RampCell` is where the per-rank drawing happens: it asks `hunch-glyph-renderer` for the attribute's
own register at that rank — the silhouette for `shape`, the interior texture for `fill`, the contour
nodes for `pips`, the index stroke for `hue` — and draws nothing in the other three registers. The
cell is *a picture of one channel*, which is why no attribute emblem has to be learned (§4.1).

`Metrics` carries `headerWidth`, `cell`, `gutter`, already multiplied by `env.artScale`; build it
with `.dial(env:isLargeDevice:)`, `.benchTile(env:railContent:)` or `.codex(env:)` so a call site
never assembles one by hand.

---

## 5. VoiceOver

§13.10, verbatim in structure:

| Element | Traits | Label | Value |
|---|---|---|---|
| the ramp (container) | container | `"Fill"` — the attribute name; `"Rank"` / `"Count"` for the Tally's two | Dial: the current value. Tile: `"admits triangle, hexagon"` |
| a cell | `.button`, `.isSelected` when lit | the value name — `"striped"`, `"triangle"` | `"selected"` (Dial) / `"admitted"` (tile) |

- The container's value enumerates the **admitted** values in canonical rank order, not the unlit
  ones, and is regenerated from `RankSet` so it cannot disagree with the drawing.
- A **disabled** cell keeps its label and gains `.notEnabled`; it is never removed from the tree,
  because a hole in the ramp is worse than a refusing cell.
- An **inert** ramp announces its state on the container — `"inert, admits nothing"` /
  `"inert, admits every value"` — and this is the only place the two inert causes are distinguished,
  because audio has no drawing to collapse them into.
- The Dial's four ramps are the stops of the **"Attributes"** rotor (§13.10).
- **Never** synthesise the value by concatenating fragments. One localized format string with the
  interpolations, as the glyph label does (§2).

---

## 6. Reduce Motion

The ramp has one animation and one substitution:

| Normal | `isReduceMotionEnabled` |
|---|---|
| a cell's lit/unlit transition crossfades over `Dur.micro` | unchanged — a crossfade is already the substitution |
| barred-Seal rail pulse, 3 × `Dur.pulse` | the rail crossfades to `accent.cold` @ 0.5 α and back over `Dur.reduceMotionExpand` |
| empty-rail hairline pulse | **static** hairline at `C.RuleTile.emptyRailPulse` — see `rule-tile.md` §3 |

Nothing on a ramp translates, scales or rotates in either mode, which is the property §13.12 gate 9
checks by hand.

---

## 7. High Contrast

Substitutions, and they **terminate resolution** — a substituted value is never also multiplied by
Bold Text or offset by the +0.5 pt stroke delta:

- unlit cell ink — `C.Ramp.cellUnlitInk(in: env)` returns the High Contrast value directly;
- cancel hatch weight — `C.Ramp.cancelHatchWeight(in: env)`, **not** the normal weight `+ 0.5`;
- every `hue.*` inside a cell renders as `stroke.primary`, so a `hue` ramp's four cells are told
  apart **only** by index-stroke rotation — and the index stroke lengthens under High Contrast by
  the ratio `hunch-glyph-renderer/references/geometry.md` owns, which is why a `hue` ramp must never shrink its
  cell below the size that keeps four rotations distinct;
- all other stroke weights take the flat `+0.5` pt through `env.weight(_:)`.

Under **Differentiate Without Colour** nothing on the ramp changes: the hatch and the slash are
already non-colour channels, and adding a second cue here would compete with the ring's doubled gap.

---

## 8. Wrong

- **Drawing the ramp as one `Canvas`.** Five accessibility elements collapse into one image and
  `.isSelected` is gone. §4.2's whole accessibility argument rests on every cell being a standard
  element.
- **Treating the Fork's else dock as a partial ramp** — a single cell, a mirror of the then dock, or
  a shared selection. It is a full, independent ramp on the same attribute (§4.2).
- **Two inert drawings**, one for empty and one for full. One state, one drawing (§4.3).
- **Deciding inertness in the view.** `RankSet.isVacuous` is core and is what bars the Seal; a
  second view-side test will disagree with the Seal on some subset and nobody will know which.
- **Restating 0.25 / 0.40 / 0.30 / 1.0 / 2.0 / 0.78.** They are `C.Ramp.cellUnlitInk(in:)`,
  `C.Ramp.inertInk`, `C.Ramp.cancelHatchWeight(in:)`, `C.RuleTile.codexScale`. A literal here is a
  build failure by `check-source-hygiene.sh` check 9 and a drift by design.
- **An opacity-only unlit state.** Without the hatch the ramp fails at 40 % brightness, in daylight,
  and for a player who cannot discriminate brightness — which is the population the hatch exists for.
- **Putting a ramp cell below 44 pt in either axis.** 56 × 44 is the smallest shipped target in the
  app (§12.8); anything smaller breaks the floor for every locale at once.
- **Letting `accent.*` into a cell.** A lit cell steps its *interior* to `surface.cellLit`; it does
  not gain a brass tint. The registers are distinct Swift types, so this will not compile — but
  reaching `.rgb` to get around it is check 10.
- **Adding a fifth cell, a "clear" affordance or a select-all.** 14 usable states is the design; a
  clear button re-introduces the empty/vacuous distinction the single inert state exists to erase.
