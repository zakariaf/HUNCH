# T12 — H1–H21 as shipped assertions

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T11 |
| **Delivers** | §14.1 Harness invariants H1–H21 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns the rule that `tests.json` is *"never deleted or weakened to reach green"*, owns the two-axis tagging that puts a fast form in `Presubmission` and a full form in `Nightly`, owns `.timeLimit` as a hang guard, and owns the discipline that every long-running loop reports its reproducing seed. This task is the epic's `tests.json` commit and this skill is its rulebook. |

## Objective

All twenty-one invariants of §10.10 exist as named tests with the section's own measurement and pass
condition, each with a `tests.json` entry naming the command that produced its status. At the end of
this task the epic's gate is a single filter — `swift test --filter HarnessInvariant` — and every row
of §10.10's table is either passing or has a `DECISIONS.md` entry explaining what was regenerated.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.10 | The twenty-one-row table verbatim: every measurement and every pass condition, including H9's rewritten *unforced*-band-change form and the paragraph explaining why the old form would have failed on correct behaviour |
| `GAME_DESIGN.md` | §10.10 | H10's failure procedure: *"if ρ drops below 0.75, `difficulty(of:)` is wrong and the §5.1 modifier weights are regenerated from the harness — the test is never weakened"* |
| `GAME_DESIGN.md` | §10.10 | H11's band-8 clause and what it is an assertion *about*: that a family-based difficulty function beats an entropy-based one |
| `GAME_DESIGN.md` | §10.6, §10.9, §10.4 | H14's isolation, H15's absence, H20's calibration-round coverage |
| `GAME_DESIGN.md` | §14.1 VERIFICATION | `tests.json` as a structured pass/fail list of every invariant |
| `GAME_DESIGN.md` | §14.5 decision 5 | Fast subset every commit; full matrix nightly and as a hard gate before any archive |
| `ios-swift-guide/06-TESTING.md` | T26, T30, T53, T58 | Hang guard, both tag axes, promote every failure into a named regression case, never delete a slow test |

Do not restate a pass condition in prose anywhere but the test's own `#expect`. Cite §10.10.

## TDD — the test comes first

This task **is** the test. There is no implementation behind it beyond the two accessors listed under
Files; if an invariant cannot be written because a statistic is missing, add the statistic to
`HarnessStatistics.swift` and say so in the commit.

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/HarnessInvariantTests.swift`.
Structure: one `@Suite`, twenty-one `@Test` functions named for their invariant, each carrying §10.10's
measurement in its doc comment and §10.10's pass condition in its `#expect`.

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import Ladder
import HunchTestSupport

@Suite("H1–H21 — §10.10's shipped invariants", .tags(.unit, .presubmission))
struct HarnessInvariantTests {

