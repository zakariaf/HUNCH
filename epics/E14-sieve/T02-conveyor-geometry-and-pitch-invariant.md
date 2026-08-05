# T02 — Conveyor geometry and the pitch invariant

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Conveyor geometry (SIEVE) · Mode invariants (VERIFICATION — the SIEVE pitch invariant) |
| **Status** | not started |

## Skills to load

Load these in this order:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | This task opens the rest of `C.GateBand` and it is a drawing task, so the token vocabulary comes first: `accent.brass` on the two hairlines is a *deliberate* exception to the accent ration and has to be spent knowingly, `env.weight(.hairline)` is what makes High Contrast double them, and every opacity and duration in `SieveRoundView` has to resolve rather than be typed. |
| `hunch-bench-instruments` | `references/gate-band.md` is the whole component: the five regions, the three invariants, the four states, the `.contentShape(.rect)` covering the band including where there is no glyph, the VoiceOver contract, and the eight ways it goes wrong. It also carries the rule that the *travelling glyph* is `hunch-glyph-renderer`'s and the sump ring is `hunch-shared-marks`', so this task composes and redraws nothing. |
| `hunch-accessibility` | The gate is one accessibility element with an `"Admit"` custom action that must call the *same function* as the tap, and it must stay in the tree between glyphs — `.disabled()` is the named defect. `references/rotors-and-gestures.md` §9 also fixes that there is no Magic Tap in SIEVE. |

`hunch-motion-and-feedback` is **not** loaded here: the tap response (`dur.tap` ring, no scale, no
shudder) and the Reduce-Motion substitution are T07's and T10's. This task establishes *where* things
are and *what is actionable*, not how anything moves.

## Objective

At the end of this task the SIEVE surface has its five regions laid out against the SE reference,
`C.GateBand` is complete, and `SieveConveyor` is a pure core value that answers, for any time `t`,
where each glyph is and which one — if any — is actionable. The 375 × 88 pt gate is the entire tap
target, hit testing binds a touch-**down** to the glyph whose centre is nearest y = 464 within ±44 pt
or discards it in silence, and `P = 132 pt > 88 pt` is asserted at every rate across bands 1–6 ×
tempo steps 0–3 so at most one glyph is ever actionable.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.2 | the region table (instrument bar / lip / lane / gate / sump / tail / commit bar) with its `y` bounds; the gate as *the entire actionable target*; actionable = centre within ±44 pt of y = 464; `P = 132 pt` fixed at every speed; taps outside the gate discarded silently — no foul, no sound, no haptic |
| `GAME_DESIGN.md` | §9.4 S4 | the pitch invariant re-asserted at every rate `r`, as a stream guardrail |
| `GAME_DESIGN.md` | §9.9 | GATE-STRADDLE (bind to nearest centre at the tap timestamp, within ±44 pt), DOUBLE-TAP (ignored; admit is idempotent; one glyph produces at most one foul), THUMB-PARK (**touch-down only**, and a touch begun before the glyph entered does not carry over) |
| `GAME_DESIGN.md` | §12.2 screen 5 | `SieveRoundView`'s contents, and *"no lawful count anywhere, it would leak the law's admit rate `p`"* |
| `GAME_DESIGN.md` | §12.8 | targets ≥ 44 × 44 pt, ≥ 8 pt apart; SIEVE's gate at y 420–508 is tier-2 reach; everything above y = 220 is read-only |
| `GAME_DESIGN.md` | §13.10 | the gate's element: traits `.button` + `.updatesFrequently`, label "Gate", value = the actionable glyph's label announced **on gate entry**, action "Admit"; the tail as a container listing the last six resolved glyphs |
| `.claude/skills/hunch-bench-instruments/references/gate-band.md` | §1–§5, §7, §8 | the owning symbol `GateBandView`, the `C.GateBand` member list, the three invariants, the four states, High Contrast, and the eight failure modes |
| `.claude/skills/hunch-bench-instruments/references/ribbon.md` | §3, §5 | the tail is the ribbon's fourth surface — 36 pt tiles, leading→trailing, one container element. **Reuse it; do not re-implement it** |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A20, A24, A26 | the pure part (`SieveConveyor`) is extracted and tested; `RenderEnv` is injected, never read; `HunchUI` components read `@Environment` in the optional form |

