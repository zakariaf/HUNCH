# T02 — `AbilityEstimator`

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 Update rule |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that the estimator is a caseless-enum namespace of pure statics rather than a type with state (`W16`), that its four arguments are exactly `(Ability, Mode, servedDelta, Bool)` with no fifth, and that it lives in `Ladder` beside `Ability` because every input is a value you can write down. It also owns the Greek-identifier rename: `θ` → `ability`, `δ_served` → `servedDelta` (`08 §3`, `N1`, `N33`). |
| `hunch-swift-testing` | Every assertion here compares `Double`s, so `isApproximatelyEqual(_:_:absoluteTolerance:)` from `HunchTestSupport` is mandatory — swift-numerics is banned (`08 §7.9`) and `#expect(a == b)` on a `Double` is the thing this project must never ship. It also owns the seeded-corpus discipline the fixed-point test uses. |

## Objective

`AbilityEstimator.updated(_:mode:servedDelta:won:)` applies §10.2's Rasch update and nothing else: no
clock, no RNG, no store, no `ServingState`, and — the load-bearing part — **no branch on the outcome**
other than `x ∈ {0, 1}` itself. At the end of this task a seeded Bernoulli stream at a fixed served δ
drives θ̂ to its true value, and any attempt to add an "up fast, down gently" factor here fails a test
rather than a review.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.2 | The update rule verbatim; `K(n)`'s formula and its six tabulated values; the symmetry Decision and the ~0.4-logit bias it prevents; the four-wins-to-undo-one-loss ratio; `K_Δ = 0.6·K` and the 0.985 shrinkage |
| `GAME_DESIGN.md` | §10.1 | `P(win) = σ(θ_mode − δ_logit)`, with no guessing and no discrimination parameter; the ruling that the response variable is the **round outcome**, not the first declaration; which outcomes are not scored at all |
| `GAME_DESIGN.md` | §10.3 step 12 | `δ_served = 8·targetδ − 4` — **this**, not step 6's δ, is what the estimator consumes, and it is a logit |
| `GAME_DESIGN.md` | §5.1 | `δ_logit = 8·difficulty − 4`; `Rasch` (E06·T02) already ships the conversion |
| `GAME_DESIGN.md` | §10.5 | The offset decomposition and why three of four modes get a free cold start |
| `ios-swift-guide/06-TESTING.md` | T21, T30 | No loops in tests except where paid for; tag on both axes |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | `LadderTests` owns brief invariant 2; `isApproximatelyEqual` before the first `#expect` on a `Double` |

Do not restate `K`'s coefficients, the floor, or the six tabulated values in prose. Cite §10.2.

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LadderTests/AbilityEstimatorTests.swift`:

```swift
import Testing
import Glyphs                    // Mode
import LawGeneration             // Rasch
@testable import Ladder
import HunchTestSupport

@Suite("AbilityEstimator — §10.2", .tags(.unit, .presubmission))
struct AbilityEstimatorTests {

    // MARK: K(n)

