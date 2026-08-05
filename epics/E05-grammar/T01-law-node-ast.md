# T01 — LawNode, the AST

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (E02 must be merged) |
| **Delivers** | Rule AST + BNF |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task creates the first files in `HunchCore/Sources/Laws/`. It decides package, target, file, name and type kind — the skill's five-decisions procedure in order. It also owns the two collisions that bite here: `LawNode` and `Law` are **two files, not one** (they are two top-level types with different conformances), and the nested-payload exception that lets `LawNode`'s five payload structs share `LawNode.swift`. |

`hunch-swift-testing` is not loaded for this task: the assertions here are shape assertions on a value type and the suite mechanics are the plain form. Load it from T03 onward, where corpora and attachments start.

## Objective

`HunchCore/Sources/Laws/LawNode.swift` exists and spells §3.2's BNF as an `indirect enum` that can hold nothing the grammar forbids: five productions, one coupler, no `NOT`, `MAX_DEPTH 2`, `MAX_LEAVES 4`, and the four structural caps reported as a `StructuralFault?` rather than a `Bool`. Nothing else in the repo can yet resolve a law to a table — that is T02 — but from here on every law in HUNCH is one of these values.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.1 | Why there is exactly one atomic form and **no `NOT` node** — the complement-closure proof, production by production. Read it; the absence of `NOT` is the single most load-bearing thing about this type. |
| `GAME_DESIGN.md` | §3.2 | The BNF, verbatim. Every case, every operand constraint (`<rel>` attrs distinct and in canonical order; `<ctx>` attrs may be equal; `<guard>` gate attr ≠ branch attr, both branches on the same attr, branches differ; `<subset4>` is 14 values; `<attrSet>` is `\|set\| ≥ 3`; `<countSet>` is a non-empty proper subset). |
| `GAME_DESIGN.md` | §3.3 | The exhaustive predicate inventory — 56 / 36 / 96 / 8,736 / 1,214. T08 asserts these; this task must make every one of them *representable* and nothing else. |
| `GAME_DESIGN.md` | §3.4 | `MAX_DEPTH`, `MAX_LEAVES`, and the four additional structural caps. |
| `GAME_DESIGN.md` | §5.4 | The `~40 B on disk` budget and why the resolved `LawNode` — never a `(seed, band, targetδ, mode)` recipe — is what a suspended round stores. |
| `GAME_DESIGN.md` | §5.7 | The locked constants row `MAX_DEPTH / MAX_LEAVES = 2 / 4 (guard = exactly 3 leaves)` and the `1 / 2 / 2` cap row. |
| `GAME_DESIGN.md` | §2 "Locked terminology" | The verbatim enum spellings and the canonical `fill → shape → pips → hue` ordering that every commutative sort in this codebase uses. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §3 | `LawNode.swift` and `Law.swift` are separate files in `Laws/`; `LawNode` is `Codable` and `Law` is not. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W2, W28, W29, W39, W51–W53 | Type choice (a recursive tree is an `indirect enum`); illegal states unrepresentable; no `default:`; `precondition` naming the caller's contract; doc-comment shape. |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24, P25(a), P28 | One top-level type per file; the nested-payload exception; the banned-filename grep. |

Never restate a value the spec owns. `Subset4`'s legal range, the guard's operand rules and the cap numbers are cited above — read them there.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawsTests/LawNodeTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws

@Suite("Law AST", .tags(.unit, .presubmission))
struct LawNodeTests {

    // MARK: - The five productions are representable, and their inventories are the right size

    @Test("Subset4 admits exactly the 14 non-trivial masks")
    func subsetInventory() {
        let legal = (0...255).compactMap { Subset4(rawValue: UInt8($0)) }
        #expect(legal.count == 14)                       // GDD §3.1: 2^4 - 2
        #expect(Subset4(rawValue: 0b0000) == nil)        // empty forbidden
        #expect(Subset4(rawValue: 0b1111) == nil)        // full forbidden
    }

    @Test("Every atomic form is representable and none other is")
    func atomInventory() {
        var built: Set<LawNode> = []
        for attribute in Attribute.allCases {
            for subset in Subset4.all {
                built.insert(.atom(.init(attribute: attribute, subset: subset)))
            }
        }
        #expect(built.count == 56)                       // GDD §3.3, Atomic
    }

