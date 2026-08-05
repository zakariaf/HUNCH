# T05 — The Assay

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | §14.1 `The Assay` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First.** `C.Assay.cellSide(_:)` is the single home for all six cell sizes and `C.Assay.drawsLattice(_:)` / `cellInset(_:)` derive from it; restating 3.5 / 4 / 9.5 / 23 anywhere is the drift this accessor exists to prevent. The lattice is `stroke.hairline`, which this skill declares **never state-bearing** — that is why it may sit at a low ratio while the cells carry the state. |
| `hunch-bench-instruments` | `references/assay-grid.md` is this task, top to bottom: the six sites, the slice-versus-projection table, the five states, the one-`Canvas`-one-element ruling, and the two independent reasons the Assay is **never bloomed** at any size in any state in any theme. |
| `hunch-accessibility` | The Assay is a single `.image` element with `.updatesFrequently`, two custom actions, and a value that must quote the **slice on screen** — quoting the marginal projection would say 48 where the screen shows 64. This skill owns that wording rule and the "Read by attribute" action's existence. |
| `hunch-motion-and-feedback` | The live morph's per-cell stagger and its Reduce Motion substitution (cells switch *instantly*, the whole grid crossfades once) and the `matchedGeometryEffect` zoom to the inspector, which is **removed** rather than shortened under Reduce Motion. |

## Objective

At the end of this task the draft's extension is visible as a 16 × 16 constellation beside the rails,
conditioned on a pinned ghost that defaults to the seed glyph and scrubs to any of the 256, morphing
live as the player edits — and tapping it opens a full-screen read-only inspector at 23 pt cells.
Before this task the trailing column is empty; after it, unsatisfiability and tautology are visible
instantly with no message, and a test proves the live grid quotes the conditioned slice and never the
unconditional marginal projection.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.3 | The whole component: the 16 × 16 micro-grid at 4 pt cells in canonical `glyphID` order, what it gives with no text (admit rate as density, unsatisfiability, tautology), the pin defaulting to the seed glyph and scrubbable to any of the 256, **the live Assay is a slice and never a projection**, and the tap-to-expand inspector at 23 pt cells |
| `GAME_DESIGN.md` | §6.7 | The worked declaration — the Assay's counts at each of the nine taps, and the paragraph that states 64 is the conditioned count while 48 would be `p × 256`, the unconditional marginal projection, *"and the two are never quoted for each other"* |
| `GAME_DESIGN.md` | §2 | `glyphID = fill·64 + shape·16 + pips·4 + hue` — the indexing rule, stable forever, so the grid's geometry becomes memorable |
| `GAME_DESIGN.md` | §13.5 | Bloom is one blur layer per glyph-bearing region and **the Assay is excluded entirely** |
| `GAME_DESIGN.md` | §13.7.3, §13.7.4 | The `matchedGeometryEffect` zoom from the 64 pt well, and its removal under Reduce Motion; the live morph's per-cell substitution |
| `GAME_DESIGN.md` | §13.10 | The Assay's VoiceOver row — `.image`, `.updatesFrequently`, the lit count *of the slice*, and the two actions |
| `GAME_DESIGN.md` | §6.11 case 20 | At AX2+ the Assay leaves the trailing column and becomes a 44 pt chip in the instrument bar that expands full-screen on tap |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | `LawTable.row(after:)` is core; **the pin, the scrubber and the evidence unlock are `AssayCanvas`** — putting the pin in the core gives a pure table a `var` |

## TDD — the test comes first

**Step 1 — write the failing tests.** Two files: the algebra in core, the picture in `HunchUI`.

