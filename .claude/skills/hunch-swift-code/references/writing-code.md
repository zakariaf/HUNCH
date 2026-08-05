# Writing the code

1. [Choosing the kind of type](#1-choosing-the-kind-of-type)
2. [Making illegal states unrepresentable](#2-making-illegal-states-unrepresentable)
3. [Access control across two packages](#3-access-control-across-two-packages)
4. [Optionals, force-unwraps, preconditions](#4-optionals-force-unwraps-preconditions)
5. [Errors](#5-errors)
6. [Protocol or struct of closures](#6-protocol-or-struct-of-closures)
7. [Immutability](#7-immutability)
8. [The metaprogramming budget: zero](#8-the-metaprogramming-budget-zero)
9. [Doc comments](#9-doc-comments)
10. [Fails review on sight, HUNCH edition](#10-fails-review-on-sight-hunch-edition)

---

## 1. Choosing the kind of type

`W2` is an eight-row procedure — run it top to bottom and stop at the first match:

```bash
sed -n '/^\*\*W2\./,/^\*\*W3\./p' ios-swift-guide/03-WRITING-THE-CODE.md
```

For this project it lands in six places, and only six:

| What you are declaring | Type | Where |
|---|---|---|
| A value with attributes, a layout, a snapshot, a score, an estimate | `struct`, `Hashable`/`Sendable`/`Codable` as needed | `HunchCore` |
| A fixed set of alternatives, with or without payloads | `enum` — `Verdict`, `Band`, `Mode`, `RuleTile`, `SealBar`, `StoreFile`, `RoundPhase` | `HunchCore` |
| A recursive tree | `indirect enum LawNode` | `HunchCore` |
| A namespace of pure functions over values | **caseless** `enum` — `Deck`, `Anomaly` (`W16`) | `HunchCore` |
| A model a view observes | `@MainActor @Observable final class` — `Round`, `Codex`, `Ladder`, `Router` | `Modules` |
| Cohesive state with behaviour, callers already `async` | `actor` — exactly two, `FilePersistenceStore` and `LawIndexLoader` (`08 §4`) | `HunchCore` |

**Nothing in `HunchCore` is a class.** Every public type there is a value type and writes `: Sendable` explicitly. The only reference types are the two actors, and `05 R18` forbids inventing a third to protect a counter, a flag or a cache dictionary — `hunch-swift-concurrency` owns that ladder and the one documented `@unchecked Sendable` in `Modules/Sources/Feedback`.

**`@Observable` is classes only** (`04 A5`) — registration and mutation tracking need reference identity. Do not design around a hoped-for `@Observable struct`, and do not reach for `actor` to get thread safety for a view model (`W3`): the UI targets are `MainActor` by default isolation already, so an actor buys nothing but an `await` at every call site.

**Mark every class `final`** (`W10`). Nothing in this app is designed for subclassing.

**A large value copied on a hot path gets copy-on-write storage, not a class** (`W4`) — and only after measuring. `MaskTable.resident` is 54 KB of immutable data held as a `static let`, which is rung 1 of `05 R50` and needs no COW at all.

## 2. Making illegal states unrepresentable

`W28`: a comment or log line saying "this should never happen" is a type error, not a logging opportunity. So is a `Bool` that is only meaningful when some optional is non-nil. This project has four instances and they are load-bearing:

```swift
// ✓ "which rail pulses?" is answerable. A `Bool isSealBarred` would need a second parallel
//   field to carry the answer — W28 exactly. The negative name deviates from N10 because
//   the machine state *is* the bar (08 §3).
public var sealBar: SealBar?

// ✓ §10.4 says the baseline is *undefined*, not 0. `var baseline: Double` cannot say that,
//   so cold start becomes a sentinel someone compares against 0.0 (W28).
public struct Ability: Sendable { public var baseline: Double? }

// ✓ a verdict is two values, not a Bool named `passed` whose polarity a reader must recall.
public enum Verdict: Sendable { case admit, reject }
```

`StoreFile` is the fourth, and it is the one that pays off twice. §11.13's on-disk tree and its reset map both become exhaustive switches, so **adding a file to the tree is a compile error in the reset map** — which is only true if you never write `default:` (`W29`):

```swift
// ✓ HunchCore/Sources/Persistence/StoreFile.swift
public enum StoreFile: Hashable, Sendable {
    case manifest, codexIndex, anomaly, profile, ladder, statistics, lawIndex
    case codexShelf(Band)
    case round(Mode)
}

extension StoreFile {
    /// Whether a reset of `scope` removes this file. No `default:` — a new case must be
    /// classified here before the module compiles again (W29).
    public func isRemoved(byResetOf scope: ResetScope) -> Bool {
        switch self {
        case .manifest, .anomaly: false                       // never removed by any reset
        case .codexIndex, .codexShelf: scope >= .archive
        case .profile, .statistics, .ladder: scope >= .progress
        case .round, .lawIndex: true                          // always rebuildable
        }
    }
}
```

The cost `W28` names applies here too: an enum is less convenient to mutate in place. When a state has five or more independently-changing associated values, a struct with an enum `phase` field is the honest compromise — which is exactly the shape `Round` has.

## 3. Access control across two packages

`W6`: in a multi-module codebase the implicit `internal` default is not a decision. Make one per declaration.

The two-package deviation (`08 §7.2`) has exactly one surviving cost, and this is it: **`package` does not cross a package boundary.**

| Declaration | Level |
|---|---|
| A `HunchCore` type used by another `HunchCore` target only | `package` |
| A `HunchCore` type used by anything in `Modules` | `public`, with an explicit `public init` |
| A `Modules` type used by another `Modules` target only | `package` |
| Anything `App/` touches — that is `HunchAppFeature`'s product surface, and nothing else | `public` |
| An implementation detail of one file | `private` — it already reaches same-file extensions of the same type (`W8`) |

Two mechanical traps:

- **A `public struct`'s synthesized memberwise initialiser is `internal`.** Write `public init` by hand on every type the composition root constructs, or it will not compile from another target (`04 A29`).
- **One `private` stored property makes the *whole* synthesized memberwise initialiser `private`** — the compiler demotes it rather than omitting the property (`W14`). Write the initialiser by hand. SE-0502 fixes this in Swift 6.4; it is not in the shipping toolchain.

**Never put an access level on an `extension` declaration** (`W7`). It applies to every member, including the ones added six months later, and swift-format rejects it by default.

## 4. Optionals, force-unwraps, preconditions

- `if let x` shorthand, always (`W22`). `guard` when the rest of the function needs the value, `if let` when only the branch does (`W23`).
- **No bare `!`** (`W25`). `W54` turns `NeverForceUnwrap` on, so a `!` you keep carries `// swift-format-ignore: NeverForceUnwrap` plus the proof, on the line. A suppression is a reviewable event; a disabled rule is not.
- **No `try!` outside tests** (`W37`).
- The guide's `URL(staticString:)` helper has no use here — this app parses no URLs and opens no network. The one place a `!` is tempting is a total lookup, and the answer is a precondition that names the contract:

```swift
// ✗ crashes with a stack trace that says nothing about why the id was out of range
public static func glyph(id: Int) -> Glyph { all[id]! }

// ✓ the caller's contract, stated, surviving into Release (W39)
/// The glyph with the given canonical index.
///
/// - Precondition: `id` is in `0..<256`.
/// - Complexity: O(1).
public static func glyph(id: Int) -> Glyph {
    precondition(all.indices.contains(id), "glyph id \(id) is outside 0..<256")
    return all[id]
}
```

`assert` for your own invariant, `precondition` for the caller's contract, `fatalError` for a state that is unreachable rather than merely invalid — and always with a message (`W39`). Never ship `-Ounchecked` (`W40`); under it a failed `precondition` is undefined behaviour rather than a crash.

## 5. Errors

- **Plain `throws` at every boundary** (`W33`). Typed throws buys nothing the moment a second error type joins a `do` block, and this project has no generic error-passthrough case.
- **Throw; do not return `Result`** (`W36`). Its job died with `async`/`await`.
- **One error enum per capability, never one app-wide `HunchError`** (`W35`). In practice this project has one: persistence.
- **`N31` says nested errors are called `Failure` — but a protocol cannot nest one.** `extension PersistenceStore { enum Failure … }` is `error: type 'Failure' cannot be nested in protocol extension of 'PersistenceStore'`, verified on Swift 6.3.3, followed by a second error because the raw type then cannot synthesize `RawRepresentable`. So the persistence error is top-level and named for the *domain*, not for the object that threw it (`W35`): `PersistenceError`.
- **This project's ruling on `W35`'s conformance pair: `CustomNSError` yes, `LocalizedError` no.** `W35` asks for both because a thrown error serves four audiences, but the user-facing audience does not exist here: §12.9 ships zero error text, store failure surfaces as the `storeHealth` hairline, and a `String(localized:)` in an `errorDescription` would add a key to a catalog capped at 250 keys in 12 languages. Keep the explicit `Int` codes — they are what makes crash grouping stable across releases, and they are append-only forever once shipped.

```swift
// ✓ HunchCore/Sources/Persistence/PersistenceStore.swift
public protocol PersistenceStore: Sendable {
    func load<Value: Decodable & Sendable>(_ type: Value.Type, from file: StoreFile) async throws -> Value?
    func save<Value: Encodable & Sendable>(_ value: Value, to file: StoreFile) async throws
    func remove(_ file: StoreFile) async throws
}

/// Why a store operation failed. Codes are stable across releases: append, never renumber —
/// Foundation derives `NSError.code` from the raw value, and that is what groups crash reports.
public enum PersistenceError: Int, Error, CustomNSError {
    case unreadable = 1
    case unwritable = 2
    case schemaTooNew = 3
    case migrationFailed = 4

    public static var errorDomain: String { "HunchCore.PersistenceError" }
}
```

A malformed file is not a crash: §11.13's quarantine-and-rebuild path is the behaviour, and `hunch-swift-testing` owns the test that proves a truncated shelf quarantines rather than throwing through to the UI.

## 6. Protocol or struct of closures

`W44` asks two questions in order, and the first one is not about size: **a protocol is justified when the seam is a published architectural boundary.** The three-member tiebreak only settles the leftovers.

| Seam | Shape | Why |
|---|---|---|
| `PersistenceStore` | `protocol` | The brief names it, and a repository boundary keeps its protocol at any member count (`W44`'s first question, `04 A41`) |
| `CuePlayer` | `protocol` | Three shipped conformers with genuinely different mechanisms — `N25`'s `RemoteUserStore`/`InMemoryUserStore` shape |
| `Now` | `struct` of one closure | One function, one substitution point (`08 §5`) |
| `SeedSource` | `struct` of one closure | The single point of nondeterminism in the app (`08 §6`) |

What `W44` rejects is the protocol that exists **only** so a test can inject a stub. Do not invent `LawGenerating`, `AbilityEstimating` or `BenchParsing`: those are pure functions over values, and a test calls them directly with a seed.

## 7. Immutability

- `let` for every property and local until the compiler makes you change it (`W18`). Do not silence the never-mutated warning; fix it.
- **`if`/`switch` expressions instead of a `var` assigned per branch** (`W19`). A case that forgets to assign is then an error on the case rather than at the use site.
- **Computed by default; stored when the value is the source of truth; `lazy` almost never** (`W20`). `lazy var` is *not* thread-safe and there is no `lazy let`. In a strict-concurrency codebase it will fight you, and it should.
- `MaskTable.resident` and `Deck.all` are `static let` of immutable `Sendable` values. That is rung 1 of `05 R50`, and it is **not** the singleton the brief bans: there is no mutable state and nothing to substitute (`08 §4`).
- Omit `get` on a read-only computed property (`W21`).

## 8. The metaprogramming budget: zero

This codebase **consumes** macros and **authors** none. `@Observable`, `@Entry`, `@Test`, `#bundle` and `#expect` are consumed; `W47` makes authoring a completely different decision, and `W48`'s bar — boilerplate a human must keep in sync that the compiler cannot check — is not met anywhere here. The whole SwiftSyntax bill for one convenience is the cost, and the brief bans third-party dependencies that would amortise it.

Same for the other two instruments:

- **No property wrappers authored** (`W45`). And you could not use one in `Round` anyway without `@ObservationIgnored`, which removes the observation you wanted (`W46`).
- **No result builders authored** (`W50`). `ViewBuilder` is consumed; a `BenchBuilder` DSL would buy nothing a memberwise initialiser does not, and its diagnostics would be "unable to type-check this expression in reasonable time".
- **No retroactive conformances** (`W17`). Wrap the type instead.

## 9. Doc comments

- `///`, never `/** */`. Summary first as a single sentence fragment, then discussion, then `- Parameters:`, `- Returns:`, `- Throws:` in that order (`W51`).
- **Document the contract, not the signature** (`W52`): preconditions, isolation requirements, what it costs, what it deliberately does not do. `/// The current band.` above `var band: Band` is noise; delete it rather than improve it.
- **`- Complexity:` on any computed property that is not O(1)** (`N47`). `Deck.glyph(id:)` documents O(1) because the subscript promises it; `Law`'s cached metrics exist precisely so that `law.marginalDeficit` can be O(1) behind a dot instead of rebuilding a table (`08 §3`).
- Document internal symbols too — this is an app, so `public` is not the floor (`W53`). Do not enable `AllPublicDeclarationsHaveDocumentation`; it will generate a hundred `W52` violations to satisfy it.

The formatter's committed configuration is `W54`'s four-rule delta, and `hunch-build-and-ci` owns where it runs.

## 10. Fails review on sight, HUNCH edition

`03 §13` is the general table. These are the rows this diff will actually contain:

| Smell | Fix | Rule |
|---|---|---|
| `final class` under `HunchCore/Sources/` | it is a value type, or the file is in the wrong package | `W1`, `08 §2` |
| `default:` in a switch over `StoreFile`, `Band`, `Mode`, `RuleTile`, `RoundPhase`, `Verdict` | list the cases | `W29` |
| A `Bool` beside an optional that is only meaningful together | one enum | `W28` |
| `var isSealBarred: Bool` | `var sealBar: SealBar?` | `W28`, `08 §3` |
| `var baseline: Double = 0` | `var baseline: Double?` | `W28`, `08 §3` |
| A bare `!` or a `try!` outside a test | `guard let … else { throw }`, or a `precondition` naming the contract | `W25`, `W37` |
| `public` on everything in a package where `package` would do | `package` | `W6` |
| A `public struct` with no `public init`, constructed from another target | write the initialiser | `04 A29` |
| An access level on an `extension` declaration | per-member | `W7` |
| `struct Constants { static let … }` | caseless `enum`, or the owning type | `W16` |
| A protocol with ≤3 members whose only second conformer is a test double | struct of closures — unless it is `PersistenceStore` or `CuePlayer` | `W44` |
| `forEach` where `for` belongs; a `var` never mutated; `[Glyph]()` | the formatter already says so | `W54` |
| A numeric `lineWidth:`, `.opacity(…)`, `duration:`, hex or font size anywhere | a token | `hunch-design-tokens` |
| An authored macro, property wrapper or result builder | delete it | `W45`–`W50` |