## TDD — the test comes first

**Step 1 — write the failing test.** Create two files.

`HunchCore/Tests/RoundsTests/SievePitchInvariantTests.swift`:

```swift
import Testing
import Glyphs                      // Band
import Rounds                      // SieveSchedule, SieveConveyor, SieveStation
import Tokens                      // C.GateBand
import HunchTestSupport

@Suite("SIEVE pitch invariant and the actionable rule — §9.2, §9.4 S4", .tags(.unit, .presubmission))
struct SievePitchInvariantTests {

    /// The invariant in its simplest form: it is a property of two constants, not of a speed.
    @Test("P > gate height, as a fact about the tokens")
    func pitchExceedsGateHeight() {
        #expect(C.GateBand.glyphPitch > C.GateBand.height)
        #expect(C.GateBand.actionableRadius * 2 == C.GateBand.height)
        #expect(C.GateBand.centreY == C.GateBand.gateTop + C.GateBand.height / 2)
    }

    /// S4, in the form the guardrail states it: re-asserted at every rate the game can run at.
    @Test("at most one glyph is actionable, at every rate, at every sampled instant",
          arguments: Band.sieveServable, 0...3)
    func atMostOneActionable(_ band: Band, _ step: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: step, pacing: .ramped)
        let conveyor = SieveConveyor(schedule: schedule, presentation: .travelling)

        // Sample at 240 Hz — four times the display rate, so no window can hide between samples.
        let tick = Duration.milliseconds(1000 / 240)
        var t = Duration.zero
        while t < schedule.duration {
            #expect(conveyor.actionableIndices(at: t).count <= 1)
            t += tick
        }
    }

    @Test("every glyph is actionable for exactly window(n), no more and no less",
          arguments: Band.sieveServable, 0...3)
    func actionableSpanEqualsWindow(_ band: Band, _ step: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: step, pacing: .ramped)
        let conveyor = SieveConveyor(schedule: schedule, presentation: .travelling)
        for n in 0..<schedule.glyphCount {
            let span = conveyor.actionableSpan(of: n)
            #expect(isApproximatelyEqual(span.duration.seconds, schedule.window(at: n).seconds,
                                         absoluteTolerance: 1e-9))
            #expect(span.start == schedule.arrival(at: n))
        }
    }

    @Test("actionable is exactly |centre − 464| ≤ 44, and nothing else",
          arguments: Band.sieveServable)
    func actionableIsTheCentreRule(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        let conveyor = SieveConveyor(schedule: schedule, presentation: .travelling)
        let n = schedule.glyphCount / 2
        let span = conveyor.actionableSpan(of: n)

        for offset in [Duration.milliseconds(-1), .zero, span.duration, span.duration + .milliseconds(1)] {
            let t = span.start + offset
            let centre = conveyor.centreY(of: n, at: t)
            let inside = abs(centre - C.GateBand.centreY) <= C.GateBand.actionableRadius
            #expect(conveyor.actionableIndices(at: t).contains(n) == inside)
        }
    }

    // MARK: §9.9's three named edge cases

    @Test("GATE-STRADDLE — a tap binds to the nearest centre within ±44 pt, or to nothing",
          arguments: Band.sieveServable)
    func gateStraddleBindsToNearest(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        let conveyor = SieveConveyor(schedule: schedule, presentation: .travelling)
        let n = 4
        let span = conveyor.actionableSpan(of: n)

        #expect(conveyor.glyphBound(byTapAt: span.start) == n)
        #expect(conveyor.glyphBound(byTapAt: span.start + span.duration / 2) == n)
        // One tick before the glyph's leading edge crosses in, nothing is bound at all.
        #expect(conveyor.glyphBound(byTapAt: span.start - .milliseconds(2)) == nil)
    }

    @Test("the gap between two consecutive actionable spans is never negative — the pitch guarantees it",
          arguments: Band.sieveServable, 0...3)
    func spansNeverOverlap(_ band: Band, _ step: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: step, pacing: .ramped)
        let conveyor = SieveConveyor(schedule: schedule, presentation: .travelling)
        for n in 1..<schedule.glyphCount {
            let previous = conveyor.actionableSpan(of: n - 1)
            let current = conveyor.actionableSpan(of: n)
            #expect(current.start >= previous.start + previous.duration)
        }
    }
}
```

