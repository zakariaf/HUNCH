# T10 — SIEVE and ECHO accessibility

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | VoiceOver element map · Rotors, Magic Tap, announcements (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | Owns all three halves of this task. `references/rotors-and-gestures.md` §9 owns SIEVE's step mode as a **parameter of a pure value** rather than a read of `UIAccessibility`, and the rule that steady stream and VoiceOver must not collapse into one branch; §10 owns nudge suppression at the scheduler and the two things that survive VoiceOver. `references/voiceover-elements.md` §6–§7 owns ECHO's and SIEVE's element rows, and the rule that the lane is deliberately not announced. |

## Objective

At the end of this task the two modes that a sighted player reads off *motion* are playable without
it. SIEVE runs in step mode at a fixed 0.75 g/s with no ramp, its gate is one element with an "Admit"
custom action, each glyph is announced on gate entry and its resolution announced in the sump, and the
Tempo axis is not updated because the timing is not comparable. ECHO's pool and primer strips are
static grouped elements carrying lit/extinguished state, and the cast stays silent. Every nudge is
suppressed while VoiceOver runs.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.8 (VoiceOver) | step mode with `r` fixed at **0.75 g/s** (window 889 ms) and no ramp; the gate is one element with an "admit" custom action; each glyph announced on gate entry using the canonical `fill → shape → pips → hue` label and its resolution announced in the sump; **scoring is identical**; the Tempo axis is not updated |
| `GAME_DESIGN.md` | §9.8 (steady stream) | fixes `r` at `r₀` with no ramp at a 0.85 score multiplier; available to anyone, not gated behind an accessibility flag, and it does not disable Codex inscription |
| `GAME_DESIGN.md` | §9.3 | `window(n) = 0.667 / r(n)`; the six band rows of `r₀`; the tempo step adding `0.20·s` |
| `GAME_DESIGN.md` | §9.2 | the 375 × 88 pt gate is the entire actionable target; nothing that moves is ever tapped; only touch-down registers |
| `GAME_DESIGN.md` | §8.4, §8.8 | ECHO's surface: the primer strip on screen all round; the pool strip is what makes §8.8's "this is not a memory task" claim true; the cast has no verdicts and a dark ribbon |
| `GAME_DESIGN.md` | §8.2 | each primer verdict **extinguishes** every inconsistent pool member |
| `GAME_DESIGN.md` | §12.5 (hard floor on nudges) | every nudge is suppressed entirely when VoiceOver is running |
| `GAME_DESIGN.md` | §11.9 | the Tempo axis samples `par/probes`; SIEVE's Tempo sample is what step mode suppresses |
| `.claude/skills/hunch-accessibility/references/rotors-and-gestures.md` | §9, §10 | `SievePacing` as a parameter; the two-routes rule; suppression at the scheduler |
| `.claude/skills/hunch-accessibility/references/voiceover-elements.md` | §6, §7 | the ECHO and SIEVE element rows, and why the lane is not announced |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SievePacingTests.swift`:

```swift
import Foundation
import Testing
import Rounds
import LawGeneration
import HunchTestSupport

@Suite("SIEVE step pacing — §9.8", .tags(.unit, .presubmission))
struct SievePacingTests {

    @Test("stepped pacing is a flat 889 ms window at every index and every band",
          arguments: Band.sieveServable, 0...3)
    func steppedWindowIsFlat(_ band: Band, _ tempoStep: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: tempoStep, pacing: .stepped)
        let windows = (0..<schedule.glyphCount).map { schedule.window(at: $0) }
        #expect(windows.allSatisfy { isApproximatelyEqual($0.seconds, 0.667 / 0.75,
                                                          absoluteTolerance: 0.001) })
        #expect(Set(windows).count == 1, "stepped pacing must not ramp")
    }

    @Test("stepped is strictly slower than steady, which is strictly slower than adaptive at r₁",
          arguments: Band.sieveServable)
    func steppedIsTheSlowest(_ band: Band) {
        let stepped = SieveSchedule(band: band, tempoStep: 0, pacing: .stepped)
        let steady = SieveSchedule(band: band, tempoStep: 0, pacing: .steady)
        let adaptive = SieveSchedule(band: band, tempoStep: 0, pacing: .adaptive)
        let last = adaptive.glyphCount - 1
        #expect(stepped.window(at: last) > steady.window(at: last))
        #expect(steady.window(at: last) > adaptive.window(at: last))
    }

    @Test("steady pacing is r₀ with no ramp — a DIFFERENT value from stepped, and not the same case")
    func steadyIsNotStepped() {
        let band = Band.contextual
        let steady = SieveSchedule(band: band, tempoStep: 0, pacing: .steady)
        #expect(isApproximatelyEqual(steady.window(at: 0).seconds,
                                     steady.window(at: steady.glyphCount - 1).seconds,
                                     absoluteTolerance: 0.001))
        #expect(steady.window(at: 0) != SieveSchedule(band: band, tempoStep: 0, pacing: .stepped).window(at: 0))
    }

    @Test("the pitch invariant still holds at the stepped rate", arguments: Band.sieveServable, 0...3)
    func pitchInvariantHoldsWhenStepped(_ band: Band, _ tempoStep: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: tempoStep, pacing: .stepped)
        for index in 0..<schedule.glyphCount { #expect(schedule.pitch(at: index) > schedule.gateHeight) }
    }

    @Test("SieveSchedule reads no accessibility state — it is a pure value in HunchCore")
    func pacingIsAParameter() {
        // 08 §2's boundary rule: no bundle, no UIAccessibility, no screen geometry.
        #expect(SievePacing.allCases.count == 3)
        #expect(SieveSchedule(band: .literal, tempoStep: 0, pacing: .stepped)
                == SieveSchedule(band: .literal, tempoStep: 0, pacing: .stepped))
    }
}
```

Create `Modules/Tests/LoomFeatureTests/SieveVoiceOverTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI
@testable import LoomFeature

