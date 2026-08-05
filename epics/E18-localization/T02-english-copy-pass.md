# T02 — The English copy pass

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | LOCALIZATION → String Catalog; LOCALIZATION → Twelve languages (the source language) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-chrome-and-meta` | It owns the four screens that carry text — `SettingsView`, `StatisticsView`, `AboutView`, `ResetConfirmAlert` — and `references/stock-controls.md` is the only place that says which stock components exist and therefore which labels are section heads, row labels or option labels. It also owns `references/numeral-readout.md`, which decides which of these rows carry a numeral beside the label rather than a second string. |

`hunch-design-tokens` is *not* required here: this task authors words, not values. It becomes
required in T07, where `type.section` and `type.micro`'s uppercasing meets Turkish.

## Objective

At the end of this task every visible string in the app has been written once, deliberately, in the
register §1.12 fixes — nouns over verbs, ≤ 8 words, no second person outside Settings, no
exclamation marks — and every one of them is ≤ 22 characters in English so a +40 % German, Russian
or Turkish translation still fits its row. The four mode names and the product name ship as
untranslated wordmarks that never enter the catalog at all.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 (inventory table, visible block) | which strings exist: Settings 37, reset alerts 16, About 6, Statistics 24, Profile 5, screen titles 6 — and that the four mode names are **wordmarks, not translation units** |
| `GAME_DESIGN.md` | §1.12 | the seven voice rules: no address, **no exclamation marks anywhere in any of the 12 languages**, no praise, no commiseration, nouns over verbs, ≤ 8 words |
| `GAME_DESIGN.md` | §1.13 | the fourteen banned framings and their approved replacements — this is a compliance boundary, not a style preference |
| `GAME_DESIGN.md` | §11.11 | the approved framings, the banned-outright list, and P3: *Induction, Retention, Flexibility, Restraint, Tempo* never appear in the app in any form |
| `GAME_DESIGN.md` | §12.6 | the seven Settings sections and their nineteen rows, verbatim, with the option sets for each segmented control |
| `GAME_DESIGN.md` | §11.12 | what the statistics screen tracks and shows, and what it deliberately does not — no attendance metric, no percentile, no band-as-level |
| `GAME_DESIGN.md` | §11.13, §12.6 (reset map) | the five reset actions, and *why the five alert bodies differ* |
| `GAME_DESIGN.md` | §12.2 | `AboutView`'s contents; the eighteen screens and which six carry a title |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 (the four modes row) | `Text(verbatim: mode.wordmark)` is the only spelling right on both counts |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/EnglishCopyTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import HunchUI

/// The register rules of §1.12 and the +40 % budget of §12.9 are checkable, so they are checked.
/// What is *not* checkable — "written as a careful copywriter would" — is what the review in the
/// task body is for. These assertions stop the copy from drifting after the review.
@Suite("English copy — §1.12's register and §12.9's budget", .tags(.unit, .presubmission))
@MainActor
struct EnglishCopyTests {

    private static let loc = Loc.english

    /// §1.12 rule 2. Anywhere. In any of the 12 languages. T08 extends this to the other eleven
    /// by putting `!` on the banned-lexeme list; here it is asserted directly on the source
    /// language so the violation is caught the moment it is typed.
    @Test("No exclamation mark anywhere in English", arguments: LocKey.allCases)
    func noExclamationMarks(_ key: LocKey) {
        #expect(!Self.loc[key].contains("!"))
    }

    /// §12.9's budget: every visible string ≤ 22 characters in English, so a +40 % German or
    /// Turkish row still fits. Alert *bodies* are sentences by design (§12.9: "the bodies differ
    /// because the consequences do") and carry §1.12's ≤ 8 words rule instead.
    @Test("Every visible label is ≤ 22 characters", arguments: LocKey.visibleLabels)
    func visibleLabelsAreInsideTheCharacterBudget(_ key: LocKey) {
        let value = Self.loc[key]
        #expect(value.count <= 22, "\(key.rawValue) is \(value.count) characters: \"\(value)\"")
    }

    /// §1.12 rule 5, applied where the character budget cannot reach.
    @Test("Every alert body is ≤ 8 words", arguments: LocKey.alertBodies)
    func alertBodiesAreInsideTheWordBudget(_ key: LocKey) {
        let words = Self.loc[key].split(whereSeparator: \.isWhitespace)
        #expect(words.count <= 8, "\(key.rawValue) is \(words.count) words")
    }

    /// §11.11 P3. The five axis identifiers never enter the catalog in any form, visible or
    /// spoken — and that is what makes T08's banned-lexeme list survivable, because *Retention*
    /// and *Flexibility* land on "memory" and "ability" in several of the twelve languages.
    @Test("No axis identifier appears in any value", arguments: LocKey.allCases)
    func axisIdentifiersNeverAppear(_ key: LocKey) {
        let folded = Self.loc[key].lowercased()
        for identifier in ["induction", "retention", "flexibility", "restraint", "tempo"] {
            #expect(!folded.contains(identifier), "\(key.rawValue) names an axis: \(identifier)")
        }
    }

    /// §12.9: PROBE / DRIFT / ECHO / SIEVE and HUNCH are wordmarks. A wordmark in the catalog is
    /// a wordmark a translator will transliterate, and `CFBundleDisplayName` is "HUNCH" in all
    /// twelve locales including Arabic *because it is not a word*.
    @Test("No wordmark is a translation unit", arguments: LocKey.allCases)
    func wordmarksAreNotTranslationUnits(_ key: LocKey) {
        for wordmark in Mode.allCases.map(\.wordmark) + ["HUNCH"] {
            #expect(!Self.loc[key].contains(wordmark),
                    "\(key.rawValue) embeds the wordmark \(wordmark)")
        }
    }

    /// The two dedup rules check 8 enforces over the file, asserted here over the resolved values
    /// so a failure names the pair rather than a jq group.
    @Test("No two keys share an English value")
    func noTwoKeysShareAnEnglishValue() {
        var seen: [String: LocKey] = [:]
        for key in LocKey.allCases {
            let value = Self.loc[key]
            if let previous = seen[value] {
                Issue.record("\(key.rawValue) and \(previous.rawValue) both say \"\(value)\"")
            }
            seen[value] = key
        }
    }
}
```