`HunchCore/Tests/RoundsTests/SieveGateInputTests.swift`:

```swift
import Testing
import Glyphs
import Rounds
import Tokens

@Suite("SIEVE gate input policy — §9.2, §9.9", .tags(.unit, .presubmission))
struct SieveGateInputTests {

    private func gate() -> SieveGate {
        SieveGate(conveyor: SieveConveyor(
            schedule: SieveSchedule(band: .contextual, tempoStep: 0, pacing: .ramped),
            presentation: .travelling))
    }

    @Test("a touch-down inside the band while a glyph is actionable admits it")
    func admitsInsideTheBand() {
        var gate = gate()
        let t = gate.conveyor.actionableSpan(of: 3).start + .milliseconds(20)
        #expect(gate.receive(.touchDown(y: C.GateBand.centreY, at: t)) == .admitted(index: 3))
    }

    @Test("the whole 375 × 88 band admits, not just the glyph's own footprint")
    func theTargetIsTheBandNotTheMark() {
        var gate = gate()
        let t = gate.conveyor.actionableSpan(of: 3).start + .milliseconds(20)
        let top = C.GateBand.gateTop + 1
        let bottom = C.GateBand.gateTop + C.GateBand.height - 1
        #expect(gate.receive(.touchDown(y: top, at: t)) == .admitted(index: 3))
        var second = gate()
        #expect(second.receive(.touchDown(y: bottom, at: t)) == .admitted(index: 3))
    }

    @Test("a touch-down outside the band is discarded silently — no foul, no cue, no haptic")
    func outsideTheBandIsSilent() {
        var gate = gate()
        let t = gate.conveyor.actionableSpan(of: 3).start + .milliseconds(20)
        let outcome = gate.receive(.touchDown(y: C.GateBand.gateTop - 1, at: t))
        #expect(outcome == .discardedSilently)
        #expect(outcome.foulsAccrued == 0)
        #expect(outcome.cue == nil)
        #expect(outcome.haptic == nil)
    }

    @Test("a touch-down inside the band with nothing actionable is discarded silently too")
    func emptyBandIsSilent() {
        var gate = gate()
        let span = gate.conveyor.actionableSpan(of: 3)
        let between = span.start + span.duration + .milliseconds(5)
        #expect(gate.receive(.touchDown(y: C.GateBand.centreY, at: between)) == .discardedSilently)
    }

    @Test("DOUBLE-TAP — the second touch-down on the same glyph is ignored; admit is idempotent")
    func doubleTapIsIgnored() {
        var gate = gate()
        let span = gate.conveyor.actionableSpan(of: 3)
        #expect(gate.receive(.touchDown(y: C.GateBand.centreY, at: span.start)) == .admitted(index: 3))
        let second = gate.receive(.touchDown(y: C.GateBand.centreY, at: span.start + span.duration / 2))
        #expect(second == .ignoredDuplicate(index: 3))
        #expect(second.foulsAccrued == 0)
    }

    @Test("THUMB-PARK — only touch-DOWN registers; a held finger admits nothing")
    func parkedThumbAdmitsNothing() {
        var gate = gate()
        let span = gate.conveyor.actionableSpan(of: 3)
        // Down before the glyph is actionable, then held across the whole window.
        #expect(gate.receive(.touchDown(y: C.GateBand.centreY, at: span.start - .milliseconds(50)))
                == .discardedSilently)
        #expect(gate.receive(.touchMoved(y: C.GateBand.centreY, at: span.start + .milliseconds(10)))
                == .ignoredNotADown)
        #expect(gate.receive(.touchMoved(y: C.GateBand.centreY, at: span.start + span.duration / 2))
                == .ignoredNotADown)
        // Lifting and pressing again inside the window does admit — the player made a new decision.
        _ = gate.receive(.touchUp(at: span.start + span.duration / 2))
        #expect(gate.receive(.touchDown(y: C.GateBand.centreY, at: span.start + span.duration * 3 / 4))
                == .admitted(index: 3))
    }

    @Test("a touch that began before the glyph entered never carries over, however long it is held")
    func heldTouchNeverCarriesOver() {
        var gate = gate()
        let span = gate.conveyor.actionableSpan(of: 3)
        _ = gate.receive(.touchDown(y: C.GateBand.centreY, at: .zero))
        var admitted = false
        var t = Duration.zero
        while t < span.start + span.duration {
            if case .admitted = gate.receive(.touchMoved(y: C.GateBand.centreY, at: t)) { admitted = true }
            t += .milliseconds(4)
        }
        #expect(admitted == false)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter Sieve`

