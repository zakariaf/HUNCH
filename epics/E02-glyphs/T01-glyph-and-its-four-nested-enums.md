# T01 — Glyph and its four nested enums

| | |
|---|---|
| **Epic** | E02 — Glyph vocabulary and the bitboard algebra |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | nothing |
| **Delivers** | §14.1 CORE SYSTEMS → **Glyph model** (`4 attributes × 4 values, glyphID = fill*64 + shape*16 + pips*4 + hue; canonical order fill → shape → pips → hue everywhere`) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task is the first file in `HunchCore` and it makes the single most consequential naming call in the codebase: §2 of the skill's naming pass is *"the three collisions that actually bite"*, and collision #1 is `Shape`. The skill also owns the placement decision (`Glyphs/` is the leaf target), the "a `public struct`'s memberwise initialiser is internal" gotcha you will hit on line 10, and the `enum X: Int, Comparable` / SE-0266 gotcha you will hit if you try to make the value enums `Comparable`. |

No design skill is loaded: this task produces zero pixels. `Glyph.Hue.amber` is an identifier here, not a colour — the colour is `hunch-design-tokens`' in E03 and the drawing is `hunch-glyph-renderer`'s in E04.

## Objective

`HunchCore/Sources/Glyphs/Glyph.swift` exists and declares the game's atom: an immutable four-field value with `Fill`, `Shape`, `Pips`, `Hue` and `Attribute` nested inside it, cases spelled exactly as §2 locks them, and a positional `id` in `0…255`. Before this file there is no way to name a glyph in Swift; after it, every later type in the project is written in terms of one.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 | The four attributes, their registers, their four values each **in rank order 1 → 4**, the canonical `fill → shape → pips → hue` ordering, and `glyphID = fill*64 + shape*16 + pips*4 + hue`. Read the whole section including the *Locked terminology* table — the `enum` block at its end is the case list, verbatim. |
| `GAME_DESIGN.md` | §5.7 | The locked constants row `Attributes / values each / deck size = 4 / 4 / 256`. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 (tree), §3 row 1, §4 | The file path; the ruling that `Fill`/`Shape`/`Pips`/`Hue` are **nested** and why; that every public value type in `HunchCore` writes `: Sendable` explicitly. |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N22, N29, N33, N4, N1, N47 | Nest state types in their owner; enum cases are stutter-free `lowerCamelCase`; no `SCREAMING_SNAKE`; name for role not type; the call site must read aloud; `- Complexity:` on any non-O(1) computed property. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W1, W13, W18, W19, W51, W52 | `struct` by default; stored properties and designated inits in the primary declaration; `let` everywhere; `switch` **expressions**; `///` doc comments that say *why*, never what the signature already says. |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24, P28 | One top-level type per file, named for it; banned filenames. |

Do not copy any value out of §2 into a comment. Cite `§2` and let the reader open it.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/GlyphsTests/GlyphTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import HunchTestSupport   // the eight @Tag declarations from E01·T04

@Suite("Glyph", .tags(.unit, .presubmission))
struct GlyphTests {

    // MARK: - §2's case lists, verbatim and in rank order

    @Test("Each attribute has exactly four values in §2's rank 1…4 order")
    func valueEnumsAreRankOrdered() {
        #expect(Glyph.Fill.allCases == [.hollow, .dotted, .striped, .solid])
        #expect(Glyph.Shape.allCases == [.circle, .triangle, .square, .hexagon])
        #expect(Glyph.Pips.allCases == [.one, .two, .three, .four])
        #expect(Glyph.Hue.allCases == [.amber, .teal, .frost, .rose])
    }

    @Test("Raw values are the 0-based storage ordinals and rank is ordinal + 1")
    func ordinalsAndRanks() {
        #expect(Glyph.Fill.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(Glyph.Shape.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(Glyph.Pips.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(Glyph.Hue.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(Glyph.Fill.allCases.map(\.rank) == [1, 2, 3, 4])
        #expect(Glyph.Shape.allCases.map(\.rank) == [1, 2, 3, 4])
        #expect(Glyph.Pips.allCases.map(\.rank) == [1, 2, 3, 4])
        #expect(Glyph.Hue.allCases.map(\.rank) == [1, 2, 3, 4])
    }

