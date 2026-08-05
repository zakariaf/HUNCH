# T03 — Bitboard256

| | |
|---|---|
| **Epic** | E02 — Glyph vocabulary and the bitboard algebra |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 CORE SYSTEMS → **Extension tables + masks** (the stateless half: `Bitboard256`, 4 × `UInt64`, ≈20 ns build / ≈5 ns compare) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This is the type §3.6 makes the canonical form of a law, so its API decides how the evaluator, RNF, the dedup key and the Assay are all written. The skill owns the type-choice procedure (`W1`/`W2`), the "nothing in `HunchCore` is a class" rule that rules out a boxed word buffer, and the `public struct`'s-memberwise-init-is-internal gotcha you hit the moment `Laws` constructs one. |
| `hunch-swift-testing` | The ≈20 ns / ≈5 ns budgets must be *measured and recorded* without putting a wall-clock assertion in the presubmission suite. The skill owns the two-axis tag vocabulary (`.performance` + `.nightly`), the 10-second budget the fast suite must stay inside, and `06 T42`'s rule that a seeded `SplitMix64` — never `.random` — is how you get a corpus of test boards. |

## Objective

`Bitboard256` exists: an immutable 32-byte value type over the 256-glyph deck with popcount, membership, insertion, complement and the three boolean combinators that `Coupler.and/or/xor` map onto one-for-one. After this task a law's extension has a representation, and the ≈20 ns build / ≈5 ns compare figures of §3.6 are measured numbers in `DECISIONS.md` rather than a claim in a design document.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.6 | The representation table: *stateless law → `Bitboard256` = 4 × `UInt64` (32 B), build 4 word-ops from precomputed masks ≈ **20 ns**, compare 4 word compares ≈ **5 ns***. *"The extension is the canonical form. Syntax is never compared."* `FULL256` appears here and in the lifting paragraph. |
| `GAME_DESIGN.md` | §5.7 | Locked constants: *Equivalence check — stateless: 4 × `UInt64`; build ≈ 20 ns, compare ≈ 5 ns*. |
| `GAME_DESIGN.md` | §5.3 | G1 `popcount(T) ≥ 1`, G2 `popcount(T) ≤ N − 1`, G3 `p = popcount(T)/N` — the three guardrails that are pure popcount, so `count` is on the hot path of generation. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §4 | `Glyphs/Bitboard.swift` holds `Bitboard256`, `Bitboard65536` and lift/tile; every public value type writes `: Sendable`. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W1, W4, W18, W19, W39, W52 | `struct` by default; COW only after measuring; `let`; `switch` expressions; `precondition` for the caller's contract; document cost. |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N9, N33, N47 | Booleans as third-person assertions (`contains`, `isEmpty`); no `SCREAMING_SNAKE`, so §3.6's `FULL256` ships as `Bitboard256.full`; `- Complexity:` where access is not O(1). |
| `ios-swift-guide/06-TESTING.md` | T30, T42, T58 | Tag on kind **and** cadence; inject an RNG, never stub `.random`; do not delete a slow test — tag it, plan it, budget it. |

## TDD — the test comes first

**Step 1 — write the failing tests.** Two files: the correctness suite (presubmission) and the budget suite (nightly).

Create `HunchCore/Tests/GlyphsTests/BitboardTests.swift`:

