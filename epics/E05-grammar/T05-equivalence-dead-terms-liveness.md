# T05 — Equivalence, dead terms and liveness

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | Equivalence, dedup, liveness |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | `LawKey` is a new top-level type in `Laws/` and its name matters: it is what `codex-index.json` stores (§11.13) and what G9's `avoid` set holds (§5.3), so it must not be spelled `LawHash`, `LawIdentifier` or a bare `UInt64`. The skill also owns `W28` — a 64-bit key that is *not* an identity needs a type that says so, and a full compare on collision needs somewhere to live. |

`hunch-swift-testing` is not required here — the assertions are exhaustive over small sets and use no corpus machinery T03 has not already established. Load it if you find yourself reaching for `Attachment` or a new tag.

## Objective

The codebase gains the one comparison it will ever make: **two laws are the same law iff their extensions are bit-identical in the common space**, with lifting applied to the smaller arity. `LawKey` gives a 64-bit bucket for dedup with a documented full compare on collision. `Law.deadLeaves` implements §3.6's ⊤ **and** ⊥ substitution — both, always — and `Law.pivotalAttributes` implements attribute liveness by value permutation. G5, G6, G7 and E09's declaration verdict all become one-line calls into this task.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.6 | The whole task: "The extension is the canonical form. Syntax is never compared"; cross-class comparison by lifting; "Two laws are the same law iff their extensions are bit-identical in the common space"; dead-term detection with **both** substitutions and why (`XOR(a,b)` has no meaningful removal); attribute liveness by value permutation; the 64-bit dedup key with full compare on collision and the ≈2⁻⁴⁵ birthday figure at 300 pages. |
| `GAME_DESIGN.md` | §4.5 | "Correct iff `extension(declared) == extension(hidden)`, compared in the common space with lifting. Purely semantic." — the consumer in E09 T08. |
| `GAME_DESIGN.md` | §5.3 | G5, G6, G7 and G9's shape: G9 reads `hash(T) ∉ avoid`, the caller-supplied set and nothing else. |
| `GAME_DESIGN.md` | §11.13 | `codex-index.json` is `[UInt64]` lawKeys plus per-band counts, and it is the launch-time dedup authority. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W44, W52, N47 | Illegal states unrepresentable; no protocol for a one-implementation seam; document the contract and the complexity. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawsTests/LawEquivalenceTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Law equivalence, dead terms and liveness", .tags(.unit, .presubmission))
struct LawEquivalenceTests {

    // MARK: - Extension identity, with lifting as the only comparison

    @Test("Two spellings of one law are equal, and syntax is never consulted")
    func extensionIdentity() {
        // GDD §3.6: `RANK pips == RANK shape` and `RANK shape == RANK pips` are the same law.
        let a = LawNode.relational(.init(leading: .shape, comparator: .eq, trailing: .pips))
        let b = LawNode.relational(.init(leading: .pips, comparator: .eq, trailing: .shape))
        #expect(a != b)                                   // different nodes …
        #expect(Law(a).isSameLaw(as: Law(b)))             // … same law
    }