Expect missing `SieveConveyor`, `SieveStation`, `SieveGate`, `SieveTouch`, `GateOutcome` and the
remaining `C.GateBand` members. If the pitch-invariant suite passes before `SieveConveyor` exists,
the suite is asserting nothing.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SieveConveyor.swift` — `SieveConveyor`, `SieveStation`, `SievePresentation`, `ActionableSpan` |
| create | `HunchCore/Sources/Rounds/SieveGate.swift` — `SieveGate`, `SieveTouch`, `GateOutcome` |
| modify | `HunchCore/Sources/Tokens/C.swift` — extend `C.GateBand` with `gateTop`, `centreY`, `actionableRadius`, `laneGlyph`, `tailGlyph`, `hairline`, `sumpDissolve`, `seedHold`, and the region bounds |
| create | `Modules/Sources/HunchUI/GateBandView.swift` — the owning symbol from `gate-band.md` §4 |
| create | `Modules/Sources/LoomFeature/SieveRoundView.swift` — the five regions plus the instrument and commit bars |
| create | `Modules/Sources/LoomFeature/SieveRun.swift` — `@MainActor @Observable final class SieveRun`, thin over the core values |
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` — add the tail regime (36 pt, six tiles); **do not create a `TailView`** |
| create | `HunchCore/Tests/RoundsTests/SievePitchInvariantTests.swift` |
| create | `HunchCore/Tests/RoundsTests/SieveGateInputTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/SieveLayoutTests.swift` — the SE region-for-region check |
| modify | `Scripts/check-source-hygiene.sh` — check 13 |
| modify | `tests.json` — five entries: pitch invariant, actionable rule, GATE-STRADDLE, DOUBLE-TAP, THUMB-PARK |
| modify | `DECISIONS.md` — the touch-down gesture ruling |

## Implementation notes

### `SieveConveyor` — the pure half

```swift
public enum SieveStation: UInt8, Sendable, CaseIterable {
    case lip, lane, gate, sump, gone
}

/// How the lane is presented. It changes no timing whatsoever — that is what T10 asserts —
/// but it has to be a value the view reads, or the parity test has nothing to compare.
public enum SievePresentation: UInt8, Sendable { case travelling, crossfading }

public struct ActionableSpan: Hashable, Sendable {
    public let start: Duration
    public let duration: Duration
}

public struct SieveConveyor: Sendable {
    public let schedule: SieveSchedule
    public let presentation: SievePresentation

    public func centreY(of index: Int, at t: Duration) -> Double
    public func station(of index: Int, at t: Duration) -> SieveStation
    public func actionableSpan(of index: Int) -> ActionableSpan
    public func actionableIndices(at t: Duration) -> [Int]
    public func glyphBound(byTapAt t: Duration) -> Int?
    public func previewCount(at t: Duration) -> Int      // how many glyphs sit above the gate
}
```

`centreY(of:at:)` is the whole geometry in one line: glyph `n`'s centre reaches `C.GateBand.centreY`
at `schedule.arrival(at: n) + schedule.window(at: n) / 2`, and moves at `schedule.speed(at: n)`
points per second. Everything else — station, span, preview count — is derived from it, so there is
exactly one place where "where is a glyph" is decided.

**`presentation` deliberately does not appear on the right-hand side of any of those functions.** That
is not an oversight; it is the invariant. T10's parity test constructs two conveyors that differ only
in `presentation` and asserts every answer is identical. If the flag ever *did* change an answer, the
substitution would have changed the game, which is the exact failure §13.7.4 and §13.12 gate 9 exist
to prevent.

### Why the flag lives here and not on `SieveSchedule`

