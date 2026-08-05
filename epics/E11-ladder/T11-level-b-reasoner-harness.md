# T11 — Level B — `ReasonerHarness`

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T10 |
| **Delivers** | §14.1 Simulated player harness (Level B) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns brief invariant 3 and its declarative gate — `.enabled(if: ProcessInfo…["HUNCH_CALIBRATION"] == "1")` plus `.tags(.integration, .nightly)` plus `.timeLimit(.minutes(15))` as a **hang guard and not a benchmark** (`06 T26`) — owns §14.5 decision 5's cadence (fast subset every commit, full matrix nightly and before any archive), owns the rule that the smoke subset stays in the fast suite so the harness cannot rot, and owns `06 T58`: a slow test is gated, never deleted. |

## Objective

`ReasonerHarness` plays a real generated law: it holds a posterior over a materialised hypothesis
space weighted by a deliberately wrong human family prior, probes greedily for maximum expected
entropy reduction with ability entering as search breadth, substitutes a Wason positive test with a
probability that falls as ability rises, declares on a posterior threshold, ingests a counterexample as
a hard constraint, and reports `(band, δ, probes, strikes, firstDeclCorrect, won)`. At the end of this
task the 8 × 20 × 20 smoke subset runs in the fast suite and the 640 k matrix runs behind
`HUNCH_CALIBRATION=1` inside the fifteen-minute guard.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.10 | Level B's five numbered steps verbatim: the prior and its weights, the candidate-set size `m`, the Wason substitution probability, the declare threshold `τ`, the `par + Poisson(2)` and cap stopping rules, the MAP/second-mass declaration, the strike-1 recovery loop, and the emitted tuple. Plus the runtime split and the smoke subset's size |
| `GAME_DESIGN.md` | §5.4 | The friction coefficient `k`, the discovery cost `d`, the par table, the 20,000-sample rule for bands 5 and 7 with its `log₂(\|H\|/20000)` correction, and the sentence *"The harness must reproduce this table, not be told it"* |
| `GAME_DESIGN.md` | §5.2 | The eight `\|H\|` counts the prior is defined over; the three enforced jumps |
| `GAME_DESIGN.md` | §4.5 | Verdict by extension comparison; the counterexample's four deterministic selection steps; two strikes |
| `GAME_DESIGN.md` | §3.5 | `prev` is the previously **probed** glyph regardless of verdict; the seed glyph primes position 0 and is not a probe |
| `GAME_DESIGN.md` | §10.10 | H10, H11, H12 and H20 — the four invariants only Level B can carry |
| `GAME_DESIGN.md` | §14.5 decision 5 | The CI cadence |
| `GAME_DESIGN.md` | §14.6 risk 3 | If ρ fails, regenerate §5.1's weights; never weaken the test |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | The Level-A/B split as the thing that protects the ten-second budget |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/ReasonerHarnessTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import Ladder
import HunchTestSupport

@Suite("Level B — ReasonerHarness", .tags(.unit, .presubmission))
struct ReasonerHarnessTests {

    // MARK: the prior

    /// §10.10 step 2: the prior is "deliberately mis-specified" and the mis-specification IS the
    /// mechanism that produces the discovery cost `d`. Assert the weights are the published ones
    /// and that they do NOT match the true band populations — a correct prior would make band 8
    /// the easiest band and §5.4's whole argument false.
    @Test("The human family prior is the published one, and it is wrong")
    func priorIsDeliberatelyWrong() {
        let prior = HumanFamilyPrior.weights
        #expect(prior.count == 8)
        #expect(isApproximatelyEqual(prior.reduce(0, +), 1.0, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(prior[0], 0.34, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(prior[7], 0.01, absoluteTolerance: 1e-9))

        // Band 8 is the smallest real space (337) and the *least* expected a priori — the
        // inversion that makes it hardest despite having the smallest |H|.
        let byPopulation = Band.allCases.sorted { $0.population < $1.population }
        #expect(byPopulation.first == .literal)
        #expect(prior[Band.systemic.rawValue - 1] < prior[Band.pair.rawValue - 1])
    }

