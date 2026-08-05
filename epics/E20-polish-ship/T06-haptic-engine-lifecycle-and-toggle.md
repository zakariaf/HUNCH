# T06 — Haptic engine lifecycle and the toggle

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | Engine lifecycle and toggle (HAPTICS) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/haptic-patterns.md` §6 is the entire engine contract in seven bullets — capability checked once and the player *kept* rather than made optional, `isAutoShutdownEnabled = true`, `resetHandler` **and** `stoppedHandler` recreating and re-preparing, patterns compiled on first use and cached, and the sentence this task exists to make literally true: *the `Haptics` toggle is honoured before any engine call, not by muting output*. §7 gives the shape and four wrong forms, one of which (`if !isEnabled { engine?.stop() }`) is the exact bug a naive reading produces. §10's list has "omitting `resetHandler` or `stoppedHandler`" and "surfacing a haptic failure" on it. |
| `hunch-swift-concurrency` | `resetHandler` and `stoppedHandler` are escaping closures the system calls on **its** queue, so they are `05 R45`'s notification-bridge problem in a different costume; `references/real-time-audio.md` §6 has the `AsyncStream.makeStream(of:)` shape T02 and T04 already used, including `R46`'s bounded buffering policy and `R48`'s one-consumer rule. It also owns `R42` (never capture `self` in a `deinit`'s `Task` — use `isolated deinit`) and the hatch count this task must not increase. |
| `hunch-swift-code` | The composition root. `08 §6`'s `AppDependencies.live()` still hands out a `SilentCuePlayer`; this task is where it becomes the real composite, and `04 A2`/`A29`/`08 §6` govern that edit — one root, no `CuePlayer.shared`, and `preview()` untouched so "previews are silent by construction" stays a fact about the dependency graph rather than a `#if DEBUG`. `N26` bans `HapticsService`/`HapticsManager`, which is what the "thin engine" will want to be called. |

`hunch-swift-testing` is not loaded, but one of its facts decides this task's whole test strategy and is
restated here rather than looked up: **`CHHapticEngine.capabilitiesForHardware().supportsHaptics` is
`false` on every simulator**, so nothing below the gate can be exercised by CI. That is why the policy
is a pure value tested exhaustively and the engine is a thin shell tested through a spy.

## Objective

