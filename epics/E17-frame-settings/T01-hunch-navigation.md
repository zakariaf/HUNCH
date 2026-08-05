# T01 — `HunchNavigation`

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | Play key + ≤ 2-tap rule (the route graph half; T02 asserts it) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task creates a new target and four new types across two packages. It owns the boundary predicate that decides `HunchNavigation` may not import SwiftUI, `§6 Navigation`'s five rules (`04 A32`/`A33`/`A34`/`A35`/`A39`), the ban on `default:` in a switch over an enum you own (`W29`) — which is the mechanism that makes a nineteenth screen a compile error — and the ruling that routers are *not* in the dependency graph. It also owns the `public init` gotcha, which bites the moment `CodexFeature` constructs a `Router` declared in another target. |

## Objective

At the end of this task the app's navigation is **data**: `Screen` enumerates §12.2's eighteen nodes,
`NavigationGraph` enumerates every edge between them with its tap cost, and `Route` is the `Codable`
enum the two `NavigationStack`s push — all in a target that imports neither SwiftUI nor UIKit, so a
graph walk runs on the host with no simulator. Two `Router` instances exist, one per stack, each
owned by the view that hosts the stack and neither reachable from `AppDependencies`, and each stack's
path survives a scene restore as an encoded `[Route]` in `@SceneStorage`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.2 | the eighteen screens, and — in the **Entry** and **Exit** columns — the normative edge list this task encodes |
| `GAME_DESIGN.md` | §12.3 | the navigation map, the play key on screens 9–15, the tap-distance audit table, and the sentence *"`NavigationStack` is used twice, in the Codex and in Settings (→ About)"* |
| `GAME_DESIGN.md` | §12.3 | *"Exactly one path is three deep, and it is the Codex"* — root → shelf → page, which is why `Route` needs exactly three cases |
| `GAME_DESIGN.md` | §9.10 | `Mode`'s four cases, which the play key's destination is a function of ("resumes the suspended round if one exists, otherwise starts a new round in the last-played mode") |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A32, A33, A34, A35, A37, A38, A39 | `Route` enum in a UI-free target · one `Router` per stack · navigate by ID · `navigationDestination` on the container · `item:` presentation · no coordinator · `@SceneStorage` + encoded `[Route]` |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | no `default:` in a switch over an enum you own — the compile-time half of the play-key guard |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §4, §6 | `Modules/Sources/HunchNavigation/` holds `Route.swift`, `Screen.swift`, `NavigationGraph.swift`; the target gets **no** `.defaultIsolation`; `Router.swift` lives in `HunchAppFeature`; routers are absent from the graph |

**Do not restate a screen's contents, a region's `y` range or a key's rectangle here.** This task
encodes *which screen leads to which* and nothing about what any of them looks like.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchNavigationTests/RouteTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchNavigation

@Suite("Route, Screen and the graph's shape — §12.2, §12.3", .tags(.unit, .presubmission))
struct RouteTests {

    // MARK: - Screen

    @Test("§12.2 has eighteen screens, numbered 1…18, and Screen is in bijection with them")
    func eighteenScreens() {
        #expect(Screen.allCases.count == 18)
        #expect(Screen.allCases.map(\.rawValue) == Array(1...18))
        #expect(Set(Screen.allCases.map(\.rawValue)).count == 18)
    }

    @Test("the play surfaces are exactly the three round surfaces")
    func playSurfaces() {
        #expect(Screen.playSurfaces == [.roundView, .echoRoundView, .sieveRoundView])
        #expect(Screen.allCases.filter(\.isPlaySurface) == Screen.playSurfaces)
    }

    @Test("every mode maps to exactly one play surface, and PROBE and DRIFT share one")
    func modeToSurface() {
        #expect(Screen.playSurface(for: .probe) == .roundView)
        #expect(Screen.playSurface(for: .drift) == .roundView)
        #expect(Screen.playSurface(for: .echo) == .echoRoundView)
        #expect(Screen.playSurface(for: .sieve) == .sieveRoundView)
        #expect(Set(Mode.allCases.map(Screen.playSurface(for:))) == Set(Screen.playSurfaces))
    }

