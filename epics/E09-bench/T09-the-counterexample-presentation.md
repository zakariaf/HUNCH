# T09 — The counterexample presentation

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | §14.1 `Counterexample` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First.** `C.Counterexample` lands here — the 96 pt travel size, the pair spacing, the doubled outline's stroke count, the docked side and the Bench's dim ink. All five are geometry with a §6.8 citation, not values a view may type. |
| `hunch-bench-instruments` | `references/counterexample.md` exists precisely because this is a **composite with no owner** drawn at most once per round — the file lists which part belongs to which skill and owns only the geometry, the four stages and the dock. It also carries the `DoubledOutline` mark and why it is two strokes and never one heavy one. |
| `hunch-motion-and-feedback` | `references/reveal-beats.md` §2 owns the verdict-blind 640 ms hold and §5 owns the first-strike sheet — including the RULING that the `strike` cue and haptic fire at 1,300 on the dock, not at 640, and the standing warning that modelling this as a `RevealPhase` is the mistake. |
| `hunch-shared-marks` | Three marks compose the presentation and each has exactly one owner: `VerdictRing.draw` with the `.counterexample(loomAdmits:)` variant, `GhostFrame.draw` on the leading glyph of a contextual pair, `LinkArc.draw` joining them. A locally drawn ring is a second geometry within a year. |

## Objective