    @Test("The prior is renormalised over bands 1…served and never leaks a higher band",
          arguments: Band.allCases)
    func priorIsTruncated(_ served: Band) {
        let p = HumanFamilyPrior.truncated(upTo: served)
        #expect(isApproximatelyEqual(p.reduce(0, +), 1.0, absoluteTolerance: 1e-9))
        for band in Band.allCases where band > served {
            #expect(p[band.rawValue - 1] == 0)
        }
    }

    // MARK: ability as search breadth

    /// §10.10 step 3: `m = clamp(round(4 + 28·σ(θ)), 4, 32)` — "ability enters as search breadth,
    /// the honest model of what ability means here".
    @Test("Candidate-set size is the published function of ability",
          arguments: [(-6.0, 4), (-2.0, 7), (0.0, 18), (2.0, 29), (6.0, 32)])
    func searchBreadth(_ ability: Double, _ expected: Int) {
        #expect(ReasonerHarness.candidateCount(ability: ability) == expected)
    }

    /// §10.10 step 3: "With probability (1 − σ(θ))·0.30, substitute a Wason positive-test probe
    /// instead; ability reduces the bias."
    @Test("The Wason substitution probability falls as ability rises")
    func wasonBiasFallsWithAbility() {
        #expect(ReasonerHarness.wasonProbability(ability: -3) > 0.28)
        #expect(ReasonerHarness.wasonProbability(ability: 0) > 0.14)
        #expect(ReasonerHarness.wasonProbability(ability: 4) < 0.006)
        #expect(ReasonerHarness.wasonProbability(ability: -6)
                <= ReasonerHarness.wasonSubstitutionCeiling)
    }

    @Test("A Wason probe is a positive test: it maximises expected admission, not information")
    func wasonProbeIsPositive() throws {
        var reasoner = try #require(Reasoner(band: .pair, ability: 0.0, seed: 0x4A5_0E17_0B15))
        let information = reasoner.informationMaximisingCandidate()
        let positive = reasoner.positiveTestCandidate()
        #expect(reasoner.expectedAdmitProbability(of: positive)
                >= reasoner.expectedAdmitProbability(of: information))
    }

    // MARK: the declare rule

    @Test("τ rises with ability, from 0.55 toward 0.90")
    func declareThreshold() {
        #expect(isApproximatelyEqual(ReasonerHarness.declareThreshold(ability: -6), 0.55,
                                     absoluteTolerance: 0.01))
        #expect(isApproximatelyEqual(ReasonerHarness.declareThreshold(ability: 0), 0.725,
                                     absoluteTolerance: 0.005))
        #expect(ReasonerHarness.declareThreshold(ability: 6) < 0.90)
    }

    /// §5.4's sentence, made a guard rather than a hope: if the par-timeout rule dominates, H12
    /// is measuring its own input and the "reproduce the table, not be told it" claim is void.
    @Test("The posterior threshold, not the par timeout, ends the median round",
          arguments: Band.allCases)
    func parTimeoutIsNotTheDominantStoppingRule(_ band: Band) {
        let run = ReasonerHarness.smoke(band: band, laws: 20, roundsPerLaw: 20, seed: 0x570B_1DDE)
        #expect(run.share(of: .parTimeout) < 0.50,
                "band \(band.rawValue): \(run.share(of: .parTimeout)) of rounds stopped on the par timeout")
    }

    // MARK: the round

    @Test("The reasoner never sees the law, only verdicts")
    func reasonerIsBlind() throws {
        let transcript = ReasonerHarness.play(law: Corpora.handWrittenLaw(.statelessAtom),
                                              band: .literal, ability: 0.0, seed: 42)
        #expect(transcript.observedVerdicts.count == transcript.probesUsed)
        #expect(transcript.hypothesisSpaceSizeAtStart > 1)
    }

    /// §3.5: `prev` is the previously *probed* glyph regardless of verdict, and the seed glyph
    /// primes position 0 without being a probe. A harness that gets this wrong scores every
    /// contextual band wrong and H11's band-5 row silently inverts.
    @Test("Contextual rounds thread prev correctly and the seed glyph is not a probe")
    func contextIsThreadedCorrectly() throws {
        let transcript = ReasonerHarness.play(law: Corpora.handWrittenLaw(.contextualStrictIncrease),
                                              band: .contextual, ability: 1.0, seed: 7)
        #expect(transcript.probes.first?.previous == transcript.seedGlyph)
        for (i, probe) in transcript.probes.enumerated() where i > 0 {
            #expect(probe.previous == transcript.probes[i - 1].glyph)
        }
        #expect(!transcript.probes.map(\.glyph).contains(transcript.seedGlyph) ||
                transcript.probes.first?.glyph != transcript.seedGlyph)
    }

    /// §10.10 step 5: "ingest the counterexample as a hard constraint, filter H".
    @Test("A counterexample is a hard constraint the posterior can never violate again")
    func counterexampleIsAHardConstraint() throws {
        let run = ReasonerHarness.smoke(band: .relational, laws: 20, roundsPerLaw: 20, seed: 0xCE)
        for transcript in run.transcripts where transcript.strikes >= 1 {
            let ce = try #require(transcript.counterexample)
            #expect(transcript.survivingHypothesesAfterStrike
                        .allSatisfy { $0.agrees(with: ce) })
        }
    }

    @Test("Two strikes end the round, and there is never a third declaration")
    func twoStrikesIsHard() {
        let run = ReasonerHarness.smoke(band: .exclusive, laws: 20, roundsPerLaw: 20, seed: 0x2)
        #expect(run.transcripts.allSatisfy { $0.strikes <= 2 })
        #expect(run.transcripts.allSatisfy { $0.declarations.count <= 2 })
        #expect(run.transcripts.filter { $0.strikes == 2 }.allSatisfy { !$0.won })
    }

    @Test("The cap is hard and reaching it is a loss")
    func capIsHard() {
        let run = ReasonerHarness.smoke(band: .systemic, laws: 20, roundsPerLaw: 20, seed: 0xCA9)
        for transcript in run.transcripts {
            #expect(transcript.probesUsed <= Band.systemic.cap)
            if transcript.probesUsed == Band.systemic.cap { #expect(!transcript.won) }
        }
    }

    // MARK: the smoke subset, and its budget

    /// §10.10's runtime split: "the fast suite runs the 8 × 20 × 20 smoke subset (3,200 rounds,
    /// ≈ 0.8 s) plus all of Level A".
    @Test("The smoke subset is 3,200 rounds and runs in under a second", .tags(.performance))
    func smokeSubsetBudget() {
        let start = ContinuousClock.now
        let run = ReasonerHarness.smokeMatrix(seed: 0x5_0BEE_5AFE)
        let elapsed = ContinuousClock.now - start
        #expect(run.roundCount == 8 * 20 * 20)
        #expect(elapsed < .milliseconds(1_000), "smoke subset took \(elapsed)")
    }

    @Test("The harness is deterministic in its seed")
    func isDeterministic() {
        let a = ReasonerHarness.smoke(band: .relational, laws: 5, roundsPerLaw: 5, seed: 0xD37)
        let b = ReasonerHarness.smoke(band: .relational, laws: 5, roundsPerLaw: 5, seed: 0xD37)
        #expect(a.transcripts.map(\.probesUsed) == b.transcripts.map(\.probesUsed))
        #expect(a.transcripts.map(\.won) == b.transcripts.map(\.won))
    }

    // MARK: the fast forms of the invariants only Level B can carry

    /// H11's fast form. The full form is T12's, over the 640 k matrix.
    @Test("Failure rate rises monotonically across the bands at fixed ability")
    func bandMonotonicitySmoke() {
        let rates = Band.allCases.map {
            ReasonerHarness.smoke(band: $0, laws: 20, roundsPerLaw: 20, seed: 0x11).failureRate
        }
        #expect(rates == rates.sorted())
        #expect(rates[Band.systemic.rawValue - 1] > rates[Band.composite.rawValue - 1])
    }

    /// H12's fast form. §5.4: "must reproduce this table within ±20 %, or the par column is
    /// regenerated empirically."
    @Test("Median probes are within ±20 % of §5.4's par", arguments: Band.allCases)
    func parFidelitySmoke(_ band: Band) {
        let median = ReasonerHarness.smoke(band: band, laws: 20, roundsPerLaw: 20,
                                           seed: 0x9A5).medianProbes
        let ratio = Double(median) / Double(band.par)
        #expect((0.80...1.20).contains(ratio),
                "band \(band.rawValue): median \(median) vs par \(band.par), ratio \(ratio)")
    }
}

