# Architecture, State and Dependencies

This file decides where state lives, who owns it, and how the pieces reach each other: Observation and `@Observable`, the property-wrapper decision procedure, the view-model question, the UI-free domain core, dependency injection, navigation as data, the persistence boundary, the networking client, and whether to buy an architecture library. It is written for an engineer starting a new SwiftUI app on iOS 17+ who wants one defensible default per decision rather than a survey. Rules are numbered `A1`–`A50` so other files can cite them. Adjacent topics owned elsewhere: physical file/target layout in `01-PROJECT-STRUCTURE.md`, what to call these types in `02-NAMING-AND-API-DESIGN.md`, statement-level style in `03-WRITING-THE-CODE.md`, isolation and `Sendable` mechanics in `05-CONCURRENCY.md`, test mechanics in `06-TESTING.md`, build settings and `Package.swift` in `07-TOOLING-BUILD-AND-SHIPPING.md`.

---

## 1. Version ground truth

Dated **2026-07-27**. Re-verify anything here before quoting it in a design doc.

| Thing | State | Consequence for this file |
|---|---|---|
| Shipping toolchain | Xcode **26.6** (17F113, 2026-06-25), Swift **6.3.3**, **iOS 26.5 SDK** | Everything not marked otherwise works today, and the Observation behaviour in §3 was compile- and run-checked against exactly this toolchain. The SDK is 26.5, not 26.6 — `xcrun --sdk iphoneos --show-sdk-version` returns `26.5` and the path is `iPhoneOS26.5.sdk`. `01-PROJECT-STRUCTURE.md` §1 and `07-TOOLING-BUILD-AND-SHIPPING.md` §1 agree |
| Next toolchain | Xcode **27** beta 4 (27A5228h, 2026-07-20), Swift **6.4**, iOS 27 SDK; public September 2026 | §4 is a migration you will perform, not a feature you opt into |
| Observation / `@Observable` | iOS 17, macOS 14, tvOS 17, watchOS 10 (SE-0395, Swift 5.9) | This entire file assumes iOS 17+ |
| `NavigationStack`, `navigationDestination(for:)` | iOS 16+ | §10 is safe on any target this file addresses |
| `@Entry` macro | Xcode 16+ toolchain; source-generating, so it **back-deploys to iOS 13** | No deployment-target cost. Use it (§9) |
| `Observations` (AsyncSequence over `@Observable`, SE-0475) | Swift 6.2 / iOS 26 | §13 |
| SE-0506 `withContinuousObservationTracking`, `ObservationTracking.Token` | **Accepted**; the proposal names no Swift release. Apple's WWDC26 SwiftData session demos it, so it is in the iOS 27 SDK. Apple's sample spelled it `withContinuousObservation`, the proposal spells it `withContinuousObservationTracking` | One of those names is stale — check the header in your SDK before relying on it |
| `@State` becomes a **macro** — *source* incompatibilities | Xcode 27 SDK. Confirmed against TN3211 on 2026-07-27: all four breakages in §4 are documented there | §4. They bite the moment you compile with Xcode 27, whatever your deployment target |
| `@State` macro — *lazy initialisation* behaviour | Xcode 27 SDK; asserted to **back-deploy to iOS 17** | Source is WWDC26 session 269. TN3211 is a source-compatibility note and does not restate it, so treat back-deployment as one-source until you see it in the SDK's own docs. §4's A8 does not depend on it — the ordering rules hold either way |

**A1. iOS 17 is the *architectural* floor for this file; the guide's shipping default is iOS 18, and `01-PROJECT-STRUCTURE.md` §5b owns that ruling and the reason.** Read the two numbers as answering different questions. iOS 17 is where Observation begins: below it every recommendation in §3–§7 degrades to `ObservableObject` with object-level invalidation, which is a different architecture with worse performance characteristics, so iOS 17 is the point below which this file stops applying at all. iOS 18 is the floor 01 §5b *recommends* you ship, because it is the lowest one at which `05-CONCURRENCY.md` also applies with no fallback path. Nothing in §2–§14 needs iOS 18, so if a measured install base buys you iOS 17 you can hold it and still follow this file end to end — deviate in 01's two places (`platforms:` and `IPHONEOS_DEPLOYMENT_TARGET`) in one commit, with the install-base number in the message. *Deviate below 17 when:* the install base genuinely pays for it. Then write `ObservableObject` deliberately, in one layer, and plan the migration; Apple supports both types coexisting during a transition.

---

## 2. The shape, stated once

One `@Observable` store per **bounded context**, injected at a single composition root, read by views that hold ephemeral state in `@State private`. Domain logic lives in a module that cannot import SwiftUI. Navigation is a `[Route]` array. There are no per-screen view models by default.

```text
App/                     app target shell: @main and bundle resources. Nothing else (01 P8)
Modules/                 ONE local SwiftPM package, N targets (01 P14)
  Package.swift
  Sources/
    Models/              NO SwiftUI, empty `dependencies:`. Domain types, rules,
                         protocols for services, Route enum (01 P5's carve-out)
    Persistence/         depends on Models. SwiftData/GRDB/file implementation (§11)
    Networking/          depends on Models. URLSession implementation (§11a)
    DesignSystem/        depends on Models, imports SwiftUI. Reusable components, design tokens
    AppFeature/          depends on all four. Screens, navigation wiring, the composition root
```

**This is the post-threshold shape, and it is a destination rather than a day-one scaffold.** `01-PROJECT-STRUCTURE.md` P11/P12 own *when* each of these targets is allowed to exist — P12 is explicit that pre-creating an empty `Networking`/`DesignSystem` scaffold on day one is a cost with no matching benefit, and that you start with `App/` plus one `AppFeature` target and split when P11's threshold trips (two consumers, or tests you want without a simulator, or ~1,500 lines with a nameable responsibility). Every rule in this file works inside a single `AppFeature` target; the tree above is what the same rules look like once the split has happened. Read the tree for the *arrows*, not for a list of directories to create.

**The domain target is called `Models`, not `Core`.** That name is 01's, not a preference of this file: P5 carves `Models` out as a legal *target* name precisely while `.target(name: "Models")` has an **empty dependency list**, and P7 bans `Sources/Core/` outright. Holding service *protocols* there keeps the carve-out satisfied — a protocol declaration and a pure function need nothing but the standard library, so `Models` still declares no dependencies even though `BookRepository` (A41) and `Route` (A32) live in it. The moment that target needs to `import` something of yours, P5 says it has stopped being a leaf: split it into named capabilities that day rather than letting it become the bin P5 exists to prevent.

**One package with N targets, not one package per module.** `01-PROJECT-STRUCTURE.md` P14 owns that ruling and the reason it is not a taste question: a local path-based package cannot be a dependency of another local package, so four sibling packages cannot form the arrows below *at all*, and everything `package`-visible would have to become `public`. The `Packages/MyAppCore` + `Packages/MyAppUI` shape you will see recommended elsewhere does not build; the wall arrives the first time `Persistence` needs a type from `Models`.

```swift
// App/ReadingListApp.swift — the app target's only Swift file (01 P9: one feature import).
import AppFeature
import SwiftUI

@main
struct ReadingListApp: App {
    @State private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            LibraryScreen()
                .readingListEnvironment(dependencies)   // one exported modifier — A28
        }
    }
}
```

```swift
// Modules/Sources/AppFeature/AppDependencies.swift — the composition root itself.
@MainActor
public struct AppDependencies {
    public let library: LibraryStore

    public init(library: LibraryStore) { self.library = library }

    /// The one place a `ModelContainer`, a `URLSession`, a clock or an API key is constructed.
    public static func live() -> AppDependencies {
        let container = ModelContainer.readingList()          // opens or recovers the store — A46
        let repository = SwiftDataBookRepository(modelContainer: container)
        return AppDependencies(library: LibraryStore(repository: repository))
    }
}

extension View {
    /// A28: the module that knows what the graph contains is the module that installs it.
    public func readingListEnvironment(_ dependencies: AppDependencies) -> some View {
        environment(dependencies.library)
    }
}
```

Two details that are load-bearing. `@State private var dependencies = AppDependencies.live()` is safe on every Xcode version despite §4's eager-initialisation warning, because SwiftUI instantiates an `App` once — the warning is about view structs, which are re-created constantly. And routers are deliberately absent from the graph: one `Router` per `NavigationStack`, owned by the screen that hosts the stack (A33), not injected process-wide.

**This root is drawn in the post-escalation persistence shape.** A45 rules that a one-surface app skips the repository entirely: install the container with `.modelContainer(_:)`, read rows with `@Query`, and let `LibraryStore` own only the state SwiftData does not (filters, sync status, in-flight work). **§11 writes that pre-escalation root out in full, under "The default path, whole" — start there and come back here only when one of A45's four triggers has fired.**

**A2. Compose the object graph in exactly one place — a `live()` factory in the top feature module, named once by `@main` — and nowhere else.** Every `URLSession`, `ModelContainer`, API key and clock is constructed there and passed down. The factory, not the `App` struct, is the composition root, and that is what makes it compatible with `01-PROJECT-STRUCTURE.md` P9: the app target imports only `AppFeature`, so the type that imports `Persistence` and `Networking` has to live inside the package. *Cost:* one more type and one more file than writing it inline in `App.init()`. You get back a composition root that a test and a preview can construct, which `@main` never was. *Deviate when:* a self-contained feature module ships its own `live()` for its own previews and demo app — that's a second root by design, not by accident.

