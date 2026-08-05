# T04 — Mix and session policy

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Mix and session policy (AUDIO) · §13.12 gate 11 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/audio-cues.md` §5 is this task in one screen — the three buses and their trims, the master ceiling, the exact session triple and why `.playback` is a hostile act, the −4 dB drop when other audio is playing with a hard ban on ducking, the interruption rule, and the lazy-start / 20 s-idle-stop lifecycle that §13.12 gate 11 asserts. §8 rules that neither Reduce Motion nor Low Power changes a cue, and §9 lists the nine wrong turns, four of which are in this task. |

`hunch-swift-concurrency`'s `references/real-time-audio.md` §6 is cited for the `AsyncStream`
interruption bridge; T02 already loaded that skill and built the route-change stream on the same shape.

## Objective

At the end of this task the fifteen cues are mixed — three buses under a −6 dBFS master ceiling behind
a `tanh` soft clipper and a 3-pole DC blocker — and the app's relationship to the rest of the phone is
declared once and correctly: category `.ambient`, mode `.default`, options `[]`, so the hardware silent
switch is honoured and a podcast keeps playing underneath. The engine starts lazily on the first cue
and stops after twenty seconds of silence, so a player with Sound off never instantiates an audio unit,
and an interruption resumes only when the system says `.shouldResume`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.8 (Mix) | Buses: play cues 0 dB, chrome cues −6 dB, `sieve.tick` −10 dB. Master ceiling −6 dBFS with soft clipper `tanh(1.2x)/tanh(1.2)`; a 3-pole DC blocker on the source node; no cue peaks above −12 dBFS |
| `GAME_DESIGN.md` | §13.8 (Session policy) | `.ambient` / `.default` / `[]`; never `.playback`; −4 dB when `isOtherAudioPlaying`; interruption `.began` pauses, `.ended` resumes **only** with `.shouldResume`; lazy start on the first cue; stop after 20 s of silence; `Sound` on by default and `Level` Normal / Low at −8 dB |
| `GAME_DESIGN.md` | §13.12 gate 11 | What is checkable and what is not: (a) automated — the session triple; (b) manual — silent switch on, output inaudible, every verdict still readable; (c) manual — other audio never ducked, paused or interrupted. Plus the engine-lifecycle test as a separate assertion |
| `GAME_DESIGN.md` | §12.6 (FEEDBACK) | `Sound` toggle default on — *off means the engine is never instantiated*; `Level` two states, not a slider, because the mix is already ceiling-limited and a continuous gain is a control nobody can set by ear |
| `GAME_DESIGN.md` | §12.7 | `scenePhase → .background` stops `AVAudioEngine`; `.active` does not restart it — the next cue does |
| `.claude/skills/hunch-motion-and-feedback/references/audio-cues.md` | §5, §7, §8, §9 | The mix, what gate 11 can and cannot claim, the invariance under Reduce Motion and Low Power, and the wrong forms |
| `.claude/skills/hunch-swift-concurrency/references/real-time-audio.md` | §5, §6 | The lazy-start `Task`, the `isolated deinit`, and the interruption `AsyncStream` with a bounded buffering policy and exactly one consumer |

## TDD — the test comes first

Gate 11 is unusual and the skill is explicit about why: **iOS exposes no public read of the ring/silent
switch**, so "the engine never started because the phone was silent" is neither implementable nor
verifiable and is not claimed. What is checkable is the session triple, the gain arithmetic, the
clipper, the DC blocker and the lifecycle — and those are what this suite asserts. (b) and (c) are
hand-run and recorded.

**Step 1 — write the failing test.** Create `Modules/Tests/FeedbackTests/MixTests.swift` and
`Modules/Tests/FeedbackTests/AudioSessionTests.swift`:

```swift
// MixTests.swift
import Testing
@testable import Feedback

@Suite("The mix — §13.8", .tags(.unit, .presubmission))
struct MixTests {

    // MARK: the soft clipper