@Suite("Difficulty calibration — the full Level-B matrix",
       .tags(.integration, .nightly),
       .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"),
       .timeLimit(.minutes(15)))
struct DifficultyCalibrationTests {

    /// H10, in full. §14.6 risk 3: if this fails, regenerate §5.1's modifier weights from the
    /// harness. The threshold is never lowered.
    @Test("Spearman ρ between difficulty(of:) and observed failure rate")
    func difficultyPredictsFailure() {
        let matrix = ReasonerHarness.fullMatrix(seed: 0xCA11B)
        #expect(matrix.spearmanOverall >= 0.75,
                "ρ = \(matrix.spearmanOverall); §14.6 risk 3 says regenerate §5.1's weights, not this number")
        for band in Band.allCases {
            #expect(matrix.spearman(within: band) >= 0.45,
                    "band \(band.rawValue): ρ = \(matrix.spearman(within: band))")
        }
    }

    @Test("Band monotonicity over the full matrix, band 8 above band 7")
    func bandMonotonicityFull() {
        let matrix = ReasonerHarness.fullMatrix(seed: 0xCA11B)
        let rates = Band.allCases.map { matrix.failureRate(band: $0) }
        #expect(rates == rates.sorted())
        #expect(rates[7] > rates[6])
    }

    @Test("Par fidelity over the full matrix", arguments: Band.allCases)
    func parFidelityFull(_ band: Band) {
        let matrix = ReasonerHarness.fullMatrix(seed: 0xCA11B)
        let ratio = Double(matrix.medianProbes(band: band)) / Double(band.par)
        #expect((0.80...1.20).contains(ratio))
    }

    /// H20 over every served round in the matrix.
    @Test("Palette sufficiency held for every served round in the matrix")
    func paletteSufficiencyFull() {
        #expect(ReasonerHarness.fullMatrix(seed: 0xCA11B).paletteSufficiencyViolations == 0)
    }
}
```

Every seed above is a fixed literal, for the reason T10 states: a seed that moves makes "does it
reproduce?" unanswerable. T12 hoists them into `HarnessInvariants.seed(_:)`.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ReasonerHarness`