    @Test("A stateless declaration is judged against a contextual law in the lifted space")
    func crossArityComparison() {
        // GDD §4.5: comparison happens in the common space, so a stateless draft and a
        // contextual hidden law are comparable and simply disagree.
        let stateless = Law(LawNode.atom(.init(attribute: .pips, subset: Subset4(rawValue: 0b1100)!)))
        let contextual = Law(LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
        #expect(stateless.isSameLaw(as: contextual) == false)
        #expect(stateless.table.lifted().arity == contextual.table.arity)

        // A contextual law that ignores `prev` IS its stateless counterpart, in both directions.
        let liftedAtom = Law(LawNode.atom(.init(attribute: .hue, subset: Subset4(rawValue: 0b0011)!)))
        #expect(liftedAtom.isSameLaw(as: liftedAtom))
        #expect(liftedAtom.table.lifted() == liftedAtom.table.lifted())
    }

    @Test("Equality is symmetric and transitive over a corpus", arguments: Corpora.rnfCorpus)
    func equalityIsAnEquivalenceRelation(_ entry: Corpora.LawCorpusEntry) {
        let law = Law(entry.node)
        let normalised = Law(entry.node.renderedNormalForm)
        #expect(law.isSameLaw(as: normalised))
        #expect(normalised.isSameLaw(as: law))
        #expect(law.isSameLaw(as: law))
    }

    // MARK: - LawKey

    @Test("The key is stable across processes and derived from the table, never from the AST")
    func keyIsExtensionDerived() {
        let a = LawNode.relational(.init(leading: .shape, comparator: .eq, trailing: .pips))
        let b = LawNode.relational(.init(leading: .pips, comparator: .eq, trailing: .shape))
        #expect(Law(a).key == Law(b).key)
        #expect(Law(a).key.rawValue == Corpora.recordedKeyForRelationalEquality)
    }

    @Test("Distinct laws in a large corpus produce distinct keys")
    func keyCollisionRate() {
        let keys = Set(Corpora.rnfCorpus.map { Law($0.node).key })
        let tables = Set(Corpora.rnfCorpus.map { LawTable($0.node) })
        #expect(keys.count == tables.count)
    }

    @Test("A collision is resolved by full compare, not by the key alone")
    func collisionResolution() {
        // The key is a bucket, not an identity. `LawSet` must answer membership correctly even
        // when two different tables are forced into one bucket.
        var set = LawSet()
        let first = LawTable(Corpora.rnfCorpus[0].node)
        let second = LawTable(Corpora.rnfCorpus[1].node)
        set.insert(first, forcedKey: LawKey(rawValue: 0))
        set.insert(second, forcedKey: LawKey(rawValue: 0))
        #expect(set.contains(first))
        #expect(set.contains(second))
        #expect(set.count == 2)
    }

    // MARK: - Dead terms: BOTH substitutions, always

    @Test("Removal alone catches a subsumed AND")
    func subsumedAndIsDead() {
        // GDD §3.6: AND(shape∈{circle}, shape∈{circle,triangle}) is caught by removal.
        // RNF merges it first (T04), so build it pre-normalisation.
        let narrow = LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b0001)!))
        let wide = LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b0011)!))
        let node = LawNode.coupled(narrow, .and, wide)
        #expect(Law(node).deadLeaves.isEmpty == false)
    }

    @Test("XOR has no meaningful removal, so ⊥ substitution is what catches it")
    func xorNeedsBothSubstitutions() {
        // GDD §3.6: "XOR(a,b) has no meaningful removal so it needs the pivotal test.
        //            Both substitutions are required."
        let a = LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b0011)!))
        let node = LawNode.coupled(a, .xor, a)             // structurally faulted, but the
                                                            // substitution machinery must still answer
        #expect(Law.deadLeaves(of: node, substituting: [.top]).isEmpty)
        #expect(Law.deadLeaves(of: node, substituting: [.bottom]).isEmpty == false)
    }

    @Test("A healthy law has no dead leaf", arguments: Corpora.rnfCorpus)
    func healthyLawsHaveNoDeadTerms(_ entry: Corpora.LawCorpusEntry) {
        #expect(Law(entry.node).deadLeaves.isEmpty)
    }

    @Test("Dead-term detection costs eight rebuilds on a four-leaf contextual law")
    func deadTermCost() {
        // GDD §3.6: "Cost for a 4-leaf contextual law: 8 rebuilds ≈ 16 µs, at generation only."
        let four = Corpora.fourLeafContextualLaw
        #expect(Law.rebuildCount(forDeadTermScanOf: four) == 8)
    }

    // MARK: - Attribute liveness

    @Test("A named attribute that cannot change the verdict is not pivotal")
    func liveness() {
        let law = Law(LawNode.atom(.init(attribute: .fill, subset: Subset4(rawValue: 0b0100)!)))
        #expect(law.pivotalAttributes == [.fill])
        #expect(law.node.namedAttributes == [.fill])
        #expect(law.hasLiveNamedAttributes)                 // G6
    }

    @Test("Liveness is permutation invariance, in both positions for a contextual law")
    func contextualLiveness() {
        // `RANK pips(cur) == PREV RANK pips` is invariant under permuting pips in BOTH positions
        // at once, yet pips is plainly pivotal: change the current glyph's pips and the verdict
        // moves. Liveness therefore permutes the attribute in each position independently.
        let law = Law(LawNode.contextual(.init(current: .pips, comparator: .eq, previous: .pips)))
        #expect(law.pivotalAttributes == [.pips])
        #expect(law.hasLiveNamedAttributes)
    }

    @Test("Every §5.2 exemplar has every named attribute live", arguments: Corpora.bandExemplars)
    func exemplarsAreLive(_ exemplar: Corpora.BandExemplar) {
        #expect(Law(exemplar.node).hasLiveNamedAttributes)
    }

    @Test("Liveness agrees with brute-force pivotality", arguments: Corpora.rnfCorpus)
    func livenessAgreesWithBruteForce(_ entry: Corpora.LawCorpusEntry) {
        let law = Law(entry.node)
        #expect(law.pivotalAttributes == ReferenceEvaluator.pivotalAttributes(of: entry.node))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter LawEquivalenceTests`
Missing symbols first: `isSameLaw(as:)`, `LawKey`, `LawSet`, `deadLeaves`, `pivotalAttributes`. Then `contextualLiveness` is the one that will fail against a naive implementation, and it is the reason this test exists — see the implementation note below.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/LawKey.swift` |
| create | `HunchCore/Sources/Laws/LawSet.swift` |
| modify | `HunchCore/Sources/Laws/LawTable.swift` — `key`, `permuting(_:by:)`, the lifted `==` |
| modify | `HunchCore/Sources/Laws/Law.swift` — `isSameLaw(as:)`, `deadLeaves`, `pivotalAttributes`, `hasLiveNamedAttributes` |
| modify | `HunchCore/Sources/HunchTestSupport/ReferenceEvaluator.swift` — brute-force `pivotalAttributes(of:)` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `fourLeafContextualLaw`, `recordedKeyForRelationalEquality` |
| create | `HunchCore/Tests/LawsTests/LawEquivalenceTests.swift` |
| modify | `SPEC.md` — "extension identity is the only comparison" as a stated rule with its consumers named |
| modify | `tests.json` — "Equivalence, dedup, liveness" |

## Implementation notes

### Extension identity, and the fact that it is the *only* comparison

```swift
extension Law {
    /// Whether this is the same law as `other` — §3.6's only test.
    ///
    /// Extensions are compared bit-for-bit in the **common space**: if the arities differ, the
    /// stateless one is lifted (§3.6). Spelling, operand order, coupler choice and complement
    /// direction are all irrelevant, which is exactly what §4.5 promises the player.
    /// - Complexity: O(1) stateless, O(1024 words) mixed or contextual.
    public func isSameLaw(as other: Law) -> Bool {
        LawTable.equalInCommonSpace(table, other.table)
    }
}
```

Put a one-line rule in `SPEC.md`: **nothing in HUNCH ever compares two laws by AST except G10**, which compares node identity on purpose because an extension test has a blind spot on the eight symmetric contextual forms (§5.3). If a later epic writes `lawA.node == lawB.node` to decide sameness, that is a bug and this line is what a reviewer cites.

Consumers, so the search is easy later: E09 T08 declaration verdict; E11 T06 `avoid` assembly; E12 T01 D-guardrails; E15 T06 duplicate detection; E06 T05 G4/G9.

### `LawKey` and `LawSet`

```swift
/// A 64-bit bucket for a law's extension. **Not an identity** — §3.6 requires a full compare
/// on collision, and `LawSet` is where that happens. At 300 stored Codex pages the birthday
/// probability is ≈2⁻⁴⁵ (§3.6), which is why 64 bits is enough and why the full compare is
/// still written.
public struct LawKey: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UInt64
}
```

The hash must be **stable across processes and releases** — `codex-index.json` persists it (§11.13) and `determinism-seeds-v1.json` (E06 T10) freezes it. So:

- Never `Hasher`/`hashValue`: Swift seeds it per process.
- Fold the raw `UInt64` words with a written-down mixing function. Reuse `SplitMix64`'s finaliser, which §11.6 already fixes for the Anomaly and which E01 T05 already shipped — do not re-type the constants (`hunch-swift-concurrency` gotcha: "`anomalySeed` must *call* the finaliser, not re-type it"; the same applies here).
- Record one recomputed value in `Corpora.recordedKeyForRelationalEquality` and assert it, so a change to the mixing function fails loudly instead of silently orphaning every Codex page.

`LawSet` is a plain `struct LawSet: Sendable` over `[LawKey: [LawTable]]` with `insert`, `contains(_ table:)` and `count`. The `forcedKey:` overload in the test is `internal`/`package` and exists only to exercise the collision path — a bucket collision is otherwise unreachable in a test, and an unreachable branch is an untested branch.

### Dead terms — both substitutions, always

```swift
extension Law {
    public enum LeafSubstitution: Hashable, Sendable { case top, bottom }

