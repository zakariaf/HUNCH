# T06 — The 13-beat reveal script

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T05 |
| **Delivers** | 13-beat reveal script (ONBOARDING) · Frame withheld (ONBOARDING) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**. The script carries nine durations of its own (700 ms fade-up, +1.2 s, 60 ms and 120 ms staggers, +400 ms, 180 ms morph, 520 ms tug, 25 s, the 0.5 Hz breath) and a 20 pt travel. All of them land at L2 as `C.Onboarding.*`; a literal in a view fails hygiene check 9. |
| `hunch-motion-and-feedback` | Owns *what happens when*. The script is a beat sheet with player-driven triggers instead of a clock, so it has to be written in the same vocabulary as the verdict and reveal sheets, and it must obey the same invariant: nothing about the model waits for it — a player who taps PROBE at beat 1 gets a real probe, not a scripted one. |
| `hunch-bench-instruments` | Beats 8–11 are the Bench's own states — palette stamp, unbound ramp header dock, inert rail at 30 % with a hairline slash, one lit cell with the other three at 25 % + cancel hatch, the machined bar retracting. Those states exist already (E09·T02/T07); this task must *reveal* them, never re-draw them. |

## Objective

At the end of this task the opening round teaches itself: fourteen beats, 0 through 13, each revealing
exactly one affordance and each triggered by the act the previous one taught. On a second opening round
the script re-arms from beat 6 and beats 0–5 never play again. The Frame does not exist for a player who
has not finished a round — the Frame key lights for the first time on the Inscription, at beat 13.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.5 (Beat by beat) | all fourteen rows: trigger, what the player sees, what it teaches. This table is normative and is not paraphrased in code |
| `GAME_DESIGN.md` | §12.5 (How the declaration interface is discovered) | why the Bench introduces exactly one novelty, and that the handle is the only genuinely new object |
| `GAME_DESIGN.md` | §12.5 (Failure of the opening round) | beats 0–5 never repeat; the script re-arms from beat 6 onward |
| `GAME_DESIGN.md` | §12.4 (final decision) | first launch never shows the Frame — a menu is a text-shaped object and the first thing a new player must meet is the machine |
| `GAME_DESIGN.md` | §4.1, §4.2, §4.3 | the ramp as the same widget in two modes; the palette, the unbound header dock, inert vs vacuous, the Assay's 64 cells, the machined bar retracting |
| `GAME_DESIGN.md` | §6.2 | the handle's region, y 516–560 on SE |
| `GAME_DESIGN.md` | §10.4 / §4.4 | why beat 8's palette holds exactly one stamp: the ceiling is lifetime max band served + 1 = band 2, which needs only Ramp + coupler |
| `GAME_DESIGN.md` | §12.2 (screen 8) | the Inscription, whose *again* key is primary and whose Frame key is trailing |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | the beat enum's `switch`es carry no `default:` — adding a beat must break every consumer |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/OnboardingScriptTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import LoomFeature

@Suite("The 13-beat reveal script — §12.5")
struct OnboardingScriptTests {

    private func armed(_ attempt: Int = 1) -> OnboardingScript { .armed(attempt: attempt) }

    // MARK: one affordance at a time

    @Test("beat 0 shows the machine and nothing else")
    func beatZeroIsTheMachineAlone() {
        let script = armed()
        #expect(script.beat == .seedGlyph)
        #expect(script.visibleAffordances == [.throat])
    }

    @Test("beat 1 lights the PROBE key alone — the only lit pixel below the throat")
    func beatOneLightsOnlyProbe() {
        var script = armed()
        script.advance(on: .elapsed(C.Onboarding.beatOneDelay))
        #expect(script.beat == .probeKey)
        #expect(script.visibleAffordances == [.throat, .probeKey])
        #expect(script.breathing == .probeKey)
    }

    @Test("beat 2 is the seed glyph itself, un-edited, and it stops the breath")
    func beatTwoIsTheSeedProbe() {
        var script = armed()
        script.advance(on: .elapsed(C.Onboarding.beatOneDelay))
        script.advance(on: .probed(glyphID: OpeningRound.seedGlyphID, verdict: .admit, isTwin: false))
        #expect(script.beat == .firstProbe)
        #expect(script.breathing == nil)
    }