It must fail on missing symbols — `ReasonerHarness`, `Reasoner`, `HumanFamilyPrior`,
`HypothesisSpace` — not on a malformed expectation. `DifficultyCalibrationTests` will report as
skipped without the environment variable; confirm it **runs** with
`HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter DifficultyCalibrationTests`.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** `smokeSubsetBudget` is the constraint; see the cost model below
before optimising anything else.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/HunchTestSupport/ReasonerHarness.swift` |
| create | `HunchCore/Sources/HunchTestSupport/Reasoner.swift` — one player, one round |
| create | `HunchCore/Sources/HunchTestSupport/HypothesisSpace.swift` — the materialised set, the survivor list and the transposed admit columns |
| create | `HunchCore/Sources/HunchTestSupport/HumanFamilyPrior.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/HarnessStatistics.swift` — Spearman ρ, median, share |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `handWrittenLaw(_:)` accessors this suite names |
| create | `HunchCore/Tests/LadderTests/ReasonerHarnessTests.swift` |
| modify | `Nightly.xctestplan` — confirm `HUNCH_CALIBRATION=1` is set there and only there |
| modify | `PROGRESS.md` — the measured ρ overall and within band, the failure-rate ladder, the median-probe table against §5.4 |
| modify | `tests.json` — `harness.level-b-smoke`, `harness.difficulty-calibration-H10`, `harness.band-monotonicity-H11`, `harness.par-fidelity-H12` |

## Implementation notes

### The cost model — read this before writing any of it

§10.10 budgets 640 k rounds at ~9 minutes, i.e. **843 µs per round**, and the smoke subset at 3,200
rounds in ≈0.8 s, i.e. **250 µs per round**. A round is up to `cap` probes and each probe scores `m ≤
32` candidates against the surviving hypothesis set. The naive shape — for each candidate, walk every
hypothesis and ask the table — costs `32 × |H|` table lookups per probe, which at `|H| = 20,000` is
640 k lookups on the *first* probe alone.

That is affordable, and only just, because **the survivor set halves with every probe**. The
geometric sum over a round is about twice the first probe's cost — ~1.3 M bit tests, ~1.3 ms at a
nanosecond each — which is over budget by 50 % for contextual bands and comfortably inside it for the
rest once `|H|` is 2,000–10,000. Two structural decisions bring it inside:

1. **The survivor set is a compacted `[Int32]` of hypothesis indices, not a fixed-length bitset.**
   Iteration cost must fall with `|surviving|`; a bitset scan does not. This is the single decision the
   whole budget rests on.
2. **Stateless bands get a transposed admit table.** For a band's `n` hypotheses, precompute
   `admits[glyphID]` as an `n`-bit bitset — 256 × `n`/8 bytes, which for band 7's 10,314 is 330 KB.
   Scoring a candidate is then `popcount(surviving & admits[g])` over `n/64` words, and the
   per-probe cost is `32 × n/64` word operations instead of `32 × |surviving|` table lookups. Build it
   once per band and reuse it across all 400 laws × 200 rounds.
3. **Contextual bands score against row slices.** A `Bitboard65536` is 1024 words indexed
   `prev*256 + cur`, so the 256-bit row for a fixed `prev` is a **4-word slice at a fixed offset**:
   `t.words[prev*4 ..< prev*4 + 4]`. The reasoner chooses `cur` and `prev` is whatever it probed last,
   so per probe you extract `|surviving|` four-word rows and test 32 bits in each. No 164 MB transpose,
   no per-`prev` precompute.

Memory: bands 5 and 7 materialise 20,000 pair tables at 8 KiB each = **164 MB**. Build **one band's
space at a time** and release it before the next — `fullMatrix` is a loop over bands, not a
Cartesian product held in memory. State the peak in the doc comment; a CI runner has room, a laptop
running the smoke subset never builds it because the smoke subset samples 2,000.

If after all of that the full matrix overruns fifteen minutes, the lever is the **contextual sample
size**, which §5.4 already treats as a parameter with an explicit `log₂(|H|/20000)` correction — halve
it, apply the correction, and record the change in `DECISIONS.md`. Do **not** lower the round count,
which is what H10's ρ is estimated from.

### The hypothesis space

```swift
/// A band's materialised hypothesis set plus the machinery a reasoner needs to filter it fast.
/// Built from `LawIndex` for the six exhaustively enumerated bands and sampled at
/// `contextualSampleSize` for bands 5 and 7 (§5.4), with the `log₂(|H|/sample)` correction
/// applied to the information budget the reasoner reasons about.
public struct HypothesisSpace: Sendable {
    public static let contextualSampleSize = 20_000        // §5.4
    public static let smokeContextualSampleSize = 2_000

