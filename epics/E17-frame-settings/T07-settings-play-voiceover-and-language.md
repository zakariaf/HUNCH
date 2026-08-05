# T07 — Settings: PLAY, VOICEOVER and LANGUAGE

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | PLAY + VOICEOVER · LANGUAGE |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-chrome-and-meta` | `references/stock-controls.md` §4 is the ruling this task needs most: *"The language picker (13 entries) is always `.navigationLink`"* — thirteen endonyms are not a segmented control at any type size — plus the segmented/inline rule for VoiceOver Detail and the `Text(verbatim: Loc.x)` call-site rule that a `Loc` accessor already resolved its string. |
| `hunch-accessibility` | Owns *what a VoiceOver string says and whether it speaks at all*, which is the entire content of the three VOICEOVER rows. It fixes Detail's semantics (Terse omits attributes unchanged from the previous glyph, which is why every label builder takes `relativeTo previous: Glyph?`), the announcement order these toggles gate, and the 134-key accessibility budget a new label would spend. It also carries the "never concatenate translated fragments" law the language picker's endonyms sit next to. |

## Objective

At the end of this task the last three preference sections exist: PLAY (Confirm the Seal, Steady
stream), VOICEOVER (Detail, Announce verdicts, Announce the Assay) and LANGUAGE (a 13-option picker
defaulting to System, presented as a `.navigationLink`). All thirteen `hunch.settings.` keys are now
written and read, `UserDefaults` is named in exactly one file, and a hygiene check makes "preferences
only, game state never" mechanical.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.6 | the five PLAY/VOICEOVER rows and the LANGUAGE row verbatim — type, default, effect, key; *"Announce the Assay … Off by default because it is very chatty"*; Confirm the Seal is a second tap within 2.0 s, for tremor and one-handed play |
| `GAME_DESIGN.md` | §12.6 | the persistence sentence: everything under `hunch.settings.` in `UserDefaults.standard`, **preferences only**, game state in JSON |
| `GAME_DESIGN.md` | §9.8, §12.6 | Steady stream fixes `r` at `r₀` with no ramp at a 0.85 multiplier, is **not** gated behind an accessibility flag, and does not disable Codex inscription |
| `GAME_DESIGN.md` | §12.7, §9.2 | Confirm-by-repeat exists exactly twice in the app — this row and SIEVE's paused abandon chevron |
| `GAME_DESIGN.md` | §13.10 | what Detail Full/Terse changes, and the announcement set the two Announce toggles gate |
| `GAME_DESIGN.md` | §12.9 | the twelve languages plus System = 13 options; the endonyms are **constants, not translation units**; the option-label budget (App language contributes exactly one key, "System") |
| `GAME_DESIGN.md` | §12.9 | the override's two traps — layout direction is not derived from `\.locale`, and every string must go through one accessor carrying bundle *and* locale — and that `AppleLanguages` is for the next cold launch only |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3, §6 | `Mode.wordmark` rendered `Text(verbatim:)`; no `…Manager`; `@Entry` for ambient values |

**Do not implement the override mechanism here.** §12.9's `Loc` accessor, the explicit
`layoutDirection` on the root and the no-relaunch test are **E18·T05**'s. This task ships the picker,
the key and its default.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/MetaFeatureTests/PlayAndVoiceOverPreferenceTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("PLAY, VOICEOVER and LANGUAGE preferences — §12.6", .tags(.unit, .presubmission))
struct PlayAndVoiceOverPreferenceTests {

    private func emptyStore(_ name: String = #function) -> UserDefaults {
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    @Test("§12.6's defaults for the six remaining rows")
    func defaults() {
        let p = PreferenceReader(store: emptyStore())
        #expect(p.confirmSeal == false)
        #expect(p.steadyStream == false)
        #expect(p.voiceOverDetail == .full)
        #expect(p.announceVerdicts == true)
        #expect(p.announceAssay == false)          // "very chatty" — §12.6
        #expect(p.languageTag == .system)
    }

    @Test("the language picker offers System plus the twelve shipped languages, and no thirteenth")
    func languageOptions() {
        #expect(LanguageOption.allCases.count == 13)
        #expect(LanguageOption.allCases.first == .system)
        let tags = LanguageOption.allCases.compactMap(\.bcp47)
        #expect(tags == ["en", "de", "fr", "es", "pt-BR", "it", "tr", "ru", "ja", "ko", "zh-Hans", "ar"])
        #expect(Set(tags).count == 12)
    }

    @Test("every endonym is a constant, not a catalogue key", arguments: LanguageOption.allCases)
    func endonymsAreConstants(_ option: LanguageOption) {
        switch option {
        case .system:
            #expect(option.catalogueKey != nil)     // exactly one key: "System"
        default:
            #expect(option.catalogueKey == nil)
            #expect(!option.endonym.isEmpty)
        }
    }

    @Test("a language tag round-trips through UserDefaults as a BCP-47 string")
    func languageTagPersists() {
        let store = emptyStore()
        PreferenceWriter(store: store).set(.languageTag, to: LanguageOption.arabic)
        #expect(store.string(forKey: Preference.Key.languageTag.storageKey) == "ar")
        #expect(PreferenceReader(store: store).languageTag == .arabic)
    }

    @Test("System persists as the literal \"system\", never as an empty string or a nil")
    func systemPersistsExplicitly() {
        let store = emptyStore()
        PreferenceWriter(store: store).set(.languageTag, to: LanguageOption.system)
        #expect(store.string(forKey: Preference.Key.languageTag.storageKey) == "system")
    }

    @Test("Confirm the Seal is the only confirm-by-repeat this task adds, and its window is 2.0 s")
    func confirmSealWindow() {
        #expect(SealConfirmation(isEnabled: true).window == .seconds(2))
        #expect(SealConfirmation(isEnabled: false).requiresSecondTap == false)
        #expect(SealConfirmation(isEnabled: true).requiresSecondTap == true)
    }

    @Test("a second tap outside the window is a first tap again, not a commit")
    func confirmSealWindowExpires() {
        var confirmation = SealConfirmation(isEnabled: true)
        #expect(confirmation.tap(at: .zero) == .armed)
        #expect(confirmation.tap(at: .milliseconds(2_001)) == .armed)
        #expect(confirmation.tap(at: .milliseconds(3_000)) == .committed)
    }

    @Test("Steady stream is ungated: no accessibility flag reaches it")
    func steadyStreamIsUngated() {
        for env in [RenderEnv.standard, .reduceMotion, .highContrast, .boldText] {
            #expect(SteadyStream.isOffered(in: env) == true)
        }
        #expect(SteadyStream.scoreMultiplier == 0.85)
        #expect(SteadyStream.disablesInscription == false)
    }
}
```