At the end of this task haptics are wired end to end and the app makes a sound *and* a feel: a pure
`HapticGate` decides — before any framework type is touched — whether a cue produces haptic output at
all, and a thin `HapticCuePlayer` executes that decision against one `CHHapticEngine` whose capability
was read once, whose `resetHandler` and `stoppedHandler` are bridged into one `AsyncStream` with one
consumer, whose `isAutoShutdownEnabled` is `true`, and whose every failure is swallowed. The
composition root stops handing out `SilentCuePlayer` and hands out
`CompositeCuePlayer(HapticCuePlayer(), SynthesizedCuePlayer())` — haptics first, in that order,
because T01 ruled it and this is the file that makes the ruling real.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.9 (Settings and system) | iOS exposes **no public read** of the System Haptics switch for Core Haptics, so our own toggle is the player's control and is honoured **before any engine call**; it is a toggle and not a three-way; Low Power suppresses patterns over 0.4 s and transients still fire |
| `GAME_DESIGN.md` | §13.9 (engine paragraph) | `CHHapticEngine`; patterns precompiled on first use and cached (11 players); all calls no-op without hardware support; `isAutoShutdownEnabled = true`; `resetHandler` and `stoppedHandler` recreate and re-prepare |
| `GAME_DESIGN.md` | §12.6 (FEEDBACK) | `Haptics` is a toggle, default **on**, directly above `Sound`; it *gates `CHHapticEngine` entirely*; the key is `hunch.settings.haptics` — **E17·T06 owns the row and the key; this task consumes the value** |
| `GAME_DESIGN.md` | §12.7 | `scenePhase → .background` stops `CHHapticEngine`; `.active` does not restart it |
| `GAME_DESIGN.md` | §6.4 | any one channel alone is sufficient — the licence for swallowing every failure and for `drift.moment` vanishing under Low Power |
| `.claude/skills/hunch-motion-and-feedback/references/haptic-patterns.md` | §5, §6, §7, §8, §10 | the Low Power derivation this task consumes (T05 shipped it), the engine contract, the shape, the accessibility invariants, the wrong forms |
| `.claude/skills/hunch-motion-and-feedback/references/feedback-target.md` | §3, §4, §6 | `HapticCuePlayer` is a `@MainActor final class` in a target with no default isolation; the composite fires haptics first; there is no `CuePlayer.shared` |
| `.claude/skills/hunch-swift-concurrency/references/real-time-audio.md` | §5, §6 | `isolated deinit`; the `AsyncStream` bridge, its bounded buffering policy and its single consumer |
| `ios-swift-guide/05-CONCURRENCY.md` | `R8`, `R34`, `R37`, `R38`, `R42`, `R45`, `R46`, `R48` | explicit `@MainActor`; `.task` cancels with the view; the legal sync→async boundary; no `Task.detached`; no `self` in a `deinit` `Task`; the non-`Sendable` bridge and its two rules |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B34a` check 3 | the hatch grep — this task adds no hatch, and the acceptance criteria prove the count is still one |

**What already exists.** T05 shipped `HapticPatterns.pattern(for:n:)`, `HapticPatterns.composed(for:n:)`,
`HapticPattern.underLowPower` and the eleven rows as pure values. E17·T06 shipped the `Haptics` row and
its `UserDefaults` key. **This task adds no pattern, no intensity and no sharpness**; if you find
yourself typing a number from §13.9, you are in the wrong file.

## TDD — the test comes first

The engine cannot be tested in CI and the policy can be tested exhaustively, so **split them and test
the split**. `HapticGate` is a value: it takes the four inputs, returns a decision, and touches no
framework type. `HapticCuePlayer` is a shell over a `HapticEngineHandle` protocol that the real
`CHHapticEngine` and a test spy both satisfy. Everything interesting is on one side or the other of
that seam and both sides run on a simulator with no haptic hardware.

**Step 1 — write the failing test.** Create `Modules/Tests/FeedbackTests/HapticGateTests.swift`:

```swift
import Testing
import HunchCore
@testable import Feedback

@Suite("The haptic gate — §13.9's settings paragraph as a value", .tags(.unit, .presubmission))
struct HapticGateTests {

    private func gate(enabled: Bool = true, supported: Bool = true,
                      lowPower: Bool = false,
                      engine: HapticGate.EngineState = .running) -> HapticGate {
        HapticGate(isEnabled: enabled, isSupported: supported,
                   isLowPowerModeEnabled: lowPower, engineState: engine)
    }

    // MARK: the ordering, which is the whole point of the type

    @Test("the Haptics setting is consulted before the capability and before the engine",
          arguments: [true, false], [HapticGate.EngineState.notStarted, .running, .needsRecreation])
    func theSettingOutranksEverything(_ supported: Bool, _ engine: HapticGate.EngineState) {
        let decision = gate(enabled: false, supported: supported, engine: engine)
            .decision(for: .verdict(.admit, isTwin: false))
        #expect(decision == .silent(.settingOff))
        // Not `.silent(.noHardware)` even when there is none: the reason is reported as the FIRST
        // gate that fired, and that is what makes "honoured before any engine call" checkable.
    }

    @Test("with no haptic hardware every cue is silent, and the player still exists")
    func capabilityIsTheSecondGate() {
        for cue in Cue.representatives {
            #expect(gate(supported: false).decision(for: cue) == .silent(.noHardware))
        }
    }

