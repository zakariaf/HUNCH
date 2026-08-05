# T06 — The verdict beat

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T05 |
| **Delivers** | §14.1 PROBE → *Verdict beat* · §14.1 PROBE → *Admit / reject encoding* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Every duration and easing in the beat is `Dur.*` / `Easing.*`; a numeric `duration:` fails hygiene check 9. The skill also owns the six Reduce Motion substitution durations, four of which were raw numbers in §13.7.4 and must not be re-typed here. Load it first. |
| `hunch-motion-and-feedback` | `references/verdict-motion.md` is this task's normative file, and the SKILL's **three-clocks table** (commit · input lock · decoration) is the single thing that stops this beat being written wrong. It also owns `references/feedback-target.md`, the shape of the `Feedback` target. |
| `hunch-shared-marks` | The verdict ring's static geometry — base radius, weight, gap, arc count, and the 1.18 R static-closed radius Reduce Motion freezes at — is `references/verdict-ring.md`'s. This task owns only how it moves. |
| `hunch-swift-concurrency` | The beat needs one `Task` on the `@MainActor` to expire the lock. The skill's isolation table, the "no `Task.detached`" rule and the escape-hatch budget (exactly one, and it is not this) decide what that task is allowed to be. |

## Objective

Pressing PROBE computes and commits the verdict at t = 0, locks input for 420 ms (320 ms under Reduce Motion) with a constant 260 ms adjudication hold in the middle, and honours exactly one queued tap at the unlock with a compressed travel; a second tap during the lock is dropped and the Seal never queues at all. The `Cue` vocabulary exists as data behind a `CuePlayer` seam whose only shipped implementations here are `SilentCuePlayer` and `RecordingCuePlayer`, so E20 attaches engines to firing points that already exist and have already been timing-tested.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.5 | The whole beat, row by row; the constant-hold decision; fast probing and the single-slot queue; the input-lock-versus-ring-animation clarification; the Reduce Motion shortening to 320 ms |
| `GAME_DESIGN.md` | §6.1 | "The model never waits on an animation": every verdict is committed at t = 0 and merely displayed later, so killing the app mid-animation loses nothing |
| `GAME_DESIGN.md` | §6.4 | The three-channel encoding — geometry primary, colour, audio, haptic — and that any one alone is sufficient |
| `GAME_DESIGN.md` | §6.11 cases 5, 10, 11 | Backgrounded during the beat; double-tap on PROBE inside the lock; double-tap on the Seal |
| `GAME_DESIGN.md` | §13.7.2, §13.7.4 | The admit and reject micro-responses, and their Reduce Motion substitutions |
| `hunch-motion-and-feedback` | `references/verdict-motion.md` §1–§5, §9, §11, §13 | The beat table, admit, reject, twin, the Swift shape, the substitutions and the thirteen ways to get it wrong |
| `hunch-motion-and-feedback` | `references/feedback-target.md` §1–§4, §6–§7 | Why `Feedback` is its own target, `Cue`'s twelve cases, the `CuePlayer` protocol, isolation, injection, `RecordingCuePlayer` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §7.3 | `01 P12` — create a target the day its owner section is implemented, not on day one |

## TDD — the test comes first

**Step 1 — write the failing test.** Three suites: the beat's policy, the input gate's state machine, and the cue firing points.