`hunch-motion-and-feedback/references/reduce-motion.md` §7 sketches the parity test as
`SieveSchedule(band:tempoStep:isReduceMotionEnabled:)`. Taken literally that makes the assertion
tautological: `SieveSchedule` has no presentation concept, so a parameter it ignores proves only that
it ignores it. Put the flag where a wrong implementation *could* diverge — the conveyor, which is
what decides stations and preview counts — and keep the skill's assertion verbatim. Record this in
`DECISIONS.md`; it is a strengthening of the test, not a deviation from the requirement.

### `SieveGate` — the input policy, and why it is not `.onTapGesture`

```swift
public enum SieveTouch: Sendable {
    case touchDown(y: Double, at: Duration)
    case touchMoved(y: Double, at: Duration)
    case touchUp(at: Duration)
}

public enum GateOutcome: Hashable, Sendable {
    case admitted(index: Int)
    case ignoredDuplicate(index: Int)   // DOUBLE-TAP — admit is idempotent
    case ignoredNotADown                // THUMB-PARK — a move or a held finger
    case discardedSilently              // outside the band, or nothing actionable
}
```

`gate-band.md` §4's sketch uses `.onTapGesture`, and a tap gesture in SwiftUI fires on touch-**up**
inside. §9.9's THUMB-PARK row forbids exactly that: a finger pressed down before the glyph entered
and lifted inside the window would admit, which is a parked thumb harvesting the stream. Use a
zero-distance drag with a latch:

```swift
// Modules/Sources/HunchUI/GateBandView.swift
.contentShape(.rect)                                   // the whole band, always — gate-band.md §4
.gesture(
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { value in
            guard !isTouching else { return }          // only the FIRST event of a touch sequence
            isTouching = true
            onTouchDown(value.location.y)
        }
        .onEnded { _ in isTouching = false }
)
```

`isTouching` is `@GestureState`-backed `@State` local to the view; the *decision* is `SieveGate`'s,
which is why the core type takes `touchDown` / `touchMoved` / `touchUp` and can be tested without a
simulator. Record the deviation from `gate-band.md`'s sketch in `DECISIONS.md` and raise it back to
the skill so the reference file gains the drag form.

Three further rules the type encodes rather than documents:

1. **The target is the band, not the mark.** `.contentShape(.rect)` covers the full 375 × 88 pt
   including the frames where there is no glyph in it, and the `guard` is on `actionable != nil`
   *inside* the handler. Never `.disabled()` — the element must stay in the accessibility tree
   between glyphs, which is `gate-band.md` §8's named defect.
2. **Silence is total.** `.discardedSilently` carries `foulsAccrued == 0`, `cue == nil` and
   `haptic == nil` as fields, not as a comment, so T04 cannot accidentally route it into the foul
   counter and the test can assert it.
3. **One glyph, at most one foul.** `SieveGate` holds `lastAdmittedIndex` and returns
   `.ignoredDuplicate` for a repeat. Admit is idempotent (§9.9 DOUBLE-TAP).

### The five regions, and the two bars

`SieveRoundView` lays out §9.2's table against the SE reference (375 × 667, safe 375 × 647). The
regions are declared once, in `C.GateBand`, as `y` bounds — `lipRange`, `laneRange`, `gateTop`,
`sumpRange`, `tailRange` — and the view reads them; no view arithmetic re-derives a boundary.

- **The lane draws the glyph at 72 pt** and the tail at 36 pt; both call `GlyphCanvas` (E04·T05).
  Nothing here re-derives a silhouette.
