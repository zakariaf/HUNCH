# Concurrency

This file covers Swift's compile-time data-race model as it actually behaves on the toolchain shipping today: which settings to turn on and in what order, where mutable state should live, when `@MainActor` beats `Mutex` beats `actor`, how to read the diagnostics, how to bridge callback-era APIs, and how to migrate an existing app one shippable commit at a time. Read §2–§7 before you write the first line of a new app — that is the whole design decision. Read §12–§13 if you are staring at a wall of warnings in an existing one. Every diagnostic, availability claim and behaviour claim below was reproduced locally on **Swift 6.3.3 / Xcode 26.6 (build 17F113), 2026-07-27**; where I could not reproduce something I say so. Adjacent topics owned elsewhere: state ownership and view-model shape in `04-ARCHITECTURE-AND-STATE.md`, test mechanics in `06-TESTING.md`, where build settings live and how CI enforces them in `07-TOOLING-BUILD-AND-SHIPPING.md`, module and target layout in `01-PROJECT-STRUCTURE.md`, naming of async APIs in `02-NAMING-AND-API-DESIGN.md`.

---

## 1. Version ground truth

| Fact | Value | How I know |
|---|---|---|
| Compiler | Swift **6.3.3** (`swiftlang-6.3.3.1.3`) | `swift --version` on this machine |
| Xcode | **26.6** (17F113), iOS SDK **26.5** | `xcodebuild -version`, `xcrun --sdk iphoneos --show-sdk-path` |
| Next | Swift **6.4** / Xcode 27, beta as of 2026-07-27 | §14 — not shippable yet |
| `Mutex` (`import Synchronization`) | **iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2** | Compiling for `-target arm64-apple-ios17.0`: `error: 'Mutex' is only available in iOS 18.0 or newer` |
| `OSAllocatedUnfairLock` (`import os`) — and it is **`Sendable`** | **iOS 16 / macOS 13 / tvOS 16 / watchOS 9** | `iPhoneOS26.5.sdk` `os.swiftmodule/arm64e-apple-ios.swiftinterface:2393`: `@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)` / `@frozen public struct OSAllocatedUnfairLock<State> : @unchecked Swift.Sendable`. `init(initialState:)` is the `where State: Sendable` overload. §6 — this is why an iOS 17 floor does **not** cost you an escape hatch |
| `weak let` (SE-0481) | Ships **today** in Swift 6.3 | §7.1 — compiled it |
| `isolated deinit` (SE-0371) | Compiles today, down to an iOS 17 deployment target | §10 — compiled it |
| `withTaskCancellationShield`, `async` in `defer` | **Do not exist** in 6.3.3 | `error: cannot find 'withTaskCancellationShield' in scope`; `error: 'async' call cannot occur in a defer body` |

Swift 6.2 was the watershed for concurrency ergonomics (SE-0461, SE-0466, SE-0470). 6.3 and 6.4 are refinements. Any Xcode 26.x has all the 6.2 machinery.

**R1. Decide the deployment target before you design isolation — but do not let anyone sell you iOS 18 on an `@unchecked Sendable` count.** iOS 18+ gives you `Mutex`, which is the nicer API and the one R17 names first. What it does *not* give you is checked `Sendable` for lock-protected classes, because you already had that: `OSAllocatedUnfairLock` is itself `Sendable` and has been since iOS 16, so a `final class` whose only stored property is a `let` of one conforms to plain, compiler-verified `Sendable` (§6, compiled at `-target arm64-apple-ios17.0`). *Real cost of holding iOS 17:* `import os` instead of `import Synchronization`, no `~Copyable` value support, and no typed-throws `withLock`. That is a worse toolbox, not a worse safety story — so if you are writing `@unchecked Sendable` on an iOS 17 target because "`Mutex` is unavailable", R27 says you have a bug, not a constraint.

---

## 2. Settings: what to turn on, and the one trap in the default template

A new Xcode 26.6 app is created with `SWIFT_VERSION = 5.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, and (on the app target) `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. I read those three out of Xcode's own template plists on 2026-07-27. That combination gives you Swift 6 *ergonomics* with Swift 5 *enforcement*: `SWIFT_STRICT_CONCURRENCY` resolves to `complete` only when the language mode is 6, otherwise `minimal`.

**R2. New app: set the language mode to 6 in commit one and keep Approachable Concurrency on.**

```text
SWIFT_VERSION                  = 6.0        # language mode, not compiler version
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION  = MainActor  # app/UI targets only — see R7
```

*Cost:* a handful of SDK corners are still awkward in Swift 6 mode and you meet them in week one. *Deviate when:* you depend on a large unmigrated first-party framework — then stay at 5.0 with `SWIFT_STRICT_CONCURRENCY = complete` and follow §13. `07-TOOLING-BUILD-AND-SHIPPING.md §1` owns where these lines live (xcconfig, not pbxproj) and the `YES | MIGRATE | NO` mechanics.

SwiftPM equivalent. With `// swift-tools-version: 6.2` the language mode is already 6:

```swift
// swift-tools-version: 6.2
.target(
    name: "AppFeature",
    swiftSettings: [
        .defaultIsolation(MainActor.self),                      // or `nil` for nonisolated
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        // The three below are implied by language mode 6; list them only for a v5 target.
        .enableUpcomingFeature("InferSendableFromCaptures"),
        .enableUpcomingFeature("DisableOutwardActorInference"),
        .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    ]
)
```

**R3. Know which of the five "approachable" features Swift 6 mode gives you for free — it is three, not five.** Read out of `Swift.xcspec` in Xcode 26.6: `InferSendableFromCaptures`, `DisableOutwardActorInference` and `GlobalActorIsolatedTypesUsability` are conditioned on Swift 4/4.2/5 and are always on in language mode 6. `NonisolatedNonsendingByDefault` and `InferIsolatedConformances` default to `$(SWIFT_APPROACHABLE_CONCURRENCY)` with **no** language-mode condition — Swift 6 mode alone does not enable them. I confirmed the first one at runtime (§5): with language mode 6 and the feature off, a bare `nonisolated func … async` still runs off the caller's actor.