    @Test("Relational forms are 36 and forbid equal attributes")
    func relationalInventory() {
        var built: Set<LawNode> = []
        for a in Attribute.allCases {
            for b in Attribute.allCases where a.canonicalIndex < b.canonicalIndex {
                for cmp in Comparator.allCases {
                    built.insert(.relational(.init(leading: a, comparator: cmp, trailing: b)))
                }
            }
        }
        #expect(built.count == 36)                       // GDD §3.3, Relational

        let degenerate = LawNode.relational(.init(leading: .pips, comparator: .lt, trailing: .pips))
        #expect(degenerate.structuralFault == .relationalOperandsEqual(.pips))
    }

    @Test("Contextual forms are 96 and DO allow equal attributes")
    func contextualInventory() {
        var built: Set<LawNode> = []
        for a in Attribute.allCases {
            for b in Attribute.allCases {
                for cmp in Comparator.allCases {
                    built.insert(.contextual(.init(current: a, comparator: cmp, previous: b)))
                }
            }
        }
        #expect(built.count == 96)                       // GDD §3.3, Contextual

        // GDD §3.3: `RANK pips(cur) > PREV RANK pips` is the entry-level contextual law
        // and MUST exist. If this ever faults, the whole contextual ladder is unreachable.
        let entry = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        #expect(entry.structuralFault == nil)
    }

    @Test("Guard forms are 8,736 and reject the three degenerate spellings")
    func guardInventory() {
        var built: Set<LawNode> = []
        for gate in Attribute.allCases {
            for branch in Attribute.allCases where branch != gate {
                for value in 0..<4 {
                    for then in Subset4.all {
                        for otherwise in Subset4.all where otherwise != then {
                            built.insert(.guarded(.init(gate: gate, gateValue: UInt8(value),
                                                        branch: branch, then: then, otherwise: otherwise)))
                        }
                    }
                }
            }
        }
        #expect(built.count == 8_736)                    // GDD §3.3, Guard

        let sameAttribute = LawNode.guarded(.init(gate: .hue, gateValue: 0, branch: .hue,
                                                  then: Subset4(rawValue: 0b0001)!,
                                                  otherwise: Subset4(rawValue: 0b0010)!))
        #expect(sameAttribute.structuralFault == .guardGateEqualsBranch(.hue))

        let equalBranches = LawNode.guarded(.init(gate: .hue, gateValue: 0, branch: .pips,
                                                  then: Subset4(rawValue: 0b0011)!,
                                                  otherwise: Subset4(rawValue: 0b0011)!))
        #expect(equalBranches.structuralFault == .guardBranchesEqual(.pips))
    }

    @Test("Aggregate forms are 1,214 — 1,204 COUNT plus 10 PARITY")
    func aggregateInventory() {
        var counts: Set<LawNode> = []
        var parities: Set<LawNode> = []
        for set in AttributeSet.all {                    // |set| >= 3, so 5 values
            for rankIn in Subset4.all {
                for countSet in CountSet.all(over: set.count) {
                    counts.insert(.aggregate(.count(.init(attributes: set, rankIn: rankIn, countIn: countSet))))
                }
            }
            for bit in [false, true] {
                parities.insert(.aggregate(.parity(.init(attributes: set, isOdd: bit))))
            }
        }
        #expect(AttributeSet.all.count == 5)             // GDD §3.2, <attrSet>
        #expect(counts.count == 1_204)                   // GDD §3.3, Aggregate
        #expect(parities.count == 10)
    }

    // MARK: - Leaf counting, which every downstream modifier reads

