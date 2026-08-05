# T04 — `CodexShelfView`

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Taxonomy and browse (the shelf level) · Dynamic Type (the Codex row) · 18 screens (screen 10) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. The dividers are `weight.hairline` in `stroke.hairline`, the scrubber is `weight.thin` in `stroke.secondary`, and the gutters are `Space.*`; and the skill owns `env.artScale`'s ceiling and the rule that a thumbnail takes none of it — which is *why* the shelf answers Dynamic Type with a column count instead of a size. |
| `hunch-chrome-and-meta` | `references/extension-thumbnail.md` §1 owns the grid arithmetic (`5 · 60 + 4 · 10 = 340` in 375), the rail scrubber's *"snaps to skeleton sections, not pixels"*, and the 5 → 2 reflow; `references/instrument-bar.md` owns the bar this screen's regions are laid out relative to; and the skill's gotcha that `64` is a resolved height applies again, harder, because this screen has **no title** and its bar is therefore exactly 44 pt forever. |
| `hunch-accessibility` | The scrubber is `.adjustable` and must step *skeleton sections* — not rows, not pixels — so that what VoiceOver does and what the eye sees are the same operation; and §12.9 budgets `CodexShelfView` at exactly **3** control labels, which the narration format string, the empty-slot label and the scrubber consume with nothing left over. |

## Objective

At the end of this task one band is browsable: a five-column grid of 60 pt constellations in
permanent canonical order, cut into skeleton sections by a hairline divider carrying that section's
silhouette, with a rail scrubber that jumps to a section rather than scrolling by pixels. Before this
task a 2,063-row shelf is a scroll view nobody can navigate; after it, the shelf is the only screen
in the app three levels deep and it costs nothing, because it carries the play key like every other.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.2 (`CodexShelfView` table) | Instrument bar `20–64`: family sigil, fill arc, facet state. Grid `64–620`: **5 columns × 60 pt, 10 pt gutters** (`5·60 + 4·10 = 340` in 375), vertical scroll, ~45 pages per screen, skeleton dividers. Rail scrubber `64–620` in the trailing 12 pt, snapping to **skeleton sections, not to pixels** — *"the only way a 2,063-row shelf is navigable"*. Back / facets `620–667` |
| `GAME_DESIGN.md` | §11.2 | Skeleton sub-sections: *"A sub-section header is that silhouette drawn at 24 pt in the leading margin with a hairline divider. Large shelves get 10–40 sections; band 1 gets four (one per attribute)."* Canonical key orders within a section, *"deterministic, so a law's slot never moves"* |
| `GAME_DESIGN.md` | §12.8, §13.11 | At `accessibility2 … 5`: **Codex shelf grid 5 → 2 columns**. Chrome text never truncates and never shrinks; `minimumScaleFactor` is 1.0 everywhere; rows grow |
| `GAME_DESIGN.md` | §12.9 | `CodexShelfView` carries **no title** — *"a shelf is titled by its family sigil"* — and is budgeted 3 VoiceOver control labels |
| `GAME_DESIGN.md` | §12.3 | The play key in the trailing corner of the instrument bar, which is why three levels of Codex cost nothing against the ≤ 2-tap rule |
| `GAME_DESIGN.md` | §11.4 | Visible absence: on slot-map shelves the holes are drawn and **must not be collapsed out of the grid** |
| `hunch-chrome-and-meta/references/extension-thumbnail.md` | §1, §3, §4 | The grid, the 17.5 pt margins, faceting dims in place, and the scrubber as `.adjustable` stepping sections |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A14, A15, A6 | Derive, never mirror: the section index is computed from the ordered array, not stored beside it and kept in step |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/CodexFeatureTests/ShelfGridTests.swift`:

```swift
import Testing
import HunchCore
@testable import CodexFeature

@Suite("The shelf grid, its dividers and its scrubber — §11.2, §12.8", .tags(.unit, .presubmission))
@MainActor
struct ShelfGridTests {

