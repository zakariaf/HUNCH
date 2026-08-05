# T03 — The 13-step serving policy

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | §14.1 Serving policy |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that the policy is a caseless namespace returning a `Serving` value rather than a mutating method on `ServingState` (the serve-time mutations are one named function, `W29`), that the thirteen steps are one function and not thirteen (a pipeline of thirteen small functions makes the *order* — which is the whole specification — invisible), and that `targetδ`/`δ_served` are spelled `targetDelta`/`servedDelta` (`08 §3`). |
| `hunch-swift-testing` | The step-11 test is a seeded corpus over the generator: it must assert the *absence* of an anchor fallback, which means calling `generateReporting` and reading `usedAnchor`, and it must name the reproducing seed in every failure (`06 T53`, the `T21` deviation `08 §7.4` already pays for). |

## Objective

`ServingPolicy.serve(mode:ability:state:roundSeed:)` executes §10.3's thirteen steps in their exact
order and returns a `Serving` carrying a `band` in 1…8, a `targetDelta` in difficulty units, the
`servedDelta` in logits that the estimator will consume, and a per-step trace the harness invariants
read. At the end of this task the specific failure §10.3's Decision is written to prevent — a
`targetδ` derived against the pre-guard band, whose G8 window does not intersect the new band's, so
all 200 generator attempts fail and the anchor ships — is a red test rather than a silent degradation.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.3 | The thirteen-step table verbatim; the step-11 Decision and its G8-intersection argument; DRIFT's −0.50 bias and its band-3 floor; the clamp-binding freeze; what jitter is and is not for; the measured band-distribution table |
| `GAME_DESIGN.md` | §10.1 | Band width is exactly 1.000 logit; `ServingState`'s fields and their ranges |
| `GAME_DESIGN.md` | §10.5 | Steps 7–12 hand each mode a band and a `targetδ` in **difficulty units, never a logit**; SIEVE's law-band cap of 6 against its effective band of 7; `lastFamily` for SIEVE records `Family(lawBand)` |
| `GAME_DESIGN.md` | §5.1, §5.2 | `δ_logit = 8·difficulty − 4`; the eight δ ranges |
| `GAME_DESIGN.md` | §5.3 | G8's two clauses — band membership **and** within 0.02 of `targetδ` — and the 200-attempt bound with its anchor fallback |
| `GAME_DESIGN.md` | §7.2, §7.7 | DRIFT is bands 3–8 and `par_DRIFT` has no row below band 3 |
| `GAME_DESIGN.md` | §9.7 | SIEVE's `δ ≤ 2.99` ceiling in logits and `δ_SIEVE ≤ 0.874` in difficulty units |
| `E06·T02`'s ruling | `DECISIONS.md` | `Band.achievableDifficultyRange` — a `targetδ` outside it burns all 200 attempts and drives H19 to 1.00 at band 1 |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | Exhaustive `switch` with no `default:` on `Mode` and on the `targetδ` origin |

Do not restate a bias, a clamp bound, a jitter width or a band range in prose. Cite §10.3.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/ServingPolicyTests.swift`:

```swift
import Testing
import Glyphs                    // Mode
import Laws                      // LawIndex
import LawGeneration             // Band, Rasch, generateReporting
@testable import Ladder
import HunchTestSupport          // Corpora, isApproximatelyEqual

@Suite("The 13-step serving policy — §10.3", .tags(.unit, .presubmission))
struct ServingPolicyTests {

    // MARK: the contract steps 7–12 publish

