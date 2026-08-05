# T02 — Taxonomy and `CodexRootView`

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Taxonomy and browse (the first two levels) · 18 screens (screen 9, `CodexRootView`) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. The plate is `ground.raised` inside a `stroke.hairline` frame at `Radius.chrome`, the arc is `weight.body` and the sigil resolves through `env.weight(_:)`; every one of those is a token and a literal outside `Tokens/` fails hygiene check 9. It also owns the L2 rule this task creates `C.ShelfPlate` under. |
| `hunch-chrome-and-meta` | `references/shelf-plate.md` is the normative spec for all four plate states, the 44 / 127 / 172 pt internal budget, the accent-rationing rule (brass on **one** plate, the one just inscribed), and the ruling that PHOSPHOR §3's 72 pt labelled row is **superseded**. Its gotcha that `64` is a *resolved* bar height and not a constant is the single most likely bug in this task. |
| `hunch-shared-marks` | The fill arc is `ArcMeter.draw` with `style: .shelfFill`, and the sealed rim is a doubled `arc`. A plate that strokes its own arc is the drift both skills exist to stop; this task passes `value`, `total` and `scale` and lets the mark own the rest. |

`hunch-sigil-drawing` is **not** loaded here — T09 owns the eight drawings and their harness. This
task only calls `SigilRenderer.draw(.familyLiteral … .familySystemic, …)` and asserts the call.

## Objective

At the end of this task the Codex has a front door and a spine: `CanonicalKey`, `CodexTaxonomy` and
`ShelfSection` in `HunchCore` give every law a permanent, deterministic slot under
band → skeleton → canonical key, and `CodexRootView` draws the eight shelf plates that stand for the
eight bands. Before this task the archive is a set of lawKeys; after it, it is eight places, ordered,
with a picture of how full each one is and not one word anywhere on the screen.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.2 | The three levels — *"band → skeleton → canonical key"*, all textless; date is **not** a browsing axis; band is the primary shelf because canon locks one family per band, so *"eight shelves, no more, ever"*; skeleton sub-sections a shelf; canonical key orders within a section as `(attrOrdinal, cmpOrdinal, subsetBitmask)` in `fill → shape → pips → hue` order, *"deterministic, so a law's slot never moves"* |
| `GAME_DESIGN.md` | §11.2 (`CodexRootView` table) | Instrument bar `y 20–64`; eight plates `64–624`, 64 pt each + 6 pt gutter; leading 44 pt family sigil · 3 pt fill arc · trailing four most-recent 40 pt thumbnails · doubled rim when sealed; facet bar `624–667` |
| `GAME_DESIGN.md` | §11.2 | *"No global meter anywhere. A '0.3 % of 27,015' bar would be both true and useless. Only per-shelf arcs exist."* |
| `GAME_DESIGN.md` | §11.4 | The `\|H\| ≤ 512` threshold that decides linear versus log-scaled; the eight populations; sealable versus accretion |
| `GAME_DESIGN.md` | §12.2 | Screen 9's row, and the closing line: *"The Codex with zero pages draws one dashed plate and nothing else."* No empty-state copy anywhere in the app |
| `GAME_DESIGN.md` | §12.3 | Every non-play screen carries a 44 × 44 play key in the trailing corner of its instrument bar |
| `GAME_DESIGN.md` | §12.9 | `CodexRootView` is budgeted **6** VoiceOver control labels against 8 plates + 5 facet stamps + back + play — which works only if the plate label is one format string interpolating the family |
| `GAME_DESIGN.md` | §10.5, §11.9 | A family may be spoken; a **band number may not**. The shelves carry difficulty *as history*, never as a level |
| `GAME_DESIGN.md` | §5.2, §5.3 step 3 | One family per band, no reprises; the generator samples a skeleton per law, and `CodexPage.skeleton` is that index |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N40, N39 | `Codex`/`CodexShelf` take the bare domain noun; `ShelfPlate` is a `View` beside no model type of that name, so no suffix collision arises |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | The four plate states are an exhaustive `switch` with no `default:` |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files again — ordering is core, the plate is not.

Create `HunchCore/Tests/ArchiveTests/CodexTaxonomyTests.swift`:

```swift
import Testing
import Archive
import Laws                     // LawNode, LawTable
import LawGeneration            // Band, generate
import HunchTestSupport         // Corpora

@Suite("Taxonomy — band → skeleton → canonical key (§11.2)", .tags(.unit, .presubmission))
struct CodexTaxonomyTests {

    @Test("the canonical key is a pure function of the law and never of the page")
    func keyIsAFunctionOfTheLaw() {
        let page = Corpora.codexPage(band: .relational, index: 7)
        var older = page
        older.timesFound = 9
        older.bestProbes = 3
        older.burnished = true
        #expect(CodexTaxonomy.canonicalKey(for: page.law) == CodexTaxonomy.canonicalKey(for: older.law))
    }

    @Test("ordering is by (attributeOrdinal, comparatorOrdinal, subsetBitmask), in that order")
    func keyOrderIsLexicographic() {
        let a = CanonicalKey(attributeOrdinal: 0, comparatorOrdinal: 3, subsetBitmask: 0xFFFF)
        let b = CanonicalKey(attributeOrdinal: 1, comparatorOrdinal: 0, subsetBitmask: 0x0001)
        let c = CanonicalKey(attributeOrdinal: 1, comparatorOrdinal: 0, subsetBitmask: 0x0002)
        #expect(a < b)
        #expect(b < c)
        #expect([c, a, b].sorted() == [a, b, c])
    }

    @Test("a law's slot never moves when other laws are inserted — the shelf is a map, not a list",
          arguments: Band.allCases)
    func slotIsStable(_ band: Band) {
        let all = (0..<24).map { Corpora.codexPage(band: band, index: $0) }
        let target = all[11]

        let sparse = CodexTaxonomy.order(Array(all.prefix(12)))
        let dense = CodexTaxonomy.order(all)
        let sparseNeighbours = sparse.filter { $0.lawKey != target.lawKey }
            .filter { CodexTaxonomy.canonicalKey(for: $0.law) < CodexTaxonomy.canonicalKey(for: target.law) }
        let denseNeighbours = dense.filter { $0.lawKey != target.lawKey }
            .filter { CodexTaxonomy.canonicalKey(for: $0.law) < CodexTaxonomy.canonicalKey(for: target.law) }

        // The *relative* position is what §11.2 guarantees: everything ordered before it stays before it.
        #expect(Set(sparseNeighbours.map(\.lawKey)).isSubset(of: Set(denseNeighbours.map(\.lawKey))))
        #expect(dense.map(\.lawKey) == dense.sorted { CodexTaxonomy.canonicalKey(for: $0.law) < CodexTaxonomy.canonicalKey(for: $1.law) }.map(\.lawKey))
    }

    @Test("ordering is total and stable: no two distinct laws share a slot in a seeded shelf",
          arguments: Band.allCases)
    func orderingIsTotal(_ band: Band) {
        let pages = (0..<64).map { Corpora.codexPage(band: band, index: $0) }
        let ordered = CodexTaxonomy.order(pages)
        #expect(ordered.count == pages.count)
        #expect(Set(ordered.map(\.lawKey)).count == ordered.count)
        #expect(CodexTaxonomy.order(pages.shuffled(using: &Corpora.rng)).map(\.lawKey) == ordered.map(\.lawKey),
                "order() must not depend on input order")
    }

    @Test("sections are contiguous, cover the shelf exactly, and are keyed by skeleton")
    func sectionsPartitionTheShelf() {
        let pages = (0..<40).map { Corpora.codexPage(band: .pair, index: $0) }
        let ordered = CodexTaxonomy.order(pages)
        let sections = CodexTaxonomy.sections(of: ordered)

        #expect(sections.map(\.range.lowerBound) == sections.map(\.range.lowerBound).sorted())
        #expect(sections.first?.range.lowerBound == 0)
        #expect(sections.last?.range.upperBound == ordered.count)
        for (a, b) in zip(sections, sections.dropFirst()) { #expect(a.range.upperBound == b.range.lowerBound) }
        for section in sections {
            #expect(Set(ordered[section.range].map(\.skeleton)) == [section.skeleton])
        }
        #expect(Set(sections.map(\.skeleton)).count == sections.count, "one section per skeleton")
    }

    @Test("band 1 gets exactly four sections, one per attribute (§11.2)")
    func bandOneHasFourSections() {
        let pages = (0..<Band.literal.population).map { Corpora.codexPage(band: .literal, index: $0) }
        let sections = CodexTaxonomy.sections(of: CodexTaxonomy.order(pages))
        #expect(sections.count == 4)
    }

    @Test("date is not a browsing axis — no ordering function reads a find date")
    func dateIsNotAnAxis() {
        var early = Corpora.codexPage(band: .guarded, index: 3)
        var late = early
        late.firstFoundAt = early.firstFoundAt.addingTimeInterval(86_400 * 365)
        late.lastFoundAt = late.firstFoundAt
        early.firstFoundAt = .distantPast
        #expect(CodexTaxonomy.order([late, early]).map(\.lawKey) == CodexTaxonomy.order([early, late]).map(\.lawKey))
    }
}
```

