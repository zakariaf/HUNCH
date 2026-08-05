# T09 — The pseudolocalization gate and screenshots

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | LOCALIZATION → Pseudolocalization gate; VERIFICATION → Localization tests (the visual half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns the three `.xctestplan` files and their **configurations**, and E01·T07 already created the two this task activates: `Nightly`'s **RTL** (Right-to-Left Pseudolanguage) and **Double Length** (Double Length Pseudolanguage). `references/ci-workflow.md` §4 is the plan table and §5 the nightly file; the skill also owns the `--only-test-configuration` invocation and the reminder that `HunchAutomationTests` joins a plan by **target membership**, never by tag, because XCUITest has no Swift Testing path. |
| `hunch-chrome-and-meta` | Every defect this sweep finds is on a chrome or archive surface — the play surfaces render nothing to truncate. It owns the resolved bar height (`SKILL.md`'s first gotcha: 64 pt is a reference number and the bar grows when a localized title wraps), the stock `Form` container, and the rule that text grows while art does not. |

## Objective

At the end of this task every one of the eighteen screens has been rendered under an accented,
expanded pseudolocale and under forced right-to-left, with zero truncation and zero horizontal
overflow asserted mechanically; and fifty-four screenshots — eighteen screens × English, German and
Arabic — have been captured, exported, **looked at by a person**, and every visible defect fixed on
this branch rather than filed.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 trap 8 | *"Pseudolocalization is a gate, not a courtesy."* Every screen under accented + expanded pseudo-language and under `-AppleTextDirection YES` **before it is called finished**; simulator screenshots in English, German and Arabic |
| `GAME_DESIGN.md` | §12.9 trap 2 | rows grow vertically; nothing truncates and nothing scales down — which is what makes truncation a mechanical test rather than a judgement |
| `GAME_DESIGN.md` | §12.8 | `minimumScaleFactor` 1.0 everywhere, `lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`; every target ≥ 44 × 44 |
| `GAME_DESIGN.md` | §12.2 | the eighteen screens, by name, with their entry points — the sweep's worklist |
| `GAME_DESIGN.md` | §14.6 risk 8 | the named early signal: *"German or Russian Settings rows wrapping to three lines at AX3"* |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B26`, `B40` | plan configurations, and pseudolanguages as the cheapest RTL and truncation coverage there is |
| `ios-swift-guide/06-TESTING.md` | `T43` | XCUITest is `XCTestCase` and always will be |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchAutomationTests/PseudolocaleSweepTests.swift`. It is `XCTestCase` in the XCUITest bundle —
`06 T43`, and E01·T02 renamed the wizard's target to `HunchAutomationTests` precisely so this file
has an unambiguous home:

```swift
import XCTest

/// §12.9 trap 8, as a gate. The plan configuration supplies the pseudolanguage (E01·T07 created
/// `Nightly`'s RTL and Double Length configurations); this file supplies the sweep and the two
/// mechanical defect detectors. Nothing here reads a string's content — the assertions are about
/// geometry and about the ellipsis, both of which survive translation.
final class PseudolocaleSweepTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true          // one screen's defect must not hide the next seventeen
        app = XCUIApplication()
        app.launchArguments += ["-HunchUITestSeed", "0xC0FFEE"]
        app.launch()
    }

    /// The eighteen screens of §12.2, each reached by its own navigation, each asserted twice.
    func testEveryScreenSurvivesTheExpandedPseudolocale() throws {
        for screen in ScreenWalk.all {
            XCTContext.runActivity(named: screen.name) { _ in
                screen.navigate(app)
                assertNothingTruncates(on: screen.name)
                assertNothingOverflowsHorizontally(on: screen.name)
                assertEveryTargetIsBigEnough(on: screen.name)
                screen.dismiss(app)
            }
        }
    }

    // MARK: - The three detectors

    /// `minimumScaleFactor` is 1.0 everywhere and rows grow rather than shrink (§12.8), so SwiftUI
    /// truncates with U+2026 when a container refuses to grow. A horizontal ellipsis in a label is
    /// therefore a defect with no false positives — no shipped string contains one.
    private func assertNothingTruncates(on screen: String, file: StaticString = #filePath,
                                        line: UInt = #line) {
        let truncated = app.descendants(matching: .any).allElementsBoundByIndex
            .filter { $0.exists && ($0.label.contains("\u{2026}") || $0.label.hasSuffix("...")) }
        XCTAssertEqual(truncated.map(\.label), [],
                       "\(screen): truncated labels", file: file, line: line)
    }

    /// A row that grows vertically is correct; a row that grows sideways is a layout that used a
    /// fixed width. The window is the bound, and the body must never scroll horizontally.
    private func assertNothingOverflowsHorizontally(on screen: String, file: StaticString = #filePath,
                                                    line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let overflowing = app.descendants(matching: .any).allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty }
            .filter { $0.frame.minX < window.minX - 0.5 || $0.frame.maxX > window.maxX + 0.5 }
        XCTAssertEqual(overflowing.map(\.identifier), [],
                       "\(screen): elements outside the window", file: file, line: line)
    }

    /// §12.8's floor. An expanded label pushing a control below 44 pt is the second most common
    /// pseudolocale defect after truncation, and it is invisible in a screenshot.
    private func assertEveryTargetIsBigEnough(on screen: String, file: StaticString = #filePath,
                                             line: UInt = #line) {
        let tooSmall = app.buttons.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .filter { $0.frame.height < 44 || $0.frame.width < 44 }
        XCTAssertEqual(tooSmall.map(\.identifier), [],
                       "\(screen): targets under 44 pt", file: file, line: line)
    }
}
```

and `HunchAutomationTests/LocalizedScreenshotTests.swift`:

```swift
import XCTest

/// §12.9 trap 8's second half. Eighteen screens × three locales = 54 attachments, exported so a
/// person can look at them. This test asserts almost nothing on purpose: its output is evidence,
/// and the review is the gate.
final class LocalizedScreenshotTests: XCTestCase {

    func testCaptureEverythingInEnglishGermanAndArabic() throws {
        for locale in ["en", "de", "ar"] {
            let app = XCUIApplication()
            app.launchArguments += ["-AppleLanguages", "(\(locale))",
                                    "-AppleLocale", locale,
                                    "-HunchUITestSeed", "0xC0FFEE"]
            app.launch()

            for screen in ScreenWalk.all {
                screen.navigate(app)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "\(locale)-\(screen.name)"
                shot.lifetime = .keepAlways          // the default deletes on success — useless here
                add(shot)
                screen.dismiss(app)
            }
            app.terminate()
        }
    }
}
```

and the worklist they share, `HunchAutomationTests/ScreenWalk.swift` — one entry per §12.2 screen,
each with the taps that reach it and the taps that leave it.

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Nightly \
  --only-test-configuration 'Double Length' \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchAutomationTests/PseudolocaleSweepTests
```

Note Apple's inconsistent dashes: `-testPlan` takes one, `--only-test-configuration` takes two.

It must fail on **real defects**, and it will: a German Settings row wrapping to three lines is
§14.6's named early signal and the doubled pseudolocale is twice as long as German. If it fails
because `ScreenWalk` cannot reach a screen, fix the walk — that is not a defect, it is the harness.
If it reports zero elements on every screen, the app did not launch; check the seed argument against
E10·T01's `SeedSource`.

**Step 3 — implement**: fix every defect the sweep finds. That is the task. The test is written once
and then the work is in `Modules/Sources`.

**Step 4 — green, then refactor.** Run all four configurations, capture the 54 screenshots, and do
the review.

## Files

| Action | Path |
|---|---|
| create | `HunchAutomationTests/PseudolocaleSweepTests.swift` |
| create | `HunchAutomationTests/LocalizedScreenshotTests.swift` |
| create | `HunchAutomationTests/ScreenWalk.swift` |
| modify | `Modules/Sources/MetaFeature/*.swift`, `Modules/Sources/CodexFeature/*.swift` — every defect the sweep finds |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — any English shortened rather than a layout bent around it |
| modify | `.github/workflows/nightly.yml` — export the attachments as an artifact |
| modify | `Nightly.xctestplan` — `HunchAutomationTests` selected in the two pseudolanguage configurations |
| modify | `tests.json` — three entries (truncation, horizontal overflow, target floor) |
| modify | `PROGRESS.md` — the sweep result and the screenshot review, defect by defect |

## Implementation notes

### The two configurations already exist

E01·T07 created `Nightly.xctestplan` with four configurations: **Default**, **RTL** (Application
Language = Right-to-Left Pseudolanguage), **Double Length** (Double Length Pseudolanguage) and
**Calibration**. Its own note says they *"assert nothing in E01 and everything from E18 onward"* —
this is that moment. The work here is not creating them; it is **selecting `HunchAutomationTests`
into them and making the assertions real**.

§12.9 asks for accented **plus** expanded. Xcode's "Double Length Pseudolanguage" gives expansion;
the accented variant is the separate "Accented Pseudolanguage". Check what the plan actually offers
before assuming:

```bash
xcodebuild -scheme Hunch -showTestPlans
xcodebuild -scheme Hunch test -testPlan Nightly --only-test-configuration 'Double Length' --dry-run
```

If the plan carries only the doubled variant, add the accented one as a fifth configuration in the
same commit — accents are what catch a font that lacks a glyph and a line height computed from an
ASCII sample, and doubling is what catches truncation. Both are needed and each finds what the other
does not. Record which configurations exist afterwards in `PROGRESS.md`.

`-AppleTextDirection YES` is the RTL configuration's mechanism, and it is deliberately a **different
path** from T05's in-session override: it forces the *process* direction, which is what a real
right-to-left device does and what App Review will see, and it exercises the code that reads
`\.layoutDirection` from the environment rather than from `LanguageResolution`. Both must work; only
one is testable in-process.

### Why the detectors are geometric

Nothing in this sweep reads a string's meaning, and that is what makes it survive twelve languages
and a pseudolocale:

- **The ellipsis is a defect with no false positives.** `minimumScaleFactor` is 1.0 everywhere and
  nothing in the catalog contains U+2026 (assert that once in `EnglishCopyTests` if it is not
  already true), so a horizontal ellipsis in an accessibility label means SwiftUI truncated.
- **The window is the horizontal bound.** *"Wide content must scroll inside its own container; the
  body must never scroll horizontally"* is the rule, and an element whose frame leaves the window
  has broken it. The half-point tolerance absorbs `.strokeBorder`'s inset arithmetic.
- **44 pt is §12.8's floor** and an expanded label is the most common way a control loses it.

`continueAfterFailure = true` matters more here than anywhere else in the repo: the point of a sweep
is the *list*, and a run that stops at screen 3 costs seventeen more runs to enumerate.

### `ScreenWalk` — the eighteen screens

One value per §12.2 screen, holding its name, the taps that reach it and the taps that leave it.
Four need special handling and each is stated in §12.2:

| Screen | Reaching it |
|---|---|
| `LaunchSurface` (1) | it is a storyboard shown for ≤ 400 ms; capture it by screenshotting immediately after `launch()` and before the first `waitForExistence` |
| `RoundView` (3), `EchoRoundView` (4), `SieveRoundView` (5), `BenchView` (6), `AssayInspectorView` (7) | reachable only mid-round. The seeded launch argument opens a deterministic round; the play surfaces carry **no text at all**, so the truncation detector will find nothing there — which is the correct result and must still be *run*, because the instrument bar and the pause overlay are chrome |
| `InscriptionView` (8) | needs a round played to a declaration. Drive it with the fixed opening round (E10·T05) rather than a generated one — it is the same law every time |
| `ResetConfirmAlert` (17), `SievePauseOverlay` (18) | presentations. They are the two screens most likely to still be in the old language or the old direction (`04 A25`), so they must be in the walk, not skipped as "just an alert" |

If a screen cannot be reached deterministically, that is a finding about the app, not a reason to
drop it from the list. Record it in `PROGRESS.md` and reach it with a launch argument instead.

### The screenshot review — the part that is not a test

Fifty-four images, exported by the nightly workflow as an artifact:

```yaml
- name: Export localized screenshots
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: localized-screenshots
    path: '**/*.xcresult'
```

Then open them and look, in this order, because it is the order in which defects hide:

1. **German first**, because it is the longest of the three and every truncation the mechanical
   detector missed (an image clipped rather than a label ellipsised) is visible here.
2. **Arabic second**, and check the four things §12.8's table names: the instrument-bar key order,
   the commit bar order, the Bench handle side, and the Codex grid's reading order. Then check the
   two that must **not** have mirrored: any glyph, and the Codex plate's internal rule-tile layout.
3. **English last**, as the control. A defect visible in English is a defect this epic did not
   introduce and is still this epic's to fix if it is a text defect.

§12.9's wording is *"actually looked at, with the visible defects fixed rather than logged"*. So:
every defect gets a line in `PROGRESS.md` with the screen, the locale, what was wrong and the commit
that fixed it. A defect deferred to E19 or E20 needs a `DECISIONS.md` entry saying why, and "it is
cosmetic" is not a reason — §12.9 calls this a gate.

### The two fixes to reach for, in order

When a row will not fit, the fix is almost always one of two things, and they are not equivalent:

1. **Let it grow.** `lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`, no
   `minimumScaleFactor`, and a container that does not pin a height. §12.8: *"If a row cannot fit,
   the row grows."* This is the fix nine times out of ten.
2. **Shorten the English.** If German at +40 % still does not fit after the row is allowed to grow,
   the English string is too long and T02's budget was optimistic for that row. Change the English,
   and re-run T03's `translationsStayInsideTheLengthBudget` — eleven translations now have a
   different budget, and one of them will fail.

What is **not** a fix: `minimumScaleFactor(0.8)`, `lineLimit(1)`, a smaller type role, or a
`.truncationMode`. All four are forbidden by §12.8 and §13.4 and all four make the gate green while
making the product worse.

### Closing the epic

This is the last task, so it also carries the epic's bookkeeping: `tests.json` fully updated with
every entry E18 shipped and the brief's invariant 5 marked `pass`; `PROGRESS.md` carrying the sweep,
the review and the manual Arabic run from T05; and `DECISIONS.md` carrying all six of the epic's
decisions. Check them off against the epic's Definition of done before opening the PR.

## Acceptance criteria

- [ ] `xcodebuild test -testPlan Nightly --only-test-configuration 'Double Length' -only-testing:HunchAutomationTests/PseudolocaleSweepTests` green across all eighteen screens.
- [ ] The same, `--only-test-configuration RTL`, green.
- [ ] The same, for the accented configuration — added in this task if `-showTestPlans` shows it is absent — green.
- [ ] `xcodebuild test -testPlan Nightly -only-testing:HunchAutomationTests/LocalizedScreenshotTests` produces **54** attachments, and `xcrun xcresulttool get test-results` lists all of them.
- [ ] `PROGRESS.md` lists every defect the sweep and the review found, each with screen, locale, description and fixing commit; and states explicitly that no defect was deferred, or names the `DECISIONS.md` entry for each that was.
- [ ] `grep -rn 'minimumScaleFactor\|lineLimit(1)\|truncationMode' Modules/Sources` returns nothing.
- [ ] `Nightly.xctestplan` selects `HunchAutomationTests` in every pseudolanguage configuration, and `nightly.yml` uploads the results artifact with `if: always()`.
- [ ] `tests.json` carries the three sweep entries, and every other E18 entry is present and `pass`.
- [ ] `bash Scripts/check-source-hygiene.sh` and `swift Scripts/check-banned-lexemes.swift …` both green after every fix.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T09: the pseudolocale sweep over 18 screens, en/de/ar screenshots, and the defects they found"`

## Out of scope

- **`performAccessibilityAudit` on the same eighteen screens** — **E19·T11**. It joins the same
  bundle and the same plan; it is a different audit with different findings, and running both here
  would make one epic's PR unreviewable.
- **The AX5 × 5-locale snapshot** — **E19·T11**. This sweep runs at the default type size; the type
  axis is E19's.
- **The wordless App Store screenshots** — **E20·T11**. Those are marketing artifacts and are
  deliberately wordless; these 54 are review evidence and are deliberately not.
- **The `Nightly` plan's Calibration configuration and the Level-B matrix** — **E01·T07**,
  **E11·T11**.
- **Any defect that is a *drawing* rather than a *layout* problem** — it goes back to the owning
  epic's skill and task, named in `PROGRESS.md`, and is fixed there rather than patched here.