    @Test("Attribute is the canonical fill → shape → pips → hue order")
    func attributeIsCanonical() {
        #expect(Glyph.Attribute.allCases == [.fill, .shape, .pips, .hue])
        #expect(Glyph.Attribute.allCases.map(\.rawValue) == [0, 1, 2, 3])
    }

    // MARK: - the positional id

    @Test("id is §2's fill*64 + shape*16 + pips*4 + hue")
    func idIsPositional() {
        #expect(Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .amber).id == 0)
        #expect(Glyph(fill: .solid, shape: .hexagon, pips: .four, hue: .rose).id == 255)
        // striped(2) triangle(1) four(3) teal(1) = 2*64 + 1*16 + 3*4 + 1
        #expect(Glyph(fill: .striped, shape: .triangle, pips: .four, hue: .teal).id == 157)
    }

    @Test("Each attribute contributes exactly its own place value to id")
    func idPlaceValues() {
        let base = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .amber)
        #expect(Glyph(fill: .dotted, shape: .circle, pips: .one, hue: .amber).id == base.id + 64)
        #expect(Glyph(fill: .hollow, shape: .triangle, pips: .one, hue: .amber).id == base.id + 16)
        #expect(Glyph(fill: .hollow, shape: .circle, pips: .two, hue: .amber).id == base.id + 4)
        #expect(Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .teal).id == base.id + 1)
    }

    // MARK: - the generic accessor every mask and every law is built on

    @Test("ordinal(of:) reads back exactly the register the id packs")
    func ordinalReadsEachRegister() {
        let glyph = Glyph(fill: .striped, shape: .triangle, pips: .four, hue: .teal)
        #expect(glyph.ordinal(of: .fill) == 2)
        #expect(glyph.ordinal(of: .shape) == 1)
        #expect(glyph.ordinal(of: .pips) == 3)
        #expect(glyph.ordinal(of: .hue) == 1)
    }

    @Test("The four ordinals reconstruct the id — the accessor and the packing cannot drift apart")
    func ordinalsReconstructTheID() {
        let glyph = Glyph(fill: .dotted, shape: .hexagon, pips: .two, hue: .rose)
        let packed = Glyph.Attribute.allCases.reduce(0) { $0 * 4 + glyph.ordinal(of: $1) }
        #expect(packed == glyph.id)
    }

    // MARK: - value semantics

    @Test("Two glyphs with the same four values are equal and hash equally")
    func valueSemantics() {
        let a = Glyph(fill: .dotted, shape: .square, pips: .three, hue: .frost)
        let b = Glyph(fill: .dotted, shape: .square, pips: .three, hue: .frost)
        let c = Glyph(fill: .dotted, shape: .square, pips: .three, hue: .rose)
        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("A glyph survives a JSON round trip")
    func codableRoundTrip() throws {
        let glyph = Glyph(fill: .striped, shape: .hexagon, pips: .two, hue: .frost)
        let data = try JSONEncoder().encode(glyph)
        let decoded = try JSONDecoder().decode(Glyph.self, from: data)
        #expect(decoded == glyph)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter GlyphTests`

The first run must fail with `cannot find 'Glyph' in scope` / `no such module 'Glyphs'`. That is the right reason. If it fails because `HunchTestSupport` has no `presubmission` tag, E01·T04 is incomplete — fix it there, not here, and do not invent a local `@Tag`.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Glyphs/Glyph.swift` |
| create | `HunchCore/Tests/GlyphsTests/GlyphTests.swift` |
| modify | `DECISIONS.md` — two entries (see Implementation notes) |

`HunchCore/Package.swift` is **not** modified: E01·T03 already declares the `Glyphs` target and the `GlyphsTests` test target. If either is missing, that is an E01 defect — go fix E01·T03 on this branch, in its own commit, before continuing.

## Implementation notes

### The shape of the file

```swift
/// One reading of the four independent attributes — the atom of the whole game.
///
/// The deck is exactly 256 of these and never grows (`GAME_DESIGN.md` §2, §5.7). Every
/// attribute occupies a spatially disjoint register of the drawing, which is why the four
/// value types are independent and why `HunchUI` can render each channel with the others
/// removed.
public struct Glyph: Hashable, Sendable, Codable {

    public enum Fill: UInt8, CaseIterable, Sendable, Codable {
        case hollow, dotted, striped, solid
        /// The visible rank, 1…4 — the number the ramp teaches and VoiceOver reads.
        public var rank: Int { Int(rawValue) + 1 }
    }

    public enum Shape: UInt8, CaseIterable, Sendable, Codable {
        case circle, triangle, square, hexagon
        public var rank: Int { Int(rawValue) + 1 }
    }

    public enum Pips: UInt8, CaseIterable, Sendable, Codable {
        case one, two, three, four
        public var rank: Int { Int(rawValue) + 1 }
    }

    public enum Hue: UInt8, CaseIterable, Sendable, Codable {
        case amber, teal, frost, rose
        public var rank: Int { Int(rawValue) + 1 }
    }

    /// The four attributes in the canonical `fill → shape → pips → hue` order (§2), which is
    /// the order of everything: VoiceOver labels, the deck sort, ramp rows on the Dial and the
    /// Bench, Codex page layout, AST commutative-operand sorting and serialisation.
    public enum Attribute: UInt8, CaseIterable, Sendable, Codable {
        case fill, shape, pips, hue
    }

    public let fill: Fill
    public let shape: Shape
    public let pips: Pips
    public let hue: Hue

    public init(fill: Fill, shape: Shape, pips: Pips, hue: Hue) {
        self.fill = fill
        self.shape = shape
        self.pips = pips
        self.hue = hue
    }

    /// §2's `glyphID`, `0…255` and stable forever: `fill*64 + shape*16 + pips*4 + hue`.
    ///
    /// It is the index into `Deck.all` and the bit position in `Bitboard256`, so it is on disk
    /// in every snapshot and every Codex page. Changing the packing invalidates saved games.
    public var id: Int {
        Int(fill.rawValue) << 6 | Int(shape.rawValue) << 4 | Int(pips.rawValue) << 2 | Int(hue.rawValue)
    }

    /// The 0-based ordinal of `attribute` on this glyph; the visible rank is `ordinal + 1`.
    ///
    /// This is the accessor every mask, every relational comparison and every aggregate count
    /// goes through, so it is deliberately the *only* generic way to read an attribute.
    public func ordinal(of attribute: Attribute) -> Int {
        switch attribute {
        case .fill: Int(fill.rawValue)
        case .shape: Int(shape.rawValue)
        case .pips: Int(pips.rawValue)
        case .hue: Int(hue.rawValue)
        }
    }
}
```

### Six decisions already made — do not re-open them in review

1. **Nesting is not a style preference; it is the fix for a compile error.** `HunchUI` imports both SwiftUI and `HunchCore`. A top-level `Shape` then produces `error: 'Shape' is ambiguous for type lookup in this context` at *every* use site in the renderer — reproduced on Swift 6.3.3 and recorded in `08 §3` row 1 and in `hunch-swift-code` §2. `N22` fixes it at the declaration and costs nothing: `Glyph.Shape.triangle`, or `.triangle` inferred. `HunchCore::Shape` (`N23`, SE-0491) stays in reserve and should never be needed.
2. **`Attribute` nests too, though §2 lists it flat.** Same argument one step weaker — `Attribute` is a maximally generic top-level name in a project that also has `AttributedString` banned by a hygiene grep, and the attribute *is* an axis of the glyph, which is exactly `N22`'s case. This is an extension of §2's spelling, so **record it in `DECISIONS.md`**.
3. **`id`, not `glyphID`.** `glyph.glyphID` stutters at every use site (`N1`, `N4`); `Deck.glyph(id:)` in `08 §3` already uses the bare label. Document in the doc comment that it *is* §2's `glyphID` so grep from the design still lands. **Record in `DECISIONS.md`.**
4. **Raw values are 0-based ordinals; `rank` is 1-based.** §2 numbers the values 1…4 for the player, and `glyphID` packs them 0…3. Storing the ordinal makes `id` a shift-and-or with no arithmetic correction, and `rank == ordinal + 1` is strictly increasing — so every one of the six comparators gives the identical answer on ordinals as on ranks, and cross-attribute comparison may use either. Comparisons in `MaskTable` (T05) use ranks because the BNF says `RANK`; the bit positions use ordinals because that is what a bitmask indexes.
5. **`UInt8` raw values, not `Int`.** Everything in the persisted layer — `BenchLayout`, `RuleTile`, `StoreFile.round(Mode)`, the snapshot's glyph list — is `UInt8`-backed by §6.10 and `08 §3`, and a `UInt8` raw type is what gives the enums free `Codable` at one byte.
6. **No `Comparable` on the value enums.** Two reasons. `rank` already is the order and is the spelling the design uses. And a raw type *suppresses* SE-0266's synthesized `Comparable` — `enum Fill: UInt8, Comparable` fails with *"enum declares raw type 'UInt8', preventing synthesized conformance"* (verified on Swift 6.3.3; it is `hunch-swift-code`'s first gotcha, written there about `Band`). Four hand-written `<` operators to restate what `rank` says is `W28`'s smell.

### Two things /simplify will suggest, and the answers

- **"Extract a `GlyphValue` protocol so `rank` is written once."** No. It adds a public protocol to the module's surface to save three lines, and the moment it exists somebody will add `CaseIterable` and `Comparable` refinements to it and the four enums stop being four independent four-case enums. Four one-line computed properties are the cheaper total.
- **"Make `id` a stored property."** No. It is two shifts and two ors on values already in registers — cheaper than the eight bytes and the second source of truth. `N47` only asks for a `- Complexity:` note when access is *not* O(1); this is O(1).

### Conformance placement

`Hashable`, `Sendable` and `Codable` are all synthesized, so they go on the primary declaration and there are no extensions to split — `W12` (one conformance per extension) has nothing to bite on. Do **not** add `Identifiable`: `ForEach` over glyphs is E04's problem and E04 can add it in one line if it needs it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GlyphTests` is green, with all eight tests present and none skipped.
- [ ] `HunchCore/Sources/Glyphs/Glyph.swift` declares exactly one top-level type (`P24`), and `grep -c "^public struct\|^public enum" HunchCore/Sources/Glyphs/Glyph.swift` returns `1`.
- [ ] `grep -n "import" HunchCore/Sources/Glyphs/Glyph.swift` returns nothing — the file needs neither `Foundation` nor anything else.
- [ ] `grep -rn "^public enum Shape\|^public enum Fill\|^public enum Pips\|^public enum Hue\|^public enum Attribute" HunchCore/Sources/` returns nothing: all five are nested.
- [ ] `Scripts/check-source-hygiene.sh` exits 0.
- [ ] `DECISIONS.md` contains an entry for the nested `Attribute` and for `Glyph.id` as the Swift spelling of §2's `glyphID`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. The two answers above are pre-written; if it proposes either, decline and say why in the commit body.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E02/T01: Glyph with nested Fill/Shape/Pips/Hue/Attribute and the positional id"`

## Out of scope

- `Deck.all` and `Deck.glyph(id:)` — **T02**. This task must not add a way to enumerate the 256; the temptation is a `static let all` on `Glyph`, and it belongs on `Deck` (`08 §3`, `W16`).
- `Bitboard256` and anything that indexes by `id` — **T03**.
- `Verdict`, `Mode`, `Coupler`, `Comparator` — **T06**, even though §2's enum block lists them beside these four.
- Any colour, silhouette, stroke, pip geometry or index-stroke angle for a `Hue`/`Shape`/`Pips`/`Fill` value — **E03** (tokens) and **E04** (renderer). A hex literal in this file would trip E01's token grep.
- The VoiceOver format string that reads a glyph aloud — **E19**; it is a String Catalog key, and §12.9 caps the catalog at 250.
