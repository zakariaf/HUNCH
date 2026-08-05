# T05 — `CodexPageView`

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T04 |
| **Delivers** | Page rendering · 18 screens (screen 11) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. It owns `C.RuleTile.codexScale`, the type role every numeral on the strip takes, and the rule this task is most likely to break: **scale lengths, never weights** — a `weight.thin` frame at 0.78× is below the hairline and disappears, and weight already has its own axis (Bold Text, High Contrast). |
| `hunch-chrome-and-meta` | `references/codex-page.md` is the normative spec for the whole screen: the six-region band layout, the three registers, the eight elements of the instrument strip with their owners, the find log, the four states, the navigation rule, and the screenshot-clean constraint that makes prev/next a fixed band rather than an overlay. |
| `hunch-bench-instruments` | The page composes two of this skill's instruments in their `read-only` state: `references/rule-tile.md` owns the six tile states and the ruling that 0.78 is a **transform, not a second layout**; `references/assay-grid.md` owns the 9.5 pt site, the slice-versus-projection split and the never-bloomed rule. The page draws neither; it composes both. |

## Objective

At the end of this task one law is a page: its rule-tiles at 0.78× in the same grammar the player
declared it with, its full extension as a 152 pt Assay with a draggable ghost for contextual laws,
an instrument strip carrying every fact §11.1 lists, a find log of up to five re-strike rings, and a
horizontal swipe that walks the canonical order **including the holes**. Before this task a thumbnail
opens nothing; after it, the Codex's third level exists and is the only screen in the app composed to
be screenshot-clean, because §11.5 removed every alternative.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.1 | The three registers. **1.** The law in the Bench's own rule-tile grammar, *"laid out by the same `Bench.layout(for:)` that G10 already guarantees round-trips"*, read-only — no cell responds to touch, no Seal, no palette — at **0.78×** the live Bench (291 pt rails → 227 pt); a **burnished** page draws those strokes in `accent.brass`. **2.** The Assay, the law's full extension at **9.5 pt cells (152 × 152 pt)**; for a contextual law the marginal projection with a **draggable ghost thumbnail** that pins `prev` and morphs the constellation. **3.** The instrument strip: `bestProbes` as a tick row against that band's `par` with the mono numeral beside it; Seal marks as 1–3 pips; the **fracture** hairline across the rim if `unfractured == false`; the mode sigil; a band notch; the **anomaly seal** (a doubled rim arc) if `anomalyDay != nil`; the find date via `Date.FormatStyle(.dateTime.year().month().day())` |
| `GAME_DESIGN.md` | §11.2 | `CodexPageView`: `20–64` bar · `64–316` rule-tiles · `316–472` Assay · `472–540` instrument strip · `540–620` find log (up to 5 re-strike rings, each tappable for its date) · `620–667` prev/next. *"Horizontal swipe steps to the adjacent slot in canonical order, including empty slots on slot-map shelves — walking past the holes is the point"* |
| `GAME_DESIGN.md` | §11.3 | The re-strike ring: five rings, then a single filled ring meaning **5+**. A **burnish** draws no ring |
| `GAME_DESIGN.md` | §11.5 | No share sheet, no share card, no image composer, no `UIActivityViewController`, no deep link, and **no export**; the stated substitute is that *"`CodexPageView` is therefore composed to be screenshot-clean — full-bleed, no floating chrome, no modal, no transient overlay"* |
| `GAME_DESIGN.md` | §5.4, §5.7 | `par` per band — `Band.par` in `HunchCore`, never a constant in a view |
| `GAME_DESIGN.md` | §10.5, §11.9 | A band **notch** is a position in a family ladder, which the Codex is allowed to carry as history; a band **number** is forbidden |
| `GAME_DESIGN.md` | §12.9 | The page carries **no title** — it is titled by its law — and no control labels of its own beyond the shelf's three and the Assay's three, which is survivable only because its identity is the *narration* |
| `GAME_DESIGN.md` | §4.4, §5.3 G10 | `LawNode(BenchLayout(law)) == law.renderedNormalForm`, node-identical — the guarantee that makes register 1 possible at all |
| `hunch-chrome-and-meta/references/codex-page.md` | §1–§11 | Every region, every owner, the four states, and the eleven wrongs |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | The four page states are an exhaustive `switch` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/CodexFeatureTests/CodexPageTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import CodexFeature

