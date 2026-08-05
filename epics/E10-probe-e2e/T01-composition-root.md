# T01 — The composition root

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (inside this epic; the epic depends on E09) |
| **Delivers** | `PersistenceStore` (PERSISTENCE) — the injected, singleton-free seam finally wired to an app |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides which package each of `AppDependencies`, `Now`, `SeedSource`, `AppLaunchRoute` and the three `@Entry` values lives in — the boundary predicate is the whole question here, because `Now.live` calls `Date()` and `SeedSource.live` calls `SystemRandomNumberGenerator`, both of which are banned under `HunchCore/Sources/`. Also owns the composition-root rule (`04 A2`) and the `…Store` naming ruling. |
| `hunch-swift-concurrency` | `AppDependencies` is `@MainActor`, `PersistenceStore` is `Sendable` and `FilePersistenceStore` is one of the two sanctioned actors; `SeedSource` and `Now` are `Sendable` structs holding `@Sendable` closures, which is the only shape that survives strict concurrency without a global. This task must not add a third actor or a second escape hatch. |

`hunch-design-tokens` is **not** loaded: this task installs the `theme` environment value but resolves
nothing — `RenderEnv` resolution is E03·T03's and is read through E03·T06's `RenderEnvReader`.

## Objective

At the end of this task `App/HunchApp.swift` is five lines that name one factory, and every dependency
the app has — the store, the clock, the seed, the archive, the ladder, the cue player — is constructed
in exactly one function and travels down through one environment modifier that is re-applied at every
presented subtree. `AppLaunchRoute` decides the first frame from state alone: a live snapshot opens the
round, a fresh install opens the **opening round with the Frame skipped**, and only a returning player
with nothing suspended sees the Frame.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13 | the ten-file tree behind `PersistenceStore`, and that `Application Support/Hunch/` is the only directory |
| `GAME_DESIGN.md` | §12.4 (final decision) | first launch never shows the Frame — the Frame is revealed when round 1 ends |
| `GAME_DESIGN.md` | §12.3 (tap-distance audit) | "cold launch, suspended round → **0** taps — the app opens in the round"; cold launch with none → 1 tap |
| `GAME_DESIGN.md` | §6.10 (Relaunch) | a cold launch with a live snapshot opens directly into the round; no dialog, no "Resume?" button |
| `GAME_DESIGN.md` | §6.1 | "no wall-clock quantity affects score, marks or the Rasch update" — which is why there is a `Now` and no `Clock` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §6 (whole), §1, §2, §4 | the composition root verbatim, `SeedSource`, `Now`, the three `@Entry` values, the re-injection rule, and the file paths |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A2, A25, A26, A27, A28, A29, A33 | one root; presented subtrees start a new environment hierarchy; optional-form reads in `HunchUI`; `@Entry`; the installer belongs to the module that knows the graph; routers are not in the graph |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P8, P9, P24 | the app target holds `@main` and the *call* to the root, and imports exactly one feature module |
| `ios-swift-guide/05-CONCURRENCY.md` | R7, R8, R21 | default isolation per target, explicit `@MainActor` on anything visible outside its file, explicit `Sendable` |

Do not restate the directory name, the schema number or any duration here — cite and read.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchAppFeatureTests/AppDependenciesTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchAppFeature

@Suite("AppDependencies — the one composition root")
struct AppDependenciesTests {

    @Test("preview(seed:date:) is deterministic in both of its nondeterminism sources")
    @MainActor
    func previewIsDeterministic() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = AppDependencies.preview(seed: 0xC0FFEE, date: date)
        let b = AppDependencies.preview(seed: 0xC0FFEE, date: date)

        #expect(a.seeds.next() == 0xC0FFEE)
        #expect(a.seeds.next() == 0xC0FFEE)          // .fixed does not advance — it is a constant, not a stream
        #expect(b.seeds.next() == a.seeds.next())
        #expect(a.now.date() == date)
        #expect(b.now.date() == date)
    }

    @Test("preview composes the shipping in-memory store, never a file store and never a test double")
    @MainActor
    func previewUsesTheShippingInMemoryStore() {
        let dependencies = AppDependencies.preview()
        #expect(dependencies.store is InMemoryPersistenceStore)
    }

    @Test("the two seams are values, so substituting one is an assignment and not a subclass")
    func seamsAreValues() {
        #expect(SeedSource.fixed(7).next() == 7)
        #expect(Now.fixed(.distantPast).date() == .distantPast)
    }

    @Test("live() writes nowhere but Application Support/Hunch")
    @MainActor
    func liveStoreDirectory() throws {
        let dependencies = AppDependencies.live()
        let store = try #require(dependencies.store as? FilePersistenceStore)
        #expect(store.directory.lastPathComponent == "Hunch")
        #expect(store.directory.pathComponents.contains("Application Support"))
        #expect(!store.directory.pathComponents.contains("Documents"))
    }
}

