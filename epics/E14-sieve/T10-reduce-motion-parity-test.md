# T10 — The Reduce-Motion parity test

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | Reduce Motion table (ART — the SIEVE row) · Mode invariants (VERIFICATION — the preview + window parity assertion) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/reduce-motion.md` is the whole task: §1's three things a substitution may never do, §2's complete table with the SIEVE row, §4's argument for why the lane keeps four stations, §5's list of timings that do not change, §6's resolve-once-at-the-token-seam pattern with the three wrong forms, and §7's two tests — one of which *is* this task's deliverable, written verbatim in the skill. It also states the rule that decides everything here: **replace the animation, keep the information.** |
| `hunch-swift-testing` | The parity assertion is a triple parameterisation (band × tempo step × every `n`) that has to fit inside a 10-second budget, and the skill owns the budget, the tag pair and the ruling that a test needing a view means the value is in the wrong module. It also owns the `tests.json` obligation, and §13.12 gate 9 has a matching entry that must not be weakened. |

`hunch-bench-instruments` is cited rather than loaded: `gate-band.md` §6 is the component-side
statement of the same substitution and §8's *"collapsing the lane to one slot"* is the named defect.
Two minutes of reading, not a skill load.

## Objective

At the end of this task SIEVE's Reduce Motion substitution is implemented and, more importantly,
**proved**: the lane keeps its four stations and a glyph crossfades lip → lane → gate → sump at the
identical cadence, and a shipped test asserts that `preview(n) + window(n)` and the station occupied
at time `t` are identical with Reduce Motion on and off, for every band 1–6 × tempo step 0–3 × every
`n`. That test is the automated half of §13.12 gate 9 and it is what makes the substitution
trustworthy rather than merely intended.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.8 | *"Reduce Motion: the conveyor becomes a step — glyphs crossfade lip → lane → gate → sump at the identical cadence, and the gate dwell is byte-identical, so the hit window is unchanged. Motion is removed; timing is not."* |
| `GAME_DESIGN.md` | §13.7.4 | the SIEVE row and the paragraph beneath it: motion **is** the mechanic, so it is replaced rather than removed; the preview count is unchanged at every band and tempo step; scoring and difficulty are unchanged; and the shipped test named in the last sentence |
| `GAME_DESIGN.md` | §13.12 gate 9 | *"Reduce Motion on: nothing translates, scales or rotates anywhere, including SIEVE… Automated alongside it: `preview(n) + window(n)` and the station occupied at time `t` are identical with Reduce Motion on and off, across bands 1–6 × tempo steps 0–3."* Each gate line has a matching `tests.json` entry |
| `GAME_DESIGN.md` | §9.3 | the worst-case budget the argument rests on: `preview + window` = 0.87 s + 0.226 s = 1.10 s at band 6, tempo step 3 |
| `.claude/skills/hunch-motion-and-feedback/references/reduce-motion.md` | §1, §2, §4, §5, §6, §7, §9 | the complete substitution table, the SIEVE ruling, the invariant timings, the `env.animation(_:reducedTo:)` seam, the two tests, and the nine wrong things |
| `.claude/skills/hunch-bench-instruments/references/gate-band.md` | §6, §8 | *"write it before the substitution, not after"*; and the one-slot collapse as a named defect |
| `ios-swift-guide/06-TESTING.md` | T30, T22 | tag on both axes; keep the Cartesian product from exploding into runner nodes |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SieveReduceMotionParityTests.swift`:

```swift
import Testing
import Glyphs
import Rounds
import Tokens
import HunchTestSupport

@Suite("Reduce Motion changes no SIEVE timing — §13.7.4, §13.12 gate 9",
       .tags(.unit, .presubmission))
struct SieveReduceMotionParityTests {

    /// §13.12 gate 9's automated half. Parameterised over band × tempo step — 24 cases — with the
    /// `n` loop inside, which is `06 T21`'s sanctioned shape when the alternative is 1,700 runner nodes.
    @Test("preview(n) + window(n) and the station at time t are identical in both presentations",
          arguments: Band.sieveServable, 0...3)
    func timingIsInvariantUnderReduceMotion(_ band: Band, _ tempoStep: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: tempoStep, pacing: .ramped)
        let travelling = SieveConveyor(schedule: schedule, presentation: .travelling)
        let crossfading = SieveConveyor(schedule: schedule, presentation: .crossfading)

        for n in 0..<schedule.glyphCount {
            #expect(travelling.window(of: n) == crossfading.window(of: n))
            #expect(travelling.preview(of: n) == crossfading.preview(of: n))
            #expect(travelling.actionableSpan(of: n) == crossfading.actionableSpan(of: n))

            let arrival = schedule.arrival(at: n)
            #expect(travelling.station(of: n, at: arrival) == crossfading.station(of: n, at: arrival))
        }
    }

    @Test("the station occupied at time t is identical, sampled across the whole run",
          arguments: Band.sieveServable, 0...3)
    func stationAtEveryInstantIsInvariant(_ band: Band, _ tempoStep: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: tempoStep, pacing: .ramped)
        let travelling = SieveConveyor(schedule: schedule, presentation: .travelling)
        let crossfading = SieveConveyor(schedule: schedule, presentation: .crossfading)

        let tick = Duration.milliseconds(8)          // ~120 Hz
        var t = Duration.zero
        while t < schedule.duration {
            #expect(travelling.occupancy(at: t) == crossfading.occupancy(at: t))
            #expect(travelling.previewCount(at: t) == crossfading.previewCount(at: t))
            t += tick
        }
    }

    @Test("the lane keeps FOUR stations under Reduce Motion — it is not collapsed to one slot")
    func fourStationsSurvive() {
        let schedule = SieveSchedule(band: .guarded, tempoStep: 3, pacing: .ramped)
        let crossfading = SieveConveyor(schedule: schedule, presentation: .crossfading)
        let stations = Set((0..<schedule.glyphCount).flatMap { n in
            stride(from: 0.0, to: schedule.duration.seconds, by: 0.01)
                .map { crossfading.station(of: n, at: .seconds($0)) }
        })
        #expect(stations.isSuperset(of: [.lip, .lane, .gate, .sump]))
    }

    @Test("the preview is not deleted — worst-case decision time stays at 1.10 s, not one inter-glyph period")
    func previewIsNotDeleted() {
        let schedule = SieveSchedule(band: .guarded, tempoStep: 3, pacing: .ramped)
        let crossfading = SieveConveyor(schedule: schedule, presentation: .crossfading)
        let n = schedule.glyphCount - 1
        let total = crossfading.preview(of: n).seconds + crossfading.window(of: n).seconds
        #expect(isApproximatelyEqual(total, 1.10, absoluteTolerance: 0.012))
        // A one-slot substitution would leave roughly one inter-glyph period, ≈ 0.34 s.
        #expect(total > 0.9)
    }

    @Test("the presentation flag reaches no timing expression — construct-and-diff over every accessor",
          arguments: Band.sieveServable)
    func presentationIsInertInTheCore(_ band: Band) {
        for tempoStep in 0...3 {
            let schedule = SieveSchedule(band: band, tempoStep: tempoStep, pacing: .ramped)
            let a = SieveConveyor(schedule: schedule, presentation: .travelling)
            let b = SieveConveyor(schedule: schedule, presentation: .crossfading)
            for n in 0..<schedule.glyphCount {
                #expect(a.centreY(of: n, at: schedule.arrival(at: n))
                        == b.centreY(of: n, at: schedule.arrival(at: n)))
                #expect(a.glyphBound(byTapAt: schedule.arrival(at: n))
                        == b.glyphBound(byTapAt: schedule.arrival(at: n)))
            }
        }
    }

    @Test("scoring and difficulty are unchanged by the presentation")
    func scoringIsUnchanged() {
        let tally = SieveTally.flawless(glyphCount: 76)
        let a = SieveScore(tally: tally, glyphCount: 76, resolvedGlyphs: 76, ending: .sieved)
        let b = SieveScore(tally: tally, glyphCount: 76, resolvedGlyphs: 76, ending: .sieved)
        #expect(a == b)
        #expect(SieveDifficulty.serving(targetDelta: 0.525, lawDifficulty: 0.525)
                == SieveDifficulty.serving(targetDelta: 0.525, lawDifficulty: 0.525))
    }

    @Test("the pause freeze is instantaneous in both presentations — the mechanic is not animated in")
    func freezeIsInstantInBoth() {
        #expect(SieveMotion.freezeDuration(reduceMotion: true) == .zero)
        #expect(SieveMotion.freezeDuration(reduceMotion: false) == .zero)
    }
}
```

And, in the app-side suite, the row-existence half —
`Modules/Tests/LoomFeatureTests/SieveMotionRowTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI
@testable import LoomFeature

@Suite("SIEVE's Reduce Motion row — §13.7.4", .tags(.unit, .presubmission))
@MainActor
struct SieveMotionRowTests {

    @Test("SIEVE glyph travel has a substitution row, and it is a replacement rather than a removal")
    func sieveRowExists() {
        let row = MotionRow.sieveGlyphTravel
        #expect(row.substitution != nil)
        #expect(row.substitution?.transform == .none)          // no translate, scale or rotate
        #expect(row.substitution?.kind == .replaced)           // not .removed, not .shortened
    }

    @Test("every animation on the SIEVE surface declares a row", arguments: SieveMotionRow.allCases)
    func everySieveAnimationHasARow(_ row: SieveMotionRow) {
        #expect(MotionRow(row).substitution != nil)
    }

    @Test("nothing on the SIEVE surface translates, scales or rotates under Reduce Motion",
          arguments: SieveMotionRow.allCases)
    func nothingMovesUnderReduceMotion(_ row: SieveMotionRow) {
        #expect(MotionRow(row).substitution?.transform == .none)
    }

    @Test("the substitution is resolved once at the token seam, not with an if at each call site")
    func oneSeam() {
        #expect(SieveRoundView.reduceMotionBranchCount == 0)   // no inline `if env.isReduceMotion…`
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SieveReduceMotionParityTests`