Create `Modules/Tests/CodexFeatureTests/ShelfPlateTests.swift`:

```swift
import Testing
import HunchCore
@testable import CodexFeature

@Suite("Shelf plates — §11.2, §11.4, §12.2", .tags(.unit, .presubmission))
@MainActor
struct ShelfPlateTests {

    @Test("eight plates at 64 pt with a 6 pt gutter fill the reference band exactly")
    func plateColumnArithmetic() {
        let layout = CodexRootLayout(barHeight: 44, safeHeight: 647)
        #expect(layout.plates.count == Band.allCases.count)
        #expect(layout.plates.allSatisfy { $0.height == C.ShelfPlate.height })
        let span = layout.plates.count * C.ShelfPlate.height
            + layout.plates.count * C.ShelfPlate.gutter
        #expect(span == 560)
        #expect(layout.plates.first?.minY == layout.contentTop)
    }

    @Test("the plate's internal budget is 44 sigil + arc + 4×40 recents inside the content column")
    func internalBudget() {
        let plate = ShelfPlateLayout(width: Space.columnContent)
        #expect(plate.sigil.width == C.ShelfPlate.sigilSide)
        #expect(plate.recents.count == C.ShelfPlate.recentCount)
        #expect(plate.recents.allSatisfy { $0.width == C.Thumbnail.recent })
        let recentsSpan = Double(C.ShelfPlate.recentCount) * C.Thumbnail.recent
            + Double(C.ShelfPlate.recentCount - 1) * C.ShelfPlate.recentGutter
        #expect(plate.recents.span == recentsSpan)
        #expect(plate.arc.width == Space.columnContent - C.ShelfPlate.sigilSide - recentsSpan)
    }

    @Test("the four states are chosen by page count against the band's population",
          arguments: Band.allCases)
    func stateSelection(_ band: Band) {
        #expect(ShelfPlateState(band: band, held: 0, codexIsEmpty: true) == .empty)
        let partial = ShelfPlateState(band: band, held: 1, codexIsEmpty: false)
        #expect(partial == (band.isSealable ? .sealable : .accretion))
        let full = ShelfPlateState(band: band, held: band.population, codexIsEmpty: false)
        #expect(full == (band.isSealable ? .sealed : .accretion),
                "only |H| <= 512 shelves can seal (§11.4)")
    }

    @Test("an empty Codex draws ONE dashed plate and nothing else (§12.2)")
    func emptyCodexDrawsOnePlate() {
        let model = CodexRootModel(counts: [:], recents: [:], codexIsEmpty: true)
        #expect(model.plates.count == 1)
        #expect(model.plates.first?.state == .empty)
        #expect(model.plates.first?.sigil == nil, "an empty shelf has no family to name yet")
        #expect(model.facetBarIsVisible == false)
    }

    @Test("each plate names its family sigil, and no plate names a band number")
    func platesNameSigilsNotNumbers() {
        let model = CodexRootModel(counts: Dictionary(uniqueKeysWithValues: Band.allCases.map { ($0, 1) }),
                                   recents: [:], codexIsEmpty: false)
        #expect(model.plates.map(\.sigil) == Band.allCases.map { Sigil.family($0) })
        #expect(model.plates.allSatisfy { $0.renderedNumerals.isEmpty })
    }

    @Test("at most one plate draws in brass — the one just inscribed (accent rationing)")
    func brassIsRationed() {
        let counts = Dictionary(uniqueKeysWithValues: Band.allCases.map { ($0, 3) })
        let model = CodexRootModel(counts: counts, recents: [:], codexIsEmpty: false,
                                   justInscribed: .relational)
        #expect(model.plates.filter(\.isAccented).count == 1)
        #expect(model.plates.first { $0.isAccented }?.band == .relational)
        #expect(CodexRootModel(counts: counts, recents: [:], codexIsEmpty: false)
                    .plates.contains(where: \.isAccented) == false)
    }

    @Test("the arc reads the shelf's own counts and there is no global meter (§11.2)")
    func perShelfArcsOnly() {
        let counts: [Band: Int] = [.literal: 12, .exclusive: 40]
        let model = CodexRootModel(counts: counts, recents: [:], codexIsEmpty: false)
        #expect(model.plates.first { $0.band == .literal }?.arc.value == 12)
        #expect(model.plates.first { $0.band == .literal }?.arc.total == Double(Band.literal.population))
        #expect(model.globalMeter == nil)
    }

    @Test("the facet bar is pinned to the safe-area bottom and keeps a 44 pt stamp")
    func facetBarIsPinnedNotLiteral() {
        for safeHeight in [647.0, 819.0, 936.0] {
            let layout = CodexRootLayout(barHeight: 44, safeHeight: safeHeight)
            #expect(layout.facetBar.height >= C.Key.minimumSide)
            #expect(layout.facetBar.maxY == safeHeight)
            #expect(layout.plates.last!.maxY <= layout.facetBar.minY)
        }
    }

    @Test("a taller resolved instrument bar pushes the plates down, never off the bottom")
    func barHeightIsResolved() {
        let tall = CodexRootLayout(barHeight: 72, safeHeight: 647)
        #expect(tall.contentTop == tall.instrumentBar.maxY)
        #expect(tall.plates.last!.maxY <= tall.facetBar.minY)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter CodexTaxonomyTests` and
