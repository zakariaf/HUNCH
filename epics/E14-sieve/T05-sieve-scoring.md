# T05 — SIEVE scoring

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | SIEVE scoring (SIEVE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Scoring is where a `Double` becomes an `Int` exactly once, and the skill's type-choice rules decide the shape: a `SieveScore` value with stored `raw`, `idealResolved`, `ratio`, `completion`, `yield` and `score` rather than six computed properties recomputing each other, so the worked-run assertion can compare the whole record. It also carries the two-package `public` obligation — E15 and E16 both consume this type across the boundary. |
| `hunch-swift-testing` | The gate names *"§9.6's worked run reproduces (ratio 0.831, score 831, 2 marks)"*, which is a golden-value test on floating point — and `isApproximatelyEqual(_:_:absoluteTolerance:)` is hand-rolled in `HunchTestSupport` precisely because `swift-numerics` is banned and `#expect(a == b)` on a `Double` is a flake waiting to happen. |

`hunch-chrome-and-meta` is **not** loaded: nothing here is rendered. The score's *presentation* on the
Inscription is E09·T11's and its numerals are `numeral-readout.md`'s.

## Objective

At the end of this task a SIEVE run has a score, a mark count, a success bit and a Codex-page bit, all
derived from one `SieveScore` value in which accuracy and reach are charged **exactly once each** —
`ratio` normalised over *resolved* glyphs, multiplied by `completion` — and §9.6's worked band-5 run
reproduces to the digit: `ratio` 0.831, `score` 831, **2** marks.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.6 | the per-glyph weights and payoffs; `raw`, `idealResolved`, `ratio`, `completion`, `yield`; `score_SIEVE = round(1000·yield)`; the decision paragraph explaining why `ratio` is normalised over **resolved** glyphs and not over all `N`; the three mark thresholds read off `yield` with the zero-fouls-outside-the-tell clause on 3 marks; success iff **sieved and `ratio ≥ 0.80`**; the page at **`ratio ≥ 0.92`** marked with the SIEVE sigil, which then enters ECHO's pool; the Profile emission tuple; and the full worked run at band 5, tempo step 0 |
| `GAME_DESIGN.md` | §9.9 | FOUL-OUT-EARLY (`completion = 0.263`, `score ≈ 237`, and the explicit contrast with the pre-§9.6 double count's ≈ 69), ZERO-ACTION RUN (`yield ≈ 0.41` at `p = 0.30` → 0 marks, counted as a failure) |
| `GAME_DESIGN.md` | §6.9 | canon's scoring convention this section inherits: **multiply, then round once** |
| `GAME_DESIGN.md` | §8.2, §9.10 | a SIEVE page enters ECHO's pool, and SIEVE *"inscribes a Codex page only when sieved at `ratio ≥ 0.92`"* |
| `GAME_DESIGN.md` | §11.9 | SIEVE's Profile row: Tempo samples `clamp01(1 − median(gate-entry-to-tap latency) / mean window)` over **hits only**, at weight 0.7, and SIEVE also feeds Induction and Restraint. **This section is the single normative table**; §9.6 owns the transcript quantity only |
| `GAME_DESIGN.md` | §5.7 | the admit-rate window, which is what makes the ZERO-ACTION RUN's ≈ 0.41 an arithmetic consequence rather than a guess |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §7.9 | `swift-numerics` is banned; `isApproximatelyEqual` is five hand-written lines |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SieveScoreTests.swift`:

```swift
import Testing
import Glyphs
import Rounds
import HunchTestSupport

@Suite("SIEVE scoring — §9.6", .tags(.unit, .presubmission))
struct SieveScoreTests {

    // MARK: §9.6's worked run — the gate's headline assertion

    /// Law band 5, tempo step 0. N = 76; tell 12 (6 lawful / 6 unlawful, w = 0.5);
    /// run-out round(19) = 19; body 76 − 12 − 19 = 45; the 64 non-tell glyphs are 24 lawful / 40 unlawful.
    /// Player: tell — 4 hits of 6, 5 correct passes of 6, 1 false positive (no foul).
    ///         rest — 21 hits of 24, 38 correct passes of 40, 2 fouls. The run survives at 2 of 3.
    @Test("§9.6's worked run reproduces exactly: ratio 0.831, score 831, 2 marks")
    func workedRunFromSection96() {
        let tally = SieveTally(
            tell:   .init(hits: 4, correctPasses: 5, misses: 2, fouls: 1,
                          lawful: 6, unlawful: 6),
            rest:   .init(hits: 21, correctPasses: 38, misses: 3, fouls: 2,
                          lawful: 24, unlawful: 40))
        let score = SieveScore(tally: tally, glyphCount: 76, resolvedGlyphs: 76, ending: .sieved)

        #expect(isApproximatelyEqual(score.idealResolved, 399.0, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(score.raw, 331.5, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(score.ratio, 0.831, absoluteTolerance: 0.0005))
        #expect(score.completion == 1.0)
        #expect(isApproximatelyEqual(score.yield, score.ratio, absoluteTolerance: 1e-12))
        #expect(score.points == 831)
        #expect(score.marks == 2)
        #expect(score.isSuccess)                     // sieved and ratio ≥ 0.80
        #expect(score.inscribesCodexPage == false)   // below 0.92
    }

    // MARK: the two halves of the decision — each charged exactly once

    @Test("ideal is summed over RESOLVED glyphs only, so completion is not already inside ratio")
    func idealCoversOnlyWhatWasSeen() {
        let flawlessToGlyph20 = SieveTally(
            tell: .init(hits: 6, correctPasses: 6, misses: 0, fouls: 0, lawful: 6, unlawful: 6),
            rest: .init(hits: 3, correctPasses: 5, misses: 0, fouls: 3, lawful: 3, unlawful: 8))
        let score = SieveScore(tally: flawlessToGlyph20, glyphCount: 76,
                               resolvedGlyphs: 20, ending: .fouled)
        #expect(isApproximatelyEqual(score.completion, 20.0 / 76.0, absoluteTolerance: 1e-12))
        // The pre-§9.6 double count would have put 76 in the denominator of `ratio` too.
        let doubleCounted = score.ratio * score.completion * score.completion
        #expect(score.yield > doubleCounted)
    }

    @Test("FOUL-OUT-EARLY — third foul at glyph 20 of 76 caps the score near 237, not near 69 (§9.9)")
    func foulOutEarlyIsPricedCorrectly() {
        let almostFlawless = SieveTally(
            tell: .init(hits: 6, correctPasses: 6, misses: 0, fouls: 0, lawful: 6, unlawful: 6),
            rest: .init(hits: 3, correctPasses: 2, misses: 0, fouls: 3, lawful: 3, unlawful: 5))
        let score = SieveScore(tally: almostFlawless, glyphCount: 76,
                               resolvedGlyphs: 20, ending: .fouled)
        #expect(score.ratio > 0.80)
        #expect(score.yield <= 20.0 / 76.0)
        #expect(score.points >= 180 && score.points <= 265)
        #expect(score.points > 150)          // four times the ≈69 the double count produced
    }

    @Test("an early foul-out is still strictly worse than a cautious full run")
    func earlyFoulOutIsWorseThanCaution() {
        let cautious = SieveScore(tally: SieveTally(
            tell: .init(hits: 0, correctPasses: 6, misses: 6, fouls: 0, lawful: 6, unlawful: 6),
            rest: .init(hits: 0, correctPasses: 45, misses: 19, fouls: 0, lawful: 19, unlawful: 45)),
            glyphCount: 76, resolvedGlyphs: 76, ending: .sieved)
        let early = SieveScore(tally: SieveTally(
            tell: .init(hits: 6, correctPasses: 6, misses: 0, fouls: 0, lawful: 6, unlawful: 6),
            rest: .init(hits: 3, correctPasses: 2, misses: 0, fouls: 3, lawful: 3, unlawful: 5)),
            glyphCount: 76, resolvedGlyphs: 20, ending: .fouled)
        #expect(cautious.points > early.points)
    }

    @Test("ZERO-ACTION RUN — sieved, completion 1, yield ≈ ratio ≈ 0.41 at p ≈ 0.30, zero marks")
    func zeroActionRunScoresBelowOneMark() {
        let score = SieveScore(tally: SieveTally(
            tell: .init(hits: 0, correctPasses: 6, misses: 6, fouls: 0, lawful: 6, unlawful: 6),
            rest: .init(hits: 0, correctPasses: 45, misses: 19, fouls: 0, lawful: 19, unlawful: 45)),
            glyphCount: 76, resolvedGlyphs: 76, ending: .sieved)
        #expect(score.completion == 1.0)
        #expect(isApproximatelyEqual(score.ratio, 0.41, absoluteTolerance: 0.04))
        #expect(score.marks == 0)
        #expect(score.isSuccess == false)
    }

    // MARK: marks, read off yield

    @Test("marks are read off YIELD, so reach is charged to the mark as well as to the score",
          arguments: [(0.95, 0, 3), (0.95, 1, 2), (0.92, 0, 3), (0.919, 0, 2),
                      (0.80, 2, 2), (0.799, 0, 1), (0.60, 0, 1), (0.599, 0, 0)])
    func marksFromYield(_ yield: Double, _ foulsOutsideTheTell: Int, _ expected: Int) {
        #expect(SieveScore.marks(yield: yield, foulsOutsideTheTell: foulsOutsideTheTell) == expected)
    }

    @Test("three marks additionally require zero fouls outside the tell")
    func threeMarksNeedACleanRun() {
        #expect(SieveScore.marks(yield: 0.99, foulsOutsideTheTell: 0) == 3)
        #expect(SieveScore.marks(yield: 0.99, foulsOutsideTheTell: 1) == 2)
        // A foul INSIDE the tell does not disqualify — it never accrued (§9.5).
        #expect(SieveScore.marks(yield: 0.99, foulsOutsideTheTell: 0) == 3)
    }

    @Test("on a sieved run completion is 1 and yield == ratio, so the thresholds are the calibrated ones")
    func sievedRunsCollapseToRatio() {
        let score = SieveScore(tally: .flawless(glyphCount: 60), glyphCount: 60,
                               resolvedGlyphs: 60, ending: .sieved)
        #expect(score.completion == 1.0)
        #expect(score.yield == score.ratio)
    }

    // MARK: success, the page, and the clamp at zero

    @Test("success iff sieved AND ratio ≥ 0.80 — both halves are load-bearing",
          arguments: [(SieveEnding.sieved, 0.80, true), (.sieved, 0.799, false),
                      (.fouled, 0.99, false), (.abandoned, 0.99, false), (.voided, 0.99, false)])
    func successConditions(_ ending: SieveEnding, _ ratio: Double, _ expected: Bool) {
        #expect(SieveScore.isSuccess(ending: ending, ratio: ratio) == expected)
    }

    @Test("a Codex page is minted iff sieved and ratio ≥ 0.92",
          arguments: [(SieveEnding.sieved, 0.92, true), (.sieved, 0.9199, false),
                      (.fouled, 1.0, false), (.abandoned, 1.0, false)])
    func pageConditions(_ ending: SieveEnding, _ ratio: Double, _ expected: Bool) {
        #expect(SieveScore.inscribesCodexPage(ending: ending, ratio: ratio) == expected)
    }

    @Test("a page minted here is marked with the SIEVE sigil and is eligible for ECHO's pool")
    func pageCarriesTheSieveMark() {
        let score = SieveScore(tally: .flawless(glyphCount: 60), glyphCount: 60,
                               resolvedGlyphs: 60, ending: .sieved)
        #expect(score.inscribesCodexPage)
        #expect(score.pageMode == .sieve)
        #expect(score.pageIsEchoPoolEligible)
    }

    @Test("raw is clamped at zero before the division — a catastrophic run scores 0, never negative")
    func rawIsClampedAtZero() {
        let disaster = SieveScore(tally: SieveTally(
            tell: .init(hits: 0, correctPasses: 0, misses: 6, fouls: 6, lawful: 6, unlawful: 6),
            rest: .init(hits: 0, correctPasses: 0, misses: 0, fouls: 2, lawful: 0, unlawful: 2)),
            glyphCount: 76, resolvedGlyphs: 20, ending: .fouled)
        #expect(disaster.raw < 0)
        #expect(disaster.ratio == 0)
        #expect(disaster.points == 0)
    }

    @Test("the multiply happens before the single rounding (§6.9)")
    func multiplyThenRoundOnce() {
        // 0.8305 · 1000 = 830.5 → 831 (banker's rounding would give 830).
        #expect(SieveScore.points(yield: 0.8305) == 831)
        #expect(SieveScore.points(yield: 0.0004) == 0)
    }

    // MARK: the Profile emission

    @Test("SIEVE emits the four-tuple §11.9 consumes, and nothing shaped like an axis value")
    func profileEmission() {
        let score = SieveScore(tally: .flawless(glyphCount: 60), glyphCount: 60,
                               resolvedGlyphs: 60, ending: .sieved)
        let sample = score.profileSample(medianHitLatency: .milliseconds(300),
                                         meanWindowOverHits: .milliseconds(600))
        #expect(sample.ratio == score.ratio)
        #expect(sample.completion == score.completion)
        #expect(isApproximatelyEqual(sample.tempo ?? -1, 0.5, absoluteTolerance: 1e-9))
        #expect(sample.feedsInduction && sample.feedsRestraint)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SieveScoreTests`

Expect missing `SieveScore`, `SieveTally`, `SieveTally.Reach`, `SieveTally.flawless(glyphCount:)` and
`SieveProfileSample`. Confirm `workedRunFromSection96` fails on a missing symbol; if it ever passes
without the implementation, the tally type is doing the arithmetic and the score type is a shell.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SieveScore.swift` — `SieveScore`, `SieveTally`, the three mark thresholds, `isSuccess`, `inscribesCodexPage` |
| create | `HunchCore/Sources/Rounds/SieveProfileSample.swift` — the four-tuple §11.9 consumes |
| modify | `HunchCore/Sources/Rounds/SieveRunState.swift` — accumulate a `SieveTally` as glyphs resolve; expose `score` at `settled` |
| modify | `HunchCore/Sources/Archive/CodexPage.swift` — nothing structural; assert the existing `modesSeen` bit accepts `.sieve` |
| create | `HunchCore/Tests/RoundsTests/SieveScoreTests.swift` |
| modify | `tests.json` — six entries: worked run, ratio-over-resolved, marks-off-yield, three-marks-clean, success condition, page condition |
| modify | `DECISIONS.md` — where the steady-stream multiplier is applied (see T09; the *seam* is created here) |

## Implementation notes

### The tally, then the score — two types, because they answer different questions

```swift
public struct SieveTally: Hashable, Sendable {
    public struct Reach: Hashable, Sendable {
        public var hits: Int
        public var correctPasses: Int
        public var misses: Int
        public var fouls: Int
        public var lawful: Int          // how many lawful glyphs were RESOLVED in this reach
        public var unlawful: Int        // how many unlawful glyphs were RESOLVED in this reach
    }
    public var tell: Reach              // weight 0.5
    public var rest: Reach              // body + run-out, weight 1.0
}
```

`rest` collapses body and run-out because §9.6 weights them identically and never distinguishes them
in the arithmetic. Keeping three would invite a third weight that does not exist. What must **not**
collapse is `tell` versus `rest`: the 0.5 weight is applied to the tell's payoffs *and* to the tell's
share of `idealResolved`, which is why the worked run's ideal is `39 + 360` and not `78 + 360`.

```swift
public struct SieveScore: Hashable, Sendable {
    public let raw: Double              // Σ over resolved glyphs of wᵢ · payoff
    public let idealResolved: Double    // Σ over resolved i of wᵢ · (lawful ? 10 : 3)
    public let ratio: Double            // max(0, raw) / idealResolved      — accuracy
    public let completion: Double       // resolvedGlyphs / N               — reach
    public let yield: Double            // ratio · completion
    public let points: Int              // round(1000 · yield)
    public let marks: Int
    public let isSuccess: Bool
    public let inscribesCodexPage: Bool
}
```

Everything is stored, computed once in `init`. Six computed properties each recomputing the previous
one is how `ratio` ends up defined twice, and the whole §9.6 decision is a story about a quantity
that was accidentally applied twice.

### The one arithmetic trap, spelled out

`idealResolved` sums over **resolved** glyphs only. On a fouled-out run the unresolved glyphs are in
neither numerator nor denominator, so `ratio` is a clean accuracy figure over what the player
actually saw, and `completion` is the only place reach is charged. §9.6's decision paragraph gives
the number this prevents: a flawless player fouling out at glyph 20 of 76 scored ≈ 69 under the
double count, *"roughly 7 % of a completed run and about four times harsher than the mode's own
edge-case table claims."* The `foulOutEarlyIsPricedCorrectly` test is that paragraph made executable.

`max(0, raw)` clamps before the division, not after: a run with more fouls than hits has a negative
`raw`, and a negative `ratio` would multiply with `completion` into a *less* negative number, which
would make quitting early literally scoring.

### Marks, and the one clause that is not a threshold

```swift
public static func marks(yield: Double, foulsOutsideTheTell: Int) -> Int {
    if yield >= 0.92, foulsOutsideTheTell == 0 { 3 }
    else if yield >= 0.80 { 2 }
    else if yield >= 0.60 { 1 }
    else { 0 }
}
```

Three notes. **Marks read `yield`, not `ratio`** — §9.6 is explicit that reach is charged to the mark
as well as to the score, and on a sieved run `completion = 1` so the thresholds are exactly the
completed-run thresholds they were calibrated as. **The three-mark clause counts fouls *outside* the
tell** — a tell foul never accrued (T04), so it cannot disqualify. And **a run that clears 0.92 with
one foul falls to 2, not to 0**: the `else if` chain is deliberate; do not rewrite it as a guard that
returns 0.

### Success and the page are two different thresholds and two different consumers

- **Success** (`sieved && ratio ≥ 0.80`) is what the Rasch update sees — E11·T02's estimator takes a
  `Bool`. It reads `ratio`, not `yield`: a run cut short by fouls is already a failure by the
  `sieved` half, so charging reach twice here would be the same double count in a different costume.
- **The page** (`sieved && ratio ≥ 0.92`) is what E15 mints and what E13's pool later selects from.
  Set `pageMode = .sieve` so E15·T05's instrument strip draws the SIEVE sigil and E13·T01's pool
  accepts it. §9.5's transition table gives the reason the law is revealed in rule-tiles on a sieved
  run at all: *"a page that may enter ECHO's pool must have been stated at least once."*

Note the asymmetry that is easy to get backwards: the page needs `ratio ≥ 0.92` while three marks
need `yield ≥ 0.92`. On a sieved run they coincide; on an abandoned run (T08) they do not, and §9.8
says the page gate for an abandoned run is `yield ≥ 0.92`. Model that as
`inscribesCodexPage(ending:ratio:yield:)` taking both, with the `sieved` branch reading `ratio` and
the `abandoned` branch reading `yield` — and put the citation on each branch.

### The score multiplier seam

T09's steady stream multiplies the **score by 0.85**. Create the seam here so T09 is a one-line
change and not a refactor:

```swift
public init(tally: SieveTally, glyphCount: Int, resolvedGlyphs: Int,
            ending: SieveEnding, scoreMultiplier: Double = 1.0)
```

`scoreMultiplier` folds into `points = Int((1000 * yield * scoreMultiplier).rounded())` — **multiply
then round once** (§6.9) — and touches `yield`, `ratio`, `marks`, `isSuccess` and
`inscribesCodexPage` not at all. §9.8 calls it a *score* multiplier and separately guarantees that
steady stream *"does not disable Codex inscription"*; applying it to `yield` would silently move both
the mark thresholds and the page gate, which is the reading that sentence rules out. Record it in
`DECISIONS.md` with that reasoning.

### The Profile emission is a tuple, not an axis value

§11.9 is the **single normative table** for all five axes; §9.6 owns only the transcript quantities.
So `SieveProfileSample` carries `(medianHitLatency, meanWindowOverHits, ratio, completion)` plus the
derived Tempo sample `clamp01(1 − median / meanWindow)` and the two flags saying it also feeds
Induction and Restraint. It carries **no EWMA constant, no α, no weight** — those are E16·T06's.
`tempo` is `Double?` and is `nil` under `.steady` and `.stepped` pacing (T09); this task creates the
optionality, T09 fills in when it is `nil`.

§9.6's closing sentence is a useful guard against a whole class of future bug: *"SIEVE has no
quantity ranging 0–12 and no notion of a tier — any axis definition that reads one is reading a field
that does not exist."* If a later reviewer asks for a "tier" field, the answer is that sentence.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveScoreTests` green — all 14 tests, with `workedRunFromSection96` producing `ratio` 0.831, `points` 831 and `marks` 2.
- [ ] `grep -n "var ratio: Double {" HunchCore/Sources/Rounds/SieveScore.swift` returns nothing — every quantity is stored, computed once in `init`.
- [ ] `grep -n "rounded()" HunchCore/Sources/Rounds/SieveScore.swift` appears exactly once.
- [ ] `SieveScore.marks` reads `yield` and `SieveScore.isSuccess` reads `ratio`, each with its §9.6 citation in the doc comment — verified by reading the file.
- [ ] `scoreMultiplier` appears in the `points` expression and in no other expression in the file.
- [ ] `tests.json` carries the six entries, including the worked run with its three expected values.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes turning the stored quantities into computed properties, decline: the whole §9.6 decision is about a quantity applied twice, and one stored value is the structural defence.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically whether `completion` can appear anywhere in `ratio`'s derivation.
4. Commit: `git commit -m "E14/T05: SIEVE scoring — ratio over resolved, marks off yield"`

## Out of scope

- Where the 0.85 multiplier comes from and when it applies — **T09**. This task only creates the parameter.
- The abandoned run's `ratio`/`completion` at the last resolved glyph, and the void record — **T08**.
- Minting, deduplicating and drawing the Codex page — **E15·T01/T05/T06**. This task sets two bits.
- Adding the page to ECHO's pool — **E13·T01**.
- The Rasch update that consumes `isSuccess` — **E11·T02**.
- The Profile's α, weight, `n` cap and idle decay — **E16·T06**. This task emits a sample.
- Rendering the score, the marks or the ticks on the Inscription — **E09·T10/T11**.