    // ─── H1 ─────────────────────────────────────────────────────────────────────────────────
    /// Convergence. θ_true ∈ {−3,−2,−1,0,1,2,3,4}, 400 rounds, 64 seeds each; |θ̂₄₀₀ − θ_true|.
    /// Pass: ≤ 0.35 all seeds; median ≤ 0.15.
    @Test("H1 — convergence", arguments: HarnessInvariants.h1Abilities)
    func convergence(_ trueAbility: Double) {
        let errors = HarnessInvariants.seeds(64).map { seed -> Double in
            let run = ResponseHarness.run(trueAbility: trueAbility, rounds: 400,
                                          seed: seed, mode: .probe, recordingRounds: false)
            return abs(run.summary.finalEstimate - trueAbility)
        }
        #expect(errors.allSatisfy { $0 <= 0.35 },
                "worst |θ̂ − θ| = \(errors.max()!) at θ_true \(trueAbility)")
        #expect(HarnessStatistics.median(errors) <= 0.15)
    }

    // ─── H2 ─────────────────────────────────────────────────────────────────────────────────
    /// Convergence speed. Rounds until |θ̂ − θ_true| ≤ 0.5 and stays.
    /// Pass: ≤ 25 worst case, ≤ 12 median.
    @Test("H2 — convergence speed", arguments: HarnessInvariants.h1Abilities)
    func convergenceSpeed(_ trueAbility: Double) {
        let rounds = HarnessInvariants.seeds(64).map { seed in
            ResponseHarness.run(trueAbility: trueAbility, rounds: 400, seed: seed,
                                mode: .probe).summary.roundsToWithin(0.5)
        }
        #expect(rounds.max()! <= 25)
        #expect(HarnessStatistics.median(rounds.map(Double.init)) <= 12)
    }

    // ─── H3 ─────────────────────────────────────────────────────────────────────────────────
    /// Target hold. Round success rate, rounds 26–400, over θ_true ∈ {−1, 0, +1, +2, +3} — the
    /// range in which an eight-band ladder can actually serve the target. Pass: 0.80 ± 0.03.
    @Test("H3 — target hold", arguments: HarnessInvariants.h3Abilities)
    func targetHold(_ trueAbility: Double) {
        let rate = ResponseHarness.medianAcrossSeeds(trueAbility: trueAbility, rounds: 400,
                                                     seeds: 64, mode: .probe,
                                                     window: 26...400).successRate
        #expect(isApproximatelyEqual(rate, 0.80, absoluteTolerance: 0.03),
                "θ_true \(trueAbility): realised \(rate)")
    }

    // ─── H4 ─────────────────────────────────────────────────────────────────────────────────
    /// First-declaration rate, same window. Pass: 0.62 ± 0.05.
    @Test("H4 — first-declaration rate", arguments: HarnessInvariants.h3Abilities)
    func firstDeclarationRate(_ trueAbility: Double) {
        let success = ResponseHarness.medianAcrossSeeds(trueAbility: trueAbility, rounds: 400,
                                                        seeds: 64, mode: .probe,
                                                        window: 26...400).successRate
        #expect(isApproximatelyEqual(ResponseHarness.firstDeclarationRate(successRate: success),
                                     0.62, absoluteTolerance: 0.05))
    }

    // ─── H5 ─────────────────────────────────────────────────────────────────────────────────
    /// Counterexample recovery: P(2nd declaration correct | 1st wrong). Pass: 0.47 ± 0.06.
    /// Measured on Level B, where a second declaration actually happens.
    @Test("H5 — counterexample recovery")
    func counterexampleRecovery() {
        let matrix = ReasonerHarness.smokeMatrix(seed: HarnessInvariants.seed(5))
        #expect(isApproximatelyEqual(matrix.secondDeclarationSuccessRate, 0.47,
                                     absoluteTolerance: 0.06),
                "measured \(matrix.secondDeclarationSuccessRate)")
    }

    // ─── H6 ─────────────────────────────────────────────────────────────────────────────────
    /// No loss loop. Max consecutive losses over 10⁶ Level-A rounds.
    /// Pass: ≤ 6, and P(run ≥ 4) < 0.004.
    @Test("H6 — no loss loop", .tags(.performance))
    func noLossLoop() {
        let run = ResponseHarness.run(trueAbility: 0.0, rounds: 1_000_000,
                                      seed: HarnessInvariants.seed(6), mode: .probe,
                                      recordingRounds: false)
        #expect(run.summary.maxConsecutiveLosses <= 6)
        #expect(run.summary.probabilityOfLossRun(atLeast: 4) < 0.004)
    }

    // ─── H7 ─────────────────────────────────────────────────────────────────────────────────
    /// Relief efficacy: P(win | exactly 2 preceding losses). Pass: ≥ 0.86.
    @Test("H7 — relief efficacy", .tags(.performance))
    func reliefEfficacy() {
        let run = ResponseHarness.run(trueAbility: 0.0, rounds: 1_000_000,
                                      seed: HarnessInvariants.seed(7), mode: .probe,
                                      recordingRounds: false)
        #expect(run.summary.winRateAfterExactlyTwoLosses >= 0.86)
    }

    // ─── H8 ─────────────────────────────────────────────────────────────────────────────────
    /// No trap at the floor. θ_true = −5 (below band 1); win rate after the floor rescue.
    /// Pass: ≥ 0.55.
    @Test("H8 — no trap at the floor", .tags(.performance))
    func noTrapAtTheFloor() {
        let run = ResponseHarness.run(trueAbility: -5.0, rounds: 200_000,
                                      seed: HarnessInvariants.seed(8), mode: .probe,
                                      recordingRounds: false)
        #expect(run.summary.winRateAfterFloorRescue >= 0.55)
        #expect(run.summary.floorRescuesFired > 0, "the rescue never armed — the test measured nothing")
    }

    // ─── H9 ─────────────────────────────────────────────────────────────────────────────────
    /// No trap at the ceiling. θ_true = +6; win rate, modal band share, and *unforced* band
    /// changes. Pass: ≥ 0.88; band 8 modal with share ≥ 0.65; ZERO band changes on rounds where
    /// reach, relief and the ceiling rotation are all inert.
    ///
    /// §10.10 is explicit that the old "band changes < 5 %" form measured relief and the rotation
    /// doing their jobs and would have failed on correct behaviour. Assert the unforced form.
    @Test("H9 — no trap at the ceiling", .tags(.performance))
    func noTrapAtTheCeiling() {
        let run = ResponseHarness.run(trueAbility: 6.0, rounds: 200_000,
                                      seed: HarnessInvariants.seed(9), mode: .probe,
                                      recordingRounds: false)
        #expect(run.summary.successRate >= 0.88)
        #expect(run.summary.modalBand == .systemic)
        #expect(run.summary.modalBandShare >= 0.65)
        #expect(run.summary.unforcedBandChanges == 0,
                "\(run.summary.unforcedBandChanges) band changes with reach, relief and the rotation all inert")
    }

    // ─── H10 ────────────────────────────────────────────────────────────────────────────────
    /// Difficulty calibration. Spearman ρ between difficulty(of:) and Level-B per-law failure
    /// rate, θ fixed at 8 values. Pass: ρ ≥ 0.75 overall; ≥ 0.45 within every band.
    /// The full form lives in `DifficultyCalibrationTests` behind HUNCH_CALIBRATION=1 (T11);
    /// this is the smoke form, and it uses the SAME threshold.
    @Test("H10 — difficulty calibration (smoke)")
    func difficultyCalibration() {
        let matrix = ReasonerHarness.smokeMatrix(seed: HarnessInvariants.seed(10))
        #expect(matrix.spearmanOverall >= 0.75,
                "ρ = \(matrix.spearmanOverall). §10.10: regenerate §5.1's weights, never this number")
        for band in Band.allCases {
            #expect(matrix.spearman(within: band) >= 0.45, "band \(band.rawValue)")
        }
    }

    // ─── H11 ────────────────────────────────────────────────────────────────────────────────
    /// Band monotonicity: mean failure rate across bands 1→8 at fixed θ.
    /// Pass: strictly increasing, no inversion; band 8 > band 7.
    @Test("H11 — band monotonicity")
    func bandMonotonicity() {
        let matrix = ReasonerHarness.smokeMatrix(seed: HarnessInvariants.seed(11))
        let rates = Band.allCases.map { matrix.failureRate(band: $0) }
        #expect(zip(rates, rates.dropFirst()).allSatisfy { $0 < $1 }, "\(rates)")
        // The clause that says a family-based difficulty function beats an entropy-based one:
        // band 8 has the SMALLEST |H| after band 1 and must still be the hardest.
        #expect(rates[7] > rates[6])
        #expect(Band.systemic.population < Band.pair.population)
    }

    // ─── H12 ────────────────────────────────────────────────────────────────────────────────
    /// Par fidelity: Level-B median probes vs §5.4 par. Pass: within ±20 % per band.
    @Test("H12 — par fidelity", arguments: Band.allCases)
    func parFidelity(_ band: Band) {
        let matrix = ReasonerHarness.smokeMatrix(seed: HarnessInvariants.seed(12))
        let ratio = Double(matrix.medianProbes(band: band)) / Double(band.par)
        #expect((0.80...1.20).contains(ratio),
                "band \(band.rawValue): median \(matrix.medianProbes(band: band)) vs par \(band.par)")
    }

    // ─── H13 ────────────────────────────────────────────────────────────────────────────────
    /// Purity / determinism: (seed, θ_true) → θ trajectory, across runs and processes.
    /// Pass: byte-identical.
    @Test("H13 — purity and determinism, in process")
    func determinismInProcess() {
        let a = ResponseHarness.run(trueAbility: 1.0, rounds: 2_000,
                                    seed: HarnessInvariants.seed(13), mode: .probe)
        let b = ResponseHarness.run(trueAbility: 1.0, rounds: 2_000,
                                    seed: HarnessInvariants.seed(13), mode: .probe)
        #expect(a.abilityTrajectory == b.abilityTrajectory)
    }

    @Test("H13 — purity and determinism, across processes")
    func determinismAcrossProcesses() throws {
        // The committed golden, written by a separate `swift run` on a different day —
        // the same mechanism E06·T10 uses for the generator.
        let golden = try HarnessInvariants.loadTrajectoryGolden()
        let run = ResponseHarness.run(trueAbility: golden.trueAbility, rounds: golden.rounds,
                                      seed: golden.seed, mode: .probe)
        #expect(run.abilityTrajectory == golden.trajectory)
    }

    // ─── H14 ────────────────────────────────────────────────────────────────────────────────
    /// Anomaly isolation: 400 Anomaly rounds injected mid-run.
    /// Pass: θ̂ bit-identical to the run without them.
    @Test("H14 — Anomaly isolation")
    func anomalyIsolation() {
        let clean = ResponseHarness.run(trueAbility: 0.5, rounds: 2_000,
                                        seed: HarnessInvariants.seed(14), mode: .probe)
        let injected = ResponseHarness.run(trueAbility: 0.5, rounds: 2_000,
                                           seed: HarnessInvariants.seed(14), mode: .probe,
                                           injectingAnomalyRounds: 400)
        #expect(injected.abilityTrajectory == clean.abilityTrajectory)
        #expect(injected.summary.finalServingState.reach == clean.summary.finalServingState.reach)
        #expect(injected.summary.finalServingState.relief == clean.summary.finalServingState.relief)
        #expect(injected.summary.finalServingState.winStreak == clean.summary.finalServingState.winStreak)
        #expect(injected.summary.finalServingState.consecutiveLosses
                == clean.summary.finalServingState.consecutiveLosses)
    }

    // ─── H15 ────────────────────────────────────────────────────────────────────────────────
    /// Absence: 90-day gap injected at round 200; rounds to re-converge. Pass: ≤ 6.
    @Test("H15 — absence")
    func absence() {
        let run = ResponseHarness.run(trueAbility: 1.2, rounds: 400,
                                      seed: HarnessInvariants.seed(15), mode: .probe,
                                      injectingGapDays: 90, atRound: 200)
        #expect(run.summary.roundsToReconvergeAfterGap <= 6)
    }

    // ─── H16 ────────────────────────────────────────────────────────────────────────────────
    /// Boundedness: θ̂ range; NaN/Inf check. Pass: [−6, +6], never non-finite.
    @Test("H16 — boundedness", .tags(.performance),
          arguments: [-6.5, -3.0, 0.0, 3.0, 6.5])
    func boundedness(_ trueAbility: Double) {
        let run = ResponseHarness.run(trueAbility: trueAbility, rounds: 200_000,
                                      seed: HarnessInvariants.seed(16), mode: .probe,
                                      recordingRounds: false)
        #expect(run.summary.sawNonFinite == false)
        #expect(run.summary.estimateRange.lowerBound >= -6.0)
        #expect(run.summary.estimateRange.upperBound <= 6.0)
    }

    // ─── H17 ────────────────────────────────────────────────────────────────────────────────
    /// Mode independence: strong PROBE / weak SIEVE player, 120 SIEVE rounds.
    /// Pass: |Δ̂_sieve − Δ_true| ≤ 0.45.
    @Test("H17 — mode independence")
    func modeIndependence() {
        let trueOffset = -1.5
        let run = ResponseHarness.run(trueAbility: 2.0, rounds: 120,
                                      seed: HarnessInvariants.seed(17), mode: .sieve,
                                      trueOffset: trueOffset, startingFromConvergedProbe: true)
        #expect(abs(run.summary.finalOffset - trueOffset) <= 0.45,
                "Δ̂ = \(run.summary.finalOffset), Δ_true = \(trueOffset)")
        // The other half of §10.5's claim: PROBE's estimate is not contaminated by SIEVE evidence.
        #expect(isApproximatelyEqual(run.summary.finalEstimate, 2.0, absoluteTolerance: 0.05))
    }

    // ─── H18 ────────────────────────────────────────────────────────────────────────────────
    /// Pressure is centred. E[reach − relief] over 10⁶ Level-A rounds at θ_true ∈ {0, +2}, and
    /// the realised success rate at π₀ = 0.44.
    /// Pass: E[reach − relief] = 0.375 ± 0.02; success 0.80 ± 0.01.
    /// **Fails the build if π₀ is stale.**
    @Test("H18 — pressure is centred", .tags(.performance), arguments: [0.0, 2.0])
    func pressureIsCentred(_ trueAbility: Double) {
        let run = ResponseHarness.run(trueAbility: trueAbility, rounds: 1_000_000,
                                      seed: HarnessInvariants.seed(18), mode: .probe,
                                      recordingRounds: false)
        #expect(isApproximatelyEqual(run.summary.meanReachMinusRelief,
                                     Pressure.expectedReachMinusRelief, absoluteTolerance: 0.02),
                "measured E[reach − relief] = \(run.summary.meanReachMinusRelief); "
                + "Pressure.expectedReachMinusRelief is \(Pressure.expectedReachMinusRelief). "
                + "If the jitter width, the relief ladder or the reach schedule changed, "
                + "re-solve π₀ with ResponseHarness.solveCentringConstant — do not widen this.")
        #expect(isApproximatelyEqual(run.summary.successRate, 0.80, absoluteTolerance: 0.01))
        #expect(isApproximatelyEqual(Pressure.centringConstant, 0.44, absoluteTolerance: 1e-12))
    }

    // ─── H19 ────────────────────────────────────────────────────────────────────────────────
    /// Generator fallback rate: share of rounds falling back to the family anchor law (§5.3),
    /// per band, across the H1 convergence run. Pass: < 2 % per band.
    /// This is what catches a targetδ derived against the wrong band (§10.3 step 11) — the
    /// failure is silent in every other metric.
    @Test("H19 — generator fallback rate")
    func generatorFallbackRate() {
        let rates = HarnessInvariants.fallbackRatesPerBand(
            abilities: HarnessInvariants.h1Abilities, roundsPerAbility: 2_000,
            seed: HarnessInvariants.seed(19))
        for (band, rate) in rates {
            #expect(rate < 0.02, "band \(band.rawValue): fallback rate \(rate)")
        }
        #expect(rates.count == Band.allCases.count, "a band was never served — the test measured nothing")
    }

    // ─── H20 ────────────────────────────────────────────────────────────────────────────────
    /// Palette sufficiency: for every served round in the Level-B matrix AND every calibration
    /// round, paletteTileClasses ⊇ tileClasses(Family(servedBand)). Pass: 100 %, asserted at
    /// serve time, not at generation time.
    @Test("H20 — palette sufficiency")
    func paletteSufficiency() {
        #expect(ReasonerHarness.smokeMatrix(seed: HarnessInvariants.seed(20))
                    .paletteSufficiencyViolations == 0)
        #expect(HarnessInvariants.calibrationPaletteViolations() == 0)
    }

    // ─── H21 ────────────────────────────────────────────────────────────────────────────────
    /// Family rotation: over 10⁶ stationary rounds at θ_true ∈ {0, +0.35, +2}, modal family share
    /// and P(same family ≥ 5 rounds running). Pass: modal share ≤ 0.62; P(run ≥ 5) ≤ 0.10.
    /// At θ_true = +6 the same statistics are asserted WITH the ceiling rotation active.
    @Test("H21 — family rotation", .tags(.performance), arguments: [0.0, 0.35, 2.0, 6.0])
    func familyRotation(_ trueAbility: Double) {
        let run = ResponseHarness.run(trueAbility: trueAbility, rounds: 1_000_000,
                                      seed: HarnessInvariants.seed(21), mode: .probe,
                                      recordingRounds: false)
        #expect(run.summary.modalBandShare <= 0.62, "θ_true \(trueAbility)")
        #expect(run.summary.probabilityOfBandRun(atLeast: 5) <= 0.10)
        if trueAbility == 6.0 {
            #expect(run.summary.ceilingRotationsFired > 0,
                    "the rotation never fired at the ceiling — H21's +6 row measured nothing")
        }
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter HarnessInvariant`

Expect two kinds of failure and treat them differently:

- **Missing symbols** (`HarnessInvariants`, `Summary.winRateAfterFloorRescue`,
  `probabilityOfBandRun(atLeast:)`, `injectingAnomalyRounds:`) — add them. That is the implementation.
- **A red assertion.** Read the §10.10 row, then read the implementation it measures. The pass
  condition does not move. H10 is the one row with a documented alternative — regenerate §5.1's
  weights — and even that is a change to `Difficulty.swift`, not to this file.

**Step 3 — implement** the two accessors and every missing `Summary` field. Files below.

**Step 4 — green, then refactor.** Then run the whole suite and re-check the ten-second budget: this
task adds roughly 6 × 10⁶ Level-A rounds and one smoke matrix.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/LadderTests/HarnessInvariantTests.swift` |
| create | `HunchCore/Sources/HunchTestSupport/HarnessInvariants.swift` — the seed table, the ability lists, the two aggregate helpers, the golden loader |
| create | `HunchCore/Tests/LadderTests/Fixtures/ability-trajectory-v1.json` — H13's cross-process golden |
| modify | `HunchCore/Sources/HunchTestSupport/ResponseHarness.swift` — `injectingAnomalyRounds:`, `injectingGapDays:atRound:`, `startingFromConvergedProbe:`, `window:` |
| modify | `HunchCore/Sources/HunchTestSupport/HarnessStatistics.swift` — median, run-length distributions, the win-rate-after-two-losses accumulator |
| modify | `Presubmission.xctestplan` / `Nightly.xctestplan` — confirm the split; nothing here is `.prerelease` |
| modify | `tests.json` — **twenty-one** rows, `harness.H1` … `harness.H21` |
| modify | `PROGRESS.md` — the measured value beside every pass condition |
| modify | `DECISIONS.md` — only if H10 was regenerated |