`swift test --package-path Modules --filter ShelfPlateTests`

Expect missing `CanonicalKey`, `CodexTaxonomy`, `ShelfSection`, `CodexRootLayout`,
`ShelfPlateLayout`, `ShelfPlateState`, `CodexRootModel`, `C.ShelfPlate`, `Sigil.family(_:)`. If
`bandOneHasFourSections` passes trivially because `sections(of:)` returns one section per page, the
test is not yet failing for the right reason — assert `sections.count == 4` **and** the partition
property together, as written.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/CanonicalKey.swift` — `CanonicalKey: Hashable, Comparable, Sendable` |
| create | `HunchCore/Sources/Archive/CodexTaxonomy.swift` — `canonicalKey(for:)`, `order(_:)`, `sections(of:)`, `ShelfSection` |
| create | `HunchCore/Tests/ArchiveTests/CodexTaxonomyTests.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.ShelfPlate` (height, gutter, sigilSide, recentCount, recentGutter, arcThickness) and `C.Thumbnail.recent` |
| create | `Modules/Sources/CodexFeature/CodexRootView.swift` — the screen |
| create | `Modules/Sources/CodexFeature/ShelfPlate.swift` — `ShelfPlate: View`, `ShelfPlateState`, `ShelfPlateLayout` |
| create | `Modules/Sources/CodexFeature/CodexRootLayout.swift` — `CodexRootLayout`, `CodexRootModel` |
| create | `Modules/Sources/HunchUI/SigilRenderer.swift` — the call seam only; the drawings land in T09 |
| create | `Modules/Tests/CodexFeatureTests/ShelfPlateTests.swift` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — one plate format string, one empty-shelf label (2 of the 6 budgeted keys) |
| modify | `tests.json` — canonical-key stability, section partition, empty-Codex single plate, no global meter |

## Implementation notes

### `CanonicalKey`, and where its three fields come from

```swift
public struct CanonicalKey: Hashable, Comparable, Sendable {
    public let attributeOrdinal: UInt8    // canonical fill → shape → pips → hue order, §2
    public let comparatorOrdinal: UInt8   // Comparator's own ordinal, E02·T06
    public let subsetBitmask: UInt16      // the leaf's value subset as bits

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.attributeOrdinal, lhs.comparatorOrdinal, lhs.subsetBitmask)
            < (rhs.attributeOrdinal, rhs.comparatorOrdinal, rhs.subsetBitmask)
    }
}
```

The key is computed from the law's **RNF leading leaf**, not from an arbitrary traversal. RNF already
fixes a commutative sort by `(kindOrdinal, attrOrdinal, cmpOrdinal, subsetBitmask)` (§3.4, E05·T04),
so `canonicalKey(for:)` reads the first leaf of `law.renderedNormalForm` and lifts three of those
four fields. That is the whole implementation, and it is why *"a law's slot never moves"* is a
consequence rather than a promise: RNF gives one law exactly one layout, so the leading leaf is
stable under every spelling of the same law.

**Do not tie-break on `lawKey`.** Two laws in one band with the same leading leaf are ordered by the
*next* leaf, recursively; if the whole RNF matches they are the same law and one of them does not
exist. If the recursion is needed, express it as `Comparable` on a `[CanonicalKey]` rather than
inventing a second key type.

### `sections(of:)`

`CodexPage.skeleton: UInt16` is already the index into the family's skeleton list (§11.1 — it is a
page field precisely so a shelf open is not 2,000 AST walks). So sectioning is a group-by over an
already-ordered array:

```swift
public struct ShelfSection: Hashable, Sendable {
    public let skeleton: UInt16
    public let range: Range<Int>          // into the ordered page array
}
```

Two constraints the tests pin:

- **Sections partition.** Contiguous, gapless, covering `0..<count`. That is what makes T04's
  scrubber able to snap to a section by index arithmetic and nothing else.
- **Order within a section is the canonical key, and the *sections themselves* are ordered by
  skeleton index.** The generator's skeleton list order (§5.3 step 3) is the section order; do not
  re-sort sections by size or by count, which would move a section every time a page landed.

For a **slot-map** shelf the array is not the held pages but the full slot list; that is T07's
`slotOrder(for:index:)`, and `sections(of:)` takes whichever array it is handed. Keep the signature
over `[CodexPage]` here and let T07 add the slot overload — do not pre-build it.

### The plate, region by region

`shelf-plate.md` §1 is the spec and it is complete; three things it says that are easy to lose:

1. **`64` is a resolved height, not a literal.** `CodexRootLayout` takes `barHeight` from the
   instrument bar's measured height and lays everything below relative to it. The reference table's
   `y 20–64 / 64–624 / 624–667` is *the layout at Dynamic Type Large on a 375 × 667 device*, and this
   screen carries a localized title, so a German AX5 string wraps and the bar grows.
2. **The facet bar is pinned to the safe-area bottom.** §11.2's `624–667` is 43 pt against a 44 pt
   stamp and a stated safe height of 647; the two cannot both be literal. Pin the bar to the bottom
   of the safe area with `C.Key.minimumSide` height, let the plate column take what is left, and
   record the resolution in `DECISIONS.md`. The stamps stay 44 pt, which is the constraint §12.8
   actually enforces.
3. **`.strokeBorder`, never `.stroke`.** A 343 pt plate stroked on its centre-line eats a half-weight
   into the 6 pt gutter at both ends (`hunch-chrome-and-meta` gotcha 2).

### The four states, and the one that is not a state

```swift
public enum ShelfPlateState: Hashable, Sendable {
    case empty          // the whole Codex holds zero pages — ONE plate, no sigil, dashed
    case accretion      // |H| > 512
    case sealable       // |H| <= 512, not complete
    case sealed         // |H| <= 512, complete — doubled rim
}
```

Exhaustive `switch`, no `default:` (`W29`). Note what `.empty` is: it is a property of the **Codex**,
not of a band — §12.2 says *"The Codex with zero pages draws one dashed plate and nothing else"*, so
a player who holds one band-4 page sees eight plates, seven of them at `fraction = 0`. Getting this
backwards produces eight dashed plates, which `shelf-plate.md` §6 names as the first wrong answer.

### The arc

One call, and the mark owns everything else:

```swift
ArcMeter.draw(into: context,
              track: .custom(plate.arcPath),
              value: Double(held), total: Double(band.population),
              scale: band.isSealable ? .linear : .logarithmic,
              style: .shelfFill, env: env)
