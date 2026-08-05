# T08 — The five nudges

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | Five nudges (ONBOARDING) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**. The one nudge vocabulary is two values and a period — opacity 0.55 ↔ 1.0 over 1.2 s ease-in-out, plus a single 0.4-amplitude click on the first cycle. They belong at L2 in `C.Nudge`, shared with beat 1's and beat 8's breath from T06, so that "one vocabulary" is a fact about the code and not a promise in prose. |
| `hunch-motion-and-feedback` | Owns when a cue fires and what Reduce Motion substitutes. The click is a `Cue`, fired once on the first cycle only, through the `SilentCuePlayer` seam E08·T06 established — so E20 attaches a player to a firing point that already exists and has already been timing-tested. |
| `hunch-accessibility` | Owns the suppression rule and where it lives: nudges are suppressed **at the scheduler**, not inside the animation, and the barred Seal's rail pulse and the empty-rail hairline are information rather than nudges and must not be swept up with them (`references/rotors-and-gestures.md` §10). |

## Objective

At the end of this task a stuck player is recovered by one wordless vocabulary in five situations —
idle, no-Bench, barred-Seal, global idle and unvaried — each with its own trigger, form and repeat
budget, and every one of them bound by a hard floor: a nudge may only ever say *this control exists and
is pressable*. Under VoiceOver nothing fires at all; under Reduce Motion every nudge is a pure opacity
crossfade.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.5 (The nudge) | the one vocabulary: breath, opacity 0.55 ↔ 1.0, 1.2 s ease-in-out, plus one 0.4-amplitude click on the first cycle only |
| `GAME_DESIGN.md` | §12.5 (nudge table) | all five rows: trigger threshold, form and repeat budget, verbatim |
| `GAME_DESIGN.md` | §12.5 (Hard floor on nudges) | a nudge may never indicate which cell, attribute or comparator; no auto-play, no auto-solve, no skip, no hint economy; Reduce Motion → pure opacity crossfade; VoiceOver → suppressed entirely |
| `GAME_DESIGN.md` | §12.5 (The passive path) | nudge 5's exact role: stop breathing the PROBE key, breathe the lit ramp's four cells **as a group**, never one cell |
| `GAME_DESIGN.md` | §4.3 / §13.7.2 | the barred Seal's rail pulse already exists (3 × 90 ms) — nudge 3 *adds* the sweep-highlight after it and does not re-specify the pulse |
| `GAME_DESIGN.md` | §13.7.4 | the Reduce Motion row for the barred-Seal rail and the empty-rail hairline |
| `GAME_DESIGN.md` | §9 (SIEVE) | nudge 4 fires in any round and any mode **except SIEVE** |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | the `Nudge` enum's `switch`es carry no `default:` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/NudgeSchedulerTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import LoomFeature

@Suite("The five nudges — §12.5")
struct NudgeSchedulerTests {

    private func scheduler(_ env: RenderEnv = .standard,
                           voiceOver: Bool = false) -> NudgeScheduler {
        NudgeScheduler(env: env, isVoiceOverRunning: voiceOver)
    }

    // MARK: 1 — Idle

