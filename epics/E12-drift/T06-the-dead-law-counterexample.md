# T06 — The dead-law counterexample

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Dead-law counterexample (DRIFT) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | E06·T08 was written to be *extended here* — it takes the candidate set as an internal parameter defaulting to "all disagreements" precisely so step 0 can be layered in front without forking `select`. This skill owns the rule that says a second copy of the four-step selection is the failure, and it is the only real risk in this task. |
| `hunch-shared-marks` | `references/verdict-ring.md` owns the doubled and **split** ring — the exact drawing a twin already uses when its two verdicts differ. The dead-law counterexample renders as that mark and must not author a third ring; the skill is the proof that the drawing already exists and what its states are. |

`hunch-bench-instruments` is **not** loaded: `references/counterexample.md`'s rise, two rings, dock and
auto-collapse are E09·T09's and are reused unchanged. This task changes *which glyph*, never *how it
arrives*.

## Objective

At the end of this task a post-hinge declaration of the dead law is answered with a counterexample the
player has already seen: a glyph from their own ribbon whose verdict differs under `L₁` and `L₂`,
selected deterministically and rendered as the twin ring they learned in PROBE. When the disagreement
set holds no ribbon member, selection falls through to canon §4.5's ordinary four steps with no special
case anywhere.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.6 | The whole task: step 0 inserted before canon §4.5's selection, the preference, both tie-breaks, the twin-ring rendering, the fall-through, and the DEAD-HINGE guarantee |
| `GAME_DESIGN.md` | §4.5 | Canon's four steps — disagreements → prefer false negatives → minimise attribute-space Hamming distance to the nearest ribbon glyph → lowest `glyphID`; and that the law is never revealed |
| `GAME_DESIGN.md` | §6.6 | Layer 4, the split doubled ring: *"a rendered contradiction; no colour required, no text possible"* — the meaning this task borrows rather than teaches |
| `GAME_DESIGN.md` | §6.8 | The counterexample is **not** a probe: it does not increment `probesUsed`, never becomes `prev`, and docks below the ribbon as a marginal island |
| `GAME_DESIGN.md` | §7.11 | DEAD-HINGE — *"the counterexample is guaranteed to come from `D`, so the mode delivers its lesson at least once per round"* |
| `GAME_DESIGN.md` | §3.6 | Extension identity, lifting, and `D = T₁ △ T₂` in the common space |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W12 | One function, one job — step 0 filters the candidate set; it does not re-implement steps 1–4 |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LawGenerationTests/DriftCounterexampleTests.swift`:

```swift
import Testing
@testable import LawGeneration
import Glyphs
import Laws
import HunchTestSupport

@Suite("The dead-law counterexample — §7.6", .tags(.unit, .presubmission))
struct DriftCounterexampleTests {

    // MARK: step 0

