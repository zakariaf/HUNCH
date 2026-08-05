# Writing the Code

This file covers the decisions you make inside a Swift file: which kind of type to declare, what access level to give it, how to organise it across files and extensions, how to handle optionals and errors, when to reach for generics versus existentials, and when *not* to reach for a macro, property wrapper, or result builder. Read it if you are writing or reviewing day-to-day application code. Topics owned elsewhere and deliberately not repeated here: folder and module layout in `01-PROJECT-STRUCTURE.md`, names and argument labels in `02-NAMING-AND-API-DESIGN.md`, `@Observable` and state ownership in `04-ARCHITECTURE-AND-STATE.md`, `Sendable`/isolation/actors in `05-CONCURRENCY.md`, test doubles in `06-TESTING.md`, and where the formatter runs in `07-TOOLING-BUILD-AND-SHIPPING.md`.

Rules are numbered **`W1`–`W57`**. Every file in this guide owns a unique prefix (`P` / `N` / `W` / `A` / `R` / `T` / `B`); cross-file citations are written file-qualified.

---

## 0. Version ground truth

| Thing | Value | How I checked, 2026-07-27 |
|---|---|---|
| Xcode | **26.6 (17F113)** | `xcodebuild -version` |
| Swift compiler | **6.3.3** (`swiftlang-6.3.3.1.3`) | `swift --version` |
| Bundled `swift-format` | **6.3.0**, 43 rules | `xcrun swift-format --version`, `dump-configuration` |
| iOS shipping | **26.x** | Apple's year-based scheme; there is no iOS 19–25 |
| Swift next | **6.4**, Xcode 27 beta | Do not ship; sections marked *6.4* say so |

**Every compiler and linter diagnostic quoted in this file was produced by that toolchain on 2026-07-27.** If a quoted message differs on yours, trust your toolchain and tell me. Language mode is `07-TOOLING-BUILD-AND-SHIPPING.md` B1's call — ship language mode 6.

Note the tag naming, because it confuses people searching GitHub: the binary reports `6.3.0`, while the `swiftlang/swift-format` repo tags the matching release `603.0.0`. Same thing.

**One trap that governs every "is this feature available yet?" question below:** `swiftc` **silently ignores an unrecognised `-enable-experimental-feature` name**. I passed `-enable-experimental-feature TotallyMadeUpFeature123` and got no diagnostic at all. So a flag that changes nothing tells you nothing — it may not exist, or it may exist and be inert. Always verify by testing the *behaviour*, never by the absence of an error on the flag.

---

## 1. Choosing the kind of type

**W1. Default to `struct`. Everything else needs a reason you can name.** Apple's guidance leads with *"Choose Structures by Default"*, and the under-quoted corollary kills the most bugs: *"Use structures when you're modeling data that contains information about an entity with an identity that you don't control."* A server record has an identity — on the server. Locally it is a value.

```swift
// ✗ "it has an id, so it must be a class" — now two view models share mutations
final class Order {
    var items: [Item] = []
    var coupon: Coupon?
}

// ✓ a copy is a copy; Sendable falls out for free
struct Order: Identifiable, Equatable, Sendable {
    let id: UUID
    var items: [Item] = []
    var coupon: Coupon?
}
```

**W2. Run this procedure top to bottom and stop at the first match.**

| Question | Type if yes |
|---|---|
| Fixed set of alternatives, data attached to some? | `enum` with associated values (§6) |
| Plain data? | `struct` — **stop here** unless a row below forces you off |
| Is it *itself* an identity — live connection, file handle, hardware session, app-wide cache? | `final class` |
| Must you subclass an Objective-C framework class? | `class` (non-`final`) |
| Large value copied on a **measured** hot path? | `struct` with COW storage (W4), *not* a class |
| SwiftUI model the view observes? | `@Observable final class` — the macro only applies to classes; see `04-ARCHITECTURE-AND-STATE.md` |
| Mutated concurrently by multiple tasks, and cannot be confined to one isolation domain? | `actor` — read `05-CONCURRENCY.md` §6 first |
| Abstraction over several concrete types? | `protocol` — but read §9 first |

*Cost of W1:* you will occasionally write `mutating` and thread a value back out where a reference would have "just worked". That friction is the feature — it puts the mutation in the signature.
*Deviate when:* a row fires. Not before.

**W3. `actor` is usually the wrong answer in an app target as of Swift 6.2+.** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (the default for new app targets in Xcode 26), a plain `final class` in that target is already main-actor-isolated and therefore data-race-safe. An `actor` view model buys nothing but an `await` at every call site. Reserve `actor` for state that genuinely must be mutated off the main actor by more than one task. The `@MainActor` → `Mutex` → `actor` ladder is `05-CONCURRENCY.md` §6.

**W4. If a value type is genuinely large, add copy-on-write storage rather than switching to a class.** Swift's own `OptimizationTips.rst` recommends this over the class rewrite. `isKnownUniquelyReferenced(_:)` is the primitive.

```swift
struct PixelBuffer {
    private final class Storage {
        var bytes: [UInt8]
        init(bytes: [UInt8]) { self.bytes = bytes }
    }
    private var storage: Storage

    private mutating func makeUniqueIfNeeded() {
        guard !isKnownUniquelyReferenced(&storage) else { return }
        storage = Storage(bytes: storage.bytes)
    }

    subscript(index: Int) -> UInt8 {
        get { storage.bytes[index] }
        set { makeUniqueIfNeeded(); storage.bytes[index] = newValue }
    }
}
```

*Cost:* you hand-write the uniqueness check in every mutating path, and one missed `makeUniqueIfNeeded()` is a silent aliasing bug that no test will catch until two owners diverge.
*Deviate when:* you have not measured. This is profiler-driven, never speculative.

**W5 (Swift 6.4).** `~Sendable` (SE-0518) marks a public type as *deliberately* non-`Sendable` rather than merely un-audited. It applies only to type declarations, cannot appear in an extension, and — unlike an `@available(*, unavailable)` conformance — does **not** propagate to subclasses.

```swift
public enum ExecutionResult: ~Sendable {
    case success
    case failure(NonSendableReason)
}
```

On Swift 6.3.3 that is an error with a precise remedy, so you can try it today behind a flag:

```text
error: '~Sendable' requires -enable-experimental-feature TildeSendable
```

Do not ship it on an experimental flag — §0's trap applies, and experimental spellings change between releases.