    private func shelf(_ band: Band = .pair, pages: Int = 40) -> ShelfGridModel {
        let ordered = CodexTaxonomy.order((0..<pages).map { Corpora.codexPage(band: band, index: $0) })
        return ShelfGridModel(band: band, slots: ordered.map(ShelfSlot.held),
                              sections: CodexTaxonomy.sections(of: ordered))
    }

    // MARK: geometry

    @Test("five 60 pt columns with 10 pt gutters fit the reference width with equal margins")
    func referenceGridArithmetic() {
        let layout = ShelfGridLayout(width: 375, columns: 5)
        #expect(layout.columns == 5)
        #expect(layout.cell == C.Thumbnail.grid)
        #expect(layout.gutter == C.ShelfGrid.gutter)
        let content = Double(layout.columns) * layout.cell + Double(layout.columns - 1) * layout.gutter
        #expect(content == 340)
        #expect(layout.leadingMargin == layout.trailingMargin)
        #expect(layout.leadingMargin == (375 - 340) / 2)
    }

    @Test("the scrubber occupies the trailing 12 pt of the grid band and never overlaps a cell")
    func scrubberIsInTheTrailingRail() {
        let layout = ShelfGridLayout(width: 375, columns: 5)
        #expect(layout.scrubber.width == C.ShelfGrid.scrubberWidth)
        #expect(layout.scrubber.minX >= layout.contentTrailingEdge)
    }

    @Test("the grid goes 5 → 2 columns at AX2 and above, and holds 5 below it")
    func columnsByTypeSize() {
        for size in [DynamicTypeSize.large, .xxxLarge, .accessibility1] {
            #expect(ShelfGridLayout.columns(for: size) == 5)
        }
        for size in [DynamicTypeSize.accessibility2, .accessibility3, .accessibility4, .accessibility5] {
            #expect(ShelfGridLayout.columns(for: size) == 2)
        }
    }

