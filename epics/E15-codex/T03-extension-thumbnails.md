# T03 — Extension thumbnails

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Extension thumbnails |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. Every cell side goes through `C.Assay.cellSide(_:)`, the ink is `env.palette.stroke.primary`, the frame is `env.weight(.hairline)` in `stroke.hairline`; the skill also owns the rule that this drawing takes **neither** `env.artScale` nor the Codex page's 0.78× — it is a picture, not text. |
| `hunch-chrome-and-meta` | `references/extension-thumbnail.md` is the normative spec: two sizes and one inset rule, the two-versus-four ink levels, the three states, the three overlays, the lazy-narration VoiceOver contract, and the ruling that faceting **dims in place and never reflows the grid**. |
| `hunch-glyph-renderer` | The four ink densities are the glyph's own `fill` ladder — hollow / dotted / striped / solid — reused, and this skill owns that ladder's coverage arithmetic and the measured fact that it is *pitch-invariant as a ratio and not as a raster*. It also owns the standing prohibition this task must honour: **never bloom a thing drawn as the Assay**, because widening a dot pattern raises measured ink coverage and corrupts the density ladder that carries the whole meaning. |

## Objective

At the end of this task a law is a picture: its extension over all 256 glyphs, drawn as the 16 × 16
deck grid in `glyphID` order, at 60 pt in a shelf grid and 40 pt on a plate. Before this task the
Codex can count what the player holds; after it, the player can *recognise* it — and because
extension is identity (§3.6), no two thumbnails can collide, which this task proves over a seeded
corpus rather than asserting.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.2 | *"The thumbnail is the extension, not the syntax."* A 60 × 60 pt cell drawn as the 16 × 16 deck grid at 3.5 pt cells in `glyphID` order — the Assay signature. Contextual laws (bands 5, 7) project: cell *i* carries the fraction of the 256 `prev` values under which glyph *i* is admitted, quantised to four levels drawn as **hollow / dotted / striped / solid** — the fill ink-density ladder from §2, reused, monotone, colour-free. Overlays: a 2 pt corner notch for a fracture, a doubled rim for an anomaly page, an unlit dashed socket for an empty slot |
| `GAME_DESIGN.md` | §3.6 | Extension identity: the extension **is** the canonical form, so two laws with the same extension are one law. This is why collision-freeness is a theorem about the drawing and not a hope |
| `GAME_DESIGN.md` | §4.3 | The live Assay is a **slice** pinned to the ghost `prev`; the thumbnail is the **unconditional marginal projection**. *"The two must not be quoted for each other"* |
| `GAME_DESIGN.md` | §2, §13.5 | The fill ladder's four levels and their nominal coverages; a glyph's `fill` channel is where the player already learned this ramp |
| `GAME_DESIGN.md` | §13.5, §13.11 | The Assay is excluded from bloom **entirely**; the thumbnail is fixed in size and never scales with Dynamic Type |
| `hunch-chrome-and-meta/references/extension-thumbnail.md` | §1–§7 | `cell = (side − 2·inset)/16` with `inset = 2`; the 40 pt variant quantises to **two** levels and why; faceted-out dims in place; visible absence is the point; narrate lazily |
| `hunch-bench-instruments/references/assay-grid.md` | §1, §2, §3 | `C.Assay.cellSide(_:)` is the **only** home of 3.5 / 4 / 9.5 / 23; the slice-versus-projection table with its sources `LawTable.row(after:)` and `LawTable.marginal()`; and the ruling that the thumbnail's overlays are drawn *around* the grid, never inside it |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29, W18 | No `default:` over an owned enum; a `let` context, since `stroke`/`fill` are non-mutating |

## TDD — the test comes first

**Step 1 — write the failing test.** The load-bearing half is core and runs on the host in
microseconds; the drawing half is a small app-side suite.

Create `HunchCore/Tests/LawsTests/ThumbnailSignatureTests.swift`:

```swift
import Testing
import Glyphs                   // Deck
import Laws                     // LawTable, ExtensionSignature
import LawGeneration            // Band, generate
import HunchTestSupport         // Corpora

@Suite("The extension signature — §11.2, §3.6", .tags(.unit, .presubmission))
struct ThumbnailSignatureTests {

    @Test("a stateless law's signature is 256 two-level cells in glyphID order")
    func statelessIsBinaryAndOrdered() {
        let law = Corpora.law(band: .literal, index: 0)
        let table = LawTable(law)
        let signature = ExtensionSignature(table, levels: 4)

        #expect(signature.cells.count == 256)
        #expect(Set(signature.cells).isSubset(of: [0, 3]), "a stateless cell is empty or solid")
        for id in 0..<256 {
            #expect((signature.cells[id] == 3) == table.admits(Deck.glyph(id: id)))
        }
    }

    @Test("a contextual law projects to four monotone levels (bands 5 and 7)",
          arguments: [Band.contextual, .composite])
    func contextualProjectsToFourLevels(_ band: Band) {
        let table = LawTable(Corpora.law(band: band, index: 0))
        let marginal = table.marginal()                        // 256 counts in 0...256
        let signature = ExtensionSignature(table, levels: 4)

        #expect(marginal.count == 256)
        #expect(Set(signature.cells).isSubset(of: [0, 1, 2, 3]))
        // Monotone: a strictly larger marginal never yields a smaller level.
        for a in 0..<256 {
            for b in 0..<256 where marginal[a] < marginal[b] {
                #expect(signature.cells[a] <= signature.cells[b])
            }
        }
    }

    @Test("the 40 pt variant quantises to two levels, thresholded at half")
    func fortyPointQuantisesToTwo() {
        let table = LawTable(Corpora.law(band: .contextual, index: 3))
        let two = ExtensionSignature(table, levels: 2)
        let marginal = table.marginal()
        #expect(Set(two.cells).isSubset(of: [0, 3]))
        for id in 0..<256 {
            #expect((two.cells[id] == 3) == (Double(marginal[id]) / 256.0 >= 0.5))
        }
    }

    @Test("equal extensions give equal signatures — the drawing is a function of the table",
          arguments: Band.allCases)
    func equalTablesGiveEqualSignatures(_ band: Band) {
        for index in 0..<64 {
            let law = Corpora.law(band: band, index: index)
            #expect(ExtensionSignature(LawTable(law), levels: 4)
                    == ExtensionSignature(LawTable(law.renderedNormalForm), levels: 4),
                    "spelling changed the picture")
        }
    }

    /// The gate's item 7. Extension is identity, so distinct laws must draw distinct constellations.
    @Test("distinct extensions give distinct signatures across a seeded corpus", arguments: Band.allCases)
    func signaturesAreCollisionFree(_ band: Band) {
        var byTable: [LawTable: ExtensionSignature] = [:]
        var bySignature: [ExtensionSignature: LawTable] = [:]

        for index in 0..<Corpora.lawsPerBand {
            let table = LawTable(Corpora.law(band: band, index: index))
            let signature = ExtensionSignature(table, levels: 4)
            if let seen = bySignature[signature], seen != table {
                Issue.record("""
                    signature collision at band \(band.rawValue), index \(index) — \
                    two distinct extensions drew the same constellation
                    """)
                return
            }
            if let seen = byTable[table] { #expect(seen == signature) }
            byTable[table] = signature
            bySignature[signature] = table
        }
    }

    @Test("the signature is the marginal projection, never a pinned slice (§4.3)")
    func projectionIsNotASlice() {
        let table = LawTable(Corpora.law(band: .contextual, index: 5))
        let pinned = table.row(after: Deck.glyph(id: 22))
        let projection = ExtensionSignature(table, levels: 4)
        let slice = ExtensionSignature(row: pinned)
        #expect(projection != slice, "quoting the slice would say 48 where the screen shows 64")
    }
}
```

Create `Modules/Tests/CodexFeatureTests/ExtensionThumbnailTests.swift`:

```swift
import Testing
import HunchCore
@testable import CodexFeature

@Suite("The thumbnail's geometry, states and overlays", .tags(.unit, .presubmission))
@MainActor
struct ExtensionThumbnailTests {

    @Test("cell = (side − 2·inset)/16 at both sites, and the inset is the same at both")
    func cellArithmetic() {
        #expect(C.Thumbnail.cell(side: C.Thumbnail.grid) == C.Assay.cellSide(.codexThumbnail))
        #expect(C.Thumbnail.cell(side: C.Thumbnail.recent) == C.Assay.cellSide(.shelfRecent))
        #expect(C.Thumbnail.cell(side: C.Thumbnail.grid) * 16
                == C.Thumbnail.grid - 2 * C.Thumbnail.inset)
        #expect(C.Thumbnail.cell(side: C.Thumbnail.recent) * 16
                == C.Thumbnail.recent - 2 * C.Thumbnail.inset)
    }

    @Test("the 60 pt site draws four ink levels and the 40 pt site two")
    func levelsBySite() {
        #expect(ExtensionThumbnail.levels(forSide: C.Thumbnail.grid) == 4)
        #expect(ExtensionThumbnail.levels(forSide: C.Thumbnail.recent) == 2)
    }

    @Test("the thumbnail composes the Assay grid and declares no 16×16 of its own")
    func composesTheGrid() {
        let model = ThumbnailModel(page: Corpora.codexPage(band: .exclusive, index: 0),
                                   site: .codexThumbnail)
        #expect(model.assay.site == C.Assay.Site.codexThumbnail)
        #expect(model.assay.picture.isProjection)
    }

    @Test("the three overlays are chosen by the page and nothing else")
    func overlaySelection() {
        var page = Corpora.codexPage(band: .relational, index: 0)
        page.unfractured = true
        page.anomalyDay = nil
        #expect(ThumbnailOverlays(page: page) == ThumbnailOverlays(notch: false, doubledRim: false))

        page.unfractured = false
        #expect(ThumbnailOverlays(page: page).notch)

        page.anomalyDay = 20_000
        #expect(ThumbnailOverlays(page: page).doubledRim)
    }

    @Test("an empty slot is a dashed socket, not an absence")
    func emptySlotIsDrawn() {
        let model = ThumbnailModel(emptySlotAt: CanonicalKey(attributeOrdinal: 1,
                                                             comparatorOrdinal: 0,
                                                             subsetBitmask: 0b0011))
        #expect(model.state == .emptySlot)
        #expect(model.isDashed)
        #expect(model.isHitTestable == false)
    }

    @Test("faceted-out dims in place and stops responding to touch — it never reflows (§11.2)")
    func facetedOutDimsInPlace() {
        let pages = (0..<12).map { Corpora.codexPage(band: .pair, index: $0) }
        let ordered = CodexTaxonomy.order(pages)
        let filtered = ThumbnailModel.models(for: ordered, facetedOut: Set([ordered[3].lawKey]))
        #expect(filtered.map(\.lawKey) == ordered.map(\.lawKey), "the grid did not reflow")
        #expect(filtered[3].state == .facetedOut)
        #expect(filtered[3].isHitTestable == false)
    }

    @Test("a thumbnail is a picture: it takes neither artScale nor the page's 0.78×")
    func thumbnailHoldsItsGeometry() {
        for multiplier in [1.0, 1.2, 1.35] {
            let env = RenderEnv.preview(typeMultiplier: multiplier)
            #expect(ThumbnailModel(page: Corpora.codexPage(band: .literal, index: 0),
                                   site: .codexThumbnail).side(in: env) == C.Thumbnail.grid)
        }
    }

    @Test("a 40 pt thumbnail is never a hit target — the plate is the target")
    func recentsAreDepictive() {
        let model = ThumbnailModel(page: Corpora.codexPage(band: .literal, index: 0), site: .shelfRecent)
        #expect(model.isHitTestable == false)
    }

    @Test("nothing on a thumbnail blooms, in any environment")
    func neverBloomed() {
        for env in [RenderEnv.preview(), .preview(theme: .highContrast), .preview(reduceTransparency: true)] {
            #expect(ThumbnailModel(page: Corpora.codexPage(band: .systemic, index: 0),
                                   site: .codexThumbnail).blooms(in: env) == false)
        }
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter ThumbnailSignatureTests` and
`swift test --package-path Modules --filter ExtensionThumbnailTests`

