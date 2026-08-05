# T05 — MaskTable, the 54 KB resident precompute

| | |
|---|---|
| **Epic** | E02 — Glyph vocabulary and the bitboard algebra |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T04, **T06** (every relational and contextual mask is keyed by a `Comparator`) |
| **Delivers** | §14.1 CORE SYSTEMS → **Extension tables + masks** (`…over ~54 KB of resident precomputed masks`) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task creates the **first file in the `Laws` target** and has to place it correctly (`Laws/MaskTable.swift`, per `08 §1`) without pre-empting the five files E05 adds beside it. The skill's boundary predicate is the check that this stays core, and its "never a `static var`" line is the difference between a 54 KB precompute and a data race. |
| `hunch-swift-concurrency` | `MaskTable.resident` is one of exactly **two** `static let`s of immutable `Sendable` values in `HunchCore` (`08 §4` names both), which is rung 1 of `05 R50`'s global-state ladder. The skill's state table is what says the answer here is *not* an actor, not a `Mutex`, not a lazily-filled cache — and tests run parallel in one process (`06 T10`), so getting this wrong is a race, not an ordering hazard. |
| `hunch-swift-testing` | 1,690 masks cannot be 1,690 parameterised cases. The skill owns the **T21 deviation** — parameterise over the outer dimension, loop inside, and pay it back with a reproducing identifier in the failure message and an `Attachment.record` of the offending form — which is exactly the shape this suite needs. It also owns the 10-second budget this suite must not eat. |

## Objective

`MaskTable.resident` exists: one immutable value holding all 1,690 precomputed `Bitboard256` masks — 56 atom, 36 relational, 96 × 4 contextual row, 1,204 `COUNT` and 10 `PARITY` — with a total, index-function-addressable layout measuring 54,080 bytes, and every entry verified against a brute-force evaluation over `Deck.all`. After this task no code in the project ever walks the AST per glyph: a law's extension is assembled from these masks in a handful of word operations, which is the whole reason §3.6's build budget is 20 ns.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.6 | *"**Never walk the AST per glyph.** Precompute once at launch and keep resident"* and the four-row table that fixes the counts and the sizes: atom masks 56 × 256 bit = 1.8 KB · relational 36 × 256 bit = 1.2 KB · contextual **row** masks — *"`ctx(a,b,cmp)` row for `prev` depends only on `prev`'s value of `b`, so store 4 rows per form"* — 96 × 4 × 256 bit = 12 KB · aggregate masks *"all 1,214 forms, not only the 337 in-window ones, because the player may build any of them on the Tally"* = 39 KB · **total resident ≈ 54 KB**. |
| `GAME_DESIGN.md` | §3.2 | The BNF each mask class transcribes: `<atom>`, `<rel>` (attrs **distinct**, canonical order), `<ctx>` (attrs **may be equal**), `<aggregate>` = `COUNT <attrSet> RANKIN <subset4> IN <countSet>` \| `PARITY <attrSet> IS <bit>`, and the four terminal productions `<subset4>` (bitmask 0001…1110, 14 values), `<attrSet>` (\|set\| ≥ 3, 5 values), `<countSet>` (non-empty proper subset of {0…\|attrSet\|}), `<bit>`. |
| `GAME_DESIGN.md` | §3.3 | The exhaustive predicate inventory and its counts — Atomic **56**, Relational **36**, Contextual **96**, Aggregate **1,214** — and the sentence that the *in-window* column counts distinct extensions, not forms. This table stores **forms**. |
| `GAME_DESIGN.md` | §5.7 | Locked: non-trivial subsets per attribute / total atoms = 14 / **56**; relational / contextual forms = 36 / 96; aggregate forms = **1,214**; resident precomputed masks ≈ **54 KB**. |
| `GAME_DESIGN.md` | §5.2 | The band-8 worked example `COUNT {fill,shape,pips} RANKIN {three,four} IN {2,3}` with `p = 0.500` — a usable end-to-end check on the `COUNT` builder. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §4 | `Laws/MaskTable.swift`; `MaskTable.resident` is a `static let` of immutable `Sendable` values and is explicitly *not* one of the singletons the brief bans. |
| `ios-swift-guide/05-CONCURRENCY.md` | R21, R50 | Explicit `: Sendable`; the global-state ladder, stopping at rung 1. |
| `ios-swift-guide/06-TESTING.md` | T10, T18a, T21, T30 | Parallel in one process; attach the artefact that explains the failure; a `for` loop in a test is a bug *except* where §5 of `08` rules otherwise; tag on both axes. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W16, W29, W39, W52 | Constants on the owning type; no `default:` over your own enum; `precondition` for the caller's contract; document cost. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawsTests/MaskTableTests.swift`:

```swift
import Foundation           // Attachment.record needs Foundation's Attachable conformance
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("MaskTable", .tags(.unit, .presubmission))
struct MaskTableTests {

    private let table = MaskTable.resident

    // MARK: - shape and size

    @Test("Every class holds exactly the number of forms §3.3 counts")
    func formCounts() {
        #expect(table.atomMasks.count == 56)          // 4 attributes × 14 subsets
        #expect(table.relationalMasks.count == 36)    // 6 distinct pairs × 6 comparators
        #expect(table.contextualRowMasks.count == 384) // 96 forms × 4 rows
        #expect(table.countMasks.count == 1_204)
        #expect(table.parityMasks.count == 10)        // 5 attribute sets × 2 bits
        #expect(table.countMasks.count + table.parityMasks.count == 1_214)
    }

    @Test("The resident precompute is §3.6's ≈54 KB")
    func residentSize() {
        let masks = 56 + 36 + 384 + 1_204 + 10
        #expect(masks == 1_690)
        #expect(MemoryLayout<Bitboard256>.stride == 32)
        #expect(table.byteCount == masks * 32)
        #expect(table.byteCount == 54_080)
        #expect((53_000...55_000).contains(table.byteCount))   // "≈ 54 KB", decimal, as §3.6 counts
    }

    @Test("resident is one value — reading it twice yields the same masks")
    func residentIsBuiltOnce() {
        #expect(MaskTable.resident.atomMasks == MaskTable.resident.atomMasks)
        #expect(MaskTable.resident.byteCount == MaskTable.resident.byteCount)
    }

    // MARK: - the index functions are bijections onto their ranges

    @Test("atomIndex is a bijection onto 0..<56")
    func atomIndexIsABijection() {
        let indices = Glyph.Attribute.allCases.flatMap { attribute in
            (UInt8(1)...14).map { MaskTable.atomIndex(attribute, subset: $0) }
        }
        #expect(Set(indices) == Set(0..<56))
    }

    @Test("relationalIndex is a bijection onto 0..<36 and accepts either attribute order")
    func relationalIndexIsABijection() {
        let indices = MaskTable.relationalPairs.flatMap { pair in
            Comparator.allCases.map { MaskTable.relationalIndex(pair.0, $0, pair.1) }
        }
        #expect(Set(indices) == Set(0..<36))
        // Reversing the operands and flipping the comparator names the same form (§3.4 step 3).
        #expect(MaskTable.relationalIndex(.pips, .lt, .shape)
             == MaskTable.relationalIndex(.shape, .gt, .pips))
    }

    @Test("contextualRowIndex is a bijection onto 0..<384")
    func contextualRowIndexIsABijection() {
        var indices: Set<Int> = []
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases {
                for comparator in Comparator.allCases {
                    for previousOrdinal in 0..<4 {
                        indices.insert(MaskTable.contextualRowIndex(
                            a, comparator, previous: b, previousOrdinal: previousOrdinal))
                    }
                }
            }
        }
        #expect(indices == Set(0..<384))
    }

    @Test("countIndex is a bijection onto 0..<1204 and parityIndex onto 0..<10")
    func aggregateIndicesAreBijections() {
        var countIndices: Set<Int> = []
        var parityIndices: Set<Int> = []
        for attributes in MaskTable.aggregateAttributeSets {
            let arity = attributes.nonzeroBitCount
            let countSets = UInt8(1)...UInt8((1 << (arity + 1)) - 2)
            for subset in UInt8(1)...14 {
                for countSet in countSets {
                    countIndices.insert(
                        MaskTable.countIndex(attributes: attributes, subset: subset, countSet: countSet))
                }
            }
            parityIndices.insert(MaskTable.parityIndex(attributes: attributes, bit: 0))
            parityIndices.insert(MaskTable.parityIndex(attributes: attributes, bit: 1))
        }
        #expect(countIndices == Set(0..<1_204))
        #expect(parityIndices == Set(0..<10))
    }

    // MARK: - every mask against a brute-force walk of the deck
    // 08 §7.4's T21 deviation: parameterise the outer dimension, loop inside, and name the
    // exact failing form in the message with an Attachment of it (06 T18a).

    @Test("Atom masks match a brute-force walk", arguments: Glyph.Attribute.allCases)
    func atomMasksAreCorrect(_ attribute: Glyph.Attribute) {
        for subset in UInt8(1)...14 {
            let expected = Bitboard256(ids: Deck.all.lazy
                .filter { subset & (1 << $0.ordinal(of: attribute)) != 0 }
                .map(\.id))
            guard table.atom(attribute, subset: subset) != expected else { continue }
            Attachment.record("attr=\(attribute) subset=\(String(subset, radix: 2))",
                              named: "atom-mismatch.txt")
            Issue.record("atom mask wrong for \(attribute) IN 0b\(String(subset, radix: 2))")
            return
        }
    }

    @Test("Relational masks match a brute-force walk", arguments: Comparator.allCases)
    func relationalMasksAreCorrect(_ comparator: Comparator) {
        for pair in MaskTable.relationalPairs {
            let (a, b) = pair
            let expected = Bitboard256(ids: Deck.all.lazy
                .filter { comparator.matches($0.ordinal(of: a) + 1, $0.ordinal(of: b) + 1) }
                .map(\.id))
            guard table.relational(a, comparator, b) != expected else { continue }
            Issue.record("relational mask wrong for RANK \(a) \(comparator) RANK \(b)")
            return
        }
    }

    @Test("Contextual row masks match a brute-force walk", arguments: Comparator.allCases)
    func contextualRowMasksAreCorrect(_ comparator: Comparator) {
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases {
                for previousOrdinal in 0..<4 {
                    let expected = Bitboard256(ids: Deck.all.lazy
                        .filter { comparator.matches($0.ordinal(of: a) + 1, previousOrdinal + 1) }
                        .map(\.id))
                    let actual = table.contextualRow(a, comparator, previous: b,
                                                     previousOrdinal: previousOrdinal)
                    guard actual != expected else { continue }
                    Issue.record("""
                        contextual row wrong for RANK \(a) \(comparator) PREV RANK \(b), \
                        prev ordinal \(previousOrdinal)
                        """)
                    return
                }
            }
        }
    }

    @Test("A contextual row's contents depend only on (a, comparator, prev ordinal) — b selects "
        + "the row, never its contents", arguments: Comparator.allCases)
    func contextualRowsAreIndependentOfTheSecondAttribute(_ comparator: Comparator) {
        for a in Glyph.Attribute.allCases {
            for previousOrdinal in 0..<4 {
                let rows = Glyph.Attribute.allCases.map {
                    table.contextualRow(a, comparator, previous: $0, previousOrdinal: previousOrdinal)
                }
                guard Set(rows).count > 1 else { continue }
                Issue.record("rows differ across b for RANK \(a) \(comparator) …, prev \(previousOrdinal)")
                return
            }
        }
    }

    @Test("COUNT masks match a brute-force walk", arguments: MaskTable.aggregateAttributeSets)
    func countMasksAreCorrect(_ attributes: UInt8) {
        let arity = attributes.nonzeroBitCount
        for subset in UInt8(1)...14 {
            for countSet in UInt8(1)...UInt8((1 << (arity + 1)) - 2) {
                let expected = Bitboard256(ids: Deck.all.lazy.filter { glyph in
                    let hits = Glyph.Attribute.allCases.count { attribute in
                        attributes & (1 << attribute.rawValue) != 0
                            && subset & (1 << glyph.ordinal(of: attribute)) != 0
                    }
                    return countSet & (1 << hits) != 0
                }.map(\.id))
                let actual = table.count(attributes: attributes, subset: subset, countSet: countSet)
                guard actual != expected else { continue }
                Attachment.record("attrs=\(attributes) subset=\(subset) countSet=\(countSet)",
                                  named: "count-mismatch.txt")
                Issue.record("COUNT mask wrong for attrs=0b\(String(attributes, radix: 2)) "
                           + "subset=0b\(String(subset, radix: 2)) countSet=0b\(String(countSet, radix: 2))")
                return
            }
        }
    }

    @Test("PARITY masks match a brute-force walk over ranks",
          arguments: MaskTable.aggregateAttributeSets)
    func parityMasksAreCorrect(_ attributes: UInt8) {
        for bit in 0...1 {
            let expected = Bitboard256(ids: Deck.all.lazy.filter { glyph in
                let sum = Glyph.Attribute.allCases.reduce(0) { total, attribute in
                    attributes & (1 << attribute.rawValue) != 0
                        ? total + glyph.ordinal(of: attribute) + 1
                        : total
                }
                return sum % 2 == bit
            }.map(\.id))
            guard table.parity(attributes: attributes, bit: bit) != expected else { continue }
            Issue.record("PARITY mask wrong for attrs=0b\(String(attributes, radix: 2)) bit=\(bit)")
            return
        }
    }

    // MARK: - the properties §3 and §5 claim of these masks

    @Test("Complement closure: a subset's mask is the complement of its complement's mask")
    func atomComplementClosure() {
        // §3.1: `¬(a ∈ S) = a ∈ S̄`, and the 14 subsets are closed under complement.
        #expect(Glyph.Attribute.allCases.allSatisfy { attribute in
            (UInt8(1)...14).allSatisfy { subset in
                table.atom(attribute, subset: subset) == ~table.atom(attribute, subset: 15 - subset)
            }
        })
    }

    @Test("Complement closure for comparators: ¬(RANK a ⋈ RANK b) = RANK a ⋈̄ RANK b")
    func relationalComplementClosure() {
        #expect(MaskTable.relationalPairs.allSatisfy { pair in
            Comparator.allCases.allSatisfy { comparator in
                table.relational(pair.0, comparator, pair.1)
                    == ~table.relational(pair.0, comparator.complemented, pair.1)
            }
        })
    }

    @Test("¬PARITY(A, b) = PARITY(A, 1 − b) — §3.1's aggregate case")
    func parityComplementClosure() {
        #expect(MaskTable.aggregateAttributeSets.allSatisfy { attributes in
            table.parity(attributes: attributes, bit: 0)
                == ~table.parity(attributes: attributes, bit: 1)
        })
    }

    @Test("¬COUNT(A, S, C) = COUNT(A, S, C̄) — §3.1's other aggregate case")
    func countComplementClosure() {
        let attributes = MaskTable.aggregateAttributeSets[0]     // a 3-attribute set: counts 0…3
        let universe = UInt8((1 << 4) - 1)                        // all four counts
        #expect((UInt8(1)...14).allSatisfy { subset in
            (UInt8(1)...UInt8(14)).allSatisfy { countSet in
                table.count(attributes: attributes, subset: subset, countSet: countSet)
                    == ~table.count(attributes: attributes, subset: subset, countSet: universe - countSet)
            }
        })
    }

    @Test("§5.2's worked band-8 COUNT law admits exactly half the deck")
    func workedBandEightExample() {
        // COUNT {fill, shape, pips} RANKIN {three, four} IN {2, 3} — §5.2 gives p = 0.500.
        let attributes: UInt8 = 0b0111                            // fill, shape, pips
        let subset: UInt8 = 0b1100                                // ranks 3 and 4
        let countSet: UInt8 = 0b1100                              // counts 2 and 3
        let mask = table.count(attributes: attributes, subset: subset, countSet: countSet)
        #expect(mask.count == 128)
    }

    @Test("An atom's admit rate is the subset's size over four")
    func atomAdmitRates() {
        #expect(Glyph.Attribute.allCases.allSatisfy { attribute in
            (UInt8(1)...14).allSatisfy { subset in
                table.atom(attribute, subset: subset).count == Int(subset.nonzeroBitCount) * 64
            }
        })
    }
}
```

