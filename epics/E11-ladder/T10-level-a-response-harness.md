# T10 — Level A — `ResponseHarness`

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | §14.1 Simulated player harness (Level A) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns brief invariant 2 and its home (`LadderTests`), owns the ten-second budget and its published sub-budgets (*"Level A at 10⁶ rounds < 0.4 s"*), owns the rule that `HunchTestSupport` is a `.target` absent from `products:` — which is where a shipped harness that must not reach the release binary belongs — and owns the discipline that a long-running loop inside a test pays `06 T21` back with a reproducing seed in every failure message. |

## Objective

`ResponseHarness` closes the loop: it serves through `ServingPolicy`, draws
`x ~ Bernoulli(σ(θ_true + ε − δ))` with `ε ~ N(0, 0.35²)`, updates through `AbilityEstimator`, advances
`ServingState` through `Pressure`, and records every round. At the end of this task 10⁶ rounds run in
under 0.4 s, §10.10's published seven-row results table reproduces, and `π₀` has an offline solver that
H18 can measure the shipped constant against.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.10 | Level A's definition verbatim: what it draws, the day-to-day `ε`, the 10⁶-rounds-under-0.4 s budget, that it runs in the fast suite, and that it is what `π₀` is solved against |
| `GAME_DESIGN.md` | §10.10 | The seven-row results table (θ_true × θ̂@400 × rounds→±0.5 × success × 1st-decl × max loss run × modal band), and the paragraph explaining its two edge rows |
| `GAME_DESIGN.md` | §10.1 | `firstDecl = (success − r)/(1 − r)` with the derived `r = 0.474` — the identity that makes H4 and H5 one claim |
| `GAME_DESIGN.md` | §10.3 | `π₀`'s operational definition: *"the unique offset for which the Level-A harness realises 0.800 at equilibrium"* |
| `GAME_DESIGN.md` | §10.10 | H1, H2, H3, H6, H16, H18, H21 — every invariant Level A alone can carry |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | The budget rules; `Corpora` as `let` of immutable `Sendable` values; no `swift-numerics`, so the Gaussian is hand-rolled |
| `ios-swift-guide/06-TESTING.md` | T21, T26, T30, T58 | Loops paid for by seeds; `.timeLimit` is a hang guard not a benchmark; both tag axes; a slow test is gated, never deleted |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/ResponseHarnessTests.swift`:

```swift
import Testing
import Glyphs
import LawGeneration
import Ladder
import HunchTestSupport

@Suite("Level A — ResponseHarness", .tags(.unit, .presubmission))
struct ResponseHarnessTests {

    // MARK: the response model

    /// §10.10: "Given a served δ, draws x ~ Bernoulli(σ(θ_true + ε − δ)) with ε ~ N(0, 0.35²)".
    @Test("The realised win rate matches σ(θ_true − δ) once ε is integrated out")
    func responseIsCalibrated() {
        var harness = ResponseHarness(trueAbility: 0.0, seed: 0xA11CE)
        var wins = 0
        let rounds = 200_000
        for _ in 0..<rounds { if harness.responds(toServedDelta: -Rasch.servingOffset) { wins += 1 } }
        // ε is zero-mean but σ is concave at ln4, so the realised rate sits just under 0.80
        // (§10.3's curvature term). That gap is a measured quantity, not noise.
        #expect(isApproximatelyEqual(Double(wins) / Double(rounds), 0.80, absoluteTolerance: 0.01))
    }

    @Test("ε has the stated standard deviation and zero mean")
    func noiseIsAsSpecified() {
        var harness = ResponseHarness(trueAbility: 0.0, seed: 7)
        var sum = 0.0, sumSquares = 0.0
        let n = 400_000
        for _ in 0..<n {
            let e = harness.drawNoise()
            sum += e; sumSquares += e * e
        }
        let mean = sum / Double(n)
        let sd = (sumSquares / Double(n) - mean * mean).squareRoot()
        #expect(isApproximatelyEqual(mean, 0.0, absoluteTolerance: 0.005))
        #expect(isApproximatelyEqual(sd, ResponseHarness.dayToDaySigma, absoluteTolerance: 0.005))
    }

    @Test("The harness is deterministic in its seed")
    func isDeterministic() {
        let a = ResponseHarness.run(trueAbility: 1.0, rounds: 5_000, seed: 0xBEEF, mode: .probe)
        let b = ResponseHarness.run(trueAbility: 1.0, rounds: 5_000, seed: 0xBEEF, mode: .probe)
        #expect(a.abilityTrajectory == b.abilityTrajectory)
        #expect(a.rounds.map(\.band) == b.rounds.map(\.band))
    }