**R4. Never ship `SWIFT_STRICT_CONCURRENCY = minimal` in a codebase that uses `async`/`await`.** All of the semantics, none of the checking. It is the worst configuration available.

**R5. Turn Approachable Concurrency on *before* raising strictness.** SE-0461 and SE-0470 delete whole classes of error; going to `complete` first means a day spent fixing diagnostics that were about to disappear.

**R6. Verify a feature name before you commit it.** An unrecognised `-enable-upcoming-feature` name is accepted silently and does nothing. `swiftc -print-supported-features` lists the real ones.

---

## 3. Default isolation: split it by module

Genuinely contested. Apple (WWDC25 268) recommends `MainActor` default for "modules primarily interacting with the UI, such as your main app module", and Xcode's template agrees. Matt Massicotte argues against on comprehensibility grounds — "it is not possible to fully understand how or even if Swift code works without knowing this setting" — and the Swift Forums new-project thread landed on `nonisolated`. Both are right, about different modules.

**R7. `MainActor` default for app/UI/view-model targets; `nonisolated` default for model, networking, persistence, and anything you might extract into a package.**

| Target | Default isolation | Why |
|---|---|---|
| App target, feature/UI modules, view models | `MainActor` | Single-threaded in practice; SwiftUI is already `@MainActor`; kills annotation noise |
| Networking, persistence, parsing, domain model | `nonisolated` | A main-actor-by-default data layer is a design error you pay for the first time you profile |
| Any SwiftPM package you may publish | `nonisolated` | Your clients choose their isolation, not you |

*Honest cost:* you maintain a module boundary, and a bare `func` means different things in different targets. That dialect problem is real. Mitigate with R8. `01-PROJECT-STRUCTURE.md P16` owns the move-code-into-a-package version of this trap.

**R8. In a `MainActor`-default module, write `@MainActor` explicitly on every declaration visible outside its own file.** The declaration should read correctly without knowing the build setting. Redundant annotations are free; unreadable headers are not.

**R9. Never change default isolation and language mode in the same commit, and never flip default isolation across a large existing app at once.** SE-0466 states plainly that changing it is source-incompatible. Both `-default-isolation MainActor` and `-default-isolation=MainActor` are accepted by the driver; Xcode emits the second.

---

## 4. Every diagnostic is one of two questions

Each declaration is in exactly one bucket: **nonisolated** (no domain), **actor-isolated** (one actor instance), or **global-actor-isolated** (a process-wide domain such as `@MainActor`). Mutable state is reachable from one domain at a time, checked at compile time.

**R10. Classify the diagnostic before you fix it.**

| The compiler is asking | Class | Fix lives in |
|---|---|---|
| "Can this *value* cross this boundary?" | **A — `Sendable` / `sending`** | §7, §12.3 |
| "Am I allowed to touch this *state* from here?" | **B — isolation** | §3, §5, §6, §12.2 |

Almost every bad fix in the wild is a class-B error misdiagnosed as class-A: `@unchecked Sendable` bolted onto a type to silence what was really a missing `@MainActor` on the caller. Say the question out loud first.

**R11. Memorise the four inference rules.** All four compile as shown on 6.3.3:

```swift
@MainActor class Animal {}
class Chicken: Animal {}                  // 1. subclasses inherit isolation and CANNOT change it

@MainActor protocol Feedable { func eat(_ f: Pineapple) }
final class Hen: Feedable { func eat(_ f: Pineapple) {} }   // 2. conformance in the primary
                                                            //    declaration isolates the WHOLE type
extension Pirate: Feedable { func eat(_ f: Pineapple) {} }  // 3. conformance in an extension
                                                            //    isolates ONLY that extension
// 4. closures inherit their enclosing context: `Task { }` inherits,
//    `Task { @MyActor in }` overrides, `Task.detached { }` inherits nothing.
```

**R12. `await` is not a critical section. Actors are not atomic across suspension points.**

```swift
// WRONG: `island.food` can change while suspended. Compiles clean. Races.
func deposit(_ pineapples: [Pineapple], onto island: Island) async {
    var food = await island.food
    food += pineapples
    await island.store(food)
}

// RIGHT: the read-modify-write is one synchronous step inside the actor.
extension Island {
    func deposit(_ pineapples: [Pineapple]) { food += pineapples }   // no await inside
}
await island.deposit(pineapples)
```

Data-race safety is not logic-race safety. This is the most common misunderstanding among people whose migration is "done".

---

## 5. `nonisolated` no longer means "background"

**R13. If you used `nonisolated func … async` to get off the main thread, that code now runs *on* the caller's actor. Audit every one.** SE-0461 (Swift 6.2) changed it. Apple DTS confirmed real-world breakage on the developer forums (thread 812598) and told the reporter to move forward with the new settings and fix the code, not revert.

Reproduced here — same file, same language mode, one flag apart, printing whether the callee ran on the main thread when called from a `@MainActor` function:

```text
$ swiftc -swift-version 6 probe.swift && ./probe                       # feature OFF
bare nonisolated        -> onMainThread: false
$ swiftc -swift-version 6 -enable-upcoming-feature \
      NonisolatedNonsendingByDefault probe.swift && ./probe            # feature ON
bare nonisolated        -> onMainThread: true
@concurrent             -> onMainThread: false
nonisolated(nonsending) -> onMainThread: true
```

| Spelling | Where it runs | Use it for |
|---|---|---|
| `@concurrent func f() async` | Always off the caller's actor | Work you profiled and decided to offload |
| `nonisolated(nonsending) func f() async` | On the caller's actor | The explicit form of the new default |
| bare `nonisolated func f() async` | Caller's actor **if** `NonisolatedNonsendingByDefault` is on, otherwise off it | Nothing — say which you mean |