`Modules/Tests/LoomFeatureTests/VerdictBeatTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import LoomFeature

@Suite("The 420 ms verdict beat", .tags(.unit, .presubmission))
struct VerdictBeatTests {

    @Test("The input lock is 420 ms, and 320 ms under Reduce Motion")
    func inputLock() {
        #expect(VerdictBeat(reduceMotion: false).inputLock == .milliseconds(420))
        #expect(VerdictBeat(reduceMotion: true).inputLock == .milliseconds(320))
    }

    @Test("The adjudication hold is 260 ms in both motion modes")
    func holdSurvivesReduceMotion() {
        #expect(VerdictBeat(reduceMotion: false).adjudicationHold == .milliseconds(260))
        #expect(VerdictBeat(reduceMotion: true).adjudicationHold == .milliseconds(260))
    }

    @Test("Travel is what is left of the lock, and compresses to 180 ms for a queued probe")
    func travel() {
        let beat = VerdictBeat(reduceMotion: false)
        #expect(beat.travel(queued: false) == beat.inputLock - beat.adjudicationHold)
        #expect(beat.travel(queued: true) == .milliseconds(180))
    }

    /// §6.5's decision, asserted rather than trusted: *variable latency is a side channel*.
    @Test("The hold does not depend on the verdict, the band, or whether the law is contextual",
          arguments: Band.allCases)
    func theHoldIsConstant(_ band: Band) {
        let stateless = VerdictBeat(reduceMotion: false)
        for verdict in [Verdict.admit, .reject] {
            #expect(stateless.adjudicationHold(for: verdict, band: band) == stateless.adjudicationHold)
        }
    }

    /// The stronger version of the same claim: the type has nothing to condition on.
    @Test("VerdictBeat is a function of the motion setting alone")
    func theBeatKnowsNothingElse() {
        #expect(VerdictBeat(reduceMotion: false) == VerdictBeat(reduceMotion: false))
        #expect(VerdictBeat(reduceMotion: false) != VerdictBeat(reduceMotion: true))
    }
}
```

`Modules/Tests/LoomFeatureTests/InputGateTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import LoomFeature

@Suite("The single-slot input queue", .tags(.unit, .presubmission))
struct InputGateTests {

    @Test("An unlocked gate fires immediately and locks")
    func firesWhenOpen() {
        var gate = InputGate()
        #expect(gate.request(.probe(Fixtures.seedGlyph)) == .fires)
        #expect(gate.isLocked)
        #expect(gate.queued == nil)
    }

    @Test("One tap during the lock is queued; the second is dropped — §6.11 case 10")
    func oneSlotOnly() {
        var gate = InputGate()
        _ = gate.request(.probe(Deck.glyph(id: 1)))
        #expect(gate.request(.probe(Deck.glyph(id: 2))) == .queued)
        #expect(gate.request(.probe(Deck.glyph(id: 3))) == .dropped)
        #expect(gate.queued == .probe(Deck.glyph(id: 2)))
    }

    @Test("The queued action fires at the unlock and re-locks the gate")
    func queuedFiresAtUnlock() {
        var gate = InputGate()
        _ = gate.request(.probe(Deck.glyph(id: 1)))
        _ = gate.request(.twin)
        #expect(gate.unlock() == .twin)
        #expect(gate.isLocked)                      // the queued action opened its own beat
        #expect(gate.queued == nil)
        #expect(gate.unlock() == nil)
        #expect(gate.isLocked == false)
    }

    @Test("The twin key shares the one slot with the PROBE key")
    func oneQueueForBothKeys() {
        var gate = InputGate()
        _ = gate.request(.twin)
        #expect(gate.request(.probe(Deck.glyph(id: 4))) == .queued)
        #expect(gate.request(.twin) == .dropped)
    }

    @Test("The Seal is edge-triggered and never queues — §6.11 case 11")
    func theSealHasNoQueue() {
        var gate = InputGate()
        #expect(gate.requestSeal() == .fires)
        _ = gate.request(.probe(Fixtures.seedGlyph))
        #expect(gate.requestSeal() == .dropped)
        #expect(gate.queued == nil)
    }
}
```

`Modules/Tests/LoomFeatureTests/VerdictCueTests.swift`:

```swift
import Testing
import HunchCore
import Feedback
import ModulesTestSupport
import LoomFeature

@Suite("What the beat fires, and when", .tags(.unit, .presubmission))
@MainActor
struct VerdictCueTests {

    @Test("A probe fires probeSubmit at t = 0 and the verdict cue at the end of the hold")
    func cueOrder() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)

        round.probe(Fixtures.seedGlyph)
        #expect(recorder.cues == [.probeSubmit])                  // committed and announced at t = 0
        round.landVerdict()                                       // the end of the 260 ms hold
        #expect(recorder.cues.count == 2)
        #expect(recorder.cues.last == .verdict(round.ribbon.probes[0].verdict, isTwin: false))
        round.endVerdictBeat()
        #expect(recorder.cues.count == 2)                         // the unlock is silent
    }

    @Test("The verdict is in the ribbon before any cue for it is played")
    func commitPrecedesFeedback() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)
        round.probe(Fixtures.seedGlyph)
        #expect(round.ribbon.probes.count == 1)
        #expect(recorder.cues.contains { if case .verdict = $0 { true } else { false } } == false)
    }

    @Test("SilentCuePlayer is a legitimate implementation, not a stub")
    func silenceIsAnImplementation() {
        let round = Fixtures.round(cues: SilentCuePlayer())
        round.probe(Fixtures.seedGlyph)
        round.landVerdict()
        #expect(round.ribbon.probes.count == 1)                   // geometry alone carries the verdict
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/VerdictBeatTests \
  -only-testing:LoomFeatureTests/InputGateTests \
  -only-testing:LoomFeatureTests/VerdictCueTests
```

Expect `no such module 'Feedback'` and `cannot find 'VerdictBeat' in scope`. **Never** fix a red test here by adding a `Task.sleep` to it (`06 T27`): the beat's clock is driven from the test by calling `landVerdict()` and `endVerdictBeat()` directly, which is exactly why they exist as methods.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/Feedback/Cue.swift` |
| create | `Modules/Sources/Feedback/CuePlayer.swift` |
| create | `Modules/Sources/LoomFeature/VerdictBeat.swift` |
| create | `Modules/Sources/LoomFeature/CommitKey.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` |
| modify | `Modules/Sources/HunchUI/ThroatView.swift` |
| modify | `Modules/Package.swift` |
| modify | `Modules/Sources/ModulesTestSupport/Fixtures.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| create | `Modules/Tests/LoomFeatureTests/VerdictBeatTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/InputGateTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/VerdictCueTests.swift` |
| modify | `DECISIONS.md` |

## Implementation notes

### The three clocks, and which one gates input

| Clock | Governs | Where it is written |
|---|---|---|
| **commit** | when state becomes true | t = 0, always. `Round.commit` mutates, then the animation starts. |
| **input lock** | when the next tap is accepted | 420 ms (320 under Reduce Motion). The Seal is edge-triggered; PROBE and twin share one slot. |
| **decoration** | when pixels stop moving | outlives the lock by design — the admit ring finishes at 520 ms, 100 ms after input unlocks. |

§13.7.2 calls the micro-responses "never blocking". **That is true of the rings and false of the beat.** Read its timings as offsets into §6.5's 260–520 ms window, never as an input policy. Most bugs in this task are a clock confusion, not a curve.

### `VerdictBeat` — policy as a value

```swift
/// §6.5's input policy. Not `Dur.*` tokens: these are *input* durations, not animation durations,
/// and `hunch-motion-and-feedback` rules that they have exactly one home, which is here.
public struct VerdictBeat: Equatable, Sendable {
    public let reduceMotion: Bool
    public init(reduceMotion: Bool)

    public var inputLock: Duration          // 420 · 320
    public var adjudicationHold: Duration   // 260, both modes
    public func travel(queued: Bool) -> Duration

