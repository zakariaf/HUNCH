# T05 — Cold start and calibration

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | §14.1 Cold start · §14.1 Palette sufficiency |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that `Calibration` is a caseless namespace of pure functions over `(round, marks, band)` and not a state machine object, that the gallop's five rungs are a `static let [Band]` rather than an arithmetic expression on `rawValue` (they are 1·2·4·6·8, not a stride), and that `ServingPolicy.next(…)` — the dispatcher between the calibration path and the ordinary path — is the one function `@Observable Ladder` calls, so the branch cannot be forgotten at a call site. |
| `hunch-bench-instruments` | The reason the full-palette grant exists at all is a **Bench** fact: §10.4's Decision is that a band-4 RELATIONAL law cannot be stated without a Bridge, band 6 without a Fork, band 8 without a Tally. This skill owns `references/rule-tile.md` and the tile-class inventory that `RuleTileClass.required(for:)` (E09·T04) is derived from, and it is what tells you the assertion is about *tile classes*, not about band numbers. |

## Objective

A brand-new player is served bands 1, 2, 4, 6 and 8 in that order while they keep winning, with the
full palette in their hands for every one of those rounds; the first loss seeds `baseline` from the
rung and the previous round's marks; and calibration ends. At the end of this task the failure §10.4's
second Decision names — *"every new player who wins their first two rounds was being handed a round
that is unwinnable by construction"* — is a red test if anyone removes the grant.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.4 | The whole section: the no-prior Decision, the five rungs, `b_est`, `core = (b_est − 4.5) + 1.3863`, the seeded-core table, the full-palette Decision and its four-round argument, the serve-time-not-generation-time rule, the reset paragraph, "modes 2–4 never re-calibrate", and why it does not feel like a test |
| `GAME_DESIGN.md` | §4.4 | The palette Decision the calibration grant is an exception to: tile classes unlock at lifetime maximum band + 1 |
| `GAME_DESIGN.md` | §10.6 | The Anomaly's identical grant — same mechanism, different trigger |
| `GAME_DESIGN.md` | §10.10 | H2 (≤ 12 median rounds to converge, which the ±1-band seeding error is budgeted against) and H20 (palette sufficiency for every calibration round) |
| `GAME_DESIGN.md` | §5.4 | Marks: 3 at ≤ 0.6·par, 2 at ≤ par, 1 at ≤ cap — the quantity `b_est` breaks its tie on |
| `E09·T04` | `PaletteCeiling.swift` | `grantingFullPalette()`, `reverted()`, `isSufficient(for:)`, `raised(toServe:)` — all shipped; this task is what calls them |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | Exhaustive switch, no `default:` |

Do not restate a rung, a seeded core or the `b_est` rule in prose. Cite §10.4.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/CalibrationTests.swift`:

```swift
import Testing
import Glyphs
import Bench                     // PaletteCeiling, RuleTileClass
import LawGeneration             // Band, Rasch
@testable import Ladder
import HunchTestSupport

@Suite("Cold start and calibration — §10.4", .tags(.unit, .presubmission))
struct CalibrationTests {

    // MARK: the gallop

    @Test("The ladder gallops 1, 2, 4, 6, 8 and has exactly five rungs")
    func rungs() {
        #expect(Calibration.rungs == [.literal, .pair, .relational, .guarded, .systemic])
        #expect(Calibration.rungs.count == 5)
    }

    @Test("Round 1 is band 1 unconditionally, whatever the state says")
    func roundOneIsBandOne() {
        for seed in UInt64(0)..<200 {
            let serving = ServingPolicy.next(mode: .probe, ability: .undefined,
                                             state: .dayOne, roundSeed: seed)
            #expect(serving.band == .literal)
        }
    }

    @Test("Each win advances exactly one rung", arguments: Array(1...4))
    func winsAdvanceOneRung(_ round: Int) {
        var state = ServingState.dayOne
        state.calibrationRound = round
        let serving = ServingPolicy.next(mode: .probe, ability: .undefined,
                                         state: state, roundSeed: 1)
        #expect(serving.band == Calibration.rungs[round - 1])

        let after = Calibration.afterRound(won: true, marks: 3, state: state, ability: .undefined)
        #expect(after.state.calibrationRound == round + 1)
        #expect(after.ability.baseline == nil)              // still undefined while winning
    }

    // MARK: b_est and the seeded core

