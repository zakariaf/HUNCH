# T07 — Plurals, formats and script profiles

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | LOCALIZATION → Plurals, formats, scripts; ART / MOTION → Typography (the per-script half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Loaded first, because this task changes how a type role resolves. It owns the seven roles and their tracking in em (`references/type-ramp.md` §1, §3), which two roles are uppercased and **by which call** (§4), and the mandatory monospaced numeral (§5). It also owns the ruling this task has to reconcile against §12.9 trap 5 — see *The one conflict* below. |
| `hunch-chrome-and-meta` | It owns every surface a number or a date is rendered on: `references/numeral-readout.md` is the resolved table of where a numeral may appear at all (three sections of the GDD disagree and that file is the resolution), and `references/stock-controls.md` is the four screens where a formatted value sits beside a localized label. |

## Objective

At the end of this task every counted thing in the app reads its plural form out of a String Catalog
variation — Russian's four categories and Arabic's six included — with no concatenated fragment and
no `count == 1` anywhere in the codebase; every date, number and measurement is produced by
`Date.FormatStyle`, `NumberFormatter` or `Measurement` against the resolved locale; and Arabic,
Japanese, Korean and Simplified Chinese render under a typographic profile that turns off small
caps and letterspacing and raises the line height, while Turkish uppercases through
`String.uppercased(with: locale)` and gets its dotless ı right.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 trap 3 | never concatenate translated fragments — one format string per sentence, interpolations only |
| `GAME_DESIGN.md` | §12.9 trap 4 | plurals are per-language grammar: Russian needs four categories, Arabic six; **any `count == 1 ? … : …` in the codebase is a bug** |
| `GAME_DESIGN.md` | §12.9 trap 5 | Turkish dotless ı; `"i".uppercased()` is `"I"`, which is wrong in Turkish |
| `GAME_DESIGN.md` | §12.9 trap 6 | ar / ja / ko / zh-Hans take a per-script profile: no small caps, no negative tracking, taller line height — the instrument aesthetic is carried by rules and spacing there, not by letterforms |
| `GAME_DESIGN.md` | §12.9 trap 7 | locale-native numerals are **allowed**, because the play surface uses ticks and notches rather than numerals — Eastern Arabic digits in the Codex are correct |
| `GAME_DESIGN.md` | §13.4 | the seven roles, which two are uppercased, tracking stored in em, `minimumScaleFactor` 1.0 everywhere, and that uppercasing uses `String.uppercased(with: locale)` and never a display transform |
| `GAME_DESIGN.md` | §11.12 | *"every number is formatted with `Date.FormatStyle` / `NumberFormatter` / `Measurement`, never string arithmetic"* |
| `GAME_DESIGN.md` | §13.10 | the `pips` interpolation is itself a plural-aware entry and a complete grammatical unit |
| `.claude/skills/hunch-design-tokens/references/type-ramp.md` | §4 | the uppercasing call, and the three shipped-bug reasons behind it |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/PluralTests.swift`:

```swift
import Foundation
import Testing
import HunchUI

/// §12.9 trap 4. CLDR gives Russian four plural categories (one/few/many/other) and Arabic six
/// (zero/one/two/few/many/other). The assertion is not "the translation is right" — that is T03's
/// native review — it is "the catalog entry HAS the categories", which is what a machine draft
/// silently omits and what a `count == 1` ternary makes impossible.
@Suite("Plurals — catalog variations, never a ternary", .tags(.unit, .presubmission))
@MainActor
struct PluralTests {

    /// CLDR's category-triggering counts. Each row is (locale, counts that must produce distinct
    /// strings, the number of distinct forms CLDR requires).
    static let expectations: [(locale: String, counts: [Int], distinct: Int)] = [
        ("en",      [1, 2],                     2),   // one, other
        ("ru",      [1, 2, 5, 0],                4),   // one, few, many, other
        ("ar",      [0, 1, 2, 3, 11, 100],       6),   // zero, one, two, few, many, other
        ("ja",      [0, 1, 2, 5],                1),   // other only — and that is correct
        ("tr",      [1, 2],                      2),
    ]

    @Test("Every plural-bearing key produces the categories its language requires",
          arguments: expectations, LocKey.pluralBearing)
    func pluralCategoriesResolve(
        _ expectation: (locale: String, counts: [Int], distinct: Int),
        _ key: LocKey
    ) throws {
        let loc = try #require(Loc.forTesting(languageTag: expectation.locale))
        let forms = Set(expectation.counts.map { loc.plural(key, count: $0) })
        #expect(forms.count == expectation.distinct,
                "\(expectation.locale)/\(key.rawValue): \(forms.count) forms, expected \(expectation.distinct)")
        #expect(!forms.contains { $0.contains(key.rawValue) })
    }

    /// The number inside the string is formatted, not interpolated by `\(count)` into a Swift
    /// string — so Arabic gets Eastern Arabic digits (§12.9 trap 7) and Russian gets a non-breaking
    /// space before its group separator.
    @Test("A plural string carries a locale-formatted numeral")
    func pluralNumeralIsLocaleFormatted() throws {
        let arabic = try #require(Loc.forTesting(languageTag: "ar"))
        let rendered = arabic.plural(.probeCount, count: 12)
        #expect(rendered.contains("١٢") || rendered.contains("12"))
        #expect(!rendered.contains("%"))
    }

    /// §12.9 trap 3. `GLYPH_LABEL` is the canonical case: four positional interpolations, and a
    /// translator must be able to reorder them.
    @Test("A format string's arguments are positional and reorderable")
    func formatArgumentsArePositional() throws {
        for tag in TwelveLanguageTests.locales {
            let loc = try #require(Loc.forTesting(languageTag: tag))
            let raw = loc[.glyphLabel]
            #expect(raw.contains("%1$@"), "\(tag) lost its positional specifiers")
            #expect(raw.contains("%4$@"))
        }
    }
}
```

and `Modules/Tests/HunchUITests/FormattingAndScriptTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import Tokens
import HunchUI

