# Naming a declaration in HUNCH

1. [The vocabulary index](#1-the-vocabulary-index)
2. [The three collisions](#2-the-three-collisions)
3. [The Band/Family collapse](#3-the-bandfamily-collapse)
4. [Naming something the vocabulary does not cover](#4-naming-something-the-vocabulary-does-not-cover)
5. [Argument labels](#5-argument-labels)
6. [Booleans, verbs, async, actors](#6-booleans-verbs-async-actors)
7. [SwiftUI names](#7-swiftui-names)
8. [The ban list, applied to this project](#8-the-ban-list-applied-to-this-project)

---

## 1. The vocabulary index

`GAME_DESIGN.md` §2 locks the *terminology* for seven authors. It does not lock the type count, and three of its words do not survive contact with Swift (§2 below). `08 §3` is the authoritative mapping — it carries the rule that fires and the reasoning for each row. This is the index only: term on the left, the symbol you type on the right.

**Once the Swift exists, `grep` beats this table.** `grep -rn 'public struct\|public enum\|public protocol\|public final class\|public actor' HunchCore/Sources/` is the current truth; a disagreement means this file is stale and should be fixed.

| Design word | What you type |
|---|---|
| glyph and its four attributes | `Glyph`, and **nested** `Glyph.Fill`, `Glyph.Shape`, `Glyph.Pips`, `Glyph.Hue`, cases verbatim from §2 |
| the deck | `enum Deck` caseless, `Deck.all`, `Deck.glyph(id:)` |
| a law's truth table, "extension" | `struct LawTable: Hashable, Sendable` |
| the law | `indirect enum LawNode` (the AST, `Codable`, stored) **plus** `struct Law` (node + resolved table + cached metrics, never `Codable`) |
| the Loom | **no type.** `Law.admits(_ glyph: Glyph, after previous: Glyph) -> Bool`; the word survives as `LoomFeature` and `ThroatView` |
| admit / reject | `enum Verdict: Sendable { case admit, reject }` |
| band, family | one `enum Band: Int, CaseIterable, Comparable, Sendable` — see §3 |
| `targetδ`, `δ_served`, `θ` | `targetDelta`, `servedDelta`, `ability` |
| probe (noun and verb), twin | `struct Probe`; `func probe(_ glyph: Glyph)`, `func probeTwin()` |
| the Bench, rule-tiles, the coupler | `struct BenchLayout: Codable`, `enum RuleTile`, `enum Coupler: UInt8`; widgets are `RampView`, `BridgeView`, `ForkView`, `TallyView` |
| bench layout and its parser | `BenchLayout.init(_ law: LawNode)` and `LawNode.init?(_ layout: BenchLayout)` — a value-preserving conversion drops the label (`N14`) |
| the Seal, barred | `func seal()`; `var sealBar: SealBar?` where `enum SealBar { case inertRail(Int), unboundSocket(Int), constantExtension }` |
| the Codex, a page, a shelf | `@MainActor @Observable final class Codex`; `struct CodexPage: Codable`; `struct CodexShelf` |
| the Anomaly | `enum Anomaly` caseless; `struct AnomalyLedger: Codable` |
| the Profile and its axes | `struct Profile: Codable, Sendable` with nested `enum Axis: CaseIterable` |
| the four modes | `enum Mode: UInt8, Codable, Sendable`, rendered `Text(verbatim: mode.wordmark)` |
| ability, "core" | `struct Ability` with `var baseline: Double?` — `core` collides with the module name, and §10.4's "undefined, not 0" is what the optional says |
| the ten on-disk files | `enum StoreFile` |
| the persistence seam | `protocol PersistenceStore: Sendable` — the brief's name, kept |
| audio and haptic cues | `enum Cue`; `protocol CuePlayer: Sendable`; `SynthesizedCuePlayer`, `HapticCuePlayer`, `SilentCuePlayer` |

`Profile.Axis`'s five case names are **code-only**. §12.9 forbids them entering the String Catalog in any form, visible or spoken.

## 2. The three collisions

### `Shape` — ambiguous with `SwiftUI.Shape`

`HunchUI` imports both SwiftUI and `HunchCore`. A top-level `Shape` in the core is then ambiguous at every use site in the renderer. Reproduced on Swift 6.3.3:

```swift
// ✗ HunchCore/Sources/Glyphs/Glyph.swift
public enum Shape: UInt8, Sendable { case disc, triangle, square, hexagon }
```
```text
// …and in HunchUI, which imports SwiftUI and HunchCore:
error: 'Shape' is ambiguous for type lookup in this context
note: found this candidate            (HunchCore.Shape)
note: found this candidate            (SwiftUI.Shape)
```

Nesting fixes it at the declaration and costs nothing at the use site, because the context infers the leading dot (`N22`):

```swift
// ✓ HunchCore/Sources/Glyphs/Glyph.swift
public struct Glyph: Hashable, Sendable, Codable {
    public enum Shape: UInt8, CaseIterable, Sendable, Codable { case disc, triangle, square, hexagon }
    public enum Fill: UInt8, CaseIterable, Sendable, Codable { case solid, hollow, halved, dotted }
    public var shape: Shape
    public var fill: Fill
}
```
```swift
// ✓ Modules/Sources/HunchUI/GlyphShape.swift — `Shape` here is SwiftUI's; the attribute is qualified.
import SwiftUI
import HunchCore

struct GlyphShape: Shape {
    let shape: Glyph.Shape

    /// `nonisolated` because `HunchUI` is `.defaultIsolation(MainActor.self)` and `Shape`'s
    /// requirement is not. Why that is the spelling is `hunch-swift-concurrency`'s; that it is
    /// required here is why the line exists.
    nonisolated func path(in rect: CGRect) -> Path {
        switch shape {
        case .disc: Path(ellipseIn: rect)
        case .triangle, .square, .hexagon: Path(rect)   // real silhouettes belong to hunch-glyph-renderer
        }
    }
}
```

`HunchCore::Shape` — the module selector from SE-0491, shipping in Swift 6.3 (`N23`) — stays in reserve for an ambiguity that survives nesting. It should never be needed here.

### `extension` — a keyword

The design calls a law's truth table its "extension". `extension` cannot be an identifier, and `Extension.swift` would additionally trip `01 P28`'s banned-filename grep. Ship `struct LawTable` in `LawTable.swift`, and keep the word "extension" in prose only. Do not settle for `[UInt64]` with a comment: the table has behaviour (`row(after:)`, `isSatisfiable`, `isFalsifiable`, `admitRate`) and a `typealias` gives none of it.

### `Ramp` — a payload *and* a widget

`RuleTile.ramp(Ramp)` carries a payload struct; the Bench also draws a ramp. `N39` allows the `View` suffix on a SwiftUI view **only** to break a collision with a model type, and this is that case — so `Ramp` is the payload and `RampView` is the widget, and the same holds for bridge, fork and tally.

```swift
// ✓ HunchCore/Sources/Bench/RuleTile.swift — payloads nested in their owner (01 P25a, N22)
public enum RuleTile: Hashable, Sendable {
    case ramp(Ramp), bridge(Bridge), fork(Fork), tally(Tally)

    public struct Ramp: Hashable, Sendable { /* … */ }
    public struct Bridge: Hashable, Sendable { /* … */ }
    public struct Fork: Hashable, Sendable { /* … */ }
    public struct Tally: Hashable, Sendable { /* … */ }
}
```

Note what nesting buys twice over: `RuleTile.Ramp` cannot collide with anything, and the four `…View` suffixes then have no competitor left to break — but keep them anyway, because `08 §3` fixes those names and `hunch-bench-instruments` draws against them.

## 3. The Band/Family collapse

§5.3 fixes "strictly one family per band, no reprises", so band and family are in bijection. Two types for one concept is `W28`'s smell in a different costume, and `Family(band)` would be an identity function that eventually drifts. **Ship one type; keep both words in prose; record the collapse in `DECISIONS.md`** (`08 §3`).

The declaration in `08 §3` is one clause short of compiling. A raw type suppresses SE-0266's synthesized `Comparable` — verified on Swift 6.3.3, *"enum declares raw type 'Int', preventing synthesized conformance of 'Band' to 'Comparable'"*:

```swift
// ✓ HunchCore/Sources/LawGeneration/Band.swift
public enum Band: Int, CaseIterable, Comparable, Sendable {
    case literal = 1, pair, exclusive, relational, contextual, guarded, composite, systemic

    /// A raw type suppresses the synthesized `Comparable` conformance (SE-0266), so state it.
    public static func < (lhs: Band, rhs: Band) -> Bool { lhs.rawValue < rhs.rawValue }
}
```

`par(for:)`, `cap(for:)`, `population` and `difficultyRange` hang off this type. The *tick pitch* does not — that is layout and lives in `HunchUI` (`08 §2`).

## 4. Naming something the vocabulary does not cover

`N1` and `N2` first, and they settle most arguments before the tables do:

- **Read the call site out loud.** If the sentence is ungrammatical or ambiguous, the name is wrong (`N1`).
- **If you cannot write a one-sentence summary of the declaration, the problem is the design.** Split it, then name the halves (`N2`, `N46`). This is the only naming review that catches a wrong abstraction rather than a wrong word.

Then: include every word needed to disambiguate at the use site and delete every word the types already say (`N3`); name parameters and locals for their **role**, not their type (`N4`); nest error, configuration and state types in their owner (`N22`); no Objective-C prefixes (`N21`).

Greek and subscripted identifiers compile and are still banned: `δ_served` cannot be typed reliably, greped or read aloud (`N1`), and the underscore breaks `N33` on top. `targetDelta`, `servedDelta`, `ability`.

## 5. Argument labels

`N15` is a seven-row decision table. Run it rather than freestyling:

```bash
sed -n '/^\*\*N15\./,/^\*\*N16\./p' ios-swift-guide/02-NAMING-AND-API-DESIGN.md
```

The two rows this project gets wrong:

- **Row 3 — arg 1 completing a verb phrase folds into the base name.** `bench.addTile(ramp)`, never `bench.add(tile: ramp)`.
- **Preposition rows.** Randomness is always a parameter and always takes `shuffled(using:)`'s own label: `func draw(from deck: [Glyph], using rng: inout some RandomNumberGenerator)`. The RNG scoping rule behind that is `08 §4` and belongs to `hunch-swift-concurrency`.

Defaulted parameters beat method families and must be labelled and last (`N16`).

## 6. Booleans, verbs, async, actors

- **No side effects → noun phrase; side effects → imperative verb** (`N6`). `func probe(_ glyph: Glyph)` mutates the round; `func twin() -> Probe` would be a noun promising purity, so the mutating form is `probeTwin()`.
- **Booleans are positive assertions** using `is`/`has`/`can`/`should`/`will`/`did`/`does` or a third-person verb (`N9`), never negative (`N10`). `law.admits(glyph, after: previous)`, `table.isSatisfiable`, `snapshot.hasStrike`. Never `isNotBarred`.
- **`sealBar` deviates from `N10` deliberately**: the machine state *is* the bar, and a `Bool isSealBarred` cannot answer "which rail pulses?" (`W28`, `08 §3`).
- **Never suffix `Async`, never prefix `get`** (`N37`). `store.load(_:from:)`, not `getRoundAsync(mode:)`.
- **Actors take plain nouns** (`N38`): `FilePersistenceStore`, `LawIndexLoader` — never `PersistenceActor`.
- **Enum cases never stutter the enum name and never start with `is`** (`N29`). `Verdict.admit` and `Verdict.reject` are imperative verbs, which `N29` would normally reject; `N36` (precedent beats purity) applies because the domain locks them.

## 7. SwiftUI names

- **A view is named for what appears on screen**, with the `View` suffix only to break a collision with a model type (`N39`). `ThroatView` and `RampView` earn it; `RoundView`, `BenchView` and `AssayInspectorView` are `08 §1`'s fixed names.
- **`ContentView` is deleted on day one.** It means nothing.
- **A `ViewModifier` type is a noun and its `View` extension method is the same word lowerCamelCased** (`N41`), so it composes like a built-in. `.hunchEnvironment(_:)` is the one exported installer (`04 A28`).
- **Environment entries use `@Entry` and are named after the value** (`N42`, `04 A27`): `@Entry var glyphScale: CGFloat`, `@Entry var theme: Theme`, `@Entry var storeHealth: StoreHealth`. There is no `…Key` type left to name.
- **`@Observable` types take the bare domain noun** (`N40`). `Round`, `Codex`, `Ladder`, `Router`. `…Store` is the one sanctioned suffix and only for a type that gatekeeps a collection — which is why `PersistenceStore` keeps it and `CodexStore` is banned: the Codex *is* the archive.

Test names are `N43`/`N44` and belong to `hunch-swift-testing`.

## 8. The ban list, applied to this project

`02 §17` is the general table. These are the names this codebase would otherwise actually produce:

| ✗ Never here | ✓ Instead | Rule |
|---|---|---|
| `AudioManager`, `HapticsService`, `CueProvider` | `SynthesizedCuePlayer`, `HapticCuePlayer`, `SilentCuePlayer` behind `protocol CuePlayer` | `N25`, `N26` |
| `PersistenceStoreProtocol`, `PersistenceStoreImpl`, `DefaultPersistenceStore` | `PersistenceStore` + `FilePersistenceStore` / `InMemoryPersistenceStore` | `N25` |
| `RoundViewModel`, `CodexViewModel`, `LadderManager` | `Round`, `Codex`, `Ladder` | `N40`, `04 A19`, `08 §7.8` |
| `GlyphUtils`, `LawHelpers`, `BenchService` | the behaviour goes on `Glyph`, `Law`, `BenchLayout` | `N26`, `N45` |
| `enum Bench { static func layout(for:) }` | `BenchLayout.init(_ law: LawNode)` — a namespace holding two statics is a `Utils` with a better name | `08 §3` |
| `CodexStore`, `CodexManager` | `Codex` | `N40` |
| `Family`, `Family(band)` | `Band` | `W28`, `08 §3` |
| `getLawAsync(seed:)`, `fetchGlyphData(_:)` | `generate(seed:band:targetDelta:mode:avoid:)`, `Deck.glyph(id:)` | `N37` |
| `δ_served`, `θ`, `targetδ` | `servedDelta`, `ability`, `targetDelta` | `N1`, `N33`, `N35` |
| `k_PI_ZERO`, `PI_ZERO`, `_cache` | `piZero`, `private var cache` | `N33` |
| `LawIndexActor`, `StoreActor` | `LawIndexLoader`, `FilePersistenceStore` | `N38` |
| `Utils.swift`, `Extensions.swift`, `Extension.swift`, `Constants.swift` | name the capability, or nest it on the owning type | `01 P28`, `N45` |
