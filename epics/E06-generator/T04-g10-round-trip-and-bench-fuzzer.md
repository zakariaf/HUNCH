# T04 — G10 round-trip and the Bench fuzzer

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | §14.1 G10 round-trip + fuzzer |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-testing` | This task is two of the largest loops in the codebase and both are `T21` deviations. The skill owns the deviation's terms — parameterise over a small axis, loop inside, and pay `T21` back with a reproducing seed and an `Attachment` in every failure — and the rule that the fuzzer moves to `.nightly` the moment it measures over ~1 s. |
| `hunch-bench-instruments` | The fuzzer has to generate configurations a *player* could actually build, which means it must know the instrument's state space: fourteen usable ramp states plus two inert, six comparators, the ghost on the trailing socket only, three coupler states, the Tally's two modes. A fuzzer over an imaginary state space proves nothing about the Bench. |

## Objective

G10 holds as a **node** identity, not an extension identity, for every law the design says must be
constructible, and §4.4's parity table is asserted production by production — 10,138 single-tile
layouts. In the other direction, 200,000 random Bench configurations each either parse to a
grammar-valid AST or are barred at the Seal, with nothing in between.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.4 | The parity table, both enforcing tests, and the palette-ceiling decision that follows them |
| `GAME_DESIGN.md` | §5.3 | G10's statement, and the paragraph explaining why an extension round-trip has a blind spot |
| `GAME_DESIGN.md` | §3.3 | The exhaustive predicate inventory: 56 / 36 / 96 / 8,736 / 1,214 |
| `GAME_DESIGN.md` | §3.4 | RNF rule 3, which is the convention the eight symmetric forms would let you break silently |
| `GAME_DESIGN.md` | §4.3 | The three bar conditions — the fuzzer's "or is barred" arm |
| `ios-swift-guide/06-TESTING.md` | T18a, T21, T22, T23, T53, T58 | Attachments, the loop deviation, the Cartesian trap, promoting failures, never deleting a slow test |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | The T21 deviation as applied to HUNCH, and the fuzzer's nightly escape hatch |

## TDD — the test comes first

This task *is* tests, so step 1 and step 3 collapse: write the assertions, watch them fail against
T03's implementation, and fix `BenchLayout` until they pass. The eight symmetric contextual forms
are the assertion most likely to fail first, and that is the point.

**Step 1 — write the failing test.** Create
`HunchCore/Tests/BenchTests/BenchRoundTripTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import Bench
import HunchTestSupport

@Suite("G10 — the Bench and the grammar are the same language", .tags(.unit, .presubmission))
struct BenchRoundTripTests {

    // MARK: §4.4's parity table, production by production

    @Test("All 56 atoms are one Ramp each, and round-trip node-identically")
    func atomsAreExhaustive() throws {
        var seen = Set<LawNode>()
        for attribute in Glyph.Attribute.allCases {
            for subset in Subset4.usable {                       // 14 per attribute
                let node = LawNode.atom(attribute: attribute, subset: subset)
                #expect(LawNode(BenchLayout(node)) == node.renderedNormalForm)
                seen.insert(node)
            }
        }
        #expect(seen.count == 56)                                // §3.3
    }

    @Test("All 36 relational forms are one Bridge each, both sockets on cur")
    func relationalFormsAreExhaustive() throws {
        var seen = Set<LawNode>()
        for pair in Glyph.Attribute.orderedDistinctPairs {       // 6 unordered pairs
            for comparator in Comparator.allCases {              // 6
                let node = LawNode.relational(leading: pair.0, comparator: comparator,
                                              trailing: pair.1)
                #expect(LawNode(BenchLayout(node)) == node.renderedNormalForm)
                seen.insert(node.renderedNormalForm)
            }
        }
        #expect(seen.count == 36)
    }

    @Test("All 96 contextual forms are one ghosted Bridge each")
    func contextualFormsAreExhaustive() throws {
        var seen = Set<LawNode>()
        for leading in Glyph.Attribute.allCases {                // 4
            for trailing in Glyph.Attribute.allCases {           // 4 — may be equal (§3.3)
                for comparator in Comparator.allCases {          // 6
                    let node = LawNode.contextual(leading: leading, comparator: comparator,
                                                  trailing: trailing)
                    #expect(LawNode(BenchLayout(node)) == node.renderedNormalForm)
                    seen.insert(node)
                }
            }
        }
        #expect(seen.count == 96)
    }

