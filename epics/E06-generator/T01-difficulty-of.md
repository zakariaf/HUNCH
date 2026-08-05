# T01 — `difficulty(of:)`

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (E05 must be merged) |
| **Delivers** | §14.1 `difficulty(of:)` |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides where `Difficulty.swift` goes (`LawGeneration`, not `Laws` — it reads `Law`'s cached metrics and is consumed by the generator), whether the shipped shape is a free function or a type, and how `Band` may be extended without a second `Family` type. `08 §3`'s Band/Family collapse is the reason `law.family.index` becomes `law.band.rawValue - 1`. |
| `hunch-swift-testing` | Every assertion in this task compares `Double`s, so `ApproximateEquality.isApproximatelyEqual(_:_:absoluteTolerance:)` from `HunchTestSupport` is mandatory — swift-numerics is banned and `#expect(a == b)` on a `Double` is the thing this project must never ship. |

## Objective

`difficulty(of:)` returns a law's position on §5.1's `[0.000, 1.000)` scale, and each of the five
modifiers is separately inspectable so it can be asserted on its own. At the end of this task the
eight exemplar laws of §5.2 reproduce the δ column of that table to three decimal places from the
formula alone.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.1 | The formula verbatim, the five modifier definitions and their maxima, the claim that they sum to exactly 0.124 |
| `GAME_DESIGN.md` | §5.2 | The eight exemplar laws with their `p` and `δ`, and the band-8 `COUNT` paragraph that proves flatness positions rather than gates |
| `GAME_DESIGN.md` | §5.7 | Difficulty range and modifier ceiling as locked constants |
| `GAME_DESIGN.md` | §3.2 | The BNF, from which each family's minimum leaf count is read |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 | Band/Family collapse; `Law` carries the resolved table and cached `Metrics` so this stays O(1) |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24 | One top-level type per file, named for it |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B34a | The hygiene grep this file must not trip |

Do not restate a coefficient, a maximum or a δ value in prose or in a comment. Cite §5.1 and §5.2
and let the reader open them.

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LawGenerationTests/DifficultyTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("difficulty(of:)", .tags(.unit, .presubmission))
struct DifficultyTests {

    // MARK: the whole table, from the formula alone

    /// §5.2's δ column is *derived* from §5.1, not independent of it. Reproducing all eight rows
    /// from the formula is the single strongest statement that the implementation is the design.
    @Test("Every exemplar reproduces its §5.2 δ", arguments: Band.allCases)
    func exemplarMatchesPublishedDelta(_ band: Band) throws {
        let law = Law(band.exemplar)
        #expect(isApproximatelyEqual(difficulty(of: law), band.publishedDelta,
                                     absoluteTolerance: 0.001),
                "band \(band.rawValue): computed \(difficulty(of: law)), §5.2 prints \(band.publishedDelta)")
        #expect(isApproximatelyEqual(law.admitRate, band.publishedAdmitRate,
                                     absoluteTolerance: 0.001))
    }

    @Test("Difficulty never escapes its band", arguments: Band.allCases)
    func exemplarStaysInsideItsBand(_ band: Band) throws {
        #expect(band.difficultyRange.contains(difficulty(of: Law(band.exemplar))))
    }

    // MARK: the base and the ceiling

    @Test("The five modifier maxima sum to exactly one tick short of the band width")
    func modifierCeilingIsExact() {
        let ceiling = Difficulty.leafExcessMax + Difficulty.marginalDeficitMax
                    + Difficulty.freeAttributesMax + Difficulty.rateSkewMax + Difficulty.scatterMax
        #expect(isApproximatelyEqual(ceiling, Difficulty.modifierCeiling, absoluteTolerance: 1e-12))
        #expect(ceiling < Band.width)               // §5.1: "a law can never escape its band"
    }

    @Test("Base is family index × the band width", arguments: Band.allCases)
    func baseIsTheFamilyIndex(_ band: Band) {
        #expect(isApproximatelyEqual(Difficulty(of: Law(band.exemplar)).base,
                                     band.difficultyRange.lowerBound,
                                     absoluteTolerance: 1e-12))
    }

    // MARK: one modifier at a time, on hand-computed laws

    /// m1 — a band-1 atom is at its family minimum, so the leaf-excess term is zero; the
    /// band-2 exemplar is a two-leaf law whose family minimum is also two.
    @Test("m1 is zero at the family minimum and saturates two leaves above it")
    func leafExcessSaturates() throws {
        #expect(Difficulty(of: Law(Band.literal.exemplar)).leafExcess == 0)
        #expect(Difficulty(of: Law(Band.pair.exemplar)).leafExcess == 0)
        let threeLeaves = try #require(Corpora.handWritten(.pairPlusOneLeaf))
        #expect(isApproximatelyEqual(Difficulty(of: Law(threeLeaves)).leafExcess,
                                     Difficulty.leafExcessMax / 2, absoluteTolerance: 1e-12))
        let fourLeaves = try #require(Corpora.handWritten(.pairPlusTwoLeaves))
        #expect(isApproximatelyEqual(Difficulty(of: Law(fourLeaves)).leafExcess,
                                     Difficulty.leafExcessMax, absoluteTolerance: 1e-12))
    }

    /// m2 — §5.1 states the two poles outright: an atom scores 0, a flat XOR / relational /
    /// parity law scores 1. Both are asserted, because a sign error passes any one-sided test.
    @Test("m2 is 0 for an atom and 1 for the flat families")
    func marginalDeficitPoles() {
        #expect(Law(Band.literal.exemplar).marginalDeficit == 0)
        #expect(isApproximatelyEqual(Law(Band.exclusive.exemplar).marginalDeficit, 1.0,
                                     absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(Law(Band.relational.exemplar).marginalDeficit, 1.0,
                                     absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(Law(Band.systemic.exemplar).marginalDeficit, 1.0,
                                     absoluteTolerance: 1e-9))
    }

    /// **The band-8 COUNT law of §5.2.** This is the assertion the whole task exists for:
    /// a legitimate band-8 law whose marginals are *not* flat, positioned inside band 8 by m2
    /// rather than excluded from it. If flatness ever becomes an entry condition, |H|(8) collapses
    /// to roughly the ten parity forms and par, cap and the index all move with it.
    @Test("The band-8 COUNT law: flatness positions, it does not gate")
    func countLawIsBandEightWithoutBeingFlat() throws {
        let law = Law(try #require(Corpora.handWritten(.systemicCount)))
        #expect(isApproximatelyEqual(law.admitRate, 0.500, absoluteTolerance: 0.001))
        #expect(isApproximatelyEqual(law.marginalDeficit, 0.286, absoluteTolerance: 0.001))
        #expect(isApproximatelyEqual(difficulty(of: law), 0.906, absoluteTolerance: 0.001))
        #expect(Band.systemic.difficultyRange.contains(difficulty(of: law)))
        #expect(law.marginalDeficit < 1.0)          // not flat, and still band 8
    }

    /// m3 — a law naming one attribute leaves three free and saturates; a law naming all four
    /// scores zero. The band-8 PARITY exemplar names all four.
    @Test("m3 saturates at three free attributes and is zero at none")
    func freeAttributesSaturate() {
        #expect(isApproximatelyEqual(Difficulty(of: Law(Band.literal.exemplar)).freeAttributes,
                                     Difficulty.freeAttributesMax, absoluteTolerance: 1e-12))
        #expect(Difficulty(of: Law(Band.systemic.exemplar)).freeAttributes == 0)
    }

    /// m4 — distance from the 0.30 mode, in either direction, normalised by 0.30.
    @Test("m4 is symmetric about the mode and zero at it")
    func rateSkewIsSymmetric() throws {
        let atMode = try #require(Corpora.handWritten(.admitRateAtMode))       // p == 0.30
        #expect(isApproximatelyEqual(Difficulty(of: Law(atMode)).rateSkew, 0,
                                     absoluteTolerance: 1e-9))
        let below = try #require(Corpora.handWritten(.admitRateBelowMode))     // p == 0.25
        let above = try #require(Corpora.handWritten(.admitRateAboveMode))     // p == 0.35
        #expect(isApproximatelyEqual(Difficulty(of: Law(below)).rateSkew,
                                     Difficulty(of: Law(above)).rateSkew,
                                     absoluteTolerance: 1e-9))
    }

    /// m5 — exactly five of the fourteen subsets are non-contiguous runs of ranks (§5.1).
    @Test("Exactly five of the fourteen subsets are scattered")
    func scatteredSubsetsAreFive() {
        let scattered = (1...14).map(UInt8.init).filter { Subset4(rawValue: $0)!.isScattered }
        #expect(scattered.count == 5)
    }

    @Test("m5 counts scattered leaves and saturates at two")
    func scatterSaturates() throws {
        #expect(Difficulty(of: Law(Band.exclusive.exemplar)).scatter == 0)     // both runs contiguous
        let one = try #require(Corpora.handWritten(.oneScatteredLeaf))
        #expect(isApproximatelyEqual(Difficulty(of: Law(one)).scatter,
                                     Difficulty.scatterMax / 2, absoluteTolerance: 1e-12))
        let two = try #require(Corpora.handWritten(.twoScatteredLeaves))
        #expect(isApproximatelyEqual(Difficulty(of: Law(two)).scatter,
                                     Difficulty.scatterMax, absoluteTolerance: 1e-12))
    }

    // MARK: the breakdown is the function

    @Test("The breakdown sums to the published value", arguments: Band.allCases)
    func breakdownSumsToTotal(_ band: Band) {
        let law = Law(band.exemplar)
        let d = Difficulty(of: law)
        let sum = d.base + d.leafExcess + d.marginalDeficit
                + d.freeAttributes + d.rateSkew + d.scatter
        #expect(isApproximatelyEqual(sum, difficulty(of: law), absoluteTolerance: 1e-12))
    }

    @Test("difficulty(of:) is O(1) — it reads cached metrics and never rebuilds a table")
    func readsCachedMetricsOnly() {
        let law = Law(Band.contextual.exemplar)             // 8 KiB pair table, built once
        let before = law.tableBuildCount
        _ = difficulty(of: law)
        _ = difficulty(of: law)
        #expect(law.tableBuildCount == before)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter DifficultyTests`

It must fail on missing symbols — `difficulty(of:)`, `Difficulty`, `Band.exemplar`,
`Band.publishedDelta`, `Corpora.handWritten` — not on a malformed expectation. If any test passes
before `Difficulty.swift` exists, the test is asserting nothing.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** In particular collapse any modifier that ended up computing a
metric `Law` already caches; `08 §3` resolves all five in `Law.init` for exactly this reason.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/Difficulty.swift` |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — adds `minLeaves`, `exemplar`, `publishedDelta`, `publishedAdmitRate`, `width` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — adds `Corpora.handWritten(_:)` and its `HandWrittenLaw` enum |
| create | `HunchCore/Tests/LawGenerationTests/DifficultyTests.swift` |
| modify | `tests.json` — one entry for `difficulty(of:)` |

`Band.swift` was created by E05·T06 at `HunchCore/Sources/LawGeneration/Band.swift` per `08 §1`'s
tree. If E05 relocated it to break a dependency cycle with `LawIndex`, follow the location on disk
— `${CLAUDE_SKILL_DIR}/scripts/check-boundary.sh --all` from `hunch-swift-code` will confirm the
file is still inside `HunchCore`.

## Implementation notes

### The shape

`08 §3` requires the design's published signature to stay literally true, so the free function
survives and the breakdown is a type beside it:

```swift
/// The five modifiers of §5.1, kept apart so each one can be asserted on its own.
/// `Difficulty(of:).value` and `difficulty(of:)` are the same number by construction.
public struct Difficulty: Hashable, Sendable {
    public let base: Double
    public let leafExcess: Double        // m1
    public let marginalDeficit: Double   // m2
    public let freeAttributes: Double    // m3
    public let rateSkew: Double          // m4
    public let scatter: Double           // m5

    public var value: Double { base + leafExcess + marginalDeficit + freeAttributes + rateSkew + scatter }

    public init(of law: Law) { … }       // O(1): every input is a cached metric on `Law`
}

/// - Complexity: O(1). Every term reads a metric `Law.init` already resolved (`08 §3`).
public func difficulty(of law: Law) -> Double { Difficulty(of: law).value }
```

`P24` is satisfied: one top-level type, `Difficulty`, in `Difficulty.swift`; the free function
introduces no second type and keeps §5.1's signature readable at the call site.

The six coefficients are `public static let` on `Difficulty` (`leafExcessMax`, `marginalDeficitMax`,
`freeAttributesMax`, `rateSkewMax`, `scatterMax`, `modifierCeiling`) so the ceiling test can add
them up rather than restate the sum. Each carries a one-line doc comment citing §5.1's row — never
its prose.

### `Band.minLeaves`, and why it is not a guess

`m1` reads `law.leafCount - law.family.minLeaves`. Under `08 §3`'s collapse that is
`band.minLeaves`, and each value is read straight off §3.2's production for that family:

| Band | Production | Minimum leaves |
|---|---|---|
| literal | `<atom>` | 1 |
| pair | `<atom> <coupler> <atom>` | 2 |
| exclusive | `<atom> "XOR" <atom>` | 2 |
| relational | `<rel>` | 1 |
| contextual | `<ctx>` | 1 |
| guarded | `<guard>` | 3 — §5.7 locks "guard = exactly 3 leaves" |
| composite | two terms under a coupler | 2 |
| systemic | `<aggregate>` | 1 |

Do not hard-code this table twice. T06 ships `Band.skeletons`, and its acceptance criteria include
`band.skeletons.map(\.leafCount).min() == band.minLeaves` for all eight bands — one constant checked
from two directions.

### The eight exemplars

`Band.exemplar: LawNode` ships here, not in a test file, because T06 uses it as the family's
deterministic anchor law. Each is §5.2's "Example law" column, spelled in the AST E05·T01 defines
and already in RNF (assert `exemplar.renderedNormalForm == exemplar` — that assertion belongs to
T02's band-table suite, and if it fails here first, fix the spelling, not RNF).

`publishedDelta` and `publishedAdmitRate` are §5.2's δ and `p` columns, carried as
`internal`-visibility constants used by the tests only. They are the *table's* numbers; the formula
is normative. Which brings us to the one row that does not land on the printed digit:

> **Band 7.** Hand-computing §5.2's composite exemplar
> (`RANK hue(cur) == PREV RANK hue XOR RANK shape < RANK pips`) from §5.1 gives base 0.750, m1 0,
> m3 = max/3, m4 from `p = 0.4375`, m5 = 0, and a maximum single-condition deviation of 0.1875 →
> **0.7844**. §5.2 prints **.785**. Every other row lands exactly on its printed digit. Assert with
> `absoluteTolerance: 0.001`, which both values satisfy. If any row misses by more than that, the
> metric is wrong, not the table — §5.1 is the normative owner and §5.2's column is its rounding.
> Record the band-7 discrepancy in `DECISIONS.md` when you confirm it.

### The metrics this depends on

All five come from E05·T02's `Law.Metrics`, resolved once in `Law.init`:

- `admitRate` — `popcount(T) / N`, where `N` is 256 or 65,536 depending on arity.
- `marginalDeficit` — §5.1's definition over the 16 (attribute, value) conditions φ. For contextual
  laws the conditions are on the **current** glyph: that is the quantity the player manipulates
  when they vary one attribute and watch the lamp, and it is the reading under which §5.2's band-5
  exemplar comes out at exactly .525.
- `leafCount`, `freeAttributeCount` — structural, from the AST.
- `scatteredSubsetCount` — leaves whose `subset4` is not a contiguous run of ranks. Add
  `Subset4.isScattered` beside the subset type E05 ships; the five scattered masks fall out of the
  definition and the test above counts them rather than listing them.

If any of these is missing from `Law` when you start, add it to `Law.Metrics` in E05's file rather
than computing it here — `difficulty(of:)` must stay O(1), and a contextual table costs ≈2 µs to
rebuild.

### `Corpora.handWritten(_:)`

The nine one-off laws the modifier tests need live in `HunchTestSupport`, as an
`enum HandWrittenLaw: CaseIterable` plus a `static func handWritten(_:) -> LawNode?`. They are
`let` values of an immutable `Sendable` type (`06 T10`). Each case carries a doc comment naming the
modifier it isolates and the arithmetic it is expected to produce, so a future reader can re-derive
the expected value without re-deriving the law.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DifficultyTests` is green.
- [ ] All eight of §5.2's exemplars reproduce their published δ within 0.001, and their `p` within
      0.001, from `difficulty(of:)` alone.
- [ ] The band-8 `COUNT` law asserts at admit rate 0.500, marginal deficit 0.286 and δ 0.906, and
      `Band.systemic.difficultyRange.contains(0.906)` is true while `marginalDeficit < 1.0`.
- [ ] `Difficulty.leafExcessMax + … + Difficulty.scatterMax == Difficulty.modifierCeiling`, and that
      ceiling is strictly less than `Band.width`.
- [ ] Each of m1…m5 has at least one test that pins its zero and at least one that pins its maximum.
- [ ] `grep -rn 'import SwiftUI\|Date()\|UUID()\|\.random(' HunchCore/Sources/LawGeneration/Difficulty.swift`
      returns nothing.
- [ ] `DECISIONS.md` carries the band-7 δ discrepancy with the hand computation that produced it.
- [ ] `tests.json` has a `difficulty(of:)` entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T01: difficulty(of:) with a per-modifier breakdown, asserted against §5.2's eight exemplars"`

## Out of scope

- `k`, `d`, `log₂|H|`, `Band.centre`, the achievable difficulty range and the Rasch coupling — **T02**.
- Par, cap, scoring and marks — **T07**.
- G8, which *uses* `difficulty(of:)` as its band-fidelity test — **T05**.
- Any calibration of the modifier weights against the harness (H10 may regenerate §5.1's weights;
  when it does, the test is never weakened) — **E11·T12**.