Expect missing `ExtensionSignature`, `LawTable.marginal()`, `C.Thumbnail`, `ExtensionThumbnail`,
`ThumbnailModel`, `ThumbnailOverlays`. **`signaturesAreCollisionFree` must fail with "no such type"
and not with a collision** — a collision on the first run means `ExtensionSignature` was written to
hash rather than to hold the cells, which is the one implementation that would make the gate a lie.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/ExtensionSignature.swift` — `ExtensionSignature: Hashable, Sendable` |
| modify | `HunchCore/Sources/Laws/LawTable.swift` — `marginal() -> [UInt16]` (256 counts over the 256 `prev` values); `row(after:)` already exists from E05 |
| create | `HunchCore/Tests/LawsTests/ThumbnailSignatureTests.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Thumbnail` (`grid`, `recent`, `inset`, `cell(side:)`, `notchLength`, `rimGap`); correct `C.Assay.cellSide(.shelfRecent)` per the ruling below |
| create | `Modules/Sources/CodexFeature/ExtensionThumbnail.swift` — `ExtensionThumbnail: View`, `ThumbnailModel`, `ThumbnailOverlays` |
| modify | `Modules/Sources/HunchUI/AssayCanvas.swift` — accept `AssayPicture.projection([UInt8])` if E09·T05 shipped only `.slice` |
| modify | `Modules/Sources/CodexFeature/ShelfPlate.swift` — fill T02's four recent slots |
| create | `Modules/Tests/CodexFeatureTests/ExtensionThumbnailTests.swift` |
| modify | `tests.json` · `DECISIONS.md` — see *Acceptance criteria* |

## Implementation notes

### `ExtensionSignature` holds cells; it does not hash them

```swift
public struct ExtensionSignature: Hashable, Sendable {
    /// 256 ink levels in `glyphID` order, 0 = hollow … 3 = solid. `glyphID = fill*64 + shape*16 + pips*4 + hue`.
    public let cells: [UInt8]

    /// The unconditional marginal projection, quantised. `levels` is 4 at 60 pt and 2 at 40 pt.
    public init(_ table: LawTable, levels: Int)

    /// A pinned slice. Used by the Assay, never by a thumbnail — §4.3.
    public init(row: Bitboard256)
}
```

**Why it holds the cells.** Collision-freeness follows from extension identity only if the signature
is *injective on tables at four levels for a stateless law*, and the only implementation with that
property is the one that keeps every cell. A 64-bit hash would be smaller and would make the gate
untrue: two extensions colliding in the hash would draw one constellation. `Hashable` is synthesised
over `cells` and is fine — the drawing is the array, the hash is an index.

**A stateless law is not a special case.** Its marginal is 0 or 256 per cell, so the four-level
quantiser already yields `{0, 3}` and the two-level one yields the same. `statelessIsBinaryAndOrdered`
asserts that rather than a `if isContextual` branch, which is why the branch must not exist.

### `LawTable.marginal()`

```swift
/// For each of the 256 `cur` glyphs, the number of the 256 `prev` glyphs under which it is admitted.
/// - Complexity: O(256) over the lifted `Bitboard65536`; ~2 µs, and the Codex calls it once per
///   thumbnail per shelf open.
public func marginal() -> [UInt16]
```

For a stateless table this is `admits(cur) ? 256 : 0`, computed from the `Bitboard256` without
lifting — `P == lift(P & FULL256)` is E02·T04's statelessness identity and it is the cheap path.
For a contextual table it is a popcount per `cur` column of the 1024-word board. Do not materialise
65,536 `Bool`s.

### Quantisation is the fill ladder, verbatim

Four levels, monotone, colour-free, thresholded on the marginal fraction:

```
level(f) = f == 0     ? 0        // hollow
         : f <  1/3   ? 1        // dotted
         : f <  2/3   ? 2        // striped
         :              3        // solid
