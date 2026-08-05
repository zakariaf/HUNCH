# T07 — Slot maps versus accretion shelves

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | Slot maps vs accretion |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. The notch, the sealed rim and the dashed socket all resolve through `env.weight(_:)` and `stroke.*`; and this is where `C.ArcMeter`'s `logThreshold` and `C.ShelfPlate`'s rim gap land as L2 members rather than as numbers in a view. |
| `hunch-chrome-and-meta` | `references/shelf-plate.md` §2 owns the four states, the two arc scales and the ruling that the `\|H\| ≤ 512` threshold is **the same threshold** as the slot map and deliberately so; `references/extension-thumbnail.md` §3 owns the dashed empty socket and the rule that empty slots are never collapsed out of the grid. Both name "a global completion meter" as a wrong. |
| `hunch-shared-marks` | `references/arc-meter.md` owns `ArcMeter.draw` — the one drawing behind all five progress sites — including the `.linear` / `.logarithmic` scale enum, the notch geometry, and the reason the track is always drawn even at `fraction = 0`. A plate that computes its own logarithm is the drift this skill exists to stop. |

## Objective

At the end of this task three shelves are maps and five are logs, and the difference is a property of
`Band.population` rather than a branch somebody remembered. Bands 1, 3 and 8 enumerate every law in
their family as a permanent socket, draw a linear arc, and take a doubled rim when complete; the
other five draw only what the player holds behind a log-scaled arc notched at six milestones. Before
this task a shelf shows what happened; after it, three of them show what is missing.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.4 | The Decision: *"three shelves are **exhaustible and sealable** — bands 1 (40), 3 (108), 8 (337), total **485 pages** — and five are not. Reason: `\|H\| ≤ 512` is precisely the set of shelves where a full **slot map** (every law drawn as a permanent socket, empty ones dashed) is renderable and where a real terminal state is reachable in tens of hours rather than thousands. Bands 2, 4, 5, 6, 7 get **accretion shelves**: found pages only, log-scaled fill arc `log₂(1+n)/log₂(1+\|H\|)` with inscribed notches at n ∈ {8, 32, 128, 512, 2048, 8192}"* |
| `GAME_DESIGN.md` | §11.4 | The five properties that make this a collection: permanent identity, **visible absence** (*"a log shows what happened, a map shows what is missing"*), pages improve, intrinsic rarity, and the shelf as a picture of the law space |
| `GAME_DESIGN.md` | §11.4 | Completion: 485 pages ≈ 53 hours. *"That is the completion state, and it is the only one. There is no global 100 %, no prestige, no reset-for-a-star"* |
| `GAME_DESIGN.md` | §11.2 | *"No global meter anywhere. A '0.3 % of 27,015' bar would be both true and useless. Only per-shelf arcs exist."* And the sealed shelf's **doubled rim** on the plate |
| `GAME_DESIGN.md` | §11.3 | The serving layer's soft-avoid uses the **same** `\|H\| ≤ 512` threshold — *"the shelves you can see the holes in are exactly the shelves the server tries to fill"* |
| `GAME_DESIGN.md` | §5.2 | The eight `\|H\|` counts, enumerated exhaustively and asserted per band; they live in `Band.population` |
| `GAME_DESIGN.md` | §3.6 | The lower-band index: bands 1, 2, 3, 4, 6, 8 are enumerated to 9,767 tables behind a six-entry offset header, so a per-band slot list is a contiguous range |
| `hunch-shared-marks/references/arc-meter.md` | §2, §7 | `Scale.linear` / `.logarithmic`; the notch as a radial tick `2 ×` the track weight either side in `stroke.secondary`; `C.ArcMeter.logThreshold = 512`, *"§11.2, and the same threshold as §11.3 and §11.4"* |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | `ShelfKind` is an owned enum and every switch over it is exhaustive |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/ArchiveTests/ShelfKindTests.swift`:

```swift
import Testing
import Archive
import Laws                     // LawIndex
import LawGeneration            // Band
import HunchTestSupport

@Suite("Slot maps versus accretion — §11.4", .tags(.unit, .presubmission))
struct ShelfKindTests {

    @Test("a shelf is a slot map iff its population is at most the threshold")
    func kindFollowsPopulation() {
        for band in Band.allCases {
            let expected: ShelfKind = band.population <= ShelfKind.slotMapThreshold ? .slotMap : .accretion
            #expect(ShelfKind(band) == expected)
            #expect(band.isSealable == (ShelfKind(band) == .slotMap))
        }
    }

