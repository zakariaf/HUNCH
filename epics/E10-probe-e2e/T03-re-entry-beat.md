# T03 — The 900 ms re-entry beat

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Mid-round snapshot (the re-entry half) · Leaving a round (the returning half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | This task adds a duration and a stagger to the token module. Load it **first**: the 900 ms total and its four stage bounds land at L2 as `C.ReEntry.*` in `HunchCore/Sources/Tokens/C.swift`, referencing L1 only, and a literal `0.9` in a view fails hygiene check 9. |
| `hunch-motion-and-feedback` | Owns beat sheets and what happens when. The re-entry beat is a *fourth* beat sheet alongside the verdict, the reveal and the 600 ms spin-up, and this skill's `references/transitions.md` §§4–5 and §9 hold the spin-up it must not be confused with and the Reduce Motion form it copies. It also owns the rule that the model never waits on an animation — the round is already `probing` before the first frame. |

## Objective

At the end of this task a cold launch with a live snapshot lands the player **inside the round** — phase
`probing` from the first frame, Bench collapsed, draft intact — and the surface re-reads itself over
900 ms in one order: par ticks, ribbon, docked counterexample, throat. Input is locked for the whole
beat, the par crossing is restored rather than replayed, and there is no dialog and no "Resume?" button
anywhere in the path.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.10 (Relaunch) | the beat verbatim: 900 ms, par ticks leading→trailing, the crossing **restored not replayed**, the ribbon scroll, the docked counterexample, the throat last, input locked, no dialog |
| `GAME_DESIGN.md` | §6.1 (transition table) | `arming → probing` on a passing integrity hash, with the note that the phase is `probing` **from its first frame** and the beat is decoration over it |
| `GAME_DESIGN.md` | §6.11 #27, #28 | returning without abandoning costs nothing; backgrounded with the Bench up then cold-launched resumes into `probing` with the Bench collapsed and the draft intact |
| `GAME_DESIGN.md` | §6.9 (par crossing) | what the crossing *is*, so that restoring it means drawing its end state and not firing its event |
| `GAME_DESIGN.md` | §6.8 (1,300–1,600 ms) | the counterexample docks below the ribbon's trailing end as a marginal island and stays for the rest of the round — which is why it re-appears docked, not travelling |
| `GAME_DESIGN.md` | §12.7 | the `.active` 600 ms spin-up, which is a **different** event in a live process and is E17·T09's |
| `GAME_DESIGN.md` | §13.7.4 | the Reduce Motion doctrine: substitute, never delete the information the motion carried |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | durations are `HunchUI`/L2, transitions are core — which is why the *schedule* is a value and only its playback is a view |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/ReEntryBeatTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import LoomFeature

@Suite("The 900 ms re-entry beat — §6.10")
struct ReEntryBeatTests {

    private func beat(probes: Int, par: Int = 7, counterexample: Bool = false,
                      env: RenderEnv = .standard) -> ReEntryBeat {
        ReEntryBeat(snapshot: .fixture(probes: Array(0..<UInt8(probes)),
                                       counterexample: counterexample ? .init(cur: 40, prev: nil) : nil),
                    par: par, in: env)
    }

    @Test("four stages fill the beat, in §6.10's order, and the throat lights last")
    func stageOrderAndTotal() {
        let b = beat(probes: 5)
        #expect(b.stages.map(\.kind) == [.parTicks, .ribbon, .counterexample, .throat])
        #expect(b.duration == C.ReEntry.total)
        #expect(b.stages.first?.start == .zero)
        #expect(b.stages.last?.end == b.duration)
        #expect(zip(b.stages, b.stages.dropFirst()).allSatisfy { $0.end <= $1.start })
    }

    @Test("input is locked for the whole beat and unlocks exactly at its end")
    func inputLockedThroughout() {
        let b = beat(probes: 5)
        #expect(b.inputUnlocksAt == b.duration)
        #expect(b.isInputLocked(at: .zero))
        #expect(b.isInputLocked(at: b.duration - .milliseconds(1)))
        #expect(!b.isInputLocked(at: b.duration))
    }

    @Test("par ticks re-fill leading to trailing")
    func parTicksFillInOrder() {
        let b = beat(probes: 5, par: 7)
        let ticks = b.parTickSchedule
        #expect(ticks.count == 5)                                     // one per probe already spent
        #expect(ticks == ticks.sorted())                              // strictly leading → trailing
        #expect(ticks.last! <= b.stage(.parTicks).end)
    }

    @Test("past par the crossing is RESTORED, not replayed")
    func crossingRestoredNotReplayed() {
        let b = beat(probes: 9, par: 7)
        #expect(b.parRow == .invertedFromFirstFrame)
        #expect(b.capRow == .emptyingFromFirstFrame(remaining: 9 - 7))
        #expect(!b.stages.contains { $0.kind == .parCrossing })
        #expect(b.cues.isEmpty)                                        // the crossing has no cue anyway (§6.9)
    }

    @Test("below par the row is simply partially filled and the cap row stays dim")
    func belowParNoInversion() {
        let b = beat(probes: 5, par: 7)
        #expect(b.parRow == .filling(5, of: 7))
        #expect(b.capRow == .dim)
    }

    @Test("a docked counterexample re-appears docked; without one the stage is empty and the order holds")
    func counterexampleStage() {
        let withCE = beat(probes: 5, counterexample: true)
        #expect(withCE.stage(.counterexample).content == .dockedIsland)
        let withoutCE = beat(probes: 5, counterexample: false)
        #expect(withoutCE.stage(.counterexample).content == .none)
        #expect(withoutCE.stages.map(\.kind) == withCE.stages.map(\.kind))
        #expect(withoutCE.duration == withCE.duration)                 // the beat does not shorten
    }

    @Test("resume enters probing with the Bench collapsed and the draft intact (§6.11 #28)")
    func resumeEntersProbing() {
        let draft = BenchLayout.singleRamp(attribute: .shape, values: [.triangle])
        let snapshot = ProbeSnapshot.fixture(probes: [22, 30], draft: draft)
        let entry = RoundEntryPlan(snapshot: snapshot, par: 7, in: .standard)
        #expect(entry.phase == .probing)
        #expect(entry.isBenchOpen == false)
        #expect(entry.draft == draft)
        #expect(entry.prompt == nil)                                   // no dialog, ever
    }

    @Test("a failed integrity hash never plays the beat — it opens the round card (§6.1)")
    func voidedSkipsTheBeat() {
        var snapshot = ProbeSnapshot.fixture(probes: [22])
        snapshot.lawHash ^= 1
        let entry = RoundEntryPlan(snapshot: snapshot, par: 7, in: .standard)
        #expect(entry.phase == .settled(.voided))
        #expect(entry.beat == nil)
    }

    @Test("Reduce Motion keeps the stagger and its direction; only translation is dropped")
    func reduceMotionSubstitution() {
        let normal = beat(probes: 5)
        let reduced = beat(probes: 5, env: .reduceMotion)
        #expect(reduced.duration == normal.duration)
        #expect(reduced.stages.map(\.kind) == normal.stages.map(\.kind))
        #expect(reduced.stages.allSatisfy { $0.form == .opacity })
        #expect(normal.stages.contains { $0.form == .translate })
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter ReEntryBeatTests`

Failures must be missing symbols — `ReEntryBeat`, `RoundEntryPlan`, `C.ReEntry` — not arithmetic. A test
that goes green before `ReEntryBeat` exists means the assertions are reading defaults; delete and rewrite.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/LoomFeature/ReEntryBeat.swift` |
| create | `Modules/Sources/LoomFeature/RoundEntryPlan.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — play the beat on appear when the plan carries one |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `init(resuming:)` and the input lock for the beat's duration |
| modify | `HunchCore/Sources/Tokens/C.swift` — add the `C.ReEntry` namespace |
| create | `Modules/Tests/LoomFeatureTests/ReEntryBeatTests.swift` |
| modify | `tests.json` — three entries (stage order + total, input lock, crossing restored) |
| modify | `DECISIONS.md` — the Reduce Motion form of the re-entry beat |

## Implementation notes

### Why the schedule is a value

§6.10 gives four things that happen and one order they happen in; nothing about them needs a view. Model
the beat as a `Sendable` value with an array of stages and let `RoundView` play it. That buys the eight
assertions above at host speed and keeps `phaseAnimator` out of the test.

```swift
public struct ReEntryBeat: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case parTicks, ribbon, counterexample, throat }
    public enum Form: Equatable, Sendable { case translate, opacity }
    public enum Content: Equatable, Sendable { case none, dockedIsland, tiles(Int), ticks(Int), glyph }

    public struct Stage: Equatable, Sendable {
        public let kind: Kind
        public let start: Duration
        public let end: Duration
        public let form: Form
        public let content: Content
    }

    public let stages: [Stage]
    public var duration: Duration { C.ReEntry.total }
    public var inputUnlocksAt: Duration { duration }
}
```

`Duration` and never `Double` (`hunch-design-tokens/references/tokens-swift-layout.md` §2's rule).

### The four stages

Divide `C.ReEntry.total` into the four windows at L2, one constant each, with the stagger *inside*
`parTicks` and `ribbon` derived from the count so a long ribbon never overruns:

```swift
extension C {
    public enum ReEntry {
        public static let total = Duration.milliseconds(900)   // §6.10
        public static let parTicks   = Duration.milliseconds(0)   ..< .milliseconds(240)
        public static let ribbon     = Duration.milliseconds(240) ..< .milliseconds(600)
        public static let counterexample = Duration.milliseconds(600) ..< .milliseconds(760)
        public static let throat     = Duration.milliseconds(760) ..< .milliseconds(900)

        /// The stagger is capped so the total never moves — the same rule the 600 ms spin-up uses
        /// (`hunch-motion-and-feedback/references/transitions.md` §5): items past the cap arrive together.
        public static func stagger(count: Int, within window: Range<Duration>) -> [Duration]
    }
}
```

The four sub-windows are this task's own composition of §6.10's stated order and total; record them in
`DECISIONS.md` as *derived*, not as spec, so nobody later mistakes them for quoted numbers.

### The crossing, restored

This is the one place the beat could be wrong in a way that looks right. §6.9's crossing is an **event**:
the par row inverts to a solid rule and the cap row lights and begins emptying, once, permanently, on the
probe that fills the last tick. Restoring means:

- `parRow == .invertedFromFirstFrame` — the row is drawn already inverted at t = 0 of the beat;
- `capRow == .emptyingFromFirstFrame(remaining:)` — the cap row is already lit and already partly emptied;
- **no crossing animation, no cue, no haptic** is emitted (§6.9 gives the crossing no audio and no haptic
  even when it *does* fire, so an emitted cue here would be a bug twice over);
- the par ticks still fill leading→trailing during the beat, because that is the row re-reading itself,
  not the crossing re-firing.

### The counterexample stage

A docked counterexample re-appears **already docked** below the ribbon's trailing end (§6.8's 1,300–1,600
ms beat put it there and said it stays for the rest of the round). It does not travel from the Assay, it
does not re-take its two rings, and the stage is a fade-in of the marginal island. When the snapshot
carries none, the stage stays in the timeline with `.none` content and the beat does not shorten — a
variable-length re-entry would leak whether the player has struck out before the first frame.

### No dialog, and how that stays true

`RoundEntryPlan.prompt` is `Never?`-shaped in intent: there is no type that could carry a resume question.
Assert it structurally rather than by comment —

```bash
grep -rn "\.alert(\|\.confirmationDialog(" Modules/Sources/LoomFeature   # must be empty
```

and hygiene check 7 already bans `Text`/`Label` in `RoundView.swift` outside `.accessibility*`, so a
"Resume?" string cannot appear even by accident.

### The two beats that are not this one

- **The 600 ms `.active` spin-up** (§12.7) happens when a *live* process comes back to the foreground.
  Different trigger, different duration, different owner (E17·T09). Do not merge them and do not share a
  token; borrowing one for the other is how two surfaces end up sharing a value only one of them wanted.
- **The 420 ms verdict beat** (§6.5) is E08·T06's. The re-entry beat never plays one, even if the app died
  mid-beat: §6.11 #5 says the verdict was committed at t = 0 and the animation is simply skipped.

### VoiceOver

Under VoiceOver the beat still runs (it locks input for 900 ms either way) but posts nothing: the round
resumes into a surface whose elements are already labelled, and an announcement here would arrive before
the player has asked anything. Element identity is E19·T01's.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter ReEntryBeatTests` green, all nine tests.
- [ ] `grep -rn "0\.9\|900" Modules/Sources/LoomFeature/ReEntryBeat.swift` returns nothing — the total comes from `C.ReEntry.total`.
- [ ] `grep -rn "\.alert(\|\.confirmationDialog(\|Resume" Modules/Sources/LoomFeature` returns nothing.
- [ ] `Scripts/check-source-hygiene.sh` check 9 (no literal duration outside `Tokens/`) passes over the new files.
- [ ] Simulator check, recorded in the task's commit message: launch with a suspended round past par, confirm the par row is solid on the first frame and the cap row is already partly emptied.
- [ ] `tests.json` carries the three entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T03: the 900 ms re-entry beat, input-locked, crossing restored"`

## Out of scope

- The 600 ms `.active` spin-up and the full `scenePhase` table — **E17·T09**.
- The par tick row and cap row drawings themselves — **E08·T08**; this task only says what state they enter in.
- The counterexample's selection and its two-ring presentation — **E06·T08** and **E09·T09**.
- DRIFT's resume, which must additionally neither re-fire nor un-fire the hinge — **E12·T09**.
- ECHO's resume and its one free cast restart — **E13·T09**.
- Reduce Motion for every *other* animation in the round — **E09·T12**.
