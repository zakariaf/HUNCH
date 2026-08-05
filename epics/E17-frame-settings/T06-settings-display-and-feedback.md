# T06 — Settings: DISPLAY and FEEDBACK

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | DISPLAY · FEEDBACK |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**: this task draws a switch and a segmented control, and it owns the `ThemePreference → RenderEnv.Theme` mapping this task implements. `references/render-env.md` §4 already writes the mapping's signature and states the exact rule — *"theme preference beats system state, except that `isDarkerSystemColorsEnabled` forces High Contrast only when the player has made no explicit choice"* — and §3 owns `isArtScaleClamped`, which is the only legal spelling of the picker-style threshold. |
| `hunch-chrome-and-meta` | `references/stock-controls.md` is this screen: §1's container neutralisation (the one place the OS picks a colour and picks wrong), §2's `DrawnToggleStyle` with its two non-colour channels and its deliberate deviation from PHOSPHOR's capsule, §3's rows, separators and the `Loc`-side casing rule, and §4's segmented→inline swap. Its "Wrong" list already names every mistake this task could make. |

## Objective

At the end of this task `SettingsView` exists with its first two sections working end to end: DISPLAY
(Theme, Grain, Reduce motion, Left-hand keys) and FEEDBACK (Haptics, Sound, Level). The theme control
is a four-way segmented picker whose System case resolves through `ThemePreference` — forced to High
Contrast when `isDarkerSystemColorsEnabled` and the player has made no choice — and every switch on
the screen is a drawn `ToggleStyle` with no accent and no system tint anywhere.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.6 | the DISPLAY and FEEDBACK rows verbatim — type, default, effect and key for each of the seven; the note that Level is *"two states, not a slider"* and why; the note that Haptics has no Light tier and why |
| `GAME_DESIGN.md` | §12.6 | *"Everything persists to `UserDefaults.standard` under the `hunch.settings.` prefix except the DATA rows"* and *"`UserDefaults` holds preferences only; game state lives in JSON"* |
| `GAME_DESIGN.md` | §13.2 | Theme selection: System / Dark / Light / High Contrast, default System, Dark below `.light` and Light above; the `isDarkerSystemColorsEnabled` forcing rule |
| `GAME_DESIGN.md` | §13.11 | what High Contrast *is* — hues → `stroke.primary`, index stroke `0.273·S → 0.409·S`, strokes +0.5, shader off; and the Settings row behaviour at accessibility1 (label-over-value) and 2…5 |
| `GAME_DESIGN.md` | §13.6 | Grain's effect and the three conditions that hold it at `amt = 0` |
| `GAME_DESIGN.md` | §13.7.4 | what "Reduce motion = Always" means downstream — every animation becomes a crossfade, and the Frame's idle glyph stops drifting |
| `GAME_DESIGN.md` | §13.8, §13.9 | Sound gates `AVAudioEngine` entirely; Level Low is −8 dB; Haptics gates `CHHapticEngine` entirely and is the control, because iOS exposes no public read |
| `GAME_DESIGN.md` | §12.6, §4.1, §4.2, §8.4, §9.2 | Left-hand keys mirrors **only** the commit-bar key order and the Bench handle side, and never the play surface |
| `GAME_DESIGN.md` | §12.9 | 7 section headers + 19 row labels + 11 option labels = 37 keys; ≤ 22 characters in English, budgeted at +40 % |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3, §6 | no `…Manager`/`…Service` names; `@Entry` for custom environment values; re-inject into every presented subtree |

**Do not restate a default, a decibel figure or a key name in prose here.** §12.6's table is the
source; this task encodes it once, in `Preference.Key`, and cites it.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/TokensTests/ThemePreferenceTests.swift`:

```swift
import Testing
import Tokens
import HunchTestSupport

@Suite("ThemePreference resolves the four cases and the forcing rule — §13.2, §12.6",
       .tags(.unit, .presubmission))
struct ThemePreferenceTests {

    @Test("the default is System")
    func defaultIsSystem() {
        #expect(ThemePreference.default == .system)
    }