## Implementation notes

### `tests.json` is the deliverable, not a side effect

Twenty-one rows, each carrying the invariant's id, §10.10's measurement, §10.10's pass condition, the
**exact command** that produced its status, and the measured value. A row whose status is `pass` with
no command is a row nobody ran.

The rule from `hunch-swift-testing` and from §14.1's VERIFICATION column applies without exception:
**never delete or weaken an entry to reach green.** Concretely, the four moves that are forbidden and
that a reviewer should grep for in the diff:

1. Widening an `absoluteTolerance` past §10.10's stated one.
2. Reducing a round count so a statistic gets noisier and the assertion gets easier.
3. Moving a fast-form test to `.nightly` because it is red.
4. Wrapping an assertion in `withKnownIssue`.

If an invariant genuinely cannot pass, the change is to the **implementation** it measures, and the
`DECISIONS.md` entry names which.

### `HarnessInvariants` — the seed table

Every invariant gets one fixed seed, in one place:

```swift
/// The seeds H1–H21 run at. Fixed, published and never regenerated: when a row goes red, the
/// first question is "does it reproduce", and a seed that moves makes that question unanswerable.
public enum HarnessInvariants {
    public static func seed(_ invariant: Int) -> UInt64
    public static func seeds(_ count: Int) -> [UInt64]        // derived from seed(1) by SplitMix64
    /// §10.10 H1's eight abilities.
    public static let h1Abilities: [Double] = [-3, -2, -1, 0, 1, 2, 3, 4]
    /// §10.10 H3's five — "the range in which an eight-band ladder can actually serve the target".
    public static let h3Abilities: [Double] = [-1, 0, 1, 2, 3]
}
```