And `Modules/Tests/MetaFeatureTests/UserDefaultsScopeTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("UserDefaults holds preferences only — §12.6", .tags(.unit, .presubmission))
struct UserDefaultsScopeTests {

    @Test("after writing every preference, the domain holds exactly thirteen keys and all are ours")
    func domainIsExactlyTheThirteen() {
        let name = #function
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        let writer = PreferenceWriter(store: store)
        for key in Preference.Key.allCases { writer.writeDefault(key) }

        let written = Set(store.persistentDomain(forName: name)?.keys.map(String.init) ?? [])
        #expect(written == Set(Preference.Key.allCases.map(\.storageKey)))
    }

    @Test("no StoreFile has a UserDefaults counterpart — game state never lands here")
    func noStoreFileLeaks() {
        for file in StoreFile.allCases {
            #expect(!Preference.Key.allCases.contains { $0.rawValue.lowercased().contains(file.slug) },
                    "\(file) has a preference key shaped like it")
        }
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path Modules --filter "PlayAndVoiceOverPreferenceTests|UserDefaultsScopeTests"`

Failures must be missing symbols — `LanguageOption`, `SealConfirmation`, `SteadyStream` — or a
default that contradicts §12.6. `defaults` passing before `PreferenceReader` knows the six new keys
means it is returning zero values; check `announceVerdicts` is `true` and not the `Bool` default.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/MetaFeature/SettingsSection+Play.swift` |
| create | `Modules/Sources/MetaFeature/SettingsSection+VoiceOver.swift` |
| create | `Modules/Sources/MetaFeature/SettingsSection+Language.swift` |
| create | `Modules/Sources/MetaFeature/LanguageOption.swift` |
| create | `Modules/Sources/HunchUI/SealConfirmation.swift` |
| modify | `Modules/Sources/MetaFeature/Preference.swift` — the reader/writer accessors for the six remaining keys |
| modify | `Modules/Sources/MetaFeature/SettingsView.swift` — mount the three sections |
| modify | `Scripts/check-source-hygiene.sh` — add **check 12**: `UserDefaults` named in exactly one file |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — 3 section headers, 6 row labels, 3 option labels ("Full", "Terse", "System"), English only |
| create | `Modules/Tests/MetaFeatureTests/PlayAndVoiceOverPreferenceTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/UserDefaultsScopeTests.swift` |
| modify | `tests.json` — four entries: the six defaults, the 13-option language inventory, the confirm window, and the UserDefaults scope |

## Implementation notes

### `LanguageOption` — thirteen options, twelve of which cost no catalogue key

```swift
// Modules/Sources/MetaFeature/LanguageOption.swift
public enum LanguageOption: String, CaseIterable, Sendable {
    case system                                  // the default, and the ONLY translated label
    case english = "en", german = "de", french = "fr", spanish = "es"
    case portugueseBrazil = "pt-BR", italian = "it", turkish = "tr", russian = "ru"
    case japanese = "ja", korean = "ko", simplifiedChinese = "zh-Hans", arabic = "ar"

