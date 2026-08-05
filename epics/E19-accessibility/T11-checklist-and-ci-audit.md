# T11 — The §13.12 checklist and the CI audit

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T10 (and, in truth, all of T01–T10) |
| **Delivers** | Accessibility checklist · `tests.json` (VERIFICATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | `references/audit-in-ci.md` is this task, end to end: the thirteen gates mapped to their owners, `performAccessibilityAudit`'s exact shape and its four silent failure modes, the screen list, the AX5 × five-locale plan configuration, the source lint that covers what XCUITest cannot see, the four manual gates with their scripts, and the two `HunchUITests` targets that collide by name. |
| `hunch-swift-testing` | Owns test-plan membership and cadence — Swift Testing selects by tag, **XCTest selects by target and class in the plan**, so the XCUITest bundle is included in `Nightly` and `Prerelease` and excluded from `Presubmission` explicitly. It also owns step 5 of writing a test: *update `tests.json`; never delete or weaken an entry to reach green.* |

## Objective

At the end of this task all thirteen gates of §13.12 are green, each with a runnable `tests.json`
entry naming its owner; `performAccessibilityAudit` runs against every screen of §12.2's inventory in
the `Nightly` and `Prerelease` plans; the AX5 × five-locale matrix runs as plan configurations rather
than as five copies of a suite; and the four manual gates have written scripts, three of which have
been run on a device and recorded.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.12 | the thirteen gates verbatim — each one *a gate before any release build*, each with a matching `tests.json` entry |
| `GAME_DESIGN.md` | §12.2 | the eighteen screens the audit must cover |
| `GAME_DESIGN.md` | §12.3 | the tap-distance audit — every screen is at most two taps from a play surface, so each audit test's navigation is one or two lines |
| `GAME_DESIGN.md` | §12.9 | the pseudolocalization gate and the five review locales |
| `GAME_DESIGN.md` | §13.11 | *"Snapshot test: every screen × AX5 × {English, German, Turkish, Russian, Arabic}, asserting zero truncation and zero horizontal overflow"* |
| `.claude/skills/hunch-accessibility/references/audit-in-ci.md` | §1–§8 | the gate map, the audit's shape, the screen list, the plan configurations, the lint, the manual scripts, the plans, the target-name collision |
| `.claude/skills/hunch-accessibility/references/rotors-and-gestures.md` | §7 | the sixteen-gesture walkthrough — the script for gate 3 |
| `ios-swift-guide/06-TESTING.md` | T43, T44, T47 | `import Testing` is rejected in a UI test target; no `@Test` beside an `XCTestCase`; `continueAfterFailure = false` |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B24, B26, B31, B40, B46 | plan cadence tags; a second plan configuration; `set -o pipefail`; Application Language per configuration; **`issueHandler` returning `true` suppresses the issue** |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §7.10 | the two `HunchUITests` paths; XCUITest as `XCTestCase` is not a brief violation |

## TDD — the test comes first

Here the "test" *is* the deliverable, so step 1 writes the audit against screens that are already
shipped and watches it fail on the ones that are not yet clean. That is the correct failure: an audit
that passes on its first run has not been pointed at anything.

**Step 1 — write the failing test.** Create `HunchUITests/AccessibilityAuditTests.swift` — the
**repo-root XCUITest bundle**, not `Modules/Tests/HunchUITests/`:

```swift
import XCTest
import XCUIAutomation          // since the Xcode 16 module split, XCUIApplication lives here

final class AccessibilityAuditTests: XCTestCase {

    /// Launched per test, not held as a stored property. `XCUIApplication` is `@MainActor` and
    /// `XCTestCase.setUp()` is not, so under Swift 6 strict checking a `var app: XCUIApplication!`
    /// populated in `setUp()` is an isolation error — and `@MainActor override func setUp()` does
    /// not fix it either, because an override cannot add isolation its superclass method lacks.
    @MainActor
    private func launchedApp(_ extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false                                    // 06 T47
        let app = XCUIApplication()
        app.launchArguments += ["-UITest",                              // SeedSource.fixed + Now.fixed
                                "-AppleAnimationsEnabled", "NO"] + extraArguments
        app.launch()
        return app
    }

    /// Explicit, never `.all`: when Apple adds an audit type, `.all` fails a green pipeline on a
    /// build nobody changed, and the reflex fix is a blanket handler that suppresses everything.
    static let auditTypes: XCUIAccessibilityAuditType =
        [.contrast, .dynamicType, .elementDetection, .hitRegion,
         .sufficientElementDescription, .trait, .action, .parentChild, .textClipped]

    // MARK: the eighteen screens of §12.2

    @MainActor func testFrameIsAccessible() throws {
        try launchedApp().performAccessibilityAudit(for: Self.auditTypes)
    }

    @MainActor func testRoundSurfaceIsAccessible() throws {
        let app = launchedApp()
        app.buttons["mode.probe"].tap()
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
            // The ONE accepted exception. `stroke.hairline` is declared never state-bearing, so a
            // decorative rule below the contrast floor is by design. Suppress by element AND by
            // audit type — either alone waves through far more than intended.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "decorative.rule"
        }
    }

    @MainActor func testRoundSurfaceWithBenchUpIsAccessible() throws {
        let app = launchedApp()
        app.buttons["mode.probe"].tap()
        app.buttons["bench.handle"].tap()
        // The barred Seal must still be DISCOVERABLE while it is refusing.
        XCTAssertTrue(app.buttons["bench.seal"].exists)
        XCTAssertTrue(app.buttons["bench.seal"].isEnabled)
        try app.performAccessibilityAudit(for: Self.auditTypes)
    }

    @MainActor func testAssayInspectorIsAccessible() throws { … }        // Bench ▸ Assay ▸ "Inspect"
    @MainActor func testInscriptionIsAccessible() throws { … }           // audit at .settled, not mid-reveal
    @MainActor func testEchoRoundIsAccessible() throws { … }             // -UITest unlocks §9.10's gates
    @MainActor func testSieveRoundIsAccessible() throws { … }
    @MainActor func testSievePauseOverlayIsAccessible() throws { … }     // assert .isModal keeps the lane out
    @MainActor func testCodexRootIsAccessible() throws { … }             // -UITest seeds the Codex
    @MainActor func testCodexShelfIsAccessible() throws { … }
    @MainActor func testCodexPageIsAccessible() throws { … }
    @MainActor func testAnomalyIsAccessible() throws { … }
    @MainActor func testProfileIsAccessible() throws { … }
    @MainActor func testStatisticsIsAccessible() throws { … }
    @MainActor func testSettingsIsAccessible() throws { … }
    @MainActor func testAboutIsAccessible() throws { … }
    @MainActor func testResetConfirmAlertIsAccessible() throws { … }
    // `LaunchSurface` is a storyboard with no elements and ≤ 400 ms of life. Not audited, and that
    // exclusion is recorded in tests.json rather than left as a silent gap.
}
```

Create `HunchUITests/AX5LocaleSnapshotTests.swift` — gate 8, driven by plan configuration rather than
by five copies of the suite:

```swift
import XCTest
import XCUIAutomation

/// Gate 8. The LOCALE and the Dynamic Type category are plan-configuration settings (07 B26, B40),
/// so this file is written once and runs ten times: five locales × two text directions.
final class AX5LocaleSnapshotTests: XCTestCase {

    @MainActor
    private func launchedApp() -> XCUIApplication { … }                  // as above

    @MainActor func testNoTruncationOrOverflowOnEveryScreen() throws {
        let app = launchedApp()
        for screen in UITestScreen.allAudited {
            screen.navigate(app)
            try app.performAccessibilityAudit(for: [.textClipped, .hitRegion, .dynamicType])
            XCTAssertFalse(app.hasHorizontalOverflow, "\(screen) overflows horizontally")
            for element in app.descendants(matching: .any).allElementsBoundByAccessibilityElement
            where element.isHittable {
                XCTAssertGreaterThanOrEqual(element.frame.width, 44, "\(screen): \(element.identifier)")
                XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(screen): \(element.identifier)")
            }
        }
    }

    /// The mirroring assertions the audit cannot see. Chrome mirrors; glyph bodies, index strokes
    /// and pip positions do not — mirroring 45° and 135° swaps `teal` and `rose`, which is a
    /// two-hue data corruption dressed as a layout bug.
    @MainActor func testChromeMirrorsAndGlyphsDoNot() throws {
        try XCTSkipUnless(UITestConfiguration.isRightToLeft)
        let app = launchedApp()
        app.buttons["mode.probe"].tap()
        XCTAssertGreaterThan(app.buttons["commit.probe"].frame.midX, app.buttons["commit.bench"].frame.midX)
        XCTAssertEqual(app.images["throat.glyph"].label, UITestConfiguration.expectedThroatLabel)
    }
}
```

Create `Modules/Tests/HunchNavigationTests/AuditCoverageTests.swift` — the cheapest guard against a
gate-4 hole, reusing the graph walk `NavigationDepthTests` already does:

```swift
import Foundation
import Testing
@testable import HunchNavigation

@Suite("Every reachable screen has an audit method — §13.12 gate 4", .tags(.unit, .presubmission))
struct AuditCoverageTests {

    @Test("every screen in the route graph is either audited or explicitly excluded")
    func everyScreenIsAuditedOrExcluded() {
        for screen in NavigationGraph.reachableScreens {
            #expect(AuditManifest.audited.contains(screen) || AuditManifest.excluded[screen] != nil,
                    "\(screen) has no audit method and no recorded exclusion")
        }
    }

    @Test("the only excluded screen is LaunchSurface, and the reason is recorded")
    func theOnlyExclusion() {
        #expect(AuditManifest.excluded.keys.map(\.self) == [.launchSurface])
        #expect(AuditManifest.excluded[.launchSurface]?.isEmpty == false)
    }

    @Test("the manifest lists eighteen screens and audits seventeen of them")
    func counts() {
        #expect(NavigationGraph.reachableScreens.count == 18)
        #expect(AuditManifest.audited.count == 17)
    }
}
```

Finally, complete **check 11** in `Scripts/check-source-hygiene.sh` — T01 added 11a/11b, T05 added
11c, T06 added 11d, T08 added 11e; this task adds the last one and wires the whole script into the
workflow:

```bash
# check 11f — an audit handler that can never fail (07 B46: returning true SUPPRESSES the issue).
grep -Rq '{ _ in true }' HunchUITests && fail "an audit handler that suppresses everything (07 B46)"
grep -Rq 'for: .all' HunchUITests && fail "audit types are listed explicitly, never .all"
```

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail          # 07 B31 — a swallowed exit code makes an audit fail invisibly
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Nightly \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/AccessibilityAuditTests | xcbeautify
swift test --package-path Modules --filter AuditCoverageTests
Scripts/check-source-hygiene.sh
```

Expect real failures, and read every one: a missing `.accessibilityIdentifier` that the navigation
lines need, a `.hitRegion` failure on a target T07 measured at reference size but that shrinks under
the audit's own Dynamic Type pass, a `.parentChild` failure where a `.contain` container was written
as `.ignore`. **A first audit run that is clean means it did not reach the screen** — check the test
actually navigated by asserting a known element exists before the audit call.

**Step 3 — implement** the fixes. Every audit failure is fixed **in the offending view**, never by
adding a suppression. There is exactly one suppression in the whole bundle and it is
`decorative.rule` under `.contrast`.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchUITests/AccessibilityAuditTests.swift` — repo-root XCUITest bundle |
| create | `HunchUITests/AX5LocaleSnapshotTests.swift` |
| create | `HunchUITests/UITestScreen.swift` — navigation per screen, one or two lines each |
| create | `Modules/Sources/HunchNavigation/AuditManifest.swift` — audited / excluded, with reasons |
| create | `Modules/Tests/HunchNavigationTests/AuditCoverageTests.swift` |
| modify | `Modules/Sources/**` — `.accessibilityIdentifier` only where the navigation lines need one |
| modify | `Nightly.xctestplan` — include `HunchUITests/AccessibilityAuditTests` by target and class |
| modify | `Prerelease.xctestplan` — include both classes; add five locale configurations plus Double Length and Right to Left pseudolanguages; set the Dynamic Type category to AX5 per configuration |
| modify | `Presubmission.xctestplan` — **exclude** the XCUITest bundle explicitly |
| modify | `.github/workflows/ci.yml` — the audit job on the nightly schedule; `set -o pipefail` before the formatter |
| modify | `Scripts/check-source-hygiene.sh` — check 11f, and confirm 11a–11e are all present |
| modify | `tests.json` — **all thirteen** §13.12 entries |
| modify | `PROGRESS.md` — §Accessibility, the manual-gate records |
| modify | `DECISIONS.md` — the `LaunchSurface` exclusion; any audit issue accepted rather than fixed |

## Implementation notes

### The thirteen gates, and which ones are this epic's

Most of §13.12 is **not** this task's to write. The value of the table is knowing which ones are, and
refusing to duplicate the rest. Every row gets a `tests.json` entry here regardless of who owns it.

| # | Gate | Kind | Owner |
|---|---|---|---|
| 1 | all 256 glyphs pairwise-distinct as greyscale rasters at 44 pt @2× | automated | **E04·T06** |
| 2 | `render(g, monochrome:)` gives bit-identical coverage masks | automated | **E04·T06** |
| 3 | a complete band-5 round playable with the screen curtain on | **manual** | **here**, §the four manual gates |
| 4 | every interactive element non-empty and non-duplicated; audit clean on every §12.2 screen | automated | **E19·T01** + **here** |
| 5 | Magic Tap fires Probe / Seal; two-finger scrub closes Bench and Assay | **manual** + lint | **E19·T05** + **here** |
| 6 | all four rotors correct in context, Counterexample only after a strike | **manual** + lint | **E19·T05** + **here** |
| 7 | narration matches the rendered tiles for 10,000 laws | automated, `swift test` | **E19·T03** |
| 8 | AX5 × 5 locales: zero truncation, zero overflow, targets ≥ 44 × 44 | automated | **E19·T07** + **here** |
| 9 | Reduce Motion: nothing translates, scales or rotates, including SIEVE; plus preview/window parity | automated + manual | **E09·T12**, **E14·T10** |
| 10 | High Contrast: every pair clears the floor, hue index-stroke-only, 256 distinguishable | automated | **E19·T09** |
| 11 | audio session category / mode / options; silent switch; other audio never ducked | automated + manual | **E20·T04** |
| 12 | admit / reject / `bar` distinguishable face-down by three testers | **manual** | **E20·T05/T12** |
| 13 | nothing claims a cognitive, memory, focus, intelligence or health benefit | lint + **manual** | **E18·T08**, **E20·T11** |

Five gates are manual or partly manual, and that is not a failure of automation: three of them (3, 5,
6) test VoiceOver's **own gesture layer**, which XCUITest cannot synthesise — it drives the app
*through* the accessibility layer, and custom actions are not exposed on `XCUIElement` at all.

**Gate 12 stays `pending` at the end of this epic**, with E20·T12 named as its owner and the three
testers as its method. That is the one entry that may legitimately be non-green when this PR merges,
and the entry says so rather than being omitted.

### `performAccessibilityAudit`, and its four silent failure modes

This is `XCTestCase`, and it has to be: `performAccessibilityAudit` is a method on `XCUIApplication`,
so it needs the out-of-process XCUITest runner, and Xcode's build system rejects `import Testing` in a
UI test target outright (`06 T43`). `08 §7.10` already ruled this is not a violation of the brief's
"Swift Testing, not XCTest" — that rule governs new *unit* tests, which all live in the two packages.

Four things that each fail silently:

- **`issueHandler` returning `true` SUPPRESSES the issue** (`07 B46`). `{ _ in true }` is a test that
  passes unconditionally, forever, and nothing about it looks wrong. When there is no exception to
  suppress, pass **no handler at all** — that is the safe default and it is what `testFrameIsAccessible`
  does. Check 11f greps for it because review does not catch it.
- **Suppress by element *and* audit type, never by one alone.** The type alone waves through every
  contrast failure on the screen; the identifier alone waves through everything about that element.
- **The app must be deterministic.** `-UITest` swaps in `SeedSource.fixed` and `Now.fixed` at the
  composition root (E10·T01). An audit run against a randomly generated law is a flaky audit, and a
  flaky gate is a gate that gets disabled.
- **Every method that touches `XCUIApplication` is `@MainActor`, and the app is never a stored
  property.** The XCTest-era `private var app: XCUIApplication!` + `setUp()` shape does not compile
  under Swift 6, and the tempting fix — `@MainActor override func setUp()` — is itself an error,
  because an override cannot add isolation its superclass method lacks. A `@MainActor` factory method
  is the shape that works, and it makes each test's launch arguments visible at the call site.

`.all` is available and tempting. Prefer the explicit list: when Apple adds an audit type, `.all`
starts failing a green pipeline on a build nobody changed, and the reflex fix is the blanket handler
above.

### The screen list, and the hole it closes

Gate 4 says *every screen in §12.2's inventory*. That is eighteen, seventeen of them audited, and
§12.3's tap-distance audit guarantees each is at most two taps from a play surface — so each test's
navigation is one or two lines. `RoundView` is audited **twice**: once mid-round, once with the Bench
up, because the Bench is a presented subtree with its own environment and its own Magic Tap handler.

A new screen with no audit method is a gate-4 hole that nobody notices. `AuditCoverageTests` walks the
same route graph `NavigationDepthTests` already walks (E17·T02) and fails when a reachable screen is
neither audited nor **explicitly excluded with a recorded reason**. There is exactly one exclusion —
`LaunchSurface`, a storyboard with no elements and ≤ 400 ms of life — and it is in `DECISIONS.md`, not
in a comment.

`.accessibilityIdentifier` is set **only** where these tests must find an element. It is never
localized and it is never a substitute for a label: the audit's `.sufficientElementDescription` pass
will not accept one.

### AX5 × five locales — one plan, ten configurations

Do not write five copies of the suite. Drive it from a **second test-plan configuration** (`07 B26`),
which runs the whole plan once per configuration and sets Application Language and Region without
touching a test file (`07 B40`):

- one configuration per locale — **English, German, Turkish, Russian, Arabic** — plus **Double Length
  Pseudolanguage** and **Right to Left Pseudolanguage**, because §12.9 makes pseudolocalization a gate
  rather than a courtesy and RTL is where §12.8's mirroring rules are actually checked;
- **the Dynamic Type category is set per configuration too**, so AX5 is a plan setting rather than a
  launch argument somebody forgets.

Cost is linear: five locales × two directions is ten full runs, so this is the **`Prerelease`** plan
and not the presubmission one.

The mirroring assertions are written by hand because the audit cannot see them: in Arabic the
instrument-bar key order and the commit-bar order reverse, and the index stroke's rotation does
**not** — mirroring 45° and 135° swaps `teal` and `rose`.

### The four manual gates, with their scripts

Each has a written script so it is repeatable by someone who did not write the feature. Record every
run in `PROGRESS.md` with the build number and the date: *a manual gate with no record is a manual gate
that stopped being run three releases ago.*

1. **Gate 3 — curtain on, band 5, end to end.** The script is `rotors-and-gestures.md` §7, sixteen
   gestures, for `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}` — nine taps
   sighted. Triple-tap three fingers to toggle the screen curtain. **A step that needs a peek is a
   failure, not a note.** The round must be played through probe, twin, declare, strike, re-declare and
   inscribe, which is §13.12 gate 3's full wording and is more than the declaration walkthrough alone.
2. **Gate 5 — Magic Tap and escape.** Two fingers double-tap on the Dial fires a probe; the same on
   the Bench fires the Seal, *including when the Seal is barred*, where it must announce the bar rather
   than do nothing. Two-finger scrub closes the Bench, then the expanded Assay, and does **not** leave
   the round.
3. **Gate 6 — the four rotors.** Rotate to each; confirm "Counterexample" is **absent** before the
   first strike and present after it, with exactly two stops.
4. **Gate 12 — haptics face-down.** Three testers who were not told which is which distinguish admit
   (one soft), reject (two sharp) and `bar` (one blunt heavy). **Owned by E20·T05/T12** and listed here
   because it is a release gate and gets forgotten. Its `tests.json` entry is written now and stays
   `pending`.

### Plans and cadence

| Suite | Plan | Why |
|---|---|---|
| narration parity, 10,000 laws (T03) | **Presubmission** | `swift test`, no simulator, inside the 10 s budget |
| `RenderEnv` arithmetic, thresholds, targets, vocabulary (T01, T02, T04–T08, T10) | **Presubmission** | value tests |
| greyscale distinctness under High Contrast (T09) | **Nightly** | 256 rasters, 32,640 comparisons |
| `AccessibilityAuditTests` | **Nightly** and **Prerelease** | XCUITest needs a simulator and a full launch per screen |
| `AX5LocaleSnapshotTests` | **Prerelease** | ten full runs |
| the four manual gates | **Prerelease**, by hand | above |

`07 B24` drives Swift Testing membership with tags; **XCTest membership is by target and class
selection in the plan**, not by tags, which is why `Presubmission.xctestplan` has to exclude the
XCUITest bundle explicitly rather than merely not tagging it.

One warning that is this task's business and not the build skill's: **`set -o pipefail` before piping
`xcodebuild` into a formatter** (`07 B31`). An audit whose handler suppresses everything already cannot
fail; a swallowed exit code makes it fail invisibly, twice over.

### The two target names that collide

`08 §1` puts a `HunchUITests` under `Modules/Tests/` **and** a `HunchUITests/` at the repo root:

| Path | What it is | Framework | Runs on |
|---|---|---|---|
| `Modules/Tests/HunchUITests/` | unit tests for the `HunchUI` **module** | Swift Testing | the host, via `swift test` |
| `HunchUITests/` (repo root) | the XCUITest bundle — audit, screenshots | XCTest | a simulator |

They do not collide in the build system but they collide in every conversation and every grep.
**Always write the full path.** Gate 10's raster test is `Modules/Tests/HunchUITests/`; gate 4's audit
is `HunchUITests/`. If the ambiguity ever causes a test to land in the wrong target, rename the
XCUITest bundle to `HunchAppUITests` and record it in `DECISIONS.md`.

### `tests.json` — thirteen entries, and the rule about them

Each entry carries `id`, `statement`, `source`, `home`, `command`, `owner` and `status`, per
`Scripts/check-tests-json.sh` (E01·T08). Thirteen entries with `source: "§13.12 gate N"`, one per gate,
each with a `command` that actually runs. Gates 1, 2, 9, 11, 12 and 13 point at their **owning epic's**
test rather than being re-implemented here — a duplicated gate is two things to keep green and one of
them will rot.

**No entry is ever removed or weakened to reach green**, and that includes turning on an audit
suppression: an `issueHandler` that returns `true` is the same offence as deleting the test, wearing a
closure.

## Acceptance criteria

- [ ] `xcodebuild test … -testPlan Nightly -only-testing:HunchUITests/AccessibilityAuditTests` green: **18 audit methods** over 17 audited screens, run on iPhone SE (3rd generation).
- [ ] `xcodebuild test … -testPlan Prerelease` green across **ten configurations** — five locales × two text directions — with AX5 set per configuration.
- [ ] Exactly **one** `issueHandler` exists in the whole bundle, and it suppresses `decorative.rule` under `.contrast` only. `grep -c 'issueHandler\|{ issue in' HunchUITests/*.swift` confirms it.
- [ ] `grep -Rn 'for: .all\|{ _ in true }' HunchUITests` returns nothing; `Scripts/check-source-hygiene.sh` check 11f fires on a planted one.
- [ ] `swift test --package-path Modules --filter AuditCoverageTests` green; `NavigationGraph.reachableScreens.count == 18`, `AuditManifest.audited.count == 17`, one recorded exclusion.
- [ ] `Presubmission.xctestplan` explicitly excludes the XCUITest bundle; `Nightly` and `Prerelease` include it by target and class.
- [ ] `Scripts/check-source-hygiene.sh` runs checks 11a through 11f and is wired both as the Xcode run-script phase and in CI.
- [ ] `tests.json` carries **thirteen** entries with `source: "§13.12 gate 1…13"`; every `command` has been run; only gate 12 is `pending`, owned by E20·T12.
- [ ] `PROGRESS.md` §Accessibility records gates 3, 5 and 6 with a build number and a date, and gate 3's record names the band-5 law and confirms no step needed a peek.
- [ ] `DECISIONS.md` records the `LaunchSurface` exclusion and every audit issue accepted rather than fixed, if any.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s. The `Nightly` and `Prerelease` plans green in the simulator.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T11: the 13 gates, the CI audit across 18 screens, and the AX5 × 5-locale plan"`

## Out of scope

- Gates 1, 2, 9, 11, 12 and 13's implementations — **E04·T06**, **E09·T12**, **E14·T10**, **E18·T08**, **E20·T04/T05/T11/T12**. This task writes their `tests.json` entries and runs their commands; it does not re-implement them.
- The CI workflow's structure, the three test plans' creation and the 10-second budget check — **E01·T07**; this task adds membership and configurations to files that exist.
- `check-tests-json.sh` itself — **E01·T08**.
- The screenshot review in English, German and Arabic — **E18·T09**; the RTL configuration here is the mechanical half of the same gate.
- Running gate 12 with three testers — **E20·T12**.