    @Test("the clipper is odd-symmetric, monotone, and never exceeds unity")
    func clipperShape() {
        for x in stride(from: -4.0, through: 4.0, by: 0.05) {
            let y = Mix.softClip(Float(x))
            #expect(abs(y) <= 1.0000001)
            #expect(isApproximatelyEqual(Double(Mix.softClip(Float(-x))), Double(-y),
                                         absoluteTolerance: 1e-6))
        }
        let ramp = stride(from: -2.0, through: 2.0, by: 0.01).map { Mix.softClip(Float($0)) }
        #expect(zip(ramp, ramp.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test("the clipper is near-transparent in the working range and saturates outside it")
    func clipperIsTransparentWhereItMatters() {
        #expect(isApproximatelyEqual(Double(Mix.softClip(0.1)), 0.1, absoluteTolerance: 0.02))
        #expect(Mix.softClip(1.0) < 1.0)                       // it compresses at full scale
        #expect(Mix.softClip(8.0) < 1.0 + 1e-6)                // and it never runs away
    }

    @Test("the master ceiling is honoured for any input the bank can produce")
    func ceilingHolds() {
        let ceiling = pow(10.0, Double(Mix.masterCeilingDecibels) / 20)
        for x in stride(from: -6.0, through: 6.0, by: 0.01) {
            #expect(Double(abs(Mix.master(Float(x), gainDecibels: 0))) <= ceiling + 1e-6)
        }
    }

    // MARK: the DC blocker

    @Test("three poles of DC blocking remove a constant offset")
    func dcBlockerRemovesDC() {
        var blocker = Mix.DCBlocker()
        var last: Float = 0
        for _ in 0..<4_000 { last = blocker.process(0.5) }
        #expect(abs(last) < 0.001)
    }

    @Test("the DC blocker passes audio: a 1 kHz sine survives within a fraction of a dB")
    func dcBlockerPassesAudio() {
        var blocker = Mix.DCBlocker()
        let rate = 48_000.0, frequency = 1_000.0
        var peakIn: Float = 0, peakOut: Float = 0
        for n in 0..<4_800 {
            let x = Float(sin(2 * .pi * frequency * Double(n) / rate))
            let y = blocker.process(x)
            if n > 480 { peakIn = max(peakIn, abs(x)); peakOut = max(peakOut, abs(y)) }
        }
        #expect(20 * log10(Double(peakOut / peakIn)) > -0.2)
    }

    // MARK: the buses and the two gain offsets

    @Test("the three buses are trimmed in the order §13.8 states, and sieve.tick is the quietest")
    func busTrims() {
        #expect(Mix.trimDecibels(.play) > Mix.trimDecibels(.chrome))
        #expect(Mix.trimDecibels(.chrome) > Mix.trimDecibels(.tick))
        #expect(Mix.trimDecibels(.play) == 0)
        #expect(CueTable.voices(for: .sieveTick, droneStep: 0).allSatisfy { $0.bus == .tick })
        #expect(CueTable.voices(for: .admit, droneStep: 0).allSatisfy { $0.bus == .play })
    }

    @Test("the two master offsets are additive in dB and are computed, never stored twice")
    func masterGainIsDerived() {
        let plain = Mix.masterGainDecibels(isOtherAudioPlaying: false, level: .normal)
        let ducked = Mix.masterGainDecibels(isOtherAudioPlaying: true, level: .normal)
        let low = Mix.masterGainDecibels(isOtherAudioPlaying: false, level: .low)
        let both = Mix.masterGainDecibels(isOtherAudioPlaying: true, level: .low)
        #expect(plain == 0)
        #expect(ducked < plain)
        #expect(low < plain)
        #expect(isApproximatelyEqual(both, ducked + low, absoluteTolerance: 1e-9))
    }

    @Test("Level is two states — there is no continuous gain to set")
    func levelIsNotASlider() {
        #expect(SoundLevel.allCases.count == 2)
    }
}
```

```swift
// AudioSessionTests.swift
import AVFAudio
import Testing
@testable import Feedback

