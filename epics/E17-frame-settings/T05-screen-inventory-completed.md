# T05 — The screen inventory completed

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | 18 screens · ABOUT |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-chrome-and-meta` | `AboutView` is one of exactly four screens in the app permitted a stock component, and `references/stock-controls.md` owns all four — the container neutralisation that stops `Form` painting `systemGroupedBackground` and system blue, the row/separator/header shapes, and the ruling that `AboutView` is screen 16 and therefore carries **no** play key. Its "Wrong" list is also where "a fifth screen with a `Form`" and "a settings row for anything §12.6 lists as deliberately absent" are already written down. |
| `hunch-build-and-ci` | `LaunchScreen.storyboard` is a build artefact, not Swift: it is wired by `INFOPLIST_KEY_UILaunchStoryboardName` in `Config/Base.xcconfig` (the only home for a build setting) and the launch colour is the one thing besides `AppIcon` allowed in `Assets.xcassets`. This skill also owns `Scripts/check-source-hygiene.sh` and its numbered gate roster, which is where this task's deliberate-absence lint becomes check 11. |

## Objective

At the end of this task all eighteen screens of §12.2 exist: `LaunchSurface` as a storyboard that
covers the cold-start hitch in ≤ 400 ms and `AboutView` as the last of the six stock rows land here,
and every other screen is already shipped by an earlier epic. A closed-inventory test walks
`Screen.allCases` and proves each one is presentable; a source lint keeps the eleven deliberately
absent screen kinds absent.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.2 | the eighteen rows; screen 1 (`LaunchSurface`: wordmark HUNCH, one brass hairline, dark ground, **storyboard, no code**, auto-exit ≤ 400 ms, primary action none); screen 16 (`AboutView`: version, build, "no data is collected", copyright, storage-status indicator); **and the paragraph after the table**, which is the complete list of eleven things that are deliberately not screens |
| `GAME_DESIGN.md` | §12.2 | *"Every one is portrait-only, dark-first, and none of the play surfaces render a single character"* |
| `GAME_DESIGN.md` | §12.3 | screens 16, 17 and 18 carry no play key |
| `GAME_DESIGN.md` | §12.9 | `AboutView` is 6 keys, including the no-data-collected statement and the storage-status line |
| `GAME_DESIGN.md` | §11.13 | the storage-status indicator's source — the disk-full hairline, surfaced as the `storeHealth` `@Entry` value |
| `GAME_DESIGN.md` | §11.5, §12.6 | why there is no export row, no `Documents/` presence and no share sheet — the same reasons the lint enforces |
| `GAME_DESIGN.md` | §1.13, §13.12 item 13 | nothing in the UI claims or implies a cognitive, memory, focus, intelligence or health benefit — re-read every string in `AboutView` against this before shipping it |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B5, B6, B34a, B36, B37 | every build setting in `Config/*.xcconfig`; `project.pbxproj` carries none; the hygiene script's numbered checks; `PrivacyInfo.xcprivacy`; `ITSAppUsesNonExemptEncryption` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 | `App/` is a buildable folder of five files, forever; `Assets.xcassets` holds `AppIcon` + launch colour **only** |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/MetaFeatureTests/ScreenInventoryTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import HunchNavigation
import ModulesTestSupport
@testable import HunchAppFeature

@Suite("§12.2's inventory is complete and closed", .tags(.unit, .presubmission))
struct ScreenInventoryTests {

    @Test("every one of the eighteen screens has a presentable destination")
    @MainActor
    func everyScreenIsPresentable() throws {
        let dependencies = AppDependencies.preview()
        for screen in Screen.allCases {
            // `ScreenCatalogue` is a switch with no `default:` returning an `AnyView` factory,
            // so an unimplemented screen is a compile error and an unreachable one is this failure.
            let destination = ScreenCatalogue.destination(for: screen, using: dependencies)
            #expect(destination != nil, "\(screen) has no destination")
        }
    }

    @Test("the launch surface is a storyboard and has no Swift destination")
    func launchSurfaceIsNotCode() {
        #expect(ScreenCatalogue.isStoryboardBacked(.launchSurface))
        #expect(Screen.allCases.filter(ScreenCatalogue.isStoryboardBacked) == [.launchSurface])
    }

    @Test("AboutView is screen 16, carries no play key, and exits only to Settings")
    func aboutIsTerminal() {
        #expect(Screen.about.rawValue == 16)
        #expect(!Screen.about.carriesPlayKey)
        let graph = NavigationGraph(lastPlayedMode: .probe)
        #expect(graph.destinations(from: .about).map(\.to) == [.settings])
    }

    @Test("AboutView renders exactly the six rows §12.9 budgets")
    func aboutRowCount() {
        let rows = AboutModel(version: "1.0", build: "42", health: .healthy).rows
        #expect(rows.count == 6)
        #expect(rows.map(\.id) == [.version, .build, .noDataCollected, .copyright, .storage, .licences])
    }

    @Test("the storage row reads storeHealth and says something different when it is not healthy",
          arguments: StoreHealth.allCases)
    func storageRowTracksHealth(_ health: StoreHealth) {
        let model = AboutModel(version: "1.0", build: "42", health: health)
        #expect(model.storageRow.health == health)
        #expect(!model.storageRow.detailKey.isEmpty)
    }
}
```

And `Modules/Tests/HunchUITests/LaunchPerformanceTests.swift` — XCTest, because
`XCTApplicationLaunchMetric` has no Swift Testing path (`06 T43`, `08 §7.10`):

```swift
import XCTest

final class LaunchPerformanceTests: XCTestCase {

    /// §12.2 screen 1: the launch surface exists to cover the cold-start hitch, and its exit is
    /// "auto, ≤ 400 ms". Measured, not asserted in prose.
    func testColdLaunchIsUnder400ms() {
        let app = XCUIApplication()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            app.launch()
            app.terminate()
        }
        // The 400 ms budget is recorded as a baseline in the test plan and fails on regression.
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path Modules --filter ScreenInventoryTests`, then
`xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -only-testing:HunchUITests/LaunchPerformanceTests -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'`

Failures must be missing symbols — `ScreenCatalogue`, `AboutModel` — or a screen with no destination.
`everyScreenIsPresentable` passing before `ScreenCatalogue` exists means the factory is returning a
non-optional placeholder; make the return type optional and let the switch prove exhaustiveness.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `App/LaunchScreen.storyboard` |
| modify | `App/Assets.xcassets` — add the launch background colour set (and nothing else) |
| modify | `Config/Base.xcconfig` — `INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen` |
| create | `Modules/Sources/MetaFeature/AboutView.swift` |
| create | `Modules/Sources/MetaFeature/AboutModel.swift` |
| create | `Modules/Sources/HunchAppFeature/ScreenCatalogue.swift` |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — the six `AboutView` keys, English only (E18 adds the other eleven languages) |
| modify | `Scripts/check-source-hygiene.sh` — add **check 11**, the deliberate-absence lint |
| create | `Modules/Tests/MetaFeatureTests/ScreenInventoryTests.swift` |
| create | `Modules/Tests/HunchUITests/LaunchPerformanceTests.swift` |
| modify | `Presubmission.xctestplan` — record the launch-metric baseline |
| modify | `tests.json` — three entries: closed inventory, the deliberate-absence lint, and the ≤ 400 ms cold-launch budget |

## Implementation notes

### `LaunchSurface` — a storyboard, and the two reasons it must stay one

§12.2 says *"Storyboard, no code"* and it is not a stylistic preference. A launch screen is rendered
by the system **before** the process is running, so it is the only thing that can cover the hitch; a
SwiftUI view cannot appear until after `@main` has run, which is the hitch. And a storyboard cannot
reference `HunchUI`'s tokens, so:

- **the ground colour and the brass hairline are a colour set in `Assets.xcassets`**, which is the
  one exception the tree already carves out ("`AppIcon` + launch colour ONLY"). Add exactly two
  colour sets — the launch ground and the launch hairline — with the same sRGB values as
  `ground.base` (dark) and `accent.brass` (dark). Write the pair into
  `hunch-design-tokens/references/palette.md` as a documented duplication with its reason, so
  `check-tokens.swift`'s three-way divergence check knows about it and the day the palette moves,
  the asset moves with it. This is the **only** sanctioned copy of a token value in the repository.
- **the wordmark is a `UILabel` with the string "HUNCH"**, verbatim, in the system font. §12.9:
  `CFBundleDisplayName` is "HUNCH" in all 12 locales including Arabic — *it is a wordmark, not a
  word* — so the label is not localizable and `Info.plist` keeps its zero localizable strings.
- **no `UIImageView`, no glyph, no icon.** `01 P33`/`P37`: no glyph asset, ever.

Both colour sets must declare `Any` and `Dark` appearances with the same value, so a light-mode
device does not flash a system-white launch screen before a dark-first app appears.

### The ≤ 400 ms budget

§12.2's Exit column is *"auto, ≤ 400 ms"*. That is a **measurement**, so measure it:
`XCTApplicationLaunchMetric` in `HunchUITests` with the baseline recorded in `Presubmission.xctestplan`.

Two things that would silently blow it, and the guard for each:

| Risk | Guard |
|---|---|
| `AppDependencies.live()` doing file I/O synchronously at `@main` | `FilePersistenceStore` is an `actor` and every read is `await`; `AppLaunchRoute.resolve` is `async` and the first frame is the launch storyboard, not a blocked main thread (E10·T01) |
| the lower-band index being built at launch | `actor LawIndexLoader` caches the `Task`, not the value, and the index is built in the background (E05·T07, §14.5 open decision 4). Nothing on the launch path awaits it |

If the measurement regresses, the fix is upstream in whichever of those two moved — never a
lengthened budget.

### `AboutView` — six rows, and the one that is not static

| Row | Content | Source |
|---|---|---|
| version | `CFBundleShortVersionString` | `Bundle.main` |
| build | `CFBundleVersion` | `Bundle.main` |
| no data is collected | a statement, not a claim to verify — it is true because `PrivacyInfo.xcprivacy` says so and check 5 greps for every network symbol | §12.2, §12.9 |
| copyright | one line | §12.2 |
| storage status | **the only live row**: reads the `storeHealth` `@Entry` value (`04 A27`, `08 §6`) | §11.13's disk-full hairline |
| licences | there are no third-party dependencies, so this row says so | brief |

`AboutModel` is a value so `aboutRowCount` and `storageRowTracksHealth` run on the host. The view is
a `Form` neutralised exactly as `stock-controls.md` §1 prescribes — `.scrollContentBackground(.hidden)`,
`ground.base` background, `.tint(stroke.primary)` and never the system accent, `ground.raised` row
background, hairline separator tint, `defaultMinListRowHeight` at 44.

**`AboutView` carries no play key** (§12.3: screens 9–15 only). It is reached by a push from Settings
and its only exit is back — which is exactly why §12.3's audit table puts it at "dismiss, then play
key → 2".

Every string goes through `Loc` and every call site is `Text(verbatim:)` — a `Loc` accessor returns an
already-resolved `String`, and re-wrapping it in the localizing `Text` overload is a second lookup
against `Bundle.main` that fails silently and renders the key (`hunch-accessibility/SKILL.md`,
§12.9 trap 1).

### `ScreenCatalogue` — the closed-inventory mechanism

```swift
// Modules/Sources/HunchAppFeature/ScreenCatalogue.swift
@MainActor
enum ScreenCatalogue {
    /// One `case` per §12.2 row, no `default:` (W29). Adding a nineteenth screen does not compile
    /// until someone has decided what it presents — which is the same guard T02 relies on, from the
    /// other side.
    static func destination(for screen: Screen, using dependencies: AppDependencies) -> AnyView? { … }

    /// `.launchSurface` alone; everything else is Swift.
    static func isStoryboardBacked(_ screen: Screen) -> Bool { screen == .launchSurface }
}
```

`AnyView` is normally a smell; here it is the return type of a factory whose whole job is to erase
eighteen heterogeneous screens for one test, and it is used **only** by that test and by `AppView`'s
own switch. Do not let it spread — `AppView` switches on the surface directly and constructs the
concrete view, so the erased path exists for the inventory assertion and nowhere else.

### Check 11 — the deliberate-absence lint

§12.2's closing paragraph is a list of eleven things that are not screens, each with a reason
elsewhere in the document. A test cannot see their absence; a grep can. Append to
`Scripts/check-source-hygiene.sh`, following the numbered-check convention
(`hunch-build-and-ci/references/source-hygiene.md` §2 is the whole script and its ordering):

```bash
# 11. §12.2's eleven deliberate absences. Each symbol below would BE one of them.
forbidden='UIActivityViewController|ShareLink|SKStoreReviewController|requestReview|AppStore\.requestReview|
StoreKit|SKOverlay|Purchases|AuthenticationServices|SignInWithApple|ASAuthorization|
TipKit|popoverTip|TipView|ContentUnavailableView|
UNUserNotificationCenter|UNMutableNotificationContent|
TabView\(.*PageTabViewStyle|onboarding[Cc]arousel|difficultySelector|leaderboard'
```

Each hit names the §12.2/§12.6 sentence that forbids it in the failure message, so the fix is
obvious and the exemption route is a written `DECISIONS.md` entry, not a `# shellcheck disable`.

`ContentUnavailableView` is in the list on purpose: it is the framework's empty-state-copy component,
and §12.2 ends with *"The Codex with zero pages draws one dashed plate and nothing else."*

`UNUserNotificationCenter` is already covered by check 5's network/notification grep if that grep
includes it; if it does, do not duplicate — extend the message instead. Two greps for one symbol is
the same defect this whole library is about.

### Portrait-only and dark-first, asserted rather than assumed

Both are build settings (E01·T02) and both are checked, not re-implemented:

```bash
xcodebuild -project Hunch.xcodeproj -showBuildSettings -configuration Release \
  | grep -E 'INFOPLIST_KEY_UISupportedInterfaceOrientations|INFOPLIST_KEY_UIUserInterfaceStyle'
```

Portrait-only must list `UIInterfaceOrientationPortrait` and nothing else. Dark-first is *not*
`UIUserInterfaceStyle = Dark` — that would break the light theme §13.2 ships and the System theme
preference §12.6 defaults to. Dark-first means the **default `ThemePreference` resolves to Dark below
`.light`** (T06's `ThemePreference` mapping), and the launch storyboard's colour sets are dark in
both appearances. Assert the first with the build-settings grep and the second in T06's tests; do not
conflate them.

### The screens that are already here

Sixteen of the eighteen arrive before this task and are not re-created: `RoundView`, `BenchView`,
`AssayInspectorView`, `InscriptionView` (E08/E09), `EchoRoundView` (E13), `SieveRoundView` and
`SievePauseOverlay` (E14), the three Codex screens (E15), `AnomalyView`, `StatisticsView`,
`ProfileView` (E16), `FrameView` (T03), and `SettingsView` + `ResetConfirmAlert` (T06–T08, which is
why this task depends on T03 and not on T08 — `ScreenCatalogue` may return a stub for those two until
T06 lands, and `everyScreenIsPresentable` will then be green for the right reason). If a stub is
used, mark it with a `// T06` comment and grep for those comments in T08's acceptance criteria.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter ScreenInventoryTests` green, all five tests.
- [ ] `xcodebuild test … -only-testing:HunchUITests/LaunchPerformanceTests` green with the 400 ms baseline recorded in `Presubmission.xctestplan`.
- [ ] `App/LaunchScreen.storyboard` exists, contains one label and one hairline view, references only the two launch colour sets, and contains **no** image view.
- [ ] `xcodebuild -showBuildSettings | grep UILaunchStoryboardName` reports `LaunchScreen`, and `Scripts/check-pbxproj-clean.sh` still passes.
- [ ] `xcodebuild -showBuildSettings | grep UISupportedInterfaceOrientations` lists portrait and nothing else.
- [ ] `ls App/Assets.xcassets` shows `AppIcon` plus exactly two colour sets and no other asset.
- [ ] `Scripts/check-source-hygiene.sh` check 11 exists, and was demonstrated to fail on a planted `ShareLink` and on a planted `ContentUnavailableView` before being reverted — both failure messages pasted into the commit message.
- [ ] `grep -rn "Text(Loc\." Modules/Sources/MetaFeature/AboutView.swift` returns nothing; every call site is `Text(verbatim:)`.
- [ ] `AboutView`'s six English strings are in `Localizable.xcstrings`, each ≤ 22 characters, and every one re-read against §1.13's approved framings and the banned list.
- [ ] `hunch-design-tokens/references/palette.md` records the two launch colour sets as the single sanctioned token duplication, with its reason.
- [ ] `tests.json` carries the three entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T05: LaunchScreen storyboard, AboutView, the closed 18-screen inventory and check 11"`

## Out of scope

- `SettingsView` itself, its seven sections and its 19 rows — **T06**, **T07**, **T08**. This task only proves `AboutView` is reachable from it.
- The app icon at 29 / 60 / 1024 pt — **E20·T10**. The launch screen and the icon are different artefacts with different gates.
- `PrivacyInfo.xcprivacy`'s contents and the store metadata — **E20·T11**.
- The eleven other languages for `AboutView`'s six strings, the completeness test and the pseudolocale gate — **E18·T03/T09**.
- `performAccessibilityAudit` over the eighteen screens — **E19·T11**.
- The `storeHealth` value's *producer* — the disk-full write path — **E07·T02**.
