# T05 — The override accessor

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | LOCALIZATION → Override accessor |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task changes what the composition root holds and what the root view installs, and both are its rules: one composition root named once by `@main` (`04 A2`, `08 §6`), re-injection into every presented subtree (`04 A25` — `AssayInspectorView`, `ResetConfirmAlert` and `SievePauseOverlay` start a new environment hierarchy and are the exact three that will keep the old locale if this is done wrong), and `@Entry` for custom environment values (`04 A27`). It also owns the boundary predicate that keeps `Locale` and `Bundle` out of `HunchCore` entirely. |

## Objective

At the end of this task selecting a language in Settings switches every visible string and, for
Arabic, mirrors the chrome — in the same frame, in the same process, with no relaunch. The accessor
carries a bundle **and** a locale so it does not resolve against `Bundle.main`'s launch-time
localization; `layoutDirection` is set explicitly on the root because it is not derived from
`\.locale`; and the `AppleLanguages` write is kept for the next cold launch only and is documented
as not being the mechanism for the current session.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 (Language override, and the two things that do not work by default) | the whole task: `hunch.settings.languageTag` holds `"system"` or a BCP-47 tag; the root view is re-created on change; **`AppleLanguages` is for the next cold launch only**; point 1 is the explicit `layoutDirection`; point 2 is the bundle-and-locale accessor with its exact spelling |
| `GAME_DESIGN.md` | §12.9 (final claim) | *"selecting Arabic mirrors the chrome and switches every string immediately, with no relaunch"* — a brief requirement, a Definition-of-Done item, and therefore a shipped test |
| `GAME_DESIGN.md` | §12.6 LANGUAGE row | the preference key is `languageTag` under `hunch.settings.`, the picker has 13 options and defaults to System |
| `GAME_DESIGN.md` | §12.6 (Reset everything) | `hunch.settings.*` is cleared **except** `languageTag` and `theme` — a player who reset everything in Arabic does not get an English app back |
| `GAME_DESIGN.md` | §12.9 (trap 7) | locale-native numerals are correct, not a bug — Eastern Arabic digits in the Codex are the right outcome |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | `A2`, `A25`, `A27`, `A28` | the composition root, re-injection into presented subtrees, `@Entry`, and who installs the environment |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §6 | `AppDependencies` and `hunchEnvironment(_:)`'s shape |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/LanguageOverrideTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import HunchUI
import HunchAppFeature

/// §12.9's Definition-of-Done item, shipped as a test: set the override to `ar`, assert
/// `layoutDirection` flips and a sampled key resolves to its Arabic value, **without restarting
/// the process**. Every assertion below happens inside one test run; there is no `exit`, no
/// relaunch and no `AppleLanguages` read.
@Suite("Language override — no relaunch", .tags(.unit, .presubmission))
@MainActor
struct LanguageOverrideTests {

    @Test("`system` resolves against the process's own localization")
    func systemResolvesAgainstTheProcess() {
        let resolution = LanguageResolution(tag: "system")
        #expect(resolution.locale.identifier == Locale.autoupdatingCurrent.identifier)
    }

    /// The core claim. One process, two resolutions, different strings.
    @Test("Switching to Arabic changes the resolved value with no relaunch")
    func switchingToArabicChangesTheValue() throws {
        let english = try #require(LanguageResolution(tag: "en").loc)
        let arabic  = try #require(LanguageResolution(tag: "ar").loc)
        for key in LocKey.sampledForOverride {
            #expect(english[key] != arabic[key], "\(key.rawValue) did not change")
            #expect(arabic[key] != key.rawValue)
        }
    }

    /// §12.9 point 1: layoutDirection is NOT derived from `\.locale`. It comes from the process's
    /// effective localization and is fixed at launch, so it has to be set explicitly on the root.
    @Test("Arabic resolves to right-to-left and every other locale to left-to-right",
          arguments: TwelveLanguageTests.locales)
    func layoutDirectionFollowsTheResolvedLocale(_ tag: String) {
        let resolution = LanguageResolution(tag: tag)
        #expect(resolution.layoutDirection == (tag == "ar" ? .rightToLeft : .leftToRight))
    }

    /// The negative control, and the reason this task exists. Setting `\.locale` alone mirrors
    /// nothing — if this ever starts passing, SwiftUI changed and the explicit set can go.
    @Test("Setting \\.locale alone does not mirror")
    func settingLocaleAloneDoesNotMirror() {
        var environment = EnvironmentValues()
        environment.locale = Locale(identifier: "ar")
        #expect(environment.layoutDirection == .leftToRight)
    }

