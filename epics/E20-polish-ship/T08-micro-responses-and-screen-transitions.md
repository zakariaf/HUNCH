# T08 — Micro-responses and screen transitions

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | Micro-responses + transitions (ART / MOTION) · Reduce Motion table · §13.12 gate 9 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | This is the skill's whole subject in one task. `references/verdict-motion.md` §1 is the three-clock frame the six attachment points hang on, §2/§3 the two rings, §5 the twin at ×0.7 with its ×0.72 gain and +60 ms haptic offset, §6 the DRIFT moment as **one** continuous 0–700 ms event over three visual parts, §7 SIEVE's four outcomes and the two silences, §8 the barred Seal. `references/transitions.md` §1 is the six-row table that "contains no numbers, and that is the test that it is written correctly". `references/reduce-motion.md` §2 declares itself the complete substitution table and §7 gives the two tests that keep it honest. |
| `hunch-design-tokens` | Every duration and easing in both tables is an L1 token, and `references/durations-and-easing.md` §2 is their one home — including the six `dur.reduceMotion*` tokens, four of which were bare numbers in §13.7.4. Check 9 fails the build on a literal, and the skill's own warning applies at every row here: never borrow a same-valued token that means something else (`dur.ringAdmit` is 200 and so is `dur.reduceMotionExpand`). |
| `hunch-accessibility` | `references/environment-settings.md` §7 keeps exactly two Reduce Motion facts on the accessibility side and both are this task's: **gate 9's wording** — *nothing translates, scales or rotates anywhere, including SIEVE* — and the fact that Reduce Motion and VoiceOver are independent axes that must compose. It also owns the rule that the announcement is posted by the **view** on the same frame as the cue, never from inside a `CuePlayer`. |

## Objective

At the end of this task every micro-response in §13.7.2 fires its cue and its haptic on the frame the
picture lands on — admit, reject, twin at ×0.7 amplitude, the DRIFT moment, the SIEVE tap and the
barred Seal — none of them blocking input and none of them over 260 ms; the six screen transitions of
§13.7.3 exist as a value that names a token per row and contains no number; and §13.7.4's substitution
table has been re-verified **row by row against every animation the app now ships**, mechanically by a
registry the compiler enumerates, textually by a script that diffs the registry against the table, and
by hand, recorded, because §13.12 gate 9 is a hand audit and always was.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.7 | the budget: at most one animation over 260 ms per screen state; the play surface has exactly **two** recurring animations, both under 260 ms, neither blocking input |
| `GAME_DESIGN.md` | §13.7.2 | admit (260 ms), reject (250 ms), twin at 0.7 × amplitude, the DRIFT moment (520 ms inserted at reveal-local t = 230), SIEVE's tap response inside 120 ms, the barred Seal's 3 × 90 ms rail pulse — and the Decision that the non-colour encoding is ring direction and closure |
| `GAME_DESIGN.md` | §13.7.3 | the six transitions and their durations |
| `GAME_DESIGN.md` | §13.7.4 | *"Every animation in the app appears here"* — the completeness claim this task turns into a test |
| `GAME_DESIGN.md` | §13.12 gate 9 | *"Reduce Motion on: nothing translates, scales or rotates anywhere, including SIEVE; every substitution in §13.7.4 verified by hand"* |
| `GAME_DESIGN.md` | §6.5 | the 420 ms verdict beat, 320 ms under Reduce Motion, the constant 260 ms adjudication hold, the single-slot input queue and the Seal's absence of one |
| `GAME_DESIGN.md` | §9.5, §9.8 | SIEVE's four outcomes, the gate band as the only actionable region, and the substitution that keeps four stations |
| `GAME_DESIGN.md` | §13.8, §13.9 | which cue and which pattern each point fires — **consumed, never restated** |
| `.claude/skills/hunch-motion-and-feedback/references/verdict-motion.md` | §1–§8, §11, §13 | the beat, the six points, the Reduce Motion column and the thirteen wrongs |
| `.claude/skills/hunch-motion-and-feedback/references/transitions.md` | §1–§5, §9 | the six rows, the one interactive drag, the exactly-two shared elements, scene phase, the substitutions |
| `.claude/skills/hunch-motion-and-feedback/references/reduce-motion.md` | §2–§7, §9 | the complete table, the four newly named tokens, the SIEVE ruling, the invariant timings, the token seam, the two tests |
| `ios-swift-guide/06-TESTING.md` | `T21`, `T22`, `T29` | parameterise over the registry rather than looping; the Cartesian trap; same-named tags across modules |

