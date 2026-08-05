# assay-grid.md — the 16 × 16 deck, at six sizes, never bloomed

Contents: [1 Geometry and the six sizes](#1-geometry-and-the-six-sizes) ·
[2 Slice versus projection](#2-slice-versus-projection) · [3 States and overlays](#3-states-and-overlays) ·
[4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `AssayCanvas` in `Modules/Sources/HunchUI/AssayCanvas.swift`. **L2:** `C.Assay`.
The table behind it is core — `LawTable` and `LawTable.row(after:)` in
`HunchCore/Sources/Laws/`. The **cell chrome and overlays of a Codex thumbnail** (fracture notch,
anomaly rim, dashed empty slot) belong to
`hunch-chrome-and-meta/references/extension-thumbnail.md`, which *calls* this grid and never redraws it — that
split is what stops a second 16 × 16 drawing existing.

---

## 1. Geometry and the six sizes

The Assay is the entire deck laid out in canonical `glyphID` order, *"so its geometry becomes
memorable"* (§4.3). One indexing rule, everywhere:

```
glyphID = fill·64 + shape·16 + pips·4 + hue        // §2, stable forever
row     = glyphID / 16                             // cell 0 sits top-leading
column  = glyphID % 16
```

Cell 0 is top-**leading**, and the horizontal order **mirrors under RTL** (§12.8); the row order does
not. The deck order itself never mirrors — it is `glyphID`, not a reading direction.

| Site | Cell | Grid | § |
|---|---|---|---|
| Bench trailing column ("the well") | **4** pt | 64 × 64 | §4.3 |
| expanded inspector | **23** pt | 368 × 368 | §4.3 |
| Codex page | **9.5** pt | 152 × 152 | §11.1 |
| Codex thumbnail | **3.5** pt | 56 × 56 **inside a 60 pt cell** — 2 pt of inset for the thumbnail's hairline frame | §11.2 |
| shelf-plate recents | 2.5 pt | 40 × 40 | §11.2 |
| ECHO pool member | 2.5 pt | 40 × 40 | §8.4 |

Those are the only six. They live in one accessor so a seventh cannot appear by accident:

```swift
extension C.Assay {
    public enum Site: Hashable, Sendable {
        case benchWell, inspector, codexPage, codexThumbnail, shelfRecent, echoPool
    }

    public static func cellSide(_ site: Site) -> Double {
        switch site {
        case .benchWell: 4.0
        case .inspector: 23.0
        case .codexPage: 9.5
        case .codexThumbnail: 3.5
        case .shelfRecent, .echoPool: 2.5
        }
    }

    public static func gridSide(_ site: Site) -> Double { cellSide(site) * 16 }

    /// The hairline lattice is drawn only where it is a lattice rather than a smear:
    /// a 0.5 pt hairline between 8 pt cells is 6 % of the pitch, between 2.5 pt cells 20 %.
    public static func drawsLattice(_ site: Site) -> Bool { cellSide(site) >= 8 }

    /// Below the lattice threshold, separation comes from insetting each lit cell.
    public static func cellInset(_ site: Site) -> Double {
        drawsLattice(site) ? 0 : max(0.25, cellSide(site) * 0.06)
    }

    public static let litInk = 0.92          // PHOSPHOR's `opacity.assayLit`, now owned here
}
```

`env.artScale` multiplies the **well** and the **inspector**; the Codex sizes are pictures on a
scrolling page and hold their size, exactly as the 44 pt Codex glyph thumbnail does (§13.11).

**The Assay is never bloomed — at any size, in any state, in any theme.** §13.5 and PHOSPHOR §2 both
state it, for two independent reasons: its cells are 2.5–23 pt and carry no stroke to widen, so pass
B would raise measured ink coverage and corrupt nothing but the picture; and during the
correct-declaration reveal it floods 256 cells at 1.6 ms/cell on top of the throat and the ribbon
(§6.8), which is the one frame in the app that cannot afford a fourth offscreen layer against the
≤ 0.4 ms/frame shader budget. `env.isBloomEnabled` is **not consulted** here — the Assay does not
ask, it never blooms.

---

## 2. Slice versus projection

Two different pictures with two different jobs, and **they must never be quoted for each other**
(§4.3, §13.10).

| | The live **slice** | The **marginal projection** |
|---|---|---|
| Where | Bench well, inspector, Codex page for a *stateless* law | Codex thumbnail, shelf recents, Codex page for a *contextual* law |
| What a cell means | is glyph *i* admitted **given the pinned `prev`** | over how many of the 256 `prev` values is glyph *i* admitted |
| Ink levels | 2 — lit or dark | **4** — quantised and drawn as `hollow · dotted · striped · solid`, the fill ink-density ladder from §2, reused, monotone, colour-free |
| Source | `LawTable.row(after: pinned)` | `LawTable.marginal()` |
| Lit count | the row count for the pinned `prev` | in general **not** `p × 256` |

The pin defaults to the seed glyph and is scrubbable to any of the 256; scrubbing the ghost
thumbnail morphs the constellation, *"the clearest possible non-verbal statement of what
'contextual' means"* (§4.3). The pin, the scrubber and the band-4 evidence unlock are **view state**
in `AssayCanvas`, not core — putting the pin in `LawTable` would give a pure table a `var`
(`08-APPLIED-TO-HUNCH.md` §2).

---

## 3. States and overlays

| State | When | Drawing |
|---|---|---|
| **live-morphing** | the draft changed | cells switch, staggered per cell — the stagger duration is `hunch-motion-and-feedback/references/reduce-motion.md` §2's live-morph row |
| **all-dark** | the draft is unsatisfiable | every cell dark — instantly and unmistakably, with no message |
| **all-lit** | the draft is a tautology | every cell lit |
| **evidence overlay** | band ≥ 4 only | probed glyphs gain a ring; any cell the draft gets wrong against the ribbon flashes |
| **read-only** | inspector, Codex page, every thumbnail | no pin scrubber, no evidence, no tap |

All-dark and all-lit are also the two states that bar the Seal — *"the draft's extension is
constant"* (§4.3) — and the predicate is core (`SealBar`), shared with the Seal and the rail pulse.

**The evidence overlay unlocks at band 4, not band 1**, because a free consistency check trivialises
the low bands where the reasoning is the game, and from band 4 up nobody can hold a 65,536-entry
pair table in their head (§4.3). The ring is `hunch-shared-marks/references/verdict-ring.md`'s drawing at cell
scale, not a new mark.

**Overlays that are not this component's:** the 2 pt corner fracture notch, the doubled anomaly rim
and the dashed empty slot are drawn by `hunch-chrome-and-meta/references/extension-thumbnail.md` *around* the
grid it asks for (§11.2). Drawing them here would put Codex state into the play surface's renderer.

Tapping the well expands it to the full-screen read-only inspector at 23 pt cells (§4.3), a
`matchedGeometryEffect` zoom from the 64 pt well (§13.7.3).

---

## 4. SwiftUI

**One `Canvas` for all 256 cells, and one accessibility element** — §13.10 exposes the Assay as a
single `.image`, so this is the one place on the Bench where a monolithic `Canvas` is correct. It is
also the only shape that performs: accumulate one `Path` per ink level and fill at most four times,
never 256 fills.

```swift
// Modules/Sources/HunchUI/AssayCanvas.swift
import HunchCore
import SwiftUI

struct AssayCanvas: View {
    let env: RenderEnv
    let site: C.Assay.Site
    let picture: AssayPicture        // .slice(Bitboard256) or .projection([UInt8])
    let evidence: AssayEvidence?     // band >= 4 only; nil elsewhere
    let onInspect: () -> Void
    let onReadByAttribute: () -> Void

    private var cell: Double { C.Assay.cellSide(site) * scale }
    private var scale: Double {
        site == .benchWell || site == .inspector ? env.artScale : 1
    }

    var body: some View {
        Canvas(opaque: false) { context, _ in
            if C.Assay.drawsLattice(site) { drawLattice(&context) }
            // One path per ink level: 1 fill for a slice, at most 4 for a projection.
            for (level, path) in paths() {
                context.fill(path, with: .color(ink(level)))
            }
            if let evidence { draw(evidence, in: &context) }
        }
        .frame(width: cell * 16, height: cell * 16)
        .drawingGroup(opaque: false)          // rasterise; never .blur, never a bloom layer
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits([.isImage, .updatesFrequently])
        .accessibilityLabel(Loc.assay)
        .accessibilityValue(Loc.assayLitCount(picture.litCount, isConditioned: picture.isSlice))
        .accessibilityAction(named: Loc.inspect, onInspect)
        .accessibilityAction(named: Loc.readByAttribute, onReadByAttribute)
    }

    private func rect(forGlyphID id: Int) -> CGRect {
        let inset = C.Assay.cellInset(site) * scale
        return CGRect(
            x: Double(id % 16) * cell + inset,
            y: Double(id / 16) * cell + inset,
            width: cell - 2 * inset,
            height: cell - 2 * inset)
    }
}
```

`.drawingGroup` is a rasterisation hint, not a bloom: it composites the finished grid once. Do not
reach for `.blur(radius:)` or `GraphicsContext.addFilter(.blur)` anywhere in this file — that is the
fourth offscreen layer §1 exists to prevent.

The RTL mirror is free: SwiftUI flips the `Canvas`'s coordinate space with the layout direction, so
`id % 16` produces a leading-to-trailing order in every locale without a conditional. Do not add one.

---

## 5. VoiceOver

§13.10, and this row is subtle enough to be worth reading twice:

| Traits | Label | Value | Actions |
|---|---|---|---|
| `.image`, `.updatesFrequently` | `"Assay"` | the **lit count of the slice on screen** | `"Inspect"`, `"Read by attribute"` |

- Contextual draft: *"Admits 64 of 256 glyphs, with this previous glyph."* Stateless draft:
  *"Admits 64 of 256 glyphs."* **Never the unconditional marginal** — canon makes the live Assay a
  slice pinned to the ghost, and quoting the projection would say 48 where the screen shows 64.
- **"Read by attribute"** is the answer to a 256-cell grid: it speaks the sixteen marginals —
  *"Of glyphs with shape triangle, 12 of 64 admitted"* — as one interruptible announcement. That is
  the non-visual equivalent of reading a constellation's density, it leaks nothing (the Assay shows
  the player's own draft), and it is 20 seconds against an impossible 256 swipes.
- Individual cells are **never** exposed. `children: .ignore` is deliberate.
- `.updatesFrequently` without a rate limit will talk over the verdict announcement; the value is
  re-posted on draft change, not on every morph frame.

---

## 6. Reduce Motion

Three rows of `hunch-motion-and-feedback/references/reduce-motion.md` §2 land on the Assay — the
**live morph** (cells switch *instantly*; the whole grid crossfades once), the **expand to the
inspector** (`matchedGeometryEffect` **removed**, not shortened), and **reveal beat 5**. Read the
durations there.

The live morph is the row that matters for feel: the per-cell stagger is what makes the constellation
look alive, and it is exactly what a Reduce Motion player asked not to see. The *information* — which
cells are lit — is unchanged, which is §13.7.4's rule.

---

## 7. High Contrast

- A lit cell is `stroke.primary` at `C.Assay.litInk`; the lattice is `stroke.hairline`, which is
  **never state-bearing** (§13.2) and sits at 3.04 : 1 under High Contrast. That is acceptable
  precisely because the lattice carries no state — the cells do.
- The four projection ink levels are `hollow · dotted · striped · solid`, a **coverage** ladder, so
  they survive the hue collapse untouched: High Contrast changes no ink level here.
- At the two smallest sites (2.5 and 3.5 pt cells) the lattice is not drawn at all (§1), so High
  Contrast's `+0.5` pt on a hairline cannot swallow the cells. Check the **9.5 pt Codex page** case
  in the snapshot gallery: that is the smallest site that *does* draw a lattice, and 0.5 → 1.0 pt is
  10.5 % of its pitch.

**Differentiate Without Colour** changes nothing: the Assay is monochrome in every theme.

---

## 8. Wrong

- **Blooming it.** Any size, any state, any theme — no. This is the correction
  `DESIGN-SYSTEM-SCOPE.md` §3 calls out explicitly, and the reveal frame is where it costs.
- **Quoting the projection for the slice** in the VoiceOver value, in a tooltip that does not exist,
  or in a test fixture. They are different numbers (§4.3).
- **Restating 3.5 / 4 / 9.5 / 23 / 40** anywhere. `C.Assay.cellSide(_:)` is the only home, and a
  seventh site must be added to the enum, where it is visible.
- **256 fills.** Accumulate one `Path` per ink level. At 4 pt cells inside a live-morphing Bench this
  is the difference between a frame and a stutter.
- **Exposing cells to VoiceOver.** 256 swipes; `"Read by attribute"` exists for this.
- **Putting the pin in `LawTable`.** It gives a pure table a `var` and drags view state into a
  package whose whole value is that it has none.
- **Drawing the fracture notch, anomaly rim or empty-slot dash here.** They belong to the extension
  thumbnail, around this grid.
- **A conditional for RTL.** The layout direction already flips the `Canvas`; a manual mirror flips
  it twice and puts glyph 0 in the wrong corner in Arabic.
- **Shipping the evidence overlay below band 4.** It trivialises bands 1–3, where the reasoning is
  the game.