@Suite("SIEVE under VoiceOver — §9.8, §13.10", .tags(.unit, .presubmission))
struct SieveVoiceOverTests {

    private let loc = Loc.english

    @Test("VoiceOver selects stepped pacing; the steady-stream SETTING carries the 0.85 multiplier")
    func pacingAndMultiplierAreSeparateQuestions() {
        #expect(SieveRun.pacing(isVoiceOverRunning: true, steadyStream: false) == .stepped)
        #expect(SieveRun.pacing(isVoiceOverRunning: false, steadyStream: true) == .steady)
        #expect(SieveRun.pacing(isVoiceOverRunning: true, steadyStream: true) == .stepped)   // the slower wins
        #expect(SieveRun.scoreMultiplier(isVoiceOverRunning: true, steadyStream: false) == 1.0)
        #expect(SieveRun.scoreMultiplier(isVoiceOverRunning: false, steadyStream: true) == 0.85)
        #expect(SieveRun.scoreMultiplier(isVoiceOverRunning: true, steadyStream: true) == 0.85)
    }

    @Test("the Tempo axis is not updated under stepped pacing, in either route")
    func steppedEmitsNoTempoSample() {
        #expect(SieveRun.profileSamples(pacing: .stepped).map(\.axis).contains(.tempo) == false)
        #expect(SieveRun.profileSamples(pacing: .steady).map(\.axis).contains(.tempo) == false)
        #expect(SieveRun.profileSamples(pacing: .adaptive).map(\.axis).contains(.tempo))
    }

    @Test("the gate is ONE element with an Admit custom action, and it never leaves the tree")
    func gateIsOneElement() {
        #expect(GateAccessibility.childBehaviour == .ignore)
        #expect(GateAccessibility.traits == [.isButton, .updatesFrequently])
        #expect(GateAccessibility.actions(loc) == [loc.admit])
        // §13.10: the element stays present between glyphs; the ACTION is gated, not the element.
        #expect(GateAccessibility.isPresent(actionable: nil))
        #expect(GateAccessibility.isActionEnabled(actionable: nil) == false)
    }

    @Test("each glyph is announced on gate ENTRY and its resolution in the SUMP — two events, in order")
    func announcementsOnEntryAndInTheSump() {
        let spy = AnnouncerSpy()
        let voice = SieveVoice(announcer: spy, loc: loc)
        let g = Glyph(fill: .dotted, shape: .square, pips: .two, hue: .frost)
        voice.glyphEnteredGate(g, previous: nil, detail: .full)
        voice.glyphResolved(g, verdict: .admit, outcome: .hit)
        #expect(spy.posts.count == 2)
        #expect(spy.posts[0].text == loc.glyphLabel(g, relativeTo: nil, detail: .full))
        #expect(spy.posts[1].text == loc.sieveResolution(.hit))
    }

    @Test("the lane is never announced — §9.8 already traded the preview for the longer window")
    func laneIsSilent() {
        let spy = AnnouncerSpy()
        let voice = SieveVoice(announcer: spy, loc: loc)
        voice.glyphEnteredLane(Glyph(fill: .solid, shape: .circle, pips: .one, hue: .amber))
        #expect(spy.posts.isEmpty)
        #expect(SieveElementMap.hidden.contains(.lip))
        #expect(SieveElementMap.hidden.contains(.lane))
    }