    /// §10.2 tabulates six values. They are the formula's outputs, not a second table —
    /// asserting them here is asserting that the formula was transcribed correctly.
    @Test("K(n) reproduces §10.2's six published values",
          arguments: [(0, 0.900), (4, 0.600), (8, 0.450), (16, 0.300), (24, 0.225), (32, 0.180)])
    func learningRateMatchesTheTable(_ n: Int, _ expected: Double) {
        #expect(isApproximatelyEqual(AbilityEstimator.learningRate(scoredRounds: n), expected,
                                     absoluteTolerance: 5e-4))
    }

    @Test("K is monotonically non-increasing and never falls below its floor",
          arguments: [0, 1, 2, 5, 13, 31, 32, 33, 100, 4_096])
    func learningRateIsBoundedAndMonotone(_ n: Int) {
        let k = AbilityEstimator.learningRate(scoredRounds: n)
        #expect(k >= AbilityEstimator.learningRateFloor)
        #expect(k <= AbilityEstimator.learningRateCeiling)
        if n > 0 {
            #expect(k <= AbilityEstimator.learningRate(scoredRounds: n - 1))
        }
    }

    // MARK: P

    @Test("Serving θ − ln4 gives exactly the locked target success rate")
    func servingOffsetHitsTheTarget() {
        for ability in stride(from: -4.0, through: 4.0, by: 0.5) {
            let p = AbilityEstimator.successProbability(
                ability: ability, servedDelta: ability - Rasch.servingOffset)
            #expect(isApproximatelyEqual(p, Rasch.targetSuccessRate, absoluteTolerance: 5e-4))
        }
    }

    @Test("P is σ and nothing else — no guessing floor, no discrimination slope")
    func successProbabilityIsPlainLogistic() {
        #expect(isApproximatelyEqual(
            AbilityEstimator.successProbability(ability: 0, servedDelta: 0), 0.5,
            absoluteTolerance: 1e-12))
        // A guessing parameter would lift the tail off zero; assert it does not.
        #expect(AbilityEstimator.successProbability(ability: -6, servedDelta: 4) < 0.001)
        #expect(AbilityEstimator.successProbability(ability: 6, servedDelta: -4) > 0.999)
    }

    // MARK: symmetry — the whole point of the task

    /// §10.2's Decision, as arithmetic: for ANY P, the win step over `(1 − P)` and the loss step
    /// over `P` are the same number, namely `K`. A direction-dependent factor breaks this equality
    /// and moves θ̂ up by ~0.4 logit at equilibrium.
    @Test("The step size is K in both directions, at every P",
          arguments: [-3.0, -1.0, -0.25, 0.0, 0.25, 1.0, 3.0])
    func updateIsStrictlySymmetric(_ servedDelta: Double) throws {
        let before = Ability.seeded(baseline: 0.0)
        let n = before.scoredRounds[.probe]
        let k = AbilityEstimator.learningRate(scoredRounds: n)
        let p = AbilityEstimator.successProbability(ability: 0.0, servedDelta: servedDelta)

        let afterWin = AbilityEstimator.updated(before, mode: .probe,
                                                servedDelta: servedDelta, won: true)
        let afterLoss = AbilityEstimator.updated(before, mode: .probe,
                                                 servedDelta: servedDelta, won: false)

        let up = try #require(afterWin.baseline) - 0.0
        let down = 0.0 - (try #require(afterLoss.baseline))

        #expect(isApproximatelyEqual(up / (1 - p), k, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(down / p, k, absoluteTolerance: 1e-9))
    }

    /// §10.2's worked sentence: at the floor, a win at P = 0.8 moves +0.036 and a loss −0.144 —
    /// four wins to undo one loss, produced by symmetry rather than by an asymmetry knob.
    @Test("At the K floor and the target rate, four wins undo one loss")
    func fourWinsUndoOneLoss() throws {
        var ability = Ability.seeded(baseline: 0.0)
        ability.setScoredRounds(4_096, for: .probe)        // K at its floor
        let servedDelta = 0.0 - Rasch.servingOffset        // P = 0.80 by construction

        let win = AbilityEstimator.updated(ability, mode: .probe, servedDelta: servedDelta, won: true)
        let loss = AbilityEstimator.updated(ability, mode: .probe, servedDelta: servedDelta, won: false)
        let up = try #require(win.baseline)
        let down = try #require(loss.baseline)

        #expect(isApproximatelyEqual(up, 0.036, absoluteTolerance: 5e-4))
        #expect(isApproximatelyEqual(down, -0.144, absoluteTolerance: 5e-4))
        #expect(isApproximatelyEqual(-down / up, 4.0, absoluteTolerance: 0.02))
    }

    // MARK: the fixed point

    /// The property that makes the whole model work: feeding a Bernoulli(true P) stream at a
    /// fixed served δ drives θ̂ to θ_true. This is a loop inside a test and it is the `06 T21`
    /// deviation `08 §7.4` already pays for — the seed is in the failure message.
    @Test("θ̂ converges to θ_true under a stationary Bernoulli stream",
          arguments: [-2.0, -0.5, 0.0, 1.5, 3.0])
    func fixedPointIsTheTruth(_ trueAbility: Double) throws {
        let seed: UInt64 = 0xF17ED_0DDE_5EED
        var rng = SplitMix64(seed: seed ^ UInt64(bitPattern: Int64(trueAbility * 1_000)))
        var ability = Ability.seeded(baseline: 0.0)
        let servedDelta = trueAbility - Rasch.servingOffset      // stationary, P = 0.80

        for round in 0..<4_000 {
            let p = AbilityEstimator.successProbability(ability: trueAbility, servedDelta: servedDelta)
            let won = Sampling.unitInterval(using: &rng) < p
            ability = AbilityEstimator.updated(ability, mode: .probe,
                                               servedDelta: servedDelta, won: won)
            ability.setScoredRounds(round + 1, for: .probe)
        }
        let estimate = try #require(ability.baseline)
        #expect(isApproximatelyEqual(estimate, trueAbility, absoluteTolerance: 0.35),
                "θ_true \(trueAbility), θ̂ \(estimate), seed 0x\(String(seed, radix: 16))")
    }

    // MARK: the mode decomposition

    /// §10.5: "core is PROBE-anchored, the only absolute" and "three of the four modes get a free,
    /// accurate cold start". A SIEVE round must therefore not move the baseline.
    @Test("A non-PROBE round moves only that mode's offset", arguments: [Mode.drift, .echo, .sieve])
    func nonProbeRoundsLeaveTheBaselineAlone(_ mode: Mode) throws {
        let before = Ability.seeded(baseline: 1.0)
        let after = AbilityEstimator.updated(before, mode: mode, servedDelta: 0.0, won: false)
        #expect(try #require(after.baseline) == try #require(before.baseline))
        #expect(after.offset[mode] < before.offset[mode])
        for other in Mode.allCases where other != mode {
            #expect(after.offset[other] == before.offset[other])
        }
    }

    @Test("A PROBE round moves only the baseline")
    func probeRoundsLeaveEveryOffsetAlone() throws {
        var before = Ability.seeded(baseline: 1.0)
        before.setOffset(-0.7, for: .sieve)
        let after = AbilityEstimator.updated(before, mode: .probe, servedDelta: 0.0, won: true)
        #expect(try #require(after.baseline) > try #require(before.baseline))
        for mode in Mode.allCases {
            #expect(after.offset[mode] == before.offset[mode])
        }
    }

    @Test("A mode offset moves at 0.6·K and is then shrunk")
    func offsetUsesTheReducedRateAndShrinks() {
        var before = Ability.seeded(baseline: 0.0)
        before.setScoredRounds(0, for: .drift)
        let after = AbilityEstimator.updated(before, mode: .drift, servedDelta: 0.0, won: true)

        let k = AbilityEstimator.learningRate(scoredRounds: 0)
        let raw = Ability.offsetLearningRateFactor * k * (1.0 - 0.5)     // P = σ(0) = 0.5
        #expect(isApproximatelyEqual(after.offset[.drift], raw * Ability.offsetShrinkage,
                                     absoluteTolerance: 1e-9))
    }

    // MARK: purity

    @Test("The estimator is a pure function: same inputs, same output, every time")
    func isPure() {
        let before = Ability.seeded(baseline: -1.25)
        let a = AbilityEstimator.updated(before, mode: .probe, servedDelta: 0.7, won: true)
        let b = AbilityEstimator.updated(before, mode: .probe, servedDelta: 0.7, won: true)
        #expect(a == b)
        #expect(before == Ability.seeded(baseline: -1.25))       // the input was not mutated
    }

    /// H16, in its cheap form. The expensive form runs over 10⁶ rounds in T12.
    @Test("θ̂ stays finite and inside its clamp under adversarial input",
          arguments: [-40.0, -6.0, 0.0, 6.0, 40.0])
    func staysBounded(_ servedDelta: Double) throws {
        var ability = Ability.seeded(baseline: 0)
        for i in 0..<500 {
            ability = AbilityEstimator.updated(ability, mode: .probe,
                                               servedDelta: servedDelta, won: i % 2 == 0)
        }
        let estimate = try #require(ability.baseline)
        #expect(estimate.isFinite)
        #expect(Ability.range.contains(estimate))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter AbilityEstimatorTests`

It must fail on missing symbols — `AbilityEstimator`, `learningRate(scoredRounds:)`,
`successProbability(ability:servedDelta:)`, `updated(_:mode:servedDelta:won:)`,
`Sampling.unitInterval(using:)` — not on a malformed expectation.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** `fixedPointIsTheTruth` is the canary: if it converges to something
systematically above `θ_true`, an asymmetry has crept in. Do not adjust the tolerance.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/AbilityEstimator.swift` |
| modify | `HunchCore/Sources/LawGeneration/Sampling.swift` — add `unitInterval(using:)` beside E06·T06's `uniform(below:using:)` |
| create | `HunchCore/Tests/LadderTests/AbilityEstimatorTests.swift` |
| modify | `DECISIONS.md` — the PROBE-anchored updating ruling |
| modify | `tests.json` — `ladder.update-rule-symmetric`, `ladder.update-rule-fixed-point`, `ladder.mode-decomposition` |

## Implementation notes

### The shape

```swift
/// §10.2's Rasch update. A caseless namespace of pure statics (`W16`): there is no state to hold,
/// and a `struct AbilityEstimator` with an `Ability` inside it would be a second home for a value
/// that already has one.
public enum AbilityEstimator {

    /// §10.2's `K(n)`. `n` is scored rounds in that mode **after calibration**.
    public static func learningRate(scoredRounds n: Int) -> Double

    /// §10.1's `P(win) = σ(θ_mode − δ_served)`. No guessing parameter, no discrimination parameter.
    /// - Parameter servedDelta: **in logits** — §10.3 step 12's `δ_served`, i.e.
    ///   `Rasch.logit(ofDifficulty: serving.targetDelta)`. Passing a difficulty here is the
    ///   single most damaging unit error available in this file.
    public static func successProbability(ability: Double, servedDelta: Double) -> Double

    /// The one entry point. Pure over its four arguments: no wall clock, no RNG, no store, and
    /// deliberately no `ServingState` — every "up fast, down gently" rule lives in the policy
    /// (§10.2's Decision), so this function cannot see `reach` or `relief` even by accident.
    public static func updated(_ ability: Ability, mode: Mode,
                               servedDelta: Double, won: Bool) -> Ability
}
```

`learningRateFloor` and `learningRateCeiling` are `public static let` on the enum with §10.2 cited,
so `learningRateIsBoundedAndMonotone` adds them up rather than restating them.

### `x` is a `Bool`, and the branch-freedom is the design

```swift
let x = won ? 1.0 : 0.0
let p = successProbability(ability: theta, servedDelta: servedDelta)
let step = k * (x - p)
```

That is the *entire* branch on the outcome. There is no second `if won`, no `k * (won ? a : b)`, no
clamp applied only on a loss. `updateIsStrictlySymmetric` is the behavioural test; add a structural one
to the acceptance criteria as well —
`grep -c 'won' HunchCore/Sources/Ladder/AbilityEstimator.swift` should return a small, auditable number
and every occurrence should be inspectable in one screen.

§10.2 states the cost of getting this wrong precisely: a direction-dependent factor destroys the fixed
point at `E[x] = P` and biases θ̂ upward by ~0.4 logit at equilibrium, which silently moves the true
success rate to ~0.74 — inside H3's neighbourhood but outside its tolerance, which is why the test
that catches it is `fixedPointIsTheTruth` and not H3.

### PROBE-anchored updating — the ruling this task must record

> **Ruling, to be recorded in `DECISIONS.md`.** On a **PROBE** round only `baseline` moves, at `K(n)`.
> On a **DRIFT / ECHO / SIEVE** round only that mode's `offset` moves, at `K_Δ(n) = 0.6·K(n)`, and it
> is then shrunk by 0.985. The baseline never moves on a non-PROBE round.
>
> §10.2's sentence *"Mode offsets update on the same rule with `K_Δ(n) = 0.6·K(n)` plus shrinkage"*
> admits a reading in which both move. That reading fails three stated properties at once: §10.1 calls
> `core` *"PROBE-anchored, the only absolute"*; §10.5 says the decomposition is what gives *"three of
> the four modes a free, accurate cold start"*; and **H17** measures `|Δ̂_sieve − Δ_true| ≤ 0.45` after
> 120 SIEVE rounds for a strong-PROBE / weak-SIEVE player — under the both-move reading most of the
> movement lands in `baseline`, `Δ̂` under-estimates badly, and the player's PROBE ability is corrupted
> by SIEVE evidence. H17's comparatively loose 0.45 tolerance is itself explained by the shrinkage
> bias under the anchored reading, which is the third piece of evidence that this is the intended one.

`n` is incremented by the **caller** (the serving layer, T06, after a scored round), not by the
estimator: §10.1 lists four outcomes that are not scored at all, and the estimator has no way to know
which one it is looking at. `updated` therefore reads `scoredRounds[mode]` and does not write it. State
that in the doc comment; `E10·T04`'s `RoundEffects.updatesAbility` is the field that decides whether
`updated` is called at all.

### The clamp lives on `Ability`, not here

T01 made every write clamp. `updated` therefore builds the new value through `setBaseline` /
`setOffset` / `shrinkOffset` and never assigns a stored property directly. `staysBounded` is the test;
the reason is that a clamp applied in two places will eventually be applied in only one.

### `Sampling.unitInterval(using:)`

E06·T06 hand-rolled `Sampling.uniform(below:using:)` so the determinism golden survives a toolchain
upgrade. The tests here and T10's harness both need a uniform `Double`, and `Double.random(in:)` is
both banned by hygiene check 6 and a stdlib implementation detail. Add one function beside it:

```swift
extension Sampling {
    /// A uniform `Double` in `[0, 1)`, built from 53 explicit bits so the mapping is ours and not
    /// the standard library's. Same reason as `uniform(below:using:)`; see `DECISIONS.md`.
    public static func unitInterval(using rng: inout some RandomNumberGenerator) -> Double {
        Double(rng.next() >> 11) * (1.0 / 9_007_199_254_740_992.0)      // 2^53
    }
}
```

It belongs in `LawGeneration` beside its sibling rather than in `Ladder`: two homes for "how this
project turns bits into a Double" is exactly the drift the golden fixture exists to catch.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AbilityEstimatorTests` is green, all eleven tests.
- [ ] `K(n)` reproduces all six of §10.2's published values within 5e-4, and is monotone non-increasing over `0...4096`.
- [ ] `successProbability(ability: a, servedDelta: a - Rasch.servingOffset)` equals `Rasch.targetSuccessRate` within 5e-4 for every `a` in `-4...4`.
- [ ] For every served δ tested, `Δ_win / (1 − P) == Δ_loss / P == K(n)` to 1e-9.
- [ ] At the K floor and the target rate, the win step is 0.036, the loss step −0.144, and their ratio 4.0 ± 0.02.
- [ ] `fixedPointIsTheTruth` converges within 0.35 for all five `θ_true` values, with the seed printed in the failure message.
- [ ] `grep -n 'ServingState\|reach\|relief\|Date\|rng\|Store' HunchCore/Sources/Ladder/AbilityEstimator.swift` returns nothing.
- [ ] `DECISIONS.md` carries the PROBE-anchored updating ruling with H17 named as its evidence.
- [ ] `tests.json` carries the three estimator entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T02: the symmetric Rasch update, PROBE-anchored, pure over four arguments"`

## Out of scope

- Choosing what δ to serve — **T03**. This function is told.
- `reach`, `relief` and every other asymmetry — **T04**, by §10.2's own Decision.
- Incrementing `n`, deciding whether a round is scored at all, and the `abandoned`/`voided`/Anomaly exclusions — **T06** for the wiring, **E10·T04** and **E16·T03** for the rules.
- `n`'s decay after an absence — **T08**.
- Convergence *speed* (H2), the 80 % hold (H3) and boundedness over 10⁶ rounds (H16) — **T10** and **T12**. The tests here are the unit-level versions.