Create `HunchCore/Tests/LawsTests/MaskTableBuildBudgetTests.swift`:

```swift
import Foundation
import Testing
import Laws
import HunchTestSupport

/// §3.6 says the precompute is built "once at launch". Nightly, so the presubmission suite
/// never pays for it twice (`06 T30`, `T58`).
@Suite("MaskTable build budget", .tags(.performance, .nightly))
struct MaskTableBuildBudgetTests {

    @Test("Building the whole precompute is a launch-time cost, not a launch-time stall")
    func buildCost() {
        let elapsed = ContinuousClock().measure { _ = MaskTable() }   // `package init`
        let milliseconds = Double(elapsed.components.seconds) * 1e3
            + Double(elapsed.components.attoseconds) / 1e15
        Attachment.record("\(milliseconds) ms", named: "masktable-build.txt")
        #expect(milliseconds < 500)
    }

    @Test("A freshly built table is identical to the resident one")
    func freshBuildEqualsResident() {
        let fresh = MaskTable()
        #expect(fresh.atomMasks == MaskTable.resident.atomMasks)
        #expect(fresh.relationalMasks == MaskTable.resident.relationalMasks)
        #expect(fresh.contextualRowMasks == MaskTable.resident.contextualRowMasks)
        #expect(fresh.countMasks == MaskTable.resident.countMasks)
        #expect(fresh.parityMasks == MaskTable.resident.parityMasks)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter MaskTableTests`
