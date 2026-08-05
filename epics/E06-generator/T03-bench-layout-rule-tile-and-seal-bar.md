# T03 — `BenchLayout`, `RuleTile` and `SealBar`

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T01 |
| **Delivers** | §14.1 The Bench · The Seal + machined bar |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | `08 §2` rules `BenchLayout` **core** even though it renders as tiles: G10 is a generation-time guardrail, so putting it in `Modules/` would invert the dependency arrow and make G10 simulator-only. This skill also owns the `Ramp` payload / `RampView` widget collision (`N39`), the `SealBar`-not-`isSealBarred` ruling (`N10` deviation, `W28`), and the ban on `default:` in a switch over an enum you own (`W29`). |
| `hunch-bench-instruments` | The data model must be able to express every state the instruments draw and nothing they cannot: the Bridge's ghost toggle is on the **trailing** socket only, a ramp has **one** inert state rather than two, the Fork's then and else docks are two independent full ramps on one attribute, and the Tally's counted set has a minimum of three. Getting any of those wrong in the payload makes a whole class of E09 drawings unrepresentable or, worse, representable twice. |

## Objective

The Bench exists as pure data: a `Codable` draft of at most two rails, the four tile classes with
their payloads, the coupler, and `SealBar` as the reason a Seal refuses. Both directions of the
conversion to `LawNode` exist and are value-preserving, which is what makes G10 checkable at
generation time in T04.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.2 | The four tile classes and their parts, the coupler's three states, the gesture inventory, and the leading-socket-is-always-`cur` rule |
| `GAME_DESIGN.md` | §4.3 | The one inert ramp state, and the three conditions that bar the Seal |
| `GAME_DESIGN.md` | §4.4 | The parity table — what each production is constructible as — and the admitted over-reach |
| `GAME_DESIGN.md` | §3.2 | The BNF each payload must be able to spell exactly |
| `GAME_DESIGN.md` | §3.4 | RNF rule 3 (`cur` leading, `prev` trailing) and the structural caps |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §3 | File paths, the two things that look app-layer and are core, the `RuleTile`/`SealBar`/`BenchLayout` naming rows |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24, P25 | One top-level type per file; the three sanctioned exceptions |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | No `default:` over an enum you own |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/BenchTests/BenchLayoutTests.swift` and
`HunchCore/Tests/BenchTests/SealBarTests.swift`.

`BenchLayoutTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import Bench
import HunchTestSupport

@Suite("BenchLayout", .tags(.unit, .presubmission))
struct BenchLayoutTests {

    // MARK: the storage contract