```swift
// WRONG post-6.2: silently runs on the caller's actor, usually the main one.
nonisolated func decodeLargeImage(_ data: Data) async -> UIImage? { … }

// RIGHT: explicit offload.
@concurrent func decodeLargeImage(_ data: Data) async -> UIImage? { … }
```

**R14. Do the audit with the compiler's migrate mode, not with grep.** The feature's `:migrate` variant flags every affected declaration with a fix-it, in both language modes:

```bash
swiftc -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault:migrate …
# warning: feature 'NonisolatedNonsendingByDefault' will cause nonisolated async global
#          function 'decode' to run on the caller's actor; use '@concurrent' to preserve
#          behavior [#NonisolatedNonsendingByDefault]
```

In Xcode that is `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT = MIGRATE`. Apply the fix-its, review each one — the fix-it preserves *old* behaviour, which is not always what you want — then flip to `YES`. Keep `rg -n --type swift -U 'nonisolated\s+func[^\n{]*\basync\b'` as a second pass for code the compiler cannot see (protocol witnesses in unmigrated targets).

**R15. `@concurrent` in app code where you profiled a bottleneck; plain `nonisolated` in library code so the caller decides.** Apple's own guidance for general-purpose libraries is to ship nonisolated API. `@concurrent` in a public signature makes a scheduling decision your client cannot undo.

**R16. Never add `@concurrent` speculatively.** Xcode 27's Swift Executors instrument (tracks for the cooperative pool, main actor and custom executors) is the right tool; before that, Time Profiler filtered to the main thread. No credible published per-hop cost figures exist — do not quote any, measure your own.

---

## 6. Where state lives: `@MainActor`, then `Mutex`, then `actor`

Apple's position (WWDC25 268) is more conservative than community practice and it is correct: "most of the classes in your app probably are not meant to be actors: UI-facing classes should stay on the main actor… Model classes should generally be on the main actor with the UI, or kept non-Sendable."

**R17. The decision procedure. One answer per row.**

| Situation | Use | Not |
|---|---|---|
| State is UI state, or read by UI | `@MainActor` on the type | an actor |
| Small state, synchronous access, no `await` in the critical section | `Mutex` (iOS 18+) | an actor |
| Cohesive state *with behaviour*, callers already async, critical section must `await` | `actor` | `Mutex` — you cannot hold a lock across `await` |
| A value that needs to reach another domain exactly once | plain non-`Sendable` type + `sending` | a `Sendable` conformance |
| Pre-iOS-18 target needing a lock | `final class` + `let` of `OSAllocatedUnfairLock` + plain `: Sendable` | `@unchecked Sendable` — you do not need it |

```swift
// ANTI-PATTERN: unchecked, hand-rolled, and obsolete on every floor this guide contemplates.
final class Counter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()
    func increment() { lock.lock(); value += 1; lock.unlock() }
}

// RIGHT (iOS 18+): CHECKED Sendable. `Mutex` is Sendable, the property is `let`,
// the compiler verifies the whole type. No escape hatch anywhere.
import Synchronization

final class Counter: Sendable {
    private let value = Mutex(0)
    func increment() { value.withLock { $0 += 1 } }
    func read() -> Int { value.withLock { $0 } }
}
```

**On iOS 16–17 the answer is the same shape, one import different — and still checked.** `OSAllocatedUnfairLock` is `Sendable` (§1), so the surrounding class needs no annotation; the only thing you lose is `Mutex`'s ergonomics. Compiled on 6.3.3 at `-swift-version 6 -target arm64-apple-ios17.0`: clean, with no `@unchecked` anywhere.

```swift
import os

final class Counter: Sendable {
    private let value = OSAllocatedUnfairLock(initialState: 0)
    func increment() { value.withLock { $0 += 1 } }
    func read() -> Int { value.withLock { $0 } }
}
```

Two footnotes so you do not trip on the API. Use `init(initialState:)`, which is the overload constrained to `State: Sendable`; `init(uncheckedState:)` is the escape hatch and R26 applies to it. And `withLock` here requires a `@Sendable` body returning a `Sendable` result, which is a slightly tighter constraint than `Mutex.withLock` — if your state is a non-`Sendable` class, you wanted an `actor` or `@MainActor` anyway.

*Cost of preferring `Mutex`:* `withLock` is non-async and non-escaping, so awaiting inside it is a compile error. That restriction is the feature — the day you genuinely need to `await` mid-critical-section you must move to an actor and confront reentrancy (§8). *Cost of preferring `actor`:* every caller becomes `async`, which is a viral API change that is hard to walk back. That is why it is third.

**R18. Never make an actor to protect a counter, a flag, or a cache dictionary with synchronous accessors.** You pay an executor hop and infect every caller with `async` to guard a `+= 1`.

**R19. Do not write custom `SerialExecutor` / `unownedExecutor` conformances without a measured interop reason** — typically an existing serial `DispatchQueue` you must share. The escape hatch exists; it is not a default.

**R20. New code does not use `DispatchQueue`.** `DispatchQueue.main.async { }` is `Task { @MainActor in }` or, from an already-async context, `await MainActor.run { }`. `DispatchQueue.global().async { }` is `@concurrent`. Keeping GCD alongside structured concurrency means two schedulers with no shared priority or cancellation model.

---

## 7. `Sendable`, `sending`, and the value of staying non-`Sendable`

### 7.1 What you get for free

| Kind | Implicitly `Sendable`? |
|---|---|
| Non-public value type whose stored properties are all `Sendable` | **Yes** |
| **Public** value type, same contents | **No** — you must write it |
| `actor` | **Yes**, even with non-`Sendable` stored properties |
| Global-actor-isolated type (`@MainActor class X`) | **Yes** |
| Any other reference type | **Never** |

**R21. Write `: Sendable` explicitly on every public value type clients need to send.** Its absence is invisible from the outside and clients cannot fix it. Library authors can make the compiler nag: `-Wwarning ExplicitSendable` is live in 6.3.3 and emits `warning: public struct 'Money' does not specify whether it is 'Sendable' or not [#ExplicitSendable]`.