    @Test("A leaf is one (attribute, comparator, operand) triple",
          arguments: [
            (LawNode.atom(.init(attribute: .fill, subset: Subset4(rawValue: 0b0100)!)), 1),
            (LawNode.relational(.init(leading: .shape, comparator: .eq, trailing: .pips)), 1),
            (LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips)), 1),
          ])
    func singleTermsAreOneLeaf(_ node: LawNode, _ expected: Int) {
        #expect(node.leafCount == expected)
    }

    @Test("A guard is exactly three leaves and an aggregate is one per counted attribute")
    func compositeLeafCounts() throws {
        // GDD §5.7: "MAX_DEPTH / MAX_LEAVES = 2 / 4 (guard = exactly 3 leaves)"
        let fork = LawNode.guarded(.init(gate: .hue, gateValue: 0, branch: .pips,
                                         then: Subset4(rawValue: 0b1100)!,
                                         otherwise: Subset4(rawValue: 0b0001)!))
        #expect(fork.leafCount == 3)

        // GDD §5.2's band-8 exemplar names three attributes; MAX_LEAVES 4 is the four-attribute Tally.
        let three = try #require(AttributeSet(.fill, .shape, .pips))
        let four = try #require(AttributeSet(.fill, .shape, .pips, .hue))
        let countThree = LawNode.aggregate(.count(.init(attributes: three,
                                                        rankIn: Subset4(rawValue: 0b1100)!,
                                                        countIn: try #require(CountSet(rawValue: 0b1100, over: 3)))))
        let parityFour = LawNode.aggregate(.parity(.init(attributes: four, isOdd: false)))
        #expect(countThree.leafCount == 3)
        #expect(parityFour.leafCount == 4)
        #expect(parityFour.leafCount == LawNode.maxLeaves)
    }

    @Test("A coupler over two terms is depth 2 and no deeper node exists")
    func depth() {
        let left = LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b1010)!))
        let right = LawNode.atom(.init(attribute: .pips, subset: Subset4(rawValue: 0b1100)!))
        let coupled = LawNode.coupled(left, .and, right)
        #expect(left.depth == 1)
        #expect(coupled.depth == 2)
        #expect(coupled.depth == LawNode.maxDepth)

        // A coupler whose operand is itself a coupler is depth 3 and must fault, not trap.
        let nested = LawNode.coupled(coupled, .or, right)
        #expect(nested.structuralFault == .depthExceeded(3))
    }

    // MARK: - The four structural caps of §3.4

    @Test("At most one relational term")
    func relationalCap() {
        let r1 = LawNode.relational(.init(leading: .fill, comparator: .eq, trailing: .shape))
        let r2 = LawNode.relational(.init(leading: .pips, comparator: .lt, trailing: .hue))
        #expect(LawNode.coupled(r1, .and, r2).structuralFault == .tooManyRelationalTerms(2))
    }

    @Test("At most two contextual terms — and exactly two is legal")
    func contextualCap() {
        let c1 = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        let c2 = LawNode.contextual(.init(current: .hue, comparator: .eq, previous: .hue))
        #expect(LawNode.coupled(c1, .xor, c2).structuralFault == nil)
    }

    @Test("A coupler may only stand over two terms — never over a guard or an aggregate")
    func couplerOverNonTerm() {
        // GDD §3.2: `<law> ::= <term> | <term> <coupler> <term> | <guard> | <aggregate>` and
        // `<term> ::= <atom> | <rel> | <ctx>`. §4.2 says the same thing physically: a Fork or a
        // Tally occupies the whole Bench and has no coupler.
        let fork = LawNode.guarded(.init(gate: .hue, gateValue: 0, branch: .pips,
                                         then: Subset4(rawValue: 0b1100)!,
                                         otherwise: Subset4(rawValue: 0b0001)!))
        let atom = LawNode.atom(.init(attribute: .pips, subset: Subset4(rawValue: 0b0011)!))
        #expect(LawNode.coupled(fork, .and, atom).structuralFault == .couplerOverNonTerm)
    }

    @Test("At most two leaves per attribute — the cap that only a corrupt decode can break")
    func perAttributeCap() throws {
        // Inside the grammar this cap is unreachable: a coupler stands over at most two terms
        // and therefore two leaves, a guard is 1 + 2, and an aggregate names each attribute once.
        // It is checked anyway, because `round-{mode}.json` is decoded from disk (§11.13) and a
        // tampered or truncated file must fault rather than resolve to a table (§5.4).
        // `Corpora.tamperedThreeOnPips` is a committed JSON blob encoding an aggregate whose
        // attribute set has been rewritten to name `pips` three times — a shape the initialisers
        // refuse but the decoder can produce.
        let node = try JSONDecoder().decode(LawNode.self, from: Corpora.tamperedThreeOnPips)
        #expect(node.structuralFault == .tooManyLeavesOnAttribute(.pips, 3))
    }

    @Test("No two leaves share an identical (attribute, comparator, operand) triple")
    func duplicateLeafRejected() {
        let atom = LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b0110)!))
        #expect(LawNode.coupled(atom, .or, atom).structuralFault == .duplicateLeaf)
    }

    @Test("A well-formed law of every production reports no fault", arguments: LawNode.wellFormedSamples)
    func wellFormedSamplesAreClean(_ node: LawNode) {
        #expect(node.structuralFault == nil)
    }

    // MARK: - Codable, and the §5.4 size budget

    @Test("A law round-trips through JSON unchanged", arguments: LawNode.wellFormedSamples)
    func codableRoundTrip(_ node: LawNode) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(node)
        #expect(try JSONDecoder().decode(LawNode.self, from: data) == node)
    }

    /// GDD §5.4 budgets the suspended round's resolved law at ~40 B. JSON with single-character
    /// coding keys does not reach 40 B, so this is a **ratchet**, not a spec value: it fails when
    /// the encoding grows, and the measured figure lives in DECISIONS.md beside §5.4's estimate.
    @Test("The worst-case law stays inside the recorded encoding budget")
    func encodedSizeRatchet() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let worst = try #require(LawNode.wellFormedSamples.max { a, b in
            (try? encoder.encode(a).count) ?? 0 < (try? encoder.encode(b).count) ?? 0
        })
        let budget = 256                                  // measured, then recorded in DECISIONS.md
        #expect(try encoder.encode(worst).count <= budget)
    }
}
```

`LawNode.wellFormedSamples` is a `public static let [LawNode]` on the type — one instance of every production, including §5.2's eight exemplar laws. It lives in the source, not the test, because T03, T04, T05 and E06 all want it and `HunchTestSupport` cannot be imported by `Laws`.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter LawNodeTests`
Every test must fail with *"cannot find `LawNode` in scope"* or *"cannot find `Subset4` in scope"* — a missing symbol. If any test passes before you write a line of `Laws/`, you have a stale build; `swift package clean` and re-run. A test that passes before the implementation exists is testing nothing.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/LawNode.swift` |
| create | `HunchCore/Sources/Laws/Subset4.swift` |
| create | `HunchCore/Sources/Laws/AttributeSet.swift` |
| create | `HunchCore/Sources/Laws/CountSet.swift` |
| create | `HunchCore/Sources/Laws/StructuralFault.swift` |
| create | `HunchCore/Tests/LawsTests/LawNodeTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `tamperedThreeOnPips`, the committed corrupt-decode blob |
| modify | `HunchCore/Package.swift` — add the `Laws` target (dependency `Glyphs`) and the `LawsTests` test target, if E02 did not already |
| modify | `SPEC.md` — the leaf-counting rule and the `MAX_DEPTH`/`MAX_LEAVES` row |
| modify | `tests.json` — the "Rule AST + BNF" invariant |

