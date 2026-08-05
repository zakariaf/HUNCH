# Swift Testing mechanics, as HUNCH writes them

1. [The shape of a suite](#1-the-shape-of-a-suite)
2. [`#expect` versus `#require`](#2-expect-versus-require)
3. [Keeping effects out of the expectation](#3-keeping-effects-out-of-the-expectation)
4. [Parameterisation](#4-parameterisation)
5. [Traits](#5-traits)
6. [Helpers and `#_sourceLocation`](#6-helpers-and-_sourcelocation)
7. [Attachments and issue severity](#7-attachments-and-issue-severity)
8. [Known issues](#8-known-issues)
9. [Scoped setup — the `TestScoping` trait](#9-scoped-setup--the-testscoping-trait)
10. [Async, confirmations, continuations](#10-async-confirmations-continuations)
11. [Exit tests](#11-exit-tests)
12. [The XCTest boundary](#12-the-xctest-boundary)

The general rules and their reasoning are `06-TESTING.md`. This file is the HUNCH spelling: the forms you will actually type, with the project's own types in them.

---

## 1. The shape of a suite

```swift
// HunchCore/Tests/RoundsTests/RoundPhaseTests.swift
import Testing
import Rounds

@Suite("Round phase transitions", .tags(.unit, .presubmission))
struct RoundPhaseTests {
    @Test("A verdict during a locked window is ignored")
    func lockedWindowIgnoresVerdict() {
        let phase = RoundPhase.revealing
        #expect(transition(phase, on: .probe(.glyph0)) == .revealing)
    }
}
```

- A type containing `@Test` functions is already a suite; `@Suite` adds a display name or traits (`06 T6`).
- Default to `struct` (`06 T8`). Every instance-method test gets a fresh instance — that is the isolation guarantee, and `static var` defeats it (`06 T7`).
- `init() throws` is `setUp`. There is no `deinit` in this repo; see §9.
- Neither the suite nor any enclosing type may carry `@available` — the compiler rejects it (`06 T7`).
- Naming follows `02 §13`: short lowerCamelCase identifier asserting behaviour, no `test` prefix (`N43`), full sentence in `@Test("…")`. Suites are a plain noun ending in `Tests` (`N44`). Pick that form and stay on it — do not mix in raw identifiers, and never put both a raw identifier and a display string on one test.
- Nested suites express *conditions*, not units, and stay in one file (`06 T5b`): `struct RoundPhaseTests { struct WhenLocked { … }; struct WhenSealed { … } }`.
- **Import every module whose types the test names, including the ones it only names by inference.** `HunchCore` is eight source targets, so `generate(seed:band:targetDelta:mode:)` reaches across several — and under Swift 6's member-import-visibility rules a bare `.probe` still needs the module that declares `Mode` imported. The compiler offers a fix-it naming the module; take it rather than widening an existing import or, worse, moving the type.

**Main-actor isolation.** Swift Testing runs every test on an arbitrary task (`06 T9`). `HunchCore` targets are nonisolated by default (`08 §4`), so core suites need nothing. `Modules/` UI targets carry `.defaultIsolation(MainActor.self)` — **which does not propagate to their test targets.** Any suite constructing `Round`, `Codex`, `Ladder`, `Router` or a `View` annotates:

```swift
@Test @MainActor func probingAdvancesThePhase() { … }
```

or puts `@MainActor` on the suite type when every test needs it.

## 2. `#expect` versus `#require`

`#require` for the preconditions of the test; `#expect` for the assertions you came for (`06 T11`). `#expect` records and continues, so several failures report per run; `try #require` throws and returns the unwrapped value.

```swift
@Test func aBandCarriesItsAdmitWindow() throws {
    let band = try #require(Band(rawValue: 4))          // meaningless to continue if nil
    #expect(band.admitWindow.lowerBound > 0)
    #expect(band.admitWindow.upperBound < 1)            // still reported if the line above fails
}
```

Do not port `continueAfterFailure` (`06 T12`). Comparison of `Double`s uses `isApproximatelyEqual` from `HunchTestSupport` — `XCTAssertEqual(_:_:accuracy:)` has no Swift Testing equivalent and `swift-numerics` is banned (`08 §7.9`).

## 3. Keeping effects out of the expectation

Hoist every `await` and `try` out of `#expect`, or the macro cannot decompose the expression and you get source text back instead of runtime values (`06 T13`).

```swift
// ❌ Expectation failed: await store.load(.profile).axes.count == 5
#expect(await store.load(.profile).axes.count == 5)

// ✅ Expectation failed: (count → 4) == 5
let profile = try await store.load(.profile)
#expect(profile.axes.count == 5)
```

When an effect must stay inline, put `try`/`await` *inside* the argument list — `#expect(try h())`, not `try #expect(h())` (`06 T14`). Both compile; only the first decomposes.

Do not chain binary operators: `#expect(a && b && !c)` reports `a && b` and `!c` and does not recurse (`06 T15`). Split them; that is better failure isolation anyway.

## 4. Parameterisation

A `for` loop inside a test is a bug (`06 T21`) — **except** for the one documented deviation in SKILL.md, which is invariant 1 and the Bench fuzzer, and which pays the debt back with a reproducing seed plus an `Attachment`.

```swift
@Test("Every mode round-trips through its raw value", arguments: Mode.allCases)
func modeRoundTrips(_ mode: Mode) throws {
    #expect(Mode(rawValue: mode.rawValue) == mode)
}
```

- `zip()` when you mean pairs; two collections is the **Cartesian product** (`06 T22`). `arguments: Band.allCases, Mode.allCases` is 32 cases; `arguments: Band.allCases, 0..<10_000` is 80,000 runner nodes, which is exactly the trap that produced the deviation.
- Maximum two collections (`06 T24`). For three or more dimensions build a `[Case]` array of a small `Codable` struct — which reads better anyway, and is how `Corpora.knownBadSeeds` is shaped.
- Argument types must be `Codable`, or `RawRepresentable where RawValue: Encodable`, or `Identifiable where ID: Encodable` (`06 T23`) — otherwise a failing case cannot be re-run alone. Every HUNCH type you would parameterise over (`Band`, `Mode`, `Glyph`, `LawNode`, `StoreFile`) already qualifies; a bare tuple does not, so wrap it.

```swift
extension Corpora {
    public struct KnownBadSeed: Codable, Sendable, CustomStringConvertible {
        public let band: Band
        public let index: Int
        public let note: String
        public var description: String { "band \(band) index \(index) — \(note)" }
    }
}
```

## 5. Traits

| Trait | HUNCH use | Watch |
|---|---|---|
| `.tags(.unit, .presubmission)` | on every suite, both axes | inert metadata; the *runner* filters |
| `.enabled(if:)` | the Level-B calibration gate | evaluated possibly more than once — keep it cheap and pure |
| `.timeLimit(.minutes(15))` | hang guard on the nightly matrix | `.minutes` is the only factory; not a performance assertion (`06 T26`) |
| `.disabled("reason")` | almost never — prefer `withKnownIssue` | pair with `.bug(id:)` |
| `.bug(id:)` | on every known issue and every disabled test | URL must be RFC 3986-parseable |
| `.serialized` | **nowhere** | if it fixes a flake you found shared state (`06 T27`) |

Traits go after the display name (`06 T25`). Several conditions must all pass; the first failing one is reported as the skip reason.

## 6. Helpers and `#_sourceLocation`

Every helper that records an issue forwards a `SourceLocation`, or the failure points at the helper instead of the caller (`06 T17`). **The default value is `#_sourceLocation`, with the underscore** — the unprefixed `#sourceLocation` is the compiler's line-control directive.

```swift
// HunchCore/Sources/HunchTestSupport/ApproximateEquality.swift
import Testing

public func expectApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    absoluteTolerance: Double,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard !isApproximatelyEqual(a, b, absoluteTolerance: absoluteTolerance) else { return }
    Issue.record(
        comment ?? "\(a) and \(b) differ by \(abs(a - b)), tolerance \(absoluteTolerance)",
        sourceLocation: sourceLocation
    )
}
```

```swift
// ❌ XCTest-era signature — reports the helper's own line
func expectApproximatelyEqual(_ a: Double, _ b: Double, file: StaticString = #filePath, line: UInt = #line)
// ❌ does not parse — #sourceLocation is the compiler directive and needs (file:line:)
func expectApproximatelyEqual(_ a: Double, _ b: Double, sourceLocation: SourceLocation = #sourceLocation)
```

## 7. Attachments and issue severity

Attach the artefact that explains the failure instead of printing it (`06 T18a`). `print` output is not kept; a `.xcresult` attachment is.

```swift
import Foundation                    // the Attachable conformance for Encodable comes from here
import Testing

Attachment.record(law, named: "band\(band.rawValue)-index\(index).json")
```

Anything `Encodable` or `NSSecureCoding` is attachable for free once Foundation is imported — `LawNode`, `BenchLayout`, `RoundSnapshot`, `Profile`, `CodexPage` all qualify. `Law` does not: `08 §3` makes it deliberately non-`Codable`. Attach `law.node` or the `LawTable`'s raw words instead.

`Issue.record(_:severity: .warning)` (Swift 6.3+) records without failing. HUNCH uses it for near-threshold statistics — a calibration ρ between the target and the floor is a warning, below the floor is a failure — so drift is visible before it is blocking.

## 8. Known issues

```swift
withKnownIssue("Band-8 composites occasionally exceed the admit window", .bug(id: "HUNCH-142")) {
    try assertGuardrails(forBand: .systemic)
}
```

`withKnownIssue` beats commenting out, `.disabled` and `#expect(throws:)` because if the block *passes* it records a different issue telling you the bug may be fixed (`06 T35`). That ratchet is what stops known issues rotting into dead weight. Everything the block depends on must be **inside** it — errors are swallowed too. `isIntermittent: true` disables the ratchet, so set it only for a genuine flake, and always with `.bug(id:)`.

## 9. Scoped setup — the `TestScoping` trait

No `deinit` in this repo (`06 T20`). Scoped setup *and* teardown is a `TestScoping` trait, which is also the only mechanism that can bind a `@TaskLocal`. The persistence fixture tree uses exactly this:

```swift
// HunchCore/Sources/HunchTestSupport/StoreSandboxTrait.swift
import Foundation
import Testing

public enum StoreSandbox {
    @TaskLocal public static var root = URL.temporaryDirectory
}

public struct StoreSandboxTrait: TestTrait, SuiteTrait, TestScoping {
    public var isRecursive: Bool { true }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try await StoreSandbox.$root.withValue(url) { try await function() }
    }
}

extension Trait where Self == StoreSandboxTrait {
    public static var storeSandbox: Self { Self() }
}

@Suite("Persistence round-trip", .tags(.unit, .presubmission), .storeSandbox)
struct FilePersistenceStoreTests { … }
```

`UUID()` and `FileManager` here are fine: this is `HunchTestSupport`, not `HunchCore/Sources/*`, and check 6's grep is scoped to the latter (`08 §5`).

## 10. Async, confirmations, continuations

Default to plain `async`/`await`. `Confirmation` counts events that fire during an operation you are already awaiting; it does **not** wait (`06 T32`). HUNCH has almost no completion-handler surface — `CuePlayer` is `async`, `PersistenceStore` is an actor — so the honest answer is usually that you do not need either.

Never record an expectation from a detached `Task` after the test returns (`06 T34`); await the work you started. `XCTestExpectation` and `XCTWaiter` have no interop path, ever (`06 T33`) — they must be rewritten, not left alone. Nothing in this repo should introduce one.

## 11. Exit tests

`#expect(processExitsWith:)` covers a `precondition` body and **does not run on iOS** (`06 T49`). It is available here precisely because `HunchCore` is host-testable, which is one of the concrete arguments for the package split.

```swift
#if os(macOS)
@Test("Serving a band above the ladder ceiling traps", .tags(.unit, .presubmission))
func servingAboveCeilingTraps() async {
    let band = Band.systemic
    _ = await #expect(processExitsWith: .failure) { [band] in
        _ = ServingPolicy.serve(band: band, above: .systemic)    // hits precondition()
    }
}
#endif
```

The `#if os(macOS)` is not optional: the `Presubmission` plan also runs the package targets in the simulator, where the macro is unavailable. Captured values must be **both `Sendable` and `Codable`** — they are encoded, piped and decoded into a child process. Implicit capture is a compile error, and capture lists only work on Swift 6.3+; below that the macro silently captures nothing.

## 12. The XCTest boundary

`06 T43` names three things with no Swift Testing path, and one of them binds here: **UI automation.** Xcode's build system rejects `import Testing` in a UI test target outright, so `E03/HunchUITests/` is `XCTestCase` — the en/de/ar screenshot pass and `performAccessibilityAudit`, which is a method on `XCUIApplication`. `08 §7.10` rules that this is not a violation of the brief's "Swift Testing, not XCTest": the brief governs new unit tests, which all live in the two packages.

```swift
final class HunchScreenTests: XCTestCase {
    /// `XCUIApplication` is `@MainActor` and `XCTestCase.setUp()` is not, so the XCTest-era
    /// `let app = XCUIApplication()` + `setUp()` shape is an isolation error under Swift 6 —
    /// and `@MainActor override func setUp()` does not fix it, because an override cannot add
    /// isolation its superclass method lacks. Launch from a `@MainActor` factory instead.
    @MainActor
    private func launchedApp() -> XCUIApplication {
        continueAfterFailure = false                 // correct here, opposite of Swift Testing (06 T47)
        let app = XCUIApplication()
        app.launchArguments += ["-UITest", "-AppleAnimationsEnabled", "NO"]
        app.launch()
        return app
    }

    @MainActor
    func testFrameScreenshotsInEnglish() {
        let app = launchedApp()
        add(XCTAttachment(screenshot: app.screenshot()))
    }
}
```

Both frameworks may live in one test target; the only hard constraint is that a `@Test` cannot be declared inside an `XCTestCase` subclass (`06 T44`). On Xcode 27 set XCTest interoperability to **Complete** (`06 T46`) — before Swift 6.4 an `XCTAssert` failing inside a `@Test` function was silently dropped.