    @Test("a permitted cue asks for an engine start only from a state that has none",
          arguments: [HapticGate.EngineState.notStarted, .stopped, .needsRecreation, .running])
    func engineStartIsRequestedOnlyWhenThereIsNoEngine(_ state: HapticGate.EngineState) {
        guard case .play(let plan) = gate(engine: state).decision(for: .bar) else {
            Issue.record("bar must never be silent with the setting on and hardware present")
            return
        }
        #expect(plan.needsEngineStart == (state != .running))
        #expect(plan.needsRecreation == (state == .needsRecreation))
    }

    // MARK: Low Power lands inside the plan, not at the call site

    @Test("Low Power applies T05's derivation and nothing else", arguments: Cue.representatives)
    func lowPowerIsAppliedInsideThePlan(_ cue: Cue) {
        let full = gate(lowPower: false).decision(for: cue)
        let reduced = gate(lowPower: true).decision(for: cue)
        guard case .play(let a) = full else { return }
        switch reduced {
        case .play(let b):
            #expect(b.patterns == a.patterns.map(\.underLowPower).filter { !$0.events.isEmpty })
        case .silent(let reason):
            // Every pattern was suppressed to nothing — drift.moment is the only such cue.
            #expect(reason == .nothingToPlay)
            #expect(a.patterns.allSatisfy { $0.underLowPower.events.isEmpty })
        }
    }

    @Test("drift.moment under Low Power is silent, and that is a decision rather than an error")
    func driftMomentVanishesCleanly() {
        #expect(gate(lowPower: true).decision(for: .driftMoment) == .silent(.nothingToPlay))
        #expect(gate(lowPower: false).decision(for: .driftMoment) != .silent(.nothingToPlay))
    }

    @Test("law.declared.correctly keeps its landing and its marks under Low Power", arguments: 1...3)
    func theBeatSixPayoffSurvives(_ marks: Int) {
        guard case .play(let plan) =
            gate(lowPower: true).decision(for: .lawDeclaredCorrectly(marks: marks)) else {
            Issue.record("the reveal must still be felt in Low Power"); return
        }
        #expect(plan.patterns.flatMap(\.events).count == 1 + marks)
        #expect(plan.patterns.flatMap(\.events).allSatisfy { $0.kind == .transient })
    }

    // MARK: totality

    @Test("the gate is total over every cue in every configuration")
    func theGateIsTotal() {
        for cue in Cue.representatives {
            for enabled in [true, false] {
                for supported in [true, false] {
                    for lowPower in [true, false] {
                        for engine in HapticGate.EngineState.allCases {
                            _ = gate(enabled: enabled, supported: supported,
                                     lowPower: lowPower, engine: engine).decision(for: cue)
                        }
                    }
                }
            }
        }
    }

    @Test("a cue with no haptic row is silent without ever asking for an engine")
    func silentInHapticsMeansSilent() {
        for cue in [Cue.declare, .codexInscribe, .sieveTick] {
            #expect(gate().decision(for: cue) == .silent(.nothingToPlay))
        }
    }

    @Test("twin composes to two patterns and the second one is offset")
    func twinIsTwoStarts() {
        guard case .play(let plan) = gate().decision(for: .verdict(.reject, isTwin: true)) else {
            Issue.record("twin must play"); return
        }
        #expect(plan.patterns.count == 2)
        #expect(plan.patterns[0].offset == .zero)
        #expect(plan.patterns[1].offset > .zero)
    }
}
```

Then `Modules/Tests/FeedbackTests/HapticEngineLifecycleTests.swift`, which is the whole reason the
engine sits behind a protocol:

```swift
import Testing
@testable import Feedback

@Suite("The engine shell — §13.9's engine paragraph", .tags(.unit, .presubmission))
@MainActor
struct HapticEngineLifecycleTests {

    @Test("with Haptics off nothing is created, prepared or started — ever")
    func theToggleGatesTheCallAndNotTheOutput() {
        let spy = HapticEngineSpy()
        let player = HapticCuePlayer(engine: { spy }, isSupported: true)
        player.isEnabled = false
        for cue in Cue.representatives { player.play(cue) }
        #expect(spy.log.isEmpty)                       // not "started then muted": nothing at all
    }