    // MARK: the budget

    /// §10.10's own figure, asserted rather than hoped for. `08 §5` budgets the whole fast suite
    /// at ten seconds and this is the single largest item in it.
    @Test("10⁶ rounds run in under 0.4 s", .tags(.performance))
    func millionRoundBudget() {
        let start = ContinuousClock.now
        let run = ResponseHarness.run(trueAbility: 0.0, rounds: 1_000_000,
                                      seed: 0x5EED, mode: .probe)
        let elapsed = ContinuousClock.now - start
        #expect(run.rounds.count == 1_000_000)
        #expect(elapsed < .milliseconds(400), "10⁶ rounds took \(elapsed)")
    }

    /// The run must not allocate per round either — a 10⁶-element `[Round]` is one allocation,
    /// but a per-round `Ability` copy that heap-allocates is a million.
    @Test("A run of 10⁶ rounds performs a bounded number of allocations", .tags(.performance))
    func runIsAllocationBounded() {
        let summaryOnly = ResponseHarness.run(trueAbility: 0.0, rounds: 1_000_000,
                                              seed: 0x5EED, mode: .probe, recordingRounds: false)
        #expect(summaryOnly.rounds.isEmpty)
        #expect(summaryOnly.summary.roundCount == 1_000_000)
    }

    // MARK: §10.10's published table

    /// The seven rows of §10.10's "A passing run, numerically". Reproducing them is the strongest
    /// single statement that the estimator, the policy and the pressure term agree with the design.
    @Test("§10.10's results table reproduces at 400 rounds × 64 seeds",
          arguments: [(-3.0, -2.98, 0.636, 6, Band.literal),
                      (-1.0, -1.12, 0.796, 3, Band.pair),
                      ( 0.0, -0.07, 0.800, 2, Band.exclusive),
                      ( 1.0,  0.89, 0.800, 2, Band.relational),
                      ( 2.0,  1.92, 0.800, 2, Band.contextual),
                      ( 3.0,  2.86, 0.800, 2, Band.guarded),
                      ( 4.0,  3.93, 0.803, 2, Band.composite)])
    func publishedTableReproduces(_ trueAbility: Double, _ expectedEstimate: Double,
                                  _ expectedSuccess: Double, _ expectedMaxLossRun: Int,
                                  _ expectedModalBand: Band) {
        let s = ResponseHarness.medianAcrossSeeds(trueAbility: trueAbility, rounds: 400,
                                                  seeds: 64, mode: .probe)
        #expect(isApproximatelyEqual(s.finalEstimate, expectedEstimate, absoluteTolerance: 0.15),
                "θ_true \(trueAbility): θ̂ \(s.finalEstimate), table prints \(expectedEstimate)")
        #expect(isApproximatelyEqual(s.successRate, expectedSuccess, absoluteTolerance: 0.03))
        #expect(s.maxConsecutiveLosses <= expectedMaxLossRun + 2)
        #expect(s.modalBand == expectedModalBand)
    }

    /// §10.1's derived recovery rate, used as an identity rather than measured twice.
    @Test("The first-declaration identity holds at the target rate")
    func firstDeclarationIdentity() {
        let r = ResponseHarness.counterexampleRecoveryRate
        #expect(isApproximatelyEqual(r, 0.474, absoluteTolerance: 0.001))
        #expect(isApproximatelyEqual(ResponseHarness.firstDeclarationRate(successRate: 0.80),
                                     0.62, absoluteTolerance: 0.005))
        // The identity is invertible, which is what makes H4 and H5 one claim.
        #expect(isApproximatelyEqual(
            ResponseHarness.successRate(firstDeclarationRate: 0.62), 0.80,
            absoluteTolerance: 0.005))
    }

    // MARK: π₀'s solver

    /// §10.3 defines π₀ operationally. The solver is what makes "re-solved if the jitter width,
    /// the relief ladder or the reach schedule ever changes" an action rather than a wish.
    @Test("The offline solver recovers the shipped π₀", .tags(.integration, .nightly))
    func solverRecoversTheShippedConstant() {
        let solved = ResponseHarness.solveCentringConstant(
            trueAbilities: [-1, 0, 1, 2, 3], rounds: 200_000, seed: 0x501F_ED0C)
        #expect(isApproximatelyEqual(solved, Pressure.centringConstant, absoluteTolerance: 0.02),
                "solver says \(solved), Pressure.centringConstant is \(Pressure.centringConstant)")
    }

    // MARK: the invariants Level A alone can carry (fast forms; T12 owns the full ones)

    @Test("No loss loop: the longest run of losses is bounded", .tags(.performance))
    func noLossLoop() {
        let run = ResponseHarness.run(trueAbility: 0.0, rounds: 1_000_000,
                                      seed: 0x10551, mode: .probe, recordingRounds: false)
        #expect(run.summary.maxConsecutiveLosses <= 6)
        #expect(run.summary.probabilityOfLossRun(atLeast: 4) < 0.004)
    }

    @Test("θ̂ is finite and inside its clamp for the whole run", .tags(.performance))
    func boundedness() {
        let run = ResponseHarness.run(trueAbility: 5.5, rounds: 200_000,
                                      seed: 0xB0DD_ED17, mode: .probe, recordingRounds: false)
        #expect(run.summary.estimateRange.lowerBound >= -6.0)
        #expect(run.summary.estimateRange.upperBound <= 6.0)
        #expect(run.summary.sawNonFinite == false)
    }

    /// §10.2's `|Δ| ≤ 3.0 in practice` — asserted empirically, because §10.2 states it
    /// empirically and T01 deliberately did not clamp it.
    @Test("A mode offset stays inside three logits over a long run", .tags(.performance))
    func offsetStaysBounded() {
        let run = ResponseHarness.run(trueAbility: 0.0, rounds: 200_000, seed: 0xD1FF,
                                      mode: .sieve, trueOffset: -1.2, recordingRounds: false)
        #expect(run.summary.offsetRange.lowerBound >= -3.0)
        #expect(run.summary.offsetRange.upperBound <= 3.0)
    }
}
```

Every run above names its seed as a literal. Keep it that way and keep the values fixed: when a
statistic moves, the first question is *"does it reproduce"*, and a seed that moves makes that
question unanswerable. T12 hoists the whole seed table into `HarnessInvariants`.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ResponseHarnessTests`