    /// `nil` for `.system`, whose row is a translated label.
    public var bcp47: String? { self == .system ? nil : rawValue }

    /// The language's own name in its own script — "Deutsch", "日本語", "العربية".
    /// §12.9: *"Excludes the 12 language endonyms, which are constants, not translation units"*.
    public var endonym: String { … }

    /// Exactly one option has a catalogue key, and it is "System".
    public var catalogueKey: String? { self == .system ? "settings.language.system" : nil }
}
```

**Why the endonyms are constants.** A French speaker choosing German should see "Deutsch", not
"Allemand" — the picker is a list of languages *as their speakers name them*, so translating them
would be wrong twelve times over, and it would cost 12 × 12 = 144 catalogue units against a 250-key
budget. §12.9 makes the ruling; this file makes it mechanical by giving `.system` the only
`catalogueKey`.

**The rawValue is the persisted tag**, so `.arabic` writes `"ar"` and `.system` writes `"system"` —
never an empty string and never a removed key, because "absent" and "System" would then be
indistinguishable from "written by a build that did not know this key".

**`.navigationLink`, always** (`stock-controls.md` §4). Thirteen endonyms in one row is not a
segmented control at any type size, and unlike the other four pickers this one does not branch on
`env.isArtScaleClamped` — it has one style at every size.

### Confirm the Seal — the second of the app's two confirm-by-repeats

§12.7 is explicit: *"That confirm-by-repeat and the Seal's optional one (§12.6) are the only two in
the app."* So model it once, as a value, and let both the Seal and SIEVE's abandon chevron be the two
call sites — do not let a third appear.

```swift
// Modules/Sources/HunchUI/SealConfirmation.swift
public struct SealConfirmation: Sendable {
    public enum Outcome: Sendable { case armed, committed }