```swift
import Testing
import Glyphs
import HunchTestSupport

@Suite("Bitboard256", .tags(.unit, .presubmission))
struct BitboardTests {

    /// Sixty-four boards with varied bit patterns, from a fixed mixing sequence.
    ///
    /// Deliberately **not** `SplitMix64`: that type lives in `LawGeneration`, and importing it
    /// here would point `GlyphsTests` at a target three layers above the one it tests. Nothing
    /// below needs randomness — it needs variety, and every assertion is an invariant rather
    /// than a golden order (`06 T42`).
    private static let corpus: [Bitboard256] = (0..<64).map { index in
        func word(_ salt: UInt64) -> UInt64 {
            let mixed = (UInt64(index) &+ salt) &* 0x9E37_79B9_7F4A_7C15
            return mixed ^ (mixed >> 29)
        }
        return Bitboard256(word0: word(1), word1: word(2), word2: word(3), word3: word(4))
    }

    // MARK: - the 256 bit positions

    @Test("An empty board contains nothing and a full board contains everything")
    func emptyAndFull() {
        #expect(Bitboard256.empty.count == 0)
        #expect(Bitboard256.empty.isEmpty)
        #expect(Bitboard256.full.count == 256)
        #expect(!Bitboard256.full.isEmpty)
        #expect(~Bitboard256.empty == .full)
        #expect(~Bitboard256.full == .empty)
    }

    @Test("A single insert is visible at exactly one id", arguments: 0..<256)
    func insertAndTest(_ id: Int) {
        var board = Bitboard256.empty
        board.insert(id)
        #expect(board.contains(id))
        #expect(board.count == 1)
        #expect(Bitboard256.full.contains(id))
        #expect(!Bitboard256.empty.contains(id))
        #expect((0..<256).filter(board.contains) == [id])
    }

    @Test("Inserting twice is idempotent")
    func insertIsIdempotent() {
        var board = Bitboard256.empty
        board.insert(97)
        board.insert(97)
        #expect(board.count == 1)
    }

    @Test("id maps to word id >> 6, bit id & 63 — the packing the mask builders assume")
    func wordPacking() {
        var board = Bitboard256.empty
        board.insert(0)
        board.insert(64)
        board.insert(129)
        board.insert(255)
        #expect(board.word(at: 0) == 1)
        #expect(board.word(at: 1) == 1)
        #expect(board.word(at: 2) == 1 << 1)
        #expect(board.word(at: 3) == 1 << 63)
    }

    @Test("init(ids:) is the same board as repeated inserts")
    func initFromIDs() {
        let ids = [0, 1, 63, 64, 200, 255]
        var built = Bitboard256.empty
        for id in ids { built.insert(id) }        // building the oracle, not the assertion
        #expect(Bitboard256(ids: ids) == built)
        #expect(Bitboard256(ids: ids).count == ids.count)
        #expect(Bitboard256(ids: 0..<256) == .full)
    }

    // MARK: - the boolean algebra Coupler maps onto

    @Test("Complement and the three combinators obey the identities RNF folds with",
          arguments: BitboardTests.corpus)
    func booleanAlgebra(_ a: Bitboard256) {
        #expect(~(~a) == a)
        #expect(a & a == a)
        #expect(a | a == a)
        #expect(a ^ a == .empty)
        #expect(a & ~a == .empty)
        #expect(a | ~a == .full)
        #expect(a ^ .empty == a)
        #expect(a & .full == a)
        #expect(a | .empty == a)
        #expect(a.count + (~a).count == 256)
    }

    @Test("De Morgan holds pairwise across the corpus")
    func deMorgan() {
        let pairs = zip(Self.corpus, Self.corpus.dropFirst())
        #expect(pairs.allSatisfy { ~($0 & $1) == ~$0 | ~$1 })
        #expect(pairs.allSatisfy { ~($0 | $1) == ~$0 & ~$1 })
        #expect(pairs.allSatisfy { ($0 ^ $1) == ($0 | $1) & ~($0 & $1) })
        #expect(pairs.allSatisfy { ($0 & $1).count <= min($0.count, $1.count) })
    }

    @Test("count is the population count, checked against a bit-by-bit walk",
          arguments: BitboardTests.corpus)
    func countIsPopulationCount(_ board: Bitboard256) {
        #expect(board.count == (0..<256).count(where: board.contains))
    }

    @Test("The layout is 32 bytes — T05's 54 KB resident figure is 1,690 × this")
    func layoutIsThirtyTwoBytes() {
        #expect(MemoryLayout<Bitboard256>.size == 32)
        #expect(MemoryLayout<Bitboard256>.stride == 32)
    }

    // MARK: - equality is the whole point of the type

    @Test("Two boards are equal iff they hold the same ids, and equal boards hash equally")
    func equalityIsExtensional() {
        let a = Bitboard256(ids: [3, 200])
        let b = Bitboard256(ids: [200, 3])
        let c = Bitboard256(ids: [3, 201])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("An out-of-range id is a precondition failure, not a silent wrap")
    func outOfRangeIDTraps() async {
        await #expect(processExitsWith: .failure) {
            var board = Bitboard256.empty
            board.insert(256)
        }
    }
}
```

Create `HunchCore/Tests/GlyphsTests/BitboardBudgetTests.swift`:

```swift
import Foundation            // Attachment.record needs Foundation's Attachable conformance
import Testing
import Glyphs
import HunchTestSupport

/// §3.6's two published figures, measured rather than asserted. Nightly, because a wall-clock
/// assertion in the presubmission suite is a flake generator on shared CI (`06 T30`, `T58`).
/// The ceilings below are order-of-magnitude guards, not the design's figures: they catch a
/// build that has become allocating or boxed, and nothing finer than that.
@Suite("Bitboard256 budgets", .tags(.performance, .nightly))
struct BitboardBudgetTests {

    private static let iterations = 1_000_000

    /// Nanoseconds per operation. `Duration.components` splits into whole seconds plus
    /// attoseconds, so both halves must be read or a run over one second is mis-reported.
    private static func nanosecondsPerOperation(_ elapsed: Duration) -> Double {
        let total = Double(elapsed.components.seconds) * 1e9
            + Double(elapsed.components.attoseconds) / 1e9
        return total / Double(iterations)
    }

    @Test("Building a two-term extension from masks stays inside the build budget")
    func buildBudget() {
        // 256 pretend atom masks, indexed the way MaskTable will be, so neither lookup
        // is loop-invariant and the optimiser cannot hoist the build out of the loop.
        let masks = (0..<256).map { Bitboard256(ids: stride(from: $0 % 13, to: 256, by: 3)) }
        var sink = Bitboard256.empty

        let elapsed = ContinuousClock().measure {
            for index in 0..<Self.iterations {
                let left = masks[index & 255]
                let right = masks[(index &* 31) & 255]
                sink = sink ^ (left & right)          // one build: two lookups, one combinator
            }
        }

        let perOperation = Self.nanosecondsPerOperation(elapsed)
        Attachment.record("\(perOperation) ns/build", named: "bitboard256-build.txt")
        #expect(sink.count >= 0)                      // reads `sink`, so the loop may not be deleted
        #expect(perOperation < 200)                   // §3.6 says ≈20 ns; this catches a regression of kind
    }

    @Test("Comparing two extensions stays inside the compare budget")
    func compareBudget() {
        // Built in equal adjacent pairs: boards[2k] == boards[2k+1], so every comparison
        // is a real four-word compare that returns true and the count is checkable.
        let boards = (0..<256).map { Bitboard256(ids: stride(from: ($0 / 2) % 11, to: 256, by: 3)) }
        var matches = 0

        let elapsed = ContinuousClock().measure {
            for index in 0..<Self.iterations {
                let slot = index & 255
                if boards[slot] == boards[slot ^ 1] { matches &+= 1 }
            }
        }

        let perOperation = Self.nanosecondsPerOperation(elapsed)
        Attachment.record("\(perOperation) ns/compare", named: "bitboard256-compare.txt")
        #expect(matches == Self.iterations)
        #expect(perOperation < 50)                    // §3.6 says ≈5 ns
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter BitboardTests`
It must fail with `cannot find 'Bitboard256' in scope`. Confirm the budget suite does **not** run in the default plan — `swift test --package-path HunchCore` should not spend a second in it; if it does, the `.nightly` tag is not wired into `Presubmission.xctestplan` and that is an E01·T07 defect.

**Step 3 — implement.** **Step 4 — green, then refactor, then measure.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Glyphs/Bitboard.swift` |
| create | `HunchCore/Tests/GlyphsTests/BitboardTests.swift` |
| create | `HunchCore/Tests/GlyphsTests/BitboardBudgetTests.swift` |
| modify | `DECISIONS.md` — the measured build/compare figures and the `@inlinable` ruling |

`Bitboard.swift` is the one deliberate `P24` exception in this epic: `08 §1` puts `Bitboard256`, `Bitboard65536` and lifting in one file because the second type is meaningless without the first and `lift` is a conversion between them (`P25` case (a), read broadly). T04 adds `Bitboard65536` to this same file. Do not create `Bitboard256.swift`.

## Implementation notes

### The type

```swift
/// The extension of a stateless law: which of the 256 glyphs it admits.
///
/// Four `UInt64`s, bit `id & 63` of word `id >> 6`, indexed by `Glyph.id`. §3.6 makes this the
/// canonical form of a law — *syntax is never compared* — so equality of two `Bitboard256`s is
/// equality of two laws, and it costs four word compares.
public struct Bitboard256: Hashable, Sendable {
    public var word0: UInt64
    public var word1: UInt64
    public var word2: UInt64
    public var word3: UInt64

    public init(word0: UInt64 = 0, word1: UInt64 = 0, word2: UInt64 = 0, word3: UInt64 = 0) { … }

    public init(ids: some Sequence<Int>) { … }

    /// Nothing admitted. The all-0 table §3.4 step 5 constant-folds and the Seal bars on.
    public static let empty = Bitboard256()

    /// Everything admitted — §3.6's `FULL256`, spelled for `N33`.
    public static let full = Bitboard256(word0: .max, word1: .max, word2: .max, word3: .max)

    public var count: Int          // popcount: four `nonzeroBitCount`s
    public var isEmpty: Bool       // all four words zero — cheaper than `count == 0`
    public func contains(_ id: Int) -> Bool
    public mutating func insert(_ id: Int)
    public func word(at index: Int) -> UInt64      // 0…3; what `lift` scatters

