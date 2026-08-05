# T07 — Par, cap, scoring and marks

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 Par / cap / scoring |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | `Score` goes in the `Rounds` target, not `LawGeneration` — `08 §1`'s tree names it there — and this task is where the temptation to invent a `ScoreCalculator` or a `Constants.swift` is highest. Both are named bans. |
| `hunch-swift-testing` | Every number here is checked by reproducing §6.9's three worked rounds exactly, which is a golden-value test on `Double` arithmetic; the multiply-then-round-once rule only shows up as a test if the intermediate is never rounded, and `isApproximatelyEqual` is required for the `economy` comparisons. |

## Objective

Par and cap stop being a copied table and become a derivation: par from §5.4's `k·log₂|H| + d`, cap
from `ceil(1.6·par)`. `Score` computes points and marks with §6.9's evaluation order, and the three
worked rounds of §6.9 reproduce numerically.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.4 | The par table with its `k` and `d`, `cap = ceil(1.6 × par)`, par-is-soft/cap-is-hard, and the band-8 argument |
| `GAME_DESIGN.md` | §6.9 | The scoring block verbatim, the evaluation order, the three mark thresholds, the three worked rounds, and the decision that the middle threshold does not move |
| `GAME_DESIGN.md` | §5.7 | Par and cap as locked constants |
| `GAME_DESIGN.md` | §1.8 | Why probe economy is rewarded without punishing careful play — the reason the gradient is flat below par |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2 | `Score` lives in `HunchCore/Sources/Rounds/`; the par tick row's geometry is app-layer and is not this file |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/ScoreTests.swift`:

```swift
import Foundation
import Testing
import LawGeneration
import Rounds
import HunchTestSupport

@Suite("Par, cap, scoring and marks", .tags(.unit, .presubmission))
struct ScoreTests {

    // MARK: the two locked columns

    @Test("cap is derived from par and never stored", arguments: Band.allCases)
    func capIsDerivedFromPar(_ band: Band) {
        #expect(band.cap == Int((1.6 * Double(band.par)).rounded(.up)))
    }

    @Test("par rises monotonically except where §5.4 says it does not")
    func parIsMonotoneApartFromTheKnownFlat() {
        let pars = Band.allCases.map(\.par)
        #expect(pars == pars.sorted())
        // bands 5 and 6 share a par: §5.4 gives them different k and d that land on the same ceil.
        #expect(Band.contextual.par == Band.guarded.par)
        #expect(Band.contextual.frictionCoefficient != Band.guarded.frictionCoefficient)
    }

    /// §5.4's whole argument: band 8's hypothesis space is *smaller* than band 2's, and it is still
    /// the most expensive band. A difficulty function based on entropy would invert this.
    @Test("Band 8 costs more probes than band 2 despite a smaller hypothesis space")
    func bandEightIsTheArgumentForTheLadder() {
        #expect(Band.systemic.population < Band.pair.population)
        #expect(Band.systemic.logPopulation < Band.pair.logPopulation)
        #expect(Band.systemic.par > Band.pair.par)
    }

    // MARK: the scoring arithmetic

    @Test("A zero-probe declaration is guarded")
    func zeroProbesIsGuarded() {
        #expect(Score(par: 7, probesUsed: 0, strikes: 0).points
             == Score(par: 7, probesUsed: 1, strikes: 0).points)
    }

    @Test("The gradient is flat at or below par", arguments: 1...23)
    func flatBelowPar(_ probes: Int) {
        #expect(Score(par: 23, probesUsed: probes, strikes: 0).points == 1000)
    }

    @Test("Past par the score decays as par/probes")
    func decaysPastPar() {
        #expect(Score(par: 20, probesUsed: 24, strikes: 0).points == 833)
        #expect(Score(par: 20, probesUsed: 40, strikes: 0).points == 500)
    }

    /// §6.9: multiply then round **once**, so a strike never produces a fractional intermediate.
    /// The separating case is band 8 at 36 probes: 1000 × 29/36 × 0.6 = 483.33 → **483**, while
    /// rounding the unstruck score first gives 806 × 0.6 = 483.6 → **484**. Most probe counts agree
    /// under both orders, which is exactly why the wrong order survives casual testing.
    @Test("Evaluation is multiply-then-round-once")
    func multiplyThenRoundOnce() {
        #expect(Score(par: 29, probesUsed: 36, strikes: 1).points == 483)
        #expect(Score(par: 29, probesUsed: 36, strikes: 0).points == 806)
        #expect(Score(par: 29, probesUsed: 36, strikes: 1).points
             != Int((Double(Score(par: 29, probesUsed: 36, strikes: 0).points) * 0.6)
                        .rounded(.toNearestOrAwayFromZero)))
        #expect(Score(par: 20, probesUsed: 24, strikes: 1).points == 500)
    }

    @Test("A strike costs exactly the §6.9 multiplier and a second strike does not score at all")
    func strikePenalty() {
        #expect(Score(par: 23, probesUsed: 10, strikes: 0).points == 1000)
        #expect(Score(par: 23, probesUsed: 10, strikes: 1).points == 600)
        #expect(Score.lost.points == 0)
        #expect(Score.lost.marks == 0)
    }

    @Test("Rounding is to-nearest-away-from-zero, not to-even")
    func roundingIsAwayFromZero() {
        // The only band/probe pair inside a real budget that lands on an exact .5 intermediate:
        // band 2, par 13, probe 16 → 1000 × 13/16 = 812.5. Away-from-zero gives 813; a banker's
        // rounding — which is what `Int(x + 0.5)` and `NSDecimalNumber` defaults tend to produce —
        // gives 812.
        #expect(Score(par: Band.pair.par, probesUsed: 16, strikes: 0).points == 813)
    }

    // MARK: marks

    @Test("The three mark thresholds are 0.6·par, par and cap", arguments: Band.allCases)
    func markThresholds(_ band: Band) {
        let third = Int((0.6 * Double(band.par)).rounded(.down))
        #expect(Score(par: band.par, probesUsed: third, strikes: 0).marks == 3)
        #expect(Score(par: band.par, probesUsed: band.par, strikes: 0).marks == 2)
        #expect(Score(par: band.par, probesUsed: band.par + 1, strikes: 0).marks == 1)
        #expect(Score(par: band.par, probesUsed: band.cap, strikes: 0).marks == 1)
    }

    /// §6.9 rules explicitly that the middle threshold does **not** move in to 0.85·par: at band 8
    /// that would put the 2-mark boundary at probe 24 against a budget of 29, taxing exactly the
    /// careful play the flat gradient protects.
    @Test("The middle threshold is par itself, not 0.85·par")
    func middleThresholdDoesNotMoveIn() {
        let band = Band.systemic
        let eightyFive = Int((0.85 * Double(band.par)).rounded(.down))
        #expect(Score(par: band.par, probesUsed: eightyFive + 1, strikes: 0).marks == 2)
    }

    @Test("Marks and the strike are independent records")
    func marksAndFractureAreIndependent() {
        let struck = Score(par: 23, probesUsed: 13, strikes: 1)
        #expect(struck.marks == 3)                    // a 3-mark fractured page exists (§6.9)
        #expect(struck.points == 600)
    }

    // MARK: §6.9's three worked rounds, reproduced

    @Test("Round A — band 5, one declaration at probe 13")
    func workedRoundA() {
        let score = Score(par: Band.contextual.par, probesUsed: 13, strikes: 0)
        #expect(score.points == 1000)
        #expect(score.marks == 3)
    }

    @Test("Round B — band 4, strike at 17, correct at 24")
    func workedRoundB() {
        let score = Score(par: Band.relational.par, probesUsed: 24, strikes: 1)
        #expect(isApproximatelyEqual(Score.economy(par: Band.relational.par, probesUsed: 24),
                                     0.8333, absoluteTolerance: 0.0001))
        #expect(score.points == 500)
        #expect(score.marks == 1)
    }

    @Test("Round C — band 6, two strikes, nothing inscribed")
    func workedRoundC() {
        #expect(Band.guarded.par == 23)
        #expect(Band.guarded.cap == 37)
        #expect(Score.lost.points == 0)
    }

    @Test("Round C′ — the same band reaching the cap with no declaration scores zero too")
    func workedRoundCPrime() {
        #expect(Score.lost.points == 0)
        #expect(Score.lost.marks == 0)
    }

    // MARK: the incentive §6.9 computes

    /// §6.9's expected-value comparison between patient and spam play. Reproducing it here is what
    /// stops a later "small" change to the strike multiplier from quietly inverting the incentive.
    @Test("Patient play dominates spam play by the margin §6.9 computes")
    func patientPlayDominates() {
        let patient = 0.62 * 1000 + 0.38 * 0.474 * 600
        let spam    = 0.03 * 1000 + 0.97 * 0.62 * 600
        #expect(patient > spam)
        #expect(isApproximatelyEqual((patient - spam) / patient, 0.46, absoluteTolerance: 0.01))
        #expect(isApproximatelyEqual(Score.strikeMultiplier * 1000, 600, absoluteTolerance: 1e-9))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ScoreTests`
The `Rounds` target exists in the manifest from E01·T03 but has no source yet, so the first failure
is a missing `Score`.

**Step 3 — implement.** Files below.

**Step 4 — green, then refactor.** Check that `cap` is not stored anywhere; if E05·T06 shipped
`cap(for:)` as a literal table, replace it with the derivation and let the eight assertions above be
what proves the replacement is faithful.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/Score.swift` |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — `cap` becomes derived from `par`, if it was not already |
| create | `HunchCore/Tests/RoundsTests/ScoreTests.swift` |
| modify | `HunchCore/Package.swift` — `Rounds` depends on `LawGeneration` (for `Band`); the target itself already exists from E01·T03 |
| modify | `tests.json` — one entry for Par / cap / scoring |

## Implementation notes

### `Score`

```swift
/// §6.9's scoring, as a value. Only an inscribed round is scored; `broken`, `exhausted`,
/// `abandoned` and `voided` all take `Score.lost`. The `Outcome` switch that decides which is
/// E07's — this type does the arithmetic and nothing else.
public struct Score: Hashable, Sendable {
    public let points: Int
    public let marks: Int