At the end of this task a wrong first declaration is answered: 640 ms of a hold that looks and lasts
exactly the same as a correct one, then 960 ms in which one glyph rises out of the Assay, takes two
rings at once — your verdict and the Loom's, disagreeing — and docks below the ribbon as a marginal
island that stays for the rest of the round. Before this task the incorrect path transitions and shows
nothing; after it, the round's one piece of counter-evidence is on screen, and it is provably the one
§4.5 selected.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.5 | Selection's four steps; the rendering: *"the ribbon stays on screen, the counterexample animates to centre and takes **two rings at once** — the declaration's ring says one verdict, the Loom's outer ring says the other. … In contextual bands it is two glyphs joined by the link arc."* And: *"the law is never revealed"* |
| `GAME_DESIGN.md` | §6.8 | The 640 ms seal beat and why it is verdict-blind: *"identical in content and duration for a correct and an incorrect declaration, so the answer is not readable off the clock"*; the first-strike sheet's four rows at 640 / 640–1,000 / 1,000–1,300 / 1,300–1,600; the two Decisions — **not a probe** (no `probesUsed`, never `prev`, no link arc into the chain) and **auto-collapse with no forced probe** |
| `GAME_DESIGN.md` | §6.1 | `sealing` 640 ms input-locked and verdict-blind; `counterexample` 960 ms input-locked, first strike only; `counterexample —beat completes→ probing`, strikes := 1, Bench collapses, draft preserved |
| `GAME_DESIGN.md` | §13.7.2, §13.11 | The ring idiom — admit expands and stays closed, reject contracts and breaks; under `shouldDifferentiateWithoutColor` the two rings take distinct dash patterns |
| `GAME_DESIGN.md` | §13.8, §13.9 | The `incorrect` cue and the `law.broken` haptic, in **local** offsets that must be converted with `absolute = 640 + local` before scheduling |
| `GAME_DESIGN.md` | §13.12 gate 9 | Nothing translates, scales or rotates under Reduce Motion — so the rise, the travel and the dock all become crossfades between the same three positions |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | *"Selection is core (§4.5 is fully deterministic and testable); the two-ring animation and the 960 ms beat are `LoomFeature`"* — timing constants in the core invite `Task.sleep` into a package whose entire value is that it has no clock |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Create `Modules/Tests/LoomFeatureTests/CounterexamplePresentationTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature

@Suite("Counterexample presentation", .tags(.unit, .presubmission))
@MainActor
struct CounterexamplePresentationTests {

    // §6.8: the hold is verdict-blind — "identical in content and duration for a correct
    // and an incorrect declaration, so the answer is not readable off the clock."
    @Test("The seal hold is identical in duration for both outcomes")
    func holdDurationIsBlind() {
        #expect(SealHold.duration(for: .correct) == C.Reveal.sealHold)
        #expect(SealHold.duration(for: .incorrect) == C.Reveal.sealHold)
    }

    @Test("The seal hold is identical in CONTENT for both outcomes")
    func holdContentIsBlind() {
        // Two sub-beats: the hairline circuit 0–240 lighting 80 ms apart, then the slow
        // ring rotation 240–640. Nothing in either branches on the outcome.
        #expect(SealHold.beats(for: .correct) == SealHold.beats(for: .incorrect))
        #expect(SealHold.beats(for: .correct).map(\.duration).reduce(.zero, +) == C.Reveal.sealHold)
    }

    // §6.8's first-strike sheet: 640 → 1,000 → 1,300 → 1,600, absolute from the Seal press.
    @Test("The first-strike beat is 960 ms and lands at 1,600 ms absolute")
    func strikeBeatTiming() {
        let stages = C.Counterexample.stages
        #expect(stages.map(\.duration).reduce(.zero, +) == .milliseconds(960))
        #expect(C.Reveal.sealHold + .milliseconds(960) == .milliseconds(1_600))
        #expect(C.Counterexample.absoluteOffsets == [.milliseconds(640),
                                                     .milliseconds(1_000),
                                                     .milliseconds(1_300)])
        #expect(stages.count == CounterexampleView.Stage.allCases.count - 1)  // `island` persists
    }

    // §4.5: the two rings DISAGREE, by construction. One Bool, not two Verdicts.
    @Test("The two rings take one Bool, so an agreeing counterexample is unrepresentable")
    func twoRingsOneBool() throws {
        let ce = try #require(Corpora.statelessCounterexample)
        let ring = CounterexampleView.ringState(for: ce)
        #expect(ring == .counterexample(loomAdmits: ce.loomAdmits))
        // The declaration's ring is the negation; there is no third state.
        #expect(CounterexampleView.declarationRingIsClosed(for: ce) == !ce.loomAdmits)
    }

    // §4.5 / §6.8: "In contextual bands it is two glyphs joined by the link arc, the
    // leading one wearing the ghost frame."
    @Test("A contextual counterexample draws a pair, a ghost frame and a link arc")
    func contextualPair() throws {
        let stateless = try #require(Corpora.statelessCounterexample)
        let contextual = try #require(Corpora.contextualCounterexample)

        #expect(CounterexampleView.parts(for: stateless) == [.glyph, .rings])
        #expect(CounterexampleView.parts(for: contextual) == [.contextGlyph, .ghostFrame,
                                                              .linkArc, .glyph, .rings])
        #expect(contextual.context != nil)
        #expect(stateless.context == nil)
    }

    // §6.8's Decision: "the counterexample is NOT a probe. It does not increment
    // `probesUsed`, it does not become `prev`, and it draws below the chain with no link
    // arc into it."
    @Test("A strike leaves the transcript untouched")
    func notAProbe() throws {
        let round = Round.fixture(band: .contextual)
        round.probe(Deck.glyph(id: 7))
        round.probe(Deck.glyph(id: 91))
        let probesBefore = round.probesUsed
        let prevBefore = round.previousProbedGlyph
        let ribbonBefore = round.ribbon

        round.declareIncorrectly()
        round.advanceThroughCounterexampleBeat()

        #expect(round.probesUsed == probesBefore)
        #expect(round.previousProbedGlyph == prevBefore)
        #expect(round.ribbon == ribbonBefore)
        #expect(round.dockedCounterexample != nil)
        #expect(!round.ribbon.contains(round.dockedCounterexample!.glyph))
        #expect(CounterexampleView.drawsChainArc == false)
    }

    // §6.8's second Decision: "the Bench auto-collapses to the Dial after a strike, and
    // there is NO forced probe before re-declaring."
    @Test("The Bench auto-collapses and the player may declare again immediately")
    func autoCollapseNoForcedProbe() {
        let round = Round.fixture(band: .literal)
        round.openBench()
        let draft = round.benchDraft

        round.declareIncorrectly()
        round.advanceThroughCounterexampleBeat()

        #expect(round.phase == .probing)
        #expect(round.isBenchOpen == false)
        #expect(round.benchDraft == draft, "draft preserved")
        #expect(round.canDeclare, "no forced probe")
    }

    // §6.8 / counterexample.md §2: first strike ONLY. The second ends the round and the
    // lost reveal is the sheet that runs.
    @Test("The second strike shows no counterexample")
    func firstStrikeOnly() {
        let round = Round.fixture(band: .literal)
        round.declareIncorrectly()
        round.advanceThroughCounterexampleBeat()
        let firstDock = round.dockedCounterexample

        round.declareIncorrectly()
        #expect(round.phase == .revealing(.broken))
        #expect(round.dockedCounterexample == firstDock, "the island stays; no second one")
    }

    // §13.12 gate 9: the rise, the travel and the dock are three translations, and all
    // three become crossfades between the SAME three positions.
    @Test("Under Reduce Motion nothing translates and both rings survive")
    func reduceMotionSubstitution() throws {
        let ce = try #require(Corpora.contextualCounterexample)
        let reduced = CounterexampleView.plan(for: ce, in: .fixture(isReduceMotionEnabled: true))
        #expect(reduced.transforms.allSatisfy { $0 == .none })
        #expect(reduced.positions.count == 3, "still three positions, reached by crossfade")
        #expect(reduced.parts.contains(.rings))
        #expect(reduced.parts.contains(.linkArc))
        #expect(reduced.islandOutlineStrokes == C.Counterexample.dockedOutlineCount)
    }

    // reveal-beats.md §5's RULING: `strike` fires at 1,300 on the dock, not at 640.
    @Test("The strike cue lands on the dock, not on the verdict")
    func strikeCueOnTheDock() {
        let schedule = CounterexampleCueSchedule.absolute
        #expect(schedule[.incorrect] == .milliseconds(640))
        #expect(schedule[.lawBroken] == .milliseconds(640))
        #expect(schedule[.strike] == .milliseconds(1_300))
    }
}
```

