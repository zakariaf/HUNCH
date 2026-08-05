# T04 — RNF canonicaliser

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | RNF canonicaliser |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | `RenderedNormalForm.swift` holds an extension on `LawNode` and no new top-level type, which is one of the three sanctioned shapes (`01 P25`) and is exactly what `08 §1`'s tree names. The skill also owns `W29` — every fold in this file switches exhaustively over `LawNode`, `Coupler` and `Comparator` with no `default:`, because a new production must break canonicalisation at compile time rather than silently pass through. |
| `hunch-swift-testing` | Idempotence and one-law-one-layout are property assertions over a seeded corpus, and the corpus argument type must be `Codable` so a failing spelling re-runs alone (`06 T23`). The skill also forbids asserting a golden *order* out of an RNG — assert the invariant (`rnf(rnf(x)) == rnf(x)`), not a recorded output. |

## Objective

`LawNode.renderedNormalForm` exists and implements §3.4's five RNF steps, so one law gets exactly one tile layout forever. `LawNode.constantFold` exists and answers "is this draft's extension all-0 or all-1?", which is the third of the three conditions that bar the Seal (§4.3). Together they are what makes E06's G10 — `LawNode(BenchLayout(law)) == law.renderedNormalForm`, node-identical — a meaningful statement.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.4 | The five RNF steps in order, and the closing sentence: "**RNF guarantees *one law, one tile layout, forever*. It is explicitly not the equivalence test.**" |
| `GAME_DESIGN.md` | §3.1 | The complement-closure proof, production by production — the seven identities `LawNode.complemented` implements. |
| `GAME_DESIGN.md` | §4.2 | Why the ghost toggle sits on the **trailing** socket, and why the leading socket is always `cur`: RNF rule 3 made physical. |
| `GAME_DESIGN.md` | §4.3 | The Seal is barred while the draft's extension is constant — RNF step 5's consumer. |
| `GAME_DESIGN.md` | §4.4 | The expressiveness-parity table, whose "exhaustive" column RNF must not narrow. |
| `GAME_DESIGN.md` | §5.3 | G10: `parse(Bench.layout(for: L))` is **node-identical to `RNF(L)`**, and the paragraph explaining why an extension round-trip has a blind spot on the eight symmetric contextual forms. |
| `GAME_DESIGN.md` | §2 | The canonical `fill → shape → pips → hue` order, which is the `attrOrdinal` in the sort key. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §3 | `RenderedNormalForm.swift` in `Laws/`; G10 reads `law.renderedNormalForm`. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W19, W29, W39, W52 | `switch` expressions over a `var` per branch; no `default:`; `precondition` naming the caller's contract. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawsTests/RenderedNormalFormTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Rendered normal form", .tags(.unit, .presubmission))
struct RenderedNormalFormTests {

    // MARK: - Step 1: complement-fold is discharged by the type, and the operation still ships

    @Test("There is no negation case anywhere in the AST")
    func noNegation() {
        // GDD §3.1: "there is no `NOT` node in the AST or the UI". Step 1 of RNF therefore has
        // nothing to remove — it is discharged at the type level — and the complement OPERATION
        // is what the Bench's parse uses to push a player's negation into the operand.
        #expect(Coupler.allCases.count == 3)
        #expect(Coupler.allCases.allSatisfy { $0 == .and || $0 == .or || $0 == .xor })
    }

    @Test("Complementing a node twice is the identity", arguments: Corpora.rnfCorpus)
    func complementIsAnInvolution(_ entry: Corpora.LawCorpusEntry) {
        #expect(entry.node.complemented.complemented == entry.node.renderedNormalForm)
    }

    @Test("Complementing a node complements its extension", arguments: Corpora.rnfCorpus)
    func complementInvertsTheExtension(_ entry: Corpora.LawCorpusEntry) {
        let table = LawTable(entry.node)
        let complement = LawTable(entry.node.complemented)
        #expect(complement.popCount == table.universeSize - table.popCount)
        #expect(complement.admitRate + table.admitRate == 1.0)
    }

    @Test("Each of §3.1's seven complement identities holds", arguments: Corpora.complementIdentities)
    func complementIdentities(_ identity: Corpora.ComplementIdentity) {
        #expect(LawTable(identity.left.complemented) == LawTable(identity.right))
    }