**A3. Draw the dependency arrows once and enforce them with the `dependencies:` lists in the single `Package.swift`.** `App → AppFeature → {DesignSystem, Persistence, Networking} → Models`. `Models` depends on nothing of yours — that empty `dependencies:` array is not decoration, it is the condition 01 P5 attaches to the target's existence. Leave a target out of a `dependencies:` list and the `import` stops compiling — the compiler becomes the architecture reviewer; no lint rule, no convention doc. A22 shows the isolation settings that hang off these same target declarations; `01-PROJECT-STRUCTURE.md` P14 explains why it is one manifest and not four.

---

## 3. Observation: the invalidation model you are now programming against

`ObservableObject` published through `objectWillChange`: **any** `@Published` change invalidated **every** view holding the object. `@Observable` tracks at the granularity of *(view body, property)*. Apple: a view "is now only updated when a property it depends on changes."

```swift
@Observable final class Book: Identifiable {
    var title = "Sample"
    var author = Author()
    var isAvailable = true
}

struct BookTitle: View {
    var book: Book                 // NO property wrapper — this is the correct form
    var body: some View {
        Text(book.title)           // depends on `title` only; `isAvailable` churn costs nothing
    }
}
```

**A4. Migrate `ObservableObject` to `@Observable` wholesale per type, using Apple's mapping, and delete the wrappers as you go.**

| Old | New |
|---|---|
| `class X: ObservableObject` + `@Published var` | `@Observable class X` + plain `var` |
| `@StateObject private var x = X()` | `@State private var x = X()` |
| `@ObservedObject var x: X` | `var x: X` — **no wrapper at all** |
| `@ObservedObject var x: X` and you need `$x.prop` | `@Bindable var x: X` |
| `@EnvironmentObject var x: X` | `@Environment(X.self) private var x` |
| `.environmentObject(x)` | `.environment(x)` |
| (nothing) | `@ObservationIgnored` on caches and backing storage |

Half-migration is supported — the two kinds of object can coexist, they just invalidate differently. There is a known interop bug worth knowing while you are half-migrated: FB21879758, SwiftUI views mixing `@ObservedObject` and `@Environment` inside a `UIHostingController` that overrides `viewWillAppear` stop updating; Apple's in-thread advice is to finish the migration, the workaround is `viewDidLayoutSubviews`.

**A5. `@Observable` is classes only, and that is load-bearing.** SE-0395's author wanted value-type support and abandoned it: registration and mutation tracking need reference identity. Do not design around a hoped-for `@Observable struct`. (This limitation is the entire reason TCA's `Store` exists — see §12.)

**A6. A dependency forms from every tracked read that happens *while* `body` is evaluating — including reads inside synchronous helpers `body` calls. It does not form from reads that escape that window.**

Tracking is **dynamic, not lexical**. The `access(keyPath:)` call the macro injects into each getter registers against whatever observation scope is on the stack when it runs, and SwiftUI evaluates `body` inside one. So the widely-repeated claim that *"extracting a read into a helper method breaks tracking"* is folklore. Verified on Swift 6.3.3 / Xcode 26.6 against `withObservationTracking`, the same mechanism SwiftUI uses: the helper read registers, a read deferred out of the scope does not.

```swift
// ✅ FINE. subtitle() runs synchronously during body, so `author.name` registers normally.
struct Row: View {
    let book: Book
    var body: some View { Text(subtitle()) }
    func subtitle() -> String { book.author.name }
}
```

Three things that *do* silently lose the update. First, a read that runs **after** `body` returns:

```swift
// ❌ the read happens in a closure SwiftUI runs later, outside the tracking window.
//    `caption` is captured once and never invalidates again.
struct StaleRow: View {
    let book: Book
    @State private var caption = ""
    var body: some View {
        Text(caption)
            .onAppear { caption = book.author.name }   // no dependency forms — and see A14
    }
}

// ✅ read it in body; derived values are computed, never cached into @State (A14, A15)
struct FreshRow: View {
    let book: Book
    var body: some View { Text(book.author.name) }
}
```

The same hole opens in a `Button` action, a `.task { }`, a `Task { }`, or any closure you store and call later. If a value is displayed, read it in `body`.

Second, a short-circuited condition, where the tracked read never executes at all:

```swift
// ❌ `FeatureFlags.isEditingEnabled` is a plain global — not tracked. While it is false,
//    `model.isDirty` is never read, so no dependency registers; and when the flag flips,
//    nothing invalidates either, because it was never observable. The view is stuck.
if FeatureFlags.isEditingEnabled && model.isDirty { SaveButton() }

// ✅ read the tracked operand unconditionally, so the dependency forms in every branch
let isDirty = model.isDirty
if FeatureFlags.isEditingEnabled && isDirty { SaveButton() }
```

Be precise about when this bites, because the folk version over-claims. If *every* operand is tracked state (`@State`, or a property of an `@Observable`), short-circuiting is harmless: a change to the left operand re-evaluates `body`, which opens a fresh tracking scope and registers the right-hand read then. The bug needs an **untracked** left operand — a global, a `UserDefaults` read, a captured `let` whose parent does not re-render. Reading eagerly costs nothing and removes the question.

Third, a computed property with no stored property behind it — there is nothing for the registrar to observe:

```swift
// ❌ nothing to track: no stored property is read, so no access() is ever recorded
@Observable final class Settings {
    var isPro: Bool { UserDefaults.standard.bool(forKey: "isPro") }   // never invalidates
}

// ✅ store it; sync UserDefaults on write (or use @AppStorage in the view for a scalar).
//    `didSet` coexists with @Observable — verified on Swift 6.3.3: the property is still
//    tracked, and the observer fires after the change notification.
@Observable final class Settings {
    var isPro: Bool = UserDefaults.standard.bool(forKey: "isPro") {
        didSet { UserDefaults.standard.set(isPro, forKey: "isPro") }
    }
}
```

Things Observation gets right that `ObservableObject` did not, and which you should now rely on: optionals and collections track properly; **computed properties track transitively** through the stored properties they read; nested observable objects reached through another observable track correctly.

**A7. Mutate UI-driving properties on the main actor even though `ObservationRegistrar` is thread-safe.** Thread-safe registration is not the same as a well-ordered UI update. See `05-CONCURRENCY.md` R7 (default isolation split by module, so a UI target is `MainActor` without you typing it) and R17 (the `@MainActor` → `Mutex` → `actor` decision procedure) for how to get that isolation by construction rather than by attribute.

---

## 4. Xcode 27: `@State` is a macro now

`@State` changed from a property wrapper conforming to `DynamicProperty` into a **Swift macro**. The initial-value expression is now evaluated **lazily, once, for the lifetime of the view**. Before: `@State private var store = StickerStore()` constructed a `StickerStore` on every re-init of the view struct and threw it away. Per WWDC26 session 269 the new behaviour back-deploys to iOS 17, so you get it by compiling with Xcode 27 rather than by raising the target — that is a single-source claim (§1), but nothing below depends on it.

**A8. On Xcode 27+, `@State private var model = Model()` is the correct and complete way to own an observable model in a view. The `.task { }`-based lazy-init dance is dead.** On Xcode 26 and earlier the eager-init cost is real and the old workaround still applies — Apple's `State` reference page as of late July 2026 still carried both the old guidance and the new note, so read it with the version in mind.

**A9. Budget one mechanical migration pass when you move to Xcode 27.** TN3211 documents the breakages. Three are compile errors; one ships bugs.

```swift
// ❌ error: 'self' used before all stored properties are initialized
//    note: 'self.name' not initialized
struct LibraryScreen: View {
    var name: String
    @State private var counter: Int
    init(name: String) {
        self.counter = 42        // reaches through self to the synthesized storage,
        self.name = name         // and `name` has not been written yet
    }
}

// ✅ plain stored properties FIRST, @State last
struct LibraryScreen: View {
    var name: String
    @State private var counter: Int
    init(name: String) {
        self.name = name
        self.counter = 42
    }
}
```

**A note on that diagnostic, because the wrong version of it is in circulation.** A view is a `struct`, so the error you get is the *struct* form above — Swift's definite-initialization pass, reproduced on 6.3.3 with `swiftc -emit-sil` (it is a SIL-stage diagnostic, so `-typecheck` alone will not show it to you). If you see this migration described with `error: 'self' used in property access '_counter' before 'super.init' call`, that text is wrong and grepping for it will find nothing: `super.init` exists only for a class with a superclass, and a struct initialiser never calls it. I could not run the Xcode 27 toolchain to paste its exact wording, so treat the note text as the 6.3.3 wording and the *form* — "you touched `self` too early" — as the part that transfers.

```swift
// ❌ SILENT: the inline default wins, the init assignment is ignored. Compiles. Ships wrong.
struct CounterView: View {
    @State private var counter: Int = 0
    init() { self.counter = 42 }     // dead code
}

// ✅ drop the inline default when init assigns
struct CounterView: View {
    @State private var counter: Int
    init() { self.counter = 42 }
}
```

Also: you can no longer compose another property wrapper onto `@State` (`error: invalid redeclaration of synthesized property '_counter'` — both wrappers want the same underscored storage), and the **memberwise initialiser is no longer synthesised** for a struct containing `@State`. Write it by hand:

```swift
struct Foo: View {
    @State private var bar = 0
    private let baz: Int

    init(bar: Int, baz: Int) {
        self._bar = State(initialValue: bar)   // assigning the STORAGE directly
        self.baz = baz
    }
}
```

Note the ordering here contradicts the rule above only in appearance. A9's "plain properties first" applies to assigning through the **wrapped** name (`self.counter = 42`), which reads `self` to reach the synthesized storage. Assigning `self._bar` *is* the storage, so it is legal anywhere in the initialiser. Both forms are correct; do not "fix" one into the other.