    @Test("§12.3: the play key is on screens 9…15 and on no other screen")
    func playKeyInventory() {
        let carrying = Screen.allCases.filter(\.carriesPlayKey).map(\.rawValue)
        #expect(carrying == Array(9...15))
        #expect(!Screen.about.carriesPlayKey)             // 16
        #expect(!Screen.resetConfirmAlert.carriesPlayKey) // 17
        #expect(!Screen.sievePauseOverlay.carriesPlayKey) // 18
    }

    // MARK: - Route

    @Test("Route round-trips through JSON — the whole argument for A32 over NavigationPath",
          arguments: Route.samples)
    func routeRoundTrips(_ route: Route) throws {
        let data = try JSONEncoder().encode(route)
        #expect(try JSONDecoder().decode(Route.self, from: data) == route)
    }

    @Test("a typed [Route] path round-trips, which is what @SceneStorage stores")
    func pathRoundTrips() throws {
        let path: [Route] = [.codexShelf(.contextual), .codexPage(lawKey: 0xDEAD_BEEF_CAFE_F00D)]
        let encoded = try RoutePath.encode(path)
        #expect(try RoutePath.decode(encoded) == path)
    }

    @Test("a corrupt scene-storage payload restores to an empty path, never to a crash")
    func corruptPathRestoresEmpty() {
        #expect(RoutePath.decodeOrEmpty("not json") == [])
        #expect(RoutePath.decodeOrEmpty("") == [])
    }

    @Test("Route carries IDs, never models — A34")
    func routeCarriesIdentifiersOnly() {
        // A `codexPage(CodexPage)` case would make this fail to compile; the assertion is that the
        // payload is a value small enough to be a key, and that decoding it needs no store.
        if case .codexPage(let lawKey) = Route.codexPage(lawKey: 7) {
            #expect(lawKey == 7)
        } else {
            Issue.record("codexPage lost its lawKey")
        }
    }

    // MARK: - Stacks

    @Test("§12.3: exactly two NavigationStacks, and every Route belongs to exactly one of them")
    func everyRouteBelongsToOneStack() {
        #expect(NavigationStackID.allCases.count == 2)
        for route in Route.samples {
            let owners = NavigationStackID.allCases.filter { $0.accepts(route) }
            #expect(owners.count == 1, "\(route) is accepted by \(owners.count) stacks")
        }
    }

    // MARK: - Router

    @Test("Router pushes, pops, pops to root and replaces")
    @MainActor
    func routerMutations() {
        let router = Router()
        #expect(router.path.isEmpty)
        router.push(.codexShelf(.literal))
        router.push(.codexPage(lawKey: 1))
        #expect(router.path.count == 2)
        router.pop()
        #expect(router.path == [.codexShelf(.literal)])
        router.replace(with: [.codexShelf(.systemic), .codexPage(lawKey: 2)])
        #expect(router.path.count == 2)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test("popping an empty path is a no-op, not a crash")
    @MainActor
    func popOnEmptyIsSafe() {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }
}
```

Add `Route.samples` to the test target, not to the shipping type — one sample per case, including
both extremes of `Band` and a `lawKey` with the high bit set.

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter RouteTests`

Every failure must be a **missing symbol** — `Screen`, `Route`, `RoutePath`, `NavigationStackID`,
`Router` — or a count that is wrong. If `eighteenScreens` passes before `Screen` exists, the import
is resolving to something else; delete and rewrite.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchNavigation/Screen.swift` |
| create | `Modules/Sources/HunchNavigation/Route.swift` |
| create | `Modules/Sources/HunchNavigation/NavigationGraph.swift` |
| create | `Modules/Sources/HunchAppFeature/Router.swift` |
| create | `Modules/Sources/HunchAppFeature/CodexStack.swift` |
| create | `Modules/Sources/HunchAppFeature/SettingsStack.swift` |
| modify | `Modules/Package.swift` — add the `HunchNavigation` target (no dependency on `HunchUI`, **no** `.defaultIsolation`), the `HunchNavigationTests` test target, and `HunchNavigation` as a dependency of `HunchAppFeature`, `CodexFeature` and `MetaFeature` |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — host the two stacks, install `@SceneStorage`, and `switch` over the top-level surface |
| create | `Modules/Tests/HunchNavigationTests/RouteTests.swift` |
| modify | `tests.json` — entries for the eighteen-screen inventory, the play-key inventory, and `[Route]` scene-storage round-trip |
| modify | `DECISIONS.md` — the three rulings named in *Implementation notes* below |

## Implementation notes

### `Screen` — the graph's nodes, numbered as §12.2 numbers them

```swift
// Modules/Sources/HunchNavigation/Screen.swift
import HunchCore

/// §12.2's eighteen screens. The raw value is the row number in that table, so a reviewer can
/// check the enum against the spec by reading down one column.
public enum Screen: Int, CaseIterable, Hashable, Codable, Sendable {
    case launchSurface = 1
    case frame, roundView, echoRoundView, sieveRoundView
    case bench, assayInspector, inscription
    case codexRoot, codexShelf, codexPage
    case anomaly, statistics, profile
    case settings, about, resetConfirmAlert, sievePauseOverlay