    /// §10.4's table, row by row. `core = (b_est − 4.5) + ln 4`, i.e. band centre plus the
    /// serving offset — never the rounded 3.114 the comment prints.
    @Test("The seeded core reproduces §10.4's table",
          arguments: [(Band.literal,   3, 1, -2.114), (Band.pair,      1, 1, -2.114),
                      (Band.relational, 2, 3, -0.114), (Band.relational, 1, 2, -1.114),
                      (Band.guarded,   2, 5,  1.886), (Band.guarded,   1, 4,  0.886),
                      (Band.systemic,  2, 7,  3.886), (Band.systemic,  1, 6,  2.886)])
    func seededCore(_ lostAt: Band, _ marks: Int, _ expectedBEst: Int, _ expectedCore: Double) {
        #expect(Calibration.estimatedBand(lostAt: lostAt, marks: marks) == expectedBEst)
        #expect(isApproximatelyEqual(Calibration.seededBaseline(estimatedBand: expectedBEst),
                                     expectedCore, absoluteTolerance: 0.001))
    }

    @Test("b_est never goes below band 1")
    func bEstFloorsAtOne() {
        #expect(Calibration.estimatedBand(lostAt: .literal, marks: 0) == 1)
        #expect(Calibration.estimatedBand(lostAt: .literal, marks: 3) == 1)
        #expect(Calibration.estimatedBand(lostAt: .pair, marks: 0) == 1)
    }

    @Test("Winning all five rungs seeds band 8 permanently")
    func winningEverythingSeedsBandEight() throws {
        var state = ServingState.dayOne
        var ability = Ability.undefined
        for round in 1...5 {
            state.calibrationRound = round
            let after = Calibration.afterRound(won: true, marks: 3, state: state, ability: ability)
            state = after.state
            ability = after.ability
        }
        #expect(state.calibrationRound == nil)
        #expect(isApproximatelyEqual(try #require(ability.baseline), 4.886, absoluteTolerance: 0.001))
    }

    @Test("The first loss ends calibration and seeds the baseline")
    func firstLossEndsIt() throws {
        var state = ServingState.dayOne
        state.calibrationRound = 3                          // serving band 4
        let after = Calibration.afterRound(won: false, marks: 2, state: state, ability: .undefined)
        #expect(after.state.calibrationRound == nil)
        #expect(isApproximatelyEqual(try #require(after.ability.baseline), -0.114,
                                     absoluteTolerance: 0.001))
        for mode in Mode.allCases { #expect(after.ability.scoredRounds[mode] == 0) }
    }

    /// §10.4: "`n[mode] = 0` — K restarts at 0.900". The seeding error is up to ±1 band and
    /// K = 0.900 for the next four rounds is what removes it (H2).
    @Test("K restarts at its ceiling after calibration")
    func learningRateRestarts() throws {
        let after = Calibration.afterRound(won: false, marks: 2,
                                           state: { var s = ServingState.dayOne
                                                    s.calibrationRound = 4; return s }(),
                                           ability: .undefined)
        #expect(isApproximatelyEqual(
            AbilityEstimator.learningRate(scoredRounds: after.ability.scoredRounds[.probe]),
            AbilityEstimator.learningRateCeiling, absoluteTolerance: 1e-12))
    }

    // MARK: the full palette — §10.4's second Decision

    /// The whole argument in one test. A player who wins rounds 1 and 2 has lifetime max band 2,
    /// so their ordinary ceiling is band 3: two Ramps and a coupler, NO Bridge. Round 3 is band 4
    /// RELATIONAL and cannot be stated without one.
    @Test("Without the grant, round 3 is unwinnable by construction")
    func theGrantIsNotDecorative() {
        let earnedCeiling = PaletteCeiling.opening.raised(toServe: .pair)
        #expect(earnedCeiling.isSufficient(for: .relational) == false)

        let granted = earnedCeiling.grantingFullPalette()
        #expect(granted.isSufficient(for: .relational))
        #expect(granted.isSufficient(for: .guarded))
        #expect(granted.isSufficient(for: .systemic))
    }

    @Test("Every calibration round is served with the full palette", arguments: Array(1...5))
    func calibrationRoundsGrantTheFullPalette(_ round: Int) {
        var state = ServingState.dayOne
        state.calibrationRound = round
        let served = Calibration.serving(round: round, mode: .probe, roundSeed: 42, state: state)
        #expect(served.state.palette.isFullPaletteGranted)
        #expect(served.state.palette.unlocked == Set(RuleTileClass.allCases))
        #expect(served.state.palette.isSufficient(for: served.serving.band))
    }

    @Test("The grant reverts the moment calibration ends and takes nothing lifetime with it")
    func grantReverts() {
        var state = ServingState.dayOne
        state.calibrationRound = 5
        let served = Calibration.serving(round: 5, mode: .probe, roundSeed: 7, state: state)
        let after = Calibration.afterRound(won: false, marks: 1,
                                           state: served.state, ability: .undefined)
        #expect(after.state.palette.isFullPaletteGranted == false)
        // Lifetime maximum band served is real progress and survives the revert (§10.4).
        #expect(after.state.palette.maxBandEverServed == .systemic)
    }

    // MARK: H20, at serve time

    /// §10.4: "the guarantee is enforced at serve time, not at generation time" — G10 proves a law
    /// is buildable on the FULL palette and says nothing about the palette this player holds.
    @Test("Palette sufficiency holds for every serving, calibration or not", arguments: Mode.allCases)
    func paletteSufficiencyAtServeTime(_ mode: Mode) {
        var state = ServingState.dayOneCalibrated
        for i in 0..<400 {
            let ability = Ability.seeded(baseline: Double(i % 120) / 10.0 - 6.0)
            let serving = ServingPolicy.next(mode: mode, ability: ability,
                                             state: state, roundSeed: UInt64(i) &+ 1)
            state = state.recordingServe(serving)
            #expect(state.palette.isSufficient(for: serving.band),
                    "band \(serving.band) served with palette \(state.palette.unlocked)")
        }
    }

    // MARK: modes 2–4

    /// §10.4: "Modes 2–4 never re-calibrate. A player opening DRIFT for the first time is served
    /// at core + 0 + modeBias — that is the entire point of the offset decomposition."
    @Test("Only PROBE calibrates", arguments: [Mode.drift, .echo, .sieve])
    func otherModesNeverCalibrate(_ mode: Mode) {
        var state = ServingState.dayOne          // calibrationRound == 1
        state.calibrationRound = nil             // PROBE finished calibrating
        let serving = ServingPolicy.next(mode: mode, ability: Ability.seeded(baseline: 1.0),
                                         state: state, roundSeed: 3)
        #expect(serving.trace.targetOrigin != .calibrationRung)
    }

    // MARK: the reset

    @Test("Resetting the ladder rearms calibration at round 1 with an undefined baseline")
    func resetRearmsCalibration() {
        var lived = LadderState.dayOne
        lived.ability.setBaseline(3.0)
        lived.serving.calibrationRound = nil
        lived.serving.palette = PaletteCeiling.opening.raised(toServe: .systemic)

        let reset = lived.resettingTheLadder()
        #expect(reset.serving.calibrationRound == 1)
        #expect(reset.ability.baseline == nil)
        #expect(reset.serving.palette == PaletteCeiling.opening)
    }

    /// §10.4's closing argument: zeroing `core` to 0.0 would serve band 3 immediately and skip
    /// calibration entirely. Assert the thing that must never be true.
    @Test("A reset player is never served band 3 on their first round back")
    func resetDoesNotSkipCalibration() {
        let reset = LadderState.dayOne
        let serving = ServingPolicy.next(mode: .probe, ability: reset.ability,
                                         state: reset.serving, roundSeed: 0xDEAD_BEEF)
        #expect(serving.band == .literal)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter CalibrationTests`

It must fail on missing symbols — `Calibration`, `ServingPolicy.next(…)`,
`Serving.TargetOrigin.calibrationRung` — not on a malformed expectation.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** In particular, check that nothing outside `ServingPolicy.next`
branches on `calibrationRound`.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/Calibration.swift` |
| modify | `HunchCore/Sources/Ladder/ServingPolicy.swift` — `next(mode:ability:state:roundSeed:)`, the one dispatcher |
| modify | `HunchCore/Sources/Ladder/Serving.swift` — a fourth `TargetOrigin` case, `.calibrationRung` |
| create | `HunchCore/Tests/LadderTests/CalibrationTests.swift` |
| modify | `tests.json` — `ladder.gallop`, `ladder.seeded-core`, `ladder.calibration-palette`, `palette.sufficiency-H20` (E09·T04 opened this row cross-referenced to E11; close it here) |

## Implementation notes

### The dispatcher, and why the branch is not at the call site

```swift
extension ServingPolicy {
    /// The one entry point the app layer calls. §10.4's galloping ladder and §10.3's thirteen
    /// steps are two different serving rules for the same moment, and a call site that has to
    /// remember which one applies is a call site that will forget on the fourth mode.
    public static func next(mode: Mode, ability: Ability,
                            state: ServingState, roundSeed: UInt64) -> Serving {
        if mode == .probe, let round = state.calibrationRound {
            return Calibration.serving(round: round, mode: mode,
                                       roundSeed: roundSeed, state: state).serving
        }
        return serve(mode: mode, ability: ability, state: state, roundSeed: roundSeed)
    }
}
```

`mode == .probe` is load-bearing: §10.4 says modes 2–4 never re-calibrate, so a player who opens DRIFT
during their own PROBE calibration is served at `core + offset + modeBias` — which requires a defined
baseline. That case is real (the Frame's mode rack unlocks on archive evidence, and a band-≥3 page can
be inscribed during calibration round 3, 4 or 5). Handle it: if `ability.baseline == nil` and the mode
is not PROBE, the mode key is **barred** — E17·T04 owns the gate, and the reason it can be barred is
§9.10's archive-evidence rule, which no calibration round satisfies until it inscribes. Add a
`precondition` with that citation, and a test in T06 that the app layer never reaches it.

### `Calibration`

```swift
/// §10.4's cold start. Pure over `(round, won, marks, state, ability)`; no clock, no RNG beyond
/// the round seed it forwards, no store.
public enum Calibration {
    /// §10.4's five rungs. A `[Band]`, not a stride: 1·2·4·6·8 is not arithmetic.
    public static let rungs: [Band] = [.literal, .pair, .relational, .guarded, .systemic]

    public static func band(forRound round: Int) -> Band       // clamped into rungs' indices

    /// §10.4: "the probe economy breaks the tie".
    public static func estimatedBand(lostAt band: Band, marks: Int) -> Int

    /// §10.4: `(Double(b_est) − 4.5) + ln 4` — band centre in logits plus the serving offset.
    /// Never the printed rounding `b_est − 3.114`.
    public static func seededBaseline(estimatedBand: Int) -> Double {
        (Double(estimatedBand) - 4.5) + Rasch.servingOffset
    }

    /// The serving for a calibration round, with the palette granted for its duration.
    public static func serving(round: Int, mode: Mode, roundSeed: UInt64,
                               state: ServingState) -> (serving: Serving, state: ServingState)

    /// The state transition after a calibration round settles.
    public static func afterRound(won: Bool, marks: Int, state: ServingState,
                                  ability: Ability) -> (state: ServingState, ability: Ability)
}
```

Four details:

1. **`seededBaseline` uses `Rasch.servingOffset`, not `1.3863` and not `3.114`.** E06·T02 already
   ships the offset and asserts `σ(offset) == targetSuccessRate`. Writing the rounded constant here
   would make the seeded core depend on a transcription rather than on the model, and `seededCore`'s
   0.001 tolerance is exactly wide enough to hide the difference — which is why the *implementation*
   must be the unrounded form even though the *test* quotes the table.
2. **`marks` is the previous (winning) round's marks**, not this round's — §10.4 says so explicitly,
   and this round was a loss so it has none. `afterRound`'s parameter is therefore
   `marks:` documented as *"Seal marks earned on the previous, winning round; 0 for a loss at
   round 1"*. Getting this backwards silently shifts every seeded core by one band.
3. **A loss at round 1 is `b_est = 1`.** `max(1, b − 2)` with `b = 1` and no previous round: the
   `marks` argument is 0, the `>= 2` branch is not taken, `max(1, -1) = 1`. §10.4's table says the
   same. No special case needed — but assert it (`bEstFloorsAtOne`).
4. **Winning round 5 gives `b_est = 8`, not `7`.** §10.4's last table row is *"never — won all 5 → 8 →
   4.886"*, which is not produced by the `b_est` formula (there was no loss). It is a separate branch
   in `afterRound`, and it is the one place where the rung, not the rung minus something, becomes the
   estimate. `winningEverythingSeedsBandEight` is its test.

### The palette grant

`Calibration.serving` returns a **new `ServingState`** as well as the `Serving`, because granting the
palette is a state change and §10.4 requires it to be in force *for the duration of that round only*.
The sequence is:

```swift
var granted = state
granted.palette = state.palette.grantingFullPalette()        // E09·T04
let serving = /* the rung, at that band's achievable centre */
granted = granted.recordingServe(serving)                    // raises maxBandEverServed — T03
return (serving, granted)
```

and `afterRound` calls `palette.reverted()`. `grantReverts` asserts the two halves that matter: the
grant is gone, and `maxBandEverServed` is **not** — a calibration round that served band 8 is a band 8
the player was really served, and §10.4 derives the ceiling from the highest band ever *served*.

That is also the whole of **H20** for calibration rounds: T12 asserts it over the Level-B matrix, and
`paletteSufficiencyAtServeTime` here asserts it over 400 servings per mode with the ordinary policy.
Both call `isSufficient(for:)` after `recordingServe`, which is what makes "serve time" a place in the
code rather than a phrase.

### `targetDelta` for a calibration round

The rung fixes the band; the position inside it is not specified by §10.4. Use
`band.achievableDifficultyRange`'s midpoint — i.e. `band.centre`, which E06·T02 already defines as the
midpoint of the *achievable* range for exactly this class of caller. Set
`trace.targetOrigin = .calibrationRung` so H19's fallback attribution and H9's unforced-change
statistic can both exclude calibration rounds cleanly. Add the case to `Serving.TargetOrigin` and fix
the two `switch`es that now fail to compile — which is the point of having made them exhaustive.

### Why it does not feel like a test

§10.4's last paragraph is a design constraint with a mechanical consequence, and it belongs in the doc
comment: *no* assessment screen, *no* progress bar, *no* "finding your level" copy — a calibration
round is an ordinary round in every visible respect. Concretely, that means this task adds **nothing**
to `Modules/`: no view reads `calibrationRound`, and T09's hygiene check 13 greps for exactly that.
A calibration loss also fractures nothing, because nothing was inscribed — E09·T11's page minting is
already conditional on `inscribed`, so this is an assertion to add to T06's wiring test rather than
new behaviour.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter CalibrationTests` is green, all thirteen tests.
- [ ] All eight rows of §10.4's seeded-core table reproduce within 0.001, computed from `(b_est − 4.5) + Rasch.servingOffset`.
- [ ] `grep -n '3\.114\|1\.3863' HunchCore/Sources/Ladder/Calibration.swift` returns nothing.
- [ ] `Calibration.rungs == [.literal, .pair, .relational, .guarded, .systemic]`, asserted as a literal comparison.
- [ ] For all five calibration rounds, `palette.unlocked == Set(RuleTileClass.allCases)` and `isSufficient(for:)` holds at the served band.
- [ ] `PaletteCeiling.opening.raised(toServe: .pair).isSufficient(for: .relational)` is **false** — the test that says the grant is load-bearing.
- [ ] After calibration ends, `isFullPaletteGranted == false` and `maxBandEverServed` is unchanged.
- [ ] Over 400 servings × four modes, `state.recordingServe(serving).palette.isSufficient(for: serving.band)` holds 100 % of the time.
- [ ] A reset player's first round is band 1, never band 3.
- [ ] `grep -rn 'calibrationRound' Modules/Sources` returns nothing.
- [ ] `tests.json` carries the three calibration entries and closes `palette.sufficiency-H20`'s E11 cross-reference.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T05: the galloping cold start, the seeded core and the calibration palette grant"`

## Out of scope

- `PaletteCeiling`, `RuleTileClass.required(for:)` and the locked-stamp drawing — **E09·T04**.
- The Anomaly's identical grant and its θ-isolation — **E16·T03**.
- The fixed opening round (band 1, seed `0x48554E4348`, `shape ∈ {triangle}`) and its 13 beats, which is what calibration round 1 *is* on a fresh install — **E10·T05/T06**. This task must not re-specify it.
- `OnboardingLedger` and the elastic cap — **E10·T07**.
- Who calls `afterRound`, and the rule that an unscored outcome calls neither it nor the estimator — **T06**.
- The mode gate that bars DRIFT/ECHO/SIEVE before their archive evidence exists — **E17·T04**.
- H2's convergence-speed measurement — **T12**.