Create `HunchCore/Tests/LawsTests/LawTableSliceTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("The slice is not the projection", .tags(.unit, .presubmission))
struct LawTableSliceTests {

    // §6.7's worked declaration, verbatim: the band-5 law of §5.5, pinned to the seed glyph
    // (hollow triangle, two pips, teal → prev pips rank = 2). The slice is 64. The
    // unconditional marginal projection would be p × 256 = 0.188 × 256 ≈ 48.
    // "The two are never quoted for each other."
    @Test("§6.7's worked draft slices to 64, not to 48")
    func workedDeclaration() throws {
        let law = try #require(Corpora.workedBand5Law)      // RANK pips(cur) > PREV RANK pips
                                                            //   AND shape ∈ {triangle, hexagon}
        let table = LawTable(law)
        let seed = try #require(Corpora.workedBand5SeedGlyph)

        let slice = table.row(after: seed)
        #expect(slice.popCount == 64)

        let projected = Int((table.admitRate * 256).rounded())
        #expect(projected == 48)
        #expect(slice.popCount != projected)
    }

    // §6.7 taps 4 and 5: the conditioned count moves with the comparator, which is the
    // clearest possible non-verbal statement of what "contextual" means.
    @Test("Cycling the comparator moves the slice: 64 at eq, 128 at gt")
    func theSliceMovesWithTheDraft() throws {
        let seed = try #require(Corpora.workedBand5SeedGlyph)
        let eq = LawTable(try #require(Corpora.contextualPips(.eq)))
        let gt = LawTable(try #require(Corpora.contextualPips(.gt)))

        #expect(eq.row(after: seed).popCount == 64)
        #expect(gt.row(after: seed).popCount == 128)
    }

    // §4.3: the pin is scrubbable to any of the 256, so every pin is a well-defined slice,
    // and for a genuinely contextual law they are not all the same slice.
    @Test("Every one of the 256 pins yields a slice, and a contextual law's slices differ")
    func allPinsAreDefined() throws {
        let table = LawTable(try #require(Corpora.workedBand5Law))
        let slices = Deck.all.map { table.row(after: $0) }
        #expect(slices.count == 256)
        #expect(Set(slices).count > 1)
    }

    // A stateless law is the degenerate case: every slice is the same, and it equals the
    // stateless extension lifted. That is what makes one widget correct for both.
    @Test("A stateless law's slices are all equal to its own extension")
    func statelessDegenerateCase() throws {
        let table = LawTable(try #require(Corpora.statelessAtom))
        let reference = table.row(after: Deck.glyph(id: 0))
        for glyph in Deck.all {
            #expect(table.row(after: glyph) == reference)
        }
    }
}
```