**What already exists, and is not re-authored.** Every animation this task audits was written by the
epic that owns its surface: the verdict rings (E08·T06), the reveal and the strike (E09·T09/T10/T12),
the DRIFT hinge (E12·T08), ECHO's cast (E13·T04/T09), SIEVE's lane (E14·T10), the streak bloom
(E16·T10), the scene-phase spin-up (E17·T09). **This task attaches feedback to them and audits them;
it does not re-time them.** If a duration changes here, something is wrong upstream.

## TDD — the test comes first

Three suites and one script, and the script exists because the completeness claim is a claim about a
*markdown table* and a *Swift enum* agreeing — which no test bundle can see.

**Step 1a — write the failing tests.** Create `Modules/Tests/HunchUITests/MotionRowTests.swift`:

```swift
import Testing
import Tokens
@testable import HunchUI

@Suite("§13.7.4 — every animation has a substitution and none of them moves",
       .tags(.unit, .presubmission))
struct MotionRowTests {

    // MARK: gate 9's mechanical half

    @Test("every row declares a substitution", arguments: MotionRow.allCases)
    func substitutionExists(_ row: MotionRow) {
        #expect(row.substitution != nil, "\(row) ships with no Reduce Motion row")
    }

    @Test("no substitution translates, scales or rotates — gate 9, verbatim",
          arguments: MotionRow.allCases)
    func nothingMoves(_ row: MotionRow) throws {
        let substitution = try #require(row.substitution)
        #expect(substitution.transform == .none)
        // A geometry match is a translation AND a scale wearing a modifier's name.
        #expect(substitution.usesMatchedGeometryEffect == false)
        // "Shortened" is not "substituted": a 50 ms drag is still a drag.
        #expect(substitution.kind != .shortenedNormal)
    }

    @Test("every substitution's duration is one of the six sanctioned tokens, or instant",
          arguments: MotionRow.allCases)
    func durationsAreTokens(_ row: MotionRow) throws {
        let substitution = try #require(row.substitution)
        let sanctioned: Set<Duration?> = [
            Dur.reduceMotionReveal, Dur.reduceMotionRing, Dur.reduceMotionSwap,
            Dur.reduceMotionStrike, Dur.reduceMotionExpand, Dur.reduceMotionMorph,
            Dur.crossfade, Dur.micro, nil,          // nil == instant / removed
        ]
        #expect(sanctioned.contains(substitution.duration))
    }

    // MARK: the rows that are geometry rather than timing — the two easiest to get wrong

    @Test("the static closed admit ring is at 1.18 R, not at 1.35 R")
    func theSettledRadiiAreTheSettledOnes() {
        #expect(MotionRow.admitRing.substitution?.frozenRadius == C.VerdictRing.settledAdmitRadius)
        #expect(MotionRow.rejectRing.substitution?.frozenRadius == C.VerdictRing.settledRejectRadius)
        #expect(C.VerdictRing.settledAdmitRadius < C.VerdictRing.transientAdmitRadius)
    }

    // MARK: timing that does not change

    @Test("the holds, the onsets and SIEVE's schedule are identical with the setting on and off")
    func invariantTiming() {
        #expect(C.Reveal.sealHold(reduceMotion: true) == C.Reveal.sealHold(reduceMotion: false))
        #expect(C.Verdict.adjudicationHold(reduceMotion: true)
                == C.Verdict.adjudicationHold(reduceMotion: false))
        // The one timing that DOES change: the input lock, 420 → 320 (§6.5).
        #expect(C.Verdict.inputLock(reduceMotion: true) < C.Verdict.inputLock(reduceMotion: false))
    }

    @Test("an onset past the shortened reveal is dropped, never rescheduled")
    func droppedNotRescheduled() {
        let full = RevealCueSchedule.absolute(for: .inscribed, marks: 3, reduceMotion: false)
        let short = RevealCueSchedule.absolute(for: .inscribed, marks: 3, reduceMotion: true)
        let end = C.Reveal.reduceMotionEnd
        #expect(short.allSatisfy { $0.0 <= end })
        #expect(short == full.filter { $0.0 <= end })     // a filter, not a remap
    }

    // MARK: completeness, from the Swift side

    @Test("every surface that animates is represented, and no row is orphaned")
    func theRegistryIsClosed() {
        #expect(MotionRow.allCases.count == MotionRow.declaredRowNames.count)
        #expect(Set(MotionRow.allCases.map(\.rowName)) == MotionRow.declaredRowNames)
        #expect(MotionRow.allCases.allSatisfy { !$0.owningFile.isEmpty })
    }
}
```

