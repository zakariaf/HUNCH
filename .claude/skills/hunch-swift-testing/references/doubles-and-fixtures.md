# Doubles, corpora and fixtures

1. [The two support targets, and the manifest shape that keeps them out of the app](#1-the-two-support-targets-and-the-manifest-shape-that-keeps-them-out-of-the-app)
2. [HUNCH's entire substitutable surface](#2-hunchs-entire-substitutable-surface)
3. [Fakes first](#3-fakes-first)
4. [The `unimplemented` double](#4-the-unimplemented-double)
5. [Structs of closures — `Now` and `SeedSource`](#5-structs-of-closures--now-and-seedsource)
6. [`isApproximatelyEqual`, on day one](#6-isapproximatelyequal-on-day-one)
7. [The fixture tree and the `.copy` trap](#7-the-fixture-tree-and-the-copy-trap)
8. [Migration fixtures and malformed siblings](#8-migration-fixtures-and-malformed-siblings)
9. [The banned list](#9-the-banned-list)

---

## 1. The two support targets, and the manifest shape that keeps them out of the app

`import Testing` must never reach a shipping target (`06 T5`) — test functions are not stripped from release binaries, so fixtures, builders and every `Issue.record` string ship to anyone who inspects the build product. But `06 T38` makes `Issue.record` mandatory in every `unimplemented` double, and `01 P20` requires shared fixtures to live in a `.target`, never a `.testTarget`. `06 T5a` resolves it: a plain `.target` **may** import `Testing`, under three mechanical conditions.

```swift
// HunchCore/Package.swift
products: [
    .library(name: "Glyphs", targets: ["Glyphs"]),
    .library(name: "Laws", targets: ["Laws"]),
    // … no HunchTestSupport entry, ever (condition 1)
],
targets: [
    .target(name: "Laws", dependencies: ["Glyphs"], swiftSettings: swiftSettings),
    .target(name: "HunchTestSupport", dependencies: ["Glyphs", "Laws", "LawGeneration", "Persistence"],
            swiftSettings: swiftSettings),
    .testTarget(name: "LawGenerationTests",
                dependencies: ["LawGeneration", "HunchTestSupport"],   // test targets only (condition 2)
                resources: [.copy("Fixtures")],
                swiftSettings: swiftSettings),
]
```

1. **Absent from `products:`.** No external consumer can name it.
2. **Named in `dependencies:` of test targets only** — never the app target's, never a shipping library target's, never transitively through one.
3. **CI asserts both against the manifest**, not against your memory. `swift package describe --type json` lists every target's `target_dependencies`; no non-test target may name a support target. That is check 4 of `Scripts/check-source-hygiene.sh` (`07 B34a`), and the build skill owns where it runs.

Get condition 2 wrong and you have caused exactly the failure `T5` warns about.

**`Modules/` needs its own.** `HunchTestSupport` is absent from `HunchCore`'s products, so nothing in the `Modules` package can import it — the deliberate cost of the two-package deviation (`08 §7.2`). Add `Modules/Sources/ModulesTestSupport/` under the same three conditions, carrying the mirrored tag declarations (`references/test-plan.md` §2) and any SwiftUI-side doubles. Do not solve this by exporting `HunchTestSupport` as a product; that breaks condition 1 and puts `import Testing` one careless `dependencies:` line away from the app.

## 2. HUNCH's entire substitutable surface

Four seams. That is the whole list, and it is short because `08 §4` and `08 §5` designed most dependencies out rather than injecting them.

| Seam | Type | Live | Test | Shape |
|---|---|---|---|---|
| Persistence | `protocol PersistenceStore: Sendable` | `actor FilePersistenceStore` | `InMemoryPersistenceStore` (**ships**), `UnimplementedPersistenceStore` (support target) | protocol — many members (`06 T39`) |
| Cues | `protocol CuePlayer: Sendable` | `SynthesizedCuePlayer` + `HapticCuePlayer` | `SilentCuePlayer` (**ships**) | protocol |
| Dates | `struct Now: Sendable` | `.live` | `.fixed(_:)` | struct of one closure |
| Seeds | `struct SeedSource: Sendable` | `.live` | `.fixed(_:)` | struct of one closure |

There is no clock seam, no network seam, no RNG seam. The RNG is a parameter (`references/determinism.md` §1); the network does not exist; time was designed out.

`InMemoryPersistenceStore` and `SilentCuePlayer` **ship in the app** and import no `Testing` — previews use them, and `AppDependencies.preview(seed:date:)` composes them with `Now.fixed` and `SeedSource.fixed` into a deterministic graph (`08 §6`). Only the `Issue.record`ing doubles live in a support target. Keeping that line straight is what lets previews be real without dragging test code into the binary.

## 3. Fakes first

Hand-write them; take no mocking framework (`06 T36`). The compiler *is* the codegen — conform a type and it lists the missing members, so adding a protocol member makes every double fail to build, which is the property a generated mock cannot give you.

Default to a **fake**: a real, working, in-memory implementation, so assertions land on resulting state rather than on recorded calls. `verify(save(any()))` fails on refactors that change nothing observable; `#expect(await store.present.count == 2)` survives them.

```swift
// HunchCore/Sources/Persistence/InMemoryPersistenceStore.swift  — ships; imports no Testing
public actor InMemoryPersistenceStore: PersistenceStore {
    private var files: [StoreFile: Data]

    public init(_ seed: [StoreFile: Data] = [:]) { files = seed }

    public func load(_ file: StoreFile) throws -> Data {
        guard let data = files[file] else { throw StoreError.missing(file) }
        return data
    }

    public func save(_ data: Data, to file: StoreFile) { files[file] = data }
    public func remove(_ file: StoreFile) { files[file] = nil }

    public var present: Set<StoreFile> { Set(files.keys) }   // introspection, for assertions
}
```

Regenerate the member list from `HunchCore/Sources/Persistence/PersistenceStore.swift` rather than from this file — the protocol there is authoritative, and a double that has drifted from it will not compile, which is the point.

Use a **stub** (canned answers, no assertions) for a dependency whose output you are varying, and a **spy** only where the call *is* the observable behaviour. In HUNCH that is `CuePlayer` and nothing else: whether a verdict fired the admit cue is a real requirement, and a recording `SpyCuePlayer` is the only way to assert it. Make it thread-safe — it will be written from parallel tests, and an unprotected `var calls: [Cue]` in a spy is the classic flake.

## 4. The `unimplemented` double

The highest-value double and the one people skip (`06 T38`). It is how you discover that a "unit" test is quietly hitting the store, and it is the answer to the standing objection to hand-written fakes — a new protocol member defaults to failing loudly instead of silently passing.

```swift
// HunchCore/Sources/HunchTestSupport/Unimplemented.swift
import Foundation
import Persistence
import Testing

public struct UnimplementedError: Error {}

public struct UnimplementedPersistenceStore: PersistenceStore {
    public init() {}

    public func load(_ file: StoreFile) async throws -> Data {
        Issue.record("PersistenceStore.load(\(file)) was called unexpectedly")
        throw UnimplementedError()
    }

    public func save(_ data: Data, to file: StoreFile) async throws {
        Issue.record("PersistenceStore.save(to: \(file)) was called unexpectedly")
        throw UnimplementedError()
    }

    public func remove(_ file: StoreFile) async throws {
        Issue.record("PersistenceStore.remove(\(file)) was called unexpectedly")
        throw UnimplementedError()
    }
}
```

Use it as the default in any test that should not touch storage — a `Ladder` estimator test, a `RoundPhase` transition test — and the day someone adds a save to a pure path, the test names it.

## 5. Structs of closures — `Now` and `SeedSource`

For a seam of one to three members, a struct of closures beats a protocol (`06 T39`): a test overrides one endpoint and leaves the rest alone, with no fake type per permutation.

```swift
public struct SeedSource: Sendable {
    public var next: @Sendable () -> UInt64

    public static let live = Self { SystemRandomNumberGenerator().next() }
    public static func fixed(_ seed: UInt64) -> Self { Self { seed } }
}
```

`SeedSource` is where "no singletons" actually bites (`08 §6`): it is the single point at which the app becomes nondeterministic, it lives in `Modules/`, and that is exactly why check 6's grep bans `SystemRandomNumberGenerator` from `HunchCore/Sources/` outright. `04 A29`'s rule is not "no singletons" but "no singleton inside a boundary you test across" — this is that boundary, made one line wide.

The cost is honest: worse autocomplete, no `extension` default implementations, less discoverable. Worth it at two members; not worth it at ten, which is why `PersistenceStore` is a protocol.

## 6. `isApproximatelyEqual`, on day one

`06`'s migration table records that `XCTAssertEqual(_:_:accuracy:)` has **no Swift Testing equivalent**, and `swift-numerics` is banned (`08 §7.9`). This project compares floating point constantly — δ, θ, π₀, Spearman ρ, the G8 tolerance — so write it before the first `#expect(a == b)` on a `Double` ships, not after.

```swift
// HunchCore/Sources/HunchTestSupport/ApproximateEquality.swift
public func isApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    absoluteTolerance: Double,
    relativeTolerance: Double = 0
) -> Bool {
    if a == b { return true }                       // covers ±infinity
    guard a.isFinite, b.isFinite else { return false }   // NaN is never equal to anything
    let difference = (a - b).magnitude
    return difference <= absoluteTolerance
        || difference <= relativeTolerance * Swift.max(a.magnitude, b.magnitude)
}
```

Pair it with the `expectApproximatelyEqual` helper in `references/swift-testing-mechanics.md` §6, which forwards `#_sourceLocation` so the failure points at the caller.

`#expect(a == b)` on two `Double`s is a defect even when it passes today. State the tolerance and state why it is that number.

## 7. The fixture tree and the `.copy` trap

**This is where fixture suites die** (`06 T54`, `07 B22`). `.copy(_:)` is verbatim and **preserves the directory**; `.process(_:)` **flattens** to the bundle root. HUNCH declares `resources: [.copy("Fixtures")]`, so a file lands at `Fixtures/checkout.json` and a bare `url(forResource:withExtension:)` returns `nil` — every `#require` in the suite fails at once, and the symptom looks like a missing file rather than a wrong lookup.

`.copy` is right here even though `.process` is the general default: the persistence fixture is a whole `Application Support/Hunch/` tree whose directory structure is the thing under test, and the `subdirectory:` argument documents where it lives.

**`Fixture` lives in a support target, so it cannot use `#bundle` itself.** `#bundle` expands to *the enclosing target's* bundle, and the resources are declared on the test targets — so an accessor in `HunchTestSupport` that says `#bundle` looks in the wrong bundle and returns `nil` from every lookup. Symptom identical to the `.copy` trap, cause completely different. The accessor takes the bundle; each call site passes its own.

```swift
// HunchCore/Sources/HunchTestSupport/Fixture.swift
import Foundation
import Testing

public enum Fixture {
    private static let directory = "Fixtures"      // matches resources: [.copy("Fixtures")]

    public static func url(
        _ name: String,
        ext: String = "json",
        in bundle: Bundle,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> URL {
        try #require(
            bundle.url(forResource: name, withExtension: ext, subdirectory: directory),
            "No fixture named \(name).\(ext) in \(directory)/",
            sourceLocation: sourceLocation
        )
    }

    public static func data(
        _ name: String,
        ext: String = "json",
        in bundle: Bundle,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Data {
        try Data(contentsOf: url(name, ext: ext, in: bundle, sourceLocation: sourceLocation))
    }

    /// Migration opens its store read-write, so copy somewhere writable first.
    public static func copyToTemporaryDirectory(
        _ name: String,
        ext: String,
        in bundle: Bundle,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> URL {
        let source = try url(name, ext: ext, in: bundle, sourceLocation: sourceLocation)
        let destination = URL.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}

// Call site, inside a test target — #bundle here is the test target's own bundle:
let data = try Fixture.data("determinism-seeds-v1", in: #bundle)
```

`#bundle`, not `Bundle.module` (`01 P36`, `07 B22`). One caveat worth knowing before it bites: `#bundle` carries `@available(iOS 15, macOS 12, …)`, so a package with no `platforms:` floor fails with *"'bundle()' is only available in macOS 12 or newer"* — naming **macOS**, because `swift test` builds for the host. `HunchCore/Package.swift` declares `platforms: [.iOS(.v18), .macOS(.v15)]`, which is what fixes it; adding only an iOS floor leaves the message exactly where it was.

## 8. Migration fixtures and malformed siblings

**A fixture must have been produced by a shipped binary** (`06 T56`). A store file your current code wrote proves nothing: it was written by the schema you are migrating *to*. Keep one directory per shipped version, forever, and name it for the version: `Fixtures/v1/`, `Fixtures/v2/`.

**Every decoding fixture gets a malformed sibling** asserting a *specific typed error* (`06 T55`). "It decodes the happy path" is half a test, and in HUNCH the other half is a stated product behaviour: a truncated `codex-b4.json` must quarantine and rebuild, not crash. Assert the resulting `StoreHealth`, not merely that something threw.

```swift
@Test("A truncated shelf quarantines and rebuilds rather than throwing to the caller",
      .tags(.unit, .presubmission), .storeSandbox)
func truncatedShelfQuarantines() async throws {
    let url = try Fixture.copyToTemporaryDirectory("codex-b4.truncated", ext: "json", in: #bundle)
    let store = FilePersistenceStore(directory: StoreSandbox.root)
    try await store.install(url, as: .codexShelf(.relational))

    let health = await store.health
    #expect(health == .quarantined(.codexShelf(.relational)))
    #expect(await store.present.contains(.codexIndex))     // the index survived the quarantine
}
```

The fixture tree is otherwise governed by the three assertions in `references/test-plan.md` §8.

## 9. The banned list

No third-party dependencies, and these are the ones a testing task will reach for. Each has a named replacement, so "there was no alternative" is never true.

| Wanted | Banned | Instead |
|---|---|---|
| `TestClock` | `swift-clocks` | there is no clock — the timing was designed out (`08 §5`) |
| `.json` snapshots | `swift-snapshot-testing` | hand-rolled golden fixtures, `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])` |
| image snapshots | `swift-snapshot-testing` | the DEBUG snapshot gallery plus phase-7 manual review in en/de/ar, which the brief mandates anyway |
| `accuracy:` comparison | `swift-numerics` | `isApproximatelyEqual`, §6 |
| generated mocks | any mocking framework | hand-written fakes, §3 (`06 T36`) |
| unimplemented defaults | `swift-dependencies` | `UnimplementedPersistenceStore`, §4 |
| property-based generators | SwiftCheck, `swift-property-based`, SwiftQC | `@Test(arguments:)` over a seeded corpus (`06 T53`), plus the promotion discipline that replaces shrinking |
| view-tree assertions | ViewInspector | test the `@Observable` model; `06 §21.3` refuses it on merits independently of the ban |