**A10. Grep for `@State private var x: T = ` alongside an `init` before you build with Xcode 27.** That combination is the one that changes behaviour without a diagnostic.

The same technote covers `ContentBuilder`, which unifies `ViewBuilder`/`SectionBuilder`/`ChartContentBuilder` to cut type-checking time; it works with any deployment target. Its breakages are ambiguity (`.overlay(Color.blue.opacity(0.7).blendMode(.overlay))` → use the closure form `.overlay { … }`), cross-module `Color` collisions (fully qualify `SwiftUI.Color.clear`), and `TupleView<(A, B)>` → `TupleContent<A, B>`. That is a syntax migration, not an architectural one — `07-TOOLING-BUILD-AND-SHIPPING.md` owns the upgrade sequencing.

---

## 5. The property-wrapper decision procedure

**A11. Run this table. Do not choose by feel.**

| Situation | Use | Note |
|---|---|---|
| Value-type state this view owns, nobody else needs (`isExpanded`, `searchText`) | `@State private var` | Always `private`. No exceptions |
| An `@Observable` model **created by** this view | `@State private var model = Model()` | Lazy once, on Xcode 27+ (§4) |
| Child needs read/write on a parent's value state | `@Binding var` in child, `$value` at call site | |
| Child needs to **read** an `@Observable` from a parent | plain `var model: Model` — **no wrapper** | Adding a wrapper here is the anti-pattern |
| Child needs `$model.prop` for an `@Observable` it does not own | `@Bindable var model: Model` | Or inline in `body`: `@Bindable var model = model` |
| Ambient dependency needed deep in a hierarchy | `@Environment(Model.self)` / `@Environment(\.key)` | §9 for the cost |
| The environment value may not be installed | `@Environment(Model.self) private var model: Model?` | Optional form avoids a runtime trap |
| Scalar user preference | `@AppStorage` | Do not build a model layer for a `Bool` |
| Per-scene UI restoration (selected tab, encoded path) | `@SceneStorage` | §10 |

**A12. When you need bindings out of an environment model, redeclare it with `@Bindable` at the top of `body`.** `@Environment` hands you a `let`-ish value; this is the sanctioned trick, straight from Apple's docs.

```swift
struct SettingsScreen: View {
    @Environment(Settings.self) private var settings
    var body: some View {
        @Bindable var settings = settings          // one line, inside body
        Toggle("Dark mode", isOn: $settings.isDarkMode)
    }
}
```

**A13. The rule for view state vs model state, stated flatly:**

> State belongs in the view **if and only if** losing it when the view is destroyed is correct behaviour, **and** no other part of the app can observe or change it.

Everything else is model state: anything restored after relaunch, anything two screens read, anything a background task mutates, anything you want to unit test. Test cases: `isShowingDeleteConfirmation` → view. `draftTitle` in an editor sheet → view, unless you want draft restoration, at which point it becomes model. `sortOrder` on a list → view if it resets, model if the user expects it to persist. Anything fetched from network or disk → model, always.

---

## 6. Three tiers, and the two rules that prevent most state bugs

| Tier | Lifetime | Owner | Persisted | Examples |
|---|---|---|---|---|
| **App state** | Process / account session | `@Observable` store injected at `@main`, or the persistence layer | Yes | signed-in user, library contents, sync status, feature flags |
| **Screen state** | While the screen is on a stack | `@State` in the screen; a screen-scoped `@Observable` only if §7 triggers | Sometimes, via `@SceneStorage` | current filter, nav path, wizard step, in-flight submit |
| **Ephemeral view state** | While the view exists | `@State private` in the leaf | Never | `isExpanded`, focus, hover, animation phase |

**A14. Never mirror app state into screen state.** `@State private var books = store.books` is a second source of truth that will drift, and it defeats Observation, which was going to give you the update for free. Read `store.books` in `body`.

**A15. Derive, don't store.** If a value is a pure function of other state, make it a computed property. Observation tracks computed properties transitively, so the invalidation is correct and free.

```swift
// ❌ two sources of truth; every mutation path must remember to re-filter
@Observable final class LibraryStore {
    var books: [Book] = []
    var visibleBooks: [Book] = []
    var query = "" { didSet { visibleBooks = books.filter { $0.title.contains(query) } } }
}

// ✅ one source of truth, derived projection
@Observable final class LibraryStore {
    var books: [Book] = []
    var query = ""
    var visibleBooks: [Book] { BookSearch.filter(books, query: query) }   // pure fn from Models
}
```

*Cost of A15:* a genuinely expensive derivation now runs on every `body` evaluation that reads it. Measure before caching; if you must cache, cache into an `@ObservationIgnored` property behind an explicit invalidation, and write a comment saying why.

**A16. Expose mutable model state as `private(set)` and mutate it through named methods.** `books` is read by five views; `toggleRead(_:)` is the only thing that may change it. This is what makes a store testable without a UI and greppable when the value is wrong.

---

## 7. View models: the ruling

**Default: no per-screen view models.** Model the domain with `@Observable` stores scoped by bounded context, keep transient UI state in `@State`, and put pure logic in plain testable types.

The evidence, honestly: Apple's current sample app `sample-backyard-birds` contains **not one** `ViewModel` type — views read `@Query` directly, hold `@State` for selection, and pull configuration from `@Environment`. Apple's docs say the framework "automatically performs most of the work that **view controllers** traditionally do" — note *view controllers*, not view models. The widely-circulated "…(and view models)" version of that quote is not the current doc text; do not repeat it. Separately, an Apple DTS engineer wrote "I think it does make sense for your view models to be main-actor bound" — Apple has never said don't use them. **The accurate claim is: Apple doesn't need view models and doesn't ship them, not that Apple bans them.**

The strongest case against per-screen view models: SwiftUI's `body` already *is* the state→UI transform a UIKit view model performed; one view model per screen manufactures N overlapping sources of truth and hands you a synchronisation problem you did not have; and `@Environment` is unreachable from a plain object, so view models push you back into constructor threading. The strongest case for: views are not unit-testable — asked how he unit tests SwiftUI views, Sundell answered "I don't" — and an `async` flow that mutates UI state needs a `@MainActor` home that isn't a struct recreated on every render.

**A17. One `@Observable` store per bounded context, not per screen.** `CatalogStore` (products, categories, reviews), `OrderingStore` (orders, line items, shipping). Two screens sharing one store is the normal case, not a smell.

The store below is drawn behind a repository, i.e. **after** A45's persistence escalation, because that is the version that has wiring worth showing. Pre-escalation the same store is much smaller: `books`, `load()`, `loadFailure` and `visibleBooks` all disappear — the rows come from `@Query` and the filtering moves into its predicate — leaving `query` plus whatever in-flight or sync state SwiftData does not model. §11's "The default path, whole" writes that version out and diffs it against this one.

```swift
@MainActor @Observable
public final class LibraryStore {
    public private(set) var books: [Book] = []
    public private(set) var loadFailure: String?
    public var query = ""

    public var visibleBooks: [Book] { BookSearch.filter(books, query: query) }   // A15

    private let repository: any BookRepository
    public init(repository: any BookRepository) { self.repository = repository } // A20

    public func load() async {
        do { books = try await repository.all(); loadFailure = nil }
        catch { loadFailure = error.localizedDescription }
    }

    public func toggleRead(_ book: Book) async {
        guard let i = books.firstIndex(where: { $0.id == book.id }) else { return }
        var updated = book
        updated.isRead.toggle()
        books[i] = updated                                   // optimistic
        do { try await repository.save(updated) }
        catch { books[i] = book }                            // rollback
    }

    public func book(id: Book.ID) -> Book? { books.first { $0.id == id } }
}
```

**The honest cost of A17:** async orchestration ends up in `.task { }` and `Button` actions, and *that* code is not unit-testable except through the store. You are trading per-screen unit tests for store-level tests plus previews. If your org's definition of done is "every screen has a view-model test", you will fight this rule and probably lose. And complex screens do accumulate `@State` properties — watch the count.

**A18. Introduce a screen-scoped `@Observable` when — and only when — one of these is true:**

1. The screen owns a multi-step async flow with cancellation, retry, or in-flight de-duplication.
2. The screen has ≥3 interdependent pieces of ephemeral state whose invariants you'd assert in a test (wizard steps, form validity, optimistic update plus rollback).
3. The screen's behaviour must be tested without rendering because it is high-risk: payments, auth, sync.
4. A UIKit screen alongside it must share the same behaviour.

**A19. Name it after the screen's job — `CheckoutFlow`, `SignUpForm`, `FeedPaginator` — not `XViewModel`.** The suffix invites the pass-through version. (`02-NAMING-AND-API-DESIGN.md` N40 is the authority and it rejects the `ViewModel` suffix outright, naming these same alternative shapes; it records the weaker position — allow `XViewModel` when the type adapts exactly one view — as defensible and common, and then rules against it *because* the suffix invites the pass-through object this rule exists to prevent. This rule is the architectural half of that same ruling, and 02 §17's ban table is the naming half.)

**The pass-through smell test:** if you deleted the type and had the view read the model directly, would any test fail and would any behaviour change? If no to both, delete it.

```swift
// ❌ Every member forwards. No state, no decisions, no test worth writing. Delete the file.
@MainActor @Observable
final class BookDetailViewModel {
    private let book: Book
    init(book: Book) { self.book = book }
    var title: String { book.title }
    var author: String { book.author.name }
    func toggleAvailability() { book.isAvailable.toggle() }
}
```

