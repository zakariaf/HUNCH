# T09 — Pause, interruption and leaving a round

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | Leaving a round · `SievePauseOverlay` (the scene-phase half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-chrome-and-meta` | Owns the two places this task touches chrome: `references/instrument-bar.md` §3, whose per-screen table already states *"`SieveRoundView` | leading: **nothing** — §12.7 is explicit"* and whose "Wrong" list names "a chevron in SIEVE's bar" as a defect; and `references/scrim.md` §4, which rules that the SIEVE pause scrim does **not** dismiss on tap because resuming needs a deliberate tap on the gate itself. |
| `hunch-motion-and-feedback` | Owns *what happens when*. `references/transitions.md` §4 is §12.7's table already transcribed for both column groups, and §5 owns the 600 ms spin-up's stagger — throat, then ribbon tiles leading → trailing at 40 ms each, then the Dial — including the rule that the stagger is capped so the total never moves, and its Reduce Motion form. It also owns the law that the model never waits on an animation, which is why every one of these transitions is decoration over settled state. |

## Objective

At the end of this task §12.7's whole interruption table is a value: one pure
`ScenePhasePolicy.effects(entering:from:in:)` covering both column groups, exhaustively tested on the
host. The leading chevron suspends silently in PROBE, DRIFT and ECHO with no confirmation; SIEVE has
no chevron anywhere while it streams and gains one only in `paused`, behind a confirming second tap;
and returning to `.active` in the three untimed modes runs a 600 ms spin-up.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | **§12.7** | the whole table — six event rows × two column groups — plus the *Leaving a round* paragraph and the SIEVE-exception paragraph with its two stated reasons |
| `GAME_DESIGN.md` | §9.2 | SIEVE's commit bar: `pause` alone during `streaming`; in `paused` the same slot gains a leading chevron that ends the run on a second confirming tap; the instrument bar carries foul ticks and the progress arc and nothing else |
| `GAME_DESIGN.md` | §12.2 screens 5 and 18 | `SieveRoundView`'s exits; `SievePauseOverlay`'s entry (`scenePhase != .active` during SIEVE, or the pause key) and its two exits |
| `GAME_DESIGN.md` | §11.13 | the flush order on `.background` — `round.json` first, the snapshot slot cleared last |
| `GAME_DESIGN.md` | §9.8 | the 3-glyph run-up at `r₀`, and the void-on-termination rule that makes SIEVE's termination row different from every other mode's |
| `GAME_DESIGN.md` | §6.10 | relaunch after termination in PROBE/DRIFT opens directly into the round — the row this task must **not** confuse with the 600 ms spin-up |
| `GAME_DESIGN.md` | §13.7.4 | Reduce Motion: the spin-up keeps its stagger because a staggered opacity ramp translates nothing |
| `GAME_DESIGN.md` | §13.8, §13.9 | `AVAudioEngine` and `CHHapticEngine` stop on `.background`; the engine restarts only on `.shouldResume` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | the boundary predicate — a policy that returns effects **as data** is a pure function of values and therefore core |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/ScenePhasePolicyTests.swift`:

```swift
import Foundation
import Testing
import Rounds
import Persistence
import HunchTestSupport

@Suite("§12.7's interruption table, both column groups", .tags(.unit, .presubmission))
struct ScenePhasePolicyTests {

    private let untimed: [Mode] = [.probe, .drift, .echo]

    // MARK: - .inactive

    @Test("untimed modes show nothing on .inactive — the round is already on disk", arguments: [Mode.probe, .drift, .echo])
    func inactiveIsInvisibleWhenUntimed(_ mode: Mode) {
        let effects = ScenePhasePolicy.effects(entering: .inactive, from: .active, in: mode)
        #expect(effects.isEmpty)
    }

    @Test("SIEVE freezes on the current frame within one display tick and drops its scrim")
    func inactiveFreezesSieve() {
        let effects = ScenePhasePolicy.effects(entering: .inactive, from: .active, in: .sieve)
        #expect(effects.contains(.freezeStream(within: .oneDisplayTick)))
        #expect(effects.contains(.presentPauseOverlay))
    }

    // MARK: - .background

    @Test("every mode flushes round.json FIRST and stops both engines", arguments: Mode.allCases)
    func backgroundFlushesInOrder(_ mode: Mode) throws {
        let effects = ScenePhasePolicy.effects(entering: .background, from: .inactive, in: mode)
        let flush = try #require(effects.compactMap(\.flushOrder).first)
        #expect(flush.first == .round(mode))                     // §11.13: smallest file, written first
        #expect(flush.last == .manifest)                          // the snapshot slot is cleared last
        #expect(effects.contains(.stopAudioEngine))
        #expect(effects.contains(.stopHapticEngine))
    }

    @Test("SIEVE additionally writes the frozen stream position")
    func backgroundWritesSievePosition() {
        let effects = ScenePhasePolicy.effects(entering: .background, from: .inactive, in: .sieve)
        #expect(effects.contains(.writeFrozenStreamPosition))
        for mode in untimed {
            #expect(!ScenePhasePolicy.effects(entering: .background, from: .inactive, in: mode)
                .contains(.writeFrozenStreamPosition))
        }
    }

    // MARK: - .active

    @Test("untimed modes spin up over 600 ms in one order", arguments: [Mode.probe, .drift, .echo])
    func activeSpinsUp(_ mode: Mode) throws {
        let effects = ScenePhasePolicy.effects(entering: .active, from: .background, in: mode)
        let spinUp = try #require(effects.compactMap(\.spinUp).first)
        #expect(spinUp.stages == [.throatRing, .ribbonLeadingToTrailing, .dial])
        #expect(spinUp.total == C.SpinUp.total)
    }

    @Test("SIEVE does NOT spin up — the overlay stays and the gate owns the resume")
    func activeDoesNotSpinUpSieve() {
        let effects = ScenePhasePolicy.effects(entering: .active, from: .background, in: .sieve)
        #expect(effects.compactMap(\.spinUp).isEmpty)
        #expect(effects.contains(.keepPauseOverlay))
        #expect(effects.contains(.awaitGateTap))
    }

    // MARK: - termination, audio, power, memory

    @Test("termination resumes the round in untimed modes and VOIDS a SIEVE run", arguments: Mode.allCases)
    func terminationPolicy(_ mode: Mode) {
        let effects = ScenePhasePolicy.effects(entering: .active, from: .terminated, in: mode)
        if mode == .sieve {
            #expect(effects.contains(.voidRun))
            #expect(effects.contains(.openFrame))
            #expect(effects.contains(.writeRunRecord(marked: .void)))
        } else {
            #expect(effects.contains(.openRoundDirectly))
            #expect(!effects.contains(.voidRun))
        }
    }

    @Test("an audio interruption restarts only on .shouldResume", arguments: Mode.allCases)
    func audioInterruption(_ mode: Mode) {
        #expect(ScenePhasePolicy.audioInterruption(.began, in: mode) == [.stopAudioEngine])
        #expect(ScenePhasePolicy.audioInterruption(.ended(shouldResume: false), in: mode) == [])
        #expect(ScenePhasePolicy.audioInterruption(.ended(shouldResume: true), in: mode) == [.startAudioEngine])
    }

    @Test("Low Power stops the shader and the Frame's idle glyph, and caps SIEVE's frame rate", arguments: Mode.allCases)
    func lowPower(_ mode: Mode) {
        let effects = ScenePhasePolicy.lowPowerModeEnabled(in: mode)
        #expect(effects.contains(.disableShader))
        #expect(effects.contains(.stopIdleLoomDrift))
        #expect(effects.contains(.capStreamFrameRate) == (mode == .sieve))
    }

    @Test("a memory warning drops the contextual pair table and unmaps the index, in every mode",
          arguments: Mode.allCases)
    func memoryWarning(_ mode: Mode) {
        let effects = ScenePhasePolicy.memoryWarning(in: mode)
        #expect(effects.contains(.dropContextualPairTable))
        #expect(effects.contains(.unmapLawIndex))
    }

    @Test("the policy is total: every phase pair × every mode returns without trapping")
    func policyIsTotal() {
        for from in AppPhase.allCases {
            for to in AppPhase.allCases {
                for mode in Mode.allCases {
                    _ = ScenePhasePolicy.effects(entering: to, from: from, in: mode)
                }
            }
        }
    }
}
```

And `Modules/Tests/LoomFeatureTests/LeavingARoundTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
@testable import LoomFeature

@Suite("Leaving a round — §12.7, §9.2", .tags(.unit, .presubmission))
struct LeavingARoundTests {

    @Test("PROBE, DRIFT and ECHO carry a leading chevron that suspends on ONE tap, with no confirmation",
          arguments: [Mode.probe, .drift, .echo])
    func untimedChevron(_ mode: Mode) {
        let bar = RoundInstrumentBar(mode: mode, phase: .probing)
        #expect(bar.leading == .chevron)
        #expect(bar.chevronBehaviour == .suspendImmediately)
        #expect(bar.chevronConfirmations == 1)
    }

    @Test("SIEVE has NO chevron in its instrument bar, in any phase", arguments: SievePhase.allCases)
    func sieveBarNeverHasAChevron(_ phase: SievePhase) {
        #expect(RoundInstrumentBar(mode: .sieve, phase: .sieve(phase)).leading == .nothing)
    }

    @Test("SIEVE's commit bar holds pause alone while streaming")
    func sieveCommitBarWhileStreaming() {
        let bar = SieveCommitBar(phase: .streaming)
        #expect(bar.keys == [.pause])
    }

    @Test("SIEVE's commit bar gains the abandon chevron ONLY in paused, and it needs two taps")
    func sieveCommitBarWhenPaused() {
        let bar = SieveCommitBar(phase: .paused)
        #expect(bar.keys == [.abandonChevron, .pause])          // leading, then trailing
        #expect(bar.abandonConfirmations == 2)
    }

    @Test("the pause scrim does not resume on tap — only the gate band does")
    func onlyTheGateResumes() {
        let overlay = SievePauseOverlayBehaviour()
        #expect(overlay.scrimTap == .none)
        #expect(overlay.gateTap == .resume)
    }

    @Test("there is no pause control in PROBE, DRIFT or ECHO — there is no clock to pause",
          arguments: [Mode.probe, .drift, .echo])
    func noPauseWhenUntimed(_ mode: Mode) {
        #expect(!RoundCommitBar(mode: mode).keys.contains(.pause))
    }

    @Test("confirm-by-repeat exists exactly twice in the app")
    func exactlyTwoConfirmByRepeats() {
        #expect(ConfirmByRepeat.allSites == [.sealOptional, .sieveAbandon])
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter ScenePhasePolicyTests` and
`swift test --package-path Modules --filter LeavingARoundTests`

Failures must be missing symbols — `ScenePhasePolicy`, `SceneEffect`, `AppPhase`, `C.SpinUp`,
`RoundInstrumentBar`, `SieveCommitBar`, `ConfirmByRepeat` — or a wrong row. `inactiveIsInvisibleWhenUntimed`
passing before the policy exists means `effects` returns `[]` unconditionally; check
`inactiveFreezesSieve` fails first.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/ScenePhasePolicy.swift` |
| create | `HunchCore/Sources/Rounds/SceneEffect.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — add `C.SpinUp` (the total and the three stage windows) |
| create | `Modules/Sources/LoomFeature/ScenePhaseBridge.swift` — maps SwiftUI's `ScenePhase` to `AppPhase` and performs the effects |
| create | `Modules/Sources/LoomFeature/SpinUp.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — the leading chevron, and `.onChange(of: scenePhase)` |
| modify | `Modules/Sources/LoomFeature/EchoRoundView.swift` — the leading chevron |
| modify | `Modules/Sources/LoomFeature/SieveRoundView.swift` — assert the bar has no chevron; commit bar keys by phase |
| modify | `Modules/Sources/LoomFeature/SievePauseOverlay.swift` — the abandon chevron, presented only from `paused` |
| create | `HunchCore/Tests/RoundsTests/ScenePhasePolicyTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/LeavingARoundTests.swift` |
| modify | `tests.json` — six entries: the `.inactive`, `.background`, `.active` and termination rows; the chevron policy per mode; and the two confirm-by-repeat sites |

## Implementation notes

### The policy is core, and returns effects as data

`08 §2`'s boundary predicate: a file may live in `HunchCore/` iff it imports nothing but
Swift/Foundation **and** its behaviour is a pure function of values you can write down. A function
`(AppPhase, AppPhase, Mode) -> [SceneEffect]` is exactly that — it decides *what should happen*, and
`LoomFeature` decides *how*. Putting the table in a view would make §12.7 — twelve cells that must
all be right — testable only in the simulator, and it is the kind of table that rots one cell at a
time.

```swift
// HunchCore/Sources/Rounds/SceneEffect.swift
public enum AppPhase: CaseIterable, Sendable { case active, inactive, background, terminated }

public enum SceneEffect: Hashable, Sendable {
    case flush([StoreFile])                 // §11.13's order, as a list
    case writeFrozenStreamPosition
    case stopAudioEngine, startAudioEngine
    case stopHapticEngine
    case freezeStream(within: FreezeDeadline)
    case presentPauseOverlay, keepPauseOverlay, awaitGateTap
    case spinUp(SpinUpPlan)
    case openRoundDirectly, openFrame
    case voidRun, writeRunRecord(marked: RunMark)
    case disableShader, stopIdleLoomDrift, capStreamFrameRate
    case dropContextualPairTable, unmapLawIndex
}
```

**`SwiftUI.ScenePhase` never crosses the boundary.** `AppPhase` is our own four-case mirror, mapped
at the edge in `ScenePhaseBridge`, and it carries a `terminated` case SwiftUI does not have — because
§12.7's termination row is a real event with a real policy and it is observed at *relaunch*, not at
`scenePhase`.

`effects(entering:from:in:)` is a `switch` over `(to, mode)` with **no `default:`** (`W29`), so a
fifth mode or a fifth phase breaks it at compile time.

### The two column groups are a `Mode` split, not a `Bool`

§12.7's table has two columns: "PROBE / DRIFT / ECHO" and "SIEVE". Resist
`if mode.isTimed { … } else { … }`: the grouping is *which modes have a clock*, and §9.1 already
states SIEVE is the only one. Model it as a computed `var hasStreamClock: Bool` on `Mode` with the
§9.1 citation in its doc comment, and let the two branches read as the table does. A `Bool` parameter
threaded through the policy would be the same fact with a second home.

### The 600 ms spin-up, and the two beats it is not

§12.7's `.active` row: *"600 ms spin-up: the throat ring re-lights, ribbon tiles fade in leading →
trailing at 40 ms each, then the Dial."* `transitions.md` §5 adds the two properties that matter:

- **it is a stagger, not a crossfade**, and the direction is load-bearing — it re-reads the chain in
  the order the player built it;
- **the stagger is capped so the total stays 600 ms**; tiles past the cap arrive together.

Model it as `SpinUpPlan`, a value with three stage windows and a derived per-tile schedule, so
`activeSpinsUp` asserts the order and the total without a view. The 40 ms and the 600 ms are duration
tokens (`Dur.*` / `C.SpinUp.*`), never literals — check 9.

**Two other beats look like this one and are not:**

| Beat | Trigger | Duration | Owner |
|---|---|---|---|
| **600 ms spin-up** | a *live* process returns to `.active` | 600 ms | **this task** |
| 900 ms re-entry beat | a *cold launch* with a live snapshot | 900 ms | **E10·T03** |
| 420 ms verdict beat | a probe committed | 420 ms | **E08·T06** |

Do not merge them and **do not share a token**: borrowing one duration for another is how two
surfaces end up sharing a value only one of them wanted. E10·T03's own file already names this task
as the thing it must not be confused with; the reverse note belongs here.

Under Reduce Motion the spin-up **keeps its stagger** — a staggered opacity ramp translates nothing —
and each tile's fade becomes a crossfade rather than a slide (`transitions.md` §9). It does not
shorten.

### The chevron, per mode

| Mode | Instrument bar leading | Commit bar | Confirmations |
|---|---|---|---|
| PROBE, DRIFT | chevron | PROBE · twin · Bench | **1** — one tap suspends and returns to the Frame, no confirmation, because nothing is lost |
| ECHO | chevron | twin/replay · Seal | **1** |
| SIEVE, `streaming` | **nothing** | `pause` alone | — there is no exit |
| SIEVE, `paused` | **nothing** | abandon chevron (leading) · pause | **2** — a second, confirming tap |

The two reasons §12.7 gives for SIEVE's shape are worth carrying into the code comment, because they
are what stops someone "simplifying" it into a one-tap bar control: *a timed mode is the one place a
stray thumb near the chrome can destroy something*, and *stopping the stream first means the decision
to leave is made against a frozen screen rather than a moving one*.

`instrument-bar.md` §8's "Wrong" list already contains **"A chevron in SIEVE's bar"**, so
`sieveBarNeverHasAChevron` parameterises over every `SievePhase` rather than checking one — the defect
would arrive in exactly one phase.

**The chevron's VoiceOver label describes the effect, not the shape** (`instrument-bar.md` §6): it
suspends and returns, and nothing is lost. A label of "Back" would be a lie on a round surface. The
wording is E19·T01's; the requirement that it is not "Back" is stated here because it is a property of
what the control does.

### `ConfirmByRepeat` — two sites, enumerated

§12.7 closes with *"That confirm-by-repeat and the Seal's optional one (§12.6) are the only two in the
app."* Make it a type:

```swift
public enum ConfirmByRepeat: CaseIterable, Sendable {
    case sealOptional        // §12.6, off by default — T07's SealConfirmation
    case sieveAbandon        // §9.2, always
    public static let allSites = allCases
}
```

Two cases, `CaseIterable`, and `exactlyTwoConfirmByRepeats` asserts the count. A third site then
requires adding a case, which is a visible decision rather than a quiet one. `key.md` §5 already says
*"A key that asks twice anywhere else is wrong."*

### What E14 already built, and what this task adds to it

E14·T07 shipped `SievePauseOverlay`: the freeze at the next glyph boundary, the 70 % scrim over the
frozen lane, the deliberate gate tap to resume, and the 3-glyph run-up at `r₀`. E14·T08 shipped the
two-tap abandon's **scoring** as a foul-out at the last resolved glyph, and the void-on-termination
rule with its sticky target.

This task adds three things above them and re-implements none:

1. the **scene-phase trigger** — §12.2 screen 18's entry is *"`scenePhase != .active` during SIEVE,
   **or** the pause key"*, and only the second half existed before;
2. the **chevron's placement and absence** across all four modes, as a value the bar reads;
3. the **untimed column** of §12.7's table, which E14 had no reason to touch.

Before writing, read what is there:

```bash
grep -rn "SievePauseOverlay\|runUp\|freeze" Modules/Sources/LoomFeature/ | head -30
```

If `SievePauseOverlay` already reads `scenePhase` directly, move that read into `ScenePhaseBridge` so
there is one observer and one policy — two observers of the same phase is how the freeze and the
flush end up in a race.

### The flush order, cited not restated

§11.13 fixes it: `round.json` first because it is the smallest file and an in-progress round is the
last thing to be lost, the snapshot slot cleared last. `FilePersistenceStore.save(_:to:)` already
switches on `StoreFile` for that order (E07·T02). `ScenePhasePolicy` therefore emits
`.flush([StoreFile])` in that order and the store honours it; it does not re-derive the order and it
does not write files itself. `backgroundFlushesInOrder` asserts the first and last elements, which is
the property §11.13 actually states.

### Reduce Transparency, High Contrast, VoiceOver

- **The pause scrim** is `C.Scrim.sievePause`, flat, always — it does **not** step under Reduce
  Transparency, because the blur was never what made the frozen lane readable (`scrim.md` §1, §6).
  This task changes none of that.
- **The covered content is `.accessibilityHidden(true)`** while the overlay is up. A hand-drawn
  overlay does not remove what is beneath it from the accessibility tree, and a rotor swipe landing
  on the frozen lane is the defect `scrim.md` §5 exists to prevent. The `Scrim` modifier already does
  it; verify it is applied and do not re-implement it.
- **Post `.layoutChanged`, not `.screenChanged`, on pause** — the screen did not change; a surface
  covered it (`transitions.md` §8).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ScenePhasePolicyTests` green, all eleven tests.
- [ ] `swift test --package-path Modules --filter LeavingARoundTests` green, all seven tests.
- [ ] `grep -rn "import SwiftUI\|ScenePhase" HunchCore/Sources/Rounds/ScenePhasePolicy.swift HunchCore/Sources/Rounds/SceneEffect.swift` returns nothing.
- [ ] `grep -rn "default:" HunchCore/Sources/Rounds/ScenePhasePolicy.swift` returns nothing.
- [ ] `grep -rn "chevron" Modules/Sources/LoomFeature/SieveRoundView.swift` shows it only inside the `paused` commit-bar branch, never in the instrument bar.
- [ ] `grep -rn "scenePhase" Modules/Sources/LoomFeature/` shows exactly one observer — `ScenePhaseBridge`.
- [ ] `grep -rnE "600|0\.6|40\b" Modules/Sources/LoomFeature/SpinUp.swift` returns nothing; every duration is `C.SpinUp.*` / `Dur.*`, and `Scripts/check-source-hygiene.sh` check 9 passes.
- [ ] `grep -rn "Dur.reEntry\|C.ReEntry" Modules/Sources/LoomFeature/SpinUp.swift` returns nothing — the 900 ms re-entry beat's tokens are not borrowed.
- [ ] Simulator walk recorded in the commit message, one row of §12.7 at a time: a call arrives during PROBE (nothing visible) and during SIEVE (freeze within one tick, scrim drops); backgrounding in each mode with the file tree dumped to show `round.json` written first; returning to `.active` in PROBE (600 ms spin-up, correct order) and in SIEVE (overlay stays, gate tap resumes, run-up replays); force-quitting a SIEVE run and confirming relaunch opens the Frame with the record marked `void`; Low Power Mode toggled and the Frame's idle glyph confirmed still.
- [ ] `tests.json` carries the six entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T09: ScenePhasePolicy as effects-as-data; the chevron policy per mode; the 600 ms spin-up"`

## Out of scope

- SIEVE's freeze-at-glyph-boundary, the 70 % scrim, the gate resume and the 3-glyph run-up — **E14·T07**.
- The two-tap abandon's *scoring* as a foul-out, the void-on-termination rule and the sticky target — **E14·T08**.
- ECHO's one free cast restart and its second-interruption abandon — **E13·T09**.
- The 900 ms cold-launch re-entry beat — **E10·T03**.
- Abandon / discard / suspend semantics as values, and the `round-{mode}.json` slots — **E10·T04**.
- The atomic write path and `FilePersistenceStore`'s ordering implementation — **E07·T02**.
- Stopping and starting `AVAudioEngine` and `CHHapticEngine` for real — **E20·T04**, **E20·T06**. This task emits the effect; E20 attaches the player.
- The `loomGrain` shader that Low Power disables — **E20·T07**.
- Every VoiceOver label's wording, including the chevron's — **E19·T01**.
