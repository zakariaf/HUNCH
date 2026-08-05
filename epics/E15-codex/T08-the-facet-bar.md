# T08 — The facet bar

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P2 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | Facet bar |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. Each stamp is a 44 pt key with its sigil at `U = 24`; the active state is a ground step on the **key** plus an ink step on the **sigil**, both tokens, and the disabled state is `Opacity.disabled` — none of which may be typed as a number. |
| `hunch-sigil-drawing` | `references/codex-facet-stamps.md` is the normative spec for all five stamps, and it carries three rulings this task must not re-litigate: the **no-NOT rule** (a stamp draws the thing it retains, never a negation of what it excludes), `facet.attributes` as a 2 × 2 quad of blank notches rather than four `AttributeHeaderView`s, and the fact that the bar is **full at five**. The write-back contract from `references/drawing-a-new-sigil.md` §5 applies again. |
| `hunch-chrome-and-meta` | `references/key.md` owns the 44 pt stamp rectangle and the six `KeyState` cases the stamp sits inside; `references/extension-thumbnail.md` §3 owns the ruling that faceting **dims in place and never reflows the grid**, which is the invariant this task's predicate must not be able to violate. |

## Objective

At the end of this task a shelf can be read through five questions without a word: which mode found
it, was it found clean, was it the Anomaly, which attributes it names, and did it earn three marks.
Each is a 44 pt stamp; together they compose one predicate; and applying any of them dims pages in
place rather than reflowing the grid, so the shelf stays a picture of the law space instead of
becoming a result list.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.2 (`CodexRootView` table) | *"facet bar · 5 stamps at 44 pt: mode (cycles through 4 sigils + off), unfractured-only, anomaly-only, attribute-participation (four ramp headers), 3-marks-only"* |
| `GAME_DESIGN.md` | §11.2 (`CodexShelfView` table) | The shelf's instrument bar carries **facet state** in the same stamps |
| `GAME_DESIGN.md` | §11.2 | Canonical-key order is permanent — *"a law's slot never moves"* — which is why a facet may dim but may not reorder |
| `GAME_DESIGN.md` | §11.4 | Visible absence: empty slots are drawn on slot-map shelves and are not collapsed out, by a facet or by anything else |
| `GAME_DESIGN.md` | §3.1 | *"there is no `NOT` node in the AST or the UI … a negation operator is the single hardest thing to render unambiguously without text."* That constraint reaches the facet bar |
| `GAME_DESIGN.md` | §11.1 | The page fields a facet reads: `firstFoundMode` / `modesSeen`, `unfractured`, `anomalyDay`, `bestMarks` |
| `GAME_DESIGN.md` | §12.9 | `CodexRootView` is budgeted **6** VoiceOver control labels; the five facets consume five of them. A sixth facet costs a catalog key against an asserted 250 |
| `GAME_DESIGN.md` | §12.8 | ≥ 44 × 44, ≥ 8 pt between independent targets, no long-press and no context menu |
| `hunch-sigil-drawing/references/codex-facet-stamps.md` | §1–§7 | The four new drawings plus the off state, the six per-stamp states, the no-NOT rule, the VoiceOver table, and the ruling that `facet.attributes`' 16 participation subsets are **one** drawing with a state parameter |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29, W28 | The facet set is one value, not five parallel `Bool`s scattered across two screens |

## TDD — the test comes first

**Step 1 — write the failing test.** The predicate is core; the stamps are not.

Create `HunchCore/Tests/ArchiveTests/CodexFacetTests.swift`:

```swift
import Testing
import Archive
import Glyphs                   // Glyph.Attribute
import LawGeneration            // Band, Mode
import HunchTestSupport

@Suite("The facet predicate — §11.2", .tags(.unit, .presubmission))
struct CodexFacetTests {

    private func page(mode: Mode = .probe, unfractured: Bool = true,
                      anomalyDay: Int64? = nil, marks: UInt8 = 2,
                      band: Band = .relational, index: Int = 0) -> CodexPage {
        var p = Corpora.codexPage(band: band, index: index)
        p.firstFoundMode = mode
        p.modesSeen = [mode]
        p.unfractured = unfractured
        p.anomalyDay = anomalyDay
        p.bestMarks = marks
        return p
    }

    @Test("no facet active admits every page")
    func emptyFacetsAdmitEverything() {
        let facets = CodexFacets.none
        #expect(facets.isEmpty)
        for marks in UInt8(1)...3 {
            #expect(facets.admits(page(marks: marks)))
        }
    }

    @Test("the mode facet matches modesSeen, not only firstFoundMode")
    func modeFacetReadsModesSeen() {
        var p = page(mode: .probe)
        p.modesSeen = [.probe, .echo]
        #expect(CodexFacets(mode: .echo).admits(p))
        #expect(CodexFacets(mode: .drift).admits(p) == false)
    }

    @Test("unfractured-only retains the unfractured, and draws no negation of the fractured")
    func unfracturedFacet() {
        #expect(CodexFacets(unfracturedOnly: true).admits(page(unfractured: true)))
        #expect(CodexFacets(unfracturedOnly: true).admits(page(unfractured: false)) == false)
    }

    @Test("anomaly-only retains pages with an anomalyDay")
    func anomalyFacet() {
        #expect(CodexFacets(anomalyOnly: true).admits(page(anomalyDay: 20_431)))
        #expect(CodexFacets(anomalyOnly: true).admits(page(anomalyDay: nil)) == false)
    }

    @Test("3-marks-only retains bestMarks == 3 and nothing lower")
    func threeMarksFacet() {
        #expect(CodexFacets(threeMarksOnly: true).admits(page(marks: 3)))
        #expect(CodexFacets(threeMarksOnly: true).admits(page(marks: 2)) == false)
    }

    @Test("attribute participation reads the law's live attributes, and is a subset test")
    func attributeFacet() {
        let p = Corpora.codexPage(band: .pair, index: 0)
        let participating = CodexFacets.participatingAttributes(of: p.law)
        #expect(participating.isEmpty == false)

        #expect(CodexFacets(attributes: participating).admits(p))
        #expect(CodexFacets(attributes: [participating.first!]).admits(p))
        let absent = Set(Glyph.Attribute.allCases).subtracting(participating)
        if let missing = absent.first {
            #expect(CodexFacets(attributes: [missing]).admits(p) == false)
        }
    }

    @Test("active facets compose with AND, in any order")
    func facetsCompose() {
        let p = page(mode: .drift, unfractured: true, anomalyDay: 7, marks: 3)
        var facets = CodexFacets.none
        facets.mode = .drift
        facets.unfracturedOnly = true
        facets.anomalyOnly = true
        facets.threeMarksOnly = true
        #expect(facets.admits(p))

        var fails = facets
        fails.threeMarksOnly = true
        #expect(fails.admits(page(mode: .drift, anomalyDay: 7, marks: 2)) == false)
    }

    @Test("a facet that would return an empty set is reported, so its stamp can disable")
    func emptinessIsReported() {
        let pages = [page(marks: 1), page(marks: 2, index: 1)]
        #expect(CodexFacets.none.wouldBeEmpty(.threeMarks, over: pages))
        #expect(CodexFacets.none.wouldBeEmpty(.unfractured, over: pages) == false)
    }

    @Test("the facet set is Codable and survives a round trip, so a shelf keeps its filter")
    func facetsRoundTrip() throws {
        var facets = CodexFacets.none
        facets.mode = .sieve
        facets.attributes = [.shape, .hue]
        let decoded = try JSONDecoder().decode(CodexFacets.self, from: JSONEncoder().encode(facets))
        #expect(decoded == facets)
    }
}
```

Create `Modules/Tests/CodexFeatureTests/FacetBarTests.swift`:

```swift
import Testing
import HunchCore
@testable import CodexFeature

@Suite("The five facet stamps — §11.2, no-NOT", .tags(.unit, .presubmission))
@MainActor
struct FacetBarTests {

    @Test("there are exactly five stamps, each 44 pt with its sigil at 24")
    func fiveStamps() {
        let bar = FacetBarModel(facets: .none, shelf: [])
        #expect(bar.stamps.count == 5)
        #expect(bar.stamps.allSatisfy { $0.side == C.Key.minimumSide })
        #expect(bar.stamps.allSatisfy { $0.sigilSide == C.FacetBar.sigilSide })
    }

    @Test("the mode stamp cycles four mode sigils plus off, and returns to off")
    func modeStampCycles() {
        var bar = FacetBarModel(facets: .none, shelf: [])
        #expect(bar.modeStamp.sigil == .facetModeOff)
        let expected: [Sigil] = [.modeProbe, .modeDrift, .modeEcho, .modeSieve, .facetModeOff]
        for sigil in expected {
            bar.cycleMode()
            #expect(bar.modeStamp.sigil == sigil)
        }
        #expect(bar.facets.mode == nil, "a full cycle returns to off")
    }

    @Test("the four other stamps draw the thing they retain and never a negation")
    func stampSigils() {
        let bar = FacetBarModel(facets: .none, shelf: [])
        #expect(bar.stamps.map(\.sigil) == [
            .facetModeOff, .facetUnfractured, .facetAnomaly, .facetAttributes, .facetThreeMarks,
        ])
        #expect(bar.stamps.allSatisfy { $0.drawsNegation == false })
    }

    @Test("the attribute stamp has 16 renderings of ONE drawing, not 16 sigils")
    func attributeStampIsOneDrawing() {
        for subset in Glyph.Attribute.allCases.powerSet {
            var facets = CodexFacets.none
            facets.attributes = Set(subset)
            let stamp = FacetBarModel(facets: facets, shelf: []).attributeStamp
            #expect(stamp.sigil == .facetAttributes)
            #expect(stamp.filledQuadrants == Set(subset).count)
        }
    }

    @Test("a stamp whose facet would return an empty set is disabled, not hidden")
    func emptyFacetDisablesItsStamp() {
        let pages = (0..<6).map { i -> CodexPage in
            var p = Corpora.codexPage(band: .pair, index: i)
            p.bestMarks = 1
            return p
        }
        let bar = FacetBarModel(facets: .none, shelf: pages)
        let stamp = bar.stamps.first { $0.sigil == .facetThreeMarks }!
        #expect(stamp.isEnabled == false)
        #expect(stamp.isVisible, "disabled, never hidden — the bar has a fixed five")
    }

    @Test("applying a facet dims in place: the grid placement is unchanged (§11.2)")
    func facetingNeverReflows() {
        let pages = CodexTaxonomy.order((0..<20).map { Corpora.codexPage(band: .pair, index: $0) })
        let model = ShelfGridModel(band: .pair, slots: pages.map(ShelfSlot.held),
                                   sections: CodexTaxonomy.sections(of: pages))
        var facets = CodexFacets.none
        facets.threeMarksOnly = true

        let before = model.place(columns: 5)
        let after = model.applying(facets).place(columns: 5)
        #expect(before.map(\.slotIndex) == after.map(\.slotIndex))
        #expect(before.map(\.frame) == after.map(\.frame))
        #expect(after.contains { $0.state == .facetedOut })
    }

    @Test("a facet never removes an empty slot from a slot-map shelf (§11.4)")
    func facetsNeverCollapseHoles() {
        let slots: [ShelfSlot] = [
            .held(Corpora.codexPage(band: .literal, index: 0)),
            .empty(CanonicalKey(attributeOrdinal: 1, comparatorOrdinal: 0, subsetBitmask: 0b11)),
        ]
        var facets = CodexFacets.none
        facets.anomalyOnly = true
        let model = ShelfGridModel(band: .literal, slots: slots, sections: []).applying(facets)
        #expect(model.slots.count == 2)
        #expect(model.slots[1].isEmptySlot)
    }

    @Test("the bar shows the same five stamps on the root and on a shelf")
    func barIsSharedBetweenScreens() {
        let root = FacetBarModel(facets: .none, shelf: [])
        let shelf = ShelfInstrumentBar(band: .pair, held: 12, facets: .none).facetState
        #expect(shelf.map(\.sigil) == root.stamps.map(\.sigil))
    }

    @Test("no stamp adds a Localizable key: mode names are wordmarks and attribute names exist")
    func noNewCatalogKeys() {
        let bar = FacetBarModel(facets: .none, shelf: [])
        #expect(bar.stamps.allSatisfy { $0.labelKey == Loc.Key.codexFacet })
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter CodexFacetTests` and
`swift test --package-path Modules --filter FacetBarTests`