@Suite("AppLaunchRoute — what the first frame is")
struct AppLaunchRouteTests {

    @Test("a fresh install opens the opening round; the Frame is withheld (§12.4)")
    func freshInstallSkipsTheFrame() {
        #expect(AppLaunchRoute.initial(suspended: nil, hasFinishedARound: false) == .round(.opening))
    }

    @Test("a live snapshot opens directly into the round — zero taps, no dialog (§12.3, §6.10)")
    func liveSnapshotResumesWithNoPrompt() {
        let snapshot = ProbeSnapshot.fixture(probes: [22, 30])
        #expect(AppLaunchRoute.initial(suspended: snapshot, hasFinishedARound: true)
                == .round(.resume(snapshot)))
    }

    @Test("a returning player with nothing suspended lands on the Frame")
    func returningPlayerSeesTheFrame() {
        #expect(AppLaunchRoute.initial(suspended: nil, hasFinishedARound: true) == .frame)
    }

    @Test("a snapshot on a device that has never finished a round still resumes — the round outranks onboarding")
    func snapshotOutranksOnboarding() {
        let snapshot = ProbeSnapshot.fixture(probes: [22])
        #expect(AppLaunchRoute.initial(suspended: snapshot, hasFinishedARound: false)
                == .round(.resume(snapshot)))
    }
}
```

and the fixture helper it needs, `Modules/Tests/HunchAppFeatureTests/ProbeSnapshotFixture.swift`:

```swift
import Foundation
import HunchCore

extension ProbeSnapshot {
    /// Modules-side tests cannot see `HunchTestSupport` — it is deliberately absent from
    /// `HunchCore`'s `products:` (`06 T5a`), so every app-side fixture is local.
    static func fixture(probes: [UInt8], strikes: Int = 0, draft: BenchLayout? = nil) -> ProbeSnapshot {
        let law = OpeningRound.law
        return ProbeSnapshot(schema: 1,
                             law: law,
                             lawHash: LawTable(law).extensionHash,
                             seed: OpeningRound.seed, band: .literal, targetDelta: 0.023, mode: .probe,
                             seedGlyph: OpeningRound.seedGlyphID,
                             probes: probes, strikes: strikes, counterexample: nil, benchDraft: draft,
                             startedAt: Date(timeIntervalSince1970: 1_700_000_000), elapsedActive: 0)
    }
}
```

> `OpeningRound` arrives in T05. Until then, hand the fixture a literal `LawNode` for
> `shape ∈ {triangle}` built directly and replace it with `OpeningRound.law` in T05's commit —
> do not leave two spellings of the opening law in the repo.

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter AppDependenciesTests`

It must fail on **missing symbols** — `AppDependencies`, `SeedSource`, `Now`, `AppLaunchRoute` — not on a
compile error inside the test. If the whole target fails to build because `Modules/Tests/HunchAppFeatureTests`
is not in the manifest, add the test target first; that is setup, not the test passing.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchAppFeature/AppDependencies.swift` |
| create | `Modules/Sources/HunchAppFeature/Now.swift` |
| create | `Modules/Sources/HunchAppFeature/SeedSource.swift` |
| create | `Modules/Sources/HunchAppFeature/AppLaunchRoute.swift` |
| create | `Modules/Sources/HunchUI/HunchEnvironmentValues.swift` |
| create | `Modules/Sources/HunchUI/StoreHealth.swift` |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — switch on `AppLaunchRoute` |
| modify | `App/HunchApp.swift` — `@State private var dependencies = AppDependencies.live()` and one `.hunchEnvironment(dependencies)` |
| modify | `Modules/Package.swift` — add the `HunchAppFeatureTests` test target |
| modify | `Scripts/check-source-hygiene.sh` — add checks 11 and 12 |
| modify | `Modules/Sources/LoomFeature/Round.swift` — accept `now:` as an injected closure (see notes) |
| create | `Modules/Tests/HunchAppFeatureTests/AppDependenciesTests.swift` |
| create | `Modules/Tests/HunchAppFeatureTests/ProbeSnapshotFixture.swift` |
| modify | `DECISIONS.md` — two entries (see notes) |

## Implementation notes

### The root itself

`08 §6` is normative and is reproduced in the guide; write it as it stands, with `Ladder` and `Codex`
elided until E11 and E15 create them (`01 P12` — a field for a type that does not exist yet is not
"planned", it is a compile error waiting).

```swift
// Modules/Sources/HunchAppFeature/AppDependencies.swift
@MainActor
public struct AppDependencies {
    public let store: any PersistenceStore
    public let now: Now
    public let seeds: SeedSource
    public let cues: any CuePlayer          // SilentCuePlayer until E20 ships the real two