    public let band: Band
    public let tables: [LawTable]           // one per hypothesis
    public let weights: [Double]            // the truncated human prior, uniform within a band
    private let admits: [Bitset]?           // stateless bands only; nil for 5 and 7

    public func admits(hypothesis: Int32, glyph: Glyph, after previous: Glyph) -> Bool
    public func admitMass(of candidate: Glyph, after previous: Glyph,
                          among surviving: [Int32], weights: [Double]) -> Double
    public func filtered(_ surviving: inout [Int32], keeping verdict: Bool,
                         glyph: Glyph, after previous: Glyph)
}
```

`filtered` compacts **in place** with a `removeAll(where:)`-shaped loop over the index array; it is the
hot function and it must not allocate.

`Corpora.index` (E05·T07, `HunchTestSupport`'s `static let`) is the source for bands 1, 2, 3, 4, 6 and
8 — `08 §5` rule 3 makes it the one sanctioned piece of shared state in a parallel suite. Bands 5 and
7 sample from the contextual hash runs plus regeneration; make the sampler deterministic in the
harness seed and assert `isDeterministic` covers it.

### The reasoner

```swift
/// One simulated player, one round. §10.10's five numbered steps.
public struct Reasoner {
    public init?(band: Band, ability: Double, seed: UInt64)