    /// - Parameter probesUsed: guarded to at least 1, so a probe-0 declaration cannot divide by zero.
    public init(par: Int, probesUsed: Int, strikes: Int)

    public static let lost = Score(points: 0, marks: 0)

    /// Exposed for the worked-round tests and for E08's instrument bar, which needs the ratio and
    /// not the points.
    public static func economy(par: Int, probesUsed: Int) -> Double

    /// §6.9's strike multiplier, as one named constant so no call site multiplies by a literal.
    public static let strikeMultiplier: Double
}
```

Three rules the implementation must not soften:

1. **Multiply then round once.** `Int((1000.0 * economy * penalty).rounded(.toNearestOrAwayFromZero))`
   in one expression. Rounding `economy` first produces a different number for round B, and that is
   exactly the test above.
2. **`.toNearestOrAwayFromZero`, not the default.** Swift's `rounded()` is
   to-nearest-**away-from-zero** already, but write the rule explicitly so a later reader does not
   "clean it up" to `Int(x + 0.5)` or to a banker's rounding.
3. **Marks are computed from `probesUsed` and `par` alone**, never from `points`. §6.9 rules that
   marks and the fracture are independent records; a 3-mark fractured page exists and is drawn with
   three marks and a crack.

### `cap` is derived, and `par` is checked

`Band.cap` becomes `Int((1.6 * Double(par)).rounded(.up))`. `Band.par` stays a stored table — §5.4's
`k` and `d` are design-time priors and §5.7 locks the eight par values — but T02's
`parIsRecomputable` test already proves the stored column equals `ceil(k·log₂|H| + d)`. Between the
two tests, changing `|H|` without changing `par`, or changing `par` without changing `k` or `d`,
fails the build. That is the coupling §5.4 asks for when it says the par column would be regenerated
empirically if the harness disagreed by more than 20 %.

### What this task does *not* decide

`Outcome` does not exist yet — E07·T07 ships it — so "only `inscribed` scores" is expressed here as
`Score.lost` plus a doc comment naming the rule and its owner. Round C and C′ are therefore asserted
as `Score.lost`, which is honest about what this layer can prove: the arithmetic is here, the
outcome gating arrives with the outcome. E07·T08's acceptance criteria include re-asserting round C
through the real `Outcome` switch.

`par_DRIFT` and `cap_DRIFT` (§7.7's six-row table, 25…40 / 40…64) are a different table with a
different derivation and belong to E12·T04. Do not generalise `Score.init` to take them now; when
E12 arrives, the substitution §7.7 describes is "canon's formula with `par_DRIFT` substituted", and
`Score(par:probesUsed:strikes:)` already takes par as an argument.

### The tick row is not here

§5.4's "par renders as a row of unlit tick marks" and §6.9's par crossing are `HunchUI` and
`LoomFeature`. `08 §2` names the par tick row as the canonical example of something that looks core
and is layout: `tickPitch = min(nominalPitch, rowWidth/N)` needs a row width, and the moment a row
width enters `HunchCore` the 10-second suite starts needing a device idiom.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ScoreTests` is green.
- [ ] `band.cap == ceil(1.6 · band.par)` for all eight bands, and `cap` is stored nowhere —
      `grep -n '12\|21\|26\|32\|37\|42\|47' HunchCore/Sources/LawGeneration/Band.swift` shows no cap
      table.
- [ ] `Score(par:probesUsed:strikes:)` pays 1000 for every probe count at or below par, decays as
      `par/probes` past it, and applies the strike multiplier before the single rounding.
- [ ] §6.9's three worked rounds reproduce: 1000 with 3 marks; 500 with 1 mark and a strike; 0.
- [ ] The mark thresholds are `0.6·par` / `par` / `cap` for all eight bands, and a test pins the
      middle threshold at `par` rather than `0.85·par`.
- [ ] A 3-mark result with a strike exists and scores 600 — marks and fracture are independent.
- [ ] `Score.strikeMultiplier` is the only place the strike penalty appears as a number.
- [ ] `tests.json` has a Par / cap / scoring entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T07: par derived from k·log₂|H|+d, cap from ceil(1.6·par), §6.9 scoring and marks"`

## Out of scope

- `Outcome`, `Probe`, `Ribbon` and applying the score to a round — **E07·T07–T08**.
- The par tick row, the par crossing and the instrument bar — **E08·T08**.
- The Seal's three marks striking in at reveal beat 6 — **E09·T10**.
- `par_DRIFT` / `cap_DRIFT` and DRIFT's `rec(b)` mark condition — **E12·T04**.
- ECHO's and SIEVE's scoring, which are different formulas entirely — **E13·T08**, **E14·T05**.
- Run totals, which are the plain sum of round scores with no multiplier — **E17·T03**.