Then `Modules/Tests/LoomFeatureTests/MicroResponseCueTests.swift`, which is where the six attachment
points get pinned:

```swift
import Testing
import HunchCore
import Feedback
@testable import LoomFeature

@Suite("The six micro-responses fire on their own frames — §13.7.2", .tags(.unit, .presubmission))
@MainActor
struct MicroResponseCueTests {

    private func recorder() -> (RecordingCuePlayer, Round) {
        let cues = RecordingCuePlayer()
        return (cues, Round.fixture(band: .contextual, cues: cues))
    }

    @Test("admit and reject fire one cue each, at the verdict frame and not at the beat's start")
    func theVerdictFrame() {
        let (cues, round) = recorder()
        round.probe(Glyph.fixtureAdmitted)
        #expect(cues.cues == [.probeSubmit, .verdict(.admit, isTwin: false)])
        #expect(cues.onsets[0] == .zero)                                  // key depress, t = 0
        #expect(cues.onsets[1] == C.Verdict.adjudicationHold(reduceMotion: false))  // t = 260
    }

    @Test("a twin is one cue carrying isTwin, never a second cue layered on the verdict")
    func twinIsOneCue() {
        let (cues, round) = recorder()
        round.probe(Glyph.fixtureAdmitted)
        cues.reset()
        round.probeTwin()
        #expect(cues.cues == [.probeSubmit, .verdict(.admit, isTwin: true)])
        #expect(cues.cues.contains(.verdict(.admit, isTwin: false)) == false)
    }

    @Test("the twin's animation runs at 0.7 amplitude and its cue at the table's own gain")
    func twinAmplitude() {
        #expect(C.Verdict.twinAmplitude == 0.7)
        // The ×0.72 gain and the +60 ms haptic prefix are §13.8/§13.9's and are asserted in
        // FeedbackTests; here we only assert this surface does not apply a second scaling.
        #expect(C.Verdict.twinAmplitude != CueTable.twinGainScalar)
    }

    @Test("the DRIFT moment fires one cue across all three visual parts, at absolute t = 870")
    func driftIsOneGesture() {
        let (cues, round) = recorder()
        round.revealHinge()
        #expect(cues.cues.filter { $0 == .driftMoment }.count == 1)
        #expect(cues.onsets[cues.cues.firstIndex(of: .driftMoment)!] == .milliseconds(870))
    }

    @Test("SIEVE: a hit and a miss speak, a correct pass and an out-of-band tap do not")
    func sieveIsMostlySilent() {
        let (cues, run) = SieveRun.fixture()
        run.tapGate(at: .lawful);        #expect(cues.cues.last == .sieveHit)
        cues.reset(); run.passUnlawful(); #expect(cues.cues.isEmpty)      // silence is the reward
        cues.reset(); run.tapOutsideBand(); #expect(cues.cues.isEmpty)    // a fumble costs nothing
        cues.reset(); run.missLawful();  #expect(cues.cues.last == .sieveMiss)
        cues.reset(); run.arriveGlyph(); #expect(cues.cues == [.sieveTick])
    }

    @Test("the barred Seal fires `bar` from both of its two sites and nothing else moves")
    func theBarredSeal() {
        let (cues, round) = recorder()
        round.pressSeal()                                  // rails empty ⇒ barred
        #expect(cues.cues.last == .bar)
        #expect(round.sealBar != nil)
        cues.reset()
        FrameModel.fixture().pressBarredModeKey(.drift)    // §12.4, the identical drawing
        #expect(cues.cues.last == .bar)
    }

    // MARK: the budget

    @Test("every micro-response is under 260 ms and none of them gates input")
    func theBudget() {
        for row in MotionRow.microResponses {
            #expect(row.normalDuration <= Dur.admit)                     // 260 ms
            #expect(row.blocksInput == false)
        }
        // §13.7: the play surface has exactly two RECURRING animations.
        #expect(MotionRow.recurringOnPlaySurface.count == 2)
    }

    @Test("the rings outlive the input lock, which is what 'never blocking' means")
    func decorationOutlivesTheLock() {
        #expect(C.Verdict.adjudicationHold(reduceMotion: false) + Dur.ringAdmit
                > C.Verdict.inputLock(reduceMotion: false))
    }
}
```

And `Modules/Tests/HunchUITests/TransitionCatalogueTests.swift`:

```swift
import Testing
import Tokens
@testable import HunchUI

@Suite("§13.7.3 — six transitions, each naming a token", .tags(.unit, .presubmission))
struct TransitionCatalogueTests {

    @Test("there are exactly six, and they are §13.7.3's six")
    func theSix() {
        #expect(TransitionCatalogue.all.count == 6)
        #expect(Set(TransitionCatalogue.all.map(\.id)) == [
            .homeToMode, .dialToBench, .assayToInspector,
            .revealToCodexPage, .roundEndToNextRound, .anyToSettings,
        ])
    }

    @Test("every row names a token — the table contains no number", arguments: TransitionCatalogue.all)
    func everyRowIsTokenised(_ transition: Transition) {
        switch transition.timing {
        case .token(let duration, let easing):
            #expect(Dur.allTokens.contains(duration))
            #expect(Easing.allTokens.contains(easing))
        case .system:
            #expect(transition.id == .anyToSettings)      // the one stock presentation
        }
    }

    @Test("the two shared elements are the only two, and both are removed under Reduce Motion")
    func exactlyTwoSharedElements() {
        let shared = TransitionCatalogue.all.filter(\.usesMatchedGeometryEffect)
        #expect(shared.map(\.id) == [.assayToInspector, .revealToCodexPage])
        for transition in shared {
            #expect(transition.reduced.usesMatchedGeometryEffect == false)
        }
    }

    @Test("the Dial↔Bench drag is substituted by a control, not by a shorter drag")
    func theDragIsReplaced() {
        let drag = TransitionCatalogue.dialToBench
        #expect(drag.isInteractive)
        #expect(drag.reduced.isInteractive == false)
        #expect(drag.reduced.handleBecomesPlainButton)
        #expect(drag.reduced.timing == .token(Dur.crossfade, .easeInOut))
    }

    @Test("the round-end crossfade goes through ground.base, not ground.raised")
    func throughTheRoom() {
        #expect(TransitionCatalogue.roundEndToNextRound.crossfadeGround == \Palette.ground.base)
    }
}
```

**Step 1b — write the failing script.** `Scripts/check-motion-rows.sh` diffs
`reduce-motion.md` §2's table against `MotionRow`'s cases. It needs a markdown parse, so it is a
standalone program rather than another grep, exactly as `source-hygiene.md` §7 rules for
`check-inventory.sh`. It reuses that file's `prose()` helper so a fenced example is not mistaken for a
row. Prove it before writing it — `/tmp/prove-motion-rows.sh`, scratch:

```bash
#!/bin/bash
set -uo pipefail
probe() { eval "$2"
  if Scripts/check-motion-rows.sh >/tmp/m.out 2>&1; then echo "$1: MISSED"; else echo "$1: CAUGHT"; fi
  eval "$3"; }

# A row in the table with no case in Swift — the "we forgot to substitute it" failure.
probe 'table row with no Swift case' \
  'printf "\n| a new pulse | 300 ms | 200 ms crossfade |\n" >> .claude/skills/hunch-motion-and-feedback/references/reduce-motion.md' \
  'git checkout -- .claude/skills/hunch-motion-and-feedback/references/reduce-motion.md'

# A case in Swift with no row in the table — the "we shipped an animation and never wrote its row" failure.
probe 'Swift case with no table row' \
  'sed -i "" "s/case grainShimmer/case grainShimmer, newUndocumentedPulse/" Modules/Sources/HunchUI/MotionRow.swift' \
  'git checkout -- Modules/Sources/HunchUI/MotionRow.swift'

# A row silently renamed on one side only.
probe 'renamed row' \
  'sed -i "" "s/| admit ring |/| admit halo |/" .claude/skills/hunch-motion-and-feedback/references/reduce-motion.md' \
  'git checkout -- .claude/skills/hunch-motion-and-feedback/references/reduce-motion.md'

# The legal spellings must NOT be caught.
Scripts/check-motion-rows.sh >/dev/null 2>&1 && echo 'clean: OK' || echo 'clean: FALSE POSITIVE'
# A fenced code block that happens to contain a pipe table is an EXAMPLE, not a row.
printf '\n```\n| not a row | x | y |\n```\n' >> .claude/skills/hunch-motion-and-feedback/references/reduce-motion.md
Scripts/check-motion-rows.sh >/dev/null 2>&1 && echo 'fenced example: OK' || echo 'fenced: FALSE POSITIVE'
git checkout -- .claude/skills/hunch-motion-and-feedback/references/reduce-motion.md
```

