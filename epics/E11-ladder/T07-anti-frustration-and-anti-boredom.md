# T07 — Anti-frustration and anti-boredom

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P2 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | §14.1 Anti-frustration (P0) · §14.1 Anti-boredom (P2) |
| **Status** | not started |

> **Priority note.** The plan sizes this task P2 because §14.1 rates *Anti-boredom* P2. Half of it —
> the floor rescue, the sticky target and the family repeat guard — is on §14.1's **P0** row
> *Anti-frustration*, and most of that half already landed in T03, T04 and T06. What is genuinely new
> and genuinely P0 here is the **floor rescue**; everything else in this file is the P2 half. If the
> epic ever has to be cut, cut the ceiling variation, the ceiling rotation's counter maintenance and
> the weak-mode predicate — never the floor rescue, which H8 measures.

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that the floor rescue is a *serving-layer branch returning a different law*, not a new field on `Serving`, and that the ceiling variation is a `MarkStandard` parameter threaded into E06·T07's existing `Marks` function rather than a second marks function. It also owns the ruling that "no cap relief and no par relief" is enforced by `Band.par(for:)`'s arity — a function of one `Band` and nothing else — rather than by a comment. |

## Objective

The four remaining pacing triggers exist as state and predicates: the floor rescue that serves the
anchor law and opens the Assay overlay permanently when relief has nowhere left to go; the ceiling
variation that tightens the three-mark threshold instead of the law; the ceiling-rotation counter that
step 10 already reads; and the weakest-mode predicate the mode rack renders. At the end of this task
`Band.par(for:)` and `Band.cap(for:)` still take one argument and there is a test that says so.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.7 | All eight anti-frustration rows; the floor-rescue definition (anchor law, `freeAttributeCount = 3`, contiguous subset, `p ≈ 0.25`, minimum difficulty in the band, plus a **permanent** Assay overlay); **"No cap relief, ever, and no par relief, ever"** and the identifiability argument behind it |
| `GAME_DESIGN.md` | §10.8 | All six anti-boredom rows: the ceiling variation's `0.45·par`, the shelf soft-avoid, the family rotation as a measured property, the ceiling rotation, the weak-mode sigil lift, and band 7/8 skeleton weighting |
| `GAME_DESIGN.md` | §10.3 | Step 10's ceiling rotation and the `θ_true = +6` measurement (band 8 on 89 % of rounds, mean family run 4.7) that motivates it |
| `GAME_DESIGN.md` | §5.3 | The family's deterministic anchor law and its two exemptions |
| `GAME_DESIGN.md` | §5.4 | Marks at `0.6·par` / `par` / `cap`, and "par is soft; the cap is hard" |
| `GAME_DESIGN.md` | §10.10 | H8 (no trap at the floor, ≥ 0.55 after rescue) and H9 (no trap at the ceiling) |
| `E09·T06` | `AssayEvidenceGrant.swift` | `grantingFloorRescue()` and its latch — shipped; this task is what calls it |
| `E09·T04` | `PaletteCeiling.swift` | Untouched by any of this — the palette is not relief |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/PacingTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import Bench
import LawGeneration
@testable import Ladder
import HunchTestSupport

@Suite("Anti-frustration and anti-boredom — §10.7, §10.8", .tags(.unit, .presubmission))
struct PacingTests {

    // MARK: the floor rescue — the P0 half

    /// §10.7: "3 consecutive losses at band 1 (the floor — relief has nowhere to go)".
    /// Two of the three at band 1 is not enough, and three losses spread across bands is not it either.
    @Test("The rescue arms on the third consecutive loss at band 1 and not before")
    func floorRescueArmsOnTheThird() {
        var state = ServingState.dayOneCalibrated
        for i in 1...3 {
            state = FloorRescue.recordingLoss(at: .literal, in: state)
            #expect(FloorRescue.isArmed(state) == (i >= 3))
        }
    }

    @Test("A loss above band 1 resets the run")
    func lossAboveTheFloorResetsTheRun() {
        var state = ServingState.dayOneCalibrated
        state = FloorRescue.recordingLoss(at: .literal, in: state)
        state = FloorRescue.recordingLoss(at: .literal, in: state)
        state = FloorRescue.recordingLoss(at: .pair, in: state)
        state = FloorRescue.recordingLoss(at: .literal, in: state)
        #expect(FloorRescue.isArmed(state) == false)
    }

    @Test("A win at band 1 resets the run")
    func winResetsTheRun() {
        var state = ServingState.dayOneCalibrated
        state = FloorRescue.recordingLoss(at: .literal, in: state)
        state = FloorRescue.recordingLoss(at: .literal, in: state)
        state = FloorRescue.recordingWin(in: state)
        #expect(state.floorLossRun == 0)
    }