    /// §12.3: "Every non-play screen carries a play key … (screens 9–15; not on 16, 17, 18)".
    public var carriesPlayKey: Bool {
        switch self {
        case .codexRoot, .codexShelf, .codexPage, .anomaly, .statistics, .profile, .settings: true
        case .launchSurface, .frame, .roundView, .echoRoundView, .sieveRoundView,
             .bench, .assayInspector, .inscription,
             .about, .resetConfirmAlert, .sievePauseOverlay: false
        }
    }

    public var isPlaySurface: Bool { Screen.playSurfaces.contains(self) }

    public static let playSurfaces: [Screen] = [.roundView, .echoRoundView, .sieveRoundView]

    public static func playSurface(for mode: Mode) -> Screen {
        switch mode {
        case .probe, .drift: .roundView       // §12.2 screen 3 is "the PROBE / DRIFT play surface"
        case .echo: .echoRoundView
        case .sieve: .sieveRoundView
        }
    }
}
```

Both switches are exhaustive with **no `default:`** (`W29`). That is not style: it is the mechanism
by which a nineteenth screen becomes a compile error in three places at once, which is the first half
of §12.3's *"fails CI if a new screen is added without one"*.

### `Route` — three cases, because exactly one path is three deep

§12.3 is explicit that `NavigationStack` is used twice and that the Codex is the only three-deep
path. So the pushed routes are: the Codex's two, and Settings' one.

```swift
// Modules/Sources/HunchNavigation/Route.swift
import HunchCore

public enum Route: Hashable, Codable, Sendable {
    case codexShelf(Band)                 // Codex stack, depth 1
    case codexPage(lawKey: UInt64)        // Codex stack, depth 2
    case about                            // Settings stack, depth 1
}

public enum NavigationStackID: CaseIterable, Hashable, Sendable {
    case codex, settings