    @Test("the pause overlay is modal, so VoiceOver stops walking the frozen lane behind it")
    func pauseOverlayIsModal() { #expect(SievePauseAccessibility.traits.contains(.isModal)) }
}
```

Create `Modules/Tests/LoomFeatureTests/EchoVoiceOverTests.swift`:

```swift
@Suite("ECHO under VoiceOver — §8.2, §8.4, §13.10", .tags(.unit, .presubmission))
struct EchoVoiceOverTests {

    private let loc = Loc.english

    @Test("the pool strip is a static grouped element and each member carries lit / extinguished")
    func poolStripIsGrouped() {
        let pool = EchoPoolAccessibility(members: Corpora.echoPool(extinguished: [1, 3]), loc: loc)
        #expect(pool.childBehaviour == .contain)
        #expect(pool.label == loc.pool)
        #expect(pool.members[0].value == loc.lit)
        #expect(pool.members[1].value == loc.extinguished)
        #expect(pool.members.allSatisfy { $0.traits == [.isStaticText] })   // read-only, not a hit target
    }

    @Test("the primer strip is a container with m glyphs, each carrying its verdict")
    func primerStripIsGrouped() {
        let primer = EchoPrimerAccessibility(primer: Corpora.echoPrimer(count: 3), loc: loc)
        #expect(primer.childBehaviour == .contain)
        #expect(primer.value == loc.glyphCount(3))
        #expect(primer.glyphs.map(\.value) == [loc.admitted, loc.rejected, loc.admitted])
    }

    @Test("the cast is silent: the dark ribbon is hidden and nothing announces during it")
    func castIsSilent() {
        let spy = AnnouncerSpy()
        EchoVoice(announcer: spy, loc: loc).castDidPlay(Corpora.echoCast(length: 8))
        #expect(spy.posts.isEmpty)
        #expect(EchoElementMap.hidden.contains(.castRibbon))
    }
}
```

Create `Modules/Tests/LoomFeatureTests/NudgeSuppressionTests.swift`:

```swift
@Suite("Nudges under VoiceOver — §12.5", .tags(.unit, .presubmission))
struct NudgeSuppressionTests {

    @Test("every nudge is suppressed at the SCHEDULER when VoiceOver is running",
          arguments: Nudge.allRepresentativeCases)
    func everyNudgeIsSuppressed(_ nudge: Nudge) {
        var scheduler = NudgeScheduler(env: .standard, isVoiceOverRunning: true)
        scheduler.update(nudge.triggeringObservation)
        #expect(scheduler.pending == nil)
        #expect(scheduler.firedCount == 0)          // the budget is not consumed either
    }

    @Test("the barred Seal's rail pulse survives VoiceOver — it is information, not attention")
    func railPulseSurvives() {
        let round = Round.preview(phase: .declaring, sealBar: .inertRail(1), isVoiceOverRunning: true)
        round.seal()
        #expect(round.railPulses == [1])
    }

    @Test("the empty-rail hairline survives VoiceOver — it is a state, not a nudge")
    func emptyRailHairlineSurvives() {
        #expect(BenchRailState.empty.drawsHairline(isVoiceOverRunning: true))
    }

