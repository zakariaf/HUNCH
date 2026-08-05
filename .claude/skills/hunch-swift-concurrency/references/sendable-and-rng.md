# Sendable, sending, and the seeded RNG

Read when a `Sendable` or `sending` diagnostic fires, when writing anything that draws a random
number, or when tempted to inject a clock. Rule numbers are `ios-swift-guide/05-CONCURRENCY.md`;
`08 §n` is `ios-swift-guide/08-APPLIED-TO-HUNCH.md`; `§n` alone is `GAME_DESIGN.md`.

1. [How conformance is earned](#1-how-conformance-is-earned)
2. [The roster](#2-the-roster)
3. [`sending` — the case that almost never arises here](#3-sending--the-case-that-almost-never-arises-here)
4. [`SplitMix64`](#4-splitmix64)
5. [Threading the generator](#5-threading-the-generator)
6. [If generation ever needs to move off the main actor](#6-if-generation-ever-needs-to-move-off-the-main-actor)
7. [`SeedSource` — the one point of nondeterminism](#7-seedsource--the-one-point-of-nondeterminism)
8. [`Now`, and why there is no clock](#8-now-and-why-there-is-no-clock)
9. [Immutable shared state that is not a singleton](#9-immutable-shared-state-that-is-not-a-singleton)
10. [The greps](#10-the-greps)

---

## 1. How conformance is earned

`05 §7.1`, applied to what HUNCH actually contains:

| Kind | Implicitly `Sendable`? | In HUNCH |
|---|---|---|
| non-public value type, all stored properties `Sendable` | yes | test-local helpers only |
| **public** value type, same contents | **no — you write it** | everything in `HunchCore` |
| `actor` | yes | the two actors |
| global-actor-isolated type | yes | `Round`, `Codex`, `Ladder`, `Router` |
| any other reference type | never | `VoiceBank`, and only `VoiceBank` |

`05 R21`: write `: Sendable` explicitly on every public value type. Its absence is invisible from
outside the module and a client cannot fix it. `HunchCore` is public API to `Modules/`, so this is
not hypothetical.

## 2. The roster

`08 §4` fixes the list: `Glyph`, `Verdict`, `LawNode`, `LawTable`, `Law`, `Band`, `Probe`, `Ribbon`,
`BenchLayout`, `RuleTile`, `RoundPhase`, `Outcome`, `Ability`, `ServingState`, `CodexPage`,
`RoundSnapshot`, `Profile`, `StoreFile` — plus `PersistenceStore` and `CuePlayer`, which are
`Sendable` *protocols* so that an `any PersistenceStore` can be stored in a `@MainActor` struct and
handed to an `actor`.

```swift
public struct Glyph: Hashable, Sendable, Codable {
    public let fill: Fill, shape: Shape, pips: Pips, hue: Hue      // nested — `08 §3`, the SwiftUI.Shape collision
}

public protocol PersistenceStore: Sendable {                       // `04 A41`, the brief's name
    func load<T: Decodable & Sendable>(_ type: T.Type, from file: StoreFile) async throws -> T?
    func save<T: Encodable & Sendable>(_ value: T, to file: StoreFile) async throws
}
```

Nothing in `HunchCore` is a class, so no `final class … : Sendable` question arises there. The one
place it does — `VoiceBank` — is `real-time-audio.md`.

## 3. `sending` — the case that almost never arises here

`Sendable` is a permanent property of a type: safe for concurrent use by many domains forever.
`sending` (`05 R22`) is a one-time complete transfer. HUNCH is value types end to end, so the
`sending` diagnostic mostly means something else has gone wrong. Before adding either annotation:

1. **Check for latent isolation** (`05 R52`). Most crossing errors are "you forgot `@MainActor` on the
   caller", not "you need a conformance".
2. **Check whether deleting a later use fixes it** (`05 R23`). The diagnostics are flow-sensitive, not
   signature-sensitive: passing a non-`Sendable` value to an `@concurrent` function is legal and you
   may keep using it afterwards; the error appears only where the value reaches something that
   *outlives* the call — an actor, a global-actor function, a stored `Task`.
3. Only then: `: Sendable` if you own the type and it is genuinely shareable, `sending` if it is a
   one-time hand-off.

The realistic HUNCH instance of step 3 is a large `LawIndex` or a decoded shelf moving from
`FilePersistenceStore` to its caller once. Both are already immutable `Sendable` values, so the
annotation is not needed — which is the point.

## 4. `SplitMix64`

```swift
public struct SplitMix64: RandomNumberGenerator, Sendable {   // one UInt64 — trivially Sendable
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 { /* increment, then the §11.6 finaliser */ }
}
```

Two facts about the constants, and they are not symmetrical:

- **The finaliser is canon.** `§11.6` states the multipliers and the shift sequence, in
  `anomalySeed(day:)`. `next()`'s mixing stage is the same three lines. Implement the finaliser
  **once** and have `anomalySeed(day:)` call it — retyping the constants is how a law that is
  supposed to be identical for every player on Earth stops being identical.
- **The increment is not canon.** No section of `GAME_DESIGN.md` states the gamma. Choose the standard
  SplitMix64 value once, record it in `DECISIONS.md` with a pointer to this gap, and let
  `LawGenerationTests/Fixtures/determinism-seeds-v1.json` freeze it. Two spellings of `next()` are two
  different games and nothing else in the project will notice.

`SplitMix64` conforms to `Sendable` because it is one `UInt64` and the compiler can see that. Do not
read that as permission to send one. It is never sent; see §5.

## 5. Threading the generator

The generator is a pure function of five arguments (`§5.3`), and the RNG is created inside it and
dies at the closing brace. That is the whole answer to "an RNG is mutable state" — the problem is
scoping, not concurrency (`08 §4`).

```swift
public func generate(seed: UInt64, band: Band, targetDelta: Double,
                     mode: Mode, avoid: Set<UInt64> = []) -> LawNode {
    var rng = SplitMix64(seed: seed ^ (UInt64(band.rawValue) << 32) ^ mode.salt)
    let skeleton = Skeleton.sample(for: band, using: &rng)
    return skeleton.filled(targetDelta: targetDelta, avoid: avoid, using: &rng)
}

/// `using rng:` is `shuffled(using:)`'s own label (`02 N15`, the preposition row).
func sample(for band: Band, using rng: inout some RandomNumberGenerator) -> Skeleton { … }
```

Operational rules, all from `08 §4`:

1. **`generate` is synchronous and `nonisolated`.** Not `async`. `05 R13`'s trap cannot fire on a
   function with no suspension point, and `@concurrent` on a sub-millisecond pure function is wrong.
2. **Randomness is a parameter, never an ambient.** `inout some RandomNumberGenerator` all the way
   down. A function that reaches for randomness it was not given is a bug even if it compiles.
3. **`SystemRandomNumberGenerator`, `Int.random`, `Date()` and `UUID()` are banned from `HunchCore`
   by CI grep** (§10 below).
4. **No RNG in an `@Observable` class, ever.** The law would depend on how many times SwiftUI
   evaluated a body — a bug that reproduces on one device and not another.
5. **Determinism is a scoping problem, and the scope is one function call.**

The guardrail loop resamples up to 200 times on failure (`§5.3` G1–G10) — all inside that same
`var rng`, so the retry sequence is part of the deterministic draw order. Do not "helpfully" reseed
between attempts.

## 6. If generation ever needs to move off the main actor

Only after profiling (`05 R16` — measure, do not quote hop costs). The offload sends a `UInt64`:

```swift
// The seed crosses the isolation boundary. The generator is constructed on the far side.
@concurrent
public func makeLaw(seed: UInt64, band: Band, targetDelta: Double,
                    mode: Mode, avoid: Set<UInt64>) async -> LawNode {
    generate(seed: seed, band: band, targetDelta: targetDelta, mode: mode, avoid: avoid)
}
```

`@concurrent`, not bare `nonisolated … async` (`05 R13`) and not `Task.detached` (`05 R38`). Note that
`avoid: Set<UInt64>` is `Sendable` and `LawNode` is `Sendable`, so nothing needs `sending`. The
generator itself is unchanged — which is the test that the design was right.

## 7. `SeedSource` — the one point of nondeterminism

```swift
// Modules/Sources/HunchAppFeature/ — `08 §6`
public struct SeedSource: Sendable {
    public var next: @Sendable () -> UInt64
    public static let live = Self { SystemRandomNumberGenerator().next() }
    public static func fixed(_ value: UInt64) -> Self { Self { value } }
}
```

It sits in `AppDependencies` beside `store`, `now` and `cues`, it is injected, and it is the reason
`SystemRandomNumberGenerator` can be banned outright from `HunchCore`. `04 A29`'s rule is not "no
singletons" but "no singleton inside a boundary you test across" — this is that boundary, one line
wide. `AppDependencies.preview(seed:date:)` composes `.fixed` with `Now.fixed`,
`InMemoryPersistenceStore` and `SilentCuePlayer`, so a preview is deterministic by construction.

## 8. `Now`, and why there is no clock

```swift
public struct Now: Sendable {                       // dates only: firstFoundAt, lastPlayed, the UTC day index
    public var date: @Sendable () -> Date
    public static let live = Self { Date() }
    public static func fixed(_ date: Date) -> Self { Self { date } }
}
```

`§6.1` fixes that no wall-clock quantity affects score, marks or the Rasch update, and `§9`'s speed
curve is a function of glyph index rather than elapsed seconds. So HUNCH has **no `Clock`
abstraction anywhere** (`08 §5`): SIEVE's timing is a pure `SieveSchedule` value plus one
`ContinuousClock.sleep` at the view edge. `swift-clocks` is a third-party dependency and therefore
banned, so this is not merely tidier — re-implementing `TestClock` would have been real work.

Adding a `Clock` protocol to make something testable means the timing leaked into `HunchCore`. Move
the timing out instead.

## 9. Immutable shared state that is not a singleton

`MaskTable.resident` (54 KB) and `Deck.all` are `static let` of immutable `Sendable` values —
`05 R50` rung 1, and *not* the singletons the brief bans, because there is no mutable state and
nothing to substitute (`08 §4`). The same applies to `Corpora.index` in `HunchTestSupport`, which is
the one sanctioned piece of shared state under `06 T10`'s parallel-in-one-process model.

```swift
public enum Deck {
    public static let all: [Glyph] = …          // let, immutable, Sendable → rung 1
}

public enum MaskTable {
    public static let resident: MaskTable = …   // built once at first touch, never mutated
}
```

`static var` anywhere is `error: … is not concurrency-safe because it is nonisolated global shared
mutable state [#MutableGlobalVariable]`, and the ladder for fixing it is `05 R50`. Rung 5
(`nonisolated(unsafe)`) has a budget of zero in this repository.

## 10. The greps

`Scripts/check-source-hygiene.sh` (`07 B34a` plus `08 §5`'s four HUNCH checks). The two that belong
to this skill:

```bash
# Check 3 — every escape hatch carries a justifying comment (`05 R29`). Two-line window.
grep -rn --include='*.swift' -E \
  '@unchecked Sendable|nonisolated\(unsafe\)|@preconcurrency import|Task\.detached|assumeIsolated' \
  App Modules HunchCore

# Check 6 — no ambient nondeterminism in the core (`08 §5`).
grep -rn --include='*.swift' -E \
  'SystemRandomNumberGenerator|\.random\(|Date\(\)|UUID\(\)' HunchCore/Sources
```

Check 3's exact implementation, including why it tests a two-line window rather than the matched
line, is `07 B34a`. Check 6 has no legitimate exception: if a core function needs a date, it takes
one.