`h3Abilities` being a **subset** of `h1Abilities` is §10.10's own exclusion and it is *"by
construction, not by convenience"* — below θ ≈ −2.2 the δ clamp cannot serve an easy enough law (H8
owns it) and above +4 the clamp at 3.99 cannot serve a hard enough one (H9 owns it). Put that sentence
in the doc comment, because the first reviewer to notice the shorter list will ask whether it was
trimmed to pass.

### Three tests that must assert they measured something

H8, H19 and H21's +6 row can all pass vacuously — the floor rescue never arming, a band never being
served, the ceiling rotation never firing. Each therefore carries a second `#expect` that the
mechanism fired at least once. That pattern is worth generalising in review: any invariant whose pass
condition is "≤ x" over a filtered subpopulation needs a non-emptiness assertion beside it.

### H13's cross-process golden

Same mechanism as E06·T10's `determinism-seeds-v1.json`: a committed fixture produced by a separate
`swift run` on a different day, so the comparison is against bytes written by a different process.
`ability-trajectory-v1.json` carries `(seed, trueAbility, rounds)` and the resulting `[Double]`
trajectory, encoded with `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])` and the
`Double`s written at full precision. Declare it `resources: [.copy("Fixtures")]` and look it up with
`subdirectory: "Fixtures"` — `06 T54`'s trap, and the reason fixture suites die.