    @Test("idle fires after 12 s with zero touches while exactly one control is lit")
    func idleFires() {
        var s = scheduler()
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 11.9))
        #expect(s.pending == nil)
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 12.0))
        #expect(s.pending == .idle(.probeKey))
    }

    @Test("idle does not fire while two controls are lit — that is what the unvaried nudge is for")
    func idleNeedsExactlyOneLitControl() {
        var s = scheduler()
        s.update(.init(litControls: [.probeKey, .ramp(.shape)], secondsSinceTouch: 30))
        #expect(s.pending == nil)
    }

    @Test("idle repeats every 20 s, at most five times, then is permanently silent for the session")
    func idleBudget() {
        var s = scheduler()
        var fired = 0
        for tick in stride(from: 12.0, through: 200.0, by: 0.5) {
            s.update(.init(litControls: [.probeKey], secondsSinceTouch: tick))
            if s.consumePending() != nil { fired += 1 }
        }
        #expect(fired == 5)
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 400))
        #expect(s.consumePending() == nil)
    }

    // MARK: 2 — No-Bench

    @Test("no-Bench fires at probes 6 and 9 only, and only while the Bench has never been opened")
    func noBenchBudget() {
        var s = scheduler()
        var firedAt: [Int] = []
        for probe in 1...15 {
            s.update(.init(probesUsed: probe, openedBench: false))
            if case .noBench = s.consumePending() { firedAt.append(probe) }
        }
        #expect(firedAt == [6, 9])
    }

    @Test("no-Bench never fires once the Bench has been opened")
    func noBenchStopsAfterOpening() {
        var s = scheduler()
        s.update(.init(probesUsed: 6, openedBench: true))
        #expect(s.pending == nil)
    }

    // MARK: 3 — Barred Seal

    @Test("barred-Seal fires on the third press with no rail edit in between")
    func barredSealNeedsThreePresses() {
        var s = scheduler()
        s.update(.barredSealPressed); s.update(.barredSealPressed)
        #expect(s.pending == nil)
        s.update(.barredSealPressed)
        #expect(s.pending == .barredSeal(rail: 0))
    }

    @Test("a rail edit resets the count — the nudge answers repetition, not frustration")
    func railEditResetsTheCount() {
        var s = scheduler()
        s.update(.barredSealPressed); s.update(.barredSealPressed)
        s.update(.railEdited)
        s.update(.barredSealPressed)
        #expect(s.pending == nil)
    }

    @Test("barred-Seal fires at most three times per round")
    func barredSealBudget() {
        var s = scheduler()
        var fired = 0
        for _ in 0..<30 { s.update(.barredSealPressed); if s.consumePending() != nil { fired += 1 } }
        #expect(fired == 3)
    }

    // MARK: 4 — Global idle

    @Test("global idle fires after 90 s in any mode except SIEVE",
          arguments: [Mode.probe, .drift, .echo])
    func globalIdleFires(_ mode: Mode) {
        var s = scheduler()
        s.update(.init(mode: mode, secondsSinceTouch: 90))
        #expect(s.pending == .globalIdle(dimming: true))
    }

    @Test("global idle never fires in SIEVE")
    func globalIdleSkipsSieve() {
        var s = scheduler()
        s.update(.init(mode: .sieve, secondsSinceTouch: 300))
        #expect(s.pending == nil)
    }

    // MARK: 5 — Unvaried

    @Test("unvaried fires at unvariedRun == 2 while sawReject is false, and breathes the cells AS A GROUP")
    func unvariedBreathesTheGroup() {
        var s = scheduler()
        s.update(.init(isOpeningRound: true,
                       ledger: .init(unvariedRun: 2, sawReject: false),
                       litRamps: [.shape]))
        #expect(s.pending == .unvaried(.rampCellGroup([.shape])))
        #expect(s.suppressedBreaths.contains(.probeKey))     // the PROBE key's breath stops
    }

    @Test("after beat 6 the group is all four ramps' cells")
    func unvariedGroupWidensAfterBeatSix() {
        var s = scheduler()
        s.update(.init(isOpeningRound: true,
                       ledger: .init(unvariedRun: 2, sawReject: false),
                       litRamps: Glyph.Attribute.allCases))
        #expect(s.pending == .unvaried(.rampCellGroup(Glyph.Attribute.allCases)))
    }

    @Test("unvaried is silent forever once a reject has been seen")
    func unvariedSilentAfterAReject() {
        var s = scheduler()
        s.update(.init(isOpeningRound: true,
                       ledger: .init(unvariedRun: 6, sawReject: true),
                       litRamps: [.shape]))
        #expect(s.pending == nil)
    }

    @Test("unvaried exists only in the opening round")
    func unvariedIsOpeningRoundOnly() {
        var s = scheduler()
        s.update(.init(isOpeningRound: false,
                       ledger: .init(unvariedRun: 9, sawReject: false),
                       litRamps: [.shape]))
        #expect(s.pending == nil)
    }

    // MARK: the hard floor, and the two environment rules

    @Test("no nudge can name a cell, a value, an attribute's contents or a comparator")
    func hardFloor() {
        for nudge in Nudge.allRepresentativeCases {
            #expect(nudge.target.isControlIdentity)
            #expect(nudge.target.namesNoValue)
            #expect(nudge.highlightedCells.count != 1)     // never one cell — always a whole control or group
        }
    }

    @Test("every nudge is suppressed under VoiceOver, at the scheduler and not in the animation")
    func voiceOverSuppression() {
        var s = scheduler(voiceOver: true)
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 300))
        s.update(.barredSealPressed); s.update(.barredSealPressed); s.update(.barredSealPressed)
        s.update(.init(probesUsed: 6, openedBench: false))
        #expect(s.pending == nil)
        #expect(s.firedCount == 0)
    }

    @Test("under Reduce Motion every nudge is a pure opacity crossfade — no scale, no translate, no tug")
    func reduceMotionForm() {
        for nudge in Nudge.allRepresentativeCases {
            let form = nudge.form(in: .reduceMotion)
            #expect(form.kind == .opacityCrossfade)
            #expect(form.translation == .zero)
            #expect(form.scale == 1.0)
        }
        #expect(Nudge.noBench.form(in: .reduceMotion).handleBehaviour == .brightenHairline)
    }

    @Test("the click fires once, on the first cycle, and never again")
    func clickFiresOnceOnTheFirstCycle() {
        var s = scheduler()
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 12))
        let first = s.consumePending()
        #expect(first?.cues == [.nudgeClick])
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 32))
        #expect(s.consumePending()?.cues.isEmpty == true)
    }

    @Test("every fired nudge increments the ledger's nudgesFired and nothing else")
    func nudgesAreCounted() {
        var ledger = OnboardingLedger()
        var s = scheduler()
        s.update(.init(litControls: [.probeKey], secondsSinceTouch: 12))
        s.consumePending()?.apply(to: &ledger)
        #expect(ledger.nudgesFired == 1)
        #expect(ledger.isComplete == false)                // a nudge changes no success field
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter NudgeSchedulerTests`

Missing `NudgeScheduler`, `Nudge`, `C.Nudge`. `idleBudget` and `barredSealBudget` are the two that will
pass accidentally if the budget is unimplemented (a scheduler that never fires also never fires six
times) — check that each fails with a **count of 0 against an expected 5 and 3**, which proves the
assertion is live.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/LoomFeature/NudgeScheduler.swift` |
| create | `Modules/Sources/LoomFeature/Nudge.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — add the `C.Nudge` namespace |
| modify | `Modules/Sources/Feedback/Cue.swift` *(or E08·T06's placeholder)* — add `nudgeClick` at amplitude 0.4 |
| modify | `Modules/Sources/LoomFeature/Round.swift` — drive the scheduler, apply fired nudges to the ledger |
| modify | `Modules/Sources/LoomFeature/RoundView.swift`, `BenchView.swift` — render the breath on the nudged control |
| create | `Modules/Tests/LoomFeatureTests/NudgeSchedulerTests.swift` |
| modify | `tests.json` — five entries (one per nudge) plus the floor, the VoiceOver and the Reduce Motion entries |

## Implementation notes

### One vocabulary, one token namespace

```swift
extension C {
    public enum Nudge {
        public static let breathLow  = 0.55                        // §12.5
        public static let breathHigh = 1.00
        public static let breathPeriod = Duration.milliseconds(1_200)
        public static let clickAmplitude = 0.4                     // first cycle only
        public static let idleThreshold = Duration.seconds(12)
        public static let idleRepeat    = Duration.seconds(20)
        public static let idleBudget    = 5
        public static let globalIdleThreshold = Duration.seconds(90)
        public static let globalIdleDim = 0.60
        public static let sweepStagger  = Duration.milliseconds(80) // nudge 3's cell sweep
        public static let barredSealBudget = 3
    }
}
```

T06's beat-1 and beat-8 breaths are the *same* animation at 0.5 Hz rather than 1.2 s — §12.5 states both
periods and they are genuinely different (the script's breath is slower). Keep `C.Onboarding.breathPeriod`
and `C.Nudge.breathPeriod` as two named tokens with the two spec values, and share `breathLow`/`breathHigh`,
because the *opacity pair* is the vocabulary and the period is the situation.

### The scheduler is a value with one owner

`NudgeScheduler` is a `struct` held by `Round`, fed a small observation record on every state change, and
producing at most one pending nudge. That shape gives the tests above and keeps timers out of the model:
the view drives elapsed time in, the scheduler never reads a clock.

Suppression is **at the scheduler**:

```swift
mutating func update(_ observation: Observation) {
    guard !isVoiceOverRunning else { return }     // §12.5 — the rotor already enumerates every control
    …
}
```

Not inside the animation, and not by setting the amplitude to zero: `hunch-accessibility`'s
`references/rotors-and-gestures.md` §10 names that as the mistake, and the reason is that a suppressed
animation still consumes its budget and still increments `nudgesFired`.

### The two things that look like nudges and are not

- **The barred Seal's rail pulse** (§4.3, 3 × 90 ms) fires on *every* barred press and is information —
  it says *which rail*. Nudge 3 fires on the third press and adds the four-cell sweep-highlight on top.
  Do not merge them; do not suppress the pulse under VoiceOver.
- **The empty-rail hairline pulse** (1.6 s loop) is a static state under Reduce Motion (§13.7.4) and is a
  rail state, not a recovery. It survives VoiceOver.

Also not a nudge: **the breath** on the twin key past 0.6·par (§6.6, E08·T07). It is a discoverability
layer, it fires in every band on the same rule, and it has its own stop condition. It shares the opacity
vocabulary and nothing else.

### The hard floor, made structural

Model the target as a type that cannot name a value:

```swift
public enum NudgeTarget: Equatable, Sendable {
    case control(OnboardingAffordance)          // "this control exists and is pressable"
    case rampCellGroup([Glyph.Attribute])       // a whole ramp's cells, as a group — never one cell
    case rail(Int)                              // which rail is unfinished, which §4.3 already shows
    case surface                                // global idle's dim
}
```

There is no case that carries a `Glyph.Fill`, a value rank, a comparator or a cell index, so
"never indicate which cell" is a thing the compiler enforces rather than a thing a reviewer checks. The
`hardFloor` test asserts the property anyway, because a future case could add one.

### Nudge 5 in one sentence

While the opening round has never produced a reject and the player has repeated themselves twice, stop
breathing the control that has nothing left to teach (PROBE) and breathe the one that does (the lit
ramps' cells, as a group), every two unvaried probes, with no limit — and go permanently silent the
instant `sawReject` turns true. It is the only nudge with no budget, and §12.5's reason is that the path
it closes is the one path on which the tutorial teaches nothing at all.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter NudgeSchedulerTests` green, all nineteen tests.
- [ ] `grep -n "case " Modules/Sources/LoomFeature/Nudge.swift` shows exactly five nudges.
- [ ] `grep -rn "0\.55\|1\.2\|0\.4\b\|12\b\|90\b" Modules/Sources/LoomFeature/NudgeScheduler.swift` returns nothing — every threshold comes from `C.Nudge`.
- [ ] `grep -rn "isVoiceOverRunning" Modules/Sources/LoomFeature/NudgeScheduler.swift` shows exactly one guard, at the top of `update`.
- [ ] No `NudgeTarget` case carries a glyph attribute *value*, a comparator or a cell index — read the enum and confirm.
- [ ] `tests.json` carries eight entries: five nudges, the hard floor, VoiceOver suppression, Reduce Motion form.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T08: the five nudges, one vocabulary, one hard floor"`

## Out of scope

- The `nudgeClick` cue's synthesis — **E20·T01/T03**; this task fires a named `Cue` through the silent seam.
- The barred Seal's rail pulse itself — **E09·T07**.
- The twin key's breath past 0.6·par — **E08·T07**.
- VoiceOver element identity and wording — **E19·T01/T10**.
- Every *other* Reduce Motion substitution in the round — **E09·T12**.
- Rendering the global-idle dim over the Frame — **E17·T03**; in a round it is the round's own surface.