```

`band.population` is `HunchCore`'s (`08 §3`'s `Band` row) and is never a constant in a view. The
notch positions for the logarithmic case belong to `ArcMeter` and are exercised by T07; this task
only has to pass the right `scale`, and `stateSelection` above is what proves it did.

### The recents

Four 40 pt thumbnails, pinned to the trailing edge, most recent leading, **depictive and never
tappable** — the whole 343 × 64 plate is one target (`shelf-plate.md` §3). Sorting is by
`lastFoundAt` descending, which is the one place a date is read on this screen and is *not* a
browsing axis: it selects which four are shown, never where anything sits.

`ExtensionThumbnail` lands in T03. Until then the recents slot draws its dashed empty socket, and
`internalBudget` asserts the geometry regardless — that is deliberate, so T03 fills a rect that
already exists.

### VoiceOver, at six labels

| Element | Traits | Label | Value |
|---|---|---|---|
| plate | `.isButton` | the shared plate format string, family interpolated | pages held, plus "sealed" when sealed |
| empty plate | `.isButton`, `.notEnabled` | the empty-shelf label | — |

**A family may be spoken; a band number may not** (§10.5, §11.9, `shelf-plate.md` §4) — "Relational",
never "Band 4". The eight family identifiers LITERAL…SYSTEMIC never enter
`Localizable.xcstrings`; the plate's label is one format string whose interpolation is a
*localized family name*, which is a separate, budgeted key set. If E19's element map has not landed,
wire the label through an `Unimplemented`-backed closure so the shape is right and the strings are
E18/E19's.

### The play key

The trailing 44 × 44 slot in the instrument bar exists here and takes `onPlay: () -> Void` as an
injected closure. **Do not import `HunchNavigation`.** E17·T01 owns `Route` and E17·T02's graph walk
asserts `distanceToPlay(.codexRoot) <= 2`; this task's only obligation is that the slot exists and is
44 × 44.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter CodexTaxonomyTests` green, all seven tests.
- [ ] `swift test --package-path Modules --filter ShelfPlateTests` green, all eight tests.
- [ ] `grep -rn "Text(\|Label(\|AttributedString" Modules/Sources/CodexFeature/CodexRootView.swift Modules/Sources/CodexFeature/ShelfPlate.swift | grep -v accessibility` returns nothing.
- [ ] `grep -rn "27015\|27,015" Modules/Sources` returns nothing — there is no global meter.
- [ ] `grep -rn "default:" HunchCore/Sources/Archive/CodexTaxonomy.swift Modules/Sources/CodexFeature/ShelfPlate.swift` returns nothing.
- [ ] `Scripts/check-source-hygiene.sh` check 9 passes — no hex, `lineWidth:` or literal `.opacity(` in the two new view files.
- [ ] `DECISIONS.md` records the facet bar pinned to the safe-area bottom rather than to `y 624`.
- [ ] `tests.json` carries: canonical-key stability, section partition, band-1's four sections, the empty-Codex single plate, plate state selection, and no-global-meter.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T02: canonical-key taxonomy, shelf sections and CodexRootView's eight plates"`

## Out of scope

- **The eight family sigil drawings, their skeleton detail and the distinctness harness** — **T09**, executed next. This task calls `SigilRenderer` and asserts the key it asks for.
- **The extension thumbnail's drawing** — **T03**. The four recent slots are laid out here and filled there.
- **The shelf grid, its dividers and the scrubber** — **T04**.
- **Slot enumeration on sealable shelves, the log arc's notches and the sealed rim's geometry** — **T07**. This task selects the scale; T07 proves the notches.
- **The facet bar's five stamps and their predicate** — **T08**. This task reserves the band and asserts its height.
- **`ArcMeter.draw` itself** — **E04·T08**.
- **`Route`, the `Router` and the play key's destination** — **E17·T01/T02**.
- **The localized plate format string and the family name keys** — **E18·T02/T03**; **E19·T01** owns the element map.