**Step 2 — run them and watch them fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" \
  -only-testing:HunchUITests/MotionRowTests \
  -only-testing:HunchUITests/TransitionCatalogueTests \
  -only-testing:LoomFeatureTests/MicroResponseCueTests | xcbeautify
bash /tmp/prove-motion-rows.sh
```

Expect `cannot find 'MotionRow' in scope`, `cannot find 'TransitionCatalogue' in scope`, and `MISSED`
on every script line. Three failures to read rather than fix reflexively:

- **`nothingMoves` failing on a row you did not write** means an earlier epic shipped an animation
  whose substitution shortens rather than replaces. Fix it in that epic's file, on this branch, and say
  which file in the commit body — that is the whole point of running this sweep last.
- **`theBudget` failing on `recurringOnPlaySurface.count == 2`** means a third recurring animation
  reached the play surface. §13.7 says there are two. The fix is deletion, not a bigger constant.
- **`droppedNotRescheduled` failing** means someone compressed the reveal's onsets into the shortened
  window instead of filtering them. That is `reduce-motion.md` §9's named wrong and it produces a
  second event, not the same one.

**Step 3 — implement.** The registry first, then the attachment points, then the catalogue, then the
script.

**Step 4 — green, then look at it.** Gate 9 is a hand audit and no registry replaces it. Turn Reduce
Motion on, on a device, and walk every row: a full PROBE round with a twin and a strike, a correct
reveal, a DRIFT hinge, an ECHO cast, a SIEVE run, the Codex drill-down, the Profile, the Frame. Record
what you saw in `PROGRESS.md`, row by row.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/MotionRow.swift` — the registry: one case per §13.7.4 row, each with its substitution, its owning file and its normal duration |
| create | `Modules/Sources/HunchUI/TransitionCatalogue.swift` — §13.7.3's six as values |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `cues.play(_:)` at the verdict frame, the twin, the barred Seal |
| modify | `Modules/Sources/LoomFeature/DriftHinge.swift` — one `drift.moment` at absolute 870 |
| modify | `Modules/Sources/LoomFeature/SieveRun.swift` — `sieveTick` on arrival, `sieveHit`/`sieveMiss` on resolution, silence on a correct pass and outside the band |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — the six transitions read from the catalogue |
| create | `Scripts/check-motion-rows.sh` |
| modify | `.github/workflows/ci.yml` — the checker as its own named step |
| create | `Modules/Tests/HunchUITests/MotionRowTests.swift` |
| create | `Modules/Tests/HunchUITests/TransitionCatalogueTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/MicroResponseCueTests.swift` |
| modify | `PROGRESS.md` — §Motion: the row-by-row hand audit, dated, with the build number |
| modify | `tests.json` — `motion.reduce-motion-rows`, `motion.micro-response-cues`, `motion.transition-tokens`, and gate 9's hand audit as `manual` |

## Implementation notes

### The registry is the deliverable

§13.7.4 opens with a claim — *"Every animation in the app appears here"* — and a claim in prose is a
claim nobody can check. `MotionRow` is that sentence as an enum:

```swift
/// One case per row of `hunch-motion-and-feedback/references/reduce-motion.md` §2, which is
/// §13.7.4 plus the four rows that lived only in component files until it absorbed them.
/// `Scripts/check-motion-rows.sh` diffs the two, so a row added to either side without the
/// other fails the build rather than going missing.
public enum MotionRow: String, CaseIterable, Hashable, Sendable {
    case revealCorrect, revealLost
    case admitRing, rejectRing, throatScale, throatSubmitContraction, throatRegisterCrossfade
    case rejectShudder, ribbonTileSlideIn, ribbonAutoScroll
    case dialToBench, assayExpand, assayCellMorph, codexSharedElement, screenPush
    case driftMoment, sealMarksStrikeIn, keyDepression, streakBloom, profileMorph
    case barredRailPulse, emptyRailPulse, tallyDialCollapse, idleLoom
    case grainShimmer, bloomPulseOnAdmit
    case sieveGlyphTravel

    public struct Substitution: Hashable, Sendable {
        public enum Kind: Hashable, Sendable {
            case crossfade, instant, removed, controlReplacesGesture, staticState
            /// Present only so a test can reject it. Never construct one.
            case shortenedNormal
        }
        public enum Transform: Hashable, Sendable { case none, translate, scale, rotate }
        public var kind: Kind
        public var duration: Duration?          // nil == instant or removed
        public var transform: Transform         // gate 9: must be `.none`, every row
        public var usesMatchedGeometryEffect: Bool
        public var frozenRadius: Double?        // the two ring rows only
    }

    public var substitution: Substitution? { … }   // one exhaustive switch, no `default:`
    public var normalDuration: Duration { … }
    public var blocksInput: Bool { … }
    public var owningFile: String { … }            // "E14·T10 — SieveLaneView.swift"
}
```