Expect missing `SieveConveyor.window(of:)`, `.preview(of:)`, `.occupancy(at:)`, `SieveMotion`,
`MotionRow.sieveGlyphTravel` and `SieveMotionRow`. **Then deliberately break it once:** make
`SieveConveyor.previewCount(at:)` return `1` when `presentation == .crossfading`, confirm
`stationAtEveryInstantIsInvariant` and `previewIsNotDeleted` both fail, and revert. A parity test
that has never failed is a parity test nobody has calibrated.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Rounds/SieveConveyor.swift` — `window(of:)`, `preview(of:)`, `occupancy(at:)` as conveyor-level accessors that forward to the schedule |
| create | `Modules/Sources/HunchUI/SieveLaneView.swift` — the four stations, translating under `.travelling` and crossfading under `.crossfading` |
| modify | `Modules/Sources/HunchUI/Motion.swift` — nothing new; SIEVE uses the existing `env.animation(_:reducedTo:)` seam |
| create | `Modules/Sources/LoomFeature/SieveMotionRow.swift` — the SIEVE rows of §13.7.4, enumerated |
| modify | `Modules/Sources/HunchUI/MotionRow.swift` — add `sieveGlyphTravel` with `kind: .replaced` |
| modify | `Modules/Sources/LoomFeature/SieveRoundView.swift` — read `env.isReduceMotionEnabled` **once** to pick the presentation, and pass it down |
| create | `HunchCore/Tests/RoundsTests/SieveReduceMotionParityTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/SieveMotionRowTests.swift` |
| modify | `tests.json` — the §13.12 gate 9 entry, plus four-stations, preview-not-deleted, presentation-is-inert |
| modify | `DECISIONS.md` — the `SieveConveyor`-carries-the-flag ruling, seeded in T02 and completed here |

## Implementation notes

### The substitution, in one sentence and four stations

Under `.crossfading` a glyph does not translate. It **appears** at the lip, crossfades to the lane
slot, crossfades to the gate slot, crossfades to the sump slot, and dissolves — at exactly the times
`SieveSchedule` says it would have arrived at each. The four station positions are the four region
centres from `C.GateBand`; the glyph is drawn at one of them and never between them.

What that preserves, and why each matters:

- **The gate dwell**, so the hit window is unchanged. This is the scored quantity.
- **The preview count** — how many glyphs are visible above the gate at once. §9.3 budgets worst-case
  decision time as `preview + window` = 1.10 s. Collapsing the lane to a single centre slot leaves
  roughly one inter-glyph period (≈ 0.34 s at band 6, `s = 3`), *"which would cut the hardest
  decision in the game to a third of its length for exactly the players who asked for less motion."*
  `previewIsNotDeleted` is that sentence made executable.
- **The cadence**, so `sieve.tick` still lands on arrival and the run still takes 41–46 s.

### Why the flag lives on the conveyor and the test is not tautological

`reduce-motion.md` §7 sketches the assertion as
`SieveSchedule(band:tempoStep:isReduceMotionEnabled:)`. Taken literally, `SieveSchedule` has no
presentation concept, so the parameter would be ignored and the test would assert only that it is
ignored. T02 put the flag on `SieveConveyor` — the type that *decides* stations and preview counts,
and therefore the type where a wrong implementation could actually diverge. The assertions are the
skill's, verbatim in effect; only the constructor moved. `presentationIsInertInTheCore` closes the
loop by diffing every geometric accessor as well as the two timing ones.

`stationAtEveryInstantIsInvariant` samples at ~120 Hz across the full run rather than only at arrival
instants, because the interesting failure is a station that is *right at the boundaries and wrong in
between* — which is exactly what a naive crossfade implementation that snaps early produces.

### The one seam, and the three wrong forms

Resolve the substitution once, at the token seam:

```swift
// Modules/Sources/LoomFeature/SieveRoundView.swift
private var presentation: SievePresentation {
    env.isReduceMotionEnabled ? .crossfading : .travelling
}
```

That is the only read of `isReduceMotionEnabled` on the whole surface, and `oneSeam` asserts it by
counting inline branches. `reduce-motion.md` §6 lists the three wrong forms and the third is this
exact component:

```swift
// WRONG — collapses SIEVE's lane to one slot. Deletes the preview and
// cuts worst-case decision time from 1.10 s to ≈ 0.34 s.
GlyphView(current).position(gateCentre)
```

Two more that would pass a careless review: shortening the travel animation instead of replacing it
(*"a 40 ms `matchedGeometryEffect` is still a translation and a scale"*), and keeping the geometry
match with a near-zero duration. Neither survives `nothingMovesUnderReduceMotion`, which asserts
`transform == .none` rather than a duration.

### The rows this surface owns

`SieveMotionRow` enumerates every animation on the SIEVE surface so the row-existence test is
exhaustive rather than aspirational:

| Row | Normal | Reduce Motion |
|---|---|---|
| glyph travel | translation lip → sump | **replaced** — four-station crossfade at the identical cadence (§13.7.4) |
| tap response | `dur.tap` ring, no scale, no shudder (§13.7.2) | the ring crossfades; **the timing is unchanged** — it is inside the 120 ms micro budget either way |
| sump dissolve | `C.GateBand.sumpDissolve` | crossfade at the same duration |
| pause freeze | instantaneous | instantaneous — `freezeIsInstantInBoth` |
| the run-up's three retracting arcs | sweep | the three states crossfade; the cadence is unchanged (T07) |
| `fouling` freeze | 400 ms hold | unchanged — it is a hold, not a motion |

Every one of those goes into §13.7.4's table via `MotionRow`, which E09·T12 already established; this
task adds SIEVE's rows to the existing enum rather than starting a second table. `reduce-motion.md`
§9's *"writing a second substitution table in a component's reference file"* is the named defect.

### Budget

The parity suite is 24 parameterised cases, each looping 60–80 glyph indices, plus 24 cases sampling
a ~45 s run at 8 ms. That second one is ~5,600 iterations per case, ~135,000 total, each a handful of
`Double` operations — well under 100 ms in aggregate. If it measures over ~200 ms, reduce the sampling
tick to 16 ms and add exact checks at every station boundary; do **not** reduce the band × tempo-step
matrix, because §13.12 gate 9 names it explicitly.

### `tests.json` and the gate

§13.12 says *"each line is a gate before any release build and has a matching entry in
`tests.json`."* Gate 9's entry gets the automated half's test name and pass condition; the manual
half (*"nothing translates, scales or rotates anywhere… verified by hand"*) stays a manual row owned
by **E19·T09**, and this task's entry must not claim it. Never weaken or delete the entry to reach
green.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveReduceMotionParityTests` green — all seven tests across all 24 (band × tempo step) cases.
- [ ] `swift test --package-path Modules --filter SieveMotionRowTests` green.
- [ ] The parity test has been **demonstrated to fail** by temporarily making `previewCount(at:)` presentation-dependent, and the failure output names the band and tempo step.
- [ ] `grep -c "isReduceMotionEnabled" Modules/Sources/LoomFeature/SieveRoundView.swift` returns 1.
- [ ] `grep -rn "matchedGeometryEffect\|\.position(" Modules/Sources/HunchUI/SieveLaneView.swift` shows no geometry match and no absolute positioning under `.crossfading`.
- [ ] `MotionRow.sieveGlyphTravel.substitution?.kind == .replaced` — not `.removed`, not `.shortened`.
- [ ] Every `SieveMotionRow` case has a row in §13.7.4's table via `MotionRow`, and no second table exists anywhere under `Modules/Sources`.
- [ ] `tests.json` carries the §13.12 gate 9 automated entry plus the three supporting entries, and the manual half is attributed to E19·T09.
- [ ] The fast suite is still under 10 s, and this suite's own contribution is recorded in `PROGRESS.md`.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes removing `SievePresentation` from `SieveConveyor` on the grounds that it is unused, decline: it is unused *by design*, and its inertness is the invariant.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically whether any drawing on the SIEVE surface translates, scales or rotates under `.crossfading`.
4. Commit: `git commit -m "E14/T10: SIEVE's Reduce Motion substitution and the preview/window parity test"`

## Out of scope

- The rest of §13.7.4's substitution table — **E09·T12**. This task adds SIEVE's rows to the existing `MotionRow`.
- Gate 9's **manual** half, the accessibility audit and the AX5 screenshots — **E19·T09/T11**.
- VoiceOver's step pacing, which is an independent axis and can be on at the same time — **T09** (the pacing) and **E19·T05** (the experience).
- The tap response's own timing and cue — **T02** and **E20·T03**.
- `env.isShaderTimeFrozen` and the grain shader — **E03·T03 / E20·T07**. Reduce Motion freezes `t`; Reduce Transparency, High Contrast and Low Power set `amt = 0`, and they are different predicates.