    public static func live() -> AppDependencies { … }
    public static func preview(seed: UInt64 = 0xC0FFEE, date: Date = .distantPast) -> AppDependencies { … }
}

extension View {
    /// `04 A28` — the module that knows what the graph contains is the module that installs it.
    public func hunchEnvironment(_ dependencies: AppDependencies) -> some View { … }
}
```

`P24` governs *top-level types*; the `View` extension exists only to install the struct declared above
it and stays in the same file, as `08 §6` shows it.

### `Now` and `SeedSource`: where they live, and the one shape that works

`08 §6` places both in `Modules/`, and the hygiene grep (check 6) is what makes that binding: `Date()`
and `SystemRandomNumberGenerator` are banned under `HunchCore/Sources/`.

That creates one real problem worth writing down rather than working around: **`LoomFeature` cannot
import `HunchAppFeature`** (the arrow runs the other way — `HunchAppFeature` composes the features),
and `Round` genuinely needs a clock for `startedAt` and `elapsedActive` (§6.10's snapshot fields).

Resolution, and it is the decision to record:

- `Now` and `SeedSource` stay in `HunchAppFeature` as the guide places them, each a `Sendable` struct
  of exactly one `@Sendable` closure.
- **`Round` takes the capability, not the record**: `init(…, now: @escaping @Sendable () -> Date)`.
  A one-field struct's whole value *is* its closure, so nothing is lost, `LoomFeature` gains no
  dependency, and the composition root passes `dependencies.now.date`.
- Nothing else in `Modules/` reads a clock. If a second consumer appears, move `Now` down into the
  lowest target both consumers already import — never up into `HunchCore`, which would put `Date()`
  back inside the grep.

Record in `DECISIONS.md`: *"`Now` and `SeedSource` live in `HunchAppFeature` per `08 §6`; `LoomFeature`
receives the clock as `@Sendable () -> Date` because it cannot import the composition root."*

### The two `@Entry` values that are not the theme

```swift
// Modules/Sources/HunchUI/HunchEnvironmentValues.swift
extension EnvironmentValues {
    @Entry public var glyphScale: CGFloat = 1.0          // Dynamic Type art scale, capped at 1.35 by E19·T06
    @Entry public var theme: RenderEnv.Theme = .dark      // the *resolved* theme, not the Settings row
    @Entry public var storeHealth: StoreHealth = .healthy // §11.13's disk-full hairline
}
```

- They live in `HunchUI` because `HunchUI` **reads** them and cannot import `HunchAppFeature`.
- `theme` carries the already-resolved theme (the Settings choice resolved against
  `isDarkerSystemColorsEnabled`, §12.6). Resolution is E17·T06's; `RenderEnv` composition from it is
  E03·T03's. This task only threads the value.
- `HunchUI` reads all three in the **optional/defaulted** form (`04 A26`), because those components are
  used from previews that install nothing.
- `StoreHealth` is a two-case `Sendable` enum (`healthy`, `writesFailing`), set by `AppDependencies`
  when a store write throws. It drives §6.11 #22's hairline strip in the **chrome** and never the play
  surface; drawing it is E17·T03's.

### Re-injection, and the check that makes it mechanical

`AssayInspectorView`, `ResetConfirmAlert` and `SievePauseOverlay` are presented subtrees; each starts a
new environment hierarchy (`04 A25`). Every one of them re-applies `.hunchEnvironment(dependencies)`.
Because "remember to re-inject" is exactly the rule reviews forget, append **check 11** to
`Scripts/check-source-hygiene.sh`:

```bash
# 11. Every presented subtree re-injects the dependency graph (04 A25).
#     Owner: hunch-swift-code. A .sheet/.fullScreenCover/.alert/.popover in Modules/Sources must be
#     followed by .hunchEnvironment( within 12 lines.
```

Implement it with `grep -n` for the four presenters over `Modules/Sources`, then `sed -n "N,N+12p"`
on each hit and fail if `hunchEnvironment(` is absent. Prove it works: plant a `.sheet` without the
modifier, run the script, watch it fail, revert.

And **check 12**, which is check 6 pointed at `Modules/`:

```bash
# 12. The app becomes nondeterministic in exactly two files.
#     Owner: hunch-swift-code. `Date()` may appear only in Modules/Sources/HunchAppFeature/Now.swift;
#     `SystemRandomNumberGenerator` only in Modules/Sources/HunchAppFeature/SeedSource.swift.
```

### `AppLaunchRoute`

Pure, `Equatable`, no SwiftUI, and therefore host-testable:

```swift
public enum AppLaunchRoute: Equatable, Sendable {
    case round(RoundEntry)
    case frame

    public enum RoundEntry: Equatable, Sendable {
        case opening                       // fresh install — §12.4: the Frame is withheld
        case resume(ProbeSnapshot)         // §6.10: directly into the round, no dialog
    }

    public static func initial(suspended: ProbeSnapshot?, hasFinishedARound: Bool) -> AppLaunchRoute
}
```

Order of the three arms matters and is asserted: a snapshot outranks onboarding, because a player who
was mid-round when the app died has already met the machine.

`AppView` switches over it exhaustively, with **no `default:`** (`03 W29`) — adding a fourth launch
state must be a compile error.

### Tags, and why Modules-side tests do not have them

The `@Tag` vocabulary lives in `HunchTestSupport`, which is deliberately absent from `HunchCore`'s
`products:` (`06 T5a`), so no `Modules` test target can see it. Two same-named tags declared in two
targets are two different tags, and a test plan selecting by name would silently split.

So: **`HunchCore` tests are selected by tag; `Modules` tests are selected by target** in the three
`.xctestplan` files. Record it in `DECISIONS.md` and do not scatter `.tags(...)` through `Modules`.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter AppDependenciesTests` and `--filter AppLaunchRouteTests` are green.
- [ ] `App/HunchApp.swift` is ≤ 12 lines, imports exactly `HunchAppFeature` and `SwiftUI` (`01 P9`), and contains the string `AppDependencies.live()` exactly once.
- [ ] `grep -rn "AppDependencies(" Modules/Sources App | grep -v AppDependencies.swift` returns nothing — the struct is constructed in one file.
- [ ] `grep -rn "Date()" Modules/Sources App` returns exactly one file: `Modules/Sources/HunchAppFeature/Now.swift`.
- [ ] `grep -rn "SystemRandomNumberGenerator" Modules/Sources App` returns exactly one file: `Modules/Sources/HunchAppFeature/SeedSource.swift`.
- [ ] `Scripts/check-source-hygiene.sh` exits 0, and checks 11 and 12 have each been demonstrated to exit non-zero on a planted violation that was then reverted.
- [ ] `grep -rn "static let shared\|static var shared" HunchCore/Sources Modules/Sources App` returns nothing.
- [ ] `grep -c "actor " HunchCore/Sources/**/*.swift Modules/Sources/**/*.swift` still names exactly the two sanctioned actors.
- [ ] `DECISIONS.md` has the `Now`/`SeedSource`-placement entry and the tags-by-target entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T01: composition root, SeedSource, Now, launch route and the two new hygiene checks"`

## Out of scope

- The `Router`, `Route` and the navigation graph — **E17·T01**. `AppDependencies` holds no router (`04 A33`).
- Drawing the disk-full hairline strip — **E17·T03**; this task only carries `StoreHealth` in the environment.
- Resolving `theme` from the Settings row and from `isDarkerSystemColorsEnabled` — **E17·T06**.
- The real `CuePlayer` implementations — **E20·T01/T02/T05**; `SilentCuePlayer` is what `live()` composes until then.
- `Ladder` and `Codex` as fields on `AppDependencies` — **E11·T01** and **E15·T01** add them when the types exist.
- Snapshot loading at launch (who reads `round-probe.json` and when) — **T02**; this task only types the route that consumes the result.
