# T07 — Pause, run-up and `SievePauseOverlay`

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Pause and run-up (SIEVE) · `SievePauseOverlay` (SCREENS — screen 18 of 18) |
| **Status** | not started |

## Skills to load

Load these in this order:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | This task draws a screen, so the token vocabulary comes first. The SIEVE pause scrim is the one opacity in the app that is **L2 and not L1** (`C.Scrim.sievePause`), deliberately, because §12.7's whole argument is that the lane must stay readable through it — `Opacity.scrim(in:)` would hide it. Typing `0.7` or reaching for `Color.black.opacity(0.6)` breaks that argument and the second form slips past check 9. |
| `hunch-chrome-and-meta` | `references/scrim.md` is the owning file: two scrims and no third, `Scrim.Kind`, the `.accessibilityHidden(true)` on the covered content that a hand-drawn overlay does not get for free, the extent over the entire safe area including the instrument bar, and — the load-bearing bullet — **the SIEVE pause scrim does not dismiss on tap**. |
| `hunch-motion-and-feedback` | `references/transitions.md` owns the `scenePhase` table and the rule that SIEVE has no chevron while streaming. The freeze itself is instantaneous in both motion modes because motion is the mechanic here, and the run-up is a *replay*, not an animation — so it needs a substitution row that says "unchanged", written at the same time as the code. |

`hunch-accessibility` is cited rather than loaded: `audit-in-ci.md` §3 requires
`SievePauseOverlay` to assert `.isModal` keeps the frozen lane out of traversal, and that is one line
plus one XCUITest row.

## Objective

At the end of this task a SIEVE run can be stopped safely. The stream freezes at the **next glyph
boundary** — never mid-glyph, so no window is ever truncated — under a scrim through which the frozen
lane stays readable; resuming requires **one deliberate tap on the gate**, the same 375 × 88 pt band
the run is played with; and resumption replays the last 3 resolved glyphs at `r₀` before continuing,
a run-up that costs nothing, is not re-scored, and is its own soft disincentive against pausing
repeatedly.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.8 | *"Backgrounding is neither"* — the stream freezes at the next glyph boundary and, on resume, the last 3 resolved glyphs replay at `r₀` before it continues; **the run-up costs nothing and is not re-scored — those glyphs keep their original results**; a run may be paused any number of times, each costing a run-up; the 100 ms frame-budget auto-pause |
| `GAME_DESIGN.md` | §9.5 | the two `paused` transitions: `streaming → paused` (pause key **or backgrounded**, freeze at the next glyph boundary) and `paused → streaming` (resume, with the run-up) |
| `GAME_DESIGN.md` | §9.2 | the commit bar holds **pause** (trailing, 44 pt) during `streaming` and nothing else; in `paused` the same slot gains a **chevron** (leading, 44 pt) |
| `GAME_DESIGN.md` | §12.7 | the full `scenePhase` table for SIEVE; *"resuming needs **one deliberate tap on the gate** — the same 375 × 88 pt band the run is played with, never a region SIEVE does not have"*; the two reasons the exit is built from `paused` and not from a bar control |
| `GAME_DESIGN.md` | §12.2 screen 18 | `SievePauseOverlay`: 70 % scrim, frozen lane, **three retracting arcs on resume**; the abandon chevron lives here **and only here**; entry is `scenePhase != .active` during SIEVE or the pause key; exit is a gate tap or chevron ×2 |
| `.claude/skills/hunch-chrome-and-meta/references/scrim.md` | §1–§6 | `Scrim.Kind.sievePause`, `C.Scrim.sievePause` as L2, the safe-area extent, the manual `.accessibilityHidden`, and *"pass `onDismiss` as a no-op there and let the gate own the resume"* |
| `.claude/skills/hunch-motion-and-feedback/references/transitions.md` | §69–§82 | the `scenePhase` rows and the no-chevron-while-streaming rule |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A25, A20 | a presented subtree starts a new environment hierarchy and must be re-injected; the pure part is extracted and tested |

## TDD — the test comes first

**Step 1 — write the failing test.** Create two files.

