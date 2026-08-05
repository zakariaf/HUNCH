# T04 — The pressure term and `π₀`

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | §14.1 Pressure term |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that the outcome-time mutation of `ServingState` is **one** named function (`Pressure.applying(…)`) rather than four scattered `if`s at four call sites — `W29`'s exhaustive-switch discipline applied to a state machine that is not spelled as an enum. It also owns the ruling that `π₀`'s three constants are `public static let` on a namespace so H18 can assert each part rather than the sum. |

## Objective

`reach` climbs on a win streak, `relief` buys a full band after two consecutive losses, both freeze in
whichever direction a step-8 clamp is binding, and the whole term is centred by `π₀ = 0.44` so it
**reallocates** difficulty across rounds instead of shifting it. At the end of this task the
uncentred policy's realised 0.75 is reproducible on demand as a failing test, and the shipped 0.44 is
decomposed into the two quantities H18 measures separately.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.3 | The `reach` / `relief` pseudocode verbatim; the clamp-binding freeze; the whole `π₀` derivation, including `E[reach] = 0.413`, `E[relief] = 0.035`, the fixed point at 0.75 uncentred, `σ'' = −0.096`, the curvature term and the measured 0.797–0.799 |
| `GAME_DESIGN.md` | §10.7 | The relief ladder as an anti-frustration trigger; the trace `L → LL → LLL → LLLL → W → WW`; the guaranteed floor behaviour at band 1 |
| `GAME_DESIGN.md` | §10.1 | `reach` 0…1.00, `relief` 0…2.00, `winStreak`, `consecutiveLosses`; what counts as a loss and what is not scored at all |
| `GAME_DESIGN.md` | §10.10 | H6, H7, H18 and H21 — the four invariants that measure this term |
| `GAME_DESIGN.md` | §10.4 | Calibration rounds are exempt from `reach`, `relief` and `consecutiveLosses` |
| `GAME_DESIGN.md` | §10.6 | Anomaly rounds never update `reach`, `relief`, `winStreak` or `consecutiveLosses` |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | One function for one moment; no parallel fields |

Do not restate a ladder step, a cap or `π₀`'s value in prose. Cite §10.3.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/PressureTests.swift`:

```swift
import Testing
import Glyphs
import LawGeneration
@testable import Ladder
import HunchTestSupport

@Suite("The pressure term — §10.3, §10.7", .tags(.unit, .presubmission))
struct PressureTests {

    // MARK: reach

    /// §10.3: "Streak 1 → 0, 2 → 0.25, 3 → 0.50, 4 → 0.75, ≥5 → 1.00."
    @Test("reach follows §10.3's schedule and saturates",
          arguments: [(0, 0.00), (1, 0.00), (2, 0.25), (3, 0.50), (4, 0.75),
                      (5, 1.00), (9, 1.00), (400, 1.00)])
    func reachSchedule(_ streak: Int, _ expected: Double) {
        #expect(isApproximatelyEqual(Pressure.reach(winStreak: streak), expected,
                                     absoluteTolerance: 1e-12))
    }

    @Test("A loss collapses reach to zero from anywhere")
    func lossCollapsesReach() {
        var state = ServingState.dayOneCalibrated
        state.winStreak = 12
        state.reach = 1.0
        let after = Pressure.applying(.loss, to: state, servedBand: .relational, mode: .probe)
        #expect(after.reach == 0)
        #expect(after.winStreak == 0)
    }

    // MARK: relief — §10.7's trace, one row at a time

    /// L → 0.00 · LL → 1.00 · LLL → 2.00 · LLLL → 2.00 · W → 0.50 · WW → 0.00
    @Test("The relief ladder reproduces §10.7's trace exactly")
    func reliefTrace() {
        var state = ServingState.dayOneCalibrated
        func loss() { state = Pressure.applying(.loss, to: state, servedBand: .relational, mode: .probe) }
        func win()  { state = Pressure.applying(.win,  to: state, servedBand: .relational, mode: .probe) }

        loss(); #expect(isApproximatelyEqual(state.relief, 0.00, absoluteTolerance: 1e-12))
        loss(); #expect(isApproximatelyEqual(state.relief, 1.00, absoluteTolerance: 1e-12))
        loss(); #expect(isApproximatelyEqual(state.relief, 2.00, absoluteTolerance: 1e-12))
        loss(); #expect(isApproximatelyEqual(state.relief, 2.00, absoluteTolerance: 1e-12))
        win();  #expect(isApproximatelyEqual(state.relief, 1.50, absoluteTolerance: 1e-12))
        win();  #expect(isApproximatelyEqual(state.relief, 1.00, absoluteTolerance: 1e-12))
        win();  #expect(isApproximatelyEqual(state.relief, 0.50, absoluteTolerance: 1e-12))
        win();  #expect(isApproximatelyEqual(state.relief, 0.00, absoluteTolerance: 1e-12))
        win();  #expect(isApproximatelyEqual(state.relief, 0.00, absoluteTolerance: 1e-12))
    }

    @Test("One loss moves nothing but the estimate")
    func oneLossBuysNothing() {
        let state = ServingState.dayOneCalibrated
        let after = Pressure.applying(.loss, to: state, servedBand: .relational, mode: .probe)
        #expect(after.relief == state.relief)
        #expect(after.consecutiveLosses == 1)
    }

    @Test("relief is capped at two full bands")
    func reliefCaps() {
        var state = ServingState.dayOneCalibrated
        for _ in 0..<12 {
            state = Pressure.applying(.loss, to: state, servedBand: .relational, mode: .probe)
        }
        #expect(state.relief <= Pressure.reliefCap)
        #expect(isApproximatelyEqual(state.relief, Pressure.reliefCap, absoluteTolerance: 1e-12))
    }

    // MARK: the freeze

    /// §10.3: "reach is frozen at its current value while band == maxBand(mode)" — so the ladder
    /// never builds unspendable pressure that must be discharged before the next real move.
    @Test("reach does not accumulate while the mode ceiling is binding")
    func reachFreezesAtTheCeiling() {
        var state = ServingState.dayOneCalibrated
        state.winStreak = 2
        state.reach = 0.25
        let after = Pressure.applying(.win, to: state, servedBand: .systemic, mode: .probe)
        #expect(after.winStreak == 3)                     // the streak still counts
        #expect(isApproximatelyEqual(after.reach, 0.25, absoluteTolerance: 1e-12))   // reach does not
    }

    @Test("relief does not accumulate while the mode floor is binding")
    func reliefFreezesAtTheFloor() {
        var state = ServingState.dayOneCalibrated
        state = Pressure.applying(.loss, to: state, servedBand: .literal, mode: .probe)
        state = Pressure.applying(.loss, to: state, servedBand: .literal, mode: .probe)
        #expect(state.consecutiveLosses == 2)             // the counter still counts
        #expect(state.relief == 0)                        // relief does not
    }

    @Test("The freeze is directional: a loss at the ceiling still collapses reach")
    func freezeIsDirectional() {
        var state = ServingState.dayOneCalibrated
        state.winStreak = 6
        state.reach = 1.0
        let after = Pressure.applying(.loss, to: state, servedBand: .systemic, mode: .probe)
        #expect(after.reach == 0)
    }

    @Test("A win at the floor still spends relief")
    func winAtTheFloorStillSpendsRelief() {
        var state = ServingState.dayOneCalibrated
        state.relief = 2.0
        let after = Pressure.applying(.win, to: state, servedBand: .literal, mode: .probe)
        #expect(isApproximatelyEqual(after.relief, 1.50, absoluteTolerance: 1e-12))
    }

    /// DRIFT's floor is band 3, not band 1 (§10.3 step 8), so the freeze must read the MODE's
    /// range and not a global one.
    @Test("The freeze reads the mode's own band range", arguments: Mode.allCases)
    func freezeReadsTheModeRange(_ mode: Mode) {
        var state = ServingState.dayOneCalibrated
        let floor = ServingPolicy.bandRange(for: mode).lowerBound
        state = Pressure.applying(.loss, to: state, servedBand: floor, mode: mode)
        state = Pressure.applying(.loss, to: state, servedBand: floor, mode: mode)
        #expect(state.relief == 0)
    }

    // MARK: reach never touches θ

    /// §10.3: "Reach never touches θ, so a probing escalation cannot inflate the estimate."
    /// Structural first — the estimator takes no `ServingState` — then behavioural.
    @Test("Two runs differing only in reach produce a bit-identical θ̂")
    func reachDoesNotTouchAbility() throws {
        func run(startingReach: Double) throws -> Double {
            var ability = Ability.seeded(baseline: 0.0)
            var state = ServingState.dayOneCalibrated
            state.reach = startingReach
            state.winStreak = startingReach > 0 ? 5 : 0
            for i in 0..<200 {
                // Both runs are handed the SAME served δ, so only the estimator is exercised.
                ability = AbilityEstimator.updated(ability, mode: .probe,
                                                   servedDelta: -1.3863, won: i % 5 != 0)
            }
            return try #require(ability.baseline)
        }
        #expect(try run(startingReach: 0.0) == try run(startingReach: 1.0))
    }

    // MARK: π₀

    /// §10.3 gives π₀ as `E[reach − relief] + curvature = 0.375 + 0.065`. Ship the parts, not
    /// the sum: H18 measures `E[reach − relief]` and the realised rate separately, and a sum-only
    /// constant makes a stale jitter width indistinguishable from a stale relief ladder.
    @Test("π₀ is the documented sum of its two parts")
    func centringConstantIsDecomposed() {
        #expect(isApproximatelyEqual(
            Pressure.expectedReachMinusRelief + Pressure.curvature,
            Pressure.centringConstant, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Pressure.centringConstant, 0.44, absoluteTolerance: 1e-12))
    }

    /// The counterfactual, kept as a live test rather than a paragraph: with the centring removed
    /// the policy serves about +0.37 logit hard and the fixed point lands at 0.75, not 0.80.
    /// §10.3 calls that "a different game", and this is the test that says so in numbers.
    @Test("Uncentred, the realised success rate collapses to ≈0.75", .tags(.performance))
    func uncentredPolicyMissesTheTarget() {
        let centred = ResponseHarness.realisedSuccessRate(
            trueAbility: 0.0, rounds: 200_000, seed: 0xC0FFEE_1, centring: Pressure.centringConstant)
        let uncentred = ResponseHarness.realisedSuccessRate(
            trueAbility: 0.0, rounds: 200_000, seed: 0xC0FFEE_1, centring: 0.0)

        #expect(isApproximatelyEqual(centred, 0.800, absoluteTolerance: 0.01))
        #expect(isApproximatelyEqual(uncentred, 0.749, absoluteTolerance: 0.015))
    }

    // MARK: exemptions

    @Test("A calibration round changes nothing in the pressure term")
    func calibrationIsExempt() {
        var state = ServingState.dayOne          // calibrationRound == 1
        state.winStreak = 0
        let after = Pressure.applying(.win, to: state, servedBand: .literal, mode: .probe)
        #expect(after == state)
    }

    /// §10.6 / H14. The Anomaly is not an outcome this function is ever handed; asserting the
    /// absence here is what makes E16·T03's isolation claim structural rather than hopeful.
    @Test("There is no way to spell an Anomaly outcome to this function")
    func anomalyIsNotAnOutcome() {
        #expect(Pressure.Outcome.allCases == [.win, .loss])
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter PressureTests`