@Suite("The Codex page composite — §11.1, §11.2, §11.5", .tags(.unit, .presubmission))
@MainActor
struct CodexPageTests {

    private func page(_ band: Band = .relational, index: Int = 0) -> CodexPage {
        Corpora.codexPage(band: band, index: index)
    }

    // MARK: the band layout

    @Test("the six regions are laid out relative to the resolved bar height, in order")
    func regionsAreOrderedAndRelative() {
        for barHeight in [44.0, 44.0, 61.0] {
            let layout = CodexPageLayout(barHeight: barHeight, safeHeight: 647)
            let regions = [layout.instrumentBar, layout.tiles, layout.assay,
                           layout.strip, layout.findLog, layout.prevNext]
            for (a, b) in zip(regions, regions.dropFirst()) {
                #expect(a.maxY == b.minY, "regions must abut with no gap and no overlap")
            }
            #expect(layout.instrumentBar.height == barHeight)
            #expect(layout.prevNext.maxY == 647)
        }
    }

    @Test("the Assay region is a 152 pt square with 2 pt each side (§11.2)")
    func assayIsASquare() {
        let layout = CodexPageLayout(barHeight: 44, safeHeight: 647)
        #expect(layout.assaySquare.width == C.Assay.gridSide(.codexPage))
        #expect(layout.assaySquare.width == layout.assaySquare.height)
        #expect(layout.assay.height - layout.assaySquare.height == 4)
    }

    // MARK: register 1

    @Test("the tiles are laid out by BenchLayout(law) and round-trip — G10, reused")
    func tilesComeFromBenchLayout() {
        let p = page(.contextual, index: 4)
        let model = CodexPageModel(page: p, par: Band.contextual.par)
        #expect(model.benchLayout == BenchLayout(p.law))
        #expect(LawNode(model.benchLayout) == p.law.renderedNormalForm)
    }

    @Test("the tile scale is a transform at 0.78, and the live rail becomes 227 pt")
    func tileScaleIsATransform() {
        #expect(C.RuleTile.codexScale == 0.78)
        let model = CodexPageModel(page: page(), par: Band.relational.par)
        #expect(model.tilePresentation.scale == C.RuleTile.codexScale)
        #expect((C.RuleTile.railContent * C.RuleTile.codexScale).rounded() == 227)
    }

    @Test("stroke weights are NOT scaled by 0.78 — weight has its own axis")
    func weightsAreNotScaled() {
        let env = RenderEnv.preview()
        let model = CodexPageModel(page: page(), par: Band.relational.par)
        #expect(model.tilePresentation.strokeWeight(in: env) == env.weight(.thin))
    }

    @Test("every tile is read-only: no hit target, no Seal, no palette")
    func registerOneIsReadOnly() {
        let model = CodexPageModel(page: page(), par: Band.relational.par)
        #expect(model.tilePresentation.presentation == RuleTileFrame.Presentation.readOnly)
        #expect(model.tilePresentation.isHitTestable == false)
        #expect(model.hasSeal == false)
        #expect(model.hasPalette == false)
    }

    @Test("a burnished page draws register 1 in brass, and only register 1")
    func burnishIsBrassTiles() {
        var p = page()
        p.burnished = true
        let model = CodexPageModel(page: p, par: Band.relational.par)
        #expect(model.state == .burnished)
        #expect(model.tilePresentation.presentation == RuleTileFrame.Presentation.burnished)
        #expect(model.strip.accentedElements.isEmpty, "the strip does not also go brass")
    }

    // MARK: register 2

    @Test("a stateless law shows its slice; a contextual law shows the projection plus a ghost")
    func assayPictureBySubject() {
        let stateless = CodexPageModel(page: page(.exclusive), par: Band.exclusive.par)
        #expect(stateless.assay.picture.isSlice)
        #expect(stateless.assay.ghost == nil)

        let contextual = CodexPageModel(page: page(.contextual), par: Band.contextual.par)
        #expect(contextual.assay.picture.isProjection)
        #expect(contextual.assay.ghost != nil)
    }

    @Test("dragging the ghost pins prev and morphs the constellation")
    func ghostPinsPrev() {
        var model = CodexPageModel(page: page(.contextual), par: Band.contextual.par)
        let before = model.assay.picture
        model.pinGhost(toGlyphID: 137)
        #expect(model.assay.pinnedPrev?.glyphID == 137)
        #expect(model.assay.picture != before)
    }