@Suite("Formats and script profiles", .tags(.unit, .presubmission))
@MainActor
struct FormattingAndScriptTests {

    /// §12.9 trap 5. `"i".uppercased()` is `"I"`, which is wrong in Turkish; the app's uppercasing
    /// path must go through the locale. This is the whole test, and it is two lines.
    @Test("Uppercasing is locale-aware — Turkish dotless ı")
    func uppercasingIsLocaleAware() {
        let turkish = Locale(identifier: "tr")
        #expect(TypeRole.section.uppercased("bilgi", locale: turkish) == "BİLGİ")
        #expect(TypeRole.section.uppercased("bilgi", locale: Locale(identifier: "en")) == "BILGI")
    }

    /// §12.9 trap 6. Arabic is caseless and letterspacing breaks its cursive joining; CJK has no
    /// case and negative tracking crushes it. The profile is per SCRIPT, not per language.
    @Test("The four non-cased scripts take the flat profile",
          arguments: ["ar", "ja", "ko", "zh-Hans"])
    func nonCasedScriptsTakeTheFlatProfile(_ tag: String) {
        let profile = ScriptProfile(locale: Locale(identifier: tag))
        #expect(profile.isUppercased == false)
        #expect(profile.trackingScale == 0)
        #expect(profile.lineHeightScale > 1.0)
    }

    /// …and the eight cased locales keep the instrument-panel look unchanged.
    @Test("Every cased locale keeps the shipped ramp",
          arguments: ["en", "de", "fr", "es", "pt-BR", "it", "tr", "ru"])
    func casedLocalesKeepTheRamp(_ tag: String) {
        let profile = ScriptProfile(locale: Locale(identifier: tag))
        #expect(profile.isUppercased)
        #expect(profile.trackingScale == 1)
        #expect(profile.lineHeightScale == 1)
    }

    /// The profile applies to the two uppercased roles and to nothing else. `type.body` was never
    /// uppercased and must not acquire a profile-shaped branch.
    @Test("Only section and micro are affected", arguments: [TypeRole.section, .micro])
    func onlyTheUppercasedRolesAreAffected(_ role: TypeRole) {
        #expect(role.isUppercased)
        for other in [TypeRole.display, .title, .body, .caption, .numeral] {
            #expect(other.isUppercased == false)
        }
    }