    /// **The assertion this whole task exists for.** A rendering convention that transposes `cur`
    /// and `prev` produces a different extension for 64 of the 96 contextual forms — and *the same*
    /// extension for the other 8 (`==` and `!=` with both sockets on one attribute). An extension
    /// round-trip passes those eight, and the bug ships as "sometimes the tile lies" (§5.3).
    @Test("Exactly eight contextual forms are invisible to an extension round-trip")
    func eightSymmetricFormsProveNodeIdentityIsRequired() throws {
        var blind: [LawNode] = []
        for leading in Glyph.Attribute.allCases {
            for trailing in Glyph.Attribute.allCases {
                for comparator in Comparator.allCases {
                    let node = LawNode.contextual(leading: leading, comparator: comparator,
                                                  trailing: trailing)
                    let transposed = LawNode.contextual(leading: trailing, comparator: comparator,
                                                        trailing: leading)
                    if LawTable(transposed) == LawTable(node) && transposed != node {
                        blind.append(node)
                    }
                }
            }
        }
        #expect(blind.count == 8)
        #expect(blind.allSatisfy { $0.comparator == .eq || $0.comparator == .neq })
        #expect(blind.allSatisfy { $0.leadingAttribute == $0.trailingAttribute })
    }

    /// And the corollary: a deliberately transposing encoder passes an extension test on those
    /// eight and fails the node test on all of them. If this test ever goes green with
    /// `transposingLayout` removed, G10 has quietly become an extension check again.
    @Test("A transposing encoder survives an extension check and dies on the node check")
    func transposingEncoderIsCaughtOnlyByNodeIdentity() throws {
        for node in Corpora.symmetricContextualForms {                  // the eight from above
            let bad = BenchLayout.transposingLayout(node)               // test-only, in Corpora
            #expect(LawTable(LawNode(bad)!) == LawTable(node))          // extension test: passes
            #expect(LawNode(bad) != node.renderedNormalForm)            // node test: fails
        }
    }

    @Test("All three couplers are reachable and round-trip")
    func couplersAreExhaustive() throws {
        for coupler in Coupler.allCases {
            let node = LawNode.coupled(.atom(attribute: .fill, subset: Subset4(ranks: [1, 2])),
                                       coupler,
                                       .atom(attribute: .shape, subset: Subset4(ranks: [1, 2])))
            #expect(LawNode(BenchLayout(node)) == node.renderedNormalForm)
        }
    }

    /// 12 ordered (gate, branch) pairs × 4 gate values × 14 then-subsets × 13 else-subsets = 8,736.
    @Test("All 8,736 guards are one Fork each", .tags(.integration, .nightly))
    func guardsAreExhaustive() throws {
        var count = 0
        for (gate, branch) in Glyph.Attribute.orderedDistinctPairsBothWays {   // 12
            for value in 0..<4 {
                for thenSubset in Subset4.usable {                             // 14
                    for elseSubset in Subset4.usable where elseSubset != thenSubset {  // 13
                        let node = LawNode.guarded(gate: gate, value: UInt8(value),
                                                   branch: branch,
                                                   then: thenSubset, else: elseSubset)
                        guard LawNode(BenchLayout(node)) == node.renderedNormalForm else {
                            Attachment.record(node, named: "guard-\(gate)-\(branch)-\(value)-\(thenSubset.rawValue)-\(elseSubset.rawValue).json")
                            Issue.record("G10 failed on a guard")
                            return
                        }
                        count += 1
                    }
                }
            }
        }
        #expect(count == 8_736)                                                // §3.3, §5.7
    }

    /// 1,204 COUNT forms + 10 PARITY forms = 1,214.
    @Test("All 1,214 aggregates are one Tally each")
    func aggregatesAreExhaustive() throws {
        var counts = 0, parities = 0
        for set in AttributeSet.countable {                    // 5 sets: four of size 3, one of size 4
            for rankSubset in Subset4.usable {                 // 14
                for countSet in CountSet.properNonEmpty(over: set.count) {
                    let node = LawNode.count(attributes: set, rankIn: rankSubset, countIn: countSet)
                    #expect(LawNode(BenchLayout(node)) == node.renderedNormalForm)
                    counts += 1
                }
            }
            for bit in UInt8(0)...1 {
                let node = LawNode.parity(attributes: set, bit: bit)
                #expect(LawNode(BenchLayout(node)) == node.renderedNormalForm)
                parities += 1
            }
        }
        #expect(counts == 1_204)
        #expect(parities == 10)
    }

    @Test("The parity table's ceiling: nothing the Bench builds exceeds depth 2 or four leaves")
    func benchCeilingIsTheGrammarCeiling() throws {
        for layout in Corpora.sampleLayouts {
            guard let node = LawNode(layout) else { continue }
            #expect(node.depth <= LawNode.maxDepth)
            #expect(node.leafCount <= LawNode.maxLeaves)
        }
    }
}
```

Create `HunchCore/Tests/BenchTests/BenchFuzzerTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import Bench
import LawGeneration            // SplitMix64 only
import HunchTestSupport

