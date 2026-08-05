# Architecture and state

1. [The single composition root](#1-the-single-composition-root)
2. [The four observables, and why each is earned](#2-the-four-observables-and-why-each-is-earned)
3. [Which wrapper](#3-which-wrapper)
4. [The three ways a tracked read goes stale](#4-the-three-ways-a-tracked-read-goes-stale)
5. [Environment](#5-environment)
6. [Navigation](#6-navigation)
7. [Persistence](#7-persistence)
8. [What does not apply to this project](#8-what-does-not-apply-to-this-project)

---

## 1. The single composition root

`AppDependencies.live()` in `HunchAppFeature`, named in one line by `@main` (`04 A2`). `08 §6` is the full listing — print it rather than reconstructing it:

```bash
sed -n '/^## 6\. Dependency injection/,/^## 7\./p' ios-swift-guide/08-APPLIED-TO-HUNCH.md
```

Five standing rules:

1. **Every `FilePersistenceStore`, `Now`, `SeedSource`, `Ladder`, `Codex` and cue player in the process is constructed there and nowhere else.** The factory, not the `App` struct, is the composition root, because `@main` is the one type a test and a preview can never construct.
2. **`preview(seed:date:)` is a peer of `live()`, not an afterthought.** It composes `InMemoryPersistenceStore`, `Now.fixed`, `SeedSource.fixed` and `SilentCuePlayer` — real shipping types, not fakes. `InMemoryPersistenceStore` lives in `HunchCore/Sources/Persistence/` and imports no `Testing`.
3. **`SeedSource` is the single point at which the app becomes nondeterministic**, and it lives in `Modules/`. `04 A29`'s rule is not "no singletons" but "no singleton inside a boundary you test across"; this is that boundary, made one line wide, and it is why `SystemRandomNumberGenerator` is banned from `HunchCore` outright.
4. **Routers are not in the graph** (`04 A33`). One `@Observable Router` per `NavigationStack`, owned by the screen that hosts it.
5. **The environment is installed by one exported modifier**, `.hunchEnvironment(_:)` (`04 A28`), so the module that knows what the graph contains is the module that installs it.

**Adding a dependency to the graph is four edits and no more:** a `public let` on `AppDependencies`; its construction in `live()`; its deterministic counterpart in `preview(seed:date:)`; and an `.environment(…)` line inside `hunchEnvironment(_:)` if a view needs it ambiently. If you find yourself editing a fifth place, something else is constructing it.

## 2. The four observables, and why each is earned

`04 §7`'s default is **no per-screen view models**. Four types clear the bar, and nothing else does.

| Type | Where | What earns it |
|---|---|---|
| `Round` | `LoomFeature` | `A18` triggers 1 and 2 both fire — a nine-phase machine with locked-input windows, two strikes, a Bench draft and a snapshot after every verdict (`08 §7.8`) |
| `Ladder` | `HunchAppFeature`'s graph | `A17`, a bounded context: ability, serving state, the novelty rings |
| `Codex` | `CodexFeature` | `A17`, a bounded context: lazy shelf loading and dedup authority. It is app-layer because `@Observable` drags Observation and main-actor isolation in (`08 §2`) |
| `Router` | the screen hosting each `NavigationStack` | `A33` |

Name each for the thing it is, never `…ViewModel` (`N40`, `04 A19`). **The pass-through test is the review gate**: delete the type and have the view read the model directly — if no test fails and no behaviour changes, delete it. `Round` passes because deleting it breaks phase timing, input locking and snapshot cadence.

**The pure part stays in `HunchCore` and is tested there** (`04 A20`). `RoundPhase`'s transition table is a pure `(RoundPhase, Event) -> RoundPhase`; scoring, the ribbon and the verdict are pure functions of values. `Round` orchestrates them and owns nothing they own.

```swift
// ✓ Modules/Sources/LoomFeature/Round.swift — the shape, not the whole file.
@MainActor @Observable
public final class Round {
    public private(set) var phase: RoundPhase = .dealt        // A16: mutated only by named methods
    public private(set) var strikes = 0
    public private(set) var probes: [Probe] = []

    /// Derived, never stored — Observation tracks it transitively (A15).
    public var isInputLocked: Bool { phase.locksInput }

    private let law: Law
    private let store: any PersistenceStore
    private let cues: any CuePlayer

    public init(law: Law, store: any PersistenceStore, cues: any CuePlayer) {
        self.law = law
        self.store = store
        self.cues = cues
    }

    public func probe(_ glyph: Glyph) { /* pure verdict from HunchCore, then phase + snapshot */ }
    public func seal() { /* … */ }
}
```

## 3. Which wrapper

`04 A11` is the decision table; run it rather than choosing by feel. The rows this project actually uses:

| Situation | Use |
|---|---|
| Ephemeral view state — sheet presentation, focus, animation phase, scrubber position | `@State private var` — always `private`, no exceptions |
| An observable this view creates | `@State private var round = Round(…)` |
| A child reading an observable it does not own | plain `var round: Round` — **no wrapper at all**; adding one is the anti-pattern |
| A child needing `$round.prop` | `@Bindable var round: Round`, or `@Bindable var round = round` at the top of `body` (`A12`) |
| An ambient dependency deep in the hierarchy | `@Environment(Codex.self)`, `@Environment(\.theme)` |
| A component that may be previewed with nothing installed | the optional form, `@Environment(Codex.self) private var codex: Codex?` (`A26`) |
| A scalar preference | `@AppStorage`. Do not build a model layer for a `Bool` — and `UserDefaults` is preferences only, per the brief |
| Restoring the navigation stack | `@SceneStorage` holding an encoded `[Route]` (`A39`) |

**State belongs in the view if and only if losing it when the view is destroyed is correct, *and* nothing else can observe or change it** (`A13`). Everything restored after relaunch, read by two screens, or worth a unit test is model state.

## 4. The three ways a tracked read goes stale

Tracking is dynamic, not lexical: a dependency forms from every tracked read that happens *while* `body` is evaluating, including reads inside synchronous helpers `body` calls (`04 A6`). The widely-repeated claim that extracting a read into a helper breaks tracking is folklore. Three things do lose the update, and all three are silent:

1. **A read that runs after `body` returns** — in `.onAppear`, `.task { }`, a `Task { }`, or a stored closure. The value is captured once and never invalidates again.
2. **A short-circuited condition whose left operand is untracked** — a global, a `UserDefaults` read, a captured `let`. Read the tracked operand unconditionally instead; it costs nothing.
3. **A computed property with no stored property behind it.** There is nothing for the registrar to observe, so it never invalidates.

```swift
// ✗ the copy is taken once, outside the tracking window, and never updates again (A6, A14)
struct ThroatView: View {
    let round: Round
    @State private var phase: RoundPhase = .dealt
    var body: some View {
        Throat(phase: phase).onAppear { phase = round.phase }
    }
}

// ✓ read it in body; derive rather than store (A14, A15)
struct ThroatView: View {
    let round: Round
    var body: some View { Throat(phase: round.phase) }
}
```

Two rules that prevent most of the rest: **never mirror model state into `@State`** (`A14`), and **expose mutable model state as `private(set)` and mutate it through named methods** (`A16`). That is what makes a store testable without a UI and greppable when a value is wrong.

## 5. Environment

**The single most common environment bug is a sheet.** A presented subtree starts a new environment hierarchy, and a missing `@Environment` is a runtime trap rather than a compile error (`04 A25`). In this project that is exactly three sites — `AssayInspectorView`, `ResetConfirmAlert` and `SievePauseOverlay` (`08 §6`) — plus any new presentation:

```swift
// ✗ AssayInspectorView traps at runtime
.sheet(item: $inspecting) { row in AssayInspectorView(row: row) }

// ✓ re-inject everything the subtree reads
.sheet(item: $inspecting) { row in
    AssayInspectorView(row: row).hunchEnvironment(dependencies)
}
```

`HunchUI` components read `@Environment` in the **optional** form (`A26`), because they are used from previews that install nothing. Custom values use `@Entry` (`A27`) and are named after the value, not after a key type that no longer exists:

```swift
// ✓ Modules/Sources/HunchUI/Environment.swift
extension EnvironmentValues {
    @Entry public var glyphScale: CGFloat = 1.0
    @Entry public var theme: Theme = .dark
    @Entry public var storeHealth: StoreHealth = .healthy   // §11.13's disk-full hairline
}
```

## 6. Navigation

- **`Route` is a `Codable` enum in `HunchNavigation`** — a target with no SwiftUI, so `NavigationDepthTests` runs on the host (`04 A32`, `08 §1`).
- **A typed `[Route]` array, never `NavigationPath`.** `NavigationPath.CodableRepresentation` serialises only if every pushed value is `Codable`, and otherwise restoration silently no-ops.
- **Navigate by ID, never by model object** (`A34`). A `Glyph` or a `CodexPage` sitting in the path is a stale-data bug factory.
- **`navigationDestination(for:)` goes on the container, never inside a `List`, `ForEach`, `LazyVStack` or `ScrollView` child** (`A35`). Lazy containers instantiate only visible children, so a destination declared inside may never register and the push silently does nothing.
- **Present with the `item:` form, never `isPresented` plus a parallel payload** (`A37`). The two-variable form is where every "sheet shows with stale data" bug comes from.
- **Restore with `@SceneStorage` holding an encoded `[Route]`** (`A39`) — plain `JSONEncoder`, no `CodableRepresentation` dance.
- **No coordinator layer** (`A38`). `Route` + one `Router` per stack + one `switch` per stack is the whole mechanism.

## 7. Persistence

The brief fixes the shape and `08 §7.5` rules on the one place it strains:

- **`Codable` JSON in Application Support, behind `protocol PersistenceStore`, written atomically, versioned from v1 with a migration path.** Not SwiftData, so `04 A40`'s first table row is the one in force and `A41`/`A42`/`A45`/`A46`'s SwiftData mechanics are inapplicable.
- **`actor FilePersistenceStore`** — cohesive state with behaviour, callers already `async`, and file I/O has no business on the main actor. `.atomic` writes are the whole durability story: a temporary file and a rename, so a crash mid-write leaves the previous version intact.
- **`save(_:to:)` switches on `StoreFile` for the write order §11.13 fixes** — `round.json` first, the snapshot slot cleared last.
- **Eight lazily-loaded shelves keep `A40`'s "~1000 records" ruling true** (`08 §7.5`). That shard boundary is an assertion, not a comment: opening a shelf must parse exactly one shelf file, and no single file may exceed 512 KB. `hunch-swift-testing` owns those tests.
- **`A46`'s question survives even without SwiftData: opening a store can fail on data you do not control, so `try!` is not available to you.** The policy is written once — §11.13's quarantine-and-rebuild for anything rebuildable, and the `storeHealth` hairline for everything else. A malformed `codex-b4.json` quarantines and rebuilds; it never crashes and never silently looks like deleted data.

## 8. What does not apply to this project

Knowing which parts of `04` are void here is worth as much as knowing which apply. Do not implement any of these:

| Void | Why |
|---|---|
| `04 §11a` in its entirety — `APIClient`, `Endpoint`, `APIError`, `TokenStore`, `A47`–`A50` | The brief bans network code of any kind. There is no `URLSession`, no `URLRequest`, no `Authorization` header |
| SwiftData: `@Model`, `@Query`, `ModelContainer`, `@ModelActor`, `A45`'s escalation ladder | JSON behind `PersistenceStore` is the brief's ruling (`08 §7.5`, `§7.6`) |
| `A44`'s `Observations` AsyncSequence | Swift 6.2 / **iOS 26**; this app's floor is iOS 18. `Codex` re-implements change notification by hand, which `A42` warned is the bill (`08 §7.6`) |
| TCA (`A43`), `swift-dependencies` (`A31`), `swift-sharing`, GRDB | Third-party. The brief bans every SPM dependency |
| A coordinator layer (`A38`) | Never needed; `Route` plus one `Router` per stack is the mechanism |
| `A4`'s `ObservableObject` migration table | There is no legacy here. `@Observable` from the first commit; Combine is not imported at all |
