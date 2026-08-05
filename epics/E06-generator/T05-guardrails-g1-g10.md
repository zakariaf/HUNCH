# T05 — Guardrails G1–G10

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T04, T02 |
| **Delivers** | §14.1 Guardrails G1–G10 |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | Ten predicates over one context value is exactly the shape that decays into a `GuardrailValidator` class with stored state; this skill's state-ownership rules keep them free functions over `Sendable` values, and `W29` forbids the `default:` that would let an eleventh guardrail be silently ignored. |
| `hunch-swift-testing` | Each guardrail needs a test that fails it deliberately, which means hand-built laws that violate exactly one clause — this skill's rules on hand-written fixtures, the ban on `@testable import`, and the `isApproximatelyEqual` requirement for G3's and G8's `Double` comparisons all bite here. |

## Objective

Each of §5.3's ten guardrails is a separately callable predicate with its own test, and one function
runs them cheap-to-expensive and names the first failure. G4 is scoped to strictly lower bands and
is vacuous at band 5; G8's two clauses are separable so the anchor law can be exempted from one of
them; G9 reads the caller-supplied `avoid` set and nothing else.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.3 | The ten guardrails, their tests, the admit-window argument, the anchor's two exemptions |
| `GAME_DESIGN.md` | §3.6 | Lifting, dead-term detection with **both** substitutions, attribute liveness, the dedup key, and G4's exact scope including why the candidate's own band is excluded |
| `GAME_DESIGN.md` | §5.2 | `\|H\|` is defined as the count surviving G1–G3, G5–G7, G10 and G8's membership clause plus G4's strictly-lower exclusion — the definition this task must implement exactly, or E05·T08's counts move |
| `GAME_DESIGN.md` | §5.7 | The admit-rate window, the G4 scope row, the 0.02 tolerance implied by §5.1's rejection sampling |
| `GAME_DESIGN.md` | §5.1 | The `\|difficulty − target\| ≤ 0.02` rejection-sampling rule G8 implements |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | Exhaustive switch over the guardrail enum |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LawGenerationTests/GuardrailTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import Bench
import LawGeneration
import HunchTestSupport

@Suite("Guardrails G1–G10", .tags(.unit, .presubmission))
struct GuardrailTests {

    private func context(_ band: Band,
                         targetDelta: Double? = nil,
                         avoid: Set<UInt64> = []) -> GuardrailContext {
        GuardrailContext(band: band,
                         targetDelta: targetDelta ?? band.centre,
                         avoid: avoid,
                         index: Corpora.index,
                         exemptions: [])
    }

    // MARK: the roster

    @Test("There are exactly ten guardrails and the evaluation order covers all of them")
    func rosterIsComplete() {
        #expect(Guardrail.allCases.count == 10)
        #expect(Set(Guardrail.evaluationOrder) == Set(Guardrail.allCases))
        #expect(Guardrail.evaluationOrder.count == 10)
    }

    @Test("Every exemplar law clears every guardrail at its own band's centre",
          arguments: Band.allCases)
    func exemplarsClearEverything(_ band: Band) throws {
        let law = Law(band.exemplar)
        let ctx = context(band, targetDelta: difficulty(of: law))
        #expect(firstFailure(for: law, in: ctx) == nil)
    }

    // MARK: G1, G2, G3