It must fail with `no such module 'Laws'` or `cannot find 'MaskTable' in scope`. If it fails with `no such module 'Laws'`, check `HunchCore/Package.swift`: E01·T03 declares the `Laws` target and a `LawsTests` test target depending on `Laws`, `Glyphs` and `HunchTestSupport`. Add only what is missing, in its own commit, and do not add a ninth target.

**Step 3 — implement.** **Step 4 — green, then refactor, then measure the build.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/MaskTable.swift` |
| create | `HunchCore/Tests/LawsTests/MaskTableTests.swift` |
| create | `HunchCore/Tests/LawsTests/MaskTableBuildBudgetTests.swift` |
| modify | `tests.json` — the mask-vs-brute-force and 54 KB invariants |
| modify | `DECISIONS.md` — the PARITY rank convention and the measured build cost |

## Implementation notes

### The type

```swift
/// Every predicate the grammar can name, precomputed as a mask over the deck.
///
/// §3.6: *never walk the AST per glyph.* A law's extension is assembled from these in a
/// handful of word operations, which is what makes the build budget 20 ns rather than 256
/// evaluations. Forms, not distinct extensions — all 1,214 aggregates are here, not only the
/// 337 in the admit window, because the player may build any of them on the Tally.
public struct MaskTable: Sendable {