    @Test("beat 3 reveals the shape ramp and leaves the other three dark")
    func beatThreeRevealsOneRamp() {
        var script = armed().played(.firstProbeAdmitted)
        script.advance(on: .elapsed(C.Onboarding.beatThreeDelay))
        #expect(script.beat == .shapeRamp)
        #expect(script.visibleAffordances.contains(.ramp(.shape)))
        #expect(!script.visibleAffordances.contains(.ramp(.fill)))
        #expect(!script.visibleAffordances.contains(.ramp(.pips)))
        #expect(!script.visibleAffordances.contains(.ramp(.hue)))
    }

    @Test("beat 4 is a Dial edit and it restarts the PROBE key's breath")
    func beatFourRestartsTheBreath() {
        var script = armed().played(.shapeRampShown)
        script.advance(on: .dialEdited(attribute: .shape))
        #expect(script.beat == .throatMorph)
        #expect(script.breathing == .probeKey)
    }

    // MARK: beat 6 — the gate that the passive path cannot pass

    @Test("beat 6 needs BOTH a first admit and a first reject; an admit alone does not open it")
    func beatSixNeedsBothVerdicts() {
        var script = armed().played(.secondProbeSubmitted)
        script.advance(on: .ledgerChanged(.init(sawAdmit: true, sawReject: false)))
        #expect(script.beat == .secondProbe)
        #expect(!script.visibleAffordances.contains(.ramp(.fill)))

        script.advance(on: .ledgerChanged(.init(sawAdmit: true, sawReject: true)))
        #expect(script.beat == .remainingRamps)
        #expect(Glyph.Attribute.allCases.allSatisfy { script.visibleAffordances.contains(.ramp($0)) })
    }

    // MARK: beat 7 — whichever comes first

    @Test("beat 7 fires at probe 4")
    func beatSevenByProbeCount() {
        var script = armed().played(.remainingRampsShown)
        script.advance(on: .probeCountReached(4))
        #expect(script.beat == .handle)
        #expect(script.visibleAffordances.contains(.handle))
    }

    @Test("beat 7 fires 25 s after beat 6 if probe 4 never comes")
    func beatSevenByTimeout() {
        var script = armed().played(.remainingRampsShown)
        script.advance(on: .elapsed(C.Onboarding.handleTimeout))
        #expect(script.beat == .handle)
    }

    @Test("the handle tugs exactly once, ever")
    func handleTugsOnce() {
        var script = armed().played(.remainingRampsShown)
        script.advance(on: .probeCountReached(4))
        #expect(script.pendingGestures == [.handleTug])
        script.advance(on: .gesturePlayed(.handleTug))
        script.advance(on: .probeCountReached(5))
        #expect(script.pendingGestures.isEmpty)
    }

    // MARK: beats 8–11 — the Bench

    @Test("beat 8's palette holds exactly one stamp, and it breathes")
    func beatEightHasOneStamp() {
        var script = armed().played(.handleShown)
        script.advance(on: .benchOpened)
        #expect(script.beat == .bench)
        #expect(script.visiblePaletteStamps == [.ramp])
        #expect(script.breathing == .paletteStamp(.ramp))
    }

    @Test("beat 11 is the moment: the bar retracts and nothing has been said")
    func beatElevenClearsTheBar() {
        var script = armed().played(.attributeBound)
        script.advance(on: .valueLit(count: 1))
        #expect(script.beat == .valueLit)
        #expect(script.visibleAffordances.contains(.seal))
        #expect(script.sealIsBarred == false)
    }

    // MARK: the re-arm

    @Test("a re-run arms at beat 6; beats 0–5 never repeat", arguments: [2, 3])
    func reRunArmsAtBeatSix(_ attempt: Int) {
        let script = armed(attempt)
        #expect(script.beat == .remainingRamps)
        #expect(Glyph.Attribute.allCases.allSatisfy { script.visibleAffordances.contains(.ramp($0)) })
        #expect(script.visibleAffordances.contains(.probeKey))
        #expect(script.playedBeats.isDisjoint(with: Set(OnboardingScript.Beat.allCases.prefix(6))) == false)
        #expect(script.remainingBeats.allSatisfy { $0.rawValue >= 6 })
    }

    // MARK: the Frame