Expect missing `CodexFacets`, `FacetBarModel`, `Sigil.facet*`, `C.FacetBar`,
`ShelfGridModel.applying(_:)`. **`facetingNeverReflows` must fail on a missing symbol** — if it fails
on unequal frames, `applying(_:)` was written as a filter and the whole shelf premise is broken.

**Step 3 — implement** the minimum that turns it green. Run the sigil harness **first**:

```bash
d=.claude/skills/hunch-sigil-drawing
node $d/scripts/check-sigil-distinctness.js                 # must exit 0 with all 22 keys
node $d/scripts/check-sigil-distinctness.js --json > HunchCore/Tests/SigilsTests/Fixtures/sigils.json
```

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/CodexFacets.swift` — `CodexFacets`, `Facet`, `participatingAttributes(of:)` |
| create | `HunchCore/Tests/ArchiveTests/CodexFacetTests.swift` |
| modify | `HunchCore/Sources/Sigils/Sigil.swift` — the five `facet.*` cases and their transcribed coordinates |
| modify | `HunchCore/Tests/SigilsTests/Fixtures/sigils.json` — regenerate |
| create | `Modules/Sources/CodexFeature/FacetBar.swift` — `FacetBar: View`, `FacetBarModel`, `FacetStamp` |
| modify | `Modules/Sources/CodexFeature/CodexRootView.swift` — the bar T02 reserved |
| modify | `Modules/Sources/CodexFeature/ShelfInstrumentBar.swift` — facet state in the same five stamps |
| modify | `Modules/Sources/CodexFeature/ShelfGrid.swift` — `applying(_ facets: CodexFacets) -> ShelfGridModel` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.FacetBar` (`sigilSide`, `gutter`) |
| create | `Modules/Tests/CodexFeatureTests/FacetBarTests.swift` |
| modify | `tests.json` — predicate composition, no-reflow, no-collapsed-holes, the attribute stamp's one drawing |

## Implementation notes

### `CodexFacets` — one value, not five `Bool`s in two views

```swift
public struct CodexFacets: Hashable, Codable, Sendable {
    public var mode: Mode?                       // nil = off; the stamp cycles probe → drift → echo → sieve → off
    public var unfracturedOnly = false
    public var anomalyOnly = false
    public var attributes: Set<Glyph.Attribute> = []
    public var threeMarksOnly = false

    public static let none = CodexFacets()
    public var isEmpty: Bool { … }

    public func admits(_ page: CodexPage) -> Bool { … }          // AND over the active facets
    public func wouldBeEmpty(_ facet: Facet, over pages: [CodexPage]) -> Bool { … }

    public static func participatingAttributes(of law: LawNode) -> Set<Glyph.Attribute>
}
```

`W28`: five `Bool`s plus an optional plus a set, threaded separately through `CodexRootView` and
`CodexShelfView`, is six things to keep in step across two screens. One `Codable` value also means a
shelf keeps its filter across a push and back with no extra plumbing, which `facetsRoundTrip` pins.

**The mode facet reads `modesSeen`, not `firstFoundMode`.** A law first found in PROBE and later
re-found in DRIFT is a DRIFT page too — §11.1 keeps both fields precisely so the question "have I
ever found this in DRIFT?" is answerable. `modeFacetReadsModesSeen` is that reading, and it is the
one a careless implementation gets wrong.

