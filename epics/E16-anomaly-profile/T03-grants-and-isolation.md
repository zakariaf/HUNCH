# T03 — Grants and isolation

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Grants and isolation (ANOMALY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The isolation rule has to be a *type*, not a discipline. This skill's state-ownership section is what decides that the bookkeeping decision is a pure core value computed once from a `RoundRecord`, consumed by `Ladder`, `Codex` and `Profile` alike, rather than five separate `if record.isAnomaly` branches scattered across `Modules/` — which is the shape that lets one of them be forgotten. |

## Objective

At the end of this task an Anomaly round is a full round that the adaptive engine cannot see. One
core function turns a settled `RoundRecord` into a `RoundBookkeeping` value, and that value is the
only thing `Ladder`, `Codex` and `Profile` consult: for an Anomaly it grants the full palette and the
Assay evidence overlay for the duration of that round and reverts both, leaves θ, `reach`, `relief`,
`winStreak`, `consecutiveLosses` and `maxBandEverServed` untouched, inscribes the Codex page in full,
feeds every Profile axis at half weight, and emits no Induction loss-sample at all.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.6 | the four-row problem/mechanism table: never updates θ / `reach` / `relief` / `winStreak` / `consecutiveLosses`; the temporary full palette; the always-granted Assay overlay; the tally and streak as the two records. Asserted by H14 |
| `GAME_DESIGN.md` | §11.6 | the two decisions — always PROBE, and *"it does inscribe Codex pages, and it feeds Profile axes at 0.5 weight, never emitting an Induction loss-sample"* |
| `GAME_DESIGN.md` | §11.9 | the axis weights the 0.5 multiplies, and Induction's `lost:` branch that is suppressed |
| `GAME_DESIGN.md` | §10.4 | the palette ceiling derives from `maxBandEverServed` — which is why the Anomaly must not raise it |
| `GAME_DESIGN.md` | §4.4 | the palette ceiling rule: lifetime maximum band served **+ 1**, never the current round's band |
| `GAME_DESIGN.md` | §4.3 | the Assay evidence overlay unlocks at band 4 in canon; the Anomaly is always band ≥ 4, so granting it is consistent rather than an exception |
| `GAME_DESIGN.md` | §10.10 | **H14**: 400 Anomaly rounds injected mid-run, `θ̂` bit-identical to the run without them |
| `GAME_DESIGN.md` | §11.12 | the Anomaly does not count toward a "run" of consecutive solved rounds |
| `ios-swift-guide/03-WRITING-CODE.md` | W29 | no `default:` in the bookkeeping switch — adding a mode or an outcome must break it |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/RoundsTests/RoundBookkeepingTests.swift`:

```swift
import Foundation
import Testing
import Rounds
import LawGeneration
import HunchTestSupport

@Suite("Anomaly grants and isolation — §10.6 and §11.6", .tags(.unit, .presubmission))
struct RoundBookkeepingTests {

    private func record(anomaly: Bool, mode: Mode = .probe, band: Band = .contextual,
                        outcome: Outcome = .solved, strikes: Int = 0) -> RoundRecord {
        RoundRecord(mode: mode, band: band, outcome: outcome, strikes: strikes,
                    probesUsed: 18, score: 700, marks: 2, isAnomaly: anomaly,
                    settledAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - the isolation half

    @Test("an Anomaly round moves nothing the serving layer reads")
    func anomalyMovesNothingInTheLadder() {
        let b = RoundBookkeeping(for: record(anomaly: true))
        #expect(!b.updatesAbility)
        #expect(!b.updatesPressure)          // reach and relief
        #expect(!b.updatesStreaks)           // winStreak and consecutiveLosses
        #expect(!b.raisesMaxBandEverServed)  // §10.4 — otherwise the palette grant leaks forever
        #expect(!b.countsTowardRun)          // §11.12
    }

    @Test("an ordinary round of the same shape moves all five")
    func anOrdinaryRoundMovesThem() {
        let b = RoundBookkeeping(for: record(anomaly: false))
        #expect(b.updatesAbility)
        #expect(b.updatesPressure)
        #expect(b.updatesStreaks)
        #expect(b.raisesMaxBandEverServed)
        #expect(b.countsTowardRun)
    }

    @Test("isolation holds for every outcome, not only for a loss",
          arguments: [Outcome.solved, .lostOnStrike, .lostAtCap, .abandoned, .voided])
    func isolationHoldsForEveryOutcome(_ outcome: Outcome) {
        let b = RoundBookkeeping(for: record(anomaly: true, outcome: outcome))
        #expect(!b.updatesAbility)
        #expect(!b.updatesStreaks)
        #expect(!b.raisesMaxBandEverServed)
    }

    // MARK: - what it DOES feed

    @Test("an Anomaly round inscribes a Codex page in full")
    func anomalyInscribesFully() {
        #expect(RoundBookkeeping(for: record(anomaly: true)).inscribesCodexPage)
        #expect(RoundBookkeeping(for: record(anomaly: true)).codexPageCarriesAnomalySeal)
    }

    @Test("an Anomaly round feeds the Profile at half weight")
    func anomalyFeedsTheProfileAtHalfWeight() {
        #expect(isApproximatelyEqual(RoundBookkeeping(for: record(anomaly: true)).profileWeight,
                                     0.5, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(RoundBookkeeping(for: record(anomaly: false)).profileWeight,
                                     1.0, absoluteTolerance: 1e-12))
    }

    /// §11.6: "never emitting an Induction loss-sample". A band-7 loss by a band-2 player would
    /// otherwise sample Induction at (7−2)/7 = 0.71 and pull the axis UP on a defeat.
    @Test("a lost Anomaly round emits no Induction sample at all",
          arguments: [Outcome.lostOnStrike, .lostAtCap])
    func lostAnomalyEmitsNoInductionSample(_ outcome: Outcome) {
        let b = RoundBookkeeping(for: record(anomaly: true, outcome: outcome))
        #expect(!b.emitsInductionSample)
        #expect(b.profileWeight > 0)          // Restraint and Tempo still sample
    }

    @Test("a solved Anomaly round DOES emit an Induction sample, at half weight")
    func solvedAnomalyEmitsInduction() {
        let b = RoundBookkeeping(for: record(anomaly: true, outcome: .solved))
        #expect(b.emitsInductionSample)
        #expect(isApproximatelyEqual(b.profileWeight, 0.5, absoluteTolerance: 1e-12))
    }

    @Test("an ordinary lost round DOES emit an Induction sample",
          arguments: [Outcome.lostOnStrike, .lostAtCap])
    func ordinaryLossStillSamplesInduction(_ outcome: Outcome) {
        #expect(RoundBookkeeping(for: record(anomaly: false, outcome: outcome)).emitsInductionSample)
    }

    // MARK: - the grants

    @Test("the Anomaly's serving grants the full palette and the Assay overlay")
    func grantsAreOn() {
        let g = AnomalyGrants.forServing(band: .composite)
        #expect(g.paletteCeiling == Band.allCases.last)     // the whole palette, not band + 1
        #expect(g.assayEvidenceOverlay)
    }

    @Test("the grants are scoped to the round and carry no persistent effect")
    func grantsAreScoped() {
        // The grant is a value on the Serving; there is no setter anywhere that persists it.
        let g = AnomalyGrants.forServing(band: .guarded)
        #expect(g.isTemporary)
        #expect(!RoundBookkeeping(for: record(anomaly: true, band: .guarded)).raisesMaxBandEverServed)
    }

    // MARK: - exhaustiveness

    @Test("the bookkeeping table is total over mode × anomaly × outcome",
          arguments: Mode.allCases, [true, false])
    func tableIsTotal(_ mode: Mode, _ anomaly: Bool) {
        for outcome in Outcome.allCases {
            let b = RoundBookkeeping(for: record(anomaly: anomaly, mode: mode, outcome: outcome))
            // Only PROBE is ever an Anomaly (§11.6). Every other pairing must still answer.
            if anomaly && mode != .probe { #expect(!b.updatesAbility) }
            #expect(b.profileWeight >= 0 && b.profileWeight <= 1)
        }
    }
}
```

`HunchCore/Tests/LadderTests/AnomalyIsolationTests.swift` — the H14 assertion, run at the fast
subset:

```swift
import Foundation
import Testing
import Ladder
import Rounds
import LawGeneration
import HunchTestSupport

@Suite("H14 — Anomaly isolation", .tags(.unit, .presubmission))
struct AnomalyIsolationTests {

    /// §10.10 H14: 400 Anomaly rounds injected mid-run; θ̂ bit-identical to the run without them.
    @Test("400 injected Anomaly rounds leave the ability estimate BIT-identical")
    func fourHundredAnomalyRoundsChangeNothing() {
        let clean = ResponseHarness(seed: 0xA17_0MA1Y, trueAbility: 0.85).run(rounds: 600)
        let noisy = ResponseHarness(seed: 0xA17_0MA1Y, trueAbility: 0.85)
            .run(rounds: 600, injectingAnomalyRoundsEvery: 1)      // 400 extra, interleaved
        #expect(noisy.ability.baseline?.bitPattern == clean.ability.baseline?.bitPattern)
        #expect(noisy.serving.reach.bitPattern == clean.serving.reach.bitPattern)
        #expect(noisy.serving.relief.bitPattern == clean.serving.relief.bitPattern)
        #expect(noisy.serving.winStreak == clean.serving.winStreak)
        #expect(noisy.serving.consecutiveLosses == clean.serving.consecutiveLosses)
        #expect(noisy.serving.maxBandEverServed == clean.serving.maxBandEverServed)
        #expect(noisy.anomalyRoundsSeen == 400)     // the injection really happened
    }

    @Test("the same 400 rounds DO move the Codex and the Profile")
    func theSameRoundsAreNotInvisibleEverywhere() {
        let clean = ResponseHarness(seed: 0xA17_0MA1Y, trueAbility: 0.85).run(rounds: 600)
        let noisy = ResponseHarness(seed: 0xA17_0MA1Y, trueAbility: 0.85)
            .run(rounds: 600, injectingAnomalyRoundsEvery: 1)
        #expect(noisy.codexPagesMinted > clean.codexPagesMinted)
        #expect(noisy.profileSamplesEmitted > clean.profileSamplesEmitted)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter RoundBookkeepingTests` then `--filter AnomalyIsolationTests`.
The failures must be missing symbols (`RoundBookkeeping`, `AnomalyGrants`,
`ResponseHarness.run(rounds:injectingAnomalyRoundsEvery:)`) and, once those exist, a **failing**
bit-identity assertion — because a naive implementation feeds the estimator. Watch it go red on
`bitPattern` before you make it green; a `θ̂` that is merely *close* is a failure.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/RoundBookkeeping.swift` |
| create | `HunchCore/Sources/Archive/AnomalyGrants.swift` |
| create | `HunchCore/Tests/RoundsTests/RoundBookkeepingTests.swift` |
| create | `HunchCore/Tests/LadderTests/AnomalyIsolationTests.swift` |
| modify | `HunchCore/Sources/Archive/RoundRecord.swift` — add `isAnomaly: Bool` (additive, `decodeIfPresent` default `false`) |
| modify | `HunchCore/Sources/Ladder/ServingPolicy.swift` — the Anomaly path bypasses steps 1–13 entirely and returns T01's parameters |
| modify | `HunchCore/Sources/Ladder/ServingState.swift` — `maxBandEverServed` is raised only where `RoundBookkeeping.raisesMaxBandEverServed` says so |
| modify | `HunchTestSupport/ResponseHarness.swift` (E11·T10's) — the `injectingAnomalyRoundsEvery:` parameter and the three counters |
| modify | `Modules/Sources/LoomFeature/Round.swift` — the settle path consults `RoundBookkeeping` once, and nothing downstream re-asks `isAnomaly` |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — palette ceiling reads `serving.paletteCeiling`, not `maxBandEverServed + 1`, so the grant is expressible |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/stats.json` — the `recentRounds` ring gains `isAnomaly` |
| modify | `tests.json` — five entries |

## Implementation notes

### One value, consulted once

```swift
/// The complete answer to "what does this settled round change?", computed once at `settled`.
/// Every consumer reads this value; nobody re-asks `record.isAnomaly`.
public struct RoundBookkeeping: Equatable, Sendable {
    public let updatesAbility: Bool
    public let updatesPressure: Bool            // reach, relief
    public let updatesStreaks: Bool             // winStreak, consecutiveLosses
    public let raisesMaxBandEverServed: Bool
    public let countsTowardRun: Bool            // §11.12's "run" statistic
    public let inscribesCodexPage: Bool
    public let codexPageCarriesAnomalySeal: Bool
    public let emitsInductionSample: Bool
    public let profileWeight: Double            // multiplies §11.9's per-axis w

    public init(for record: RoundRecord)
}
```

The initialiser is one `switch` and about twelve lines. The **only** thing that matters is that it is
one place: §10.6's list is five separate quantities living in three different types, and five
separate `if isAnomaly` guards is five chances to forget one. The `grep` in the acceptance criteria
is what keeps it that way.

`voided` and `abandoned` already update nothing (E10·T04, E07·T07); the Anomaly's rule composes with
theirs by conjunction, not by replacement — `updatesAbility` is `outcomeIsScored && !isAnomaly`.

### The Induction suppression, and why it is not "weight 0"

`emitsInductionSample` is a separate flag from `profileWeight` because they mean different things. A
lost Anomaly round emits Restraint (`d = 0.00` on a second strike, or `0.60` on a cap loss with zero
strikes) and Tempo (`0.5 · min(1, par/probes)`) at weight 0.5 — the player really did spend those
probes and really did or did not declare early, and those facts are about *them*. What it does not
emit is Induction, because Induction's `lost:` branch is `clamp((band−2)/7, 0, 1)` and the Anomaly's
band is drawn from 4–7 independently of the player. A band-2 player losing a band-7 daily would
sample Induction at 0.714 — the axis would rise on a defeat, which is the one direction §11.9's
monotonicity property forbids.

Setting the weight to 0 instead would look equivalent and is not: T06's update rule does
`n = min(60, n + w)`, so a zero-weight sample is a no-op *now* and a subtle bug the first time
someone adds a floor to `α`. Absence is expressible; zero weight is a coincidence.

### The grants

```swift
public struct AnomalyGrants: Equatable, Sendable {
    public let paletteCeiling: Band          // the FULL palette, not the band + 1 rule
    public let assayEvidenceOverlay: Bool    // always true
    public let isTemporary: Bool             // always true; there is no persistent form
    public static func forServing(band: Band) -> AnomalyGrants
}
```

Three points:

- **The palette is the whole palette**, not `band + 1`. §10.6: *"Without this a band-2 player
  literally cannot express a band-6 law and the Anomaly is not merely hard but impossible."* Every
  tile class is unlocked for the round.
- **The overlay is always on.** §10.6 notes this is consistent rather than an exception: canon
  unlocks it at band 4 and the Anomaly is always band ≥ 4. It also composes with §10.7's floor
  rescue, which grants it permanently — a player with the permanent grant sees no change.
- **Reversion is by construction, not by a teardown step.** The grants ride on the `Serving` value
  the round was armed with and die with it. There is no `revert()` to forget to call, and there is no
  writer that could persist them: `raisesMaxBandEverServed == false` is what makes that true, because
  `maxBandEverServed` in `ladder.json` is the *only* durable input to the palette ceiling (§10.4).
  That single flag is the entire reversion mechanism, and `grantsAreScoped` is its test.

### Serving an Anomaly round

The Anomaly does not go through §10.3's thirteen steps at all. `ServingPolicy` gains an early return:

```
if request.isAnomaly {
    let p = Anomaly.parameters(day: request.day)                     // T01
    return Serving(seed: p.seed, band: p.band, targetDelta: p.targetDelta, mode: .probe,
                   avoid: [], grants: AnomalyGrants.forServing(band: p.band),
                   par: p.par, cap: p.cap, isAnomaly: true)
}
```

`avoid: []` again — the serving layer's novelty ring, per-band soft-avoid and lost-law cooldown
(E11·T06) are all skipped, because §11.6 requires the day's law to be identical for every player and
every one of those three sets is per-player. This is the second place `avoid: []` appears and the
last; if a third appears, one of them is wrong.

### The harness hook

E11·T10's `ResponseHarness` gains `injectingAnomalyRoundsEvery: Int?` — after every *n*th ordinary
round it feeds a synthetic Anomaly round through the same settle path, with a band drawn 4–7 and an
outcome drawn from the same Bernoulli. The three counters (`anomalyRoundsSeen`, `codexPagesMinted`,
`profileSamplesEmitted`) exist so that both halves are assertable: the estimator did not move **and**
the injection was real. A test that only asserts the first half passes when the injection silently
does nothing, which is the failure mode that makes H14 worthless.

Keep this at the fast subset — 600 rounds twice is microseconds. E11·T12's full H14 run at the
nightly matrix is not replaced by it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RoundBookkeepingTests` green, all eleven tests.
- [ ] `swift test --package-path HunchCore --filter AnomalyIsolationTests` green, with `bitPattern` equality on θ, `reach` and `relief` — not approximate equality.
- [ ] `grep -rn "isAnomaly" HunchCore/Sources Modules/Sources` shows the flag read in exactly two places: `RoundBookkeeping.init(for:)` and `ServingPolicy`'s early return. Every other consumer reads `RoundBookkeeping`.
- [ ] `grep -rn "avoid: \[\]" HunchCore/Sources` returns exactly two sites — `Anomaly.law(day:)` and `ServingPolicy`'s Anomaly branch.
- [ ] `grep -rn "default:" HunchCore/Sources/Rounds/RoundBookkeeping.swift` returns nothing.
- [ ] `grep -rn "maxBandEverServed" HunchCore/Sources Modules/Sources` shows exactly one write site, guarded by `raisesMaxBandEverServed`.
- [ ] `tests.json` carries five entries: ladder isolation across all outcomes, Codex inscription, the 0.5 Profile weight, the suppressed Induction loss-sample, and H14's bit-identity at the fast subset.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes collapsing `emitsInductionSample` into `profileWeight == 0`, reject it and point at the note above.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T03: Anomaly grants, ladder isolation and the single bookkeeping value"`

## Out of scope

- The five axis sample formulas the 0.5 weight multiplies — **T05**; the update rule that consumes `w` — **T06**.
- `Ability`, `AbilityEstimator`, the 13-step policy, `π₀`, `reach` and `relief` themselves — **E11·T01–T04**.
- The palette ceiling rule and the Assay overlay's *drawing* — **E09·T04/T06**.
- The Codex page's anomaly seal on the instrument strip — **E15·T05**.
- H14's full nightly run — **E11·T12**.
