# T02 — The procedural audio engine

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T01 |
| **Delivers** | Procedural engine (AUDIO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-concurrency` | `references/real-time-audio.md` **owns** this task's hardest half: §1 walks `05 R17`'s ladder and shows every row failing, §2 is `VoiceBank` in full with the acquire/release pair and the reclamation bound, §3 is the four-question comment contract that hygiene check 3 enforces, §4 is the render-block ban list, §5 is the main-actor half and the `isolated deinit`, §6 is the `AsyncStream` bridge that keeps a non-`Sendable` `Notification` from crossing a boundary. Its §8 review checklist is the one to run before committing. |
| `hunch-motion-and-feedback` | `references/audio-cues.md` §4 fixes what the engine must be: everything computed per sample, one engine and one source node, a fixed 8-slot array with an atomic head, oldest-stolen, polyphony capped at 6, AD envelopes only, and the sample rate read from the session with the source node rebuilt on a channel-count route change. Its §9 names hard-coding 44,100 as a defect. |

## Objective

At the end of this task one `AVAudioEngine` drives one `AVAudioSourceNode` whose render block
allocates nothing, locks nothing and awaits nothing, reading an eight-slot POD voice array published
by a single atomic release/acquire pair — the repository's one and only `@unchecked Sendable`, carrying
the comment that hygiene check 3 requires. A pure admission function caps polyphony at six on the
producer side without ever reading a consumer field, and a pure `VoiceSpec → Voice` conversion takes
the sample rate as an argument, so a 48 kHz route produces the same pitches as a 44.1 kHz one.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.8 (engine paragraph) | One `AVAudioEngine`, one `AVAudioSourceNode` into a mixer; no `AVAudioFile`, no buffers from disk, no assets; the render block allocation-free and lock-free; a fixed 8-slot voice array with an atomic head index, oldest-stolen; polyphony capped at **6**; sample rate follows `AVAudioSession.sharedInstance().sampleRate`; the source node is rebuilt on a route change that alters channel count |
| `GAME_DESIGN.md` | §13.8 (envelopes) | AD only — no sustain stage, no release stage; decay is exponential to −60 dB over the stated time. The stated times are T03's; the *shape* is this task's |
| `GAME_DESIGN.md` | §14.4 | No audio assets of any kind, and the 15 MB budget that is one reason why |
| `ios-swift-guide/05-CONCURRENCY.md` | `R17`, `R18`, `R20`, `R26`, `R27`, `R29`, `R36`, `R37`, `R38`, `R42`, `R45`, `R46`, `R48` | The state ladder and why every row fails here; no `DispatchQueue`; the comment requirement; `Task {}` at a sync→async boundary is correct and `Task.detached` is not; never capture `self` in a `deinit`'s `Task`; the `AsyncStream` bridge with a bounded buffering policy and one consumer |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B34a` check 3 | An undocumented escape hatch fails the build. This task is the reason the check exists |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 ("The one escape hatch"), §7.7 | The ruling, and why iOS 18 is the floor: `Synchronization` is iOS 18+ and `Modules/Package.swift` must declare `platforms: [.iOS(.v18)]` in its own right |
| `.claude/skills/hunch-swift-concurrency/references/real-time-audio.md` | §1–§6, §8 | Everything above, worked, plus the review checklist |

## TDD — the test comes first

**The engines are never exercised in the fast suite** (`feedback-target.md` §7): `swift test` must stay
under 10 s with no simulator, and an `AVAudioEngine` on a CI host is a flake, not a test. Everything
below tests the parts that actually break — the DSP, the publication order, the admission policy and
the sample-rate dependence — and none of it starts an engine.

**Step 1 — write the failing test.** Create `Modules/Tests/FeedbackTests/VoiceBankTests.swift`:

```swift
import AVFAudio
import Testing
@testable import Feedback

@Suite("VoiceBank — the render block and the slot discipline", .tags(.unit, .presubmission))
struct VoiceBankTests {

    /// One allocation-free scratch buffer, built once per test, mirroring what the render block
    /// is handed. Not an AVAudioEngine: nothing here starts one.
    private func render(_ bank: VoiceBank, frames: Int, channels: Int = 2) -> [[Float]] {
        var storage = Array(repeating: [Float](repeating: .nan, count: frames), count: channels)
        storage.withUnsafeMutableBufferPointer { outer in
            let list = AudioBufferList.allocate(maximumBuffers: channels)
            defer { free(list.unsafeMutablePointer) }
            for channel in 0..<channels {
                list[channel] = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(frames * MemoryLayout<Float>.size),
                    mData: outer[channel].withUnsafeMutableBytes { $0.baseAddress })
            }
            bank.render(into: list, frameCount: frames)
        }
        return storage
    }

    @Test("an empty bank renders exact silence into every channel")
    func silenceWhenIdle() {
        let bank = VoiceBank()
        let out = render(bank, frames: 256)
        #expect(out.allSatisfy { $0.allSatisfy { $0 == 0 } })
    }

    @Test("one enqueued voice sounds, decays monotonically, and then stops for good")
    func oneVoiceDecaysAndEnds() {
        let bank = VoiceBank()
        bank.enqueue(VoiceBank.Voice(phaseIncrement: 0.05, amplitude: 0.5,
                                     decayPerSample: 0.999, samplesRemaining: 128))
        let first = render(bank, frames: 128)[0]
        #expect(first.contains { $0 != 0 })

        let peaks = stride(from: 0, to: 128, by: 16).map { abs(first[$0]) }
        // sampled at a fixed phase stride the envelope is monotone non-increasing
        #expect(zip(peaks, peaks.dropFirst()).allSatisfy { $0 >= $1 } || peaks.max()! > 0)

        let after = render(bank, frames: 128)[0]
        #expect(after.allSatisfy { $0 == 0 })            // samplesRemaining exhausted
    }

    @Test("the ninth enqueue steals the oldest slot and nothing else")
    func oldestStolen() {
        let bank = VoiceBank()
        for index in 0..<VoiceBank.slotCount {
            bank.enqueue(VoiceBank.Voice(phaseIncrement: 0.01 * Double(index + 1),
                                         amplitude: 0.1, decayPerSample: 1, samplesRemaining: 1 << 20))
        }
        let ninth = VoiceBank.Voice(phaseIncrement: 0.9, amplitude: 0.2,
                                    decayPerSample: 1, samplesRemaining: 1 << 20)
        bank.enqueue(ninth)
        #expect(bank.slotSnapshotForTesting(0).phaseIncrement == ninth.phaseIncrement)
        #expect(bank.slotSnapshotForTesting(1).phaseIncrement == 0.02)   // untouched
    }

    @Test("render is deterministic — the same bank state gives bit-identical samples")
    func renderIsDeterministic() {
        func run() -> [Float] {
            let bank = VoiceBank()
            bank.enqueue(VoiceBank.Voice(phaseIncrement: 0.031, amplitude: 0.4,
                                         decayPerSample: 0.9995, samplesRemaining: 512))
            return render(bank, frames: 512)[0]
        }
        #expect(run() == run())
    }

    @Test("every channel of the buffer list receives the same mixed sample")
    func mixIsWrittenToEveryChannel() {
        let bank = VoiceBank()
        bank.enqueue(VoiceBank.Voice(phaseIncrement: 0.07, amplitude: 0.3,
                                     decayPerSample: 1, samplesRemaining: 64))
        let out = render(bank, frames: 64, channels: 2)
        #expect(out[0] == out[1])
    }
}

@Suite("The producer half — admission and the sample rate", .tags(.unit, .presubmission))
struct VoiceAdmissionTests {

    private let spec = VoiceSpec(frequency: 220, waveform: .sine, attack: .milliseconds(4),
                                 decay: .milliseconds(260), peak: -16, bus: .play,
                                 startOffset: .zero)

    @Test("polyphony is capped at six, and the cap keeps the newest requests")
    func polyphonyCap() {
        let requested = Array(repeating: spec, count: 12)
        let admitted = SynthesizedCuePlayer.admitted(requested, live: 0)
        #expect(admitted.count == VoiceBank.polyphonyCap)
        #expect(VoiceBank.polyphonyCap == 6)             // §13.8

        // a burst arriving while five are already sounding gets one slot, not six
        #expect(SynthesizedCuePlayer.admitted(requested, live: 5).count == 1)
        #expect(SynthesizedCuePlayer.admitted(requested, live: 6).isEmpty)
    }

    @Test("live-voice bookkeeping is the producer's own — the bank exposes no count to it")
    func producerNeverReadsTheConsumer() {
        // A compile-shaped assertion: the admission function takes `live` as a parameter, so
        // there is no path from the producer to `samplesRemaining`.
        #expect(SynthesizedCuePlayer.admitted([spec], live: 0).count == 1)
    }

    @Test("phase increment is a function of the session's sample rate, never of a constant")
    func sampleRateDrivesPitch() {
        let at44 = SynthesizedCuePlayer.voice(for: spec, sampleRate: 44_100)
        let at48 = SynthesizedCuePlayer.voice(for: spec, sampleRate: 48_000)
        #expect(at44.phaseIncrement > at48.phaseIncrement)
        #expect(isApproximatelyEqual(at44.phaseIncrement / at48.phaseIncrement,
                                     48_000 / 44_100, absoluteTolerance: 1e-9))
    }

    @Test("the envelope is AD: decay reaches −60 dB in exactly the stated time, at any rate")
    func decayReachesMinusSixtyDecibels() {
        for rate in [44_100.0, 48_000.0] {
            let voice = SynthesizedCuePlayer.voice(for: spec, sampleRate: rate)
            let samples = Double(spec.decay.milliseconds) / 1000 * rate
            let remaining = pow(voice.decayPerSample, samples)
            #expect(isApproximatelyEqual(20 * log10(remaining), -60, absoluteTolerance: 0.5))
            #expect(voice.samplesRemaining >= Int32(samples))
        }
    }
}
```

`isApproximatelyEqual(_:_:absoluteTolerance:)` is `HunchTestSupport`'s (E01·T04) — but that target is
absent from `products:` and cannot be imported from `Modules` (`06 T5a`). Mirror the five lines into
`Modules/Tests/FeedbackTests/` beside `Tags.swift`, exactly as the tag vocabulary is mirrored, and
say so in a comment; do **not** add a dependency arrow that would let `import Testing` reach a shipping
target.

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" -only-testing:FeedbackTests | xcbeautify
```

Expect `cannot find 'VoiceBank' in scope` first. After the bank exists, expect
`type 'SynthesizedCuePlayer' has no member 'admitted'`. Then — and this is the one to watch for —
build once with the hatch comment deleted and confirm `Scripts/check-source-hygiene.sh` **fails**
check 3 before restoring it. A check that has never been seen to fail is not a check (`07 B6`).

**Step 3 — implement.** In this order: `VoiceBank`, then the pure producer functions, then the node
and the engine. The engine is last because nothing tests it.

**Step 4 — green, then run `real-time-audio.md` §8's review checklist line by line** before
`/simplify`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/Feedback/VoiceBank.swift` |
| create | `Modules/Sources/Feedback/SynthesizedCuePlayer.swift` |
| modify | `Modules/Sources/Feedback/VoiceSpec.swift` — `Waveform` and `Bus` cases, and the pure `VoiceSpec → Voice` conversion's home |
| modify | `Modules/Package.swift` — confirm `platforms: [.iOS(.v18)]`; `Feedback` gains no dependency |
| create | `Modules/Tests/FeedbackTests/VoiceBankTests.swift` |
| create | `Modules/Tests/FeedbackTests/VoiceAdmissionTests.swift` |
| create | `Modules/Tests/FeedbackTests/ApproximateEquality.swift` (mirrored, five lines) |
| modify | `Scripts/check-source-hygiene.sh` — the render-block purity check |
| modify | `DECISIONS.md` — the reclamation-bound entry |
| modify | `tests.json` — the render-block and admission entries |

## Implementation notes

### `VoiceBank` — copy it, do not re-derive it

`real-time-audio.md` §2 carries the implementation in full, including the comment. **Paste it and
adapt it; do not write it from memory.** The four properties that make it correct are easy to
reproduce approximately and worthless approximately:

1. **`slots` is allocated exactly once, in `init`, and never resized.** An
   `UnsafeMutableBufferPointer<Voice>` of `slotCount`, initialised with `Voice()`, deinitialised and
   deallocated in `deinit`. A growable buffer hands the render thread a dangling pointer.
2. **`Voice` is plain old data** — `Double`, `Float`, `Int32`. No references, nothing that can
   deallocate on the render thread, no `Duration` (which is a struct but invites arithmetic that
   allocates), no optionals holding classes.
3. **`head` is the only synchronisation.** `.releasing` on the store in `enqueue`, `.acquiring` on the
   load at the top of `render`. The loaded value is deliberately unused: it is a fence, not data.
4. **The producer never reads `samplesRemaining`.** It is the consumer's field. Polyphony is enforced
   from what the producer already knows, because every cue's envelope length is fixed at enqueue time
   by §13.8's table.

`slotSnapshotForTesting(_:)` in the test above is the one addition to §2's listing: an
`internal` read of a slot's producer-written fields, used only by `VoiceBankTests` and never by
`SynthesizedCuePlayer`. Keep it `internal`, not `public`, and never let it read `samplesRemaining` —
if the temptation arrives, the test wants a different assertion.

### The comment is the build gate

`05 R26`/`R29` treat an `@unchecked Sendable` with no comment naming the exact synchronisation
mechanism as a defect, and `07 B34a` check 3 fails the build on one. The comment must answer four
questions in this order (`real-time-audio.md` §3): **who writes and from where**, **who reads and from
where**, **what the mechanism actually is** — the acquire/release pair, the fixed allocation, the
reclamation bound — and **what would break it**: a second producer, a growable buffer, a producer-side
read of a consumer field.

Record the reclamation bound in `DECISIONS.md`: a slot is reclaimed only after eight further
enqueues, which at §13.8's cue rate is an order of magnitude longer than the longest envelope, and
**if that ever stops being true the fix is more slots, not a lock.** SIEVE at maximum speed requests
about twelve cues per second and the six-voice cap holds; that is the measurement the bound rests on.

### The render block

```swift
// SynthesizedCuePlayer, @MainActor. `bank` is captured by the @Sendable render block —
// which is precisely why VoiceBank needs the Sendable conformance at all.
private func makeSourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
    let bank = self.bank
    return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
        bank.render(into: UnsafeMutableAudioBufferListPointer(audioBufferList),
                    frameCount: Int(frameCount))
        return noErr
    }
}
```

Inside that block, never: allocate (an `Array` literal, a `String`, boxing, ARC traffic on a class),
lock, `await`, `print`, `os_log`, throw, touch `self`, touch any `@MainActor` type, or call anything
whose implementation you have not read. A `guard let` on a class-typed optional is a retain.

Make that mechanical rather than remembered — append to `Scripts/check-source-hygiene.sh`, as the next
free number in the roster (several epics have appended past check 10; take the next unused index and
add the row to `hunch-build-and-ci`'s table in the same commit):

```bash
# N. The audio render path allocates nothing. `07 B34a`-shaped: a grep, because no test can see
#    a malloc on the render thread until it underruns on a device.
hits=$(grep -nE '(Array\(|String\(|\.map\{|\.map\(|print\(|os_log|await |try |self\.)' \
        Modules/Sources/Feedback/VoiceBank.swift || true)
[ -n "$hits" ] && report 'Allocation-shaped token in the audio render path:' "$hits"
```

Scope it to the one file, and keep the file to the bank alone so the grep stays a true statement about
the render path rather than a nuisance over the whole target.

### The producer half

Two pure functions, both `static`, both testable with no engine:

```swift
/// §13.8: polyphony is capped at 6. Enforced on the main actor from what the producer knows;
/// counting live voices by reading the shared array is the bug the whole design avoids.
static func admitted(_ requested: [VoiceSpec], live: Int) -> ArraySlice<VoiceSpec> {
    let budget = max(0, VoiceBank.polyphonyCap - live)
    return requested.prefix(budget)
}

/// §13.8: the sample rate follows the session. Hard-coding 44,100 gives a chipmunk on 48 kHz.
static func voice(for spec: VoiceSpec, sampleRate: Double) -> VoiceBank.Voice { … }
```

`voice(for:sampleRate:)` is where the AD envelope becomes numbers: `phaseIncrement = 2π·f/rate`, and
`decayPerSample` is the per-sample factor whose product over the decay window is −60 dB — i.e.
`pow(10, -60 / (20 · decaySamples))`. Solve it that way rather than tabulating it, so a decay time
moving in T03 moves the envelope with it. `samplesRemaining` covers attack plus decay; a voice that
outlives its envelope wastes a slot and a voice that dies inside it clicks.

**`live` is the player's own count**, maintained by adding on enqueue and subtracting on a timer
derived from the spec's own envelope length — never by asking the bank. A `Task` per voice is wrong
(`05 R37` is about the sync→async boundary, not about one task per note); keep a small array of
`(deadline, count)` and prune it on the next `play(_:)`.

### The engine, the format and the route change

`AVAudioEngine`, one `AVAudioSourceNode`, `engine.connect(node, to: engine.mainMixerNode, format:)`.
The format's sample rate is `AVAudioSession.sharedInstance().sampleRate` **read at build time, not
cached across route changes**. On `AVAudioSession.routeChangeNotification`, compare the new format's
channel count with the current node's; if it differs, tear the node down and build a new one. §13.8
requires the rebuild only for a channel-count change, so do not rebuild on every route change — a
headphone unplug that keeps two channels must not glitch the mix.

Bridge that notification with the same `AsyncStream` shape `real-time-audio.md` §6 uses for
interruptions: `Notification` is not `Sendable`, so parse it inside the observer closure and let only
a small `Sendable` enum cross. **A route-change stream is its own stream with its own enum** — `05 R48`
makes an `AsyncStream` single-consumer, and a second `for await` over one stream silently drops
events. The interruption stream itself is T04's; build the route one here and leave the interruption
one to that task.

### What this task does not do

It does not start the engine. Lazy start on the first cue, the 20 s idle stop, the session category,
the buses, the ceiling, the clipper and the DC blocker are all **T04**, and building any of them here
would mean `play(_:)` starting an audio unit before there is a mix to start it into. `play(_:)` in
this task's `SynthesizedCuePlayer` may be a `preconditionFailure`-free no-op that enqueues into the
bank and nothing more.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:FeedbackTests` green — `VoiceBankTests` (5) and `VoiceAdmissionTests` (4).
- [ ] `grep -rn '@unchecked Sendable' HunchCore Modules App | wc -l` is exactly `1`, and it is `VoiceBank`.
- [ ] Deleting the hatch comment makes `Scripts/check-source-hygiene.sh` exit non-zero on check 3; restoring it makes it exit 0. Demonstrated, then reverted.
- [ ] The new render-path purity check is in the roster table in `hunch-build-and-ci/SKILL.md` and was demonstrated to fail on a planted `print(mix)` in `VoiceBank.render`.
- [ ] `grep -rn '44100\|44_100\|48000\|48_000' Modules/Sources/Feedback/` returns nothing outside a comment — the rate is a parameter everywhere.
- [ ] `grep -rn 'AVAudioFile\|AVAudioPCMBuffer\|Bundle.*wav\|\.mp3\|\.caf' Modules Modules/Sources App` returns nothing (§13.8: no assets, ever).
- [ ] `grep -rn 'DispatchQueue\|Task.detached\|assumeIsolated' Modules/Sources/Feedback/` returns nothing (`05 R20`, `R38`, `R36`).
- [ ] `real-time-audio.md` §8's eight-item review checklist has been walked, item by item, and the walk is noted in the commit body.
- [ ] `DECISIONS.md` carries the reclamation-bound entry with "more slots, not a lock" as the stated fix.
- [ ] `tests.json` carries `feedback.render-block` and `feedback.polyphony-cap`, each with its `-only-testing` command.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T02: the procedural audio engine — VoiceBank, the render block and the one documented hatch"`

## Out of scope

- Every frequency, waveform, attack, decay and peak — **T03**. This task's tests use invented numbers precisely so they cannot be mistaken for the table.
- The mix, the three buses, the −6 dBFS ceiling, the soft clipper, the DC blocker, the session category, the lazy start, the 20 s idle stop and the interruption stream — **T04**.
- Anything haptic — **T05**, **T06**. `CHHapticEngine` is not real-time and gets no hatch (`real-time-audio.md` §7).
- Switching `AppDependencies.live()` to the real composite — **T06**.
- `Cue`, `AudioRow`, `HapticRow`, `CompositeCuePlayer` — **T01**.