**`participatingAttributes(of:)` walks the AST**, not the table. The law's *live* attributes are its
pivotal ones (G6, E05·T05), and they are already computable — reuse that function rather than
inferring participation from the extension, which would count an attribute a constant-folded leaf
mentioned.

### The five stamps, and the no-NOT rule

| Key | §11.2's clause | Verb | Drawing |
|---|---|---|---|
| `facet.mode.off` | "…+ off" | `contain` | one ring at the ring modulus, empty — the throat with nothing in it, which is *any mode* |
| `facet.unfractured` | "unfractured-only" | `contain` | the Codex page frame, closed: a rect with a filled closure node at its top-leading corner |
| `facet.anomaly` | "anomaly-only" | `double` | two concentric arcs with a gap — the doubled rim an anomaly page takes |
| `facet.attributes` | "attribute-participation" | `quad` | four blank notch rects in a 2 × 2 quad; participating attributes fill |
| `facet.threeMarks` | "3-marks-only" | `count` | three Seal-mark bars at `verb` weight, no baseline |

The mode stamp has **no drawing of its own**: it displays `mode.probe` / `mode.drift` / `mode.echo` /
`mode.sieve` or `facet.mode.off`. That is why the bar has five stamps and this task adds four
drawings plus an off state.

**§3.1's no-NOT constraint reaches the facet bar.** A stamp draws the thing it **retains**, never a
negation of what it excludes: "unfractured-only" is a closed frame, not a crossed-out fracture;
"anomaly-only" is the anomaly rim, not a struck-through calendar. There is no slash, no cross and no
prohibition ring anywhere in the set — the cancel hatch belongs to an unlit ramp cell and means *not
admitted*, which is a different sentence. `stampSigils` asserts `drawsNegation == false` for all
five, which is a property the `SIGILS` entry carries and the harness already checked.

**`facet.attributes` is one drawing with 16 renderings.** The filled/empty distinction is **ink,
never opacity** — full versus none — because this is the one sigil whose cell pattern is
*state-bearing* rather than depictive, and a live ramp's unlit-cell treatment plus a cancel hatch is
unreadable in a quadrant of about 12 pt. Two channels (position, fill), no accent. A new participation
subset is **not a new sigil** and does not go in the catalogue.

### States, and disabled-not-hidden

Six per stamp; four of them are `KeyState`'s and are not this task's to re-enumerate
(`hunch-chrome-and-meta/references/key.md` §3 is the one home). The two that are:

| State | Drawing |
|---|---|
| cycling (mode stamp only) | swaps between the four mode sigils and `facet.mode.off` |
| partial (`facet.attributes` only) | 1–3 of the four notches filled |

A stamp whose facet would return an empty set is `disabled` — `Opacity.disabled` over the whole mark
— and **not hidden**. The bar has a fixed five; a bar whose stamp count changed with the shelf's
contents would be a different bar on every screen and would make the fifth stamp's position
unlearnable. `emptyFacetDisablesItsStamp` asserts `isVisible` alongside `isEnabled == false`.

Under Reduce Motion the mode stamp's cycle is an instant swap inside the default crossfade; at normal
motion it is the same crossfade at `Dur.crossfade`. Nothing translates, scales or rotates, so
§13.7.4 needs no new row.

### Dimming in place is the whole constraint

```swift
extension ShelfGridModel {
    /// Marks non-admitted slots `.facetedOut`. It does **not** filter, sort or reindex.
    public func applying(_ facets: CodexFacets) -> ShelfGridModel
}
```

§11.2 fixes canonical order so *"a law's slot never moves"*, and that guarantee is what makes the
shelf a picture of the law space rather than a result list. A filter that reflowed would move every
slot on every facet change and destroy the adjacency that puts near-neighbours in extension space
side by side. Dimming also keeps the *shape* of what the facet excluded visible, which is
information.

Two consequences the tests pin:

- `place(columns:)` is byte-identical before and after — same indices, same frames.
- **Empty slots are never removed by a facet** either. An empty slot has no page and therefore
  satisfies no facet, so the naive predicate would delete every hole the moment any facet turned on,
  and §11.4's *"a map shows what is missing"* would evaporate at the first tap.
  `facetsNeverCollapseHoles` is the guard: a facet applies to `.held` slots only, and `.empty` slots
  pass through untouched.

### VoiceOver, at five labels and zero new keys

| Element | Traits | Label | Value |
|---|---|---|---|
| mode stamp | `.button`, `.isSelected` when not off | the shared facet label | the mode wordmark, or "off" |
| unfractured, anomaly, 3-marks | `.button`, `.isSelected` when active | the shared facet label | "on" / "off" |
| attribute stamp | `.button`, `.isSelected` when any attribute participates | the shared facet label | the participating attributes, from the four existing attribute-name keys |

Mode names are **wordmarks** and cost nothing; attribute names already exist in the catalog for the
glyph label (§13.10). **No new key is needed for any stamp**, which is what keeps `CodexRootView`
inside §12.9's budget of six — five facets plus one shared plate format string.

### The bar is full at five

§11.2 fixes the count, §12.9 budgets five VoiceOver keys against an asserted 250-key catalog, and
`drawing-a-new-sigil.md` §6 works a sixth facet ("duplicates only") through the procedure and lands
on **two** semantic collisions in a row — `repeat` over `ring`+`arc` is `mode.echo`, `double` over
`arc` is `facet.anomaly`. That is the signal that the set is closed. If a sixth is ever wanted, the
catalog key is budgeted first and the collision is resolved before a pixel is drawn.

### Write-back, again

Adding the five `facet.*` cases to `Sigil` is rows 3 and 4 of the same contract T09 executed: the
`case` **and its transcribed coordinates** from `SIGILS`, then regenerate `sigils.json`. The CI
freshness diff and `catalogueMatchesTheHarness` are what stop the Swift forking. Do not hand-edit
either artefact.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter "CodexFacetTests|SigilCatalogueTests"` green.
- [ ] `swift test --package-path Modules --filter FacetBarTests` green, all nine tests.
- [ ] `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` exits 0 and the `--json` freshness diff is empty.
- [ ] `grep -rn "filter\|removeAll\|sorted" Modules/Sources/CodexFeature/ShelfGrid.swift | grep -i facet` returns nothing.
- [ ] `grep -rn "slash\|cross\|prohibit\|strikethrough" HunchCore/Sources/Sigils/Sigil.swift` returns nothing in the `facet.*` region — no negation is drawn.
- [ ] `Localizable.xcstrings` key count is unchanged by this task, and `CodexRootView` is still at six control labels.
- [ ] `grep -c "case facet" HunchCore/Sources/Sigils/Sigil.swift` reports 5.
- [ ] `tests.json` carries: facet composition, mode reads `modesSeen`, attribute participation from the AST, the empty-set disable, dimming never reflows, and holes are never collapsed.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T08: the five facet stamps, one AND-composed predicate and dimming in place"`

## Out of scope

- **A sixth facet.** The bar is full at five (§11.2, §12.9). The worked rejection is `drawing-a-new-sigil.md` §6.
- **The four `mode.*` sigils the mode stamp displays** — **E12·T05 / E17·T04**.
- **The eight `family.*` sigils** — **T09**.
- **`KeyState`'s six cases and the 44 pt key rectangle** — **E04**/`hunch-chrome-and-meta`; this task places a key, it does not define one.
- **Sorting the eight plates, or faceting the shelf *list*** — the facet bar filters *within* a shelf, never the shelf list (`shelf-plate.md` §6).
- **Persisting the facet set across launches.** It is `Codable` so a push-and-back keeps it; whether it survives a cold launch is `@SceneStorage`'s question and belongs to **E17·T01**.
- **`participatingAttributes` as a *Profile* signal.** The five axes are **E16·T05**; this is a filter, not a measurement.