---

## 2. Access control

**W6. In a multi-module codebase the implicit `internal` default is not a decision — make one per declaration.** Once an app is six SwiftPM targets, "module" stops meaning "my code", so the default stops expressing anything you meant.

| Level | Use it for | Frequency in a healthy app target |
|---|---|---|
| `private` | The default you should *reach for*. It reaches same-file extensions, so it is nearly always enough. | very high |
| `internal` (unwritten) | Implementation detail of this module | high |
| `package` | The seam between **your own** modules (SE-0386, Swift 5.9) | this is what most `public` should have been |
| `public` | A real published API surface | low |
| `open` | A framework you intend third parties to subclass | in an app: never |
| `fileprivate` | Two *different* top-level types in one file must see each other | almost never |

`package` requires the `-package-name` flag; SwiftPM passes it automatically for targets in the same package. Without it, `package` declarations are simply unavailable.

```swift
// Module Engine, package gamePkg
public struct MainEngine {
    public init() {}
    package func run() {}          // cross-module, but only inside gamePkg
}

// Module Game, package gamePkg — ✓ compiles
// Module App,  package appPkg   — ✗ error: 'run()' is package-internal to 'gamePkg'
```

**W7. Never put an access level on an `extension` declaration.** It silently applies to every member, including the ones you add six months later.

```swift
// ✗ everything in here is public forever, including whatever you add next
public extension Order {
    func total() -> Decimal { … }
    func debugDump() { … }          // oops, now API
}

// ✓ per-member, explicit
extension Order {
    public func total() -> Decimal { … }
    func debugDump() { … }
}
```
Google's guide calls the first form *forbidden*; swift-format enforces it as `NoAccessLevelOnExtensionDeclaration`, **on by default**.

**W8. `fileprivate` is a `private` you typed wrong.** `private` already reaches extensions of the same declaration in the same file — verified below in W14. Check that before keeping a `fileprivate`.

**W9. Access modifiers come before other modifiers: `public final class`, not `final public class`.** Arbitrary; pick it and stop discussing it.

**W10. Mark every class `final` unless you designed it for subclassing.** With Whole Module Optimization the compiler already infers `final` for non-`open` classes, so on an `internal` class this is **documentation, not optimization** — do not claim a perf win you cannot measure. Where it genuinely matters is `public`: across a module boundary the optimizer can no longer prove there are no overrides, and a non-`final` `public` class is a permanent API commitment.

---

## 3. Files and extensions

`01-PROJECT-STRUCTURE.md` owns the folder tree, module boundaries, file naming, and banned file names. These are the in-file rules only.

**W11. One top-level type per file, named for the type.** `SessionStore.swift`. The three sanctioned exceptions — private nested helpers, a type plus its delegate protocol, and a SwiftUI parent plus tiny extracted sections — and the banned file names are `01-PROJECT-STRUCTURE.md` P24–P28. Read them there; this entry does not restate them, because a shortened copy here was wrong for a while.

**W12. One protocol conformance per extension.** Which *file* a split-out conformance lands in is P26 (your own type) and P27 (foreign type: always `Foreign+Capability.swift`). This entry owns only "one conformance per extension".

**W13. Stored properties and designated initializers stay in the primary declaration; everything else may live in extensions.** This is not taste — a struct's memberwise initializer and a class's designated initializers must be in the primary declaration. Putting an *extra* `init` in an extension of a struct is what **preserves** the memberwise init. That is a technique, not an accident.

```swift
struct Pagination {
    var page: Int
    var pageSize: Int
}

// ✓ keeps Pagination(page:pageSize:) alive alongside the convenience init
extension Pagination {
    init(firstPageOf size: Int) { self.init(page: 0, pageSize: size) }
}
```

**W14. One `private` stored property makes the whole synthesized memberwise initializer `private`. Write the initializer by hand.** The synthesized init's access level is capped by the least accessible stored property. Verified on Swift 6.3.3:

```swift
struct Pagination {
    var page: Int
    var pageSize: Int
    private var cursor: String? = nil
}
let p = Pagination(page: 0, pageSize: 20)
// error: 'Pagination' initializer is inaccessible due to 'private' protection level
// note:  'init(page:pageSize:cursor:)' declared here
```

Two details people get wrong. First, the private property is still *in* the init — the compiler does not omit it, it demotes the whole thing. Second, `private` does not mean "same file": the failure above is at file scope in the **same file**, because top-level code is outside `Pagination`'s declaration. Same-file *extensions of the type* do reach it:

```swift
struct B { var x: Int; private var y = 0 }
extension B { static func make() -> B { B(x: 1) } }   // ✓ extension of B, same file
let b = B(x: 1)                                        // ✗ file scope is outside B
```

*Swift 6.4 (SE-0502)* changes this so that less-accessible stored properties **that have an initial value** are excluded from the memberwise init rather than restricting it. It is **not** in Swift 6.3.3: passing `-enable-experimental-feature ExcludePrivateFromMemberwiseInit` produced the identical `init(page:pageSize:cursor:)` error, and per §0 the silent-flag trap means that is not proof the flag name is right. Write the init by hand until Xcode 27 is GA.

**W15. Use `// MARK: -` between conformances, not between arbitrary method groups.** The hyphen draws the divider in Xcode's jump bar. If you need MARKs *inside* one conformance to navigate it, the type is too big — that is the signal; act on it.

**W16. Constants go in a caseless `enum`, or better, on the type they belong to. Never `struct Constants`.** A caseless enum cannot be instantiated; a struct can.

```swift
struct Constants { static let timeout: Duration = .seconds(30) }   // ✗
let c = Constants()                                                // meaningless but legal

enum Timeouts { static let network: Duration = .seconds(30) }      // ✓
extension URLRequest { static let defaultTimeout: Duration = .seconds(30) }   // ✓✓ where it's used
```

**W17. Never declare a retroactive conformance in a library; in an app, prefer a wrapper.** Conformances are globally unique at runtime, so two modules declaring `ExternalType: ExternalProtocol` is undefined behaviour — SE-0364 (Swift 6.0) made it a warning. If Foundation later adds the conformance with a different implementation, persisted IDs corrupt.

```swift
// ✗ in a library — swift-format's AvoidRetroactiveConformances (on by default) forbids it
extension Date: Identifiable { public var id: TimeInterval { timeIntervalSince1970 } }

// ✓ in an app, if you own the risk and say so out loud
extension Date: @retroactive Identifiable { public var id: TimeInterval { timeIntervalSince1970 } }

// ✓✓ anywhere — a type you own
struct DatedRow: Identifiable { let id: Date; let value: String }
```

