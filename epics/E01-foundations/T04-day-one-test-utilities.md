# T04 — Day-one test utilities in `HunchTestSupport`

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T03, T05 |
| **Delivers** | Fast loop (§14.1 VERIFICATION) |
| **Status** | not started |

> **Order note.** T04 runs **after** T05 because `Corpora.seed(band:index:)` is a `SplitMix64` derivation.

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | It owns all three utilities: `references/doubles-and-fixtures.md` §4 (the `unimplemented` double) and §6 (`isApproximatelyEqual`, five lines, written **before** the first `#expect` on a `Double` ships), `references/determinism.md` §2 (the `Corpora` seed derivation), `references/swift-testing-mechanics.md` §6 (`#_sourceLocation`, with the underscore). |

## Objective

`HunchTestSupport` gains the three things every later suite depends on and none of which can be added retroactively without rewriting assertions: a hand-rolled `isApproximatelyEqual` (because `swift-numerics` is banned and Swift Testing has no `accuracy:` overload), `Issue.record`-ing `unimplemented` doubles, and `Corpora`, which owns the corpus size and the `(band, index) → seed` derivation so that every future failure message is a complete reproduction.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §7.9 | The ruling: `swift-numerics` is banned, `XCTAssertEqual(_:_:accuracy:)` has **no** Swift Testing equivalent, and this project compares floating point constantly (δ, θ, π₀ = 0.44, Spearman ρ, the ±0.02 G8 tolerance). Write the five lines on day one. |
| `ios-swift-guide/06-TESTING.md` | `T17`, `T36`, `T38`, `T53` | Forward `SourceLocation` from every helper; no mocking framework; every dependency gets an `unimplemented` default that fails when touched; promote every found failure into a named case. |
| `hunch-swift-testing` | `references/doubles-and-fixtures.md` §4, §6, §9 | The double's shape, the comparison's shape, and the banned list with a named replacement for each. |
| `hunch-swift-testing` | `references/determinism.md` §2 | `Corpora` owns the derivation so a corpus is reproducible from `(band, index)` and nothing else. `static let`, never `static var`. |
| `GAME_DESIGN.md` | §5.7, §14.1 | The 10,000-law-per-band corpus size this file becomes the code-side home of. |

## TDD — the test comes first

**Step 1 — write the failing tests.** Three files, one per utility, path-mirrored (`06 T5b`).

`HunchCore/Tests/HunchTestSupportTests/ApproximateEqualityTests.swift`:

```swift
import Testing
import HunchTestSupport

/// `#expect(a == b)` on two Doubles is a defect even when it passes today. This suite pins the
/// four behaviours every later float assertion in the project inherits — and the two edge cases
/// (NaN, ±infinity) that a naive `abs(a - b) <= tol` gets wrong.
@Suite("Approximate equality", .tags(.unit, .presubmission))
struct ApproximateEqualityTests {
    @Test("Bit-identical values are equal at zero tolerance")
    func exactValuesAreEqualAtZeroTolerance() {
        #expect(isApproximatelyEqual(0.3, 0.3, absoluteTolerance: 0))
        #expect(isApproximatelyEqual(-0.0, 0.0, absoluteTolerance: 0))
    }

    @Test("Values inside the absolute tolerance are equal, outside are not")
    func absoluteToleranceIsInclusive() {
        #expect(isApproximatelyEqual(0.44, 0.45, absoluteTolerance: 0.01))
        #expect(!isApproximatelyEqual(0.44, 0.46, absoluteTolerance: 0.01))
    }

    @Test("The classic accumulation the operator == gets wrong")
    func floatingPointAccumulation() {
        #expect(0.1 + 0.2 != 0.3)
        #expect(isApproximatelyEqual(0.1 + 0.2, 0.3, absoluteTolerance: 1e-12))
    }

    @Test("Relative tolerance scales with magnitude; the default of 0 disables it")
    func relativeTolerance() {
        #expect(!isApproximatelyEqual(1_000_000, 1_000_001, absoluteTolerance: 0.5))
        #expect(isApproximatelyEqual(1_000_000, 1_000_001, absoluteTolerance: 0.5, relativeTolerance: 1e-5))
    }