    /// The one resident copy. `static let` of an immutable `Sendable` value — rung 1 of
    /// `05 R50`, named in `08 §4` beside `Deck.all`, and not a singleton in the sense the
    /// brief bans: there is no mutable state and nothing to substitute.
    public static let resident = MaskTable()

    public let atomMasks: [Bitboard256]            // 56  = 4 attributes × 14 subsets
    public let relationalMasks: [Bitboard256]      // 36  = 6 pairs × 6 comparators
    public let contextualRowMasks: [Bitboard256]   // 384 = 96 forms × 4 rows
    public let countMasks: [Bitboard256]           // 1,204
    public let parityMasks: [Bitboard256]          // 10  = 5 attribute sets × 2 bits

    /// The mask payload in bytes — §3.6's ≈54 KB. Excludes the five array headers, which is
    /// what the design's table counts.
    public var byteCount: Int { … }

    /// Builds the whole precompute. `package` rather than `public`: production code reads
    /// `resident`, and the accessible initialiser exists so a test can measure a build and
    /// compare a fresh table against the resident one.
    package init() { … }
}
```

### The five index layouts, and why each one is what it is

Every layout is chosen so the index is arithmetic rather than a search, and so that the *ordering* is the canonical one already fixed elsewhere. Write each derivation into the source as a comment; the test asserts each is a bijection, but only the comment explains it.

**Atoms — 56.** Attribute-major, subset ascending. `<subset4>` is a bitmask `0001…1110` where bit *v* means the value with ordinal *v*; `0000` and `1111` are forbidden by the BNF, so the 14 legal values are `1...14` and the index is dense:

```swift
public static func atomIndex(_ attribute: Glyph.Attribute, subset: UInt8) -> Int {
    precondition((1...14).contains(subset), "subset 0b\(String(subset, radix: 2)) is ∅ or full — §3.2 forbids both")
    return Int(attribute.rawValue) * 14 + Int(subset) - 1
}
```

**Relational — 36.** `<rel>` requires **distinct** attributes in canonical order (`RANK a ⋈ RANK a` is constant), so the six unordered pairs are enumerated `(fill,shape) (fill,pips) (fill,hue) (shape,pips) (shape,hue) (pips,hue)` and the pair ordinal is the standard strictly-upper-triangular index for n = 4:

```
pairOrdinal(a, b) = a * (2*4 - a - 1) / 2 + (b - a - 1)      for a < b
```

`relationalIndex(_:_:_:)` accepts either operand order and normalises with `Comparator.flipped` (T06), which is §3.4 step 3's rule made total: `relational(.pips, .lt, .shape)` and `relational(.shape, .gt, .pips)` are one form and must be one index.

**Contextual rows — 96 × 4.** The form ordinal is `(a * 4 + b) * 6 + cmp` — note `a` and `b` **may be equal** here (`RANK pips(cur) > PREV RANK pips` is §5.2's entry-level contextual law and must exist), which is why this is 4 × 4 and not the 6 pairs above. Each form stores four rows indexed by the *previous* glyph's ordinal of `b`:

```swift
public static func contextualRowIndex(_ a: Glyph.Attribute, _ comparator: Comparator,
                                      previous b: Glyph.Attribute, previousOrdinal: Int) -> Int {
    precondition((0..<4).contains(previousOrdinal))
    let form = (Int(a.rawValue) * 4 + Int(b.rawValue)) * 6 + Int(comparator.rawValue)
    return form * 4 + previousOrdinal
}
```

> **The 4× redundancy is deliberate — do not dedup it.** A row's *contents* are `{ cur : RANK a(cur) ⋈ r+1 }`, which does not mention `b` at all: `b` chooses *which* row is used at evaluation time, not what is in it. So of the 384 stored rows only 96 are distinct, and collapsing them would save 9 KB. Keep all 384: it keeps evaluation a branch-free `contextualRowMasks[form * 4 + previousOrdinal]` with no second lookup table, and it is the layout §3.6's 12 KB line budgets for. `contextualRowsAreIndependentOfTheSecondAttribute` turns the redundancy into a *checked invariant* rather than a latent inconsistency — if the builder ever makes two of the four differ, that test fails.

**COUNT — 1,204.** `<attrSet>` is a subset of the four attributes with |set| ≥ 3, so the five legal masks in ascending bitmask order are `0b0111, 0b1011, 0b1101, 0b1110, 0b1111`. `<countSet>` is a non-empty **proper** subset of `{0…k}` where `k = |attrSet|`, so there are `2^(k+1) − 2` of them: 14 for a 3-attribute set, 30 for the 4-attribute set. The arithmetic that has to come out right:

```
4 sets of size 3 × 14 subsets × 14 countSets = 784
1 set  of size 4 × 14 subsets × 30 countSets = 420
                                        total 1,204        ✓ §3.3's 1,204
