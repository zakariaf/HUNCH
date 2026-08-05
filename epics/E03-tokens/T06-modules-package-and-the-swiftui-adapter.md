# T06 — `Modules` package and the SwiftUI adapter

| | |
|---|---|
| **Epic** | E03 — Design tokens and RenderEnv |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04, T05 |
| **Delivers** | §14.1 *Palette tokens* (the application half) · *Typography* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | It owns the adapter. `references/render-env.md` §4 is `RenderEnvReader` and the three-line colour conversion with `.sRGB` pinned and the four things that are easy to get wrong; `references/durations-and-easing.md` §§1, 3 are `Duration.seconds` and `Easing.animation(for:)`; `references/type-ramp.md` §§2–5 are what `Typography.swift` applies and §6 is the zero-text rule it must never reach the play surface with. |
| `hunch-swift-code` | Six new files across a package boundary: `package` access does not cross it so everything is `public`; `InternalImportsByDefault` means a `public` signature needs a `public import`; `P24`/`P28` govern the file names; and `N39`/`N45` govern what the adapter may not be called. |
| `hunch-build-and-ci` | It owns both manifests, the hygiene script and the workflow. `references/package-manifests.md` §3 is `Modules/Package.swift` and §7 is the import-visibility rule; `references/source-hygiene.md` §§3–4 are the conventions a new check must follow and the drill that proves one can fail; `references/ci-workflow.md` §3 is where the token steps are wired. |

## Objective

The second package exists with its first target, and the token layer reaches SwiftUI through
exactly four small files that are the only code in the repository knowing SwiftUI exists: a colour
conversion with `.sRGB` pinned, a `Duration` → seconds conversion, an `Easing` → `Animation` map,
and the `RenderEnvReader` that builds the seven-axis record from the system's own accessibility
state. `Typography.swift` applies the seven type roles with per-role Dynamic Type scaling and
locale-aware uppercasing, and checks 9, 10 and a new check 11 are proved — by planting a violation
and watching the build fail — to make the literal ban and the L2 → L1 → L0 direction mechanical.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.2 | theme selection: System / Dark / Light / High Contrast, default System, and `isDarkerSystemColorsEnabled` forcing High Contrast **only** when the player has made no explicit choice |
| `GAME_DESIGN.md` | §13.4 | the seven roles, `relativeTo:` per role, tracking applied as `scaledSize × em`, `minimumScaleFactor` 1.0 everywhere, `String.uppercased(with: locale)` |
| `GAME_DESIGN.md` | §13.11 | the accessibility state the reader has to read: Reduce Transparency, Bold Text, Differentiate Without Colour, Dynamic Type |
| `design/DESIGN-SYSTEM-SCOPE.md` | §4.2, §4.4 item 5 | the "~30-line adapter, the only file that knows SwiftUI exists"; drift prevented by a grep, not a generator |
| `hunch-design-tokens/references/render-env.md` | §4 | `RenderEnvReader` in full, the `.sRGB` pin, and the four traps: there is no `\.accessibilityBoldText`; `@ScaledMetric` *is* the multiplier; `isDarkerSystemColorsEnabled` and `isLowPowerModeEnabled` are passed in; preference beats system state |
| `hunch-design-tokens/references/tokens-swift-layout.md` | §5, §6.1 | what the adapter contains; checks 9 and 10 verbatim |
| `hunch-build-and-ci/references/package-manifests.md` | §3, §4, §5, §7 | the manifest, how to add a target, the iOS-only floor and why `Modules` is never host-built, and import visibility |
| `hunch-build-and-ci/references/source-hygiene.md` | §1, §3, §4 | where checks 9–10 are pasted from, the conventions check 11 must follow, and the proof-of-failure drill |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P9`, `P35` | `App/` imports one module; `defaultLocalization` is required by the String Catalog |
| `ios-swift-guide/05-CONCURRENCY.md` | `R8` | every declaration visible outside its own file states its isolation explicitly, even under `.defaultIsolation` |

## TDD — the test comes first

**Step 1 — write the failing tests.** Four suites plus the tag declarations, all under
`Modules/Tests/HunchUITests/`. These run in the **simulator** under `xcodebuild test`, not under
`swift test`: `Modules` is iOS-only and is never host-built.

Create `Modules/Tests/HunchUITests/Tags.swift`:

```swift
import Testing

