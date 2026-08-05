# T03 — The eleven other languages

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | LOCALIZATION → Twelve languages; VERIFICATION → Localization tests (the completeness half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | Check 8 is the completeness gate and this task is what makes it assert: `references/source-hygiene.md` §2 is its exact jq for the locale set, the `new`/`needsReview` scan, the missing-locale scan and the duplicate scan. The skill also owns the rule that this stays a `Scripts/` lint rather than becoming a package test, because a `.xcstrings` is not in a test bundle (`08 §5`). |
| `hunch-swift-testing` | The runtime half — twelve-locale resolution and the +40 % length budget — is a Swift Testing suite in `Modules/Tests/HunchUITests`, and the skill owns the two-axis tag vocabulary (`06 T30`), the `tests.json` obligation, and the rule that an entry is never weakened to reach green. It also owns the `arguments:` shape that turns 12 × 215 into readable per-locale failures rather than one opaque assertion. |

## Objective

At the end of this task `Localizable.xcstrings` holds a reviewed translation of every key in all
twelve of the brief's languages, with zero `new` or `needsReview` entries and zero keys missing a
locale, and three shipped tests make that mechanical: check 8 over the file, a twelve-locale
resolution suite over the key space, and a length-budget suite that fails when a German, Russian or
Turkish label overruns the +40 % it was designed for.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 | the twelve locales, ≈ 228 × 12 ≈ 2,740 translated units, and the +40 % budget for German, Russian and Turkish |
| `GAME_DESIGN.md` | §14.5 open decision 6 | the process, and its default: **English written as a copywriter, the rest machine-drafted, then native review of all visible strings and the five Profile sentences; the accessibility strings natively reviewed in de, tr, ru, ja, ar at minimum** |
| `GAME_DESIGN.md` | §14.6 risk 8 | the early signals — a native reviewer flagging more than 10 % of the visible strings; German or Russian rows wrapping to three lines at AX3 |
| `GAME_DESIGN.md` | §11.11 | the five approved Profile vertex sentences, which are translated here and which are the only place any axis is described in words |
| `GAME_DESIGN.md` | §1.12, §1.13 | the register and the claims policy, which bind **every localisation**, not only English |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 (brief invariant 5) | localisation completeness is a CI script, and it is one of the brief's seven critical tests |

The twelve locale identifiers are `ar de en es fr it ja ko pt-BR ru tr zh-Hans` — check 8's `want`
string, sorted, and the one place they are written down.

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`Modules/Tests/HunchUITests/TwelveLanguageTests.swift`:

```swift
import Foundation
import Testing
import HunchUI

@Suite("Twelve languages", .tags(.unit, .presubmission))
@MainActor
struct TwelveLanguageTests {

    /// The brief's twelve, and the one place in Swift they are written down. Check 8 holds the
    /// same list in shell; the reconciliation between the two is the `localeSetMatches` test.
    static let locales = ["ar", "de", "en", "es", "fr", "it", "ja", "ko", "pt-BR", "ru", "tr", "zh-Hans"]

    static let cases: [(String, LocKey)] = locales.flatMap { locale in
        LocKey.allCases.map { (locale, $0) }
    }

    /// The load-bearing assertion. A missing translation resolves to the *English* value under
    /// Foundation's fallback, or to the key itself if the entry is absent entirely — and both ship
    /// silently. Twelve locales × the key space is ~2,600 expectations and runs in well under a
    /// second, because resolution is a dictionary lookup.
    @Test("Every key resolves in every locale", arguments: cases)
    func everyKeyResolvesInEveryLocale(_ locale: String, _ key: LocKey) throws {
        let loc = try #require(Loc.forTesting(languageTag: locale))
        let value = loc[key]
        #expect(!value.isEmpty)
        #expect(value != key.rawValue, "\(key.rawValue) has no entry in \(locale)")
    }

    /// Fallback detection. A key that resolves to *exactly* the English string in ten of the
    /// eleven other locales is not a translation, it is Foundation quietly falling back — which is
    /// what an entry marked "translated" with the English value copied into it looks like from
    /// inside the app. Proper nouns legitimately match, so the allowlist is explicit and small.
    @Test("No key falls back to English in a non-English locale", arguments: LocKey.allCases)
    func noSilentFallbackToEnglish(_ key: LocKey) throws {
        guard !LocKey.sameInEveryLanguage.contains(key) else { return }
        let english = Loc.english[key]
        let identical = try Self.locales
            .filter { $0 != "en" }
            .filter { try #require(Loc.forTesting(languageTag: $0))[key] == english }
        #expect(identical.count < 8,
                "\(key.rawValue) is identical to English in \(identical.joined(separator: ", "))")
    }

    /// §12.9's budget, from the other end. English is ≤ 22 characters (T02); a translation is
    /// budgeted at +40 %, so 31. German, Russian and Turkish are the three §12.9 names, and they
    /// are the three that fail — asserting only those three keeps the failure list actionable.
    @Test("Visible labels stay inside the +40 % budget",
          arguments: ["de", "ru", "tr"], LocKey.visibleLabels)
    func translationsStayInsideTheLengthBudget(_ locale: String, _ key: LocKey) throws {
        let loc = try #require(Loc.forTesting(languageTag: locale))
        let value = loc[key]
        let budget = Int((Double(Loc.english[key].count) * 1.4).rounded(.up))
        #expect(value.count <= max(budget, 12),
                "\(locale)/\(key.rawValue) is \(value.count) against a budget of \(budget): \"\(value)\"")
    }

    /// §11.11's five sentences, which are the only place the Profile is described in words, and
    /// which §14.5 decision 6 singles out for native review in *every* locale.
    @Test("The five Profile sentences exist in every locale", arguments: locales)
    func profileSentencesExistEverywhere(_ locale: String) throws {
        let loc = try #require(Loc.forTesting(languageTag: locale))
        for key in LocKey.profileVertexSentences {
            let value = loc[key]
            #expect(value.count > 20, "\(locale)/\(key.rawValue) is too short to be a sentence")
            #expect(value != key.rawValue)
        }
        #expect(LocKey.profileVertexSentences.count == 5)
    }

    /// The Swift list and the shell list must not drift. `localeSet.txt` is written by check 8's
    /// `want` string; if this fails, one of the two lists was edited alone.
    @Test("The Swift locale list matches check 8's")
    func localeSetMatches() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().appending(path: "Fixtures/locale-set.txt")
        let fromScript = try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isWhitespace).map(String.init)
        #expect(fromScript == Self.locales)
    }
}
```

`Loc.forTesting(languageTag:)` is a `#if DEBUG` factory added in this task that resolves the
`<tag>.lproj` inside `#bundle` — the same resolution T05 will ship for the real override, built
here first because the completeness test needs it and cannot wait for T05. `LocKey.sameInEveryLanguage`
and `LocKey.profileVertexSentences` are two more `static let [LocKey]` slices on the key space.

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/TwelveLanguageTests
```

It must fail with ~2,400 `has no entry in <locale>` failures — one per key per non-English locale —
and not with a missing symbol. If it fails with a missing symbol, `Loc.forTesting` or one of the
three `LocKey` slices is not written yet.

**Step 2b — watch check 8 fail on the file.** `bash Scripts/check-source-hygiene.sh` must report
*"Locale set is not the brief's twelve"* and *"Keys missing a locale"*, listing every key. That
report is the work list for step 3.

**Step 3 — implement**: draft, review, land. The process is below.

**Step 4 — green, then refactor.** The refactor is the second review round: the reviewer's returned
changes go in as a single commit per locale so a later `git log -- Localizable.xcstrings` shows who
changed what.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — eleven localizations per key |
| modify | `Modules/Sources/HunchUI/LocKey.swift` — `sameInEveryLanguage`, `profileVertexSentences` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — `forTesting(languageTag:)` and the `.lproj` resolution it needs |
| create | `Modules/Tests/HunchUITests/TwelveLanguageTests.swift` |
| create | `Modules/Tests/HunchUITests/Fixtures/locale-set.txt` |
| create | `Localization/review-ledger.md` |
| create | `Scripts/export-for-review.sh` |
| modify | `tests.json` — the brief's invariant 5 moves from `pending` to `pass`, plus four new entries |
| modify | `PROGRESS.md` — the review round, locale by locale |

## Implementation notes

### The process, exactly as open decision 6 fixes it

| Stage | Scope | Who | Gate |
|---|---|---|---|
| 1. Machine draft | all keys × 11 locales | a translation engine, with the `comment` field as context | every entry lands as `"state": "needsReview"` — never `"translated"` |
| 2. Native review, tier A | the 81 visible strings + the 5 Profile sentences, **all 11 locales** | a native speaker per locale | reviewer flips `needsReview` → `translated` per entry |
| 3. Native review, tier B | the 134 accessibility strings, **de, tr, ru, ja, ar** | a native speaker per locale | same |
| 4. Machine-only, accepted | the accessibility strings in fr, es, pt-BR, it, ko, zh-Hans | — | flipped to `translated` with a `DECISIONS.md` entry naming the accepted risk |

Stage 1 must write `needsReview`, and check 8 must be **red** between stages 1 and 4. That redness
is the mechanism: it is impossible to ship a machine draft by forgetting to review it, because the
build will not go green until every entry has been touched deliberately.

Give the reviewers something reviewable rather than raw JSON:

```bash
# Scripts/export-for-review.sh <locale> — one TSV per locale: key, comment, English, draft.
jq -r --arg l "$1" '
  .strings | to_entries[]
  | [ .key,
      (.value.comment // ""),
      (.value.localizations.en.stringUnit.value // ""),
      (.value.localizations[$l].stringUnit.value // "") ]
  | @tsv' Modules/Sources/HunchUI/Resources/Localizable.xcstrings
```

The `comment` column is why T02 required one on every entry. A reviewer handed `SETTINGS_ROW_LEVEL`
→ `Level` with no context translates it as a difficulty level in at least three of the eleven.

### The brief the reviewers get

Send it with every export. It is four paragraphs and it is what §14.6 risk 8 is mitigated by:

1. **Register.** Instrument labelling, not prose. Nouns over verbs. ≤ 8 words. The machine never
   addresses the player and has no personality (§1.12).
2. **No exclamation marks, in any language.** This is a build-failing rule, not a preference.
3. **The claims boundary.** Never a word from the local category term for "brain game" — §1.13
   lists the tokens per language and the build fails on any of them. If the natural translation of
   a string reaches for one of those words, the string is wrong and should come back flagged rather
   than translated.
4. **Length.** Each visible label has a character budget of 1.4 × its English length. A translation
   that overruns comes back with a shorter alternative, because the row grows vertically rather
   than truncating (§12.8) and a three-line Settings row is the defect §14.6 names.

### The five Profile sentences

§11.11's five approved behavioural strings are the highest-risk translation in the product and get
native review in **all eleven** locales, not the tier-B five. Two reasons, both in §11.11: they are
the only place any axis is described in words, and *Retention* and *Flexibility* land on "memory"
and "ability" in several of the twelve languages — which are two of the words T08 fails the build
on. A translator working from the English sentence *"How often you re-ask a question the ribbon
already answered"* who compresses it to a noun phrase will produce the banned word.

Tell the reviewers that these five are **descriptions of what the player did, never of what the
player is**, and that a translation which reads as an assessment is wrong even if it is accurate.

### `Loc.forTesting(languageTag:)` and the `.lproj` resolution

```swift
extension Loc {
    /// Resolve against one specific `.lproj` inside HunchUI's own resource bundle. This is the
    /// same mechanism T05 ships for the user-facing override; it exists here first because the
    /// completeness test needs it and because building it under test is how the `pt-BR` and
    /// `zh-Hans` directory-name mapping gets found before a player finds it.
    public static func forTesting(languageTag: String) -> Loc? {
        guard let path = #bundle.path(forResource: languageTag, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        return Loc(locale: Locale(identifier: languageTag), bundleURL: bundle.bundleURL)
    }
}
```

The one thing to verify by hand rather than assume: **what Xcode names the `.lproj` directories.**
`pt-BR` and `zh-Hans` are the two that vary between BCP-47 tag and on-disk name across toolchains.

```bash
xcodebuild build -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -showBuildSettings -json >/dev/null
find ~/Library/Developer/Xcode/DerivedData -name '*.lproj' -path '*HunchUI*' -print | sed 's|.*/||' | sort -u
```

If the directory names differ from the tags, the mapping lives in **one** function on `Loc` and
nowhere else, and it gets its own test case here rather than a comment in T05.

### `Localization/review-ledger.md`

Native review is not machine-checkable, so it is recorded instead. One table, one row per locale:

| Locale | Visible + Profile sentences | Accessibility | Reviewer | Date | Flagged | Notes |
|---|---|---|---|---|---|---|
| de | reviewed | reviewed | | | 4 of 81 | |
| … | | machine only (decision 6) | | | | |

The **Flagged** column is §14.6's early signal made visible: *"a native reviewer flagging more than
10 % of the 94 visible strings"* is 9 strings. If any locale crosses 9, the English is the suspect,
not the translation — take it back to T02 and rewrite the source string rather than patching eleven
translations of a bad one.

### Two failures this suite is written to catch that check 8 cannot

- **The English-copied translation.** An entry marked `translated` whose value is the English
  string passes every jq filter in check 8 — it has a locale, it has a state, it is not a
  duplicate. `noSilentFallbackToEnglish` is the only thing that finds it. The threshold of "fewer
  than 8 of the 11" is deliberately loose so genuine proper nouns (`Codex`, `Anomaly`) pass, and
  `LocKey.sameInEveryLanguage` names the handful that legitimately do not translate at all.
- **The over-long German row.** Check 8 counts keys, not characters. `translationsStayInsideTheLengthBudget`
  is what turns §12.9's *"budgeted at +40 %"* from a sentence into a gate, and it is what stops
  T09's pseudolocale sweep from being the first time anybody discovers a three-line Settings row.

The `max(budget, 12)` floor exists because a 4-character English word (`Dark`, `Full`, `Low`) has a
budget of 6, and no language translates `Low` in six characters. Twelve is the smallest floor that
admits every reasonable translation of the eight one-word option labels; if a locale needs more,
the option label is too terse in English.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/TwelveLanguageTests` green — every key resolves in all twelve, no silent English fallback, every de/ru/tr label inside +40 %, five Profile sentences everywhere, and the two locale lists agree.
- [ ] `bash Scripts/check-source-hygiene.sh` green — check 8's four filters (budget, locale set, `new`/`needsReview`, missing locale, duplicate English) all clean against the real file.
- [ ] `jq -r '[.strings[].localizations | keys] | flatten | unique | join(" ")' Modules/Sources/HunchUI/Resources/Localizable.xcstrings` prints exactly `ar de en es fr it ja ko pt-BR ru tr zh-Hans`.
- [ ] `jq -r '[.. | objects | select(has("state")) | .state] | unique' …/Localizable.xcstrings` prints exactly `["translated"]`.
- [ ] `Localization/review-ledger.md` has a filled row for every one of the eleven locales, with a reviewer, a date and a flagged count, and no locale's flagged count exceeds 9 without a `PROGRESS.md` note saying what was rewritten in English instead.
- [ ] `DECISIONS.md` records the machine-only acceptance for the accessibility strings in fr, es, pt-BR, it, ko and zh-Hans, naming it as open decision 6's default rather than an oversight.
- [ ] `tests.json`'s `localisation completeness` entry (seeded `pending` in E01·T08) is `pass`, with a `command` that runs from the repo root.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T03: eleven languages, the completeness suite and the review ledger"`

## Out of scope

- **The banned-lexeme scan over the eleven new locales** — **T08**. It is the *reason* this task's
  reviewer brief says what it says, but the checker is T08's and it runs after every translation is
  in place, not during.
- **The user-facing override** — **T05**. `Loc.forTesting(languageTag:)` is a test seam and stays
  one; T05 ships the resolution path the app uses.
- **Plural variations.** A machine draft of a plural-bearing key produces one `stringUnit` and not
  a `variations.plural` block; **T07** authors those in all twelve, and the reviewers are asked for
  the plural forms in the same round so nobody is contacted twice.
- **Per-script typography** — **T07**. A Japanese translation that is correct still needs its
  tracking zeroed and its uppercasing switched off.
- **The pseudolocale sweep and the de/ar screenshots** — **T09**. The length budget asserted here
  is arithmetic; T09 is what a human looks at.
- **App Store metadata in twelve languages** — **E20·T11**.