It must fail on missing symbols — `Pressure`, `Pressure.Outcome`, `Pressure.applying(_:to:servedBand:mode:)`,
`Pressure.centringConstant` — not on a malformed expectation. `uncentredPolicyMissesTheTarget` will
additionally fail to compile until T10 exists; **write it now and mark it with a
`// requires T10's ResponseHarness` comment**, then delete the comment and confirm it green as the
first thing T10 does. Do not weaken it to a placeholder.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** The freeze is the part most likely to end up duplicated between
`applying` and the policy; it belongs here, once.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/Pressure.swift` |
| modify | `HunchCore/Sources/Ladder/ServingPolicy.swift` — step 4 now reads `Pressure.centringConstant` from its real home |
| create | `HunchCore/Tests/LadderTests/PressureTests.swift` |
| modify | `SPEC.md` — `π₀ = 0.44` joins §5.7's locked-constant table, with H18 named as its guard |
| modify | `tests.json` — `ladder.reach-schedule`, `ladder.relief-ladder`, `ladder.clamp-freeze`, `ladder.pi-zero-decomposed` |

## Implementation notes

### The shape

```swift
/// §10.3's pacing term: the whole of the ladder's "up fast, down gently" behaviour, kept out of
/// the estimator by §10.2's Decision so the Rasch fixed point survives.
public enum Pressure {