    @Test("the round reads VoiceOver from the environment and threads it as a parameter, not a RenderEnv axis")
    func voiceOverIsNotARenderEnvAxis() {
        #expect(RenderEnv.axisCount == 7)
        #expect(!RenderEnv.axisNames.contains("voiceOver"))
    }
}
```

**Step 2 — run it and watch it fail.**

```
swift test --package-path HunchCore --filter SievePacingTests
swift test --package-path Modules   --filter SieveVoiceOverTests
swift test --package-path Modules   --filter EchoVoiceOverTests
swift test --package-path Modules   --filter NudgeSuppressionTests
```

Missing `SievePacing.stepped`, `SieveRun`, `SieveVoice`, `GateAccessibility`, `EchoPoolAccessibility`,
`EchoPrimerAccessibility`, `EchoVoice`. Two traps: `everyNudgeIsSuppressed` passes against E10·T08's
scheduler if it already guards on the flag — that is fine and expected, and the *new* assertion is
`firedCount == 0`, which fails if suppression was implemented inside the animation instead of at the
scheduler. And `steppedIsTheSlowest` fails loudly if `.stepped` was implemented by reusing `.steady`'s
value, which is the shortcut this whole task exists to prevent.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Rounds/SieveSchedule.swift` — add `.stepped` to `SievePacing`; a flat window with no ramp |
| create | `Modules/Sources/LoomFeature/SieveRun.swift` — `pacing(isVoiceOverRunning:steadyStream:)`, `scoreMultiplier(…)`, `profileSamples(pacing:)` |
| create | `Modules/Sources/LoomFeature/SieveVoice.swift` — gate-entry and sump announcements |
| create | `Modules/Sources/LoomFeature/EchoVoice.swift` — the cast's silence, made explicit |
| modify | `Modules/Sources/LoomFeature/SieveRoundView.swift` — the gate as one element with the Admit action; lip and lane hidden |
| modify | `Modules/Sources/LoomFeature/SievePauseOverlay.swift` — `.isModal` (T05 added it; assert it here) |
| modify | `Modules/Sources/LoomFeature/EchoRoundView.swift` — pool strip, primer strip, dark ribbon hidden |
| modify | `Modules/Sources/LoomFeature/Round.swift` — thread `isVoiceOverRunning` in from `@Environment(\.accessibilityVoiceOverEnabled)` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — `admit`, `pool`, `lit`, `extinguished`, `glyphCount(_:)`, `sieveResolution(_:)` |
| create | `HunchCore/Tests/RoundsTests/SievePacingTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/{SieveVoiceOverTests,EchoVoiceOverTests,NudgeSuppressionTests}.swift` |
| modify | `tests.json` — the SIEVE step-mode, no-Tempo-sample, ECHO-strip and nudge-suppression entries |
| modify | `DECISIONS.md` — the pacing-versus-multiplier ruling below |

## Implementation notes

### SIEVE's pacing is a parameter of a pure value

`SieveSchedule` lives in `HunchCore` and `08 §2`'s boundary rule bans it from reading
`UIAccessibility` outright. The pacing is supplied once, at round start, by the app layer:

```swift
// HunchCore/Sources/Rounds/SieveSchedule.swift
public enum SievePacing: Sendable, CaseIterable {
    case adaptive        // §9.3's ramp, r₀ → r₁
    case steady          // §12.6's steady-stream toggle: r₀ flat
    case stepped         // VoiceOver: 0.75 g/s flat
}

public struct SieveSchedule: Hashable, Sendable {
    public init(band: Band, tempoStep: Int, pacing: SievePacing) { … }
    public func window(at index: Int) -> Duration { … }     // pure; `.stepped` returns 889 ms, flat
}
```

`window = 0.667 / r`, so 0.667 / 0.75 = **889 ms** — the number §9.8 states, arrived at rather than
copied. `r₀` is never below 1.00 g/s at any band (§9.3), so `.stepped` is strictly slower than
`.steady`, which is what `steppedIsTheSlowest` pins.

### Pacing and the score multiplier are two different questions

§9.8 says VoiceOver's step mode leaves **scoring identical**, and that the steady-stream toggle carries
a **0.85 multiplier**. Both can be on. `rotors-and-gestures.md` §9 explicitly forbids collapsing them
into one `isVoiceOverRunning` branch.

**Ruling: pacing is `max`-by-slowness and the multiplier is a property of the *setting*.** If VoiceOver
is running, pacing is `.stepped` regardless of the toggle, because that is the slower and the player
needs it. If the steady-stream toggle is on, the multiplier is 0.85 regardless of pacing, because the
player *chose* an easier run and the choice is what is priced. If only VoiceOver is on, the multiplier
is 1.0. Record it in `DECISIONS.md` — it is the one place the two routes genuinely interact, and the
naive `if voiceOver { .stepped, 1.0 } else if steady { .steady, 0.85 }` silently makes a
steady-stream player's run free the moment they turn VoiceOver on.

### The Tempo axis is not updated, and that is not the same as "no samples"

The Tempo sample would measure the *setting*, not the player, so it is suppressed under both
non-adaptive pacings. Every other axis is emitted normally, and scoring, marks and Codex inscription
are all unchanged. `steppedEmitsNoTempoSample` asserts all three cases so that "not updated" cannot
quietly become "the run does not count".

### The gate, and the element that must not vanish

The gate is **one element**: `children: .ignore`, `[.isButton, .updatesFrequently]`, label "Gate",
value = the glyph label of whatever is actionable, one custom action "Admit". Two rules that are easy
to break:

- **Never `.disabled()` between glyphs.** The element must stay in the accessibility tree, or VoiceOver
  focus jumps away every time the gate is empty and the player has to re-find it several times a
  second. Gate the **action**, not the element: `isActionEnabled(actionable: nil) == false` while the
  value reads empty.
- **Never announce the lane.** §9.8 already priced that trade — the VoiceOver player gets a longer
  window (889 ms against 226 ms at the worst adaptive case) *in exchange for* the preview a sighted
  player reads off the lane. Announcing the lane hands back both, which is a different game with a
  different difficulty. The lip and the lane are `.accessibilityHidden(true)`.

Announcements are two events in order: the glyph label **on gate entry**, and its resolution **in the
sump**. Both go through `Announcer`; neither is built inside `SieveRoundView`, because an announcement
is an `AttributedString` and hygiene check 7 fails the build on one in that file.

### ECHO's two strips

Both are **static grouped elements** — `.contain`, read-only, not hit targets:

- **The pool strip** is up to eight extension thumbnails in Codex order, and each primer verdict
  *extinguishes* every inconsistent member. Without the strip §8.8's claim — that ECHO is not a memory
  task — is false, and for a VoiceOver player the strip is the *only* form that claim takes, because
  the extinguishing is otherwise a pure opacity change. Each member's value is lit or extinguished;
  that is the whole informational content and it must be spoken.
- **The primer strip** is on screen all round with `m ∈ {3,4,5}` glyphs, each carrying its verdict.
  Its container value is the count.

**The cast is silent by construction.** §8.4 gives no feedback during it, so the ribbon draws dark and
speaks nothing. A value announcing "cast in progress" would leak the fact that a verdict exists.
`castIsSilent` is a regression guard against somebody adding a progress announcement out of kindness.

### Nudges

Every nudge is suppressed when VoiceOver is running — idle, no-Bench, barred-Seal, global idle and the
opening round's *unvaried*. The rotor already enumerates every control, so a breathing opacity cycle is
noise that interrupts nothing and helps nobody.

E10·T08 wrote the scheduler with the guard at the top of `update(_:)`. This task **wires the flag** —
`@Environment(\.accessibilityVoiceOverEnabled)` at the round's root, threaded into `Round`, threaded
into the scheduler — and asserts the property, including that a suppressed nudge does not consume its
budget. Suppression at the animation instead of at the scheduler is the failure mode
`rotors-and-gestures.md` §10 names, and `firedCount == 0` is what catches it.

Two things that survive VoiceOver and must not be swept up with the nudges, because they are
information rather than attention-getting: **the barred Seal's rail pulse** (it is the answer to a
press the player made, and it is also announced) and **the empty-rail hairline**, which is a static
state.

