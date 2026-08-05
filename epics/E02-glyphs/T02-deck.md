# T02 — Deck

| | |
|---|---|
| **Epic** | E02 — Glyph vocabulary and the bitboard algebra |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | §14.1 CORE SYSTEMS → **Glyph model** (the deck half: all 256, canonical order, `glyphID` round trip) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | `Deck` is `W16`'s caseless-enum namespace and `Deck.all` is the first of exactly two `static let` shared values in the whole core (the other is `MaskTable.resident`). The skill's "Never" list is explicit that this is *not* the singleton the brief bans, and its gotchas cover the `- Complexity: O(1)` doc `08 §3` demands on the subscript. |
| `hunch-swift-testing` | This task owns a gate row — "`Deck.all` is 256 with `glyphID` round-tripping for every one" — so it must be a parameterised suite whose failure names the offending glyph, and it must update `tests.json`. The skill also owns the `06 T49` exit-test rule that covers the `precondition` in `glyph(id:)`, which only works because `HunchCore` is host-testable. |

## Objective

`Deck` exists as a caseless enum vending the 256 glyphs in the canonical `fill → shape → pips → hue` order, index-aligned with `Glyph.id`, plus an O(1) inverse `glyph(id:)`. After this task the deck can be enumerated and addressed by id, which is what every bitboard, every mask and every brute-force test in the rest of the project walks.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 | *"Four attributes × four values = 256 glyphs. That deck never grows."* · the canonical ordering sentence — deck sort order is one of the seven places it applies · `glyphID = fill*64 + shape*16 + pips*4 + hue`, *"0…255, stable forever"*. |
| `GAME_DESIGN.md` | §5.7 | Locked constant: deck size **256**. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §3 row 2, §4 | `Glyphs/Deck.swift`; `enum Deck` caseless with `Deck.all: [Glyph]` and `Deck.glyph(id:)`; `W16`; `- Complexity: O(1)` on the subscript (`N47`); `Deck.all` is a `static let` of immutable `Sendable` values and is *not* a banned singleton. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W16, W39, W52 | Constants in a caseless enum; `precondition` for the caller's contract; document the contract, not the signature. |
| `ios-swift-guide/06-TESTING.md` | T5b, T23, T49, T13 | Path-mirrored test file, one suite per file; `Codable` argument types so one failing case re-runs alone; exit tests are the only way to cover a `precondition` body and they run on macOS; hoist `try` out of `#expect`. |
| `ios-swift-guide/05-CONCURRENCY.md` | R21, R50 | Explicit `: Sendable`; `static let` is rung 1 of the global-state ladder. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/GlyphsTests/DeckTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import HunchTestSupport

@Suite("Deck", .tags(.unit, .presubmission))
struct DeckTests {

    @Test("The deck is exactly 256 glyphs")
    func deckIsTwoFiftySix() {
        #expect(Deck.all.count == 256)
    }

    @Test("Every glyph in the deck is distinct")
    func deckHasNoDuplicates() {
        #expect(Set(Deck.all).count == Deck.all.count)
        #expect(Set(Deck.all.map(\.id)).count == Deck.all.count)
    }

    // The gate row: glyphID round-trips for every one of the 256.
    @Test("glyphID round-trips", arguments: Deck.all)
    func idRoundTrips(_ glyph: Glyph) {
        #expect(Deck.glyph(id: glyph.id) == glyph)
        #expect((0..<256).contains(glyph.id))
    }

    @Test("all is index-aligned with glyphID, so glyph(id:) is a subscript and not a search")
    func allIsIndexAligned() {
        #expect(Deck.all.indices.allSatisfy { Deck.all[$0].id == $0 })
    }

    @Test("The deck is in canonical fill → shape → pips → hue order")
    func deckIsCanonicallyOrdered() {
        let keys = Deck.all.map { glyph in
            Glyph.Attribute.allCases.map { glyph.ordinal(of: $0) }
        }
        #expect(keys == keys.sorted { $0.lexicographicallyPrecedes($1) })
        #expect(keys.first == [0, 0, 0, 0])
        #expect(keys.last == [3, 3, 3, 3])
    }

    @Test("Every combination of the four attributes appears exactly once")
    func deckIsTheFullCartesianProduct() {
        // [Int] is Hashable, so the set counts distinct four-tuples directly.
        let combinations = Deck.all.map { [$0.fill.rank, $0.shape.rank, $0.pips.rank, $0.hue.rank] }
        #expect(Set(combinations).count == 256)
    }

    @Test("The whole deck survives a JSON round trip")
    func deckIsCodable() throws {
        let data = try JSONEncoder().encode(Deck.all)
        let decoded = try JSONDecoder().decode([Glyph].self, from: data)
        #expect(decoded == Deck.all)
    }

