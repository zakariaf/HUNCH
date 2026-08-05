# fork.md — the guard tile, and the three ramps inside it

Contents: [1 Geometry](#1-geometry) · [2 The turnout, and why it teaches](#2-the-turnout-and-why-it-teaches) ·
[3 States](#3-states) · [4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) ·
[6 Reduce Motion](#6-reduce-motion) · [7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `ForkView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`. **L2:** `C.Fork`.
The three ramps inside it: `ramp.md` — instances 3, 4 and 5 of seven. The frame:
`rule-tile.md`. Values: `hunch-design-tokens`.

---

## 1. Geometry

A Fork occupies the **whole Bench** and has no coupler (§4.2). On the SE reference the Bench is
y 228–560 with 291 pt rails and the Assay in a 64 pt trailing column, so the tile's interior is
291 × 332 pt.

A vertical stack, leading-aligned, `Space.s8` between bands:

| Band | Height | Content |
|---|---|---|
| **gate dock** | 44 | a ramp, `exactlyOne`, header + four 56 × 44 cells |
| **turnout** | 56 | the switch drawing — one line in, two out |
| **then dock** (lit) | 44 | a full ramp, `multi`, on the branch attribute |
| **else dock** (dim) | 44 | a full ramp, `multi`, on the **same** attribute |

`44 + 8 + 56 + 8 + 44 + 8 + 44 = 212` pt inside 332 — and `212 × 1.35 = 286`, still inside 332, so
the Fork fits at the Dynamic Type ceiling without paging. (The Tally does not; see `tally.md` §1.)

```swift
extension C.Fork {
    public static let dockHeight = 44.0
    public static let turnoutHeight = 56.0
    public static let bandGutter = Space.s8
    /// The two branch strands. `w.body` is the weight PHOSPHOR §1.3 gives the wedge and
    /// the coupler strands, and the turnout is the same family of mark.
    public static let strandWeight = StrokeWeight.body
}
```

**The then and else docks are two independent full ramps on one attribute** — this is the instance
`DESIGN-SYSTEM-SCOPE.md` §2(b) corrects canon on, and the one most often collapsed into a single
control. They share an attribute; they do not share a selection, a header or a drawing.

---

## 2. The turnout, and why it teaches

*"A railway switch: one incoming line splits into an upper lit track and a lower dim track… Lit =
'then', dim = 'else', and the mapping is taught by the tile's own drawing — the gate cell that is
lit routes to the lit track"* (§4.2).

That last clause is a **behaviour, not a decoration**: the incoming line originates at the *x centre
of the gate dock's lit cell* and moves when the selection moves. A player taps a different gate cell,
watches the line slide, and has learned the mapping without a word. Draw the turnout from a fixed
centre and the tile still looks right and teaches nothing.

Construction, in the turnout band of width `w` and height `h`:

1. from `(gateLitCellCentreX, 0)` descend `h/3`;
2. split: the **then** strand curves to the leading edge of the then dock, the **else** strand to
   the leading edge of the else dock, each as a single quadratic with its control point at the split;
3. the then strand and the then dock draw in `stroke.primary`; the else strand and the else dock in
   `stroke.secondary`.

**"Dim" is a colour-register step, not an opacity.** Canon never says how dim, and
`stroke.secondary` is a step canon already measures against every ground (`palette.md`). The else
dock's *cells* keep the ramp's own treatment — admitted cells at full ink in `stroke.secondary`,
unlit cells at `C.Ramp.cellUnlitInk(in:)` plus the diagonal hatch — so both docks read the same way
internally and only the branch differs.

Under **Differentiate Without Colour** the two strands additionally take distinct dash patterns
(then solid, else dashed), because a secondary/primary step is a luminance cue and this setting's
whole job is to add a second non-luminance channel. The dash pattern is the ghost frame's, from
`hunch-shared-marks`, so the vocabulary stays small.

---

## 3. States

| Part | States |
|---|---|
| gate dock | `exactlyOne`; never inert, because one cell is always lit |
| then dock | the ramp states of `ramp.md` §3, including **inert** when its set is empty or full |
| else dock | the same, independently |
| turnout | follows the gate's lit cell; **read-only** in a Codex page or the Inscription |
| tile | the six of `rule-tile.md` §3 |

A Fork bars the Seal when either branch dock is inert (§4.3) — the predicate is `RankSet.isVacuous`
in core, via `SealBar`, and a barred press pulses **the Fork's rail**, which is the whole Bench.

There is no third branch, no nested Fork and no Fork inside a dock: *"the Fork's docks accept ramps
only, so there is no fork-inside-fork"* (§4.4). `MAX_DEPTH = 2` is a structural ceiling, and the
backward fuzzer over 200,000 Bench configurations asserts every reachable configuration parses.

---

## 4. SwiftUI

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

struct ForkView: View {
    let env: RenderEnv
    let fork: RuleTile.Fork          // HunchCore: gate, branchAttribute, then, else
    let metrics: RampView.Metrics
    let isReadOnly: Bool
    let onGateTap: (Int) -> Void
    let onBranchTap: (ForkBranch, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: C.Fork.bandGutter) {
            RampView(
                env: env, attribute: fork.gate.attribute, admitted: fork.gate.lit,
                mode: .exactlyOne, metrics: metrics, isReadOnly: isReadOnly,
                onToggle: onGateTap)
            .accessibilityLabel(Loc.forkGate)

            TurnoutShape(litCellIndex: fork.gate.litIndex, metrics: metrics, branch: .then)
                .stroke(env.palette.stroke.primary.color, lineWidth: env.weight(.body))
                .frame(height: C.Fork.turnoutHeight * env.artScale)
                .overlay {
                    TurnoutShape(
                        litCellIndex: fork.gate.litIndex, metrics: metrics, branch: .`else`
                    )
                    .stroke(env.palette.stroke.secondary.color, style: elseStrandStyle)
                }
                .accessibilityHidden(true)

            branchRamp(.then, admitted: fork.then, ink: env.palette.stroke.primary)
            branchRamp(.`else`, admitted: fork.`else`, ink: env.palette.stroke.secondary)
        }
    }

    private var elseStrandStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: env.weight(.body),
            dash: env.isDifferentiateWithoutColorEnabled ? GhostFrame.dash : [])
    }
}
```

`ForkBranch` is a two-case enum in `HunchCore` with cases `then` and `` `else` ``. Both are Swift
keywords and both need backticks at every use site — a small ongoing tax, and still better than
renaming them to `lit` / `dim` or `otherwise` and losing the match with §4.2's own vocabulary, which
is what the VoiceOver labels and the narrator strings are written against. `TurnoutShape` takes the
lit cell index rather than a point so the geometry is a pure function of state and can be
unit-tested without a view.

The turnout is `.accessibilityHidden(true)`: it carries no information a VoiceOver user cannot get
from the gate's value and the two dock labels, and exposing it would add a stop that announces
nothing.

---

## 5. VoiceOver

§13.10 gives the three docks as containers:

| Element | Traits | Label | Value |
|---|---|---|---|
| gate dock | container | `"Gate"` | `"hue is amber"` |
| then dock | container | `"Then"` | `"pips admits three, four"` |
| else dock | container | `"Else"` | the same shape |

- The gate's value is a **binding**, not a set: exactly one value is lit, so it reads
  `"hue is amber"` rather than `"admits amber"`. The two phrasings are different String Catalog
  entries and using the set phrasing for the gate would make a guard sound like a ramp.
- Cells inside each dock stay `.button` `.isSelected` as everywhere else.
- The Fork contributes to the Bench container's single narrated sentence via `LawNarrator`; it never
  narrates itself, and the 10,000-law parity test is what keeps the narration and the tiles the same
  law.

---

## 6. Reduce Motion

| Normal | `isReduceMotionEnabled` |
|---|---|
| the turnout's origin slides when the gate selection changes, `Dur.micro` | the strands **crossfade** between the two positions over `Dur.micro` — nothing translates |
| a dock cell's lit/unlit crossfade | unchanged |
| barred-Seal rail pulse | rail crossfades to `accent.cold` @ 0.5 α and back over `Dur.reduceMotionExpand` |

The first row matters: the sliding origin is the tile's whole teaching, so it is *substituted*, never
removed — the strand still ends up under the newly lit cell, it just gets there by crossfade
(§13.7.4's rule: replace the animation, keep what it was showing).

---

## 7. High Contrast

- `stroke.secondary` is 9.7 : 1 against ground under High Contrast against `stroke.primary`'s 21.0,
  so the then/else distinction survives — but the margin is narrower than in dark (3.3 vs 15.6). Draw
  the else strand's Differentiate-Without-Colour dash **unconditionally** under High Contrast as
  well, so the branch never rests on a luminance step alone.
- Every stroke takes the flat `+0.5` pt through `env.weight(_:)`; the gate dock's unlit cells go
  through `C.Ramp.cellUnlitInk(in:)` and `C.Ramp.cancelHatchWeight(in:)`, which **substitute** and
  therefore terminate resolution — they are never also offset.
- No `hue.*` appears in a Fork's chrome, so the hue collapse does not touch the tile — but it does
  touch a **`hue` gate dock's cells**, whose four values then differ only by index-stroke rotation.
  That is the case to check first in the snapshot gallery.

---

## 8. Wrong

- **One dock instead of two.** The lit and dim docks are each a full ramp on the same attribute
  (§4.2, scope §2(b)). Collapsing them makes 8,736 guard forms unreachable and G10's forward test
  fails on the first Fork law.
- **A shared selection between the docks.** They are independent sets; a value may be admitted by
  both branches, by neither, or by one.
- **Two attributes.** Both docks are on the *same* attribute; the gate is on its own.
- **A fixed turnout origin.** It must follow the lit gate cell, or the tile stops teaching its own
  mapping and the drawing becomes decoration.
- **An opacity for "dim".** `stroke.secondary` is measured; an invented 0.55 is not, and it will
  fail the light theme where the register step is smaller.
- **Nesting a Fork, or putting a Bridge in a dock.** The docks accept ramps only (§4.4); the fuzzer
  will find anything else.
- **Exposing the turnout to VoiceOver.** It announces nothing and adds a stop to a traversal §13.10
  worked hard to shorten.
- **Letting a Fork share the Bench with a coupler or a second rail.** It is a whole-Bench tile
  (§4.2).