    /// Leaves whose presence does not change the extension (§3.6, G5).
    ///
    /// For each leaf: rebuild with ⊤ substituted, rebuild with ⊥ substituted. If **either**
    /// rebuild equals the original extension, the leaf is dead. Both substitutions are
    /// required: a subsumed `AND` is caught by removal, and `XOR(a, b)` has no meaningful
    /// removal at all, so it is only caught by the ⊥ rebuild (§3.6).
    /// - Complexity: 2 × leafCount table rebuilds — ≈16 µs for a four-leaf contextual law.
    ///   Generation-time only; never call this in a hot loop.
    public var deadLeaves: [LawNode.Leaf]
}
```

Substitution is a *resolver* parameter, not an AST edit — the grammar has no ⊤ or ⊥ node and T01 must not gain one. Extend T02's resolver:

```swift
extension LawTable {
    /// Resolve `node`, forcing the leaf at `index` to the given constant.
    package init(_ node: LawNode, forcingLeaf index: Int, to constant: Bool)
}
```

Walk the AST once counting leaves and, at the forced index, substitute `Bitboard.full` or `Bitboard.empty` instead of the mask. Do not implement this by rewriting the node — that would need a constant production and would leak into `Codable`.

### Attribute liveness — the trap this test exists to catch

§3.6: *"Attribute `a` is live iff `T != permute_a(T)` for at least one of the three non-identity value permutations of `a`."*

The naive contextual implementation applies the permutation to **both** the `prev` and `cur` halves of the pair index at once. Under that reading `RANK pips(cur) == PREV RANK pips` is invariant — equality survives any relabelling applied to both sides — so `pips` reads as dead and the entry-level contextual law of §3.3, the one that *"must exist"*, is rejected by G6. That would silently delete a slice of bands 5 and 7.

The correct reading is **dependence**, which is what "pivotal" means in G6's own wording: permute the attribute's values in the `cur` position and in the `prev` position *independently*, and the attribute is live if either changes the table.

```swift
extension LawTable {
    /// This table with attribute `attribute`'s four values relabelled by `permutation`,
    /// applied to `position` only.
    package func permuting(_ attribute: Attribute, by permutation: [UInt8],
                           in position: Position) -> LawTable        // .current | .previous
}