    /// §10.5's sentence, as a test: `floor(logit/0.125)+1` on a logit of −2 returns band −15,
    /// and this is the assertion that stops that value ever leaving this function.
    @Test("targetDelta is always in difficulty units and band is always 1…8",
          arguments: Mode.allCases)
    func outputsAreAlwaysInRange(_ mode: Mode) {
        for i in 0..<2_000 {
            let ability = Ability.seeded(baseline: Double(i % 240) / 20.0 - 6.0)
            let serving = ServingPolicy.serve(mode: mode, ability: ability,
                                              state: .dayOne, roundSeed: UInt64(i) &* 0x9E37_79B9)
            #expect((0.0..<1.0).contains(serving.targetDelta))
            #expect(Band.allCases.contains(serving.band))
            #expect(serving.band.difficultyRange.contains(serving.targetDelta))
            #expect(isApproximatelyEqual(serving.servedDelta,
                                         Rasch.logit(ofDifficulty: serving.targetDelta),
                                         absoluteTolerance: 1e-12))
        }
    }

    // MARK: step order, one step at a time

    @Test("Step 3: only DRIFT carries a mode bias", arguments: Mode.allCases)
    func modeBiasIsDriftOnly(_ mode: Mode) {
        let bias = ServingPolicy.modeBias(mode)
        #expect(mode == .drift ? bias < 0 : bias == 0)
    }

    @Test("Step 5: jitter is deterministic in the round seed and never leaves its interval")
    func jitterIsDeterministicAndBounded() {
        for i in 0..<10_000 {
            let seed = UInt64(i) &* 0xD1B5_4A32_D192_ED03
            let a = ServingPolicy.jitter(roundSeed: seed, mode: .probe)
            let b = ServingPolicy.jitter(roundSeed: seed, mode: .probe)
            #expect(a == b)                                        // bit-identical, not approximate
            #expect(ServingPolicy.jitterRange.contains(a))
        }
        // Two different modes on the same round seed must not draw the same jitter.
        #expect(ServingPolicy.jitter(roundSeed: 42, mode: .probe)
             != ServingPolicy.jitter(roundSeed: 42, mode: .sieve))
    }

    /// §10.3's own paragraph: jitter cannot cross a 1.000-logit band from centre, and the
    /// document says an earlier draft wrongly claimed it could. Assert the true statement.
    @Test("Step 5: jitter alone cannot move the band from a band centre")
    func jitterCannotCrossABand() {
        for i in 0..<5_000 {
            let ability = Ability.seeded(baseline: 0.0)
            let centred = ServingPolicy.serve(mode: .probe, ability: ability, state: .dayOneCalibrated,
                                              roundSeed: UInt64(i) &* 0x2545_F491_4F6C_DD1D)
            #expect(centred.trace.bandBeforeJitter == centred.trace.bandAfterJitter)
        }
    }

    @Test("Step 6: SIEVE gets the extra ceiling and every mode gets the shared clamp")
    func clampBounds() {
        let strong = Ability.seeded(baseline: 6.0)
        let sieve = ServingPolicy.serve(mode: .sieve, ability: strong, state: .dayOneCalibrated,
                                        roundSeed: 1)
        #expect(sieve.trace.deltaAfterClamp <= ServingPolicy.sieveDeltaCeiling)
        let probe = ServingPolicy.serve(mode: .probe, ability: strong, state: .dayOneCalibrated,
                                        roundSeed: 1)
        #expect(ServingPolicy.deltaClamp.contains(probe.trace.deltaAfterClamp))
    }

    @Test("Step 8: every mode's band clamp, at both ends", arguments: Mode.allCases)
    func modeBandClamps(_ mode: Mode) {
        let floorPlayer = Ability.seeded(baseline: -6.0)
        let ceilingPlayer = Ability.seeded(baseline: 6.0)
        let low = ServingPolicy.serve(mode: mode, ability: floorPlayer,
                                      state: .dayOneCalibrated, roundSeed: 7)
        let high = ServingPolicy.serve(mode: mode, ability: ceilingPlayer,
                                       state: .dayOneCalibrated, roundSeed: 7)
        #expect(low.band == ServingPolicy.bandRange(for: mode).lowerBound)
        #expect(high.band == ServingPolicy.bandRange(for: mode).upperBound)
    }

    /// §10.3's DRIFT paragraph names the consequence outright: a calibrated beginner at
    /// core = −2.114 with relief 2.00 would otherwise call the generator at a band with no
    /// `par_DRIFT` row at all.
    @Test("Step 8: DRIFT never serves below band 3, even at the floor with full relief")
    func driftFloorsAtBandThree() {
        var state = ServingState.dayOneCalibrated
        state.relief = 2.0
        let beginner = Ability.seeded(baseline: -2.114)
        for seed in UInt64(0)..<500 {
            let serving = ServingPolicy.serve(mode: .drift, ability: beginner,
                                              state: state, roundSeed: seed)
            #expect(serving.band >= .exclusive)
        }
    }

    @Test("Step 9: after a loss, the same band as last round is moved one down")
    func familyRepeatGuardMovesDown() {
        var state = ServingState.dayOneCalibrated
        state.lastBand = .contextual
        state.consecutiveLosses = 1
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 1.35),
                                          state: state, roundSeed: 0xBADD_5EED)
        #expect(serving.trace.bandBeforeRepeatGuard == .contextual)
        #expect(serving.band == .relational)
        #expect(serving.trace.targetOrigin == .bandCentre)
    }

    @Test("Step 9: at the mode's floor the guard moves UP, not down")
    func familyRepeatGuardMovesUpAtTheFloor() {
        var state = ServingState.dayOneCalibrated
        state.lastBand = .literal
        state.consecutiveLosses = 1
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: -4.0),
                                          state: state, roundSeed: 3)
        #expect(serving.band == .pair)
    }

    @Test("Step 9: the guard is inert after a win, however matched the band")
    func familyRepeatGuardIsLossOnly() {
        var state = ServingState.dayOneCalibrated
        state.lastBand = .contextual
        state.consecutiveLosses = 0
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 1.35),
                                          state: state, roundSeed: 0xBADD_5EED)
        #expect(serving.trace.bandAfterRepeatGuard == serving.trace.bandBeforeRepeatGuard)
    }

    @Test("Step 10: three clamped rounds force one band down at the upper near edge")
    func ceilingRotationFires() {
        var state = ServingState.dayOneCalibrated
        state.ceilingClampRun = 3
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 6.0),
                                          state: state, roundSeed: 11)
        #expect(serving.band == .composite)
        #expect(serving.trace.targetOrigin == .upperNearEdge)
        #expect(isApproximatelyEqual(serving.targetDelta,
                                     Band.composite.difficultyRange.upperBound
                                        - ServingPolicy.upperNearEdgeInset,
                                     absoluteTolerance: 1e-12))
    }

    @Test("Step 10: two clamped rounds are not enough")
    func ceilingRotationNeedsThree() {
        var state = ServingState.dayOneCalibrated
        state.ceilingClampRun = 2
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 6.0),
                                          state: state, roundSeed: 11)
        #expect(serving.band == .systemic)
    }

    // MARK: step 11 — the Decision this whole task exists for

    /// §10.3's Decision, reproduced literally. With `targetδ = 0.56` and a 5 → 4 shift, G8's
    /// band-membership window `[0.375, 0.500)` and its ±0.02 proximity window `[0.54, 0.58]`
    /// do not intersect; all 200 attempts fail and the anchor ships, silently degrading the
    /// family-repeat guard into "serve the same fixed law every time you lose twice".
    @Test("Step 11: a guard-moved band re-derives targetδ into the NEW band")
    func stepElevenReDerivesAfterTheGuard() throws {
        var state = ServingState.dayOneCalibrated
        state.lastBand = .contextual
        state.consecutiveLosses = 1
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 1.35),
                                          state: state, roundSeed: 0xBADD_5EED)

        #expect(serving.band == .relational)
        #expect(Band.relational.difficultyRange.contains(serving.targetDelta))
        #expect(serving.targetDelta < 0.50)                     // NOT the pre-guard 0.56
        #expect(isApproximatelyEqual(serving.targetDelta, Band.relational.centre,
                                     absoluteTolerance: Band.width / 2))
    }

    /// The consequence, measured where it actually bites: the generator must not fall back.
    @Test("Step 11: a guard-moved serving never forces the generator onto its anchor")
    func guardMovedServingsDoNotFallBack() throws {
        let index = Corpora.index
        var fallbacks = 0
        var served = 0
        for i in 0..<400 {
            var state = ServingState.dayOneCalibrated
            state.consecutiveLosses = 1
            state.lastBand = Band.allCases[i % 8]
            let ability = Ability.seeded(baseline: Double(i % 60) / 10.0 - 3.0)
            let serving = ServingPolicy.serve(mode: .probe, ability: ability, state: state,
                                              roundSeed: Corpora.seed(band: Band.allCases[i % 8],
                                                                      index: i))
            guard serving.trace.targetOrigin != .withinBand else { continue }
            served += 1
            let report = generateReporting(seed: serving.seed, band: serving.band,
                                           targetDelta: serving.targetDelta, mode: .probe,
                                           avoid: [], in: index)
            if report.usedAnchor { fallbacks += 1 }
        }
        #expect(served > 0)
        #expect(Double(fallbacks) / Double(served) < 0.02,
                "\(fallbacks)/\(served) guard-moved servings fell back to the anchor")
    }

    @Test("Step 11: an untouched band keeps its within-band position, clamped to the achievable range")
    func stepElevenKeepsWithinBandPosition() {
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 0.9),
                                          state: .dayOneCalibrated, roundSeed: 0x1234_5678)
        if serving.trace.targetOrigin == .withinBand {
            #expect(serving.band.achievableDifficultyRange.contains(serving.targetDelta))
        }
    }

    /// E06·T02's ruling, consumed. Band 1's forty atoms take three distinct difficulties;
    /// asking for the nominal centre burns 200 attempts and drives H19 to 1.00 at band 1.
    @Test("Step 11: targetδ is always inside the band's ACHIEVABLE range", arguments: Band.allCases)
    func targetDeltaIsAchievable(_ band: Band) {
        for i in 0..<500 {
            let ability = Ability.seeded(baseline: Double(band.rawValue) - 4.5 + Rasch.servingOffset)
            let serving = ServingPolicy.serve(mode: .probe, ability: ability,
                                              state: .dayOneCalibrated, roundSeed: UInt64(i) &+ 1)
            #expect(serving.band.achievableDifficultyRange.contains(serving.targetDelta))
        }
    }

    // MARK: step 12

    @Test("Step 12: servedDelta is derived from targetδ, never from step 6's δ")
    func servedDeltaComesFromStepEleven() {
        var state = ServingState.dayOneCalibrated
        state.lastBand = .guarded
        state.consecutiveLosses = 1
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 2.4),
                                          state: state, roundSeed: 99)
        #expect(isApproximatelyEqual(serving.servedDelta,
                                     Rasch.logit(ofDifficulty: serving.targetDelta),
                                     absoluteTolerance: 1e-12))
        #expect(abs(serving.servedDelta - serving.trace.deltaAfterClamp) > 1e-9)
    }

    // MARK: determinism and purity

    @Test("The policy is a pure function of its four arguments")
    func isPure() {
        let a = ServingPolicy.serve(mode: .echo, ability: Ability.seeded(baseline: 0.4),
                                    state: .dayOneCalibrated, roundSeed: 0xC0FFEE)
        let b = ServingPolicy.serve(mode: .echo, ability: Ability.seeded(baseline: 0.4),
                                    state: .dayOneCalibrated, roundSeed: 0xC0FFEE)
        #expect(a == b)
    }

    // MARK: serve-time state, in one named place

    @Test("recordingServe updates the clamp run, the last band and the palette — and nothing else")
    func serveTimeMutationsAreOneFunction() {
        let state = ServingState.dayOneCalibrated
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 6.0),
                                          state: state, roundSeed: 5)
        let after = state.recordingServe(serving)

        #expect(after.lastBand == serving.band)
        #expect(after.ceilingClampRun == 1)                 // clamped at maxBand this round
        #expect(after.palette.maxBandEverServed >= serving.band)
        #expect(after.reach == state.reach)                 // outcome-time only — T04
        #expect(after.relief == state.relief)
        #expect(after.winStreak == state.winStreak)
        #expect(after.consecutiveLosses == state.consecutiveLosses)
    }

    @Test("An unclamped round resets the ceiling clamp run to zero")
    func clampRunResets() {
        var state = ServingState.dayOneCalibrated
        state.ceilingClampRun = 2
        let serving = ServingPolicy.serve(mode: .probe, ability: Ability.seeded(baseline: 0.0),
                                          state: state, roundSeed: 5)
        #expect(state.recordingServe(serving).ceilingClampRun == 0)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ServingPolicyTests`

It must fail on missing symbols — `ServingPolicy`, `Serving`, `Serving.Trace`,
`ServingState.dayOneCalibrated`, `ServingState.recordingServe(_:)` — not on a malformed expectation.
`stepElevenReDerivesAfterTheGuard` passing before the implementation exists would mean the test is
asserting nothing.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** Resist splitting `serve` into thirteen functions. See below.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/ServingPolicy.swift` |
| create | `HunchCore/Sources/Ladder/Serving.swift` (with `Serving.Trace` and `Serving.TargetOrigin` nested) |
| modify | `HunchCore/Sources/Ladder/ServingState.swift` — `recordingServe(_:)` and `dayOneCalibrated` |
| create | `HunchCore/Tests/LadderTests/ServingPolicyTests.swift` |
| modify | `tests.json` — `ladder.serving-policy-order`, `ladder.step-11-rederivation`, `ladder.units-are-difficulty` |

## Implementation notes

### `Serving` — what leaves this function

```swift
/// The output of §10.3's steps 1–12. Step 13 dispatches on it and is not this type's business.
public struct Serving: Hashable, Sendable {
    public let mode: Mode
    /// 1…8, already clamped to the mode's range and moved by the guard and the rotation.
    public let band: Band
    /// **Difficulty units**, `[0.000, 1.000)`, inside `band.achievableDifficultyRange`.
    /// §8.6 and §9.7 consume this; neither ever sees a logit (§10.5).
    public let targetDelta: Double
    /// **Logits.** §10.3 step 12's `δ_served` — what `AbilityEstimator` consumes, and nothing else.
    public let servedDelta: Double
    /// The seed the caller handed in, carried so the round record and the generator agree.
    public let seed: UInt64
    /// Whether this serving came from a frozen sticky target (T06 sets it; the policy reads it).
    public let isSticky: Bool
    public let trace: Trace
}
```

Two fields with the same Greek letter in the design and different units is a trap, so make the trap
loud: the doc comments above say **difficulty units** and **logits** in bold, the acceptance criteria
include a grep for `targetDelta` being passed to `servedDelta:`, and `outputsAreAlwaysInRange` asserts
the two are related by exactly `Rasch.logit(ofDifficulty:)`. A wrapper type (`struct Logit`) was
considered and rejected as heavier than the bug it prevents — record that in the commit message, not
in `DECISIONS.md`, because it is a style call and not a design one.

### `Serving.Trace` — the harness's window into the policy

H9 needs *"zero band changes on rounds where `reach`, `relief` and the ceiling rotation are all
inert"*, H19 needs the anchor-fallback rate attributed per band, and H21 needs the modal family share.
None of that is derivable from `Serving` alone, and none of it should be recomputed by the test from
the same inputs — that would be asserting the implementation against itself.

```swift
extension Serving {
    /// Per-step record. Present in release builds: it is ~80 bytes on a value that is created
    /// once per round, and the alternative is a `#if DEBUG` divergence between what ships and
    /// what the harness measures.
    public struct Trace: Hashable, Sendable {
        public let ability: Double              // step 1
        public let deltaAfterModeBias: Double   // step 3
        public let reach: Double, relief: Double, centring: Double   // step 4's three parts
        public let jitter: Double               // step 5
        public let deltaAfterClamp: Double      // step 6
        public let bandBeforeJitter: Band       // for the "jitter cannot cross a band" assertion
        public let bandAfterJitter: Band        // == quantised band, step 7
        public let bandAfterModeClamp: Band     // step 8
        public let bandBeforeRepeatGuard: Band
        public let bandAfterRepeatGuard: Band   // step 9
        public let bandAfterCeilingRotation: Band  // step 10
        public let targetOrigin: TargetOrigin   // step 11's three cases
        public let didClampAtModeCeiling: Bool  // feeds `ceilingClampRun`
        public let didClampAtModeFloor: Bool    // feeds T04's relief freeze
    }

    /// §10.3 step 11's three cases, as data — because "which of the three fired" is exactly what
    /// H9 and the step-11 test need and is not recoverable from the number.
    public enum TargetOrigin: Hashable, Sendable {
        case withinBand         // steps 8–10 all left the band untouched
        case bandCentre         // a clamp or the repeat guard moved it
        case upperNearEdge      // the ceiling rotation moved it
    }
}
```

**`bandBeforeJitter`** is computed by quantising the step-4 δ (before jitter) with step 7's formula.
It exists only for `jitterCannotCrossABand`; it is not a step of the policy and must be documented as
a measurement.

### The thirteen steps stay in one function

`03 W`'s general advice is to decompose. Do not, here. The specification **is** the order, and the
document's own Decision is about a step happening after another step. Thirteen small private
functions called from a `serve` that reads as a list is fine; thirteen *public* pipeline stages that
some future caller can invoke out of order is not. Concretely: `serve` is one function with a `// 1.`
… `// 12.` comment on each line, each comment naming the step from §10.3's table and nothing else,
and the only helpers hoisted out are the ones the tests call by name (`modeBias`, `jitter`,
`bandRange(for:)`).

```swift
public enum ServingPolicy {

    public static let deltaClamp: ClosedRange<Double>      // §10.3 step 6
    public static let sieveDeltaCeiling: Double            // §10.3 step 6, §9.7
    public static let jitterRange: ClosedRange<Double>     // §10.3 step 5
    public static let upperNearEdgeInset: Double           // §10.3 step 11's third case
    public static let ceilingRotationRun: Int              // §10.3 step 10

    public static func modeBias(_ mode: Mode) -> Double            // switch, no default:
    public static func bandRange(for mode: Mode) -> ClosedRange<Band>   // switch, no default:
    public static func jitter(roundSeed: UInt64, mode: Mode) -> Double

    /// §10.3's steps 1–12, in the order the table prints them.
    /// - Precondition: `ability.value(for: mode) != nil`. An uncalibrated player is T05's
    ///   `Calibration.serve`, dispatched by `ServingPolicy.next(…)`, which T05 adds.
    public static func serve(mode: Mode, ability: Ability,
                             state: ServingState, roundSeed: UInt64) -> Serving
}
```

### Step by step, with the parts that bite

1. **`θ = baseline + offset(mode)`** — `ability.value(for: mode)`. T05 adds the calibration branch in
   front of this; here it is a precondition with a message naming T05.
2. **`δ = θ − Rasch.servingOffset`** — E06·T02 already ships `servingOffset` and asserts
   `σ(servingOffset) == targetSuccessRate`. Do not write `1.3863`.
3. **`δ += modeBias(mode)`** — a `switch` over `Mode` with no `default:`, so adding a fifth mode is a
   compile error here rather than a silent zero.
4. **`δ += reach − relief − π₀`** — reads `state.reach`, `state.relief` and
   `Pressure.centringConstant`. **T04 owns the constant and the ladders**; this task consumes them. If
   `Pressure` does not exist yet, create the file with just `centringConstant` and its §10.3 citation
   and let T04 fill it in — do not inline `0.44` here and delete it later.
5. **Jitter.** Deterministic from `roundSeed`, and the RNG must never escape (`08 §4`):
   ```swift
   public static func jitter(roundSeed: UInt64, mode: Mode) -> Double {
       var rng = SplitMix64(seed: roundSeed ^ mode.salt)           // local var, never escapes
       let u = Sampling.unitInterval(using: &rng)                   // T02 added it; not Double.random
       return jitterRange.lowerBound + u * (jitterRange.upperBound - jitterRange.lowerBound)
   }
   ```
   Mixing in `mode.salt` is why `jitterIsDeterministicAndBounded`'s last assertion holds: two modes
   served from the same round seed must not receive the same jitter, or a player alternating modes
   sees correlated bands.
6. **Clamp**, then SIEVE's extra ceiling. Both as `static let` ranges, cited.
7. **Quantise.** `band = clamp(Int((δ + 4).rounded(.down)) + 1, 1, 8)`. Write it once; note in a
   comment that this is `floor(difficulty/0.125)+1` with `difficulty = (δ+4)/8` folded, and that it is
   valid **only** on a logit already clamped by step 6.
8. **Mode band clamp.** `bandRange(for:)`, a `switch` with no `default:`. Record
   `didClampAtModeCeiling` / `didClampAtModeFloor` here — T04's freeze and step 10's counter both read
   them, and recomputing them later means recomputing the clamp.
9. **Family repeat guard.** Fires iff `state.consecutiveLosses > 0` **and** `band == state.lastBand`.
   Down one, or up one if already at `bandRange(for: mode).lowerBound`. §10.7's row says the same
   thing in prose and adds "*and `targetδ` re-derived to the new band's centre — §10.3 step 9 then
   step 11, in that order*", which is step 11's job and not this one's.
10. **Ceiling rotation.** Fires iff `state.ceilingClampRun >= ceilingRotationRun`. Down one band.
11. **The re-derivation.** Three cases, in this precedence:
    ```swift
    let origin: Serving.TargetOrigin =
        if bandAfterCeilingRotation != bandAfterRepeatGuard { .upperNearEdge }
        else if bandAfterRepeatGuard != bandAfterJitter { .bandCentre }
        else { .withinBand }
    ```
    The rotation is step 10, the *last* mover, so when both it and the guard moved the band its rule
    wins. State that in a comment; §10.3 does not spell the collision out and a reader will ask.

    Then the value:
    - `.withinBand` → `clamp((δ + 4)/8, band.difficultyRange.lowerBound, band.difficultyRange.upperBound - 0.001)`
    - `.bandCentre` → `band.difficultyRange.upperBound - Band.width/2`
    - `.upperNearEdge` → `band.difficultyRange.upperBound - upperNearEdgeInset`

    **Then, in all three cases, clamp into `band.achievableDifficultyRange`.** This is E06·T02's
    ruling arriving. Band 1's forty atoms occupy roughly `0.023…0.040`; the nominal centre `0.0625` is
    unsatisfiable, all 200 attempts fail, the anchor ships, and H19 reads 1.00 at band 1 while every
    other statistic looks healthy. The clamp is one line and it is the difference between H19 passing
    and H19 being meaningless.
12. **Record.** `servedDelta = Rasch.logit(ofDifficulty: targetDelta)`. §10.3 is explicit that this,
    and not step 6's δ, is what the estimator consumes — `servedDeltaComesFromStepEleven` asserts the
    two differ.
13. **Dispatch is not here.** `Serving` is the handoff. PROBE and DRIFT call `generate` (E06·T06,
    E12·T01); ECHO calls `selectFromPool(targetδ)` (E13·T07); SIEVE solves `lawBand` and `s`
    (E14·T06). Each of those three tasks asserts that what it receives is in `[0, 1)`.

### `recordingServe(_:)` — the serve-time mutation, in exactly one place

```swift
extension ServingState {
    /// The three things that change when a round is *served*, as opposed to when it *ends*.
    /// Outcome-time mutation is `Pressure.applying(…)` (T04). Two functions, two moments,
    /// no third place where `ServingState` is mutated.
    public func recordingServe(_ serving: Serving) -> ServingState {
        var copy = self
        copy.lastBand = serving.band                       // §10.5: SIEVE records Band(lawBand)
        copy.ceilingClampRun = serving.trace.didClampAtModeCeiling ? ceilingClampRun + 1 : 0
        copy.palette = palette.raised(toServe: serving.band)   // E09·T04; H20's serve-time raise
        return copy
    }
}
```

`palette.raised(toServe:)` here is what makes **H20** true by construction: §10.4 says the guarantee is
enforced *at serve time, not at generation time*, and this is serve time. T05 asserts it for
calibration rounds as well.

`lastBand` for a SIEVE round must be the **law's** band, not the effective band (§10.5's last
sentence). The `Serving.band` a SIEVE round carries is the effective band `1…7`; E14·T06 derives
`lawBand = min(6, …)` from `targetDelta`. So `recordingServe` takes the band to record from the
caller, not from `Serving`, in SIEVE's case — add a `recordingServe(_:lawBand:)` overload in T06 when
the SIEVE path is wired, and leave a `// E14·T06` marker here. Do **not** guess the mapping in this
task.