**VoiceOver is not an eighth `RenderEnv` axis.** It changes behaviour and structure — SIEVE's pacing,
nudge suppression, the SIEVE Tempo update — not values. Thread it as a parameter.
`voiceOverIsNotARenderEnvAxis` asserts the record still has exactly seven.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SievePacingTests` green, all five tests, parameterised over the six SIEVE-servable bands × four tempo steps.
- [ ] `swift test --package-path Modules --filter SieveVoiceOverTests` green, all six tests.
- [ ] `swift test --package-path Modules --filter EchoVoiceOverTests` green, all three tests.
- [ ] `swift test --package-path Modules --filter NudgeSuppressionTests` green, all four tests.
- [ ] `grep -rn 'UIAccessibility\|accessibilityVoiceOverEnabled' HunchCore/Sources` returns nothing.
- [ ] `grep -Rn 'accessibilityVoiceOverEnabled' Modules/Sources --include='*.swift'` shows it read at the round roots only, and threaded as a parameter thereafter.
- [ ] `grep -Rn 'disabled(' Modules/Sources/LoomFeature/SieveRoundView.swift` returns nothing on the gate element.
- [ ] `grep -Rn 'accessibilityHidden(true)' Modules/Sources/LoomFeature/SieveRoundView.swift` covers the lip and the lane; `…/EchoRoundView.swift` covers the cast's dark ribbon.
- [ ] `RenderEnv.axisCount == 7`.
- [ ] `tests.json` carries four entries: SIEVE step mode, no Tempo sample, ECHO's two strips, nudge suppression.
- [ ] `DECISIONS.md` carries the pacing-versus-multiplier ruling.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T10: SIEVE step mode, ECHO's strips, and nudges suppressed under VoiceOver"`

## Out of scope

- `SieveSchedule`'s speed curve, stream composition, fouls and scoring — **E14·T01/T03/T04/T05**; this task adds one pacing case and asserts the invariants still hold under it.
- The steady-stream Settings row — **E14·T09**, **E17·T06**.
- ECHO's pool selection, the primer's separating chain and the cast's cadence — **E13·T01/T03/T04**.
- The nudge scheduler's five triggers, forms and budgets — **E10·T08**.
- The Reduce Motion parity test for the conveyor — **E14·T10**; Reduce Motion and VoiceOver are independent axes and both may be on, which is why that test and this one do not share a fixture.
- The Profile's Tempo axis formula — **E16·T05**.