Other tells: every property is `model.something` with no transformation; its only "logic" is formatting (`Text(date, format: .dateTime)` does that for free and locale-correctly); it exists because the template had one.

**A20. Extract non-trivial view logic into plain structs and test those, not the view.**

```swift
// In Models. No SwiftUI, no I/O, no mocks needed to test it.
public struct LoginFormConfig: Equatable, Sendable {
    public var username = ""
    public var password = ""
    public var isValid: Bool { !username.trimmed.isEmpty && password.count >= 8 }
}
```

Resist inventing a protocol and a mock purely so a test can exist — test-induced damage is a real cost and it is charged to every future reader.

---

## 8. The UI-free core

**A21. Every decision your app makes — pricing, validation, scheduling, conflict resolution, state machines, parsing — lives in a module that does not import SwiftUI.** If you *can't* `import SwiftUI` there, you can't accidentally put a `Color` or a `@State` in your domain, and you can't accidentally require a running app to test it.

**A22. Give the domain module no default actor isolation, and give the UI modules `MainActor`.** This mechanically discourages main-actor-bound business logic. Rationale and the full isolation strategy are in `05-CONCURRENCY.md` R7 (split default isolation by module); the `Package.swift` mechanics are in `07-TOOLING-BUILD-AND-SHIPPING.md`.

```swift
// Modules/Package.swift — swift-tools-version: 6.2 or later. One manifest, N targets (A3).
.target(name: "Models"),                                  // no dependencies (01 P5) and no default
                                                          // isolation — nonisolated pure logic and actors
.target(name: "Persistence", dependencies: ["Models"]),   // nonisolated: a @MainActor data layer is a bug you profile later
.target(name: "Networking",  dependencies: ["Models"]),   // nonisolated — see §11a and 05 R7
.target(name: "DesignSystem", dependencies: ["Models"],
        swiftSettings: [.defaultIsolation(MainActor.self)]),
.target(name: "AppFeature", dependencies: ["Models", "DesignSystem", "Persistence", "Networking"],
        swiftSettings: [.defaultIsolation(MainActor.self)]),
```

**A23. Write `@MainActor` explicitly on model types that live in packages**, even when a build setting would supply it. The isolation should be legible at the declaration, not in a target's settings.

**Honest cost of A21–A23:** cross-package refactors are slower because you widen `public` surface deliberately (that is also the point), and Xcode's local-package handling is still occasionally janky around previews and resource bundles. **For a genuinely tiny app — one screen, no persistence — a single target with folders is fine.** `01-PROJECT-STRUCTURE.md` P11 owns the trigger and states it as three independent tests: two targets need the code, or you want tests for it that do not boot a simulator, or it has crossed ~1,500 lines with a nameable responsibility. A second surface (widget, watch app, App Intents) is P11's first test and it forces the split anyway; if you know one is coming, split on day one. Note that A21's boundary is not the same decision as P11's: A21 says domain logic must be *unable* to import SwiftUI, and one target with a `#if canImport` discipline does not give you that — only a separate target does. So when P11 has not fired yet, keep the domain in its own folder and treat "no SwiftUI import" as a review rule until it becomes a compiler rule.

---

## 9. Dependency injection

**A24. Initialiser injection for everything below the view layer; `Environment` for the handful of ambient things every screen needs; no DI framework until you have a concrete, named pain.**

This is a contested area and the disagreement is real: Azam argues environment-for-everything because DI boilerplate is the enemy; Sundell and SwiftLee argue initialiser injection for testability; Fatbobman runs both systems in parallel. **Rule: Fatbobman is right**, and the two facts that settle it are that a plain service object cannot read the SwiftUI environment, and that new presentation hierarchies do not inherit it.

| Mechanism | Use it for | Real cost |
|---|---|---|
| **Initialiser injection** | Stores, repositories, clients, anything below the view layer | "Threading through layers" — but only if you inject into *views*. Inject into the store once at the root and there is nothing to thread |
| **SwiftUI `Environment`** | App-wide stores, router, feature flags, design tokens, formatters | Not inherited by sheets/covers/popovers/alerts/new windows/UIKit-hosted islands; missing installation is a runtime trap, not a compile error; unreadable in `init`; unreachable from non-views |
| **Container / property-wrapper DI** (`swift-dependencies` 1.14.1, Factory 3.3.2) | Test and preview overrides without rewriting initialisers | A *controlled* global. You lose "read the signature, know the dependencies" |

**A25. The #1 environment bug is a sheet. Re-inject everything a presented subtree needs.**

```swift
// ❌ BookEditor traps at runtime: sheets start a new environment hierarchy
.sheet(item: $editing) { book in BookEditor(book: book) }

// ✅
.sheet(item: $editing) { book in
    BookEditor(book: book).environment(library)
}
```

**A26. Use the optional form wherever installation isn't guaranteed** — reusable components in a package, anything presented from a new window scene.

```swift
@Environment(Library.self) private var library: Library?   // no trap; you handle nil
```

**A27. Declare custom environment values with `@Entry`.** Xcode 16+ toolchain, back-deploys to iOS 13, and it removes the `EnvironmentKey` + `defaultValue` + computed-property boilerplate entirely.

```swift
// ✅ three lines
extension EnvironmentValues {
    @Entry var analytics: any AnalyticsClient = NoopAnalyticsClient()
}

// ❌ the pre-Xcode-16 form. Delete it on sight.
private struct AnalyticsKey: EnvironmentKey {
    static let defaultValue: any AnalyticsClient = NoopAnalyticsClient()
}
extension EnvironmentValues {
    var analytics: any AnalyticsClient {
        get { self[AnalyticsKey.self] }
        set { self[AnalyticsKey.self] = newValue }
    }
}
```

**A28. Install app-wide dependencies with a `ViewModifier` exported from the owning module**, not with a chain of `.environment(…)` calls in `@main`. Apple's own sample does this — `.backyardBirdsDataContainer()` — and it keeps the knowledge of what a module needs inside that module.

**A29. The rule is not "no singletons" — it is "no singleton on the inside of a boundary you need to test across."** `URLSession.shared` at the composition root is fine, because the substitutable boundary is the protocol you defined in front of it.

```swift
// 1. Define the capability you need — narrow, not the vendor's whole SDK
public protocol ImageLoading: Sendable {
    func load(_ url: URL) async throws -> Data
}

// 2. Real implementation is a plain type — no `static let shared`.
//    `public let` + an explicit `public init`: a public struct's synthesized memberwise
//    initialiser is INTERNAL, so without these two lines step 4 does not compile from
//    another target — which is the whole point of the boundary.
public struct URLSessionImageLoader: ImageLoading {
    public let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func load(_ url: URL) async throws -> Data { try await session.data(from: url).0 }
}

// 3. Consumers take it in the initialiser
@MainActor @Observable
public final class GalleryStore {
    private let loader: any ImageLoading
    public init(loader: any ImageLoading) { self.loader = loader }
}

// 4. Compose once, in AppDependencies.live() (A2):
//    GalleryStore(loader: URLSessionImageLoader(session: .shared))
```

Step 2 is the one people get wrong across a module boundary. Swift never synthesises a `public` memberwise initialiser, and one internal stored property makes even the internal one useless to a caller outside the target. Write the `public init` by hand on every type the composition root constructs.

What the singleton costs, concretely: downstream tests become integration tests against the real network/disk/keychain/clock; state leaks between tests, so ordering matters and flakes follow; previews break or, worse, do real work (a live analytics client firing from a preview); and the dependency is invisible at the call site.

**A30. Wrap a legacy singleton you cannot delete; do not inject it.** One file of shim buys the whole test suite.

```swift
struct LegacyAnalytics: AnalyticsClient {
    func log(_ event: Event) { Analytics.shared.log(event.name, event.parameters) }
}
```

**A31. Reach for `swift-dependencies` (standalone, no TCA) only when you hit the specific pain of needing preview/test overrides without rewriting initialisers.** It is one package. Adopting it is not adopting an architecture. *Deviate when:* your team already runs Factory — the two solve the same problem and switching buys nothing.

---

## 10. Navigation is data

**A32. Model routes as an enum in your UI-free core, and navigate with a typed `[Route]` array — not `NavigationPath`.**

```swift
// Modules/Sources/Models/Route.swift — no SwiftUI import
public enum Route: Hashable, Codable, Sendable {
    case bookDetail(Book.ID)
    case authorDetail(Author.ID)
    case settings
}
```

Apple documents `[Route]` and `NavigationPath` neutrally. The ruling is typed arrays: they are `Codable` for free, inspectable in the debugger, assertable in a test, and state restoration is plain `JSONEncoder`. `NavigationPath.CodableRepresentation` serialises **only if every pushed value is `Codable`**; otherwise `path.codable` is `nil` and restoration silently no-ops. *Deviate when:* the stack is genuinely heterogeneous across modules that cannot share a `Route` type.

**A33. One `@Observable` `Router` per `NavigationStack` — i.e. per tab — not one global router.** Each tab keeps independent history, and routers compose with modularisation.

```swift
@MainActor @Observable
final class Router {
    var path: [Route] = []
    func push(_ route: Route) { path.append(route) }
    func pop() { _ = path.popLast() }
    func popToRoot() { path.removeAll() }
    func replace(with routes: [Route]) { path = routes }     // deep links land here
}
```

**A34. Navigate by ID, never by model object.** Apple's sample does `navigationDestination(for: Backyard.ID.self)` and looks the model up. A model copy sitting in the path is a stale-data bug factory; IDs survive serialisation and refetch.