### `ServingState.dayOneCalibrated`

A test fixture that is genuinely useful in production code's shape: `dayOne` with
`calibrationRound = nil`. It belongs on the type rather than in the test file because T05, T10 and T12
all need it and three private copies will drift. Document it as *"day-one state for a player who has
finished calibration"* and nothing more.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ServingPolicyTests` is green, all seventeen tests.
- [ ] For 2,000 seeds × four modes, `serving.targetDelta ∈ [0, 1)`, `serving.band.difficultyRange.contains(targetDelta)`, and `servedDelta == Rasch.logit(ofDifficulty: targetDelta)` to 1e-12.
- [ ] `serving.targetDelta ∈ band.achievableDifficultyRange` for every band and every seed tested.
- [ ] The 5 → 4 repeat-guard case returns band 4 with `targetOrigin == .bandCentre` and a `targetDelta` strictly below 0.50.
- [ ] Over 400 guard-moved servings the generator falls back to the anchor on fewer than 2 %.
- [ ] `grep -n 'default:' HunchCore/Sources/Ladder/ServingPolicy.swift` returns nothing.
- [ ] `grep -n '1\.386\|0\.44\|0\.125\|-4\.0\|3\.99' HunchCore/Sources/Ladder/ServingPolicy.swift` returns only the `static let` declarations, each with a §10.3 or §5.1 citation, and no literal inside `serve`.
- [ ] `grep -rn 'Date()\|\.random(\|PersistenceStore' HunchCore/Sources/Ladder/ServingPolicy.swift` returns nothing.
- [ ] `ServingState` is mutated in exactly two named functions across the whole package: `recordingServe(_:)` here and `Pressure.applying(…)` in T04 — `grep -rn 'var copy = self' HunchCore/Sources/Ladder` confirms it.
- [ ] `tests.json` carries the three policy entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it. If it proposes splitting `serve` into a pipeline,
   decline and say why in the commit message.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T03: the 13-step serving policy with step 11 re-derived after every band move"`

## Out of scope

- How `reach` and `relief` *change*, the freeze when a clamp binds, and π₀'s derivation — **T04**. This task reads all three from `ServingState` and `Pressure`.
- The uncalibrated branch of step 1 — **T05**.
- Step 13's four dispatches, the seed's provenance and the sticky target's consumption — **T06**, **E12·T01**, **E13·T07**, **E14·T06**.
- The floor rescue, which replaces the generated law entirely at band 1 after three losses — **T07**.
- `n`'s decay and the re-entry relief that feeds step 4 — **T08**.
- Every measurement over the policy (H3, H9, H19, H21) — **T10** and **T12**. The tests here are per-step unit tests, not statistics.