@Suite("The Bench fuzzer — every configuration parses or is barred", .tags(.unit, .presubmission))
struct BenchFuzzerTests {

    /// §4.4's backward direction. Parameterised over eight seeds so one failing shard names itself;
    /// the 25,000 configurations inside each are a deliberate `T21` deviation (`08 §5`).
    @Test("Random configurations parse or bar", arguments: 0..<8)
    func everyConfigurationParsesOrBars(_ shard: Int) throws {
        var rng = SplitMix64(seed: Corpora.fuzzerSeed(shard: shard))
        for index in 0..<Corpora.fuzzerConfigurationsPerShard {
            let layout = BenchLayout.random(using: &rng)

            let parsed = LawNode(layout)
            let bar = layout.sealBar

            let failure: String? =
                if parsed == nil && bar == nil { "neither parsed nor barred" }
                else if let node = parsed, !node.isGrammarValid { "parsed to an invalid AST" }
                else if parsed == nil, case .constantExtension = bar { "barred as constant but did not parse" }
                else { nil }

            guard let failure else { continue }
            Attachment.record(layout, named: "fuzz-shard\(shard)-index\(index).json")   // 06 T18a
            Issue.record("\(failure) — reproduce with Corpora.fuzzerSeed(shard: \(shard)), index \(index)")
            return
        }
    }

    @Test("A barred layout is barred for exactly one reason, and the first one that applies",
          arguments: 0..<8)
    func barIsDeterministicAndOrdered(_ shard: Int) throws {
        var rng = SplitMix64(seed: Corpora.fuzzerSeed(shard: shard))
        for _ in 0..<Corpora.fuzzerConfigurationsPerShard {
            let layout = BenchLayout.random(using: &rng)
            #expect(layout.sealBar == layout.sealBar)          // pure: same input, same answer
            if case .inertRail(let rail)? = layout.sealBar {
                #expect(layout.rails.indices.contains(rail))
            }
            if case .unboundSocket(let rail)? = layout.sealBar {
                #expect(layout.rails.indices.contains(rail))
            }
        }
    }