**A35. Put `navigationDestination(for:)` on the container, never inside a lazy container's children.** `List`, `ForEach`, `LazyVStack` and `ScrollView` content instantiate only visible children, so a destination declared inside may never register and the push silently does nothing.

```swift
NavigationStack(path: $router.path) {
    List(library.visibleBooks) { book in
        NavigationLink(value: Route.bookDetail(book.id)) { BookRow(book: book) }
    }
    .navigationDestination(for: Route.self) { route in     // ✅ OUTSIDE the List
        switch route {
        case .bookDetail(let id):   BookDetailScreen(bookID: id)
        case .authorDetail(let id): AuthorDetailScreen(authorID: id)
        case .settings:             SettingsScreen()
        }
    }
}
```

**A36. Deep-link parsing is a pure `URL -> [Route]?` function in `Models`, with a unit test per supported URL shape.** This is the single biggest testability win available in navigation, and it costs about fifteen lines.

```swift
public enum DeepLink {
    public static func routes(for url: URL) -> [Route]? {
        guard url.scheme == "readinglist" else { return nil }
        switch url.host() {
        case "book":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return [.bookDetail(id)]
        default:
            return nil
        }
    }
}
// .onOpenURL { if let routes = DeepLink.routes(for: $0) { router.replace(with: routes) } }
```

**A37. Present sheets, covers, dialogs and alerts with the `item:` form, never `isPresented` plus a parallel payload.** The two-variable form is where every "sheet shows with stale data" bug comes from.

```swift
// ❌ two variables that can disagree
@State private var isEditing = false
@State private var bookToEdit: Book?

// ✅ one source of truth
@State private var editing: Book?
.sheet(item: $editing) { book in BookEditor(book: book).environment(library) }   // + A25
```

Per WWDC26, `.confirmationDialog(_:item:)` and `.alert(_:item:)` take the same item binding in the new SDK, removing the last places a parallel `Bool` was required. Verify availability in your SDK before adopting.

**A38. No coordinator layer.** The UIKit coordinator existed because `UIViewController` owned presentation imperatively and something had to break the child↔parent coupling. `NavigationStack(path:)` already made navigation *data*; a coordinator wrapping that data adds a layer without removing one. A `Route` enum, one `Router` per stack, one `switch` per stack and a tested deep-link function give you everything the coordinator promised at roughly forty lines and zero new concepts. The "MVVM+C is the 2026 production default" claim is asserted almost entirely by low-quality SEO content; it does not appear in any first-tier source. *Deviate when:* you have a genuinely reusable **flow** entered from multiple places with entry-dependent completion — onboarding, a payment flow, a document-picker-like modal chain. Then a small flow object with its own sub-`Route` enum and a completion closure earns its keep. That is a flow controller, not an app-wide coordinator layer.

**A39. Restore navigation with `@SceneStorage` holding encoded `[Route]`.** With a typed array this is plain `JSONEncoder`/`JSONDecoder` — no `CodableRepresentation` dance. It is the strongest concrete argument for A32.

---

## 11. The persistence boundary

**A40. For a new small offline app: SwiftData.** Models are your Swift types with `@Model` — no `.xcdatamodeld`, no codegen, no `NSManagedObject` subclasses; `#Predicate` is type-checked where `NSPredicate` format strings are runtime landmines; `@ModelActor` gives a usable background story; and Apple's own current multiplatform sample is built on it.

This one is genuinely contested. Azam says iOS 27 is "the first release where many of the framework's early rough edges have started to disappear" and now considers it fit for larger projects. Fatbobman says the same release "feels more like it is filling key gaps rather than making a leap significant enough to fundamentally change confidence in it"; Massicotte reports `ModelActor` "continues to sometimes run code on the main thread"; Heß notes `@Attribute(.codable)` content "cannot participate in SwiftData's predicate, sort, or migration awareness". **Ruling: ship it for a small offline app, with those four holes on your risk list — no CloudKit sync for public/shared data, unqueryable `.codable` blobs, reported `ModelActor` main-thread bleed, and Core Data's failure modes still reachable underneath.**

| Instead use | When |
|---|---|
| Plain `Codable` + atomic write to `URL.applicationSupportDirectory` | Data is small, read/written whole, no relational queries. Settings, a saved game, a small offline list, a cache. **Under ~1000 records with no querying this genuinely beats SwiftData**: ~30 lines, zero framework risk, trivially testable, diffs in git |
| `@AppStorage` | Scalar user preferences. Do not build a model layer for a `Bool` |
| GRDB (7.11.1) | Real SQL, tens of thousands of rows, migrations you fully control, or measured insert throughput. (The widely-quoted "~20x faster inserts" figure is a single practitioner blog with no reproducible benchmark — treat as directional, and measure your own workload) |
| Core Data | Only in an existing Core Data app. Do not start one in 2026. Nothing new shipped this year and there has been no communication about it — that is a read, not an Apple deprecation notice |

**Here are the ~30 lines, because a row in a table that says "~30 lines" and does not show them is not a recommendation.** This is the whole first row: no schema, no migration, no framework to be wrong about. Atomicity is one `Data.WritingOptions` flag — `.atomic` writes a temporary file and renames it, so a crash mid-write leaves the previous version intact rather than a truncated one.

```swift
// Modules/Sources/Persistence/JSONStore.swift — the entire persistence layer for the first row.
public actor JSONStore<Value: Codable & Sendable> {
    private let url: URL
    private let makeDefault: @Sendable () -> Value
    private var cached: Value?

    /// A48's "one decoder" rule is per *wire format*, not per app: this pair is the second and
    /// last one in the codebase, it is `let` and module-private, and it deliberately does NOT
    /// adopt `.convertFromSnakeCase` — on disk the keys are your property names, forever.
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(url: URL, default makeDefault: @escaping @Sendable () -> Value) {
        self.url = url
        self.makeDefault = makeDefault
    }

    public func load() throws -> Value {
        if let cached { return cached }
        guard FileManager.default.fileExists(atPath: url.path()) else {
            let value = makeDefault()               // first launch is not an error (W37)
            cached = value
            return value
        }
        let value = try decoder.decode(Value.self, from: Data(contentsOf: url))
        cached = value
        return value
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(value).write(to: url, options: .atomic)   // the whole durability story
        cached = value
    }
}
```

Composed like anything else, in `live()` (A2): `JSONStore<[Book]>(url: .applicationSupportDirectory.appending(path: "books.json"), default: { [] })`. It is an `actor` because file I/O has no business on the main actor (`05-CONCURRENCY.md` R7), and because "read the whole file, hand back a value type" is exactly the cohesive-state-with-behaviour row of R17. **What you are giving up, stated plainly:** no partial reads, no queries, no indexes, and the whole file is rewritten on every save — which is why the row says ~1000 records. Past that, or the first time you want "all unread books added this month" without loading everything, you have outgrown it; go to SwiftData or GRDB rather than inventing an index.

**A45. Default to `@Query` in the view. Add A41's repository boundary only when a named trigger fires — and then it is not optional.** These are not two interchangeable styles; they produce different view code, and this guide has one default. For the small offline app §1 targets, install the container at the root, read rows with `@Query`, and let SwiftData be the observation mechanism it was built to be. Escalate the moment **any** of these is true:

1. **A second surface reads the same data** — widget, App Intent, Live Activity, watch app, sync engine. `@Query` only exists inside a SwiftUI view; the second surface is what forces a headless read path.
2. **You expect the engine to change** inside the app's likely lifetime — SwiftData → GRDB, or off-device entirely.
3. **The write path has invariants worth unit-testing without a view** — reconciliation, conflict resolution, optimistic update plus rollback.
4. **Migration is complex enough** that you want the store's failure modes (A46) behind one type you can test.

Below that bar the boundary is cost with no return: you hand-roll observation and end up with a worse `@Query`. Above it, one of the four triggers is already forcing the split, so "should I?" is not the question — write the protocol. **Record which side of A45 you are on in the repo README**, because the answer changes what every new screen looks like.