// The eight-tag vocabulary is declared once per *package* (06 T29, T30). `HunchTestSupport` is
// absent from HunchCore's products:, so Modules cannot import it and mirrors the declarations
// here. When a second Modules test target appears (E10), lift these into a ModulesTestSupport
// target — not before (01 P12).
extension Tag {
    @Tag static var unit: Self
    @Tag static var presubmission: Self
}
```

Create `Modules/Tests/HunchUITests/RGB8ColorTests.swift`:

```swift
import SwiftUI
import Testing

import Tokens
import HunchUI

@Suite("The colour adapter", .tags(.unit, .presubmission))
@MainActor
struct RGB8ColorTests {

    /// `.sRGB` is not a preference. Every ratio in `palette.md` is sRGB relative luminance, and a
    /// Display P3 constructor with the same three numbers produces a different colour and moves
    /// all of them — with nothing in `HunchCore` able to notice, because `HunchCore` has no
    /// colour space. This is the assertion that makes the one-word difference falsifiable.
    ///
    /// The colour is reached through `Palette`, not through `Prim`: check 11 forbids an L0
    /// primitive anywhere under `Modules/`, and a test is not an exception.
    @Test("the adapter pins sRGB and is not Display P3")
    func adapterPinsSRGB() {
        let environment = EnvironmentValues()
        let amber = Palette(theme: .dark).hue.amber.rgb
        let channels = (
            red: Double(amber.red) / 255,
            green: Double(amber.green) / 255,
            blue: Double(amber.blue) / 255
        )
        let adapted = amber.color.resolve(in: environment)
        let sRGB = Color(.sRGB, red: channels.red, green: channels.green, blue: channels.blue)
            .resolve(in: environment)
        let displayP3 = Color(
            .displayP3, red: channels.red, green: channels.green, blue: channels.blue
        ).resolve(in: environment)

        #expect(adapted == sRGB)
        #expect(adapted != displayP3)
    }

    /// Both registers convert, and neither acquires a way to become the other: `.color` reads
    /// `rgb` and there is still no public initialiser on either struct.
    @Test("both registers convert through the same three lines")
    func bothRegistersConvert() {
        let environment = EnvironmentValues()
        let palette = Palette(theme: .dark)
        #expect(palette.accent.brass.color.resolve(in: environment)
            == palette.accent.brass.rgb.color.resolve(in: environment))
        #expect(palette.hue.teal.color.resolve(in: environment)
            == palette.hue.teal.rgb.color.resolve(in: environment))
    }
}
```

Create `Modules/Tests/HunchUITests/MotionAdapterTests.swift`:

```swift
import SwiftUI
import Testing

import Tokens
import HunchUI

@Suite("The motion adapter", .tags(.unit, .presubmission))
@MainActor
struct MotionAdapterTests {

    /// The single place milliseconds become seconds. `Duration` exists so that a bare `260`
    /// is never ambiguous; this is where the ambiguity would come back if the division moved.
    @Test("Duration converts to seconds exactly once")
    func durationConvertsToSeconds() {
        #expect(abs(Dur.admit.seconds - 0.26) < 1e-12)
        #expect(abs(Dur.reveal.seconds - 1.84) < 1e-12)
        #expect(abs(Duration.seconds(2).seconds - 2.0) < 1e-12)
    }

    /// Each case maps to its own animation kind. A spring ignores the duration argument by
    /// design — SwiftUI derives its own from `response` — which is why `ease.snap` and friends
    /// carry no companion duration token.
    @Test("each easing maps to its own SwiftUI animation")
    func easingsMapDistinctly() {
        #expect(Easing.linear.animation(for: Dur.tap) == .linear(duration: Dur.tap.seconds))
        #expect(Easing.easeOut.animation(for: Dur.tap) == .easeOut(duration: Dur.tap.seconds))
        #expect(Easing.linear.animation(for: Dur.tap) != Easing.easeIn.animation(for: Dur.tap))
        #expect(Easing.snap.animation(for: Dur.tap) != Easing.settle.animation(for: Dur.tap))
    }
}
```

Create `Modules/Tests/HunchUITests/ThemePreferenceTests.swift`:

```swift
import SwiftUI
import Testing

