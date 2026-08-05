# feedback-target.md — the shape of `Modules/Sources/Feedback/`

Contents: [1 Why it is its own target](#1-why-it-is-its-own-target) · [2 `Cue`](#2-cue--the-shared-vocabulary) ·
[3 `CuePlayer` and the four implementations](#3-cueplayer-and-the-four-implementations) ·
[4 Isolation](#4-isolation) · [5 The real-time hatch](#5-the-real-time-hatch-not-owned-here) ·
[6 Injection](#6-injection) · [7 Testing](#7-testing) · [8 Accessibility](#8-accessibility) ·
[9 What would be wrong](#9-what-would-be-wrong)

Files, from `ios-swift-guide/08-APPLIED-TO-HUNCH.md` §1:

```
Modules/Sources/Feedback/
    Cue.swift                  # the shared cue vocabulary
    CuePlayer.swift            # protocol + SilentCuePlayer + CompositeCuePlayer
    SynthesizedCuePlayer.swift # AVAudioEngine + AVAudioSourceNode; VoiceBank
    HapticCuePlayer.swift      # CHHapticEngine, 11 cached pattern players
```

---

## 1. Why it is its own target

`Feedback` imports `AVFoundation` and `CoreHaptics`, so the boundary rule sends it to `Modules/`
immediately: *a file may live in `HunchCore/` iff it imports nothing but Swift/Foundation and its
behaviour is a pure function of values you can write down in a test.* Both halves fail.

It is separate from `HunchUI` because a cue vocabulary is a **value**, not a view, and because
`LoomFeature`, `CodexFeature` and `MetaFeature` all fire cues without importing each other. It gets
**no default isolation** in `Package.swift` for the same reason `HunchNavigation` does not: a vocabulary
is data.

`Cue` names *what happened in the game*, never *what to play*. `.verdict(.admit, isTwin: false)`, not
`.playFifth`. That is `02 N25` — name the abstraction for what it is — and it is what lets
`SilentCuePlayer` be a legitimate implementation rather than a stub.

## 2. `Cue` — the shared vocabulary

One enum drives **both** players. A verdict is one event that happens to have a sound and a feel; two
enums would let them diverge, and the whole design rests on their landing on the same frame.

```swift
// Modules/Sources/Feedback/Cue.swift
import HunchCore

public enum Cue: Hashable, Sendable {
    case probeSubmit
    case verdict(Verdict, isTwin: Bool)
    case declare
    case bar
    case strike
    case lawDeclaredCorrectly(marks: Int)     // 1…3 — parameterises audio and haptic together
    case lawBroken
    case driftMoment
    case streak(step: Int)                    // 1…5, capped
    case codexInscribe
    case sieveTick
    case sieveHit
    case sieveMiss
}
```

Twelve cases, fifteen audio cues, eleven haptic patterns — the counts differ **because the mapping is
many-to-one in both directions and that is correct**: `.verdict(_:isTwin:)` covers four audio cues
(`admit`, `reject`, and `twin`'s two forms) and three haptic patterns, while `.codexInscribe` has a sound
and no feel. Model the *event*; let each player resolve it.

The parameter tables hang off the enum, one per medium, and each is the sole home for its numbers:

```swift
extension Cue {
    /// §13.8's table, transcribed once. A test asserts every row against the GDD.
    var voices: [VoiceSpec] { … }
    /// §13.9's table, transcribed once. Same test shape.
    var hapticPatterns: [HapticPattern] { … }
}
```

## 3. `CuePlayer` and the four implementations

```swift
// Modules/Sources/Feedback/CuePlayer.swift
public protocol CuePlayer: Sendable {
    @MainActor func play(_ cue: Cue)
}
```

`: Sendable` on the protocol so `AppDependencies` can hold `any CuePlayer`; `@MainActor` on the
requirement because every call site is a view. Both conforming classes are `@MainActor final class`, which
makes them implicitly `Sendable` with no escape hatch.

| Type | Role | Notes |
|---|---|---|
| `SynthesizedCuePlayer` | audio | `AVAudioEngine` + one `AVAudioSourceNode` + `VoiceBank`. Lazy start, 20 s idle stop |
| `HapticCuePlayer` | haptics | `CHHapticEngine`, 11 cached players. No-ops without hardware support |
| `SilentCuePlayer` | previews, tests, and a player with both settings off | a `struct` with an empty `play` |
| `CompositeCuePlayer` | production | fans one `Cue` out to both; the composition root's `cues` |

```swift
public struct CompositeCuePlayer: CuePlayer {
    private let players: [any CuePlayer]
    public init(_ players: any CuePlayer...) { self.players = players }
    @MainActor public func play(_ cue: Cue) { for p in players { p.play(cue) } }
}
```

**Firing order inside the composite is not arbitrary: haptics first, then audio.** `CHHapticPatternPlayer.start`
is cheap; scheduling an audio voice can touch the engine's lazy start on the very first cue of a session.
Playing audio first would push the haptic behind that one-off cost, and the first `admit` of a session is
exactly where the two channels must agree.

## 4. Isolation

- **Target default isolation: none** (SwiftPM's default). `Cue`, `VoiceSpec`, `HapticPattern`,
  `SilentCuePlayer` and `CompositeCuePlayer` are values.
- **`SynthesizedCuePlayer` and `HapticCuePlayer` are `@MainActor final class`** — they own engine handles
  and are driven from views. Both write `@MainActor` explicitly (`05 R8`), even though nothing else in the
  target is isolated.
- **No actors here.** `05 R18`: an actor for a counter is wrong, and an actor around an engine handle buys
  an `await` at every cue for state that only the main actor touches.
- **No `Task.detached`, no `nonisolated(unsafe)`, no `assumeIsolated`.** `07 B34a` check 3 greps for all
  five hatches and requires a justifying comment; the only one this repository is allowed is §5's.

## 5. The real-time hatch — not owned here

`AVAudioSourceNode`'s render block runs on a real-time audio thread: **it may not allocate, may not lock,
and may not touch main-actor state.** `05 R17`'s ladder has no row for it — `@MainActor` is wrong, `Mutex`
is wrong (priority inversion in a render callback), an actor is wrong (no `await` in a render block).

`VoiceBank` is the answer — a fixed 8-slot POD array allocated once in `init`, an atomic head index,
main actor the sole producer and the render thread the sole consumer — and it is **the one
`@unchecked Sendable` in the repository**.

**It is owned by `hunch-swift-concurrency/references/real-time-audio.md`.** Read that file before touching
the render block; do not restate its reasoning here, and do not add a second producer.

The mandatory comment (`05 R26`/`R29`, enforced by `07 B34a` check 3) travels with the declaration, not
with this document.

## 6. Injection

One composition root, `AppDependencies` in `HunchAppFeature`:

```swift
cues: CompositeCuePlayer(SynthesizedCuePlayer(), HapticCuePlayer())
```

and `AppDependencies.preview(seed:date:)` composes `SilentCuePlayer`, so **previews are silent by
construction** — no `#if DEBUG`, no environment check, no `isPreview` flag. Views take `cues: any CuePlayer`
from the environment and never construct a player.

**There is no `CuePlayer.shared`.** A singleton here would be both the brief's banned pattern and a
main-actor global; it would also make "previews are silent" impossible to state as a fact about the graph.

## 7. Testing

`Feedback` cannot be tested by listening, so test the two things that actually break:

1. **The spec tables match the GDD.** One test per medium, walking every `Cue` and comparing `voices` /
   `hapticPatterns` against §13.8 / §13.9. This is the divergence check that keeps M4 honest for values
   that do not live in `Tokens/`.
2. **The onsets match the beat sheet.** `RecordingCuePlayer` captures `(Duration, Cue)` pairs so a reveal
   can be asserted without a simulator:

```swift
@Test("The correct reveal fires its cues on the beats")
@MainActor
func revealOnsets() {
    let recorder = RecordingCuePlayer()
    let schedule = RevealCueSchedule.onsets(for: .inscribed, marks: 3, beats: C.Reveal.correct)
    #expect(schedule.first?.1 == .declare)
    #expect(schedule.contains { $0.0 == .milliseconds(1450) })   // beat 4, registration
    #expect(schedule.contains { $0.0 == .milliseconds(1630) })   // beat 5, codex.inscribe
}
```

`RecordingCuePlayer` **ships** in the target, like `InMemoryPersistenceStore` does, and imports no
`Testing` — previews and the DEBUG snapshot gallery use it too. The `Issue.record`-ing `unimplemented`
doubles stay in `HunchTestSupport`.

Neither engine is exercised in the fast suite. `swift test` must stay under 10 s with no simulator, and an
`AVAudioEngine` on a CI host is a flake, not a test.

## 8. Accessibility

- **The announcement seam is not in this target.** VoiceOver utterances are posted by the view that fires
  the cue, on the same frame, at priority `.high`. Wording is `hunch-accessibility`'s. Putting
  `UIAccessibility.post` inside a `CuePlayer` would make `SilentCuePlayer` silence announcements too.
- **Both channels are optional and neither is load-bearing.** §6.4: any one of geometry, audio and haptic
  alone is sufficient. A player with `Sound` off and `Haptics` off loses nothing but redundancy — that is
  what makes the two toggles honest, and it is asserted by §13.12 gate 3 (a full band-5 round played with
  the screen curtain on) and gate 11(b).
- **`Sound` and `Haptics` are two states each**, in §12.6's FEEDBACK section, `Haptics` directly above
  `Sound`. `Level` is Normal / Low. No sliders.

## 9. What would be wrong

- Putting `Feedback` in `HunchCore`. It imports `AVFoundation` and `CoreHaptics`; the boundary rule is a
  grep and it would fail.
- Two enums, one for audio and one for haptics. A verdict is one event.
- Naming a case for what it plays (`.playFifth`, `.buzz`) rather than what happened (`.verdict(_:isTwin:)`).
- `AudioManager`, `HapticsService`, `CueManager` — all `02 N26` bans.
- A `CuePlayer.shared`, or any singleton in this target.
- An `actor` around an engine handle, or a `Mutex` in the render block.
- A second `@unchecked Sendable`, or an undocumented one. `07 B34a` check 3 fails the build.
- A second producer into `VoiceBank`.
- Shipping any audio file, sample, or `AVAudioFile`. Everything is computed per sample; the binary budget
  is 15 MB and there are no assets.
- Any `URLSession`, `Network` or `NWConnection` reference. Check 5 greps the whole repository.
- Posting a VoiceOver announcement from inside a player.
- Exercising either engine in the fast suite.
- A `#if DEBUG` to silence previews. Compose `SilentCuePlayer` in `AppDependencies.preview` instead.
