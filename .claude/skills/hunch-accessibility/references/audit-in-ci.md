# audit-in-ci.md — the thirteen gates, and the audit that catches the rest

Contents: [1 The thirteen gates, mapped](#1-the-thirteen-gates-mapped) ·
[2 performAccessibilityAudit](#2-performaccessibilityaudit) · [3 The screen list](#3-the-screen-list) ·
[4 AX5 × five locales](#4-ax5--five-locales) · [5 What XCUITest cannot see, and the lint that covers it](#5-what-xcuitest-cannot-see-and-the-lint-that-covers-it) ·
[6 The manual gates](#6-the-manual-gates) · [7 Plans and cadence](#7-plans-and-cadence) ·
[8 Two target names that collide](#8-two-target-names-that-collide) · [9 What would be wrong](#9-what-would-be-wrong)

---

## 1. The thirteen gates, mapped

§13.12 is thirteen gates before any release build, each with a matching entry in `tests.json`. Most of them are not
this skill's to write — the value of the table is knowing which ones are, and refusing to duplicate the rest.

| # | Gate | Kind | Owner |
|---|---|---|---|
| 1 | all 256 glyphs pairwise-distinct as greyscale rasters | automated | `hunch-glyph-renderer/references/triple-encoding-proof.md` |
| 2 | `render(g, monochrome:)` gives bit-identical coverage masks | automated | " |
| 3 | a complete band-5 round playable with the screen curtain on | **manual** | `rotors-and-gestures.md` §7 is the script |
| 4 | every interactive element has a non-empty, non-duplicated label; the audit is clean on every §12.2 screen | automated | **here**, §2–§3 |
| 5 | Magic Tap fires Probe / Seal; two-finger scrub closes Bench and Assay | **manual** + source lint | **here**, §5 |
| 6 | all four rotors present and correct, Counterexample only after a strike | **manual** + source lint | **here**, §5 |
| 7 | narration matches the rendered tiles for 10,000 laws | automated, `swift test` | `voiceover-elements.md` §10 |
| 8 | AX5 × 5 locales: zero truncation, zero overflow, targets ≥ 44 × 44 | automated | **here**, §4 |
| 9 | Reduce Motion: nothing translates, scales or rotates, including SIEVE; plus the preview/window invariant | automated + manual | `hunch-motion-and-feedback/references/reduce-motion.md` |
| 10 | High Contrast: every pair clears the floor, hue is index-stroke-only, 256 still distinguishable | automated | `hunch-design-tokens/scripts/contrast.swift` + gate 1's harness |
| 11 | audio session category / mode / options; silent switch; other audio never ducked | automated + manual | `hunch-motion-and-feedback/references/audio-cues.md` |
| 12 | admit / reject / `bar` distinguishable face-down by three blind testers | **manual** | `hunch-motion-and-feedback/references/haptic-patterns.md` |
| 13 | nothing claims a cognitive, memory, focus, intelligence or health benefit | lint + **manual** | `hunch-build-and-ci` (`08 §5` check 8's banned lexemes) |

Five gates are manual or partly manual, and that is not a failure of automation — three of them (3, 5, 6) test
VoiceOver's *own* gesture layer, which no harness can synthesise. §5 covers what to do about it.

---

## 2. performAccessibilityAudit

**This is `XCTestCase`, and it has to be.** `performAccessibilityAudit` is a method on `XCUIApplication`, so it needs
the out-of-process XCUITest runner, and Xcode's build system rejects `import Testing` in a UI test target outright
(`06 T43`). `08 §7.10` already ruled that this is not a violation of the brief's "Swift Testing, not XCTest": that rule
governs new *unit* tests, which all live in the two packages.

```swift
// HunchUITests/AccessibilityAuditTests.swift  — the XCUITest bundle at the repo root (see §8)
import XCTest
import XCUIAutomation          // since the Xcode 16 module split, XCUIApplication lives here

final class AccessibilityAuditTests: XCTestCase {
    /// Launched per test, not held as a stored property. `XCUIApplication` is `@MainActor`, and
    /// `XCTestCase.setUp()` is not — so under Swift 6's strict checking a `var app: XCUIApplication!`
    /// populated in `setUp()` is an isolation error. Marking the override `@MainActor` does not fix
    /// it either: an override cannot add isolation the superclass method does not have.
    @MainActor
    private func launchedApp() -> XCUIApplication {
        continueAfterFailure = false                                   // 06 T47
        let app = XCUIApplication()
        app.launchArguments += ["-UITest",                             // installs SeedSource.fixed + Now.fixed
                                "-AppleAnimationsEnabled", "NO"]
        app.launch()
        return app
    }

    @MainActor
    func testFrameIsAccessible() throws {
        try launchedApp().performAccessibilityAudit(for: Self.auditTypes)
    }

    @MainActor
    func testRoundSurfaceIsAccessible() throws {
        let app = launchedApp()
        app.buttons["mode.probe"].tap()
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
            // The ONE accepted exception. `stroke.hairline` is declared never state-bearing
            // (hunch-design-tokens/references/palette.md §1), so a decorative rule sitting below
            // the contrast floor is by design — that file holds the ratio, not this one.
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "decorative.rule"
        }
    }

    static let auditTypes: XCUIAccessibilityAuditType =
        [.contrast, .dynamicType, .elementDetection, .hitRegion,
         .sufficientElementDescription, .trait, .action, .parentChild, .textClipped]
}
```

Four things this shape encodes, all of which have a failure mode that is silent:

- **`issueHandler` returning `true` SUPPRESSES the issue** (`07 B46`). `{ _ in true }` is a test that passes
  unconditionally, forever, and nothing about it looks wrong. When there is no exception to suppress, pass **no
  handler at all** — that is the safe default and it is what `testFrameIsAccessible` does.
- **Suppress by element *and* audit type, never by one alone.** `issue.auditType == .contrast` without the identifier
  check waves through every contrast failure on the screen; the identifier without the type waves through everything
  about that element.
- **The app must be deterministic.** `08 §6` makes `SeedSource` the single point of nondeterminism, in `Modules/`;
  `-UITest` swaps in `SeedSource.fixed` and `Now.fixed` at the composition root. An audit run against a randomly
  generated law is a flaky audit, and a flaky gate gets disabled.
- **Every method that touches `XCUIApplication` is `@MainActor`, and the app is never a stored property.**
  `XCUIApplication` is main-actor-isolated and `XCTestCase.setUp()` is not, so the XCTest-era
  `private var app: XCUIApplication!` + `setUp()` shape does not compile under Swift 6 strict
  concurrency — and the tempting fix, `@MainActor override func setUp()`, is itself an error because
  an override cannot add isolation its superclass method lacks. A `@MainActor` factory method is the
  shape that works, and it also makes each test's launch arguments visible at the call site.

`.all` is available and tempting. Prefer the explicit list: when Apple adds an audit type, `.all` starts failing a
green pipeline on a build nobody changed, and the reflex fix is the blanket `true` handler above.

Accessibility Inspector (`Xcode ▸ Open Developer Tool`) is the exploratory pass and has a Font slider for previewing
Dynamic Type live. `performAccessibilityAudit` is the regression net.

---

## 3. The screen list

Gate 4 says *every screen in §12.2's inventory*. That is eighteen, and §12.3's tap-distance audit guarantees each is at
most two taps from a play surface, so the navigation in each test is one or two lines.

| Screen | Reached by | Note |
|---|---|---|
| `FrameView` | launch with no suspended round | |
| `RoundView` | Frame ▸ PROBE | run it twice: once mid-round, once with the Bench up |
| `EchoRoundView`, `SieveRoundView` | `-UITest` unlocks the mode gates | §9.10's page gates would otherwise bar them |
| `BenchView` | Round ▸ handle | assert the barred Seal is still **discoverable** |
| `AssayInspectorView` | Bench ▸ Assay ▸ "Inspect" | a presented subtree — `04 A25` |
| `InscriptionView` | seal a correct declaration | audit at `.settled`, not mid-reveal |
| `CodexRootView`, `CodexShelfView`, `CodexPageView` | Frame ▸ Codex | seed the Codex from `-UITest` |
| `AnomalyView`, `ProfileView`, `StatisticsView` | Frame ▸ Anomaly / shelf | |
| `SettingsView`, `AboutView`, `ResetConfirmAlert` | Frame ▸ Settings | stock components; the audit is mostly free here |
| `SievePauseOverlay` | SIEVE ▸ pause | assert `.isModal` keeps the frozen lane out of traversal |
| `LaunchSurface` | — | storyboard, ≤ 400 ms, no elements. Not audited |

A new screen without a row here is a gate-4 hole. The cheapest guard is a test that walks the route table and asserts
one audit method exists per reachable screen — the same graph walk `NavigationDepthTests` already does for
`distanceToPlay(screen) ≤ 2` (§12.3).

---

## 4. AX5 × five locales

Gate 8: every screen at AX5 in **English, German, Turkish, Russian and Arabic**, asserting zero truncation and zero
horizontal overflow, with every target still ≥ 44 × 44.

Do not write five copies of the suite. Drive it from a **second test-plan configuration** (`07 B26`), which runs the
whole plan once per configuration and sets Application Language and Region without touching a test file (`07 B40`):

- one configuration per locale, plus **Double Length Pseudolanguage** and **Right to Left Pseudolanguage** — §12.9
  makes pseudolocalization a gate, not a courtesy, and RTL is where the mirroring rules of §12.8 are actually checked
  (chrome mirrors; glyph bodies, index strokes and pip positions do not);
- Dynamic Type is set per-configuration too, so AX5 is a plan setting rather than a launch argument someone forgets.

Cost is linear: five locales × two directions is ten full runs, so this plan is **not** the presubmission plan (§7).

The mirroring assertions worth writing by hand, because the audit cannot see them: in Arabic, the instrument-bar key
order and the commit-bar order reverse, and the index stroke's rotation does **not** — mirroring 45° and 135° swaps
`teal` and `rose`, which is a two-hue data corruption dressed as a layout bug.

---

## 5. What XCUITest cannot see, and the lint that covers it

XCUITest drives the app **through** the accessibility layer, so it can read labels, values and traits — and it cannot
synthesise VoiceOver's own gestures. There is no way to perform a Magic Tap, a two-finger scrub or a rotor turn from a
UI test, and custom actions are not exposed on `XCUIElement`. Gates 5 and 6 are therefore manual.

The cheap mechanical net is a **source lint**, appended to `Scripts/check-source-hygiene.sh` beside `08 §5`'s existing
checks. It cannot prove the gestures work; it proves the code that implements them still exists, which is the
regression that actually happens:

```bash
# check 11 — the accessibility surface that no test can reach.
count() { grep -Rho "$1" Modules/Sources --include='*.swift' | wc -l | tr -d ' '; }

[ "$(count 'accessibilityAction(\.magicTap)')" = "2" ] || fail "expected exactly 2 magic-tap handlers (Dial, Bench)"
[ "$(count 'accessibilityAction(\.escape)')"   = "2" ] || fail "expected exactly 2 escape handlers (Bench, Assay inspector)"
[ "$(count 'accessibilityRotor(')"             = "4" ] || fail "expected exactly 4 rotors (§12.8 fixes the set at four)"
grep -Rq 'accessibilitySortPriority' Modules/Sources && fail "sort priority is not used in HUNCH — voiceover-elements.md §12"
grep -Rq '{ _ in true }' HunchUITests && fail "an audit handler that suppresses everything (07 B46)"
```

The counts are the point. A fifth rotor, a deleted Magic Tap and a third escape all fail loudly, and each of those is a
change a reviewer would otherwise wave through as harmless.

`Scripts/check-source-hygiene.sh` is `hunch-build-and-ci`'s file; this is the block that belongs to this skill, and it
runs as an Xcode run-script phase **and** in CI so it cannot be skipped locally.

---

## 6. The manual gates

Four passes, on device, before an archive. Each has a written script so it is repeatable by someone who did not write
the feature.

1. **Gate 3 — curtain on, band 5, end to end.** The script is `rotors-and-gestures.md` §7, sixteen gestures. Triple-tap
   three fingers to toggle the screen curtain. A step that needs a peek is a failure, not a note.
2. **Gate 5 — Magic Tap and escape.** Two fingers double-tap on the Dial fires a probe; the same on the Bench fires the
   Seal, *including* when the Seal is barred, where it must announce the bar rather than do nothing. Two-finger scrub
   closes the Bench, then the expanded Assay, and does **not** leave the round.
3. **Gate 6 — the four rotors.** Rotate to each; confirm "Counterexample" is **absent** before the first strike and
   present after it, with exactly two stops.
4. **Gate 12 — haptics face-down.** Three testers who were not told which is which distinguish admit (one soft),
   reject (two sharp) and `bar` (one blunt heavy). Owned by `hunch-motion-and-feedback`; listed here because it is a
   release gate and gets forgotten.

Record the result in `PROGRESS.md` with the build number. A manual gate with no record is a manual gate that stopped
being run three releases ago.

---

## 7. Plans and cadence

Three plans exist (`08 §1`): `Presubmission`, `Nightly`, `Prerelease`, named after the cadence tag (`07 B24`).

| Suite | Plan | Why |
|---|---|---|
| narration parity, 10,000 laws | **Presubmission** | `swift test`, no simulator, inside the 10 s budget (`08 §5`) |
| `RenderEnv` arithmetic, greyscale distinctness | **Presubmission** | value tests |
| `AccessibilityAuditTests` | **Nightly** and **Prerelease** | XCUITest needs a simulator and a full launch per screen |
| AX5 × 5 locales × 2 directions | **Prerelease** | ten full runs; `07 B26`'s cost is linear |
| the four manual gates | **Prerelease**, by hand | §6 |

`07 B24` drives Swift Testing membership with tags; **XCTest membership is by target and class selection in the plan**,
not by tags, so the XCUITest bundle is included in two plans and excluded from `Presubmission` explicitly. The CI
workflow that runs them belongs to `hunch-build-and-ci` — with one warning that is this skill's business: `set -o
pipefail` before piping `xcodebuild` into a formatter (`07 B31`). An audit whose handler suppresses everything already
cannot fail; a swallowed exit code makes it fail invisibly twice over.

---

## 8. Two target names that collide

`08 §1` puts a `HunchUITests` under `Modules/Tests/` **and** a `HunchUITests/` at the repo root. They are different
things:

| Path | What it is | Framework | Runs on |
|---|---|---|---|
| `Modules/Tests/HunchUITests/` | unit tests for the `HunchUI` **module** — token arithmetic, `ImageRenderer` rasters, snapshot rows | Swift Testing | the host, via `swift test` |
| `HunchUITests/` (repo root) | the XCUITest bundle — accessibility audit, screenshots in en/de/ar | XCTest | a simulator |

They do not collide in the build system — one is a SwiftPM test target, the other an Xcode target — but they collide in
every conversation, every `grep`, and every instruction that says "put it in HunchUITests". **Always write the full
path.** Gate 1's greyscale raster test is `Modules/Tests/HunchUITests/`; gate 4's audit is `HunchUITests/`. If the
ambiguity ever causes a test to be written into the wrong target, rename the XCUITest bundle to `HunchAppUITests` and
record it in `DECISIONS.md` — that is a naming change, so it belongs there and not in a comment.

---

## 9. What would be wrong

- **`issueHandler: { _ in true }`.** `07 B46`: returning `true` *suppresses* the issue, so this is a test that passes
  unconditionally and forever, and nothing about it looks wrong. When there is no exception to suppress, pass **no
  handler at all**. Check 11's `grep -Rq '{ _ in true }' HunchUITests` exists because review does not catch it.
- **Suppressing by audit type alone, or by element alone.** §2. The first waves through every contrast failure on the
  screen; the second waves through everything about that element.
- **`for: .all`.** §2. Apple adding an audit type then fails a green pipeline on a build nobody changed, and the reflex
  fix is the blanket handler above.
- **`import Testing` in the XCUITest bundle,** or a `@Test` function beside an `XCTestCase`. Xcode's build system
  rejects the first outright (`06 T43`) and `06 T44` bans the second. `08 §7.10` already ruled this is not a brief
  violation.
- **A stored `XCUIApplication` property populated in `setUp()`.** §2. It does not compile under Swift 6 strict
  concurrency, and the obvious repair — `@MainActor` on the `setUp()` override — is a second error.
- **An audit run against a randomly generated law.** §2. `-UITest` installs `SeedSource.fixed` and `Now.fixed`; a flaky
  gate is a gate that gets disabled.
- **A new screen with no row in §3.** That is a gate-4 hole, and the cheapest guard is the route-table walk described
  there rather than a reviewer remembering.
- **Five copies of the suite, one per locale.** §4. It is one plan with a configuration per locale (`07 B26`, `07 B40`),
  plus the two pseudolanguages — and the AX5 category is a plan setting, not a launch argument someone forgets.
- **Putting the AX5 × locale matrix in the presubmission plan.** §4, §7. Ten full runs; it is a `Prerelease` plan.
- **Asserting that the index stroke mirrors under RTL.** §4. Mirroring 45° and 135° swaps `teal` and `rose` — a two-hue
  data corruption dressed as a layout bug. Chrome mirrors; glyph bodies, index strokes and pip positions do not.
- **Treating gates 3, 5, 6 and 12 as automatable.** §5. XCUITest drives the app *through* the accessibility layer and
  cannot synthesise VoiceOver's own gestures; custom actions are not exposed on `XCUIElement` at all. The source lint
  proves the code still exists, never that the gesture works.
- **Changing one of check 11's counts to make it pass.** §5. The counts *are* the assertion — a fifth rotor, a deleted
  Magic Tap and a third escape each look harmless in a diff.
- **Piping `xcodebuild` into a formatter without `set -o pipefail`.** §7. A swallowed exit code makes an audit fail
  invisibly, on top of a handler that may already have made it unable to fail at all.
- **Writing "put it in HunchUITests" without the full path.** §8. Two targets share the name; gate 1's raster test and
  gate 4's audit go in different ones.
- **A manual gate with no record in `PROGRESS.md`.** §6. That is a manual gate that stopped being run three releases
  ago.