@Suite("The audio session — §13.12 gate 11(a)", .tags(.unit, .presubmission))
struct AudioSessionTests {

    @Test("the session triple is exactly .ambient / .default / [] — gate 11(a)")
    func theTriple() throws {
        let policy = AudioSessionPolicy()
        try policy.activateIfNeeded()
        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .ambient)
        #expect(session.mode == .default)
        #expect(session.categoryOptions == [])
    }

    @Test("nothing in the policy can request .playback or an override option")
    func neverPlayback() {
        #expect(AudioSessionPolicy.category == .ambient)
        #expect(AudioSessionPolicy.options.isEmpty)
    }

    @Test("no audio unit exists before the first cue")
    @MainActor
    func lazyStart() {
        let player = SynthesizedCuePlayer(session: .stub)
        #expect(player.isEngineRunningForTesting == false)
        player.play(.probeSubmit)
        #expect(player.isEngineRunningForTesting)
    }

    @Test("with Sound off the engine is never instantiated at all")
    @MainActor
    func soundOffNeverStartsAnything() {
        let player = SynthesizedCuePlayer(session: .stub)
        player.isEnabled = false
        player.play(.verdict(.admit, isTwin: false))
        #expect(player.isEngineRunningForTesting == false)
    }

    @Test("the idle stop is scheduled for 20 s and is re-armed by every cue")
    @MainActor
    func idleStopPolicy() {
        #expect(SynthesizedCuePlayer.idleStopDelay == .seconds(20))
        let schedule = IdleStop.deadline(lastCueAt: .milliseconds(1_000))
        #expect(schedule == .milliseconds(21_000))
        #expect(IdleStop.deadline(lastCueAt: .milliseconds(5_000)) > schedule)
    }

    @Test("an interruption resumes only on .shouldResume")
    func interruptionPolicy() {
        #expect(AudioInterruption.began.action == .stop)
        #expect(AudioInterruption.endedShouldResume.action == .resume)
        #expect(AudioInterruption.endedStay.action == .stayStopped)
    }

    @Test("backgrounding stops the engine and returning does not restart it — the next cue does")
    @MainActor
    func scenePhasePolicy() {
        let player = SynthesizedCuePlayer(session: .stub)
        player.play(.probeSubmit)
        player.handleScenePhase(.background)
        #expect(player.isEngineRunningForTesting == false)
        player.handleScenePhase(.active)
        #expect(player.isEngineRunningForTesting == false)
        player.play(.probeSubmit)
        #expect(player.isEngineRunningForTesting)
    }
}
```

`SynthesizedCuePlayer(session:)` takes an injected session façade so the suite never touches the real
`AVAudioSession` except in `theTriple`, which is the one test that must. `.stub` records what was asked
of it and activates nothing.

**Step 2 — run it and watch it fail.** `xcodebuild test … -only-testing:FeedbackTests/MixTests` and
`…/AudioSessionTests`. Expect `cannot find 'Mix' in scope`, then a failing `theTriple` — and check
*why* it fails: a category of `.soloAmbient` (the default when nothing is set) is a different failure
from a category of `.playback` (someone wrote the wrong line), and only the second is a design error.

**Step 3 — implement.** `Mix` first — it is pure and the render block needs it — then the session, then
the lifecycle.

**Step 4 — green, then run gate 11(b) and (c) by hand** on a device and record both in `PROGRESS.md`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/Feedback/Mix.swift` — buses, master gain, `softClip`, `DCBlocker`, the ceiling |
| create | `Modules/Sources/Feedback/AudioSessionPolicy.swift` — the triple, activation, `isOtherAudioPlaying` |
| create | `Modules/Sources/Feedback/AudioInterruption.swift` — the `Sendable` enum and its `AsyncStream` monitor |
| modify | `Modules/Sources/Feedback/SynthesizedCuePlayer.swift` — lazy start, idle stop, scene phase, `isEnabled`, `level` |
| modify | `Modules/Sources/Feedback/VoiceBank.swift` — the clipper and DC blocker on the summed sample |
| create | `Modules/Tests/FeedbackTests/MixTests.swift` |
| create | `Modules/Tests/FeedbackTests/AudioSessionTests.swift` |
| modify | `PROGRESS.md` — gate 11(b) and 11(c), dated, with the build number |
| modify | `tests.json` — the gate 11 entries |

