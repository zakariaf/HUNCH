# T08 — Absence and return

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P1 |
| **Size** | S |
| **Depends on** | T04 |
| **Delivers** | §14.1 Absence and return |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that the whole of this task is a pure function taking `(Ability, ServingState, Date)` and returning both, with the `Date` handed in from `Now` at the app edge — `08 §2`'s "half (b) bans *ambient* sources, not parameters", which is the only reason a section about elapsed days can live in `HunchCore` at all. It also owns the ruling that the re-entry grant is a field with a lifetime rather than a one-off write, which is what makes §10.9's worked table reproducible. |

## Objective

A returning player's *confidence* decays and their *ability* does not: `n` falls past seven days with
a floor of six, which raises `K` and lets two or three rounds re-measure them, and a re-entry relief
grant ramps the first rounds back so they read as a short round rather than a demotion. At the end of
this task §10.9's four-row worked table reproduces numerically, row for row, including the `reach` and
`relief` columns.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.9 | The whole section: the Decision that θ never decays and confidence does; the two-line pseudocode; the 92-day worked example with its four-row table; "cleared on first win, or after two rounds"; H15 |
| `GAME_DESIGN.md` | §10.2 | `K(n)` — what raising `n`'s decay actually buys |
| `GAME_DESIGN.md` | §10.3 | The relief ladder the grant feeds into, and π₀ |
| `GAME_DESIGN.md` | §10.12 | No login reward, no calendar, no "come back" — this mechanism is invisible and must stay so |
| `GAME_DESIGN.md` | §11.6 | The no-`Calendar`/no-`Locale`/no-`TimeZone` rule the day arithmetic must respect |
| `GAME_DESIGN.md` | §10.10 | H15: 90-day gap injected at round 200, ≤ 6 rounds to re-converge |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | `Now` is the only injected time source and there is no `Clock` abstraction anywhere |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/AbsenceTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
@testable import Ladder
import HunchTestSupport