import Tokens
import HunchUI

@Suite("Theme selection", .tags(.unit, .presubmission))
@MainActor
struct ThemePreferenceTests {

    @Test("System follows the colour scheme")
    func systemFollowsColorScheme() {
        #expect(ThemePreference.system.theme(
            colorScheme: .dark, isDarkerSystemColorsEnabled: false) == .dark)
        #expect(ThemePreference.system.theme(
            colorScheme: .light, isDarkerSystemColorsEnabled: false) == .light)
    }

    /// §13.2: Increase Contrast forces High Contrast **only** when the player has made no
    /// explicit choice. A player who chose Light and then turned on Increase Contrast has made
    /// a choice, and overriding it is how a preference becomes a suggestion.
    @Test("Increase Contrast forces High Contrast only when nothing was chosen")
    func darkerSystemColorsOnlyOverridesSystem() {
        #expect(ThemePreference.system.theme(
            colorScheme: .light, isDarkerSystemColorsEnabled: true) == .highContrast)
        #expect(ThemePreference.light.theme(
            colorScheme: .dark, isDarkerSystemColorsEnabled: true) == .light)
        #expect(ThemePreference.dark.theme(
            colorScheme: .light, isDarkerSystemColorsEnabled: true) == .dark)
        #expect(ThemePreference.highContrast.theme(
            colorScheme: .light, isDarkerSystemColorsEnabled: false) == .highContrast)
    }

    @Test("there are four preferences and three themes")
    func vocabularySizes() {
        #expect(ThemePreference.allCases.count == 4)
        #expect(RenderEnv.Theme.allCases.count == 3)
    }
}
```

Create `Modules/Tests/HunchUITests/TypographyTests.swift`:

```swift
import SwiftUI
import Testing

import Tokens
import HunchUI

@Suite("Typography — applying the seven roles", .tags(.unit, .presubmission))
@MainActor
struct TypographyTests {

    /// Turkish dotted-I is the shipped bug this rule exists to prevent: the naive path maps
    /// `i → I`, and HUNCH ships twelve localisations, so it will occur.
    @Test("uppercasing is locale-aware and applies only to the two uppercased roles")
    func uppercasingIsLocaleAware() {
        let turkish = Locale(identifier: "tr_TR")
        #expect(Typography.cased("istanbul", role: .section, locale: turkish) == "İSTANBUL")
        #expect(Typography.cased("istanbul", role: .micro, locale: turkish) == "İSTANBUL")
        #expect(Typography.cased("istanbul", role: .body, locale: turkish) == "istanbul")
        #expect(Typography.cased("istanbul", role: .section, locale: Locale(identifier: "en_US"))
            == "ISTANBUL")
    }

    /// Arabic is caseless; a transform must return the string unchanged rather than mangling
    /// shaping. `uppercased(with:)` already does — this asserts we did not add a fallback.
    @Test("a caseless script is untouched")
    func caselessScriptsAreUntouched() {
        let arabic = Locale(identifier: "ar")
        #expect(Typography.cased("مثال", role: .section, locale: arabic) == "مثال")
    }

    @Test("the four token weights map onto the four Font weights")
    func weightMappingIsTotal() {
        #expect(Typography.fontWeight(.regular) == .regular)
        #expect(Typography.fontWeight(.medium) == .medium)
        #expect(Typography.fontWeight(.semibold) == .semibold)
        #expect(Typography.fontWeight(.bold) == .bold)
    }

    /// The role's `size` is the value at Large and is never multiplied by hand; the per-role
    /// `relativeTo:` metric is what scales it, and tracking is derived from the result.
    @Test("tracking is computed from the scaled size, not the token size")
    func trackingFollowsTheScaledSize() {
        let role = TypeRole.micro
        #expect(Typography.tracking(for: role, scaledSize: role.size)
            == role.size * role.trackingEm)
        #expect(Typography.tracking(for: role, scaledSize: role.size * 2.6)
            > Typography.tracking(for: role, scaledSize: role.size))
        #expect(Typography.tracking(for: .body, scaledSize: 100) == 0)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