    @Test("NaN is never approximately equal to anything, including itself")
    func nanIsNeverEqual() {
        #expect(!isApproximatelyEqual(.nan, .nan, absoluteTolerance: .infinity))
        #expect(!isApproximatelyEqual(.nan, 0, absoluteTolerance: .infinity))
    }

    @Test("Infinities equal themselves and nothing else")
    func infinities() {
        #expect(isApproximatelyEqual(.infinity, .infinity, absoluteTolerance: 0))
        #expect(!isApproximatelyEqual(.infinity, -.infinity, absoluteTolerance: .infinity))
        #expect(!isApproximatelyEqual(.infinity, .greatestFiniteMagnitude, absoluteTolerance: .infinity))
    }

    @Test("The expect- helper records an issue at the CALLER's line, not its own")
    func helperRecordsAtTheCaller() {
        withKnownIssue("deliberately outside tolerance") {
            expectApproximatelyEqual(0.44, 0.50, absoluteTolerance: 0.01)
        }
    }
}
```

`HunchCore/Tests/HunchTestSupportTests/UnimplementedTests.swift`:

```swift
import Testing
import HunchTestSupport

/// The highest-value double and the one people skip (06 T38). It is how you discover that a
/// "unit" test is quietly hitting the store, and it is the answer to the standing objection to
/// hand-written fakes: a new protocol member defaults to failing loudly.
@Suite("Unimplemented doubles", .tags(.unit, .presubmission))
struct UnimplementedTests {
    @Test("Calling an unimplemented member records an issue and throws")
    func recordsAndThrows() {
        var thrown: UnimplementedError?
        withKnownIssue("the double is supposed to record") {
            do { try unimplemented("PersistenceStore.load(_:)") }
            catch let error as UnimplementedError { thrown = error }
            catch { Issue.record("threw the wrong error type") }
        }
        #expect(thrown == UnimplementedError("PersistenceStore.load(_:)"))
    }

    @Test("The non-throwing form still records, and returns the caller's placeholder")
    func nonThrowingFormRecords() {
        var value = 0
        withKnownIssue { value = unimplemented("Ladder.ability", returning: 42) }
        #expect(value == 42)
    }

    @Test("The error's description names the member, so a CI log is diagnosable")
    func descriptionNamesTheMember() {
        #expect(UnimplementedError("Codex.page(for:)").description.contains("Codex.page(for:)"))
    }
}
```

`HunchCore/Tests/HunchTestSupportTests/CorporaTests.swift`:

```swift
import Testing
import HunchTestSupport

/// `Corpora` is the authoritative home of the corpus size and of the (band, index) → seed
/// derivation. Both are frozen here rather than in a test, because a failure message that says
/// "reproduce with Corpora.seed(band: 4, index: 8117)" is only a reproduction while the
/// derivation is stable. E05·T06 changes the parameter type from `Int` to `Band`; these vectors
/// are what prove that change moved no bits.
@Suite("Corpora", .tags(.unit, .presubmission))
struct CorporaTests {
    @Test("The corpus size is the brief's, and lives here rather than in a literal")
    func corpusSize() {
        #expect(Corpora.lawsPerBand == 10_000)
    }

    @Test("The derivation is frozen — these vectors must survive the Band signature change")
    func derivationIsFrozen() {
        #expect(Corpora.seed(band: 1, index: 0) == 0xE6AA_C108_7DE6_1679)
        #expect(Corpora.seed(band: 1, index: 1) == 0x221A_2037_83C6_9578)
        #expect(Corpora.seed(band: 8, index: 0) == 0x49C4_72CB_21F7_CA72)
    }

    @Test("The seed is a pure function of (band, index)")
    func isPure() {
        #expect(Corpora.seed(band: 5, index: 99) == Corpora.seed(band: 5, index: 99))
    }

