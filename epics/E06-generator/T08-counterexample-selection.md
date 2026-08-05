# T08 — Counterexample selection

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | §14.1 Counterexample (the selection half; the presentation half is E09·T09) |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | `08 §2` lists the counterexample as one of the four things that *look* core and are half app-layer: selection is core and fully deterministic, the two-ring animation and the 960 ms beat are `LoomFeature`. This task is the line, and the skill's boundary predicate is what keeps a duration from creeping into `HunchCore`. |
| `hunch-swift-testing` | The four steps are a total order over candidates, so the tests are equivalence-class tests — construct two candidates that tie at step *n* and assert step *n+1* breaks it. That is a different test shape from the corpus suites and this skill's rules on hand-built fixtures and named regression cases apply directly. |

## Objective

Given a declared law, a hidden law and the ribbon, `Counterexample.select(…)` returns the one glyph
— or, in contextual bands, the one ordered pair — that §4.5's four steps identify, with no
randomness and no ties left unresolved. Nothing about how it is drawn lives here.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.5 | The four selection steps in order, why a counterexample and not the law, why a false negative is preferred, and the anti-farming argument |
| `GAME_DESIGN.md` | §3.6 | Extension identity in the common space with lifting — which is what "disagree" means when the two laws have different arities |
| `GAME_DESIGN.md` | §2 | `glyphID = fill*64 + shape*16 + pips*4 + hue` and the canonical attribute order, which fixes both the Hamming metric and the tie-break |
| `GAME_DESIGN.md` | §6.8, §6.11 | The counterexample docks as a marginal island, is **not** a probe, and the probe-0 declaration edge case |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | Selection is core, presentation is not |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LawGenerationTests/CounterexampleTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Counterexample selection", .tags(.unit, .presubmission))
struct CounterexampleTests {

    // MARK: step 1 — restrict to disagreements

    @Test("Identical laws have no counterexample")
    func agreementYieldsNothing() {
        let law = Law(Band.literal.exemplar)
        #expect(Counterexample.select(declared: law, hidden: law, ribbon: []) == nil)
    }