@Suite("Absence and return — §10.9", .tags(.unit, .presubmission))
struct AbsenceTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Int) -> Date { epoch.addingTimeInterval(Double(n) * 86_400) }

    // MARK: θ never decays

    /// §10.9's Decision, and the single most important assertion in the task: a player who solved
    /// a band-6 GUARDED law in March has not forgotten how a guard works.
    @Test("The baseline and every offset are bit-identical after any gap",
          arguments: [0, 7, 8, 30, 92, 365, 3_650])
    func abilityNeverDecays(_ gap: Int) throws {
        var before = Ability.seeded(baseline: 1.20)
        before.setOffset(-0.75, for: .sieve)
        before.setOffset(0.30, for: .drift)
        before.setLastPlayed(epoch, for: .probe)

        let after = Absence.decayed(before, mode: .probe, now: day(gap)).ability
        #expect(try #require(after.baseline) == try #require(before.baseline))
        for mode in Mode.allCases {
            #expect(after.offset[mode] == before.offset[mode])
        }
    }

    // MARK: confidence does

    @Test("Nothing decays at or under seven days", arguments: [0, 1, 6, 7])
    func nothingHappensInsideAWeek(_ gap: Int) {
        var before = Ability.seeded(baseline: 0)
        before.setScoredRounds(40, for: .probe)
        before.setLastPlayed(epoch, for: .probe)
        let after = Absence.decayed(before, mode: .probe, now: day(gap))
        #expect(after.ability.scoredRounds[.probe] == 40)
        #expect(after.reentryRelief == 0)
    }

    /// §10.9's worked line: `n → max(6, 40·e^(−85/90)) = 15`, so `K` rises 0.180 → 0.297.
    @Test("A 92-day gap takes n from 40 to 15 and K from 0.180 to 0.297")
    func ninetyTwoDayGap() {
        var before = Ability.seeded(baseline: 1.20)
        before.setScoredRounds(40, for: .probe)
        before.setLastPlayed(epoch, for: .probe)

        let after = Absence.decayed(before, mode: .probe, now: day(92)).ability
        #expect(after.scoredRounds[.probe] == 15)
        #expect(isApproximatelyEqual(
            AbilityEstimator.learningRate(scoredRounds: after.scoredRounds[.probe]),
            0.297, absoluteTolerance: 0.002))
        #expect(isApproximatelyEqual(
            AbilityEstimator.learningRate(scoredRounds: before.scoredRounds[.probe]),
            0.180, absoluteTolerance: 0.002))
    }

    @Test("n has a floor of six however long the absence", arguments: [200, 1_000, 10_000])
    func confidenceHasAFloor(_ gap: Int) {
        var before = Ability.seeded(baseline: 0)
        before.setScoredRounds(4_096, for: .probe)
        before.setLastPlayed(epoch, for: .probe)
        #expect(Absence.decayed(before, mode: .probe, now: day(gap)).ability.scoredRounds[.probe]
                == Absence.confidenceFloor)
    }

    @Test("The decay is per mode: a SIEVE gap does not touch PROBE's confidence")
    func decayIsPerMode() {
        var before = Ability.seeded(baseline: 0)
        before.setScoredRounds(40, for: .probe)
        before.setScoredRounds(40, for: .sieve)
        before.setLastPlayed(day(90), for: .probe)          // played PROBE yesterday
        before.setLastPlayed(epoch, for: .sieve)            // last SIEVE was 91 days ago

        let after = Absence.applying(to: before, state: .dayOneCalibrated, now: day(91)).ability
        #expect(after.scoredRounds[.probe] == 40)
        #expect(after.scoredRounds[.sieve] < 40)
    }

    @Test("A mode never played has nothing to decay")
    func neverPlayedIsUntouched() {
        var before = Ability.seeded(baseline: 0)
        before.setScoredRounds(0, for: .echo)
        let after = Absence.decayed(before, mode: .echo, now: day(500))
        #expect(after.ability.scoredRounds[.echo] == 0)
        #expect(after.reentryRelief == 0)
    }

    // MARK: the re-entry grant

    @Test("Re-entry relief is 0.5·min(3, gap/30) and saturates at 1.5",
          arguments: [(8, 0.133), (30, 0.50), (60, 1.00), (90, 1.50), (92, 1.50), (400, 1.50)])
    func reentryReliefSchedule(_ gap: Int, _ expected: Double) {
        #expect(isApproximatelyEqual(Absence.reentryRelief(gapDays: gap), expected,
                                     absoluteTolerance: 0.005))
    }

    @Test("The grant raises relief and never lowers it")
    func grantTakesTheMaximum() {
        var state = ServingState.dayOneCalibrated
        state.relief = 2.0
        var ability = Ability.seeded(baseline: 0)
        ability.setScoredRounds(40, for: .probe)
        ability.setLastPlayed(epoch, for: .probe)

        let after = Absence.applying(to: ability, state: state, now: day(92)).state
        #expect(isApproximatelyEqual(after.relief, 2.0, absoluteTolerance: 1e-12))
    }

    /// §10.9's table, reproduced whole. Each row is steps 1–7 of §10.3 at zero jitter, including
    /// π₀ and the `reach` the preceding wins have earned. This is the acceptance test for the
    /// grant's *lifetime* reading — see the ruling below.
    @Test("§10.9's 92-day worked example reproduces row for row")
    func workedExampleReproduces() throws {
        var ability = Ability.seeded(baseline: 1.20)
        ability.setScoredRounds(40, for: .probe)
        ability.setLastPlayed(epoch, for: .probe)

        var applied = Absence.applying(to: ability, state: .dayOneCalibrated, now: day(92))
        ability = applied.ability
        var state = applied.state

        let expected: [(reach: Double, relief: Double, delta: Double, band: Band)] = [
            (0.00, 1.50, -2.13, .pair),
            (0.00, 1.00, -1.63, .exclusive),
            (0.25, 0.50, -0.88, .relational),
            (0.50, 0.00, -0.13, .relational),
        ]

        for (i, row) in expected.enumerated() {
            #expect(isApproximatelyEqual(state.reach, row.reach, absoluteTolerance: 1e-9),
                    "round \(i + 1) reach")
            #expect(isApproximatelyEqual(state.relief, row.relief, absoluteTolerance: 1e-9),
                    "round \(i + 1) relief")

            let serving = ServingPolicy.serve(mode: .probe, ability: ability,
                                              state: state, roundSeed: ServingPolicyTests.zeroJitterSeed)
            #expect(isApproximatelyEqual(serving.trace.deltaAfterClamp, row.delta,
                                         absoluteTolerance: 0.02), "round \(i + 1) δ")
            #expect(serving.band == row.band, "round \(i + 1) band")

            state = state.recordingServe(serving)
            state = Pressure.applying(.win, to: state, servedBand: serving.band, mode: .probe)
            state = Absence.clearingGrantAfterRound(won: true, in: state)
        }
    }

    @Test("The grant disarms on the first win")
    func grantDisarmsOnAWin() {
        var state = ServingState.dayOneCalibrated
        state.reentryGrant = .init(roundsRemaining: 2)
        #expect(Absence.clearingGrantAfterRound(won: true, in: state).reentryGrant == nil)
    }

    @Test("The grant disarms after two rounds without a win")
    func grantDisarmsAfterTwoRounds() {
        var state = ServingState.dayOneCalibrated
        state.reentryGrant = .init(roundsRemaining: 2)
        state = Absence.clearingGrantAfterRound(won: false, in: state)
        #expect(state.reentryGrant != nil)
        state = Absence.clearingGrantAfterRound(won: false, in: state)
        #expect(state.reentryGrant == nil)
    }

    /// §10.9's closing paragraph and §10.12's rule: nothing is taken away while the player is gone.
    @Test("Absence touches nothing but n and the grant")
    func absenceIsNarrow() {
        var ability = Ability.seeded(baseline: 1.2)
        ability.setScoredRounds(40, for: .probe)
        ability.setLastPlayed(epoch, for: .probe)
        var state = ServingState.dayOneCalibrated
        state.palette = state.palette.raised(toServe: .guarded)
        state.assayGrant = state.assayGrant.grantingFloorRescue()

        let after = Absence.applying(to: ability, state: state, now: day(400)).state
        #expect(after.palette == state.palette)
        #expect(after.assayGrant == state.assayGrant)
        #expect(after.winStreak == state.winStreak)
        #expect(after.calibrationRound == state.calibrationRound)
    }

    // MARK: the day arithmetic

    @Test("Whole days are counted by division, with no Calendar anywhere")
    func wholeDaysAreDivision() {
        #expect(Absence.wholeDays(from: epoch, to: epoch.addingTimeInterval(86_399)) == 0)
        #expect(Absence.wholeDays(from: epoch, to: epoch.addingTimeInterval(86_400)) == 1)
        #expect(Absence.wholeDays(from: epoch, to: epoch.addingTimeInterval(-10)) == 0)   // clock back
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter AbsenceTests`

It must fail on missing symbols — `Absence`, `ServingState.ReentryGrant`, `Absence.confidenceFloor` —
not on a malformed expectation. `workedExampleReproduces` additionally needs
`ServingPolicyTests.zeroJitterSeed`; add it to T03's suite as an `internal static let` found by
searching for a round seed whose jitter is under 1e-3, and document how it was found.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** If `workedExampleReproduces` is off by a constant on every row, the
grant's lifetime is wrong; read the ruling below before touching a tolerance.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/Absence.swift` |
| modify | `HunchCore/Sources/Ladder/ServingState.swift` — `reentryGrant` |
| modify | `Modules/Sources/LoomFeature/Ladder.swift` — calls `Absence.applying(to:state:now:)` once on `load()` and on `scenePhase → .active`, never per round |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/ladder.json` — `reentryGrant: null` |
| create | `HunchCore/Tests/LadderTests/AbsenceTests.swift` |
| modify | `HunchCore/Tests/LadderTests/ServingPolicyTests.swift` — `zeroJitterSeed` |
| modify | `DECISIONS.md` — the grant-lifetime reading of §10.9 |
| modify | `tests.json` — `ladder.theta-never-decays`, `ladder.confidence-decays`, `ladder.reentry-grant`, `ladder.worked-example-10-9` |

## Implementation notes

### The shape

```swift
/// §10.9. Pure over `(Ability, ServingState, Date)` — the `Date` arrives from `Now` at the app
/// edge (`08 §2`, `08 §5`), which is the only reason a section about elapsed days is core.
public enum Absence {
    public static let gracePeriodDays = 7          // §10.9
    public static let decayTimeConstant = 90.0     // §10.9
    public static let confidenceFloor = 6          // §10.9
    public static let reliefPerThirtyDays = 0.5    // §10.9
    public static let reliefGapCap = 3.0           // §10.9
    public static let grantRounds = 2              // §10.9

    /// Whole days, by division. §11.6's no-`Calendar`/no-`Locale`/no-`TimeZone` rule applies here
    /// too: this is an *elapsed* interval, not a calendar date, so a division is not merely
    /// permitted, it is the correct model — a player who stops for 92 days has stopped for 92
    /// days regardless of which time zone they were in.
    public static func wholeDays(from: Date, to: Date) -> Int

    public static func reentryRelief(gapDays: Int) -> Double

    /// One mode's confidence decay.
    public static func decayed(_ ability: Ability, mode: Mode,
                               now: Date) -> (ability: Ability, reentryRelief: Double)

    /// The session-start hook: all four modes, plus the grant.
    public static func applying(to ability: Ability, state: ServingState,
                                now: Date) -> (ability: Ability, state: ServingState)

    /// Called after every settled round while the grant is armed.
    public static func clearingGrantAfterRound(won: Bool, in state: ServingState) -> ServingState
}
```

`wholeDays` clamps at zero: a clock moved backwards must not produce a negative gap and therefore a
negative decay exponent, which would *raise* `n` above its stored value. §11.7 owns the clock-back
rule for the Anomaly; here it is one `max(0, …)` and a test.

### The grant's lifetime — the ruling this task must record

> **Ruling, to be recorded in `DECISIONS.md`.** The re-entry relief is applied **once**, at session
> start, as `relief = max(relief, reentryRelief(gap))`. What §10.9 means by *"cleared on first win, or
> after two rounds"* is that the **grant** — the licence to apply that maximum — is disarmed then; the
> `relief` *value* it produced continues to decay by §10.3's ordinary ladder (−0.50 per win, +1.00
> after two losses).
>
> The alternative reading — zero the relief itself on the first win or after two rounds — is
> contradicted by §10.9's own worked table three rows down. That table shows relief 1.50 → 1.00 → 0.50
> → 0.00 across four rounds, which is exactly −0.50 per win over three wins; under the zeroing reading
> round 3 would read 0.00, not 0.50. The table is the numerically checkable artifact and H15's ≤ 6
> rounds is calibrated against it, so the table wins and the sentence is read as being about the
> grant.
>
> `ServingState.ReentryGrant` is therefore a small optional value with `roundsRemaining`, armed by
> `applying(to:state:now:)` and disarmed by `clearingGrantAfterRound(won:in:)`. It exists so that a
> player who re-opens the app three times in one evening is granted the ramp once, not three times.

`workedExampleReproduces` is the acceptance test for that ruling and it asserts all four columns —
`reach`, `relief`, δ and band — because getting the band right with the wrong relief is possible for
two of the four rows (§10.9's δ of −0.88 and −0.13 both quantise to band 4).

### The decay

```swift
n[mode] = max(confidenceFloor,
              Int(Double(n[mode]) * exp(-Double(gap - gracePeriodDays) / decayTimeConstant)))
```

Three details:

- **`Int(...)` truncates**, and §10.9's worked line depends on it: `40 · e^(−85/90) = 15.49` → `15`,
  and `K(15) = 0.90/(1 + 15/8) = 0.313`… which is not the 0.297 §10.9 prints. §10.9's 0.297 is
  `K(16)`. Assert 0.297 with a 0.002 tolerance as §10.9 prints it and **check which of the two the
  formula gives before you widen anything**: if `Int` truncation gives `n = 15` and `K = 0.313`, the
  discrepancy is a rounding choice in the document's worked line, and the resolution is to record it
  in `DECISIONS.md` (§10.9's *formula* is normative, its worked K is a rounding) and assert `K(15)`
  with the formula rather than the printed number. Do not silently change the formula to match the
  prose — write down which one you kept and why.
- **A mode with `n == 0` decays to 0, not to 6.** `max(6, 0 · anything)` is 6 under a naive reading,
  which would hand a never-played mode a confidence it has not earned and a `K` of 0.297 instead of
  0.900. Guard on `n == 0` first; `neverPlayedIsUntouched` is the test.
- **`lastPlayed[mode] == nil` is the same case.** No last-played date means no gap.

### Where it is called from

Exactly once per session, in `Ladder.load()` and on `scenePhase → .active`, never per round. A
per-round call would re-decay `n` every round of a long session, because `lastPlayed` is only updated
when a round settles. Put the citation on the call site and add an assertion to
`LadderObservableTests` (T06's file) that two consecutive `serve` calls do not change `scoredRounds`.

`lastPlayed[mode]` is written by `Ladder.settle` from the injected `now` closure, on **scored rounds
only** — §10.9 says "the last scored round in that mode", and a suspended round that never scored has
not measured anything.

### It must stay invisible

§10.12 forbids every retention surface, and §10.9's closing line is that *"the ramp back is invisible
— it reads as a short round, not as a demotion"*. Concretely, this task adds nothing to `Modules/`
except one call: no "welcome back", no re-entry animation, no badge, no notification. T09's hygiene
check 13 greps for the absence; add `reentryGrant` and `Absence` to its list of identifiers that must
not appear under `Modules/Sources` outside `Ladder.swift`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AbsenceTests` is green, all thirteen tests.
- [ ] `baseline` and all four offsets are bit-identical for gaps of 0, 7, 8, 30, 92, 365 and 3,650 days.
- [ ] A 92-day gap takes `n` from 40 to 15 and raises `K` accordingly, with the `K` value asserted from the formula and any discrepancy against §10.9's printed 0.297 recorded in `DECISIONS.md`.
- [ ] `n` never falls below 6 for a played mode and never rises above 0 for an unplayed one.
- [ ] `reentryRelief(gapDays:)` reproduces all six tabulated rows within 0.005 and saturates at 1.5.
- [ ] §10.9's four-row worked table reproduces on all four columns — `reach`, `relief`, δ within 0.02, and band exactly.
- [ ] The grant disarms on the first win and after two winless rounds, and never lowers an existing `relief`.
- [ ] `grep -rn 'Calendar\|TimeZone\|Locale\|DateComponents' HunchCore/Sources/Ladder` returns nothing.
- [ ] `grep -rn 'Absence\|reentryGrant' Modules/Sources | grep -v 'LoomFeature/Ladder.swift'` returns nothing.
- [ ] `DECISIONS.md` carries the grant-lifetime ruling with §10.9's table cited as the evidence.
- [ ] `tests.json` carries the four absence entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T08: confidence decays and ability does not — the n decay and the re-entry grant"`

## Out of scope

- The relief ladder the grant feeds — **T04**.
- `Now` itself and its injection — **E10·T01**.
- The Profile's own idle decay (`n = max(4, n·0.5^(daysIdle/60))`), which is a different rule for a different quantity — **E16·T06**.
- The Anomaly's UTC day index and the clock-back lock — **E16·T01/T02**.
- H15's ≤ 6-rounds-to-re-converge measurement — **T12**.
- Anything a player can see. There is nothing.
