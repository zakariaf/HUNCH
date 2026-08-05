# T02 — The band table and the Rasch coupling

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M — the plan sizes this S; it grows to M because `Band.achievableDifficultyRange` has to be derived and asserted here, or T06's fallback rate is unbounded at band 1 |
| **Depends on** | T01 |
| **Delivers** | §14.1 Band table |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | `Band` is one type for two design words (`08 §3`), and this task is where the temptation to add a second `Family` type is strongest — every column added here is a `Band` member, not a new type. It also owns the gotcha that `enum Band: Int, CaseIterable, Comparable` does not compile: a raw type suppresses the synthesized `Comparable`, so `<` is hand-written. |

## Objective

`Band` carries every column §5.2 publishes plus the two §5.4 priors `k` and `d`, and one test walks
the eight rows end to end. The Rasch coupling `δ_logit = 8·difficulty − 4` exists as a pair of
conversions with the serving offset beside them, so E11 can serve against it without ever surfacing
a number.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.2 | The eight rows: family, δ range, conceptual move, `\|H\|`, `log₂\|H\|`, example law, `p`, `δ` — and the three enforced jumps |
| `GAME_DESIGN.md` | §5.4 | `k` and `d` per band, and `par = ceil(k·log₂\|H\| + d)` |
| `GAME_DESIGN.md` | §5.1 | `δ_logit = 8·difficulty − 4`, working range, and the rule to serve `θ − 1.386` |
| `GAME_DESIGN.md` | §5.7 | Band populations, difficulty range, modifier ceiling, Rasch coupling — all locked |
| `GAME_DESIGN.md` | §3.6 | Why the enumeration runs in ascending band order, and why G4's own band is excluded |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 | The Band/Family collapse and its `DECISIONS.md` entry |

## TDD — the test comes first

**Step 1 — write the failing test.** Create two files.