    @Test("with no hardware the player exists, no-ops, and never becomes nil")
    func capabilityIsCheckedOnceAndTheEngineIsNeverBuilt() {
        let spy = HapticEngineSpy()
        let player = HapticCuePlayer(engine: { spy }, isSupported: false)
        player.play(.bar)
        #expect(spy.log.isEmpty)
        #expect(player.isEnabled)                      // the setting is untouched by the capability
    }

    @Test("the engine is built on the first permitted cue and auto-shutdown is set before start")
    func lazyCreationAndAutoShutdown() async {
        let spy = HapticEngineSpy()
        let player = HapticCuePlayer(engine: { spy }, isSupported: true)
        #expect(spy.log.isEmpty)
        player.play(.bar)
        await player.settleForTesting()
        #expect(spy.log.prefix(3) == [.created, .setAutoShutdown(true), .started])
        #expect(spy.log.contains(.startedPlayer(row: .bar)))
    }

    @Test("a reset drops every cached player before recreating the engine")
    func resetInvalidatesTheCache() async {
        let spy = HapticEngineSpy()
        let player = HapticCuePlayer(engine: { spy }, isSupported: true)
        player.play(.admit); await player.settleForTesting()
        #expect(player.cachedPlayerCountForTesting == 1)

        spy.fireReset()
        await player.settleForTesting()
        #expect(player.cachedPlayerCountForTesting == 0)   // stale players throw on every start
        #expect(spy.log.contains(.created))                // recreated…
        #expect(spy.log.contains(.started))                // …and re-prepared

        player.play(.admit); await player.settleForTesting()
        #expect(spy.log.last == .startedPlayer(row: .admit))
    }

    @Test("a stop marks the engine for restart and the next cue restarts it")
    func stoppedHandlerRestartsOnDemand() async {
        let spy = HapticEngineSpy()
        let player = HapticCuePlayer(engine: { spy }, isSupported: true)
        player.play(.admit); await player.settleForTesting()
        spy.fireStopped(.idleTimeout)
        await player.settleForTesting()
        #expect(player.engineStateForTesting == .needsRecreation)
        spy.log.removeAll()
        player.play(.reject); await player.settleForTesting()
        #expect(spy.log.contains(.started))
    }

    @Test("a throwing start is swallowed: nothing is surfaced and the next cue tries again")
    func failuresAreNeverSurfaced() async {
        let spy = HapticEngineSpy(); spy.startError = HapticEngineSpy.Failure.refused
        let player = HapticCuePlayer(engine: { spy }, isSupported: true)
        player.play(.bar)
        await player.settleForTesting()
        #expect(player.lastErrorForTesting != nil)         // recorded for the test, never for the player
        #expect(spy.log.contains(.startedPlayer(row: .bar)) == false)
        spy.startError = nil
        player.play(.bar); await player.settleForTesting()
        #expect(spy.log.contains(.startedPlayer(row: .bar)))
    }

    @Test("backgrounding stops the engine; returning does not restart it")
    func scenePhasePolicy() async {
        let spy = HapticEngineSpy()
        let player = HapticCuePlayer(engine: { spy }, isSupported: true)
        player.play(.admit); await player.settleForTesting()
        player.handleScenePhase(.background)
        #expect(spy.log.contains(.stopped))
        spy.log.removeAll()
        player.handleScenePhase(.active)
        #expect(spy.log.isEmpty)
    }

