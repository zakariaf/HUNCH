# T04 — Bitboard65536 and cross-arity lifting

| | |
|---|---|
| **Epic** | E02 — Glyph vocabulary and the bitboard algebra |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | §14.1 CORE SYSTEMS → **Extension tables + masks** (the contextual half: `Bitboard65536` with cross-arity lifting) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | `lift` is the *only* comparison path between a stateless declaration and a contextual law (§3.6, §4.5), so its API shape decides how E05's equivalence test and E09's declaration verdict are written. The skill owns the type-choice procedure — an 8 KiB value is exactly `W4`'s "is this large enough to want storage?" question — and the rule that nothing in `HunchCore` is a class, which rules out the obvious buffer-object answer. |

`hunch-swift-testing` is deliberately **not** loaded here: this task adds no new test infrastructure, tag or fixture, and its assertions are algebraic identities in the suite T03 already established. Load it again at T05, which does add a corpus-shaped suite.

## Objective

`Bitboard65536` exists — 1024 `UInt64`s over the 65,536 ordered `(prev, cur)` pairs, indexed `prev*256 + cur` — together with `lift`, row extraction, comparison at the larger of two arities, and `isStateless`, the property that answers §3.6's question *"is this contextual law secretly stateless?"*. After this task a contextual law has a representation, a stateless law can be judged against one, and G7 has the predicate it is defined in terms of.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.6 | The contextual row of the representation table (`Bitboard65536` = 1024 × `UInt64`, 8 KiB, index `prev*256 + cur`, build ≈2 µs, compare ≈0.4 µs) · **Cross-class comparison — lifting**: `lift(T) = TILE * T` where `TILE` has bit `i*256` set for all `i`, *no carries since `T < 2^256`* · *"Comparison always happens at the larger of the two arities"* · `P == lift(P & FULL256)` · *"A contextual pair table is materialised on demand by tiling its four row masks — 1024 word writes"* · *"Never stored in the Codex; a Codex page stores the AST and rebuilds."* |
| `GAME_DESIGN.md` | §3.5 | Why the second axis is `prev` at all: `previous` means the **previously probed** glyph regardless of verdict, and the Loom is always primed by a seed glyph, so position 0 has a `prev`. There is no third axis — *"Statefulness beyond depth 1: none."* |
| `GAME_DESIGN.md` | §5.3 | G7, *genuinely contextual*: bands 5 and 7 require `P != lift(P & FULL256)`. |
| `GAME_DESIGN.md` | §5.7 | Locked: ordered pairs = 65,536; contextual equivalence check = 1024 × `UInt64` (8 KiB). |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §4 | Same file as `Bitboard256`; explicit `: Sendable`. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W4, W18, W39, W52 | COW storage for a genuinely large value type rather than a class; `let`; `precondition`; document the cost. |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N9, N14, N33 | Third-person boolean verbs (`contains`, `matches`, `isStateless`); a *narrowing or widening* conversion labels the conversion, so `init(lifting:)` keeps its label; `FULL256`/`TILE` are `N33` violations as spellings and ship as `full` and an implementation detail of `lift`. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/GlyphsTests/Bitboard65536Tests.swift`:

```swift
import Testing
import Glyphs
import HunchTestSupport

@Suite("Bitboard65536 and lifting", .tags(.unit, .presubmission))
struct Bitboard65536Tests {

    /// Eight stateless tables with varied bit patterns — the same fixed mixing sequence
    /// `BitboardTests` uses, kept local so the two suites stay independent.
    private static let statelessCorpus: [Bitboard256] = (0..<8).map { index in
        func word(_ salt: UInt64) -> UInt64 {
            let mixed = (UInt64(index) &+ salt) &* 0x9E37_79B9_7F4A_7C15
            return mixed ^ (mixed >> 29)
        }
        return Bitboard256(word0: word(1), word1: word(2), word2: word(3), word3: word(4))
    }

    /// §5.2's entry-level contextual law: `RANK pips(cur) > PREV RANK pips`.
    /// Built here by brute force over all 65,536 ordered pairs — the oracle, not the API.
    private static let pipsIncreases: Bitboard65536 = {
        var board = Bitboard65536()
        for previous in Deck.all {
            for current in Deck.all where current.pips.rank > previous.pips.rank {
                board.insert(current: current.id, after: previous.id)
            }
        }
        return board
    }()

    // MARK: - the pair index