    // 06 T49 — the only way to cover a precondition body, and it runs because HunchCore is
    // host-testable on macOS. If the toolchain rejects `processExitsWith:`, it is `exitsWith:`
    // before Swift 6.2 — check `swift --version` rather than deleting the test.
    @Test("An out-of-range glyphID trips the precondition instead of trapping on the array")
    func outOfRangeIDIsAPreconditionFailure() async {
        await #expect(processExitsWith: .failure) { _ = Deck.glyph(id: 256) }
        await #expect(processExitsWith: .failure) { _ = Deck.glyph(id: -1) }
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter DeckTests`

It must fail with `cannot find 'Deck' in scope`. If instead the *parameterised* test fails to compile with a `Sendable`/`CustomTestArgumentEncodable` complaint, `Glyph` lost a conformance in T01 — fix T01, not this file (`06 T23`).

**Step 3 — implement.** **Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Glyphs/Deck.swift` |
| create | `HunchCore/Tests/GlyphsTests/DeckTests.swift` |
| modify | `tests.json` — add the deck round-trip invariant |

## Implementation notes

```swift
/// The deck: all 256 glyphs, in the canonical `fill → shape → pips → hue` order of §2.
///
/// A caseless enum, so there is nothing to instantiate (`W16`). `all` is a `static let` of
/// immutable `Sendable` values — rung 1 of `05 R50` — and is deliberately not injectable:
/// there is no second deck, and the brief's singleton ban is about substitutable mutable
/// state, of which this has none.
public enum Deck {

    /// Every glyph, ordered so that `all[i].id == i`.
    public static let all: [Glyph] = Glyph.Fill.allCases.flatMap { fill in
        Glyph.Shape.allCases.flatMap { shape in
            Glyph.Pips.allCases.flatMap { pips in
                Glyph.Hue.allCases.map { hue in
                    Glyph(fill: fill, shape: shape, pips: pips, hue: hue)
                }
            }
        }
    }

    /// The glyph with `id`.
    ///
    /// - Complexity: O(1). `all` is built in `glyphID` order, so this is an array subscript
    ///   and never a search — which is what lets the evaluator, the Assay and every
    ///   brute-force test address the deck by bit position.
    /// - Precondition: `id` is in `0..<256`.
    public static func glyph(id: Int) -> Glyph {
        precondition(all.indices.contains(id), "glyphID \(id) is outside 0…255")
        return all[id]
    }
}
```

### Why the nested `flatMap` and not a `for` loop over `0..<256`

Two equivalent orderings exist and only one of them *proves* anything. Building from the four `allCases` in canonical order makes the canonical order structural: `deckIsCanonicallyOrdered` then checks a property of the construction rather than of a hand-written loop bound. Building from `0..<256` by decoding the id would instead make `all` a function of `id` and the round-trip test tautological. Keep the construction and the id independent — that independence is the entire content of `allIsIndexAligned`.

### Deliberate omissions

- **No `Deck.size`.** `Deck.all.count` is the one spelling; a `static let size = 256` is a second source of truth for §5.7's locked constant and the first thing that goes stale. `Bitboard256` gets its 256 from `4 × 64`, structurally.
- **No `Deck.index(of:)`** — that is `Glyph.id`, already O(1).
- **No `Deck.shuffled(using:)`.** ECHO's tray is in canonical `glyphID` order (§8.3) and SIEVE's stream composition is a generator concern (E14). Randomness in `HunchCore` is always `using rng: inout some RandomNumberGenerator` threaded from a caller, never a convenience on the deck.
- **`all` is `[Glyph]`, not a lazy sequence.** 256 × 4 bytes is nothing, it is built once by `swift_once`, and `Bitboard256`'s brute-force builders index it directly.

### Cost

`all` is lazily initialised on first touch (Swift globals are `swift_once`-guarded, which is also why it is concurrency-safe under `06 T10`'s parallel-in-one-process test model). Building it is 256 struct initialisations; if it ever appears in a profile, the problem is the caller, not the deck.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DeckTests` is green, showing **256** parameterised cases for `idRoundTrips` plus the seven scalar tests.
- [ ] `grep -n "Complexity" HunchCore/Sources/Glyphs/Deck.swift` shows the `O(1)` note on `glyph(id:)` (`N47`, `08 §3`).
- [ ] `grep -rn "static var" HunchCore/Sources/Glyphs/` returns nothing.
- [ ] The exit test runs (it appears in the output, not as a skip) — confirming `HunchCore` tests execute on the host and `06 T49` is available to the project.
- [ ] `tests.json` has an entry named for the deck round-trip invariant with status `pass`.
- [ ] `Scripts/check-source-hygiene.sh` exits 0.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. If it proposes collapsing `all` into `(0..<256).map(decode)`, decline: see *Why the nested `flatMap`* above.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E02/T02: Deck.all in canonical order with an O(1) glyph(id:) and the 256-way id round trip"`

## Out of scope

- Any bitboard, mask or table — **T03**, **T04**, **T05**.
- The spool sheet's 7 × 10 grid, the Dial's ramps, or any other *display* of the deck — **E08**.
- ECHO's tray ordering, which is canonical `glyphID` order and therefore reads `Deck.all` but is scheduled in **E13**.
- The seed glyph (`0x48554E4348` → glyph 22 in the fixed opening round) — **E10·T05**; it is drawn from a round seed, and this task ships no randomness.