    @Test("No two of the first 512 seeds collide within a band, and no band shares one")
    func seedsAreDistinct() {
        let withinOneBand = Set((0..<512).map { Corpora.seed(band: 4, index: $0) })
        #expect(withinOneBand.count == 512)
        let acrossBands = Set((1...8).map { Corpora.seed(band: $0, index: 0) })
        #expect(acrossBands.count == 8)
    }
}
```

**Step 2 — run them and watch them fail.** `swift test --package-path HunchCore --filter HunchTestSupportTests`

Every suite fails on a missing symbol — `cannot find 'isApproximatelyEqual' in scope`, `cannot find 'unimplemented' in scope`, `cannot find 'Corpora' in scope`. The three frozen vectors in `derivationIsFrozen` are the exception: they will fail with *wrong numbers* if you write the derivation differently from `determinism.md` §2, which is exactly what they are for. Do not "fix" them by pasting whatever the implementation printed — the derivation is the thing under test.

**Step 3 — implement** the three source files below.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/HunchTestSupport/ApproximateEquality.swift` |
| create | `HunchCore/Sources/HunchTestSupport/Unimplemented.swift` |
| create | `HunchCore/Sources/HunchTestSupport/Corpora.swift` |
| create | `HunchCore/Tests/HunchTestSupportTests/ApproximateEqualityTests.swift` |
| create | `HunchCore/Tests/HunchTestSupportTests/UnimplementedTests.swift` |
| create | `HunchCore/Tests/HunchTestSupportTests/CorporaTests.swift` |
| modify | `HunchCore/Package.swift` — add `"LawGeneration"` to `HunchTestSupport`'s `dependencies:` |

## Implementation notes

### `ApproximateEquality.swift`

The comparison is `doubles-and-fixtures.md` §6's, verbatim, and the helper is `swift-testing-mechanics.md` §6's, verbatim. Two functions, no more:

```swift
public import Testing

/// Hand-rolled because `swift-numerics` is a third-party dependency and the brief bans them,
/// and because `XCTAssertEqual(_:_:accuracy:)` has no Swift Testing equivalent (08 §7.9).
public func isApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    absoluteTolerance: Double,
    relativeTolerance: Double = 0
) -> Bool {
    if a == b { return true }                            // covers ±infinity and ±0
    guard a.isFinite, b.isFinite else { return false }   // NaN is never equal to anything
    let difference = (a - b).magnitude
    return difference <= absoluteTolerance
        || difference <= relativeTolerance * Swift.max(a.magnitude, b.magnitude)
}

public func expectApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    absoluteTolerance: Double,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) { … }
```

Three details that are not decoration:

- **The `a == b` early return comes first**, before the finiteness guard, because `.infinity == .infinity` must be `true` while `.infinity - .infinity` is `NaN` and would fail every comparison below it.
- **`#_sourceLocation`, with the underscore.** The unprefixed `#sourceLocation` is the compiler's line-control directive and does not even parse in that position. Without the forward, every float failure in the project points at this file instead of at the test (`06 T17`).
- **`Swift.max`, not `max`.** `HunchTestSupport` will eventually be imported alongside modules that define their own `max`-shaped helpers; the qualified spelling costs six characters and removes a whole class of ambiguity.

`#expect(a == b)` on two `Double`s is a defect even when it passes. Every use site states its tolerance **and why it is that number** — the ±0.02 in G8 is `GAME_DESIGN.md` §5.3's, the 0.03 around 0.80 is §14.3's, and neither is a taste.

### `Unimplemented.swift`

```swift
public import Testing

public struct UnimplementedError: Error, CustomStringConvertible, Equatable {
    public let member: String
    public init(_ member: String) { self.member = member }
    public var description: String { "\(member) was called unexpectedly" }
}

/// Records an issue against the CALLING test and throws (06 T38).
public func unimplemented(
    _ member: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> Never { … }

/// For members that cannot throw. Records, then returns the caller's placeholder.
public func unimplemented<T>(
    _ member: String,
    returning value: T,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T { … }
```

This task ships the **mechanism**, not the conformances. `UnimplementedPersistenceStore` needs `protocol PersistenceStore`, which is E07·T01; that task writes the conformance using these two functions, and `doubles-and-fixtures.md` §4 shows its exact shape. Writing a placeholder protocol here to hang a double off would invent a boundary whose shape has not been learned (`01 P12`).

`import Testing` in a shipping-shaped `.target` is safe only under `06 T5a`'s three conditions, all of which T03 already established and check 4 (T06) asserts every build. If you find yourself wanting these helpers from a non-test target, the file is in the wrong target.

### `Corpora.swift`