    @Test("G1 rejects an unsatisfiable table")
    func g1RejectsUnsatisfiable() throws {
        let law = Law(try #require(Corpora.handWritten(.alwaysFalse)))
        #expect(law.table.popCount == 0)
        #expect(Guardrail.satisfiable.holds(for: law, in: context(.literal)) == false)
    }

    @Test("G2 rejects a tautology")
    func g2RejectsTautology() throws {
        let law = Law(try #require(Corpora.handWritten(.alwaysTrue)))
        #expect(Guardrail.falsifiable.holds(for: law, in: context(.literal)) == false)
    }

    /// §5.3's window is deliberately asymmetric: the floor exists so a blind prober meets an admit
    /// inside the smallest par, the ceiling because Wason's positive-test bias must be rewarded,
    /// not punished. Both edges are asserted, inclusive.
    @Test("G3's window is inclusive at both edges and rejects outside them")
    func g3WindowEdges() throws {
        let window = Band.literal.admitWindow
        #expect(Guardrail.admitRateWindow.holds(for: Law(Corpora.law(admitRate: window.lowerBound)),
                                                in: context(.literal)))
        #expect(Guardrail.admitRateWindow.holds(for: Law(Corpora.law(admitRate: window.upperBound)),
                                                in: context(.literal)))
        #expect(!Guardrail.admitRateWindow.holds(for: Law(Corpora.law(admitRate: 0.0625)),
                                                 in: context(.literal)))
        #expect(!Guardrail.admitRateWindow.holds(for: Law(Corpora.law(admitRate: 0.75)),
                                                 in: context(.literal)))
    }

    @Test("G3 for a contextual law is computed over all 65,536 ordered pairs")
    func g3UsesPairSpaceWhenContextual() throws {
        let law = Law(Band.contextual.exemplar)
        #expect(law.table.universeSize == 65_536)
        #expect(Guardrail.admitRateWindow.holds(for: law, in: context(.contextual)))
    }

    // MARK: G4 — the one with a scope

    /// §3.6: strictly lower bands, never its own. Comparing a band against itself would reject
    /// 100 % of candidates at five of the eight bands and drive the fallback rate to 1.00.
    @Test("G4 never consults the candidate's own band", arguments: Band.allCases)
    func g4ExcludesItsOwnBand(_ band: Band) throws {
        let law = Law(band.exemplar)                    // by construction a member of its own band
        #expect(Guardrail.notSecretlyEasier.holds(for: law, in: context(band)))
    }

    @Test("G4 rejects a band-2 spelling of a band-1 law served at band 2")
    func g4CatchesTheSecretlyEasierCase() throws {
        // `fill ∈ {striped} AND fill ∈ {striped, solid}` merges under RNF to a band-1 atom.
        let law = Law(try #require(Corpora.handWritten(.pairThatIsSecretlyAnAtom)))
        #expect(Guardrail.notSecretlyEasier.holds(for: law, in: context(.pair)) == false)
    }

    @Test("G4 is vacuous at band 5")
    func g4IsVacuousAtBandFive() throws {
        // every band below 5 is stateless, and G7 guarantees no band-5 table is a lift of one.
        #expect(Guardrail.notSecretlyEasier.consultedRuns(at: .contextual).isEmpty)
        for form in Corpora.sampledContextualLaws(count: 64) {
            #expect(Guardrail.notSecretlyEasier.holds(for: Law(form), in: context(.contextual)))
        }
    }

    @Test("G4 at band 7 reduces to the band-5 hash run")
    func g4AtBandSevenIsTheBandFiveRun() {
        #expect(Guardrail.notSecretlyEasier.consultedRuns(at: .composite) == [.contextual])
    }

    @Test("G4 at a stateless band consults exactly the stateless runs strictly below it",
          arguments: [Band.pair, .exclusive, .relational, .guarded, .systemic])
    func g4ConsultsTheStatelessRunsBelow(_ band: Band) {
        let consulted = Guardrail.notSecretlyEasier.consultedRuns(at: band)
        #expect(consulted.allSatisfy { $0 < band })
        #expect(consulted.allSatisfy { Band.enumerableCases.contains($0) })
        #expect(!consulted.contains(band))
    }

    // MARK: G5, G6

    /// §3.6 is explicit that removal alone is not enough: `XOR(a, b)` has no meaningful removal,
    /// so the ⊥ substitution is what catches a dead XOR operand.
    @Test("G5 requires both substitutions")
    func g5NeedsTopAndBottom() throws {
        let subsumed = Law(try #require(Corpora.handWritten(.andWithSubsumedLeaf)))
        #expect(Guardrail.noDeadTerms.holds(for: subsumed, in: context(.pair)) == false)
        let deadXor = Law(try #require(Corpora.handWritten(.xorWithDeadOperand)))
        #expect(Guardrail.noDeadTerms.holds(for: deadXor, in: context(.exclusive)) == false)
        #expect(Guardrail.noDeadTerms.holds(for: Law(Band.exclusive.exemplar),
                                            in: context(.exclusive)))
    }

    @Test("G6 rejects a law naming an attribute it does not depend on")
    func g6RequiresPivotality() throws {
        let law = Law(try #require(Corpora.handWritten(.namesAnInertAttribute)))
        #expect(Guardrail.attributeLiveness.holds(for: law, in: context(.pair)) == false)
    }

    // MARK: G7

    /// The lift test. A contextual law whose pair table is the lift of a stateless one is a
    /// stateless law wearing a ghost toggle, and serving it at band 5 poisons the estimate.
    @Test("G7 rejects a contextual law that is secretly stateless")
    func g7RejectsALiftedTable() throws {
        let fake = Law(try #require(Corpora.handWritten(.contextualThatIsStateless)))
        #expect(fake.table == fake.table.statelessProjection.lifted)
        #expect(Guardrail.genuinelyContextual.holds(for: fake, in: context(.contextual)) == false)
        #expect(Guardrail.genuinelyContextual.holds(for: Law(Band.contextual.exemplar),
                                                    in: context(.contextual)))
    }

    @Test("G7 is vacuous outside bands 5 and 7", arguments: Band.statelessCases)
    func g7OnlyAppliesToContextualBands(_ band: Band) {
        #expect(Guardrail.genuinelyContextual.holds(for: Law(band.exemplar), in: context(band)))
    }

    // MARK: G8 — two clauses, separately testable

    @Test("G8's membership clause uses the canonical form's difficulty", arguments: Band.allCases)
    func g8MembershipUsesTheCanonicalForm(_ band: Band) {
        let law = Law(band.exemplar.renderedNormalForm)
        #expect(Guardrail.bandFidelity.membershipHolds(for: law, band: band))
        #expect(!Guardrail.bandFidelity.membershipHolds(for: law, band: band.next ?? .literal))
    }

    @Test("G8's proximity clause is a symmetric ±tolerance window on targetδ")
    func g8ProximityIsSymmetric() throws {
        let law = Law(Band.relational.exemplar)
        let d = difficulty(of: law)
        let tol = Guardrail.proximityTolerance
        #expect(Guardrail.bandFidelity.proximityHolds(for: law, targetDelta: d))
        #expect(Guardrail.bandFidelity.proximityHolds(for: law, targetDelta: d + tol))
        #expect(Guardrail.bandFidelity.proximityHolds(for: law, targetDelta: d - tol))
        #expect(!Guardrail.bandFidelity.proximityHolds(for: law, targetDelta: d + 2 * tol))
    }

    @Test("The proximity clause can be exempted; the membership clause never can")
    func g8ProximityIsExemptibleAndMembershipIsNot() throws {
        let law = Law(Band.relational.exemplar)
        var ctx = context(.relational, targetDelta: 0.0)          // absurd target
        #expect(Guardrail.bandFidelity.holds(for: law, in: ctx) == false)
        ctx.exemptions = [.proximity]
        #expect(Guardrail.bandFidelity.holds(for: law, in: ctx))
        #expect(GuardrailExemption.allCases == [.proximity, .novelty])   // no third exemption exists
    }

    // MARK: G9

    @Test("G9 reads the caller's avoid set and nothing else")
    func g9ReadsOnlyTheAvoidSet() throws {
        let law = Law(Band.literal.exemplar)
        #expect(Guardrail.novelty.holds(for: law, in: context(.literal)))
        #expect(!Guardrail.novelty.holds(for: law,
                                         in: context(.literal, avoid: [law.table.dedupHash])))
    }

    @Test("G9 keys on the extension hash, so a re-spelling of an avoided law is still avoided")
    func g9KeysOnTheExtension() throws {
        let spelling = Law(try #require(Corpora.handWritten(.complementSpellingOfLiteralExemplar)))
        let avoided: Set<UInt64> = [Law(Band.literal.exemplar).table.dedupHash]
        #expect(!Guardrail.novelty.holds(for: spelling, in: context(.literal, avoid: avoided)))
    }

    @Test("G9 can be exempted, which is exactly how the anchor and the Anomaly are served")
    func g9IsExemptible() throws {
        let law = Law(Band.literal.exemplar)
        var ctx = context(.literal, avoid: [law.table.dedupHash])
        ctx.exemptions = [.novelty]
        #expect(Guardrail.novelty.holds(for: law, in: ctx))
    }

    // MARK: G10

    @Test("G10 is the node round-trip and not an extension match", arguments: Band.allCases)
    func g10IsNodeIdentity(_ band: Band) {
        #expect(Guardrail.constructible.holds(for: Law(band.exemplar), in: context(band)))
    }

    // MARK: the order

    @Test("firstFailure reports the earliest failing guardrail in evaluation order")
    func firstFailureRespectsTheOrder() throws {
        // a tautology that is also in the avoid set: G2 comes before G9 in the order.
        let law = Law(try #require(Corpora.handWritten(.alwaysTrue)))
        let ctx = context(.literal, avoid: [law.table.dedupHash])
        #expect(firstFailure(for: law, in: ctx) == .falsifiable)
    }

    @Test("The evaluation order is cheap to expensive")
    func orderIsCheapToExpensive() {
        let order = Guardrail.evaluationOrder
        #expect(order.first == .satisfiable)
        #expect(order.last == .noDeadTerms || order.last == .notSecretlyEasier)
        #expect(order.firstIndex(of: .admitRateWindow)! < order.firstIndex(of: .constructible)!)
        #expect(order.firstIndex(of: .novelty)! < order.firstIndex(of: .noDeadTerms)!)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter GuardrailTests` — missing symbols in `LawGeneration`,
not malformed expectations.

**Step 3 — implement.** Files below.

**Step 4 — green, then refactor**, then **measure the order**: time each guardrail over the exemplar
set and reorder `evaluationOrder` to the measured cost. Record the measured order and its numbers in
`DECISIONS.md` — the order is a performance decision, and a decision nobody wrote down is a decision
somebody will reverse.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/Guardrail.swift` — the enum, the per-guardrail predicates, `evaluationOrder`, `firstFailure(for:in:)` |
| create | `HunchCore/Sources/LawGeneration/GuardrailContext.swift` — the context value and `GuardrailExemption` |
| modify | `HunchCore/Sources/Laws/LawTable.swift` — `statelessProjection`, `lifted`, `isConstant`, `universeSize`, `dedupHash` if E05 did not ship them under these names |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — the ten hand-written violating laws |
| create | `HunchCore/Tests/LawGenerationTests/GuardrailTests.swift` |
| modify | `DECISIONS.md` — the measured evaluation order |
| modify | `tests.json` — one entry for Guardrails G1–G10 |

## Implementation notes

### The shape

```swift
public enum Guardrail: Int, CaseIterable, Sendable {
    case satisfiable = 1          // G1
    case falsifiable              // G2
    case admitRateWindow          // G3
    case notSecretlyEasier        // G4
    case noDeadTerms              // G5
    case attributeLiveness        // G6
    case genuinelyContextual      // G7
    case bandFidelity             // G8
    case novelty                  // G9
    case constructible            // G10

    public func holds(for law: Law, in context: GuardrailContext) -> Bool
    /// Cheap to expensive, measured. See `DECISIONS.md`.
    public static let evaluationOrder: [Guardrail]
}

public struct GuardrailContext: Hashable, Sendable {
    public let band: Band
    public let targetDelta: Double
    public let avoid: Set<UInt64>
    public let index: LawIndex
    public var exemptions: Set<GuardrailExemption>
}

/// The anchor law's two exemptions, and nothing else may ever be added here (§5.3).
public enum GuardrailExemption: CaseIterable, Hashable, Sendable { case proximity, novelty }

/// - Returns: the first guardrail that fails, in `evaluationOrder`, or `nil` if all ten hold.
public func firstFailure(for law: Law, in context: GuardrailContext) -> Guardrail?
```

`holds(for:in:)` is a `switch` over `self` with **no `default:`** (`W29`). Adding G11 must break the
file at compile time.

### Guardrail by guardrail

| # | Predicate | Notes that are not obvious from §5.3 |
|---|---|---|
| G1 | `law.table.popCount >= 1` | Cheapest thing in the file; it goes first for that reason alone |
| G2 | `law.table.popCount <= universeSize - 1` | The complement of G1; the two together are "not constant", which is also `SealBar.constantExtension`'s test — reuse `LawTable.isConstant` rather than writing the arithmetic twice |
| G3 | `band.admitWindow.contains(law.admitRate)` | Inclusive at both ends. For a contextual law, `admitRate` is already over 65,536 pairs because `Law.init` resolved the table at the right arity |
| G4 | `!context.index.contains(law.table, inRunsBelow: band)` | See the scope table below |
| G5 | leaf-by-leaf ⊤ **and** ⊥ substitution, rebuild, compare | E05·T05 ships the substitution; this guardrail is the caller. ≈8 rebuilds ≈16 µs for a 4-leaf contextual law, which is why it sits near the end of the order |
| G6 | every named attribute pivotal under at least one of its three non-identity value permutations | Also E05·T05 |
| G7 | bands 5 and 7 only: `P != lift(P & FULL256)` | Everywhere else it returns `true` immediately. This is the guarantee G4 leans on |
| G8 | membership **and** proximity, as two separable clauses | The anchor is exempt from proximity only |
| G9 | `!context.avoid.contains(law.table.dedupHash)` unless exempt | Reads the argument, never a store, never a `Ladder`, never a date |
| G10 | `LawNode(BenchLayout(law.node)) == law.node.renderedNormalForm` | T04 proved the round-trip; this is the guardrail that *uses* it |

### G4's scope, spelled out

§3.6 is the normative source and this table is its consequence. `consultedRuns(at:)` exists so the
scope is assertable rather than buried in an `if`:

| Candidate band | Runs consulted | Why the rest are excluded |
|---|---|---|
| 1 literal | none | nothing below it |
| 2 pair | 1 | stateless runs strictly below |
| 3 exclusive | 1, 2 | |
| 4 relational | 1, 2, 3 | |
| 5 contextual | **none — vacuous** | every band below is stateless, and G7 guarantees a band-5 table is not the lift of a stateless one |
| 6 guarded | 1, 2, 3, 4 | band 5 is contextual and cannot equal a stateless table, by G7 |
| 7 composite | **band 5's hash run only** | bands 1–4 and 6 are stateless and excluded by G7; band 5 is the only contextual band below |
| 8 systemic | 1, 2, 3, 4, 6 | bands 5 and 7 are contextual and excluded by G7 |

Because the stateless index is band-partitioned into six sorted runs behind an offset header, "all
runs strictly below" is a **contiguous range** and the lookup is one binary search, not six. That is
the entire reason E05·T07 partitioned it, and the implementation must actually take the range —
looping six runs is a silent regression against a design decision.

### `|H|` and the closure question

§5.2 defines `|H|(b)` as the count surviving G1–G3, G5–G7, G10 and G8's *membership* clause plus
G4's strictly-lower exclusion. E05·T08 already asserts the eight counts. If this task changes any
predicate's meaning, those counts move and `LawsTests` goes red — that is the intended coupling, not
an accident. **Never adjust E05's expected counts to match a new predicate.** Fix the predicate.

### `exemptions`, and why not two booleans

`GuardrailExemption` is a set of exactly two cases so that the generator's fallback path reads
`context.exemptions = [.proximity, .novelty]` in one line, and so that a third exemption cannot be
added without a `CaseIterable` test failing (`g8ProximityIsExemptibleAndMembershipIsNot` asserts the
full case list). §5.3's reasoning is that a last resort which can itself be vetoed is not a last
resort — and equally, a last resort that can dodge *band membership* is not a band-`b` law at all.

### What must never appear in this file

No `Date()`, no store, no `Ladder`, no `Codex`, no player history in any form. G9's whole design is
that novelty arrives as an argument (§5.3's purity decision), and the hygiene grep will catch the
first three. The fourth — importing a serving-layer type — is caught by the package graph, because
`LawGeneration` cannot see `Modules/`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GuardrailTests` is green.
- [ ] `Guardrail.allCases.count == 10` and `evaluationOrder` is a permutation of `allCases`.
- [ ] Every guardrail has at least one test that makes it **fail** on a hand-built law, and G8 and
      G9 additionally have tests for their exemptions.
- [ ] `Guardrail.notSecretlyEasier.consultedRuns(at:)` matches the scope table above for all eight
      bands, and `consultedRuns(at: .contextual)` is empty.
- [ ] G5 is shown to need both substitutions by a law that only the ⊥ substitution catches.
- [ ] `firstFailure(for:in:)` returns the earliest failure in `evaluationOrder`, proved by a law
      that fails two guardrails.
- [ ] `grep -n 'default:' HunchCore/Sources/LawGeneration/Guardrail.swift` returns nothing.
- [ ] E05's per-band `|H|` assertions are still green — `swift test --package-path HunchCore --filter LawsTests`.
- [ ] `DECISIONS.md` records the measured evaluation order with its timings.
- [ ] `tests.json` has a Guardrails G1–G10 entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T05: G1–G10 as ten separately testable predicates with a measured evaluation order"`

## Out of scope

- The rejection-sampling loop that *calls* these, the 200-attempt bound and the anchor — **T06**.
- Assembling the `avoid` set — **E11·T06**.
- Building the `LawIndex` G4 consults — **E05·T07**; this task consumes it.
- DRIFT's pair guardrails D1–D7, which run *after* both laws clear G1–G10 individually — **E12·T01**.
- SIEVE's stream guardrails S1–S5 and ECHO's primer separation — **E14·T03**, **E13·T03**.