Create `Modules/Tests/HunchUITests/AssayCanvasTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI

@Suite("The Assay", .tags(.unit, .presubmission))
struct AssayCanvasTests {

    // assay-grid.md §1: six sites, and a seventh must be added to the enum where it is visible.
    @Test("There are exactly six Assay sites and each has one cell size")
    func sixSites() {
        #expect(C.Assay.Site.allCases.count == 6)
        let sides = C.Assay.Site.allCases.map(C.Assay.cellSide)
        #expect(sides.allSatisfy { $0 > 0 })
        #expect(C.Assay.cellSide(.inspector) > C.Assay.cellSide(.benchWell))
        #expect(C.Assay.gridSide(.benchWell) == C.Assay.cellSide(.benchWell) * 16)
    }

    // §2: glyphID = fill·64 + shape·16 + pips·4 + hue; row = id/16, column = id%16,
    // cell 0 top-LEADING. One indexing rule, everywhere.
    @Test("Cell rects follow glyphID order with cell 0 top-leading")
    func indexing() {
        let canvas = AssayCanvas.Geometry(site: .inspector, artScale: 1)
        #expect(canvas.rect(forGlyphID: 0).minX == 0)
        #expect(canvas.rect(forGlyphID: 0).minY == 0)
        #expect(canvas.rect(forGlyphID: 15).minY == canvas.rect(forGlyphID: 0).minY)
        #expect(canvas.rect(forGlyphID: 16).minY > canvas.rect(forGlyphID: 0).minY)
        #expect(canvas.rect(forGlyphID: 255).maxX <= canvas.gridSide + 0.0001)
    }

    // assay-grid.md §4: accumulate one Path per ink level and fill at most four times,
    // never 256 fills. At 4 pt cells inside a live-morphing Bench this is the frame.
    @Test("A slice fills once and a projection at most four times")
    func fillCount() throws {
        let slice = AssayPicture.slice(Corpora.arbitrarySlice)
        let projection = AssayPicture.projection(Corpora.arbitraryProjection)
        #expect(slice.inkLevels.count == 1)
        #expect(projection.inkLevels.count <= 4)
    }

    // §4.3: the pin DEFAULTS to the seed glyph.
    @Test("The pin defaults to the seed glyph and scrubs to any of the 256")
    func pinDefaultAndRange() throws {
        var model = AssayModel(seedGlyph: Deck.glyph(id: 22))
        #expect(model.pinnedGhost == Deck.glyph(id: 22))
        model.scrub(to: Deck.glyph(id: 199))
        #expect(model.pinnedGhost == Deck.glyph(id: 199))
        #expect(model.scrubRange.count == 256)
    }

    // §13.10 / accessibility: the VALUE quotes the slice on screen. The projection would
    // say 48 where the screen shows 64.
    @Test("The accessibility value quotes the on-screen slice, never the projection")
    func valueQuotesTheSlice() throws {
        let law = try #require(Corpora.workedBand5Law)
        let model = AssayModel(seedGlyph: try #require(Corpora.workedBand5SeedGlyph), draft: law)

        #expect(model.picture.isSlice)
        #expect(model.picture.litCount == 64)
        #expect(model.accessibilityLitCount == model.picture.litCount)
    }

    // §4.3: unsatisfiability (all dark) and tautology (all lit), "instantly and
    // unmistakably", with no message — and they are the two states that bar the Seal.
    @Test("All-dark and all-lit are states of the picture, not messages")
    func constantExtensionStates() {
        #expect(AssayPicture.slice(.empty).state == .allDark)
        #expect(AssayPicture.slice(.full).state == .allLit)
        #expect(AssayPicture.slice(Corpora.arbitrarySlice).state == .live)
    }

    // §13.5 / assay-grid.md §1: never bloomed, at any size, in any state, in any theme.
    // `env.isBloomEnabled` is NOT consulted — the Assay does not ask.
    @Test("The Assay never blooms and never asks whether it should",
          arguments: [true, false])
    func neverBlooms(_ bloomEnabled: Bool) {
        let env = RenderEnv.fixture(isBloomEnabled: bloomEnabled)
        #expect(AssayCanvas.layerCount(in: env) == 1)      // one rasterised drawingGroup
        #expect(AssayCanvas.blurRadius(in: env) == 0)
    }

    // assay-grid.md §1: artScale multiplies the well and the inspector; the Codex sizes
    // are pictures on a scrolling page and hold their size (§13.11).
    @Test("Art scale reaches the well and the inspector and nothing else",
          arguments: C.Assay.Site.allCases)
    func artScaleScope(_ site: C.Assay.Site) {
        let scaled = AssayCanvas.Geometry(site: site, artScale: Prim.artScaleCeiling)
        let plain = AssayCanvas.Geometry(site: site, artScale: 1)
        let scales = site == .benchWell || site == .inspector
        #expect((scaled.gridSide > plain.gridSide) == scales)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter LawTableSliceTests
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:HunchUITests/AssayCanvasTests
```

