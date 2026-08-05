# Testing

This file covers how to test an iOS app written in Swift: which tests to write and which to refuse, how to write them in Swift Testing, what stays in XCTest and why, how to keep the fast suite under ten seconds, and how to stop flakes at the source. Read it if you are writing tests, reviewing them, or deciding what a test target should contain. `01-PROJECT-STRUCTURE.md` owns where test targets live, `02-NAMING-AND-API-DESIGN.md` owns what tests are named, `04-ARCHITECTURE-AND-STATE.md` owns dependency injection as a design choice, `05-CONCURRENCY.md` owns isolation and `Sendable`, and `07-TOOLING-BUILD-AND-SHIPPING.md` owns schemes, test plans and CI wiring. This file owns the tests themselves.

---

## 0. Version ground truth (2026-07-27)

`05-CONCURRENCY.md §1` and `07-TOOLING-BUILD-AND-SHIPPING.md §0` carry the full toolchain baseline. The testing-specific availability facts, because almost every rule below is gated on one:

| Feature | First available | Note |
|---|---|---|
| Swift Testing | Swift 6.0 / Xcode 16 | |
| `TestScoping` traits (ST-0007) | Swift 6.1 / Xcode 16.3 | The setUp/tearDown replacement |
| `#expect(throws:)` returns the error (ST-0006) | Xcode 16.3 | |
| Ranged confirmations `expectedCount: 1...` (ST-0005) | Xcode 16.3 | |
| `xcodebuild -only-testing-tags` / `-skip-testing-tags` | Xcode 16.3 | |
| Exit tests `#expect(processExitsWith:)` (ST-0008) | Swift 6.2 / Xcode 26.0 | **Not available on iOS** |
| Raw identifiers in test names (SE-0451) | Swift 6.2 | |
| Exit-test capture lists (ST-0012) | Swift 6.3 | Below 6.3 the macro silently captures nothing |
| `Issue.record(_:severity: .warning)` (ST-0013) | Swift 6.3 | |
| `try Test.cancel(_:)` (ST-0016) | Swift 6.3 | 6.2 mishandles cancellation in some cases (swift-testing#1289) |
| Cross-platform image attachments | Swift 6.3 | |
| **XCTest ⟷ Swift Testing interop (ST-0021)** | **Swift 6.4 / Xcode 27** | Ships with Xcode 27; beta 4 as of today |
| Per-test-case repetition, `swift test --maximum-repetitions` (ST-0024) | Swift 6.4 | |
| `swift test --filter tag:` (ST-0025) | Accepted 2026-07-01, **ship version not stated** | Assume not in 6.3; verify before relying on it |
| `.taskLocal` trait (ST-0026) | **In review, review window closes today** | Treat as not shipped; hand-roll a `TestScoping` trait |

Stable today: Swift 6.3.3, Xcode 26.6 (contains Swift 6.3, iOS 26.5 SDK). Xcode 27 beta 4 contains Swift 6.4.

---

## 1. The decision procedure

Before writing a test, answer one question: *what is the cheapest thing that would have caught this bug?*

| The thing you want to verify | Write this | Not this |
|---|---|---|
| A pure function, a branch, a boundary case | Unit test on the function | A UI test that reaches it |
| A view model / reducer transition | Unit test driving the model directly | A view-tree assertion |
| Decoding a real server payload | Fixture test with a recorded, scrubbed payload | A live network test |
| Two of your own components cooperating | Integration test: real store, real decoder, fake network, fake clock | Mock-verified call sequences |
| Time-dependent behaviour (debounce, retry, timeout) | Unit test with a `TestClock` | `Task.sleep` and hope |
| A crash / `precondition` | Exit test — **only in a SwiftPM package tested on macOS** | Nothing; it stays uncovered |
| Visual regression in a design-system component | Image snapshot, one device, one type size, light+dark | Image snapshots of whole screens |
| The shape of encoded persisted data | `.json` snapshot with an explicit re-record step | Hand-written expected-JSON strings |
| Data migration from a shipped version | Migration test against a store file **produced by the shipped binary** | A store file your current code wrote |
| A revenue-critical end-to-end flow | One XCUITest | Twenty XCUITests |
| Anything Apple wrote | Nothing | A test for `JSONDecoder` |

**T1. Budget by layer, and enforce the budget with time, not with a ratio.** Unit tests: hundreds to thousands, whole suite **under 10 seconds**. Integration tests: tens, under 60 seconds. UI tests: single digits to low tens, CI only, never on ⌘U. The commonly-quoted 70/20/10 pyramid is community folklore, not Apple guidance — Apple's own framing is about *feedback speed*: one plan for the module you are working on, another for everything before submission. Optimise the number you can measure.

**Deviate upward on UI tests** when there is no other way to exercise a system integration (StoreKit purchase, push handling, widget/App Intent entry points), or when you are in a legacy codebase with no unit-testable seams and a handful of UI tests is the harness that lets you refactor safely. Delete them once the seams exist.

---

## 2. Architecture is the lever

**T2. You cannot test what you cannot construct.** Every `Date()`, `UUID()`, `URLSession.shared`, `UserDefaults.standard`, `FileManager.default`, `Task.sleep`, `.random(in:)` and singleton accessor written *inside* a type is a dependency you cannot replace, and therefore a test you cannot write. Grep for that list before you grep for missing tests. `04-ARCHITECTURE-AND-STATE.md` owns the injection mechanics.

**T3. Put the logic in SwiftPM package targets; leave the app target a thin shell.** Package tests build and run on macOS with no simulator and no host app — this is the single biggest lever on suite time, it is the only way to use exit tests, and it forces the dependency graph to be honest (if `CartFeature` cannot build without `Networking`, it was never a unit). **Cost:** a multi-module project is more setup, slower cold builds, and you will fight per-module resource bundles (`#bundle`, and the `.copy`/`.process` trap in T54). **Deviate** for a genuinely single-screen app you expect to stay that way.

**T4. Prefer plain `import` over `@testable import`.** `@testable` requires the Enable Testability build setting and is a licence to assert on implementation details, which is exactly what makes suites brittle. Use it when the alternative is widening real API for test-only reasons — but ask first whether the behaviour is observable through the public surface.

**T5. Never `import Testing` from a shipping target.** Apple is explicit: test functions are not stripped from release binaries, so your fixtures and logic ship to anyone who inspects the build product. Shared fakes and builders live in their own target (`CartTestSupport`), which test targets depend on and the app never links.

**T5a. `TestSupport` is a plain `.target` and it *may* `import Testing` — provided it is not a product and nothing the app links depends on it.** This is the one place T5 and `01-PROJECT-STRUCTURE.md P20` could be read as contradicting each other: P20 requires shared fixtures to live in a `.target` named `TestSupport`, never a `.testTarget` (test targets cannot be depended on), and T38 below makes `Issue.record` mandatory in every `unimplemented` double — which needs `import Testing`. Verified on Xcode 26.6: a plain `.target` that imports `Testing` builds and links fine. Three conditions make that safe, and all three are mechanical:

1. `TestSupport` is **absent from `products:`**. It is internal to the manifest, so no external consumer can even name it.
2. `TestSupport` appears in `dependencies:` of test targets **only** — never the app target's, never a shipping library target's, and never transitively through one.
3. CI asserts both of the above against the manifest rather than against your memory — `swift package describe --type json` lists every target's `target_dependencies`, and no non-test target may name `TestSupport`. `07-TOOLING-BUILD-AND-SHIPPING.md §9.1 (B34a)` owns that check and writes it out; it is one `jq` filter and it belongs in the same job as the other three source-hygiene checks.

```swift
// Package.swift — no product for TestSupport; only the test target depends on it.
products: [.library(name: "Cart", targets: ["Cart"])],
targets: [
    .target(name: "Cart", swiftSettings: swiftSettings),
    .target(name: "CartTestSupport", dependencies: ["Cart"], swiftSettings: swiftSettings),
    .testTarget(
        name: "CartTests",
        dependencies: ["Cart", "CartTestSupport"],
        swiftSettings: swiftSettings
    ),
]
```

Get condition 2 wrong and you have caused exactly the failure T5 warns about: every fake, every builder and every `Issue.record` string ships in the release binary. `01-PROJECT-STRUCTURE.md P3` — no file belongs to two targets — is what pushes people toward a shared target in the first place, which is why this needs saying out loud rather than being left implied.

**T5b. One suite per file, the file named for the suite, and the test path mirroring the source path.** `Sources/Cart/CartPricing.swift` → `Tests/CartTests/CartPricingTests.swift`; tests for `Foo+Bar.swift` go in `Foo+Bar Tests.swift`. `01-PROJECT-STRUCTURE.md §6` owns which *target* and which runner; this is the within-target rule, and its whole point is that "is this file covered?" becomes answerable from a directory listing instead of a grep. **Deviate** for nested suites that express conditions rather than units — `struct CartTests { struct WhenEmpty { … }; struct WhenAtMaxQuantity { … } }` stays in one file, because it is one unit under test.

---

## 3. The shape of a Swift Testing test

```swift
import Testing
import Cart                                 // plain import, not @testable — see T4

struct CartTests {                          // no base class, no @Suite needed
    let cart: Cart                          // fresh instance per test — see T7

    init() throws {                          // this is setUp
        cart = Cart(catalogue: .fixture)
    }

    @Test func emptyCartHasZeroTotal() {
        #expect(cart.total == .zero)
    }
}
```

**T6. A type containing `@Test` functions is already a suite.** Add `@Suite` only to set a display name or attach traits. Nested suites are just nested types.

**T7. Each instance-method test runs against a fresh instance of the suite type.** That is the isolation guarantee — do not defeat it with `static var`. Two hard constraints the compiler enforces: the suite needs a callable zero-argument initialiser (may be `private`, `async`, `throws`), and neither the suite nor any enclosing type may carry `@available`.

**T8. Default to `struct` suites.** Reach for `final class`/`actor` only when you need `deinit`, and read §7 before you do.

**T9. Swift Testing runs every test on an arbitrary task; XCTest ran synchronous tests on the main actor.** This is the number-one migration breakage. If the test touches UIKit, SwiftUI, or a `@MainActor` model, annotate it:

```swift
// ❌ Migrated from XCTest, compiles, then races or traps at runtime
@Test func selectingRowUpdatesTitle() {
    let model = CheckoutModel()      // @MainActor — now being constructed off the main actor
    model.select(.first)
    #expect(model.title == "First")
}

// ✅
@Test @MainActor func selectingRowUpdatesTitle() {
    let model = CheckoutModel()
    model.select(.first)
    #expect(model.title == "First")
}
```

**T10. Tests run in parallel by default, in one process.** Not simulator clones — task groups. Global mutable state is now a *data race*, not merely an ordering hazard. XCTest's default was serial, so a migrated suite that shared state will start failing; that is the migration working correctly.

**Naming** belongs to `02-NAMING-AND-API-DESIGN.md §13` — short lowerCamelCase identifier, full sentence in `@Test("…")`. Apple's own docs and WWDC26 material increasingly use raw identifiers instead (`@Test func \`returns nil when the cart is empty\`()`, Swift 6.2+). Both are defensible; follow `02` for consistency, and if you do adopt raw identifiers, note that backticks are not part of the symbol name for `-only-testing` / `--filter` purposes and never pass both a raw identifier and a display-name string.

---

## 4. `#expect` versus `#require`

**T11. `#require` for the preconditions of the test; `#expect` for the assertions you came for.** `#expect` records an issue and keeps going, so several failures report in one run — more information per run. `try #require` throws and stops the test, and `try #require(optional)` returns the unwrapped value.

```swift
@Test func returningCustomerRemembersUsualOrder() throws {
    let customer = try #require(Customer(id: 123))   // meaningless to continue if nil
    #expect(customer.usualOrder.itemCount == 2)      // the actual assertion
    #expect(customer.usualOrder.total == 14.50)      // still reported if the line above fails
}
```

**T12. `#require` replaces `continueAfterFailure = false`.** Do not port that flag. XCTest implemented it by throwing an Objective-C exception through Swift frames — undefined behaviour, and through an `async` function it typically terminates the process and takes the rest of the run with it.

### Migration mapping

| XCTest | Swift Testing |
|---|---|
| `XCTAssert(x)`, `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertNil(x)` / `XCTAssertNotNil(x)` | `#expect(x == nil)` / `#expect(x != nil)` |
| `XCTAssertEqual/NotEqual(x, y)` | `#expect(x == y)` / `#expect(x != y)` |
| `XCTAssertIdentical/NotIdentical(x, y)` | `#expect(x === y)` / `#expect(x !== y)` |
| `XCTAssertGreaterThan(x, y)` etc. | `#expect(x > y)` etc. |
| `XCTAssertThrowsError(try f())` | `#expect(throws: (any Error).self) { try f() }` |
| `XCTAssertThrowsError(try f()) { e in … }` | `let e = #expect(throws: (any Error).self) { try f() }` |
| `XCTAssertNoThrow(try f())` | `#expect(throws: Never.self) { try f() }` |
| `try XCTUnwrap(x)` | `try #require(x)` |
| `XCTFail("…")` | `Issue.record("…")` |
| `XCTExpectFailure` | `withKnownIssue { … }` |
| `XCTSkip` | `.disabled(…)` / `.enabled(if:)` trait, or `try Test.cancel(…)` |
| `XCTAssertEqual(x, y, accuracy: e)` | **No equivalent.** Use `isApproximatelyEqual` from swift-numerics |

---

## 5. Keep effects out of the expectation

**T13. Hoist every `await` and `try` out of `#expect`, or you lose the failure message.** The macros read syntax; they cannot see types or effects, so an expression containing an effect is not expanded and you get the source text back instead of the runtime values. The Swift Testing team's stated position is that this will not change.

```swift
// ❌  Expectation failed: await store.state.items.count == 3
#expect(await store.state.items.count == 3)

// ✅  Expectation failed: (count → 5) == 3
let items = await store.state.items
#expect(items.count == 3)
```

**T14. When you must keep the effect inline, put `try`/`await` *inside* the argument list.** Write `#expect(try h())`, not `try #expect(h())`.

This is a legibility rule, not a compiler rule, and the difference matters when you are reviewing someone's code. A target containing both spellings builds clean — I compiled exactly that against the swift-testing bundled in Xcode 26.6 (testing library 1902) and got zero errors and zero warnings. Do not send anyone hunting for a "No calls to throwing functions occur within 'try' expression" diagnostic; on the shipping toolchain there isn't one. The reason to prefer the inner form is T13's reason: the macro decomposes what is inside its argument list, so `try`/`await` written to the left leaves it an expression it will not break down, and the failure message degrades to source text.

**T15. Do not chain more than one binary operator inside `#expect`.** Operator folding means `#expect(x && y && !z)` reports values for `x && y` and `!z` only; it does not recurse. Split into separate expectations, which is better failure isolation anyway. (The full recursive breakdown shown in `ExpectationCapture.md` comes from swift-testing PR #840, which is **still open as of 2026-07-27** — do not expect that output.)

---

## 6. Errors, issues and helper functions

```swift
#expect(throws: PizzaError.outOfRange) { try order.add(topping: .mozzarella, toPizzasIn: -1..<0) }
#expect(throws: (any Error).self)      { try order.submit() }
#expect(throws: Never.self)            { try order.validate() }

// The matched error is returned, so assert on associated values
let error = #expect(throws: InvalidToppingError.self) {
    try Pizza.current.add(topping: .marshmallows)
}
#expect(error?.topping == .marshmallows)
#expect(error?.reason == .dessertToppingOnly)
```

**T16. To assert a call does *not* throw, just call it in a `throws` test.** `#expect(throws: Never.self)` records an issue and continues; a bare `try` stops the test at the point where continuing is pointless. Use `Never.self` only when you want the rest of the test to run regardless.

**T17. Helper functions must forward a `SourceLocation`, or every failure points at the helper. The default value is `#_sourceLocation`, with the underscore.**

```swift
// ❌ XCTest-era signature; under Swift Testing this reports the helper's own line
func assertUnique(_ fruits: [Fruit], file: StaticString = #filePath, line: UInt = #line) { … }

// ❌ does not parse: #sourceLocation is the *compiler directive* and needs (file:line:)
func assertUnique(_ fruits: [Fruit], sourceLocation: SourceLocation = #sourceLocation) { … }

// ✅ failure is attributed to the caller
func assertUnique(_ fruits: [Fruit], sourceLocation: SourceLocation = #_sourceLocation) {
    var seen = Set<String>()
    for name in fruits.map(\.name) where !seen.insert(name).inserted {
        Issue.record("Duplicate name: \(name)", sourceLocation: sourceLocation)
    }
}
```

The underscore is not a typo, and the underscored one is the *public* one. `#sourceLocation(file:line:)` is a Swift compiler line-control statement and has owned the unprefixed spelling since Swift 3, so swift-testing declares the macro twice: `_sourceLocation()`, plain `public`; and `sourceLocation()`, which is marked **`@_spi(Experimental)`** and whose own doc comment says you *"must specify a module selector … to avoid conflicting with the Swift compiler's `#sourceLocation(file:line:)` statement"* — that is, `#Testing::sourceLocation`. So: write `#_sourceLocation`. It is the spelling swift-testing itself uses as the default argument on `Issue.record`, `#expect`, `#require`, `Attachment.record` and every trait that reports a location. (Read off `Sources/Testing/SourceAttribution/SourceLocation+Macro.swift` and `Sources/Testing/Issues/Issue+Recording.swift` on `main`, 2026-07-27; the underscored spelling also compiles against Xcode 26.6.)

**T18. Use `severity: .warning` for signal you want visible but not blocking** (Swift 6.3+). `Issue.record("Pixel match 92%", severity: .warning)` does not fail the test; it is recorded in the results. This is ST-0013's own motivating example — fail a snapshot below 90% match, warn between 90 and 95%.

**T18a. Attach the artefact that explains the failure instead of printing it.** `Attachment.record(_:named:)` replaces `XCTAttachment`, and `import Foundation` gives free `Attachable` conformance to anything `Encodable` or `NSSecureCoding` (Swift 6.3 added cross-platform image attachments). The payoff is entirely on CI: a decoding failure whose result bundle contains the exact bytes is diagnosable from the build log; the same failure with a `print` in it is not, because nobody keeps stdout.

```swift
@Test func decodesRecordedCheckout() throws {
    let data = try Fixture.data("checkout.v2")
    do {
        _ = try JSONDecoder.api.decode(Order.self, from: data)
    } catch {
        Attachment.record(data, named: "checkout.v2.json")   // survives into the .xcresult
        throw error
    }
}
```

---

## 7. Lifecycle: `init`, and why not `deinit`

**T19. `init()` is `setUp`. Prefer not needing teardown at all** — value types, in-memory stores, OS-scoped temporary directories. **T20. When you genuinely need scoped setup *and* teardown, write a `TestScoping` trait (Swift 6.1+), not `deinit`.**

```swift
enum Sandbox {
    @TaskLocal static var root = URL.temporaryDirectory
}

struct TemporaryDirectoryTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try await Sandbox.$root.withValue(url) { try await function() }
    }
}

extension Trait where Self == TemporaryDirectoryTrait {
    static var temporaryDirectory: Self { Self() }
}

@Suite(.temporaryDirectory) struct FileStoreTests { … }
```

Apple's *shipped* migration guide still says to switch your suite to a `final class` and implement `deinit`. Apple's own unmerged branch (`dreisbach/weaken_recommendation_around_deinit`) softens that to "adopt structured concurrency … if teardown is necessary, `deinit` must be synchronous and non-throwing", and ST-0007's rationale is explicitly anti-`setUp`/`tearDown`: the pair *"encourages the use of global mutable state … and this limits the testing library's ability to parallelize test execution"*, and cannot bind a `@TaskLocal` at all. **Ruling: trait, not `deinit`.** `deinit` cannot be `async` or `throws` and its timing is refcount-dependent. **Cost:** roughly fifteen lines of boilerplate per trait — which is exactly what ST-0026's `.taskLocal` trait proposes to remove, and ST-0026 is still in review as of today.

---

## 8. Parameterized tests

**T21. A `for` loop inside a test is a bug.** One failing input reports as one failing test with no indication of which value broke.

```swift
// ❌ one test, hidden loop, opaque failure, serial
@Test func allFoodsAvailable() async throws {
    for food in Food.allCases {
        #expect(await FoodTruck(selling: food).cook(food))
    }
}

// ✅ one test case per argument: individually named, individually re-runnable, parallel
@Test("All foods available", arguments: Food.allCases)
func foodAvailable(_ food: Food) async throws {
    #expect(await FoodTruck(selling: food).cook(food))
}
```

Test cases of a parameterized function run in parallel with each other by default, each is a separate node in the Test navigator, and adding an enum case extends coverage for free.

**T22. `zip()` when you mean pairs; two collections when you mean the Cartesian product.** `arguments: Food.allCases, 1...100` is 5 × 100 = **500 invocations**. `arguments: zip(Food.allCases, 1...100)` is **five**, destructured automatically into the two parameters. Getting this wrong is the most common way a suite silently gains a thirty-second test.

**T23. Make argument types `Codable` (or `Identifiable` with an `Encodable` ID).** Selective re-run of one failing case requires each argument to conform to `CustomTestArgumentEncodable`, `RawRepresentable where RawValue: Encodable`, `Encodable`, or `Identifiable where ID: Encodable`, in that precedence order. Without it you cannot click one failing case and re-run it.

**T24. Maximum two collections.** The API offers one collection, two collections, and a `Zip2Sequence` overload. For three or more dimensions, build a `[Case]` array of a small `Codable` struct — which reads better anyway. Argument expressions may be prefixed with `try`/`await` and are evaluated lazily only if the test will run. Avoid enormous ranges: `0..<Int.max` will not finish.

---

## 9. Traits

| Trait | Use it for | Watch out |
|---|---|---|
| `.disabled("reason")` | Turning a test off with the reason in the report | Pair with `.bug(id:)` |
| `.enabled(if: cond)` | Environment/season/feature gating | Conditions may be evaluated **multiple times** — keep them cheap and pure |
| `.timeLimit(.minutes(n))` | Guarding against hangs | **`.minutes` is the only factory.** Not for micro-timeouts |
| `.serialized` | A test that owns a genuinely global resource | No effect on a non-parameterized function; recursive on suites |
| `.tags(.foo)` | Cross-cutting selection from the runner | Inert metadata; the *runner* filters |
| `.bug(id:)` / `.bug("url")` | Linking a disabled/known-issue test to the tracker | URL must be RFC 3986-parseable |
| `.compactMapIssues` / `.filterIssues` | Downgrading or dropping expected issue classes | Easy to silence real failures |

**T25. Traits go after the display name, and if a test has several conditions they must all pass.** The first failing condition is reported as the skip reason.

**T26. `.timeLimit` is a hang guard, not a performance assertion.** ST-0004 verbatim: *"not intended to be used to apply small timeouts to tests to ensure test runtime doesn't regress by small amounts … intended to guard against hangs and pathologically long running tests."* Applied to a suite it applies to *each* test; applied to a parameterized test, to *each invocation*. Shortest limit wins when several apply.

**T27. `.serialized` is a diagnostic, not a cure.** If adding it fixes a flake, you have found shared mutable state — go fix the state. Serial tests are slower and, worse, they mask concurrency bugs in the product. **Deviate** for a test that must own a real on-disk database at a fixed path or an OS-level singleton.

**T28. `try Test.cancel("reason")` (Swift 6.3+) is the fallback, not the default.** Prefer moving enablement logic into a trait. Inside a parameterized test it cancels only the current case; inside a suite it cancels that suite's pending and running tests. Use it when the skip condition is only knowable after the test starts.

### Tags

```swift
extension Tag {
    // Kind — what the test is.
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var snapshot: Self
    @Tag static var ui: Self
    @Tag static var performance: Self

    // Cadence — when you can afford to run it.
    @Tag static var presubmission: Self
    @Tag static var nightly: Self
    @Tag static var prerelease: Self
}

@Suite(.tags(.integration, .nightly)) struct CheckoutIntegrationTests { … }
```

**That list is the whole vocabulary. There is no `.smoke` tag** — the fast cadence is called `.presubmission`, and the test plan that filters on it is called `Presubmission`. Declare all eight in one place; a tag that is never declared is a compile error, and a tag that is declared but never used costs nothing.

**T29. Tags must be declared as `@Tag static var` in an extension of `Tag` or a type nested in `Tag`.** Anywhere else is a compile error, and aliasing (`static var slow: Self { integration }`) compiles but **silently does not work at runtime**. Tags with the same name in different modules are treated as equivalent — if that matters, nest a reverse-DNS namespace: `extension Tag { enum com_example_app {} }`.

**T30. Tag on two axes: *kind* (unit / integration / snapshot / ui / performance) and *cadence* (presubmission / nightly / prerelease).** Kind is what the test is; cadence is when you can afford to run it. Suite tags are inherited by contained tests, and tags cut across suites, files and targets in a way suite structure cannot.

**Name each test plan after the cadence tag it filters on** — plan `Presubmission` includes `.presubmission`, plan `Nightly` includes `.nightly`, plan `Prerelease` includes `.prerelease`. Then keeping this file and `07-TOOLING-BUILD-AND-SHIPPING.md §7` in sync is mechanical rather than a promise: the plan name *is* the tag name, capitalised, and `07 B24` says so from the other side.

```bash
# Xcode 16.3+
xcodebuild test -scheme App -only-testing-tags presubmission          # fast local run
xcodebuild test -scheme App -skip-testing-tags integration,snapshot   # same idea, by kind
xcodebuild test -scheme App -only-testing-tags nightly                # the nightly job
```

`swift test --filter tag:` is ST-0025, accepted 2026-07-01 with no ship version named — verify against your toolchain before wiring it into CI. Note also that `-only-testing` with a Swift Testing suite member has been reported to need doubled parentheses (`'AppTests/CartTests/total()()'`); that is a practitioner report, not Apple documentation — **verify locally before relying on it**.

**T31. A plain comment immediately above `@Test`/`@Suite` is captured and printed with recorded issues.** Free context in CI logs where the source is not visible. If the comment is about a defect, use `.bug` instead.

---

## 10. Async, confirmations and continuations

Default to plain `async`/`await`. Reach for `Confirmation` only to count events that fire during an operation you are already awaiting.

```swift
@Test func subtotalNotifiesOnce() async {
    let calculator = OrderCalculator()
    await confirmation(expectedCount: 1) { confirmed in
        calculator.successHandler = { _ in confirmed() }
        _ = await calculator.subtotal(for: PizzaToppings(bases: []))
    }
}
```

`expectedCount: 0` asserts an event never happens. Ranges (Xcode 16.3+) need an explicit lower bound: `1...` at least once, `1...5` between one and five, `0..<100` optional but bounded. `expectedFulfillmentCount` maps to `expectedCount:`; `assertForOverFulfill = false` maps to an open-ended range.

**T32. `Confirmation` does not wait. For a classic completion-handler API, use a continuation.** Apple's migration guide presents `Confirmation` as the `XCTestExpectation` replacement; practitioners (Donny Wals) report it does not work for completion handlers because the closure returns before the callback fires. Both are right about different things — the ruling is: `Confirmation` counts callbacks *during* an awaited operation, a continuation *waits for* a single completion.

```swift
// ❌ passes/fails nondeterministically — the confirmation body returns before createFile calls back
@Test func fileCreation() async throws {
    await confirmation { confirm in
        manager.createFile { confirm() }
    }
}

// ✅ the test actually waits
@Test func fileCreation() async throws {
    await withCheckedContinuation { continuation in
        manager.createFile { result in
            #expect(result.isSuccess)
            continuation.resume()
        }
    }
}
```

**Better than either: wrap the completion-handler API in an `async` function once, in production code, and test that.** `05-CONCURRENCY.md §11` owns the wrapping.

**T33. `XCTestExpectation` and `XCTWaiter` have no interop path, ever.** ST-0021 is explicit: *"They cannot be used safely in a Swift concurrency context when running Swift Testing tests."* They are the one XCTest API you must rewrite rather than leave alone.

**T34. Never record an expectation from a detached `Task` after the test returns.** It produces a fatal error class of failure (swift-testing#500; Xcode 16.3 improved the diagnostics for "issues recorded from unknown contexts"). Make the test await the work it started — structured concurrency, not fire-and-forget.

---

## 11. Known issues

```swift
withKnownIssue("Propane tank is empty") {
    try foodTruck.startGrill()             // errors are swallowed too
    #expect(foodTruck.grill.isHeating)     // everything dependent must be INSIDE
}

withKnownIssue(isIntermittent: true) { … }                       // a flake, not a hard failure
withKnownIssue { … } when: { !hasPropane } matching: { issue in  // scoped + typed
    guard case .expectationFailed(let e) = issue.kind else { return false }
    return e.isRequired
}
```

**T35. `withKnownIssue` beats commenting out, `.disabled`, and `#expect(throws:)` for a genuine known defect** — because if the block *passes*, it records a different issue telling you the bug may be fixed. That built-in ratchet is what stops known-issues rotting into permanent dead weight. Set `isIntermittent: true` only for real flakes; it disables the ratchet. Always attach `.bug(id:)`.

`XCTExpectFailure` maps across: `.nonStrict()` → `isIntermittent: true`, `options.isEnabled` → `when:`, `options.issueMatcher` → `matching:`. There is **no** equivalent of the closure-less `XCTExpectFailure(_:options:)` that affects the rest of the test — you must wrap.

---

## 12. Test doubles: hand-write them

**T36. Write fakes by hand; do not take a mocking framework.** Four Swift-specific reasons: the compiler *is* the codegen (conform a type and it lists the missing members); codegen and macro-based mocks cost build time (`swift-syntax` is heavyweight — Apple says so about Swift Testing itself); generated mocks encode *interaction* rather than *behaviour*, so `verify(mock.save(any()))` fails on refactors that change nothing observable; and under parallel-by-default execution, a generated mock's shared recorded-call array is exactly the shared mutable state that causes flakes. **Cost:** boilerplate proportional to protocol size. Mitigate by keeping protocols small — which `02-NAMING-AND-API-DESIGN.md §7` tells you to do anyway. **Deviate** in a large legacy Objective-C-heavy codebase where hand-writing hundreds of doubles is genuinely the bottleneck; even then, generate once and check the output in.

```swift
protocol UserStore: Sendable {
    func load(id: User.ID) async throws -> User
    func save(_ user: User) async throws
}
```

**T37. Default to a *fake* — a real, working, in-memory implementation — so you can assert on resulting state instead of on calls.**

```swift
actor InMemoryUserStore: UserStore {
    private var users: [User.ID: User]
    init(_ seed: [User] = []) { users = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) }) }

    func load(id: User.ID) throws -> User {
        guard let user = users[id] else { throw StoreError.notFound(id) }
        return user
    }
    func save(_ user: User) { users[user.id] = user }

    var all: [User] { Array(users.values) }      // test-only introspection
}

// #expect(await store.all.count == 2)  — survives refactoring; verify(save(any())) does not
```

Use a **stub** (canned answers, no assertions) for a dependency whose output you are varying; a **spy** for dependencies where the call *is* the observable behaviour (analytics, logging) — and make it thread-safe, because it will be written from parallel tests.

**T38. Give every dependency an `unimplemented` default that fails when touched.** This is the highest-value double and the one people skip: it is how you discover that a "unit" test is quietly hitting the network, and it is what answers the standard objection to hand-written fakes ("someone will add a protocol member and forget to assert on it") — a new member defaults to failing loudly.

```swift
struct UnimplementedUserStore: UserStore {
    func load(id: User.ID) async throws -> User {
        Issue.record("UserStore.load was called unexpectedly")
        throw UnimplementedError()
    }
    func save(_ user: User) async throws {
        Issue.record("UserStore.save was called unexpectedly")
        throw UnimplementedError()
    }
}
```

**T39. Protocols for dependencies with many members; a struct of closures for one to three.** A struct of closures lets a test override one endpoint and leave the rest unimplemented, with no fake type per permutation. **Cost, honestly:** worse autocomplete, no `extension` default implementations, less discoverable.

```swift
struct UserClient: Sendable {
    var load: @Sendable (User.ID) async throws -> User
    var save: @Sendable (User) async throws -> Void

    static let unimplemented = Self(
        load: { _ in Issue.record("load unimplemented"); throw UnimplementedError() },
        save: { _ in Issue.record("save unimplemented"); throw UnimplementedError() }
    )
}

var client = UserClient.unimplemented
client.load = { _ in .mock }        // only what this test needs
```

If you would rather buy this than build it, `swift-dependencies` (1.14.1, 2026-06-17) formalises exactly this pattern including the unimplemented default.

---

## 13. Determinism

**T40. A unit test must not touch:** the wall clock, the RNG, the network, `UserDefaults.standard`, the real filesystem, the keychain, run-loop timing, locale/timezone defaults, or any `static var` another test can write. That list is the whole of §13.

### Time

**T41. Inject a clock. Never `Task.sleep` in a test.**

```swift
@MainActor @Observable final class FeatureModel {
    var count = 0
    private let clock: any Clock<Duration>
    private var timerTask: Task<Void, Error>?

    init(clock: any Clock<Duration>) { self.clock = clock }

    func startTimerButtonTapped() {
        timerTask = Task { while true { try await clock.sleep(for: .seconds(1)); count += 1 } }
    }
    func stopTimerButtonTapped() { timerTask?.cancel(); timerTask = nil }
}

@Test @MainActor func timerIncrementsOncePerSecond() async {
    let clock = TestClock()
    let model = FeatureModel(clock: clock)

    model.startTimerButtonTapped()
    await clock.advance(by: .seconds(1));  #expect(model.count == 1)
    await clock.advance(by: .seconds(4));  #expect(model.count == 5)

    model.stopTimerButtonTapped()
    await clock.run()                       // drain remaining suspensions
    #expect(model.count == 5)
}
```

`swift-clocks` (1.1.0) gives you three: `TestClock` when the passage of time *is* the behaviour under test (debounce, throttle, timeout, retry backoff), `ImmediateClock` when the delay is incidental, `UnimplementedClock` to prove a path never sleeps. If you only need "what time is it", you do not need the dependency:

```swift
struct Now: Sendable {
    var date: @Sendable () -> Date

    static let live = Self { Date() }
    static func fixed(_ date: Date) -> Self { Self { date } }
}
```

The anti-pattern to refuse is Apple's own legacy-refactoring example, `class StubAccount: Account { override var now: Date { … } }` — it forces a class, forces the property to be overridable, and needs one subclass per behaviour.

### Randomness

**T42. Inject a `RandomNumberGenerator`; never stub `Int.random`. Assert invariants, not golden orders.**

```swift
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {                       // splitmix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test func shuffleIsAPermutation() {
    var rng = SeededGenerator(seed: 42)
    let shuffled = Deck.standard.shuffled(using: &rng)
    #expect(Set(shuffled) == Set(Deck.standard.cards))     // invariant, not a fixed order
}
```

Inject UUID generation the same way; an incrementing generator producing `…0000`, `…0001` makes assertions readable as literals.

### Storage

| Dependency | In tests |
|---|---|
| `UserDefaults` | `UserDefaults(suiteName: UUID().uuidString)` per test, or a protocol + dictionary. **Never `.standard`** — it is shared mutable state across every parallel test in the process |
| Filesystem | Fresh `URL.temporaryDirectory.appending(path: UUID().uuidString)`, torn down by the trait in §7 |
| SwiftData | `ModelConfiguration(isStoredInMemoryOnly: true)` |
| Core Data | `NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))` — widely used, not Apple-documented; verify |
| Network | Your own `APIClient` **struct** with one substitutable `send` closure (`04-ARCHITECTURE-AND-STATE.md A47`), overridden per test — this is T39's one-to-three case, not T36's protocol case. Reserve `URLProtocol` stubs for testing the networking layer *itself* |

---

## 14. What stays in XCTest, and how the two coexist

**T43. Three things have no Swift Testing equivalent and are not getting one:** UI automation (`XCUIApplication`, `XCUIElement`, `XCUIRemote`, `XCTActivity`), performance testing (`measure`, `XCTMetric`, baselines, Max STDDEV), and catching Objective-C exceptions (Swift code cannot do it safely; you need an Objective-C `XCTestCase`). These are not gaps waiting to close — XCUITest is an *out-of-process* automation harness driving another app through accessibility, and `measure` needs OS-level instrumentation and stored baselines. Neither maps onto `@Test`.

For UI automation the block is harder than a rule and you will hit it as a build error, not a runtime surprise: **Xcode's build system rejects `import Testing` in a UI test target outright.** Swift Testing's maintainers state the reason — XCTest's UI automation APIs "do not behave correctly when used in Swift Testing tests", and allowing them needs work inside Apple's closed-source XCTest framework (swift-testing#516, opened 2024-07-01, still open on 2026-07-27). So anything reaching for `XCUIApplication` — including `performAccessibilityAudit`, which is a method on it (`07-TOOLING-BUILD-AND-SHIPPING.md §14`) — is an `XCTestCase` method. Do not try to route it through `@Test`.

**T44. Both frameworks live in the same test target. The only hard constraint: a Swift Testing test cannot be declared inside an `XCTestCase` subclass.** No new bundle, no split target.

**T45. Migrate opportunistically. Leave existing XCTests alone; write every new test in Swift Testing.** Apple's WWDC26 guidance is unambiguous, and with Swift 6.4 interop you lose no signal from mixed helpers, so there is no coverage argument for a big-bang conversion — only risk.

**T46. Set XCTest interoperability to Complete (Swift 6.4 / Xcode 27).** Before 6.4, an `XCTAssert` failing inside a `@Test` function was **silently dropped** — a shared helper made both frameworks' tests pass while the code was broken.

| Mode | Behaviour |
|---|---|
| `none` | Cross-library issues ignored. Use only temporarily; it hides bugs |
| `limited` | XCTest→Swift Testing issues become **warnings** plus modernization hints |
| `complete` | All cross-library issues keep original severity, plus hints. **This is the setting** |
| `strict` | XCTest-originated issues reported via `fatalError()`. Turn on for a week to finish the job |

Defaults: toolchain <6.4 → `none`; toolchain ≥6.4 with `swift-tools-version` <6.4 → `limited`; both ≥6.4 → `complete`. Configure with `SWIFT_TESTING_XCTEST_INTEROP_MODE=strict swift test`, or in Xcode via Test Plan → Test Execution → "interoperability". Interop covers `XCTAssert*`, `XCTFail`, `XCTExpectFailure`, issue-handling traits and `Test.cancel`. It does **not** cover `XCTestExpectation`/`XCTWaiter` (T33). `XCTSkip` is deliberately excluded.

**T47. UI tests set `continueAfterFailure = false` and disable animations.** In XCUITest a failed step invalidates everything after it — the opposite of the Swift Testing default, and correct here.

```swift
final class CheckoutUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments += ["-UITest", "-AppleAnimationsEnabled", "NO"]
        app.launch()
    }
}
```

**T48. Performance tests run Release, with Debug executable OFF and coverage and sanitizers disabled in the plan.** Anything else measures the instrumentation. Exclude setup from the measurement:

```swift
final class ParsingPerformanceTests: XCTestCase {
    func testParsingIsFastEnough() {
        measureMetrics([XCTClockMetric()], automaticallyStartMeasuring: false) {
            let data = loadFixture()          // not measured
            startMeasuring()
            _ = try? Parser().parse(data)
            stopMeasuring()
        }
    }
}
```

**T49. Exit tests are the only way to cover a `precondition` body — and they do not run on iOS.** Available on macOS, Linux, FreeBSD, OpenBSD and Windows (Swift 6.2+). This is a concrete argument for T3: if the logic lives in a package you also test on macOS, you get them.

```swift
@Test func customerRejectsBadFood() async {
    let food = Food(name: "Gruel", isDelicious: false)   // Sendable & Codable
    _ = await #expect(processExitsWith: .failure) { [food] in
        Customer.current.eat(food)                       // hits precondition()
    }
}
```

The library spawns a child process with the same executable and runs the body as its `main()`. Captured values must be **both `Sendable` and `Codable`** (encoded, piped, decoded); implicit capture is a compile error; capture lists only work on Swift 6.3+ — below that the macro captures nothing, silently. Streams are off unless you opt in with `observing: [\.standardOutputContent]`. An exit test cannot nest inside another exit test.

---

## 15. Snapshot testing

**T50. Take the dependency, then restrict it hard.** `pointfreeco/swift-snapshot-testing` is 1.19.3 (2026-07-08) and is now Swift-Testing-native — 1.19.0 added attachment support and an explicit `record: Record?` parameter, 1.19.1 uses native Swift Testing image attachments on Swift ≥6.3. That is the fact that changes the 2024 answer.

| Verdict | Use |
|---|---|
| ✅ Always | `.dump` / `.json` snapshots of **values** — decoded models, formatted receipts, navigation state trees, generated queries. Text, diffs in review, no renderer dependency |
| ✅ Sparingly | A deliberate allowlist of image snapshots of design-system primitives (button states, empty/error/loading), **one device, one dynamic-type size, light + dark**, tagged `.snapshot`, excluded from the fast plan |
| ❌ Never | Whole screens with live data. That is what integration tests are for |

The failure mode that kills snapshot suites is specific and predictable: image snapshots are coupled to the OS renderer, so a new iOS version changes font metrics or symbol glyphs and *every* snapshot fails at once, producing a mass re-record that trains the team to re-record without looking. **T51. Treat `record: .all` reaching `main` as a build-breaking lint** — one `grep -rn -E 'record:[[:space:]]*\.all'` over your source roots, written out with the other three source-hygiene checks in `07-TOOLING-BUILD-AND-SHIPPING.md §9.1 (B34a)`. Commit `.failed` and re-record locally; `.all` in a merged branch means the suite has quietly stopped asserting anything. Pin the CI simulator model *and* OS version while you are there. Use `Issue.record(severity: .warning)` for near-threshold pixel diffs so cosmetic drift is visible without failing the gate.

---

## 16. Property-based testing without a library

**T52. Do not take a property-based-testing dependency.** SwiftCheck is unmaintained; `swift-property-based` (1.2.0, 2026-04-13) has eighteen stars; SwiftQC is new. None is blessed by Apple and Swift Testing ships no generator or shrinker. **T53. Build an invariant suite on `@Test(arguments:)` with a seeded corpus instead** — you already have a parallel runner with per-case naming and selective re-run.

```swift
extension Tag { @Tag static var invariant: Self }

@Suite("Money invariants", .tags(.invariant))
struct MoneyInvariants {
    static let cases: [Money] = {
        var rng = SeededGenerator(seed: 0xC0FFEE)
        return (0..<500).map { _ in
            Money(minorUnits: .random(in: -1_000_000...1_000_000, using: &rng))
        }
    }()

    @Test(arguments: cases)
    func formattingRoundTrips(_ money: Money) throws {
        #expect(try Money(formatted: money.formatted()) == money)
    }

    @Test(arguments: zip(cases, cases.reversed()))
    func additionIsCommutative(_ a: Money, _ b: Money) {
        #expect(a + b == b + a)
    }
}
```

Deterministic, reproducible from a seed, and each case re-runnable in isolation provided `Money` is `Codable` (T23). **Cost: you lose shrinking** — compensate by promoting every failure you find into a named regression test with the literal input. **Deviate and take a library** if you are writing a parser, a CRDT, a scheduler, or crypto glue, where shrinking earns its keep. The invariants worth writing are the same five every time: round-trip (`decode(encode(x)) == x`), idempotence, commutativity/associativity, ordering (a sort is a permutation *and* is sorted), and conservation (total before == total after).

---

## 17. Fixtures and migration tests

**T54. Fixtures are recorded from production responses, scrubbed, and dated in the filename.** A payload you hand-wrote tests your imagination, not the server. Keep one fixture per *shape*, not per record, and store them in `Tests/<Module>Tests/Fixtures/` declared as SwiftPM `resources: [.copy("Fixtures")]`.

**`.copy` and the lookup have to agree, and this is where fixture suites die.** `07-TOOLING-BUILD-AND-SHIPPING.md B22` owns the distinction and states the rule: `.copy(_:)` is verbatim and **preserves the directory**, `.process(_:)` **flattens** to the bundle root. So with `.copy("Fixtures")` the file lands at `Fixtures/checkout.v1.json` and a bare `url(forResource:withExtension:)` returns `nil` — every `#require` in this section fails at once. Pass `subdirectory:`. I verified both halves on Xcode 26.6: under `.copy`, the flat lookup is `nil` and the `subdirectory:` lookup resolves; under `.process`, exactly the reverse.

`.copy` is the right choice here even though B22 makes `.process` the general default: fixtures want their directory to survive so `store-v1.store` and a same-named asset cannot collide in a flat namespace, and the `subdirectory:` argument documents where they live.

```swift
enum Fixture {
    private static let directory = "Fixtures"     // matches resources: [.copy("Fixtures")]

    static func url(_ name: String, ext: String = "json") throws -> URL {
        try #require(
            #bundle.url(forResource: name, withExtension: ext, subdirectory: directory),
            "No fixture named \(name).\(ext) in \(directory)/"
        )
    }

    static func data(_ name: String, ext: String = "json") throws -> Data {
        try Data(contentsOf: url(name, ext: ext))
    }

    /// Copies a fixture somewhere writable, because migration opens its store read-write.
    static func copyToTemporaryDirectory(_ name: String, ext: String) throws -> URL {
        let source = try url(name, ext: ext)
        let destination = URL.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}

@Test(arguments: ["checkout.v1", "checkout.v2", "checkout.empty", "checkout.malformed-price"])
func decodesRecordedPayloads(_ name: String) throws {
    let data = try Fixture.data(name)
    let order = try JSONDecoder.api.decode(Order.self, from: data)
    #expect(order.lineItems.allSatisfy { $0.quantity > 0 })
}
```

`#bundle` rather than `Bundle.module`: `01-PROJECT-STRUCTURE.md P36` owns that ruling and `07-TOOLING-BUILD-AND-SHIPPING.md B22` follows it. `Bundle.module` still works and you will see it in older code.

**T55. Every decoding fixture gets a malformed sibling asserting a specific typed error.** "It decodes the happy path" is half a test.

**T56. Migration tests use a store file produced by the *shipped* binary, and you keep one per shipped version forever.** A store your current code wrote proves nothing — it was written by the schema you are migrating *to*. This is the one class of bug that is unrecoverable in production, so it earns disproportionate coverage.

```swift
@Test(arguments: ["store-v1", "store-v2", "store-v3"])
func migratesEveryShippedSchemaToCurrent(_ fixture: String) throws {
    let url = try Fixture.copyToTemporaryDirectory(fixture, ext: "store")
    let container = try ModelContainer(
        for: Trip.self,
        migrationPlan: TripMigrationPlan.self,
        configurations: ModelConfiguration(url: url)
    )
    let trips = try ModelContext(container).fetch(FetchDescriptor<Trip>())
    #expect(trips.allSatisfy { !$0.title.isEmpty })     // v2 renamed `name` → `title`
}
```

For `Codable` app state, add a cheap schema-lock test: snapshot the JSON of one canonical value so any change to the encoded shape requires an explicit re-record.

---

## 18. Keeping the fast suite under ten seconds

Where the time actually goes, in order: simulator boot and host-app launch for a *unit* bundle; real I/O and real clocks; serial execution (or `.serialized` sprinkled to paper over shared state); and compilation, because a monolithic target rebuilds everything for a one-line change.

The plays, in payoff order:

1. **Move logic into package targets and run `swift test`** — no simulator, no host app (T3). Structural, and by far the biggest win.
2. **Set Host Application to None** for pure-logic Xcode test targets. Where you cannot, gate startup: `if ProcessInfo.processInfo.environment["IS_UNIT_TESTING"] == "1" { return }` in your `App.init`, with the variable set in the test plan configuration.
3. **Fix shared state instead of serializing it** (T27). `xcodebuild -parallel-testing-enabled YES -parallel-testing-worker-count N`.
4. **Inject clocks** (T41). Every sleep in a test is dead time; `ImmediateClock` removes it.
5. **T57. Never assert by polling.** `try await Task.sleep(for: .milliseconds(100)); #expect(…)` is both slow and flaky. Replace with a confirmation, a continuation, or a `TestClock`.
6. **Split by tag and plan** (T30), and run the `Presubmission` plan on ⌘U.
7. **Gate genuinely expensive suites declaratively:**
   ```swift
   @Suite("Live API contract",
          .tags(.integration),
          .enabled(if: ProcessInfo.processInfo.environment["RUN_LIVE_TESTS"] == "1"),
          .timeLimit(.minutes(5)))
   struct LiveAPIContractTests { … }
   ```
8. **`build-for-testing` once on CI, then `test-without-building` across N machines** with different subsets. `07-TOOLING-BUILD-AND-SHIPPING.md §9` owns the pipeline.

**T58. Do not delete slow tests — tag them, plan them, budget them, and give them an owner.** A slow test that runs nightly still catches the regression. A slow test everyone skips on ⌘U catches nothing.

Arithmetic worth internalising: 200 UI tests at 5 s each, four simulators per machine, is about **4.1 minutes on one CI machine** — the entire budget of a ten-minute pipeline, for 200 UI tests, which is not much coverage.

---

## 19. Coverage

**T59. Gather coverage. Do not set a global percentage gate.** Apple's own caveat is verbatim: *"achieving a high level of coverage is an excellent goal, [but] code coverage alone doesn't ensure that your tests are doing their job."*

The specific ways the number lies:

1. **It measures execution, not assertion.** A test that calls a function and asserts nothing scores identically to one that asserts everything.
2. **The host app inflates it.** A unit bundle with a host application launches the app, so your `@main`, AppDelegate and root views read as covered with zero tests. This is the usual source of an unearned 20–30 points.
3. **`withKnownIssue` and expected-failure tests still count** (Apple documents this). You can hold coverage flat while the feature is broken. Skipped tests do *not* count.
4. **Line coverage is not branch coverage.** `a && b` on one line, a `guard` whose `else` never runs, a `switch` whose `default` is never hit — all read as covered.
5. **Generated code dominates.** `@Observable`, `@Model`, `#Preview`, `Codable` synthesis, `.pb.swift`.
6. **`deinit`, error paths and `precondition` bodies are structurally hard to cover** — which is exactly what exit tests fix (T49).

**T60. Use coverage diff-wise and per-module.** "Which lines in *this PR* are uncovered?" has an actionable answer; "we are at 82%" does not. Gate a pure-logic `Pricing` package at 90% if you like; never gate the app shell. Exclude the host app and generated files before you believe any number, and turn coverage **off** for performance runs and the fast local plan.

---

## 20. Flakes

| Cause | Swift-specific mechanism | Cure |
|---|---|---|
| Shared mutable state | Parallel **in one process** — `static var`, singletons, `UserDefaults.standard`, a shared `ModelContainer` are now data races | Per-test instances; `@TaskLocal` + `TestScoping`; unique suite names and URLs |
| Time | `Task.sleep`-then-assert; DST/midnight arithmetic; `Date()` vs a literal | Inject a clock (T41) |
| Ordering assumptions | `Dictionary`/`Set` iteration order, `FetchDescriptor` without a sort, task interleaving | Assert on sets, or sort explicitly |
| Real I/O | Network (even localhost), DNS, disk pressure, keychain | Fakes + an `Unimplemented` double (T38) |
| Main-actor assumptions | XCTest ran sync tests on the main actor; Swift Testing does not | `@MainActor` on the test (T9) |
| Escaped continuations | Recording an issue after the test returns | Structured concurrency; await the work you started (T34) |
| Environment | Locale, timezone, `Calendar.current`, dynamic type, appearance, simulator drift, first-launch permission alerts | Pin them in the test; pin the simulator in CI |

**T61. Turn on random execution order permanently in at least one plan configuration.** If that breaks the suite you have hidden inter-test dependencies and you want to know today. (`07-TOOLING-BUILD-AND-SHIPPING.md §7` owns the plan setting.)

**T62. Hunt a flake with repetition, not with retries.** `xcodebuild test -only-testing <id> -run-tests-until-failure -test-iterations 100`, or on Swift 6.4 `swift test --maximum-repetitions 100 --repeat-until fail` (ST-0024 made repetition per-*case*, so only the failing case repeats).

**T63. Never add a blanket CI retry.** Retrying is precisely the mechanism by which a genuine race condition ships. Quarantine a known flake with `withKnownIssue(isIntermittent: true)` plus `.bug(id:)`, which keeps it visible and attributable.

---

## 21. What not to test

Nothing in Apple's docs enumerates this, so it is opinion — but it is where most wasted test-writing goes.

1. **The compiler.** Memberwise inits, synthesized `Equatable`/`Codable` with no custom keys, a computed property that aliases a stored one, plain enum raw values.
2. **Apple's frameworks.** `URLSession` performing a GET, `JSONDecoder` decoding an `Int`, `VStack` laying out. Test *your* usage at the boundary.
3. **View bodies.** `body` is a description; asserting on the view tree couples tests to layout and breaks on every design change. Test the `@Observable` model, snapshot a small set of states. **On ViewInspector specifically: no.** Its last release is 0.10.3 (2025-09-21) and it reportedly conflicts with Swift Testing's concurrency model — building a SwiftUI test strategy on runtime reflection of a private view tree is a standing liability. **Deviate** if you own a design-system library where the view *is* the product.
4. **Private implementation details.** If you need `@testable` to reach it, ask whether the behaviour is observable publicly first (T4).
5. **Trivial delegation.** A method whose whole body is `store.save(x)` — the fake passes by construction and you have written a change-detector.
6. **Generated code.** `.pb.swift`, macro expansions, generated mocks.
7. **Third-party libraries.** Test your adapter, at your boundary, with your fixtures.
8. **Analytics and log *strings*.** Assert the event *identity* with a spy if it is a business requirement; never the human-readable copy.
9. **Localised copy.** Assert on the key, never the translation.
10. **Navigation plumbing through XCUITest** when the same decision is a testable function on a router.

The single test to write instead of most of these: an integration test that exercises the seam, plus one invariant that catches the whole class of bug.

---

## Checklist

**Structure**
- [ ] Logic lives in package targets; app target is a shell (T3)
- [ ] `import Testing` appears in no shipping target (T5)
- [ ] Shared fakes live in a `TestSupport` **`.target`** that is not a `product` and appears in no target the app links — checked by CI, not by eye (T5a, `07 §9.1 / B34a`)
- [ ] Suites are `struct`s with `init()`; no `deinit` — scoped setup uses a `TestScoping` trait (T8, T19, T20)
- [ ] No `@available` on a suite type or its enclosing types (T7)
- [ ] One suite per file, file named for the suite, test path mirroring the source path (T5b)

**Writing tests**
- [ ] `#require` for preconditions, `#expect` for assertions (T11)
- [ ] `continueAfterFailure` not ported from XCTest (T12)
- [ ] No `await`/`try` inside `#expect` — hoist the effect (T13, T14)
- [ ] No `for` loop where `arguments:` belongs (T21)
- [ ] `zip()` when you mean pairs, not the Cartesian product (T22)
- [ ] Argument types are `Codable`/`Identifiable` so a failing case re-runs alone (T23)
- [ ] Helpers take `sourceLocation: SourceLocation = #_sourceLocation` — underscored (T17)
- [ ] `@MainActor` on any test touching UI or a main-actor model (T9)
- [ ] Tags declared as `@Tag static var` on `Tag`; no aliases (T29)
- [ ] Known defects wrapped in `withKnownIssue` with a `.bug(id:)`, not commented out (T35)
- [ ] Failure evidence attached with `Attachment.record`, not `print`ed (T18a)

**Doubles and determinism**
- [ ] Fakes hand-written; no mocking framework (T36)
- [ ] Default fake is a working in-memory implementation; assertions are on state (T37)
- [ ] Every dependency has an `unimplemented` variant that fails when touched (T38)
- [ ] Clock injected; no `Task.sleep` and no polling anywhere in the suite (T41, T57)
- [ ] RNG and UUID injected; assertions are invariants, not golden orders (T42)
- [ ] No `UserDefaults.standard`, no real network, no real filesystem outside a per-test temp dir (T40)

**Suite health**
- [ ] Fast plan under 10 s; slow tests tagged, planned, budgeted and owned (T1, T58)
- [ ] `.serialized` appears nowhere except for genuinely global resources (T27)
- [ ] Random execution order on in at least one configuration (T61)
- [ ] No blanket CI retry (T63)
- [ ] Coverage gathered, read as a diff, gated only per pure-logic module (T59, T60)
- [ ] Image snapshots are an allowlist on a pinned device/OS; `record: .all` never reaches `main` — checked in CI (T50, T51, `07 §9.1`)
- [ ] XCTest interop set to Complete on Xcode 27; new tests are Swift Testing only (T45, T46)
- [ ] `XCTestExpectation`/`XCTWaiter` rewritten, not left alone (T33)
- [ ] Every decoding fixture has a malformed sibling (T55)
- [ ] One migration fixture per shipped schema version, produced by the shipped binary (T56)
- [ ] Fixture lookup matches the resource declaration: `.copy` ⇒ pass `subdirectory:`, `.process` ⇒ do not (T54, `07 B22`)
- [ ] Tags are the eight in T30; plans are named after the cadence tags (T30, `07 B24`)