`HunchCore/Tests/RoundsTests/SievePauseTests.swift`:

```swift
import Testing
import Glyphs
import Rounds
import HunchTestSupport

@Suite("SIEVE pause and the 3-glyph run-up — §9.8, §12.7", .tags(.unit, .presubmission))
struct SievePauseTests {

    private func runningRun() -> SieveRunState {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .relational, index: 0))
        for index in 0..<9 { run.resolve(index: index, tapped: run.stream.isLawful(at: index)) }
        return run
    }

    // MARK: freezing

    @Test("a pause request freezes at the NEXT glyph boundary, never mid-glyph")
    func freezesAtTheBoundary() {
        var run = runningRun()
        let inFlight = run.resolvedGlyphs                    // glyph `inFlight` is mid-window
        run.requestPause(at: run.conveyor.actionableSpan(of: inFlight).start + .milliseconds(30))
        #expect(run.phase == .streaming(.body))              // not yet — the glyph finishes
        run.resolve(index: inFlight, tapped: false)
        #expect(run.phase == .paused(.body))
        #expect(run.resolvedGlyphs == inFlight + 1)
    }

    @Test("no glyph's window is ever shortened by a pause", arguments: Band.sieveServable)
    func pauseNeverTruncatesAWindow(_ band: Band) {
        var run = SieveRunState(stream: Corpora.sieveStream(band: band, index: 0))
        for index in 0..<6 { run.resolve(index: index, tapped: false) }
        run.requestPause(at: run.conveyor.actionableSpan(of: 6).start + .milliseconds(1))
        #expect(run.actionableWindowRemaining(of: 6) == run.schedule.window(at: 6) - .milliseconds(1))
    }

    @Test("a frame-budget miss over 100 ms auto-pauses through the same path")
    func autoPauseUsesTheSamePath() {
        var run = runningRun()
        run.reportFrameOverrun(.milliseconds(120))
        run.resolve(index: run.resolvedGlyphs, tapped: false)
        #expect(run.phase == .paused(.body))
        #expect(run.pauseCount == 1)
    }

    // MARK: the run-up

    @Test("the run-up replays exactly the last 3 resolved glyphs")
    func runUpIsThreeGlyphs() {
        var run = runningRun()
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        let resumed = run.resume()
        #expect(resumed.runUpIndices == Array((run.resolvedGlyphs - 3)..<run.resolvedGlyphs))
        #expect(resumed.runUpIndices.count == 3)
    }

    @Test("fewer than three resolved glyphs means a shorter run-up, never a negative index")
    func runUpClampsAtTheStart() {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .literal, index: 0))
        run.resolve(index: 0, tapped: false)
        run.requestPause(at: .zero); run.resolve(index: 1, tapped: false)
        #expect(run.resume().runUpIndices == [0, 1])
    }

    @Test("the run-up runs at r₀, not at the rate the run had reached")
    func runUpRunsAtRZero() {
        var run = runningRun()
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        let resumed = run.resume()
        for index in resumed.runUpIndices {
            #expect(resumed.rate(during: index) == run.schedule.rateStart)
        }
    }

    @Test("the run-up costs NOTHING — no score, no foul, no resolution, no completion")
    func runUpIsFree() {
        var run = runningRun()
        let before = (run.tally, run.foulCount, run.resolvedGlyphs, run.resolutions)
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        let afterFreeze = (run.tally, run.foulCount, run.resolvedGlyphs, run.resolutions)
        run.replayRunUp()
        #expect(run.tally == afterFreeze.0)
        #expect(run.foulCount == afterFreeze.1)
        #expect(run.resolvedGlyphs == afterFreeze.2)
        #expect(run.resolutions == afterFreeze.3)
        #expect(before.3.count < afterFreeze.3.count)      // the freeze glyph DID resolve
    }

    @Test("replayed glyphs keep their original results, whatever the player does during the run-up")
    func replayedGlyphsKeepTheirResults() {
        var run = runningRun()
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        let original = run.resolutions
        run.replayRunUp(tappingEverything: true)           // the player mashes through the run-up
        #expect(run.resolutions == original)
        #expect(run.foulCount == 0)
    }

    @Test("the stream continues at the glyph that was frozen, never re-resolving one")
    func resumeContinuesWhereItStopped() {
        var run = runningRun()
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        let frozenAt = run.resolvedGlyphs
        run.replayRunUp()
        run.resume()
        #expect(run.nextGlyphIndex == frozenAt)
    }

    @Test("a run may be paused any number of times; each costs one run-up")
    func pausingIsUnlimitedButNotFree() {
        var run = runningRun()
        for _ in 0..<5 {
            run.requestPause(at: .zero)
            run.resolve(index: run.resolvedGlyphs, tapped: false)
            run.replayRunUp()
            run.resume()
        }
        #expect(run.pauseCount == 5)
        #expect(run.runUpGlyphsReplayed == 15)
        #expect(run.tally.rest.fouls == 0)
    }

    // MARK: resume is the gate and only the gate

    @Test("resume comes from a gate tap only — no other input reaches the paused state",
          arguments: [SievePauseInput.gateTap, .scrimTap, .backgroundReturn, .anywhereTap])
    func onlyTheGateResumes(_ input: SievePauseInput) {
        var run = runningRun()
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        run.receive(input)
        #expect((run.phase == .streaming(.body)) == (input == .gateTap))
    }

    @Test("returning to the foreground does NOT resume — the overlay stays until the gate is tapped")
    func foregroundDoesNotResume() {
        var run = runningRun()
        run.requestPause(at: .zero); run.resolve(index: run.resolvedGlyphs, tapped: false)
        run.receive(.backgroundReturn)
        #expect(run.phase == .paused(.body))
    }
}
```

