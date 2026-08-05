# E18 — Localization

| | |
|---|---|
| **id** | E18 |
| **title** | Localization |
| **branch** | `epic/E18-localization` |
| **depends on** | E17 (which itself carries E01–E16) |
| **gate** | Completeness across all 12 languages with zero `new`/`needsReview` entries and zero duplicates at a key count ≤ 250 · the per-locale banned-lexeme test passes with exclamation marks included · `PlaySurfaceTextTests` fails on any `Text`/`Label`/`AttributedString` outside `.accessibility*` in the six play-surface files · setting the override to `ar` flips `layoutDirection` and resolves a sampled key **with no relaunch** · every screen reviewed under the expanded pseudolocale and screenshots reviewed in English, German and Arabic |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, every character the app can render exists in exactly one place — one
`Localizable.xcstrings` in `HunchUI/Resources` — in twelve languages, reached through exactly one
accessor that carries both a bundle and a resolved locale. Selecting Arabic in Settings mirrors the
chrome and switches every visible string in the same frame, with no relaunch, because the accessor
resolves against an `.lproj` URL rather than against `Bundle.main`'s launch-time localization and
because `layoutDirection` is set explicitly on the root rather than hoped for from `\.locale`. The
glyph never mirrors and the chrome always does. Plurals come from String Catalog variations, so
Russian gets its four categories and Arabic its six and no line of Swift ever asks `count == 1`.
Dates, numbers and measurements are formatted by `Date.FormatStyle`, `NumberFormatter` and
`Measurement` against that same resolved locale.

And three claims that were previously discipline become machinery: the play surface renders zero
characters in any locale (a source lint that fails the build); no translation in any of the twelve
languages contains a banned lexeme or an exclamation mark (a diacritic- and case-insensitive checker
that fails the build); and every screen has been seen under an accented, expanded, right-to-left
pseudolocale and in real German and real Arabic, with the defects fixed rather than filed.

## Why now

**Because you cannot count the strings until the last screen that owns one exists.** §12.9's
inventory is 94 visible keys and 134 accessibility keys, and they are spread across the Codex
(E15), the Anomaly, the Profile and Statistics (E16), and the Frame, Settings, About and the five
reset alerts (E17). Starting localization before E17 means translating a moving inventory twelve
times.

It sits *before* E19 for the opposite reason. E19 completes the VoiceOver element map, and every
label it writes is a new catalog key. Once this epic's completeness check is on the branch, a key
added in E19 with no translation is `"state": "new"` in eleven locales and **fails the build the day
it is added** — so E19 gets its localization gate for free instead of discovering 40 untranslated
labels at submission. Doing it the other way round is how §14.6's risk 8 lands.

Three concrete unblocks:

- **E19·T02 and E19·T03** (the glyph label and `LawNarrator`) need the plural machinery and the
  one-format-string-per-sentence rule to already exist as a shipped, tested accessor. T07 ships it.
- **E20·T11** re-reads every string against §1.13 and ships the same twelve languages of App Store
  metadata through the same banned-lexeme checker. T08 ships the checker.
- **E20·T12**'s archive gate is "zero warnings, every string re-read". A catalog with `new` entries
  is a warning in Xcode's build log; this epic is what makes that log clean.

## Scope