    @Test("one engine-event stream, one consumer")
    func oneStreamOneConsumer() {
        #expect(HapticCuePlayer.eventBufferingPolicyForTesting == .bufferingNewest(1))
    }
}
```

`HapticEngineSpy` is hand-written in the test target (`06 T36`/`T52` ban every mocking framework): a
`@MainActor final class` conforming to `HapticEngineHandle`, appending a `Step` enum to `log`, with
`fireReset()` and `fireStopped(_:)` calling the handlers the player installed.

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" \
  -only-testing:FeedbackTests/HapticGateTests \
  -only-testing:FeedbackTests/HapticEngineLifecycleTests | xcbeautify
```

Expect `cannot find 'HapticGate' in scope` and `cannot find 'HapticCuePlayer' in scope`. Two failures
to read carefully once the types exist:

- `theSettingOutranksEverything` failing with `.silent(.noHardware)` means the gate checks capability
  first. That compiles, ships, and is wrong: on a device with the setting off it behaves identically,
  so nothing catches it until someone reorders the two and the *engine* gets touched with the setting
  off. Order is the deliverable.
- `theGateIsTotal` crashing rather than failing means a `switch` somewhere has a `!` or an
  index-out-of-range on an unexpanded parameter. Fix it in the gate, not in the test's arguments.

**Step 3 — implement.** `HapticGate` first — it compiles with no `import CoreHaptics` — then the
handle protocol, then the shell, then the composition root.

**Step 4 — green, then feel it.** Build to a device with Haptics on, then off, then in Low Power, and
confirm by thumb that the toggle is instant and that a barred Seal in Low Power still thuds. Then run
`/simplify`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/Feedback/HapticGate.swift` — the policy, `EngineState`, `Decision`, `Reason`, `PlayPlan` |
| create | `Modules/Sources/Feedback/HapticEngineHandle.swift` — the protocol both the real engine and the spy satisfy |
| create | `Modules/Sources/Feedback/HapticCuePlayer.swift` — the shell: cache, the `AsyncStream` bridge, scene phase, `isolated deinit` |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — `live()` composes the real players, haptics first |
| create | `Modules/Tests/FeedbackTests/HapticGateTests.swift` |
| create | `Modules/Tests/FeedbackTests/HapticEngineLifecycleTests.swift` |
| create | `Modules/Tests/FeedbackTests/HapticEngineSpy.swift` |
| modify | `DECISIONS.md` — the dropped-first-cue ruling and the `bufferingNewest(1)` ruling |
| modify | `tests.json` — `haptics.gate-policy`, `haptics.engine-lifecycle` |

## Implementation notes

### The gate is a value, and that is what makes §13.9's sentence checkable

> *"our own `Haptics` toggle … is honoured before any engine call"*

A sentence about **ordering** cannot be asserted from outside the object that does the ordering unless
the ordering is itself a value. So it is:

```swift
public struct HapticGate: Hashable, Sendable {
    public enum EngineState: CaseIterable, Hashable, Sendable {
        case notStarted, running, stopped, needsRecreation
    }
    public enum Reason: Hashable, Sendable { case settingOff, noHardware, nothingToPlay }
    public struct PlayPlan: Hashable, Sendable {
        public var patterns: [HapticPattern]     // already composed and already Low-Power-reduced
        public var needsEngineStart: Bool
        public var needsRecreation: Bool
    }
    public enum Decision: Hashable, Sendable { case silent(Reason), play(PlayPlan) }

    public var isEnabled: Bool                   // §12.6's Haptics row
    public var isSupported: Bool                 // read ONCE, at construction
    public var isLowPowerModeEnabled: Bool
    public var engineState: EngineState

