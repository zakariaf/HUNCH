# T08 — The hinge reveal

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T06 |
| **Delivers** | The hinge reveal (DRIFT) · Reduce Motion table (the DRIFT reveal's row) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/reveal-beats.md` §7 already carries §7.9's five parts and, more importantly, §8's rule for building a sheet: **store durations, compute offsets, assert the sum** in one `phaseAnimator` over a phase enum, so the beats cannot drift apart. `references/reduce-motion.md` §5 lists the DRIFT reveal's total among the timings that do **not** change, which is the constraint the four crossfades have to satisfy. |
| `hunch-design-tokens` | Two of the five parts have no duration in §7.9, and inventing two numbers here would create a second home for durations. The skill owns `Dur.*` and the rule that a substitution is resolved **once, at the token seam** — which is also what stops eight files each deciding what Reduce Motion means for this sheet. |

`hunch-shared-marks` is worth opening for `references/cancel-hatch.md` alone — the dead stretch's
diagonal hatch is the same drawing as an unlit Bench cell and must not be re-authored.

## Objective

At the end of this task a settled DRIFT round plays its own reveal: a 500 ms seam that stops at
`t_hinge`, a split of the ribbon into two lanes at ±18 pt that shows the transcript was about two
different machines, a hatched dead stretch, a 900 ms morph in which **only the edited leaf moves**, and
three seconds of hold. Under Reduce Motion it becomes four crossfades of the same total duration with
the two-lane geometry and the single changed leaf intact, because those are information rather than
motion.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.9 | The whole task: five parts; seam 500 ms stopping at `t_hinge` and docking to the trigger-(b) marker; the split's ±18 pt and its three tile states; the dead stretch at 25 % with the cancel hatch; the 900 ms morph with `L₁` assembling over 700 ms and only the edited leaf animating; the 3 s hold; the Reduce Motion substitution; the two audio cues |
| `GAME_DESIGN.md` | §7.6 | A loss before the hinge still plays the full reveal with the un-fired `L₂` at 40 % opacity |
| `GAME_DESIGN.md` | §7.11 | DOUBLE-STRIKE-PRE-HINGE — and that the un-fired seam draws **dashed** |
| `GAME_DESIGN.md` | §7.8 | `t_hinge` and `t_evidence` as the two indices the sheet is built on |
| `GAME_DESIGN.md` | §6.1, §7.9 | Adjudication commits to disk **before** the animation starts, so the reveal is decoration over settled state and can be skipped, interrupted or replayed from the Codex |
| `GAME_DESIGN.md` | §13.7.4 | The Reduce Motion table's shape and the rule that a substitution is a crossfade unless motion *is* the mechanic |
| `GAME_DESIGN.md` | §13.7.2 | The 520 ms **DRIFT moment** — a different animation, inserted into a *round* reveal at local t = 230, and not this sheet |
| `hunch-motion-and-feedback` | `references/reveal-beats.md` §7–§8 | The five parts and the `C.Reveal`-shaped value the sheet must be |
| `hunch-shared-marks` | `references/cancel-hatch.md` | The dead stretch's hatch, already owned |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/HingeRevealTests.swift`:

```swift
import Testing
@testable import LoomFeature
@testable import HunchUI
import Rounds
import LawGeneration

@Suite("The hinge reveal — §7.9", .tags(.unit, .presubmission))
struct HingeRevealTests {

    // MARK: the sheet

    @Test("Five parts, in §7.9's order")
    func fiveParts() {
        #expect(HingeRevealPhase.allCases == [.seam, .split, .deadStretch, .morph, .hold])
    }

    @Test("The sheet's durations come from tokens and its offsets are derived, never stored")
    func offsetsAreDerived() {
        let sheet = C.HingeReveal.sheet
        #expect(sheet.offset(of: .seam) == .zero)
        #expect(sheet.offset(of: .split) == sheet.duration(of: .seam))
        #expect(sheet.total == HingeRevealPhase.allCases.reduce(.zero) { $0 + sheet.duration(of: $1) })
    }

    @Test("The two durations §7.9 states are exactly those values")
    func statedDurations() {
        #expect(C.HingeReveal.sheet.duration(of: .seam) == .milliseconds(500))
        #expect(C.HingeReveal.sheet.duration(of: .morph) == .milliseconds(900))
        #expect(C.HingeReveal.sheet.duration(of: .hold) == .milliseconds(3000))
    }

    @Test("Reduce Motion keeps the total — four crossfades, same sum, plus the unchanged hold")
    func reduceMotionPreservesTheTotal() {
        #expect(C.HingeReveal.reducedSheet.total == C.HingeReveal.sheet.total)
        #expect(C.HingeReveal.reducedSheet.duration(of: .hold)
             == C.HingeReveal.sheet.duration(of: .hold))
    }

    // MARK: the seam

    @Test("The seam stops at t_hinge, not at the ribbon's end")
    func seamStopsAtTheHinge() {
        let g = HingeRevealGeometry(transcript: .fixture(.workedBandFive), ribbonLength: 27)
        #expect(g.seamTileIndex == 10)
        #expect(g.seamSweepFraction == 10.0 / 27.0)
    }

    @Test("It docks to the trigger-(b) marker when one exists, and draws its own hairline otherwise")
    func seamDocksToTheMarker() {
        let captured = HingeRevealGeometry(transcript: .fixture(.captureThenCleanWin), ribbonLength: 20)
        #expect(captured.seamDocksToExistingMarker == true)
        let satiated = HingeRevealGeometry(transcript: .fixture(.workedBandFive), ribbonLength: 27)
        #expect(satiated.seamDocksToExistingMarker == false)
    }

    @Test("An un-fired hinge draws the seam dashed and L₂ at 40 %")
    func unfiredHinge() {
        let g = HingeRevealGeometry(transcript: .fixture(.doubleStrikePreHinge), ribbonLength: 14)
        #expect(g.seamIsDashed == true)
        #expect(g.lawTwoOpacity == C.HingeReveal.unfiredLawOpacity)
        #expect(g.seamTileIndex == 14)          // the un-fired seam sits past every tile
    }

    // MARK: the split

    @Test("Every tile lands in exactly one of three lanes, decided by BOTH laws")
    func threeLanes() {
        let g = HingeRevealGeometry(transcript: .fixture(.workedBandFive), ribbonLength: 27)
        for index in 1...27 {
            let lane = g.lane(ofTile: index)
            switch (g.lawOneExplains(index), g.lawTwoExplains(index)) {
            case (true,  false): #expect(lane == .rise)
            case (false, true):  #expect(lane == .fall)
            case (true,  true):  #expect(lane == .hold)
            case (false, false): Issue.record("tile \(index) explained by neither law")
            }
        }
    }

    @Test("The lanes are ±18 pt from the ribbon's own baseline")
    func laneOffsets() {
        #expect(HingeRevealGeometry.laneOffset(.rise) == -18)
        #expect(HingeRevealGeometry.laneOffset(.fall) == 18)
        #expect(HingeRevealGeometry.laneOffset(.hold) == 0)
    }

    @Test("The split re-evaluates EVERY tile, on both sides of the seam")
    func splitCoversTheWholeRibbon() {
        let g = HingeRevealGeometry(transcript: .fixture(.workedBandFive), ribbonLength: 27)
        #expect((1...27).allSatisfy { g.lane(ofTile: $0) != nil })
    }

    // MARK: the dead stretch

    @Test("Only tiles after t_evidence that agree under both laws are hatched")
    func deadStretch() {
        let g = HingeRevealGeometry(transcript: .fixture(.workedBandFive), ribbonLength: 27)
        #expect(g.isDead(tile: 12) == true)         // after t_evidence, in the agreement set
        #expect(g.isDead(tile: 11) == false)        // t_evidence itself is inside D
        #expect(g.isDead(tile: 9)  == false)        // before the hinge
        #expect(g.isDead(tile: 13) == false)        // t_recover is inside D
    }

    @Test("The hatch is the cancel hatch and the opacity is the unlit-cell token")
    func hatchIsShared() {
        #expect(HingeRevealGeometry.deadTileMarkOwner == "CancelHatch.draw")
        #expect(C.HingeReveal.deadTileOpacity == C.opacity.cellUnlit)
    }

    @Test("No count and no label accompanies the dead stretch")
    func deadStretchIsSilent() {
        let composition = HingeRevealComposition(transcript: .fixture(.workedBandFive))
        #expect(composition.elementIDs.contains { $0.contains("count") || $0.contains("label") }
                == false)
    }

    // MARK: the morph — one moving part

    @Test("Exactly one leaf animates; every shared leaf slides without redrawing")
    func onlyTheEditedLeafAnimates() {
        let m = MorphPlan(pair: .fixture(.workedBandFive), sheet: C.HingeReveal.sheet)
        #expect(m.animatingLeafIndices == [DriftPair.fixture(.workedBandFive).editedLeafIndex])
        #expect(m.animatingLeafIndices.count == 1)
        #expect(m.slidingLeafIndices.contains(m.animatingLeafIndices[0]) == false)
    }

    @Test("L₁ assembles over 700 ms of the 900 ms morph, staggered")
    func assemblyWindow() {
        let m = MorphPlan(pair: .fixture(.workedBandFive), sheet: C.HingeReveal.sheet)
        #expect(m.lawOneAssemblyDuration == .milliseconds(700))
        #expect(m.lawOneAssemblyDuration < C.HingeReveal.sheet.duration(of: .morph))
        #expect(m.stagger > .zero)
    }

    @Test("The morph's one moving part survives Reduce Motion — it is information, not motion")
    func reduceMotionKeepsTheLeafAndTheLanes() {
        let plain = HingeRevealComposition(transcript: .fixture(.workedBandFive), reduceMotion: false)
        let reduced = HingeRevealComposition(transcript: .fixture(.workedBandFive), reduceMotion: true)
        #expect(reduced.lanes == plain.lanes)
        #expect(reduced.animatingLeafIndices == plain.animatingLeafIndices)
        #expect(reduced.isCrossfadeOnly == true)
    }

    // MARK: the model never waits on the animation

    @Test("The round is settled and written before the first frame of the reveal")
    func adjudicationCommitsFirst() {
        let round = Round.fixture(.driftAtHingeEntry)
        #expect(round.phase == .hinge)
        #expect(round.settlementWritten == true)
        #expect(round.revealPhase == nil)          // not yet started
    }

    @Test("Skipping or backgrounding the reveal changes nothing about the outcome")
    func revealIsDecoration() {
        var round = Round.fixture(.driftAtHingeEntry)
        let before = round.settlement
        round.skipReveal()
        #expect(round.settlement == before)
        #expect(round.phase == .settled(before.outcome))
    }

    // MARK: cue points, published as data for E20

    @Test("Two cue points, at the seam's start and the morph's start")
    func cuePoints() {
        let points = HingeRevealCueSchedule.points
        #expect(points.map(\.phase) == [.seam, .morph])
        #expect(points.first?.cue == .driftSeamSweep)
        #expect(points.last?.cue == .driftMorphResolve)
    }

    @Test("Cue onsets are absolute and the ones past the reduced sheet are dropped, not moved")
    func cueOnsetsAreAbsolute() {
        let normal = HingeRevealCueSchedule.onsets(in: C.HingeReveal.sheet)
        let reduced = HingeRevealCueSchedule.onsets(in: C.HingeReveal.reducedSheet)
        #expect(reduced.allSatisfy { normal.contains($0) })
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter HingeRevealTests`

Expect missing `HingeRevealPhase`, `C.HingeReveal`, `HingeRevealGeometry`, `HingeRevealComposition`,
`MorphPlan`, `HingeRevealCueSchedule`. `C.opacity.cellUnlit` and `CancelHatch.draw` already exist
(E03·T04, E04·T08) — if either is named differently, use the shipped name and keep the assertion.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Then record the reveal in the simulator with Reduce Motion off and
on, and put both recordings' durations in `PROGRESS.md` — they must be the same number.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.HingeReveal`: the five durations, `reducedSheet`, `unfiredLawOpacity`, `deadTileOpacity`, the ±18 pt lane offset |
| create | `Modules/Sources/LoomFeature/HingeRevealPhase.swift` — the five-case enum |
| create | `Modules/Sources/LoomFeature/HingeRevealGeometry.swift` — the seam index, the three lanes, the dead-stretch predicate |
| create | `Modules/Sources/LoomFeature/MorphPlan.swift` — which leaf animates, which slide, the 700 ms staggered assembly |
| create | `Modules/Sources/LoomFeature/HingeRevealView.swift` — the `phaseAnimator` and the composition |
| create | `Modules/Sources/LoomFeature/HingeRevealCueSchedule.swift` — the two cue points as data |
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` — the two-lane layout, reusing the three tile states E08·T05 already made expressible |
| modify | `Modules/Sources/Feedback/Cue.swift` — `driftSeamSweep`, `driftMorphResolve` as vocabulary entries only |
| modify | `Modules/Sources/LoomFeature/Round.swift` — enter `.hinge` with the settlement already written; `skipReveal()` |
| create | `Modules/Tests/LoomFeatureTests/HingeRevealTests.swift` |
| modify | `tests.json` — the five parts, the equal totals, the seam stop, the three lanes, the one animating leaf, the settle-before-animate rule |
| modify | `DECISIONS.md` — the two unspecified durations and the tokens they came from |

## Implementation notes

### The sheet: two durations are stated, two are not, and one is the hold

§7.9 gives 500 ms for the seam, 900 ms for the morph and "three seconds of silence" for the hold. It
gives **no duration for the split or the dead stretch**. Do not invent two numbers:

> **Ruling.** The split takes the ribbon's own tile-movement duration and the dead stretch takes the
> Assay's live-morph duration — both already in `Dur.*` from E03·T04, both already the value the eye
> is trained on for "a tile moved" and "cells changed state". Record the two token names and the
> resulting total in `DECISIONS.md`; the total is what Reduce Motion has to preserve, so it must be
> written down somewhere a reviewer can find it.

The sheet is one value in `C.HingeReveal`, built the way `reveal-beats.md` §8 requires: **store
durations, compute offsets, assert the sum**. Offsets are never stored — two homes for one fact is
guaranteed drift, and it is the exact failure E09·T10 spent a task removing from the round reveal.

### The seam, and what "stops at `t_hinge`" means when the hinge never fired

`seamTileIndex` is `transcript.hingeProbe ?? ribbonLength` — an un-fired hinge puts the seam past every
tile, which is geometrically the truth: nothing in the transcript was ever judged by `L₂`. It draws
**dashed** (§7.11) and `L₂` assembles at 40 % (§7.6). That combination is the whole DOUBLE-STRIKE-PRE-HINGE
row and it must be reachable — a fast loss still teaches the mode's shape, which is why the reveal plays
at all after a two-strike loss.

When trigger (b) wrote a seam marker, the sweep **docks** to it rather than drawing a second hairline at
the same x. One mark, one position; two hairlines a pixel apart is the artefact that makes a reveal look
like a bug.

### The split: three lanes, decided by both laws, over the whole ribbon

Every tile is re-evaluated under **both** laws — not "which law judged it", which is T02's
`lawInForce(atProbe:)` and a different question:

| `L₁` explains | `L₂` explains | Lane | Offset |
|---|---|---|---|
| yes | no | rise | −18 pt |
| no | yes | fall | +18 pt |
| yes | yes | hold | 0 |
| no | no | — | unreachable: the tile's recorded verdict came from one of the two laws, so at least one explains it |

"Explains" means *this law's verdict for this tile's `(prev, cur)` equals the verdict the ribbon
recorded*. The fourth row is genuinely unreachable and the test records an `Issue` rather than
inventing a fourth lane — if it ever fires, the transcript and the laws have gone out of sync and that
is a corruption bug, not a rendering one.

The two lanes fork **at the seam**, so tiles before it that both laws explain stay on the baseline and
the fork is visible as a divergence rather than as a global reshuffle. This is what makes the picture
read as *your evidence was about two different machines* rather than as a sort.

Reuse `RibbonCanvas`. E08·T05's out-of-scope note is explicit that the three tile states are already
expressible there; a second ribbon drawn for the reveal is the drift `hunch-bench-instruments` exists
to stop.

### The dead stretch

`isDead(tile:)` is `index > t_evidence && !pair.disagrees(on: probePair(at: index))` — tiles probed
after the first contradiction whose verdicts are equally consistent with both laws. Three properties:

- **`t_evidence` itself is never dead.** It is by definition inside `D`.
- **Nothing before the hinge is dead.** Those probes were about a live law.
- **No count, no label** (§7.9). The player sees the length of the useless run and is told nothing
  about it. `deadStretchIsSilent` asserts the composition holds no numeral and no text id.

The mark is `CancelHatch.draw` — the same diagonal already used for unlit Bench cells and inert ramps —
and the opacity is `opacity.cellUnlit`, which is the token behind §7.9's "25 %". Do not write 0.25.

### The morph: one moving part

```swift
public struct MorphPlan: Sendable {
    /// Exactly one, from `DriftPair.editedLeafIndex`. §7.9: "only the edited leaf animates".
    public let animatingLeafIndices: [Int]
    /// Every other leaf. They do not redraw — they *slide down* from L₁'s stack to L₂'s.
    public let slidingLeafIndices: [Int]
    public let lawOneAssemblyDuration: Duration     // 700 ms of the 900 ms morph
    public let stagger: Duration
}
```

`editedLeafIndex` comes from T01 and is carried on the pair precisely so this plan does not have to
re-derive "which part changed" by diffing two ASTs at animation time. §7.9 names the three shapes the
one animation can take — a ramp cell extinguishing while another ignites, a wedge rotating 30°, a gate
cell moving — and they correspond one-to-one with `OneLeafEdit.Kind`, so the `switch` that picks the
animation is over the kind and has no `default:`.

The reason this is the money shot and not decoration: two laws with one visible difference is the
*argument* that the round was solvable. A morph in which everything re-lays-out would say the law was
replaced, which is exactly the reading §7.2's one-leaf-edit decision exists to prevent.

### Reduce Motion

Parts 1–4 become four crossfades of **the same total duration** (§7.9, and `reduce-motion.md` §5 lists
this total among the timings that do not change). What survives:

- **the two-lane geometry** — tiles are still at ±18 pt, they simply arrive by crossfade;
- **the single changed leaf** — still exactly one leaf differs between the two stacks;
- **the hatched dead stretch** and its length;
- **the hold**, unchanged.

Resolve the substitution **once, at the token seam** (`reduce-motion.md` §6): `C.HingeReveal.sheet`
versus `C.HingeReveal.reducedSheet`, chosen by `RenderEnv`, with call sites asking rather than
branching. Eight files each deciding what Reduce Motion means is how a row goes missing.

### Audio and haptics: two cue points, published, not played

§7.9 names two sounds — the seam is a filtered noise sweep, and the morph plays the admit interval
detuned a semitone and then **resolved**, which §7.9 flags as *the only place in the game where
dissonance resolves rather than closes*. That is a design fact worth preserving in the cue's own
doc comment, because a future synthesis pass that "fixes" the detune destroys the one moment the game
has of a machine coming back into tune.

This task ships them as **data**: `HingeRevealCueSchedule.points` with absolute onsets, behind the
`SilentCuePlayer` seam E08·T06 established. E20 attaches the players. Onsets are absolute and the ones
past a shortened sheet are **dropped, not rescheduled** — `reduce-motion.md` §5, and here the totals are
equal anyway, so nothing should drop; the test asserts that.

### The reveal is decoration over settled state

§7.9's first sentence and §6.1's invariant: adjudication commits to disk **before** the animation starts.
So `Round` enters `.hinge` with the settlement already written — Codex page on a win, θ update, Profile
accumulators, novelty ring — and the reveal can be skipped, backgrounded, or replayed from the Codex page
with no consequence. The two tests above are the cheapest possible statement of that, and they are the
reason §7.10's "termination during `hinge` resumes into `settled`" is implementable at all (T09).

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter HingeRevealTests` green, all nineteen tests.
- [ ] `C.HingeReveal.sheet.total == C.HingeReveal.reducedSheet.total`, asserted, and the two recorded simulator durations in `PROGRESS.md` agree.
- [ ] `grep -rn "500\|900\|3000\|18\b\|0\.4\b\|0\.25" Modules/Sources/LoomFeature/HingeReveal*.swift` returns nothing — every number resolves through `C.HingeReveal`.
- [ ] `grep -n "offset" HunchCore/Sources/Tokens/C.swift | grep HingeReveal` shows offsets **computed**, never stored.
- [ ] `MorphPlan.animatingLeafIndices.count == 1` for every pair in the seeded corpus, asserted over all six served bands.
- [ ] `grep -rn "Canvas\|Path(" Modules/Sources/LoomFeature/HingeRevealView.swift` shows no second ribbon drawing; the two-lane layout is `RibbonCanvas`'s.
- [ ] `grep -rn "CancelHatch" Modules/Sources/LoomFeature/` shows the dead stretch calling the shared mark, not drawing diagonals.
- [ ] `DECISIONS.md` records the two unspecified durations, their token names and the resulting total.
- [ ] `tests.json` carries the six entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T08: the hinge reveal — seam, two-lane split, dead stretch and the one-leaf morph"`

## Out of scope

- The 520 ms **DRIFT moment** of §13.7.2 — a different animation inserted into a *round* reveal at local t = 230, owned by **E09·T10** / **E08·T05**. Do not merge the two.
- The four end-of-round sheets (correct / broken / exhausted) and their absolute times — **E09·T10**.
- Synthesising the seam sweep and the detuned-then-resolved morph interval — **E20**; this task publishes their onsets.
- Replaying the reveal from a Codex page — **E15·T05**, which reads `driftPartner` and `driftHinge`.
- The seam **marker** written during play — **T05**; this task only docks to it.
- Persisting the settled state the reveal decorates — **T09**.
- VoiceOver announcements during the reveal — **E19**.