    /// Deliberately ignores both arguments. It exists so that a future "optimisation" that makes
    /// the hold depend on the verdict or the band has to delete a test to land (§6.5).
    public func adjudicationHold(for verdict: Verdict, band: Band) -> Duration { adjudicationHold }
}
```

The constant hold is not an implementation detail. A Loom that "thinks harder" about hard glyphs leaks the family before probe 3, and the real evaluation cost is 5 ns to 0.4 µs, so there is nothing to optimise anyway.

### `InputGate` — the single slot

```swift
public struct InputGate: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case probe(Glyph), twin }
    public enum Disposition: Equatable, Sendable { case fires, queued, dropped }

    public private(set) var isLocked = false
    public private(set) var queued: Action?

    public mutating func request(_ action: Action) -> Disposition
    public mutating func requestSeal() -> Disposition     // never queues; `.dropped` while locked
    public mutating func unlock() -> Action?              // returns the queued action and re-locks
}
```

A pure value, so the whole policy is testable with no clock. `Round` holds one and drives it:

```swift
public func probe(_ glyph: Glyph) {
    switch gate.request(.probe(glyph)) {
    case .fires:  beginBeat(.probe(glyph), queued: false)
    case .queued, .dropped: break                     // §6.11 case 10 — silently, no feedback
    }
}