    /// §12.9: the `AppleLanguages` write is kept for the NEXT COLD LAUNCH ONLY and is explicitly
    /// not the mechanism for the current session. Assert both halves — that it is written, and
    /// that nothing in the resolution path reads it.
    @Test("AppleLanguages is written for the next cold launch and read by nothing")
    func appleLanguagesIsWriteOnly() throws {
        let defaults = try #require(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }

        LanguagePreference(defaults: defaults).set("ar")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ar"])
        #expect(defaults.string(forKey: "hunch.settings.languageTag") == "ar")

        LanguagePreference(defaults: defaults).set("system")
        #expect(defaults.object(forKey: "AppleLanguages") == nil)
    }

    /// §12.9: `Date.FormatStyle`, `NumberFormatter` and `Measurement` all read the same resolved
    /// locale, so a player in French-on-an-English-phone gets French dates in the Codex.
    @Test("Formatters read the resolved locale, not the process locale")
    func formattersReadTheResolvedLocale() throws {
        let french = try #require(LanguageResolution(tag: "fr").loc)
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let formatted = reference.formatted(Date.FormatStyle(date: .abbreviated).locale(french.locale))
        #expect(formatted != reference.formatted(
            Date.FormatStyle(date: .abbreviated).locale(Locale(identifier: "en_US"))))
    }

    /// §12.6: Reset everything clears `hunch.settings.*` EXCEPT `languageTag` and `theme`.
    @Test("Reset everything keeps the language override")
    func resetEverythingKeepsTheOverride() throws {
        let defaults = try #require(UserDefaults(suiteName: #function))
        defer { defaults.removePersistentDomain(forName: #function) }

        LanguagePreference(defaults: defaults).set("tr")
        SettingsReset(defaults: defaults).resetEverything()
        #expect(defaults.string(forKey: "hunch.settings.languageTag") == "tr")
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/LanguageOverrideTests
```

Failures must be missing symbols — `LanguageResolution`, `LanguagePreference`,
`LocKey.sampledForOverride` — except `settingLocaleAloneDoesNotMirror`, which **passes immediately**
and is meant to: it is the negative control that documents why the rest of the task is necessary.
If `resetEverythingKeepsTheOverride` fails on `SettingsReset` rather than on the value, E17·T08's
reset already handles the exclusion and the test only needs its real type name.

**Step 3 — implement.** `LanguageResolution`, `LanguagePreference`, the root install, the
re-injection into the three presented subtrees.

**Step 4 — green, then refactor.** Then do the thing a test cannot: run the app, open Settings,
choose العربية, and watch the screen mirror without a relaunch. Record it in `PROGRESS.md`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/LanguageResolution.swift` |
| create | `Modules/Sources/HunchUI/LanguagePreference.swift` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — the `.lproj` resolution promoted from T03's test seam to the shipping path |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — hold the resolution; install `\.loc`, `\.locale` and `\.layoutDirection` |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — the root `.id(…)` and the three environment values |
| modify | `Modules/Sources/LoomFeature/AssayInspectorView.swift`, `SievePauseOverlay.swift`, `Modules/Sources/MetaFeature/ResetConfirmAlert.swift` — re-inject (`04 A25`) |
| modify | `Modules/Sources/MetaFeature/SettingsView.swift` — the LANGUAGE row writes through `LanguagePreference` |
| create | `Modules/Tests/HunchUITests/LanguageOverrideTests.swift` |
| modify | `tests.json` — five entries (no-relaunch switch, layoutDirection, `\.locale` negative control, `AppleLanguages` write-only, reset keeps the override) |
| modify | `DECISIONS.md` — why the root is keyed on the resolved identifier, and the `.lproj` name mapping |

## Implementation notes

### `LanguageResolution` — one value, three outputs

Everything the app needs to switch language is a pure function of one string, and making it a value
is what makes all seven tests above possible without a running app:

```swift
// Modules/Sources/HunchUI/LanguageResolution.swift
import Foundation
import SwiftUI

/// `hunch.settings.languageTag` resolved into the three things the app actually installs.
/// Pure over its tag; it reads no defaults and no bundle state of its own.
public struct LanguageResolution: Sendable, Hashable {
    public let tag: String                  // "system" or a BCP-47 tag

    public init(tag: String) { self.tag = tag }

    /// `.autoupdatingCurrent` for "system" so a mid-session OS change is picked up; a fixed
    /// `Locale` otherwise. Every formatter in the app reads *this*, never `Locale.current`.
    public var locale: Locale {
        tag == "system" ? .autoupdatingCurrent : Locale(identifier: tag)
    }

    /// §12.9 point 1. `EnvironmentValues.layoutDirection` comes from the process's effective
    /// localization and is fixed at launch, so setting `\.locale` to `ar` mirrors nothing. This is
    /// what the root sets explicitly.
    public var layoutDirection: LayoutDirection {
        locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// The accessor, resolved against the override's own `.lproj` rather than against
    /// `Bundle.main`'s launch-time localization (§12.9 point 2).
    public var loc: Loc? { Loc.resolved(self) }
}
```

`characterDirection` is on `Locale.Language` and is the right question: it answers "does this
*script* run right to left", which is why `ar` mirrors and `ja` does not, and it needs no
hard-coded list of RTL languages that would be wrong the day a thirteenth is added.

### `Loc.resolved(_:)` — the bundle half

§12.9 gives the spelling literally:

```swift
LocalizedStringResource(key, bundle: .atURL(overrideBundle.bundleURL), locale: resolvedLocale)
```

which means `Loc` needs the override bundle's URL, and the override bundle is the `<tag>.lproj`
directory inside `HunchUI`'s own resource bundle:

```swift
extension Loc {
    /// Promoted from T03's `forTesting(languageTag:)`. One function, one mapping, one fallback.
    public static func resolved(_ resolution: LanguageResolution) -> Loc? {
        guard resolution.tag != "system" else { return .system }
        guard let directory = lprojName(for: resolution.tag),
              let path = #bundle.path(forResource: directory, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            // A tag with no lproj is a bug, not a user state: the picker offers exactly the twelve
            // the catalog ships. Fall back to the system accessor rather than crashing, and let
            // TwelveLanguageTests be what catches it — it enumerates all twelve every run.
            return .system
        }
        return Loc(locale: resolution.locale, bundleURL: bundle.bundleURL)
    }
}
```

**Verify the `.lproj` directory names against a real build before writing `lprojName(for:)`** — the
mapping from BCP-47 tag to on-disk directory is not always the identity, and `pt-BR` and `zh-Hans`
are the two that vary:

```bash
find ~/Library/Developer/Xcode/DerivedData -path '*HunchUI*' -name '*.lproj' -print \
  | sed 's|.*/||' | sort -u
```

If they are identical to the tags, `lprojName(for:)` is `{ $0 }` and says so in a comment with the
date it was verified. If they are not, the mapping lives here and in exactly one place, and it gets
a test case in `TwelveLanguageTests`.

### The root install — three values, one `.id`

```swift
// Modules/Sources/HunchAppFeature/AppView.swift
public struct AppView: View {
    @Environment(\.self) private var environment          // illustrative; read what you install
    private let resolution: LanguageResolution

    public var body: some View {
        RootScene()
            .environment(\.loc, resolution.loc ?? .system)
            .environment(\.locale, resolution.locale)              // formatters and plural rules
            .environment(\.layoutDirection, resolution.layoutDirection)   // §12.9 point 1
            .id(resolution.tag)          // §12.9: "on change the app re-creates the root view"
    }
}
```

Four notes, each of which is a bug if it is got wrong:

- **`.id(resolution.tag)`** is what re-creates the root. Without it, views that captured a resolved
  `String` in `@State` — an `accessibilityLabel` computed in `onAppear`, a formatted date stored on
  first render — keep the old language while everything computed in `body` switches. `A6`: a value
  read in `.onAppear` forms no dependency and never updates again. Keying the root is cheaper and
  more reliable than auditing every screen for that mistake.
- **`\.locale` is still installed**, even though it mirrors nothing, because it is what
  `Text(…, format:)`, `.formatted()` and String Catalog plural selection read when no locale is
  passed explicitly. Installing all three is one line each; installing two of the three is a bug
  class.
- **`\.layoutDirection` is set from `resolution`, never from `\.locale`.** The negative-control test
  is in the suite to keep that honest.
- **Re-inject into the three presented subtrees.** `AssayInspectorView`, `ResetConfirmAlert` and
  `SievePauseOverlay` are presentations and start a new environment hierarchy (`04 A25`, "the single
  most common environment bug"). An alert body that stays English while the screen behind it is
  Arabic is exactly how this ships broken, and it is the one place a `.sheet` or `.alert` will not
  tell you. E10·T01 added a hygiene check for re-injection; confirm all three appear in it.

### `LanguagePreference` — the write, and what is not read

```swift
public struct LanguagePreference: Sendable {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var tag: String { defaults.string(forKey: "hunch.settings.languageTag") ?? "system" }

    public func set(_ tag: String) {
        defaults.set(tag, forKey: "hunch.settings.languageTag")
        // §12.9: the AppleLanguages write is kept for the NEXT COLD LAUNCH ONLY, so a relaunch
        // starts in the chosen language and system UI (the keyboard, the share sheet the app does
        // not have, VoiceOver's own strings) follows. It is explicitly NOT the mechanism for this
        // session — nothing in LanguageResolution reads it, and `appleLanguagesIsWriteOnly` asserts
        // that by asserting the switch works before any relaunch could occur.
        if tag == "system" {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([tag], forKey: "AppleLanguages")
        }
    }
}
```

`UserDefaults` holds preferences only; game state is JSON (§12.6). And `Reset everything` clears
every `hunch.settings.*` key **except** `languageTag` and `theme` — that exclusion is E17·T08's
code, and `resetEverythingKeepsTheOverride` is this task's assertion over it, because the two epics
would otherwise each assume the other tested it.

### The Settings row

The picker is E17·T07's; this task only changes what its selection does. Thirteen options: twelve
endonyms rendered `Text(verbatim:)` from the constant array T02 defines, plus
`loc[.optionFollowSystem]`. Writing the preference is the whole action — the root is keyed on the
tag, so the screen re-creates itself and the player sees the Settings screen they are standing on
switch language under them, which is the correct and slightly startling feedback.

### `LocKey.sampledForOverride`

A named handful — the six screen titles plus a Settings row and an alert title — rather than all
215. Two reasons: the assertion is *"a sampled key resolves"* (§12.9's own wording), and asserting
every key differs between English and Arabic duplicates `noSilentFallbackToEnglish` from T03 while
being much slower. Choose keys whose Arabic is certainly different — a proper noun rendered in
Arabic script still differs from its Latin form, so `LABEL_CODEX` is a legitimate sample.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/LanguageOverrideTests` green, all seven tests, in **one** process.
- [ ] `grep -rn 'Locale.current\|Locale(identifier:' Modules/Sources --include='*.swift' | grep -v LanguageResolution.swift` returns nothing — every locale in the app comes from the resolution.
- [ ] `grep -rn 'AppleLanguages' Modules/Sources` shows exactly one write site and **zero** read sites.
- [ ] `grep -n 'environment(\\.layoutDirection' Modules/Sources/HunchAppFeature/AppView.swift` shows one hit, and its value comes from `LanguageResolution`.
- [ ] `grep -rn 'hunchEnvironment\|environment(\\.loc' Modules/Sources/LoomFeature/AssayInspectorView.swift Modules/Sources/LoomFeature/SievePauseOverlay.swift Modules/Sources/MetaFeature/ResetConfirmAlert.swift` shows a re-injection in each of the three.
- [ ] `bash Scripts/check-source-hygiene.sh` green, including E10·T01's re-injection check.
- [ ] `PROGRESS.md` records the manual run: Settings → العربية → the screen mirrors and switches language with the process still running, with the simulator build number.
- [ ] `tests.json` carries the five entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T05: the override accessor, the explicit layoutDirection and the no-relaunch test"`

## Out of scope

- **The 13-option picker itself, its 12 endonyms and the `hunch.settings.` convention** —
  **E17·T07**. This task changes what selecting a row does, not the row.
- **What actually mirrors when `layoutDirection` flips** — **T06**. This task proves the flag
  flips; T06 proves the chrome follows it and the glyphs do not.
- **Plural selection under the resolved locale** — **T07**. `\.locale` is installed here so T07 has
  something to select against.
- **The `Reset everything` implementation** — **E17·T08**; this task asserts one property of it.
- **`CFBundleDisplayName` and the `Info.plist` absences** — **T08**.
- **Pseudolocale runs, which set the language by launch argument rather than by this preference** —
  **T09**. The two paths are deliberately independent: a pseudolocale must exercise the *process*
  localization, which is what a real App Store review environment does.
