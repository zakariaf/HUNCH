# T04 — The cast

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | The cast (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load first: this task draws and animates, so every duration is `Dur.*` and every weight is `env.weight(_:)`. The 120 / `cadence − 240` / 120 split is three tokens with one arithmetic identity between them, and a literal `0.12` in a view fails hygiene check 9. |
| `hunch-motion-and-feedback` | Owns *what happens when*, and this is the only surface in the game where the cadence **is** the mechanic. The skill's three clocks decide that the cast's model state advances at t = 0 of each step while the draw-in is decoration, and its Reduce Motion table is the file the ECHO cast row has to be added to — an animation that is not in that table does not ship. |
| `hunch-glyph-renderer` | The throat's 96 pt glyph and the shipped bleed at that size are this skill's; so is the ruling that a glyph never animates itself, which is what allows the cast to be one `phaseAnimator` over positions rather than fourteen self-animating canvases. |
| `hunch-swift-code` | The construction half is core, pure over `(law, seed, L, A, seedGlyph)`, with the RNG local to one synchronous call tree. It also owns the decision that `EchoCast` publishes its glyph sequence publicly and its lawful indices through a separate value the view layer cannot name. |
| `hunch-bench-instruments` | The ribbon is dark during the cast, and "dark" is a *state of the existing drawing*, not an absence: `references/ribbon.md` §3 lists ECHO's cast as one of the four surfaces of one component. Re-implementing it as a second view is the failure mode the skill names explicitly. |

## Objective

At the end of this task the Loom emits: `L` pairwise-distinct glyphs through the throat at a fixed
cadence, exactly `A` of them lawful by construction and verified by evaluation, with no verdict rings
and a dark ribbon because a cast is not probing and the Loom does not log it. `A` is never displayed,
anywhere, at any point — and that is enforced by which type the view layer is allowed to hold, not by
a review note.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.3 (first two bullets and the paragraph above them) | the cast's shape: `L` glyphs one at a time at fixed cadence with no verdicts; the ribbon stays dark and that is diegetic; 120 ms draw-in, `cadence − 240 ms` hold, 120 ms withdraw, link arc to the predecessor; Reduce Motion is hard crossfades at the identical cadence; glyphs pairwise distinct; exactly `A` lawful; `A` never displayed |
| `GAME_DESIGN.md` | §8.6 (the paragraph beginning "Cast construction") | deterministic from `seed ^ Mode.echo.salt`; sample `A` lawful and `L − A` unlawful, all distinct; then order subject to (i) contextual realisation checked **by evaluation rather than assumed**, and (ii) no more than three consecutive positions sharing a verdict |
| `GAME_DESIGN.md` | §8.4 (paragraph under the table) | during primer and cast the layout is PROBE's: 96 pt throat at 64–176, ribbon dark, Dial absent, pool strip pinned at 68–108 |
| `GAME_DESIGN.md` | §8.5 (`primer → casting`, `casting → recalling`) | the 600 ms gap into `casting`; `recalling` begins when the `L`-th glyph withdraws |
| `GAME_DESIGN.md` | §8.10 DUPLICATE-SUPPRESSION | forbidden at construction; the "same glyph, two verdicts" lesson belongs to PROBE's twin |
| `GAME_DESIGN.md` | §3.5 | the seed glyph primes position 0, so position 0's verdict is evaluated against the primer's seed |
| `GAME_DESIGN.md` | §13.7.4 | the substitution rule: a Reduce Motion row replaces the animation, never the information the animation carried |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 | the RNG rule; `EchoRound` is `@MainActor @Observable` in `LoomFeature` under `04 A18`'s earned exception |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/RoundsTests/EchoCastTests.swift`:

```swift
import Foundation
import Testing
@testable import Rounds
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("EchoCast — §8.6's construction", .tags(.unit, .presubmission))
struct EchoCastTests {

    private let seedGlyph = Deck.glyph(id: 22)

    private func build(_ law: LawNode, length: Int, lawful: Int, seed: UInt64) -> EchoCast {
        EchoCast(law: Law(law), seedGlyph: seedGlyph, length: length, lawfulCount: lawful, seed: seed)
    }

    @Test("every cast glyph is distinct — DUPLICATE-SUPPRESSION is a construction rule",
          arguments: Band.allCases)
    func glyphsAreDistinct(_ band: Band) {
        for index in 0..<64 {
            let cast = build(Corpora.law(band: band, index: index),
                             length: 14, lawful: 6, seed: Corpora.seed(band: band, index: index))
            #expect(Set(cast.glyphs).count == cast.glyphs.count)
            #expect(!cast.glyphs.contains(seedGlyph) || cast.glyphs.first(where: { $0 == seedGlyph }) != nil)
        }
    }

    @Test("exactly A positions are lawful, checked by evaluating the realised sequence",
          arguments: LoadIndex.allCases)
    func lawfulCountHoldsUnderEvaluation(_ load: LoadIndex) {
        for index in 0..<32 {
            let node = Corpora.law(band: .contextual, index: index)     // the hard case: prev matters
            let law = Law(node)
            let cast = build(node, length: load.length, lawful: load.lawfulCount,
                             seed: Corpora.seed(band: .contextual, index: index))

            var previous = seedGlyph
            var lawful: [Int] = []
            for (position, glyph) in cast.glyphs.enumerated() {
                if law.admits(glyph, after: previous) { lawful.append(position) }
                previous = glyph
            }
            #expect(lawful.count == load.lawfulCount)
            #expect(cast.truth == lawful)                                // §8.6 (i), by evaluation
            #expect(cast.glyphs.count == load.length)
        }
    }

    @Test("no more than three consecutive positions share a verdict — the answer is never a block",
          arguments: LoadIndex.allCases)
    func noRunLongerThanThree(_ load: LoadIndex) {
        for index in 0..<32 {
            let cast = build(Corpora.law(band: .exclusive, index: index),
                             length: load.length, lawful: load.lawfulCount,
                             seed: Corpora.seed(band: .exclusive, index: index))
            let truth = Set(cast.truth)
            var run = 1
            for position in 1..<cast.glyphs.count {
                run = truth.contains(position) == truth.contains(position - 1) ? run + 1 : 1
                #expect(run <= 3)
            }
        }
    }

    @Test("the truth indices are ascending, which is what LIS is measured against")
    func truthIsAscending() {
        let cast = build(Corpora.law(band: .pair, index: 2), length: 11, lawful: 4, seed: 0xC1)
        #expect(cast.truth == cast.truth.sorted())
        #expect(Set(cast.truth).count == cast.truth.count)
    }

    @Test("construction is deterministic in (law, seed, L, A) and salted by the mode")
    func deterministic() {
        let node = Corpora.law(band: .relational, index: 5)
        let a = build(node, length: 12, lawful: 5, seed: 0xD1)
        let b = build(node, length: 12, lawful: 5, seed: 0xD1)
        #expect(a == b)
        #expect(build(node, length: 12, lawful: 5, seed: 0xD2) != a)
    }

    @Test("the presentation value carries the glyphs and the cadence, and nothing else")
    func presentationCannotLeakA() {
        let cast = build(Corpora.law(band: .literal, index: 0), length: 6, lawful: 2, seed: 0xE1)
        let presentation = cast.presentation(cadence: LoadIndex.one.cadence)
        #expect(presentation.glyphs == cast.glyphs)
        #expect(presentation.cadence == LoadIndex.one.cadence)
        // `CastPresentation` has exactly two stored properties; adding a third is how A leaks.
        #expect(Mirror(reflecting: presentation).children.count == 2)
    }
}
```

`Modules/Tests/LoomFeatureTests/EchoCastPresentationTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature
import ModulesTestSupport

@Suite("The cast's beat — §8.3", .tags(.unit, .presubmission))
@MainActor
struct EchoCastPresentationTests {

    @Test("draw-in + hold + withdraw is exactly the cadence, at every load index",
          arguments: LoadIndex.allCases)
    func stepSumsToCadence(_ load: LoadIndex) {
        let step = CastStep(cadence: load.cadence, env: .reference)
        #expect(step.drawIn == Dur.echoCastDrawIn)
        #expect(step.withdraw == Dur.echoCastWithdraw)
        #expect(step.hold == load.cadence - Dur.echoCastDrawIn - Dur.echoCastWithdraw)
        #expect(step.drawIn + step.hold + step.withdraw == load.cadence)
        #expect(step.hold > .zero)                         // the fastest cadence still holds 610 ms
    }

    @Test("Reduce Motion keeps the cadence and replaces only the animation",
          arguments: LoadIndex.allCases)
    func reduceMotionKeepsTheCadence(_ load: LoadIndex) {
        let normal = CastStep(cadence: load.cadence, env: .reference)
        let reduced = CastStep(cadence: load.cadence, env: .reduceMotion)
        #expect(reduced.total == normal.total)
        #expect(reduced.onset(of: 5) == normal.onset(of: 5))
        #expect(reduced.style == .crossfade)
        #expect(normal.style == .drawInHoldWithdraw)
    }

    @Test("the ribbon is dark: no verdict rings, no tiles, nothing announced")
    func ribbonIsDark() {
        let view = EchoRoundView(round: Fixtures.echoRound(phase: .casting), env: .reference)
        let probe = RenderProbe(view)
        #expect(probe.ribbonSurface == .echoCastDark)
        #expect(probe.verdictRingCount == 0)
        #expect(AccessibilityProbe(view).elements.allSatisfy { $0.identifier != .ribbon })
    }

    @Test("link arcs join consecutive cast glyphs so the chain reads as a chain")
    func linkArcs() {
        let probe = RenderProbe(EchoRoundView(round: Fixtures.echoRound(phase: .casting, position: 4),
                                              env: .reference))
        #expect(probe.linkArcCount == 3)                    // one fewer than the glyphs shown
    }

    @Test("the view layer cannot name the lawful count")
    func viewLayerCannotNameA() throws {
        for path in SourcePath.echoViewSurface {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            #expect(!source.contains("lawfulCount"))
            #expect(!source.contains(".truth"))
        }
    }

    @Test("the cast advances on its own clock and never waits on a frame")
    func castAdvancesAtStepStart() {
        let round = Fixtures.echoRound(phase: .casting)
        for position in 0..<round.cast.glyphs.count {
            round.advanceCast()
            #expect(round.castPosition == position + 1)     // committed at t = 0 of the step
        }
        #expect(round.phase == .recalling)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter EchoCastTests`, then
`xcodebuild test … -only-testing:LoomFeatureTests/EchoCastPresentationTests`.
`LoadIndex` is T07's type; declare the enum's eight cases with `length`, `lawfulCount` and `cadence`
here as the minimum this task needs, and let T07 add `δ_ECHO`, the solver and the derived cast
duration. Two tasks touching one enum is fine; two tasks each declaring their own table is not.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/EchoCast.swift` |
| create | `HunchCore/Sources/Rounds/EchoPhase.swift` — the eight cases only |
| create | `HunchCore/Sources/Rounds/LoadIndex.swift` — the eight rows; T07 extends it |
| modify | `HunchCore/Sources/Tokens/C.swift` — `Dur.echoCastDrawIn`, `Dur.echoCastWithdraw` |
| create | `Modules/Sources/LoomFeature/EchoRound.swift` |
| create | `Modules/Sources/LoomFeature/EchoRoundView.swift` |
| create | `Modules/Sources/LoomFeature/CastStep.swift` |
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` — add the `echoCastDark` surface case |
| modify | `Modules/Package.swift` — `LoomFeature` gains nothing new; confirm only |
| create | `HunchCore/Tests/RoundsTests/EchoCastTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/EchoCastPresentationTests.swift` |
| modify | `tests.json` — four entries |
| modify | `Scripts/check-source-hygiene.sh` — the lawful-count check |

## Implementation notes

### The construction, in one algorithm that covers both cases

The naive reading of §8.6 — "sample `A` lawful and `L − A` unlawful glyphs, then order them" — only
works for a stateless law, because for a contextual law *lawful* is a property of a `(prev, cur)` pair
and not of a glyph. §8.6 anticipates that: constraint (i) says the realised sequence must actually
produce the intended verdicts, **checked by evaluation rather than assumed**. One algorithm satisfies
both cases and terminates:

```swift
public struct EchoCast: Codable, Hashable, Sendable {
    public let glyphs: [Glyph]        // L, pairwise distinct, in cast order
    public let truth: [Int]           // ascending cast indices of the lawful positions; |truth| = A

    /// Deterministic in `(law, seedGlyph, length, lawfulCount, seed)`. §8.6.
    public init(law: Law, seedGlyph: Glyph, length: Int, lawfulCount: Int, seed: UInt64)

    /// Everything the view layer is allowed to know. §8.3: `A` is never displayed, anywhere.
    public func presentation(cadence: Duration) -> CastPresentation
}
```

1. **Draw the label sequence first.** A permutation of `A` `.admit`s and `L − A` `.reject`s with no run longer than three (constraint (ii)). Rejection-sample shuffles with a bounded attempt count, then fall back to a deterministic block interleave — which always exists at every row of the `ℓ` table: the worst case is `ℓ = 8` (`L = 14`, `A = 6`), and `RRR AAA RRR AAA RR` has a maximum run of three.
2. **Realise it, position by position.** `prev` starts at `seedGlyph` (§3.5). At each position take `law.row(after: prev)` — the `Bitboard256` of glyphs admitted after `prev`, which for a stateless law is the same row every time — or its complement for a `.reject` label, subtract the glyphs already used, and draw uniformly from what remains.
3. **If a position has no candidate, re-draw the label sequence** and start over, bounded. With `L ≤ 14` against a 256-glyph deck and admit rates inside §5.7's `[0.15, 0.60]` window this effectively never fires, but the bound is what makes the function total rather than "usually fast".
4. **Verify by evaluation and store the result.** Walk the realised sequence once more computing `law.admits(_:after:)`, assert it equals the labels, and store the admitting positions as `truth`. That walk is constraint (i) made structural — it costs `L` mask lookups and it is the difference between a cast that *is* right and a cast that was *intended* to be right.

The RNG is `var rng = SplitMix64(seed: seed ^ Mode.echo.salt)`, local, threaded as
`using rng: inout some RandomNumberGenerator`, never stored (`08 §4`). `Mode.echo.salt` is folded in
exactly once, at the top, so the cast and the primer (which folds the salt with `m`) never re-draw the
same sequence from the same round seed.

**Distinctness is enforced by the `used` set at step 2, not by a post-hoc filter.** That is
DUPLICATE-SUPPRESSION (§8.10) at construction, and it is why the tray can be a set: two identical
tiles would make "which one did you mean" unanswerable, and the same-glyph-two-verdicts lesson is
PROBE's twin key, not this mode's.

### Keeping `A` off the screen

§8.3 says `A` is "never displayed, anywhere, at any point". A comment cannot enforce that; a type can:

```swift
public struct CastPresentation: Hashable, Sendable {
    public let glyphs: [Glyph]
    public let cadence: Duration
}
```

Two stored properties, and the `Mirror` assertion in the test is what stops a third being added
"temporarily". `EchoRound` holds the full `EchoCast` — it must, because T08 scores against `truth` —
but `EchoRoundView` and every subview take `CastPresentation`. The hygiene check added by this task
greps the six ECHO view files for `lawfulCount` and `.truth` and fails the build on either; plant a
reference once, watch it fail, revert it, and record that you did in the PR body.

The instrument bar's **cast ticks** (§8.4) are "one per position, all filled" — a `TickRow.draw` of
`L` filled ticks. Note what that is *not*: it is not `A` ticks, it is not progress through the cast,
and it is not a countdown. It tells the player how long the cast is, which is the same information
the par row gives in PROBE, and it is the only running readout on the surface.

### The beat

```swift
struct CastStep {
    let drawIn: Duration       // Dur.echoCastDrawIn — 120 ms
    let hold: Duration         // cadence − drawIn − withdraw
    let withdraw: Duration     // Dur.echoCastWithdraw — 120 ms
    var total: Duration { drawIn + hold + withdraw }   // == cadence, asserted
}
```

The identity `drawIn + hold + withdraw == cadence` is asserted rather than assumed, because it is what
makes the cast's total duration equal `L × cadence` — the figure T07's table derives its last row from.
At the fastest cadence the hold is still 610 ms, comfortably above the 400 ms the reveal uses per
glyph, so no row of the table needs a special case.

One `phaseAnimator` over the cast position drives the whole thing, exactly as E09·T10 drives the
reveal. The model advances at t = 0 of each step (`hunch-motion-and-feedback`'s commit clock): the
position increments, *then* the draw-in animates. Backgrounding mid-step therefore never leaves the
round between two positions — which is what makes T09's "restart from position 1" a clean rule rather
than a resumption problem.

**The Reduce Motion row.** §13.7.4's table has no ECHO cast row and §8.3 states the substitution, so
this task adds it: *ECHO cast glyph — normal: 120 ms draw-in, hold, 120 ms withdraw with a link arc —
Reduce Motion: hard crossfade at the identical cadence.* Add it to
`hunch-motion-and-feedback/references/reduce-motion.md` §2's table in the same commit, because that
file is the checklist §13.12 gate 9 is verified against and a row that only exists in a task file is a
row that will go missing. The rule it instantiates is the same one the SIEVE row states at length:
*the cadence is the game, the animation is not.*

### The dark ribbon

`references/ribbon.md` §3 lists **ECHO cast — dark** as one of the four surfaces of one drawing: the
same tiles with no verdict rings. So `RibbonCanvas` gains a surface case, not a sibling view. Three
consequences worth writing down:

- **No verdict ring is drawn**, which is the entire diegetic point — there is no admit ring during a cast because the Loom is not logging.
- **The ribbon publishes no accessibility element in this state.** `references/voiceover-elements.md` §6 gives the cast's dark ribbon a `hidden` row and says why: a value announcing "cast in progress" would leak the fact that a verdict exists. The test asserts the absence.
- **Link arcs are still drawn**, by `LinkArc.draw` with the `.arc` variant, because §8.3 wants the chain to read as a chain — contextual pool laws are unreadable without adjacency.

### `EchoPhase` and `EchoRound`

`EchoPhase` is declared here with §8.5's eight cases verbatim and nothing else:

```swift
public enum EchoPhase: Hashable, Sendable {
    case arming, priming, primer, casting, recalling, adjudicating, reveal, settled
}
```

The transition table, the asserted invariant and the interruption rules are **T09's**. Declaring the
enum here keeps `EchoRound` from inventing a private phase type that would then have to be merged.

`EchoRound` is `@MainActor @Observable final class EchoRound` in `LoomFeature`, alongside `Round` and
for the same reason — `04 A18`'s triggers 1 and 2 both fire, and `A19`'s pass-through test still
passes because deleting it breaks the cadence, the phase timing and the snapshot cadence while the
cast construction, the scoring and the pool all keep working. It is not `Round` with a mode flag:
ECHO has no Dial, no Bench, no probes, no strikes and no cap, so five of `Round`'s six invariants
would be vacuous. Record that in `DECISIONS.md` if it is not already implied by E12's equivalent
ruling for DRIFT.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EchoCastTests` green, all six, including the eight-row `LoadIndex` sweeps at bands with and without contextuality.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/EchoCastPresentationTests` green, all six.
- [ ] `grep -rn "lawfulCount\|\.truth" Modules/Sources/LoomFeature/EchoRoundView.swift Modules/Sources/LoomFeature/CastStep.swift` returns nothing, and the new hygiene check has been demonstrated to fail on a planted reference.
- [ ] `grep -rn "struct .*Ribbon\|RibbonView" Modules/Sources/LoomFeature/` shows no second ribbon implementation.
- [ ] The ECHO cast row exists in `hunch-motion-and-feedback/references/reduce-motion.md` §2.
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh HunchCore/Sources/Rounds/EchoCast.swift` exits 0.
- [ ] `tests.json` carries four entries: distinctness, `|truth| == A` under evaluation, the run bound, and cadence parity under Reduce Motion.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T04: cast construction, the cadence beat and the dark ribbon"`

## Out of scope

- The tray and rail that appear when the `L`-th glyph withdraws — **T05**.
- Replaying the cast — **T06**; this task ships one playthrough and no replay affordance.
- The `ℓ` table's `δ_ECHO`, its solver and its derived cast duration — **T07**; this task declares the eight rows it needs.
- The transition table, the interruption policy and the reveal's own 400 ms-per-glyph replay — **T09**.
- Audio and haptic cues on the cadence — **E20**; publish the cue points as data and attach nothing.