    @Test("Step 0 prefers a ribbon glyph whose verdict differs under L₁ and L₂")
    func prefersARibbonMemberOfD() throws {
        let s = DriftScenario.fixture(.ribbonHoldsTwoMembersOfD)
        let chosen = try #require(DriftCounterexample.select(declared: s.pair.lawOne,
                                                             pair: s.pair, ribbon: s.ribbon))
        #expect(s.ribbon.contains(chosen))
        #expect(s.pair.disagrees(on: chosen))
    }

    @Test("Ties break on the MOST RECENT ribbon index, then the lowest glyphID")
    func tieBreaks() throws {
        let s = DriftScenario.fixture(.ribbonHoldsTwoMembersOfD)   // at indices 3 and 9
        let chosen = try #require(DriftCounterexample.select(declared: s.pair.lawOne,
                                                             pair: s.pair, ribbon: s.ribbon))
        #expect(s.ribbon.lastIndex(of: chosen) == 9)

        let duplicated = DriftScenario.fixture(.sameGlyphOfDAtOneIndexTwice)
        let tied = try #require(DriftCounterexample.select(declared: duplicated.pair.lawOne,
                                                           pair: duplicated.pair,
                                                           ribbon: duplicated.ribbon))
        #expect(tied.glyphID == duplicated.lowestIDAtThatIndex)
    }

    @Test("Most-recent beats lowest-glyphID — the order of the two tie-breaks is not symmetric")
    func recencyDominatesID() throws {
        // index 2 holds glyphID 4; index 8 holds glyphID 200. Both are in D.
        let s = DriftScenario.fixture(.recentHighIDAndOldLowID)
        let chosen = try #require(DriftCounterexample.select(declared: s.pair.lawOne,
                                                             pair: s.pair, ribbon: s.ribbon))
        #expect(chosen.glyphID == 200)
    }

    // MARK: the fall-through

    @Test("With no ribbon member in D, selection is canon §4.5's, unchanged")
    func fallsThroughToCanon() throws {
        let s = DriftScenario.fixture(.ribbonHoldsNoMemberOfD)
        let drift = try #require(DriftCounterexample.select(declared: s.pair.lawOne,
                                                            pair: s.pair, ribbon: s.ribbon))
        let canon = try #require(Counterexample.select(declared: s.pair.lawOne,
                                                       hidden: s.pair.lawTwo, ribbon: s.ribbon))
        #expect(drift == canon)
    }

    @Test("An empty ribbon falls through and still returns a glyph — declare at probe 0 is legal")
    func emptyRibbon() throws {
        let s = DriftScenario.fixture(.emptyRibbon)
        #expect(DriftCounterexample.select(declared: s.pair.lawOne,
                                           pair: s.pair, ribbon: []) != nil)
    }

    // MARK: DEAD-HINGE — the guarantee

    @Test("A dead-law declaration always yields a counterexample inside D",
          arguments: DriftBudget.servedBands)
    func alwaysInsideD(_ band: Band) {
        for i in 0..<500 {
            let s = DriftScenario.seeded(band: band, index: i)
            guard let chosen = DriftCounterexample.select(declared: s.pair.lawOne,
                                                          pair: s.pair, ribbon: s.ribbon) else {
                Issue.record("no counterexample at band \(band.rawValue), index \(i)")
                return
            }
            guard s.pair.disagrees(on: chosen) else {
                Attachment.record(s, named: "deadhinge-b\(band.rawValue)-\(i).json")
                Issue.record("counterexample outside D at band \(band.rawValue), index \(i)")
                return
            }
        }
    }

    @Test("D1 makes D non-empty, so `select` never returns nil for a dead-law declaration",
          arguments: DriftBudget.servedBands)
    func neverNil(_ band: Band) {
        let s = DriftScenario.seeded(band: band, index: 0)
        #expect(DriftCounterexample.select(declared: s.pair.lawOne, pair: s.pair,
                                           ribbon: s.ribbon) != nil)
    }

    // MARK: contextual bands

    @Test("Contextual bands return an ordered pair, in ribbon reading order",
          arguments: [Band.contextual, .composite])
    func contextualReturnsAPair(_ band: Band) throws {
        let s = DriftScenario.seeded(band: band, index: 3)
        let pair = try #require(DriftCounterexample.selectPair(declared: s.pair.lawOne,
                                                               pair: s.pair, ribbon: s.ribbon))
        #expect(s.pair.disagrees(on: pair))
        #expect(s.ribbon.containsAdjacent(pair.previous, pair.current))
    }

    // MARK: it is only for the dead law

    @Test("An ordinary wrong declaration takes canon's path, not step 0")
    func ordinaryStrikeIsUnaffected() throws {
        let s = DriftScenario.fixture(.ribbonHoldsTwoMembersOfD)
        let garbage = Corpora.unrelatedLaw(band: s.band)
        let drift = try #require(DriftCounterexample.select(declared: garbage,
                                                            pair: s.pair, ribbon: s.ribbon))
        let canon = try #require(Counterexample.select(declared: garbage,
                                                       hidden: s.pair.lawTwo, ribbon: s.ribbon))
        #expect(drift == canon)
    }

    @Test("Selection is deterministic")
    func deterministic() {
        let s = DriftScenario.seeded(band: .relational, index: 42)
        #expect(DriftCounterexample.select(declared: s.pair.lawOne, pair: s.pair, ribbon: s.ribbon)
             == DriftCounterexample.select(declared: s.pair.lawOne, pair: s.pair, ribbon: s.ribbon))
    }
}
```

And `Modules/Tests/LoomFeatureTests/DeadLawPresentationTests.swift`:

```swift
@Suite("The dead-law counterexample renders as the twin ring — §7.6", .tags(.unit, .presubmission))
struct DeadLawPresentationTests {