    @Test("System follows the colour scheme: Dark below .light, Light above")
    func systemFollowsColorScheme() {
        #expect(ThemePreference.system.theme(colorScheme: .dark, isDarkerSystemColorsEnabled: false) == .dark)
        #expect(ThemePreference.system.theme(colorScheme: .light, isDarkerSystemColorsEnabled: false) == .light)
    }

    @Test("an explicit choice beats the system colour scheme",
          arguments: [(ThemePreference.dark, RenderEnv.Theme.dark),
                      (.light, .light),
                      (.highContrast, .highContrast)])
    func explicitChoiceWins(_ pair: (ThemePreference, RenderEnv.Theme)) {
        #expect(pair.0.theme(colorScheme: .light, isDarkerSystemColorsEnabled: false) == pair.1)
        #expect(pair.0.theme(colorScheme: .dark, isDarkerSystemColorsEnabled: false) == pair.1)
    }

    @Test("isDarkerSystemColorsEnabled forces High Contrast ONLY when the player has not chosen")
    func darkerSystemColorsForcesOnlyTheUnchosen() {
        #expect(ThemePreference.system.theme(colorScheme: .dark, isDarkerSystemColorsEnabled: true) == .highContrast)
        #expect(ThemePreference.system.theme(colorScheme: .light, isDarkerSystemColorsEnabled: true) == .highContrast)
        // An explicit Dark stays Dark: the player asked, and the system flag does not overrule them.
        #expect(ThemePreference.dark.theme(colorScheme: .light, isDarkerSystemColorsEnabled: true) == .dark)
        #expect(ThemePreference.light.theme(colorScheme: .dark, isDarkerSystemColorsEnabled: true) == .light)
        #expect(ThemePreference.highContrast.theme(colorScheme: .dark, isDarkerSystemColorsEnabled: true) == .highContrast)
    }

    @Test("the mapping is total: four preferences × two schemes × two flags, no crash, no default:")
    func mappingIsTotal() {
        for preference in ThemePreference.allCases {
            for scheme in [ColorSchemeSurrogate.light, .dark] {
                for darker in [true, false] {
                    _ = preference.theme(colorScheme: scheme, isDarkerSystemColorsEnabled: darker)
                }
            }
        }
    }
}
```

And `Modules/Tests/MetaFeatureTests/PreferenceKeyTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("Preferences are 13 hunch.settings. keys and nothing else — §12.6",
       .tags(.unit, .presubmission))
struct PreferenceKeyTests {

    @Test("every key carries the prefix and the prefix has one home")
    func everyKeyIsPrefixed() {
        for key in Preference.Key.allCases {
            #expect(key.storageKey.hasPrefix("hunch.settings."))
            #expect(key.storageKey == "hunch.settings." + key.rawValue)
        }
    }

    @Test("§12.6 has exactly thirteen preference keys — 19 rows minus 5 DATA minus 1 ABOUT")
    func thirteenKeys() {
        #expect(Preference.Key.allCases.count == 13)
        #expect(Set(Preference.Key.allCases.map(\.storageKey)).count == 13)
    }