    public func accepts(_ route: Route) -> Bool {
        switch route {
        case .codexShelf, .codexPage: self == .codex
        case .about: self == .settings
        }
    }
}
```

**`lawKey: UInt64`, never a `CodexPage`.** `A34`: a model copy in the path is a stale-data bug
factory, and here it is worse than usual — a `CodexPage` in `@SceneStorage` would be a duplicate of
the shelf file that survives a reset and reappears after "Clear Codex". The page is looked up from
`Codex` at the destination.

`Band` is already `Codable` and `Sendable` (E05·T06), so the whole enum's conformance is synthesised.

### `RoutePath` — `@SceneStorage` restores navigation and nothing else

```swift
// Modules/Sources/HunchNavigation/Route.swift (same file — A39's storage is Route's business)
public enum RoutePath {
    public static func encode(_ path: [Route]) throws -> String {
        String(decoding: try JSONEncoder().encode(path), as: UTF8.self)
    }
    public static func decode(_ raw: String) throws -> [Route] {
        try JSONDecoder().decode([Route].self, from: Data(raw.utf8))
    }
    /// Restoration must never be able to fail loudly: a scene payload written by an older build is
    /// data we do not control (`04 A46`'s question, in its navigation costume).
    public static func decodeOrEmpty(_ raw: String) -> [Route] { (try? decode(raw)) ?? [] }
}
```

Three rules that must survive review:

1. **`@SceneStorage` holds navigation and never game state.** The suspended round is `round.json`
   and is restored by E10·T02/T03; the preferences are `UserDefaults` under `hunch.settings.` and are
   T06/T07's. A scene-storage key holding a probe, a draft or a seed would be a fourth persistence
   mechanism with no schema and no migration. Record it in `DECISIONS.md`.
2. **Plain `JSONEncoder`, no `CodableRepresentation` dance** (`A39`). This is the concrete payoff of
   `A32`'s typed array; `NavigationPath.CodableRepresentation` is `nil` the moment one pushed value
   is not `Codable`, and restoration then silently no-ops.
3. **Corrupt input restores empty, never throws.** A scene payload is versioned by nothing.

### `NavigationGraph` — the edges, with tap costs

The graph is a value. Its edge list is a `switch` over `Screen` so that a new case does not compile
until its edges are declared — the second half of §12.3's CI guard.

```swift
// Modules/Sources/HunchNavigation/NavigationGraph.swift
import HunchCore

public struct NavigationEdge: Hashable, Sendable {
    public let from: Screen
    public let to: Screen
    /// Taps the player spends on this edge. `0` for an automatic transition (launch → its
    /// destination); `2` for SIEVE's confirm-by-repeat abandon (§9.2).
    public let taps: Int
}

public struct NavigationGraph: Sendable {
    /// §12.3: the play key "resumes the suspended round if one exists, otherwise starts a new round
    /// in the last-played mode" — so the graph is a *function of* the last-played mode, and the
    /// depth test walks all four.
    public let lastPlayedMode: Mode
    public init(lastPlayedMode: Mode)