A class is *checked* `Sendable` only if it is `final`, has no mutable stored properties, and all its properties are `Sendable`. **A weak back-reference no longer costs you the conformance** — SE-0481 `weak let` ships in Swift 6.3, today, and is not a 6.4 preview:

```swift
final class Chick: Sendable {
    let name: String
    weak let coop: Coop?      // ✅ compiles on 6.3.3
    init(name: String, coop: Coop?) { self.name = name; self.coop = coop }
}

final class Chick2: Sendable {
    weak var coop: Coop?      // ❌ error: stored property 'coop' of 'Sendable'-conforming
                              //    class 'Chick2' is mutable
}
```

Read `weak let` as "this binding never changes", not "this reference never becomes nil" — the referent can still be deallocated. Prefer it for every back-reference you do not reassign; `weak var` is now the one that needs a justification. (`03-WRITING-THE-CODE.md` owns the wider `weak` vs `unowned` ruling.)

### 7.2 `Sendable` vs `sending`

`Sendable` = safe for **concurrent** use by many domains, forever, as a property of the type. `sending` (SE-0430, Swift 6.0) = a **complete transfer**: every use in the source region ends before any use begins in the destination.

```swift
public struct ColorComponents { public let red, green, blue: Float }   // public → NOT implicitly Sendable
@MainActor func applyBackground(_ color: ColorComponents) {}

// ❌ error: sending 'backgroundColor' risks causing data races [#SendingRisksDataRace]
//    note: sending task-isolated 'backgroundColor' to main actor-isolated global function
//          'applyBackground' risks causing data races between main actor-isolated and
//          task-isolated uses
func updateStyle(backgroundColor: ColorComponents) async {
    await applyBackground(backgroundColor)
}

// ✅ transfer instead of share
func updateStyle(backgroundColor: sending ColorComponents) async {
    await applyBackground(backgroundColor)
}
```

**R22. When a non-`Sendable` value needs to get over there exactly once, the fix is `sending`, not `Sendable`.** Adding `Sendable` constrains the type's design permanently — no mutable state, ever — to solve a one-time hand-off.

**R23. Passing a non-`Sendable` value to an `@concurrent` function is *not* an error, and you may keep using the value afterwards.** The caller is suspended for the duration, so the uses cannot overlap. Verified: the code below compiles clean on 6.3.3. The error appears only when the value reaches somewhere that outlives the call — an actor, a global-actor function, a stored `Task`.

```swift
final class Payload { var bytes: [UInt8] = [] }
@concurrent func upload(_ p: Payload) async {}

@MainActor func send() async {
    let p = Payload()
    await upload(p)            // ✅ fine — `send` is suspended while `upload` runs
    print(p.bytes.count)
}

actor Uploader { var last: Payload?; func store(_ p: Payload) { last = p } }

@MainActor func leak(_ u: Uploader) async {
    let p = Payload()
    await u.store(p)           // ❌ sending 'p' risks causing data races
    print(p.bytes.count)       //    note: access can happen concurrently
}
```

The practical consequence: these diagnostics are **flow-sensitive**, not signature-sensitive. Deleting the later use often fixes the error without any annotation.

### 7.3 Non-`Sendable` is a design, not a failure

Non-`Sendable` types are also thread-safe — the compiler guarantees they never cross a boundary. A plain non-`Sendable`, non-isolated model type used from one domain is the *cheapest correct* design.

**R24. If you can remove isolation from a type, remove it.** Isolation on a type used from exactly one place is pure friction.

**R25. A non-`Sendable` type with `async` methods is a red flag.** `self` cannot cross domains, so the method is quietly unusable from anywhere else. Thread the caller's isolation through instead:

```swift
// SUSPECT: callers on another actor cannot call this at all.
final class Importer { func run() async { … } }

// RIGHT: the compiler now knows isolation does not change across the call.
final class Importer {
    func run(isolation: isolated (any Actor)? = #isolation) async { … }
}
```

### 7.4 `@unchecked Sendable` is a lie you pay for

**R26. Treat `@unchecked Sendable` as a defect unless it carries a comment naming the exact synchronisation mechanism.** It is a promise to a compiler that cannot check you, in a language whose entire value proposition here is that the compiler checks you.

The failure mode is not theoretical. Jared Sinclair's example compiles clean and crashes in production, because a non-`@Sendable` closure typealias captured main-actor isolation and the `Box` hid it:

```swift
final class Box<T>: @unchecked Sendable {        // the lie
    var value: T
    init(_ value: T) { self.value = value }
}

enum Logging {
    typealias LoggingSink = (String) -> Void     // NOT @Sendable — the actual bug
    private static let _sink = Box<LoggingSink>({ print($0) })
    static var sink: LoggingSink {
        get { _sink.value }
        set { _sink.value = newValue }
    }
}

Logging.sink = { print($0) }                     // in App.init(): implicitly @MainActor
DispatchQueue.global().async { Logging.sink("x") }   // CRASH: dispatch_assert_queue

// The fix is at the TYPE level, not the annotation level:
typealias LoggingSink = @Sendable (String) -> Void
```

**R27. Three surviving legitimate uses, each requiring the comment:** (1) wrapping a C/C++ type you do not control that is documented thread-safe; (2) bridging a thread-safe but unannotated Objective-C class you cannot mark `NS_SWIFT_SENDABLE`; (3) deployment targets below **iOS 16**, where neither `Mutex` nor `OSAllocatedUnfairLock` exists.

**"My target is iOS 17, so I need `@unchecked Sendable` for locks" is not on that list, and it is the most common false one.** `OSAllocatedUnfairLock` is `Sendable` from iOS 16, so R17's pre-18 row is checked. Reason (3) is therefore dead for every floor `01-PROJECT-STRUCTURE.md §5b` contemplates — it is written down only so that the day you inherit an iOS 15 target you know why the rule bends.