`HunchCore/Tests/LawGenerationTests/BandTableTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("The band table", .tags(.unit, .presubmission))
struct BandTableTests {

    @Test("Eight bands, one family each, in ascending order")
    func eightBandsInOrder() {
        #expect(Band.allCases.count == 8)
        #expect(Band.allCases == Band.allCases.sorted())
        #expect(Band.allCases.map(\.rawValue) == Array(1...8))
    }

    @Test("The δ ranges tile [0,1) with no gap and no overlap")
    func rangesTileTheUnitInterval() {
        var cursor = 0.0
        for band in Band.allCases {
            #expect(isApproximatelyEqual(band.difficultyRange.lowerBound, cursor,
                                         absoluteTolerance: 1e-12))
            cursor = band.difficultyRange.upperBound
        }
        #expect(isApproximatelyEqual(cursor, 1.0, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Band.width, 1.0 / 8.0, absoluteTolerance: 1e-12))
    }

    /// §5.7 locks the eight populations. E05·T08 enumerates them; this asserts the table agrees
    /// with the enumeration rather than with a memory of it.
    @Test("population matches the enumerated |H|", arguments: Band.allCases)
    func populationMatchesEnumeration(_ band: Band) {
        #expect(band.population == Corpora.index.count(for: band))
    }

    @Test("log₂|H| is derived, never stored")
    func logPopulationIsDerived() {
        for band in Band.allCases {
            #expect(isApproximatelyEqual(band.logPopulation, log2(Double(band.population)),
                                         absoluteTolerance: 1e-12))
        }
    }

    /// §5.4's par column is `ceil(k·log₂|H| + d)`. Reproducing all eight from `k`, `d` and the
    /// enumerated population is what stops par, |H| and the index from drifting apart.
    @Test("par is recomputable from k, d and log₂|H|", arguments: Band.allCases)
    func parIsRecomputable(_ band: Band) {
        let derived = Int((band.frictionCoefficient * band.logPopulation
                           + Double(band.discoveryCost)).rounded(.up))
        #expect(band.par == derived)
    }

    @Test("Every exemplar is already in rendered normal form", arguments: Band.allCases)
    func exemplarIsCanonical(_ band: Band) {
        #expect(band.exemplar.renderedNormalForm == band.exemplar)
    }

    @Test("Every exemplar sits inside its own band", arguments: Band.allCases)
    func exemplarIsInItsBand(_ band: Band) {
        #expect(band.difficultyRange.contains(difficulty(of: Law(band.exemplar))))
        #expect(Band(classifying: band.exemplar) == band)
    }

    /// §5.2's three enforced jumps, as theorems and not as assertions about the table.
    @Test("Band 3's flatness is a theorem: all sixteen marginals equal p")
    func exclusiveIsFlatByConstruction() {
        let law = Law(Band.exclusive.exemplar)
        for condition in MarginalCondition.all {                 // 16 (attribute, value) pairs
            #expect(isApproximatelyEqual(law.admitRate(given: condition), law.admitRate,
                                         absoluteTolerance: 1e-12))
        }
    }

    @Test("Band 4's every value has both an admitted and a rejected glyph")
    func relationalIsNonPredictive() {
        let law = Law(Band.relational.exemplar)
        for condition in MarginalCondition.all {
            #expect(law.admitRate(given: condition) > 0)
            #expect(law.admitRate(given: condition) < 1)
        }
    }

    @Test("Band 8 is enforced by symmetry: the extension is invariant under permuting counted attributes")
    func systemicIsSymmetric() throws {
        let law = Law(Band.systemic.exemplar)
        for permutation in AttributeSetPermutation.all(of: law.countedAttributes) {
            #expect(law.table.permuting(permutation) == law.table)
        }
    }

    // MARK: the achievable range — the reason this task is M and not S

    /// A band's *nominal* δ range is 0.125 wide; the difficulties its laws can actually take are a
    /// sub-interval of it, because m3 and m4 are never simultaneously zero for most families.
    /// G8's ±0.02 proximity clause is evaluated against a requested `targetδ`, so a request outside
    /// this interval can never be satisfied and burns all 200 attempts.
    @Test("The achievable range is inside the nominal range and non-empty", arguments: Band.allCases)
    func achievableRangeIsSane(_ band: Band) {
        let achievable = band.achievableDifficultyRange
        #expect(band.difficultyRange.contains(achievable.lowerBound))
        #expect(achievable.lowerBound <= achievable.upperBound)
        #expect(achievable.upperBound < band.difficultyRange.upperBound)
        #expect(achievable.contains(band.centre))
    }

    /// The invariant that makes T06's "fallback under 2 %" a property rather than a hope:
    /// no achievable difficulty is more than the G8 tolerance away from a real law.
    @Test("No gap in the achievable difficulty set exceeds 2 × the G8 tolerance",
          .tags(.integration, .nightly), arguments: Band.enumerableCases)
    func achievableSetHasNoWideGap(_ band: Band) throws {
        let values = Corpora.index.difficulties(for: band).sorted()
        #expect(!values.isEmpty)
        for (lower, upper) in zip(values, values.dropFirst()) {
            #expect(upper - lower <= 2 * Guardrail.proximityTolerance,
                    "band \(band.rawValue): gap \(upper - lower) between \(lower) and \(upper)")
        }
    }

    @Test("Band 1's achievable difficulties are exactly the three the formula allows")
    func literalBandHasThreeAchievableValues() {
        // 4 attributes × (4 singletons + 6 pairs) = 40 laws (§5.2's |H|), taking exactly three
        // distinct difficulties: m3 is fixed, m4 has two values under G3, m5 has two.
        let values = Set(Corpora.index.difficulties(for: .literal).map { ($0 * 1e6).rounded() })
        #expect(values.count == 3)
        #expect(Band.literal.population == 40)
    }
}
```

`HunchCore/Tests/LawGenerationTests/RaschTests.swift`:

```swift
import Foundation
import Testing
import LawGeneration
import HunchTestSupport

@Suite("The Rasch coupling", .tags(.unit, .presubmission))
struct RaschTests {

    @Test("The coupling is affine and invertible")
    func couplingRoundTrips() {
        for step in 0...1000 {
            let difficulty = Double(step) / 1000.0
            let logit = Rasch.logit(ofDifficulty: difficulty)
            #expect(isApproximatelyEqual(Rasch.difficulty(ofLogit: logit), difficulty,
                                         absoluteTolerance: 1e-12))
        }
    }

    @Test("The working range runs from the bottom of band 1 to the top of band 8")
    func workingRangeMatchesTheDesign() {
        #expect(isApproximatelyEqual(Rasch.logit(ofDifficulty: 0.0), -4.0, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Rasch.logit(ofDifficulty: 0.999), 3.992, absoluteTolerance: 1e-9))
    }

    /// The serving offset is not a magic number: it is the logit distance at which a Rasch model
    /// predicts §5.7's locked 0.80 success rate. Asserting the *consequence* rather than the digit
    /// is what keeps this honest if the target rate ever moves.
    @Test("Serving θ − offset predicts exactly the locked target success rate")
    func offsetProducesTheTargetSuccessRate() {
        let predicted = 1.0 / (1.0 + exp(-Rasch.servingOffset))
        #expect(isApproximatelyEqual(predicted, Rasch.targetSuccessRate, absoluteTolerance: 0.0005))
    }

    @Test("A band's centre maps into the band's own logit interval", arguments: Band.allCases)
    func centreMapsInsideTheBand(_ band: Band) {
        let logit = Rasch.logit(ofDifficulty: band.centre)
        #expect(logit >= Rasch.logit(ofDifficulty: band.difficultyRange.lowerBound))
        #expect(logit < Rasch.logit(ofDifficulty: band.difficultyRange.upperBound))
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter "BandTableTests|RaschTests"`
It must fail on missing members of `Band` and a missing `Rasch`, not on a malformed expectation.