extension Law {
    /// - Complexity: O(3 × 2 × 4) table permutes — microseconds (§3.6).
    public var pivotalAttributes: Set<Attribute>
    /// G6: every attribute the law names is pivotal.
    public var hasLiveNamedAttributes: Bool { node.namedAttributes.isSubset(of: pivotalAttributes) }
}
```

For a stateless table `.previous` is a no-op. Three non-identity permutations are enough for a correctness argument — invariance under all transpositions implies independence, and the three transpositions generate the group — but write the doc comment saying which three you chose, because a different three is a different (equally valid) test and a reader will ask.

`ReferenceEvaluator.pivotalAttributes(of:)` is the independent check: for every glyph and every alternative value, does flipping that one attribute change the verdict? Written longhand, shared with nothing.

### G5/G6/G7 are E06's, but their predicates are here

E06 T05 assembles the ten guardrails as ordered predicates. This task ships the three they call:

| Guardrail | Call |
|---|---|
| G5 no dead terms | `law.deadLeaves.isEmpty` |
| G6 attribute liveness | `law.hasLiveNamedAttributes` |
| G7 genuinely contextual | `law.table.isSecretlyStateless == false` (T02) |

Do not name them `g5`, `g6`, `g7` here. The guardrail *ordering* and its cheap-to-expensive schedule belong to E06.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter LawEquivalenceTests` is green.
- [ ] `Law(RANK shape == RANK pips).isSameLaw(as: Law(RANK pips == RANK shape))` is `true` while the two nodes are `!=`.
- [ ] `LawKey` derives from the table's words via `SplitMix64`'s finaliser and contains no `Hasher`, no `hashValue` and no re-typed constants: `grep -n 'hashValue\|Hasher' HunchCore/Sources/Laws/LawKey.swift` returns nothing.
- [ ] `Corpora.recordedKeyForRelationalEquality` is a written-down `UInt64` and the test asserting it passes.
- [ ] `LawSet` returns the correct membership for two distinct tables forced into one bucket, and `count == 2`.
- [ ] `deadLeaves` catches the subsumed `AND` **and** the `XOR` case, and the `XOR` case is caught only by the ⊥ substitution.
- [ ] `Law.rebuildCount(forDeadTermScanOf:)` is `8` for a four-leaf contextual law (§3.6's stated cost).
- [ ] `Law(RANK pips(cur) == PREV RANK pips).hasLiveNamedAttributes` is `true` — the trap above.
- [ ] `pivotalAttributes` agrees with `ReferenceEvaluator.pivotalAttributes(of:)` for every element of `Corpora.rnfCorpus`.
- [ ] `SPEC.md` names extension identity as the only law comparison, with G10's node identity as the single stated exception.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T05: extension identity, LawKey, dead terms and attribute liveness"`

## Out of scope

- **The guardrails themselves.** G1–G10 as named, ordered, individually testable predicates are E06 T05. This task ships three of the facts they read.
- **`avoid` assembly.** The 50-entry novelty ring, the per-band soft-avoid and today's Anomaly are the serving layer, E11 T06. G9 reads only the caller-supplied set (§5.3).
- **The lower-band index.** Storing keys and tables in sorted, band-partitioned runs is T07. `LawSet` is an in-memory helper, not the on-disk index.
- **Codex dedup.** `codex-index.json` as the launch-time dedup authority is E15 T01; it stores `LawKey.rawValue` and calls `LawSet` semantics, but the file, the lazy shelves and the 512 KB assertion are not here.
- **Declaration verdict UI.** E09 T08 calls `isSameLaw(as:)`; the two-ring counterexample and the strike are not this task.