    @Test("A pair sits at bit prev*256 + cur")
    func pairIndexing() {
        var board = Bitboard65536()
        board.insert(current: 5, after: 3)
        #expect(board.contains(current: 5, after: 3))
        #expect(!board.contains(current: 3, after: 5))
        #expect(board.count == 1)
        #expect(board.row(after: 3) == Bitboard256(ids: [5]))
        #expect(board.row(after: 5) == .empty)
    }

    @Test("The universe is 65,536 ordered pairs")
    func universeSize() {
        #expect(Bitboard65536.full.count == 65_536)
        #expect(Bitboard65536().count == 0)
        #expect(Bitboard65536.wordCount == 1_024)
    }

    @Test("row(after:) agrees with contains(current:after:) on every pair of a real law")
    func rowsAgreeWithMembership() {
        let board = Self.pipsIncreases
        let disagreements = Deck.all.filter { previous in
            let row = board.row(after: previous.id)
            return !Deck.all.allSatisfy { current in
                row.contains(current.id) == board.contains(current: current.id, after: previous.id)
            }
        }
        #expect(disagreements.isEmpty)
    }

    // MARK: - lifting: the only cross-arity comparison there is

    @Test("Lifting tiles a stateless table into every row", arguments: Bitboard65536Tests.statelessCorpus)
    func liftTilesEveryRow(_ table: Bitboard256) {
        let lifted = Bitboard65536(lifting: table)
        #expect(Deck.all.allSatisfy { lifted.row(after: $0.id) == table })
        #expect(lifted.count == 256 * table.count)
        #expect(lifted.statelessProjection == table)          // P & FULL256
        #expect(lifted.isStateless)
    }