```

The **rungs** are the glyph `fill` channel's, so a player who has learned that a solid glyph is
"more" than a dotted one reads a thumbnail for free (§2, §13.5). The *rendering* of each level is
`AssayCanvas`'s — accumulate one `Path` per level and fill at most four times, never 256 fills
(`assay-grid.md` §4). Do not re-derive a dot pitch here: at 3.5 pt cells there is no room for a
texture, so a level is a **fill alpha ladder on the cell rect**, which is what `assay-grid.md` §1's
`cellInset` and the lattice threshold already anticipate.

`monotone` is the property the test pins and the one that would silently break: reversing two rungs
makes a denser law look sparser and destroys the only thing a shelf's texture communicates.

### The 40 pt site quantises to two, and the cell side needs a ruling

`extension-thumbnail.md` §2's argument is measurement, not taste: a 2.25 pt cell is 4.5 device pixels
at @2×, so "dotted" is one dot and "striped" one stroke, and four levels read as two.
**Rendering four levels that read as two is worse than rendering two honestly.** Threshold at 0.5.

The two reference files disagree on the 40 pt cell side and the disagreement must be settled in code:

> `assay-grid.md` §1 lists `C.Assay.cellSide(.shelfRecent) = 2.5`, which implies a 40 pt grid with
> **no** inset. `extension-thumbnail.md` §1 gives `cell = (side − 2·inset)/16` with `inset = 2` at
> both sizes, which makes the 40 pt cell **2.25** and leaves the hairline frame somewhere to sit.
> **Ruling: 2.25.** `extension-thumbnail.md` owns the thumbnail sites, the inset is what stops the
> frame overlapping the outer cells, and the two sites must share one formula or the 60 pt derivation
> (`(60 − 4)/16 = 3.5`, which §11.2 states directly) stops being a derivation. Correct
> `C.Assay.cellSide(.shelfRecent)` to 2.25, record it in `DECISIONS.md`, and note it back into
> `assay-grid.md` §1.

At both thumbnail sites `C.Assay.drawsLattice` is false, so separation comes from `cellInset` and the
correction changes nothing about how the grid is drawn — only where its outer edge lands.

### One 16 × 16 drawing in the app, not two

`assay-grid.md` §1 is explicit that the thumbnail *"calls this grid and never redraws it — that split
is what stops a second 16 × 16 drawing existing"*, while `extension-thumbnail.md` §6's sketch shows a
self-contained `Canvas`. **Compose.** `ExtensionThumbnail` is:

```swift
struct ExtensionThumbnail: View {
    let signature: ExtensionSignature
    let site: C.Assay.Site              // .codexThumbnail (60) or .shelfRecent (40)
    let overlays: ThumbnailOverlays
    let env: RenderEnv