| In | Out — and who owns it |
|---|---|
| `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` as a real checked-in artifact, the `LocKey` key space, `Loc` as the single accessor, the ≤ 250 assertion | The `Modules` package manifest, `defaultLocalization: "en"` and the `HunchUI` target itself — **E03·T06**. This epic only adds the `resources:` declaration |
| The English copy for every **visible** string, and the translation of all 12 locales including the accessibility strings | *Which* accessibility strings exist and what each one says — **E19·T01–T05, T10**. This epic translates the element map; it does not author it |
| `PlaySurfaceTextTests` as a source lint, and the two `Text(` traps app-wide | `check-source-hygiene.sh` itself and checks 1–10 — **E01·T06**, **E03·T06**. This epic appends |
| The override accessor, the explicit root `layoutDirection`, the `AppleLanguages` write, the no-relaunch test | The 13-option language picker, `hunch.settings.languageTag` and everything else under `hunch.settings.` — **E17·T07** |
| RTL: which chrome mirrors, which drawings never do, the wedge's flip, the `left`/`right` lint | The drawings themselves — the index stroke **E04·T04**, pip accretion **E04·T02**, the wedge **E09·T02**, the ribbon **E08·T05**, the Assay **E09·T05**. This epic asserts their behaviour under mirroring and changes exactly one path |
| Plural variations, `Date.FormatStyle`/`NumberFormatter`/`Measurement` throughout, the four per-script typographic profiles, `uppercased(with: locale)` | The seven type roles, their sizes, weights and tracking — **E03·T02**; the AX3–AX5 reflow table — **E19·T06** |
| The per-locale banned-lexeme checker with diacritic folding, and the `Info.plist` absence assertions | `Scripts/banned-lexemes.txt`'s first transcription and check 8's jq skeleton — **E01·T06**; the App Store metadata pass through the same checker — **E20·T11** |
| The pseudolocalization gate over all 18 screens, and en/de/ar screenshots reviewed | The `Nightly.xctestplan` RTL and Double Length **configurations** — **E01·T07** (this epic is what makes them assert anything); `performAccessibilityAudit` — **E19·T11**; the wordless App Store screenshots — **E20·T11** |
| The five Profile vertex sentences translated | Their authoring, their vertex sigils and the rule that the axis identifiers never enter the catalog — **E16·T09**, **E19·T01** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [The String Catalog and `Loc`](T01-string-catalog-and-loc.md) | P0 | M | — | One `Localizable.xcstrings` in `HunchUI/Resources`, `LocKey` as the closed key space, `Loc` carrying `#bundle` and a locale, symbol generation left off, the ≤ 250 assertion and the enum ↔ catalog reconciliation check |
| T02 | [The English copy pass](T02-english-copy-pass.md) | P0 | M | T01 | Every visible string authored as a copywriter would — ≤ 22 characters, ≤ 8 words, no exclamation marks, budgeted at +40 % — and the five wordmarks shipped `Text(verbatim:)` |
| T03 | [The eleven other languages](T03-eleven-other-languages.md) | P0 | L | T02 | Machine draft then native review per open decision 6; the completeness test, the twelve-locale resolution test and the +40 % length-budget test |
| T04 | [Zero play-surface strings](T04-zero-play-surface-strings.md) | P0 | S | T01 | `PlaySurfaceTextTests` as a source lint, plus the two `Text(` traps app-wide: a `String`-typed argument and a bare literal outside the accessor |
| T05 | [The override accessor](T05-override-accessor.md) | P0 | M | T03 | `LocalizedStringResource(key, bundle: .atURL(…), locale: …)`, the explicit root `layoutDirection`, `AppleLanguages` for the next cold launch only, and the no-relaunch test |
| T06 | [RTL](T06-rtl.md) | P0 | M | T05 | Chrome mirrors and glyphs never do; `leading`/`trailing` only; ramps, the Assay and the ribbon in source order in every locale; the wedge mirrors with its rail |
| T07 | [Plurals, formats and script profiles](T07-plurals-formats-and-script-profiles.md) | P0 | M | T06 | Catalog plural variations for Russian's four and Arabic's six, no concatenation and no `count == 1`, `Date.FormatStyle`/`NumberFormatter`/`Measurement` throughout, the four per-script profiles and `uppercased(with: locale)` |
| T08 | [The banned-lexeme test](T08-banned-lexeme-test.md) | P0 | M | T03 | A per-locale token list plus exclamation marks, case- and diacritic-insensitive, failing the build, exceptions only by a written `DECISIONS.md` entry; plus the three `Info.plist` absence assertions |
| T09 | [The pseudolocalization gate and screenshots](T09-pseudolocalization-gate-and-screenshots.md) | P0 | M | T08 | Accented + expanded pseudo-language and `-AppleTextDirection YES` on every one of the 18 screens, and en/de/ar screenshots actually looked at with the defects fixed |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E18-localization

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E18-localization
gh pr create --title "E18 — Localization" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E19 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed to make a build pass (§14.1, VERIFICATION), and a banned lexeme clears only
by a written exception in `DECISIONS.md` — the default is deletion (§1.13).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | **The catalog is complete in all twelve languages**: ≤ 250 keys, zero `"state": "new"` or `"needsReview"` in any locale, zero keys missing a locale, zero two-key English duplicates | `bash Scripts/check-source-hygiene.sh` — check 8, now running against the real artifact for the first time |
| 3 | Every key resolves to a real value in every one of the twelve locales — nothing falls back to its own key | `xcodebuild test … -only-testing:HunchUITests/CatalogResolutionTests` |
| 4 | **The banned-lexeme test passes per locale, exclamation marks included**, matched case- **and** diacritic-insensitively | `swift Scripts/check-banned-lexemes.swift` (exit 0), and the planted-violation drill in T08 recorded in the PR body |
| 5 | `PlaySurfaceTextTests` fails the build on any `Text`/`Label`/`AttributedString` outside `.accessibility*` in the six play-surface files, and on either `Text(` trap anywhere in `Modules/Sources` | `bash Scripts/check-source-hygiene.sh` after planting each of the three violations in turn, output pasted into the PR body |
| 6 | **Setting the override to `ar` flips `layoutDirection` and resolves a sampled key, with no relaunch** | `xcodebuild test … -only-testing:HunchUITests/LanguageOverrideTests` — one process, no `exit`, no relaunch |
| 7 | Glyphs are bit-identical under both layout directions and the chrome is not | `xcodebuild test … -only-testing:HunchUITests/MirroringTests` |
| 8 | Russian resolves four distinct plural forms and Arabic six, and no `count == 1` ternary exists in `Modules/Sources` | `xcodebuild test … -only-testing:HunchUITests/PluralTests` and `bash Scripts/check-source-hygiene.sh` |
| 9 | `Info.plist` carries zero localizable strings, no `NS*UsageDescription`, and neither `UIFileSharingEnabled` nor `LSSupportsOpeningDocumentsInPlace` | `xcodebuild test … -only-testing:HunchTests/InfoPlistTests` |
| 10 | **Every one of the 18 screens has been reviewed under the accented + expanded pseudolocale and under `-AppleTextDirection YES`**, with zero truncation and zero horizontal overflow | `xcodebuild test -testPlan Nightly --only-test-configuration 'Double Length'` and `--only-test-configuration RTL`, both green over `PseudolocaleSweepTests` |
| 11 | **Screenshots in English, German and Arabic were taken and looked at**, and every visible defect was fixed on this branch rather than logged | The 54 attachments exported from `HunchAutomationTests/LocalizedScreenshotTests`, plus the review note in `PROGRESS.md` naming each defect and its fixing commit |

