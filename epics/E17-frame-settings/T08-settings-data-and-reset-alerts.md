# T08 — Settings: DATA and the reset alerts

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | DATA · Reset confirm alerts · Reset map (the UI half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-chrome-and-meta` | `references/stock-controls.md` §6 is the five alerts: the exact `.alert` spelling with **one** `.cancel` and **one** `.destructive` and no `.defaultAction`, the ruling that the bodies differ because the consequences differ, and the rule that every destructive action in the app lives in Settings → DATA so the reset set can be enumerated, alerted and tested once. `ResetConfirmAlert` is also one of the app's three presented subtrees and must re-inject the environment. |
| `hunch-swift-testing` | This task's whole risk is a reset doing more or less than its row says. The skill owns the fixture discipline that makes that checkable — `resources: [.copy("Fixtures")]` with `subdirectory:` on every lookup, a `TestScoping` trait copying the v1 tree to a fresh temp directory per test, and the rule that a decoding fixture never ships without a malformed sibling. It also owns "never restate a value that lives in Swift", which is why this suite reads `ResetAction.allCases` rather than listing five names. |

## Objective

At the end of this task Settings' DATA section exists: five destructive rows, each opening its own
alert variant with its own body and a focused cancel, each dispatching exactly one `ResetAction` from
§11.13's map. None of the five can reach `anomaly.json` or `anomaly.hw`. Clearing the Codex re-locks
ECHO and SIEVE at §9.10's page gates and leaves the palette ceiling untouched; only resetting the
ladder drops the ceiling to its band-2 opening state.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | **§11.13** | the reset map — five actions, one row each, with the exact effect on the tree; and the migration-fixture sentence that the same fixture carries the reset assertions |
| `GAME_DESIGN.md` | §12.6 | the five DATA rows as the player meets them, including the two consequence clauses: *"Clear Codex … Re-locks ECHO and SIEVE at §9.10's page gates. **Does not touch the palette ceiling**"* and *"Reset the ladder … including `maxBandEverServed`, so **the palette drops to its band-2 opening state**"* |
| `GAME_DESIGN.md` | §12.6 | *"No reset of any kind touches `anomaly.json` or its `anomaly.hw` sidecar … That is not a courtesy to the ledger, it is the whole anti-cheat"* |
| `GAME_DESIGN.md` | §11.7 | the reset-immunity paragraph and why a reset that cleared `highWaterDay` would *be* the exploit |
| `GAME_DESIGN.md` | §12.2 screen 17 | `ResetConfirmAlert`: title, body, destructive verb, shared cancel; five variants; **cancel is the primary action and takes default focus** |
| `GAME_DESIGN.md` | §12.9 | 16 keys — 5 × (title + body + verb) plus one shared cancel |
| `GAME_DESIGN.md` | §4.4, §10.4 | what the palette ceiling is (`maxBandEverServed + 1`), so "leaves it alone" and "drops it to band 2" are checkable claims |
| `GAME_DESIGN.md` | §9.10 | the three gates the Codex reset re-evaluates — read through `ModeUnlock` (T04), never re-stated |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A25, A37 | re-inject into every presented subtree; present with the `item:` form, never `isPresented` plus a parallel payload |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3, §5 | `StoreFile` as an enum so the reset map is an exhaustive switch; the fixture-tree discipline |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/MetaFeatureTests/ResetActionWiringTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("The five DATA rows and their alerts — §12.6, §11.13", .tags(.unit, .presubmission))
struct ResetActionWiringTests {

    @Test("there are exactly five DATA rows, one per ResetAction, in §12.6's order")
    func fiveRows() {
        #expect(DataSection.rows.count == ResetAction.allCases.count)
        #expect(DataSection.rows.map(\.action) == ResetAction.allCases)
    }

    @Test("each row opens exactly one alert variant and dispatches exactly one action",
          arguments: ResetAction.allCases)
    func oneRowOneVariantOneAction(_ action: ResetAction) {
        let row = DataSection.row(for: action)
        #expect(row.variant.action == action)
        #expect(row.isDestructive)
    }

    @Test("the five bodies are pairwise distinct — a generic 'Are you sure?' erases the distinction")
    func bodiesAreDistinct() {
        let bodies = ResetAction.allCases.map { ResetAlertVariant($0).bodyKey }
        #expect(Set(bodies).count == 5)
        let titles = ResetAction.allCases.map { ResetAlertVariant($0).titleKey }
        #expect(Set(titles).count == 5)
        let verbs = ResetAction.allCases.map { ResetAlertVariant($0).verbKey }
        #expect(Set(verbs).count == 5)
    }

    @Test("every variant declares exactly one cancel and one destructive, and cancel is primary",
          arguments: ResetAction.allCases)
    func alertButtonRoles(_ action: ResetAction) {
        let variant = ResetAlertVariant(action)
        #expect(variant.buttons.filter { $0.role == .cancel }.count == 1)
        #expect(variant.buttons.filter { $0.role == .destructive }.count == 1)
        #expect(variant.buttons.count == 2)
        #expect(variant.primaryButtonRole == .cancel)
        #expect(!variant.buttons.contains { $0.isDefaultAction })   // never on the destructive button
    }

    @Test("the shared cancel is shared — one key across all five")
    func cancelIsShared() {
        let cancels = ResetAction.allCases.map { ResetAlertVariant($0).cancelKey }
        #expect(Set(cancels).count == 1)
    }

    @Test("§12.9's budget: 5 × (title + body + verb) + 1 shared cancel = 16 keys")
    func sixteenKeys() {
        let keys = ResetAction.allCases.flatMap { a -> [String] in
            let v = ResetAlertVariant(a); return [v.titleKey, v.bodyKey, v.verbKey]
        } + [ResetAlertVariant(.everything).cancelKey]
        #expect(Set(keys).count == 16)
    }

    // MARK: - The anti-cheat, asserted at the UI layer as well as on disk

    @Test("no variant's action can reach the Anomaly ledger", arguments: ResetAction.allCases)
    func noVariantTouchesTheAnomaly(_ action: ResetAction) {
        #expect(!action.filesRemoved.contains(.anomaly))
        #expect(!action.filesRewritten.contains(.anomaly))
    }

    @Test("Reset everything clears settings except languageTag and theme")
    func resetEverythingKeepsTwoPreferences() {
        let cleared = ResetAction.everything.preferenceKeysCleared
        #expect(!cleared.contains(.languageTag))
        #expect(!cleared.contains(.theme))
        #expect(Set(cleared) == Set(Preference.Key.allCases).subtracting([.languageTag, .theme]))
    }

    @Test("no other action clears any preference", arguments: ResetAction.allCases.filter { $0 != .everything })
    func onlyResetEverythingTouchesPreferences(_ action: ResetAction) {
        #expect(action.preferenceKeysCleared.isEmpty)
    }
}
```

And `Modules/Tests/MetaFeatureTests/ResetConsequenceTests.swift` — the two downstream clauses:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("The two reset consequences §12.6 states and §11.13 does not — §12.6, §9.10, §4.4",
       .tags(.unit, .presubmission))
struct ResetConsequenceTests {

    @MainActor
    private func fullyUnlocked() async throws -> AppDependencies {
        let d = AppDependencies.preview()
        try await d.seedArchive(pages: 12, highestBand: .systemic)   // ≥ 8 pages, a band-8 page
        try await d.seedServingState(maxBandEverServed: .composite)  // a raised palette ceiling
        return d
    }

    @Test("Clear Codex re-locks ECHO and SIEVE, and re-locks DRIFT with the band evidence gone")
    @MainActor
    func clearCodexRelocks() async throws {
        let d = try await fullyUnlocked()
        #expect(await d.modeUnlocks() == Set(Mode.allCases))
        try await d.perform(.clearCodex)
        #expect(await d.modeUnlocks() == [.probe])
    }

    @Test("Clear Codex leaves the palette ceiling exactly where it was — §12.6, §11.12")
    @MainActor
    func clearCodexLeavesTheCeiling() async throws {
        let d = try await fullyUnlocked()
        let before = await d.paletteCeiling()
        try await d.perform(.clearCodex)
        #expect(await d.paletteCeiling() == before)
    }

    @Test("Reset the ladder drops the palette to its band-2 opening state and KEEPS the Codex")
    @MainActor
    func resetLadderDropsTheCeilingAndKeepsTheCodex() async throws {
        let d = try await fullyUnlocked()
        try await d.perform(.ladder)
        #expect(await d.paletteCeiling() == PaletteCeiling.openingState)
        #expect(await d.modeUnlocks() == Set(Mode.allCases))   // the archive is untouched
    }

    @Test("Clear statistics and Reset Profile move neither the ceiling nor the gates",
          arguments: [ResetAction.statistics, .profile])
    @MainActor
    func theTwoInertResets(_ action: ResetAction) async throws {
        let d = try await fullyUnlocked()
        let ceiling = await d.paletteCeiling()
        let unlocks = await d.modeUnlocks()
        try await d.perform(action)
        #expect(await d.paletteCeiling() == ceiling)
        #expect(await d.modeUnlocks() == unlocks)
    }

    @Test("Reset everything re-arms onboarding from beat 0")
    @MainActor
    func resetEverythingRearmsOnboarding() async throws {
        let d = try await fullyUnlocked()
        try await d.perform(.everything)
        #expect(try await AppLaunchRoute.resolve(using: d) == .openingRound)
    }

    @Test("the Anomaly ledger is byte-identical after every one of the five", arguments: ResetAction.allCases)
    @MainActor
    func anomalySurvivesEveryReset(_ action: ResetAction) async throws {
        let d = try await fullyUnlocked()
        let before = try await d.store.rawBytes(of: .anomaly)
        try await d.perform(action)
        #expect(try await d.store.rawBytes(of: .anomaly) == before)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path Modules --filter "ResetActionWiringTests|ResetConsequenceTests"`

Failures must be missing symbols — `DataSection`, `ResetAlertVariant`, `PaletteCeiling.openingState`
— or a consequence that is wrong. `clearCodexLeavesTheCeiling` failing means the implementation
folded the two consequences together, which is the exact defect §12.6 spells out; fix the
implementation, never the test.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/MetaFeature/SettingsSection+Data.swift` |
| create | `Modules/Sources/MetaFeature/ResetConfirmAlert.swift` |
| create | `Modules/Sources/MetaFeature/ResetAlertVariant.swift` |
| modify | `HunchCore/Sources/Persistence/` — extend E07·T06's reset map with `preferenceKeysCleared` **only if** it does not already carry it; the file sets themselves are untouched |
| modify | `Modules/Sources/MetaFeature/SettingsView.swift` — mount the DATA section and the alert |
| modify | `Modules/Sources/HunchAppFeature/ScreenCatalogue.swift` — replace T05's stubs for screens 15 and 17 |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — 1 section header, 5 row labels, 16 alert keys, English only |
| create | `Modules/Tests/MetaFeatureTests/ResetActionWiringTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/ResetConsequenceTests.swift` |
| modify | `tests.json` — five entries: one-row-one-action, distinct bodies, the anti-cheat at the UI layer, the two consequences, and the preference-clearing scope |

## Implementation notes

### Read E07·T06 before writing anything

The reset map already ships. Find its real names before typing a second one:

```bash
grep -rn "enum Reset\|case clearCodex\|filesRemoved\|filesRewritten" HunchCore/Sources/Persistence/
grep -rn "ResetMapTests\|reset" HunchCore/Tests/PersistenceTests/ | head
```

E07·T06's suite already asserts, against a copy of the `Fixtures/v1/` tree, that each of the five
actions leaves exactly the specified file set with `anomaly.json` and `anomaly.hw` byte-identical.
**Do not re-implement or re-assert the file sets.** This task adds three things that live above them:

1. the **rows and the alerts** the player meets;
2. `preferenceKeysCleared`, because §12.6's fifth row also clears `hunch.settings.*` except
   `languageTag` and `theme`, and §11.13's table does not carry preferences;
3. the two **downstream consequences** — gates and ceiling — which are properties of *other systems
   reading the changed files*, not of the files themselves.

If `preferenceKeysCleared` already exists on E07's type, extend nothing.

### The two consequences, and why they are not special cases

§12.6 states them as if they were extra behaviour of two rows. They are not, and implementing them
as extra behaviour is how they drift:

- **Clear Codex re-locks ECHO and SIEVE.** `ModeUnlock` (T04) is a pure function of
  `ArchiveEvidence`, and `ArchiveEvidence` comes from `codex-index.json`. Emptying the index makes
  the function answer `[.probe]`. There is **no re-lock code**. If you find yourself writing
  `unlock.remove(.echo)`, stop: the gate has grown a cache or a latch, T04's
  `gatesAreMonotoneInEvidence` is about to become a lie, and this task has just acquired a second
  code path for a fact that had one.
  It also re-locks **DRIFT**, which §12.6 does not say and §9.10 implies — a band-≥ 3 page is
  archive evidence too, and it is gone. `clearCodexRelocks` asserts all three, and the reason it is
  correct rather than an over-reach is that §12.4's decision is *modes unlock on archive evidence*,
  full stop.
- **Clear Codex does not touch the palette ceiling; Reset the ladder drops it.** The ceiling is
  `maxBandEverServed + 1` and `maxBandEverServed` lives in `ServingState` inside `ladder.json`
  (§4.4, §10.4, §11.13). So "does not touch" is automatic — `codex-*.json` and `ladder.json` are
  different files — and "drops to its band-2 opening state" is automatic too, because §11.13's row
  already zeroes `ServingState` including `maxBandEverServed`. Both are then **assertions over
  behaviour that falls out of the file sets**, which is exactly what makes them cheap and exactly
  why they must be asserted: the next person to "optimise" the Codex reset by also clearing the
  ladder would break a stated promise with no test in the way.

Write both reasons into the code as comments citing §12.6 and §11.12. They are the two sentences a
reviewer will otherwise assume are the same sentence.

### `ResetAlertVariant` — five variants, sixteen keys, one cancel

```swift
// Modules/Sources/MetaFeature/ResetAlertVariant.swift
struct ResetAlertVariant: Identifiable, Sendable {
    enum ButtonRole: Sendable { case cancel, destructive }
    struct Button: Sendable { let role: ButtonRole; let isDefaultAction: Bool }

    let action: ResetAction
    var id: ResetAction { action }

    var titleKey: String { "settings.reset.\(action.slug).title" }
    var bodyKey: String  { "settings.reset.\(action.slug).body" }
    var verbKey: String  { "settings.reset.\(action.slug).verb" }
    var cancelKey: String { "settings.reset.cancel" }        // shared — §12.9's sixteenth key

    var buttons: [Button] { [.init(role: .destructive, isDefaultAction: false),
                             .init(role: .cancel, isDefaultAction: false)] }
    var primaryButtonRole: ButtonRole { .cancel }            // §12.2 screen 17
}
```

The presentation is the `item:` form (`A37`) — one `@State private var confirming: ResetAlertVariant?`
and never an `isPresented` `Bool` beside a payload, which is where every "alert shows with stale
data" bug comes from:

```swift
.alert(item: $confirming) { variant in
    Text(verbatim: Loc.string(variant.titleKey))
} actions: { variant in
    Button(role: .destructive) { perform(variant.action) } label: { Text(verbatim: Loc.string(variant.verbKey)) }
    Button(role: .cancel) { } label: { Text(verbatim: Loc.cancel) }
} message: { variant in
    Text(verbatim: Loc.string(variant.bodyKey))
}
```

**Declare exactly one `.cancel` and one `.destructive` and let the system order and emphasise them.**
The `.cancel` role is what delivers §12.2's "cancel (default focus)". Do **not** add `.defaultAction`
to the destructive button — that is the one line that would turn a guarded action into a one-tap
mistake, and `alertButtonRoles` asserts its absence.

Every string is already resolved by `Loc`, so every call site is `Text(verbatim:)` — the localizing
overload would treat a resolved `String` as a key and look it up a second time against
`Bundle.main`, which fails silently and renders the key.

**Re-inject the environment.** `ResetConfirmAlert` is one of the app's three presented subtrees,
alongside `AssayInspectorView` and `SievePauseOverlay` (`04 A25`, `08 §6`). A presented subtree starts
a fresh environment hierarchy, and an alert rendered without `RenderEnv` is the dark theme inside a
light-theme app.

### The five bodies differ because the consequences differ

This is the sentence `stock-controls.md` §6 makes a rule and §12.9 budgets sixteen keys for. Write
them so a player can tell the five apart without reading the title twice:

| Action | What its body must make clear |
|---|---|
| Clear statistics | the counters go to zero and **nothing else moves** |
| Clear Codex | the pages go; the modes that the pages unlocked go with them; **your difficulty does not change** |
| Reset Profile | the portrait re-forms unformed |
| Reset the ladder | the game starts judging you from scratch — calibration re-runs, the palette returns to its opening state — and **the Codex is kept** |
| Reset everything | everything except the daily record |

Each ≤ 22 characters is the *label* budget, not the body budget; bodies are sentences and are still
budgeted at +40 % for German, Russian and Turkish, still wrap rather than truncate, and are still
re-read against §1.13's approved framings — including the ban on implying a cognitive benefit, which
a body saying "start training again from scratch" would breach.

**No exclamation marks**, in any of the sixteen (§12.9's banned-lexeme test, E18·T08, fails the build
on one).

### Nothing destructive exists outside this section

`stock-controls.md` §6: *"Every destructive action in the app lives in Settings → DATA (§11.12), so
the reset set can be enumerated, alerted and tested once. `StatisticsView` is read-only; the Codex
has no delete; a page cannot be discarded."*

The one apparent exception is the mode key's trailing-swipe discard (T04), and it is not one: it
discards a *suspended round*, which §6.10 already defines as costing nothing but a re-roll, and it is
covered by §12.4's own gesture ruling rather than by an alert. Do not add an alert to it, and do not
move it into DATA.

Add the check to the acceptance criteria:

```bash
grep -rn "role: \.destructive" Modules/Sources | grep -v ResetConfirmAlert.swift   # must be empty
```

### The anti-cheat, asserted twice on purpose

E07·T06 asserts on disk that `anomaly.json` and `anomaly.hw` are byte-identical after all five.
`anomalySurvivesEveryReset` here asserts it again through the *UI's* dispatch path. That is not
duplication: the first proves the map is right, the second proves the rows are wired to the map and
that no row grew a side effect on its way to the screen. §11.7 is explicit that a reset which cleared
`highWaterDay` would *be* the exploit, so the two assertions guard the two different ways it could
happen.

`noVariantTouchesTheAnomaly` is the cheapest of the three — a pure property over
`ResetAction.allCases` with no store at all — and it is the one that will catch a sixth action added
carelessly, because `StoreFile` is an enum and the map is an exhaustive switch (`08 §3`): a new file
is a compile error in the reset map, and a new *action* is a failure here.

### `AppDependencies` test helpers

`seedArchive(pages:highestBand:)`, `seedServingState(maxBandEverServed:)`, `modeUnlocks()`,
`paletteCeiling()` and `perform(_:)` are test-facing helpers over the preview dependencies. Put them
in `ModulesTestSupport`, not in the shipping type — `AppDependencies` is the composition root and
must not grow a seeding API. They compose `InMemoryPersistenceStore`, which ships and imports no
`Testing` (`08 §6`), so nothing here reaches the release binary.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter "ResetActionWiringTests|ResetConsequenceTests"` green, all fifteen tests.
- [ ] `swift test --package-path HunchCore --filter ResetMapTests` still green and **unchanged** — this task edits no assertion E07·T06 made.
- [ ] `grep -rn "role: \.destructive" Modules/Sources | grep -v ResetConfirmAlert.swift` returns nothing.
- [ ] `grep -rn "unlock.*remove\|relock\|reLock" Modules/Sources HunchCore/Sources` returns nothing — the gate is a function, not an action.
- [ ] `grep -rn "isPresented" Modules/Sources/MetaFeature/ResetConfirmAlert.swift` returns nothing; the presentation is `item:`.
- [ ] `grep -rn "defaultAction" Modules/Sources/MetaFeature/` returns nothing.
- [ ] `grep -rn "hunchEnvironment\|renderEnv" Modules/Sources/MetaFeature/ResetConfirmAlert.swift` shows the re-injection (`A25`).
- [ ] `grep -c "settings.reset." Modules/Sources/HunchUI/Resources/Localizable.xcstrings` accounts for 16 keys and no more.
- [ ] `grep -n "!" Modules/Sources/HunchUI/Resources/Localizable.xcstrings` finds no exclamation mark in any of the sixteen.
- [ ] Simulator walk recorded in the commit message, on a disposable container: each of the five rows tapped, its alert read, cancel confirmed as the focused default, then each performed and the resulting file tree dumped with `xcrun simctl get_app_container` — with `anomaly.json`'s SHA-256 printed before and after all five and shown identical.
- [ ] `tests.json` carries the five entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T08: Settings DATA, five alert variants, and the two reset consequences asserted"`

## Out of scope

- The reset map itself, its file sets and the on-disk byte-identity assertion — **E07·T06**.
- `AnomalyLedger`, `highWaterDay` and the `.clockBehind` lock — **E16·T02**.
- The palette ceiling's *rule* (`maxBandEverServed + 1`, raised at serve time) — **E09·T04**, **E11·T05**.
- `ModeUnlock` and the three gates — **T04**. This task changes the evidence, not the function.
- Cold-start calibration re-running after a ladder reset — **E11·T05**.
- The eleven other languages for the 22 strings this task adds — **E18·T03**.
- Any destructive action anywhere else in the app: there are none, and check the grep says so.