```swift
/// Thread-safe: every access to `_entries` is serialised on `queue`.
final class ImageCache: @unchecked Sendable { … }
```

**R28. For a type you do not own, the escape hatch is `@retroactive`, and it is a last resort:** `extension Foo: @retroactive @unchecked Sendable {}`. If two modules do this for the same type, behaviour is undefined at link time.

**R29. Grep CI for `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency import`, `Task.detached` and `assumeIsolated`, and require a justifying comment on each.** The term list is this file's; the pipeline wiring is `07-TOOLING-BUILD-AND-SHIPPING.md`.

---

## 8. Actors: reentrancy is the bug that survives your migration

Actors serialise access but do **not** hold their lock across `await`. Every `await` inside an actor method is a door another call walks through.

```swift
// WRONG — 5 concurrent reads of the same key produce 5 network requests.
actor DataCache {
    private var cache: [UUID: Data] = [:]
    private let remote: any RemoteCache

    func read(_ key: UUID) async throws -> Data {
        if let data = cache[key] { return data }   // all 5 callers miss here…
        let data = try await remote.read(key)      // …suspend here…
        cache[key] = data                          // …and all 5 fetch, then all 5 write.
        return data
    }
}
```

**R30. Cache the `Task`, not the value.** Storing the task is synchronous, so it lands before the first suspension and later callers find it.

```swift
actor DataCache {
    private enum Entry { case inProgress(Task<Data, Error>), loaded(Data) }
    private var cache: [UUID: Entry] = [:]
    private let remote: any RemoteCache

    init(remote: any RemoteCache) { self.remote = remote }

    func read(_ key: UUID) async throws -> Data {
        switch cache[key] {
        case .loaded(let data):     return data
        case .inProgress(let task): return try await task.value
        case nil:
            let task = Task { [remote] in try await remote.read(key) }
            cache[key] = .inProgress(task)          // synchronous — no suspension yet
            do {
                let data = try await task.value
                cache[key] = .loaded(data)
                return data
            } catch {
                cache[key] = nil                    // never cache the failure
                throw error
            }
        }
    }
}
```

*Cost:* the stored `Task` no longer propagates the caller's priority, and cancelling one caller does not cancel the shared fetch. If you need those, escalate to continuation tracking (`.empty` / `.pending([Continuation])` / `.filled`) plus `withTaskCancellationHandler` and a `[UUID: Continuation]` registry — Massicotte's ConcurrencyRecipes grades four variants. Do not build that until a requirement forces it.

**R31. State read before an `await` must be re-validated after it, or the mutation must happen synchronously before the first suspension.**

**R32. Recognise the three wrong reentrancy fixes in review:** marking the method `nonisolated` (moves the problem), adding an `isLoading` flag and returning `nil` early (silently drops results), wrapping the body in a lock (impossible — you cannot lock across `await`). Apple's own `NetworkManager.openConnection(for:)` slide sample from WWDC25 268 has this bug; it is a fine illustration of API shape and a bad one of caching.

---

## 9. `@MainActor` and SwiftUI

SwiftUI's `View` protocol is `@MainActor`-isolated, because that reflects the runtime behaviour SwiftUI already implements. A few SwiftUI APIs genuinely run off the main actor — `Shape.path`, `visualEffect`, `Layout` methods, `onGeometryChange`, built-in animations — which is why their closures require `@Sendable` and cannot read `@State` directly.

```swift
// ❌ data race: `pulse` is @MainActor state, the closure is not.
.visualEffect { content, _ in content.blur(radius: pulse ? 2 : 0) }

// ✅ capture a copy in the capture list.
.visualEffect { [pulse] content, _ in content.blur(radius: pulse ? 2 : 0) }
```

**R33. Update UI state synchronously, *then* start the async work.** Especially when the update drives a time-sensitive animation.

```swift
struct ColorExtractorView: View {
    @State private var model = ColorExtractor()

    var body: some View {
        ColorSchemeView(isLoading: model.isExtracting, colorScheme: model.scheme)
            .onTapGesture {
                withAnimation { model.isExtracting = true }   // synchronous
                Task {
                    await model.extractColorScheme()
                    withAnimation { model.isExtracting = false }
                }
            }
    }
}
```

**R34. Consume async work from a view with `.task`, not `.onAppear` + `Task { }`.** `.task` cancels its work when the view goes away and re-runs on an `id:` change; `onAppear` gives you an unstructured task nobody owns.

```swift
Text(model.status)
    .task { await model.observe(events) }        // cancelled with the view
    .task(id: userID) { await model.load(userID) }  // cancelled and restarted on change
```

**R35. Use `nonisolated init` when a `@MainActor` type must be constructible from anywhere.**

```swift
@MainActor
final class WindowStyler {
    private var viewStyler = ViewStyler()
    private var primaryStyleName: String
    nonisolated init(name: String) { self.primaryStyleName = name }
}
```

**R36. `MainActor.assumeIsolated` only where a framework contract guarantees the thread; `await MainActor.run` when you need to get there.** `assumeIsolated` asserts and crashes if you are wrong — it is not a way to paper over an unknown. Custom global actors must hand-roll their own `assumeIsolated`; generic actor isolation cannot be expressed, so every one implements it manually.

Where view state itself should live, and what belongs in a view model at all, is `04-ARCHITECTURE-AND-STATE.md`.

---

## 10. Structured concurrency, `Task`, and cancellation

| Need | Use |
|---|---|
| Known, fixed number of concurrent children | `async let` |
| Dynamic number of children | `withTaskGroup` / `withThrowingTaskGroup` |
| Bridge a synchronous callback (SwiftUI action, delegate) into async | `Task { }` |
| Anything else | one of the first three |

**R37. `Task { }` is a smell *inside an already-async function*, and not a smell at a synchronous→asynchronous boundary.** Inside async code it means you dropped out of structured concurrency and lost cancellation and priority propagation for nothing. In a tap handler it is the only door, and Apple's own sample code uses it.