`Modules/Tests/LoomFeatureTests/SievePauseOverlayTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature

@Suite("SievePauseOverlay — §12.2 screen 18", .tags(.unit, .presubmission))
@MainActor
struct SievePauseOverlayTests {

    @Test("the overlay is the only place the abandon chevron exists")
    func chevronLivesOnlyHere() {
        #expect(SievePauseOverlay.controls.contains(.abandonChevron))
        #expect(SieveRoundView.streamingControls.contains(.abandonChevron) == false)
        #expect(SieveRoundView.streamingControls == [.pauseKey])
    }

    @Test("the chevron abandons only on a second, confirming tap")
    func chevronNeedsTwoTaps() {
        var overlay = SievePauseOverlay.Model()
        #expect(overlay.tapChevron() == .arming)
        #expect(overlay.tapChevron() == .abandoned)
    }

    @Test("the confirm arming lapses, so a stray first tap does not sit waiting")
    func chevronArmingLapses() {
        var overlay = SievePauseOverlay.Model()
        _ = overlay.tapChevron()
        overlay.armingElapsed()
        #expect(overlay.tapChevron() == .arming)          // back to the first tap
    }

    @Test("the scrim does not dismiss on tap — the gate owns the resume")
    func scrimIsInert() {
        #expect(SievePauseOverlay.scrimKind == .sievePause)
        #expect(SievePauseOverlay.scrimDismissesOnTap == false)
    }

    @Test("the covered lane is removed from the accessibility tree")
    func coveredContentIsHidden() {
        #expect(SievePauseOverlay.hidesCoveredContent)
        #expect(SievePauseOverlay.isModal)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SievePauseTests`
then `swift test --package-path Modules --filter SievePauseOverlayTests`

