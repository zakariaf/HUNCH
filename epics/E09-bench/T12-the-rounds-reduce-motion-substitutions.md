# T12 — The round's Reduce Motion substitutions

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T10 |
| **Delivers** | §14.1 `Reduce Motion table` (the E08 + E09 half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/reduce-motion.md` **is** this task: §1's three things a substitution may never do, §2's complete table, §3's four tokens §13.7.4 left unnamed, §5's list of timing that does not change, §6's one-place-decides Swift seam, and §7's two tests. Its §8 also rules the two places canon contradicts itself. |
| `hunch-design-tokens` | The four unnamed substitution durations are **L1** because each is shared by two or more components — `dur.reduceMotionSwap`, `…Strike`, `…Expand`, `…Morph` — and this skill is their one home. It also owns the distinction this task must not blur: Reduce Motion freezes the shader's `t`; Reduce Transparency, High Contrast and Low Power set `amt = 0`. Two settings, two predicates. |
| `hunch-accessibility` | §13.12 gate 9 is a **hand audit** — *"Reduce Motion on: nothing translates, scales or rotates anywhere, including SIEVE; every substitution in §13.7.4 verified by hand"* — and this skill owns the gate list and how a gate is recorded in `tests.json`. It also owns that Reduce Motion arrives through `RenderEnv`, never through a `UIAccessibility` read in a view. |
| `hunch-bench-instruments` | Its standing rule — *"Never let a Reduce Motion substitution change what the instrument shows"* — is the acceptance criterion for every row this task writes, and its component files state which rows land on which instrument. |

## Objective

At the end of this task every animation E08 and E09 added has a named substitution in one table, a
test asserts the table is complete and that no substitution translates, scales or rotates, and the
three things that must **not** change under the setting — the 640 ms seal hold, the 260 ms
adjudication hold and every audio and haptic onset's absolute position — are asserted invariant.
Before this task the substitutions are scattered across the components that added them; after it,
there is one table, one seam, and a test that fails when a row goes missing.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.7.4 | The complete substitution table, and its opening normative clause: *"Every animation in the app appears here. The substitution is a crossfade unless motion **is** the mechanic."* |
| `GAME_DESIGN.md` | §6.5, §6.11 case 10 | The one timing that **does** change: the probe input lock shortens 420 → **320 ms**; a queued tap is honoured at 320 with a 180 ms compressed travel |
| `GAME_DESIGN.md` | §6.8 | *"the 640 ms hold runs unchanged, then one 260 ms crossfade to the settled composition with the marks already struck — 900 ms total. Every audio and haptic onset keeps its absolute position; the ones that fall past 900 ms are **dropped rather than rescheduled**, because a haptic arriving after the screen has settled is a second event, not the same one"* |
| `GAME_DESIGN.md` | §6.5 | The constant **260 ms adjudication hold regardless of verdict, band or contextuality** — variable latency is a side channel |
| `GAME_DESIGN.md` | §13.12 gate 9 | The acceptance gate: nothing translates, scales or rotates anywhere, every substitution verified by hand |
| `GAME_DESIGN.md` | §13.6, §13.11 | Reduce Motion freezes the shader's `t`; the `amt = 0` predicates are Reduce Transparency, High Contrast and Low Power |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A24, A29 | `RenderEnv` is injected; there is no `UIAccessibility` read below the composition root |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`Modules/Tests/LoomFeatureTests/ReduceMotionTableTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI
@testable import LoomFeature

@Suite("Reduce Motion substitutions", .tags(.unit, .presubmission))
struct ReduceMotionTableTests {

    // §13.7.4 opens by declaring itself complete. This is that clause, made checkable.
    @Test("Every animation the round surface ships declares a substitution",
          arguments: MotionRow.allCases.filter { $0.owner == .round })
    func everyRowHasASubstitution(_ row: MotionRow) {
        #expect(row.substitution != nil)
    }

    // §13.12 gate 9's automatable half: nothing translates, scales or rotates.
    @Test("No substitution translates, scales or rotates",
          arguments: MotionRow.allCases.filter { $0.owner == .round })
    func nothingMoves(_ row: MotionRow) {
        #expect(row.substitution?.transform == MotionTransform.none)
    }

    // The registry is closed against the animations that actually exist: every animation
    // registered by an E08 or E09 view has a row, and every round row names a live animation.
    // A view that animates without registering is what makes a row go missing.
    @Test("The registry and the shipped animations are the same set")
    func registryMatchesReality() {
        let registered = Set(MotionRow.allCases.filter { $0.owner == .round }.map(\.animationID))
        let shipped = Set(RoundSurfaceAnimations.allIDs)
        #expect(registered == shipped,
                "missing rows: \(shipped.subtracting(registered)); dead rows: \(registered.subtracting(shipped))")
    }

    // §6.5: the ONE timing that changes.
    @Test("The probe input lock shortens from 420 ms to 320 ms")
    func inputLockShortens() {
        #expect(RoundTiming.inputLock(in: .fixture(isReduceMotionEnabled: false)) == .milliseconds(420))
        #expect(RoundTiming.inputLock(in: .fixture(isReduceMotionEnabled: true)) == .milliseconds(320))
    }

    // §6.8, §13.7.4, reduce-motion.md §5: DELIBERATELY unchanged. Shortening it for some
    // players hands them a different game.
    @Test("The 640 ms seal hold is identical with the setting on and off")
    func sealHoldIsInvariant() {
        let on = RenderEnv.fixture(isReduceMotionEnabled: true)
        let off = RenderEnv.fixture(isReduceMotionEnabled: false)
        #expect(RoundTiming.sealHold(in: on) == RoundTiming.sealHold(in: off))
        #expect(RoundTiming.sealHold(in: on) == C.Reveal.sealHold)
        #expect(MotionRow.sealHold.substitution == nil, "there is no row; it is not an animation")
    }

    // §6.5: a variable adjudication hold is a side channel. It does not move either.
    @Test("The 260 ms adjudication hold is identical with the setting on and off")
    func adjudicationHoldIsInvariant() {
        #expect(RoundTiming.adjudicationHold(in: .fixture(isReduceMotionEnabled: true))
                == RoundTiming.adjudicationHold(in: .fixture(isReduceMotionEnabled: false)))
    }

    // §6.8: "900 ms total" — the hold plus one crossfade, both outcomes.
    @Test("The reduced reveal is the hold plus one crossfade, 900 ms absolute",
          arguments: [Outcome.inscribed(marks: 3, fracture: false), .broken])
    func reducedRevealIs900(_ outcome: Outcome) {
        let plan = RevealTimeline.plan(for: outcome, in: .fixture(isReduceMotionEnabled: true))
        #expect(plan.total == .milliseconds(900))
        #expect(plan.total == C.Reveal.sealHold + Dur.reduceMotionReveal)
        #expect(plan.beats.count == 1)
        #expect(plan.marksAlreadyStruck)
    }

    // §6.8: onsets keep their ABSOLUTE positions; those past 900 ms are DROPPED, not
    // rescheduled. A haptic after the screen has settled is a second event.
    @Test("Surviving onsets are unmoved and late ones are dropped")
    func onsetsAreDroppedNotRescheduled() {
        let full = RevealCueSchedule.absolute(for: .inscribed(marks: 3, fracture: false))
        let reduced = RevealCueSchedule.absolute(for: .inscribed(marks: 3, fracture: false),
                                                 in: .fixture(isReduceMotionEnabled: true))

        #expect(reduced.allSatisfy { $0.at <= .milliseconds(900) })
        #expect(reduced == full.filter { $0.at <= .milliseconds(900) },
                "survivors keep their exact absolute positions")
        #expect(reduced.count < full.count, "some onsets are past 900 ms and are dropped")
        #expect(!reduced.contains { point in full.contains { $0.cue == point.cue && $0.at != point.at } })
    }

    // reduce-motion.md §3: the four tokens §13.7.4 wrote as bare numbers, and the warning
    // not to borrow a same-valued token that means something else.
    @Test("The four substitution durations are named tokens with the right values")
    func theFourTokens() {
        #expect(Dur.reduceMotionSwap == .milliseconds(140))
        #expect(Dur.reduceMotionStrike == .milliseconds(180))
        #expect(Dur.reduceMotionExpand == .milliseconds(200))
        #expect(Dur.reduceMotionMorph == .milliseconds(240))
        // dur.ringAdmit is ALSO 200 and is the normal ring, not a substitution.
        #expect(Dur.ringAdmit == Dur.reduceMotionExpand)
        #expect(MotionRow.assayExpand.substitution?.duration == Dur.reduceMotionExpand)
        #expect(MotionRow.admitRing.duration == Dur.ringAdmit)
    }

    // reduce-motion.md §1 rule 3: a gesture is substituted by a CONTROL, and a geometry
    // match is REMOVED — neither is merely shortened.
    @Test("Gestures become controls and geometry matches are removed, never shortened")
    func gesturesAndMatches() {
        #expect(MotionRow.dialToBench.substitution?.replacesGestureWithControl == true)
        #expect(BenchHandle.affordance(in: .fixture(isReduceMotionEnabled: true)) == .button)
        #expect(MotionRow.assayExpand.substitution?.removesGeometryMatch == true)
        #expect(MotionRow.codexSharedElement.substitution?.removesGeometryMatch == true)
    }

    // reduce-motion.md §2's two geometry values, which are the easiest rows to get wrong.
    @Test("The static rings sit at 1.18 R and 1.00 R")
    func staticRingRadii() {
        #expect(MotionRow.admitRing.substitution?.staticRadiusMultiple == 1.18)
        #expect(MotionRow.rejectRing.substitution?.staticRadiusMultiple == 1.00)
    }

    // §13.6: Reduce Motion freezes `t`; it does NOT set amt = 0. Two settings, two predicates.
    @Test("Reduce Motion freezes the shader's time and does not disable it")
    func shaderPredicates() {
        let reduced = RenderEnv.fixture(isReduceMotionEnabled: true)
        #expect(reduced.isShaderTimeFrozen)
        #expect(reduced.shaderAmount > 0)
        #expect(RenderEnv.fixture(isReduceTransparencyEnabled: true).shaderAmount == 0)
    }

    // A24 / A29: the setting arrives through RenderEnv, so every surface agrees what it means.
    @Test("Reduce Motion is resolved once, at the token seam")
    func oneSeam() {
        #expect(RenderEnv.reduceMotionResolutionSites == 1)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:LoomFeatureTests/ReduceMotionTableTests
```

`cannot find 'MotionRow' in scope` is the right failure. `registryMatchesReality` will keep failing
after `MotionRow` exists, and its failure message names exactly which rows are missing — that is the
test doing its job, not a broken test.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then do the **hand audit**: §13.12 gate 9 is not automatable in
full, and the automated half above only proves the rows are declared correctly.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/LoomFeature/MotionRow.swift` — the registry: one case per animation, its owner, its normal timing and its substitution |
| create | `Modules/Sources/HunchUI/Motion.swift` — `RenderEnv.animation(_:reducedTo:)` and `animationOrNone(_:)`, the one seam |
| create | `Modules/Sources/LoomFeature/RoundSurfaceAnimations.swift` — the IDs every E08/E09 view registers, so the registry can be checked against reality |
| modify | every E08 and E09 view that animates — route through the seam, register an ID |
| modify | `Modules/Sources/LoomFeature/RevealTimeline.swift` — `plan(for:in:)` returning the 900 ms reduced plan |
| modify | `Modules/Sources/LoomFeature/RevealCueSchedule.swift` — `absolute(for:in:)` dropping onsets past 900 ms |
| modify | `HunchCore/Sources/Tokens/Dur.swift` — the four L1 substitution tokens, **if E03·T02 did not ship them** |
| create | `Modules/Tests/LoomFeatureTests/ReduceMotionTableTests.swift` |
| modify | `tests.json` — gate 9's automated half, the seal-hold invariant and the dropped-onset rule |
| modify | `PROGRESS.md` — the hand-audit record |

## Implementation notes

### The registry, and why it is checked against reality

A table that lists rows is a table somebody forgets to add to. `MotionRow` is therefore checked
**both ways**:

```swift
public enum MotionRow: CaseIterable, Hashable, Sendable {
    case admitRing, rejectRing, throatScale, throatRegisterCrossfade, rejectShudder,
         ribbonTileSlideIn, ribbonAutoScroll, dialToBench, assayExpand, assayLiveMorph,
         assayWrongCellFlash, sealMarksStrikeIn, keyDepression, barredSealRailPulse,
         emptyRailPulse, tallyDialCollapse, forkTurnoutSlide, wedgeCycle, couplerCycle,
         counterexampleRise, counterexampleTravel, counterexampleDock,
         lawRevealCorrect, lawRevealLost, codexSharedElement, screenPush,
         bloomPulseOnAdmit, grainShimmer
    // …plus `sealHold`, which has no substitution because it is not an animation.

    public var owner: Owner { … }              // .round for everything E08 and E09 shipped
    public var animationID: AnimationID { … }  // the ID the view registers
    public var substitution: Substitution? { … }
}
```

`RoundSurfaceAnimations.allIDs` is populated by the views themselves — each animating view declares
its `AnimationID` beside the `.animation(…)` call. `registryMatchesReality` then fails in **both**
directions: a new animation with no row (the failure mode that made §13.7.4 incomplete before) and a
dead row for an animation that was deleted. Its failure message names the offending set, so the fix is
mechanical.

Rows this epic added and that must be present: the Assay's **wrong-cell flash** (T06), the
counterexample's **rise, travel and dock** (T09), the **Fork turnout slide**, the **wedge** and
**coupler** cycles and the **Tally dial collapse** (T02), the **Dial ↔ Bench** drag (T01), and both
**law reveal** rows (T10). T06 and T09 were told to write their rows in their own commits; this task
is what catches it if they did not.

### One seam, not eight `if`s

```swift
extension RenderEnv {
    func animation(_ normal: (Duration, Easing), reducedTo substitute: (Duration, Easing)) -> Animation {
        let (duration, easing) = isReduceMotionEnabled ? substitute : normal
        return easing.animation(for: duration)
    }
    func animationOrNone(_ normal: (Duration, Easing)) -> Animation? {
        isReduceMotionEnabled ? nil : normal.1.animation(for: normal.0)
    }
}
```

Eight files each deciding what Reduce Motion means is how a row goes missing.
`reduceMotionResolutionSites == 1` is a debug-only counter incremented at the seam and asserted to be
the only site; if that reads as too clever at review, replace it with a hygiene grep for
`isReduceMotionEnabled` outside `Motion.swift`, `RenderEnv.swift` and the geometry rows that
legitimately branch (the static ring radii, the handle affordance).

The three wrong forms, from `reduce-motion.md` §6, and each will pass a naive review:

```swift
// WRONG — shortens a gesture instead of substituting a control
.animation(.easeInOut(duration: reduceMotion ? 0.04 : 0.28), value: isOpen)

// WRONG — keeps the geometry match and hopes a short duration hides it. It still
// translates and scales; gate 9 fails.
.matchedGeometryEffect(id: id, in: ns)
.animation(reduceMotion ? .linear(duration: 0.01) : .spring, value: expanded)

// WRONG — the setting read in a view, so two surfaces can disagree about it
@Environment(\.accessibilityReduceMotion) var reduceMotion
```

### Three things a substitution may never do

1. **Delete information the animation carried.** *Replace* the animation; do not *remove* what it was
   showing. The worked case is SIEVE (E14), and the pattern is every row: the Fork's turnout still
   ends up under the newly lit cell, the counterexample still takes both rings, the Assay still
   switches the same cells.
2. **Change timing the game is scored on.** Beat positions, hit windows, holds and previews are
   identical with the setting on and off.
3. **Merely shorten a gesture.** A 50 ms drag is still a drag; a 40 ms `matchedGeometryEffect` is
   still a translation and a scale. Gestures are substituted by controls; geometry matches are removed.

### The three invariants, and the one change

| Thing | Under Reduce Motion | Why |
|---|---|---|
| the 640 ms seal hold | **unchanged** | verdict-blind; shortening it for some players hands them a different game |
| the 260 ms adjudication hold | **unchanged** | a variable hold is a side channel — a Loom that thinks harder about hard glyphs leaks the family before probe 3 |
| every audio and haptic onset | **absolute position unchanged**; those past 900 ms **dropped** | a haptic arriving after the screen has settled is a second event, not the same one |
| the probe input lock | **420 → 320 ms** | §6.5; the 260 ms hold is unchanged inside it and a 60 ms crossfade replaces the contraction, the travel and the arc draw. A queued tap is honoured at 320 |

`sealHold` appears in `MotionRow` **with a `nil` substitution and a comment**, rather than being
absent, so that a future reader finds the decision instead of the gap. `everyRowHasASubstitution` is
parameterised over `owner == .round` and `sealHold`'s owner is `.invariant`, so it is excluded by
construction rather than by a special case in the test body.

### Dropped, not rescheduled

```swift
public static func absolute(for outcome: Outcome, in env: RenderEnv) -> [RevealCuePoint] {
    let full = absolute(for: outcome)
    guard env.isReduceMotionEnabled else { return full }
    return full.filter { $0.at <= C.Reveal.sealHold + Dur.reduceMotionReveal }   // 900 ms
}
```

A `filter`, never a `map` that compresses. The test asserts both halves: survivors keep their exact
absolute positions, and the count strictly drops. Rescheduling `codex.inscribe` from 1,630 to 880
would give a Reduce Motion player a different *sound* for the same event, which is the second-event
problem in the audio channel.

### Two canon conflicts, already ruled

- **The Profile morph.** §11.10 says *"all motion below becomes a 0.35 s crossfade"*; §13.7.4 says
  *"new shape instantly; 240 ms crossfade"*. §13.7.4 wins — it opens by declaring that every animation
  in the app appears in it, which is a normative-source clause. Keep §11.10's dash-gap rule, take
  §13.7.4's 240 ms. (That row is **E16**'s to implement; the ruling is recorded here because this is
  the table's home.)
- **The reveal.** §13.7.4 gives one crossfade; §6.8 gives the 640 ms hold **plus** that crossfade,
  900 ms absolute. Both are true and they are in different clocks — §13.7.4 is local, §6.8 is
  absolute.

### The hand audit

§13.12 gate 9 is *"verified by hand"*. Automating the row declarations does not discharge it. With
Reduce Motion on in the simulator, walk `RoundView`, `BenchView`, `AssayInspectorView` and
`InscriptionView` and confirm by eye that nothing translates, scales or rotates — including the key
depression, which §13.7.4 has no row for and which `reduce-motion.md` §2 closes as an interior step to
`surface.cellLit`. Record the walk in `PROGRESS.md` with the date and the four screens named.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/ReduceMotionTableTests` green.
- [ ] `registryMatchesReality` passes with **zero** missing and **zero** dead rows.
- [ ] `grep -rn 'accessibilityReduceMotion\|isReduceMotionEnabled' Modules/Sources | grep -v 'Motion.swift\|RenderEnv'`
      returns only the geometry rows that legitimately branch, each with a comment saying why.
- [ ] `grep -rnE 'duration: *reduceMotion|reduceMotion \? 0\.' Modules/Sources` returns nothing — no
      shortened gesture.
- [ ] `grep -rn 'matchedGeometryEffect' Modules/Sources` shows both sites guarded by
      `if !env.isReduceMotionEnabled`.
- [ ] `grep -rnE '\b140\b|\b180\b|\b200\b|\b240\b' Modules/Sources | grep -i 'reduce'` returns nothing
      — the four tokens are cited, never inlined.
- [ ] `tests.json` carries `motion.reduce-motion-table-complete`, `motion.seal-hold-invariant` and
      `motion.onsets-dropped-not-rescheduled`, and gate 9's entry names the hand audit.
- [ ] `PROGRESS.md` records the hand audit with its date and the four screens walked.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:LoomFeatureTests/ReduceMotionTableTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T12: the round's Reduce Motion substitution table and its completeness test"`

## Out of scope

- **SIEVE's replaced-not-removed row and its parity test.** **E14·T10**. Its ruling lives in the same
  table; its implementation does not.
- **The DRIFT moment and the hinge reveal's rows.** **E12·T08**.
- **The Profile morph, the tremble, the streak bloom and the idle Loom's crossfade.** **E16·T10** and
  **E17·T03**; the rulings are recorded here, the implementations are not.
- **The grain shader's `amt = 0` predicates.** **E20·T07**. This task asserts only that Reduce Motion
  freezes `t` and is not one of them.
- **The final row-by-row re-verification against every animation the shipped app contains.**
  **E20·T08**, which re-runs this table when nothing is left to add.
- **The five nudges' Reduce Motion behaviour** (a pure opacity crossfade). **E10·T08**.
- **Audio and haptic players.** **E20**. This task changes only *which* published onsets survive.