    @Test("Lifting is injective — two stateless laws lift to the same pair table iff they are the same law")
    func liftIsInjective() {
        let lifted = Self.statelessCorpus.map(Bitboard65536.init(lifting:))
        #expect(lifted.indices.allSatisfy { i in
            lifted.indices.allSatisfy { j in (lifted[i] == lifted[j]) == (i == j) }
        })
    }

    @Test("Lifting is a homomorphism, which is what makes comparison at the larger arity sound",
          arguments: Bitboard65536Tests.statelessCorpus)
    func liftIsAHomomorphism(_ a: Bitboard256) {
        let b = Bitboard256(ids: stride(from: 1, to: 256, by: 7))
        #expect(Bitboard65536(lifting: a & b) == Bitboard65536(lifting: a) & Bitboard65536(lifting: b))
        #expect(Bitboard65536(lifting: a | b) == Bitboard65536(lifting: a) | Bitboard65536(lifting: b))
        #expect(Bitboard65536(lifting: a ^ b) == Bitboard65536(lifting: a) ^ Bitboard65536(lifting: b))
        #expect(Bitboard65536(lifting: ~a) == ~Bitboard65536(lifting: a))
    }

    @Test("The two constants lift to the two constants")
    func liftPreservesConstants() {
        #expect(Bitboard65536(lifting: .empty) == Bitboard65536())
        #expect(Bitboard65536(lifting: .full) == Bitboard65536.full)
    }

    @Test("matches(_:) compares at the larger arity", arguments: Bitboard65536Tests.statelessCorpus)
    func comparisonHappensAtTheLargerArity(_ table: Bitboard256) {
        #expect(Bitboard65536(lifting: table).matches(table))
        #expect(!Self.pipsIncreases.matches(table))
    }

    // MARK: - "is this contextual law secretly stateless?"

    @Test("A genuinely contextual law is not stateless — G7's predicate")
    func genuinelyContextualIsNotStateless() {
        let board = Self.pipsIncreases
        #expect(!board.isStateless)
        #expect(board != Bitboard65536(lifting: board.statelessProjection))
        // Its verdict really does depend on prev: two different rows exist.
        #expect(board.row(after: Deck.all.first { $0.pips == .one }!.id)
             != board.row(after: Deck.all.first { $0.pips == .four }!.id))
    }

    @Test("isStateless is exactly P == lift(P & FULL256)", arguments: Bitboard65536Tests.statelessCorpus)
    func statelessnessIsTheStatedIdentity(_ table: Bitboard256) {
        let lifted = Bitboard65536(lifting: table)
        #expect(lifted.isStateless == (lifted == Bitboard65536(lifting: lifted.statelessProjection)))
        #expect(Self.pipsIncreases.isStateless
             == (Self.pipsIncreases == Bitboard65536(lifting: Self.pipsIncreases.statelessProjection)))
    }

    // MARK: - building from row masks, which is how a contextual law is materialised

    @Test("init(rows:) reproduces a law built pair by pair")
    func initFromRows() {
        // The same law as `pipsIncreases`, built the way MaskTable will build it: one row
        // per prev, where the row depends only on prev's pips rank.
        let byRow = Bitboard65536(rows: { previous in
            let previousRank = Deck.glyph(id: previous).pips.rank
            return Bitboard256(ids: Deck.all.lazy.filter { $0.pips.rank > previousRank }.map(\.id))
        })
        #expect(byRow == Self.pipsIncreases)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter Bitboard65536Tests`
It must fail with `cannot find 'Bitboard65536' in scope`. If it fails on `Deck` or `Bitboard256`, T02/T03 regressed — fix those first.

**Step 3 — implement.** **Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Glyphs/Bitboard.swift` — add `Bitboard65536` below `Bitboard256` |
| create | `HunchCore/Tests/GlyphsTests/Bitboard65536Tests.swift` |
| modify | `tests.json` — add the lift-identity and statelessness invariants |

## Implementation notes

### The type

```swift
/// The extension of a contextual law: which of the 65,536 ordered `(prev, cur)` pairs it admits.
///
/// 1024 `UInt64`s, bit `(prev*256 + cur)`, exactly as §3.6 fixes the index. `prev` is the
/// previously *probed* glyph regardless of verdict (§3.5); at position 0 it is the seed glyph.
/// There is no third axis and there will not be one — §3.5 rules out depth-2 statefulness, and
/// the table would grow from 8 KiB to 2 MiB.
///
/// Never persisted. A Codex page stores the AST and rebuilds this in ≈2 µs (§3.6).
public struct Bitboard65536: Equatable, Sendable {

    /// 65,536 bits ÷ 64.
    public static let wordCount = 1_024

    @usableFromInline internal private(set) var words: ContiguousArray<UInt64>

    /// The empty table.
    public init() { words = ContiguousArray(repeating: 0, count: Self.wordCount) }

    /// Tiles `table` across every value of `prev` — §3.6's `lift(T) = TILE * T`.
    public init(lifting table: Bitboard256) { … }

    /// Materialises a contextual table from one row per `prev` — the four-row tiling of §3.6.
    /// - Complexity: O(256) calls to `row`, 1024 word writes, ≈2 µs.
    public init(rows row: (Int) -> Bitboard256) { … }

    public static let full: Bitboard65536 = …
    public var count: Int
    public func contains(current: Int, after previous: Int) -> Bool
    public mutating func insert(current: Int, after previous: Int)
    public func row(after previous: Int) -> Bitboard256

    /// §3.6's `P & FULL256`: the low 256 bits, which is the row for `prev == 0`.
    public var statelessProjection: Bitboard256

    /// §3.6's *"is this contextual law secretly stateless?"* — `P == lift(P & FULL256)`. G7 (§5.3)
    /// requires this to be `false` at bands 5 and 7.
    public var isStateless: Bool

    /// Comparison at the larger of the two arities (§3.6) — how a stateless declaration is
    /// judged against a contextual hidden law (§4.5).
    public func matches(_ table: Bitboard256) -> Bool { self == Bitboard65536(lifting: table) }

    public static prefix func ~ (board: Self) -> Self
    public static func & (lhs: Self, rhs: Self) -> Self
    public static func | (lhs: Self, rhs: Self) -> Self
    public static func ^ (lhs: Self, rhs: Self) -> Self
}
```

### The one insight that makes `lift` trivial

§3.6 states lifting as a bignum multiply — `lift(T) = TILE * T`, `TILE` having bit `i*256` set for all `i`, *"no carries, since `T < 2^256`"*. Do **not** write a multiply. 256 bits is exactly four 64-bit words, and every block boundary `prev*256` is therefore a multiple of 64, so the multiply degenerates to a **word-aligned copy** with no shifting and, by construction, no carries:

```swift
public init(lifting table: Bitboard256) {
    var words = ContiguousArray<UInt64>(repeating: 0, count: Self.wordCount)
    for previous in 0..<256 {
        let base = previous << 2                       // prev*256 bits = prev*4 words
        words[base] = table.word(at: 0)
        words[base + 1] = table.word(at: 1)
        words[base + 2] = table.word(at: 2)
        words[base + 3] = table.word(at: 3)
    }
    self.words = words
}
```

That alignment is the whole reason §3.6 can claim "no carries" without qualification, and it is why `init(rows:)` is the same loop with a varying source. Write the comment; the next reader will otherwise go looking for the missing multiplication.

`init(rows:)` is the general form and `init(lifting:)` is `init(rows: { _ in table })` — implement the general one and express the special case in terms of it *only if* it measures the same; a constant-source loop is cheaper than 256 closure calls, so keeping the two loops separate is justified and should be commented as such.

### Row extraction and the projection

```swift
public func row(after previous: Int) -> Bitboard256 {
    precondition((0..<256).contains(previous), "glyphID \(previous) is outside 0…255")
    let base = previous << 2
    return Bitboard256(word0: words[base], word1: words[base + 1],
                       word2: words[base + 2], word3: words[base + 3])
}

/// §3.6's `P & FULL256` — the low 256 bits, which by the index formula is `row(after: 0)`.
public var statelessProjection: Bitboard256 { row(after: 0) }
```

Both spellings are correct and identical; use `row(after: 0)` and say in the doc comment that it is `P & FULL256`, so a reader coming from §3.6 finds the sentence they are looking for.

### `isStateless`, written the way the design writes it

```swift
public var isStateless: Bool { self == Bitboard65536(lifting: statelessProjection) }
```

This allocates and fills 8 KiB to answer a question that a short-circuiting row scan answers in three words on the average failing case. Keep the literal form anyway: it is called at *generation* time only (G7, and E05's equivalence path), it costs ≈2 µs against a 200-attempt budget, and the identity in the source matching the identity in §3.6 is worth more than the microseconds. **Write that reasoning as a comment**, or `/simplify` will replace it with the scan and the next reader will have to re-derive the equivalence.

### Storage: `ContiguousArray`, not four hundred properties and not a class

8 KiB is `W4`'s genuinely-large value: `ContiguousArray<UInt64>` gives copy-on-write for free, so passing a table around costs a retain, and mutation through `insert` costs one uniqueness check. A class is out (`hunch-swift-code`: nothing in `HunchCore` is a class). An `InlineArray` would put 8 KiB on the stack for every temporary — worse, not better.

`words` is `private(set)` and `@usableFromInline` so the operators can be `@inlinable` without exposing the buffer; the invariant *`words.count == wordCount`, always* is maintained by every initialiser and by nothing else. State it in a comment on the property.

### `Equatable`, not `Hashable`

Deliberate. Hashing 8 KiB feeds 1,024 words into the hasher on every insertion into a `Set`, and §3.6 does not index contextual tables that way — it uses an explicit **64-bit hash with rebuild-and-compare on collision** (E05·T05/T07, the 17,248-hash contextual index). Leaving `Hashable` off makes the expensive mistake a compile error. Say so in the doc comment.

### Cost, and the sentence to put in the doc comment

Build ≈2 µs, compare ≈0.4 µs (§3.6). No benchmark suite here: T03 established the measurement pattern for the 32-byte type, and a 1024-word `memcmp` needs no defending. If E05's equivalence path ever shows up in a profile, the fix named by the design is to compare the 64-bit hash first, not to make this type cleverer.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter Bitboard65536Tests` is green, all 12 tests, including the eight-case parameterised ones.
- [ ] `#expect(Bitboard65536.wordCount == 1_024)` passes and `MemoryLayout` is not asserted for this type (it is a COW box; its `stride` is a pointer).
- [ ] `grep -n "lift\|TILE\|FULL256" HunchCore/Sources/Glyphs/Bitboard.swift` shows a comment explaining the word-aligned-copy degeneration of §3.6's multiply.
- [ ] `grep -n "Hashable" HunchCore/Sources/Glyphs/Bitboard.swift` shows `Bitboard256` conforming and `Bitboard65536` not, with the reason on the line above.
- [ ] The fast suite is still under 10 s.
- [ ] `tests.json` has entries for the lift identities and for `P == lift(P & FULL256)`, both `pass`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. Decline the `isStateless` row-scan rewrite and decline collapsing `init(lifting:)` into `init(rows:)`; both are argued above.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E02/T04: Bitboard65536, word-aligned lifting, comparison at the larger arity and the statelessness identity"`

## Out of scope

- G7 itself — the guardrail that *calls* `isStateless` at bands 5 and 7 — **E06·T05**.
- The four contextual **row masks** that a real contextual law's rows come from — **T05**. This task ships `init(rows:)`; T05 ships the rows.
- `LawTable`'s either-arity wrapper, which chooses between the two bitboards per law — **E05·T02**.
- The declaration verdict that compares a player's draft against the hidden law by lifting — **E09·T08**.
- Any persistence of a pair table: §3.6 forbids it outright, and E07 stores the `LawNode`.