Create `HunchCore/Tests/RoundsTests/CounterexampleFidelityTests.swift` — **the epic's gate row 4**:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import Rounds
import HunchTestSupport

@Suite("Counterexample fidelity", .tags(.unit, .presubmission))
struct CounterexampleFidelityTests {

    // The gate: over a seeded corpus, what the round DOCKS is byte-identical to what §4.5's
    // four-step rule SELECTED. The view never re-selects, never re-orders, never re-picks
    // on a redraw. T21 deviation: parameterise over bands, loop inside.
    @Test("The docked counterexample is exactly the one §4.5 selected", arguments: Band.allCases)
    func presentationQuotesSelection(_ band: Band) throws {
        for index in 0..<Corpora.strikeScenariosPerBand {
            let scenario = Corpora.strikeScenario(band: band, index: index)
            let expected = Counterexample.select(declared: scenario.declared,
                                                 hidden: scenario.hidden,
                                                 ribbon: scenario.ribbon)

            var state = scenario.state
            state = try #require(state.applying(.sealed(.incorrect)))

            guard state.counterexample == expected else {
                Attachment.record(scenario, named: "band\(band.rawValue)-index\(index).json")
                Issue.record("""
                    docked \(String(describing: state.counterexample)) but §4.5 selected \
                    \(String(describing: expected)) — reproduce with \
                    Corpora.strikeScenario(band: .\(band), index: \(index))
                    """)
                return
            }
        }
    }

    // §4.5 step 2: "prefer false negatives — cases the hidden law admits and the
    // declaration rejects." The presentation must therefore usually show `loomAdmits == true`,
    // and the flag must always agree with the hidden law.
    @Test("loomAdmits always agrees with the hidden law", arguments: Band.allCases)
    func loomAdmitsIsTruthful(_ band: Band) throws {
        for index in 0..<Corpora.strikeScenariosPerBand {
            let scenario = Corpora.strikeScenario(band: band, index: index)
            let ce = try #require(Counterexample.select(declared: scenario.declared,
                                                        hidden: scenario.hidden,
                                                        ribbon: scenario.ribbon))
            #expect(ce.loomAdmits == scenario.hidden.admits(ce.glyph, after: ce.context ?? scenario.ribbon.seedGlyph))
        }
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter CounterexampleFidelityTests
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:LoomFeatureTests/CounterexamplePresentationTests
```

`cannot find 'CounterexampleView' in scope` and `type 'RoundState' has no member
'counterexample'` are the right failures.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/LoomFeature/CounterexampleView.swift` — the four stages, the parts, `DoubledOutline` |
| create | `Modules/Sources/LoomFeature/SealHold.swift` — the verdict-blind 640 ms hold, shared by both outcomes |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Counterexample` and its stage durations |
| modify | `HunchCore/Sources/Rounds/RoundState.swift` — `counterexample: Counterexample?` set on `.sealed(.incorrect)` |
| modify | `HunchCore/Sources/LawGeneration/Counterexample.swift` — add `loomAdmits` and `nearestRibbonProbeID` if E06·T08 did not |
| modify | `Modules/Sources/LoomFeature/Round.swift` — the strike path, the dock, the auto-collapse |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — collapse on `counterexample —beat→ probing` |
| create | `Modules/Tests/LoomFeatureTests/CounterexamplePresentationTests.swift` |
| create | `HunchCore/Tests/RoundsTests/CounterexampleFidelityTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `strikeScenario(band:index:)`, `strikeScenariosPerBand`, `statelessCounterexample`, `contextualCounterexample` |
| modify | `tests.json` — the fidelity corpus and the verdict-blind hold |