Regenerating the golden is a **deliberate act** with a `DECISIONS.md` entry: it means the estimator,
the policy or the RNG changed, and the whole point of the fixture is that such a change cannot pass
unnoticed.

### H14's injection

`injectingAnomalyRounds:` inserts `n` rounds that are served normally (§10.6: the Anomaly is a real
round of a band drawn 4–7) and settled with `LadderOutcome.anomaly`, i.e. calling neither the
estimator nor `Pressure.applying`. The assertion is **bit-identical**, not approximately equal, on the
whole trajectory — which only holds if the Anomaly rounds also do not consume RNG draws that the
ordinary rounds would have used. So the harness draws the Anomaly's seed from a **separate SplitMix64
stream**. That is a real implementation constraint and it is the thing that makes H14 pass or fail;
write it into the doc comment.

### H17's setup

`startingFromConvergedProbe: true` seeds the run with `Ability` already at the true PROBE baseline and
`scoredRounds[.probe]` high, because H17 measures a *strong PROBE, weak SIEVE* player — a run that
also has to converge PROBE first would measure two things. 120 SIEVE rounds at `K_Δ = 0.6·K` with
0.985 shrinkage is the exact regime T02's ruling predicted, and the 0.45 tolerance is what the
shrinkage bias costs. The second assertion — PROBE's estimate unchanged to 0.05 — is the half that
makes it a test of the *decomposition* rather than of a single number.