**Step 3 — implement.** Files below.

**Step 4 — green, then refactor.** Delete any column you find you stored that is derivable —
`logPopulation`, `centre` and `difficultyRange` are all derived, and storing them creates a second
place §5.2 can drift from.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/LawGeneration/Band.swift` |
| create | `HunchCore/Sources/LawGeneration/Rasch.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `count(for:)` and `difficulties(for:)` over the built index |
| create | `HunchCore/Tests/LawGenerationTests/BandTableTests.swift` |
| create | `HunchCore/Tests/LawGenerationTests/RaschTests.swift` |
| modify | `DECISIONS.md` — the achievable-range ruling and its consequence for E11 |
| modify | `tests.json` — one entry for the band table |

## Implementation notes

### What `Band` gains here

E05·T06 shipped `par(for:)`, `cap(for:)`, `population` and `difficultyRange`; T01 added `minLeaves`,
`exemplar` and the two published columns used by tests. This task adds the rest:

```swift
extension Band {
    /// §5.4's friction coefficient `k` — a design-time prior the Level-B harness may regenerate.
    public var frictionCoefficient: Double { … }
    /// §5.4's discovery cost `d`, in probes.
    public var discoveryCost: Int { … }
    /// Derived, never stored — see §5.2's log₂|H| column.
    public var logPopulation: Double { log2(Double(population)) }
    /// The width of one band. §5.7 locks eight bands of equal width.
    public static let width: Double = 1.0 / 8.0
    /// The difficulties this band's laws can actually take, as a closed interval. Derived once by
    /// enumeration; see the ruling below.
    public var achievableDifficultyRange: ClosedRange<Double> { … }
    /// The midpoint of `achievableDifficultyRange` — what a test or a caller asks for when it has
    /// no opinion. Never the midpoint of `difficultyRange`.
    public var centre: Double { … }
    /// §5.3's admit-rate window. Identical in every band; a member so call sites read
    /// `band.admitWindow.contains(table.admitRate)` (`hunch-swift-testing`'s sketch).
    public var admitWindow: ClosedRange<Double> { … }
    /// The six bands the stateless index enumerates exhaustively (§3.6).
    public static var enumerableCases: [Band] { … }
}
```

`Band` still cannot synthesize `Comparable` alongside its `Int` raw value — write `<` by hand, as
`hunch-swift-code`'s gotcha states, or the file will not compile.

### The achievable range, and the ruling it forces

> **Ruling, to be recorded in `DECISIONS.md`.** `Band.centre` is the midpoint of the band's
> *achievable* difficulty range, not of its nominal δ range. A band's laws cannot reach the whole
> nominal 0.125-wide interval: band 1, for instance, is exactly 40 atoms, m1 and m2 are identically
> zero for all of them, m3 is identically at its maximum, and m4 and m5 each take two values, so the
> forty laws take exactly **three** distinct difficulties spanning roughly 0.023…0.040. A request
> for the nominal centre 0.062 is unsatisfiable and burns all 200 generator attempts, driving the
> fallback rate at band 1 to 1.00 against §5.3's 2 % budget. E11's serving policy therefore clamps
> its computed `targetδ` into `band.achievableDifficultyRange` at step 11, and this epic records
> that requirement for E11·T03 to consume.