- **The sump's ring is `hunch-shared-marks`' verdict ring** (E04·T07): solid 3 pt for admit, broken
  3 pt for reject, independent of hue (§9.8's last bullet). On a **miss**, the Loom's admit ring is
  drawn with the player's ring absent — a hollow result. That is a *composition* of two existing
  marks, not a new mark.
- **The tail is the ribbon's fourth surface** (`ribbon.md` §3): six 36 pt tiles, leading→trailing,
  one accessibility container labelled "Tail". Extend `RibbonCanvas` with the regime; a `TailView`
  would be the second drawing the skill's rule 1 forbids.
- **The instrument bar carries three foul ticks, the stream progress arc and the mode sigil, and
  nothing else.** The tick row and the arc meter are E04·T08's shared marks. **No numerals, and no
  lawful count of any kind** — a count of how many lawful glyphs have passed leaks the law's admit
  rate `p` directly (§12.2 screen 5). The foul-tick *values* arrive in T04; this task wires three
  empty ticks.
- **The commit bar holds `pause` (trailing, 44 pt) and nothing else while streaming.** The abandon
  chevron appears only in `paused` and is T07's.

### `accent.brass`, spent once

The gate's two hairlines are `accent.brass` with edge ticks. That is a deliberate spend of SIEVE's
accent ration (§13.1: three accent elements per screen) on the one control the mode has, and it is
why **nothing else on this surface is brass** — `gate-band.md` §8's last bullet. High Contrast does
not collapse `accent.brass` (only `hue.*` collapses), and `env.weight(.hairline)` doubles 0.5 → 1.0
there, so the band gets *more* legible, not less. Do not add a second brass element to the instrument
bar or the commit bar.

### Check 13

Append to `Scripts/check-source-hygiene.sh`:

```bash
# 13 — SIEVE's play surface renders no character and no numeral (§12.2 screen 5, §12.9)
grep -nE '\b(Text|Label|AttributedString)\b' \
     Modules/Sources/LoomFeature/SieveRoundView.swift \
     Modules/Sources/LoomFeature/SievePauseOverlay.swift \
  | grep -v 'accessibility' && fail "SIEVE surface renders text"
grep -nE 'lawfulCount|admitRate|\bp\b *=|numeral' \
     Modules/Sources/LoomFeature/SieveRoundView.swift \
  && fail "SIEVE instrument bar would leak the law's admit rate"
```

Demonstrate it fails on a planted `Text("3")` in `SieveRoundView.swift` before reverting.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SievePitchInvariantTests` green — the ≤ 1-actionable assertion sampled at 240 Hz across all 24 (band × tempo step) combinations.
- [ ] `swift test --package-path HunchCore --filter SieveGateInputTests` green — all seven tests, including THUMB-PARK's held-touch loop.
- [ ] `swift test --package-path Modules --filter SieveLayoutTests` green — the five regions match §9.2's `y` bounds on the SE reference, and every interactive target is ≥ 44 × 44 pt and within 460 pt of the bottom safe edge.
- [ ] `grep -n "onTapGesture" Modules/Sources/HunchUI/GateBandView.swift` returns nothing.
- [ ] `grep -n "disabled(" Modules/Sources/HunchUI/GateBandView.swift` returns nothing.
- [ ] `grep -rn "struct TailView\|struct SieveTailView" Modules/Sources` returns nothing — the tail is `RibbonCanvas`'s regime.
- [ ] `grep -n "brass" Modules/Sources/LoomFeature/SieveRoundView.swift` returns nothing — the gate spends the ration and nothing else on the surface does.
- [ ] `Scripts/check-source-hygiene.sh` green, and check 13 demonstrated to fail on a planted `Text("3")`.
- [ ] `SievePresentation` appears in `SieveConveyor`'s stored properties and in **no** expression on the right-hand side of `centreY`, `station`, `actionableSpan` or `previewCount` — verified by reading the file, and asserted by T10.
- [ ] `DECISIONS.md` records the touch-down ruling against `gate-band.md`'s `.onTapGesture` sketch, and the `SievePresentation`-on-the-conveyor ruling.
- [ ] `tests.json` carries the five entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s. The 240 Hz sampling loop is the one thing here that could cost real time — measure it, and if it exceeds ~150 ms, reduce to 120 Hz sampling plus an exact boundary check at every `span.start` and `span.start + span.duration`, which is stronger anyway.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E14/T02: conveyor geometry, the gate band and the pitch invariant"`

## Out of scope

- The tap's visual response — a `dur.tap` ring, no scale, no shudder — and the `sieve.tick` / `sieve.hit` / `sieve.miss` cue firing — **T04** (which outcomes) and **E20·T03/T04** (which players).
- What a glyph *is* at index `n` — **T03**.
- Whether an admit is a hit or a foul — **T04**.
- The pause scrim, the abandon chevron and the run-up — **T07**.
- The Reduce-Motion crossfade substitution and the parity assertion — **T10**.
- The travelling glyph's drawing, the verdict ring and the tick row — **E04·T05/T07/T08**.
- Localising "Gate", "Admit" and "Tail" — **E18**; this task adds the `Loc` accessors and English values only.