```swift
internal import LawGeneration

public enum Corpora {
    /// The brief's invariant-1 count. The single authoritative home: tests cite this, never a
    /// literal (`hunch-swift-testing`, *Never* — "never restate a value that lives in Swift").
    public static let lawsPerBand = 10_000

    /// Reproducible from `(band, index)` alone, so a failure message is a complete repro.
    ///
    /// - Note: `band` is an `Int` only until `Band` exists (E05·T06), at which point the
    ///   parameter type changes to `Band` and the body reads `UInt64(band.rawValue)`. `Band`'s
    ///   raw values are 1…8, so the change moves no bits — `CorporaTests.derivationIsFrozen`
    ///   is what proves it.
    public static func seed(band: Int, index: Int) -> UInt64 {
        var rng = SplitMix64(seed: 0xC0FF_EE00_0000_0000 ^ UInt64(band))
        for _ in 0..<index { _ = rng.next() }
        return rng.next()
    }
}
```

- **`internal import LawGeneration`.** Nothing in `Corpora`'s public signature mentions a `LawGeneration` type — `seed` returns a `UInt64` — so the import stays internal, which is what lets the compiler skip rebuilding this module when `LawGeneration` changes internally (`07 B7a`).
- **`static let`, never `static var`.** Tests run in parallel *in one process* (`06 T10`), so a `static var` here is a data race across every test in the suite, not merely an ordering hazard. The one sanctioned shape is a `let` of an immutable `Sendable` value.
- **The stepped derivation is O(index) and that is fine at these counts** (`determinism.md` §2). If it ever measures, replace the body with a mix of `(band, index)` — no test changes, because they only ever say `Corpora.seed(band:index:)`. If you do, the frozen vectors change and that is a deliberate act with a `DECISIONS.md` entry, exactly like re-recording a golden fixture.
- **`Corpora.index` — the `LawIndex` static let built once for the whole suite — is E05·T07's** and is the single largest thing standing between this project and its ten-second budget. Do not stub it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore` is green with 23 tests (3 tag + 6 SplitMix64 + 7 approximate-equality + 3 unimplemented + 4 corpora), and the whole run is under 2 s.
- [ ] `swift test --package-path HunchCore --filter CorporaTests` passes **with the vectors written before the implementation**, unmodified.
- [ ] `grep -rn 'accuracy:' HunchCore Modules` returns nothing (that spelling is XCTest's and does not exist here).
- [ ] `grep -rn 'import Numerics\|swift-numerics' .` returns nothing outside the guide files.
- [ ] `grep -rn 'static var' HunchCore/Sources` returns nothing.
- [ ] `grep -rn '#sourceLocation' HunchCore` returns nothing (only `#_sourceLocation`, with the underscore).
- [ ] `swift package describe --package-path HunchCore --type json | jq -r '.targets[] | select(.name=="HunchTestSupport") | .target_dependencies[]'` is exactly `LawGeneration`.
- [ ] Check 4's query still prints nothing: no product and no non-test target names `HunchTestSupport`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still nowhere near 10 s.
2. **Run `/simplify`** — likely targets are the two `unimplemented` overloads (they are not duplication: one returns `Never`, one returns `T`, and collapsing them loses the `Never` at every throwing call site) and the early-return ordering in `isApproximatelyEqual` (which is load-bearing; see above). Re-run the tests after it.
3. **Run `/code-review`** — the findings that matter are a missing `sourceLocation` forward, a `static var`, and a `public import` that should be `internal` or the reverse.
4. Commit: `git commit -m "E01/T04: isApproximatelyEqual, the unimplemented doubles and Corpora"`

## Out of scope

- **`UnimplementedPersistenceStore`** — E07·T01, which is where `PersistenceStore` is declared.
- **`InMemoryPersistenceStore`** — E07·T03. It **ships** in the app and imports no `Testing`; only the `Issue.record`ing doubles live here. Keeping that line straight is what lets previews be real without dragging test code into the binary.
- **`Fixture` (the `subdirectory:`-passing accessor)** — E06·T10 and E07·T05 add it with the first fixture tree. It takes a `Bundle` parameter rather than using `#bundle`, because `#bundle` expands to the *enclosing target's* bundle and the resources are declared on the test targets.
- **`Corpora.index` and `Corpora.knownBadSeeds`** — E05·T07 and E06·T09.
- **`SpyCuePlayer`** — E20·T01, the only place a spy is the right double in this project.
- **`ModulesTestSupport`** — E03·T06, which mirrors the eight tags and any SwiftUI-side doubles. Do not solve `Modules`' need for these helpers by exporting `HunchTestSupport` as a product; that breaks `06 T5a` condition 1.
