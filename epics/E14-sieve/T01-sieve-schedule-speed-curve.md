# T01 — `SieveSchedule`, the speed curve

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | Speed curve (SIEVE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task creates the first file in a target that does not exist yet (`HunchCore/Sources/Rounds/SieveSchedule.swift` is named in `08 §1` as *phase 5* work), so the placement question is live: the boundary predicate has to rule that a speed curve is core because it is a pure function of `(band, tempoStep, pacing, n)` with no clock in it. This skill also carries **the one bullet in the whole library that says there is no `Clock` in this project** — SIEVE's timing is a pure `SieveSchedule` plus one `ContinuousClock.sleep` at the view edge — which is precisely the temptation this task must refuse. |
| `hunch-design-tokens` | `window(n)` and `preview(n)` are ratios of geometric constants (`88 / 132`, `340`) that have exactly one home, `C.GateBand`. Typing `0.667` or `340` into `SieveSchedule` creates a second home for a number the gate band already owns, and check 9 will not catch a bare `340`. |

`hunch-bench-instruments` is **not** loaded here. This task computes times; it draws nothing. The
gate band's geometry, states and hit testing are T02's, and `gate-band.md` is read there.

## Objective

At the end of this task `SieveSchedule` is a pure `Sendable` value that answers, for any band 1–6,
any tempo step 0–3 and any glyph index `n`, what rate the conveyor is running at, how long that glyph
is actionable, how long it is visible before it becomes actionable, when it arrives, and how long the
whole run takes — with no clock, no view and no reference to elapsed wall time anywhere in it. Because
the ramp is a function of `n` and never of seconds, a run is reproducible from its seed and a dropped
frame delays a glyph without ever shortening its window.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.3 | the four formulas (`r`, `v`, `window`, `preview`); the six band rows with `r₀`, `r₁`, `N`; the tempo step adding `0.20·s` to **both** `r₀` and `r₁`; and the ruling that SIEVE serves law bands 1–6 only, with ability above band 6 absorbed by the tempo step |
| `GAME_DESIGN.md` | §9.8 | the auto-pause past a 100 ms frame-budget miss, and the sentence that justifies the whole design — *"because `r` ramps in glyph index rather than wall-clock, a frame drop delays a glyph but never shortens its window"*; also the **steady stream** pacing (`r` fixed at `r₀`, no ramp) and the **VoiceOver step mode** pacing (`r` fixed at 0.75 g/s, no ramp) |
| `GAME_DESIGN.md` | §9.10 | the fixed round length, 41–46 s, which is what `duration` is checked against |
| `GAME_DESIGN.md` | §14.6 risk 6 | the performance framing: no dropped frame at `r₁`, and the auto-pause as the stated mitigation |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §5 | `SieveSchedule.swift` belongs in `HunchCore/Sources/Rounds/`; the boundary predicate; **"there is no `Clock` abstraction anywhere"** |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | one type for one concept; no `default:` in a `switch` over an enum you own |
| `ios-swift-guide/05-CONCURRENCY.md` | R21 | every public core type writes `: Sendable` explicitly |
| `.claude/skills/hunch-bench-instruments/references/gate-band.md` | §1, §2 | the owners of `glyphPitch`, `height` and the actionable radius; read it for the *token names only* — the drawing is T02's |
| `.claude/skills/hunch-accessibility/references/rotors-and-gestures.md` | §9 | the `SievePacing` shape, and the explicit warning **not** to collapse steady stream and VoiceOver step mode into one `isVoiceOverRunning` branch |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SieveScheduleTests.swift`:

```swift
import Testing
import Glyphs                      // Band
import Rounds                      // SieveSchedule, SievePacing
import Tokens                      // C.GateBand
import HunchTestSupport            // isApproximatelyEqual

@Suite("SIEVE speed curve — §9.3", .tags(.unit, .presubmission))
struct SieveScheduleTests {

    // MARK: the servable set

    @Test("SIEVE serves law bands 1–6 only (§9.3)")
    func servableBands() {
        #expect(Band.sieveServable == [.literal, .pair, .exclusive, .relational, .contextual, .guarded])
        #expect(Band.sieveServable.count == 6)
        #expect(Band.sieveServable.contains(.composite) == false)
        #expect(Band.sieveServable.contains(.systemic) == false)
    }

    // MARK: the ramp is linear in index, and only in index

    @Test("r(0) is the band's own r₀ at tempo step 0",
          arguments: Band.sieveServable)
    func rampStartsAtRZero(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        #expect(schedule.rate(at: 0) == schedule.rateStart)
    }

    @Test("r(n) = r₀ + (r₁ − r₀)·n/N, exactly, for every n",
          arguments: Band.sieveServable)
    func rampIsLinearInIndex(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        let span = schedule.rateEnd - schedule.rateStart
        for n in 0..<schedule.glyphCount {
            let expected = schedule.rateStart + span * Double(n) / Double(schedule.glyphCount)
            #expect(isApproximatelyEqual(schedule.rate(at: n), expected, absoluteTolerance: 1e-12))
        }
    }

    @Test("the last glyph runs below r₁ — n/N never reaches 1 (the table's r₁ column is nominal)",
          arguments: Band.sieveServable)
    func lastGlyphIsBelowREnd(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        #expect(schedule.rate(at: schedule.glyphCount - 1) < schedule.rateEnd)
    }

    @Test("the rate never decreases along the run",
          arguments: Band.sieveServable)
    func rateIsMonotone(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        for n in 1..<schedule.glyphCount {
            #expect(schedule.rate(at: n) >= schedule.rate(at: n - 1))
        }
    }

    // MARK: the tempo step

    @Test("tempo step s adds 0.20·s to BOTH ends, so it shifts the whole curve and never tilts it",
          arguments: Band.sieveServable, 0...3)
    func tempoStepShiftsWithoutTilting(_ band: Band, _ step: Int) {
        let base = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        let stepped = SieveSchedule(band: band, tempoStep: step, pacing: .ramped)
        let shift = 0.20 * Double(step)

        #expect(isApproximatelyEqual(stepped.rateStart, base.rateStart + shift, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(stepped.rateEnd, base.rateEnd + shift, absoluteTolerance: 1e-12))
        #expect(stepped.glyphCount == base.glyphCount)          // the step changes speed, never length

        for n in 0..<base.glyphCount {
            #expect(isApproximatelyEqual(stepped.rate(at: n), base.rate(at: n) + shift,
                                         absoluteTolerance: 1e-12))
        }
    }

    @Test("a tempo step outside 0…3 is not representable")
    func tempoStepIsClamped() {
        #expect(SieveSchedule(band: .guarded, tempoStep: 9, pacing: .ramped).tempoStep == 3)
        #expect(SieveSchedule(band: .guarded, tempoStep: -4, pacing: .ramped).tempoStep == 0)
    }

    // MARK: window and preview, derived from the gate's geometry and nothing else

    @Test("window(n) = (gate height / pitch) / r(n) — the 0.667 in §9.3 is 88/132, not a constant",
          arguments: Band.sieveServable)
    func windowIsGateHeightOverSpeed(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        let ratio = C.GateBand.height / C.GateBand.glyphPitch
        for n in 0..<schedule.glyphCount {
            #expect(isApproximatelyEqual(schedule.window(at: n).seconds, ratio / schedule.rate(at: n),
                                         absoluteTolerance: 1e-9))
        }
    }

    @Test("preview(n) = previewTravel / v(n), and v(n) = r(n)·pitch",
          arguments: Band.sieveServable)
    func previewIsTravelOverSpeed(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        for n in 0..<schedule.glyphCount {
            let speed = schedule.rate(at: n) * C.GateBand.glyphPitch
            #expect(isApproximatelyEqual(schedule.speed(at: n), speed, absoluteTolerance: 1e-9))
            #expect(isApproximatelyEqual(schedule.preview(at: n).seconds,
                                         C.GateBand.previewTravel / speed, absoluteTolerance: 1e-9))
        }
    }

    @Test("the worst case in the game is band 6, step 3, last glyph: window ≈ 226 ms, preview ≈ 0.87 s, total ≈ 1.10 s")
    func worstCaseDecisionTime() {
        let schedule = SieveSchedule(band: .guarded, tempoStep: 3, pacing: .ramped)
        let n = schedule.glyphCount - 1
        let total = schedule.preview(at: n).seconds + schedule.window(at: n).seconds
        #expect(isApproximatelyEqual(schedule.window(at: n).seconds, 0.226, absoluteTolerance: 0.003))
        #expect(isApproximatelyEqual(schedule.preview(at: n).seconds, 0.87, absoluteTolerance: 0.01))
        #expect(isApproximatelyEqual(total, 1.10, absoluteTolerance: 0.012))
    }

    // MARK: arrival and duration

    @Test("arrival(0) is zero and arrival(n) is the running sum of inter-glyph periods 1/r(k)",
          arguments: Band.sieveServable)
    func arrivalIsTheRunningSum(_ band: Band) {
        let schedule = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped)
        #expect(schedule.arrival(at: 0) == .zero)
        var running = 0.0
        for n in 0..<schedule.glyphCount {
            #expect(isApproximatelyEqual(schedule.arrival(at: n).seconds, running, absoluteTolerance: 1e-9))
            running += 1.0 / schedule.rate(at: n)
        }
        #expect(isApproximatelyEqual(schedule.duration.seconds, running, absoluteTolerance: 1e-9))
    }

    @Test("every band's run is 41–46 s at tempo step 0 (§9.10: 'fixed')",
          arguments: Band.sieveServable)
    func runLengthIsFixed(_ band: Band) {
        let seconds = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped).duration.seconds
        #expect(seconds > 41.0 && seconds < 47.0)
    }

    @Test("a higher tempo step always shortens the run", arguments: Band.sieveServable)
    func tempoStepShortensTheRun(_ band: Band) {
        let durations = (0...3).map { SieveSchedule(band: band, tempoStep: $0, pacing: .ramped).duration }
        #expect(durations == durations.sorted(by: >))
    }

    // MARK: the three pacings

    @Test("steady stream fixes r at r₀ with no ramp (§9.8, §12.6)", arguments: Band.sieveServable, 0...3)
    func steadyIsFlatAtRZero(_ band: Band, _ step: Int) {
        let ramped = SieveSchedule(band: band, tempoStep: step, pacing: .ramped)
        let steady = SieveSchedule(band: band, tempoStep: step, pacing: .steady)
        for n in 0..<steady.glyphCount {
            #expect(steady.rate(at: n) == ramped.rateStart)
        }
    }

    @Test("VoiceOver step mode fixes r at 0.75 g/s with no ramp, giving an 889 ms window (§9.8)",
          arguments: Band.sieveServable, 0...3)
    func steppedIsFlatAtThreeQuarters(_ band: Band, _ step: Int) {
        let stepped = SieveSchedule(band: band, tempoStep: step, pacing: .stepped)
        for n in 0..<stepped.glyphCount {
            #expect(stepped.rate(at: n) == 0.75)
            #expect(isApproximatelyEqual(stepped.window(at: n).seconds, 0.889, absoluteTolerance: 0.0005))
        }
    }

    @Test("steady and stepped are two pacings, not one — §9.8 gives them different rates",
          arguments: Band.sieveServable)
    func steadyIsNotStepped(_ band: Band) {
        let steady = SieveSchedule(band: band, tempoStep: 0, pacing: .steady)
        let stepped = SieveSchedule(band: band, tempoStep: 0, pacing: .stepped)
        #expect(steady.rate(at: 0) != stepped.rate(at: 0))
    }

    // MARK: reproducibility, and the auto-pause

    @Test("the schedule is a pure function of its three arguments", arguments: Band.sieveServable, 0...3)
    func scheduleIsPure(_ band: Band, _ step: Int) {
        #expect(SieveSchedule(band: band, tempoStep: step, pacing: .ramped)
                == SieveSchedule(band: band, tempoStep: step, pacing: .ramped))
    }

    @Test("a frame-budget miss over 100 ms auto-pauses; at or under it does not (§9.8)")
    func autoPauseThreshold() {
        #expect(SieveSchedule.shouldAutoPause(frameOverrun: .milliseconds(101)))
        #expect(SieveSchedule.shouldAutoPause(frameOverrun: .milliseconds(100)) == false)
        #expect(SieveSchedule.shouldAutoPause(frameOverrun: .zero) == false)
    }

    @Test("no API on the schedule takes or returns a wall-clock instant")
    func scheduleHasNoClock() {
        // A compile-level statement: `arrival` and `duration` are Durations, never Dates or Instants.
        let schedule = SieveSchedule(band: .contextual, tempoStep: 0, pacing: .ramped)
        #expect(type(of: schedule.arrival(at: 3)) == Duration.self)
        #expect(type(of: schedule.duration) == Duration.self)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SieveScheduleTests`

Expect missing `SieveSchedule`, `SievePacing`, `Band.sieveServable`, `C.GateBand.height`,
`C.GateBand.glyphPitch`, `C.GateBand.previewTravel` and `Duration.seconds`. Confirm the failure is a
**missing symbol**, not a malformed suite: if `SieveScheduleTests` compiles and passes before
`SieveSchedule.swift` exists, the file is testing nothing.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SieveSchedule.swift` — `SieveSchedule`, `SievePacing` |
| modify | `HunchCore/Sources/Tokens/C.swift` — open the `C.GateBand` namespace with **three** members: `height`, `glyphPitch`, `previewTravel` |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` (E05·T06's file) — `static let sieveServable: [Band]` |
| modify | `HunchCore/Package.swift` — the `Rounds` target gains `Tokens` as a dependency |
| create | `HunchCore/Sources/Rounds/Duration+Seconds.swift` — the one `Duration.seconds: Double` accessor, if E12 has not already added it |
| create | `HunchCore/Tests/RoundsTests/SieveScheduleTests.swift` |
| modify | `tests.json` — four entries: ramp-is-index-linear, tempo-step-shifts-both-ends, worst-case decision time, auto-pause threshold |
| modify | `DECISIONS.md` — the three-case `SievePacing` |

## Implementation notes

### The shape

```swift
// HunchCore/Sources/Rounds/SieveSchedule.swift
import Tokens

/// How the rate behaves across a run. Three cases, not two: §9.8 gives the steady-stream setting
/// and VoiceOver step mode *different* rates, so collapsing them would silently change one of them.
public enum SievePacing: UInt8, Sendable, CaseIterable {
    case ramped      // §9.3 — the default: r₀ → r₁ linearly in glyph index
    case steady      // §12.6 — r fixed at r₀, no ramp, ×0.85 score (T09)
    case stepped     // §9.8  — VoiceOver: r fixed at 0.75 g/s, no ramp, scoring identical
}

public struct SieveSchedule: Hashable, Sendable {
    public let band: Band
    public let tempoStep: Int          // clamped to 0…3 in init
    public let pacing: SievePacing

    public init(band: Band, tempoStep: Int, pacing: SievePacing)

    public var glyphCount: Int         // N, from §9.3's table
    public var rateStart: Double       // r₀ + 0.20·s
    public var rateEnd: Double         // r₁ + 0.20·s

    public func rate(at index: Int) -> Double        // glyphs per second
    public func speed(at index: Int) -> Double       // points per second
    public func window(at index: Int) -> Duration    // seconds actionable
    public func preview(at index: Int) -> Duration   // seconds visible above the gate
    public func arrival(at index: Int) -> Duration   // when glyph `index` enters the gate
    public var duration: Duration                    // arrival(N−1) + 1/r(N−1)

    public static let autoPauseThreshold = Duration.milliseconds(100)
    public static func shouldAutoPause(frameOverrun: Duration) -> Bool
}
```

### The band table has one home and it is a `switch`

The six rows of §9.3 — `r₀`, `r₁`, `N` — go into one `private static func row(_ band: Band) ->
(rateStart: Double, rateEnd: Double, glyphCount: Int)` with an exhaustive `switch` and **no
`default:`** (`W29`). Bands 7 and 8 are not servable, so the switch's job at those two cases is to
`preconditionFailure` naming §9.3, not to invent a row. Do not spell the table as a dictionary keyed
by `Band` — a dictionary makes "band 7 has no row" a runtime `nil` instead of a compile-time
exhaustiveness obligation, and `Band.sieveServable` then becomes a second, drifting source of truth.

`Band.sieveServable` is derived from the same switch, not typed out beside it:

```swift
extension Band {
    /// §9.3 — SIEVE serves law bands 1–6 only; ability above band 6 is absorbed by the tempo step.
    public static let sieveServable: [Band] = allCases.filter { $0 <= .guarded }
}
```

### Why the ramp is in index and what that buys

`r(n) = r₀ + (r₁ − r₀)·n/N` divides by `N`, not `N − 1`, so the last glyph runs strictly below `r₁`.
That is deliberate and is asserted: the table's `r₁` column is the *asymptote*, and reading it as
"the speed of the final glyph" is the sort of off-by-one that would make the worst-case decision-time
budget wrong by one glyph's worth of ramp.

The whole point of indexing by `n` is stated in §9.8 and is the thing to protect in review: **a
dropped frame delays a glyph but never shortens its window.** Concretely, T02's conveyor advances the
*index* only when the current glyph's `window(at:)` has fully elapsed in presented time. If any part
of this file ever reads elapsed seconds and solves for `n`, a stutter compresses the window and the
mode becomes unfair exactly when the device is under load — which is §14.6 risk 6's failure mode,
not a hypothetical.

### `window` and `preview` are derived, never typed

```swift
public func window(at index: Int) -> Duration {
    .seconds(C.GateBand.height / C.GateBand.glyphPitch / rate(at: index))
}

public func preview(at index: Int) -> Duration {
    .seconds(C.GateBand.previewTravel / speed(at: index))
}
```

§9.3 writes `window(n) = 88 / v(n) = 0.667 / r(n)`. **0.667 is `88 / 132`** — the gate's height over
the glyph pitch — so writing it as a literal would be a third home for two numbers that already have
one. `C.GateBand.previewTravel` is `340` and is a **spec constant**: §9.3 states it and never derives
it from the region boundaries in §9.2. Declare it once with the §9.3 citation attached and do not
"fix" it by recomputing it from lip/lane/gate coordinates — record that in `DECISIONS.md`.

### `Duration`, not `TimeInterval`

Every time this file returns is a `Duration` (`Swift.Duration`, iOS 16+, and the project floor is 18).
It is the only spelling that cannot be confused with a wall-clock instant, and the test asserts the
return type for exactly that reason. Add one accessor:

```swift
extension Duration {
    /// Seconds as a `Double`, for arithmetic and for `#expect` against §9.3's tabulated values.
    public var seconds: Double { Double(components.seconds) + Double(components.attoseconds) * 1e-18 }
}
```

If E12·T01 (`DriftSchedule`) already added it, modify that file rather than creating a second one —
`01 P28`'s banned-filename rule and `N45` both bite here, and two `Duration+` files is exactly the
drift the ownership table exists to stop.

### The three pacings, and the trap in collapsing two of them

```swift
public func rate(at index: Int) -> Double {
    switch pacing {
    case .ramped:  rateStart + (rateEnd - rateStart) * Double(index) / Double(glyphCount)
    case .steady:  rateStart
    case .stepped: Self.voiceOverRate          // 0.75 g/s, §9.8
    }
}
```

`hunch-accessibility/references/rotors-and-gestures.md` §9 sketches `SievePacing { adaptive, stepped
}` and says the steady-stream toggle *"reaches the same `.stepped` pacing by a different route."*
That is loose and this task rules against it: §9.8 fixes steady stream at `r₀` and VoiceOver at
**0.75 g/s**, which at band 1 are 1.00 and 0.75 and are not the same run. They also differ in two
other observable ways — steady carries a 0.85 score multiplier and VoiceOver does not, and both
suppress the Tempo sample (§11.9) but for different reasons. Three cases, one `switch`, and a
`DECISIONS.md` entry naming the conflict so the next reader does not "simplify" it back.

### The auto-pause is a predicate here and a policy at the view edge

`shouldAutoPause(frameOverrun:)` is a pure comparison and belongs here beside the schedule it
protects. **Measuring** the overrun is not core — it needs a display link — so T02's `SieveRoundView`
computes the overrun from consecutive presentation timestamps and calls this. Keep the threshold as a
`static let` so a future change is one edit and one test, and note in the doc comment that §9.8's
100 ms is the *miss over budget*, not the frame time: at 60 Hz a frame that takes 116 ms has
overrun by 100 ms and does **not** pause; 117 ms does.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveScheduleTests` green — all 17 tests.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/SieveSchedule.swift` returns nothing.
- [ ] `grep -nE "0\.667|340|132|88\b" HunchCore/Sources/Rounds/SieveSchedule.swift` returns nothing — every geometric constant arrives through `C.GateBand`.
- [ ] `grep -rn "Date\(\)\|ContinuousClock\|SuspendingClock\|TimeInterval\|Instant" HunchCore/Sources/Rounds/SieveSchedule.swift` returns nothing.
- [ ] `Scripts/check-boundary.sh HunchCore/Sources/Rounds/SieveSchedule.swift` reports the file as core.
- [ ] `Band.sieveServable.count == 6` and the band-7/8 cases of the row switch `preconditionFailure` with a §9.3 citation in the message.
- [ ] `DECISIONS.md` records the three-case `SievePacing` with the two observable differences that force it.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. Watch for one specific "simplification" it may propose: collapsing `.steady` and `.stepped`. Reject it and point at the `DECISIONS.md` entry.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E14/T01: SieveSchedule — the speed curve, ramped in glyph index"`

## Out of scope

- The gate band's drawing, hit testing, states and the `±44 pt` rule — **T02**.
- The rest of `C.GateBand` (`centreY`, `actionableRadius`, `laneGlyph`, `hairline`, `sumpDissolve`, `seedHold`) — **T02**, which extends this same namespace rather than opening a second one.
- The stream's contents — which glyph arrives at index `n` — **T03**.
- The score multiplier that `.steady` carries and the Tempo suppression both pacings cause — **T09**.
- The Reduce-Motion presentation flag and the parity assertion — **T10**, which puts the flag on `SieveConveyor` and not here.
- §10.3's serving policy, which chooses the band and the tempo step — **E11·T03**; this task consumes them.