    /// The order below is the specification, not an implementation detail.
    public func decision(for cue: Cue, n: Int = 0) -> Decision {
        guard isEnabled else { return .silent(.settingOff) }          // 1. §13.9
        guard isSupported else { return .silent(.noHardware) }         // 2. §13.9
        let composed = HapticPatterns.composed(for: cue, n: n)         // 3. T05's values
        let reduced = isLowPowerModeEnabled                            // 4. T05's derivation
            ? composed.map(\.underLowPower).filter { !$0.events.isEmpty }
            : composed
        guard !reduced.isEmpty else { return .silent(.nothingToPlay) }
        return .play(PlayPlan(patterns: reduced,
                              needsEngineStart: engineState != .running,
                              needsRecreation: engineState == .needsRecreation))
    }
}
```

Four things that are deliberate:

- **`Reason` reports the *first* gate that fired.** A player with haptics off on a phone with no Taptic
  Engine reports `.settingOff`, not `.noHardware`. That is the assertion in
  `theSettingOutranksEverything`, and it is the only way a test can see an order.
- **Low Power reduction happens here, not in the shell**, so `underLowPower` (T05) is applied at one
  site rather than at eleven, and the empty result is a *decision* rather than an error path.
- **`needsRecreation` is separate from `needsEngineStart`.** After a media-services reset the engine
  object itself is dead; after auto-shutdown it merely needs starting. Collapsing them makes the reset
  path silently reuse a dead handle, which is the failure §13.9's `resetHandler` sentence exists to
  prevent.
- **The gate never touches `CoreHaptics`.** `HapticGate.swift` has no `import CoreHaptics`, which is
  checkable and is in the acceptance criteria.

### The handle, and why the shell needs one

```swift
@MainActor
protocol HapticEngineHandle: AnyObject {
    var isAutoShutdownEnabled: Bool { get set }
    func setHandlers(reset: @escaping @Sendable () -> Void,
                     stopped: @escaping @Sendable (HapticStopReason) -> Void)
    func start() async throws
    func stop()
    func makePlayer(_ pattern: HapticPattern) throws -> any HapticPatternPlaying
}
```

`CHHapticEngine` conforms in a five-line extension; `HapticEngineSpy` conforms in the test target.
Without it there is no way to assert *"nothing was created"*, and *"nothing was created"* is the whole
of §12.6's `Haptics` row. `HapticStopReason` is our own `Sendable` enum mapped from
`CHHapticEngine.StoppedReason` in that same extension — the Objective-C enum crosses no isolation
boundary and no test needs `CoreHaptics` linked to name a case.

### The two handlers are one stream, and the buffering policy is a ruling

`resetHandler` and `stoppedHandler` are escaping closures the system calls on its own queue. That is
`05 R45` — bridge them, let only a small `Sendable` value cross:

```swift
private let events: AsyncStream<HapticEngineEvent>
private let continuation: AsyncStream<HapticEngineEvent>.Continuation

// R46: bounded, never the unbounded default.
static let eventBufferingPolicy: AsyncStream<HapticEngineEvent>.Continuation.BufferingPolicy
    = .bufferingNewest(1)
```

**Ruling, and it needs writing down because `bufferingNewest(1)` normally loses information:** both
events resolve to the same action — *drop every cached player, recreate, re-prepare* — so collapsing a
burst to its newest member loses nothing. If a future event ever means something different from
"recreate", this policy stops being safe and the stream needs a second one rather than a bigger buffer.
Record that in `DECISIONS.md` with the reasoning, not just the value.

One `for await`, started once (`05 R48`), from the view that owns the player with `.task` so it is
cancelled with the view (`05 R34`) — not from `init`, which would outlive the surface:

```swift
.task { await dependencies.haptics.consumeEngineEvents() }
```

### Lazy creation, `isAutoShutdownEnabled`, and the first cue that is lost

`CHHapticEngine.start()` is `async throws` and costs real milliseconds. `play(_:)` is synchronous and
`@MainActor`, so the start is a `Task { }` that inherits main-actor isolation (`05 R37`; never
`Task.detached`, `05 R38`).

**Ruling: the cue that triggered the start is not queued.** A haptic that arrives 60–100 ms late is a
different event from the one that was asked for — on a verdict it would land after the ring has
finished — and §6.4 guarantees the moment is already carried by geometry and by the cue table. Queue
it and the first `admit` of a session feels like a stutter; drop it and it feels like nothing, which is
one of the two states the design already sanctions. Record it in `DECISIONS.md`.

Set `isAutoShutdownEnabled = true` **before** `start()`, in that order, and the spy asserts the order.
Auto-shutdown is what replaces an idle-stop timer here: unlike `AVAudioEngine` (T04's 20 s policy),
Core Haptics has a documented shutdown of its own and re-arming it by hand is two policies for one
behaviour.

```swift
@MainActor
public final class HapticCuePlayer: CuePlayer {
    private var engine: (any HapticEngineHandle)?
    private var players: [PatternKey: any HapticPatternPlaying] = [:]
    private var state: HapticGate.EngineState = .notStarted
    private let isSupported: Bool                       // §13.9: checked ONCE, at construction
    private let makeEngine: @MainActor () -> any HapticEngineHandle