    /// §10.7: "serve the family's deterministic anchor law (§5.3)". §5.3 and E06·T06's ruling
    /// make that `Band.exemplar`. It is the law with minimum difficulty in the band.
    @Test("An armed rescue serves the band-1 anchor law itself")
    func rescueServesTheAnchor() {
        var state = ServingState.dayOneCalibrated
        state.floorLossRun = 3
        let served = FloorRescue.law(forBand: .literal)
        #expect(served == Band.literal.exemplar.renderedNormalForm)

        let law = Law(served)
        #expect(law.freeAttributeCount == 3)                       // §10.7's stated shape
        #expect(isApproximatelyEqual(law.admitRate, 0.25, absoluteTolerance: 0.02))
        #expect(law.scatteredSubsetCount == 0)                     // contiguous subset
    }

    /// §10.7: "unlock the Assay evidence overlay permanently for that player. At the floor, the
    /// tooling opens because the difficulty cannot close further."
    @Test("The rescue latches the Assay overlay permanently, at every band")
    func rescueOpensTheToolingForever() {
        var state = ServingState.dayOneCalibrated
        state.floorLossRun = 3
        let after = FloorRescue.applying(to: state)

        #expect(after.assayGrant.hasFloorRescue)
        for band in Band.allCases {
            #expect(after.assayGrant.isGranted(band: band, isAnomaly: false))
        }
        // Latched: winning afterwards does not take it back.
        #expect(FloorRescue.recordingWin(in: after).assayGrant.hasFloorRescue)
    }

    @Test("The rescue does not touch the palette, par, cap or the estimate")
    func rescueIsNarrow() {
        var state = ServingState.dayOneCalibrated
        state.floorLossRun = 3
        let after = FloorRescue.applying(to: state)
        #expect(after.palette == state.palette)
        #expect(after.relief == state.relief)
        #expect(after.reach == state.reach)
    }

    // MARK: the ceiling variation

    /// §10.8: "≥ 8 wins in the last 10 rounds at band 8 with δ clamped at 3.99".
    @Test("The tightened standard arms at eight of the last ten and not at seven")
    func ceilingVariationArms() {
        var variation = CeilingVariation.inactive
        for i in 0..<10 { variation = variation.recording(win: i < 7, atCeiling: true) }
        #expect(variation.isActive == false)
        variation = variation.recording(win: true, atCeiling: true)
        #expect(variation.isActive)
    }

    @Test("Rounds served below the ceiling do not count toward the window")
    func onlyCeilingRoundsCount() {
        var variation = CeilingVariation.inactive
        for _ in 0..<10 { variation = variation.recording(win: true, atCeiling: false) }
        #expect(variation.isActive == false)
    }