    public static prefix func ~ (board: Self) -> Self
    public static func & (lhs: Self, rhs: Self) -> Self
    public static func | (lhs: Self, rhs: Self) -> Self
    public static func ^ (lhs: Self, rhs: Self) -> Self
}
```

### Four decisions

1. **Four stored `UInt64`s, not `[UInt64]` and not a tuple.** An array is a heap allocation and a retain/release per copy, which destroys the 20 ns budget and makes the type non-trivially copyable; a tuple synthesises no `Equatable`/`Hashable`. Four properties give a 32-byte trivially-copyable value with synthesized conformances. `W4` says reach for COW storage only after measuring a *large* value — 32 bytes is two registers' worth.
2. **Operators `~ & | ^`, and no `SetAlgebra` conformance.** The three combinators are exactly `Coupler.and/or/xor` (§3.2), and `RNF`'s same-attribute merge is stated in §3.4 as `AND→∩, OR→∪, XOR→△`; the operator spelling makes the evaluator read like the BNF. `SetAlgebra` would drag in `subtracting`, `isSubset(of:)`, `remove`, `Element` semantics and an `insert` that returns a tuple — a wider surface, none of which the design uses, and it invites callers to think of a law's extension as a collection to iterate. Rejected on purpose; do not let `/simplify` add it.
3. **`@inlinable` on `word(at:)`, `contains`, `insert` and the four operators.** These are three-instruction functions called across a module boundary (`Glyphs` → `Laws` → `LawGeneration`), and SwiftPM compiles each module separately, so without `@inlinable` every one is a real call and §3.6's budgets are unreachable. The cost — implementation frozen into clients — is irrelevant for a leaf type in an app that ships as one binary. Record the ruling in `DECISIONS.md`.
4. **`word(at:)` uses a `switch` expression with a `default: preconditionFailure`.** `W29` bans `default:` over *your own enum*; `Int` is not one, so the default arm is required. Use `W19`'s expression form.

```swift
@inlinable public func word(at index: Int) -> UInt64 {
    switch index {
    case 0: word0
    case 1: word1
    case 2: word2
    case 3: word3
    default: preconditionFailure("word index \(index) is outside 0…3")
    }
}
```

### Membership and insertion

```swift
@inlinable public func contains(_ id: Int) -> Bool {
    precondition((0..<256).contains(id), "glyphID \(id) is outside 0…255")
    return word(at: id >> 6) & (1 << UInt64(id & 63)) != 0
}
```

`insert` writes the same bit through a `switch` over `id >> 6`. Keep the precondition on both: a silent wrap here would corrupt a mask table that four later epics trust, and `06 T49`'s exit test is cheap enough to cover it.

### Measuring, and what to record

Run the budget suite in **release** — a debug build measures the optimiser's absence, not the code:

```bash
swift test --package-path HunchCore -c release --filter BitboardBudgetTests
```

Record in `DECISIONS.md`: the two measured `ns/op` figures, the machine and the toolchain (`swift --version`), and the note that §3.6's 20 ns / 5 ns are *A15-class device* figures while this is a host measurement, so the two are the same order and not the same number. That sentence is the whole point of writing it down: the next person to read "≈20 ns" in the design should find out, from the repo, what was actually measured and where.

If either figure lands more than 10× over budget, the cause is almost always (a) a missing `-c release`, (b) `@inlinable` not applied, or (c) the optimiser having deleted the loop because `sink` is unused — check the third by making `iterations` 10× larger and confirming the time scales.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter BitboardTests` is green, with 256 parameterised cases for `insertAndTest` and 64 for each corpus-parameterised test.
- [ ] `swift test --package-path HunchCore` does **not** execute `BitboardBudgetTests` (it is `.nightly`), and the fast suite is still under 10 s.
- [ ] `swift test --package-path HunchCore -c release --filter BitboardBudgetTests` is green and both `Attachment`s are present in the result bundle.
- [ ] `MemoryLayout<Bitboard256>.size == 32` and `.stride == 32` — assert it in `BitboardTests`; T05's 54 KB figure depends on it.
- [ ] `DECISIONS.md` records the two measured figures, the host and the toolchain version.
- [ ] `grep -n "class\|actor\|@unchecked" HunchCore/Sources/Glyphs/Bitboard.swift` returns nothing.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. Decline `SetAlgebra` and decline replacing the four words with an array; both are argued above and the reasons belong in the commit body, not in a re-litigation.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E02/T03: Bitboard256 with popcount, membership, complement and the three combinators"`

## Out of scope

- `Bitboard65536`, `lift`, `TILE`, row extraction and the statelessness identity — **T04**, in this same file.
- Any *mask* — a `Bitboard256` with a meaning — **T05**. This task ships the container and no content.
- `LawTable`, `admitRate`, `isSatisfiable`, `isFalsifiable` and the dedup hash: they are one-line wrappers over `count` and `==`, and they are **E05·T02**'s, because they need the AST to have a table to resolve.
- The Assay's 16 × 16 rendering of a table — **E09·T05**.