`LocKey.visibleLabels` and `LocKey.alertBodies` are two `static let [LocKey]` slices added to
`LocKey.swift` in this task. They are the machine-readable form of §12.9's inventory rows and the
reason the character budget can be asserted at all.

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/EnglishCopyTests
```

It must fail on the missing `LocKey.visibleLabels` symbol first, and then — once that exists — on
real copy: whatever placeholder English T01 inherited from E08–E17's call sites will be over budget,
duplicated or both. That second failure is the task.

**Step 3 — implement**: author the copy below into the catalog.

**Step 4 — green, then refactor.** The refactor here is the *read-aloud pass*: read all of it in
order, on a device, at Dynamic Type Large and at AX3, and change what sounds like a person talking.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — every `en` value and every `comment` |
| modify | `Modules/Sources/HunchUI/LocKey.swift` — the shared-key consolidation, `visibleLabels`, `alertBodies` |
| modify | `Modules/Sources/MetaFeature/SettingsView.swift`, `StatisticsView.swift`, `AboutView.swift`, `ResetConfirmAlert.swift`, `ProfileView.swift` — call sites that changed key |
| create | `Modules/Tests/HunchUITests/EnglishCopyTests.swift` |
| modify | `DECISIONS.md` — the shared-key list, the resulting count delta from §12.9's 94, and the "Level" exception |
| modify | `tests.json` — four entries (no exclamation marks, character budget, word budget, no axis identifier) |

## Implementation notes

### The copy

Every value below is ≤ 22 characters unless it is an alert body, which is ≤ 8 words instead.
Section heads are stored **sentence case** and uppercased at render by
`String.uppercased(with: locale)` (§13.4) — storing `"DISPLAY"` would defeat Turkish and mangle
Arabic, which is T07's problem and is avoided here by not creating it.

**Shared labels** — one key, several sites. Each is a word with one meaning in one product; two
keys for one word is how two screens acquire two translations of it.

| Key | English | Sites |
|---|---|---|
| `LABEL_ABOUT` | About | Settings section head · Settings row · screen title |
| `LABEL_CODEX` | Codex | screen title · Statistics section head |
| `LABEL_ANOMALY` | Anomaly | screen title · Statistics section head |
| `LABEL_ROUNDS` | Rounds | Statistics section head · MODES column head · Profile stat |
| `LABEL_LONGEST_RUN` | Longest run | Statistics row · Profile stat |
| `OPTION_FOLLOW_SYSTEM` | System | Theme · Reduce motion · App language |

**Screen titles** (§12.2 screens 9, 12–16; `CodexShelfView` and `CodexPageView` have none)

| Key | English |
|---|---|
| `SCREEN_TITLE_STATISTICS` | Statistics |
| `SCREEN_TITLE_PROFILE` | Profile |
| `SCREEN_TITLE_SETTINGS` | Settings |

**Settings section heads** (§12.6; ABOUT reuses `LABEL_ABOUT`)

| Key | English |
|---|---|
| `SETTINGS_SECTION_DISPLAY` | Display |
| `SETTINGS_SECTION_FEEDBACK` | Feedback |
| `SETTINGS_SECTION_PLAY` | Play |
| `SETTINGS_SECTION_VOICEOVER` | VoiceOver |
| `SETTINGS_SECTION_LANGUAGE` | Language |
| `SETTINGS_SECTION_DATA` | Data |

**Settings rows** (§12.6, in table order; the ABOUT row reuses `LABEL_ABOUT`)

| Key | English | chars |
|---|---|---|
| `SETTINGS_ROW_THEME` | Theme | 5 |
| `SETTINGS_ROW_GRAIN` | Grain | 5 |
| `SETTINGS_ROW_REDUCE_MOTION` | Reduce motion | 13 |
| `SETTINGS_ROW_LEFT_HAND_KEYS` | Left-hand keys | 14 |
| `SETTINGS_ROW_HAPTICS` | Haptics | 7 |
| `SETTINGS_ROW_SOUND` | Sound | 5 |
| `SETTINGS_ROW_LEVEL` | Level | 5 |
| `SETTINGS_ROW_CONFIRM_SEAL` | Confirm the Seal | 16 |
| `SETTINGS_ROW_STEADY_STREAM` | Steady stream | 13 |
| `SETTINGS_ROW_VOICEOVER_DETAIL` | Detail | 6 |
| `SETTINGS_ROW_ANNOUNCE_VERDICTS` | Announce verdicts | 17 |
| `SETTINGS_ROW_ANNOUNCE_ASSAY` | Announce the Assay | 18 |
| `SETTINGS_ROW_APP_LANGUAGE` | App language | 12 |
| `SETTINGS_ROW_CLEAR_STATISTICS` | Clear statistics | 16 |
| `SETTINGS_ROW_CLEAR_CODEX` | Clear Codex | 11 |
| `SETTINGS_ROW_RESET_PROFILE` | Reset Profile | 13 |
| `SETTINGS_ROW_RESET_LADDER` | Reset the ladder | 16 |
| `SETTINGS_ROW_RESET_EVERYTHING` | Reset everything | 16 |

**Settings option labels** (§12.6's segmented controls; `System` reuses `OPTION_FOLLOW_SYSTEM`)

| Key | English |
|---|---|
| `OPTION_THEME_DARK` | Dark |
| `OPTION_THEME_LIGHT` | Light |
| `OPTION_THEME_HIGH_CONTRAST` | High Contrast |
| `OPTION_REDUCE_MOTION_ALWAYS` | Always |
| `OPTION_LEVEL_NORMAL` | Normal |
| `OPTION_LEVEL_LOW` | Low |
| `OPTION_DETAIL_FULL` | Full |
| `OPTION_DETAIL_TERSE` | Terse |

The thirteenth picker option is `OPTION_FOLLOW_SYSTEM`; the other twelve rows are **endonyms**
(`Deutsch`, `Français`, `Español`, `Português (Brasil)`, `Italiano`, `Türkçe`, `Русский`, `日本語`,
`한국어`, `简体中文`, `العربية`, `English`) and §12.9 excludes them from the catalog explicitly —
they are constants, not translation units, and they are the same string in every locale by
definition. Ship them as a `static let` array of `String` beside the picker and render each
`Text(verbatim:)`.

**Reset alerts** (§12.6 DATA × §11.13's reset map). Five titles, five bodies, one shared cancel. The
destructive verb of each alert **reuses that row's own label key** — the button says what the row
said, which is both correct UI and five fewer keys.

| Key | English | words |
|---|---|---|
| `ALERT_CLEAR_STATISTICS_TITLE` | Clear statistics? | — |
| `ALERT_CLEAR_STATISTICS_BODY` | The counters return to zero. Nothing else changes. | 8 |
| `ALERT_CLEAR_CODEX_TITLE` | Clear Codex? | — |
| `ALERT_CLEAR_CODEX_BODY` | Every page is deleted. Locked modes re-lock. | 7 |
| `ALERT_RESET_PROFILE_TITLE` | Reset Profile? | — |
| `ALERT_RESET_PROFILE_BODY` | The portrait re-forms unformed. Pages are kept. | 7 |
| `ALERT_RESET_LADDER_TITLE` | Reset the ladder? | — |
| `ALERT_RESET_LADDER_BODY` | Calibration runs again. The Codex is kept. | 7 |
| `ALERT_RESET_EVERYTHING_TITLE` | Reset everything? | — |
| `ALERT_RESET_EVERYTHING_BODY` | Everything is deleted except the daily ledger. | 7 |
| `ALERT_CANCEL` | Cancel | — |

Two things the bodies must keep. They say what is **kept**, not only what is lost — §12.6's whole
reason for five different bodies is that Clear Codex keeps the palette while Reset the ladder drops
it, and a player who cannot read that difference off the alert will hit the wrong one. And none of
them addresses the player: *"the portrait re-forms"*, never *"your portrait"* (§1.12 rule 1).

**About rows** (§12.2 screen 16)

| Key | English |
|---|---|
| `ABOUT_VERSION` | Version |
| `ABOUT_BUILD` | Build |
| `ABOUT_NO_DATA` | No data is collected. |
| `ABOUT_COPYRIGHT` | Copyright |
| `ABOUT_STORAGE` | Storage |
| `ABOUT_LICENCES` | Licences |

The values beside `Version`, `Build` and `Copyright` are formatted, not translated: a version string,
a build number and a year formatted through `Date.FormatStyle` (T07). `ABOUT_NO_DATA` is the only
sentence on the screen and it is §1.13's approved framing — *"Nothing is sent anywhere"* is the same
claim and either is acceptable, but pick one and keep it, because `PrivacyInfo.xcprivacy` and the
App Store description (E20·T11) must not disagree with it.

**Statistics** (§11.12). Section heads: `LABEL_MODES`, `LABEL_ROUNDS`, `LABEL_BANDS`, plus the
shared `LABEL_CODEX` and `LABEL_ANOMALY`. The BANDS section's rows are identified by their **family
sigil**, never by a number (§10.5) — there is no `Band` label and there must not be one.

| Key | English | Section |
|---|---|---|
| `LABEL_MODES` | Modes | head |
| `LABEL_BANDS` | Bands | head |
| `STATS_SOLVED` | Solved | ROUNDS |
| `STATS_LOST_ON_A_STRIKE` | Lost on a strike | ROUNDS |
| `STATS_LOST_AT_THE_CAP` | Lost at the cap | ROUNDS |
| `STATS_PROBES` | Probes | ROUNDS |
| `STATS_TWINS` | Twins | ROUNDS |
| `STATS_DUPLICATE_PAIRS` | Duplicate pairs | ROUNDS |
| `STATS_STRIKES` | Strikes | ROUNDS |
| `STATS_FRACTURES` | Fractures | ROUNDS |
| `STATS_SERVED` | Served | BANDS column |
| `STATS_SOLVE_RATE` | Solve rate | BANDS column |
| `STATS_BEST_AGAINST_PAR` | Best against par | BANDS column |
| `STATS_PAGES_HELD` | Pages held | CODEX |
| `STATS_SHELF_FILL` | Shelf fill | CODEX |
| `STATS_SEALED` | Sealed | CODEX |
| `STATS_TALLY` | Tally | ANOMALY |
| `STATS_CURRENT_STREAK` | Current streak | ANOMALY |
| `STATS_LONGEST_STREAK` | Longest streak | ANOMALY |
| `STATS_LAST_28_DAYS` | Last 28 days | ANOMALY |
| `STATS_CURRENT_RUN` | Current run | ROUNDS |

The MODES section's four rows are the four **wordmarks** and carry `LABEL_ROUNDS` as their column
head. §11.12 forbids a session-duration, time-of-day, days-opened or launch-count row; if a label
for one appears here, the row was added by mistake and the label is not the fix.

**Profile stat block** (§11.11; five rows, three of which are shared)

| Key | English |
|---|---|
| `PROFILE_ANOMALY_STREAK` | Anomaly streak |
| `PROFILE_PROBES_AGAINST_PAR` | Probes against par |

with `LABEL_ROUNDS`, `STATS_PAGES_HELD` and `LABEL_LONGEST_RUN` supplying the other three. There is
**no "highest band" row** — §10.5 forbids surfacing a band number and the Codex shelves already
carry that fact retrospectively.

### The count, and the delta from §12.9

§12.9 counts **sites** — 37 + 16 + 6 + 24 + 5 + 6 = 94 places a string is rendered. The tables above
are **81 distinct keys** covering those same 94 sites, because eleven keys are used at more than one
site. The list is the `DECISIONS.md` entry this task must write, and it is the whole of the
difference:

| Key | Sites it serves |
|---|---|
| `LABEL_ABOUT` | Settings section head · Settings row · screen title |
| `LABEL_CODEX` | screen title · Statistics section head |
| `LABEL_ANOMALY` | screen title · Statistics section head |
| `LABEL_ROUNDS` | Statistics section head · MODES column head · Profile stat |
| `LABEL_LONGEST_RUN` | Statistics row · Profile stat |
| `STATS_PAGES_HELD` | Statistics CODEX row · Profile stat |
| `OPTION_FOLLOW_SYSTEM` | Theme · Reduce motion · App language |
| the five DATA row labels | each also serves its alert's destructive verb |

Count what you actually author rather than trusting the arithmetic above: after the catalog is
written, `jq '.strings | length'` and `LocKey.allCases.count` must agree with each other, and the
figure in `DECISIONS.md` must be that number. If it lands at 79 or 83 rather than 81, the entry says
so and names the extra or missing key — an estimate corrected against the artifact is the point of
writing it down.

81 visible + §12.9's 134 accessibility ≈ **215 keys**, comfortably inside the hard budget of 250 and
leaving the headroom E19 will spend completing the element map. **The binding constraint is the
budget, not the estimate** — do not add keys back to reach 94.

Several of the shares are load-bearing for check 8 rather than merely economical: two keys with
identical English is a check-8 failure (*"the translations will diverge"*), so `About`/`About`/`About`
and three `System`s could not have shipped as six keys in any case. If T03's native review finds a
locale where one of the shared keys genuinely needs two different words, the fix is a **written
`DECISIONS.md` exception plus a named allowlist line in check 8's duplicate filter** — never a quiet
second key with the same English.

### The wordmarks

PROBE, DRIFT, ECHO, SIEVE and HUNCH are untranslated in all twelve locales.

```swift
// ✗ never extracted; English forever, and it is a Latin wordmark rendered by a translator's route
Text(mode.rawValue)
// ✗ extracted — so a translator sees it, and in Russian or Japanese somebody will transliterate it
Text("PROBE")
// ✓ the only spelling right on both counts (08 §3)
Text(verbatim: mode.wordmark)
```

`Mode.wordmark` is E02·T06's and returns a `String`; `HUNCH` is `CFBundleDisplayName`, which §12.9
fixes as "HUNCH" in all twelve locales including Arabic — *it is a wordmark, not a word*. T08 asserts
that no `InfoPlist.strings` or `InfoPlist.xcstrings` exists anywhere to localize it.

`wordmarksAreNotTranslationUnits` is what stops a well-meant `ALERT_CLEAR_CODEX_BODY` of *"DRIFT,
ECHO and SIEVE re-lock"* — which is why that body says *"Locked modes re-lock"* instead.

### The one written exception this copy needs

§12.6 names the FEEDBACK row **"Level"**, and §11.11's prose bans *"level"* outright. The two are
not in conflict — §11.11's list guards the Profile and the store listing against grade language, and
this row names an **audio level** — but the word is on a list, so it clears the way §1.13 says a
token clears: by a written entry in `DECISIONS.md` naming the key, the reading and the reason. Note
also that `Scripts/banned-lexemes.txt` transcribes §1.13's per-locale list, which does **not**
contain *level*; §11.11's wider list is applied by the human copy review, and this task is that
review.

### The review pass, which is not a test

Read all 81 in order, on a device, with the screens in front of you. Three questions per string, and
each has fired on a real product:

1. **Does it name a mechanic where a drawing works?** (§1.12 rule 6.) There is no glossary, no
   "what is a contextual law", no empty-state copy — §12.2 lists empty-state copy among the things
   deliberately absent.
2. **Would it read as praise, commiseration or a grade?** (§1.12 rule 3, §11.11.) *"Solve rate"* is
   a count of outcomes; *"Success rate"* is a verdict on the player. Prefer the count.
3. **Is it a noun?** (§1.12 rule 5.) Instrument labelling: `probes`, `laws found`, `sound`,
   `language`. Where a verb is unavoidable it is on a button, and a button is an action.

Record the read-aloud pass in `PROGRESS.md` with the date and the strings you changed.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/EnglishCopyTests` green — all five suites over every `LocKey` case.
- [ ] `jq -r '.strings | to_entries[] | select(.value.localizations.en.stringUnit.value | test("!")) | .key' Modules/Sources/HunchUI/Resources/Localizable.xcstrings` returns nothing.
- [ ] `jq -r '[.strings | to_entries[] | select(.value.localizations.en.stringUnit.value | length > 22) | .key]' …` returns only alert-body keys, and each of those is ≤ 8 words.
- [ ] Every entry in the catalog carries a non-empty `comment` naming its screen and its §-reference.
- [ ] `grep -rn 'Text("' Modules/Sources/MetaFeature` returns nothing — every string on the four text-bearing screens is `Text(verbatim: loc[.key])`.
- [ ] `grep -rn 'Text(verbatim:' Modules/Sources | grep -E 'wordmark|"HUNCH"' | wc -l` is non-zero and every hit is a wordmark site.
- [ ] `bash Scripts/check-source-hygiene.sh` green — in particular check 8's duplicate-English filter, which the shared-key consolidation exists to satisfy.
- [ ] `jq '.strings | length' Modules/Sources/HunchUI/Resources/Localizable.xcstrings` equals `LocKey.allCases.count`, and both are ≤ 250; the visible slice is `LocKey.visibleLabels.count + LocKey.alertBodies.count`.
- [ ] `DECISIONS.md` carries the shared-key table, the measured visible-key count against §12.9's 94 sites with the reason for the difference, and the "Level" exception.
- [ ] `PROGRESS.md` carries the read-aloud pass with its date.
- [ ] `tests.json` carries the four entries, each with a runnable `command`.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T02: the English copy for all 81 visible strings, and the wordmark rule"`

## Out of scope

- **The 134 accessibility strings' wording** — **E19·T01–T05, T10** author them; this task neither
  writes nor rewrites them. It only asserts that none contains an exclamation mark, an axis
  identifier or a wordmark, which is true of them today and must stay true.
- **The eleven translations** — **T03**.
- **The per-locale banned-lexeme checker** — **T08**. This task's `en` review is the human half;
  T08 is the machine half and it runs over all twelve.
- **Uppercasing the section heads** — **T07**. They are stored sentence case here precisely so T07
  has one place to apply `uppercased(with: locale)`.
- **Plural forms of anything counted** — **T07**.
- **The App Store name, subtitle, description, keywords and what's-new** — **E20·T11**, and they
  are outside the catalog (§12.9).