```

Layout is attribute-set-major with the offsets `[0, 196, 392, 588, 784]`, then subset ascending, then countSet ascending:

```swift
public static func countIndex(attributes: UInt8, subset: UInt8, countSet: UInt8) -> Int {
    let setOrdinal = aggregateAttributeSets.firstIndex(of: attributes)!   // 0…4, five entries
    let arity = attributes.nonzeroBitCount
    let countSetCount = (1 << (arity + 1)) - 2
    precondition((1...UInt8(countSetCount)).contains(countSet))
    return countOffsets[setOrdinal] + (Int(subset) - 1) * countSetCount + Int(countSet) - 1
}
```

Use `precondition` rather than `!` on the `firstIndex` in shipped code — `W37`/`W39`: an invalid attribute set is a caller-contract violation and must say so.

**PARITY — 10.** `setOrdinal * 2 + bit`, and `bit` is `0` for **even** (§5.2's example reads *"PARITY {fill,shape,pips,hue} IS even"*).

### The one semantic decision the spec leaves open — and it is load-bearing

`<aggregate> ::= "PARITY" <attrSet> "IS" <bit>` does not say parity *of what*. The only sensible reading is the sum of the named attributes' values, and the design's numbering for a value is its **rank, 1…4** (§2's table is stated in ranks, and every other production says `RANK`). **Ship parity over ranks.**

This matters more than it looks: `rank = ordinal + 1`, so for an attribute set of **odd** size the two conventions disagree — `parityOrdinals(g) = parityRanks(g) XOR (|A| mod 2)`. What survives either choice is the *set* of ten masks (the two bits simply swap labels for the four 3-attribute sets); what does **not** survive is the labelling, and the labelling is exactly what E09's Tally parity comb renders and what E06·T04's G10 round-trip compares node-for-node. Lock it here, **record it in `DECISIONS.md`**, and let `parityMasksAreCorrect` freeze it.

### Building it: value planes first

Sixteen `Bitboard256`s — one per (attribute, ordinal) — make every other class a few unions:

```swift
// planes[attribute][ordinal] = the 64 glyphs with that value.
var planes = [[Bitboard256]](repeating: [Bitboard256](repeating: .empty, count: 4), count: 4)
for glyph in Deck.all {
    for attribute in Glyph.Attribute.allCases {
        planes[Int(attribute.rawValue)][glyph.ordinal(of: attribute)].insert(glyph.id)
    }
}
```

- **atom** `(a, S)` = `⋃ { planes[a][v] : bit v of S }` — four unions at worst.
- **relational** `(a, ⋈, b)` = `⋃ { planes[a][va] & planes[b][vb] : ⋈ holds on the ranks }` — 16 pairs.
- **contextual row** `(a, ⋈, r)` = `⋃ { planes[a][va] : ⋈ holds between va+1 and r+1 }` — four unions.
- **COUNT** — no plane shortcut worth having; walk `Deck.all` and count hits per glyph. 1,204 × 256 × 4 ≈ 1.2 M operations, which is milliseconds.
- **PARITY** — same walk, summing ranks.

The builders and the test's brute force are deliberately *different code*: the builders compose planes, the test transcribes §3.2 literally, glyph by glyph. For the atoms the two nearly coincide and the test's real target there is the **index mapping** — which is the failure that would otherwise ship silently, because a mask that is correct but filed under the wrong index produces a law whose extension is plausible and wrong.

### Cost and the accessor surface

`resident` is lazily initialised by `swift_once` on first touch, so the cost lands on whichever caller gets there first — in the app that is law generation on the launch path, and it is milliseconds. Measure it (the nightly suite does) and record the number; if it ever approaches a frame, the fix named by §3.6 is that the aggregates are the only expensive class and they can be built from the atom masks, not that the table becomes mutable or lazy per class.

Ship the five instance accessors (`atom`, `relational`, `contextualRow`, `count`, `parity`) as the call-site API and keep the `static` index functions public beside them: E05 needs the raw index to write RNF's sort key and to build the lower-band index, and the tests need it to prove the bijections. Every accessor is a subscript into a `let` array behind a `precondition`ed index — document `- Complexity: O(1)` on each (`N47`).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter MaskTableTests` is green — all form-count, size, bijection, brute-force, complement-closure and worked-example tests.
- [ ] `table.byteCount == 54_080` and the five per-class counts assert individually (56 / 36 / 384 / 1,204 / 10 = 1,690).
- [ ] The `§5.2` worked band-8 `COUNT` example admits exactly 128 of 256 (`p = 0.500`).
- [ ] `contextualRowsAreIndependentOfTheSecondAttribute` passes for all six comparators — the 4× redundancy is an invariant, not an accident.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s with this suite in it (`START=$SECONDS; …`).
- [ ] `swift test --package-path HunchCore -c release --filter MaskTableBuildBudgetTests` is green and the measured build cost is recorded in `DECISIONS.md`.
- [ ] `grep -rn "static var\|class \|actor \|@unchecked" HunchCore/Sources/Laws/MaskTable.swift` returns nothing.
- [ ] `DECISIONS.md` records the PARITY-over-ranks convention with its consequence for G10.
- [ ] `tests.json` has entries for "every mask matches brute force" and "resident ≈ 54 KB", both `pass`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s. If this suite alone costs more than ~1 s, move the four brute-force tests' inner loops to `.nightly` **and say so in `tests.json`** — never by deleting an assertion (`06 T58`).
2. **Run `/simplify`** — then re-run the tests. Two suggestions are pre-declined and the reasons belong in the commit body: deduplicating the 384 contextual rows to 96, and merging `countMasks` + `parityMasks` into one `aggregateMasks` array (the two have different index arithmetic and a single array reintroduces a branch on every lookup).
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E02/T05: MaskTable.resident — 1,690 masks in 54 KB, each verified against brute force"`

## Out of scope

- **Guard masks.** §3.3 counts 8,736 guard forms and §3.6's resident table deliberately does **not** hold them: a guard is `IF a IS v THEN b IN S₁ ELSE b IN S₂`, which is built from three atom masks in two word operations at evaluation time. Do not precompute them; 8,736 × 32 B is 280 KB and the design budgets 54.
- Assembling a **law's** table from these masks, and `LawTable` itself — **E05·T02**.
- `Law.admits(_:after:)`, which is where the contextual rows are actually tiled — **E05·T03**.
- The 337 in-window distinct aggregate extensions, the per-band `|H|` counts and the lower-band index — **E05·T07/T08**. This table stores forms and counts nothing.
- Any guardrail that reads a mask (G1–G10) — **E06·T05**.
- The Tally rule-tile that lets a player *build* an aggregate — **E09·T02**.