---

## 4. Immutability

**W18. `let` for every property and local until the compiler makes you change it.** The compiler warns on a `var` that is never mutated. Do not silence that warning; fix it.

**W19. Use `if`/`switch` **expressions** instead of declaring a `var` and assigning in each branch.** SE-0380, **Swift 5.9**.

```swift
// ✗ this compiles — definite initialisation proves the switch assigns in every branch.
//   The cost is not "it doesn't build": `title` must be `var`, the declaration is separated
//   from the value, and a case that forgets to assign is blamed at the *use site*.
var title: String
switch state {
case .loading: title = "Loading…"
case .loaded:  title = "Done"
case .failed:  title = "Error"
}

// ✓ same safety, better blame: a non-assigning case is an error on the case itself
let title =
    switch state {
    case .loading: "Loading…"
    case .loaded:  "Done"
    case .failed:  "Error"
    }
```

Three restrictions you will hit blind if nobody tells you. All three verified on Swift 6.3.3:

| Restriction | Example | Result |
|---|---|---|
| Each branch is one expression — but `throw` and `fatalError()` are exempt (`Never` is allowed) | `let c = if p { 1 } else { fatalError("impossible") }` | compiles |
| An `if` expression must have an `else` | — | exhaustiveness mirrors definite-initialisation |
| Branches type-check independently and must agree | `let a = if p { 0 } else { 1.0 }` | `error: branches have mismatching types 'Int' and 'Double'` |
| …unless an annotation supplies the context | `let b: Double = if p { 0 } else { 1.0 }` | compiles |

**W20. Computed by default; stored when the value is the source of truth; `lazy` almost never.**

| | recomputed | cached | init cost | thread-safe |
|---|---|---|---|---|
| stored `let`/`var` | never | always | paid at `init` | yes (value types) |
| computed `var { … }` | every access | never | none | yes (if pure) |
| `lazy var` | never | after first access | deferred | **no** |

`lazy var` is **not thread-safe** — two concurrent first-accesses can both run the initializer. There is no `lazy let` either (`error: 'lazy' cannot be used on a let`, Swift 6.3.3), which is the language telling you a lazy property is inherently mutable state. In a concurrency-checked codebase `lazy var` on a non-isolated type will fight you; that is the compiler being right. A cheap derived value (a format, a filter over a small array, a flag) should be computed — it can never go stale. Store only what you cannot derive.

