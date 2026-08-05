# T06 — One replay

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P1 |
| **Size** | S |
| **Depends on** | T05 |
| **Delivers** | One replay (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-bench-instruments` | The commit bar and its two keys are this skill's row, and the twin key already exists with a meaning — *do that again* — that ECHO borrows rather than reinvents. The skill also owns the states a commit-bar key may be in, which is what decides that a spent replay is a **drawn** state and not a disappeared control. |
| `hunch-swift-code` | "Impossible to press twice" is a claim about a type, not about a guard. This skill owns the ruling that the replay's availability is modelled as state on `EchoRound` with a `private(set)` setter and a single mutating entry point, so a second call cannot compound the score multiplier from two places. |

## Objective

At the end of this task the player can see the cast a second time, exactly once, at a known price:
the twin key replays it at a ×0.6 score multiplier, stays live for the whole of `recalling`, never
clears the rail, and after it is used it is a drawn spent state rather than a control that vanished.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.3 (third bullet) | the twin key — already meaning *do that again* in PROBE — replays the cast **exactly once per round** at a score cost of ×0.6; it stays live during recall and never clears the rail |
| `GAME_DESIGN.md` | §8.5 (`recalling → casting` row) | the transition is `twin key, first use`; the rail is preserved; `replayed = true` |
| `GAME_DESIGN.md` | §8.7 | `replayF = replayed ? 0.6 : 1.0` — a single factor, never compounded |
| `GAME_DESIGN.md` | §8.10 REPLAY-MID-PLACEMENT | the twin key with tiles already on the rail: the replay runs, the rail is preserved, `replayF` drops to 0.6; only one replay exists, so it cannot be pressed twice |
| `GAME_DESIGN.md` | §8.4 | commit bar 604–667: twin/replay leading at 44 pt, Seal trailing at 44 pt |
| `GAME_DESIGN.md` | §8.9 | `replayed` is persisted with the round, so a suspended round cannot buy a second viewing |
| `GAME_DESIGN.md` | §14.5 open decision 8 | the free replay **is** ECHO's accommodation; there is no slow-cast setting, because cadence is the difficulty knob |
| `GAME_DESIGN.md` | §6.6 layer 3 | the twin key is present from round 1 in every mode, which is why it needs no explanation here |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`Modules/Tests/LoomFeatureTests/EchoReplayTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature
import ModulesTestSupport

@Suite("One replay — §8.3, §8.10 REPLAY-MID-PLACEMENT", .tags(.unit, .presubmission))
@MainActor
struct EchoReplayTests {

    @Test("the key is live during recall and replays the same cast, not a new one")
    func replayRunsTheSameCast() {
        let round = Fixtures.echoRound(phase: .recalling)
        let before = round.cast
        round.replay()
        #expect(round.phase == .casting)
        #expect(round.cast == before)            // the cast is a value; nothing is re-sampled
        #expect(round.castPosition == 0)
    }

    @Test("a replay preserves the rail — REPLAY-MID-PLACEMENT")
    func replayPreservesTheRail() {
        let round = Fixtures.echoRound(phase: .recalling)
        for index in [5, 1, 9] { round.tapTray(castIndex: index) }
        round.replay()
        #expect(round.rail.placed == [5, 1, 9])
        for _ in 0..<round.cast.glyphs.count { round.advanceCast() }
        #expect(round.phase == .recalling)
        #expect(round.rail.placed == [5, 1, 9])
        #expect(round.trayState(of: 5) == .placed(position: 1))
    }

    @Test("the multiplier is applied once and never compounds")
    func multiplierDoesNotCompound() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.replay()
        round.replay()                            // refused
        round.replay()                            // refused
        #expect(round.replayed)
        #expect(round.replayFactor == 0.6)
        #expect(round.replayFactor != 0.6 * 0.6)
    }

    @Test("a second press cannot re-enter casting")
    func secondPressIsRefused() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.replay()
        for _ in 0..<round.cast.glyphs.count { round.advanceCast() }
        #expect(round.phase == .recalling)

        round.replay()
        #expect(round.phase == .recalling)         // still recalling; the key did nothing
    }

    @Test("the key is inert during the first cast — it is a recall affordance only")
    func inertDuringTheFirstCast() {
        let round = Fixtures.echoRound(phase: .casting)
        round.replay()
        #expect(!round.replayed)
        #expect(round.castPosition == 0)
    }

    @Test("the key draws a spent state rather than disappearing")
    func spentIsADrawnState() {
        let round = Fixtures.echoRound(phase: .recalling)
        let probe = { RenderProbe(EchoRoundView(round: round, env: .reference)) }
        #expect(probe().keyState(.replayKey) == .idle)
        round.replay()
        for _ in 0..<round.cast.glyphs.count { round.advanceCast() }
        #expect(probe().keyState(.replayKey) == .spent)
        #expect(probe().roles(at: .commitBar) == [.replayKey, .seal])   // it did not vanish
    }

    @Test("a spent replay is not interactive and says so to VoiceOver")
    func spentIsNotInteractive() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.replay()
        for _ in 0..<round.cast.glyphs.count { round.advanceCast() }
        let element = AccessibilityProbe(EchoRoundView(round: round, env: .reference)).element(.replayKey)
        #expect(element.isEnabled == false)
        #expect(element.value == Loc.replaySpent)
    }

    @Test("`replayed` survives suspension, so quitting cannot buy a second viewing")
    func replayedIsPersisted() throws {
        let round = Fixtures.echoRound(phase: .recalling)
        round.replay()
        let snapshot = round.snapshot()
        let restored = EchoRound(restoring: snapshot, dependencies: .preview())
        #expect(restored.replayed)
        #expect(restored.replayFactor == 0.6)
    }

    @Test("the breath never fires in ECHO — there is no par for it to key off")
    func noBreathInEcho() {
        let round = Fixtures.echoRound(phase: .recalling)
        #expect(round.scheduledBreath == nil)
    }
}
```

**Step 2 — run it and watch it fail.**
`xcodebuild test … -only-testing:LoomFeatureTests/EchoReplayTests`. Missing symbols only.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/LoomFeature/EchoRound.swift` — `replay()`, `replayed`, `replayFactor` |
| modify | `Modules/Sources/LoomFeature/EchoRoundView.swift` — the commit bar's leading key |
| modify | `Modules/Sources/HunchUI/Loc.swift` — one accessibility value |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — one key |
| create | `Modules/Tests/LoomFeatureTests/EchoReplayTests.swift` |
| modify | `tests.json` — two entries |