## Implementation notes

### `Mix` is pure, and it lives on the render thread

Everything in `Mix` is a `static func` or a POD struct over `Float`. No allocation, no branch on a
class, no `Double` conversion in the inner loop. `softClip` and `DCBlocker.process` are called once
per sample, so they are also the two functions in this codebase where an unnecessary `if` is
measurable.

```swift
enum Mix {
    /// §13.8's soft clipper. One expression; the normalisation is what keeps small signals unity-ish.
    static func softClip(_ x: Float) -> Float { tanh(1.2 * x) / tanh(1.2) }
}
```

The **3-pole DC blocker** is three cascaded one-pole high-passes, each `y[n] = x[n] − x[n−1] + R·y[n−1]`
with `R` set from a corner low enough to leave a 1 kHz sine alone — the test above is the definition of
"low enough", and it is the reason a single pole is not enough: summing six sine voices with 4 ms
attacks leaves an offset that one pole does not fully clear before the next cue starts.

Order on the summed sample is **DC blocker, then bus trim and master gain, then soft clip**. Clipping
before the blocker would clip an offset rather than the signal; applying the gain after the clipper
would let `Level: Low` change the clipping character rather than the level.

### The two master offsets are one arithmetic, not two code paths

```swift
static func masterGainDecibels(isOtherAudioPlaying: Bool, level: SoundLevel) -> Double
```

Additive in dB, and derived at the point of use. §13.8 gives −4 dB when other audio is playing and
−8 dB for `Level: Low`; a player with a podcast on and Level Low gets both, which is why the test
asserts additivity rather than a table of four values. `isOtherAudioPlaying` is read from
`AVAudioSession.sharedInstance()` at engine start and re-read on the interruption and route streams —
it is a property of the moment, not a stored preference.

**Never duck, pause or interrupt the other audio.** That is gate 11(c) and it is a hand check, because
what would break it is not a line of ours but an option flag: `.duckOthers`, `.interruptSpokenAudio`,
`.mixWithOthers` on a `.playback` category. The options set is empty; assert it and leave it empty.

### The session, and the sentence that decides it

**Category `.ambient`, mode `.default`, options `[]`.** `.ambient` honours the hardware silent switch
and mixes with other audio. **Never `.playback`** — overriding the silent switch in a puzzle game is a
hostile act, and §13.12 gate 11(a) asserts the exact triple automatically for exactly that reason.

Activate the session lazily, in the same place the engine starts, and do not deactivate it on every
idle stop — deactivating an `.ambient` session repeatedly is a system-level churn nobody hears and
everybody's battery pays for. Stop the engine; leave the session.

### Lifecycle: lazy start, 20 s idle stop, and the one `Task`

```swift
/// §13.8: the engine starts lazily on the first cue, so a player with sound off never
/// instantiates an audio unit; it stops after 20 s of silence.
private func scheduleIdleStop() {
    idleStop?.cancel()
    idleStop = Task { [weak self] in                  // `05 R37`: a legitimate sync → async boundary
        try? await Task.sleep(for: Self.idleStopDelay)
        guard !Task.isCancelled else { return }
        self?.stopEngine()
    }
}
```

`Task { }` inherits main-actor isolation here, so `stopEngine()` needs no hop. Never `Task.detached`
(`05 R38`), never `DispatchQueue.main.asyncAfter` (`05 R20`), and **never capture `self` in a
`deinit`'s `Task`** (`05 R42`) — use `isolated deinit` to cancel and stop, as `real-time-audio.md` §5
shows.