    /// §6.10 stores the Bench draft inside the mid-round snapshot, so the draft has to be small
    /// and boring on disk. Every scalar is a UInt8; a layout encodes to a handful of bytes.
    @Test("A layout round-trips through JSON unchanged")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for layout in Corpora.sampleLayouts {                 // one of every tile class and coupler
            let data = try encoder.encode(layout)
            #expect(try JSONDecoder().decode(BenchLayout.self, from: data) == layout)
        }
    }

    @Test("Every stored scalar is UInt8-backed")
    func rawValuesAreBytes() {
        #expect(RuleTile.Kind.self is any RawRepresentable.Type)
        #expect(MemoryLayout<Coupler.RawValue>.size == 1)
        #expect(MemoryLayout<Comparator.RawValue>.size == 1)
        #expect(MemoryLayout<Glyph.Attribute.RawValue>.size == 1)
        #expect(MemoryLayout<Subset4.RawValue>.size == 1)
    }

    @Test("An out-of-range raw value decodes to a typed error, never a crash")
    func malformedLayoutThrows() throws {
        let data = Data(#"{"rails":[{"ramp":{"attribute":99,"lit":3}}]}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(BenchLayout.self, from: data)
        }
    }

    // MARK: the forward conversion, one production at a time

    @Test("An atom becomes one Ramp on its attribute with its subset lit")
    func atomBecomesARamp() throws {
        let node = LawNode.atom(attribute: .shape, subset: Subset4(ranks: [2, 4]))
        let layout = BenchLayout(node)
        #expect(layout.rails.count == 1)
        #expect(layout.coupler == nil)
        guard case .ramp(let ramp) = layout.rails[0] else { Issue.record("not a ramp"); return }
        #expect(ramp.attribute == .shape)
        #expect(ramp.lit == Subset4(ranks: [2, 4]))
    }

    @Test("A relational term becomes one Bridge with both sockets on cur")
    func relationalBecomesABridge() throws {
        let node = LawNode.relational(leading: .shape, comparator: .lt, trailing: .pips)
        guard case .bridge(let bridge) = BenchLayout(node).rails[0] else {
            Issue.record("not a bridge"); return
        }
        #expect(bridge.leadingAttribute == .shape)
        #expect(bridge.trailingAttribute == .pips)
        #expect(bridge.comparator == .lt)
        #expect(bridge.trailingIsPrevious == false)
    }

    /// RNF rule 3 made physical: the leading socket is always `cur`, so the ghost lives on the
    /// trailing socket and nowhere else. A payload that could ghost the leading socket would make
    /// the transposed family expressible and render a law the grammar forbids (§4.2).
    @Test("A contextual term ghosts the trailing socket, and only the trailing socket")
    func contextualGhostsTheTrailingSocket() throws {
        let node = LawNode.contextual(leading: .pips, comparator: .gt, trailing: .pips)
        guard case .bridge(let bridge) = BenchLayout(node).rails[0] else {
            Issue.record("not a bridge"); return
        }
        #expect(bridge.trailingIsPrevious == true)
        // there is no `leadingIsPrevious` to assert: it does not exist on the payload.
    }

    @Test("A guard becomes one Fork occupying the whole Bench, with no coupler")
    func guardBecomesAFork() throws {
        let node = LawNode.guarded(gate: .hue, value: 1,
                                   branch: .pips,
                                   then: Subset4(ranks: [3, 4]), else: Subset4(ranks: [1]))
        let layout = BenchLayout(node)
        #expect(layout.rails.count == 1)
        #expect(layout.coupler == nil)
        guard case .fork(let fork) = layout.rails[0] else { Issue.record("not a fork"); return }
        #expect(fork.gateAttribute == .hue)
        #expect(fork.branchAttribute == .pips)
        #expect(fork.thenLit != fork.elseLit)      // §3.2: branches differ
    }

    @Test("An aggregate becomes one Tally, in count mode or parity mode")
    func aggregateBecomesATally() throws {
        guard case .tally(let count) = BenchLayout(Corpora.handWritten(.systemicCount)!).rails[0],
              case .count(let rankSubset, let countSet) = count.mode else {
            Issue.record("not a count tally"); return
        }
        #expect(count.countedAttributes.count >= 3)
        #expect(rankSubset.rawValue != 0)
        #expect(countSet.rawValue != 0)

        guard case .tally(let parity) = BenchLayout(Band.systemic.exemplar).rails[0],
              case .parity(let bit) = parity.mode else {
            Issue.record("not a parity tally"); return
        }
        #expect(bit == 0 || bit == 1)
    }

    @Test("A coupled law becomes two rails and one coupler")
    func couplerBecomesTheJunction() throws {
        let layout = BenchLayout(Band.pair.exemplar)
        #expect(layout.rails.count == 2)
        #expect(layout.coupler == .and)
    }

    @Test("A whole-Bench tile never carries a coupler")
    func forkAndTallyHaveNoCoupler() {
        #expect(BenchLayout(Band.guarded.exemplar).coupler == nil)
        #expect(BenchLayout(Band.systemic.exemplar).coupler == nil)
    }

    // MARK: the backward conversion

    @Test("Parsing a layout the generator produced returns the same node", arguments: Band.allCases)
    func parseIsTheInverseOnCanonicalLaws(_ band: Band) throws {
        let node = band.exemplar
        #expect(LawNode(BenchLayout(node)) == node)
    }

    @Test("A structurally incomplete layout does not parse")
    func incompleteLayoutsReturnNil() {
        #expect(LawNode(BenchLayout(rails: [], coupler: nil)) == nil)
        #expect(LawNode(BenchLayout(rails: [.bridge(.unboundLeading)], coupler: nil)) == nil)
        #expect(LawNode(BenchLayout(rails: [.ramp(.init(attribute: .fill, lit: .empty))],
                                    coupler: nil)) == nil)
    }

    @Test("Two rails with no coupler, and one rail with a coupler, are both unrepresentable")
    func railCountAndCouplerAgree() {
        #expect(BenchLayout(rails: [.ramp(.litFill), .ramp(.litShape)], coupler: nil).isWellFormed == false)
        #expect(BenchLayout(rails: [.ramp(.litFill)], coupler: .or).isWellFormed == false)
    }
}
```

`SealBarTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import Bench
import HunchTestSupport

@Suite("SealBar", .tags(.unit, .presubmission))
struct SealBarTests {