## Definition of done

- [ ] All nine task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator; `Nightly.xctestplan` green in all four configurations.
- [ ] `Scripts/check-source-hygiene.sh` green, with every check this epic appends present and each demonstrated to fail on a deliberately planted violation before being reverted.
- [ ] `Localizable.xcstrings` holds ≤ 250 keys in exactly the twelve locales `ar de en es fr it ja ko pt-BR ru tr zh-Hans`, with zero `new`/`needsReview` and zero duplicate English values.
- [ ] `Localization/review-ledger.md` records, per locale, who reviewed which set (all visible strings + the five Profile sentences in every locale; the accessibility set in de, tr, ru, ja, ar) and on what date.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: catalog completeness and key budget, twelve-locale resolution, the length budget, the play-surface lint and both `Text(` traps, the no-relaunch override, mirroring, plural categories, format-style usage, the script profiles, Turkish uppercasing, banned lexemes, the three `Info.plist` absences, and the pseudolocale sweep. The pre-existing `localisation completeness` entry seeded in E01·T08 moves from `pending` to `pass`.
- [ ] `DECISIONS.md` carries this epic's entries: the `loc[.key]` call-site spelling superseding the skills' `Loc.x`; the shared-key list and the resulting delta from §12.9's 94; the ruling on §12.9 trap 5 versus `type-ramp.md` §4 (uppercasing, not `smcp`); the "Level" row's written exception against §11.11's prose list; the closure of E01·T06's diacritic-folding gap; and any other lexeme exception, each with a reason.
- [ ] `PROGRESS.md` carries the pseudolocale sweep result and the en/de/ar screenshot review, defect by defect.
- [ ] The PR is merged with every check green, and `main` is pulled before E19 begins.