```swift
// WRONG: unstructured, uncancellable, no priority propagation, no error surface.
func loadAll() async {
    Task { await loadProfile() }
    Task { await loadFeed() }
}

// RIGHT: structured. Both are cancelled if `loadAll`'s task is cancelled.
func loadAll() async {
    async let profile: Void = loadProfile()
    async let feed: Void = loadFeed()
    _ = await (profile, feed)
}
```

**R38. `Task.detached` is essentially always wrong in app code.** It discards isolation, priority and task-locals. If you want off-actor execution, `@concurrent` is the modern, checked answer.

**R39. Bound the width of a task group over an unbounded input.** `for id in ids { group.addTask { … } }` over 5,000 ids starts 5,000 concurrent requests. Prime a window, then add one child per completion:

```swift
func fetchAll(_ ids: [Int], limit: Int = 4,
              fetch: @escaping @Sendable (Int) async throws -> Data) async throws -> [Int: Data] {
    try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        var results: [Int: Data] = [:]
        var iterator = ids.makeIterator()
        for _ in 0..<limit {
            guard let id = iterator.next() else { break }
            group.addTask { (id, try await fetch(id)) }
        }
        while let (id, data) = try await group.next() {
            results[id] = data
            if let next = iterator.next() {
                group.addTask { (next, try await fetch(next)) }
            }
        }
        return results
    }
}
```

**R40. Cancellation is a request, never a preemption — code that never checks never stops.** `Task.isCancelled`, `try Task.checkCancellation()`, `withTaskCancellationHandler(operation:onCancel:)`. Structured children are cancelled automatically when the parent scope exits or throws; unstructured tasks are not.

**R41. `onCancel:` runs immediately, on whatever thread cancelled, and is not isolated to your actor.**

```swift
// WRONG: onCancel is nonisolated; it cannot touch actor state.
try await withTaskCancellationHandler { try await fetch(id) }
                            onCancel: { self.pending[id] = nil }

// RIGHT: hop deliberately.
try await withTaskCancellationHandler { try await fetch(id) }
                            onCancel: { Task { await self.cancelPending(id) } }
```

**R42. Clean up actor-isolated state with `isolated deinit`, not a `Task` — and never capture `self` in a `deinit`'s `Task`.** `isolated deinit` (SE-0371) compiles on 6.3.3, including for an iOS 17 deployment target. *Cost:* if the last release happens off the actor, destruction is scheduled rather than immediate, so deallocation timing becomes non-deterministic — verify on your minimum OS before relying on it for anything time-sensitive.

```swift
@MainActor final class Screen {
    var token: Int = 0
    isolated deinit { token = 0 }        // runs on the main actor
}

// Where you cannot use it (or need async cleanup), capture the dependency, never self:
actor BackgroundStyler {
    private let store = StyleStore()
    deinit { Task { [store] in await store.stopNotifications() } }
}
```

Capturing `self` there resurrects a deallocating object and crashes at runtime.

---

## 11. Bridging callback-era APIs

**R43. Completion handler → `async` with `withCheckedContinuation`, resumed exactly once.** Zero resumes is a permanent hang; two is a crash. `withUnsafeContinuation` only after profiling proves the check costs something real.

```swift
func updateStyle(backgroundColor: ColorComponents) async {
    await withCheckedContinuation { continuation in
        updateStyle(backgroundColor: backgroundColor) { continuation.resume() }
    }
}
```

**R44. If the underlying call can be cancelled, wrap the continuation in `withTaskCancellationHandler`.** An `async` wrapper that ignores cancellation makes every caller's cancellation a lie.

**R45. Delegate → `AsyncStream` with `AsyncStream.makeStream(of:)`, not the `lazy` + optional-continuation dance.**

```swift
final class LocationStream: NSObject, CLLocationManagerDelegate {
    let stream: AsyncStream<CLLocation>
    private let continuation: AsyncStream<CLLocation>.Continuation
    private let manager = CLLocationManager()

    override init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: CLLocation.self,
            bufferingPolicy: .bufferingNewest(1)        // R46
        )
        self.stream = stream
        self.continuation = continuation
        super.init()
        manager.delegate = self
        continuation.onTermination = { [manager] _ in manager.stopUpdatingLocation() }   // R47
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations { continuation.yield(location) }
    }
}
```

**R46. Always choose a buffering policy explicitly.** The default is unbounded: every yielded value is buffered until consumed, so a producer that outruns its consumer grows memory without limit. `.bufferingNewest(1)` for latest-value-wins UI state; `.bufferingOldest(n)` when early events matter.

**R47. Set `onTermination` at construction time**, so the resource is released when the consumer goes away.

**R48. `AsyncStream` is single-consumer.** Two `for await` loops over one stream do not both see every value. For multicast, hand out one stream per observer or use a broadcast operator from swift-async-algorithms.

**R49. Annotate Objective-C at the source; prefer localised `nonisolated(unsafe)` over a file-wide `@preconcurrency import`.** A preconcurrency import does not mean "unsafe" — it means "this library is missing annotations and I am using it correctly" — but it reduces checking across the whole file, so keep the blast radius small. For headers you own, `NS_SWIFT_SENDABLE`, `NS_SWIFT_NONISOLATED`, `NS_SWIFT_UI_ACTOR`, `NS_SWIFT_ASYNC(...)` and the general `__attribute__((swift_attr("…")))` are strictly better than fixing it on the Swift side.

---

## 12. The diagnostics you will actually hit

All diagnostic text below is what Swift 6.3.3 emits today; older blog posts quote earlier wordings. Note the `[#GroupName]` suffix — it is a diagnostic group, and you can promote or demote one group at a time (§13).

### 12.1 Global and static mutable state

```text
error: var 'counter' is not concurrency-safe because it is nonisolated global shared
       mutable state [#MutableGlobalVariable]
error: static property 'retries' is not concurrency-safe because it is nonisolated global
       shared mutable state [#MutableGlobalVariable]
```

**R50. Fix globals in this order; stop at the first that applies.**