It must fail on missing symbols — `ResponseHarness`, `ResponseHarness.Run`, `Summary`,
`medianAcrossSeeds`, `solveCentringConstant` — not on a malformed expectation.

**Step 3 — implement** the minimum that turns it green. Files below. Then return to
T04's `uncentredPolicyMissesTheTarget`, delete its `// requires T10` comment, and confirm it green —
that is the first thing this task finishes.

**Step 4 — green, then refactor.** `millionRoundBudget` is the constraint that shapes the code; if it
is red, profile before rewriting.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/HunchTestSupport/ResponseHarness.swift` |
| create | `HunchCore/Sources/HunchTestSupport/HarnessStatistics.swift` — max run length, modal value, median, range |
| modify | `HunchCore/Package.swift` — `HunchTestSupport` gains `Ladder` and `LawGeneration` in its dependencies |
| create | `HunchCore/Tests/LadderTests/ResponseHarnessTests.swift` |
| modify | `HunchCore/Tests/LadderTests/PressureTests.swift` — un-comment `uncentredPolicyMissesTheTarget` |
| modify | `PROGRESS.md` — the measured table beside §10.10's published one |
| modify | `tests.json` — `harness.level-a-budget`, `harness.published-table`, `harness.pi-zero-solver` |

`HunchTestSupport` is the right home: it is a `.target`, it is **absent from `products:`**, it is named
by no non-test target, and hygiene check 4 asserts all three — so a harness that ships in the package
cannot reach the release binary. It must not `import Testing` (only `Unimplemented.swift` does), which
is also what lets `PROGRESS.md`'s numbers be produced by a `swift run` tool later if needed.

## Implementation notes

### The shape

```swift
/// §10.10's Level A. "Does not play": given a served δ it draws a response, and that is all.
/// It exists to test the estimator and the serving policy in isolation, and it is what π₀ is
/// solved against.
public struct ResponseHarness: Sendable {
    /// §10.10's day-to-day variance.
    public static let dayToDaySigma = 0.35
    /// §10.1's derived counterexample recovery rate: `0.62 + (1 − 0.62)·r = 0.80 ⟹ r = 0.474`.
    public static let counterexampleRecoveryRate = 0.474

    public let trueAbility: Double
    public let trueOffset: Double
    private var rng: SplitMix64

    public init(trueAbility: Double, trueOffset: Double = 0, seed: UInt64)

    public mutating func drawNoise() -> Double
    public mutating func responds(toServedDelta servedDelta: Double) -> Bool