## Implementation notes

### The hold is verdict-blind, and that is a *shared object*, not two matching objects

`SealHold` is one value used by both outcomes. Not `if correct { hold(640) } else { hold(640) }` —
one `SealHold.beats` array, consulted identically. That is what makes `holdContentIsBlind` a
structural property rather than two branches that happen to agree today.

Three things the hold may not do (`reveal-beats.md` §2): branch on the outcome inside it, shorten
under Reduce Motion (§13.7.4 leaves it alone deliberately), or start prefetching the correct sheet's
assets in a way that changes its length. The last one is real: if the correct path's 256-cell Assay
flood is warmed during the hold and the incorrect path's is not, a player with a slow device can read
the answer off the frame rate.

Its content is two sub-beats: a hairline circuit lighting from each rule-tile through the coupler to
the Seal, 80 ms apart, over 0–240; then a slow ring rotation in the Seal, 240–640, and nothing else.

### This is not a `RevealPhase`

The round **continues**. `counterexample.md` §2 and `reveal-beats.md` §5 both say it: modelling this
as a reveal is the mistake. It reuses no beat numbers, it has its own four-stage enum, and it never
runs twice in a round.

```swift
enum Stage: Hashable, Sendable, CaseIterable { case rising, ringed, docking, island }
```

`island` has no duration — it persists for the rest of the round — which is why
`C.Counterexample.stages` has three entries and the test asserts `allCases.count - 1`.

| Stage | Absolute | Where | Size |
|---|---|---|---|
| rising | 640–1,000 | its own cell in the live Assay → centre; the Bench dims to `C.Counterexample.benchDimInk` | Assay cell → `C.Counterexample.side` |
| ringed | 1,000–1,300 | centre | `C.Counterexample.side` |
| docking | 1,300–1,600 | centre → below the ribbon's trailing end | shrinks to `C.Counterexample.dockedSide` |
| island | rest of the round | below the ribbon, doubled outline | `C.Counterexample.dockedSide` |

### Two rings, one `Bool`

Inner ring = **your declaration's** verdict. Outer ring = **the Loom's**. §4.5 guarantees they
disagree, which is why `VerdictRing`'s variant takes one `Bool` and not two `Verdict`s: a same-verdict
counterexample is not a thing, and making it representable is the first step to drawing one.

The contradiction is legible **with no colour at all** — both rings use the same open/closed aperture
idiom as every probe verdict, so one expands and stays closed while the other contracts and breaks.
Under Differentiate Without Colour they additionally take distinct dash patterns, solid for the Loom
and dashed for yours; that pattern is `hunch-shared-marks`' and is **always on**, not gated on the
setting.

Do not add a third cue, a label, a legend or a colour pair. Three redundant encodings already carry it.

### Below the ribbon, not in it

The island sits **outside** the transcript's own row and keeps its doubled outline for the rest of the
round. That geometry *is* the argument: it is evidence, it is not a probe, and the picture has to say
so without a caption. Docking it *inside* the ribbon reads as a probe the player made.

`DoubledOutline` is `CounterexampleView`'s own mark and its only one, because nothing else in the app
draws one. It lives beside the view as a `draw(into:)` function in the same single-entry shape the
shared marks use, so if a second site ever needs it there is already one thing to move into
`hunch-shared-marks`. **Two strokes, never one heavy one**: at `weight.heavy` a single line reads as a
machined bar, which means *barred*.