| # | Fix | When |
|---|---|---|
| 1 | `let supportedStyleCount = 42` | It never changes. Almost always this. |
| 2 | `var supportedStyleCount: Int { 42 }` | Computed, no storage |
| 3 | `@MainActor var supportedStyleCount = 42` | It is UI-adjacent |
| 4 | `let supportedStyleCount = Mutex(42)` | Genuinely shared mutable state, iOS 18+ |
| 5 | `nonisolated(unsafe) var …` **plus a comment naming the lock** | Real external synchronisation exists |

Reaching for #5 to clear the board converts a compile-time diagnostic into a production heisenbug and deletes the only record that a problem existed. Same ladder for a `static let shared` of a non-`Sendable` class: isolate the type, or make it genuinely `Sendable`. (Aside worth knowing: top-level code in `main.swift` is `@MainActor`-isolated, so globals declared there are main-actor-inferred and produce a *different*, later error at the use site. That is a CLI-tool quirk, not app behaviour.)

### 12.2 Conformance isolation mismatch

```text
error: conformance of 'WindowStyler' to protocol 'Styler' crosses into main actor-isolated
       code and can cause data races [#ConformanceIsolation]
  note: isolate this conformance to the main actor with '@MainActor'
  note: mark all declarations used in the conformance 'nonisolated'
  note: turn data races into runtime errors with '@preconcurrency'
```

**R51. Fix the conformance or the protocol, not the conforming type, in this order.** Swift 6.2 added isolated-conformance spellings; both of these compile on 6.3.3:

```swift
@MainActor final class A: @MainActor Styler { … }    // 1. isolate this conformance
@MainActor final class B: nonisolated Styler {       // 2. or promise it touches nothing isolated
    nonisolated func applyStyle() {}
}
```

Then, in order: (3) isolate the *requirement* — `protocol Styler { @MainActor func applyStyle() }` — when only some requirements are UI-bound; (4) isolate the whole protocol when it is inherently UI; (5) make the requirement `async`, since a synchronous `@MainActor` implementation satisfies it — best when conformers have mixed isolation; (6) `@preconcurrency` on the conformance as a last resort, because it is a runtime-checked promise, not a compile-time one.

`InferIsolatedConformances` (SE-0470) does step 1 for you everywhere, at the cost of moving the error to the use site:

```text
error: main actor-isolated conformance of 'WindowStyler' to 'Styler' cannot be used in
       nonisolated context [#IsolatedConformances]
```

That new error is a feature: it tells you the conformance was always main-actor-only and some caller was pretending otherwise.

### 12.3 `sending 'x' risks causing data races`

**R52. Look for *latent isolation* before you reach for `Sendable`.** Most crossing errors are really "you forgot to annotate the caller" errors: the compiler is telling you the isolation design is under-specified, not that you need a conformance.

```swift
// ERROR — the caller is nonisolated, so the argument crosses into the main actor.
func updateStyle(backgroundColor: ColorComponents) async {
    await applyBackground(backgroundColor)
}

// RIGHT, usually: this function was always main-actor work and nobody said so.
@MainActor
func updateStyle(backgroundColor: ColorComponents) async {
    applyBackground(backgroundColor)          // no boundary is crossed at all
}
```

Only after ruling that out: `: Sendable` if you own the type and it is genuinely shareable, `sending` if it is a one-time transfer, `@preconcurrency import` if you do not own it. And remember R23 — check whether deleting a later use of the value fixes it outright.

### 12.4 Proving concurrency behaviour in tests

Test mechanics — `@Test func … async`, `confirmation`, `.serialized`, suite isolation — belong to `06-TESTING.md`. What is this file's:

**R53. Test actors by their outputs, never by asserting intermediate state from outside** — the extra hop changes the state you were trying to observe. For reentrancy, the test is N concurrent calls plus an assertion that the dependency was hit once.

```swift
@Test func concurrentReadsCoalesce() async {
    let remote = CountingRemoteCache()
    let cache = DataCache(remote: remote)
    let key = UUID()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 { group.addTask { _ = try? await cache.read(key) } }
    }

    #expect(await remote.callCount == 1)
}
```

---

## 13. Migrating an existing app without an outage

Per target, leaf-first. Every step ships independently. A Swift 6 target and a Swift 5 target interoperate, so you never need a big-bang commit.

| Step | Action |
|---|---|
| 0 | Baseline: Swift 5 mode, `SWIFT_STRICT_CONCURRENCY = minimal`. Record the warning count. |
| 1 | `SWIFT_APPROACHABLE_CONCURRENCY = YES`, with the two `…NONISOLATED_NONSENDING…` / `…INFER_ISOLATED_CONFORMANCES` settings at `MIGRATE` first. **Do the `nonisolated async` → `@concurrent` audit here (R13/R14).** This step changes runtime behaviour: ship it alone and watch main-thread hang metrics. |
| 2 | `GlobalConcurrency` upcoming feature alone, then `-Werror MutableGlobalVariable` once the file is clean. Fix every global and static (R50). Ship. |
| 3 | `SWIFT_STRICT_CONCURRENCY = targeted`. Ship. |
| 4 | `SWIFT_STRICT_CONCURRENCY = complete`, still Swift 5 mode — everything is a warning. This is the bulk of the work. Triage every warning as class A or B (R10) *before* fixing. |
| 5 | Fix by category, not by file: globals → conformance mismatches → sending/latent isolation → `deinit`. One category per PR. |
| 6 | `SWIFT_VERSION = 6.0` for the target. If step 4 is clean this is a no-op commit. |
| 7 | Only now consider `MainActor` default isolation, and only for UI modules (R7). |
| 8 | Guardrails: the greps from R29; enable `DynamicActorIsolation` deliberately — it converts potential data races into runtime crashes, which is what you want in beta and arguably not in release week. |

**R54. Ratchet one diagnostic group at a time with `-Werror`, instead of jumping a whole strictness level.** Verified on 6.3.3: with `GlobalConcurrency` enabled, `-Werror MutableGlobalVariable` turns exactly that group into a hard error while everything else stays a warning. That gives you a per-category ratchet that cannot regress, which a strictness level cannot.