    @Test("A re-spelling is not a disagreement")
    func equivalentSpellingsAgree() throws {
        let a = Law(Band.literal.exemplar)
        let b = Law(try #require(Corpora.handWritten(.complementSpellingOfLiteralExemplar)))
        #expect(a.table == b.table)
        #expect(Counterexample.select(declared: b, hidden: a, ribbon: []) == nil)
    }

    @Test("Every returned candidate is a genuine disagreement")
    func candidateAlwaysDisagrees() throws {
        for pair in Corpora.disagreeingLawPairs {                 // seeded, 256 pairs
            guard let choice = Counterexample.select(declared: pair.declared,
                                                     hidden: pair.hidden,
                                                     ribbon: pair.ribbon) else {
                Issue.record("no counterexample for a disagreeing pair"); return
            }
            #expect(pair.declared.admits(choice) != pair.hidden.admits(choice))
        }
    }

    // MARK: step 2 — prefer false negatives

    /// §4.5: a false negative is a case the hidden law admits and the declaration rejects — the
    /// over-narrow hypothesis, which is the most common human error.
    @Test("A false negative is chosen over a false positive even when the positive is closer")
    func falseNegativeWins() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.falseNegativeIsFarther))
        let choice = try #require(Counterexample.select(declared: scenario.declared,
                                                       hidden: scenario.hidden,
                                                       ribbon: scenario.ribbon))
        #expect(scenario.hidden.admits(choice))
        #expect(!scenario.declared.admits(choice))
    }

    @Test("A false positive is chosen when there is no false negative")
    func falsePositiveWhenNoNegativeExists() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.onlyFalsePositives))
        let choice = try #require(Counterexample.select(declared: scenario.declared,
                                                       hidden: scenario.hidden,
                                                       ribbon: scenario.ribbon))
        #expect(!scenario.hidden.admits(choice))
        #expect(scenario.declared.admits(choice))
    }

    // MARK: step 3 — minimise attribute-space Hamming distance to the ribbon

    /// §4.5's reason: it makes the counterexample land as "oh, *that* one" rather than as a random
    /// glyph, and it is also the anti-farming property — a garbage declaration disagrees nearly
    /// everywhere, so this rule hands back a glyph the player has effectively already probed.
    @Test("The nearest disagreement to the ribbon wins")
    func minimisesHammingDistanceToTheRibbon() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.twoFalseNegativesAtDifferentDistances))
        let choice = try #require(Counterexample.select(declared: scenario.declared,
                                                        hidden: scenario.hidden,
                                                        ribbon: scenario.ribbon))
        let distances = scenario.candidates.map { Glyph.hammingDistance($0, toNearestOf: scenario.ribbon) }
        #expect(Glyph.hammingDistance(choice, toNearestOf: scenario.ribbon) == distances.min())
    }

    @Test("Hamming distance is over the four attributes, not over glyphID")
    func hammingIsAttributeSpace() {
        let a = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .amber)
        let b = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .rose)
        let c = Glyph(fill: .solid,  shape: .hexagon, pips: .four, hue: .amber)
        #expect(Glyph.hammingDistance(a, b) == 1)
        #expect(Glyph.hammingDistance(a, c) == 3)
        #expect(a.glyphID.distance(to: b.glyphID) != 1)      // glyphID distance is not the metric
    }

    @Test("Distance is to the nearest ribbon member, not to the most recent one")
    func distanceIsToTheNearestMember() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.nearestIsNotMostRecent))
        let choice = try #require(Counterexample.select(declared: scenario.declared,
                                                        hidden: scenario.hidden,
                                                        ribbon: scenario.ribbon))
        #expect(choice == scenario.expected)
    }

    // MARK: step 4 — tie-break on lowest glyphID

    @Test("Ties at equal distance break on the lowest glyphID")
    func tieBreaksOnLowestGlyphID() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.twoEquidistantFalseNegatives))
        let choice = try #require(Counterexample.select(declared: scenario.declared,
                                                        hidden: scenario.hidden,
                                                        ribbon: scenario.ribbon))
        #expect(choice.glyphID == scenario.candidates.map(\.glyphID).min())
    }

    // MARK: determinism and the empty ribbon

    @Test("Selection is a pure function: same inputs, same answer", arguments: 0..<64)
    func selectionIsPure(_ index: Int) throws {
        let scenario = Corpora.disagreeingLawPairs[index]
        let first = Counterexample.select(declared: scenario.declared, hidden: scenario.hidden,
                                          ribbon: scenario.ribbon)
        let second = Counterexample.select(declared: scenario.declared, hidden: scenario.hidden,
                                           ribbon: scenario.ribbon)
        #expect(first == second)
    }

    @Test("Ribbon order does not change the answer")
    func ribbonOrderIsIrrelevant() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.twoEquidistantFalseNegatives))
        let forwards = Counterexample.select(declared: scenario.declared, hidden: scenario.hidden,
                                             ribbon: scenario.ribbon)
        let backwards = Counterexample.select(declared: scenario.declared, hidden: scenario.hidden,
                                              ribbon: scenario.ribbon.reversed())
        #expect(forwards == backwards)
    }

    /// §6.11's "declare at probe 0" edge case. With no ribbon, step 3 is vacuous and step 4 decides.
    @Test("An empty ribbon selects the lowest-glyphID false negative")
    func emptyRibbonFallsThroughToTheTieBreak() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.declaredAtProbeZero))
        let choice = try #require(Counterexample.select(declared: scenario.declared,
                                                        hidden: scenario.hidden,
                                                        ribbon: []))
        #expect(choice.glyphID == scenario.candidates.map(\.glyphID).min())
    }

    // MARK: contextual bands return an ordered pair

    @Test("A contextual disagreement returns an ordered pair, previous then current")
    func contextualReturnsAPair() throws {
        let hidden = Law(Band.contextual.exemplar)
        let declared = Law(Band.literal.exemplar)                 // a stateless guess at a contextual law
        let selection = try #require(Counterexample.selectPair(declared: declared, hidden: hidden,
                                                              ribbon: Corpora.sampleRibbon))
        #expect(hidden.admits(selection.current, after: selection.previous)
             != declared.admits(selection.current, after: selection.previous))
    }

    @Test("A stateless declaration against a contextual law is compared in the lifted space")
    func comparisonHappensAtTheLargerArity() throws {
        let hidden = Law(Band.contextual.exemplar)
        let declared = Law(Band.literal.exemplar)
        #expect(hidden.table.universeSize == 65_536)
        #expect(declared.table.lifted.universeSize == 65_536)
        #expect(Counterexample.selectPair(declared: declared, hidden: hidden, ribbon: []) != nil)
    }

    /// The pair tie-break reuses the canonical pair index the whole codebase already uses for
    /// `Bitboard65536` — `previous * 256 + current` — rather than inventing a second ordering.
    @Test("Pair ties break on the lowest canonical pair index")
    func pairTieBreaksOnPairIndex() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.twoEquidistantPairs))
        let selection = try #require(Counterexample.selectPair(declared: scenario.declared,
                                                              hidden: scenario.hidden,
                                                              ribbon: scenario.ribbon))
        #expect(selection.pairIndex == scenario.candidatePairs.map(\.pairIndex).min())
    }

    @Test("Pair distance sums each member's distance to its nearest ribbon glyph")
    func pairDistanceIsTheSum() throws {
        let scenario = try #require(Corpora.counterexampleScenario(.pairDistanceOrdering))
        let selection = try #require(Counterexample.selectPair(declared: scenario.declared,
                                                              hidden: scenario.hidden,
                                                              ribbon: scenario.ribbon))
        #expect(selection == scenario.expectedPair)
    }

    // MARK: the anti-farming property, as a measurement

    /// §4.5 prices a strike above the cost of probing by making a garbage declaration return
    /// something the player already knows. That is a claim about a distribution, so measure it.
    @Test("A garbage declaration returns a glyph within one attribute of the ribbon")
    func garbageDeclarationsTeachNothing() throws {
        var distances: [Int] = []
        for scenario in Corpora.garbageDeclarationScenarios {          // seeded, 128 of them
            guard let choice = Counterexample.select(declared: scenario.declared,
                                                     hidden: scenario.hidden,
                                                     ribbon: scenario.ribbon) else { continue }
            distances.append(Glyph.hammingDistance(choice, toNearestOf: scenario.ribbon))
        }
        #expect(distances.allSatisfy { $0 <= 1 })
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter CounterexampleTests`

**Step 3 — implement.** Files below.

**Step 4 — green, then refactor** — the two entry points share every step but the candidate set and
the tie-break key, so they should end up as one generic pass over a candidate sequence.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/Counterexample.swift` |
| modify | `HunchCore/Sources/Glyphs/Glyph.swift` — `hammingDistance(_:_:)` and `hammingDistance(_:toNearestOf:)` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — the scenario fixtures and the seeded pair corpus |
| create | `HunchCore/Tests/LawGenerationTests/CounterexampleTests.swift` |
| modify | `DECISIONS.md` — the pair distance and pair tie-break rulings |
| modify | `tests.json` — one entry for Counterexample |

## Implementation notes

### The shape

```swift
/// §4.5's selection. Fully deterministic, pure, and with no notion of *when* or *how* the
/// counterexample appears — the two-ring presentation, the 640 ms hold and the docking island are
/// `LoomFeature` (`08 §2`).
public enum Counterexample {
    /// Stateless bands. `nil` iff the two laws agree everywhere.
    public static func select(declared: Law, hidden: Law, ribbon: [Glyph]) -> Glyph?

    /// Contextual bands. Returns `previous` and `current` in that order — the ribbon's own reading
    /// direction, and the order the link arc is drawn in.
    public static func selectPair(declared: Law, hidden: Law, ribbon: [Glyph]) -> GlyphPair?
}

public struct GlyphPair: Hashable, Sendable {
    public let previous: Glyph
    public let current: Glyph
    /// The canonical pair index `previous.glyphID * 256 + current.glyphID` — the same index
    /// `Bitboard65536` uses (§3.6).
    public var pairIndex: Int { previous.glyphID * 256 + current.glyphID }
}
```

Which entry point a caller uses is decided by the **common space**, not by the band: if either
table is in pair space, the comparison happens there (§3.6's lifting rule) and the answer is a pair.
Expose that decision as `Counterexample.arity(declared:hidden:)` so E09 does not re-derive it from
`band == .contextual || band == .composite` — a stateless *hidden* law can meet a contextual
*declaration*, and that comparison is also in pair space.

### The four steps, exactly

```
candidates = { x : declared.admits(x) != hidden.admits(x) }          // step 1, in the common space
if candidates contains any x with hidden.admits(x) && !declared.admits(x):
    candidates = those x                                             // step 2, false negatives
candidates = argmin over candidates of distance(x, ribbon)           // step 3
return min of candidates by tie-break key                            // step 4
```

Four details that are decisions, not readings:

1. **Step 2 is a filter, not a sort.** If a false negative exists, no false positive can win, no
   matter how close it sits to the ribbon. The `falseNegativeWins` test constructs exactly the case
   where a sort and a filter differ.
2. **Step 3's distance is to the *nearest* ribbon member**, not to the most recent one and not the
   mean over the ribbon. §4.5 says "the nearest glyph already in the ribbon".
3. **An empty ribbon makes step 3 vacuous**, not undefined: every candidate has the same
   (undefined) distance, so the whole set survives to step 4 and the lowest `glyphID` wins. That is
   §6.11's declare-at-probe-0 case and it must not trap, return `nil`, or pick arbitrarily.
4. **Step 4 always terminates the search.** `glyphID` is unique across the 256-glyph deck and
   `pairIndex` is unique across the 65,536 pairs, so there is never a residual tie. If the
   implementation needs a fifth step, one of the first four is wrong.

> **Ruling, to be recorded in `DECISIONS.md`.** §4.5 defines steps 3 and 4 for a glyph; the pair
> case needs both extended and the design does not spell them out. The extension is: **distance of a
> pair = distance(previous, ribbon) + distance(current, ribbon)**, and **ties break on the lowest
> canonical pair index `previous*256 + current`**. Both reuse an ordering the codebase already has
> rather than inventing one, both are total, and both keep the stateless case as the special case of
> the pair case with a zero-length previous term.

### The Hamming metric

Over the four attributes in canonical `fill → shape → pips → hue` order, counting attributes that
differ — not a distance over `glyphID`, which would make `fill` worth 64 and `hue` worth 1. The
`hammingIsAttributeSpace` test pins this, and it matters: the whole point of step 3 is that the
counterexample reads as a one-attribute variation on something the player already tried.

`Glyph.hammingDistance` belongs in `Glyphs` beside `glyphID`, not here — E04's renderer and E13's
tray ordering will both want it.

### What must not appear in this file

No duration, no easing, no ring, no "two rings", no `docked`, no `isProbe`. §6.8's rules that the
counterexample does not increment `probesUsed` and never becomes `prev` are *round* rules and belong
to E07·T08's `Ribbon` and E09·T09's presentation. `08 §2` names the exact failure this prevents:
timing constants in the core invite `Task.sleep` into a package whose entire value is that it has no
clock.

### DRIFT's step 0

E12·T06 adds a **step 0** in front of these four: prefer a ribbon glyph whose verdict differs under
`L₁` and `L₂`, tie-broken by most recent index then lowest `glyphID`, falling through to canon when
the disagreement set holds no ribbon member. Write `select` so that step 0 can be layered in front
of it without modifying it — take the candidate set as an internal parameter with a default of "all
disagreements", so E12 supplies a different starting set rather than forking the function.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter CounterexampleTests` is green.
- [ ] `select` returns `nil` exactly when the two extensions are identical in the common space,
      including for equivalent re-spellings.
- [ ] A false negative is chosen over a strictly closer false positive.
- [ ] Step 3 minimises attribute-space Hamming distance to the *nearest* ribbon member, and the
      metric is proved not to be a `glyphID` distance.
- [ ] Ties resolve on the lowest `glyphID`, and pair ties on the lowest canonical pair index; no
      input produces an unresolved tie.
- [ ] An empty ribbon returns the lowest-`glyphID` false negative rather than `nil` or a trap.
- [ ] Ribbon order does not affect the result.
- [ ] A stateless declaration against a contextual hidden law selects a pair, compared in the lifted
      space.
- [ ] 128 seeded garbage declarations all return a glyph within Hamming distance 1 of the ribbon.
- [ ] `grep -rniE 'ring|ms|duration|animate|dock' HunchCore/Sources/LawGeneration/Counterexample.swift`
      returns nothing.
- [ ] `DECISIONS.md` records the pair distance and pair tie-break rulings.
- [ ] `tests.json` has a Counterexample entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T08: deterministic counterexample selection, stateless and paired"`

## Out of scope

- The two rings on one glyph, the 640 ms verdict-blind hold, the 960 ms beat, the travel to centre
  and the docked marginal island — **E09·T09**.
- "The counterexample is not a probe": it does not increment `probesUsed` and never becomes `prev`
  — **E07·T08**, **E09·T09**.
- The strike accounting, the fracture and the two-strike rule — **E09·T08**.
- DRIFT's dead-law step 0 — **E12·T06**.
- The Assay's wrong-cell flash, which is a different evidence tool entirely — **E09·T06**.
