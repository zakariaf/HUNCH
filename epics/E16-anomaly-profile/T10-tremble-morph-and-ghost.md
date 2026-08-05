# T10 — Tremble, morph and the 90-day ghost

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T09 |
| **Delivers** | Tremble and morph (PROFILE) · The 90-day ghost (PROFILE, P2) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `C.Profile.morphSpring` is the **only** spring in the app outside the six token easings, and the tokens skill owns why it is declared rather than borrowed — anyone who "fixes" it to `Easing.settle` destroys the stagger. It also owns the durations the Reduce Motion substitution cites. |
| `hunch-motion-and-feedback` | Owns what happens when: `references/reduce-motion.md` row *Profile morph* and its §8 conflict ruling (§13.7.4's 240 ms crossfade wins over §11.10's 0.35 s), and the rule that no mark animates itself — the host owns the animation and therefore owns the substitution. |
| `hunch-chrome-and-meta` | `references/profile-contour.md` §5–§7 is the spec: the tremble's deterministic `SplitMix64` noise, the `TimelineView(.animation(minimumInterval:))` rather than a `Timer`, the `phaseAnimator` over a `MorphPhase` enum, and the ghost's twelve-per-cent dashed unlabelled form. |

## Objective

At the end of this task confidence renders as *steadiness*: each vertex carries a deterministic
0.6 Hz noise whose amplitude falls to zero as `n` rises to 24, so an unformed portrait trembles and a
mature one is still. Entering the Profile screen runs one 2.4 s staggered spring — and it runs
nowhere else, never during play and never at round end. And the portrait as it stood ninety days ago
is drawn behind at 12 % opacity, dashed and unlabelled, showing change of shape and nothing else.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.10 | `A = R0 · 0.05 · (1 − min(1, nᵢ/24))` at 0.6 Hz value noise; the Reduce Motion dash substitution whose gap scales with `A`; the 2.4 s `phaseAnimator` with its hold, its `i · 0.06 s` stagger and its response/damping; the ghost's opacity, weight, dash and unlabelled-ness |
| `GAME_DESIGN.md` | §11.10 | the Day 1 / Week 1 / Month 3 table — 4.8 pt at day 1, ~1 pt at n ≈ 25, zero at the cap |
| `GAME_DESIGN.md` | §11.11 P5 | the ghost is the **only** temporal comparison in the app; no time series, no sparkline, no second ghost, no labelled ghost |
| `GAME_DESIGN.md` | §11.11 P6 | the portrait is never shown at round end and never animates during play |
| `GAME_DESIGN.md` | §11.13 | `profile.json` carries `ghost: [Double]`, `ghostTakenAt` and `lastRenderedRadii` — the last is what the morph's hold beat holds |
| `GAME_DESIGN.md` | §13.7.4 | the Reduce Motion substitution table's Profile row, which **wins** over §11.10's 0.35 s |
| `hunch-motion-and-feedback` | `references/reduce-motion.md` §2, §8 | the row, the `dur.reduceMotionMorph` token, and the conflict ruling |
| `hunch-chrome-and-meta` | `references/profile-contour.md` §5, §6, §7, §10, §12 | the noise function, the morph phases, the ghost, the environment table, and the ways to get it wrong |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files. The noise and the ghost's staleness rule are pure
arithmetic and belong in the fast suite.

`HunchCore/Tests/ArchiveTests/ProfileTrembleTests.swift`:

```swift
import Foundation
import Testing
import Archive
import Tokens
import HunchTestSupport

@Suite("Tremble and the ghost — §11.10", .tags(.unit, .presubmission))
struct ProfileTrembleTests {

    private let epoch = Date(timeIntervalSince1970: 1_785_369_600)

    // MARK: - amplitude

    @Test("amplitude is R0 · 0.05 · (1 − min(1, n/24)) and reaches §11.10's day-1 figure")
    func amplitudeAtDayOne() {
        #expect(isApproximatelyEqual(ProfileTremble.amplitude(n: 0),
                                     C.Profile.r0 * 0.05, absoluteTolerance: 1e-9))
    }

    @Test("amplitude falls monotonically to exactly zero at n = 24 and stays there",
          arguments: [0.0, 6, 12, 18, 24, 40, 60])
    func amplitudeFallsToZero(_ n: Double) {
        let a = ProfileTremble.amplitude(n: n)
        #expect(a >= 0)
        #expect(a <= ProfileTremble.amplitude(n: 0) + 1e-12)
        if n >= 24 { #expect(isApproximatelyEqual(a, 0, absoluteTolerance: 1e-12)) }
    }

    @Test("amplitude is strictly decreasing below the cap")
    func amplitudeIsStrictlyDecreasing() {
        let samples = stride(from: 0.0, to: 24.0, by: 1.0).map { ProfileTremble.amplitude(n: $0) }
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0.1 < $0.0 })
    }

    // MARK: - determinism

    /// §11.10's noise must be reproducible: two devices at the same `t` draw the same shape, and the
    /// snapshot gallery has to be stable. `Double.random` here is a determinism violation.
    @Test("the noise is a pure function of (t, vertex) and repeats exactly")
    func noiseIsDeterministic() {
        for vertex in 0..<5 {
            #expect(isApproximatelyEqual(ProfileTremble.noise(t: 12.5, vertex: vertex),
                                         ProfileTremble.noise(t: 12.5, vertex: vertex),
                                         absoluteTolerance: 0))
        }
    }

    @Test("the noise stays in [−1, +1] over a long sweep", arguments: 0..<5)
    func noiseIsBounded(_ vertex: Int) {
        let samples = stride(from: 0.0, through: 200.0, by: 0.017).map {
            ProfileTremble.noise(t: $0, vertex: vertex)
        }
        #expect(samples.allSatisfy { $0 >= -1 && $0 <= 1 })
        #expect(samples.contains { $0 < -0.5 } && samples.contains { $0 > 0.5 })
    }

    @Test("the five vertices are decorrelated — they do not tremble in lockstep")
    func verticesAreDecorrelated() {
        let a = stride(from: 0.0, through: 60.0, by: 0.05).map { ProfileTremble.noise(t: $0, vertex: 0) }
        let b = stride(from: 0.0, through: 60.0, by: 0.05).map { ProfileTremble.noise(t: $0, vertex: 3) }
        #expect(zip(a, b).contains { abs($0.0 - $0.1) > 0.5 })
    }

    @Test("the noise is continuous — no step between adjacent sample instants")
    func noiseIsContinuous() {
        let samples = stride(from: 10.0, through: 12.0, by: 0.005).map {
            ProfileTremble.noise(t: $0, vertex: 2)
        }
        #expect(zip(samples, samples.dropFirst()).allSatisfy { abs($0.1 - $0.0) < 0.05 })
    }

    @Test("a mature portrait is perfectly still — trembled radii equal normalised radii")
    func matureIsStill() {
        var p = Profile()
        for axis in ProfileAxis.allCases { p[axis] = Axis(value: 0.6, n: 60, lastSampleAt: epoch) }
        #expect(zip(p.trembledRadii(at: 7.3), p.normalisedRadii())
            .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-12) })
    }

    // MARK: - the ghost

    @Test("no ghost exists until 90 days of history exist")
    func noGhostBeforeNinetyDays() {
        var p = Profile()
        p.captureGhostIfDue(asOf: epoch)
        #expect(p.ghost == nil)
        #expect(p.ghostTakenAt == nil)
    }

    @Test("the ghost is captured once and re-captured only after another 90 days")
    func ghostRefreshesEveryNinetyDays() {
        var p = Profile()
        for axis in ProfileAxis.allCases { p[axis] = Axis(value: 0.4, n: 30, lastSampleAt: epoch) }
        p.beginHistory(at: epoch)

        p.captureGhostIfDue(asOf: epoch.addingTimeInterval(90 * 86_400))
        let first = try! #require(p.ghost)
        #expect(p.ghostTakenAt == epoch.addingTimeInterval(90 * 86_400))

        for axis in ProfileAxis.allCases { p[axis] = Axis(value: 0.9, n: 60, lastSampleAt: epoch) }
        p.captureGhostIfDue(asOf: epoch.addingTimeInterval(120 * 86_400))
        #expect(p.ghost == first)                         // not yet due

        p.captureGhostIfDue(asOf: epoch.addingTimeInterval(181 * 86_400))
        #expect(p.ghost != first)
    }

    /// §11.11 P5: because radii are mean-normalised, the ghost can only show CHANGE OF SHAPE.
    @Test("a ghost of a uniformly lower portrait is pixel-identical to the current contour")
    func aUniformlyLowerGhostIsInvisible() {
        var p = Profile()
        for (i, axis) in ProfileAxis.allCases.enumerated() {
            p[axis] = Axis(value: [0.2, 0.5, 0.3, 0.8, 0.4][i], n: 60, lastSampleAt: epoch)
        }
        p.ghost = [0.1, 0.25, 0.15, 0.4, 0.2]             // exactly half, every axis
        p.ghostTakenAt = epoch
        #expect(zip(p.ghostRadii()!, p.normalisedRadii())
            .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-9) })
    }

    @Test("Reset Profile clears the ghost, and a nil ghost draws nothing")
    func resetClearsTheGhost() {
        let p = Profile()
        #expect(p.ghost == nil)
        #expect(p.ghostRadii() == nil)
    }
}
```