## Implementation notes

### One entry point, one flag

```swift
// Modules/Sources/LoomFeature/EchoRound.swift
public private(set) var replayed = false

/// §8.3: exactly once per round, at ×0.6. §8.5: `recalling --twin key, first use--> casting`.
public func replay() {
    guard phase == .recalling, !replayed else { return }
    replayed = true                       // committed at t = 0, before any frame moves
    castPosition = 0
    phase = .casting                      // the rail is untouched; nothing else is reset
}

/// §8.7's `replayF`. A factor, not an accumulator.
public var replayFactor: Double { replayed ? EchoScore.replayPenalty : 1.0 }
```

The two things this shape prevents, both of which are real bugs and one of which is subtle:

- **Compounding.** `replayFactor` is *derived* from a `Bool`, so it cannot be multiplied twice. A `var multiplier = 1.0; multiplier *= 0.6` in `replay()` would give 0.36 to anyone who found a way to call it twice, and the guard is then the only thing standing between the player and a silently halved score. Derive; do not accumulate.
- **Clearing the rail.** `replay()` touches `castPosition` and `phase` and nothing else. Re-entering `casting` through a shared "start the cast" helper that also initialises the rail is exactly how REPLAY-MID-PLACEMENT breaks, so the first cast's entry and the replay's entry stay two call sites even though they are three lines each — or, if they are unified, the helper takes `resetRail: Bool` and this call site passes `false` explicitly.