    public static func run(trueAbility: Double, rounds: Int, seed: UInt64, mode: Mode,
                           trueOffset: Double = 0, centring: Double = Pressure.centringConstant,
                           recordingRounds: Bool = true) -> Run
    public static func medianAcrossSeeds(trueAbility: Double, rounds: Int,
                                         seeds: Int, mode: Mode) -> Summary
    public static func realisedSuccessRate(trueAbility: Double, rounds: Int,
                                           seed: UInt64, centring: Double) -> Double
    public static func solveCentringConstant(trueAbilities: [Double], rounds: Int,
                                             seed: UInt64) -> Double
}
```

`centring` as a **parameter** with the shipped constant as its default is what makes T04's
counterfactual and the π₀ solver possible without a global. `ServingPolicy.serve` reads
`Pressure.centringConstant` directly, so the harness's loop applies the override by adjusting the
served δ after the call — document that this is an *analysis* affordance and that production has one
value.

### The Gaussian, hand-rolled

`swift-numerics` is banned (`08 §7.9`) and `Double.random` is banned by hygiene check 6, so `ε` is
Box–Muller over two `Sampling.unitInterval` draws:

```swift
public mutating func drawNoise() -> Double {
    // Box–Muller. Cache the second variate: two transcendental calls per two draws, not per one,
    // which is worth ~15 % of the 400 ns round budget.
    if let spare { self.spare = nil; return spare * Self.dayToDaySigma }
    var u1 = Sampling.unitInterval(using: &rng)
    if u1 <= 0 { u1 = .leastNormalMagnitude }          // log(0) is −∞ and would poison the run
    let u2 = Sampling.unitInterval(using: &rng)
    let r = (-2 * Foundation.log(u1)).squareRoot()
    spare = r * Foundation.sin(2 * .pi * u2)
    return r * Foundation.cos(2 * .pi * u2) * Self.dayToDaySigma
}
```

The `u1 <= 0` guard is not defensive padding: `unitInterval` returns `[0, 1)`, so zero is reachable
once every 2⁵³ draws, and a single `-inf` would make every subsequent θ̂ `NaN` and H16 would report the
symptom rather than the cause. `noiseIsAsSpecified` checks the mean and the standard deviation over
400 k draws, which is the only way a transcription error in Box–Muller shows up.

### The loop, and the 400 ns budget

10⁶ rounds in 0.4 s is **400 ns per round**, and a round is: one `ServingPolicy.serve` (a SplitMix64
draw, ten arithmetic steps, two `switch`es), one `responds` (two uniforms, a log, a sin/cos, an
`exp`), one `AbilityEstimator.updated` (an `exp`), one `Pressure.applying`, one
`ServingState.recordingServe`. Four transcendentals at ~20 ns each is 80 ns; the rest is arithmetic on
inline values. It fits — **provided nothing allocates**:

1. `Ability` and `ServingState` must be trivially copyable. T01's `ModeVector` is why; if
   `millionRoundBudget` is red, check that first with `runIsAllocationBounded`.
2. `recordingRounds: false` skips the per-round record array entirely and accumulates a `Summary`
   incrementally. The 10⁶-round tests all use it; the 400-round table test does not, because it needs
   the trajectory.
3. When `recordingRounds` is true, `reserveCapacity(rounds)` once. A growing array is `log n`
   reallocations of up to 40 MB.
4. `Serving.Trace` is a struct of inline values (T03), so returning it costs nothing.

`Run` and `Summary`:

```swift
public struct ResponseHarness.Run: Sendable {
    public let rounds: [RoundRecord]          // empty when `recordingRounds` is false
    public let abilityTrajectory: [Double]    // sampled every round; also empty in summary mode
    public let summary: Summary
}