    @Test("exactly three shelves are slot maps, and they are bands 1, 3 and 8")
    func exactlyThreeSlotMaps() {
        let maps = Band.allCases.filter { ShelfKind($0) == .slotMap }
        #expect(maps == [.literal, .exclusive, .systemic])
        #expect(maps.count == 3)
    }

    @Test("the completion state is the sum of the three sealable populations and nothing more")
    func completionIsFourEightyFive() {
        let total = Band.allCases.filter { ShelfKind($0) == .slotMap }.reduce(0) { $0 + $1.population }
        #expect(total == 485)
        #expect(total < Band.allCases.reduce(0) { $0 + $1.population },
                "there is no global completion state — §11.4")
    }

    @Test("the threshold is the SAME constant the serving soft-avoid and the arc scale use")
    func oneThreshold() {
        #expect(ShelfKind.slotMapThreshold == C.ArcMeter.logThreshold)
    }

    @Test("a slot-map shelf enumerates its whole family in canonical order, once each",
          arguments: [Band.literal, .exclusive, .systemic])
    func slotOrderIsTheWholeFamily(_ band: Band) throws {
        let slots = try CodexTaxonomy.slotOrder(for: band, index: Corpora.index)
        #expect(slots.count == band.population)
        #expect(Set(slots).count == slots.count, "no law appears twice")
        #expect(slots == slots.sorted(), "canonical order, so a slot never moves")
    }

    @Test("an accretion shelf has no slot order — asking for one is a programming error",
          arguments: [Band.pair, .relational, .contextual, .guarded, .composite])
    func accretionHasNoSlots(_ band: Band) {
        #expect(throws: ShelfKindError.notASlotMap) {
            try CodexTaxonomy.slotOrder(for: band, index: Corpora.index)
        }
    }

    @Test("held pages land in their own slots and every other slot is empty")
    func slotsMergeWithHeldPages() throws {
        let band = Band.exclusive
        let held = (0..<9).map { Corpora.codexPage(band: band, index: $0) }
        let slots = try CodexTaxonomy.slots(for: band, held: held, index: Corpora.index)

        #expect(slots.count == band.population)
        #expect(slots.compactMap(\.lawKey).count == held.count)
        #expect(Set(slots.compactMap(\.lawKey)) == Set(held.map(\.lawKey)))
        #expect(slots.map(\.canonicalKey) == slots.map(\.canonicalKey).sorted())
        for page in held {
            let key = CodexTaxonomy.canonicalKey(for: page.law)
            #expect(slots.first { $0.canonicalKey == key }?.lawKey == page.lawKey)
        }
    }

    @Test("a shelf seals when every slot is held, and only a slot map can seal")
    func sealing() {
        for band in Band.allCases {
            #expect(ShelfSeal.isSealed(band: band, held: band.population)
                    == (ShelfKind(band) == .slotMap))
            #expect(ShelfSeal.isSealed(band: band, held: band.population - 1) == false)
        }
    }

    // MARK: the arcs

    @Test("a slot-map shelf's arc is linear and an accretion shelf's is logarithmic")
    func arcScaleFollowsKind() {
        for band in Band.allCases {
            #expect(ShelfArc(band: band, held: 1).scale
                    == (ShelfKind(band) == .slotMap ? ArcMeter.Scale.linear : .logarithmic))
        }
    }

    @Test("the linear arc is n/|H| and reaches exactly 1 at completion")
    func linearArcFraction() {
        #expect(ShelfArc(band: .exclusive, held: 27).fraction == 27.0 / 108.0)
        #expect(ShelfArc(band: .exclusive, held: 108).fraction == 1.0)
    }

    @Test("the log arc is log2(1+n)/log2(1+|H|), and shows early progress a linear arc would hide")
    func logArcFraction() {
        let band = Band.composite                      // |H| = 10,314
        let arc = ShelfArc(band: band, held: 10)
        let linear = 10.0 / Double(band.population)
        #expect(isApproximatelyEqual(arc.fraction,
                                     log2(11.0) / log2(Double(band.population) + 1),
                                     absoluteTolerance: 1e-12))
        #expect(arc.fraction > 8 * linear, "the whole reason the scale is log")
        #expect(ShelfArc(band: band, held: 0).fraction == 0)
    }

    @Test("notches sit at 8/32/128/512/2048/8192, and only those inside the band's population")
    func notchesAreInRange() {
        #expect(ShelfArc.notchMilestones == [8, 32, 128, 512, 2048, 8192])
        #expect(ShelfArc(band: .pair, held: 0).notches == [8, 32, 128, 512])          // |H| = 1,272
        #expect(ShelfArc(band: .composite, held: 0).notches == [8, 32, 128, 512, 2048, 8192])
        #expect(ShelfArc(band: .exclusive, held: 0).notches.isEmpty, "a linear arc has no notches")
    }

    @Test("no type in the archive exposes a global total — §11.2")
    func noGlobalMeter() {
        #expect(CodexIndex.self is any GlobalMeter.Type == false)
        // The real assertion is the source lint; this pins the intent for a reader.
        var index = CodexIndex()
        index.insert(lawKey: 1, band: .literal)
        #expect(index.total == 1, "total is a page count, never a fraction of 27,015")
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ShelfKindTests`

Expect missing `ShelfKind`, `ShelfKindError`, `CodexTaxonomy.slotOrder(for:index:)`,
`CodexTaxonomy.slots(for:held:index:)`, `ShelfSeal`, `ShelfArc`. **`slotOrderIsTheWholeFamily` must
fail on a missing symbol and not on a count** — a count failure means `Corpora.index` was built for
the wrong bands, and that is E05·T07's suite, not this one.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/ShelfKind.swift` — `ShelfKind`, `ShelfKindError`, `ShelfSeal`, `ShelfArc` |
| modify | `HunchCore/Sources/Archive/CodexTaxonomy.swift` — `slotOrder(for:index:)`, `slots(for:held:index:)` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.ArcMeter.logThreshold` if E04·T08 left it out; `C.ShelfPlate.sealedRimGap` |
| create | `HunchCore/Tests/ArchiveTests/ShelfKindTests.swift` |
| modify | `Modules/Sources/CodexFeature/ShelfPlate.swift` — the sealed doubled rim, and the arc call taking `ShelfArc` |
| modify | `Modules/Sources/CodexFeature/ShelfGrid.swift` — the slot array comes from `CodexTaxonomy.slots(for:held:index:)` on a slot map, and from the held pages on an accretion shelf |
| modify | `Modules/Sources/CodexFeature/Codex.swift` — `slots(for:) async -> [ShelfSlot]`, which needs the `LawIndex` |
| modify | `Scripts/check-source-hygiene.sh` — check 13, the no-global-meter grep |
| create | `Modules/Tests/CodexFeatureTests/ShelfCountAgreementTests.swift` — the gate's item 6 |
| modify | `tests.json` — slot-map membership, arc scales, notches, sealing, no global meter |

## Implementation notes

### One threshold, three consumers

```swift
public enum ShelfKind: Hashable, Sendable {
    case slotMap        // |H| <= 512 — bands 1, 3, 8
    case accretion      // |H| >  512 — bands 2, 4, 5, 6, 7

    /// §11.4, and the same constant §11.3's serving soft-avoid and §11.2's arc scale use.
    public static let slotMapThreshold = 512

    public init(_ band: Band) { self = band.population <= Self.slotMapThreshold ? .slotMap : .accretion }
}
```

`shelf-plate.md` §2 makes the coupling explicit and it is the reason to write one constant rather
than three: *"the shelves whose holes you can see are exactly the shelves the serving layer tries to
fill"*. `oneThreshold` asserts the identity against `C.ArcMeter.logThreshold`; **E11·T06's soft-avoid
must read the same symbol**, and if it currently spells 512 inline, fix it there in this task and say
so in the commit.

`ShelfKind` is derived from `Band.population` and never stored on a page. There is no `isSlotMap`
column in JSON; if `|H|` ever changed the derived answer would change with it, and a stored one would
not.

### Slot enumeration, and where the laws come from

A slot map needs **every law in the family**, not just the ones held. That set already exists:
E05·T07's `LawIndex` enumerates bands 1, 2, 3, 4, 6 and 8 behind a six-entry offset header
(40 / 1,272 / 108 / 2,322 / 5,688 / 337) *"so any prefix union is a contiguous range"* — and the three
slot-map bands are all in it.

```swift
extension CodexTaxonomy {
    /// The whole family, in canonical order. Slot-map bands only.
    /// - Throws: `ShelfKindError.notASlotMap` for bands 2, 4, 5, 6, 7.
    public static func slotOrder(for band: Band, index: LawIndex) throws -> [CanonicalKey]

    /// The slot array a slot-map shelf renders: every law, with the held ones filled.
    public static func slots(for band: Band, held: [CodexPage], index: LawIndex) throws -> [ShelfSlotKey]
}
```

`ShelfSlotKey` is `(canonicalKey, lawKey?)` — core, so the merge is testable on the host. T04's
`ShelfSlot` is the app-side pairing with a `CodexPage`; keep them separate rather than putting a
`CodexPage` into a core enum that the grid will then have to unwrap twice.

**Throw for an accretion band, do not return the held set.** An accretion shelf has no slot order, and
returning one silently would put 10,314 dashed sockets on band 7 — nine thousand screens of nothing,
which §11.4 spends its whole Decision avoiding. `accretionHasNoSlots` is the assertion; `W29` keeps
the switch exhaustive so a ninth band could not slip past it.

**Cost.** Band 8 is 337 slots; band 2 would be 1,272 but is not a slot map. The merge is a sorted-key
join over at most 337 entries and is microseconds. The `LawIndex` itself is `Corpora.index` in tests
(a `static let` of an immutable `Sendable` value, built once for the whole suite) and
`LawIndexLoader`'s cached value in the app — **do not build it per shelf open**.

### Sealing, and the doubled rim

```swift
public enum ShelfSeal {
    public static func isSealed(band: Band, held: Int) -> Bool {
        ShelfKind(band) == .slotMap && held >= band.population
    }
}
```

Only a slot map can seal (§11.4) — an accretion shelf's terminal state is thousands of hours away and
drawing one would be a promise the design declines to make. The **doubled rim** is the plate's
drawing (`shelf-plate.md` §2), a second concentric outline at `C.ShelfPlate.sealedRimGap`; it is
*geometry*, so it survives greyscale, High Contrast and Differentiate Without Colour with no
substitution. The family sigil lights to `stroke.primary` and gains no rim of its own
(`family-sigils.md` §4).

### The two arcs, and who computes them

```swift
public struct ShelfArc: Hashable, Sendable {
    public let band: Band
    public let held: Int
    public var scale: ArcMeter.Scale { ShelfKind(band) == .slotMap ? .linear : .logarithmic }
    public var fraction: Double         // for tests; the view passes value/total, not this
    public var notches: [Int]           // milestones inside this band's population
    public static let notchMilestones = [8, 32, 128, 512, 2048, 8192]
}
```

The **view passes `value`, `total` and `scale`** to `ArcMeter.draw` and lets the mark compute the
fraction — `arc-meter.md` §5 states that explicitly, *"so a call site never computes a logarithm and
the `|H| ≤ 512` rule is expressed once, here."* `ShelfArc.fraction` exists so the *test* can assert
the arithmetic without rasterising; the view must not read it. If `/simplify` proposes deleting it,
keep it and say why in the commit.

Why log at all: on a 10,314-law shelf a linear arc sits under 1 % for months and reads as broken. The
log arc shows the first ten finds. The notches say the scale is not linear, which is the honest way to
draw a non-linear meter without a legend — and there is no legend, because there is no text.

`notchesAreInRange` pins the filtering: a notch at 8,192 on a 1,272-law shelf would be off the end of
its own track.

### No global meter, enforced

§11.2 is unambiguous and `shelf-plate.md` §6 repeats it as a wrong. Two mechanisms:

1. **Nothing exposes a global fraction.** `CodexIndex.total` is a page *count*, used by §9.10's mode
   gates (≥ 5 pages, ≥ 8 pages) and by `StatisticsView`'s "pages" row (**E16·T11**, a labelled numeral
   on the one screen where numerals live). It is never divided by anything.
2. **Hygiene check 13**, added here:

```sh
# 13. No global completion meter (§11.2). A shelf arc is per band; there is no total.
if grep -rnE 'allCases[^\n]*(population|\.total)[^\n]*(reduce|sum)|27[,_]?015' \
      Modules/Sources HunchCore/Sources --include='*.swift' \
      | grep -v 'ShelfKindTests'; then
  echo "error: a global completion meter — §11.2 forbids it"; exit 1
fi
```

The test file is exempt because `completionIsFourEightyFive` sums three populations on purpose, to
assert that 485 is the completion state and that it is **not** 27,015.

### The gate's item 6: counts and arcs agree with the index

`Modules/Tests/CodexFeatureTests/ShelfCountAgreementTests.swift`:

```swift
@Test("after a scripted corpus and a relaunch, plate arc == index count == shelf pages, per band")
func countsAgreeAfterRelaunch() async {
    let store = RecordingPersistenceStore()
    let codex = Codex(store: store)
    await codex.load()
    for step in 0..<120 { _ = await codex.inscribe(Corpora.find(band: .allCases[step % 8],
                                                               index: step % 11)) }

    let relaunched = Codex(store: store)
    await relaunched.load()
    let model = CodexRootModel(counts: relaunched.counts, recents: [:], codexIsEmpty: false)
    for band in Band.allCases {
        let plate = model.plates.first { $0.band == band }!
        let shelf = await relaunched.shelf(band)
        #expect(Int(plate.arc.value) == relaunched.count(band))
        #expect(shelf.pages.count == relaunched.count(band))
        #expect(plate.state == (ShelfSeal.isSealed(band: band, held: shelf.pages.count)
                                ? .sealed
                                : (ShelfKind(band) == .slotMap ? .sealable : .accretion)))
    }
}
```

The relaunch is what makes this worth writing: it proves the resident index was **written back**
(T06's `05 R12` ordering) rather than only mutated in memory, which is the failure that would show up
as a wrong arc on the second launch and nowhere in a single-process test.

### Rendering an empty slot

T03 already ships the `.emptySlot` state (a dashed socket, unlit, no grid) and T04 already places
slots without inspecting the case. This task's only rendering work is the sealed rim and the notch
positions; the holes appear as a consequence of `slots(for:held:index:)` returning
`band.population` entries instead of `held.count`.

**Do not collapse empty slots out of the grid**, and do not let a facet do it either (T08) —
visible absence is the point.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ShelfKindTests` green, all thirteen tests.
- [ ] `swift test --package-path Modules --filter ShelfCountAgreementTests` green.
- [ ] `grep -rn "512" HunchCore/Sources Modules/Sources --include=*.swift | grep -v "slotMapThreshold\|logThreshold\|byteBudget"` returns nothing.
- [ ] `grep -rn "log2\|\.logarithm" Modules/Sources/CodexFeature/` returns nothing — the view never computes a fraction.
- [ ] `Scripts/check-source-hygiene.sh` check 13 is present and has been demonstrated to fail on a planted `Band.allCases.reduce(0) { $0 + $1.population }` in a view before being reverted.
- [ ] E11·T06's soft-avoid reads `ShelfKind.slotMapThreshold` rather than a literal — `grep -rn "slotMapThreshold" HunchCore/Sources/Ladder/` returns a hit.
- [ ] `grep -rn "default:" HunchCore/Sources/Archive/ShelfKind.swift` returns nothing.
- [ ] `tests.json` carries: slot-map membership is exactly bands 1/3/8, one threshold across three consumers, slot order covers the family once, accretion throws, sealing, the two arc scales, the log fraction, and notch filtering.
- [ ] The fast suite is still under 10 s — `slotOrder` at band 8 runs 337 entries and must not rebuild `Corpora.index`.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T07: ShelfKind, slot enumeration on bands 1/3/8, the two arc scales and the no-global-meter check"`

## Out of scope

- **`ArcMeter.draw` itself, its track cases, its notch drawing and its `Style` enum** — **E04·T08**.
- **`LawIndex`'s construction, its offset header and `LawIndexLoader`** — **E05·T07**. This task consumes it.
- **The serving layer's soft-avoid and the 512-most-recent ring** — **E11·T06**. This task only makes it share the constant.
- **The dashed empty socket's drawing** — **T03**; **its placement in the grid** — **T04**.
- **The facet bar** — **T08**. A facet must not collapse a slot either, and T08 asserts it.
- **The `StatisticsView` "pages" row** — **E16·T11**, the one screen where a page count is a numeral.
- **The mode gates that read `pageCount`** — **E17·T04**, set once in §9.10.