Four things it buys that a comment does not:

- **`Transform.none` on every row is gate 9, mechanically.** The gate's wording is *nothing translates,
  scales or rotates anywhere*, and that is a property of each substitution rather than of the app.
- **`shortenedNormal` exists to be rejected.** It is the one `Kind` nothing may construct, so the
  wrong answer has a name and a failing test rather than being a shape nobody thought to look for.
- **`owningFile` makes a failure actionable.** When `nothingMoves` goes red on `profileMorph`, the
  message names E16·T10's file and the fix is one file away.
- **`sieveGlyphTravel` is a row like any other**, and its substitution is `.crossfade` with
  `transform: .none` — the lane keeps four stations, the cadence is byte-identical, and the preview
  count is unchanged. E14·T10 already ships the invariant test; this registry just refuses to let the
  row be quietly absent.

### The six attachment points, one line each

Every one of these is a `cues.play(_:)` call at a beat that already exists. **No beat moves.**

| Point | Cue | Where it goes | The thing to get right |
|---|---|---|---|
| admit | `.verdict(.admit, isTwin: false)` | `Round.land(_:isTwin:)`, at t = 260 | same statement as `withAnimation`, so the ring, the cue, the haptic and the VoiceOver utterance are one frame |
| reject | `.verdict(.reject, isTwin: false)` | the same call site | one call site, both verdicts — two branches is two chances to diverge |
| twin | `.verdict(_, isTwin: true)` | the same call site with `isTwin` threaded | **one** cue, not a verdict cue plus a twin cue; the ×0.72 gain and the +60 ms haptic prefix are the players' business |
| DRIFT moment | `.driftMoment` | `DriftHinge`, absolute t = 870 | **one** cue across all three visual parts — the pitch slides and the sensation slides with it; three cues would be three onsets |
| SIEVE | `.sieveTick` / `.sieveHit` / `.sieveMiss` | `SieveRun`, on arrival and on resolution | a **correct pass fires nothing** and a tap outside the band fires nothing |
| barred Seal | `.bar` | `Round.pressSeal()` and `FrameModel.pressBarredModeKey(_:)` | two sites, one cue — §12.4 says the barred mode key is *the identical drawing*, so it is the identical sound |

`probe.submit` is already wired (E08·T06) and is listed here only so the count in
`MicroResponseCueTests` reads correctly.

The one rule that governs all six: **the model commits before the animation starts.** `Round` mutates,
the snapshot is scheduled, *then* `cues.play(_:)` and `withAnimation` run. A cue fired from an
animation's completion handler is a cue that does not fire when the animation is skipped, and the
reveal is skippable from absolute 1,040 ms.

### "Under 260 ms and none blocking input" — two different claims

They are constantly conflated and `verdict-motion.md` §13 lists the conflation as a wrong.

- **Under 260 ms** is about the *pictures*: `Dur.admit` is 260 and `Dur.reject` is 250, and §13.7's
  budget is one animation over 260 ms per screen state — the reveal is that one, everything else is
  under.
- **Non-blocking** is about *input*, and input is §6.5's: locked 0–420 ms (320 under Reduce Motion),
  single-slot queue on PROBE and twin, **no queue on the Seal**. The rings finish at 520 ms, a hundred
  milliseconds after the lock lifts, and that overhang is the design rather than a bug.

`decorationOutlivesTheLock` asserts the overhang exists, which is the only way to catch someone
"fixing" it by shortening the ring to the lock.

### The transitions are a value because §13.7.3 is a table with no numbers in it

`transitions.md` §1 says it outright: *"This table contains no numbers, and that is the test that it is
written correctly."* So the catalogue is a value whose every row names a token, and
`everyRowIsTokenised` is that sentence:

```swift
public struct Transition: Hashable, Sendable, Identifiable {
    public enum Timing: Hashable, Sendable {
        case token(Duration, Easing)
        case system                                  // Settings, and only Settings
    }
    public var id: ID
    public var timing: Timing
    public var isInteractive: Bool
    public var usesMatchedGeometryEffect: Bool
    public var crossfadeGround: KeyPath<Palette, RGB8>?
    public var reduced: Reduced
}
```