Expect missing `SieveRunState.requestPause`, `.resume`, `.replayRunUp`, `SievePauseInput`,
`SievePauseOverlay` and `Scrim.Kind.sievePause`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SievePause.swift` — `SievePauseInput`, `SieveRunUp`, the freeze-at-boundary rule |
| modify | `HunchCore/Sources/Rounds/SieveRunState.swift` — `requestPause(at:)`, `reportFrameOverrun(_:)`, `resume()`, `replayRunUp()`, `pauseCount`, `runUpGlyphsReplayed` |
| create | `Modules/Sources/LoomFeature/SievePauseOverlay.swift` — screen 18 |
| modify | `Modules/Sources/HunchUI/Chrome/Scrim.swift` — add `Scrim.Kind.sievePause`; create the file if E09·T01 has not |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Scrim.sievePause` (L2), and the run-up's three retracting arcs' duration |
| modify | `Modules/Sources/LoomFeature/SieveRoundView.swift` — the commit bar's pause key; the overlay presentation with `hunchEnvironment` re-injected |
| modify | `Modules/Sources/LoomFeature/SieveRun.swift` — `scenePhase` observation, frame-overrun measurement, the `ContinuousClock.sleep` at the view edge |
| create | `HunchCore/Tests/RoundsTests/SievePauseTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/SievePauseOverlayTests.swift` |
| modify | `HunchUITests/` — one row asserting `.isModal` keeps the frozen lane out of traversal |
| modify | `tests.json` — five entries: freeze at boundary, run-up is three glyphs, run-up is free, gate-only resume, chevron needs two taps |

## Implementation notes

### Freezing at the boundary is the whole safety property

```swift
public mutating func requestPause(at instant: Duration) {
    guard case .streaming = phase else { return }
    pauseRequested = true                 // honoured when the CURRENT glyph resolves
}
```

The pause is a **latch**, not an immediate transition. §9.5's side-effect column says *"freeze at the
next glyph boundary"*, and §9.8 explains what that protects: a glyph half-way through its window
whose window is cut short is a glyph the player was denied, and in a timed mode that is
indistinguishable from cheating in the player's favour or against them depending on the glyph. A
pause mid-window would also break the invariant T01 exists for — that a glyph's window is a property
of `n` and of nothing else.

`reportFrameOverrun(_:)` routes through the same latch, so the auto-pause and the deliberate pause
are one code path with one test. That is the reason §14.6 risk 6's mitigation can be stated as
"auto-pauses past a 100 ms budget miss" without a second set of semantics to reason about.

### The run-up is a replay, not a rewind

```swift
public struct SieveRunUp: Hashable, Sendable {
    public let indices: [Int]             // at most 3, clamped at the start of the stream
    public let rate: Double               // schedule.rateStart — r₀, always
}
```

Three properties the tests pin because prose will not hold them:

1. **It costs nothing.** No resolution is appended, no foul is counted, `resolvedGlyphs` does not
   move, `completion` does not move. `replayRunUp()` mutates *nothing* in the tally. The clean way to
   guarantee that is for the replay to be a **presentation** concern driven by `SieveRunUp`, with the
   core state machine simply not accepting `resolve` while `phase == .replayingRunUp`.