### The budget

Rough cost: H6, H7, H9, H16 (×5), H18 (×2) and H21 (×4) are 10⁵–10⁶-round Level-A runs. At T10's
measured 400 ns/round that is ~14 × 10⁶ rounds ≈ 5.6 s — **which does not fit in the ten-second budget
alongside everything else.**

The resolution is §14.5 decision 5's shape, applied honestly:

- **In `Presubmission`**, H6, H9, H16, H18 and H21 run at **10⁵** rounds with their tolerances widened
  by the √10 factor the reduced sample warrants, and each carries a doc comment naming the full form.
- **In `Nightly`**, the same tests run at §10.10's stated 10⁶ with §10.10's stated tolerances, selected
  by the `.performance` tag the fast plan excludes.

That is a **sample-size** split, not a tolerance weakening: the nightly form asserts §10.10 verbatim
and is a hard gate before any archive. Record the split in `DECISIONS.md` with the arithmetic, and put
the fast form's widened tolerance in a named constant so nobody has to reverse-engineer where √10 came
from. If the fast suite still overruns, move H21's four abilities to two in presubmission and keep all
four nightly — never drop a row.

Measure before you assume: if T10's harness comes in faster than 400 ns/round, keep more of the full
forms in presubmission. The gate is the ten-second budget, not a rule about which tests are fast.