    @Test("Known bad configurations stay fixed", arguments: Corpora.knownBadLayouts)
    func knownBadLayoutsRegress(_ layout: BenchLayout) throws {
        #expect(LawNode(layout) != nil || layout.sealBar != nil)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter BenchTests`
The guard and aggregate exhaustiveness tests must fail on a count mismatch or a missing constructor,
not on a compile error in the test itself.

**Step 3 — implement** whatever `BenchLayout` still needs: `BenchLayout.random(using:)`,
`LawNode.isGrammarValid`, `Subset4.usable`, `AttributeSet.countable`,
`CountSet.properNonEmpty(over:)`, and the `Corpora` fixtures.

**Step 4 — green, then refactor**, and **measure**. Time the fuzzer suite on its own:

```bash
cd HunchCore && START=$SECONDS && swift test --filter BenchFuzzerTests && echo "$((SECONDS-START))s"
```

If it exceeds ~1 s, re-tag the suite `.tags(.integration, .nightly)`, keep a
`.presubmission` shard-0-only smoke, and add the full run to `Nightly.xctestplan`. Do not delete it
and do not shrink the configuration count (`06 T58`).

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/BenchTests/BenchRoundTripTests.swift` |
| create | `HunchCore/Tests/BenchTests/BenchFuzzerTests.swift` |
| modify | `HunchCore/Sources/Bench/BenchLayout.swift` — whatever the round-trip proves is missing |
| modify | `HunchCore/Sources/Laws/LawNode.swift` — `isGrammarValid`, `depth`, `maxDepth`, `maxLeaves` if E05 did not ship them |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `fuzzerSeed(shard:)`, `fuzzerConfigurationsPerShard`, `symmetricContextualForms`, `knownBadLayouts`, `BenchLayout.transposingLayout(_:)` |
| modify | `Nightly.xctestplan` — only if the fuzzer measures over ~1 s |
| modify | `tests.json` — one entry for G10 round-trip + fuzzer |

`BenchLayout.random(using:)` is **test support**, not shipping code, but it takes an
`inout some RandomNumberGenerator` and therefore cannot live under `HunchCore/Sources/Bench/` where
the hygiene grep bans `.random(` — put it in `HunchTestSupport` as
`extension BenchLayout { static func random(using:) }`, which is a `.target` absent from `products:`
and so never reaches the release binary (`01 P20`, `06 T5a`).

## Implementation notes

### Why node identity and not extension identity

§5.3 gives the argument and it is worth internalising rather than paraphrasing: the extension test
has a blind spot exactly where the Bridge is most fragile. The `transposingEncoderIsCaught…` test
above is the executable form of that argument — it constructs the bug the design predicts and shows
that only the node test sees it. Keep that test even after G10 is green; it is the reason G10 is
spelled the way it is, and without it a future "optimisation" to an extension comparison looks
harmless.

RNF gives one law exactly one layout (§3.4), so demanding node identity costs nothing. If a node
round-trips to a *different but equivalent* node, the bug is in `BenchLayout.init` or in RNF, never
in this test.

### What the fuzzer must generate

Uniform random bytes into a `Codable` decoder is a different test (T03 already covers malformed
decoding). This fuzzer generates configurations **a player could reach through §4.2's gesture
inventory**, which means:

| Field | Range the fuzzer draws from |
|---|---|
| rail count | 0, 1, 2 — 0 is reachable by swiping both rails clear |
| tile class per rail | ramp / bridge / fork / tally, uniform |
| coupler | present iff two rails; `and` / `or` / `xor` |
| ramp `lit` | **0…15**, including the two inert states |
| bridge sockets | each independently unbound or any of the four attributes, including equal |
| bridge ghost | trailing socket only, both states |
| comparator | all six |
| fork gate | unbound, or any attribute × any of four values; branch attribute independent, including equal to the gate |
| fork docks | each 0…15 independently, including equal to each other |
| tally counted set | **all 16 subsets**, including the sub-minimum ones the tile refuses |
| tally mode | count with any rank subset 0…15 and any count set 0…31, or parity with bit 0/1 |

Drawing the *illegal* values is the point: those are the layouts that must bar rather than crash,
and a fuzzer that only draws legal values proves nothing §4.4 does not already prove forwards.

Use `SplitMix64` and integer-only draws — `Int.random` and `Double.random` are banned in this
project's core and their stability across toolchains is not guaranteed, which would make a fuzzer
failure irreproducible on the next Swift release.

### The three-way invariant, stated exactly

For every configuration, exactly one of these holds:

1. `LawNode(layout) != nil` **and** `layout.sealBar == nil` — the machine is ready.
2. `LawNode(layout) != nil` **and** `layout.sealBar == .constantExtension` — a complete draft with a
   constant extension. It parses; the Seal refuses.
3. `LawNode(layout) == nil` **and** `layout.sealBar` is `.inertRail` or `.unboundSocket` — the draft
   is not yet a law.

Anything else is a failure. Note case 2: "parses **or** is barred" is an inclusive or, and the
constant draft is exactly the overlap §4.4 admits.

### Promoting failures

Every fuzzer failure prints its shard and index and attaches the offending layout. Copy the layout's
JSON into `Corpora.knownBadLayouts` and it re-runs forever as its own parameterised case
(`06 T23`, `06 T53`). That promotion is the entire compensation for having no shrinker; skipping it
turns a found bug into a bug you will find again next month with a different seed.

### Budget

10,138 exhaustive round-trips plus 200,000 fuzzed configurations is the second-largest thing in the
fast suite after the 10,000-law corpus. Two levers if it is tight: the 8,736-guard sweep is already
`.nightly` above (its `.presubmission` cover is the fuzzer, which reaches Forks constantly), and the
fuzzer shards cleanly. §5.7's budget is `swift test` under 10 s in total and the epic gate measures
it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter BenchTests` is green.
- [ ] The four exhaustive counts assert 56, 36, 96 and 1,214 (1,204 + 10), and the nightly guard
      sweep asserts 8,736 — matching §3.3 and §5.7 without restating them in prose.
- [ ] `LawNode(BenchLayout(node)) == node.renderedNormalForm` holds for every node in all five
      sweeps.
- [ ] Exactly eight contextual forms are shown invisible to an extension round-trip, they are the
      `==`/`!=` same-attribute forms, and the transposing encoder is caught by the node test on all
      eight.
- [ ] 200,000 fuzzed configurations satisfy the three-way invariant with no failure.
- [ ] The fuzzer's runtime is measured and recorded in `PROGRESS.md`; if it exceeded ~1 s it is
      tagged `.nightly` with a `.presubmission` smoke shard and `Nightly.xctestplan` includes it.
- [ ] `Corpora.knownBadLayouts` exists, is `Codable`, and is wired to a parameterised regression test
      even while empty.
- [ ] `tests.json` has a G10 round-trip + fuzzer entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T04: G10 node identity over §4.4's parity table, plus the 200k Bench fuzzer"`

## Out of scope

- G10 as a *guardrail the generator runs* — **T05** wires it into the predicate list; this task
  proves the round-trip itself.
- The 10,000-law corpus, which checks G10 on generated laws rather than on enumerated forms — **T09**.
- The palette ceiling, which decides whether a tile class is available to this player at all —
  **E09·T04**.
- Any drawing, any gesture, any VoiceOver label — **E09**.