    public var edges: [NavigationEdge] { … }               // exhaustive switch over Screen
    public func destinations(from screen: Screen) -> [NavigationEdge]
    public func isReachable(_ screen: Screen) -> Bool
    /// Fewest taps from `screen` to ANY play surface. `0` when `screen` is one.
    public func distanceToPlay(_ screen: Screen) -> Int?
    /// Fewest taps from `screen` to the play surface of `mode` specifically.
    public func distanceToPlay(_ screen: Screen, mode: Mode) -> Int?
}
```

Both distance functions are a plain BFS over ≤ 18 nodes with small integer weights; write it as
Dijkstra-with-a-tiny-queue or as a repeated relaxation — at this size the simplest correct spelling
wins, and `05`'s concurrency has nothing to say about a pure function over eighteen values.

**The edge list, from §12.2's Entry and Exit columns.** Encode exactly these, one `case` per source
screen:

| From | To (taps) |
|---|---|
| `launchSurface` | `frame` (0) · `roundView` (0, when a suspended round exists) |
| `frame` | `roundView` (1, PROBE or DRIFT key) · `echoRoundView` (1) · `sieveRoundView` (1) · `codexRoot` (1) · `profile` (1) · `anomaly` (1) · `settings` (1) |
| `roundView` | `bench` (1, handle) · `frame` (1, chevron) · `inscription` (1, cap or second strike) |
| `echoRoundView` | `frame` (1, chevron) · `inscription` (1, Seal) |
| `sieveRoundView` | `sievePauseOverlay` (1, pause key) · `inscription` (1, stream exhausted or third foul) |
| `bench` | `assayInspector` (1) · `roundView` (1, pull-down) · `inscription` (1, Seal) |
| `assayInspector` | `bench` (1, dismiss) |
| `inscription` | `Screen.playSurface(for: lastPlayedMode)` (1, *again*) · `frame` (1) · `codexRoot` (1, minted-page key) |
| `codexRoot` | `codexShelf` (1) · `frame` (1, back) · play key (1) |
| `codexShelf` | `codexPage` (1) · `codexRoot` (1, back) · play key (1) |
| `codexPage` | `codexShelf` (1, back) · `codexPage` (1, swipe to the adjacent slot) · play key (1) |
| `anomaly` | `roundView` (1, tap today's cell — the Anomaly is a PROBE round) · `frame` (1, back) · play key (1) |
| `statistics` | `profile` (1, back) · play key (1) |
| `profile` | `statistics` (1) · `frame` (1, back) · play key (1) |
| `settings` | `about` (1) · `frame` (1, back) · play key (1) |
| `about` | `settings` (1, back) |
| `resetConfirmAlert` | `settings` (1, either button) |
| `sievePauseOverlay` | `sieveRoundView` (1, tap the gate) · `inscription` (2, chevron ×2) |

The play-key edge is `NavigationEdge(from: screen, to: Screen.playSurface(for: lastPlayedMode), taps: 1)`
and is emitted for exactly the screens where `carriesPlayKey` is true. Derive it — do not write it
into seven `case`s by hand, or the two facts can disagree.

`settings → resetConfirmAlert` is deliberately **not** an edge: an alert is a presentation, not a
destination, and §12.2 gives it "either button" as its only exit. It is reachable in the sense that
matters (T02 asserts reachability over the union of the graph and the presentations); adding it as a
navigation edge would put a modal in the back stack, which `A37` exists to prevent.

### Three spec conflicts this task must resolve, not paper over

1. **Where the Inscription's minted-page key lands.** §12.2 screen 9's Entry column says
   `CodexRootView`; §12.3's diagram draws `InscriptionView ──▶ CodexShelfView`; §13.7.3 says
   *"Reveal → Codex page | the beat-5 thumbnail is the shared element"*. **Ruling: encode §12.2's
   Entry column** — the screen inventory is the only exhaustive statement of entries and exits, and
   the other two are a schematic and a motion table. Record it in `DECISIONS.md`. The ≤ 2-tap rule
   holds under all three readings because every Codex screen carries a play key, so this ruling
   changes no gate; it changes which single edge is in the graph, and one home for that fact is the
   point.
2. **Profile → Statistics.** §12.3 says `NavigationStack` is used *twice* and, one clause later,
   that Profile → Statistics is "a push". **Ruling: two stacks, as stated.** Profile → Statistics is
   a full-surface transition with a `back` key in the leading slot — which is exactly what
   `hunch-chrome-and-meta/references/instrument-bar.md` §3 already prescribes for both screens
   (`StatisticsView`: leading `back`; `ProfileView`: leading `back`, trailing statistics-then-play).
   Two hand-drawn instrument bars are not a `NavigationStack`. Record it.
3. **Where `Router` lives.** `08 §1` puts `Router.swift` in `HunchAppFeature`, and `A33` says the
   router is owned by *the screen that hosts the stack*. Both hold if the two stack containers are
   in `HunchAppFeature`: `CodexStack` and `SettingsStack` are thin container views that own a
   `@State private var router = Router()`, place `navigationDestination(for: Route.self)` on the
   `NavigationStack` itself (`A35` — never inside the shelf's `LazyVGrid`), and switch to the
   feature views. `CodexFeature` and `MetaFeature` therefore never import `HunchAppFeature`, and the
   dependency arrow stays one-way. Record it.

### `Router` and the two stacks

```swift
// Modules/Sources/HunchAppFeature/Router.swift
import HunchNavigation

@MainActor @Observable
public final class Router {
    public var path: [Route] = []
    public init() {}
    public func push(_ route: Route) { path.append(route) }
    public func pop() { _ = path.popLast() }
    public func popToRoot() { path.removeAll() }
    public func replace(with routes: [Route]) { path = routes }
}
```

`public init()` written by hand — a `public` type's memberwise initialiser is internal, and this one
is constructed from `CodexStack` and `SettingsStack`.

**The router is not in `AppDependencies`.** `08 §6`: *"Routers are not in the graph."* Two instances,
each `@State private` in its container, each with its own history. A single app-wide router would
make "pop the Codex" and "pop Settings" the same operation.

```swift
// Modules/Sources/HunchAppFeature/CodexStack.swift
@MainActor
struct CodexStack: View {
    @State private var router = Router()
    @SceneStorage("hunch.nav.codex") private var stored: String = ""