Three rows carry a fact that is easy to lose:

- **`anyToSettings` is `.system`** and must stay stock. `transitions.md` §1: do not hand-roll it, do
  not add a custom transition, do not give it a `ground` crossfade. It is one of only three places
  stock components appear at all.
- **`roundEndToNextRound` crossfades through `ground.base`**, not `ground.raised` — the fade goes
  *through the room*, so the machine reads as having been dark between rounds. Through the raised
  ground it reads as a page turn.
- **`dialToBench` is the only interactive transition in the app**, it follows the finger, it is
  interruptible, and it resolves by *velocity*. Its substitution replaces the gesture with a plain
  button; `theDragIsReplaced` asserts both halves because shortening it is the reflex.

### `Scripts/check-motion-rows.sh`

```bash
#!/bin/bash
# Scripts/check-motion-rows.sh — §13.7.4's completeness claim, as a diff.
#
# reduce-motion.md §2 declares itself the complete substitution table. MotionRow.swift is that
# table as an enum. Neither can prove the other complete; the DIFF can. A row on one side only
# is either an animation with no substitution (gate 9's failure) or a substitution for an
# animation that no longer exists (a stale row nobody will notice).
#
# Run from the repo root.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$PWD}"
table="$root/.claude/skills/hunch-motion-and-feedback/references/reduce-motion.md"
swift_file="$root/Modules/Sources/HunchUI/MotionRow.swift"
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# Shared with check-inventory.sh / check-symbols.sh / check-skills.sh: a fenced block is an
# EXAMPLE, not a row. Blank the fenced lines rather than deleting them so line numbers hold.
prose() {
    awk '/^[[:space:]]*```/ { fence = !fence; print ""; next }
         /CHECK-EXEMPT/     { print ""; next }
         { print (fence ? "" : $0) }' "$1"
}

[ -f "$table" ] || { echo "No $table — nothing to check."; exit 0; }
[ -f "$swift_file" ] || { echo "No $swift_file yet — nothing to check."; exit 0; }