    public var isEnabled = true                         // §12.6's row, injected by the app layer
    public var isLowPowerModeEnabled = false

    public func play(_ cue: Cue) {
        let gate = HapticGate(isEnabled: isEnabled, isSupported: isSupported,
                              isLowPowerModeEnabled: isLowPowerModeEnabled, engineState: state)
        guard case .play(let plan) = gate.decision(for: cue, n: cue.hapticParameter) else { return }
        if plan.needsRecreation { teardown() }
        if plan.needsEngineStart { startEngine(); return }   // this cue is dropped — see the ruling
        for pattern in plan.patterns { schedule(pattern) }
    }
}
```

`guard case .play` with no `else` branch is the whole of "failures are never surfaced": there is no
alert, no `print`, no `Issue.record`, no analytics — analytics do not exist here at all (check 5).

### The cache, and the one line that stops haptics dying silently

Patterns compile to players on first use and are cached on `(row, n)` (T05's key). **On `reset`, the
cache must be emptied before the engine is recreated.** A `CHHapticPatternPlayer` belongs to the engine
that made it; after a media-services reset every cached player throws on `start`, the catch swallows
it, and haptics are dead for the rest of the session with nothing in the UI to show it. That is the
failure `haptic-patterns.md` §6 names, and `resetInvalidatesTheCache` is the test that keeps it fixed.

```swift
private func teardown() {
    players.removeAll()          // FIRST. Stale players outlive the engine and throw forever.
    engine?.stop()
    engine = nil
    state = .needsRecreation
}
```

### `deinit`, and the rule it would break

```swift
isolated deinit {
    eventConsumer?.cancel()
    engine?.stop()
}
```

`05 R42`: never capture `self` in a `deinit`'s `Task`. `isolated deinit` is the shape
`real-time-audio.md` §5 uses for the audio engine and it is the same problem here — a `Task { self.stop() }`
in `deinit` is a use-after-free the compiler will not catch.

### The composition root — the two-line edit this whole epic has been walking toward

```swift
// Modules/Sources/HunchAppFeature/AppDependencies.swift
public static func live() -> AppDependencies {
    …
    // §13.8 / §13.9. HAPTICS FIRST: CHHapticPatternPlayer.start is cheap, while scheduling an
    // audio voice can touch AVAudioEngine's lazy start on the first cue of a session, and the
    // first `admit` of a session is exactly where the two channels must agree (T01).
    cues: CompositeCuePlayer(HapticCuePlayer(), SynthesizedCuePlayer())
}
```

`preview(seed:date:)` is **not** touched: it keeps `SilentCuePlayer`, so "previews are silent by
construction" stays a fact about the dependency graph and needs no `#if DEBUG` (`08 §6`). The two
Settings values reach the players from the app layer, where `UserDefaults` is read — `Feedback` never
reads a preference, which is the same boundary that keeps `HunchCore` free of `Locale.current`.

### Scene phase

`.background` stops the engine (§12.7). `.active` does **not** restart it — the next cue does, through
the same `needsEngineStart` path. That is one policy, not two, and it is why `handleScenePhase` is
four lines and not a state machine. E17·T09 owns the app-wide `scenePhase` table; this task registers
the haptic half against it, exactly as T04 registered the audio half.