    public let isEnabled: Bool
    public var window: Duration { .seconds(2) }       // §12.6
    public var requiresSecondTap: Bool { isEnabled }

    private var armedAt: Duration?
    public mutating func tap(at now: Duration) -> Outcome { … }
}
```

The window is a `Duration`, never a `Double` — a bare `2` is ambiguous between seconds and
milliseconds and both spellings appear in the GDD (`hunch-design-tokens/SKILL.md`). The `2.0 s` is a
duration token, so declare it in `durations-and-easing.md` and read it as `Dur.sealConfirm`; a
literal fails check 9.

**The clock is passed in.** `tap(at:)` takes the instant rather than reading one, so the expiry test
is three lines with no `Task.sleep` (`06 T27`: never sleep in a test). At the call site the instant
comes from the same `ContinuousClock` the view already has; there is no `Clock` abstraction in this
project and this task must not add one (`hunch-swift-code/SKILL.md`'s one home for that rule).

**Off by default**, and when off the Seal commits on the first tap exactly as it does today —
`requiresSecondTap == false` is the whole of it. Wiring it into `BenchView`'s `seal()` is a
one-condition change to E09·T07's file.

### Steady stream — ungated, and the test says so

§9.8 and §12.6 both stress that Steady stream is **not** behind an accessibility flag, does not
disable Codex inscription and costs 0.85 of the score. `steadyStreamIsUngated` asserts all three,
because each is a thing a well-meaning later edit would break: "only offer it under Reduce Motion"
looks like a kindness and is a way of telling a player their setting is a disability aid, and
"disable inscription because it is easier" would make a legitimate play style second class.

The `0.85` multiplier itself is E14·T09's constant and lives there; this test reads it rather than
declaring it. If `SteadyStream.scoreMultiplier` does not exist yet, the assertion is the forcing
function — add the constant to E14's file, not a second copy here.

### The three VOICEOVER rows ship the switch, not the speech

| Row | What this task ships | What reads it |
|---|---|---|
| Detail (Full / Terse) | a two-way segmented control and the key | the glyph label builder, which takes `relativeTo previous: Glyph?` — **E19·T02** |
| Announce verdicts (On) | a toggle and the key | `Announcer` posting on every `admit`/`reject` — **E19·T05** |
| Announce the Assay (Off) | a toggle and the key | the Bench's per-edit admit-count announcement — **E19·T04** |

`hunch-accessibility/SKILL.md`'s gotcha is the one to honour now rather than later: *"Terse mode needs
the previous glyph … a builder without it cannot implement the setting later without changing every
call site."* If E19's label builders do not yet take `relativeTo:`, this is the task that adds the
parameter — the setting exists from here on and a builder that cannot see the previous glyph is a
setting that cannot work.

**Announce the Assay is off by default and stays off.** §12.6 gives the reason in the table itself
("it is very chatty"), and `defaults` asserts it. Flipping it to on would post an announcement on
every Bench edit — which is every tap on a 19-cell surface.

### Check 12 — `UserDefaults` in exactly one file

```bash
# 12. §12.6: UserDefaults holds preferences only, and one file owns the prefix.
hits=$(grep -rl "UserDefaults" --include='*.swift' Modules/Sources HunchCore/Sources | sort)
expected="Modules/Sources/MetaFeature/Preference.swift"
[ "$hits" = "$expected" ] || fail "UserDefaults is referenced outside Preference.swift: $hits"
```

`@AppStorage` is *not* caught by this grep and does not need to be — it is keyed through
`Preference.Key.storageKey`, so the prefix still has one home, and check 12's job is to stop a second
file reaching for `UserDefaults.standard` directly to stash "just one thing". That "one thing" is
always game state.

`UserDefaultsScopeTests.noStoreFileLeaks` is the other half: it walks `StoreFile.allCases` — the ten
on-disk files (E07·T01) — and asserts none of them has a preference key shaped like it. Together they
make §12.6's sentence a build failure rather than a convention.

### The strings

Twelve new keys: 3 section headers (PLAY, VOICEOVER, LANGUAGE), 6 row labels, 3 option labels (Full,
Terse, System). With T06's 17 and T08's 5 row labels this reaches §12.9's 37 for Settings. Each is
≤ 22 characters in English and budgeted at +40 % for German, Russian and Turkish; each goes through
`Loc` and is rendered `Text(verbatim:)`.

Section headers take the `type.section` role, are cased **in `Loc` with
`String.uppercased(with: locale)`**, and carry `.textCase(nil)` so the system cannot apply a second,
locale-unaware uppercase on top (`stock-controls.md` §3). Turkish maps `i → İ` and the naive path
gives `I`; Arabic is caseless and a transform mangles shaping.

### VoiceOver on this screen

Stock controls carry their own contract, and that is the entire reason they are stock: give a
`Toggle` a label and the system says "switch button, on". **Do not re-label, do not add `.isButton`,
do not wrap in an `.accessibilityElement`** — §13.12 gate 4 is an Accessibility Inspector audit that
must be clean on every screen, and hand-decorating a stock control is the usual way it stops being.

The `.navigationLink` picker announces its selected value for free; the endonyms are read in their
own script by the system's own language detection, which is another reason not to translate them.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter "PlayAndVoiceOverPreferenceTests|UserDefaultsScopeTests"` green, all ten tests.
- [ ] `Scripts/check-source-hygiene.sh` check 12 exists and was demonstrated to fail on a planted `UserDefaults.standard` in a second file before being reverted — the failure message pasted into the commit message.
- [ ] `grep -rn "UserDefaults" Modules/Sources HunchCore/Sources` returns hits in `Preference.swift` only.
- [ ] `Preference.Key.allCases.count == 13` and every one of the thirteen is now both written and read — `grep -rn "Preference.Key." Modules/Sources | wc -l` shows each key referenced at least twice.
- [ ] `grep -rn "\"Deutsch\"\|\"日本語\"\|\"العربية\"" Modules/Sources/MetaFeature/LanguageOption.swift` finds the endonyms as Swift constants, and `grep -c endonym Modules/Sources/HunchUI/Resources/Localizable.xcstrings` returns 0.
- [ ] `grep -rn "\.seconds(2)\|2\.0" Modules/Sources/HunchUI/SealConfirmation.swift` returns nothing; the window is `Dur.sealConfirm`.
- [ ] `grep -rn "Task.sleep" Modules/Tests/MetaFeatureTests/` returns nothing.
- [ ] `grep -rn "pickerStyle" Modules/Sources/MetaFeature/SettingsSection+Language.swift` shows `.navigationLink` with no conditional.
- [ ] Simulator walk recorded in the commit message: every one of the six rows toggled and confirmed persisted across a relaunch; the language picker opened and each of the thirteen rows read in its own script; Confirm the Seal turned on and the Seal confirmed to need two taps within 2 s and one tap after.
- [ ] The 12 English strings are ≤ 22 characters each and re-read against §1.13.
- [ ] `tests.json` carries the four entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T07: Settings PLAY, VOICEOVER and LANGUAGE; check 12 scopes UserDefaults to preferences"`

## Out of scope

- The language **override mechanism** — the `Loc` accessor carrying bundle and locale, the explicit `layoutDirection` on the root, the `AppleLanguages` write for the next cold launch, and the no-relaunch test — **E18·T05**. This task ships the picker and the key.
- Translating any of the twelve endonyms, ever — §12.9 forbids it.
- What Detail, Announce verdicts and Announce the Assay actually say — **E19·T02/T04/T05**.
- Steady stream's `r₀` behaviour and its 0.85 multiplier — **E14·T09**.
- Wiring Confirm the Seal into `BenchView.seal()` beyond the one condition — the Seal itself is **E09·T07**.
- DATA and the five reset alerts — **T08**.