## Implementation notes

### The shape

```swift
/// The abstract syntax tree of GDD §3.2's BNF. Five productions, one coupler, no `NOT`.
///
/// The type is deliberately narrower than the grammar in three places, because a value that
/// cannot exist needs no guardrail: `Subset4` rejects the empty and full masks, `Relational`
/// stores its operands in canonical attribute order, and there is no negation case at all
/// (§3.1's complement-closure proof).
public indirect enum LawNode: Hashable, Sendable, Codable {
    case atom(Atom)
    case relational(Relational)
    case contextual(Contextual)
    case coupled(LawNode, Coupler, LawNode)
    case guarded(Guard)
    case aggregate(Aggregate)
}
```

The five payloads are **nested structs in the same file** — `01 P25`'s exception (a), the same shape `hunch-swift-code`'s file-placement reference blesses for `RuleTile`'s `Ramp`/`Bridge`/`Fork`/`Tally`:

```swift
extension LawNode {
    public struct Atom: Hashable, Sendable, Codable {
        public var attribute: Attribute
        public var subset: Subset4
        public init(attribute: Attribute, subset: Subset4) { … }
    }

    /// `RANK a ⋈ RANK b`, attributes distinct.
    ///
    /// Both operand orders are **representable**: the Bench hands you whichever the player
    /// built, and RNF rule 3 (T04) reorders it and flips the comparator to compensate. Order
    /// is a normalisation concern, so `structuralFault` never reports it — only equal
    /// operands, which are constant and therefore outside the grammar (§3.3).
    public struct Relational: Hashable, Sendable, Codable {
        public var leading: Attribute
        public var comparator: Comparator
        public var trailing: Attribute
    }

    /// `RANK a(cur) ⋈ PREV RANK b`. The BNF fixes `cur` on the leading side, so the converse
    /// reading is reached by flipping the comparator and is **unrepresentable** here — which is
    /// RNF rule 3 made into a type rather than a pass (§3.4, §4.2).
    public struct Contextual: Hashable, Sendable, Codable {
        public var current: Attribute
        public var comparator: Comparator
        public var previous: Attribute
    }

    public struct Guard: Hashable, Sendable, Codable {
        public var gate: Attribute
        public var gateValue: UInt8            // 0...3, the rank-1 index into the attribute's values
        public var branch: Attribute
        public var then: Subset4
        public var otherwise: Subset4
    }

    public enum Aggregate: Hashable, Sendable, Codable {
        case count(Count)
        case parity(Parity)

        public struct Count: Hashable, Sendable, Codable {
            public var attributes: AttributeSet
            public var rankIn: Subset4
            public var countIn: CountSet
        }
        public struct Parity: Hashable, Sendable, Codable {
            public var attributes: AttributeSet
            public var isOdd: Bool
        }
    }
}
```