    @Test("a thumbnail keeps its 60 pt at every type size — the grid reflows, the picture does not")
    func thumbnailNeverScales() {
        for size in [DynamicTypeSize.large, .accessibility2, .accessibility5] {
            #expect(ShelfGridLayout(width: 375, columns: ShelfGridLayout.columns(for: size)).cell
                    == C.Thumbnail.grid)
        }
    }

    // MARK: order and sections

    @Test("the grid renders slots in canonical order and never reorders them")
    func gridOrderIsCanonical() {
        let model = shelf()
        #expect(model.slots.map(\.canonicalKey) == model.slots.map(\.canonicalKey).sorted())
    }

    @Test("every section boundary lands on a row boundary, so a divider never bisects a row")
    func dividersLandOnRowBoundaries() {
        let model = shelf()
        let placed = model.place(columns: 5)
        for section in model.sections {
            let first = placed.first { $0.slotIndex == section.range.lowerBound }
            #expect(first?.column == 0, "a section starts a new row")
        }
    }

    @Test("each divider carries its own skeleton silhouette at 24 pt")
    func dividersCarryTheSkeleton() {
        let model = shelf()
        let dividers = model.dividers
        #expect(dividers.count == model.sections.count)
        #expect(dividers.map(\.skeleton) == model.sections.map(\.skeleton))
        #expect(dividers.allSatisfy { $0.sigilSide == C.ShelfGrid.dividerSigilSide })
        #expect(dividers.allSatisfy { $0.sigil == Sigil.family(model.band) })
    }

    // MARK: the scrubber

    @Test("the scrubber has one stop per section and its stops are section indices, not offsets")
    func scrubberStopsAreSections() {
        let model = shelf()
        let scrubber = ShelfScrubber(sections: model.sections)
        #expect(scrubber.stops.count == model.sections.count)
        #expect(scrubber.stops.map(\.section) == Array(model.sections.indices))
    }

    @Test("scrubbing snaps to the nearest section and never to a pixel between two")
    func scrubberSnaps() {
        let model = shelf()
        let scrubber = ShelfScrubber(sections: model.sections)
        for fraction in stride(from: 0.0, through: 1.0, by: 0.017) {
            let stop = scrubber.stop(atFraction: fraction)
            #expect(scrubber.stops.contains(stop))
            #expect(model.sections[stop.section].range.lowerBound == stop.slotIndex)
        }
    }

    @Test("the scrubber is adjustable and steps whole sections in both directions")
    func scrubberStepsSections() {
        let model = shelf()
        let scrubber = ShelfScrubber(sections: model.sections)
        var stop = scrubber.stops[0]
        stop = scrubber.increment(stop)
        #expect(stop.section == 1)
        stop = scrubber.decrement(stop)
        #expect(stop.section == 0)
        #expect(scrubber.decrement(scrubber.stops[0]) == scrubber.stops[0], "clamps, never wraps")
        #expect(scrubber.increment(scrubber.stops.last!) == scrubber.stops.last!)
    }

    @Test("a shelf with one section still draws a scrubber with one stop, not none")
    func singleSectionScrubber() {
        let ordered = CodexTaxonomy.order([Corpora.codexPage(band: .literal, index: 0)])
        let scrubber = ShelfScrubber(sections: CodexTaxonomy.sections(of: ordered))
        #expect(scrubber.stops.count == 1)
    }

    // MARK: visible absence and faceting

    @Test("empty slots occupy grid positions and are never collapsed out (§11.4)")
    func emptySlotsHoldTheirPositions() {
        let held = CodexTaxonomy.order((0..<6).map { Corpora.codexPage(band: .literal, index: $0) })
        let slots: [ShelfSlot] = held.enumerated().flatMap { index, page in
            index.isMultiple(of: 2)
                ? [ShelfSlot.held(page)]
                : [ShelfSlot.empty(CodexTaxonomy.canonicalKey(for: page.law))]
        }
        let model = ShelfGridModel(band: .literal, slots: slots, sections: [])
        #expect(model.slots.count == slots.count)
        #expect(model.place(columns: 5).count == slots.count)
    }

    @Test("faceting dims in place: the placement is byte-identical with and without a facet")
    func facetingNeverReflows() {
        let model = shelf()
        let before = model.place(columns: 5)
        let after = model.facetedOut(Set(model.slots.prefix(4).compactMap(\.lawKey))).place(columns: 5)
        #expect(before.map(\.slotIndex) == after.map(\.slotIndex))
        #expect(before.map(\.frame) == after.map(\.frame))
    }

    // MARK: chrome

    @Test("the shelf carries no title and no numeral (§12.9)")
    func shelfIsTitleless() {
        let bar = ShelfInstrumentBar(band: .composite, held: 812, facets: .none)
        #expect(bar.title == nil)
        #expect(bar.renderedNumerals.isEmpty)
        #expect(bar.sigil == Sigil.family(.composite))
        #expect(bar.hasPlayKey)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter ShelfGridTests`

Expect missing `ShelfGridModel`, `ShelfGridLayout`, `ShelfSlot`, `ShelfScrubber`,
`ShelfInstrumentBar`, `C.ShelfGrid`. **`facetingNeverReflows` must fail with a missing symbol, not
with unequal frames** — if it fails on frames, `facetedOut(_:)` has been written as a filter, which
is the single wrong answer this task exists to prevent.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/CodexFeature/CodexShelfView.swift` — the screen |
| create | `Modules/Sources/CodexFeature/ShelfGrid.swift` — `ShelfGridModel`, `ShelfGridLayout`, `ShelfSlot` |
| create | `Modules/Sources/CodexFeature/ShelfScrubber.swift` — `ShelfScrubber`, `ScrubberStop` |
| create | `Modules/Sources/CodexFeature/ShelfInstrumentBar.swift` |
| modify | `Modules/Sources/CodexFeature/SkeletonDivider.swift` — T09's divider, placed |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.ShelfGrid` (`gutter`, `scrubberWidth`, `dividerSigilSide`, `dividerInset`, `columnsAtAX2`) |
| create | `Modules/Tests/CodexFeatureTests/ShelfGridTests.swift` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — the empty-slot label and the scrubber label (2 of the 3 budgeted keys) |
| modify | `tests.json` — grid arithmetic, section-aligned dividers, scrubber snapping, 5 → 2 columns, no-reflow |

## Implementation notes

### `ShelfSlot` is the unit, not `CodexPage`

```swift
public enum ShelfSlot: Hashable, Sendable {
    case held(CodexPage)
    case empty(CanonicalKey)          // slot-map shelves only — T07 supplies them
}
```

An accretion shelf's slot array is all `.held`; a slot-map shelf's is `.held` and `.empty`
interleaved in canonical order. **Both take the same code path**, which is what makes §11.4's
*"a log shows what happened, a map shows what is missing"* a property of the data rather than a
branch in the view. `place(columns:)` never inspects the case.

### The grid, and where its numbers come from

`5 · 60 + 4 · 10 = 340` in 375 gives 17.5 pt margins, which §11.2 states as an arithmetic
consequence and `extension-thumbnail.md` §1 repeats. Neither number is typed in the view: the cell is
`C.Thumbnail.grid`, the gutter is `C.ShelfGrid.gutter`, and the margins are *derived* from the width
so a Pro Max at 440 pt distributes the surplus rather than pinning at 17.5. `referenceGridArithmetic`
asserts the SE case exactly because that is the case §11.2 specifies.

Use `LazyVGrid` with `GridItem(.fixed(C.Thumbnail.grid), spacing: C.ShelfGrid.gutter)` — **fixed, not
flexible**. A flexible column would stretch the thumbnail, and a thumbnail is a picture that holds
its geometry at every type size (§13.11). The surplus goes to the margins.

### Dividers land on row boundaries

A section header that appeared mid-row would put half of one skeleton beside half of another, which
is exactly the adjacency §11.2 spends canonical ordering to buy. So `place(columns:)` starts each
section on a fresh row, and the last row of a section may be short. That is the correct trade: a
partially filled row costs at most four cells of screen; a bisected section costs the reading.

Implement it as a section-per-`Section` in the `LazyVGrid` rather than by padding the slot array —
padding would put phantom indices into the scrubber's arithmetic and into VoiceOver's traversal.

### The scrubber snaps to sections, and that is the whole feature

```swift
public struct ScrubberStop: Hashable, Sendable {
    public let section: Int          // index into ShelfGridModel.sections
    public let slotIndex: Int        // sections[section].range.lowerBound
}

public struct ShelfScrubber: Sendable {
    public let stops: [ScrubberStop]
    public func stop(atFraction f: Double) -> ScrubberStop     // nearest stop, always a stop
    public func increment(_ stop: ScrubberStop) -> ScrubberStop  // clamps
    public func decrement(_ stop: ScrubberStop) -> ScrubberStop  // clamps
}
```

§11.2 calls this *"the only way a 2,063-row shelf is navigable"*, and the reason is arithmetic: at
five columns a 2,063-page shelf is 413 rows and roughly nine screens of continuous scrolling with no
landmark. Ten to forty skeleton sections give ten to forty landmarks, and the scrubber's job is to be
a picture of *those* rather than a picture of scroll offset. Consequences:

- **`stop(atFraction:)` always returns a stop.** There is no intermediate value. A drag that lands
  between two sections resolves to the nearer one on the way, not on release, so the thumb and the
  content stay in agreement.
- **Scroll position follows the scrubber; the scrubber does not follow scroll position continuously.**
  Track the top-most visible section with `ScrollPosition`/`onScrollGeometryChange` and set the
  scrubber's stop when the *section* changes. Mirroring the raw offset back into the scrubber is
  `A15` — derive, never mirror — and it produces the jitter that makes a snapping control feel broken.
- **`.adjustable` steps sections.** `accessibilityIncrement`/`Decrement` call `increment`/`decrement`,
  so VoiceOver and the thumb perform the identical operation. This is the third of `CodexShelfView`'s
  three budgeted labels.

### 5 → 2 at AX2, and nothing in between

§12.8's table gives one reflow, at `accessibility2`. There is no 4-column or 3-column intermediate:
the reason the shelf reflows at all is that at AX2 the *chrome* around the grid — the bar, the
back/facets band — has grown to the point where five columns of a fixed-size picture leaves too
little vertical room, and picking an intermediate would make the grid's density depend on a setting
in a way nothing else in the app does. Write it as a two-arm function over `DynamicTypeSize`, with
`.accessibility2` as the boundary, and let `columnsByTypeSize` pin both arms.

The thumbnail **does not scale** at any size. §13.11: *"the glyph thumbnail is fixed at 44 pt and
never scales (it is a picture, not text)"* — the same rule, and the grid answers AX by going 5 → 2
instead. `thumbnailNeverScales` is that sentence as an assertion.

### The instrument bar carries no title

§12.9: *"`CodexShelfView` and `CodexPageView` have none — a shelf is titled by its family sigil."*
So this screen's bar is exactly 44 pt forever, and it is the one place in the Codex where the
resolved-height caution does **not** bite. The bar's three slots are: leading family sigil at
`U = 24` (depictive, merged into the bar's label), centre facet state (T08's five stamps in their
current state), trailing play key at 44 × 44.

The fill arc named in §11.2's table is the same `ArcMeter` call T02 makes, at the bar's scale. Do not
add a numeral beside it — §11's preamble permits numerals in exactly three places and this is not one
(`numeral-readout.md` is the resolved site table).

### Scrolling performance

Forty-five `ExtensionThumbnail`s on screen, each a `Canvas` over 256 cells. Three things keep it a
frame:

1. `LazyVGrid`, so only visible sections build.
2. `.drawingGroup(opaque: false)` on each thumbnail (T03), so the raster is cached between frames.
3. `ExtensionSignature` computed **once per page when the shelf loads**, not per body evaluation.
   Hold `[ShelfSlot: ExtensionSignature]` on the model. `LawTable(page.law)` is ~2 µs for a
   contextual law and 2,063 of them is 4 ms — acceptable once on open, unacceptable per frame.

Measure it in the simulator on the largest band before calling the task done, and note the figure in
`PROGRESS.md`.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter ShelfGridTests` green, all thirteen tests.
- [ ] `grep -rn "Text(\|Label(\|AttributedString" Modules/Sources/CodexFeature/CodexShelfView.swift Modules/Sources/CodexFeature/ShelfInstrumentBar.swift | grep -v accessibility` returns nothing.
- [ ] `grep -rn "minimumScaleFactor" Modules/Sources/CodexFeature/` returns nothing.
- [ ] `grep -rn "GridItem(.flexible\|GridItem(.adaptive" Modules/Sources/CodexFeature/ShelfGrid.swift` returns nothing — fixed columns only.
- [ ] `grep -rn "filter\|removeAll" Modules/Sources/CodexFeature/ShelfGrid.swift | grep -i facet` returns nothing — faceting is a state, not a filter.
- [ ] The scrubber is `.adjustable` with `accessibilityIncrement`/`Decrement` wired to `increment`/`decrement` — verified by reading `ShelfScrubber`'s call site.
- [ ] `Localizable.xcstrings` gains at most **2** keys from this task (empty slot, scrubber), keeping `CodexShelfView` inside §12.9's budget of 3.
- [ ] `PROGRESS.md` records the measured open-and-scroll time for the largest band on the SE simulator.
- [ ] `tests.json` carries: grid arithmetic, section-aligned dividers, scrubber snapping and stepping, 5 → 2 columns, thumbnail-never-scales, empty slots hold position, faceting never reflows.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T04: the five-column shelf grid, skeleton dividers and the section-snapping scrubber"`

## Out of scope

- **Where empty slots come from, and which shelves have them** — **T07**. This task renders whatever slot array it is handed.
- **The facet predicate and the five stamps** — **T08**. The bar reserves the centre slot and shows their state.
- **The page** — **T05**. Tapping a thumbnail calls an injected `onOpen(CodexPage)`.
- **`Route`, the `Router` and the play key's destination** — **E17·T01/T02**.
- **The family sigil and the skeleton silhouette drawings** — **T09**.
- **The full Dynamic Type pass across every screen and the AX5 × 5-locale snapshot** — **E19·T06/T11**. This task ships only the Codex's own row of §12.8's table.
- **The shared-element transition from the Inscription into a shelf** — **E20·T08**.
