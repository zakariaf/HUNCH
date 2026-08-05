# The audio render thread — the one escape hatch

Read before touching anything in `Modules/Sources/Feedback/`. Rule numbers are
`ios-swift-guide/05-CONCURRENCY.md`; `08 §n` is `ios-swift-guide/08-APPLIED-TO-HUNCH.md`; `§n` alone
is `GAME_DESIGN.md`, which owns every frequency, envelope and level and is never restated here.

1. [Why the ladder has no row for this](#1-why-the-ladder-has-no-row-for-this)
2. [`VoiceBank`](#2-voicebank)
3. [The comment contract](#3-the-comment-contract)
4. [The render-block rules](#4-the-render-block-rules)
5. [`SynthesizedCuePlayer` — the main-actor half](#5-synthesizedcueplayer--the-main-actor-half)
6. [Interruptions and route changes, without `Notification` crossing a boundary](#6-interruptions-and-route-changes-without-notification-crossing-a-boundary)
7. [Haptics are not real-time](#7-haptics-are-not-real-time)
8. [Review checklist](#8-review-checklist)

---

## 1. Why the ladder has no row for this

`AVAudioSourceNode`'s render block runs on a real-time audio thread. It may not allocate, may not
take a lock, may not `await`, and may not touch main-actor state. Walk `05 R17` and every row fails:

| Row | Why it is wrong here |
|---|---|
| `@MainActor` | the render thread is not the main actor and cannot hop to it |
| `Mutex` | priority inversion in a render callback: the audio thread blocks behind a lower-priority producer and the buffer underruns |
| `actor` | there is no `await` available inside a render block |
| non-`Sendable` + `sending` | the block is `@Sendable` and must capture the bank for the lifetime of the node |

`08 §7.7` is the ruling: a lock-free `VoiceBank` with one `Atomic` and one documented
`@unchecked Sendable`. It is also the reason the deployment floor is iOS 18 rather than the guide's
default — `Synchronization` is iOS 18+, and `Modules/Package.swift` must declare
`platforms: [.iOS(.v18)]` in its own right.

`05 R27` lists three surviving legitimate uses of `@unchecked Sendable` and this is not literally one
of them, because the guide's list was written about *inherited* code. The justification here is the
same in kind — a synchronisation mechanism the compiler cannot see — and it is written down, which
is what `05 R26` actually asks for.

## 2. `VoiceBank`

Single producer (main actor), single consumer (render thread), eight slots, oldest-stolen,
allocation-free (`§13.8`).

```swift
import AVFAudio
import Foundation
import Synchronization

/// Thread-safe by construction, not by lock. `SynthesizedCuePlayer` on the main actor is the sole
/// producer; `AVAudioSourceNode`'s render thread is the sole consumer. `slots` is a fixed
/// eight-element buffer allocated once in `init` and never resized or reallocated, so the consumer
/// never sees a dangling pointer. The only synchronisation is `head`: the releasing store in
/// `enqueue(_:)` publishes the slot's fields, and the acquiring load at the top of `render` is the
/// matching fence. A slot is reclaimed only after eight further enqueues, which at the §13.8 cue
/// rate is an order of magnitude longer than the longest envelope; if that ever stops being true
/// the fix is more slots, not a lock. Never add a second producer, never read `samplesRemaining`
/// from the producer, never make `slots` growable.
final class VoiceBank: @unchecked Sendable {
    /// Plain old data. No references, nothing that can deallocate on the render thread.
    struct Voice {
        var phase: Double = 0
        var phaseIncrement: Double = 0
        var amplitude: Float = 0
        var decayPerSample: Float = 1
        var samplesRemaining: Int32 = 0
    }

    static let slotCount = 8

    private let slots: UnsafeMutableBufferPointer<Voice>
    private let head = Atomic<UInt64>(0)

    init() {
        slots = .allocate(capacity: Self.slotCount)
        slots.initialize(repeating: Voice())
    }

    deinit {
        _ = slots.deinitialize()
        slots.deallocate()
    }

    /// Producer side. Main actor only. Claims the next slot round-robin, which is §13.8's
    /// oldest-stolen policy given a fixed slot count.
    func enqueue(_ voice: Voice) {
        let index = head.load(ordering: .relaxed)
        slots[Int(index % UInt64(Self.slotCount))] = voice
        head.store(index &+ 1, ordering: .releasing)      // publishes the write above
    }

    /// Consumer side. Render thread only. Allocates nothing, locks nothing, awaits nothing.
    func render(into buffers: UnsafeMutableAudioBufferListPointer, frameCount: Int) {
        _ = head.load(ordering: .acquiring)               // the matching fence; the value is unused
        for frame in 0..<frameCount {
            var mix: Float = 0
            for slot in 0..<Self.slotCount where slots[slot].samplesRemaining > 0 {
                mix += slots[slot].amplitude * Float(sin(slots[slot].phase))
                slots[slot].phase += slots[slot].phaseIncrement
                slots[slot].amplitude *= slots[slot].decayPerSample
                slots[slot].samplesRemaining -= 1
            }
            let sample = Mix.clip(mix)                    // §13.8 owns the clipper and the ceiling
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                data.assumingMemoryBound(to: Float.self)[frame] = sample
            }
        }
    }
}
```

**The producer must not read `samplesRemaining`.** It is the consumer's field. `§13.8` caps polyphony
at 6 — enforce that on the main actor from what the producer already knows, because the envelope
length of every cue is fixed by the `§13.8` table at enqueue time. Counting live voices by reading
the shared array is the bug this whole design exists to avoid.

## 3. The comment contract

`05 R26` treats `@unchecked Sendable` without a comment naming the exact synchronisation mechanism as
a defect, and `Scripts/check-source-hygiene.sh` check 3 (`07 B34a`) fails the build on one. The
comment above the declaration must answer four questions, in this order:

1. **Who writes, and from where.** ("the main actor is the sole producer")
2. **Who reads, and from where.** ("the render thread is the sole consumer")
3. **What the actual mechanism is.** Not "it's safe" — the acquire/release pair, the fixed
   allocation, the reclamation bound.
4. **What would break it.** A second producer, a growable buffer, a producer-side read.

Check 3 tests a two-line window, so the comment may sit above the declaration or beside it. It does
not read the comment's *content* — that part is a review obligation, and §8 below is the checklist.

## 4. The render-block rules

```swift
// SynthesizedCuePlayer, @MainActor. `bank` is captured by the @Sendable render block —
// which is precisely why VoiceBank needs the Sendable conformance at all.
private func makeSourceNode() -> AVAudioSourceNode {
    let bank = self.bank
    return AVAudioSourceNode { _, _, frameCount, audioBufferList in
        bank.render(into: UnsafeMutableAudioBufferListPointer(audioBufferList),
                    frameCount: Int(frameCount))
        return noErr
    }
}
```

Inside that block, never: allocate (no `Array`, no `String`, no boxing, no ARC traffic on a class),
lock, `await`, `print`, `os_log`, throw, touch `self`, touch any `@MainActor` type, or call anything
whose implementation you have not read. A `Float` array literal is an allocation. A `guard let` on a
class-typed optional is a retain.

## 5. `SynthesizedCuePlayer` — the main-actor half

Everything that is not the render block is ordinary main-actor code (`08 §1`: `Feedback` is a
nonisolated target, so the two players carry `@MainActor` explicitly per `05 R8`).

```swift
@MainActor
public final class SynthesizedCuePlayer: CuePlayer {
    private let bank = VoiceBank()
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var idleStop: Task<Void, Never>?

    public func play(_ cue: Cue) {
        startEngineIfNeeded()
        for voice in cue.voices { bank.enqueue(voice) }   // §13.8's cue table builds these
        scheduleIdleStop()
    }

    /// §13.8: the engine starts lazily on the first cue, so a player with sound off never
    /// instantiates an audio unit; it stops after 20 s of silence.
    private func scheduleIdleStop() {
        idleStop?.cancel()
        idleStop = Task { [weak self] in                  // `05 R37`: sync → async boundary, legitimate
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            self?.stopEngine()
        }
    }
}
```

`Task { }` here inherits main-actor isolation from the enclosing context (`05 R11` rule 4), so
`self?.stopEngine()` needs no hop. Do not write `Task.detached` (`05 R38`) or
`DispatchQueue.main.asyncAfter` (`05 R20`).

**Never capture `self` in a `deinit`'s `Task`** (`05 R42`) — it resurrects a deallocating object and
crashes. If the engine needs async teardown, capture the dependency:

```swift
isolated deinit {                    // SE-0371, compiles on 6.3.3 at an iOS 18 floor
    idleStop?.cancel()
    engine.stop()
}
```

## 6. Interruptions and route changes, without `Notification` crossing a boundary

`§13.8` requires: pause on `interruptionNotification` `.began`; on `.ended` with `.shouldResume`
restart, otherwise stay stopped until the next user action; rebuild the source node on a route change
that alters channel count. `Notification` is not `Sendable`, so bridge it with `05 R45`'s
`AsyncStream.makeStream(of:)` and let only a small `Sendable` enum cross.

```swift
public enum AudioInterruption: Sendable { case began, endedShouldResume, endedStay }

@MainActor
final class InterruptionMonitor {
    let events: AsyncStream<AudioInterruption>
    private let continuation: AsyncStream<AudioInterruption>.Continuation
    private var token: (any NSObjectProtocol)?

    init(center: NotificationCenter = .default) {
        let (events, continuation) = AsyncStream.makeStream(
            of: AudioInterruption.self,
            bufferingPolicy: .bufferingNewest(1))        // `05 R46`: never the unbounded default
        self.events = events
        self.continuation = continuation
        token = center.addObserver(forName: AVAudioSession.interruptionNotification,
                                   object: nil, queue: nil) { [continuation] notification in
            // Parsed on whatever thread posted it; only the enum leaves this closure.
            guard let event = AudioInterruption(notification) else { return }
            continuation.yield(event)
        }
    }

    isolated deinit {                                     // `05 R47`'s job, done where the token lives
        continuation.finish()
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}

extension AudioInterruption {
    init?(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return nil }
        switch type {
        case .began:
            self = .began
        case .ended:
            let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:))
            self = options?.contains(.shouldResume) == true ? .endedShouldResume : .endedStay
        @unknown default:
            return nil
        }
    }
}
```

Consumed from the player's owning view with `.task` (`05 R34`), so it is cancelled with the view:

```swift
.task { for await event in cues.interruptions { cues.handle(event) } }
```

`05 R48`: an `AsyncStream` is single-consumer. One `for await` over `events`, in one place. Route
changes get their own monitor and their own enum, not a second loop over the same stream.

## 7. Haptics are not real-time

`HapticCuePlayer` is plain `@MainActor` with no hatch. `CHHapticEngine` takes whole patterns and owns
its own threading; the 11 cached `CHHapticPatternPlayer`s are created once and started from the main
actor. `CHHapticEngine`'s `stoppedHandler` and `resetHandler` fire on an arbitrary thread — bridge
them with the same `AsyncStream` shape as §6, never with `MainActor.assumeIsolated` (`05 R36`:
`assumeIsolated` asserts and crashes if you are wrong, and Core Haptics guarantees nothing here).

## 8. Review checklist

Copy this when reviewing any change under `Feedback/`.

- [ ] `VoiceBank` is still the only `@unchecked Sendable` in the repository — the SKILL.md live block
      prints the count.
- [ ] The comment still answers all four questions in §3, and still matches the code.
- [ ] `slots` is still allocated exactly once and never reallocated.
- [ ] There is still exactly one producer and one consumer.
- [ ] The producer still never reads `samplesRemaining`.
- [ ] `head` still uses `.releasing` on the store and `.acquiring` on the load.
- [ ] The render block still allocates nothing and touches no class other than `bank`.
- [ ] Every frequency, envelope, level and duration still comes from `§13.8`, not from a literal.