`Attribute`, `Comparator` and `Coupler` come from E02 — import `Glyphs` and use them verbatim. Do **not** re-declare them, and do not add a `not` case to `Coupler`.

### The three small value types

- **`Subset4`** — `public struct Subset4: Hashable, Sendable, Codable, RawRepresentable` over `UInt8`, `init?(rawValue:)` returning `nil` outside `1...14`. Ships `static let all: [Subset4]` (14, ascending), `var count: Int` (popcount), `var isContiguousRun: Bool`, and set algebra `intersection`/`union`/`symmetricDifference` returning `UInt8` (the result may be 0 or 15, which is exactly RNF's constant case — see T04). `isContiguousRun` is what T02's `scatteredSubsetCount` reads; §5.1's m5 note says 5 of the 14 are scattered, so a test in T02 asserts `Subset4.all.count(where: { !$0.isContiguousRun }) == 5`.
- **`AttributeSet`** — a bitmask over the four attributes with `|set| ≥ 3`, so exactly five values. `init?(_:)` variadic plus `static let all: [AttributeSet]`.
- **`CountSet`** — a non-empty **proper** subset of `0...|attrSet|`, so 14 values at `|attrSet| == 3` and 30 at 4. It is arity-dependent, so it carries the arity: `init?(rawValue: UInt8, over arity: Int)` and `static func all(over arity: Int) -> [CountSet]`. Encoding stores the raw mask; decoding validates against the sibling `attributes` field, which means `Aggregate.Count` needs a hand-written `init(from:)`. Write it; do not relax the type to a bare `UInt8`.

### `StructuralFault` — a fault, not a Bool

`W28`. A `var isWellFormed: Bool` cannot answer "which cap did I break?", and both the Bench's Seal bar (E09 T07) and the generator's rejection loop (E06 T06) need to know.

```swift
public enum StructuralFault: Hashable, Sendable {
    case depthExceeded(Int)
    case tooManyLeaves(Int)
    case tooManyRelationalTerms(Int)
    case tooManyContextualTerms(Int)
    case tooManyLeavesOnAttribute(Attribute, Int)
    case duplicateLeaf
    case couplerOverNonTerm
    case relationalOperandsEqual(Attribute)
    case guardGateEqualsBranch(Attribute)
    case guardBranchesEqual(Attribute)
}

extension LawNode {
    public static let maxDepth = 2                 // GDD §3.4
    public static let maxLeaves = 4

    /// The first structural rule this node breaks, or `nil` if it is grammar-valid.
    ///
    /// Checked in a fixed order so the fault is deterministic: depth, coupler-over-non-term,
    /// leaf count, term caps, per-attribute cap, duplicate leaves, then the per-production
    /// operand rules. The tests above assert that order, so do not reshuffle it casually.
    /// - Complexity: O(leaves), which is at most 4.
    public var structuralFault: StructuralFault? { … }
}
```

Switch exhaustively — **no `default:`** anywhere (`W29`). Adding a production later must break this function at compile time.

### Leaf counting — pin this now, four things downstream read it

**A leaf is one `(attribute, comparator, operand)` triple.** That is the spelling §3.4's duplicate-leaf cap uses, and it is the only reading that reproduces §5.2's eight exemplar δ values through §5.1's `m1`:

| Production | Leaves | Why |
|---|---|---|
| `<atom>` | 1 | `(attr, IN, subset)` |
| `<rel>` | 1 | `(a, cmp, RANK b)` — one Bridge, one leaf, **two named attributes** |
| `<ctx>` | 1 | `(a, cmp, PREV RANK b)` |
| `<guard>` | 3 | gate + then + else, which §5.7 states outright |
| `<aggregate>` | `attributes.count` | 3 or 4 — and this is where `MAX_LEAVES = 4` comes from |
| `<term> <coupler> <term>` | sum of the two | ≤ 2 for two single terms |

Two derived properties every later task uses, both O(leaves):

```swift
/// Every leaf, in traversal order, as the triple §3.4's duplicate cap is written in terms of.
public var leaves: [Leaf]
public var leafCount: Int { leaves.count }

/// The attributes this law *names*. `<rel>` and `<ctx>` name two; an aggregate names its set.
/// Used by §5.1's m3 (`freeAttributeCount = 4 - namedAttributes.count`) and by G6.
public var namedAttributes: Set<Attribute>
```

`Leaf` is a nested `public struct Leaf: Hashable, Sendable { var attribute: Attribute; var comparator: Comparator?; var operand: Operand }` where `Operand` is `.subset(Subset4) | .rank(Attribute) | .previousRank(Attribute) | .value(UInt8)`. The duplicate-leaf cap is then literally `Set(leaves).count == leaves.count`. Do not implement it any other way — a hand-rolled pairwise comparison will drift from the spec's wording.

### Per-attribute cap counting

`tooManyLeavesOnAttribute` counts **leaves that name the attribute**, so a `<rel>` on `(shape, pips)` contributes one to `shape` and one to `pips`. Verify against the reachable shapes: two contextual terms on the same attribute pair is 2 per attribute and legal (§5.7 caps contextual terms at 2); a guard is 1 on the gate attribute and 2 on the branch attribute, which is exactly at the cap and is why a Fork occupies the whole Bench and takes no coupler (§4.2).

### `Codable` and the size budget

Hand-write `CodingKeys` with single-character keys on every payload and a single-character discriminator on the enum. `LawNode` is what `round-{mode}.json` stores (§5.4, §11.13) and it is the smallest file written first on the disk-full path, so the encoding is not cosmetic. Measure the worst case (a four-attribute `COUNT`), write the number into `DECISIONS.md` beside §5.4's `~40 B`, and set the test's ratchet just above it.

**Do not add a `Codable` conformance to `Law`.** That is T02's type and `08 §3` makes its non-`Codable`-ness deliberate.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter LawNodeTests` is green and contains ≥ 14 `@Test` functions.
- [ ] The five inventory assertions read `56`, `36`, `96`, `8_736`, `1_204 + 10` and each cites §3.3 in a comment.
- [ ] `grep -n 'case not' HunchCore/Sources/Laws/LawNode.swift` returns nothing, and `Coupler` is imported from `Glyphs` rather than redeclared.
- [ ] `grep -rn 'default:' HunchCore/Sources/Laws/` returns nothing.
- [ ] `LawNode.maxDepth == 2` and `LawNode.maxLeaves == 4` are declared once in `LawNode.swift` and nowhere else in the repo.
- [ ] `Subset4(rawValue: 0)` and `Subset4(rawValue: 15)` both return `nil`.
- [ ] A coupler over a guard or an aggregate reports `.couplerOverNonTerm`, and the per-attribute cap fires on the committed corrupt-decode blob rather than on an in-grammar node.
- [ ] `LawNode.wellFormedSamples` contains at least one instance of each of the six cases plus §5.2's eight exemplar laws, and every element reports `structuralFault == nil`.
- [ ] The measured worst-case encoded byte count is written into `DECISIONS.md` with a citation to §5.4.
- [ ] `Scripts/check-source-hygiene.sh` passes; no file named `Extension.swift`, `Constants.swift` or `Utils.swift` was created.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T01: LawNode, Subset4, AttributeSet, CountSet and the structural caps"`

## Out of scope

- **Resolving a node to a truth table.** `LawTable`, `Law` and `Metrics` are T02. This task's tests never build a table and never mention `admitRate`.
- **RNF.** Canonical ordering of commutative operands, the same-attribute merge and constant detection are T04. `Relational` storing its operands in canonical order is a *type* constraint, not the RNF pass.
- **The Bench.** `BenchLayout`, `RuleTile` and `LawNode.init?(_ layout:)` are E06 T03. Do not add a Bench-shaped initialiser here.
- **`Band` and families.** `LawNode` knows nothing about which band it belongs to; T06 and T07 own that direction.
- **Evaluation.** No `admits`, no `evaluate`, no mask arithmetic in this task.