    @Test("A complete, non-constant draft is not barred", arguments: Band.allCases)
    func exemplarsAreNeverBarred(_ band: Band) {
        #expect(BenchLayout(band.exemplar).sealBar == nil)
    }

    /// §4.3: "one inert state, not two". Both 0 lit and 4 lit bar the Seal, and both report the
    /// same case carrying the same rail index — the drawing does not distinguish them either.
    @Test("An empty ramp and a full ramp are the same inert state")
    func zeroAndFourLitAreOneState() {
        let empty = BenchLayout(rails: [.ramp(.init(attribute: .fill, lit: .empty)),
                                        .ramp(.litShape)], coupler: .and)
        let full  = BenchLayout(rails: [.ramp(.init(attribute: .fill, lit: .full)),
                                        .ramp(.litShape)], coupler: .and)
        #expect(empty.sealBar == .inertRail(0))
        #expect(full.sealBar == .inertRail(0))
    }

    @Test("The bar names the rail that pulses, and it is the leading offender")
    func barNamesTheOffendingRail() {
        let layout = BenchLayout(rails: [.ramp(.litFill),
                                         .ramp(.init(attribute: .shape, lit: .full))],
                                 coupler: .xor)
        #expect(layout.sealBar == .inertRail(1))
    }

    @Test("An unbound socket bars the Seal and names its rail")
    func unboundSocketBars() {
        let layout = BenchLayout(rails: [.bridge(.unboundTrailing), .ramp(.litShape)], coupler: .and)
        #expect(layout.sealBar == .unboundSocket(0))
    }

    /// The third condition, and the reason `sealBar` needs the evaluator: a bridge whose two
    /// sockets name the same attribute with no ghost is *always* constant, for every comparator.
    @Test("A constant draft bars the Seal", arguments: Comparator.allCases)
    func constantExtensionBars(_ comparator: Comparator) {
        let layout = BenchLayout(rails: [.bridge(.init(leadingAttribute: .pips,
                                                       comparator: comparator,
                                                       trailingAttribute: .pips,
                                                       trailingIsPrevious: false))],
                                 coupler: nil)
        #expect(layout.sealBar == .constantExtension)
    }

    @Test("XOR of a rail with itself is constant and therefore barred")
    func selfXorIsBarred() {
        let layout = BenchLayout(rails: [.ramp(.litFill), .ramp(.litFill)], coupler: .xor)
        #expect(layout.sealBar == .constantExtension)
    }

    @Test("The three conditions are checked in §4.3's order")
    func barOrderIsInertThenUnboundThenConstant() {
        // a draft that is both inert on rail 0 and constant overall reports the inert rail,
        // because that is the rail the Seal pulses.
        let layout = BenchLayout(rails: [.ramp(.init(attribute: .fill, lit: .full)),
                                         .ramp(.init(attribute: .fill, lit: .full))],
                                 coupler: .and)
        #expect(layout.sealBar == .inertRail(0))
    }