`LawTableSliceTests` will fail on `Corpora.workedBand5Law` and, if E05 did not ship it, on
`LawTable.row(after:)`. That is the right failure. **Do not** stub `row(after:)` in `HunchUI` to make
the second suite compile — the algebra is core.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Measure the live morph on the SE simulator with the Bench open and
a draft being edited: if the grid stutters, you have 256 fills. Fix it by accumulating paths, not by
lowering the frame rate.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Laws/LawTable.swift` — `row(after:) -> Bitboard256` and `marginal() -> [UInt8]`, **only if E05 did not ship them** |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Assay` with `Site`, `cellSide(_:)`, `gridSide(_:)`, `drawsLattice(_:)`, `cellInset(_:)`, `litInk` |
| create | `Modules/Sources/HunchUI/AssayCanvas.swift` — the drawing, its geometry, `AssayPicture` |
| create | `Modules/Sources/HunchUI/AssayModel.swift` — the pin, the scrubber and the picture derivation (view state, not core) |
| create | `Modules/Sources/LoomFeature/AssayInspectorView.swift` — the full-screen read-only inspector |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the trailing column hosts the well; tap expands |
| create | `HunchCore/Tests/LawsTests/LawTableSliceTests.swift` |
| create | `Modules/Tests/HunchUITests/AssayCanvasTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `workedBand5Law`, `workedBand5SeedGlyph`, `contextualPips(_:)`, `statelessAtom`, `arbitrarySlice`, `arbitraryProjection` |
| modify | `tests.json` — the slice-not-projection invariant |

## Implementation notes

### The one thing this task exists to get right

*"The live Assay is therefore always a **slice** of the pair table, never a projection of it: for a
draft admitting `p` of the 65,536 pairs, the lit count is the row count for the pinned `prev`, which
in general differs from `p × 256`."* (§4.3)

`LawTable.row(after: prev) -> Bitboard256` is the slice. `LawTable.marginal() -> [UInt8]` is the
projection — cell *i* carrying the count of `prev` values under which glyph *i* is admitted, quantised
to four levels. They are different pictures with different jobs:

| | The live **slice** | The **marginal projection** |
|---|---|---|
| Where | Bench well, inspector, Codex page for a *stateless* law | Codex thumbnail, shelf recents, Codex page for a *contextual* law |
| A cell means | is glyph *i* admitted **given the pinned `prev`** | over how many of the 256 `prev` values is glyph *i* admitted |
| Ink levels | 2 | **4** — `hollow · dotted · striped · solid`, the fill ink-density ladder reused, monotone, colour-free |
| Lit count | the row count for the pinned `prev` | in general **not** `p × 256` |

`AssayPicture` is a two-case enum, so the two can never be silently swapped, and `isSlice` is what the
accessibility value branches on. The Codex-side projection is **E15**'s; ship `marginal()` and the
four-level quantisation here because `AssayPicture` needs both cases to be closed, and let E15 call it.

### Never bloomed, and it does not ask

Two independent reasons (§13.5, `assay-grid.md` §1): its cells are 2.5–23 pt and carry no stroke to
widen, so a bloom pass would raise measured ink coverage and corrupt only the picture; and during the
correct-declaration reveal it floods 256 cells on top of the throat and the ribbon on the one frame in
the app that cannot afford a fourth offscreen layer against the shader's ≤ 0.4 ms/frame budget.

So `env.isBloomEnabled` is **not consulted** in `AssayCanvas.swift`, and the test asserts that by
constructing both envs and expecting one layer either way. `.drawingGroup(opaque: false)` is a
rasterisation hint that composites the finished grid once; `.blur(radius:)` and
`GraphicsContext.addFilter(.blur)` must not appear in the file at all.

### One `Canvas`, one element, at most four fills

§13.10 exposes the Assay as a single `.image`, so this is the **one** place on the Bench where a
monolithic `Canvas` is correct — everywhere else, one `Button` per part. It is also the only shape
that performs: accumulate one `Path` per ink level and fill at most four times. 256 fills at 4 pt
cells inside a live-morphing Bench is the difference between a frame and a stutter.

Individual cells are **never** exposed to VoiceOver. `children: .ignore` is deliberate: 256 swipes is
not an alternate reading of anything, and `"Read by attribute"` (E19·T04) exists for this. Wire the
two `accessibilityAction(named:)` hooks here — `Loc.inspect` and `Loc.readByAttribute` — and let E19
implement the sixteen-marginal announcement behind the second one.

`.updatesFrequently` without a rate limit will talk over the verdict announcement: re-post the value
on **draft change**, not on every morph frame.

### The RTL mirror is free — do not add one

SwiftUI flips the `Canvas`'s coordinate space with the layout direction, so `id % 16` produces a
leading-to-trailing order in every locale with no conditional. A manual mirror flips it twice and puts
glyph 0 in the wrong corner in Arabic. The **row** order does not mirror; the deck order is `glyphID`,
not a reading direction.

### The pin lives in the view

`08 §2` is explicit: `LawTable.row(after:)` is core; the pin, the scrubber and the band-4 evidence
unlock are `AssayCanvas`. Putting the pin in `LawTable` gives a pure table a `var` and drags view
state into a package whose whole value is that it has none. `AssayModel` is a `struct` held in
`@State` by `BenchView`, not an `@Observable` — there is no shared ownership to earn one (`A18`).

The scrubber is the ghost thumbnail: tapping it steps the pin, and it draws with
`GhostFrame.draw` — the same dashed hollow frame and backward chevron the ribbon's trailing tile and
the Bridge's trailing socket wear, which is `ghost-frame.md`'s third site and is why scrubbing reads
as "change which previous glyph" without a word.

### The inspector

Tap the well → a `matchedGeometryEffect` zoom from the 64 pt well to a full-screen read-only grid at
`C.Assay.cellSide(.inspector)`. Two things:

- It is a **presented subtree**, so it starts a fresh environment hierarchy and must **re-inject**
  (`04 A25`). An inspector rendered in the dark theme inside a light-theme app is the symptom, and it
  is the single most common bug in this area.
- Under Reduce Motion the `matchedGeometryEffect` is **removed**, not shortened. A 40 ms geometry
  match is still a translation and a scale, and §13.12 gate 9 is a hand audit.

At AX2+ the Assay leaves the trailing column entirely and becomes a 44 pt chip in the instrument bar
that expands full-screen on tap (§6.11 case 20). Declare the hook and the predicate
(`env.isArtScaleClamped`) here; the layout pass is E19·T06.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter LawTableSliceTests` green, and the fast suite is
      still under 10 s.