**R55. The anti-checklist. Do not:** flip the language mode project-wide as step 1; add `@unchecked Sendable` / `@preconcurrency` / `nonisolated(unsafe)` "to come back to later" (the diagnostic was the only record of the problem); change default isolation and language mode in the same commit; migrate a target before its dependencies.

---

## 14. Swift 6.4 / Xcode 27 — know it, do not ship it yet

**R56. Adopt nothing in this section in shipping code until Xcode 27 is GM.** Verified absent from 6.3.3: `withTaskCancellationShield` (`cannot find … in scope`) and `async` in `defer` (`'async' call cannot occur in a defer body`).

| Feature | SE | Status as of 2026-07-27 |
|---|---|---|
| `~Sendable` — explicitly, auditably non-`Sendable`; unlike an unavailable conformance it does **not** propagate to subclasses | SE-0518 | Implemented (6.4), experimental flag `TildeSendable` |
| `withTaskCancellationShield` — inside the shield `Task.isCancelled` is always `false`, prior state restored on exit | SE-0504 | Accepted, implemented (6.4) |
| `async` calls in `defer` bodies | SE-0493 | In 6.4; SE number is second-hand — verify |
| Warning for ignored throwing unstructured tasks, plus typed-throws `Task` initialisers | SE-0520 | In 6.4; SE number second-hand |
| `await Result { try await work() }` | SE-0530 | In 6.4; SE number second-hand |
| `withDeadline` | SE-0526 | **Proposed only.** Do not plan around it. |

`~Sendable` exists because `UserDefaults` is thread-safe yet cannot be `Sendable`: it permits subclasses, and a superclass cannot guarantee its subclasses are `Sendable`. `~Sendable` lets a library say "I am not `Sendable`, but a subclass may be." Cancellation is *not* suppressed inside an async `defer`, so pair the two when cleanup must finish:

```swift
func closeDatabaseConnection() async {
    await withTaskCancellationShield { await database.close() }
}
```

`07-TOOLING-BUILD-AND-SHIPPING.md §15` owns the rest of the Xcode 27 upgrade cost.

---

## Checklist

**Settings** — R1 deployment target first (iOS 18+ unlocks `Mutex`; below it `OSAllocatedUnfairLock` is still checked `Sendable`, so the floor is an ergonomics decision, not a safety one) · R2 language mode 6 from commit one; the template ships 5.0 · R3 Swift 6 mode gives you three of the five approachable features, not five · R4 never `minimal` strictness with async/await · R5 Approachable Concurrency before strictness · R6 verify upcoming-feature names with `-print-supported-features`

**Default isolation** — R7 `MainActor` for UI targets, `nonisolated` for model/network/package targets · R8 explicit `@MainActor` on cross-file API even in MainActor-default modules · R9 never change default isolation and language mode together

**Reading diagnostics** — R10 classify as (A) Sendable/sending or (B) isolation before fixing · R11 subclasses inherit isolation; primary-declaration conformance isolates the type, extension conformance only the extension · R12 `await` is not a critical section

**Isolation** — R13 audit every `nonisolated func … async`; it no longer means background · R14 audit with `:migrate`, not grep · R15 `@concurrent` in app code, plain `nonisolated` in library code · R16 profile before offloading; quote no hop-cost numbers you did not measure · R17 `@MainActor` → `Mutex` → `actor`, in that order; pre-iOS-18, `OSAllocatedUnfairLock` fills `Mutex`'s slot with no escape hatch · R18 no actors for counters · R19 no custom executors without a measured reason · R20 no `DispatchQueue` in new code

**Sendable** — R21 explicit `: Sendable` on public value types; `weak let` keeps a back-reference from costing the conformance · R22 one-time transfer → `sending` · R23 non-`Sendable` args to `@concurrent` are fine; the error appears where the value escapes · R24 remove isolation you do not need · R25 non-`Sendable` type with `async` methods → `isolation: isolated (any Actor)? = #isolation` · R26 `@unchecked Sendable` without a comment naming the mechanism is a defect · R27 three legitimate uses only, and "iOS 17 needs a lock" is not one of them · R28 `@retroactive` is a last resort · R29 CI greps for the five escape hatches

**Actors** — R30 cache the `Task`, not the value · R31 re-validate state read before an `await` · R32 know the three wrong reentrancy fixes

**SwiftUI** — R33 update UI state synchronously, then start async work · R34 `.task`, not `onAppear` + `Task` · R35 `nonisolated init` for `@MainActor` types built from anywhere · R36 `assumeIsolated` only under a framework guarantee

**Structured concurrency** — R37 `Task { }` inside async code is a smell; at the sync→async boundary it is not · R38 no `Task.detached` in app code · R39 bound task-group width · R40 cancellation is cooperative — check it · R41 `onCancel:` is nonisolated; hop deliberately · R42 `isolated deinit`, and never capture `self` in a `deinit` `Task`

**Bridging** — R43 resume every continuation exactly once · R44 wrap cancellable calls in `withTaskCancellationHandler` · R45 `AsyncStream.makeStream(of:)` for delegates · R46 explicit buffering policy, always · R47 `onTermination` at construction · R48 one consumer per `AsyncStream` · R49 annotate ObjC at the source; localised `nonisolated(unsafe)` over `@preconcurrency import`

**Fixing and migrating** — R50 global-state ladder: `let` → computed → `@MainActor` → `Mutex` → `nonisolated(unsafe)` + comment · R51 fix conformance mismatches with an isolated conformance or on the protocol · R52 check for latent isolation before adding `Sendable` · R53 test actors by outputs; prove coalescing with a `TaskGroup` · R54 ratchet one diagnostic group at a time with `-Werror` · R55 never big-bang, never suppress-to-come-back · R56 no Swift 6.4-only features in shipping code until Xcode 27 is GM