2. **Replayed glyphs keep their original results.** The player may tap during the run-up; the taps
   are discarded exactly as taps outside the gate are (T02's `.discardedSilently`), because the
   result is already written. `replayedGlyphsKeepTheirResults` mashes through it and asserts nothing
   moved.
3. **It runs at `r₀`, not at the rate the run had reached.** That is what makes it a *run-up* rather
   than a jump cut: the player re-enters at the mode's slowest speed and the ramp resumes from the
   frozen index.

The run-up is also the mode's only disincentive against pausing repeatedly — three glyphs of already
known evidence at the slowest rate is time spent, and §9.8 names it as *"its own soft
disincentive"*. Do not add a pause cap, a pause counter on screen, or a score penalty; the cost is
the seconds.

### The three retracting arcs

§12.2 screen 18 gives the overlay *"three retracting arcs on resume"* — one per run-up glyph,
retracting as each replays, which is the arc meter (`hunch-shared-marks`, E04·T08) at three segments.
Do not draw a countdown numeral: §12.2's row says the screen is textless and check 13 (T02) fails the
build on a `Text`. Under Reduce Motion the arcs crossfade between their three states rather than
sweeping; the cadence is unchanged, because the run-up is timing the game is scored around even
though it is not itself scored.

### The scrim, and the two things it must not do

```swift
// Modules/Sources/LoomFeature/SievePauseOverlay.swift
SieveLaneView(frozenAt: run.frozenFrame, env: env)
    .scrim(.sievePause, isPresented: true, onDismiss: {})   // ← deliberately a no-op
```

`scrim.md` §4 is explicit and the reason is worth carrying: *"a tap-anywhere resume on a timed run is
the exploit §12.7 is closing."* The gate owns the resume, and the gate is the same 375 × 88 pt band
the run is played with — *"never a region SIEVE does not have"*, which rules out a "Resume" button, a
centred play triangle, or a full-screen tap target. It also means the gate stays in the accessibility
tree while paused, with its `"Admit"` action swapped for a resume action.

The scrim covers the **entire safe area including the instrument bar** — the foul ticks and the
progress arc freeze with the lane — and the chevron sits **above** the scrim because it is the
overlay's own control. `.accessibilityHidden(true)` on the covered content is manual and is not
optional: a hand-drawn overlay does not remove what is under it from the accessibility tree, and
without it a rotor swipe reaches the frozen gate.

### The chevron: two taps, and only from here

§12.7: *"That confirm-by-repeat and the Seal's optional one (§12.6) are the only two in the app."*
So the chevron's model is a two-state latch with a lapse, not an alert:

```swift
enum ChevronOutcome { case arming, abandoned }
```

No `ResetConfirmAlert`, no modal, no confirmation sheet — §4.3 abolishes the error modal outright and
§12.2's inventory is closed at eighteen screens. The *effect* of `.abandoned` — scored exactly as a
foul-out at the last resolved glyph — is **T08's**; this task produces the intent.

### `scenePhase`, and the one `ContinuousClock`

`SieveRun` observes `scenePhase`: `.inactive` latches a pause, `.background` additionally writes the
frozen stream position, `.active` does **nothing but keep the overlay up**. This is the app's only
`ContinuousClock.sleep`, at the view edge, driving the conveyor from `SieveSchedule`'s glyph index —
never a `TimelineView` cadence a stutter can skew (`gate-band.md` §4). Re-inject
`hunchEnvironment(dependencies)` into the overlay: it is a presented subtree and starts a new
environment hierarchy (`04 A25`), and `08 §6` names `SievePauseOverlay` as one of the three places
this bug appears.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SievePauseTests` green — all eleven tests.
- [ ] `swift test --package-path Modules --filter SievePauseOverlayTests` green — all five tests.
- [ ] `grep -n "onDismiss" Modules/Sources/LoomFeature/SievePauseOverlay.swift` shows a no-op closure with the §12.7 citation beside it.
- [ ] `grep -rn "TimelineView" Modules/Sources/LoomFeature/Sieve*.swift` returns nothing.
- [ ] `grep -n "hunchEnvironment" Modules/Sources/LoomFeature/SieveRoundView.swift` shows re-injection at the overlay's presentation site.
- [ ] `grep -rn "ResetConfirmAlert\|\.alert(\|confirmationDialog" Modules/Sources/LoomFeature/SievePauseOverlay.swift` returns nothing.
- [ ] `Scrim.Kind` has exactly two cases, and `C.Scrim.sievePause` is declared at L2 in `C.swift` with its §12.2 citation.
- [ ] The `HunchUITests` row asserting `.isModal` passes, and the accessibility audit is clean on screen 18.
- [ ] `tests.json` carries the five entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes making the pause immediate rather than latched, decline and point at `pauseNeverTruncatesAWindow`.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically whether any input other than a gate tap can reach `.streaming` from `.paused`.
4. Commit: `git commit -m "E14/T07: SIEVE pause, the 3-glyph run-up and SievePauseOverlay"`

## Out of scope

- What abandoning **costs** — scored as a foul-out at the last resolved glyph, with the ability update running normally — **T08**.
- Voiding on termination, and the void record — **T08**. Backgrounding is neither pausing nor voiding, and this task owns only the first.
- The Reduce-Motion crossfade for the lane itself, and the parity assertion — **T10**.
- The arc meter's drawing — **E04·T08**; this task composes it at three segments.
- The 600 ms `.active` spin-up used by PROBE, DRIFT and ECHO — **E17·T09**. SIEVE does not have one; it has an overlay that waits.
- The pause key's drawing at 44 pt — **`hunch-chrome-and-meta/references/key.md`**, composed here, drawn in **E17·T02**.