`isEnabled` is the `Sound` toggle and it is checked **before** anything else in `play(_:)`, so §12.6's
"off means the engine is never instantiated" is literally true rather than approximately true. It is
not a mute on the mixer: a mute still spins the audio unit up and still holds the audio server awake.

### Interruptions, without a `Notification` crossing a boundary

`Notification` is not `Sendable`. Bridge it with `AsyncStream.makeStream(of:)`, parse inside the
observer closure, and let only a small `Sendable` enum cross (`05 R45`, and `real-time-audio.md` §6 has
the whole shape including the `AudioInterruption(_ notification:)` initialiser). Two rules that bite:
**`bufferingPolicy: .bufferingNewest(1)`**, never the unbounded default (`05 R46`), and **one
`for await` over one stream** (`05 R48`) — the route-change stream T02 built is its own stream with its
own enum, and a second consumer of either silently drops events.

Consume it from the view that owns the player, with `.task`, so it is cancelled with the view
(`05 R34`).

### What Reduce Motion and Low Power do to audio: nothing

`audio-cues.md` §8, and it is worth stating in a comment at the top of `SynthesizedCuePlayer`: onsets
keep their absolute positions under Reduce Motion and the ones past the shortened end are **dropped,
not rescheduled**; Low Power suppresses long *haptics* and touches no audio. If a change to a sound is
being contemplated because a setting is on, the setting is the wrong reason.

### Gate 11(b) and 11(c) are hand checks — run them, and write down what you saw

Both go into `PROGRESS.md` §Feedback with a date and a build number:

- **(b)** With the hardware silent switch on: output is inaudible, and a full round is still playable —
  every verdict readable from ring geometry and haptics alone. This is the same claim §13.12 gate 3
  makes with the screen curtain on, from the other side.
- **(c)** With a podcast playing: HUNCH's cues sit over it, the podcast is not ducked, not paused and
  not interrupted, and the master is audibly lower than with nothing else playing.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:FeedbackTests/MixTests` and `…/AudioSessionTests` green — seven and seven.
- [ ] `grep -rn 'playback\|duckOthers\|interruptSpokenAudio\|mixWithOthers\|overrideOutputAudioPort' Modules/Sources/Feedback/` returns nothing.
- [ ] `grep -rn 'setActive(false' Modules/Sources/Feedback/` returns nothing outside `isolated deinit` — the engine stops, the session stays.
- [ ] `grep -rn 'DispatchQueue\|Task.detached' Modules/Sources/Feedback/` returns nothing.
- [ ] `grep -c 'for await' Modules/Sources/Feedback/*.swift` shows exactly one consumer per stream, and the two streams carry two different enums.
- [ ] With `Sound` off, Instruments' Audio track shows **no** audio unit created across a full round — checked on a device and noted in `PROGRESS.md`.
- [ ] `PROGRESS.md` §Feedback carries gate 11(b) and 11(c) with a date and a build number, each in a sentence saying what was heard.
- [ ] `tests.json` carries `audio.session-triple` (gate 11(a)), `audio.engine-lifecycle` (lazy start + 20 s idle stop) and `audio.mix-ceiling`, each with its command; gate 11(b) and (c) are entered as `manual` with `PROGRESS.md` as their home.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T04: the mix, the ceiling and the .ambient session — lazy start, 20 s idle stop, resume only on .shouldResume"`

## Out of scope

- The `Sound`, `Level` and `Haptics` Settings rows, their `UserDefaults` keys and their drawn toggles — **E17·T06**. This task consumes the two values and draws nothing.
- Every frequency and envelope — **T03**.
- The render block, the bank and the hatch — **T02**.
- Anything haptic, including the Low Power suppression that looks superficially like this task's `isEnabled` — **T05**, **T06**.
- The `scenePhase` table for the rest of the app — **E17·T09**; this task registers the audio half of `.background` against the policy that task already ships.
