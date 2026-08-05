# Isolation plan

Read before editing either `Package.swift`, adding a target, adding an actor, or deciding whether a
type is `@MainActor`. Rule numbers are `ios-swift-guide/05-CONCURRENCY.md` unless prefixed
(`01 P…` project structure, `04 A…` architecture, `07 B…` tooling). `08 §n` is
`ios-swift-guide/08-APPLIED-TO-HUNCH.md`.

1. [The manifests, in full](#1-the-manifests-in-full)
2. [The `@MainActor` roster](#2-the-mainactor-roster)
3. [The two actors](#3-the-two-actors)
4. [Admitting a third actor](#4-admitting-a-third-actor)
5. [Annotation discipline inside a MainActor target](#5-annotation-discipline-inside-a-mainactor-target)
6. [SwiftUI isolation in a Canvas-only app](#6-swiftui-isolation-in-a-canvas-only-app)
7. [What is deliberately absent](#7-what-is-deliberately-absent)

---

## 1. The manifests, in full

Isolation is a *target* property. It is declared once, in the manifest, and nowhere else
(`01 P17`, `05 R7`, `04 A22`). `08 §1` fixes the platforms and the language mode; the upcoming-feature
list below is this skill's ruling from `05 R2` + `05 R3` — Swift 6 language mode enables three of the
five approachable features, and these two are not among them.

```swift
// HunchCore/Package.swift
// swift-tools-version: 6.2
import PackageDescription

/// Applied to every target in both packages. `05 R3`: language mode 6 does NOT imply these two.
/// Verify any name you add with `swiftc -print-supported-features` — an unrecognised
/// upcoming-feature name is accepted silently and does nothing (`05 R6`).
let baseline: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "HunchCore",
    platforms: [.iOS(.v18), .macOS(.v15)],          // .macOS is what makes `06 T49` exit tests possible
    products: [.library(name: "HunchCore", targets: ["Glyphs", "Laws", "LawGeneration",
                                                     "Bench", "Rounds", "Ladder",
                                                     "Archive", "Persistence"])],
    targets: [
        // No `.defaultIsolation` anywhere in this package. Its absence is the decision.
        .target(name: "Glyphs", swiftSettings: baseline),
        .target(name: "Laws", dependencies: ["Glyphs"], swiftSettings: baseline),
        // … one line per directory in `08 §1`'s tree, same shape …
        .target(name: "HunchTestSupport", dependencies: ["Glyphs", "Laws"], swiftSettings: baseline),
        .testTarget(name: "LawGenerationTests",
                    dependencies: ["LawGeneration", "HunchTestSupport"],
                    resources: [.copy("Fixtures")], swiftSettings: baseline),
    ],
    swiftLanguageModes: [.v6]
)
```

```swift
// Modules/Package.swift
// swift-tools-version: 6.2
import PackageDescription

let baseline: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]
let ui: [SwiftSetting] = baseline + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Modules",
    defaultLocalization: "en",                      // `01 P35`
    platforms: [.iOS(.v18)],                        // REQUIRED: `Atomic`/`Mutex` are iOS 18+, and the
                                                    // xcconfig's deployment target does not reach here
    products: [.library(name: "HunchAppFeature", targets: ["HunchAppFeature"])],
    dependencies: [.package(path: "../HunchCore")],
    targets: [
        .target(name: "HunchNavigation", swiftSettings: baseline),   // a route graph is a value
        .target(name: "Feedback", swiftSettings: baseline),          // a cue vocabulary is a value
        .target(name: "HunchUI", dependencies: [.product(name: "HunchCore", package: "HunchCore")],
                resources: [.process("Resources")], swiftSettings: ui),
        .target(name: "LoomFeature", dependencies: ["HunchUI", "Feedback"], swiftSettings: ui),
        .target(name: "CodexFeature", dependencies: ["HunchUI"], swiftSettings: ui),
        .target(name: "MetaFeature", dependencies: ["HunchUI"], swiftSettings: ui),
        .target(name: "HunchAppFeature",
                dependencies: ["LoomFeature", "CodexFeature", "MetaFeature", "HunchNavigation"],
                swiftSettings: ui),
    ],
    swiftLanguageModes: [.v6]
)
```

The app target's half lives in `Config/Base.xcconfig` (`07 B…` owns the file; this skill owns the
three lines): `SWIFT_VERSION = 6.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`,
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. `App/` holds five files and one of them is `@main`, so
the setting costs nothing and matches `05 R2`.

**The predicate for a new target.** It gets `.defaultIsolation(MainActor.self)` **iff** it declares a
`View`, or owns state a `View` reads directly. Everything else gets `baseline` alone. `Feedback` is
the instructive case: it exists to make noise *for* the UI, but a `Cue` is a value and `CuePlayer`
is a protocol, so the target is nonisolated and the two players carry `@MainActor` explicitly.

**Never change default isolation and language mode in the same commit** (`05 R9`) — SE-0466 makes the
first source-incompatible, and you want exactly one suspect.

## 2. The `@MainActor` roster

`08 §4` fixes the list. What each one is doing there:

| Type | Where | Why it is main-actor |
|---|---|---|
| `Round` | `LoomFeature` | a nine-phase machine driving one screen; `04 A18` triggers 1 and 2 both fire (`08 §7.8`) |
| `Codex` | `CodexFeature` | `@Observable`, lazy shelf loading, dedup authority — the macro is over a class |
| `Ladder` | `HunchAppFeature` graph | `@Observable`: `Ability` + `ServingState` + the novelty rings |
| `Router` | per `NavigationStack` (`04 A33`) | navigation state a `View` binds to |
| `AppDependencies` | `HunchAppFeature` | the composition root, built in `HunchApp.init` |
| every `View` | everywhere | SwiftUI's `View` protocol is already `@MainActor` |
| `SynthesizedCuePlayer`, `HapticCuePlayer` | `Feedback` | engine lifecycle is main-actor; the *render thread* is not, and that is `real-time-audio.md` |

Everything else in the app is a value. `Round` gets a `nonisolated init` only if a preview needs to
build one off-actor (`05 R35`); today nothing does, so do not add one speculatively.

**The macro is the reason for the boundary.** `@Observable` expands to a class with main-actor-bound
observation registrars. Putting one in `HunchCore` would drag Observation and `@MainActor` into a
package whose entire value is that it is neither. That is why `CodexPage` (a `Codable` value) is core
and `Codex` (the observable archive) is not — `08 §2`.

## 3. The two actors

Both satisfy `05 R17` row 3 in full: cohesive state *with behaviour*, callers already `async`, and a
critical section that must `await`.

**`actor FilePersistenceStore: PersistenceStore`** — file I/O has no business on the main actor, and
`save(_:to:)` must `await` the write. Atomic writes to Application Support; `save` switches on
`StoreFile` for the write order `GAME_DESIGN.md §11.13` fixes. The protocol is `PersistenceStore:
Sendable` (`04 A41`); the actor conforms without annotation because actors are implicitly `Sendable`.

**`actor LawIndexLoader`** — the 9,767-table enumeration is built once in the background and must not
be built twice if two callers race. `08 §4` gives the compiling shape; read it rather than retyping
it:

```bash
grep -n -A14 'actor LawIndexLoader' ios-swift-guide/08-APPLIED-TO-HUNCH.md
```

Three properties that shape must keep, because they are what `05 R30` is (cache the `Task`, not the
value):

1. The `Task` is stored **before** the first `await`. Storing is synchronous, so it lands before any
   suspension and the second caller finds it.
2. Failure clears the slot. A cached failed `Task` is a permanent outage.
3. `LawIndex` is an immutable `Sendable` struct, so once built it leaves the actor and is never
   touched again — the actor exists to serialise *building*, not reading.

```swift
// WRONG — the shape everyone writes first. Compiles clean, races, and hides it.
actor LawIndexLoader {
    private var index: LawIndex?
    func index() async throws -> LawIndex {
        if let index { return index }             // five callers all miss here…
        let built = try await LawIndex.rebuild()  // …suspend here, and all five rebuild
        index = built
        return built
    }
}
```

`05 R32` names the three wrong fixes for this, all of which will be proposed: making the method
`nonisolated` (moves the problem), an `isLoading` flag with an early `nil` return (silently drops
results), a lock around the body (impossible — you cannot hold a lock across `await`).

**Placement.** `08 §1`'s tree does not place `LawIndexLoader`. It needs both `LawIndex` and
`PersistenceStore`, so it goes in whichever target already depends on both; do not add a new
dependency edge to `Laws` for it. Record the choice in `DECISIONS.md`.

## 4. Admitting a third actor

The budget is two. A candidate has to clear all four:

1. It fails the value-threading test — the state genuinely cannot be an argument threaded through a
   pure function, which is how every other piece of HUNCH state works.
2. It satisfies all three clauses of `05 R17` row 3, including *the critical section must `await`*. If
   the accessors are synchronous, `05 R18` forbids it outright and the answer is a value or `Mutex`.
3. It is not UI-facing and not read by UI. If it is, row 1 wins and it is `@MainActor`.
4. It is recorded in `DECISIONS.md` with the sentence "an actor because ⟨the await⟩".

A counter, a flag, a cache with synchronous accessors, "somewhere to put the RNG", and "this feels
like it should be off the main thread" are all failures of clause 2.

## 5. Annotation discipline inside a MainActor target

`05 R8`: in a `MainActor`-default module, write `@MainActor` explicitly on every declaration visible
outside its own file. A bare `func` means different things in `Feedback` and in `LoomFeature`, and
the reader of a header does not know which manifest they are in.

```swift
// LoomFeature — MainActor by default. The annotation is redundant and it stays.
@MainActor
public final class Round { … }

@MainActor
public struct RoundView: View { … }

// Feedback — nonisolated by default. The annotation is load-bearing.
@MainActor
public final class SynthesizedCuePlayer: CuePlayer { … }

public struct Cue: Sendable { … }          // no annotation: it is a value, and it says so
```

Redundant annotations are free; unreadable headers are not.

## 6. SwiftUI isolation in a Canvas-only app

HUNCH renders every mark through `Shape` and `Canvas` and has zero image assets, which puts it in
constant contact with the handful of SwiftUI entry points that genuinely run *off* the main actor
(`05 §9`): `Shape.path`, `visualEffect`, `Layout` methods, `onGeometryChange`, and built-in
animations.

```swift
// RIGHT — `path(in:)` is a pure function of what the shape already stores.
struct GlyphShape: Shape {
    let silhouette: Glyph.Shape          // a Sendable value, copied in at init
    func path(in rect: CGRect) -> Path { … }
}

// WRONG — `round` is main-actor state and `path(in:)` is not on the main actor.
struct GlyphShape: Shape {
    let round: Round
    func path(in rect: CGRect) -> Path { silhouette(for: round.currentGlyph) … }
}
```

```swift
// The `LoomGrain` colorEffect and the admit bloom take a copy, not a reference (`05 §9`).
.visualEffect { [phase] content, _ in content.colorEffect(ShaderLibrary.loomGrain(.float(phase))) }
```

Two more that come up every screen:

- **`.task`, never `onAppear` + `Task { }`** (`05 R34`). `.task` is cancelled when the view goes away
  and re-runs on an `id:` change; the round's cue loop and the Codex shelf load both want that.
  `.task(id: mode)` restarts on a mode switch for free.
- **Update UI state synchronously, *then* start the async work** (`05 R33`). The nine-phase reveal in
  `GAME_DESIGN.md §6.1` is timing-sensitive; `withAnimation { … }` must land before the `Task`.

## 7. What is deliberately absent

Each of these is a decision, not an omission. Adding one is a regression and needs a `DECISIONS.md`
entry saying what changed.

| Absent | Why |
|---|---|
| any `Clock` abstraction | no wall-clock quantity affects score, marks or the Rasch update; SIEVE's timing is a pure `SieveSchedule` plus one `ContinuousClock.sleep` at the view edge (`08 §5`) |
| any `Mutex` instance | `05 R17` row 2 has no occupant here — every candidate is a value that should be threaded |
| any `DispatchQueue` | `05 R20`; two schedulers with no shared priority or cancellation model |
| any custom `SerialExecutor` | `05 R19`; there is no serial queue to interoperate with |
| `Task.detached` | `05 R38`; `@concurrent` is the checked answer if profiling ever demands one |
| a third actor, a second `@unchecked Sendable` | §4 above, and `real-time-audio.md` |
| `@preconcurrency import` | no third-party dependencies exist, and the iOS 18 SDK is annotated |