**A46. Opening the store can fail on data you do not control, so `try!` is not available to you. Decide the failure policy once, in one factory, and call it from the composition root.** `ModelContainer(for:)` throws on a migration that did not apply, a corrupt or unreadable store file, a full disk, and a schema that disagrees with the file already on disk. None of those is programmer error, so `03-WRITING-THE-CODE.md` W37 (*"`try!` is forbidden outside tests"*, enforced by swift-format's `NeverUseForceTry`, which W54 tells you to switch on repo-wide) applies here with no exemption. A failed migration is the single most common real launch failure in a SwiftData app; it deserves a decision, not a `!`.

Two defensible policies. Pick one per app and write down which.

**Policy 1 — rebuild.** Correct when the data is re-derivable: a cache, a downloaded catalogue, anything the server still has.

```swift
// Modules/Sources/Persistence/ModelContainer+ReadingList.swift
extension ModelContainer {
    /// Policy: the library is re-downloadable, so a store we cannot open is moved aside and
    /// rebuilt. The moved file is the artefact you ask an affected user to send you.
    public static func readingList(
        at url: URL = URL.applicationSupportDirectory.appending(path: "ReadingList.store")
    ) -> ModelContainer {
        let configuration = ModelConfiguration(url: url)
        do {
            return try ModelContainer(for: StoredBook.self, configurations: configuration)
        } catch {
            logger.error("store open failed at \(url.path(), privacy: .public): \(error)")
            let quarantined = url.appendingPathExtension("unreadable-\(Date.now.timeIntervalSince1970)")
            try? FileManager.default.moveItem(at: url, to: quarantined)   // reason already logged above (W38)
            do {
                return try ModelContainer(for: StoredBook.self, configurations: configuration)
            } catch {
                // W39: unreachable unless Application Support is unwritable, and then there is no
                // app to run. The message names the store so the crash report is actionable.
                fatalError("ReadingList store unusable at \(url.path()): \(error)")
            }
        }
    }
}
```

**Policy 2 — surface it.** The only honest option for user-authored data, which you must never silently discard. Return the failure instead of swallowing it, run against an in-memory container so the app still launches, and render a real screen that says so and offers retry or export.

```swift
// Modules/Sources/Persistence/StoreOpenOutcome.swift
public enum StoreOpenOutcome: Sendable {
    case opened(ModelContainer)
    case degraded(ModelContainer, StoreError)   // in-memory; the on-disk file is untouched

    public var container: ModelContainer {
        switch self {
        case .opened(let container), .degraded(let container, _): container
        }
    }
}

public enum StoreError: Int, LocalizedError, CustomNSError {   // W35
    case couldNotOpenStore = 1

    public var errorDescription: String? {
        String(localized: "Your library could not be opened. Nothing has been deleted.")
    }
}
```

What is never correct: `try!`; or a silent `ModelConfiguration(isStoredInMemoryOnly: true)` fallback with no log line and no UI, which makes the user's data look deleted and sends you no report.

**The default path, whole.** Everything after this block is the *escalated* shape, and so is the root drawn in §2. A45 says most small apps should never build it, so here is the path they should build instead, end to end: a `@Model` type, one container installed by A28's modifier, one screen where `@Query` and a `LibraryStore` coexist, and Policy 2's degraded case actually rendering. Five short files, no repository, no protocol.

```swift
// Modules/Sources/Persistence/StoredBook.swift — the only file in the app that imports SwiftData.
import SwiftData

@Model
public final class StoredBook {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isRead: Bool
    public var addedAt: Date

    public init(id: UUID = UUID(), title: String, isRead: Bool = false, addedAt: Date = .now) {
        self.id = id
        self.title = title
        self.isRead = isRead
        self.addedAt = addedAt
    }
}
```

Policy 2 defined `StoreOpenOutcome` but not the factory that returns it. This is that factory, and the small projection the UI actually reads — the view has no business pattern-matching on a `ModelContainer`:

```swift
// Modules/Sources/Persistence/StoreOpenOutcome+ReadingList.swift — A46, Policy 2.
// The factory hangs off the type it RETURNS, not off `ModelContainer`; that is what lets the
// composition root below write `store: .readingList()` and have the leading dot resolve.
extension StoreOpenOutcome {
    /// Never throws and never discards. On failure the app launches against an in-memory
    /// container and the on-disk file is left exactly where it is, for support or export.
    public static func readingList(
        at url: URL = URL.applicationSupportDirectory.appending(path: "ReadingList.store")
    ) -> StoreOpenOutcome {
        do {
            let onDisk = try ModelContainer(
                for: StoredBook.self,
                configurations: ModelConfiguration(url: url)
            )
            return .opened(onDisk)
        } catch {
            logger.error("store open failed at \(url.path(), privacy: .public): \(error)")
            do {
                let memory = try ModelContainer(
                    for: StoredBook.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                return .degraded(memory, .couldNotOpenStore)
            } catch {
                // W39: unreachable unless the process cannot allocate a container at all.
                fatalError("in-memory ReadingList container unusable: \(error)")
            }
        }
    }
}

public enum StoreHealth: Sendable, Equatable {
    case healthy
    case degraded(message: String)     // the on-disk file is intact; nothing was deleted
}

extension StoreOpenOutcome {
    public var health: StoreHealth {
        switch self {
        case .opened: .healthy
        case .degraded(_, let error): .degraded(message: error.localizedDescription)
        }
    }
}
```

The store keeps only what SwiftData has no opinion about. Rows are not in it, and neither is `load()`:

```swift
// Modules/Sources/AppFeature/LibraryStore.swift — pre-escalation. Compare §7's version.
@MainActor @Observable
public final class LibraryStore {
    public var query = ""                              // drives the @Query predicate below
    public private(set) var isImporting = false        // in-flight work; SwiftData tracks no such thing

    public init() {}

    public func importCatalogue(from importer: CatalogueImporter) async {
        isImporting = true                             // synchronous first (05 R33)
        defer { isImporting = false }
        await importer.run()
    }
}
```

The container is installed by the same exported modifier as §2, so `@main` still names exactly one thing (A28), and the degraded flag rides an `@Entry` value (A27) rather than a second observable:

```swift
// Modules/Sources/AppFeature/AppDependencies.swift — the pre-escalation composition root.
extension EnvironmentValues {
    @Entry public var storeHealth: StoreHealth = .healthy
}

@MainActor
public struct AppDependencies {
    public let library: LibraryStore
    public let store: StoreOpenOutcome

    public init(library: LibraryStore, store: StoreOpenOutcome) {
        self.library = library
        self.store = store
    }

    public static func live() -> AppDependencies {
        AppDependencies(library: LibraryStore(), store: .readingList())
    }
}

extension View {
    /// A28. Note what is absent: no repository, and `LibraryStore` never sees the container.
    public func readingListEnvironment(_ dependencies: AppDependencies) -> some View {
        self
            .modelContainer(dependencies.store.container)
            .environment(dependencies.library)
            .environment(\.storeHealth, dependencies.store.health)
    }
}
```

And the screen. A `Query` is fixed when it is initialised, so the way to give it a dynamic predicate is to build it in a small child view's `init` and let the parent own the search text — that split is the one piece of `@Query` mechanics worth memorising:

```swift
// Modules/Sources/AppFeature/LibraryScreen.swift
public struct LibraryScreen: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.storeHealth) private var storeHealth

    public init() {}

    public var body: some View {
        @Bindable var library = library                       // A12
        NavigationStack {
            List {
                if case .degraded(let message) = storeHealth {
                    DegradedStoreNotice(message: message)     // A46's "real screen that says so"
                }
                BookRows(matching: library.query)
            }
            .searchable(text: $library.query)
            .navigationTitle("Library")
        }
    }
}

struct BookRows: View {
    @Query private var books: [StoredBook]

    init(matching query: String) {
        _books = Query(
            filter: #Predicate<StoredBook> { book in
                query.isEmpty || book.title.localizedStandardContains(query)
            },
            sort: \.title
        )
    }

    var body: some View {
        ForEach(books) { book in
            BookRow(book: book)
        }
    }
}

struct BookRow: View {
    @Bindable var book: StoredBook

    var body: some View {
        Toggle(book.title, isOn: $book.isRead)   // SwiftData persists it. There is no store method.
    }
}

/// A46 Policy 2 demanded "a real screen that says so and offers retry or export". This is it:
/// relaunching is the retry, and the untouched file is what makes export honest.
struct DegradedStoreNotice: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Library unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            ShareLink("Export the unreadable file", item: URL.applicationSupportDirectory
                .appending(path: "ReadingList.store"))
        }
    }
}
```

**Read the deltas, because they are the whole of A45.** Against §7's store: no `books`, no `load()`, no `loadFailure`, no `repository`, and `toggleRead` is gone because a `@Bindable` on the `@Model` object does it. Against §2's root: no `SwiftDataBookRepository`, and the container goes into the environment instead of into a store. What you gain is that a write from anywhere re-renders every `@Query` reading it, for free, with no code — which is precisely the thing A42 warns you are buying back by hand once you escalate.

**When one of A45's four triggers fires, this is what changes.** `StoredBook` stops being visible outside `Persistence`; the `@Query` is replaced by rows the store holds; `BookRows` collapses back into `LibraryScreen`; and `LibraryStore` regains `books`, `load()` and the mutators. That is a real day of work on a real screen, which is why A45 asks for a trigger and not a preference.

**A41. Once A45's trigger fires, persistence types are an implementation detail: define the repository protocol in `Models` and keep the engine in its own module.**

```swift
// Modules/Sources/Models/BookRepository.swift — no SwiftData import
public protocol BookRepository: Sendable {
    func all() async throws -> [Book]
    func save(_ book: Book) async throws
}

// Modules/Sources/Persistence/SwiftDataBookRepository.swift
@ModelActor
public actor SwiftDataBookRepository: BookRepository {
    public func all() async throws -> [Book] {
        try modelContext.fetch(FetchDescriptor<StoredBook>(sortBy: [.init(\.title)])).map(\.asDomain)
    }
    public func save(_ book: Book) async throws { /* upsert by id, then modelContext.save() */ }
}
```

Then swapping engines is a module, not a rewrite, and `Models`' tests need no database — the fake is an actor with a dictionary in it (`06-TESTING.md` owns the test-double vocabulary).

**A42. Be honest about what A41's boundary costs with SwiftData specifically: you give up `@Query`.** `@Query`'s value *is* its coupling to the view — automatic re-fetch on write, for free, with no code. Behind a repository you re-implement that yourself: a `@ModelActor` that fetches and hands back value types, plus something that tells the store when to fetch again. That bill is exactly what A45's four triggers have to be worth. Do not pretend the boundary is free, and do not pay for it pre-emptively.

---

## 11a. The networking client

Every module list in this guide names a `Networking` target, A3 draws an arrow to it, `02-NAMING-AND-API-DESIGN.md` N26 rules that it is called `HTTPClient` or `APIClient`, and `06-TESTING.md` T40/T54 tell you to fake it and record fixtures against it — and until now nothing said what is *in* it. This section is that client, whole: about sixty lines, one substitutable seam, and no ceremony you can delete.

**A47. Ship one `APIClient` per API: a `Sendable` struct with exactly one substitutable closure, in the `Networking` target, with no default isolation.** `03-WRITING-THE-CODE.md` W44 and `06-TESTING.md` T39 both put the struct-of-closures ceiling at **three** members — W44 calls that threshold "this guide's one copy of the number" and states that it matches T39 from the test-double side. A well-shaped `APIClient` has **one** closure — "send this `URLRequest`, give me bytes and a response" — so it sits comfortably inside both. Endpoints are functions in an extension that call *through* it; they are not extra closure fields. That is what holds the count at one, gives a test exactly one thing to override, and means adding an endpoint never touches a test double. If you ever find yourself at four, W44 routes you to a protocol and row 16 of 03's fails-review table is what a reviewer will cite.

Note that W44's size tiebreak is the *second* question it asks, not the first: a repository or client that is a published architectural boundary keeps its protocol at any conformer count. `APIClient` is a struct here because its seam is narrow and single-purpose — one function — not because the count came out low.

`Networking` takes `nonisolated` default isolation (`05-CONCURRENCY.md` R7): a `@MainActor` data layer is a design error you pay for the first time you profile. The closure is `@Sendable`, the struct is `Sendable`, and every caller keeps whatever isolation it already had.

```swift
// Modules/Sources/Networking/APIClient.swift
public struct APIClient: Sendable {
    public let baseURL: URL

    /// The one substitutable member. Tests, previews and fixtures replace this and nothing else.
    public var send: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public init(
        baseURL: URL,
        send: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) {
        self.baseURL = baseURL
        self.send = send
    }
}

extension APIClient {
    public static func live(baseURL: URL, session: URLSession = .shared) -> APIClient {
        APIClient(baseURL: baseURL) { request in
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.transport }
            return (data, http)
        }
    }
}
```

The `unimplemented` default T38 asks for lives in `TestSupport`, not here, so `Testing` never links into the shipping app (`01-PROJECT-STRUCTURE.md` P20 — `TestSupport` is a `.target`, not a `.testTarget`; `06-TESTING.md` T5a gives the three conditions that keep it out of the release binary):

```swift
// Modules/Sources/TestSupport/APIClient+Unimplemented.swift
import Testing

extension APIClient {
    /// T38: what every test starts from. A request you did not stub fails loudly instead of
    /// quietly reaching the network.
    public static func unimplemented(baseURL: URL = URL(staticString: "https://unimplemented.invalid")) -> APIClient {
        APIClient(baseURL: baseURL) { request in
            Issue.record("APIClient.send called unexpectedly: \(request.url?.absoluteString ?? "<no url>")")
            throw APIError.transport
        }
    }
}
```

**A48. One `request` function builds every `URLRequest` and decodes every response; the client owns its `JSONDecoder` and nothing outside `Networking` ever configures one.** A decoder built at three call sites is three date strategies and one production bug. Build it once, as a `let`, inside the module, and let the rest of the app see only decoded domain types. **Read the rule as one coder pair per *format*, not per app:** A40's file-backed `JSONStore` owns the only other pair, deliberately configured differently — no `.convertFromSnakeCase`, because your file format's keys are your property names and the server's are not yours to copy. Two formats, two module-private `let` coders, and never a third.

```swift
// Modules/Sources/Networking/Endpoint.swift
public struct Endpoint: Sendable {
    public enum Method: String, Sendable { case get = "GET", post = "POST", delete = "DELETE" }

    public var path: String
    public var method: Method
    public var query: [URLQueryItem]
    public var body: Data?

    public init(_ path: String, method: Method = .get, query: [URLQueryItem] = [], body: Data? = nil) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
    }
}
```

```swift
// Modules/Sources/Networking/APIClient+Request.swift
extension APIClient {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// The single request function. Every endpoint in the app goes through it.
    public func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        var components = URLComponents(
            url: baseURL.appending(path: endpoint.path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
        guard let url = components?.url else { throw APIError.invalidRequest(path: endpoint.path) }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.httpBody = endpoint.body
        if endpoint.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await send(urlRequest)
        } catch let error as URLError {
            throw APIError(error)                                        // A49
        }
        try Self.validate(response)                                      // A49

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            logger.error("decode \(String(describing: Response.self)) failed: \(error)")
            throw APIError.decoding(type: String(describing: Response.self))
        }
    }
}

// Endpoints are extensions, not extra closure fields — this is what keeps A47 at one member.
extension APIClient {
    public func books() async throws -> [BookPayload] { try await request(Endpoint("books")) }
    public func book(id: UUID) async throws -> BookPayload { try await request(Endpoint("books/\(id)")) }
}
```

W33 applies: plain `throws`, not `throws(APIError)`. Every throw here *is* an `APIError`, and SE-0413 says that is precisely the reason not to reach for typed throws.

**A49. Map transport failures and status codes into the module's own error enum at the client boundary — no `URLError` and no `Int` status code escapes `Networking`.** This is `03-WRITING-THE-CODE.md` W35's rule applied to the one service every app has. Note the deviation W35 forces and why: W35 asks for explicit `Int` raw values so crash-reporter grouping stays stable, but a useful API error carries associated values, which rules out a raw type. Write `errorCode` out by hand instead. The numbers are then frozen and append-only, which is all W35 was protecting.

```swift
// Modules/Sources/Networking/APIError.swift
public enum APIError: Error, LocalizedError, CustomNSError {
    case offline
    case timedOut
    case transport                      // any other URLError, or a non-HTTP response
    case unauthorized                   // 401/403, and a refresh did not fix it (A50)
    case notFound
    case client(status: Int)            // other 4xx — your bug
    case server(status: Int)            // 5xx — their bug; the only class worth retrying
    case invalidRequest(path: String)
    case decoding(type: String)

    public static var errorDomain: String { "Networking.APIError" }

    /// Stable across releases. Append only; never renumber. (W35's intent, hand-written
    /// because associated values rule out an `Int` raw type.)
    public var errorCode: Int {
        switch self {
        case .offline: 1
        case .timedOut: 2
        case .transport: 3
        case .unauthorized: 4
        case .notFound: 5
        case .client: 6
        case .server: 7
        case .invalidRequest: 8
        case .decoding: 9
        }
    }

    public var errorDescription: String? {
        switch self {
        case .offline:
            String(localized: "You appear to be offline.")
        case .timedOut, .server:
            String(localized: "The server is not responding. Please try again.")
        case .unauthorized:
            String(localized: "Please sign in again.")
        case .notFound:
            String(localized: "That item is no longer available.")
        case .transport, .client, .invalidRequest, .decoding:
            String(localized: "Something went wrong. Please try again.")
        }
    }

    init(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed: self = .offline
        case .timedOut: self = .timedOut
        default: self = .transport
        }
    }
}

extension APIClient {
    static func validate(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200..<300:  return
        case 401, 403:   throw APIError.unauthorized
        case 404:        throw APIError.notFound
        case 400..<500:  throw APIError.client(status: response.statusCode)
        default:         throw APIError.server(status: response.statusCode)
        }
    }
}
```

`URLError.cancelled` deliberately has no case: a cancelled request is not an error to show anyone. Check `Task.isCancelled` in the store and return without touching `loadFailure` (`05-CONCURRENCY.md` R40 — cancellation is a request, so code that never checks never stops).

**A50. Attach credentials and refresh them in one decorator over `send`, never at a call site.** Threading a token through every endpoint is how apps end up with three refresh paths and a thundering herd of them after a token expires. Wrap the client once, in the composition root, and single-flight the refresh through an actor — this is `05-CONCURRENCY.md` R30 (cache the `Task`, not the value) applied to the most common place the bug appears.

```swift
// Modules/Sources/Networking/TokenStore.swift
public actor TokenStore {
    private var token: String?
    private var refresh: Task<String, Error>?
    private let mint: @Sendable () async throws -> String

    public init(token: String?, mint: @escaping @Sendable () async throws -> String) {
        self.token = token
        self.mint = mint
    }

    public func current() async throws -> String {
        if let token { return token }
        return try await renew()
    }

    /// R30: store the `Task` synchronously, before the first suspension, so ten concurrent
    /// 401s produce one network refresh rather than ten.
    public func renew() async throws -> String {
        if let refresh { return try await refresh.value }
        let task = Task { try await mint() }
        refresh = task
        defer { refresh = nil }
        let fresh = try await task.value
        token = fresh
        return fresh
    }
}
```

```swift
// Modules/Sources/Networking/APIClient+Authenticated.swift
extension APIClient {
    /// One place attaches the header; one place retries exactly once on 401. No endpoint does either.
    public func authenticated(with tokens: TokenStore) -> APIClient {
        var client = self
        let send = self.send
        client.send = { request in
            let token = try await tokens.current()
            var authorized = request
            authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await send(authorized)
            guard response.statusCode == 401 else { return (data, response) }

            let renewed = try await tokens.renew()
            var retried = request
            retried.setValue("Bearer \(renewed)", forHTTPHeaderField: "Authorization")
            return try await send(retried)   // a second 401 falls through to A49's .unauthorized
        }
        return client
    }
}
```

Composed in one line, in the one place A2 allows:

```swift
// Modules/Sources/AppFeature/AppDependencies.swift — inside live(), the one place A2 allows.
let tokens = TokenStore(token: keychain.token, mint: keychain.refreshToken)
let api = APIClient
    .live(baseURL: URL(staticString: "https://api.readinglist.example.com/v1"))
    .authenticated(with: tokens)
```

Because the seam is `send`, `06-TESTING.md` T54's recorded fixtures plug straight in — no HTTP stubbing library, no `URLProtocol` subclass, no `URLSessionConfiguration` surgery:

```swift
@Test func decodesTheRecordedBooksPayload() async throws {
    var client = APIClient.unimplemented()
    client.send = { request in
        (try Fixture.data("books-200-2026-05-14.json"), .stub(200, for: request))
    }

    #expect(try await client.books().count == 3)
}
```

`Fixture.data(_:)` and `HTTPURLResponse.stub(_:for:)` are two-line helpers in `TestSupport`; `stub` wraps `HTTPURLResponse(url:statusCode:httpVersion:headerFields:)`, whose failable initialiser is the one place in this guide a documented force-unwrap is warranted (`03-WRITING-THE-CODE.md` W24 — it returns `nil` only for a URL that cannot exist here).

---

## 12. Unidirectional data flow, and whether to buy TCA

You already have UDF: state → `body` → UI, event → mutate state → re-derive. A Redux-style library does not give you that property; it adds a **reified action type** and what that unlocks — time-travel debugging, exhaustive effect-ordering tests, interception.

**A43. Do not add TCA to a new small or medium app. Its authors agree with this.** From TCA's own `FAQ.md`: "We do not recommend people use TCA when they are first learning Swift or SwiftUI"; it doesn't "really shine when building simple 'reader' apps that mostly load JSON from the network and display it"; and "it can be fine to start a project with vanilla SwiftUI (with a concentration on concise domain modeling), and then transition to TCA later." Their `Performance.md` concedes that "sending actions is not as lightweight of an operation as, say, calling a method on a class", that action ping-ponging is real, and that a TODO reads "We should be able to completely eliminate ping-ponging in TCA 2.0."

Verified costs as of 2026-07-27: `swift-composable-architecture` 1.26.1 pulls **15 package dependencies** including `swift-syntax` (macro expansion, build time); minimum platforms iOS 16 / macOS 13; the per-feature `Action` enum is permanent ceremony; onboarding spans reducers, effects, `@Reducer`, `@ObservableState`, `Scope`, `ifLet`, `forEach`, `TestStore` exhaustivity, `@Dependency` and `@Shared` — a curriculum; and the repo carries traits to pre-adopt "2.0" deprecations, so budget a major migration with no announced date.

Take the two good ideas without the framework: **controlled dependencies** → `swift-dependencies` standalone (A31); **shared/persisted state** → `swift-sharing` (2.9.1) standalone when `@AppStorage` runs out.

**Adopt TCA only when all three are true:** (a) the app's value is in complex, stateful, side-effecting logic — a game, an editor, a sync engine, a booking flow; (b) exhaustive tests of effect ordering are a correctness requirement, not a nice-to-have; (c) you have ≥3 iOS engineers who will all actually learn it. If any is false it costs more than it returns. And never adopt it to give "architecture" to a team that doesn't have one — it will look like structure while the domain modelling stays bad.

---

## 13. Observing a model from outside SwiftUI

`withObservationTracking` fires **once** and dies. That was the biggest hole in Observation and it is why data access kept ending up in `body`.

**A44. From Swift 6.2 / iOS 26, use `Observations` to bridge an `@Observable` model into an `AsyncSequence`; do not hand-roll re-arming.**

```swift
let names = Observations { person.name }        // AsyncSequence<String, Never>
for await name in names { … }
```

Semantics that matter: it is **did-set**, not will-set — you observe values after assignment; and it is **transactional**, opening at the first `willSet` and closing at the next isolation suspension point, so several synchronous mutations coalesce into one emitted value. Do not write a test that asserts an emission per mutation. Donny Wals' caveat is fair and worth internalising: Observation "was designed to work well with SwiftUI and everything else is a bit of an afterthought" — per-property historical observation, the old `$prop.sink`, is still awkward.

SE-0506 adds `withObservationTracking(options:)` over `[.willSet, .didSet, .deinit]`, `withContinuousObservationTracking` which re-arms itself, and a noncopyable `ObservationTracking.Token`. **Accepted, but the proposal names no Swift release, and Apple's WWDC26 sample spells the continuous variant `withContinuousObservation` while the proposal spells it `withContinuousObservationTracking` — check your SDK header before relying on either.** In the same family, SwiftData's iOS 27 `ResultsObserver` finally makes a SwiftData query readable outside a view: Apple's words are that it "works anywhere in your app — independent of SwiftUI views — using Swift Observation." That is the change that retires A42's main objection, once iOS 27 is your floor.

---

## 14. Review triggers

| You see | It means | Do |
|---|---|---|
| `@ObservedObject`, `@StateObject`, `@EnvironmentObject` | Unmigrated | A4 |
| `@State private var x = store.x` | Mirrored app state | A14 |
| A model property read in `.onAppear`/`.task`/a `Button` action and stashed in `@State` | Read escapes `body`'s tracking window; the copy never invalidates | A6, A14 |
| `if flag && model.value` | Short-circuit: no dependency forms on `model.value` | A6 |
| A stored property `didSet` recomputing another stored property | Should be derived | A15 |
| A type whose every member is `model.foo` | Pass-through view model | A19, delete it |
| `import SwiftUI` in the domain module | Boundary breach | A21 |
| `.shared` referenced anywhere but the composition root | Untestable edge | A29 |
| `try!` anywhere outside a test | Fails 03 W37 and the `NeverUseForceTry` rule 03 W54 turns on | A46 |
| A second local package under `Packages/` | Cannot be depended on by the first; forfeits `package` access | A3, 01 P14 |
| `public struct` with an internal stored property, constructed from another target | Memberwise init is internal — it will not compile | A29 |
| `JSONDecoder()` outside `Networking` or the one file-backed store in `Persistence` | A second date strategy for the same wire format is now in the codebase | A48, A40 |
| An `Authorization` header set at a call site | Refresh will fan out; herd on expiry | A50 |
| `@Environment(X.self)` in a sheet's subtree | Runtime trap incoming | A25, A26 |
| A model object inside a `NavigationPath` | Stale-data bug | A34 |
| `.navigationDestination` inside a `ForEach` | Push will silently fail | A35 |
| `isPresented` plus a payload `@State` | Stale sheet content | A37 |
| `@State private var x: T = …` next to an `init` assigning `x` | Xcode 27 behaviour change | A9, A10 |

---

## Checklist

**Baseline** — A1 iOS 17 is this file's architectural floor (Observation); the guide's shipping default is iOS 18 and `01-PROJECT-STRUCTURE.md` §5b owns that ruling · A2 one composition root — a `live()` factory in the top feature module, named once by `@main` · A3 dependency arrows enforced by the `dependencies:` lists in the one `Package.swift`, not by convention

**Observation** — A4 migrate off `ObservableObject` per type, delete the wrappers · A5 classes only; don't design for `@Observable struct` · A6 tracking is dynamic: synchronous helpers called from `body` are fine; reads deferred into `onAppear`/`Task`/actions, short-circuited conditions, and computed properties with no stored backing are the three that go stale · A7 mutate UI-driving state on the main actor

**Xcode 27** — A8 `@State private var model = Model()` is now correct and lazy · A9 plain stored properties before `@State` in `init`; no inline default when `init` assigns · A10 grep for the silent case before you build

**State ownership** — A11 run the property-wrapper table · A12 `@Bindable var x = x` at the top of `body` for environment bindings · A13 view state iff losing it is correct and nobody else can observe it · A14 never mirror app state · A15 derive, don't store · A16 `private(set)` plus named mutators

**View models** — A17 one store per bounded context, not per screen · A18 screen-scoped observable only on the four triggers · A19 name it after the job, never `XViewModel`; delete pass-throughs · A20 extract logic into plain structs and test those

**Modules** — A21 domain module cannot import SwiftUI · A22 no default isolation in `Models`, `MainActor` in UI · A23 explicit `@MainActor` on package-level model types

**Dependencies** — A24 initialiser injection below the view layer, `Environment` for ambient · A25 re-inject into every sheet, cover, popover and new window · A26 optional `@Environment` where installation isn't guaranteed · A27 `@Entry` for custom environment values · A28 install via an exported `ViewModifier` · A29 no singleton inside a boundary you test across · A30 wrap legacy singletons behind a protocol · A31 `swift-dependencies` only for a named override pain

**Navigation** — A32 `Route` enum in `Models`, typed `[Route]` path · A33 one `Router` per stack · A34 navigate by ID · A35 `navigationDestination` on the container · A36 deep links are a pure tested function · A37 `item:` presentation, never `isPresented` + payload · A38 no coordinator layer · A39 restore via `@SceneStorage` + encoded `[Route]`

**Persistence** — A40 SwiftData for a small offline app; the ~30-line `JSONStore` under ~1000 records; GRDB for scale; never a new Core Data app · A45 `@Query` is the default and §11's "The default path, whole" is the code for it; the repository is the escalation, and one of the four triggers must have fired · A46 store-open failure has a written policy, never a `try!` · A41 repository protocol in `Models`, engine in its own module, once A45 fires · A42 know that the boundary costs you `@Query`

**Networking** — A47 one `APIClient` struct with one substitutable closure, `nonisolated`, endpoints in extensions · A48 one `request` function; the client owns the only `JSONDecoder` · A49 map `URLError` and status codes into `APIError` at the boundary; hand-written stable `errorCode`s · A50 credentials attached and refreshed in one decorator, single-flighted through an actor

**Libraries** — A43 no TCA unless all three conditions hold; take `swift-dependencies` and `swift-sharing` standalone instead · A44 `Observations` for non-SwiftUI observation; verify SE-0506 spellings against your SDK