private func beginBeat(_ action: InputGate.Action, queued: Bool) {
    let probe = makeProbe(action)
    commit(probe)                                      // t = 0 — the verdict is now true
    cues.play(.probeSubmit)
    beatTask = Task { [beat] in
        try? await Task.sleep(for: beat.adjudicationHold)
        landVerdict()                                  // t = 260
        try? await Task.sleep(for: beat.travel(queued: queued))
        endVerdictBeat()                               // t = 420 / 320
    }
}
```

Four constraints on that `Task`:

1. It inherits `@MainActor` from `Round` — **no `Task.detached`, no `nonisolated(unsafe)`, no `assumeIsolated`**. The repository's escape-hatch budget is exactly one and it belongs to `VoiceBank` in E20.
2. Cancel and replace `beatTask` when a new beat begins, so a queued probe cannot end up with two timers.
3. `landVerdict()` and `endVerdictBeat()` are idempotent and guarded on `phase`, because the tests call them directly and because §6.11 case 5 (backgrounded mid-beat) can leave a task unfinished — on resume the animation is skipped and the tile is already in the ribbon, which is exactly what commit-at-t-0 buys. **`landVerdict()` does not change `phase`** — it fires the verdict cue, posts the VoiceOver announcement and flips the ring's progress; only `endVerdictBeat()` leaves `adjudicating`. That is what keeps T01's and T04's suites, written before this task existed, compiling and passing unchanged.
4. Nothing in the round reads a verdict off animation state. `ringProgress`, `scaleEffect` and phase are decoration; verdicts live in `Round.ribbon` and were committed before the first frame.

### The `Cue` seam

Create `Modules/Sources/Feedback/` with **only its value half**: `Cue.swift` (the twelve cases of `feedback-target.md` §2) and `CuePlayer.swift` (`protocol CuePlayer: Sendable { @MainActor func play(_ cue: Cue) }`, `SilentCuePlayer`, `RecordingCuePlayer`). The target takes **no default isolation** — a cue vocabulary is data — and imports neither `AVFoundation` nor `CoreHaptics`.

This is a deliberate, recorded deviation from `01 P12`'s "create the target the day its owner section is implemented". The reasoning is the plan's own: §6.5 *is* an owner section for the cue firing points, and defining the vocabulary now means E20·T01 attaches players to points that already exist and have already been timing-tested, rather than discovering them a phase late. What P12 is protecting — inventing a boundary whose shape you have not learned — does not apply: `feedback-target.md` gives the shape in full. Record it in `DECISIONS.md`, naming what is deferred: `SynthesizedCuePlayer`, `HapticCuePlayer`, `CompositeCuePlayer`, `VoiceBank` and both §13.8/§13.9 parameter tables are E20's and **must not** be written here.

`Cue` names *what happened in the game*, never *what to play*: `.verdict(.admit, isTwin: false)`, not `.playFifth`. That is what lets `SilentCuePlayer` be a legitimate implementation rather than a stub, and it is why a player with Sound and Haptics both off loses only redundancy.

`RecordingCuePlayer` **ships** in the target — it imports no `Testing`, and previews and the DEBUG gallery use it too. The `Issue.record`ing doubles stay in `HunchTestSupport` on the core side.

`Round` gains `private let cues: any CuePlayer` and `Fixtures.round(…)` gains a `cues: any CuePlayer = SilentCuePlayer()` parameter — one default, so every existing test in the epic keeps compiling and stays silent. The player is injected, never constructed inside `Round` and never a singleton; E10·T01's `AppDependencies` is what will hand it the composite.

### The two micro-responses

Both are one `Shape` plus one `Animatable` progress, not two views — driving them from a single `0...1` is what keeps admit and reject the same object under Reduce Motion, where both collapse to a crossfade of a static ring. Admit expands and **stays closed**; reject contracts and **breaks**. That geometric opposition is the load-bearing encoding: in greyscale, with sound off and haptics off, the two are still opposite. Colour, tone and haptic are three redundant copies layered on it.

Under Reduce Motion the static closed ring freezes at **1.18 R**, not 1.35 R — between rest and full expansion, so a still frame reads as *larger than the glyph* rather than as a second unrelated circle. That radius is `C.VerdictRing.settledAdmitRadius` and belongs to the ring, not here.

**Never** bounce or rubber-band: the reject shudder settles *to* rest and never past it, and §13.1 lists a bounce on a verdict as a PR-rejection offence.

## Acceptance criteria

- [ ] `VerdictBeatTests` (5), `InputGateTests` (5) and `VerdictCueTests` (3) green on both destinations.
- [ ] `grep -rn 'Task.detached\|nonisolated(unsafe)\|@unchecked Sendable\|assumeIsolated' Modules/Sources` returns nothing; `bash Scripts/check-source-hygiene.sh` check 3 passes.
- [ ] `grep -rn 'AVFoundation\|CoreHaptics\|VoiceSpec\|HapticPattern' Modules/Sources/Feedback` returns nothing — the target is values only until E20.
- [ ] `grep -rn 'Task.sleep' Modules/Tests` returns nothing.
- [ ] `grep -rn 'duration: 0\.\|\.milliseconds([0-9]' Modules/Sources/HunchUI Modules/Sources/LoomFeature | grep -v VerdictBeat.swift` returns nothing — every animation duration is a `Dur.*` token and the only literal `Duration`s in the epic are §6.5's two input-lock values.
- [ ] Playing a round by hand in the simulator: taps during the lock are ignored beyond the first, and the first queued tap fires the moment the lock lifts. Recorded in `PROGRESS.md`.
- [ ] `DECISIONS.md` records the early creation of the `Feedback` target, exactly what it contains, and what is explicitly deferred to E20·T01.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; the three new filters green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T06: the 420/320 ms verdict beat, the single-slot queue and the Cue seam"`

## Out of scope

- `SynthesizedCuePlayer`, `HapticCuePlayer`, `CompositeCuePlayer`, `VoiceBank`, and the §13.8 / §13.9 parameter tables — **E20·T01–T06**. Not one frequency and not one intensity is written in this epic.
- The twin key's `probeTwin()` and the ×0.7 amplitude twin response — **T07**. `InputGate.Action.twin` exists here because the queue is shared; the key that sends it is next.
- The Seal's own 640 ms hold, the strike, the counterexample and the reveal — **E09·T07–T10**. `requestSeal()` exists here only to prove the Seal never queues.
- The par crossing that fires inside this beat's 260–420 ms window — **T08**, which reads the beat rather than extending it. It fires **no cue**: the verdict owns audio and haptics on that frame absolutely.
- VoiceOver announcement wording and the fixed verdict → evidence → bookkeeping order — **E19·T05**. Post the announcement at t = 260 on the same frame as the cue; the strings are E19's.
- The complete §13.7.4 substitution table re-verified across every animation in the app — **E09·T12**, **E20·T08**.