`Modules/Tests/MetaFeatureTests/ProfileMorphTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import Archive
import Tokens
import MetaFeature
import ModulesTestSupport

@Suite("The morph — §11.10, on entering the screen and nowhere else", .tags(.unit, .presubmission))
@MainActor
struct ProfileMorphTests {

    @Test("the morph runs three phases in order, over C.Profile.morphDuration")
    func threePhasesInOrder() {
        #expect(MorphPhase.allCases == [.hold, .spring, .settle])
        #expect(isApproximatelyEqual(MorphPhase.totalDuration, C.Profile.morphDuration,
                                     absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(MorphPhase.hold.duration, C.Profile.morphHold,
                                     absoluteTolerance: 1e-12))
    }

    @Test("each vertex is staggered by i · C.Profile.morphStagger", arguments: 0..<5)
    func staggerPerVertex(_ i: Int) {
        #expect(isApproximatelyEqual(MorphPhase.delay(forVertex: i),
                                     Double(i) * C.Profile.morphStagger, absoluteTolerance: 1e-12))
    }

    @Test("the hold beat holds lastRenderedRadii, not the new shape")
    func holdBeatHoldsThePreviousShape() {
        let model = ProfileScreen(profile: .previewWithLastRendered([50, 60, 70, 60, 50]))
        #expect(model.radii(inPhase: .hold) == [50, 60, 70, 60, 50])
        #expect(model.radii(inPhase: .settle) != [50, 60, 70, 60, 50])
    }

    @Test("with no lastRenderedRadii the hold beat is skipped, not held at zero")
    func firstEverEntrySkipsTheHold() {
        let model = ProfileScreen(profile: .preview)               // lastRenderedRadii == nil
        #expect(model.startingPhase == .spring)
    }

    @Test("lastRenderedRadii is written when the screen is left, so the next entry has a shape to hold")
    func lastRenderedRadiiIsPersistedOnExit() {
        let model = ProfileScreen(profile: .preview)
        model.onDisappear()
        #expect(model.profile.lastRenderedRadii?.count == 5)
    }

    /// §11.11 P6, and §11.10: "The portrait never animates during play."
    @Test("the morph is driven by screen entry and by nothing else")
    func morphIsDrivenByEntryOnly() {
        let model = ProfileScreen(profile: .preview)
        model.onAppear()
        #expect(model.morphRuns == 1)
        model.profileDidChange()                    // a round settled elsewhere
        #expect(model.morphRuns == 1)
    }

    // MARK: - Reduce Motion

    @Test("under Reduce Motion the morph is a crossfade at dur.reduceMotionMorph, not a spring")
    func reduceMotionSubstitutes() {
        let plan = ProfileScreen.motionPlan(in: .preview(reduceMotion: true))
        #expect(plan.usesSpring == false)
        #expect(isApproximatelyEqual(plan.duration, Dur.reduceMotionMorph, absoluteTolerance: 1e-12))
    }

    @Test("under Reduce Motion the tremble becomes a static dash whose gap scales with A")
    func trembleBecomesAStaticDash() {
        let low = ProfileScreen.contourDash(amplitude: ProfileTremble.amplitude(n: 0),
                                            in: .preview(reduceMotion: true))
        let high = ProfileScreen.contourDash(amplitude: ProfileTremble.amplitude(n: 20),
                                             in: .preview(reduceMotion: true))
        #expect(low!.gap > high!.gap)
        #expect(low!.phase == 0 && high!.phase == 0)          // a moving phase is an animation
        #expect(ProfileScreen.contourDash(amplitude: 0, in: .preview(reduceMotion: true)) == nil)
    }

    @Test("Low Power Mode stops the tremble exactly as Reduce Motion does — one rendering, not two")
    func lowPowerMatchesReduceMotion() {
        let rm = ProfileScreen.contourDash(amplitude: 3.0, in: .preview(reduceMotion: true))
        let lp = ProfileScreen.contourDash(amplitude: 3.0, in: .preview(lowPower: true))
        #expect(rm == lp)
    }

    @Test("the tremble is driven by a TimelineView, never a Timer or repeatForever")
    func trembleUsesATimelineView() {
        #expect(ProfileScreen.trembleDriver == .timelineView(minimumInterval: 1.0 / 30))
    }

    // MARK: - the ghost

    @Test("the ghost draws behind, dashed, at C.Profile.ghostInk, and carries no label")
    func ghostIsUnlabelled() {
        let elements = ProfileContour.accessibilityElements(for: .previewWithGhost)
        #expect(elements.first { $0.kind == .ghost }?.isHidden == true)
        #expect(ProfileContour.drawnElements(for: .previewWithGhost).contains(.ghost))
        #expect(!ProfileContour.drawnElements(for: .previewWithGhost).contains(.numeral))
    }

    @Test("there is exactly one ghost and no time series anywhere on the screen")
    func exactlyOneGhost() {
        let drawn = ProfileContour.drawnElements(for: .previewWithGhost)
        #expect(drawn.filter { $0 == .ghost }.count == 1)
        #expect(!drawn.contains(.sparkline))
        #expect(!drawn.contains(.timeSeries))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ProfileTrembleTests`