`EchoScore.replayPenalty` is T08's constant with its §8.7 citation. If T08 has not landed, declare it
here and let T08 move it into `EchoScore` — one home, and the home is the file that owns the formula.

### When the key is live, and what it looks like when it is not

| Phase | Key | Why |
|---|---|---|
| `priming`, `primer` | inert | there is nothing to replay yet |
| `casting` (first) | inert | §8.5 lists the transition only from `recalling`; a mid-cast restart is what an *interruption* does (T09), and it is free exactly once — conflating the two would give the player two free viewings |
| `recalling`, `replayed == false` | live | §8.3: "It stays live during recall" |
| `casting` (replay) | inert | already spent |
| `recalling`, `replayed == true` | **spent** | drawn, not removed |
| `adjudicating` onward | inert | the commit is final |

**Spent is a drawn state.** `hunch-bench-instruments`' key states include a disabled rendering, and a
control that disappears when used is worse than one that dims: the commit bar would reflow under the
thumb between two taps, which §12.8 tier 1 exists to prevent — *"the thing that ends a decision is
always in the same place under the same thumb"*. Keep the two keys and their positions fixed for the
whole round.

### What a replay is not

- **Not an interruption.** `interruptions` (T09) counts departures from `casting` caused by the system or by leaving the app. A replay is the player choosing to look again, and it is priced. §8.9's closing sentence is the check: *"since the replay is already free once, an interruption cannot buy a second viewing"* — which is only true if the two counters are separate.
- **Not a re-roll.** The cast is a value built at `arming`; `replay()` re-presents it. Nothing is re-sampled, the truth set does not move, and the tray does not re-sort.
- **Not the breath.** E08·T07's breath pulses the twin key past `0.6·par` in PROBE. ECHO has no par, no probes and no `probesUsed`, so the breath is not scheduled here at all — asserted, because a breath firing on ECHO's replay key would be a nudge telling the player to spend 40 % of their score.
- **Not an accessibility setting.** §14.5 open decision 8 rules out a slow-cast option: cadence is ECHO's difficulty knob, so a cadence control is a difficulty picker in disguise. The free replay is the accommodation, VoiceOver already gets step mode, and the decision is revisited only if playtesting shows *set* accuracy failing for motor rather than reasoning reasons. Do not add a setting here.

### Persistence

`replayed` is one of the nine fields §8.9 persists. It rides in `EchoSnapshot` (T09) and is restored
on resume, which is what closes the "suspend to get a second viewing" loop. The test above asserts the
round-trip now, against whatever snapshot shape T09 will finish; if `EchoRound(restoring:)` does not
exist yet, add the minimum initialiser this test needs and let T09 complete it.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/EchoReplayTests` green, all nine.
- [ ] `grep -n "\*= 0.6\|\* 0.6" Modules/Sources/LoomFeature/EchoRound.swift` returns nothing — the factor is derived.
- [ ] `grep -n "rail" Modules/Sources/LoomFeature/EchoRound.swift` shows no assignment to `rail` inside `replay()`.
- [ ] `Localizable.xcstrings` gained exactly one key and the total is still ≤ 250.
- [ ] `tests.json` carries two entries: one replay per round with no compounding, and rail preservation across a replay.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T06: the one replay, priced at 0.6 and impossible to press twice"`

## Out of scope

- Applying `replayF` to the score — **T08**; this task exposes the factor.
- The free cast restart after one interruption, and abandonment after a second — **T09**; a replay and an interruption are different counters and that separation is the point.
- The twin key's PROBE behaviour and the breath — **E08·T07**.
- Audio or haptic feedback on the press — **E20**.