    @Test("The same glyph is drawn twice, one ringed admit and one ringed reject")
    func twinRing() {
        let p = CounterexamplePresentation(kind: .deadLaw, glyph: Deck.glyph(id: 77),
                                           declaredVerdict: .admit, loomVerdict: .reject)
        #expect(p.ribbonTileRing == .doubledSplit)
        #expect(p.centreGlyph == Deck.glyph(id: 77))
        #expect(p.centreRings == [.declared(.admit), .loom(.reject)])
    }

    @Test("It reuses VerdictRing.draw's split state and authors no new mark")
    func noNewMark() {
        #expect(CounterexamplePresentation.markOwner(for: .deadLaw) == "VerdictRing.draw")
    }

    @Test("The beat, the rise, the dock and the auto-collapse are E09's, unchanged")
    func timingIsUnchanged() {
        #expect(CounterexamplePresentation(kind: .deadLaw, …).beatSheet
             == CounterexamplePresentation(kind: .ordinary, …).beatSheet)
    }

    @Test("It is still not a probe")
    func notAProbe() {
        let p = CounterexamplePresentation(kind: .deadLaw, …)
        #expect(p.incrementsProbesUsed == false)
        #expect(p.becomesPrevious == false)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter DriftCounterexampleTests`

Expect missing `DriftCounterexample`, `DriftScenario`, `DriftPair.disagrees(on:)`,
`Corpora.unrelatedLaw`. If `Counterexample.select` did **not** ship with an injectable candidate set,
that is the first thing to fix — add the parameter to E06·T08's function with its documented default
rather than copying the four steps.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Diff `DriftCounterexample.swift` against
`Counterexample.swift`: any line that appears in both is a bug in this task.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/DriftCounterexample.swift` — step 0, then delegation |
| modify | `HunchCore/Sources/LawGeneration/Counterexample.swift` — expose the candidate-set parameter E06·T08 promised, if it is not already there |
| modify | `HunchCore/Sources/LawGeneration/DriftPair.swift` — `disagrees(on:)` for a glyph and for a pair, over the cached `D` |
| modify | `Modules/Sources/LoomFeature/CounterexampleView.swift` — a `kind` that selects the twin ring; **no new timing** |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `DriftScenario`, its five fixtures, `unrelatedLaw(band:)` |
| create | `HunchCore/Tests/LawGenerationTests/DriftCounterexampleTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/DeadLawPresentationTests.swift` |
| modify | `tests.json` — step 0, both tie-breaks, the fall-through, the DEAD-HINGE guarantee |
| modify | `DECISIONS.md` — the contextual pair reading of step 0 |

## Implementation notes

### Step 0 is a filter in front of a function that already exists

```swift
public enum DriftCounterexample {
    /// §7.6's step 0, then canon §4.5's four steps on whatever survives.
    ///
    /// Step 0: prefer a glyph already in `ribbon` whose verdict differs under `L₁` and `L₂`.
    /// Tie-break by most recent ribbon index, then lowest `glyphID`. If no ribbon member lies in
    /// `D`, the candidate set is untouched and canon's rule runs exactly as it does in PROBE.
    public static func select(declared: Law, pair: DriftPair, ribbon: [Glyph]) -> Glyph?
    public static func selectPair(declared: Law, pair: DriftPair, ribbon: [Glyph]) -> GlyphPair?
}
```

```swift
let ribbonMembersOfD = ribbon.filter { pair.disagrees(on: $0) }
guard !ribbonMembersOfD.isEmpty else {
    return Counterexample.select(declared: declared, hidden: pair.lawTwo, ribbon: ribbon)
}
// most recent index wins; the lowest glyphID breaks a tie at one index
return ribbonMembersOfD.enumerated()
    .max { lhs, rhs in
        (ribbon.lastIndex(of: lhs.element)!, -Int(rhs.element.glyphID))
      < (ribbon.lastIndex(of: rhs.element)!, -Int(lhs.element.glyphID))
    }?.element
```

Write it however reads best — but the two properties the tests pin are non-negotiable:

1. **The tie-breaks are ordered, and the order is not symmetric.** Most recent index first, `glyphID`
   second. Sorting by `glyphID` and then stably by index gives a different answer, and the
   `recencyDominatesID` test is exactly the case where they differ. §7.6's sentence reads
   *"most recent ribbon index, then lowest `glyphID`"* and that is the order.
2. **The fall-through hands the *unfiltered* ribbon to canon.** Not the filtered candidate set, not a
   truncated ribbon — canon's step 3 minimises distance to the nearest ribbon glyph and needs the whole
   ribbon to do it.

The `hidden` law is always **`L₂`**, on both paths. That is the law in force, and the counterexample's
job is to prove the declaration false against it.

### Why the ribbon and not a fresh glyph

§7.6 gives the reason and it is worth carrying into the code comment: the player has already seen this
glyph, already recorded a verdict for it, and is about to be shown the *opposite* verdict on the same
drawing. That is the mode's entire lesson delivered as one image, and it only lands if the glyph is one
they chose. A freshly minimised-Hamming glyph is a good counterexample about a wrong law; a ribbon
member is a counterexample about *time*.

### The contextual case

`selectPair` filters the ribbon's **adjacent pairs** `(ribbon[i-1], ribbon[i])` — with the seed glyph
priming position 0 (§3.5), so the first candidate pair is `(seedGlyph, ribbon[0])`. Ties break on the
most recent `i`, then on the canonical pair index `previous*256 + current`, which is the ordering
E06·T08 already ruled on for the pair case. Record the reading in `DECISIONS.md`: §7.6 says "glyph (or
ordered pair) already in the ribbon", and *"already in the ribbon"* for a pair can only mean an
adjacency the player actually produced — a pair assembled from two non-adjacent ribbon members was
never observed and would not read as *"the same thing gave two answers"*.

### The rendering: one existing mark, no new one

The dead-law counterexample draws as the **twin ring**: the ribbon tile and the centred counterexample
carry the identical glyph, one ringed admit, one ringed reject. Every part of that already exists:

- the **doubled ring** and its **split** state are `VerdictRing.draw`'s (E04·T07), and §6.6 layer 4
  already taught the player that a split doubled ring means *the same glyph gave two answers*;
- the **two rings at once** on the centred glyph are E09·T09's presentation, unchanged;
- the rise, the 640 ms verdict-blind hold, the 960 ms beat, the dock as a marginal island and the
  Bench's auto-collapse are E09·T09's, **unchanged** — the test above asserts the two beat sheets are
  equal, which is the cheapest possible statement of "this task added no timing".

The only new thing is that `CounterexamplePresentation` knows its `kind`, and `.deadLaw` selects the
split-doubled ring on the *ribbon tile* as well as the two rings at centre. If the implementation wants
a new `Canvas`, stop: `verdict-ring.md`'s ownership table already names the owner.

### It only fires for the dead law

`.deadLaw` is T02's classification and nothing else routes here. An ordinary wrong declaration —
pre-hinge or post-hinge — takes canon's four steps against `L₂` with no step 0, because the player's
error is not a *clinging* error and dressing it as one would teach the wrong lesson. That is what the
`ordinaryStrikeIsUnaffected` test protects.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DriftCounterexampleTests` green, all ten tests, including the 500-scenario × 6-band DEAD-HINGE guarantee.
- [ ] `swift test --package-path Modules --filter DeadLawPresentationTests` green.
- [ ] `DriftCounterexample.swift` contains **no** implementation of steps 1–4: `grep -c "falseNegative\|hamming\|glyphID" HunchCore/Sources/LawGeneration/DriftCounterexample.swift` shows only the tie-break's use of `glyphID`.
- [ ] `Counterexample.select`'s signature is unchanged for every existing PROBE call site (the candidate-set parameter has a default).
- [ ] `grep -rn "Duration\|beat\|960\|640" HunchCore/Sources/LawGeneration/DriftCounterexample.swift` returns nothing.
- [ ] `grep -rn "Canvas\|Path(" Modules/Sources/LoomFeature/CounterexampleView.swift` shows no *new* canvas relative to E09·T09's diff.
- [ ] `DECISIONS.md` records the adjacent-pair reading of step 0 in contextual bands.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T06: the dead-law counterexample — step 0, its tie-breaks and the twin-ring rendering"`

## Out of scope

- Canon §4.5's four steps and the Hamming metric — **E06·T08**, extended by one parameter and otherwise untouched.
- The counterexample's rise, two rings, dock and auto-collapse — **E09·T09**, reused with no timing change.
- `VerdictRing.draw`'s doubled and split states — **E04·T07**.
- Classifying a declaration as `.deadLaw` — **T02**; routing it to `struck` — **T03**.
- `deadDeclaration` as a transcript metric — **T07**.
- The reveal that follows the second strike — **T08**.