### If H10 fails

The procedure, in order, and it goes in `DECISIONS.md` the day it is used:

1. Run `HUNCH_CALIBRATION=1 swift test --filter DifficultyCalibrationTests` and record ρ overall and
   per band.
2. Run T11's `regenerateModifierWeights(seed:)` and record the proposed five coefficients and the ρ
   they achieve.
3. Check the constraint: the five maxima must still sum to exactly §5.1's modifier ceiling, so no law
   escapes its band.
4. Apply them to `HunchCore/Sources/LawGeneration/Difficulty.swift` (E06·T01), re-run E06's
   `DifficultyTests` — §5.2's eight exemplar δs will move, and **§5.2's published column is a rounding
   of §5.1's formula**, so the exemplar test's expected values move with them and that is correct.
5. Re-run E06's 10,000-law suite and E05's per-band `|H|` counts: G8's band-fidelity clause reads
   `difficulty(of:)`, so the populations can shift. If they do, §5.2's `|H|` table, §5.4's par column
   and the lower-band index all move, and that is a much larger change that needs its own epic-level
   decision.
6. Re-run H10, H11 and H12.

Step 5 is why H10 is the invariant that must be watched from phase 4 onward rather than discovered at
phase 8 — §14.6 risk 3 names its early signal as *"within-band ρ < 0.45 at phase 4"*, which is this
task.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter HarnessInvariant` is green: twenty-one invariants, twenty-three test functions (H13 has two, H12/H16/H18/H21 are parameterised), zero skips, zero `withKnownIssue`.
- [ ] `HUNCH_CALIBRATION=1 swift test --package-path HunchCore` is green, including T11's full matrix inside the fifteen-minute guard.
- [ ] Every one of the twenty-one tests names its §10.10 measurement in a doc comment and its §10.10 pass condition in an `#expect`, with the measured value in the failure message.
- [ ] H3 measures 0.80 ± 0.03 at all five of §10.10's abilities.
- [ ] H9 measures **zero** unforced band changes at θ_true = +6, with modal band 8 at share ≥ 0.65.
- [ ] H10 measures ρ ≥ 0.75 overall and ≥ 0.45 per band — or `DECISIONS.md` records the regeneration and the test is unchanged.
- [ ] H18's failure message names `ResponseHarness.solveCentringConstant` and says not to widen the tolerance; the message was read by deliberately setting the jitter width to ±0.50 and watching it fail.
- [ ] H19 measures under 2 % per band and asserts that all eight bands were served.
- [ ] H8, H19 and H21's +6 row each assert that their mechanism fired at least once.
- [ ] H13's golden was produced by a separate process on a different day and is looked up with `subdirectory: "Fixtures"`.
- [ ] H14 asserts a **bit-identical** trajectory, and the Anomaly's seed comes from a separate RNG stream.
- [ ] `tests.json` carries `harness.H1` … `harness.H21`, each with the measurement, the pass condition, the command and the measured value.
- [ ] `PROGRESS.md` carries the measured value beside every pass condition and the Presubmission/Nightly sample-size split with its arithmetic.
- [ ] `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` passes.
- [ ] `grep -n 'withKnownIssue\|\.disabled(' HunchCore/Tests/LadderTests/HarnessInvariantTests.swift` returns nothing.

## Close the task

1. `swift test` green, and the fast suite still under 10 s. Then the nightly plan with
   `HUNCH_CALIBRATION=1`.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run everything after it. `/simplify` must not touch a tolerance, a round
   count or a tag on this file; if it proposes one, decline and record why.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T12: H1–H21 as shipped assertions with their tests.json rows"`

## Out of scope

- The harnesses themselves — **T10** and **T11**. This task measures with them.
- Every mechanism under measurement — **T01**–**T09**. If a row is red, the fix is in one of those files.
- The generator invariants (the 10,000-law suite, determinism, G1–G10) — **E06·T09/T10**, which have their own `tests.json` rows.
- The accessibility gates §13.12 lists — **E19·T11**.
- Actually regenerating §5.1's weights — a separate change with its own review, run from T11's tool by the procedure above.
- The nightly workflow's schedule and the pre-archive gate — **E01·T07** and **E20·T12**.