    /// §10.10 step 3: `m = clamp(round(4 + 28·σ(θ)), 4, 32)`.
    public static func candidateCount(ability: Double) -> Int
    /// §10.10 step 3: `(1 − σ(θ)) · 0.30`.
    public static func wasonProbability(ability: Double) -> Double
    /// §10.10 step 4: `τ = 0.55 + 0.35·σ(θ)`.
    public static func declareThreshold(ability: Double) -> Double
}
```

**Greedy maximum expected entropy reduction has an exact closed form here, and it is worth writing
down.** The verdict `V` of a candidate glyph is *deterministic* given the hypothesis `H`, so
`H(V | H) = 0` and the expected reduction in the posterior's entropy is exactly the mutual information
`I(V; H) = H(V)`, the binary entropy of the admit-mass split. So:

```
score(candidate) = H_b(p)   where p = Σ{w_i : hypothesis i admits candidate} / Σ{w_i}
```

and maximising it is maximising `H_b(p)`, i.e. **choosing the candidate whose weighted admit fraction
is closest to ½**. That is one accumulation pass per candidate and no entropy computation over the
hypothesis set at all. Put the derivation in the doc comment: without it the obvious implementation
recomputes the full posterior entropy twice per candidate and misses the budget by two orders of
magnitude.

The **Wason substitution** is then the same accumulation with a different objective: maximise `p`
rather than `H_b(p)`. `wasonProbeIsPositive` asserts exactly that relationship, which is the honest
model of *"they generate instances they expect to be admitted"* (§5.3's ceiling argument).

The **candidate set is random**, size `m`, drawn without replacement from the 256 glyphs (§10.10 step
3 says "a random candidate set of size m"). Ability enters here and only here as breadth; a reasoner
with `m = 4` frequently cannot see the informative probe at all, which is what produces the
ability-graded probe counts H12 measures.

**Declaration** (§10.10 step 4) fires on the first of: posterior max mass > `τ`; `probes == par +
Poisson(2)`; `probes == cap` (forced). Record which one fired as a `StoppingRule` on the transcript —
`parTimeoutIsNotTheDominantStoppingRule` is the guard that keeps H12 honest, and without the recorded
enum it cannot be written. Poisson(2) is Knuth's method over `Sampling.unitInterval`; six lines,
deterministic, no `Foundation` random.

The declared hypothesis is the **MAP** one, except with probability `(1 − σ(θ))·0.25` the
second-highest-mass one — §10.10's "premature commitment". Verdict is **extension identity in the
common space with lifting** (§4.5), which E05·T05 already ships; do not re-implement a comparison.

**Strike 1** (§10.10 step 5): ingest the counterexample as a hard filter, then probe up to `0.3·par`
more, then declare again. The counterexample comes from E06·T08's deterministic four-step selection —
call it, do not re-derive it, or the harness measures a counterexample rule the game does not ship.
Per §4.5 and E09·T09 the counterexample is **not a probe**: it does not increment `probesUsed` and
never becomes `prev`. `counterexampleIsAHardConstraint` and `contextIsThreadedCorrectly` are the two
tests that pin those.

### The runs

```swift
public enum ReasonerHarness {
    /// §10.10's fast subset: 8 bands × 20 laws × 20 rounds = 3,200 rounds, ≈0.8 s.
    public static func smokeMatrix(seed: UInt64) -> Matrix
    public static func smoke(band: Band, laws: Int, roundsPerLaw: Int, seed: UInt64) -> Matrix
    /// §10.10's full matrix: 8 × 400 × 200 = 640,000 rounds, ~9 min, behind HUNCH_CALIBRATION=1.
    public static func fullMatrix(seed: UInt64) -> Matrix
    public static func play(law: LawNode, band: Band, ability: Double, seed: UInt64) -> Transcript
}