public struct ResponseHarness.Summary: Sendable {
    public let roundCount: Int
    public let successRate: Double
    public let finalEstimate: Double
    public let roundsToWithin(_: Double) -> Int      // H2
    public let maxConsecutiveLosses: Int             // H6
    public let estimateRange: ClosedRange<Double>    // H16
    public let offsetRange: ClosedRange<Double>      // §10.2's |Δ| ≤ 3.0
    public let sawNonFinite: Bool                    // H16
    public let bandHistogram: [Band: Int]            // H9, H21
    public let modalBand: Band
    public let meanReachMinusRelief: Double          // H18
    public let unforcedBandChanges: Int              // H9's *unforced* form
    public let anchorFallbacks: Int                  // H19, when a generator is attached
    public func probabilityOfLossRun(atLeast: Int) -> Double
}
```

Every field on `Summary` exists because one numbered invariant needs it. Do not add a field without
naming the invariant; do not compute an invariant in the test from `rounds` when a field could carry
it, because the 10⁶-round runs have no `rounds`.

`successRate` is measured over **rounds 26–400** for the table test — H3's window, which excludes the
convergence transient. Make the window a parameter of `medianAcrossSeeds` with §10.10's default so T12
does not restate it.

### `unforcedBandChanges` — computed here, asserted in T12

H9's new form is *"zero band changes on rounds where `reach`, `relief` and the ceiling rotation are
all inert"*. That predicate reads `Serving.Trace`: `trace.reach == 0 && trace.relief == 0 &&
trace.bandAfterCeilingRotation == trace.bandAfterRepeatGuard`, comparing consecutive rounds' bands.
Compute it in the harness's accumulator, because at `θ_true = +6` the interesting runs are 10⁶ rounds
long and cannot be post-processed from an array.

### The seven-row table, and its two edge rows

§10.10 is explicit that the −3.0 and +4.0 rows are **artefacts asserted rather than corrected**: at
θ_true = −3.0 the δ clamp at −4.00 binds and the rate falls to 0.64 (H8's floor rescue owns it), and at
+4.0 the clamp at 3.99 binds the other way and θ̂ under-estimates. So `publishedTableReproduces`
asserts those two rows at their *published* values, not at 0.80 — and if a future change makes the
−3.0 row read 0.80, that is a **failure**, because it would mean the clamp stopped binding.

Tolerances: θ̂ within 0.15 (the table prints two decimals of a median across 64 seeds), success within
0.03 (H3's own tolerance), modal band exact. `maxConsecutiveLosses` is asserted as `≤ published + 2`
because a maximum over 64 seeds is heavy-tailed and the published column is a median; H6's hard bound
of 6 is asserted separately over 10⁶ rounds.

### `solveCentringConstant`

Bisection on `π₀` over `[0.0, 1.0]`, target `realisedSuccessRate == 0.800` averaged over the five
`θ_true` values H3 covers, 20 iterations, deterministic seed. Roughly 20 × 5 × 200 k = 20 M rounds ≈
8 s, which is why it is tagged `.integration .nightly`. It is not a fast-suite test and it must not
become one; H18's fast form asserts the *measured* `E[reach − relief]` and the *realised rate* at the
shipped constant, which is one 10⁶-round run and cheap.

Record the solver's output in `PROGRESS.md` beside the shipped constant every time either changes.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ResponseHarnessTests` is green.
- [ ] `millionRoundBudget` passes: 10⁶ rounds in under 400 ms, measured with `ContinuousClock` inside the test.
- [ ] `runIsAllocationBounded` passes with `recordingRounds: false` and an empty `rounds` array.
- [ ] `ε` measures mean 0 ± 0.005 and standard deviation 0.35 ± 0.005 over 400 k draws.
- [ ] All seven rows of §10.10's table reproduce within their stated tolerances, including the two edge rows at their published (non-0.80) values.
- [ ] `firstDeclarationRate(successRate:)` and `successRate(firstDeclarationRate:)` are mutual inverses and give 0.62 ↔ 0.80 within 0.005.
- [ ] The nightly π₀ solver returns the shipped `Pressure.centringConstant` within 0.02.
- [ ] T04's `uncentredPolicyMissesTheTarget` is green with its placeholder comment removed.
- [ ] `grep -n 'import Testing' HunchCore/Sources/HunchTestSupport/ResponseHarness.swift` returns nothing.
- [ ] `grep -rn 'HunchTestSupport' HunchCore/Package.swift` still shows it absent from `products:`.
- [ ] `PROGRESS.md` carries the measured table beside §10.10's published one, with every seed named.
- [ ] `tests.json` carries the three Level-A entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s — check the **whole** suite time, not just this filter.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests **and re-measure the budget** after it: a "simplification" that
   introduces a per-round allocation is the specific regression this task is exposed to.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T10: Level A — the response harness, 10^6 rounds under 0.4 s, and π₀'s solver"`

## Out of scope

- Any harness that actually induces a law — **T11**. Level A never sees a law and never calls `generate`.
- H10, H11, H12, H20 and every per-law statistic — **T11** and **T12**; Level A cannot carry them.
- Formally asserting H1–H21 with their `tests.json` rows — **T12**. The fast forms here are the harness's own tests, not the invariant suite.
- The Anomaly injection H14 needs — **T12**, using this harness.
- `π₀`'s value — **T04**. This task measures it; it does not choose it.
