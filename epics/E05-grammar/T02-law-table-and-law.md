# T02 — LawTable and Law

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Extension tables + masks · Equivalence, dedup, liveness (the metrics half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | It owns the two decisions this task turns on: the design's word "**extension**" is a Swift keyword, so it ships as `struct LawTable` and `Extension.swift` would trip the banned-filename grep (`01 P28`); and `LawNode` is `Codable` while `Law` deliberately is not, because the resolved table and cached metrics are rebuilt. It also owns `- Complexity:` on any non-O(1) property (`N47`), which is the entire justification for caching `Metrics` in `init`. |

## Objective

`LawTable` exists as a real `Hashable, Sendable` type carrying either a `Bitboard256` (stateless) or a `Bitboard65536` (contextual), built from E02's precomputed masks with word operations and never by walking the AST per glyph. `Law` exists as `node + resolved table + cached Metrics`, so `law.admitRate`, `law.marginalDeficit`, `law.leafCount`, `law.freeAttributeCount` and `law.scatteredSubsetCount` are O(1) behind a dot — which is what keeps E06's published `difficulty(of: Law) -> Double` signature literally true *and* fast.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.6 | The two representations and their costs (`Bitboard256`, 4 word-ops, ≈20 ns build / ≈5 ns compare; `Bitboard65536` indexed `prev*256 + cur`, ≈2 µs / ≈0.4 µs), "never walk the AST per glyph", and the tiling rule that materialises a contextual pair table from four row masks. |
| `GAME_DESIGN.md` | §3.6 | **"The extension is the canonical form. Syntax is never compared."** Everything in T05 rests on this type. |
| `GAME_DESIGN.md` | §5.1 | The five modifiers, and in particular `m2`'s definition of **marginal deficit** over the 16 `(attribute, value)` conditions φ, and `m5`'s "5 of the 14 subsets are scattered". |
| `GAME_DESIGN.md` | §5.2 | The eight exemplar laws with their `p` and `δ` — the oracle this task's metrics are checked against. |
| `GAME_DESIGN.md` | §5.5 | The band-5 worked round: `p = 0.188`, marginal deficit `0.464`, and the Assay note that the *slice* for a pinned `prev` lights 64 cells while `p × 256 = 48` is the unconditional projection. Both numbers are assertions here. |
| `GAME_DESIGN.md` | §4.3 | Why `LawTable.row(after:)` is core and the pin is not (`08 §2`). |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §3 | `LawTable.row(after:)` is core; `Law` is `node + resolved LawTable + cached Metrics`, never `Codable`. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W2, W20, W21, W28, W52, N47 | Struct over class; computed by default but stored when the value is the source of truth; `- Complexity:` documentation. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawsTests/LawTableTests.swift` and `HunchCore/Tests/LawsTests/LawMetricsTests.swift`.

```swift
// HunchCore/Tests/LawsTests/LawTableTests.swift
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Law tables", .tags(.unit, .presubmission))
struct LawTableTests {

    @Test("A stateless law resolves to a 256-bit table and a contextual law to a 65,536-bit one")
    func arity() {
        let stateless = LawTable(LawNode.atom(.init(attribute: .fill,
                                                    subset: Subset4(rawValue: 0b0100)!)))
        let contextual = LawTable(LawNode.contextual(.init(current: .pips,
                                                           comparator: .gt, previous: .pips)))
        #expect(stateless.arity == .stateless)
        #expect(contextual.arity == .contextual)
        #expect(stateless.universeSize == 256)
        #expect(contextual.universeSize == 65_536)
    }

    @Test("Admit rate of every §5.2 exemplar matches the band table",
          arguments: Corpora.bandExemplars)
    func exemplarAdmitRates(_ exemplar: Corpora.BandExemplar) {
        let table = LawTable(exemplar.node)
        expectApproximatelyEqual(table.admitRate, exemplar.admitRate, absoluteTolerance: 0.0005)
    }

    @Test("A stateless table lifts into pair space by tiling, and lifting is idempotent")
    func lifting() {
        let atom = LawTable(LawNode.atom(.init(attribute: .shape, subset: Subset4(rawValue: 0b0010)!)))
        let lifted = atom.lifted()
        #expect(lifted.arity == .contextual)
        expectApproximatelyEqual(lifted.admitRate, atom.admitRate, absoluteTolerance: 1e-12)
        #expect(lifted.lifted() == lifted)
    }

    @Test("`isSecretlyStateless` is exactly §3.6's `P == lift(P & FULL256)` — and G7's test")
    func secretlyStateless() {
        let genuinelyContextual = LawTable(LawNode.contextual(.init(current: .pips,
                                                                    comparator: .gt, previous: .pips)))
        let lifted = LawTable(LawNode.atom(.init(attribute: .hue,
                                                 subset: Subset4(rawValue: 0b0011)!))).lifted()
        #expect(genuinelyContextual.isSecretlyStateless == false)
        #expect(lifted.isSecretlyStateless == true)
    }

    @Test("The live Assay quotes the slice for a pinned prev, never the unconditional projection")
    func assaySliceIsNotTheProjection() throws {
        // GDD §5.5: hidden law `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}`,
        // pinned ghost = the seed glyph `hollow triangle, two pips, teal` = glyph 21.
        let law = try #require(Corpora.workedRoundBandFive.node)
        let table = LawTable(law)
        let slice = table.row(after: Deck.glyph(id: 21))
        #expect(slice.popCount == 64)                                   // §5.5, the finished draft
        #expect(Int((table.admitRate * 256).rounded()) == 48)           // §5.5, the Codex thumbnail
        #expect(slice.popCount != Int((table.admitRate * 256).rounded()))
    }

    @Test("Building a table never walks the AST per glyph")
    func maskDriven() {
        // A structural assertion, not a timing one: the resolver composes MaskTable entries with
        // word operations, so the number of per-glyph evaluations it performs is zero.
        #expect(LawTable.perGlyphEvaluationCount(for: Corpora.bandExemplars.map(\.node)) == 0)
    }

    @Test("Every exemplar table is satisfiable and falsifiable", arguments: Corpora.bandExemplars)
    func nonDegenerate(_ exemplar: Corpora.BandExemplar) {
        let table = LawTable(exemplar.node)
        #expect(table.isSatisfiable)                       // G1
        #expect(table.isFalsifiable)                       // G2
    }
}
```

```swift
// HunchCore/Tests/LawsTests/LawMetricsTests.swift
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Law metrics", .tags(.unit, .presubmission))
struct LawMetricsTests {

    @Test("Exactly 5 of the 14 subsets are scattered")
    func scatteredSubsetInventory() {
        // GDD §5.1, m5: "5 of the 14 subsets are not a contiguous run of ranks"
        #expect(Subset4.all.count(where: { !$0.isContiguousRun }) == 5)
    }

    @Test("The band-5 worked round's five metrics")
    func workedRoundBandFive() throws {
        // GDD §5.5: `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}`
        let law = Law(Corpora.workedRoundBandFive.node)
        expectApproximatelyEqual(law.admitRate, 0.1875, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(law.marginalDeficit, 0.4642857, absoluteTolerance: 5e-7)  // §5.5: 0.464
        #expect(law.leafCount == 2)
        #expect(law.freeAttributeCount == 2)               // fill and hue are named by no term
        #expect(law.scatteredSubsetCount == 1)             // {triangle, hexagon} = ranks 2 and 4
    }

    @Test("The band-8 COUNT law that proves flatness positions rather than gates")
    func bandEightCountLaw() throws {
        // GDD §5.2: `COUNT {fill,shape,pips} RANKIN {three,four} IN {2,3}`
        // p = 0.500, P(admit | fill ∈ {three,four}) = 0.750 against 0.250, deficit 0.286.
        let law = Law(Corpora.bandEightCount.node)
        expectApproximatelyEqual(law.admitRate, 0.5, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(law.marginalDeficit, 0.2857143, absoluteTolerance: 5e-7)
        #expect(law.leafCount == 3)                        // one leaf per counted attribute
        #expect(law.freeAttributeCount == 1)               // hue
        #expect(law.scatteredSubsetCount == 0)             // {three,four} is contiguous
    }

    @Test("A parity law and a relational law both have marginal deficit 1.0")
    func flatMarginals() {
        // GDD §5.1 m2: "an atom scores 0; a flat XOR, a relational law and a parity law all score 1"
        expectApproximatelyEqual(Law(Corpora.bandFourRelational.node).marginalDeficit,
                                 1.0, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(Law(Corpora.bandEightParity.node).marginalDeficit,
                                 1.0, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(Law(Corpora.bandThreeExclusive.node).marginalDeficit,
                                 1.0, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(Law(Corpora.bandOneLiteral.node).marginalDeficit,
                                 0.0, absoluteTolerance: 1e-12)
    }

    @Test("Free attribute count is 4 minus the named attributes", arguments: Corpora.bandExemplars)
    func freeAttributes(_ exemplar: Corpora.BandExemplar) {
        let law = Law(exemplar.node)
        #expect(law.freeAttributeCount == 4 - exemplar.node.namedAttributes.count)
        #expect((0...3).contains(law.freeAttributeCount))
    }

    @Test("Metrics are resolved once in init, so reading them touches no table")
    func metricsAreCached() {
        let law = Law(Corpora.workedRoundBandFive.node)
        let before = LawTable.buildCount
        _ = law.admitRate
        _ = law.marginalDeficit
        _ = law.scatteredSubsetCount
        #expect(LawTable.buildCount == before)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter LawTableTests` and `--filter LawMetricsTests`
Confirm the failures are *"cannot find `LawTable` in scope"* and, once the type exists, wrong numeric values — not malformed tests. The metric assertions above are the ones that matter: they were derived from §5.2's own δ column and they will catch a wrong `marginalDeficit` denominator or a wrong `freeAttributeCount` definition immediately.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/LawTable.swift` |
| create | `HunchCore/Sources/Laws/Law.swift` |
| create | `HunchCore/Tests/LawsTests/LawTableTests.swift` |
| create | `HunchCore/Tests/LawsTests/LawMetricsTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — add `BandExemplar` and the eight §5.2 exemplars plus §5.5's and §5.6's laws |
| modify | `SPEC.md` — the marginal-deficit condition set (16 `(attribute, value)` conditions on the **current** glyph) and the leaf-count table |
| modify | `tests.json` — "Extension tables + masks" |

## Implementation notes

### `LawTable`

```swift
/// A law's **extension** — the design's word (§2's terminology table); `extension` is a Swift
/// keyword, so the type is `LawTable` and the file is never `Extension.swift` (`01 P28`).
///
/// Stateless laws hold 4 × UInt64; contextual laws hold 1024 × UInt64 indexed `prev * 256 + cur`.
/// Comparison always happens at the larger of the two arities, by lifting (§3.6).
public struct LawTable: Hashable, Sendable {
    public enum Arity: Hashable, Sendable { case stateless, contextual }

    @usableFromInline enum Storage: Hashable, Sendable {
        case stateless(Bitboard256)
        case contextual(Bitboard65536)
    }
    @usableFromInline let storage: Storage
}
```

**Resolution is mask composition, not evaluation.** `init(_ node: LawNode)` recurses the AST *once* and, at each leaf, reads the precomputed mask E02's `MaskTable` already holds:

| Leaf | Mask source | Cost |
|---|---|---|
| `<atom>` | `MaskTable.atom(attribute, subset)` | one 4-word read |
| `<rel>` | `MaskTable.relational(a, cmp, b)` | one 4-word read |
| `<ctx>` | four `MaskTable.contextualRow(a, cmp, b, prevValue:)` masks tiled into 1024 words | ≈2 µs (§3.6) |
| `<guard>` | `(gate & then) \| (~gate & otherwise)` over three atom masks | three reads, four word-ops |
| `<aggregate>` | `MaskTable.aggregate(form)` — E02 T05 precomputes all 1,214 | one 4-word read |
| `<coupled>` | `and`/`or`/`xor` on the two operand tables, lifting the stateless one when the arities differ | 4 or 1024 word-ops |

The contextual leaf is the only one that scatters: a contextual row for a given `prev` depends only on `prev`'s value of the trailing attribute, so there are four distinct rows and the pair table is those four rows tiled 64 times each (§3.6). Do not build it glyph by glyph.

`perGlyphEvaluationCount(for:)` in the test is a debug counter incremented in the (nonexistent) per-glyph path — implement it as a `#if DEBUG` static that the resolver never touches, so the assertion is `0` by construction and becomes a real failure the moment somebody adds a fallback loop. Same for `buildCount`. Both are `#if DEBUG` and both are `static let`-adjacent counters guarded by an `Atomic` from `Synchronization`, **not** `static var` (`hunch-swift-code` "Never"); if that reads as over-engineering for a debug counter, drop both assertions and replace them with a code-review checklist item rather than shipping a data race.

**Members the rest of the epic needs:**

```swift
public var arity: Arity
public var universeSize: Int                     // 256 or 65_536
public var popCount: Int
public var admitRate: Double                     // popCount / universeSize
public var isSatisfiable: Bool                   // G1
public var isFalsifiable: Bool                   // G2
public var isConstant: Bool                      // !isSatisfiable || !isFalsifiable

/// This table tiled into pair space. `lift(T) = TILE * T` (§3.6). Idempotent on a contextual table.
public func lifted() -> LawTable

/// §3.6: `P == lift(P & FULL256)`. This is G7's test, negated.
public var isSecretlyStateless: Bool

/// The 256-bit slice for one pinned `prev` — what the live Assay draws (§4.3, §5.5).
/// A stateless table returns its own bits for every `prev`.
/// - Complexity: O(1).
public func row(after previous: Glyph) -> Bitboard256

/// The 16 (attribute, value) marginals, in canonical attribute order then rank order.
/// Conditions are on the **current** glyph; for a contextual table the probability is taken
/// over all 65,536 ordered pairs whose current glyph satisfies the condition (§5.1 m2).
/// - Complexity: O(universeSize / 64).
public var marginals: [Double]                   // exactly 16 entries
```

### `Law` — and why it is not `Codable`

```swift
/// A resolved law: the AST, its extension, and the metrics §5.1's modifiers read.
///
/// Deliberately **not** `Codable` (`08 §3`). Persist `node`; a contextual table costs ≈2 µs to
/// rebuild and 8 KiB to store, and storing a derived value invites the two to disagree.
public struct Law: Hashable, Sendable {
    public let node: LawNode
    public let table: LawTable
    public let metrics: Metrics

    /// - Precondition: `node.structuralFault == nil`.
    public init(_ node: LawNode) { … }
}
```

`Metrics` is a nested `public struct Metrics: Hashable, Sendable` with the five stored values, and `Law` forwards each one so the design's published spelling `law.marginalDeficit` reads exactly as §5.1 writes it. **Resolve everything in `init`.** As computed properties on the AST they would be O(universe) behind a dot and E06's `difficulty(of:)` is called inside a 200-attempt rejection loop, 10,000 laws × 8 bands per test run.

### The five metrics, exactly

These definitions were reconstructed from §5.1's formula and validated against **all eight** of §5.2's exemplar δ values. Reproduce that validation as a cross-check before you consider this task done; every one of the eight lands inside 1 × 10⁻³ of the published δ.

| Metric | Definition | Gotcha |
|---|---|---|
| `admitRate` | `table.popCount / table.universeSize` | For a contextual law this is over 65,536 pairs (§5.3), never over 256. |
| `marginalDeficit` | `1 − min(1, maxφ \|P(admit \| φ) − p\| / 0.35)` over the **16** `(attribute, value)` conditions | φ conditions on the **current** glyph only. This is the one place §5.1 is terse and getting it wrong is invisible: an atom must score 0, a relational law 1, a parity law 1, a size-2/size-2 XOR 1. |
| `leafCount` | `node.leafCount` from T01 | Atom / rel / ctx = 1, guard = 3, aggregate = `attributes.count`. |
| `freeAttributeCount` | `4 − node.namedAttributes.count`, so `0...3` | A `<rel>` names two attributes from one leaf. §5.1 divides by 3 because at least one attribute is always named. |
| `scatteredSubsetCount` | count of leaves whose subset is not a contiguous run of ranks | Only atoms, guard branches and an aggregate's `rankIn` carry a subset. A `CountSet` is **not** a rank subset and does not count. |

Reference decomposition, for the cross-check (`base` is E06's, listed only so you can see the modifiers add up):

| Band | Exemplar | `p` | deficit | leaves | free | scattered | δ published |
|---|---|---|---|---|---|---|---|
| 1 | `fill ∈ {striped}` | .250 | 0.000 | 1 | 3 | 0 | .023 |
| 2 | `shape ∈ {t,h} AND pips ∈ {3,4}` | .250 | 0.2857 | 2 | 2 | 1 | .160 |
| 3 | `shape ∈ {c,t} XOR fill ∈ {ho,do}` | .500 | 1.000 | 2 | 2 | 0 | .317 |
| 4 | `RANK shape == RANK pips` | .250 | 1.000 | 1 | 2 | 0 | .432 |
| 5 | `RANK pips(cur) > PREV RANK pips` | .375 | 0.000 | 1 | 3 | 0 | .525 |
| 6 | `IF hue IS amber THEN pips ∈ {3,4} ELSE pips ∈ {1}` | .3125 | 0.000 | 3 | 2 | 0 | .639 |
| 7 | `RANK hue(cur) == PREV RANK hue XOR RANK shape < RANK pips` | .4375 | 0.4643 | 2 | 1 | 0 | .785 |
| 8 | `PARITY {fill,shape,pips,hue} IS even` | .500 | 1.000 | 4 | 0 | 0 | .928 |

### `Corpora` additions

Add to `HunchCore/Sources/HunchTestSupport/Corpora.swift`:

```swift
extension Corpora {
    public struct BandExemplar: Codable, Sendable, CustomStringConvertible {
        public let bandNumber: Int          // Band does not exist until T06; keep this an Int
        public let node: LawNode
        public let admitRate: Double
        public let publishedDelta: Double   // §5.2's δ column, for E06's cross-check
        public var description: String { "band \(bandNumber)" }
    }

    /// GDD §5.2's eight exemplar laws, verbatim. Argument type is `Codable`, so a failing
    /// parameterised case re-runs alone (`06 T23`).
    public static let bandExemplars: [BandExemplar] = [ … ]

    public static let workedRoundBandFive: BandExemplar   // §5.5
    public static let workedRoundBandThree: BandExemplar  // §5.6
    public static let bandEightCount: BandExemplar        // §5.2's COUNT law, deficit 0.286

    /// Named accessors into `bandExemplars`, so a test reads the law it means rather than an
    /// index. One per band, spelled for the family: `bandOneLiteral`, `bandTwoPair`,
    /// `bandThreeExclusive`, `bandFourRelational`, `bandFiveContextual`, `bandSixGuarded`,
    /// `bandSevenComposite`, `bandEightParity`.
    public static let bandOneLiteral: BandExemplar
    // … the other seven, same shape

    /// Every exemplar whose table is stateless — bands 1, 2, 3, 4, 6, 8.
    public static let statelessExemplars: [BandExemplar]
}
```

`Corpora` is a `static let` of immutable `Sendable` values — never `static var` (`06 T10`).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'LawTableTests|LawMetricsTests'` is green.
- [ ] `LawTable` is `Hashable, Sendable` and there is no file named `Extension.swift` anywhere: `find HunchCore -name 'Extension*.swift'` returns nothing.
- [ ] `Law` has no `Codable` conformance: `grep -n 'Codable' HunchCore/Sources/Laws/Law.swift` returns nothing.
- [ ] Nothing in `HunchCore/Sources/Laws/` is a `class` or `actor`: `grep -rn -E '(final )?class |actor ' HunchCore/Sources/Laws/` returns nothing.
- [ ] All eight §5.2 exemplars pass the admit-rate assertion at tolerance 5 × 10⁻⁴.
- [ ] `Law(Corpora.workedRoundBandFive.node).marginalDeficit` is `0.464` to three decimals and `row(after: Deck.glyph(id: 21)).popCount == 64` while `admitRate * 256 == 48`.
- [ ] `Subset4.all.count(where: { !$0.isContiguousRun }) == 5`.
- [ ] `marginals` returns exactly 16 entries for both arities.
- [ ] Every non-O(1) member carries a `- Complexity:` line (`N47`).
- [ ] The δ cross-check for all eight exemplars is recorded — as a comment block in `Corpora.swift` or a `SPEC.md` row — and each lands within 1 × 10⁻³ of §5.2.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T02: LawTable, Law and the five cached metrics"`

## Out of scope

- **`difficulty(of:)` itself.** The formula, `base`, the five modifier weights and the Rasch coupling are E06 T01. This task ships the *inputs*; it does not sum them.
- **`Band` and `minLeaves`.** `m1` needs `family.minLeaves`, which arrives in T06 and is consumed in E06. `Law` carries no band.
- **The evaluator's public verb.** `Law.admits(_:after:)` and the §3.5 sequencing contract are T03.
- **Dead terms, liveness and the dedup key.** T05.
- **The Assay's pin and scrubber.** `row(after:)` is core; the pin, the ghost thumbnail and the band-4 evidence-overlay unlock are `AssayCanvas` in E09 T05 (`08 §2`).
- **`MaskTable` itself.** E02 T05 built the 54 KB resident precompute; this task consumes it and must not duplicate a single mask.