    @Test("the ghost has a non-gesture route: it is adjustable and steps prev")
    func ghostIsAdjustable() {
        var model = CodexPageModel(page: page(.contextual), par: Band.contextual.par)
        model.pinGhost(toGlyphID: 0)
        model.incrementGhost()
        #expect(model.assay.pinnedPrev?.glyphID == 1)
        model.decrementGhost()
        #expect(model.assay.pinnedPrev?.glyphID == 0)
    }

    // MARK: register 3

    @Test("the strip carries all eight elements in order (§11.1)")
    func stripElements() {
        var p = page(.systemic)
        p.unfractured = false
        p.anomalyDay = 20_431
        let strip = CodexPageModel(page: p, par: Band.systemic.par).strip
        #expect(strip.elements == [
            .probeTicks, .probeNumeral, .sealMarks, .fracture,
            .modeSigil, .bandNotch, .anomalySeal, .findDate,
        ])
    }

    @Test("the probe ticks read bestProbes against Band.par and never a literal")
    func ticksReadBandPar() {
        var p = page(.guarded)
        p.bestProbes = 17
        let strip = CodexPageModel(page: p, par: Band.guarded.par).strip
        #expect(strip.ticks.filled == 17)
        #expect(strip.ticks.total == Band.guarded.par)
    }

    @Test("an unfractured page draws no fracture; a fractured one does")
    func fractureIsConditional() {
        var p = page()
        p.unfractured = true
        #expect(CodexPageModel(page: p, par: Band.relational.par).strip.elements.contains(.fracture) == false)
        p.unfractured = false
        #expect(CodexPageModel(page: p, par: Band.relational.par).strip.elements.contains(.fracture))
    }

    @Test("the band notch is a position, never a digit (§10.5)")
    func bandNotchIsNotANumber() {
        for band in Band.allCases {
            let strip = CodexPageModel(page: page(band), par: band.par).strip
            #expect(strip.bandNotch.index == band.rawValue - 1)
            #expect(strip.bandNotch.total == Band.allCases.count)
            #expect(strip.renderedNumerals.contains(String(band.rawValue)) == false)
        }
    }

    @Test("the only numerals on the page are the probe count and the formatted date")
    func numeralSites() {
        var p = page()
        p.bestProbes = 9
        let strip = CodexPageModel(page: p, par: Band.relational.par).strip
        #expect(strip.numeralSites == [.probeNumeral, .findDate])
    }

    // MARK: the find log

    @Test("the find log shows min(timesFound, 5) rings, then one filled ring meaning 5+")
    func findLogRings() {
        for (found, expected) in [(1, 1), (3, 3), (5, 5), (6, 1), (99, 1)] {
            var p = page()
            p.timesFound = UInt16(found)
            let log = CodexPageModel(page: p, par: Band.relational.par).findLog
            #expect(log.rings.count == expected)
            #expect(log.isCapped == (found >= 6))
        }
    }

    @Test("each ring is its own 44 pt target with its date as its value")
    func ringsAreTargets() {
        var p = page()
        p.timesFound = 3
        let log = CodexPageModel(page: p, par: Band.relational.par).findLog
        #expect(log.rings.allSatisfy { $0.hitRect.width >= C.Key.minimumSide })
        #expect(log.rings.allSatisfy { $0.date != nil })
    }

    // MARK: navigation

    @Test("horizontal swipe steps the adjacent canonical slot, including empty ones")
    func swipeWalksEmptySlots() {
        let held = CodexTaxonomy.order((0..<4).map { page(.literal, index: $0) })
        let slots: [ShelfSlot] = [
            .held(held[0]),
            .empty(CodexTaxonomy.canonicalKey(for: held[1].law)),
            .held(held[2]),
        ]
        var pager = CodexPager(slots: slots, index: 0)
        pager.advance()
        #expect(pager.current.isEmpty, "walking past the holes is the point")
        pager.advance()
        #expect(pager.current.lawKey == held[2].lawKey)
        pager.advance()
        #expect(pager.index == 2, "clamps at the end, never wraps")
    }

    @Test("the page is screenshot-clean: prev/next is a fixed band and nothing floats")
    func screenshotClean() {
        let layout = CodexPageLayout(barHeight: 44, safeHeight: 647)
        let model = CodexPageModel(page: page(), par: Band.relational.par)
        #expect(layout.prevNext.isFixedBand)
        #expect(model.overlays.isEmpty, "no toast, no badge, no confirmation")
        #expect(model.hasShareAffordance == false)
        #expect(model.title == nil)
    }

    @Test("the four states are exhaustive and chosen by the page's own fields")
    func stateSelection() {
        var p = page()
        p.unfractured = true; p.burnished = false
        #expect(CodexPageModel(page: p, par: Band.relational.par).state == .settled)
        p.unfractured = false
        #expect(CodexPageModel(page: p, par: Band.relational.par).state == .fractured)
        p.burnished = true
        #expect(CodexPageModel(page: p, par: Band.relational.par).state == .burnished)
        #expect(CodexPageModel(page: p, par: Band.relational.par, isInscribing: true).state == .liveInscribing)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter CodexPageTests`

Expect missing `CodexPageLayout`, `CodexPageModel`, `CodexPager`, `StripElement`. **`tilesComeFromBenchLayout`
must fail on a missing symbol, not on a round-trip mismatch** — a mismatch means E06·T04's G10 has
regressed and belongs in that suite, not this one.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/CodexFeature/CodexPageView.swift` — the screen |
| create | `Modules/Sources/CodexFeature/CodexPageLayout.swift` — the six regions |
| create | `Modules/Sources/CodexFeature/CodexPageModel.swift` — `CodexPageModel`, `CodexPageState` |
| create | `Modules/Sources/CodexFeature/PageInstrumentStrip.swift` — `StripElement`, the eight-element strip |
| create | `Modules/Sources/CodexFeature/FindLog.swift` |
| create | `Modules/Sources/CodexFeature/CodexPager.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.CodexPage` (region heights, strip spacing, find-log ring pitch, notch length) |
| modify | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — the `.readOnly` and `.burnished` presentations, if E09·T02 left them unimplemented |
| modify | `Modules/Sources/HunchUI/AssayCanvas.swift` — the `.codexPage` site and the ghost scrubber's `.adjustable` route |
| create | `Modules/Tests/CodexFeatureTests/CodexPageTests.swift` |
| modify | `tests.json` — the strip's eight elements, the 5+ cap, weights-not-scaled, swipe-through-holes, screenshot-clean |

## Implementation notes

### Register 1: one layout, one transform

```swift
RuleTileStack(env: env, layout: model.benchLayout, presentation: model.tilePresentation.presentation)
    .scaleEffect(C.RuleTile.codexScale, anchor: .topLeading)
```

`rule-tile.md` §2 is unambiguous: *"Scale is a transform, not a second layout."* Laying the tiles out
again at 0.78 × each constant produces a second geometry that diverges on the first edit. And
`codex-page.md` §2's corollary is the one the test pins: **scale lengths, never weights.** A
`weight.thin` frame at 0.78× is 0.78 pt, below the hairline, and it disappears — so the geometry
takes the factor and `env.weight(_:)` is read unmodified. `weightsAreNotScaled` is that sentence.

`BenchLayout(page.law)` is the *same* constructor G10 already round-trips (§4.4, E06·T04), which is
why the page can render an arbitrary archived law with no new parser: any law the generator emitted
is provably buildable, so it is provably drawable.

**Read-only, absolutely.** No cell responds to touch, there is no Seal and there is no palette
(§11.1). `codex-page.md` §11 is blunt about why: a page whose cells respond to touch would let a
player edit an archived law, which is not a feature with a missing confirmation, it is a category
error. `RuleTileFrame.Presentation.readOnly` already sets `allowsHitTesting(false)`; assert it rather
than trusting it.

### Register 2: slice or projection, and a ghost that is also `.adjustable`

`assay-grid.md` §2's table decides which picture:

| Law | Picture | Source |
|---|---|---|
| stateless | the **slice** — this law admits glyph *i* | `LawTable.row(after:)` (the pin is irrelevant, the table is stateless) |
| contextual (bands 5, 7) | the **marginal projection**, four ink levels, plus a draggable ghost | `LawTable.marginal()` (T03), then `row(after: pinned)` once pinned |

The drag is **the one gesture on this screen**, and it has a non-gesture route: the ghost thumbnail
is `.adjustable`, stepping `prev` by `glyphID`. That pairing is not optional — §4.2's gesture
inventory rules out drag in the *declaration* UI, and the page is not the declaration UI, but §13.10
still requires every gesture to have a VoiceOver equivalent. `ghostIsAdjustable` is that requirement.

**Never bloomed**, at this size or any other (§13.5, `assay-grid.md` §1). `env.isBloomEnabled` is not
consulted: the Assay does not ask.

### Register 3: eight elements, seven owners, one order

| Element | Drawing | Owner |
|---|---|---|
| `bestProbes` tick row against `Band.par` | length-proportional tick row | `hunch-shared-marks/references/tick-row.md` |
| the mono numeral beside it | `type.numeral` | `numeral-readout.md` site 1 |
| Seal marks, 1–3 | pips | `hunch-bench-instruments/references/seal.md` |
| the fracture hairline across the rim | `weight.thin` `accent.cold` diagonal | PHOSPHOR §3 |
| the mode sigil | one of four | `hunch-sigil-drawing/references/mode-sigils.md` |
| the band notch | notch at 1 of 8 positions | `codex-page.md` |
| the anomaly seal — a doubled rim arc | arc | `hunch-shared-marks/references/arc-meter.md` |
| the find date | `Date.FormatStyle(.dateTime.year().month().day())` | `numeral-readout.md` site 2 |

`par` is `Band.par` in `HunchCore` and is never a constant in a view. This file owns the elements'
**order and spacing** and nothing else; every drawing above has an owning function already.

Two rulings the tests pin:

- **A band notch is not a band number.** §10.5 forbids surfacing a numeric difficulty; a notch at one
  of eight positions is a position in a family ladder, which §11.9 says the Codex is allowed to carry
  *as history*. `bandNotchIsNotANumber` asserts that the digit never renders.
- **Exactly two numerals.** The probe count and the formatted date. Seal marks are pips, the notch is
  a notch, the fracture is a diagonal. `numeralSites` is the assertion, and `numeral-readout.md` is
  the resolved site table — §13.4's list is a *typography* rule, not a licence to render one.

### The find log

Up to five re-strike rings, each tappable for its date; a sixth find draws a **single filled ring**
meaning 5+ (§11.1, §11.3). The rings are `VerdictRing.draw`'s `.restrike(count:)` state, which
already caps at `C.VerdictRing.restrikeCap`; pass the count and let the mark decide.

**A burnish draws no ring at all.** §11.3 defines it exhaustively: an ECHO round settled at 3 marks
sets `burnished` and ECHO's `modesSeen` bit and touches nothing else — *"it is therefore not a
re-find and draws no re-strike ring."* Its render is register 1's brass. Drawing a ring for a burnish
would claim a find that did not happen. T06 owns the write side; this task owns the render and must
not anticipate it with a `timesFound += 1`.

### Navigation, and why it walks the holes

```swift
public struct CodexPager: Sendable {
    public private(set) var slots: [ShelfSlot]      // canonical order, T04's array
    public private(set) var index: Int
    public mutating func advance()                  // clamps
    public mutating func retreat()                  // clamps
    public var current: ShelfSlot { slots[index] }
}
```

§11.2: *"Horizontal swipe steps to the adjacent slot in canonical order, including empty slots on
slot-map shelves — walking past the holes is the point."* An empty slot draws its dashed socket
(T03's `.emptySlot` state) with no tiles, no Assay and no strip, and its narration says "empty slot".
Skipping the holes would turn a map back into a log.

Clamp, never wrap. A wrap at the end of a 337-slot shelf is indistinguishable from a jump to a random
law.

**No other gesture.** No pinch-to-zoom on the Assay — expansion is `AssayInspectorView`'s job on the
Bench, and a page is already at reading size (`codex-page.md` §7).

### Screenshot-clean is a layout constraint, not a sentiment

§11.5 removed the share sheet, the share card, the image composer, `UIActivityViewController`, the
deep link and the export. The stated substitute is that the page is composed so the **system**
screenshot is the artefact. Concretely, and asserted by `screenshotClean`:

- prev/next is a **fixed band** at the foot, never a floating overlay;
- nothing animates in or out on top of the page after it settles — no toast, no badge, no "copied";
- the instrument bar is opaque and part of the composition, not a translucent bar over content;
- the page fills the safe area edge to edge;
- there is no title (§12.9 — a page is titled by its law).

If a future task wants a "saved" confirmation here, the answer is no, and this is where it is
recorded.

### VoiceOver

- **The page container's value is the `LawNarrator` sentence** (§13.10), using the same catalog
  fragments the thumbnail's label uses, so a narrated law and a rendered law are the same law in two
  media. `LawNarrator` is **E19·T03**; wire the closure and leave it `Unimplemented` until then.
- Register 1's tiles are read-only, so they are `.staticText` inside a container, **not** buttons that
  do nothing.
- The Assay keeps its two custom actions, "Inspect" and "Read by attribute".
- The contextual ghost is `.adjustable`.
- Each find-log ring is a `.button` with its date as its value.
- §12.9 budgets the page **no control labels of its own**, which survives only because its identity
  is the narration. Do not add a key here; if you need one, the budget is the conversation.

### Environment behaviour

| Setting | Effect |
|---|---|
| Reduce Motion | the swipe to an adjacent slot becomes a `Dur.crossfade` crossfade, as does the shared-element arrival from the Inscription; the contextual morph switches cells instantly with one whole-grid crossfade |
| High Contrast | `accent.brass` and `accent.cold` both clear the state-bearing floor; the fracture is **geometry first** (a break in the rim) so it survives greyscale and Differentiate Without Colour with no substitution |
| Bold Text | every weight steps through `env.weight(_:)`; the 0.78 factor never touches them |
| Dynamic Type | rule-tiles freeze at the art ceiling and metadata scrolls below; branch on `env.isArtScaleClamped`, **never** on the number. The Assay and the thumbnail hold their geometry |
| RTL | the page's chrome mirrors; **the internal rule-tile layout does not** — it is the law's rendering, and §12.8 lists it under "does not mirror, in any locale" |

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter CodexPageTests` green, all eighteen tests.
- [ ] `grep -rn "UIActivityViewController\|ShareLink\|shareSheet\|\.export" Modules/Sources/CodexFeature/` returns nothing.
- [ ] `grep -rn "0\.78" Modules/Sources/CodexFeature/` returns nothing — the factor is `C.RuleTile.codexScale`.
- [ ] `grep -rn "9\.5\|152" Modules/Sources/CodexFeature/CodexPageView.swift` returns nothing — the Assay's size is `C.Assay.cellSide(.codexPage)`.
- [ ] `grep -rn "\.par\b" Modules/Sources/CodexFeature/ | grep -v "Band\." ` returns nothing — `par` comes from `Band`.
- [ ] `grep -rn "1\.35\|artScaleCeiling" Modules/Sources/CodexFeature/` returns nothing — the branch is `env.isArtScaleClamped`.
- [ ] `grep -rn "default:" Modules/Sources/CodexFeature/CodexPageModel.swift` returns nothing.
- [ ] A simulator screenshot of a burnished, fractured, anomaly page at band 7 is pasted into `PROGRESS.md`, taken with the system screenshot and with no cropping — the screenshot-clean claim, demonstrated.
- [ ] `Localizable.xcstrings` gains **zero** keys from this task.
- [ ] `tests.json` carries: region abutment, G10 reuse in register 1, weights-not-scaled, read-only tiles, slice-vs-projection, ghost adjustable, the strip's eight elements and two numeral sites, the band notch as a position, the 5+ ring cap, swipe-through-holes, and screenshot-clean.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T05: CodexPageView — three registers, the find log and the hole-walking pager"`

## Out of scope

- **Writing `burnished`, `unfractured` or `timesFound`** — **T06**. This task renders them.
- **Where the slot array comes from and which shelves have holes** — **T07**. The pager takes T04's array.
- **The facet bar** — **T08**.
- **`RuleTileFrame`, `RampView`, `BridgeView`, `ForkView`, `TallyView`, `CouplerView`, `AssayCanvas`, `TickRow`, `VerdictRing`, `ArcMeter`, the Seal's marks** — **E04** and **E09**. This view composes; it draws none of them.
- **The four mode sigils** — **E12·T05 / E17·T04**.
- **`LawNarrator` and the announcement order** — **E19·T03/T05**.
- **The Inscription's shared-element arrival and reveal beats 5 and 7** — **E09·T10**; this task provides the receiving geometry only.
- **`Route`, the `Router`, back, and the play key's destination** — **E17·T01/T02**.
- **The Anomaly's own screen and its 28-cell ribbon** — **E16·T04**. This task draws only the page's anomaly seal.
