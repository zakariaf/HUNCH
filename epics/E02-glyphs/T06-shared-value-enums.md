# T06 — Shared value enums

| | |
|---|---|
| **Epic** | E02 — Glyph vocabulary and the bitboard algebra |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | §14.1 CORE SYSTEMS → **Glyph model** (§2's remaining locked enums) and **Rule AST + BNF** (the `<coupler>` and `<cmp>` productions as types) |
| **Status** | not started |

> **Execution order.** This task runs **before T05** even though its number is higher: `MaskTable` builds 36 relational and 96 × 4 contextual masks and every one of them is keyed by a `Comparator`. The plan's dependency edge `T05 → T04` is real but incomplete; `T05 → T06` is the other half.

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Three of the four types here are named in `08 §3`'s naming pass with an explicit ruling attached — `Verdict`'s cases are imperative verbs that `N29` would normally reject and `N36` admits; `Mode` must be `UInt8`-raw *and* rendered `Text(verbatim:)`, and the skill's gotcha list explains why the `String` and the literal spellings are each wrong in a different direction. It also owns the placement question this task has to answer: why four game-wide enums live in a target called `Glyphs`. |

## Objective

`Verdict`, `Mode`, `Coupler` and `Comparator` exist as `UInt8`-backed `Sendable` value enums with the case lists §2 locks, plus the three pieces of comparator algebra (`matches`, `flipped`, `complemented`) that §3.1's complement-closure proof and §3.4's RNF both depend on, and the frozen `Mode.salt` the generator mixes into every seed. After this task nothing later in the project has to invent a spelling for a verdict, a mode, a coupler or a comparator, and the four ordinals that end up in on-disk bytes are pinned by tests.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 *Locked terminology* | The four modes are **PROBE, DRIFT, ECHO, SIEVE**, *uppercase in copy* · the two verdicts are **admit / reject**, *never "pass/fail", "yes/no"* · the **coupler** is the AND/OR/XOR node between two tiles · the enum block at the end of §2 is the case list, verbatim, for `Verdict`, `Coupler` and `Comparator`. |
| `GAME_DESIGN.md` | §3.1 | The complement-closure proof, production by production: *"the six comparators are closed under complement"* — this is what `complemented` implements and what its test asserts exhaustively. |
| `GAME_DESIGN.md` | §3.4 | RNF step 2 sorts commutative operands by `(kindOrdinal, attrOrdinal, cmpOrdinal, subsetBitmask)` — so `Comparator`'s raw values are a *stored sort key* — and step 3 renders contextual `cur`-leading *"with the comparator flipped to compensate"*, which is `flipped`. |
| `GAME_DESIGN.md` | §3.2 | `<cmp> ::= "==" \| "!=" \| "<" \| "<=" \| ">" \| ">="` and `<coupler> ::= "AND" \| "OR" \| "XOR"`. |
| `GAME_DESIGN.md` | §5.3 | Step 1 of the generator: `rng = SplitMix64(seed ^ (UInt64(band) << 32) ^ mode.salt)`. The salt's *value* is fixed nowhere in the design — this task fixes it. |
| `GAME_DESIGN.md` | §6.10, §11.13 | `round-{mode}.json`: four slots, one per mode, so the mode is a persisted key. |
| `GAME_DESIGN.md` | §12.9 | The mode names ship as **untranslated wordmarks** and must not enter the String Catalog. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 rows *admit / reject*, *the four modes*, *the Bench…* | `enum Verdict: Sendable { case admit, reject }` with `N36`'s ruling; `enum Mode: UInt8, Codable, Sendable`, rendered `Text(verbatim: mode.wordmark)`; `enum Coupler: UInt8 { case and, or, xor }`. |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N9, N29, N33, N36 | Third-person verb booleans (`matches`); stutter-free lowerCamelCase cases; no `SCREAMING_SNAKE`; precedent beats purity. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W16, W19, W29, W51 | Constants on the type they belong to; `switch` expressions; **no `default:` over your own enum**; `///` doc comments. |

## TDD — the test comes first

**Step 1 — write the failing tests.** One file per type (`06 T5b`).

Create `HunchCore/Tests/GlyphsTests/ComparatorTests.swift`:

```swift
import Testing
import Glyphs
import HunchTestSupport

@Suite("Comparator", .tags(.unit, .presubmission))
struct ComparatorTests {

    /// Every ordered pair of ranks a comparator will ever see. Ranks are 1…4 (§2).
    private static let rankPairs: [(Int, Int)] =
        (1...4).flatMap { lhs in (1...4).map { (lhs, $0) } }

    @Test("The six comparators are §2's list, and their raw values are RNF's cmpOrdinal")
    func caseOrderIsTheSortKey() {
        #expect(Comparator.allCases == [.eq, .neq, .lt, .lte, .gt, .gte])
        #expect(Comparator.allCases.map(\.rawValue) == [0, 1, 2, 3, 4, 5])
    }

    @Test("matches(_:_:) is the comparison its name says", arguments: Comparator.allCases)
    func matchesIsTheComparison(_ comparator: Comparator) {
        let expected: (Int, Int) -> Bool = switch comparator {
        case .eq: { $0 == $1 }
        case .neq: { $0 != $1 }
        case .lt: { $0 < $1 }
        case .lte: { $0 <= $1 }
        case .gt: { $0 > $1 }
        case .gte: { $0 >= $1 }
        }
        #expect(Self.rankPairs.allSatisfy { comparator.matches($0.0, $0.1) == expected($0.0, $0.1) })
    }

    @Test("flipped is the operand swap — §3.4's contextual cur-leading rule",
          arguments: Comparator.allCases)
    func flippedIsTheOperandSwap(_ comparator: Comparator) {
        #expect(Self.rankPairs.allSatisfy {
            comparator.flipped.matches($0.1, $0.0) == comparator.matches($0.0, $0.1)
        })
        #expect(comparator.flipped.flipped == comparator)
    }

    @Test("complemented is negation — §3.1's closure proof, exhaustively",
          arguments: Comparator.allCases)
    func complementedIsNegation(_ comparator: Comparator) {
        #expect(Self.rankPairs.allSatisfy {
            comparator.complemented.matches($0.0, $0.1) == !comparator.matches($0.0, $0.1)
        })
        #expect(comparator.complemented.complemented == comparator)
        #expect(comparator.complemented != comparator)
    }

    @Test("The two algebras commute, so RNF may apply them in either order")
    func flipAndComplementCommute() {
        #expect(Comparator.allCases.allSatisfy { $0.flipped.complemented == $0.complemented.flipped })
    }

    @Test("A comparator survives a UInt8 round trip", arguments: Comparator.allCases)
    func rawValueRoundTrips(_ comparator: Comparator) {
        #expect(Comparator(rawValue: comparator.rawValue) == comparator)
    }
}
```

Create `HunchCore/Tests/GlyphsTests/ModeTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import HunchTestSupport

@Suite("Mode", .tags(.unit, .presubmission))
struct ModeTests {

    @Test("The four modes are §2's, in §2's order, with stable raw values")
    func caseOrder() {
        #expect(Mode.allCases == [.probe, .drift, .echo, .sieve])
        #expect(Mode.allCases.map(\.rawValue) == [0, 1, 2, 3])
    }

    @Test("Wordmarks are the uppercase mode names")
    func wordmarks() {
        #expect(Mode.allCases.map(\.wordmark) == ["PROBE", "DRIFT", "ECHO", "SIEVE"])
    }

    @Test("Every salt is the big-endian ASCII packing of its own wordmark", arguments: Mode.allCases)
    func saltIsTheWordmarkPacked(_ mode: Mode) {
        let packed = mode.wordmark.utf8.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        #expect(mode.salt == packed)
        #expect(mode.salt != 0)
    }

    @Test("Salts are pairwise distinct, or two modes would generate the same law from one seed")
    func saltsAreDistinct() {
        #expect(Set(Mode.allCases.map(\.salt)).count == Mode.allCases.count)
    }

    @Test("Mixing a seed with the salt separates the modes")
    func saltSeparatesModes() {
        let seed: UInt64 = 0x0000_0000_DEAD_BEEF
        let mixed = Mode.allCases.map { seed ^ $0.salt }
        #expect(Set(mixed).count == Mode.allCases.count)
    }

    @Test("A mode survives a JSON round trip as its raw value")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(Mode.allCases)
        let decoded = try JSONDecoder().decode([Mode].self, from: data)
        #expect(decoded == Mode.allCases)
    }
}
```

Create `HunchCore/Tests/GlyphsTests/VerdictTests.swift` and `HunchCore/Tests/GlyphsTests/CouplerTests.swift`:

```swift
import Testing
import Glyphs
import HunchTestSupport

@Suite("Verdict", .tags(.unit, .presubmission))
struct VerdictTests {

    @Test("The two verdicts are §2's, with stable raw values for the ribbon on disk")
    func caseOrder() {
        #expect(Verdict.allCases == [.admit, .reject])
        #expect(Verdict.allCases.map(\.rawValue) == [0, 1])
    }

    @Test("A Bool converts to the verdict it means")
    func initFromBool() {
        #expect(Verdict(admits: true) == .admit)
        #expect(Verdict(admits: false) == .reject)
    }

    @Test("A verdict survives a UInt8 round trip", arguments: Verdict.allCases)
    func rawValueRoundTrips(_ verdict: Verdict) {
        #expect(Verdict(rawValue: verdict.rawValue) == verdict)
    }
}

@Suite("Coupler", .tags(.unit, .presubmission))
struct CouplerTests {

    @Test("The three couplers are §3.2's, with stable raw values for the Bench draft on disk")
    func caseOrder() {
        #expect(Coupler.allCases == [.and, .or, .xor])
        #expect(Coupler.allCases.map(\.rawValue) == [0, 1, 2])
    }

    @Test("A coupler survives a UInt8 round trip", arguments: Coupler.allCases)
    func rawValueRoundTrips(_ coupler: Coupler) {
        #expect(Coupler(rawValue: coupler.rawValue) == coupler)
    }
}
```

`VerdictTests` and `CouplerTests` are two suites in one file only if you keep them in one file; `06 T5b` wants one suite per file, so **split them**: `VerdictTests.swift` and `CouplerTests.swift`.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter "ComparatorTests|ModeTests|VerdictTests|CouplerTests"`
All four must fail with `cannot find … in scope`.

**Step 3 — implement.** **Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Glyphs/Verdict.swift` |
| create | `HunchCore/Sources/Glyphs/Mode.swift` |
| create | `HunchCore/Sources/Glyphs/Coupler.swift` |
| create | `HunchCore/Sources/Glyphs/Comparator.swift` |
| create | `HunchCore/Tests/GlyphsTests/VerdictTests.swift` |
| create | `HunchCore/Tests/GlyphsTests/ModeTests.swift` |
| create | `HunchCore/Tests/GlyphsTests/CouplerTests.swift` |
| create | `HunchCore/Tests/GlyphsTests/ComparatorTests.swift` |
| modify | `DECISIONS.md` — the `Mode.salt` convention |

## Implementation notes

### Why four game-wide enums live in a target called `Glyphs`

`Mode` is named by `generate(seed:band:targetDelta:mode:avoid:)` in `LawGeneration`, by `StoreFile.round(Mode)` in `Persistence`, by `Ability.offset` in `Ladder` and by every round type in `Rounds`. `Comparator` is named by `MaskTable` in `Laws` and by `LawNode`. There is exactly one target every one of those depends on, and `08 §1` marks it *"leaf; empty `dependencies:`"* — `Glyphs`. Putting `Mode` anywhere else inverts an arrow, and adding a ninth target contradicts E01·T03's manifest. Four files, one line each in the header comment saying why they are here.

### `Comparator`

```swift
/// The six ordinal comparators of §3.2's `<cmp>` production.
///
/// They appear only on relational and contextual terms: §3.1 collapses every comparator
/// against a constant into a subset, so there is no operator dimension at the atom level at
/// all. The raw values are RNF's `cmpOrdinal` (§3.4 step 2) and are therefore a stored sort
/// key — reordering the cases relays out every saved Bench draft.
public enum Comparator: UInt8, CaseIterable, Sendable, Codable {
    case eq, neq, lt, lte, gt, gte

    /// Whether this comparator holds between two ranks.
    ///
    /// Ranks are 1…4 (§2), but the answer is unchanged on 0-based ordinals, because
    /// `rank == ordinal + 1` is strictly increasing.
    public func matches(_ lhs: Int, _ rhs: Int) -> Bool {
        switch self {
        case .eq: lhs == rhs
        case .neq: lhs != rhs
        case .lt: lhs < rhs
        case .lte: lhs <= rhs
        case .gt: lhs > rhs
        case .gte: lhs >= rhs
        }
    }

    /// The comparator that means the same thing with the operands swapped.
    ///
    /// §3.4 step 3: relational operands are ordered by canonical attribute order and the
    /// comparator is *"flipped to compensate"*; contextual terms always render `cur`-leading
    /// and reach the converse reading by flipping this, never by moving `prev`.
    public var flipped: Comparator {
        switch self {
        case .eq: .eq
        case .neq: .neq
        case .lt: .gt
        case .lte: .gte
        case .gt: .lt
        case .gte: .lte
        }
    }

    /// The negation. §3.1: the six comparators are closed under complement, which is one of
    /// the five cases that make `NOT` unnecessary in the grammar.
    public var complemented: Comparator {
        switch self {
        case .eq: .neq
        case .neq: .eq
        case .lt: .gte
        case .lte: .gt
        case .gt: .lte
        case .gte: .lt
        }
    }
}
```

`flipped` and `complemented` are the only members here that go beyond "an enum with six cases", and they are included deliberately: E05·T04 (RNF) and E05·T05 (complement-fold) both need them, T05's `MaskTable.relational(_:_:_:)` uses `flipped` to accept either attribute order, and deriving them in three places is three chances to get `lte`'s complement wrong. Every `switch` lists all six cases — `W29` forbids `default:` over your own enum, and the day a seventh comparator is added the compiler must say so in all three places.

### `Mode`, and the salt this task has to freeze

```swift
/// The four modes. Uppercase in copy (§2); `UInt8`-raw because §6.10 keys `round-{mode}.json`
/// by it and §11.13 makes it a `StoreFile` payload.
public enum Mode: UInt8, CaseIterable, Sendable, Codable {
    case probe, drift, echo, sieve

    /// The untranslated wordmark. §12.9 ships the mode names as wordmarks and forbids them
    /// entering the String Catalog, so the only correct rendering is `Text(verbatim:)`:
    /// `Text(mode.wordmark)` with a `String` is not extracted but reads as an oversight, and
    /// `Text("PROBE")` with a literal *is* extracted, which is the actual bug (`08 §3`).
    public var wordmark: String {
        switch self {
        case .probe: "PROBE"
        case .drift: "DRIFT"
        case .echo: "ECHO"
        case .sieve: "SIEVE"
        }
    }

    /// The per-mode seed salt of §5.3 step 1: `SplitMix64(seed ^ (band << 32) ^ mode.salt)`.
    ///
    /// The design fixes the formula and not the constants. These are the big-endian ASCII
    /// bytes of the wordmark — the same convention as §12.5's opening-round seed
    /// `0x48554E4348` ("HUNCH") — chosen once and frozen: changing one re-rolls every puzzle
    /// that mode has ever generated, and the cross-process determinism golden (E06·T10) will
    /// fail on the change, which is exactly what it is for.
    public var salt: UInt64 {
        switch self {
        case .probe: 0x50_52_4F_42_45      // "PROBE"
        case .drift: 0x44_52_49_46_54      // "DRIFT"
        case .echo: 0x45_43_48_4F          // "ECHO"
        case .sieve: 0x53_49_45_56_45      // "SIEVE"
        }
    }
}
```

The literals are written out rather than computed from `wordmark`, so that no `String` work happens on the generator's path and so that the constant is greppable; the *test* asserts the two agree, which is what keeps the convention honest. **Record the convention in `DECISIONS.md`** — the concurrency skill's rule for SplitMix64's unstated gamma applies verbatim to this unstated salt: choose once, write it down, let the golden fixture freeze it.

### `Verdict` and `Coupler`

```swift
/// The two verdicts (§2). Never "pass/fail", never "yes/no".
///
/// `N29` would normally reject imperative-verb cases; `N36` applies — the domain locks these
/// two words and `verdict == .admit` reads correctly (`08 §3`).
public enum Verdict: UInt8, CaseIterable, Sendable, Codable {
    case admit, reject

    /// The verdict a `Bool` from the evaluator means.
    public init(admits: Bool) { self = admits ? .admit : .reject }
}

/// The AND/OR/XOR node between two rule-tiles (§2, §3.2's `<coupler>`).
public enum Coupler: UInt8, CaseIterable, Sendable, Codable {
    case and, or, xor
}
```

`08 §3` spells `Verdict` without a raw value; this task adds `UInt8` + `Codable` because the ribbon and the snapshot persist a verdict per probe (§6.10) and because the epic brief requires all four to be `UInt8`-backed. That is additive, not contradictory — no line of `08 §3` changes meaning — so it needs no `DECISIONS.md` entry, only the comment above.

**`Coupler` gets no `apply(_:_:)`.** Combining two `Bitboard256`s under a coupler is *evaluation*, and the evaluator is E05·T03's — one owner, one place. The three operators `&`, `|`, `^` from T03 are what it will use, and the mapping is one-to-one by construction.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter "ComparatorTests|ModeTests|VerdictTests|CouplerTests"` is green.
- [ ] `grep -rn "default:" HunchCore/Sources/Glyphs/Comparator.swift HunchCore/Sources/Glyphs/Mode.swift` returns nothing (`W29`).
- [ ] `grep -rn "case .probe: 0x" HunchCore/Sources/Glyphs/Mode.swift` and the `saltIsTheWordmarkPacked` test both pass, so the constant and its derivation cannot drift.
- [ ] Every one of the four enums declares `: UInt8` and `: Sendable` explicitly (`R21`).
- [ ] `DECISIONS.md` records the `Mode.salt` = big-endian ASCII of the wordmark convention, with the note that changing it re-rolls every puzzle.
- [ ] Four source files and four test files, one top-level type each (`P24`, `06 T5b`).
- [ ] `Scripts/check-source-hygiene.sh` exits 0 — in particular the wordmarks are `String`s in core and no `Text` appears anywhere in `HunchCore`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. Decline any suggestion to compute `salt` from `wordmark` at runtime (argued above) or to merge the four files into one (`P24`).
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E02/T06: Verdict, Mode with the frozen wordmark salt, Coupler and the Comparator algebra"`

## Out of scope

- `Band` — the collapsed Band/Family type. It is §5.2's, it needs `par`/`cap`/`population`/`difficultyRange`, and it is **E05·T06**. Do not add a placeholder.
- `LawNode`, which *uses* `Coupler` and `Comparator` as payloads — **E05·T01**.
- `RoundPhase`, `Outcome`, `Probe` and `Ribbon`, which use `Verdict` — **E07·T07/T08**.
- `Text(verbatim: mode.wordmark)` at any call site — **E17** (the Frame) and **E08**; this task ships the string and no view.
- `mode.salt`'s consumer, `generate(seed:band:targetDelta:mode:avoid:)` — **E06·T06**.
- The `Cue` vocabulary, which is also a shared value enum but belongs to `Feedback` and is created on the day it is needed (`01 P12`) — **E20·T01**.