public struct Matrix: Sendable {
    public let transcripts: [Transcript]        // summary-only in the full matrix
    public let roundCount: Int
    public func failureRate(band: Band) -> Double
    public func medianProbes(band: Band) -> Int
    public func share(of rule: StoppingRule) -> Double
    public var spearmanOverall: Double
    public func spearman(within band: Band) -> Double
    public var paletteSufficiencyViolations: Int
}
```

The full matrix must **not** hold 640 k transcripts: accumulate per-law failure counts and a running
median sketch (a fixed histogram over `0...cap` is exact and costs 48 ints per band). `Transcript`
survives only in the smoke runs.

`θ` is *fixed at 8 values* for H10 (§10.10's measurement column) rather than adapting, because H10
measures `difficulty(of:)` against failure rate and an adapting θ would confound the two. That is a
different loop from Level A's, and it is why this harness does not call `AbilityEstimator` at all.
Say so in the doc comment; a reviewer will otherwise ask why the estimator is missing.

### Spearman ρ

Rank both series, handle ties with average ranks (there **will** be ties — 400 laws per band share
many difficulties), then Pearson on the ranks. Twenty lines in `HarnessStatistics.swift`, tested
against three hand-computed cases including one with ties. `swift-numerics` is banned and this is why
it does not matter.

### H10's failure path is a procedure, not a tolerance

§14.6 risk 3 and §10.10 both say it: if ρ comes in under 0.75, `difficulty(of:)` is wrong and §5.1's
modifier weights are **regenerated from the harness**. Ship the regeneration as a documented nightly
tool, not as a knob on the test:

```swift
/// Solves for the five §5.1 modifier coefficients that maximise ρ, subject to their sum being
/// exactly the locked modifier ceiling (§5.1, §5.7). Emits the new coefficients and the achieved
/// ρ; it does not write them. A human puts them in `Difficulty.swift` and `DECISIONS.md`.
public static func regenerateModifierWeights(seed: UInt64) -> ModifierWeightSolution
```

Constrained so the ceiling is untouched — a law must never escape its band (§5.1) — and emitting
rather than writing, so the change goes through review. The procedure goes in `DECISIONS.md` as a
runbook the day it is first needed.

### Where the smoke subset must not drift

`06 T58`: the full matrix is gated, never deleted, and the smoke subset exists *"so the harness itself
cannot rot"*. Concretely: every public entry point used by `DifficultyCalibrationTests` is also
exercised by a smoke test, so a compile error or a logic break in the gated path is caught on every
commit rather than nightly. Check that when you finish: anything reachable only under
`HUNCH_CALIBRATION=1` is a latent breakage.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ReasonerHarnessTests` is green, all fifteen tests.
- [ ] `HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter DifficultyCalibrationTests` is green, and the same filter without the variable reports the suite as skipped.
- [ ] `smokeSubsetBudget` passes: 3,200 rounds under 1,000 ms.
- [ ] The full matrix completes inside `.timeLimit(.minutes(15))` on the CI runner, and the wall time is recorded in `PROGRESS.md`.
- [ ] `HumanFamilyPrior.weights` sums to 1.0 and matches §10.10's eight published values to 1e-9.
- [ ] `candidateCount(ability:)`, `wasonProbability(ability:)` and `declareThreshold(ability:)` each reproduce their published formulas at the tabulated points.
- [ ] The par-timeout stopping rule fires on under 50 % of rounds in every band.
- [ ] Median probes are within ±20 % of `band.par` for all eight bands, in both the smoke and the full matrix.
- [ ] Failure rates are strictly increasing across bands 1→8 with band 8 above band 7, in both.
- [ ] ρ ≥ 0.75 overall and ≥ 0.45 within every band — or, if not, `DECISIONS.md` records the regeneration run, the new §5.1 weights and the achieved ρ, and the threshold is unchanged.
- [ ] `paletteSufficiencyViolations == 0` over the full matrix.
- [ ] `grep -n 'import Testing' HunchCore/Sources/HunchTestSupport/Reasoner*.swift` returns nothing.
- [ ] Every public entry point reachable from `DifficultyCalibrationTests` is also called from a fast-suite test.
- [ ] `PROGRESS.md` carries ρ overall, ρ per band, the failure-rate ladder and the median-probe table.
- [ ] `tests.json` carries the four Level-B entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s. Then
   `HUNCH_CALIBRATION=1 swift test --package-path HunchCore` green.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests **and re-measure the smoke budget** afterwards; the compacted
   survivor array is the thing a simplification pass is most likely to turn back into a filter chain.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T11: Level B — the reasoner, the mis-specified prior, and the gated 640k matrix"`

## Out of scope

- Level A and everything it carries — **T10**.
- Formally asserting H1–H21 with their `tests.json` rows and their stated measurements — **T12**. The fast forms here are the harness's own tests.
- `difficulty(of:)`, the guardrails, the generator and the counterexample selector — **E06**. All four are called, none is re-implemented.
- The lower-band index and the contextual hash runs — **E05·T07**.
- `Bench.layout(for:)` and G10 — **E06·T03/T04**; H20 reads `PaletteCeiling.isSufficient(for:)` (E09·T04) and nothing else.
- Actually regenerating §5.1's weights, if H10 fails — a separate change with its own review, run from the tool this task ships.