    /// §10.8: "The law does not change; the *scoring* does."
    @Test("The tightened standard moves the 3-mark threshold and nothing else",
          arguments: Band.allCases)
    func tightenedStandardMovesOnlyTheMark(_ band: Band) {
        let par = band.par
        let canonical = Marks.threshold(for: 3, par: par, cap: band.cap, standard: .canonical)
        let tightened = Marks.threshold(for: 3, par: par, cap: band.cap, standard: .tightened)
        #expect(tightened < canonical)
        #expect(Marks.threshold(for: 2, par: par, cap: band.cap, standard: .tightened)
                == Marks.threshold(for: 2, par: par, cap: band.cap, standard: .canonical))
        #expect(Marks.threshold(for: 1, par: par, cap: band.cap, standard: .tightened)
                == Marks.threshold(for: 1, par: par, cap: band.cap, standard: .canonical))
    }

    @Test("The tightened standard reverts after three failures of it")
    func tightenedStandardReverts() {
        var variation = CeilingVariation.active
        variation = variation.recordingTightenedResult(earnedThreeMarks: false)
        variation = variation.recordingTightenedResult(earnedThreeMarks: false)
        #expect(variation.isActive)
        variation = variation.recordingTightenedResult(earnedThreeMarks: false)
        #expect(variation.isActive == false)
    }

    @Test("Earning three marks under the tightened standard resets its patience")
    func tightenedStandardForgives() {
        var variation = CeilingVariation.active
        variation = variation.recordingTightenedResult(earnedThreeMarks: false)
        variation = variation.recordingTightenedResult(earnedThreeMarks: false)
        variation = variation.recordingTightenedResult(earnedThreeMarks: true)
        variation = variation.recordingTightenedResult(earnedThreeMarks: false)
        #expect(variation.isActive)
    }

    // MARK: no cap relief, no par relief — §10.7's closing rule

    /// Structural, because a behavioural test cannot prove an absence. `par` and `cap` are
    /// functions of a `Band` and nothing else; there is no player, no state and no standard.
    @Test("par and cap depend on the band alone", arguments: Band.allCases)
    func parAndCapAreFunctionsOfTheBandAlone(_ band: Band) {
        var state = ServingState.dayOneCalibrated
        state.relief = 2.0
        state.floorLossRun = 3
        state.ceilingVariation = .active
        // There is deliberately no overload that accepts any of the above.
        #expect(band.par == Band.par(for: band))
        #expect(band.cap == Band.cap(for: band))
        #expect(band.cap == Int((1.6 * Double(band.par)).rounded(.up)))
    }

    // MARK: the weakest mode

    /// §10.8: "min(drift, echo, sieve) more than 1.0 logit below core".
    @Test("The weakest mode is nil until one offset falls a full logit below the baseline")
    func weakestMode() {
        var ability = Ability.seeded(baseline: 1.0)
        #expect(ability.weakestMode == nil)
        ability.setOffset(-0.9, for: .sieve)
        #expect(ability.weakestMode == nil)
        ability.setOffset(-1.2, for: .sieve)
        #expect(ability.weakestMode == .sieve)
        ability.setOffset(-2.0, for: .echo)
        #expect(ability.weakestMode == .echo)          // the weakest, not the first
    }

    @Test("PROBE can never be the weakest mode — it is the anchor")
    func probeIsNeverWeakest() {
        var ability = Ability.seeded(baseline: -5.0)
        ability.setOffset(0.5, for: .drift)
        #expect(ability.weakestMode != .probe)
    }

    // MARK: the shelf soft-avoid at the ceiling

    /// §10.8's row and §5.3's `avoid` clause describe the same mechanism; T06 implements it for
    /// every band and this is the assertion that band 8 is covered by it rather than by a second
    /// code path.
    @Test("Band 8's found set is soft-avoided in whole, by the ordinary rule")
    func bandEightUsesTheOrdinaryShelfAvoid() {
        let found = (0..<400).map(UInt64.init)
        #expect(AvoidSet.softAvoid(band: .systemic, found: found).count == found.count)
        #expect(AvoidSet.assemble(band: .systemic, novelty: .empty, cooldown: .empty,
                                  currentRound: 0, found: found, anomaly: nil).hard.isEmpty)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter PacingTests`

It must fail on missing symbols — `FloorRescue`, `CeilingVariation`, `Marks.threshold(for:par:cap:standard:)`,
`Ability.weakestMode`, `ServingState.floorLossRun` — not on a malformed expectation.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** Check that no second copy of "0.6·par" exists after `MarkStandard`
lands.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/FloorRescue.swift` |
| create | `HunchCore/Sources/Ladder/CeilingVariation.swift` |
| modify | `HunchCore/Sources/Ladder/ServingState.swift` — `floorLossRun`, `ceilingVariation` |
| modify | `HunchCore/Sources/Ladder/Ability.swift` — `weakestMode` |
| modify | `HunchCore/Sources/Ladder/ServingLayer.swift` — the rescue branch in `serving`, the two counters in `settling` |
| modify | `HunchCore/Sources/LawGeneration/Marks.swift` — `MarkStandard` and the `standard:` parameter (E06·T07's file) |
| modify | `Modules/Sources/LoomFeature/Ladder.swift` — surfaces `assayGrant` and `ceilingVariation` to the round |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/ladder.json` — the two new fields |
| create | `HunchCore/Tests/LadderTests/PacingTests.swift` |
| modify | `DECISIONS.md` — the ceiling-variation revert reading; the one-mechanism reading of §10.8's shelf row |
| modify | `tests.json` — `ladder.floor-rescue`, `ladder.ceiling-variation`, `ladder.no-par-or-cap-relief`, `ladder.weakest-mode` |

## Implementation notes

### The floor rescue

```swift
/// §10.7's floor row: "At the floor, the *tooling* opens because the difficulty cannot close
/// further." Three consecutive losses at band 1, where `relief` has already saturated and the
/// step-6 clamp is holding.
public enum FloorRescue {
    public static let consecutiveLosses = 3

    public static func isArmed(_ state: ServingState) -> Bool
    public static func recordingLoss(at band: Band, in state: ServingState) -> ServingState
    public static func recordingWin(in state: ServingState) -> ServingState

    /// §5.3's family anchor, which E06·T06 ruled is `Band.exemplar`.
    public static func law(forBand band: Band) -> LawNode

    /// Latches E09·T06's grant and disarms the run.
    public static func applying(to state: ServingState) -> ServingState
}
```

`floorLossRun` is a **separate counter from `consecutiveLosses`**, and that is not redundancy: a player
can lose three in a row across bands 4, 3 and 2 (relief walking them down) without ever being at the
floor, and §10.7's row is specifically about the floor where relief has nowhere left to go.
`lossAboveTheFloorResetsTheRun` is the test that pins the difference. Add both fields' doc comments
with the distinction spelled out, or the next reader will delete one.

**"The floor" is the mode's floor**, `ServingPolicy.bandRange(for: mode).lowerBound` — band 1 for
PROBE, ECHO and SIEVE, band 3 for DRIFT. §10.7's row says "band 1" because it is written from PROBE's
point of view; DRIFT's floor is where DRIFT's relief runs out. Take the band range from the mode, and
note the generalisation in the doc comment as a reading of §10.7 rather than as an extension of it.

The rescue's *serving* branch sits in `ServingLayer.serving`, after the sticky check and before the
policy:

```swift
if FloorRescue.isArmed(state), mode == .probe || mode == .drift {
    // §10.7: the anchor law, exempt from G8's proximity clause and from G9 by construction (§5.3).
    …
}
```

ECHO selects from a pool and never generates (§8.6), and SIEVE's floor relief is the tempo step
(§10.7's own SIEVE row, owned by E14·T06) — so the rescue applies to the two generating modes only.
State that; do not silently skip it.

### The anchor is not "generate at minimum difficulty"

§10.7 describes the rescued law's shape — three free attributes, a contiguous subset, `p ≈ 0.25`,
minimum difficulty in the band — and §5.3 names the mechanism: *the family's deterministic anchor
law*. E06·T06 already ruled that this is `Band.exemplar`, and E06·T02 already asserts the exemplar is
in RNF, in its own band, and clear of every guardrail it is not exempt from. So `FloorRescue.law` is
one line and `rescueServesTheAnchor` asserts §10.7's four stated properties **of the exemplar** — if
any of them fails, the finding is about `Band.literal.exemplar`, not about this task, and it goes back
to E06·T01.

### The ceiling variation

```swift
/// §10.8's first two rows. Ten-round window at the ceiling; the law does not change, the
/// scoring does.
public struct CeilingVariation: Codable, Equatable, Sendable {
    public static let windowLength = 10
    public static let winsToArm = 8
    public static let failuresToRevert = 3

    private var window: UInt16          // a 10-bit mask of ceiling rounds won
    private var ceilingRoundsSeen: Int
    public private(set) var isActive: Bool
    private var consecutiveTightenedFailures: Int

    public func recording(win: Bool, atCeiling: Bool) -> Self
    public func recordingTightenedResult(earnedThreeMarks: Bool) -> Self
}
```

A `UInt16` bitmask rather than an array: it is ten bits, it is `Codable` as one integer, and
`ladder.json` stays under §11.13's 2 KB. `atCeiling` means *the round was served at band 8 with the
step-6 δ clamp binding* — both halves, exactly as §10.8 writes it; `Serving.Trace` already carries
`deltaAfterClamp` and `didClampAtModeCeiling`, so the caller in `ServingLayer.settling` computes it
from the trace and does not re-derive it.

> **Ruling, to be recorded in `DECISIONS.md`.** §10.8 says the tightened standard *"reverts after 3
> losses of the tightened standard"*, which is ambiguous between "three rounds lost" and "three
> rounds that failed to earn three marks under it". Take the second: the tightened standard is a
> *scoring* change, so the thing it can be failed at is its mark, and reading it as "three lost
> rounds" would make a player who keeps winning at 0.5·par — precisely the player it is for — keep it
> forever. `tightenedStandardForgives` pins the consecutive reading: three in a row, reset by any
> success.

### `MarkStandard` — one threshold function, one parameter

E06·T07 shipped par, cap, scoring and the marks at `0.6·par / par / cap`. Do **not** add a second marks
function here. Add a parameter:

```swift
public enum MarkStandard: Sendable {
    case canonical          // §5.4 — 3 marks at ≤ 0.6·par
    case tightened          // §10.8 — 3 marks at ≤ 0.45·par, ceiling variation only
}

extension Marks {
    public static func threshold(for marks: Int, par: Int, cap: Int,
                                 standard: MarkStandard = .canonical) -> Int
}
```

The default is `.canonical`, so every existing call site is unchanged and the diff is small — and
`tightenedStandardMovesOnlyTheMark` asserts that the 2- and 1-mark thresholds are **identical** under
both standards, which is §10.8's "the law does not change; the scoring does" made checkable. The
tightened coefficient is a `public static let` on `MarkStandard` with its §10.8 citation.

### No cap relief and no par relief

§10.7's closing rule is an absence, and an absence needs a structural test. Three of them:

1. `parAndCapAreFunctionsOfTheBandAlone` — `Band.par(for:)` and `Band.cap(for:)` take one `Band`.
2. A grep in the acceptance criteria: no call site anywhere passes a `ServingState`, an `Ability`, a
   `relief` or a `MarkStandard` to par or cap.
3. The relationship `cap == ceil(1.6 · par)` re-asserted here, because a "relief" would most plausibly
   arrive as a fudge to that multiplier.

§10.7 states the reason and it is worth the doc comment: par feeds Tempo and cap feeds the failure
signal the estimator needs; softening either makes the Rasch model unidentifiable and the Profile a
lie. Anything that makes a round easier does it through the **band and `targetδ`**, which is the one
channel the estimator can see.

### `Ability.weakestMode`

```swift
extension Ability {
    /// §10.8: the mode whose offset is more than a full logit below the baseline, if any.
    /// PROBE is excluded structurally — it *is* the baseline, so its offset is identically zero.
    public static let weakModeThreshold = -1.0
    public var weakestMode: Mode? { … }        // most negative offset, if below the threshold
}
```

Returning the **most negative** rather than the first below the threshold matters: §10.8 says
`min(drift, echo, sieve)`, and the sigil lift is a nudge toward *the* mode with slope left in it, not
toward whichever the enum happens to list first. E17·T04 renders it; this task ships the predicate and
nothing visual.

### The ceiling rotation's counter

Already read by T03 step 10 and already maintained by `recordingServe`. The only thing left is a test
that the two agree, which `ServingPolicyTests.clampRunResets` covers. §10.8's row is therefore
implemented and this task adds nothing — say so in the commit message rather than inventing a second
mechanism.

### Band 7/8 skeleton weighting

§10.8's last row — *"Skeletons weighted toward high marginal deficit (m2) at bands 7/8"* — is a
**generator** property and belongs to E06·T06's step 3. Check whether it landed; if it did not, it is
an E06 defect and goes back there as a follow-up, not here. Record which in the commit message.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter PacingTests` is green, all thirteen tests.
- [ ] The floor rescue arms on the third consecutive loss at the mode's floor band, not on the second, and not on three losses spread across bands.
- [ ] `FloorRescue.law(forBand: .literal)` is `Band.literal.exemplar.renderedNormalForm` and satisfies §10.7's four stated properties.
- [ ] After a rescue, `assayGrant.isGranted(band:isAnomaly:)` is true for all eight bands and survives a subsequent win.
- [ ] `grep -rn 'par(for:\|cap(for:' HunchCore/Sources Modules/Sources | grep -v 'Band' ` returns nothing — no call site passes anything but a band.
- [ ] `Marks.threshold(for: 2, …)` and `Marks.threshold(for: 1, …)` are identical under both standards, for all eight bands.
- [ ] The ceiling variation arms at 8 of 10 ceiling rounds, ignores non-ceiling rounds entirely, reverts after three consecutive tightened failures and forgives on any success.
- [ ] `Ability.weakestMode` returns the most negative offset below the threshold and never `.probe`.
- [ ] `Fixtures/v1/ladder.json` carries `floorLossRun` and `ceilingVariation` and `PersistenceTests` is green.
- [ ] `DECISIONS.md` carries the revert-condition ruling and the one-mechanism reading of §10.8's shelf row.
- [ ] `tests.json` carries the four pacing entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T07: floor rescue, ceiling variation, the weakest-mode predicate, and no par or cap relief"`

## Out of scope

- The relief ladder and the family repeat guard, both of which §10.7 lists and which landed in **T04** and **T03**.
- The sticky target's setting and consumption — **E10·T04** and **T06**.
- The cap reveal in rule-tiles — **E09·T10**.
- Every drawing: the third tick row — **E08·T08**; the Assay evidence overlay's rendering — **E09·T06**; the mode sigil's luminance lift — **E17·T04**.
- SIEVE's own anti-frustration row (tempo step before law band) — **E14·T06**.
- The family-rotation statistic §10.8 cites as already true — **T12**'s H21.
- Skeleton weighting at bands 7/8 — **E06·T06**.