    var body: some View {
        AssayCanvas(env: env, site: site, picture: .projection(signature.cells),
                    evidence: nil, onInspect: {}, onReadByAttribute: {})
            .frame(width: C.Thumbnail.side(site), height: C.Thumbnail.side(site))
            .overlay { overlays.rim }       // anomaly: doubled rim
            .overlay { overlays.notch }     // fracture: 2 pt corner notch
            .drawingGroup(opaque: false)    // rasterise once per signature; NOT a bloom layer
    }
}
```

Record the composition in `DECISIONS.md`. If `AssayCanvas` currently accepts only a slice, widening
`AssayPicture` is the smaller change and is this task's; do not fork the grid.

Two performance notes that are load-bearing on a 45-thumbnail scroll: `rendersAsynchronously: false`
inside the canvas (async rendering hands each canvas to a background queue and produces visible
pop-in on a surface whose whole job is texture), and `.drawingGroup` to cache the raster between
frames. `.drawingGroup` is a render-tree optimisation, **not** an image asset, and does not violate
the no-assets rule.

### The three overlays, drawn around the grid

| Overlay | Render | When |
|---|---|---|
| fracture | a 2 pt corner notch | `unfractured == false` |
| anomaly | a doubled rim | `anomalyDay != nil` |
| empty slot | dashed socket, unlit, no grid at all | slot-map shelves, T07 |

They are drawn **around** the grid, never inside it (`assay-grid.md` §3) — putting Codex state into
the play surface's renderer is the split this rule protects. `ThumbnailOverlays` is a two-`Bool`
value derived from the page, so the selection is testable without a raster.

### Faceting dims in place

§11.2 fixes canonical-key order so *"a law's slot never moves"*, and that guarantee is what makes the
shelf a picture of the law space. A facet that reflowed the grid would move every slot on every facet
change and destroy the adjacency that puts near-neighbours in extension space side by side. So:
`.facetedOut` sets `opacity.disabled` and `allowsHitTesting(false)` and changes **no index**. T08
supplies the predicate; this task supplies the state and the assertion.

### VoiceOver, narrated lazily

Each held thumbnail is a `.button` whose **label is the law's narration** — `LawNarrator`'s sentence
(§13.10), the same String Catalog fragments the Codex page uses, so a narrated law and a rendered law
are the same law in two media. Narrate **lazily**: `accessibilityLabel` takes an autoclosure
evaluated on focus, so narrating one law costs one AST walk; precomputing 2,063 narrations when the
grid builds is the mistake, and VoiceOver never asks for more than the focused element.

`LawNarrator` is **E19·T03**. Until it lands, wire the closure through an `Unimplemented` double so
the shape is right and the strings are E19's.

| Element | Trait | Label | Value |
|---|---|---|---|
| held | `.isButton` | the narration | the find date; "anomaly"; "fractured" |
| empty slot | `.isButton`, `.notEnabled` | "empty slot" | — |
| faceted-out | `.isButton`, `.notEnabled` | the narration | "filtered out" |

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ThumbnailSignatureTests` green, all six tests, at `Corpora.lawsPerBand` laws per band.
- [ ] `swift test --package-path Modules --filter ExtensionThumbnailTests` green, all nine tests.
- [ ] `grep -rn "3\.5\|2\.25\|2\.5" Modules/Sources/CodexFeature/ExtensionThumbnail.swift` returns nothing — every cell side comes from `C.Assay.cellSide(_:)`.
- [ ] `grep -rn "blur\|shadow\|addFilter" Modules/Sources/CodexFeature/ExtensionThumbnail.swift` returns nothing.
- [ ] `grep -rn "hue\.\|accent\." Modules/Sources/CodexFeature/ExtensionThumbnail.swift` returns nothing — the thumbnail is colour-free by construction.
- [ ] `grep -c "Canvas(" Modules/Sources/CodexFeature/ExtensionThumbnail.swift` reports 0 — it composes `AssayCanvas`.
- [ ] `DECISIONS.md` records the 40 pt cell side (2.25, resolving `assay-grid.md` §1 against `extension-thumbnail.md` §1) and the composition of `AssayCanvas` rather than a second grid.
- [ ] `assay-grid.md` §1's table is corrected in the skill, so the two references agree.
- [ ] `tests.json` carries: signature collision-freeness per band, the four-level monotone ladder, the two-level 40 pt variant, projection-not-slice, faceting dims in place, and never-bloomed.
- [ ] The fast suite is still under 10 s — `marginal()` at `Corpora.lawsPerBand × 8` is the one thing in this task that could spend it; measure before and after.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T03: the extension signature, its four-level projection and the thumbnail at both sites"`

## Out of scope

- **The shelf grid, its dividers, its scrubber and the 5 → 2 column reflow** — **T04**.
- **The Codex page's 9.5 pt Assay and its draggable ghost** — **T05**.
- **Which pages are faceted out** — **T08**. This task ships the `.facetedOut` state and the no-reflow guarantee.
- **Slot enumeration and where an empty slot comes from** — **T07**. This task ships the dashed-socket rendering.
- **`AssayCanvas`'s own geometry, its lattice threshold and its evidence overlay** — **E09·T05/T06**.
- **`LawNarrator`** — **E19·T03**.
- **The DEBUG snapshot gallery row that verifies the 40 pt two-level claim as a raster** — **E04·T09**; add the row there.