Derive the eight ranges once — the enumeration E05·T07 already materialises bands 1, 2, 3, 4, 6 and
8, and E05's contextual runs cover 5 and 7 — then **ship them as constants** and keep the derivation
as a `.nightly` test. Building them at launch would put a 3-second enumeration on the generator's
critical path, which is exactly what §14.5's open decision 4 moves to the background.

### `Rasch`

A caseless enum namespace, one file, named for the model it implements:

```swift
/// §5.1's coupling between HUNCH's structural difficulty and the Rasch item parameter.
/// Never surfaced numerically anywhere in the app (§10.5, §14.1 "Difficulty is never a number").
public enum Rasch {
    public static func logit(ofDifficulty difficulty: Double) -> Double
    public static func difficulty(ofLogit logit: Double) -> Double
    /// Serve `ability − servingOffset` to hold the locked target success rate (§5.1, §5.7).
    public static let servingOffset: Double
    /// §5.7's locked round success target, carried here because `servingOffset` is derived from it.
    public static let targetSuccessRate: Double
}
```

`08 §3` renames the Greek: `targetδ` → `targetDelta`, `θ` → `ability`. Neither appears in this file
as an identifier, because this file converts units and does not serve anything.

Two rules that matter more than they look:

1. **The logit is never handed to a mode.** §10.3 steps 7–12 hand each mode a band and a `targetδ`
   in *difficulty units*. `Rasch.logit(ofDifficulty:)` exists for the estimator's arithmetic in
   E11 and for nothing else. A `// swiftlint`-style comment will not enforce that; the E11 task
   file does.
2. **Nothing here is rendered.** §14.1's "Difficulty is never a number" row is a shipped grep in
   E11·T09. Do not add a `description`, a `formatted()` or a `CustomStringConvertible` to `Rasch`
   or to `Band`.

### `MarginalCondition` and the three theorems

The three enforced jumps of §5.2 are asserted as *properties of the exemplar*, not as table lookups.
That needs two small helpers, both of which belong in `Laws` beside `LawTable` rather than in a test
file, because T05's G-checks reuse them:

- `MarginalCondition` — the 16 (attribute, value) pairs, `CaseIterable`-shaped, with
  `Law.admitRate(given:)` returning `P(admit | φ)`. `Law.marginalDeficit` (E05·T02) is already
  defined over these, so this is exposing what it already computes, not adding a second computation.
- `LawTable.permuting(_:)` — E05·T05 already ships value-permutation for attribute liveness; band
  8's symmetry theorem is the same machinery applied to a *set* of attributes.

If either is missing, add it in `Laws` and re-run `LawsTests` before continuing.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter "BandTableTests|RaschTests"` is green.
- [ ] `band.par == ceil(band.frictionCoefficient · band.logPopulation + band.discoveryCost)` for all
      eight bands, with `logPopulation` derived from `band.population`.
- [ ] `band.population == Corpora.index.count(for: band)` for all eight bands — the table and the
      enumeration are the same numbers.
- [ ] The eight δ ranges tile `[0, 1)` with no gap and no overlap.
- [ ] Every exemplar is in RNF, classifies back to its own band, and sits inside its δ range.
- [ ] Band 3's sixteen marginals are all equal to `p`; band 4's are all strictly between 0 and 1;
      band 8's extension is invariant under every permutation of its counted attributes.
- [ ] `band.achievableDifficultyRange` is non-empty, strictly inside `band.difficultyRange`, and
      contains `band.centre`, for all eight bands.
- [ ] The nightly gap test shows no gap wider than `2 × Guardrail.proximityTolerance` in any
      enumerable band.
- [ ] `Rasch.logit`/`Rasch.difficulty` round-trip to 1e-12 across the unit interval, and
      `σ(Rasch.servingOffset)` equals `Rasch.targetSuccessRate` within 0.0005.
- [ ] `DECISIONS.md` carries the achievable-range ruling naming E11·T03 as the consumer.
- [ ] `tests.json` has a Band table entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T02: band table columns, achievable difficulty ranges and the Rasch coupling"`

## Out of scope

- `Band` itself, `par(for:)`, `cap(for:)`, `population`, `difficultyRange` — **E05·T06**.
- The `|H|` enumeration and its eight assertions — **E05·T08**; this task consumes them.
- Scoring, marks and the cap derivation `ceil(1.6·par)` — **T07**.
- The estimator, the serving policy, the pressure term and cold start — **E11**.
- Anything that renders a band, a δ or a θ — forbidden outright by §14.1's "Difficulty is never a
  number", enforced in **E11·T09**.