    @Test("A Tally counting fewer than three attributes is inert")
    func tallyBelowThreeIsInert() {
        #expect(BenchLayout(rails: [.tally(.countingTwo)], coupler: nil).sealBar == .inertRail(0))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter BenchTests`
Every failure must be a missing symbol in the `Bench` target. If `Corpora.sampleLayouts` compiles
before `BenchLayout` exists, something is wrong with the test.

**Step 3 — implement.** Files below.

**Step 4 — green, then refactor** — especially the three `sealBar` clauses, which want to be three
small functions with the ordering stated once.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Bench/BenchLayout.swift` — the type, `init(_ law: LawNode)`, and `extension LawNode { init?(_ layout: BenchLayout) }` |
| create | `HunchCore/Sources/Bench/RuleTile.swift` — `enum RuleTile` with its four nested payload structs |
| create | `HunchCore/Sources/Bench/SealBar.swift` — `enum SealBar` and `extension BenchLayout { var sealBar: SealBar? }` |
| modify | `HunchCore/Sources/Glyphs/Glyph.swift` — give `Glyph.Attribute` a `UInt8` raw value if E02·T01 did not |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `sampleLayouts` and the named layout fixtures the tests use |
| create | `HunchCore/Tests/BenchTests/BenchLayoutTests.swift` |
| create | `HunchCore/Tests/BenchTests/SealBarTests.swift` |
| modify | `DECISIONS.md` — the two-relational over-reach ruling |
| modify | `tests.json` — one entry for The Bench, one for The Seal + machined bar |

Both conversion directions live in `BenchLayout.swift`. `P24` asks for one top-level *type* per
file; `extension LawNode { init?(_:) }` introduces none, and keeping the two directions adjacent is
what makes G10 reviewable in one screen — the whole point of `08 §3`'s `N14` ruling that a
value-preserving conversion drops its argument label.

## Implementation notes

### The types

```swift
/// A Bench draft. Small, boring and `Codable`, because §6.10 writes it inside the mid-round
/// snapshot on `scenePhase → .inactive`.
public struct BenchLayout: Hashable, Codable, Sendable {
    public var rails: [RuleTile]        // 0…2. A Fork or a Tally occupies the whole Bench (§4.2).
    public var coupler: Coupler?        // non-nil iff rails.count == 2
}

public enum RuleTile: Hashable, Codable, Sendable {
    case ramp(Ramp), bridge(Bridge), fork(Fork), tally(Tally)

    public struct Ramp: Hashable, Codable, Sendable {
        public var attribute: Glyph.Attribute
        public var lit: Subset4                       // 0…15; 0 and 15 are the one inert state
    }

    public struct Bridge: Hashable, Codable, Sendable {
        public var leadingAttribute: Glyph.Attribute?   // nil = unbound socket
        public var comparator: Comparator
        public var trailingAttribute: Glyph.Attribute?  // nil = unbound socket
        public var trailingIsPrevious: Bool             // the ghost toggle. Trailing only (§4.2).
    }

    public struct Fork: Hashable, Codable, Sendable {
        public var gateAttribute: Glyph.Attribute?
        public var gateValue: UInt8?                    // exactly one lit cell in the gate dock
        public var branchAttribute: Glyph.Attribute?
        public var thenLit: Subset4                     // the lit dock
        public var elseLit: Subset4                     // the dim dock, same attribute (§4.2)
    }

    public struct Tally: Hashable, Codable, Sendable {
        public var countedAttributes: AttributeSet      // minimum three (§3.2)
        public var mode: Mode
        public enum Mode: Hashable, Codable, Sendable {
            case count(rankSubset: Subset4, countSet: CountSet)
            case parity(bit: UInt8)
        }
    }
}

/// Why the Seal refuses. A `Bool` cannot answer "which rail pulses?", so §4.3's behaviour would
/// need a second parallel field — `W28` exactly (`08 §3`).
public enum SealBar: Hashable, Sendable {
    case inertRail(Int)
    case unboundSocket(Int)
    case constantExtension
}
```

Four notes on the payloads, each of which is a bug avoided:

1. **`trailingIsPrevious` and no leading counterpart.** The absence is the design. `hunch-bench-instruments`'
   `bridge.md` §2 spells out that a ghost toggle on the leading socket would make the transposed
   family the only expressible one.
2. **`Ramp.lit` is a `Subset4`, not a `Bool` quartet.** The fourteen usable states plus the two
   inert ones are exactly a 4-bit mask, and `Subset4` already carries `isScattered` from T01.
3. **The Fork's two docks are two independent `Subset4`s on one attribute.** Collapsing them into
   one selection is the mistake `hunch-bench-instruments`' `fork.md` calls out by name.
4. **`Tally.Mode` is an enum, not a flag plus two optionals.** The comb toggle switches the tile;
   the count-mode payload does not exist in parity mode and must not be representable there.

Everything is `UInt8`-backed under the hood: `Glyph.Attribute`, `Comparator`, `Coupler`, `Subset4`,
`AttributeSet`, `CountSet` and `Tally.Mode`'s discriminant. Assert it with `MemoryLayout`, not with
a comment.

### The forward conversion `BenchLayout.init(_ law: LawNode)`

Total — every grammar-valid node has a layout, which is the forward half of §4.4's parity claim. It
is a `switch` over `LawNode` with **no `default:`** (`W29`): adding a production to the AST must
break this file at compile time, because a production the Bench cannot spell is a law the generator
must never emit.

The conversion is *literal*: it does not canonicalise. G10 compares
`LawNode(BenchLayout(law)) == law.renderedNormalForm`, so `BenchLayout.init` is only ever handed a
law already in RNF; re-canonicalising here would hide a spelling bug rather than expose it.

### The backward conversion `LawNode.init?(_ layout: BenchLayout)`

Returns `nil` for exactly the structurally incomplete layouts — an empty rail set, a rail count and
coupler that disagree, an unbound socket, an inert ramp, a Fork with no gate value, a Tally counting
fewer than three attributes. Every one of those is also a `sealBar` case, which is what makes the
fuzzer's invariant total.

It returns a node for everything else, **including degenerate drafts** — a bridge with both sockets
on one attribute, a guard whose branches agree, two ramps on the same attribute. Those are laws;
they are simply constant, or simply equal to a smaller law, and §4.5 judges by extension, so a
player who spells a band-1 law on a Fork tile is correct if that is the hidden law.

> **Ruling, to be recorded in `DECISIONS.md`.** §4.4 admits one over-reach — a draft whose extension
> is constant. There is a second: two Bridges on two rails, both with sockets on `cur`, is two
> relational terms, which §3.4's structural caps forbid but the BNF's
> `<law> ::= <term> <coupler> <term>` permits and the palette can physically build. The ruling is
> that §3.4's "at most one relational term / at most two contextual terms" are **generator** caps,
> asserted on everything `generate` emits (T05, T06), not parse-time caps. The Bench stays
> complement-closed and permissive, exactly as §5.3's admit-window decision argues it should be:
> unlearnable laws are worse than absent laws, and an unbuildable *thought* is worse still. The
> fuzzer's invariant is therefore "parses **or** is barred", and a two-relational draft parses.

### `sealBar`

Three clauses, in §4.3's order, returning the first that fires:

```swift
extension BenchLayout {
    /// §4.3. `nil` means the machine is ready. The associated `Int` is the rail index the Seal
    /// pulses; a whole-Bench tile is rail 0.
    public var sealBar: SealBar? {
        if let rail = firstInertRail { return .inertRail(rail) }
        if let rail = firstUnboundSocket { return .unboundSocket(rail) }
        guard let node = LawNode(self) else { return .inertRail(0) }   // unreachable after the two above
        return LawTable(node).isConstant ? .constantExtension : nil
    }
}
```

The third clause needs the evaluator, which is why `Bench` depends on `Laws`. That dependency is
also what lets T04's fuzzer assert parse-or-bar without a second evaluator.

The `guard` in the third clause is defensive, not load-bearing: after the first two clauses the
parse cannot fail, and T04's fuzzer proves it over 200,000 configurations. Do not turn it into a
`try!` or a `fatalError` — `HunchCore` ships in the app and a crash here is a crash in a player's
round.

### Barred is not an error

`hunch-bench-instruments` states it and it belongs in the model too: there is no error text, no
error state, no `throws`, no `Result`, no `LocalizedError`. `SealBar` is a *description of a
machine state*, and the only thing E09 does with it is decide which rail pulses for 3 × 90 ms.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter BenchTests` is green.
- [ ] Every stored scalar in `BenchLayout` is one byte wide, asserted with `MemoryLayout`.
- [ ] A layout round-trips through `JSONEncoder`/`JSONDecoder` unchanged for every sample layout, and
      an out-of-range raw value throws a `DecodingError` rather than trapping.
- [ ] `BenchLayout.init(_:)` is an exhaustive `switch` over `LawNode` with no `default:` —
      `grep -n 'default:' HunchCore/Sources/Bench/*.swift` returns nothing.
- [ ] `LawNode(BenchLayout(band.exemplar)) == band.exemplar` for all eight bands.
- [ ] `LawNode.init?` returns `nil` for exactly the layouts `sealBar` reports as `.inertRail` or
      `.unboundSocket`.
- [ ] 0 lit and 4 lit both report `.inertRail` with the same rail index — one inert state, not two.
- [ ] All six comparators on a same-attribute non-ghosted Bridge report `.constantExtension`.
- [ ] There is no `leadingIsPrevious`, no `isSealBarred: Bool`, and no error type anywhere in
      `HunchCore/Sources/Bench/`.
- [ ] `DECISIONS.md` records the two-relational over-reach ruling.
- [ ] `tests.json` has The Bench and The Seal + machined bar entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T03: BenchLayout, RuleTile and SealBar as core data with both conversions"`

## Out of scope

- G10 itself, the parity table and the 200,000-configuration fuzzer — **T04**.
- Every pixel: `RampView`, `BridgeView`, `ForkView`, `TallyView`, `CouplerView`, `SealView`, the
  machined bar drawing and the rail pulse — **E09·T02, T07**.
- The palette ceiling (which tile classes are available at all) — **E09·T04**.
- The Assay, live or expanded — **E09·T05**.
- Writing the draft into the mid-round snapshot — **E07·T09**, **E10·T02**.