    /// §11.12: every number is formatted, never assembled. Assert the resolved locale reaches the
    /// formatter rather than `Locale.current` — a French player on an English phone gets French
    /// dates in the Codex (§12.9).
    @Test("Dates, numbers and measurements read the resolved locale")
    func formattersReadTheResolvedLocale() {
        let french = Locale(identifier: "fr")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(Formats.codexDate(date, locale: french)
             != Formats.codexDate(date, locale: Locale(identifier: "en_US")))
        #expect(Formats.count(1234, locale: french).contains("\u{202F}")
             || Formats.count(1234, locale: french).contains("\u{00A0}"))
        #expect(Formats.count(1234, locale: Locale(identifier: "en_US")) == "1,234")
    }

    /// §13.4 and `type-ramp.md` §3: tracking is stored in em and applied as scaledSize × em, so it
    /// survives AX5. A fixed-point tracking value would collapse exactly where legibility matters.
    @Test("Tracking scales with the resolved size")
    func trackingScalesWithSize() {
        let atLarge = TypeRole.micro.tracking(atScaledSize: 11)
        let atAX5 = TypeRole.micro.tracking(atScaledSize: 29)
        #expect(atAX5 > atLarge * 2)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/PluralTests \
  -only-testing:HunchUITests/FormattingAndScriptTests
```

`pluralCategoriesResolve` must fail with *one* form where four or six are expected — that is
precisely what a T03 machine draft leaves behind, a single `stringUnit` where a
`variations.plural` block belongs. `uppercasingIsLocaleAware` must fail with `BILGI` in Turkish if
the shipped path is `.uppercased()`; if it already passes, `type-ramp.md` §4 was implemented
correctly in E03·T02 and this half of the task is an assertion rather than a change — say so in the
commit message rather than deleting the test.

**Step 3 — implement.** The catalog variations, `ScriptProfile`, `Formats`, and the two lints.

**Step 4 — green, then refactor.** Read the Statistics screen in Arabic and in Japanese on a device.
Numerals, line height and section heads are the three things that will look wrong, and all three are
in this task.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — `variations.plural` on every plural-bearing key in all twelve locales |
| modify | `Modules/Sources/HunchUI/Loc.swift` — `plural(_:count:)` and the other interpolating accessors |
| modify | `Modules/Sources/HunchUI/LocKey.swift` — `pluralBearing` |
| create | `Modules/Sources/HunchUI/ScriptProfile.swift` |
| create | `Modules/Sources/HunchUI/Formats.swift` |
| modify | `Modules/Sources/HunchUI/Typography.swift` — the two uppercased roles resolve through `ScriptProfile`; `uppercased(_:locale:)` |
| modify | `Modules/Sources/MetaFeature/StatisticsView.swift`, `Modules/Sources/CodexFeature/CodexPageView.swift`, `Modules/Sources/MetaFeature/AnomalyView.swift`, `AboutView.swift` — every numeral and date through `Formats` |
| create | `Modules/Tests/HunchUITests/PluralTests.swift` |
| create | `Modules/Tests/HunchUITests/FormattingAndScriptTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — append the `count == 1` / concatenation check and the raw-formatter check |
| modify | `tests.json` — seven entries |
| modify | `DECISIONS.md` — the §12.9 trap 5 / `type-ramp.md` §4 reconciliation |

## Implementation notes

### The one conflict, resolved and written down

§12.9 trap 5 says the instrument-panel small caps *"must come from the font's `smcp` feature, never
from `.uppercased()`"*. `hunch-design-tokens` `references/type-ramp.md` §4 says the opposite —
`String.uppercased(with: locale)`, **never** the font's small-caps feature — and gives three
shipped-bug reasons, one of which is that SF Pro's small-caps feature degrades non-Latin to full
caps.

**The token skill wins, and §12.9 trap 5's real concern is honoured anyway.** The reconciliation:

- The banned thing in trap 5 is **bare `.uppercased()`**, and that stays banned — it is the dotless-ı
  bug and it is the second half of trap 5's own sentence: *"if a locale-aware uppercase is ever
  unavoidable it is `.uppercased(with: locale)`"*. It is unavoidable, so that is the call.
- `smcp` cannot be the mechanism in a twelve-language app for the exact reason trap 6 states next:
  Arabic, Japanese, Korean and Chinese must not receive small caps at all. A font feature applies
  per-run and cannot be conditioned on script as cleanly as a resolved profile can.
- The result is identical to what trap 5 wants everywhere trap 5 applies: cased scripts get
  letterspaced uppercase section heads; the four non-cased scripts get the flat profile, which is
  what trap 6 asks for in the very next paragraph.

Write this in `DECISIONS.md` naming both sources and both rulings. A future reader finding
`.uppercased(with:)` where §12.9 says `smcp` will otherwise "fix" it.

### `ScriptProfile`

```swift
// Modules/Sources/HunchUI/ScriptProfile.swift
/// §12.9 trap 6. Keyed on the resolved locale's SCRIPT, not on its language: the rule is about
/// letterforms, and a language written in more than one script would need both answers.
public struct ScriptProfile: Sendable, Hashable {
    /// Arabic is caseless and letterspacing breaks its cursive joining; CJK has no case at all.
    public let isUppercased: Bool
    /// Multiplies `TypeRole.trackingEm`. 0 for the four; 1 everywhere else. Never negative —
    /// §13.4's ramp carries no negative tracking, and trap 6's "no negative tracking" is therefore
    /// a floor this cannot cross rather than a value to compute.
    public let trackingScale: Double
    /// Arabic ascenders/descenders and CJK ideographs both need more leading than Latin at the
    /// same point size.
    public let lineHeightScale: Double

    public init(locale: Locale) {
        let script = locale.language.script?.identifier
            ?? Locale.Language(identifier: locale.identifier).script?.identifier
        switch script {
        case "Arab", "Jpan", "Hani", "Hans", "Hant", "Hang", "Kore":
            self.init(isUppercased: false, trackingScale: 0, lineHeightScale: 1.15)
        default:
            self.init(isUppercased: true, trackingScale: 1, lineHeightScale: 1)
        }
    }
}
```

Resolve the script from the **locale**, not from a hard-coded list of four tags. `Locale.Language`
carries a `script` that Foundation infers from the language when it is not written out (`ja` → `Jpan`,
`ko` → `Kore`, `zh-Hans` → `Hans`, `ar` → `Arab`) — verify each of the four resolves as expected in
the test before relying on it, because a `nil` script falls into the cased branch and would silently
letterspace Arabic. `nonCasedScriptsTakeTheFlatProfile` is that verification.

`ScriptProfile` reads the locale, and the locale comes from `\.locale` which T05 installs from the
resolution — so a player who overrides to Japanese on a German phone gets the Japanese profile, not
the German one. That is the whole reason it is not read from `Bundle.main`.

### Wiring it into the two roles, and only the two

```swift
extension TypeRole {
    /// `type-ramp.md` §4: which roles are uppercased, and by which call.
    public func uppercased(_ text: String, locale: Locale) -> String {
        guard isUppercased, ScriptProfile(locale: locale).isUppercased else { return text }
        return text.uppercased(with: locale)      // NEVER `.uppercased()` — §12.9 trap 5
    }

    public func tracking(atScaledSize size: Double, locale: Locale) -> Double {
        size * trackingEm * ScriptProfile(locale: locale).trackingScale
    }
}
```

`type.section` and `type.micro` are the only two roles with `isUppercased`, and no third role
acquires one — `onlyTheUppercasedRolesAreAffected` is the guard. Applying the profile inside the
role, rather than at each of the ~30 call sites, is what keeps the Statistics screen from growing a
`if locale.isArabic` branch per section head.

**`minimumScaleFactor` stays 1.0 everywhere, no exceptions** (§13.4, `type-ramp.md` §3). The taller
line height makes rows grow; that is the intended outcome and T09's pseudolocale sweep is what
confirms nothing overflows because of it.

### `Formats` — one home for every rendered number

```swift
// Modules/Sources/HunchUI/Formats.swift
/// §11.12: every number is formatted with Date.FormatStyle / NumberFormatter / Measurement, never
/// string arithmetic. Every function takes the resolved locale explicitly — a default of
/// `.current` is how `Locale.current` creeps back in after T05 removed it.
public enum Formats {
    public static func codexDate(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    public static func count(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    public static func percentage(_ fraction: Double, locale: Locale) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    public static func storage(_ bytes: Int64, locale: Locale) -> String {
        Measurement(value: Double(bytes), unit: UnitInformationStorage.bytes)
            .formatted(.measurement(width: .abbreviated).locale(locale))
    }
}
```

`storage` is `AboutView`'s storage-status line and is the one genuine `Measurement` in the app —
§11.12 names all three APIs and this is the third. Do not invent a second measurement to justify it.

Two things `Formats` must **not** do. It must not surface a percentage of the law space, a global
completion meter, a percentile or a rank (`hunch-chrome-and-meta`'s *Never* list, §11.2, §11.11);
`percentage` exists for the Statistics screen's solve rate and for nothing else. And it must not be
used on the play surface, which renders no numerals at all — `references/numeral-readout.md` holds
the resolved site table and it is shorter than any of the three §-lists that disagree.

### The plural entries

A plural-bearing key in a String Catalog is a `variations.plural` block keyed by CLDR category,
with the substitution on `%lld`:

```json
"PROBE_COUNT" : {
  "extractionState" : "manual",
  "comment" : "§13.10 value format. VoiceOver only. Plural-bearing: ru needs 4, ar needs 6.",
  "localizations" : {
    "ru" : { "variations" : { "plural" : {
      "one"   : { "stringUnit" : { "state" : "translated", "value" : "%lld проба" } },
      "few"   : { "stringUnit" : { "state" : "translated", "value" : "%lld пробы" } },
      "many"  : { "stringUnit" : { "state" : "translated", "value" : "%lld проб" } },
      "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld пробы" } }
    } } }
  }
}
```

The categories a locale needs are CLDR's and are not a matter of taste: `ru` has `one/few/many/other`,
`ar` has `zero/one/two/few/many/other`, `ja`/`ko`/`zh-Hans` have `other` alone, and `en`/`de`/`fr`/
`es`/`pt-BR`/`it`/`tr` have `one/other`. Providing a category a locale does not use is harmless;
omitting one it does use is the bug `pluralCategoriesResolve` catches.

**The set of plural-bearing keys** is §12.9's *"value formats (probes-of-par, marks, band, streak) —
8, plural-bearing"* plus §13.10's `pips` interpolation. Enumerate them as `LocKey.pluralBearing` and
send the list to T03's reviewers as a second, smaller round rather than a separate contact.

The accessor is the `StaticString`-key form T01 established, because the count has to reach the
lookup for Foundation to select a category:

```swift
public func plural(_ key: LocKey, count: Int) -> String { … }
```

Implement it with a `switch` over `LocKey.pluralBearing` mapping each case to its
`String(localized: "…", defaultValue: "\(count) …", bundle:locale:)` call — the key literal must be
static, so the switch is the price. Eight-plus arms is not elegant; a dynamic key that silently
loses plural selection is worse, and the switch is exhaustive with no `default:` (`W29`) so adding
a plural key without an arm is a compile error.

### The two hygiene checks

Determine the next free numbers first (`grep -oE '^# +[0-9]+\.' Scripts/check-source-hygiene.sh | tail -1`).

```bash
# N. §12.9 trap 4 and trap 3: no plural ternary, no fragment concatenation. A `count == 1 ? … : …`
#    is right in English, wrong in Russian and wrong in Arabic twice over.
if [ "${#uiRoots[@]}" -gt 0 ]; then
  plural='(count|n|probes|pages|days|marks)[[:space:]]*[=!]=[[:space:]]*1[[:space:]]*\?'
  glue='loc\[[^]]*\][[:space:]]*\+|\+[[:space:]]*loc\[|joined\(separator:'
  hits=$(grep -rHnE "$plural|$glue" --include='*.swift' "${uiRoots[@]}" | grep -vE 'LOC-EXEMPT' || true)
  [ -n "$hits" ] && report 'A plural ternary or a glued fragment (§12.9 traps 3 and 4):' "$hits"
fi

# N+1. §11.12: every number is formatted, never assembled; §12.9 trap 5: never a bare uppercase.
if [ "${#uiRoots[@]}" -gt 0 ]; then
  raw='DateFormatter\(|NumberFormatter\(|String\(format:|\.uppercased\(\)|\.lowercased\(\)|%\.[0-9]f'
  hits=$(grep -rHnE "$raw" --include='*.swift' "${uiRoots[@]}" \
         | grep -vE 'Formats\.swift|Loc\.swift|LOC-EXEMPT' || true)
  [ -n "$hits" ] && report 'A raw formatter or a locale-blind case change (§11.12, §12.9 trap 5):' "$hits"
fi
```

`joined(separator:)` is on the glue list deliberately, and there is exactly one sanctioned exception
in the app: the VoiceOver **terse** glyph label, which joins an *enumeration* of changed attributes
with `.formatted(.list(type: .and, width: .narrow).locale(locale))` — Foundation's locale-aware list
style, not a comma (`hunch-accessibility/references/voiceover-elements.md` §9). That call does not
match this grep, which is why the grep names `joined(separator:)` and not `.formatted(.list`. If
anybody reaches for the comma version, the check fires; that is the intent.

`String(format:` is allowed inside `Loc.swift` because that is where `GLYPH_LABEL`'s four positional
arguments are substituted, and nowhere else.

Prove both by planting a `probes == 1 ? "probe" : "probes"` in `StatisticsView.swift` and a
`DateFormatter()` in `CodexPageView.swift`. Paste the output into the PR body.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/PluralTests -only-testing:HunchUITests/FormattingAndScriptTests` green.
- [ ] `jq -r '[.strings | to_entries[] | select(.value.localizations.ru.variations.plural != null) | .key] | length' Modules/Sources/HunchUI/Resources/Localizable.xcstrings` equals `LocKey.pluralBearing.count`, and the same query for `ar` returns the same number.
- [ ] `jq -r '.strings["PROBE_COUNT"].localizations.ar.variations.plural | keys | sort | join(" ")' …` prints `few many one other two zero`.
- [ ] `grep -rn '\.uppercased()' Modules/Sources` returns nothing.
- [ ] `grep -rn 'DateFormatter(\|NumberFormatter(\|String(format:' Modules/Sources | grep -v 'Formats.swift\|Loc.swift'` returns nothing.
- [ ] `grep -rnE '== 1[[:space:]]*\?' Modules/Sources` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` green, with both planted violations recorded in `.github/pr-body.md`.
- [ ] `DECISIONS.md` carries the §12.9 trap 5 versus `type-ramp.md` §4 reconciliation, naming both and stating which wins and why.
- [ ] `PROGRESS.md` records the Statistics screen read in Arabic and Japanese, with what changed.
- [ ] `tests.json` carries seven entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T07: plural variations, formatted values everywhere, and the four script profiles"`

## Out of scope

- **The seven type roles, their sizes, weights, widths and tracking values** — **E03·T02**. This
  task changes only how two of them resolve under a non-cased script.
- **The AX3–AX5 reflow table** — **E19·T06**. `minimumScaleFactor` stays 1.0 and rows grow; which
  screens reflow at which category is that task's.
- **The glyph label's wording and its terse mode** — **E19·T02**. This task ships the plural
  mechanism the `pips` interpolation needs and asserts the format string's positional arguments.
- **`LawNarrator`'s one-format-string-per-node rendering** — **E19·T03**, which will use `plural`
  and `Formats` as they are shipped here.
- **The Assay's and the par row's numerals**, which do not exist — the play surface renders no
  numerals at all (§1.12 rule 4).
- **Where a numeral may be rendered at all**, which is `hunch-chrome-and-meta`'s
  `references/numeral-readout.md` and was settled before this epic.