    /// The only two things that can happen to a *scored* round, from this term's point of view.
    /// §10.1 lists four outcomes that are not scored at all and §10.6 excludes the Anomaly;
    /// none of them is representable here, which is how H14's isolation is enforced structurally.
    public enum Outcome: CaseIterable, Sendable { case win, loss }

    public static let reachCap: Double          // §10.3
    public static let reachStep: Double         // §10.3
    public static let reliefCap: Double         // §10.3
    public static let reliefStep: Double        // §10.3
    public static let reliefRecoveryStep: Double
    public static let lossesBeforeRelief: Int

    /// π₀, and its two documented parts. §10.3 derives it as `E[reach − relief] + curvature`.
    public static let expectedReachMinusRelief = 0.375
    public static let curvature = 0.065
    public static let centringConstant = expectedReachMinusRelief + curvature

    public static func reach(winStreak: Int) -> Double

    /// The single outcome-time mutation of `ServingState`. Serve-time mutation is
    /// `ServingState.recordingServe(_:)` (T03). There is no third place.
    public static func applying(_ outcome: Outcome, to state: ServingState,
                                servedBand: Band, mode: Mode) -> ServingState
}
```

`centringConstant` is **computed from its parts**, not written as `0.44`. That is the mechanism H18
needs: §10.3 says *"if the jitter width, the relief ladder or the reach schedule ever changes, `π₀` is
re-solved; H18 fails the build if it is not"*, and a single opaque `0.44` cannot tell you which of the
three moved. `centringConstantIsDecomposed` asserts the sum still reads 0.44 so the published number
stays checkable.

### The freeze, written once

```swift
public static func applying(_ outcome: Outcome, to state: ServingState,
                            servedBand: Band, mode: Mode) -> ServingState {
    // §10.4: "Calibration rounds are exempt from consecutiveLosses, reach and relief —
    // the ladder already stops."
    guard state.calibrationRound == nil else { return state }

    let range = ServingPolicy.bandRange(for: mode)
    let ceilingBinds = servedBand == range.upperBound      // §10.3: reach frozen
    let floorBinds   = servedBand == range.lowerBound      // §10.3: relief frozen

    var copy = state
    switch outcome {
    case .win:
        copy.winStreak += 1
        copy.consecutiveLosses = 0
        if !ceilingBinds { copy.reach = reach(winStreak: copy.winStreak) }
        copy.relief = max(0, copy.relief - reliefRecoveryStep)
    case .loss:
        copy.winStreak = 0
        copy.reach = 0
        copy.consecutiveLosses += 1
        if copy.consecutiveLosses >= lossesBeforeRelief && !floorBinds {
            copy.relief = min(reliefCap, copy.relief + reliefStep)
        }
    }
    return copy
}
```

Four things this shape gets right that a scattering of `if`s at call sites does not:

1. **The freeze is directional, not a blanket skip.** A loss at the ceiling still collapses `reach`
   (that is a *decrease*, and §10.3 only freezes accumulation "in that direction"); a win at the floor
   still spends `relief`. `freezeIsDirectional` and `winAtTheFloorStillSpendsRelief` are the two tests
   that pin it, and both would pass a naive `guard !binds else { return state }` — so read them
   carefully before simplifying.
2. **The counters keep counting.** `winStreak` still increments at the ceiling and
   `consecutiveLosses` still increments at the floor. Freezing the counter as well would make the
   ceiling rotation (which reads `ceilingClampRun`, not `winStreak`) and the floor rescue (which
   reads `consecutiveLosses`) both dead at exactly the bands they exist for.
3. **Calibration exits first.** §10.4's exemption is one `guard` and it covers all three quantities,
   which is why it is a guard rather than three conditionals.
4. **`mode` is a parameter.** DRIFT's floor is band 3 (§10.3 step 8), so "the floor binds" is not a
   global question. `freezeReadsTheModeRange` is parameterised over all four modes for this reason.

### The Anomaly, and why it is an absence

§10.6 says Anomaly rounds never update θ, `reach`, `relief`, `winStreak` or `consecutiveLosses`, and
H14 asserts θ̂ is bit-identical with and without 400 of them injected. The enforcement here is that
there is **no `Outcome` case for it** — an Anomaly round simply never calls `applying`. E16·T03 owns
the call-site rule; `anomalyIsNotAnOutcome` is this task's half, and it is a real assertion because
`Outcome: CaseIterable` makes "there are exactly two" checkable.

The same applies to `abandoned`, `voided` and a suspended round: E10·T04's
`RoundEffects.updatesAbility` already decides whether the estimator runs, and T06 wires the same
predicate to `applying`. Note in the doc comment that `Outcome` is *not* `Rounds.Outcome` — the round
has five outcomes and this term has two, and collapsing them into one type would put `.voided` one
typo away from moving the ladder.

### `reach(winStreak:)`

`min(reachCap, reachStep * Double(max(0, winStreak - 1)))`. The `max(0, …)` matters: §10.3's
pseudocode increments `winStreak` *then* computes reach, so a streak of 0 (fresh, or just after a
loss) must not produce a negative reach. `reachSchedule`'s first two rows are that assertion.

### Where the counterfactual test lives

`uncentredPolicyMissesTheTarget` is the single most valuable test in this task and it belongs here
rather than in T10 or T12: it is the *justification* for the constant, and a justification that lives
three files away from the constant stops being read. It is tagged `.performance` only because it runs
400 k harness rounds; if it measures over ~0.2 s, drop both runs to 100 k rounds and widen the
tolerances by the square root of the ratio — never delete it (`06 T58`).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter PressureTests` is green, all fifteen tests (with `uncentredPolicyMissesTheTarget` green as of T10's landing).
- [ ] §10.7's relief trace `L·LL·LLL·LLLL·W·WW` reproduces exactly, to 1e-12, in one test that walks it row by row.
- [ ] `reach(winStreak:)` reproduces all eight of §10.3's schedule rows to 1e-12.
- [ ] The freeze is asserted in all four directions: reach frozen at the ceiling on a win, reach still collapsed at the ceiling on a loss, relief frozen at the floor on a loss, relief still spent at the floor on a win.
- [ ] `Pressure.expectedReachMinusRelief + Pressure.curvature == Pressure.centringConstant == 0.44` to 1e-12, and `centringConstant` is not written as a literal.
- [ ] `Pressure.Outcome.allCases.count == 2` and `grep -n 'anomaly\|abandoned\|voided\|suspended' HunchCore/Sources/Ladder/Pressure.swift` returns only doc-comment occurrences.
- [ ] `grep -rn 'var copy = self' HunchCore/Sources/Ladder` returns exactly two hits: `recordingServe` and `applying`.
- [ ] The uncentred counterfactual measures 0.749 ± 0.015 and the centred one 0.800 ± 0.01.
- [ ] `SPEC.md`'s locked-constant table carries `π₀ = 0.44` with H18 named.
- [ ] `tests.json` carries the four pressure entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it. If it proposes collapsing the freeze into a single
   early `return`, decline: the four directional tests are why.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T04: reach, relief, the clamp-binding freeze and π₀ decomposed into its two measured parts"`

## Out of scope

- Step 4's *application* of the term — **T03**, already shipped. This task supplies the values it reads.
- Calibration's own exemption logic beyond the one guard — **T05**.
- Who calls `applying` and with which outcome — **T06**, reading E10·T04's `RoundEffects`.
- The floor rescue that fires when relief has nowhere left to go — **T07**.
- The re-entry relief that raises `relief` after an absence — **T08**.
- Measuring `E[reach − relief]` over 10⁶ rounds, the realised rate, H6, H7, H18 and H21 — **T10** and **T12**.
- The Anomaly's call-site isolation and H14's bit-identity assertion — **E16·T03** and **T12**.