*Deviate when:* the setup is genuinely expensive, deterministic, one-time, and provably single-threaded (a `@MainActor` type's date formatter). Then `lazy` is fine, and say why in a comment.

**W21. Omit `get` on a read-only computed property.** (swift-format `UseSingleLinePropertyGetter`, on by default.)

```swift
var isEmpty: Bool { get { items.isEmpty } }    // ✗
var isEmpty: Bool { items.isEmpty }            // ✓
```

---

## 5. Optionals

**W22. Always use the `if let x` shorthand.** SE-0345, **Swift 5.7**. `if let user = user` should not survive review. Only bare identifiers work — `if let foo.bar` is rejected — and type annotations are allowed (`if let foo: Foo`).

**W23. `guard` when the unwrapped value is needed by the rest of the function; `if let` when only the branch needs it.** The tell is whether the `else` exits.

```swift
// ✗ pyramid
func send(to user: User?) {
    if let user {
        if let email = user.email {
            if user.isVerified { mailer.send(to: email) }
        }
    }
}

// ✓ — note a later condition can use an earlier binding
func send(to user: User?) {
    guard let user, let email = user.email, user.isVerified else { return }
    mailer.send(to: email)
}
```

**W24. Distinguish "`!` on a build-time configuration error" from "`!` on a runtime data assumption". The first is defensible; the second is not.**

An `@IBOutlet var label: UILabel!` that is nil means the storyboard is wrong: it crashes on the first run, on your machine, deterministically, pointing at the exact cause. That is a *good* crash. `dict[key]!` depends on data you may not control and crashes in production with a stack trace that says nothing about why the key was missing.

The two cases are policed by two different swift-format rules, which is what makes the distinction enforceable. Verified with both enabled:

```text
error: [NeverUseImplicitlyUnwrappedOptionals] use 'String' or 'String?' instead of 'String!'
error: [NeverForceUnwrap] do not force unwrap 'd["k"]'
```

`NeverUseImplicitlyUnwrappedOptionals` covers the *declaration*; `NeverForceUnwrap` covers the *expression*. Both ship **off**. W54 turns on the second and leaves the first off, precisely so framework-mandated outlets compile clean while every `dict[key]!` trips. I re-ran with the IUO rule off: the outlet passed, the force-unwrap still failed.

**W25. Never leave a bare `!`.** Three ways to make a defensible one self-documenting:

```swift
// ✗ bare
let baseURL = URL(string: "https://api.example.com/v1")!

// ✓ 1. state the proof, and suppress the lint in the same breath or CI stops you
// swift-format-ignore: NeverForceUnwrap
// Force-unwrap: literal is a valid URL; failure here is a compile-time typo, not runtime data.
let baseURL = URL(string: "https://api.example.com/v1")!

// ✓ 2. better — no suppression to review, and a helper whose crash message *is* the proof
extension URL {
    /// Creates a URL from a string that is known-good at authoring time.
    /// - Precondition: `string` is a valid absolute URL.
    init(staticString string: StaticString) {
        guard let url = URL(string: "\(string)") else {
            preconditionFailure("Invalid static URL: \(string)")
        }
        self = url
    }
}
let baseURL = URL(staticString: "https://api.example.com/v1")

// ✓ 3. for a lookup — do not force-unwrap at all
guard let record = index[id] else { throw StoreError.missingRecord(id: id) }
```

`// swift-format-ignore:` is scoped to the declaration it precedes — verified: with two force-unwraps in a file and the comment above the first, only the second was reported. A suppression is a reviewable event; a disabled rule is not. That asymmetry is the whole reason W54 keeps the rule on.

Force-unwraps are fine in tests without further justification (`06-TESTING.md`). Everywhere else, W25 applies.

**W26. Optional chaining plus `??` beats a nested `if let` when you only want a value.**

```swift
var name = "Anonymous"                                            // ✗
if let user { if let p = user.profile { name = p.displayName } }

let name = user?.profile?.displayName ?? "Anonymous"              // ✓
```

**W27 (Swift 6.4).** SE-0521 drops the parentheses on `any P?` and `-> some P?`. Compositions still need them: `some (P & Q)?` stays required. Until then Swift 6.3.3 tells you exactly what to write:

```text
error: optional 'any' type must be written '(any P)?'
```

---

## 6. Making illegal states unrepresentable

**W28. A comment or log line that says "this should never happen" is a type error, not a logging opportunity.** So is a `Bool` that is only meaningful when some optional is non-nil.

A struct is a *product* type (possibilities multiply); an enum is a *sum* type (possibilities add). The refactor is mechanical: distribute the struct-of-optionals into an enum, then delete the illegal cases.

```swift
// ✗ 4 representable states, 1 of them illegal (both nil)
struct ContactMethods {
    let email: Email?
    let phoneNumber: PhoneNumber?
}
if let email = user.contactMethods.email { … }
else if let phone = user.contactMethods.phoneNumber { … }
else { logger.error("This should never happen!") }        // ← the smell

// ✓ 3 representable states, all legal, switch is exhaustive
enum ContactMethods {
    case both(Email, PhoneNumber)
    case email(Email)
    case phoneNumber(PhoneNumber)
}
switch user.contactMethods {
case .both(let email, _), .email(let email): send(to: email)
case .phoneNumber(let phone): send(to: phone)
}
```

The four-flag loading state is the same move — 2⁴ = 16 combinations, roughly 4 of them legal:

```swift
// ✗ 16 representable states
struct FeedState { var isLoading = false; var items: [Item]?; var error: Error?; var hasLoadedOnce = false }

// ✓ 4 states, all legal, every switch exhaustive
enum FeedState {
    case idle
    case loading
    case loaded([Item])
    case failed(FeedError)
}
```

One case per line is not cosmetic here: swift-format's `OneCasePerLine` is **on by default** and rejects `case loaded([Item]), failed(FeedError)` with *"move 'failed' to its own 'case' declaration"*.

*Cost:* enums are less convenient to mutate in place — updating one field of `.loaded` means reconstructing the case. When a state has five or more associated values that change independently, a struct with an enum `phase` field is the honest compromise. Where this state *lives* is `04-ARCHITECTURE-AND-STATE.md`.

**W29. Never write `default:` in a switch over an enum you own.** It silences the compiler on the day you add a case — exactly the day you needed it to speak. Collapse by listing: `case .a, .b, .c:`.

**W30. `@unknown default:` is the exception, and only for non-frozen enums from other modules.** It produces a warning, not an error, when new cases appear.

**W31 (library authors). Every `public enum` must be marked.** `@nonexhaustive` (SE-0487) if you might ever add a case; `@frozen` if it is genuinely closed (`Direction`, `Weekday`). Unmarked leaves your compatibility story to chance.

Verified available in the shipping toolchain: `@nonexhaustive public enum PizzaFlavor { case hawaiian, pepperoni, cheese }` type-checks clean on Swift 6.3.3 with no flag. (That is real evidence, not silence — Swift rejects unknown attributes: a made-up one gives `error: unknown attribute 'totallyMadeUpAttribute'`.) The two attributes are mutually exclusive, also verified: `error: cannot use '@nonexhaustive' together with '@frozen'`. Inside the same module *or package* no `@unknown default:` is needed and adding one warns — the proposal treats co-developed code as a single unit.

**W32. Write `case .success(let value)`, not `case let .success(value)`.** The community is genuinely split — Airbnb mandates the first, most Apple sample code uses the second, and Apple publishes no rule. The tiebreak is that your formatter already has an opinion, on by default:

```text
error: [UseLetInEveryBoundCaseVariable] move this 'let' keyword inside the 'case' pattern,
       before each of the bound variables
```

So: write it inline, let the default config enforce it, never discuss it again.

---

## 7. Errors

### 7.1 Typed throws

**W33. Default to untyped `throws` at every API boundary. Use `throws(E)` in exactly three situations.** SE-0413 (Swift 6.0) is unusually blunt: *"Resist the temptation to use typed throws because there is only a single kind of error that the implementation can throw."*

| Situation | Use |
|---|---|
| Generic code that only passes through a caller's errors | `throws(E)` — this is what the feature is *for* |
| A leaf function whose in-module callers always switch exhaustively | `throws(E)` |
| Embedded / no-dynamic-allocation code | `throws(E)` |
| Anything crossing a module or package boundary | plain `throws` |

```swift
// ✓ the canonical case: callers mapping with a non-throwing closure see a non-throwing map,
//   with no `rethrows` magic and no `any Error` box.
extension Sequence {
    func map<U, E: Error>(_ body: (Element) throws(E) -> U) throws(E) -> [U]
}
```

Be precise about the failure mode, because the common summary ("typed throws don't survive `do`/`catch`") is wrong. A `do` block whose throwing calls all share **one** error type gives you a genuinely typed `catch` — this compiles on Swift 6.3.3:

```swift
do { _ = try loadFeed() } catch { let _: FeedError = error }   // ✓ `error` is FeedError
```

It degrades the moment you **mix** error types in one block, which in real code is most blocks:

```swift
do {
    let feed = try loadFeed()   // throws(FeedError)
    try cacheFeed(feed)         // throws(CacheError)
} catch {
    let _: FeedError = error
    // error: cannot convert value of type 'any Error' to specified type 'FeedError'
}
```

That is the argument for the untyped default: the benefit evaporates as soon as a second dependency joins the block, and you cannot predict which blocks those will be.

**Disagreement, stated honestly:** a run of 2026 blog posts pushes typed throws as general best practice; Donny Wals expects them to stay niche; SE-0413 itself lists only the three cases above. Side with the proposal.

**W34. Never spell out `throws(Never)` or `throws(any Error)`.** Write `func f()` and `func f() throws`.

### 7.2 Error enum design — the four audiences

Every thrown error serves four audiences simultaneously, and each wants something different:

| Audience | Needs | Mechanism |
|---|---|---|
| End users | localized, non-technical message | `LocalizedError.errorDescription` |
| Runtime code | catchable, distinguishable cases | Swift `enum` (not a struct) |
| Developers debugging | technical detail | default representation |
| Crash/monitoring tools | **stable** codes across app versions | `CustomNSError` + explicit `Int` raw values |

**W35. One error enum per capability or module — never one app-wide `AppError`. Conform to both `LocalizedError` and `CustomNSError`, and assign explicit `Int` raw values.**

Name the error for the domain (`LocationError`), not for the object that threw it — `02-NAMING-AND-API-DESIGN.md` N26 bans `Service` and `Manager` as type-name suffixes, and an error enum named after a banned type inherits the problem.

```swift
enum LocationError: Int, LocalizedError, CustomNSError {
    case missingAuthorization = 1
    case locationOutsideSupportedRegion = 2
    case serviceUnavailable = 3

    var errorDescription: String? {
        switch self {
        case .missingAuthorization:
            String(localized: "Location access is required to show nearby stops.")
        case .locationOutsideSupportedRegion:
            String(localized: "We don't have transit data for your area yet.")
        case .serviceUnavailable:
            String(localized: "Location services are temporarily unavailable.")
        }
    }
}
```

The raw values are load-bearing, and this is measurable rather than folklore. For an `Int`-backed enum, Foundation derives `CustomNSError.errorCode` — and therefore `NSError.code`, and therefore your Sentry grouping — straight from the raw value. Verified: `enum E: Int, LocalizedError, CustomNSError { case a = 7, b = 9 }` gives `(E.b as NSError).code == 9`. Leave the raw values implicit, let someone alphabetise the cases, and every historical crash group breaks silently.

An enum (not a struct) is what gives `catch` both granularities:

```swift
do { try await locator.currentLocation() }
catch LocationError.missingAuthorization { await requestAuthorization() }
catch is LocationError { showGenericAlert() }
```

### 7.3 `Result`, `try?`, `try!`

**W36. Throw; don't return `Result`.** Its historical job — carrying an error across an escaping completion handler — died with `async`/`await`. `Result` remains correct in exactly two places: storing a *completed* outcome as inspectable data (a cached "last refresh result"), and inside `withCheckedThrowingContinuation` when bridging a legacy callback API.

```swift
func load() async -> Result<Feed, FeedError>            // ✗ ceremony at every call site
func load() async throws -> Feed                        // ✓
```

**W37. `try!` is forbidden outside tests.** The only other defensible use is a failure impossible except by programmer error, and then W25's rules apply: say why, in a comment, on the line. (swift-format `NeverUseForceTry` — off by default; W54 turns it on.)

**W38. `try?` asserts that the failure *reason* does not matter. Nine times in ten it does.** If you write it, log at the call site.

```swift
let data = try? Data(contentsOf: url)                   // ✗ swallows why

guard let data = try? Data(contentsOf: url) else {      // ✓
    logger.warning("cache miss for \(url, privacy: .public)")
    return nil
}
```

### 7.4 `assert` vs `precondition` vs `fatalError`

| | Debug (`-Onone`) | Release (`-O`) | `-Ounchecked` |
|---|---|---|---|
| `assert` | evaluates, traps | *not evaluated, no effects* | not evaluated; optimizer **assumes true** |
| `precondition` | evaluates, traps | evaluates, traps | not evaluated; optimizer **assumes true** |
| `fatalError` | always traps | always traps | always traps |

**W39. `assert` for your own internal invariant. `precondition` for the caller's contract. `fatalError` for a state that is unreachable, never merely invalid — and always with a message.**

```swift
// ✓ caller contract → precondition (survives to Release)
func withdraw(_ amount: Decimal) {
    precondition(amount > 0, "withdraw amount must be positive, got \(amount)")
}

// ✓ own invariant → assert (gone in Release)
private mutating func rebalance() {
    assert(isBalanced, "rebalance left the tree unbalanced")
}

// ✓ unreachable → fatalError with a reason; it is the only breadcrumb in the crash report
required init?(coder: NSCoder) {
    fatalError("SessionView is code-only; it is never loaded from a nib")
}
```

**W40. Do not ship `-Ounchecked`.** Under it a failed `precondition` is not a crash, it is undefined behaviour — the optimizer already assumed the condition held and may have deleted the branch that handles the false case. It is a benchmarking flag. Every safety net you wrote becomes a promise you cannot keep.

---

## 8. Generics and existentials

**W41. Write `some` by default; change to `any` only when you must store arbitrary values.** Apple's framing at WWDC22: *"This workflow is similar to writing let-constants by default, until you know you need mutation."* The ladder is **concrete → `some` → `any`**, and you move right only when the compiler forces you.

```swift
// concrete: fastest, least flexible
static func imageFetcher(for url: URL) -> RemoteImageFetcher { RemoteImageFetcher(url: url) }

// opaque: one real type, hidden from callers, statically dispatched
static func imageFetcher(for url: URL) -> some ImageFetching { RemoteImageFetcher(url: url) }

// existential: the type genuinely varies at runtime — and only now
static func imageFetcher(for url: URL) -> any ImageFetching {
    url.isFileURL ? LocalImageFetcher(url: url) : RemoteImageFetcher(url: url)
}
```

**The cost, concretely.** SE-0335: existentials *"require dynamic memory unless the value is small enough to fit within an inline 3-word buffer"* and incur *"pointer indirection and dynamic method dispatch that cannot be optimized away."* **Three words** is the number to remember — `any` over a big struct is a hidden malloc on every boxing. You also lose type relationships: `==` does not work through a boxed protocol type, and a boxed value does not itself conform to the protocol, so `f(f(x))` fails to compile where the `some` version composes.

**W42. Store `any` at the boundary; open it to `some` the moment you need type relationships.** Implicit opening (SE-0352) does this for you when you pass an existential to a generic parameter.

```swift
func feed(_ animal: some Animal) { … }
func feedAll(_ animals: [any Animal]) {
    for animal in animals { feed(animal) }   // implicit opening: any Animal → some Animal
}
```

**W43. `ExistentialAny` is opt-in. Enable it on a new codebase; do not repeat the widespread claim that Swift 6 enforces it.** The Language Steering Group stated plainly that *"`ExistentialAny` … will not be enabled by default in Swift 6"*, contradicting a number of popular posts. Enabling it voluntarily is still right: it makes the cost visible at the declaration site.

```swift
// Package.swift
.target(name: "Core", swiftSettings: [.enableUpcomingFeature("ExistentialAny")])
```

*Cost:* a mechanical pass adding `any` across an existing codebase, and noisier signatures forever.
*Deviate when:* the codebase already exists and the diff would bury a release. Enable it on new targets only.

---

## 9. Protocols vs a struct of closures

**W44. Choose by what the seam *is*, not by how many conformers it has today. A protocol is justified when the seam is a published architectural boundary — a repository, a client, an ambient capability more than one module depends on (`04-ARCHITECTURE-AND-STATE.md` A24, A29, A41). A struct of closures wins for a narrow, single-purpose seam. The tiebreak is size: three members or fewer, ship the struct; four or more, ship the protocol.**

That threshold is this guide's one copy of the number, and it matches `06-TESTING.md` T39 from the test-double side.

The older formulation — "no protocol until the second conformer, and the mock is not the second conformer" — is a good instinct and a bad rule, because it forbids exactly the shapes the rest of this guide recommends: `ImageLoading` (A29) and `BookRepository` (A41) each have one real conformer and are still right, because a whole module is written against them and their conformers are swapped per *build*, not per test. What the instinct correctly rejects is the protocol that exists *only* so a test can inject a stub.

```swift
// ✗ two members, and the only other conformer is a mock
protocol WeatherAPI { func forecast(for city: City) async throws -> Forecast }
final class LiveWeatherAPI: WeatherAPI { … }
final class MockWeatherAPI: WeatherAPI { … }      // 40 lines of stub, all but one unused

// ✓ one concrete type, arbitrary test doubles, no `any`, no dynamic dispatch
struct WeatherClient: Sendable {
    var forecast: @Sendable (City) async throws -> Forecast
}
extension WeatherClient {
    static let live = WeatherClient { city in try await URLSession.shared.forecast(city) }
    static func constant(_ f: Forecast) -> WeatherClient { WeatherClient { _ in f } }
    static let failing = WeatherClient { _ in throw WeatherError.unavailable }
}
```

*Honest cost of the struct:* you lose `extension` default implementations, compiler-checked conformance ("did I implement everything?"), and readable autocomplete. Those costs scale with member count, which is why the threshold sits at three.
*Deviate when:* you need an associated-type relationship, conformance of types you already own, or a framework that demands a protocol. Those are real; "I need to mock a two-method seam" is not.

---

## 10. The metaprogramming budget

Property wrappers, macros, and result builders all buy the same thing — less code at the call site — and all charge in the same currency: readers who cannot see what runs. Spend deliberately.

**W45. Write a property wrapper only when the *same* get/set behaviour attaches to *many* properties and must run at runtime.** Validation, clamping, user-defaults backing, thread-checked access. The deciding axis: **property wrappers execute at runtime; macros execute at compile time.**

```swift
@propertyWrapper
struct Clamped<Value: Comparable> {
    private var value: Value
    private let range: ClosedRange<Value>

    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

struct PlaybackSettings {
    @Clamped(0...1) var volume: Double = 0.8
    @Clamped(0.5...2) var rate: Double = 1.0
}
```

One behaviour on one property of one type is not that. Write the computed property with a `private` backing store — a `@Trimmed` wrapper used once costs every reader a jump to another file to learn what `name` does.

**W46. You cannot use a property wrapper inside an `@Observable` type without `@ObservationIgnored`.** The macro rewrites stored properties into computed ones, and a property wrapper cannot be applied to a computed property. `@ObservationIgnored` restores the wrapper by removing the observation — usually not what you wanted. Design around this *before* you build a wrapper you intend to use in view models. (Reported consistently on the Swift Forums; I did not find a first-party Apple doc stating it, and Apple has shipped no fix as of Swift 6.3.3 — verify against your own type before relying on it.)

**W47. Consuming a macro is a completely different decision from authoring one.** Consuming a well-maintained one: usually fine. Authoring one in an app target: almost never worth it. Most write-ups miss this asymmetry.

**W48. Author a macro only when the alternative is boilerplate a human must keep in sync and the compiler cannot check.** The unbeatable case is compile-time validation of something the language has no literal for. Note the negative example first, because it is the one people reach for:

```swift
// ✗ don't write a regex macro — Swift 5.7+ regex *literals* are already compile-time checked
let email = /^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$/

// ✓ the shape that earns its keep: there is no URL literal, so a typo here is a runtime crash.
//   A macro moves it to a build failure. (`#URL` is a third-party macro, shown for shape.)
let base = #URL("https://api.example.com/v1")
```

A macro is a maintenance trap when it exists to save typing, encodes a project convention that will change, or is the *only* macro in your package — in which case you paid the entire SwiftSyntax bill for one feature. That bill is real (a separate host-built compiler-plugin target, a large dependency forwarded to every consumer, measurable cold-build regressions), but the specific multipliers circulating online are not independently verifiable; do not repeat a number you have not measured on your own project. Prebuilt SwiftSyntax binaries in recent toolchains reduce it — measure your own cold build before and after.

Two guarantees worth knowing: expansion is *"always an additive operation: macros add new code, but they never delete or modify existing code"*, and a macro **must not depend on external state** — not the clock, the file system, or the network. Input and output are both type-checked, which makes macros unusually easy to unit-test. Right-click → **Expand Macro** in Xcode to read what you actually shipped.

**W49. Before writing a macro, write out the code it would generate. If you would be happy reading that in the file, you do not need the macro.**

**W50. Write a result builder only when you are designing a language for a domain that is genuinely tree-shaped and that users will write a lot of.** SE-0289, Swift 5.4. `ViewBuilder`, `RegexBuilder`, a query DSL. Not for configuring a struct with eight properties — that is a memberwise initializer. Not for building an array — that is `map`.

```swift
@resultBuilder enum ConfigBuilder { … }                  // ✗
let c = Config { Timeout(30); Retries(3) }

let c = Config(timeout: .seconds(30), retries: 3)        // ✓ the boring thing is better
```

*The cost falls on your users, not you:* type-checking a builder body is expensive and the diagnostics are notoriously bad — one mistake in a large body yields "unable to type-check this expression in reasonable time", not a pointer to the mistake. The mitigation when you do ship one is the standard fix for slow SwiftUI compiles: keep bodies short by extracting subexpressions into named `let`s or separate `@ViewBuilder` computed properties.

---

## 11. Documentation comments

`02-NAMING-AND-API-DESIGN.md` owns how things are *named*; this is how they are *documented*.

**W51. `///`, never `/** */`. Summary first, as a single sentence fragment ending in a period. Then Discussion, then `- Parameters:`, `- Returns:`, `- Throws:`, in that order.**

```swift
/// Feeds the sloth the given food.
///
/// A sloth's energy level rises by the food's energy value multiplied by the
/// quantity eaten. Sloths refuse quantities greater than 100.
///
/// - Parameters:
///   - food: The food for the sloth to eat.
///   - quantity: The quantity of the food for the sloth to eat.
/// - Returns: The sloth's energy level after eating.
/// - Throws: ``SlothError/tooMuchFood`` if `quantity` is greater than 100.
public mutating func eat(_ food: Food, quantity: Int) throws -> Int
```

Double backticks are DocC symbol links; single backticks are plain code voice. Doc comments go **before** attributes and modifiers, not between them.

**W52. Document *why* and *what it costs*, never *what the signature already says*.** `/// The user's name.` above `var name: String` is noise. Document the contract: preconditions, actor/thread requirements, what it throws, what it costs, what it deliberately does *not* do. If a doc comment restates the signature, delete it.

**W53. In an app, document internal symbols too; in a library, `public` is the floor — and in a library, turn the three doc rules on.** All three ship **off** in swift-format 6.3.0, verified by `dump-configuration`: `AllPublicDeclarationsHaveDocumentation`, `BeginDocumentationCommentWithOneLineSummary`, `ValidateDocumentationComments`. So "disable it in an app" is a no-op you can skip — the actionable half is that a *published library* should enable all three, since the second enforces W51's summary sentence and the third catches parameter lists that have drifted from the signature. Do **not** enable the first in an app: it will demand a doc comment on every declaration and you will generate a hundred W52 violations to satisfy it. This file and W54 own that configuration; `02-NAMING-AND-API-DESIGN.md` §15 owns only the argument that the summary audits the name.

---

## 12. Formatting

**W54. Adopt `swift-format`. Yes, even solo. Then change four rules and one setting — the defaults already cover the rest.** It is in the toolchain (since Swift 6 / Xcode 16), needs no dependency, no build phase, and no version pinning against your Swift release, and it is what SourceKit-LSP already uses. `xcrun swift-format`, or `swift format` (space, not dash); in Xcode, **Editor → Structure → Format File with 'swift-format'** (⌃⇧I).

I dumped the real default configuration on 6.3.0: **43 rules, 31 on**. Most of what this file asks for is already enforced out of the box, which is why the config you commit should be short. Verified states:

| Rule | Default | This guide |
|---|---|---|
| `NoAccessLevelOnExtensionDeclaration` (W7), `AvoidRetroactiveConformances` (W17), `UseSingleLinePropertyGetter` (W21), `OneCasePerLine` (W28), `UseLetInEveryBoundCaseVariable` (W32), `UseShorthandTypeNames`, `UseTripleSlashForDocumentationComments` (W51), `OrderedImports`, `DoNotUseSemicolons`, `NoBlockComments`, `ReplaceForEachWithForLoop` | **on** | leave alone |
| `NeverForceUnwrap` (W25), `NeverUseForceTry` (W37), `UseEarlyExits` (W23), `AlwaysUseLiteralForEmptyCollectionInit` | **off** | **turn on** |
| `NeverUseImplicitlyUnwrappedOptionals` | off | **leave off** — it would reject the `@IBOutlet var label: UILabel!` W24 blesses, and there is no other spelling for an outlet |
| `AllPublicDeclarationsHaveDocumentation`, `BeginDocumentationCommentWithOneLineSummary`, `ValidateDocumentationComments` | off | app: leave off. Library: on (W53) |

So the whole committed file is the delta, nothing more:

```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": { "spaces": 4 },
  "rules": {
    "NeverForceUnwrap": true,
    "NeverUseForceTry": true,
    "UseEarlyExits": true,
    "AlwaysUseLiteralForEmptyCollectionInit": true
  }
}
```

**This list is the guide's single copy.** `07-TOOLING-BUILD-AND-SHIPPING.md` owns *where* the formatter runs (pre-commit hook, CI job, never a format build phase); `02-NAMING-AND-API-DESIGN.md` points here for both.

`NeverForceUnwrap` flags every `!`, including the sanctioned one in W25 — keep it on and suppress per site with `// swift-format-ignore: NeverForceUnwrap`. Re-run `xcrun swift-format dump-configuration` and diff it against your committed file after every toolchain bump; defaults do move between releases, and the point of committing only the delta is that the diff stays readable.

**W55. Set `indentation` to 4 explicitly.** swift-format's default is **2 spaces** (verified in the dump above); Xcode's editor default is **4**. Leave them mismatched and every file churns on every save. `lineLength` is already 100 by default — the line above sets it anyway, because it is the one number a reviewer will want to see stated.

**W56. Do not run `swift-format` and nicklockwood/SwiftFormat together.** They will fight. One formatter, plus optionally SwiftLint with its formatting-adjacent rules disabled, is the only sane combination.

*Deviation, honestly:* swift-format has no format-on-save in Xcode as of Xcode 26.6 — the 26.6 and 27-beta release notes do not mention swift-format at all, and the community workaround is a System Settings keyboard shortcut bound to the menu item; I could not confirm the absence of a first-party setting, only that the notes are silent. Its rule set is also smaller and less configurable than nicklockwood/SwiftFormat's. If either matters, SwiftFormat 0.62.x is strictly more capable and actively maintained; the trade is a dependency and a version to keep in step. Add **SwiftLint** on top only when you have a *team* and want rules a formatter cannot express — cyclomatic complexity, file length, forbidden APIs — and run it in CI, not in a build phase. This contradicts the common "use both SwiftLint and SwiftFormat" advice, which predates swift-format shipping in the toolchain.

---

## 13. Fails review on sight

| # | Smell | Fix | Caught by |
|---|---|---|---|
| 1 | Class used as a data bag | `struct` | W1 |
| 2 | `if let x = x` | `if let x` | W22 |
| 3 | `default:` in a switch over your own enum | list the cases | W29 |
| 4 | Bare `!` | `guard let … else { throw }`, or `URL(staticString:)` | `NeverForceUnwrap` flags **every** force-unwrap and cannot tell W24's two cases apart; a `!` you keep carries `// swift-format-ignore:` plus the proof (W25) |
| 5 | `try!` outside tests | propagate or handle | `NeverUseForceTry` (enable it) |
| 6 | `try?` silencing an error you should report | log or throw | W38 |
| 7 | Retroactive conformance in a library | wrapper type | `AvoidRetroactiveConformances` (default on) |
| 8 | `struct Constants { static let … }` | caseless `enum` | W16 |
| 9 | Access level on an `extension` declaration | per-member | `NoAccessLevelOnExtensionDeclaration` (default on) |
| 10 | `public` on everything in a multi-module package | `package` | W6 |
| 11 | Non-`final` class with no subclass | `final` | W10 |
| 12 | `[Foo]()`, `Array<Foo>()`, `Optional<String>` | `[Foo] = []`, `String?` | `AlwaysUseLiteralForEmptyCollectionInit` (**enable it**), `UseShorthandTypeNames` (default on) |
| 13 | `forEach` where a `for` loop belongs | `for x in xs` — `forEach` can't `break`/`continue`, and `return` doesn't exit the enclosing function | `ReplaceForEachWithForLoop` (default on) |
| 14 | `get { … }` on a read-only computed property | drop it | `UseSingleLinePropertyGetter` (default on) |
| 15 | `var` never mutated | `let` | compiler warning |
| 16 | Protocol with ≤3 members existing only so a test can stub it | struct of closures — but a repository/client boundary keeps its protocol at any conformer count | W44 |
| 17 | `unowned` capture | `weak`, or capture the value directly | W57 |
| 18 | `String` where an enum belongs (`track(event: "checkout_complte")` ships) | `enum AnalyticsEvent: String` | W2, row 1 |
| 19 | Multiple `Bool`s/optionals encoding a state machine | enum with associated values | W28 |
| 20 | A "this should never happen" log line | make the state unrepresentable | W28 |
| 21 | `fatalError()` with no message | always give a reason | W39 |
| 22 | `precondition` written expecting `-Ounchecked` to remove it | that's UB, not a no-op | W40 |
| 23 | Semicolons | delete | `DoNotUseSemicolons` (default on) |
| 24 | `/** */` block comments | `///` | `NoBlockComments` (default on) |
| 25 | A macro written to save typing | delete it | W48 |
| 26 | `public enum` in a library with no `@frozen`/`@nonexhaustive` | decide | W31 |

**W57. Avoid `unowned`; prefer `weak` or capturing the value directly.** `unowned` trades a crash you can debug for a crash you cannot. This entry owns the `weak` vs `unowned` ruling; `05-CONCURRENCY.md` §7.1 owns `weak let` (SE-0481, shipping in Swift 6.3) and is where to read about immutable back-references.

```swift
Task { [unowned self] in await self.refresh() }      // ✗
Task { [weak self] in await self?.refresh() }        // ✓
```

---

## Checklist

**Types** — [ ] W1 `struct` by default; a class needs a nameable reason · [ ] W2 type-choice table run top to bottom, stopped at first match · [ ] W3 no `actor` for a view model in a `MainActor`-default target · [ ] W4 large value type → COW after measuring, not a class · [ ] W5 *(6.4)* `~Sendable` on deliberately non-Sendable public types

**Access control** — [ ] W6 every access level chosen, not inherited · [ ] W7 none on an `extension` declaration · [ ] W8 no `fileprivate` that should be `private` · [ ] W9 `public final class` order · [ ] W10 every class `final` unless designed for subclassing

**Files** — [ ] W11 one top-level type per file, named for it · [ ] W12 one conformance per extension · [ ] W13 stored properties and designated inits in the primary declaration · [ ] W14 hand-written init wherever a `private` property collapsed the memberwise one · [ ] W15 `// MARK: -` between conformances only · [ ] W16 constants in a caseless `enum` or on the owning type · [ ] W17 no retroactive conformance in a library

**Immutability** — [ ] W18 `let` until the compiler forces `var` · [ ] W19 `if`/`switch` expressions, not assign-per-branch · [ ] W20 computed by default; `lazy` almost never, and never assumed thread-safe · [ ] W21 no `get` on read-only computed properties

**Optionals** — [ ] W22 `if let x` shorthand everywhere · [ ] W23 `guard` when the rest of the function needs it · [ ] W24 build-time `!` vs runtime `!` distinguished, and the two lint rules set accordingly · [ ] W25 no bare `!` — comment, helper, or `guard` · [ ] W26 chaining + `??` over nested `if let` · [ ] W27 *(6.4)* `any P?` without parens

**States and enums** — [ ] W28 no "this should never happen"; illegal states unrepresentable · [ ] W29 no `default:` over your own enum · [ ] W30 `@unknown default:` only for foreign non-frozen enums · [ ] W31 every library `public enum` marked `@nonexhaustive` or `@frozen` · [ ] W32 `case .x(let y)`, enforced by the default config, never discussed again

**Errors** — [ ] W33 untyped `throws` at boundaries; `throws(E)` only in the three listed cases · [ ] W34 no `throws(Never)`/`throws(any Error)` · [ ] W35 one error enum per capability, `LocalizedError` + `CustomNSError` + explicit `Int` raw values · [ ] W36 throw, don't return `Result` · [ ] W37 no `try!` outside tests · [ ] W38 no unexplained `try?` · [ ] W39 `assert` = your invariant, `precondition` = caller's contract, `fatalError` = unreachable + message · [ ] W40 not shipping `-Ounchecked`

**Generics** — [ ] W41 concrete → `some` → `any`, right only when forced · [ ] W42 `any` at the boundary, opened to `some` inside · [ ] W43 `ExistentialAny` enabled deliberately, not claimed as a Swift 6 default · [ ] W44 protocol for a published boundary or 4+ members; struct of closures otherwise

**Metaprogramming** — [ ] W45 property wrapper only for many properties + runtime behaviour · [ ] W46 `@Observable` + wrapper needs `@ObservationIgnored`, designed around · [ ] W47 authoring a macro held to a far higher bar than consuming one · [ ] W48 macro only where it removes a class of bug the language cannot already catch · [ ] W49 generated code written out first · [ ] W50 no result builder where a memberwise init or `map` would do

**Docs and format** — [ ] W51 `///`, summary fragment, Parameters/Returns/Throws in order · [ ] W52 documents the contract, not the signature · [ ] W53 three doc rules on in a library, off in an app · [ ] W54 `.swift-format` committed at the repo root, containing only the delta from the defaults · [ ] W55 `indentation` set to 4 explicitly · [ ] W56 exactly one formatter in the repo · [ ] W57 no `unowned` captures