    var body: some View {
        NavigationStack(path: $router.path) {
            CodexRootView(onOpenShelf: { router.push(.codexShelf($0)) })
                .navigationDestination(for: Route.self) { route in   // ← on the container (A35)
                    switch route {
                    case .codexShelf(let band):
                        CodexShelfView(band: band, onOpenPage: { router.push(.codexPage(lawKey: $0)) })
                    case .codexPage(let lawKey):
                        CodexPageView(lawKey: lawKey)
                    case .about:
                        // Unreachable by construction: NavigationStackID.codex does not accept it.
                        // Ship it as an EmptyView rather than a fatalError — a bad scene payload
                        // must not be able to kill a launch.
                        EmptyView()
                    }
                }
        }
        .onAppear { router.path = RoutePath.decodeOrEmpty(stored).filter(NavigationStackID.codex.accepts) }
        .onChange(of: router.path) { stored = (try? RoutePath.encode(router.path)) ?? "" }
    }
}
```

`SettingsStack` is the same shape with one destination. The `.filter(accepts:)` on restore is what
stops a payload written for one stack from being replayed into the other.

### What this task does **not** do

It does not draw the play key, does not decide what happens when it is tapped at runtime (that is
`AppLaunchRoute` + `Round`, E10·T01/T04), and does not add the graph *assertions* — those are T02.
The graph is a value with no callers yet, and that is correct: it is the thing the test walks.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter RouteTests` green, all ten tests.
- [ ] `grep -rn "import SwiftUI\|import UIKit\|import Observation" Modules/Sources/HunchNavigation/` returns nothing.
- [ ] `grep -rn "default:" Modules/Sources/HunchNavigation/` returns nothing — every switch over `Screen`, `Route` and `Mode` is exhaustive (`W29`).
- [ ] `grep -rn "NavigationPath" Modules/Sources/` returns nothing (`A32`).
- [ ] `grep -rn "router\|Router" Modules/Sources/HunchAppFeature/AppDependencies.swift` returns nothing (`08 §6`).
- [ ] `grep -rn "navigationDestination" Modules/Sources/` shows it only on a `NavigationStack`, never inside a `List`, `ForEach`, `LazyVGrid`, `LazyVStack` or `ScrollView` body (`A35`).
- [ ] `Modules/Package.swift` declares `HunchNavigation` with no `HunchUI` dependency and no `.defaultIsolation`, and `HunchNavigationTests` mirrors it.
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh --all` still passes (nothing moved into `HunchCore`).
- [ ] `DECISIONS.md` carries the three rulings: the Inscription → Codex edge, Profile → Statistics as a full-surface transition, and `Router`'s placement with the one-way dependency argument.
- [ ] `tests.json` carries the three entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T01: Route, Screen and NavigationGraph as SwiftUI-free values; one Router per stack"`

## Out of scope

- The depth assertions and the play-key CI guard — **T02**.
- `FrameView` and everything the Frame's edges lead to — **T03**.
- `SettingsView` and `AboutView`, the two screens the Settings stack contains — **T05**, **T06**.
- `AppDependencies`, `hunchEnvironment(_:)`, `AppLaunchRoute` and the first-frame decision — **E10·T01**.
- Restoring the *round* (`round.json`, the 900 ms re-entry beat) — **E10·T02/T03**. Scene storage carries navigation only.
- The six screen transitions and their durations — **E20·T08**, over `hunch-motion-and-feedback/references/transitions.md` §1.