    // MARK: - Step 2: commutative operands sort

    @Test("A coupled law and its transposition normalise to the same node")
    func commutativeSort() {
        let a = LawNode.atom(.init(attribute: .pips, subset: Subset4(rawValue: 0b1100)!))
        let b = LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b1010)!))
        for coupler in Coupler.allCases {
            #expect(LawNode.coupled(a, coupler, b).renderedNormalForm
                 == LawNode.coupled(b, coupler, a).renderedNormalForm)
        }
    }

    @Test("The sort is by (kind, attribute, comparator, operand) in that order")
    func sortKeyOrder() {
        let atom = LawNode.atom(.init(attribute: .hue, subset: Subset4(rawValue: 0b0001)!))
        let ctx = LawNode.contextual(.init(current: .fill, comparator: .eq, previous: .fill))
        // Atom (kind 0) sorts before contextual (kind 2) even though its attribute ordinal is higher.
        guard case let .coupled(lhs, _, _) = LawNode.coupled(ctx, .and, atom).renderedNormalForm else {
            Issue.record("expected a coupled node"); return
        }
        #expect(lhs == atom)
    }

    // MARK: - Step 3: contextual is always cur-leading

    @Test("Contextual operands are cur-leading by construction and the flip is total")
    func contextualOrientation() {
        // GDD §4.2: all 96 forms are reachable as leading × trailing × wedge, so cur-leading is
        // the grammar's own orientation, not a restriction. The converse reading is the flipped
        // comparator, and `Comparator.flipped` must be an involution covering all six.
        for cmp in Comparator.allCases { #expect(cmp.flipped.flipped == cmp) }
        #expect(Comparator.eq.flipped == .eq)
        #expect(Comparator.neq.flipped == .neq)
        #expect(Comparator.lt.flipped == .gt)
        #expect(Comparator.lte.flipped == .gte)
    }

    @Test("A relational term out of canonical order is reordered and its comparator flipped")
    func relationalReordering() {
        let reversed = LawNode.relational(.init(leading: .pips, comparator: .lt, trailing: .shape))
        let canonical = LawNode.relational(.init(leading: .shape, comparator: .gt, trailing: .pips))
        #expect(reversed.renderedNormalForm == canonical)
        #expect(LawTable(reversed) == LawTable(canonical))
    }

    // MARK: - Step 4: the same-attribute merge, which unmasks a two-term law as a one-term law

    @Test("Same-attribute atoms merge by set algebra", arguments: Corpora.mergeCases)
    func sameAttributeMerge(_ merge: Corpora.MergeCase) {
        #expect(LawNode.coupled(.atom(merge.left), merge.coupler, .atom(merge.right))
                    .renderedNormalForm == merge.expected)
    }

    @Test("A two-term law that merges reports one leaf afterwards")
    func mergeReducesLeafCount() {
        // AND → ∩ : `pips ∈ {1,2,3} AND pips ∈ {2,3,4}` is `pips ∈ {2,3}`.
        let left = LawNode.Atom(attribute: .pips, subset: Subset4(rawValue: 0b0111)!)
        let right = LawNode.Atom(attribute: .pips, subset: Subset4(rawValue: 0b1110)!)
        let merged = LawNode.coupled(.atom(left), .and, .atom(right)).renderedNormalForm
        #expect(merged.leafCount == 1)
        #expect(merged == .atom(.init(attribute: .pips, subset: Subset4(rawValue: 0b0110)!)))
    }

    @Test("Only same-attribute ATOMS merge — a bridge on the same attribute does not")
    func mergeIsAtomOnly() {
        let c1 = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        let c2 = LawNode.contextual(.init(current: .pips, comparator: .eq, previous: .pips))
        let node = LawNode.coupled(c1, .or, c2).renderedNormalForm
        #expect(node.leafCount == 2)
    }

    // MARK: - Step 5: constant detection

    @Test("A merge to the empty or full mask is reported as a constant, not a law")
    func constantFold() {
        let low = LawNode.Atom(attribute: .fill, subset: Subset4(rawValue: 0b0011)!)
        let high = LawNode.Atom(attribute: .fill, subset: Subset4(rawValue: 0b1100)!)
        #expect(LawNode.coupled(.atom(low), .and, .atom(high)).constantFold == .reject)   // ∩ = ∅
        #expect(LawNode.coupled(.atom(low), .or, .atom(high)).constantFold == .admit)     // ∪ = full
        #expect(LawNode.coupled(.atom(low), .xor, .atom(high)).constantFold == .admit)    // △ = full
    }

    @Test("A real law folds to no constant", arguments: Corpora.rnfCorpus)
    func realLawsAreNotConstant(_ entry: Corpora.LawCorpusEntry) {
        #expect(entry.node.constantFold == nil)
    }

    // MARK: - The two properties the gate names

    @Test("RNF is idempotent", arguments: Corpora.rnfCorpus)
    func idempotent(_ entry: Corpora.LawCorpusEntry) {
        let once = entry.node.renderedNormalForm
        #expect(once.renderedNormalForm == once)
    }

    @Test("RNF preserves the extension", arguments: Corpora.rnfCorpus)
    func extensionPreserving(_ entry: Corpora.LawCorpusEntry) {
        #expect(LawTable(entry.node) == LawTable(entry.node.renderedNormalForm))
    }

    /// One law, one layout. Every spelling in a group is a different route to the SAME law
    /// within the grammar — transposed operands, reversed relational sockets, unmerged
    /// same-attribute atoms — and all of them must land on one node.
    @Test("One law gets exactly one layout", arguments: Corpora.spellingGroups)
    func oneLawOneLayout(_ group: Corpora.SpellingGroup) throws {
        let normalised = Set(group.spellings.map(\.renderedNormalForm))
        guard normalised.count == 1 else {
            Attachment.record(group, named: "spellings-\(group.name).json")
            Issue.record("\(group.name) normalised to \(normalised.count) distinct nodes")
            return
        }
        // …and it is genuinely the same law, not merely the same syntax.
        #expect(Set(group.spellings.map { LawTable($0) }).count == 1)
    }

    @Test("RNF never widens or narrows §4.4's reachable set", arguments: Corpora.rnfCorpus)
    func structurallyValidAfterNormalisation(_ entry: Corpora.LawCorpusEntry) {
        #expect(entry.node.renderedNormalForm.structuralFault == nil)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter RenderedNormalFormTests`
The first failures must be missing symbols: `renderedNormalForm`, `constantFold`, `complemented`, `Comparator.flipped`. Once those exist, `oneLawOneLayout` is the one that will actually fail and tell you something — it fails whenever the sort key is not total, and that is the bug this suite exists to catch.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/RenderedNormalForm.swift` |
| modify | `HunchCore/Sources/Laws/Subset4.swift` — `complement`, and the set algebra returning a possibly-trivial `UInt8` |
| modify | `HunchCore/Sources/Laws/StructuralFault.swift` — **remove** `relationalOperandsOutOfOrder` (see below) |
| modify | `HunchCore/Sources/Glyphs/…` — `Comparator.flipped` and `Comparator.complement` if E02 did not ship them |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `rnfCorpus`, `spellingGroups`, `mergeCases`, `complementIdentities` |
| create | `HunchCore/Tests/LawsTests/RenderedNormalFormTests.swift` |
| modify | `DECISIONS.md` — the fourth sort-key field's spelling |
| modify | `SPEC.md` — RNF is for storage and display, never for equivalence |
| modify | `tests.json` — "RNF canonicaliser" |

## Implementation notes

### The published surface

```swift
extension LawNode {
    /// This law in Rendered Normal Form (§3.4) — the one spelling the Bench lays out and the
    /// one spelling `round-{mode}.json` stores.
    ///
    /// RNF is for **storage and display only**. It is explicitly not the equivalence test;
    /// two laws are the same law iff their extensions match (§3.6, and T05's `LawTable ==`).
    ///
    /// - Precondition: `constantFold == nil`. A draft whose extension is constant has no
    ///   normal form; the Seal is barred for exactly those (§4.3).
    /// - Complexity: O(leaves log leaves), which is at most 4 log 4.
    public var renderedNormalForm: LawNode

    /// The constant this node's extension collapses to, or `nil` if it is a real law.
    /// Drives `SealBar.constantExtension` (E06 T03) and is checked before `renderedNormalForm`.
    public var constantFold: Verdict?

    /// The law that admits exactly what this one rejects, spelled inside the grammar (§3.1).
    /// This is where a negation "introduced during editing" goes; the `NOT` never exists.
    public var complemented: LawNode
}
```

Callers check `constantFold` first. G1/G2 mean the generator never sees a constant, so the precondition is a player-path guard, not a hot-path branch.

### Step 1 — complement-fold, and where it actually happens

The AST has no negation case, so **step 1 is a no-op inside `renderedNormalForm`**. What ships is `complemented`, which is §3.1's proof turned into code, one line per identity:

| Production | Complement |
|---|---|
| `attr ∈ S` | `attr ∈ S̄` — `Subset4.complement`, total on the 14 (the complement of a non-trivial mask is non-trivial) |
| `RANK a ⋈ RANK b` | `RANK a ⋈̄ RANK b` — `Comparator.complement`: `eq↔neq`, `lt↔gte`, `lte↔gt` |
| `RANK a(cur) ⋈ PREV RANK b` | likewise |
| `x AND y` | `x̄ OR ȳ` |
| `x OR y` | `x̄ AND ȳ` |
| `x XOR y` | `x̄ XOR y` — complement **one** side only |
| `IF g THEN A ELSE B` | `IF g THEN Ā ELSE B̄` — the gate is untouched |
| `COUNT(A, S, C)` | `COUNT(A, S, C̄)` — complement the **count set**, not the rank subset |
| `PARITY(A, b)` | `PARITY(A, 1−b)` |

Every one of these is asserted by `complementIdentities` and by the extension-level test, which is stronger: `LawTable(x.complemented).popCount == universe − LawTable(x).popCount`.

Do not confuse `Comparator.complement` (negation: `lt → gte`) with `Comparator.flipped` (operand transposition: `lt → gt`). They are different functions, both involutions, and both are needed — `complement` by step 1, `flipped` by step 3. Name them apart and write both doc comments.

### Step 2 — the sort key

§3.4 names it `(kindOrdinal, attrOrdinal, cmpOrdinal, subsetBitmask)`. Three of the four are unambiguous; the fourth is not total across productions, so pin it and **record the ruling in `DECISIONS.md`**:

| Field | Value |
|---|---|
| `kindOrdinal` | `atom 0, relational 1, contextual 2, guarded 3, aggregate 4` — the BNF's own `<term> ::= <atom> \| <rel> \| <ctx>` order, extended for totality |
| `attrOrdinal` | the leading attribute's canonical index, `fill 0 → shape 1 → pips 2 → hue 3` (§2) |
| `cmpOrdinal` | `eq 0, neq 1, lt 2, lte 3, gt 4, gte 5`; an atom has no comparator and uses `0` |
| fourth field | an atom's `subset.rawValue`; for `<rel>`/`<ctx>` the **trailing** attribute's canonical index; for `<guard>`/`<aggregate>` the payload's `hashValue`-free stable ordinal (gate value then `then` then `otherwise`; attribute-set mask then `rankIn` then `countIn`) |

The fourth field must be **total and deterministic across processes** — never `hashValue`, which Swift seeds per process. If two operands compare equal on all four, the sort must still be stable; use `sorted(by:)` on a tuple that ends in a tiebreaker you can write down, and assert `oneLawOneLayout` catches any residual ambiguity.

Guards and aggregates never appear under a coupler (§4.2: a Fork or a Tally occupies the whole Bench), so their rows exist only so the key is total and the `switch` has no `default:`.

### Step 3 — orientation

Two different jobs share a step number:

- **Relational**: if `leading.canonicalIndex > trailing.canonicalIndex`, swap and apply `Comparator.flipped`. This is the only reordering RNF performs on operands.
- **Contextual**: nothing to do. `LawNode.Contextual` stores `current` and `previous` as separate fields, so a prev-leading spelling is **unrepresentable** — RNF rule 3 is discharged by T01's type. The flip still ships (`Comparator.flipped`) because the Bench's ghost toggle on the *trailing* socket is how a player reaches the converse reading (§4.2), and E06 T03's parse calls it.

Because relational order is a *normalisation* concern and not a grammar violation, **`StructuralFault` must not carry `relationalOperandsOutOfOrder`.** Remove that case if T01 left it in: a node with reversed operands is legal to hold, is what the Bench hands you, and is what RNF fixes. `structuralFault` answers "is this outside the grammar?", not "is this canonical?".

### Step 4 — the same-attribute merge

```
AND → intersection      OR → union      XOR → symmetric difference
```

Applies to **two `<atom>` operands on the same attribute only**. A Bridge on the same attribute pair does not merge — `RANK pips(cur) > PREV RANK pips OR RANK pips(cur) == PREV RANK pips` is `>=` semantically but that is an *extension* fact, and RNF is not the equivalence test (§3.4's closing line). Merging it would be a silent widening of RNF into equivalence and would break G10's node-identity promise.

The merge is what "unmasks a two-term law as a one-term law before it can be emitted" (§3.4) — it is why the generator cannot accidentally ship a band-2 skeleton whose extension is a band-1 atom, and T08's band-2 count depends on it.

### Step 5 — constant detection

The merge can produce `0b0000` or `0b1111`, which `Subset4.init?` rejects. That is the *only* structural route to a constant, but the extension route is wider — `AND` of two disjoint atoms on different attributes is satisfiable, while `x AND x̄` is not. So:

```swift
public var constantFold: Verdict? {
    let table = LawTable(self)
    if !table.isSatisfiable { return .reject }
    if !table.isFalsifiable { return .admit }
    return nil
}
```

This builds a table, so it is not free on a contextual draft (≈2 µs, §3.6). That is fine: it runs once per Bench edit, never per glyph. Document the cost with `- Complexity:` (`N47`).

### `Corpora` additions

- `rnfCorpus` — ≈512 seeded, structurally valid, non-constant laws across all six productions, `Codable`.
- `spellingGroups` — a `Codable` struct `{ name: String, spellings: [LawNode] }`, at least one group per commutative shape: transposed AND, transposed OR, transposed XOR, reversed relational, unmerged same-attribute AND/OR/XOR, and a group mixing two of these at once. Include the eight symmetric contextual forms as their own group, because §5.3 names them as G10's blind spot and RNF is what closes it.
- `mergeCases` — one per coupler × the three interesting outcomes (proper subset, disjoint, complementary), `Codable`.
- `complementIdentities` — the nine rows of the table above as `{ left: LawNode, right: LawNode }`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RenderedNormalFormTests` is green.
- [ ] `rnf(rnf(x)) == rnf(x)` holds for every element of `Corpora.rnfCorpus`.
- [ ] `LawTable(x) == LawTable(rnf(x))` holds for every element of `Corpora.rnfCorpus`.
- [ ] Every `Corpora.spellingGroups` entry normalises to exactly one node, and there are at least eight groups including the symmetric contextual forms.
- [ ] `Comparator.flipped` and `Comparator.complement` are two distinct functions, both involutions, both documented, and a test asserts `.lt.flipped == .gt` and `.lt.complement == .gte`.
- [ ] The same-attribute merge reduces `leafCount` and the merged-to-trivial cases report `constantFold != nil`.
- [ ] A same-attribute **Bridge** pair does **not** merge — `leafCount` stays 2.
- [ ] `grep -rn 'default:' HunchCore/Sources/Laws/RenderedNormalForm.swift` returns nothing.
- [ ] `grep -rn 'hashValue' HunchCore/Sources/Laws/RenderedNormalForm.swift` returns nothing (the sort key must be process-stable).
- [ ] `StructuralFault` has no `relationalOperandsOutOfOrder` case.
- [ ] `DECISIONS.md` records the fourth sort-key field's spelling per production.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T04: RNF — complement, sort, orientation, merge and constant detection"`

## Out of scope

- **Equivalence.** RNF is explicitly not the equivalence test (§3.4). Extension identity, the dedup key and lifting are T05. Do not add an `isEquivalent(to:)` to this file.
- **The Bench.** `BenchLayout`, the parse, and G10's round-trip are E06 T03/T04. This task ships the *target* of that round-trip and nothing that knows about rails or tiles.
- **The Seal bar.** `SealBar.constantExtension` is E06 T03's enum and E09 T07's behaviour; this task ships `constantFold`, the fact it reads.
- **The ghost toggle.** E09 T02 draws it; `Comparator.flipped` is its arithmetic and lives here.
- **Dead terms.** `AND(shape∈{circle}, shape∈{circle,triangle})` merges here and is *also* a dead-term case in T05 — the merge fires first and that is correct. T05 owns the ⊤/⊥ substitution.
