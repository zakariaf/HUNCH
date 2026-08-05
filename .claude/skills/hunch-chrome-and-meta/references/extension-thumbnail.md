# extension-thumbnail.md — the 16 × 16 deck signature

Owning symbol: `CodexFeature/ExtensionThumbnail.swift` → `struct ExtensionThumbnail: View`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row D, *Extension thumbnail*.

Contents: [1 Geometry](#1-geometry) · [2 Ink](#2-ink) · [3 States and overlays](#3-states-and-overlays) ·
[4 VoiceOver](#4-voiceover) · [5 Environment behaviour](#5-environment-behaviour) ·
[6 Implementation](#6-implementation) · [7 Wrong](#7-wrong)

A thumbnail is a law's **extension** — its truth table over all 256 glyphs — drawn as the 16 × 16
deck grid in `glyphID` order (§11.2). It is the same signature the Assay draws, at a smaller cell
size, and it is the app's only *identity* mark: extension is identity (§3.6), so **no two thumbnails
can collide**, and a filling shelf becomes a wall of constellations whose texture is genuinely
readable.

---

## 1. Geometry

Two sizes, one rule.

```
cell = (side − 2 · inset) / 16          inset = 2 pt
```

| Site | Side | Cell | Tappable |
|---|---|---|---|
| `CodexShelfView` grid | **60** | **3.5** | yes — §11.2 |
| `ShelfPlate` recents | 40 | 2.25 | **no** — depictive, inside the plate's own target |
| ECHO pool | 40 | 2.25 | that surface belongs to `hunch-bench-instruments` |

The 2 pt inset is *derived*, not invented: §11.2 fixes the 60 pt thumbnail's cell at 3.5 pt, and
`(60 − 4) / 16 = 3.5` exactly. The same inset gives the hairline frame somewhere to sit at both
sizes.

**The grid.** `CodexShelfView` is 5 columns × 60 pt with 10 pt gutters: `5 · 60 + 4 · 10 = 340` in
375, so 17.5 pt margins (§11.2). Roughly 45 thumbnails per screen, vertical scroll, skeleton dividers
between sub-sections, and a rail scrubber at the trailing 12 pt that snaps to **skeleton sections,
not pixels** — the only way a 2,063-row shelf is navigable. At AX2 and above the grid goes 5 → 2
columns (§13.11).

**Order is canonical and permanent.** `(attrOrdinal, cmpOrdinal, subsetBitmask)` in
`fill → shape → pips → hue` order (§11.2), so a law's slot never moves. That constraint drives §3's
faceting decision.

---

## 2. Ink

The thumbnail is **colour-free by construction**, which is its main virtue: it survives greyscale,
High Contrast and every colourblind case without a substitution.

| Law kind | Cell *i* | Levels |
|---|---|---|
| stateless | glyph *i* admitted? | 2 — lit / unlit |
| contextual (bands 5, 7) | fraction of the 256 `prev` values under which glyph *i* is admitted | 4 — **hollow / dotted / striped / solid** |

The four-level ladder is §2's fill ink-density ladder, reused: monotone, colour-free, and already
learned from the glyph's own `fill` channel. Ink is `stroke.primary` throughout; the grid is
`weight.hairline` in `stroke.hairline` (`assay.grid`'s alias).

**The 40 pt variant quantises to two levels, and that is this skill's ruling.** A 2.25 pt cell is 4.5
device pixels at @2×; a "dotted" cell there is one dot and a "striped" cell one stroke, so the four
levels collapse into three indistinguishable ones and the ladder stops being monotone on screen.
Rendering four levels that read as two is worse than rendering two honestly. Threshold at 0.5. The
justification is site-specific: at 60 pt the thumbnail is an *identifier* and needs its full
resolution; at 40 pt it is a *reminder* on a plate you already tapped through, and identity is
carried by position. Verify it in the DEBUG snapshot gallery — this is exactly the class of claim
§2(c) of the scope document says is true of the maths and unverified of the raster.

**Never bloomed, at any size, in any state.** The Assay and everything drawn as the Assay are
excluded from bloom passes A and B outright (PHOSPHOR §2, §13.5). Widening a dot pattern raises
measured ink coverage and corrupts the density ladder that carries the whole meaning.

---

## 3. States and overlays

| State | Render | § |
|---|---|---|
| **held** | the signature | §11.2 |
| **empty slot** | dashed socket, unlit — on slot-map shelves (bands 1, 3, 8) every law has a permanent socket | §11.2, §11.4 |
| **faceted-out** | dims to `opacity.disabled`, **in place**, and stops responding to touch | §11.2 |

| Overlay | Render |
|---|---|
| fracture | a 2 pt corner notch |
| anomaly page | a doubled rim |

**Faceting dims in place; it never reflows the grid.** §11.2 fixes canonical-key order so *"a law's
slot never moves"*, and that guarantee is what makes the shelf a picture of the law space rather than
a result list. A filter that reflowed the grid would move every slot on every facet change and
destroy the adjacency that makes near-neighbours in extension space sit side by side. Dimming also
keeps the *shape* of what the facet excluded visible, which is information.

**Visible absence is the point.** On slot-map shelves the holes are drawn (§11.4): *"a log shows what
happened, a map shows what is missing."* Do not collapse empty slots out of the grid.

---

## 4. VoiceOver

Each held thumbnail is a `.button`. Its **label is the law's narration** — the `LawNarrator` sentence
from §13.10, using the same String Catalog fragments as the Codex page, so *"a narrated law and a
rendered law are the same law in two media."* It is the only textless identity a non-sighted player
has.

**Narrate lazily.** `accessibilityLabel` takes a closure evaluated when the element is focused, so
narrating one law costs one walk of one AST. Precomputing 2,063 narrations when the grid builds is
the mistake; VoiceOver never asks for more than the focused element.

| Element | Trait | Label | Value |
|---|---|---|---|
| held | `.isButton` | the narration | the find date; "anomaly"; "fractured" |
| empty slot | `.isButton`, `.notEnabled` | "empty slot" | — |
| faceted-out | `.isButton`, `.notEnabled` | the narration | "filtered out" |

§12.9 budgets **3** control labels for `CodexShelfView`, which the narration format string, the
empty-slot label and the scrubber consume exactly. The rail scrubber is `.adjustable`, stepping
skeleton sections — not rows, not pixels — matching what it does visually.

---

## 5. Environment behaviour

| Setting | Effect |
|---|---|
| **Reduce Motion** | a thumbnail is static; there is no per-cell morph. The Assay's per-cell morph belongs to the *live* Assay, not this. Scrolling is standard; the shared-element transition into a page becomes a `Dur.crossfade` crossfade (§13.7.4) |
| **High Contrast** | the grid and the ink both resolve to `palette.md` §1's High Contrast column, and the grid picks up the flat weight offset. No hue is involved, so nothing is substituted |
| **Bold Text** | grid and overlay weights step through `env.weight(_:)`. The cell size does not change |
| **Differentiate Without Color** | no effect. Already colour-free |
| **Dynamic Type** | **fixed at 60 pt and 40 pt.** §13.11: *"the glyph thumbnail is fixed at 44 pt and never scales (it is a picture, not text)"* — the same rule, and the grid answers AX by going 5 → 2 columns instead |
| **RTL** | the grid's reading order mirrors; **cell 0 stays top-leading** and the Assay grid's horizontal order mirrors with it (§12.8) |

---

## 6. Implementation

```swift
// Modules/Sources/CodexFeature/ExtensionThumbnail.swift
struct ExtensionThumbnail: View {
    let table: LawTable                 // HunchCore; the extension, not the AST
    let side: Double                    // C.Thumbnail.grid (60) or C.Thumbnail.recent (40)
    let overlays: Overlays

    @Environment(\.renderEnv) private var env

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let cell = (side - 2 * C.Thumbnail.inset) / 16
            let levels = side >= C.Thumbnail.grid ? 4 : 2      // §2: the 40 pt variant quantises
            for id in 0..<256 {
                let r = CGRect(x: C.Thumbnail.inset + Double(id % 16) * cell,
                               y: C.Thumbnail.inset + Double(id / 16) * cell,
                               width: cell, height: cell)
                ctx.fillDensity(r, table.density(at: id, quantisedTo: levels),
                                ink: env.palette.stroke.primary)
            }
            ctx.strokeGrid(in: size, cells: 16, inset: C.Thumbnail.inset,
                           ink: env.palette.stroke.hairline, lineWidth: env.weight(.hairline))
        }
        .frame(width: side, height: side)
        .overlay(overlays.rim)          // anomaly: doubled rim
        .overlay(overlays.notch)        // fracture: 2 pt corner notch
        .drawingGroup(opaque: false)    // rasterise once per table; NOT a bloom layer
    }
}
```

`rendersAsynchronously: false` matters on a scrolling grid of 45: async rendering hands each canvas
to a background queue and produces visible pop-in on a surface whose whole job is texture.
`.drawingGroup` caches the raster between scroll frames — that is a render-tree optimisation, not an
image asset, and it does not violate the no-assets rule.

---

## 7. Wrong

- **Drawing the live Assay slice as a thumbnail.** The thumbnail is the law's *unconditional marginal
  projection*; the live Assay is a slice pinned to the ghost `prev` (§4.3). PHOSPHOR §3: *"the two
  must not be quoted for each other."* Quoting the projection where the screen shows the slice says
  48 where the player sees 64.
- **Any hue on a thumbnail.** Colour-free by construction, and `hue.*` is forbidden on chrome
  regardless.
- **Bloom on a thumbnail.** §2.
- **Four ink levels at 40 pt.** §2.
- **Reflowing or hiding cells when a facet is applied.** §3.
- **Collapsing empty slots out of a slot-map shelf.** §3.
- **A tappable 40 pt thumbnail.** `shelf-plate.md` §3.
- **Scaling with Dynamic Type**, or with the Codex page's 0.78×.
- **Caching a thumbnail as a `UIImage` or a bundled asset.** The build carries no image assets, and
  the extension is cheap to draw from the table.
- **Precomputing every narration when the grid appears.** §4.
- **A "new", "duplicate" or "×3" badge.** §11.3: a duplicate re-inscribes the existing page and takes
  a re-strike ring on its rim, drawn on the *page*, not the thumbnail.