- [ ] `xcodebuild test … -only-testing:HunchUITests/AssayCanvasTests` green.
- [ ] `grep -nE 'isBloomEnabled|\.blur\(|addFilter' Modules/Sources/HunchUI/AssayCanvas.swift`
      returns nothing.
- [ ] `grep -nE '\b3\.5\b|\b9\.5\b|\b23\b|\b2\.5\b' Modules/Sources/HunchUI/AssayCanvas.swift`
      returns nothing — every size is `C.Assay.cellSide(_:)`.
- [ ] `grep -n 'layoutDirection\|isRTL\|\.reversed()' Modules/Sources/HunchUI/AssayCanvas.swift`
      returns nothing — no manual mirror.
- [ ] `grep -n 'var ' HunchCore/Sources/Laws/LawTable.swift` shows no stored `var` — the pin did not
      leak into core.
- [ ] `tests.json` carries `assay.slice-not-projection` naming
      `LawTableSliceTests.workedDeclaration` and quoting §6.7's 64-versus-48.
- [ ] In the simulator: opening the Bench, placing a Bridge and cycling the comparator visibly morphs
      the constellation; tapping the well opens the inspector with the same lit count.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter LawTableSliceTests && xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:HunchUITests/AssayCanvasTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T05: the Assay — the live pinned slice, the six sites and the read-only inspector"`

## Out of scope

- **The evidence overlay** — ribbon rings and the wrong-cell flash, and its band-4 unlock. **T06**.
- **The Codex thumbnail's overlays** — the 2 pt fracture notch, the doubled anomaly rim, the dashed
  empty slot. **E15·T03**, drawn *around* this grid; drawing them here would put Codex state in the
  play surface's renderer.
- **"Read by attribute"'s sixteen-marginal announcement.** **E19·T04**; the action hook is wired here.
- **The AX2+ instrument-bar chip layout.** **E19·T06**.
- **Reveal beat 1 (the Assay holds at full) and beat 5 (it contracts into the page thumbnail).**
  **T10**; this task ships the grid those beats animate.
- **Bloom itself.** **E04·T05**. This task's contribution is that the Assay is excluded from it.