# §2's rows: pipe-table lines between the "## 2." heading and the next "## " heading, first cell
# stripped of emphasis. The header and the separator row drop out because they have no letters
# in the first cell or are all dashes.
rows=$(prose "$table" | awk '
  /^## 2\./ { inside = 1; next }
  /^## /    { inside = 0 }
  inside && /^\|/ {
    line = $0
    sub(/^\|[[:space:]]*/, "", line)
    sub(/[[:space:]]*\|.*$/, "", line)
    gsub(/\*\*/, "", line)
    gsub(/`/, "", line)
    if (line !~ /^-+$/ && line != "" && line != "Animation") print tolower(line)
  }')

# The Swift side declares its own row names so the mapping is explicit and reviewable rather
# than a camelCase-to-prose guess: `case admitRing  // row: admit ring`.
cases=$(grep -oE '// row: .*$' "$swift_file" | sed 's|// row: ||' | tr '[:upper:]' '[:lower:]')

missing_in_swift=$(comm -23 <(printf '%s\n' "$rows" | sort -u) <(printf '%s\n' "$cases" | sort -u))
missing_in_table=$(comm -13 <(printf '%s\n' "$rows" | sort -u) <(printf '%s\n' "$cases" | sort -u))

[ -n "${missing_in_swift//[[:space:]]/}" ] && report \
  'Row in reduce-motion.md §2 with no MotionRow case (an animation with no substitution):' \
  "$missing_in_swift"
[ -n "${missing_in_table//[[:space:]]/}" ] && report \
  'MotionRow case with no row in reduce-motion.md §2 (a substitution nobody wrote down):' \
  "$missing_in_table"

[ "$status" -eq 0 ] && echo "Motion rows: clean ($(printf '%s\n' "$rows" | grep -c .) rows)"
exit "$status"
```

`comm` needs sorted input and the `sort -u` on both sides is what makes a renamed row show up as one
line on each list — which is more useful than a diff that silently pairs them.

It is a standalone program and not a numbered check because it parses a markdown table;
`hunch-build-and-ci/SKILL.md`'s "to add a gate" step 2 is the rule, and `source-hygiene.md` §7 is the
precedent. It joins the CI ladder next to `check-inventory.sh`, with **no** `continue-on-error`.

### The hand audit is the gate, and the registry is not a substitute for it

§13.12 gate 9 says *verified by hand*, and it says so because a registry can only assert what someone
thought to model. Walk it with Reduce Motion on, on a device, in this order, and write one line per row
into `PROGRESS.md`:

1. A full PROBE round: admit, reject, a twin, a barred Seal press, a strike, a correct declaration.
2. The reveal at both outcomes, and the 640 ms seal hold — which is **not** shortened, and if it feels
   shortened someone made the verdict readable off the clock.
3. A DRIFT hinge; an ECHO cast; a SIEVE run at band 6 tempo 3.
4. Codex root → shelf → page, and back; Profile; Statistics; Settings → About.
5. The Frame's idle Loom: the drift stops, the 8 s crossfade **stays**.
6. Background and return, in PROBE and in SIEVE.

What you are looking for is anything that moves: a slide, a zoom, a spring, a scale, a rotation, a
geometry match, a drag. "Reviewed, nothing moves" is a legitimate entry. "Not reviewed" is not.

### Reduce Motion and VoiceOver are independent axes

`environment-settings.md` §7's second fact, and it bites in exactly one place: SIEVE's crossfade
substitution and SIEVE's VoiceOver step pacing can both be on, and they must compose. Check it during
the hand audit with both enabled — the lane still has four stations, the gate still announces on
entry, and the dwell is byte-identical. Neither setting is allowed to change a hit window.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/MotionRowTests` green, all six tests, with a non-zero case count (the two `HunchUITests` targets collide by name — check the run summary).
- [ ] `xcodebuild test … -only-testing:HunchUITests/TransitionCatalogueTests` green, all five; `…-only-testing:LoomFeatureTests/MicroResponseCueTests` green, all eight.
- [ ] `bash /tmp/prove-motion-rows.sh` prints `CAUGHT` on all three plants, `OK` on the clean tree, and `OK` on the fenced example.
- [ ] `Scripts/check-motion-rows.sh` is in `.github/workflows/ci.yml` as its own named step with no `continue-on-error`.
- [ ] `MotionRow.substitution` is one exhaustive `switch` with no `default:`, and `Substitution.Kind.shortenedNormal` is constructed nowhere: `grep -rn 'shortenedNormal' Modules/Sources | wc -l` → `1` (the declaration).
- [ ] `grep -rn 'matchedGeometryEffect' Modules/Sources --include='*.swift'` returns exactly two call sites, both guarded by `!env.isReduceMotionEnabled`.
- [ ] `grep -rn 'withAnimation\|\.animation(' Modules/Sources --include='*.swift' | grep -vE 'env\.animation|Easing\.' ` returns nothing — every animation goes through the token seam (`reduce-motion.md` §6).
- [ ] `bash Scripts/check-source-hygiene.sh` green — check 9 sees no literal duration, easing or spring anywhere in the diff.
- [ ] `grep -rn 'cues.play' Modules/Sources/LoomFeature | wc -l` matches the point count, and every call sits beside its `withAnimation`, not inside a completion handler.
- [ ] `PROGRESS.md` §Motion carries the row-by-row hand audit with a date and a build number, one line per §13.7.4 row, and names the device.
- [ ] `tests.json` carries `motion.reduce-motion-rows`, `motion.micro-response-cues` and `motion.transition-tokens` with commands, and §13.12 gate 9's hand audit as `manual` with `PROGRESS.md` as its home.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Reject any suggestion that deletes `Substitution.Kind.shortenedNormal` as dead code: it is a value that exists to be asserted against, and removing it removes the test. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T08: cues on the six micro-responses, the six transitions as tokens, and §13.7.4 re-verified row by row"`

## Out of scope

- **Every animation itself.** The verdict rings — **E08·T06**; the reveal, the strike and the counterexample — **E09·T01/T09/T10/T12**; the DRIFT hinge — **E12·T08**; ECHO — **E13·T04/T09**; SIEVE's lane and its preview/window invariant — **E14·T10**; the streak bloom — **E16·T10**; the scene-phase spin-up — **E17·T09**. This task attaches, audits and records. If a duration needs changing, it changes in the owning file and the commit says so.
- Every frequency, envelope, intensity and sharpness — **T03**, **T05**. This task names cues; it writes no parameter.
- The engines and the toggles — **T04**, **T06**.
- The shader and its governor — **T07**; `grainShimmer` is a row in this registry and its behaviour is that task's.
- SIEVE's `preview(n) + window(n)` parity test — **E14·T10**, already shipped; this task asserts the *row exists*, not the schedule.
- The VoiceOver announcement wording and its priority — **E19·T05**; this task only keeps the utterance on the same frame as the cue.
- The final token and type-role sweep across the eighteen screens — **T09**.