The island stays focusable to VoiceOver for the rest of the round. It is the only evidence on screen
the player did not create, and hiding it once it is small would delete it for exactly the users who
cannot see it is still there.

### Four consequences of "not a probe", all enforced in core

It does not increment `probesUsed`; it does not become `prev`; it draws **no link arc into the
chain**; and it is never eligible as the nearest-glyph reference for a later selection. All four are
`HunchCore`'s to enforce — a view that draws a chain arc from it has contradicted the model rather
than decorated it. The reason is §6.8's Decision: *"a player's carefully arranged context should not
be destroyed by their own failure, which has nothing to do with the law."*

### Cues, converted

§13.9's offsets are **local**. Convert every one with `absolute = 640 + local` before scheduling:
`law.broken`'s continuous t 0.020–0.420 is absolute 660–1,060, and its settling transient at t 0.420
is absolute 1,060 — *on the semitone fall*, which is where the `incorrect` cue drops to 138.59 Hz.

`reveal-beats.md` §5's RULING places the `strike` cue and haptic at **1,300**, on the dock, not at 640:
640 already carries `incorrect` + `law.broken`, which are the *verdict*; `strike` is the
*bookkeeping* — dry, mechanical — and belongs on the beat where the strike tick is inscribed and the
Bench collapses. Two hard events on one frame would also blur the face-down discriminability §13.12
gate 12 tests.

Publish them as data — `CounterexampleCueSchedule.absolute: [Cue: Duration]` — for **E20** to attach
players to. Nothing in this task makes a sound.

### Reduce Motion

The rise, the travel and the dock are three translations, and gate 9 forbids translation anywhere.
All three become crossfades **between the same three positions**: the glyph appears at centre, then
appears docked; it never slides. What must survive the substitution because it is information rather
than motion: **both rings at both radii**, **the doubled outline on the island**, and **the pair and
its link arc** in contextual bands. Collapsing to one glyph deletes the context that makes the
counterexample a counterexample.

Write these rows into `reduce-motion.md`'s table in this commit; T12 verifies the table is complete
and does not write missing rows for you.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter CounterexampleFidelityTests` green — the epic's
      gate row 4.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/CounterexamplePresentationTests` green.
- [ ] `grep -n 'RevealPhase' Modules/Sources/LoomFeature/CounterexampleView.swift` returns nothing.
- [ ] `grep -rn 'Counterexample.select\|selectCounterexample' Modules/Sources` returns nothing — the
      view never selects.
- [ ] `grep -n 'if.*correct\|switch.*outcome' Modules/Sources/LoomFeature/SealHold.swift` returns
      nothing — the hold does not branch.
- [ ] `grep -rnE 'Text\(|Label\(' Modules/Sources/LoomFeature/CounterexampleView.swift` returns only
      hits inside `.accessibility*` modifiers.
- [ ] `reduce-motion.md`'s table has rows for the rise, the travel and the dock, and
      `MotionRow.allCases` (T12) contains all three.
- [ ] `tests.json` carries `counterexample.presentation-quotes-selection` and
      `seal.hold-is-verdict-blind`.
- [ ] In the simulator, at band 5: declare wrong, watch the pair rise with the ghost frame on the
      leading glyph, take two rings, and dock below the ribbon — then declare again with no probe in
      between.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter CounterexampleFidelityTests && xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:LoomFeatureTests/CounterexamplePresentationTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T09: the verdict-blind hold and the 960 ms counterexample beat"`

## Out of scope

- **Selection.** §4.5's four steps are **E06·T08**, pure and already tested. This task asserts the
  presentation quotes it and never re-runs it.
- **The correct, lost and exhausted sheets.** **T10**. This task ships only the shared hold and the
  first-strike beat.
- **DRIFT's dead-law counterexample** — the step 0 that prefers a ribbon glyph whose verdict differs
  under `L₁` and `L₂`, rendered as the twin ring. **E12·T06**.
- **The *Counterexample* rotor** and the announcement's wording. **E19·T05**; §13.12 gate 6 asserts
  the rotor is **absent** before the strike, so an always-present rotor with an empty body fails.
- **Attaching audio and haptic players.** **E20·T01**. This task publishes the schedule.
- **Persisting the docked counterexample across a suspend** (`ProbeSnapshot.counterexample`).
  **E10·T02**; the value type is E07·T09's.