### Three things not to do, all of which compile

- **`if !isEnabled { engine?.stop() }` after starting the player.** The engine spins up, holds the
  haptic server awake, and costs battery for a player who turned it off. The toggle gates the *call*.
- **`engine: CHHapticEngine?` as the "is it available" signal.** Capability is a `let` read once;
  making the engine optional conflates "no hardware" with "not started yet" and the reset path then
  cannot tell them apart.
- **Routing anything through `UIFeedbackGenerator`** for "system consistency". It obeys a different
  switch, has none of the eleven patterns, and would make two of them behave unlike the other nine.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:FeedbackTests/HapticGateTests` green, all eight tests; `…/HapticEngineLifecycleTests` green, all eight.
- [ ] `grep -n 'import CoreHaptics' Modules/Sources/Feedback/HapticGate.swift` returns nothing — the policy is a value and compiles without the framework.
- [ ] `grep -n 'isAutoShutdownEnabled' Modules/Sources/Feedback/HapticCuePlayer.swift` shows it set to `true`, and the spy asserts it is set **before** `start()`.
- [ ] `grep -c 'for await' Modules/Sources/Feedback/HapticCuePlayer.swift` is `1`, and the buffering policy is `.bufferingNewest(1)`.
- [ ] `grep -rn 'UIFeedbackGenerator\|UIImpactFeedback\|UINotificationFeedback\|UISelectionFeedback' Modules/ App/` returns nothing.
- [ ] `grep -rn 'showAlert\|print(\|os_log\|Issue.record' Modules/Sources/Feedback/` returns nothing — no failure reaches the player or the console.
- [ ] `grep -rn '@unchecked Sendable' HunchCore Modules App | wc -l` → `1` (T02's `VoiceBank`), and `Scripts/check-source-hygiene.sh` check 3 is green.
- [ ] `grep -rn 'Task.detached\|DispatchQueue\|assumeIsolated' Modules/Sources/Feedback/` returns nothing; `deinit` is `isolated deinit`.
- [ ] `grep -n 'CompositeCuePlayer(' Modules/Sources/HunchAppFeature/AppDependencies.swift` shows `HapticCuePlayer()` **before** `SynthesizedCuePlayer()` in `live()`, and `SilentCuePlayer` still in `preview(`.
- [ ] On a device: Haptics off ⇒ Instruments shows no `CHHapticEngine` instantiated across a full round; Haptics on ⇒ the barred Seal thuds in Low Power. Both noted in `PROGRESS.md`.
- [ ] `DECISIONS.md` carries the dropped-first-cue ruling and the `bufferingNewest(1)` ruling, each with its reasoning and its expiry condition.
- [ ] `tests.json` carries `haptics.gate-policy` and `haptics.engine-lifecycle` with their `-only-testing` commands.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Reject any suggestion that inlines `HapticGate` into the player: the ordering is the deliverable and inlining it deletes the only test that can see it. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T06: HapticGate, the thin CHHapticEngine shell, and the composition root switched to the real composite"`

## Out of scope

- Every event kind, time, intensity and sharpness, the twin composition and the Low Power derivation — **T05**. This task calls them and writes none of them.
- Every frequency, envelope and bus — **T03**, **T04**.
- The `Haptics` Settings row, its drawn toggle and its `UserDefaults` key — **E17·T06**. This task consumes the value.
- The app-wide `scenePhase` table — **E17·T09**; this task registers the haptic half against it.
- **When** each pattern fires — **E08·T06**, **E09·T09/T10**, **E12·T08**, **E14·T04**, **E16·T04**. T08 attaches the remaining micro-responses.
- Running §13.12 gate 12's three-tester face-down panel — **T12**.
- The audio engine's own lifecycle, which looks superficially identical and is a different policy (20 s idle stop, no auto-shutdown) — **T04**.