    @Test("every key has §12.6's default, and reading an empty store returns it")
    func defaultsMatchTheTable() {
        let store = UserDefaults(suiteName: #function)!
        store.removePersistentDomain(forName: #function)
        let preferences = PreferenceReader(store: store)
        #expect(preferences.theme == .system)
        #expect(preferences.grain == true)
        #expect(preferences.reduceMotion == .system)
        #expect(preferences.leftHandKeys == false)
        #expect(preferences.haptics == true)
        #expect(preferences.sound == true)
        #expect(preferences.level == .normal)
    }

    @Test("a written preference survives a reader rebuilt over the same store")
    func writesPersist() {
        let store = UserDefaults(suiteName: #function)!
        store.removePersistentDomain(forName: #function)
        PreferenceWriter(store: store).set(.level, to: SoundLevel.low)
        #expect(PreferenceReader(store: store).level == .low)
    }

    @Test("no key names anything that is game state")
    func noGameStateKeys() {
        let banned = ["round", "probe", "law", "codex", "anomaly", "profile", "ladder", "seed", "score", "band"]
        for key in Preference.Key.allCases {
            #expect(!banned.contains { key.rawValue.lowercased().contains($0) }, "\(key.rawValue) looks like game state")
        }
    }
}
```

And `Modules/Tests/MetaFeatureTests/LeftHandKeysTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
@testable import HunchUI

@Suite("Left-hand keys mirrors exactly two things — §12.6", .tags(.unit, .presubmission))
struct LeftHandKeysTests {

    @Test("the commit bar's key ORDER reverses, and only the order")
    func commitBarOrderMirrors() {
        let normal = CommitBarLayout(keys: [.probe, .twin, .bench], leftHandKeys: false)
        let mirrored = CommitBarLayout(keys: [.probe, .twin, .bench], leftHandKeys: true)
        #expect(mirrored.order == normal.order.reversed())
        #expect(mirrored.keyRects.map(\.size) == normal.keyRects.map(\.size))
    }

    @Test("the Bench handle changes side")
    func benchHandleSideMirrors() {
        #expect(BenchHandlePlacement(leftHandKeys: false).side == .trailing)
        #expect(BenchHandlePlacement(leftHandKeys: true).side == .leading)
    }

    @Test("the instrument bar does NOT mirror for handedness — instrument-bar.md §7")
    func instrumentBarIgnoresHandedness() {
        let normal = InstrumentBarLayout(leftHandKeys: false)
        let mirrored = InstrumentBarLayout(leftHandKeys: true)
        #expect(mirrored.slotOrder == normal.slotOrder)
    }

    @Test("the play surface does NOT mirror: the Dial, the throat, the ribbon and the Assay are unchanged")
    func playSurfaceIgnoresHandedness() {
        for surface in PlaySurfaceLayout.allReferenceCases {
            #expect(surface.mirroredForHandedness(false) == surface.mirroredForHandedness(true))
        }
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter ThemePreferenceTests` and
`swift test --package-path Modules --filter "PreferenceKeyTests|LeftHandKeysTests"`

Failures must be missing symbols — `ThemePreference`, `Preference.Key`, `PreferenceReader`,
`CommitBarLayout` — or a default that is wrong. `darkerSystemColorsForcesOnlyTheUnchosen` passing
before the mapping exists means `theme(colorScheme:isDarkerSystemColorsEnabled:)` is returning a
constant; check it varies.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Tokens/ThemePreference.swift` — **only if E03·T03 did not ship it**; otherwise extend |
| create | `Modules/Sources/MetaFeature/Preference.swift` — the 13 keys, the prefix, the reader and the writer |
| create | `Modules/Sources/MetaFeature/SettingsView.swift` |
| create | `Modules/Sources/MetaFeature/SettingsSection+Display.swift` |
| create | `Modules/Sources/MetaFeature/SettingsSection+Feedback.swift` |
| create | `Modules/Sources/HunchUI/Chrome/DrawnToggleStyle.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Toggle.trackWidth`, `.trackHeight`, `.slugSide` |
| modify | `Modules/Sources/HunchUI/RenderEnvReader.swift` — take `ThemePreference` and the two passed-in system flags |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — observe the theme, grain and reduce-motion keys and rebuild `RenderEnv` |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — 2 section headers, 7 row labels, 8 option labels, English only |
| create | `HunchCore/Tests/TokensTests/ThemePreferenceTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/PreferenceKeyTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/LeftHandKeysTests.swift` |
| modify | `tests.json` — four entries: the forcing rule, the 13-key inventory with defaults, the left-hand-keys scope, and the toggle's two non-colour channels |

## Implementation notes

### `ThemePreference` belongs in `HunchCore/Sources/Tokens/`

It is a four-case enum with a pure total mapping to `RenderEnv.Theme`, so `08 §2`'s boundary
predicate puts it in the core: it imports nothing but Swift, and its behaviour is a function of
values you can write down. That is what makes `ThemePreferenceTests` a fast-suite test with no
simulator — which matters, because the forcing rule is the single most accessibility-sensitive line
in the app and it must be cheap to re-assert.

```swift
// HunchCore/Sources/Tokens/ThemePreference.swift
public enum ThemePreference: String, CaseIterable, Codable, Sendable {
    case system, dark, light, highContrast

    public static let `default` = ThemePreference.system

    /// §13.2: "Settings: System / Dark / Light / High Contrast, default System (Dark below `.light`,
    /// Light above). If `UIAccessibility.isDarkerSystemColorsEnabled` and the player has made no
    /// explicit choice, force High Contrast."
    public func theme(colorScheme: ColorSchemeSurrogate,
                      isDarkerSystemColorsEnabled: Bool) -> RenderEnv.Theme {
        switch self {
        case .system:
            isDarkerSystemColorsEnabled ? .highContrast : (colorScheme == .dark ? .dark : .light)
        case .dark: .dark
        case .light: .light
        case .highContrast: .highContrast
        }
    }
}

/// `ColorScheme` is SwiftUI's, and `HunchCore` may not import SwiftUI. Two cases, mapped at the edge.
public enum ColorSchemeSurrogate: Sendable { case light, dark }
```

**The forcing rule is a property of `.system` alone**, and writing it as a `switch` case rather than
an `if` before the switch is what makes that visible. `render-env.md` §4 already says why it is a
method and not an `if` in the view: a view-level `if` gets copied, and the second copy forgets the
"has made no explicit choice" half.

`String` raw values, because `@AppStorage` needs `RawRepresentable` with a `String` or `Int` raw
value and because a persisted preference outlives a case reordering.

### `Preference` — one home for the prefix and the thirteen keys

```swift
// Modules/Sources/MetaFeature/Preference.swift
public enum Preference {
    /// §12.6. This string appears exactly once in the codebase.
    static let prefix = "hunch.settings."

    /// The thirteen preference rows of §12.6 — nineteen rows minus five DATA rows, which act on
    /// files, minus ABOUT, which is a disclosure.
    enum Key: String, CaseIterable, Sendable {
        case theme, grain, reduceMotion, leftHandKeys           // DISPLAY
        case haptics, sound, level                              // FEEDBACK
        case confirmSeal, steadyStream                          // PLAY        (T07)
        case voiceOverDetail, announceVerdicts, announceAssay   // VOICEOVER   (T07)
        case languageTag                                        // LANGUAGE    (T07)

        var storageKey: String { Preference.prefix + rawValue }
    }
}
```

The rawValue **is** §12.6's Key column, so the table and the enum can be diffed by eye. T07 adds no
cases — they are all declared here, in one place, and T07 wires the last six rows to them. Declaring
all thirteen now is what makes `thirteenKeys` a real inventory assertion rather than a moving target.

### Reading a preference: `@AppStorage`, not a fifth observable

`hunch-swift-code/SKILL.md` fixes the observable roster at four — `Round`, `Codex`, `Ladder`, and one
`Router` per stack — and *"every other screen holds `@State private` and reads the model in `body`"*.
A `@MainActor @Observable Preferences` would be a fifth, and it would duplicate an observation
mechanism SwiftUI already provides for exactly this data.

So: **`@AppStorage` at every read site**, keyed through `Preference.Key.storageKey`, with
`PreferenceReader`/`PreferenceWriter` as thin value types over an injected `UserDefaults` **for the
tests only** — the app path is `@AppStorage`, the test path is the reader, and both name the same
`storageKey`. A `PreferenceReader` in the view hierarchy would be a value read outside `body` that
forms no dependency and never updates again (`04 A6`, `A14`).

`UserDefaults` is named in exactly one file (`Preference.swift`), and check 12 (T07) greps for that.

### `DrawnToggleStyle` — two non-colour channels, and no capsule

`stock-controls.md` §2 has the whole drawing and its one deviation, and this task implements it
verbatim:

- **`ToggleStyle`, never a hand-rolled `Button`.** The style keeps `Toggle`'s `.isToggle` trait, its
  on/off accessibility value, its Magic Tap eligibility and its `legibilityWeight` response for
  free. A `Button` flipping a `Bool` announces itself as a button with no state, which is a
  Definition-of-Done failure against §13.12 gate 4.
- **Position and fill are the two channels.** ON = slug filled `stroke.primary` at the trailing end;
  OFF = slug hollow with a `weight.thin` frame at `opacity.disabled` at the leading end. **No
  accent**: §13.1 rations it to three per screen and a 19-row list has eight toggles, and §13.2 makes
  accent the *verdict* register — spending it here would make "the machine has answered" and "you
  turned on sound" the same colour.
- **A rounded rectangle at `Radius.chrome`, not a capsule.** A capsule's radius is half its height,
  an order above §13.3's chrome cap. The 51 × 31 / 27 pt metrics are kept because they are the
  platform's travel and hit geometry, and they are `C.Toggle.trackWidth`, `.trackHeight`, `.slugSide`.
- The hit rect is `≥ 44 × 44` with `.contentShape(Rectangle())`, and it mirrors under RTL through
  `.leading`/`.trailing` alignment (§12.8).

### The container, neutralised once

```swift
Form { … }
    .scrollContentBackground(.hidden)
    .background(env.palette.ground.base.color.ignoresSafeArea())
    .tint(env.palette.stroke.primary.color)
    .listRowBackground(env.palette.ground.raised.color)
    .listRowSeparatorTint(env.palette.stroke.hairline.color)
    .environment(\.defaultMinListRowHeight, Space.s44)
```

This is the one place in the app where the OS picks a colour and picks wrong, and neither
`systemGroupedBackground` nor the system blue tint has a literal for `check-source-hygiene.sh` check
9 to find. Fix it at the container, once, and never per row.

### The four segmented controls, and the AX1 swap

§12.6 gives four segmented controls; two of them are in this task (Theme 4-way, Reduce motion 2-way)
and two in T07 (Level is FEEDBACK and therefore here; VoiceOver Detail is T07's). A four-way
segmented control cannot wrap, and §13.4 forbids `minimumScaleFactor` below 1.0, so at AX3 in German
the four theme labels have nowhere to go and §13.11's snapshot gate fails. The swap is:

```swift
.pickerStyle(env.isArtScaleClamped ? .inline : .segmented)
```

**`env.isArtScaleClamped`, never a bare comparison against 1.35 and never a Dynamic Type category
name.** The ceiling has one home in `Prim.artScaleCeiling`, a view may not name a `Prim`, and check 9
greps hexes and `lineWidth:` — it cannot see a bare `1.35`. The predicate is declared beside
`artScale` in `render-env.md` §3 and is reached at **AX1**, so naming it `isAX3OrAbove` would be
wrong on its face.

Option labels resolve through `Loc.themeName(_:)` and are rendered `Text(verbatim:)`.
`Text($0.label)` with a bare `LocalizedStringResource` bypasses `Loc`'s override bundle and stays
English until the next cold launch (§12.9 trap 1).

### Level is two states because a slider is a control nobody can set by ear

§12.6 says it, and the reason is worth keeping in the code comment: the mix is already
ceiling-limited at −6 dBFS (§13.8), so a continuous gain has no audible calibration point. Ship
`enum SoundLevel: String { case normal, low }`. **Do not** add a third state, a slider, or a
per-cue volume. Same shape as Haptics, where §12.6 spells out that a "Light" tier would be eleven
more pattern designs carrying no information the visuals do not already carry.

### Left-hand keys — the scope is two things, and the test is what keeps it two

§12.6: *"mirrors **only** the commit bar key order and the Bench handle side. Never the play
surface"*, and `instrument-bar.md` §7 adds *"the instrument bar never mirrors for handedness"*. That
is four claims — two positive, two negative — and `LeftHandKeysTests` asserts all four.

Enforce it structurally as well: the preference is read in **exactly two files**.

```bash
grep -rln "leftHandKeys" Modules/Sources | sort   # must be exactly Preference.swift, SettingsSection+Display.swift,
                                                  # CommitBarLayout.swift and BenchHandlePlacement.swift
```

If a fifth file appears, either the mirroring has spread or a view is passing the flag through — and
passing it through is how it spreads. Add the grep to the acceptance criteria, not to a comment.

### The seven effects this task does **not** implement

Every DISPLAY and FEEDBACK row has a consumer, and every one of those consumers is another epic's.
This task ships the control, the key and the persistence; the consumer reads it:

| Row | Consumer |
|---|---|
| Theme | `RenderEnv` (E03·T03) — already reads it once `ThemePreference` exists |
| Grain | the `loomGrain` shader — **E20·T07** |
| Reduce motion | every animation's substitution table — **E09·T12**, **E20·T08** |
| Left-hand keys | `CommitBarLayout` and `BenchHandlePlacement` — the *layouts* are E08·T02 / E09·T01's; this task adds the flag to them |
| Haptics | `HapticCuePlayer`'s engine gate — **E20·T06** |
| Sound | `SynthesizedCuePlayer`; off means the engine is **never instantiated** — **E20·T04** |
| Level | the master bus's −8 dB — **E20·T04** |

Wire the flag into each consumer's signature where the consumer already exists (Left-hand keys); for
the four that do not exist yet, the key is written and read by nothing, which is correct and is why
those rows appear in E20's task files.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ThemePreferenceTests` green, all five tests.
- [ ] `swift test --package-path Modules --filter "PreferenceKeyTests|LeftHandKeysTests"` green.
- [ ] `grep -rn "hunch.settings." Modules/Sources HunchCore/Sources | grep -v Preference.swift` returns nothing.
- [ ] `grep -rln "leftHandKeys" Modules/Sources` returns exactly the four expected files.
- [ ] `grep -rn "1\.35\|accessibility3\|dynamicTypeSize >=" Modules/Sources/MetaFeature/Settings*.swift` returns nothing; the picker branch is `env.isArtScaleClamped`.
- [ ] `grep -rn "accent\|\.tint(\.\|borderedProminent\|systemGroupedBackground\|Color\.blue" Modules/Sources/MetaFeature/Settings*.swift` returns nothing but the `.tint(env.palette.stroke.primary.color)` line.
- [ ] `grep -rn "Capsule()" Modules/Sources/HunchUI/Chrome/DrawnToggleStyle.swift` returns nothing.
- [ ] `grep -rn "Toggle" Modules/Sources/MetaFeature/` shows `Toggle` + `.toggleStyle(DrawnToggleStyle())` and no hand-rolled `Button` flipping a `Bool`.
- [ ] `Scripts/check-source-hygiene.sh` check 9 passes over the new files.
- [ ] Simulator walk recorded in the commit message: set Theme to each of the four and confirm the whole app repaints without relaunch; turn Darker System Colours on with Theme at System and confirm High Contrast; set Theme to Dark, turn Darker System Colours on, and confirm it **stays** Dark; check every row at AX1 (label-over-value, inline pickers) and at AX5 in German (no truncation, rows grow).
- [ ] The 17 English strings this task adds are ≤ 22 characters each and re-read against §1.13.
- [ ] `tests.json` carries the four entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T06: Settings DISPLAY and FEEDBACK; ThemePreference with the darker-colours forcing rule; DrawnToggleStyle"`

## Out of scope

- PLAY, VOICEOVER, LANGUAGE and DATA — **T07**, **T08**.
- Every downstream *effect* of the seven rows — the table above names the owning epic for each.
- `RenderEnv` itself, the palette, the three themes and the resolution order — **E03**.
- The eleven other languages for the 17 strings, and the pseudolocale gate — **E18·T03/T09**.
- The `.tint` question for `AboutView` — **T05** already neutralised its container the same way.
- Bold Text, Reduce Transparency and Differentiate Without Colour as *system* settings — **E19·T08**; this task only ships the app's own four DISPLAY rows.