    @Test("the Frame key is withheld for every beat before 13 (§12.4)")
    func frameWithheldUntilRoundOneEnds() {
        for beat in OnboardingScript.Beat.allCases where beat != .inscription {
            #expect(OnboardingScript.at(beat).frameKeyVisible == false)
        }
        #expect(OnboardingScript.at(.inscription).frameKeyVisible == true)
    }

    @Test("beat 13 makes *again* primary and lights the Frame key for the first time")
    func beatThirteen() {
        var script = armed().played(.sealPressedCorrectly)
        #expect(script.beat == .inscription)
        #expect(script.primaryAction == .again)
        #expect(script.frameKeyVisible)
    }

    @Test("the script never reveals a cell, a value or an attribute — only that a control exists")
    func scriptRevealsControlsNotAnswers() {
        for beat in OnboardingScript.Beat.allCases {
            let state = OnboardingScript.at(beat)
            #expect(state.breathing?.isValueSpecific != true)
            #expect(state.highlightedCells.isEmpty)
        }
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter OnboardingScriptTests`

Failures must be missing symbols (`OnboardingScript`, `C.Onboarding`, `.played(_:)`), or a wrong beat
index. If `beatSixNeedsBothVerdicts` passes before the implementation exists, the ledger argument is not
being read and the test is worthless — rewrite it.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/LoomFeature/OnboardingScript.swift` |
| create | `Modules/Sources/LoomFeature/OnboardingAffordance.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — add the `C.Onboarding` namespace |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — gate affordance opacity on `script.visibleAffordances` |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — gate the palette on `script.visiblePaletteStamps` |
| modify | `Modules/Sources/LoomFeature/InscriptionView.swift` — the Frame key's first lighting |
| modify | `Modules/Sources/LoomFeature/Round.swift` — feed the script its events |
| create | `Modules/Tests/LoomFeatureTests/OnboardingScriptTests.swift` |
| modify | `tests.json` — four entries (one-affordance-at-a-time, beat 6's conjunction, re-arm at 6, Frame withheld) |

## Implementation notes

### Shape: a value machine, not a coordinator

```swift
public struct OnboardingScript: Equatable, Sendable {
    /// §12.5's table, rows 0–13. The feature is called "the 13-beat script" after its last index.
    public enum Beat: Int, CaseIterable, Comparable, Sendable {
        case seedGlyph = 0, probeKey, firstProbe, shapeRamp, throatMorph, secondProbe,
             remainingRamps, handle, bench, stamp, attributeBound, valueLit, seal, inscription
    }

    public enum Event: Equatable, Sendable {
        case elapsed(Duration)
        case probed(glyphID: UInt8, verdict: Verdict, isTwin: Bool)
        case dialEdited(attribute: Glyph.Attribute)
        case ledgerChanged(OnboardingLedger)
        case probeCountReached(Int)
        case benchOpened, stampTapped, attributeBound, valueLit(count: Int)
        case sealPressed(correct: Bool)
        case gesturePlayed(ScriptedGesture)
    }

    public private(set) var beat: Beat
    public private(set) var playedBeats: Set<Beat>
    public var visibleAffordances: Set<OnboardingAffordance> { … }
    public var visiblePaletteStamps: [RuleTile.Kind] { … }
    public var breathing: OnboardingAffordance? { … }
    public var pendingGestures: [ScriptedGesture] { … }
    public var frameKeyVisible: Bool { beat == .inscription }

    public static func armed(attempt: Int) -> OnboardingScript      // attempt 1 → .seedGlyph, ≥ 2 → .remainingRamps
    public mutating func advance(on event: Event)
}
```

Keeping it a value buys the fourteen assertions above at host speed and makes the one thing that must
never regress — *one affordance at a time* — a set comparison rather than a screenshot.

### The triggers that are not clocks

Beats 2, 4, 5, 8, 9, 10, 11 and 12 are **player acts**. Beats 1 and 3 are delays after the previous beat.
Beat 6 is a *ledger predicate*. Beat 7 is `min(probe 4, 25 s after beat 6)`. Beat 13 is a screen.

Two rules the implementation must not break:

1. **The script never gates the model.** If a player taps PROBE during beat 0's 700 ms fade, they get a
   real probe with a real verdict and the script skips forward. The script only controls *opacity and
   breath*; `Round` never asks it for permission.
2. **Beat 6 reads the ledger, not the probe list.** §12.5's whole passive-path argument is that twelve
   admits must not open beat 6. `sawAdmit && sawReject` is the condition, and the ledger is T07's — until
   T07 lands, take the two booleans as an argument and wire the type in T07's commit.

### The durations

```swift
extension C {
    public enum Onboarding {
        public static let seedFadeUp    = Duration.milliseconds(700)   // beat 0
        public static let beatOneDelay  = Duration.milliseconds(1_200) // beat 1
        public static let beatThreeDelay = Duration.milliseconds(400)  // beat 3
        public static let cellStagger   = Duration.milliseconds(60)    // beat 3, cell by cell
        public static let rampStagger   = Duration.milliseconds(120)   // beat 6, leading → trailing
        public static let throatMorph   = Duration.milliseconds(180)   // beat 4
        public static let handleTug     = Duration.milliseconds(520)   // beat 7
        public static let handleTimeout = Duration.seconds(25)         // beat 7's other trigger
        public static let breathPeriod  = Duration.milliseconds(2_000) // 0.5 Hz, beats 1 and 8
        public static let handleTravel  = 20.0                          // pt, beat 7
    }
}
```

The breath at beat 1 and beat 8 is 0.5 Hz with opacity 0.55 ↔ 1.0 — the *same* vocabulary the five
nudges use (§12.5's nudge table). T08 owns the nudge scheduler; the two must read one set of tokens, so
put the opacity pair and the period here and have T08 reference them rather than restating them.

### Re-arming, exactly

`armed(attempt:)` with `attempt ≥ 2` starts at `.remainingRamps` with all four ramps, the PROBE key and
the throat already visible, and `playedBeats` pre-filled with 0–5 so nothing can replay them. §12.5's
reasoning: a player on their second opening round has already met the throat, the key and the ramp; what
they failed to reach is the Bench.

The attempt number comes from `OnboardingLedger` (T07). After three failed opening rounds the ledger
stops re-arming altogether and there is no script at all — `armed(attempt: 4)` must therefore be
unreachable; assert it with a `precondition` carrying the §12.5 citation.

### The Frame, withheld

Two enforcement points, both asserted:

- `AppLaunchRoute.initial(suspended: nil, hasFinishedARound: false) == .round(.opening)` — T01's test.
- `OnboardingScript.frameKeyVisible` is false for every beat but 13 — this task's test.

`FrameView` itself is E17·T03's; it simply is not reachable until one of those two turns true.

### Accessibility

Under VoiceOver the *breath* is suppressed (T08's scheduler, §12.5's hard floor) but the **reveal order is
not**: an affordance that is invisible is also `.accessibilityHidden(true)`, so the rotor enumerates the
same one control the sighted player sees. That is the correct behaviour and it falls out of gating
opacity and accessibility from the same `visibleAffordances` set — do it in one modifier, not two.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter OnboardingScriptTests` green, all fifteen tests.
- [ ] `grep -n "case " Modules/Sources/LoomFeature/OnboardingScript.swift` shows exactly fourteen `Beat` cases, indices 0–13, matching §12.5's table row for row.
- [ ] `grep -rn "default:" Modules/Sources/LoomFeature/OnboardingScript.swift` returns nothing.
- [ ] `grep -rn "1200\|0\.7\|25\b" Modules/Sources/LoomFeature/OnboardingScript.swift` returns nothing — every duration comes from `C.Onboarding`.
- [ ] Simulator walkthrough recorded in the commit message: fresh install (delete the app container first), fourteen beats reached in order, and the Frame key dark until the Inscription.
- [ ] `tests.json` carries the four entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T06: the 13-beat reveal script, its re-arm and the withheld Frame"`

## Out of scope

- `OnboardingLedger`'s fields and the elastic cap — **T07**; this task consumes two booleans and an attempt number.
- The five nudges — **T08**; the script reveals, the nudges recover.
- Every Bench state beats 8–11 *show* — **E09·T02/T07**. If a state does not exist yet, that is an E09 gap, not a beat.
- `FrameView`, the mode rack and the mode sigils — **E17·T03/T04**.
- The reveal at beat 12 and the Codex page it mints — **E09·T10/T11**.
- The palette ceiling rule that makes beat 8 one stamp — **E09·T04**.