UDID=$(xcrun simctl list devices available --json | /usr/bin/python3 -c \
  'import json,sys; print(next(d["udid"] for v in json.load(sys.stdin)["devices"].values() for d in v))')
xcodebuild test -scheme Hunch -testPlan Presubmission -destination "id=$UDID" | xcbeautify
```

The first failure is the manifest: there is no `Modules` package, so the scheme cannot resolve
`HunchUI` at all. That is the right first failure. After the package exists, expect
`cannot find 'Typography' in scope` and `value of type 'RGB8' has no member 'color'`. If the run
reports **green over zero tests**, the test plan's include-tags name a tag nobody declared
(`07 B24`) — fix `Tags.swift` and the plan before writing a line of source.

**Step 3 — implement**, in this order: the manifest, then `ThemePreference`, then the three
conversions, then `RenderEnvReader`, then `Typography`.

**Step 4 — green, then switch the greps on** (the drill below), then wire CI.

## Files

| Action | Path |
|---|---|
| create | `Modules/Package.swift` |
| create | `Modules/Sources/HunchUI/ThemePreference.swift` |
| create | `Modules/Sources/HunchUI/RGB8+Color.swift` |
| create | `Modules/Sources/HunchUI/Duration+Seconds.swift` |
| create | `Modules/Sources/HunchUI/Easing+Animation.swift` |
| create | `Modules/Sources/HunchUI/RenderEnvReader.swift` |
| create | `Modules/Sources/HunchUI/Typography.swift` |
| create | `Modules/Tests/HunchUITests/Tags.swift` |
| create | `Modules/Tests/HunchUITests/RGB8ColorTests.swift` |
| create | `Modules/Tests/HunchUITests/MotionAdapterTests.swift` |
| create | `Modules/Tests/HunchUITests/ThemePreferenceTests.swift` |
| create | `Modules/Tests/HunchUITests/TypographyTests.swift` |
| modify | `Hunch.xcodeproj` — add `Modules` as a local package, link `HunchUI` to the `Hunch` target, rename the wizard's `HunchUITests` XCUITest bundle to `HunchAutomationTests` |
| modify | `Presubmission.xctestplan` — add the `HunchUITests` package test target |
| modify | `Scripts/check-source-hygiene.sh` — verify checks 9 and 10, append check 11 |
| modify | `.github/workflows/*.yml` — add the `check-tokens.swift` step |
| modify | `DECISIONS.md`, `tests.json`, `PROGRESS.md` |

## Implementation notes

**`Modules/Package.swift` — the shape, minus what does not exist yet.** Paste
`package-manifests.md` §3 and then delete every target whose owner section has not been implemented
(`01 P12`, `08 §7.3`): today that leaves `HunchUI` and `HunchUITests`. Four things are not
negotiable:

- `platforms: [.iOS(.v18)]` and nothing else. **`Modules` is never host-built.** `swift build
  --package-path Modules` and `swift test --package-path Modules` are both wrong and both fail with
  `'bundle()' is only available in macOS 12 or newer` or a SwiftUI availability error; the fix is not
  to add `.macOS(.v15)` — that would promise a host build the SwiftUI targets cannot honour. CI
  builds and tests this package through `xcodebuild` only.
- `defaultLocalization: "en"` (`01 P35`), even though the String Catalog does not arrive until
  E18·T01. It is a package-level declaration, not a resource.
- **Omit `resources: [.process("Resources")]`** until `Modules/Sources/HunchUI/Resources/` exists,
  or the manifest fails to load.
- `swiftSettings` is the `ui` array — `base`'s three upcoming features plus
  `.defaultIsolation(MainActor.self)`. The product is `.library(name: "HunchUI", targets: ["HunchUI"])`
  for now; E10·T01 replaces it with `HunchAppFeature`, which is what makes `01 P9` ("`App/` imports
  exactly one module") true.

**The import that will bite you.** With `InternalImportsByDefault` on, an undecorated `import` is
`internal`, and a `public` signature mentioning a type from it fails **at the declaration**, not at
the import (`package-manifests.md` §7). Every file below writes `public import Tokens`. Note that
`Tokens` is the *module*; `HunchCore` is the *product* that contains it and is not importable by
that name — `import HunchCore` does not compile, and §7's example is written against an umbrella
module this package does not have. If you edit that reference file, correct the example.

**Isolation.** `HunchUI` is `@MainActor` by default, so every declaration in it is main-actor
isolated unless it says otherwise, and `05 R8` requires anything visible outside its own file to say
which. The three pure conversions — `RGB8.color`, `Duration.seconds`, `Easing.animation(for:)` —
and `Typography`'s pure helpers are `nonisolated`: they touch no view state, and `Feedback` (E20·T01)
will call `Duration.seconds` from a non-isolated context. `RenderEnvReader` and the `ViewModifier`
are `@MainActor`, explicitly.

**The colour adapter is three lines and the whole of it is the colour space.**

```swift
extension RGB8 {
    /// `.sRGB` is not optional: every ratio in `palette.md` is sRGB relative luminance,
    /// and a Display P3 constructor moves all of them with no test in `HunchCore` noticing,
    /// because `HunchCore` has no colour space to be wrong about.
    nonisolated public var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
extension AccentColor { nonisolated public var color: Color { rgb.color } }
extension HueColor { nonisolated public var color: Color { rgb.color } }
```

Note what is *not* added: no `Color` initialiser taking a hex, no `UIColor` bridge, no
`ShapeStyle` conformance on either register. Each would be a second way to make a colour, and the
first of them would reopen the hex ban this epic exists to close.

**`ThemePreference` lives here, not in Settings.** It needs `ColorScheme`, which is SwiftUI, so it
cannot live in `Tokens`; and it is theme *selection*, which `palette.md` §6 owns, so it is not the
Settings screen's either. Ship `enum ThemePreference: String, CaseIterable, Codable, Sendable` with
`case system, dark, light, highContrast` and one method,
`theme(colorScheme:isDarkerSystemColorsEnabled:) -> RenderEnv.Theme`. E17·T06 binds a picker to it
and persists it under `hunch.settings.`; nothing else changes. The rule is a `switch` with no
`default:`, and the `.system` arm is the only one that reads `isDarkerSystemColorsEnabled` — which
is exactly why it is a method on the preference rather than an `if` inside the reader view.

**`RenderEnvReader` — paste `render-env.md` §4 and keep its four warnings.**

- **There is no `\.accessibilityBoldText`.** SwiftUI exposes Bold Text as
  `\.legibilityWeight == .bold`. Reaching for `UIAccessibility.isBoldTextEnabled` in a view means
  wiring a notification observer for a value SwiftUI already invalidates on.
- **`@ScaledMetric(relativeTo: .body) var typeUnit: CGFloat = 1` *is* the type multiplier.** It is
  the only way to get the numeric factor; `\.dynamicTypeSize` is an ordinal category, not a number.
- **`isDarkerSystemColorsEnabled` and `isLowPowerModeEnabled` are parameters**, passed from the
  composition root, because neither is in SwiftUI's environment and both need a notification
  observer. Read inside the view they would give a value that never updates. E10·T01 owns the
  observers; this task owns the seam, and the seam is two `let`s.
- **Preference beats system state**, except that Increase Contrast forces High Contrast when nothing
  was chosen — which is `ThemePreference.theme(…)`'s job, above.

**`Typography.swift` — one top-level type, and the seven-metric trick.** `Font` has no
`system(size:relativeTo:)`, and `@ScaledMetric` needs its text style at compile time, so a role's
`relativeTo:` cannot be looked up at runtime from one metric. The working shape is a `ViewModifier`
holding **seven** `@ScaledMetric` properties, one per `TypeRole.TextStyle`, and selecting by role:

```swift
public enum Typography {
    @MainActor
    public struct RoleModifier: ViewModifier {
        @ScaledMetric(relativeTo: .largeTitle) private var largeTitleUnit: CGFloat = 1
        @ScaledMetric(relativeTo: .title2) private var title2Unit: CGFloat = 1
        @ScaledMetric(relativeTo: .subheadline) private var subheadlineUnit: CGFloat = 1
        @ScaledMetric(relativeTo: .body) private var bodyUnit: CGFloat = 1
        @ScaledMetric(relativeTo: .footnote) private var footnoteUnit: CGFloat = 1
        @ScaledMetric(relativeTo: .caption) private var captionUnit: CGFloat = 1
        @ScaledMetric(relativeTo: .caption2) private var caption2Unit: CGFloat = 1

        let role: TypeRole
        let env: RenderEnv

        public func body(content: Content) -> some View {
            let resolved = env.type(role)                      // stage 2: Bold Text, +1 notch
            let size = Double(unit(for: resolved.textStyle)) * resolved.size
            return content
                .font(Typography.font(resolved, scaledSize: size))
                .tracking(Typography.tracking(for: resolved, scaledSize: size))
                .minimumScaleFactor(1)                          // §13.4, no exceptions
        }
    }

    nonisolated public static func font(_ role: TypeRole, scaledSize: Double) -> Font { … }
    nonisolated public static func tracking(for role: TypeRole, scaledSize: Double) -> Double {
        role.tracking(atScaledSize: scaledSize)
    }
    nonisolated public static func fontWeight(_ weight: TypeRole.Weight) -> Font.Weight { … }
    nonisolated public static func cased(
        _ string: String, role: TypeRole, locale: Locale
    ) -> String {
        role.isUppercased ? string.uppercased(with: locale) : string
    }
}

extension View {
    public func typeRole(_ role: TypeRole, in env: RenderEnv) -> some View { … }
}
```

Five details:

- `font(_:scaledSize:)` builds `Font.system(size:weight:design:)` with `design: .monospaced` for the
  `mono` face, then applies `.width(.condensed)` for a condensed role. `Font.width(_:)` is iOS 16+
  and is the only way to reach SF Pro's condensed axis; there is no `Font.Design` for width.
- Do **not** call `.monospacedDigit()` on top of `design: .monospaced` — SF Mono's digits are
  already tabular and the extra modifier is a second spelling of the same intent.
- The scale factor and the size are multiplied **once**, here. `env.artScale` is for art and is
  never applied to text: doing so would scale text twice and clamp it at 1.35 into the bargain.
- `cased(_:role:locale:)` uses `String.uppercased(with:)`, never a display transform and never the
  font's small-caps feature. Three shipped-bug reasons in `type-ramp.md` §4, all of which HUNCH
  will meet across twelve localisations.
- **Nothing in this file may reach the play surface.** §13.4's zero-text rule is absolute and is
  enforced by check 7, not by this file — but the doc comment says it, because the tempting misuse
  of a `typeRole(_:in:)` modifier is a debug label on a `Canvas`.
- All four static helpers are `public`. This project never uses `@testable import` (`06 T4`), so a
  helper the test suite calls has to be part of the module's surface — and each of these four is
  something view code legitimately calls anyway (`cased(_:role:locale:)` most of all, since
  uppercasing happens on the string and not on the view).

**Check 9 may report `Typography.swift`, and the response is not to hide it.** Check 9's pattern
includes `\.font\(\.system\(size:`. The helper spelling above (`Font.system(size:…)` inside a
`static func`) does not match it, and that is legitimate — the check bans a *literal* size at a call
site, and here the size arrives from the token. Run the script; if it does report the file, add
`// TOKENS-EXEMPT: the single TypeRole → Font adapter; the size comes from the token` on the line
above, which is check 3's two-line-window convention. One exemption, with a reason, in one file.

**Switching the greps on — the drill, which is the epic's gate row 2.** Checks 9 and 10 were pasted
into `Scripts/check-source-hygiene.sh` in E01·T06, but until this task there was no `Modules/`
directory and no non-token Swift for them to run over, so they have never been observed to fail.
`07 B6`: a check that cannot fail is worse than no check.

```bash
# green first
Scripts/check-source-hygiene.sh; echo "exit=$?"                 # expect: clean, exit=0

# check 9 — a hex and a Color(red:) outside Tokens/
printf '\nlet planted = Color(red: 1, green: 0, blue: 0)  // #FF0000\n' \
  >> Modules/Sources/HunchUI/RGB8+Color.swift
Scripts/check-source-hygiene.sh; echo "exit=$?"                 # expect: names that file, exit=1
git checkout -- Modules/Sources/HunchUI/RGB8+Color.swift

# check 10 — minting a register colour outside Tokens. Reach the RGB8 through Palette so that
# only check 10 fires; naming a Prim here would trip check 11 as well and muddy the drill.
printf '\nlet laundered = HueColor(Palette(theme: .dark).accent.brass.rgb)\n' \
  >> Modules/Sources/HunchUI/Typography.swift
Scripts/check-source-hygiene.sh; echo "exit=$?"                 # expect: names that file, exit=1
git checkout -- Modules/Sources/HunchUI/Typography.swift
```

Paste the observed output into `.github/pr-body.md`. Note that check 10's grep is nearly free
because both initialisers are internal to `Tokens` and the laundering line would not compile anyway
— the grep exists to catch the day someone makes one `public` "just for previews".

**Check 11 — L2 and view code may never name an L0 primitive.** `C.swift` shipped clean in T04 and
this is what keeps it that way. Append it following `source-hygiene.md` §3's conventions (`|| true`
on every grep, `report` on a hit, never end on `grep -q … && exit 1`):

```bash
# 11. L2 and view code may never name an L0 primitive.  Owner: hunch-design-tokens.
#     L2 -> L1 -> L0 and nothing skips: only Palette, StrokeWeight and RenderEnv name a Prim.
hits=$(grep -rnE 'Prim\.' --include='*.swift' App Modules HunchCore/Sources 2>/dev/null \
  | grep -vE '^HunchCore/Sources/Tokens/(Prim|Palette|StrokeWeight|RenderEnv)\.swift:' || true)
[ -n "$hits" ] && report 'L0 primitive named outside L1 (hunch-design-tokens):' "$hits"
```

Prove it the same way — `printf '\nlet x = Prim.brass400\n' >> Modules/Sources/HunchUI/Typography.swift` —
then revert. Add its row to the gate roster in `hunch-build-and-ci`'s SKILL.md table. Numbering is
fixed: checks are appended, never renumbered, because the rest of the library cites them by number.

**The grep root `Modules` includes `Modules/Tests`,** so checks 9, 10 and 11 all apply to this
task's test files — which is why `RGB8ColorTests` reaches amber through `Palette` rather than
through `Prim`, and why no test here writes a hex. `HunchCore/Tests` is *not* covered (the root is
`HunchCore/Sources`), which is why `MotionTests.swift` may write `.milliseconds(260)` and
`ContrastTests.swift` may write `15.61`. Do not widen the roots to "fix" that asymmetry: the
assertions in `HunchCore/Tests` are the second source that the token values are checked against, and
banning them there would delete the check.

**CI wiring.** `references/ci-workflow.md` §3 fixes the order — cheapest first, so the common
failure is reported in seconds. Add one step after `check-source-hygiene.sh`:

```yaml
- name: Token divergence check
  run: swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift
```

and add `HunchUITests` (the *package* test target) to `Presubmission.xctestplan`. Keep
`set -o pipefail` on every `xcodebuild | xcbeautify` line — without it `xcbeautify` swallows the
exit status and CI goes green over failing tests.

**The Xcode-side rename.** The wizard's XCUITest bundle is called `HunchUITests` and so is this
task's package test target. Two targets with one name makes `-only-testing:HunchUITests` ambiguous
and puts two identically-named rows in every scheme and test plan. Rename the **XCUITest** bundle to
`HunchAutomationTests`: the package's path-mirroring rule is mechanical and load-bearing, the
wizard's name is not. Run `Scripts/check-pbxproj-clean.sh` afterwards — adding a package reference
is not a build setting, but the rename touches the project file and `07 B5`/`B6` still apply.

**Record in `DECISIONS.md`:** the `HunchUITests` → `HunchAutomationTests` rename with the ambiguity
reason; the `Modules` product being `HunchUI` until E10·T01 introduces `HunchAppFeature`; and the
`public import Tokens` spelling with the note that `HunchCore` is a product, not a module.

## Acceptance criteria

- [ ] `xcodebuild test -scheme Hunch -testPlan Presubmission -destination "id=$UDID"` is green
      **and reports a non-zero test count** for the four new suites, with `$UDID` resolved at
      runtime rather than a hardcoded name+OS pair (`07 B29`).
- [ ] `xcodebuild build -scheme Hunch -destination 'generic/platform=iOS'` succeeds — the SwiftUI
      side compiles, which `swift test` structurally cannot check.
- [ ] `swift test --package-path HunchCore` is still green and under 10 s: nothing in this task
      touched `HunchCore`.
- [ ] `find Modules/Sources/HunchUI -name '*.swift' | wc -l` is `6`, and
      `grep -rln 'import SwiftUI' Modules/Sources/HunchUI HunchCore/Sources | wc -l` is `5`
      (`ThemePreference` needs `ColorScheme`; nothing in `HunchCore` imports SwiftUI).
- [ ] `grep -rn 'import SwiftUI\|import UIKit' HunchCore/Sources` returns nothing, and
      `.claude/skills/hunch-swift-code/scripts/check-boundary.sh --all` exits 0.
- [ ] The three drills were run and each was observed to exit 1 naming its planted file; the tree is
      clean afterwards (`git status --porcelain` empty) and the output is in `.github/pr-body.md`.
- [ ] `Scripts/check-source-hygiene.sh` exits 0 on the clean tree with eleven checks present:
      `grep -cE '^# +[0-9]+\.' Scripts/check-source-hygiene.sh` is `11`.
- [ ] The workflow runs `check-tokens.swift`, and CI is green on the PR.
- [ ] `Color(.displayP3` appears nowhere in the repository outside `RGB8ColorTests.swift`.
- [ ] At most one `TOKENS-EXEMPT` comment exists in the whole repository:
      `grep -rc 'TOKENS-EXEMPT' --include='*.swift' App Modules HunchCore/Sources | grep -v ':0' | wc -l` ≤ 1.
- [ ] `DECISIONS.md`, `tests.json` and `PROGRESS.md` updated.

## Close the task

1. Both runners green — `swift test --package-path HunchCore` under 10 s, and the `xcodebuild test`
   plan green — with `set -o pipefail` on the piped command.
2. **Run `/simplify`** — then re-run both. Two things it must not be allowed to do: collapse the
   seven `@ScaledMetric` properties into one (`relativeTo:` is per role and one metric would scale
   three of the seven roles against the wrong system style), and inline `Duration.seconds` at its
   call sites (it is deliberately the only division in the repository).
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E03/T06: Modules package, the SwiftUI adapter with .sRGB pinned, Typography, and checks 9-11 proved"`

Then take the epic to PR: `.github/pr-body.md`, `git push -u origin epic/E03-tokens`,
`gh pr create`, `gh pr checks --watch`, and merge only on green.

## Out of scope

- Every other `HunchUI` file. `GlyphShape`/`GlyphCanvas` → **E04**; `RuleTileCanvas`, `AssayCanvas`,
  `RibbonCanvas`, `ParTickRow`, `ThroatView` → **E08/E09**; `Loc.swift` and
  `Resources/Localizable.xcstrings` → **E18·T01**; `LoomGrain.metal` → **E20·T07**.
- Every other `Modules` target — `HunchNavigation`, `Feedback`, `LoomFeature`, `CodexFeature`,
  `MetaFeature`, `HunchAppFeature`. Create a target the day its owner section is implemented
  (`01 P12`), not on the day the package appears.
- `AppDependencies`, `hunchEnvironment(_:)`, the `@Entry` values and the notification observers that
  feed `isDarkerSystemColorsEnabled` / `isLowPowerModeEnabled` — **E10·T01**.
- The Settings theme picker and its `UserDefaults` key — **E17·T06**. This task ships
  `ThemePreference` and its mapping; that task binds a control to it.
- The DEBUG snapshot gallery across three themes × Bold Text × Reduce Motion — **E04·T09**.
- Checks 1–8 of the hygiene script, and the workflow itself — **E01·T06/T07**. This task verifies
  and extends; it does not author them.