and `swift test --package-path Modules --filter ProfileMorphTests`. Missing symbols. Watch
`noiseIsDeterministic` in particular: a `Double.random` implementation makes it fail, which is the
point.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/ProfileTremble.swift` — `amplitude(n:)`, `noise(t:vertex:)`, `Profile.trembledRadii(at:)` |
| modify | `HunchCore/Sources/Archive/Profile.swift` — `captureGhostIfDue(asOf:)`, `beginHistory(at:)`, `ghostRadii()` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `morphDuration`, `morphHold`, `morphStagger`, `morphSpring`, `trembleFraction`, `trembleHz`, `trembleConfidenceCap`, `ghostInk`, `ghostWeight`, each with its §11.10 citation |
| create | `Modules/Sources/MetaFeature/ProfileMorph.swift` — `MorphPhase` and the `phaseAnimator` |
| modify | `Modules/Sources/MetaFeature/ProfileContour.swift` — the `TimelineView`, the ghost layer, the Reduce Motion dash |
| create | `Modules/Sources/MetaFeature/ProfileScreen.swift` — `@MainActor @Observable`, entry/exit and the motion plan |
| create | `HunchCore/Tests/ArchiveTests/ProfileTrembleTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/ProfileMorphTests.swift` |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — `captureGhostIfDue(asOf:)` at session start, beside T06's confidence decay |
| modify | `tests.json` — seven entries |

## Implementation notes

### Tremble — confidence as steadiness, never as size

```
Aᵢ = R0 · C.Profile.trembleFraction · (1 − min(1, nᵢ / C.Profile.trembleConfidenceCap))
rᵢ' = rᵢ + Aᵢ · noise(t, i)
```

At day 1 every vertex trembles at `0.05 · R0`; at `n ≥ 24` the amplitude is exactly zero and the
contour is still. Confidence therefore reads as *steadiness*, which cannot be mistaken for *more* —
which is the entire reason it is not drawn as size.

**The noise must be deterministic.** `profile-contour.md` §5 gives the shape: `SplitMix64` from
`HunchCore/LawGeneration`, seeded per vertex index, sampled at `floor(t · trembleHz)` and
smoothstep-interpolated between the two neighbouring samples. Two devices at the same `t` must draw
the same shape and the DEBUG snapshot gallery must be reproducible; `Double.random` in a draw call
breaks both. This is also why `noise` is core: it is a pure function and it is tested in the fast
suite.

Drive it with `TimelineView(.animation(minimumInterval: 1.0 / 30))`, **never** a `Timer` and never
`.repeatForever`. A 0.6 Hz signal does not need 120 Hz, and a `TimelineView` stops when the view
leaves the screen — which is what stops the portrait costing battery on a screen nobody is looking at.

**Tremble stops under Reduce Motion and under Low Power Mode**, with the *same* static-dash
substitution in both, so no third rendering exists. Reduce Motion is §11.10's own substitution; Low
Power is `hunch-chrome-and-meta`'s ruling, and the reason is direct — a continuously redrawing
`TimelineView` is exactly the work Low Power Mode asks us not to do. The dash's **gap** scales with
`A` and its **phase is constant**: a time-varying `dashPhase` is an animation by another name.

### The morph

One `phaseAnimator` over a `MorphPhase` enum, for the same reason §13.7.1's reveal is one — so the
beats cannot drift apart:

```
hold    the previous session's contour, for C.Profile.morphHold
spring  each vertex to its new radius, staggered i · C.Profile.morphStagger, under C.Profile.morphSpring
settle  the contour settles; tremble amplitude updates
```

`lastRenderedRadii` is persisted in `profile.json` (§11.13) **precisely so the hold beat has a
previous shape to hold**. Write it on `onDisappear`; on the very first entry it is `nil` and the hold
beat is skipped rather than held at zero — `firstEverEntrySkipsTheHold` is the test, because holding
five zeros for 0.4 s and then springing outward is a "level up" animation and this screen must never
have one.

`C.Profile.morphSpring` carries §11.10's own response and damping and is **not** `Easing.settle` or
any other L1 spring. It is the only spring in the app outside the six token easings, because it is a
staggered per-vertex morph rather than a UI transition. Declare it in `C.swift` **with that sentence
attached**, or someone will "fix" it and the stagger will lose its shape.

**On entering the Profile screen only.** Never during play, never at round end (§11.11 P6).
`morphIsDrivenByEntryOnly` asserts that a `Profile` mutation from a settled round does not start it —
which it cannot, because nothing observes the profile outside this screen, and T08's
`ProfileVisibilityTests` is what keeps that true.

Under Reduce Motion the morph is *"new shape instantly; `dur.reduceMotionMorph` crossfade"*. §11.10
says 0.35 s and §13.7.4 says 240 ms; **§13.7.4 wins** — `reduce-motion.md` §8 rules it, because
§13.7.4 opens by declaring that every animation in the app appears in it, which is a normative-source
clause, while §11.10 is a section about geometry. Keep §11.10's dash-gap rule; take §13.7.4's
duration. Cite the token, never the number.

### The ghost

The portrait as it stood **90 days ago**, drawn behind at `C.Profile.ghostInk` and
`C.Profile.ghostWeight`, dashed, unlabelled. Stored as `ghost: [Double]` + `ghostTakenAt`.

- **`captureGhostIfDue(asOf:)` runs at session start**, beside T06's confidence decay, and captures
  the current five *values* — not radii — when `ghostTakenAt` is nil and 90 days of history exist, or
  when `ghostTakenAt` is more than 90 days old. Storing values rather than radii is what makes
  `aUniformlyLowerGhostIsInvisible` true: the ghost is re-normalised against **its own** five-axis
  mean at draw time, so it can only show change of shape, exactly as §11.11 P5 requires.
- **No legend, no date, no "90 days ago" caption.** A label would turn it into a before/after, which
  is a grade with two columns. It is `.accessibilityHidden(true)` for the same reason the contour is.
- **If `ghostTakenAt` is nil there is no ghost.** Do not draw the current contour twice at 12 %.
- **Exactly one.** No second ghost, no sparkline, no time series — §11.11 P5, and
  `exactlyOneGhost` asserts the drawn-element inventory rather than hoping.

`beginHistory(at:)` stamps the first-ever sample date so "90 days of history exist" is answerable; if
E07·T09's `Profile` already carries a creation date, use that instead of adding a field.

### Why the ghost is P2 and the rest is P1

§14.1 prices the ghost P2 and tremble/morph P1. Dropping the ghost leaves `ghost`/`ghostTakenAt`
`nil` forever and every other test green — which is why `ghostRadii()` returns an optional and the
draw is a `if let`. Dropping tremble and morph leaves a correct static portrait. Neither drop touches
a P0 gate.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ProfileTrembleTests` green, all eleven tests.
- [ ] `swift test --package-path Modules --filter ProfileMorphTests` green, all twelve tests.
- [ ] `grep -rn "Double.random\|\.random(" Modules/Sources/MetaFeature HunchCore/Sources/Archive` returns nothing.
- [ ] `grep -rn "Timer\|repeatForever" Modules/Sources/MetaFeature` returns nothing.
- [ ] `grep -rn "Easing.settle\|spring(response" Modules/Sources/MetaFeature/ProfileMorph.swift` returns nothing — the spring is `C.Profile.morphSpring`.
- [ ] `grep -rn "0.35\|350\|240" Modules/Sources/MetaFeature` returns nothing — the Reduce Motion duration is `Dur.reduceMotionMorph`.
- [ ] `C.Profile.morphSpring`'s declaration in `C.swift` carries the "only spring outside the six token easings" sentence.
- [ ] Reduce Motion and Low Power both produce the identical static-dash rendering, verified in the simulator, and the two screenshots are in `PROGRESS.md`.
- [ ] `tests.json` carries seven entries: the amplitude law, noise determinism, noise continuity and bounds, the three morph phases with their stagger, entry-only driving, the Reduce Motion dash with a constant phase, and the ghost's 90-day capture with its shape-only property.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes storing the ghost as radii "since that is what is drawn", reject it and point at `aUniformlyLowerGhostIsInvisible`.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T10: deterministic tremble, the staggered morph and the 90-day ghost"`

## Out of scope

- The contour, the normalisation and the spline — **T08**; the sigils — **T09**, which do not tremble and do not animate.
- The statistics key this screen's instrument bar carries — **T11**.
- The complete Reduce Motion substitution table re-verified row by row across every shipped animation — **E20·T08**.
- `Dur.*` and `Easing.*` themselves — **E03·T02**.
- The DEBUG snapshot gallery the deterministic noise makes reproducible — **E04·T09**.
