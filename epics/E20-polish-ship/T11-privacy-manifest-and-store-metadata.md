# T11 — Privacy manifest and store metadata

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T10 |
| **Delivers** | `PrivacyInfo.xcprivacy` · App Store metadata × 12 · §13.12 gate 13 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-release` | `references/rejection-triggers.md` is this task's specification and it is ordered by what bites *this* app: §1 states the gap this task closes — **the five App Store fields × twelve locales are sixty units that live outside `Localizable.xcstrings`, so hygiene check 8 has never seen them**; §2 is the privacy manifest with the warning that the required-reason code strings could not be verified and must be read off Apple's rendered page; §3 is the App Privacy questionnaire, which is a *different* artefact from the manifest and nothing checks the two against each other; §4, §5 and §6 are the encryption key, the tracking key that must be **absent**, and the usage descriptions; §8 is the wordless-screenshot ruling; §12 is the App Review notes a wordless game needs and is not written in any guide. |
| `hunch-build-and-ci` | It owns check 8, `Scripts/banned-lexemes.txt` and the gate roster, and its "to add a gate" list is what this task follows to point E18·T08's checker at a second corpus. It also owns the rule that `ITSAppUsesNonExemptEncryption` lives in `Config/Base.xcconfig` as an `INFOPLIST_KEY_*` and nowhere else — this task asserts it survived rather than re-adding it — and the rule that a new check is proved by planting a violation before it is committed. |

`hunch-accessibility` is not loaded. Gate 13 is a claims gate, not an accessibility one; it appears in
§13.12 because that list is *"a gate before any release build"*, and its owner is §1.13.

## Objective

At the end of this task the two artefacts App Review reads before it reads any code are correct and
provable. `App/PrivacyInfo.xcprivacy` declares — truthfully, and provably, because there is no network
symbol anywhere in the repository — that nothing is collected and nothing is tracked, and declares the
one required-reason API this app uses. Sixty units of App Store metadata exist in twelve languages,
written against §1.13's **approved** framings rather than merely avoiding its banned ones, with the
screenshots wordless by construction and the App Review notes explaining a game that says nothing. And
the banned-lexeme checker that has guarded 2,740 translated units since E18·T08 now guards these sixty
too, proved by planting a violation in four locales and proved not to fire on the legal spelling.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §1.13 | the compliance boundary, the fourteen banned/approved rows **with their reasons**, the per-locale token list, exclamation marks on the same list, and the enforcement clause: *"a test over `Localizable.xcstrings` (all 12 languages) **plus the App Store metadata files** fails the build on any match"* — the second half of that sentence is this task |
| `GAME_DESIGN.md` | §1.12 | the register the copy is written in: no second person, no exclamation marks, no praise, nouns over verbs, ≤ 8 words, never name a mechanic in text where a drawing works |
| `GAME_DESIGN.md` | §12.9 | the metadata row — *"App Store Connect: name, subtitle, description, keywords, what's-new … 5 × 12 = 60 units"*, **screenshots: 0 words, wordless by decision**, `Info.plist` zero localizable strings, `CFBundleDisplayName` is "HUNCH" in all twelve including Arabic |
| `GAME_DESIGN.md` | §13.12 gate 13 | *"Nothing in the UI, App Store copy or onboarding claims or implies a cognitive, memory, focus, intelligence or health benefit. Re-read every string before submission."* |
| `GAME_DESIGN.md` | §1.4, §14.5 decision 1 | paid once, no IAP, no ads, no free tier — the listing must describe the model the binary ships |
| `GAME_DESIGN.md` | §14.4 | no network, no analytics, no crash SDK, no notifications — what makes "Data Not Collected" verifiable rather than asserted |
| `GAME_DESIGN.md` | §14.6 risk 8 | the risk this task retires: the banned-lexeme exposure is highest in the eleven translations |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B36`, `B37`, `B38` | the privacy manifest and `UserDefaults` as a required-reason API; the encryption key; the tracking key and its ATT pair |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P32` | where the manifest goes — one, at the app bundle root, unless a local package becomes a dynamic framework |
| `.claude/skills/hunch-release/references/rejection-triggers.md` | §1–§12 | the whole of it |

**What already exists.** E01·T02 set `ITSAppUsesNonExemptEncryption = NO` in `Config/Base.xcconfig`.
E18·T08 shipped `Scripts/check-banned-lexemes.swift` with diacritic-insensitive matching, the completed
`Scripts/banned-lexemes.txt`, the `banned-lexemes.allow` mechanism, **and its directory mode, taken
early precisely so this task wires files in rather than rewriting the checker** — plus
`HunchTests/InfoPlistTests.swift`, which already asserts zero `NS*UsageDescription` keys, no Files
presence and the encryption key's value. This task adds a positive declaration and a second corpus; it
duplicates none of those assertions.

## TDD — the test comes first

Two artefacts, two shapes. The manifest is a file in the built product, so it gets a real XCTest that
reads `Bundle.main` — the same reasoning E18·T08 used, and the reason it is not a package test. The
metadata is sixty text files, so it gets two scripts: E18·T08's checker pointed at a directory, and a
new `check-metadata.sh` for the structural facts a lexeme checker cannot see. Both are proved by
planting.

**Step 1a — write the failing manifest test.** Add to `HunchTests/PrivacyManifestTests.swift`:

```swift
import Foundation
import XCTest

/// §12.9 and `07 B36`. XCTest in the host-app bundle, because the claim is about the artefact the
/// build produced: a package test would read its own bundle and prove nothing. This file asserts
/// what the manifest DOES say; `InfoPlistTests` (E18·T08) asserts what the plist does NOT.
final class PrivacyManifestTests: XCTestCase {

    private func manifest() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "no privacy manifest in the built product — 07 B36 makes this an UPLOAD rejection")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    func testNothingIsTrackedAndTheDomainListIsEmpty() throws {
        let plist = try manifest()
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(plist["NSPrivacyTrackingDomains"] as? [String], [])
        // Empty, present. An absent key and an empty array read the same to a human and
        // differently to the validator.
    }

    func testNothingIsCollected() throws {
        let plist = try manifest()
        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        XCTAssertEqual(collected, [], "the App Privacy answers say Data Not Collected; so must this")
    }

    func testExactlyOneRequiredReasonAPI_UserDefaults() throws {
        let plist = try manifest()
        let accessed = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(accessed.count, 1, "this app uses one required-reason API: UserDefaults")
        let entry = try XCTUnwrap(accessed.first)
        XCTAssertEqual(entry["NSPrivacyAccessedAPIType"] as? String,
                       "NSPrivacyAccessedAPICategoryUserDefaults")
        let reasons = try XCTUnwrap(entry["NSPrivacyAccessedAPITypeReasons"] as? [String])
        XCTAssertEqual(reasons.count, 1)
        // The code itself is asserted against DECISIONS.md's recorded value rather than a literal,
        // because `07 B36` could not verify the strings and the authority is Apple's rendered page.
        XCTAssertEqual(reasons.first, RecordedPrivacyReason.userDefaultsOwnContainer)
    }

    func testNoOtherCategoryAppears() throws {
        let plist = try manifest()
        let accessed = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let categories = Set(accessed.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
        for other in ["NSPrivacyAccessedAPICategoryFileTimestamp",
                      "NSPrivacyAccessedAPICategorySystemBootTime",
                      "NSPrivacyAccessedAPICategoryDiskSpace",
                      "NSPrivacyAccessedAPICategoryActiveKeyboards"] {
            XCTAssertFalse(categories.contains(other),
                           "\(other) declared — either it is untrue or the app grew a capability")
        }
    }

    /// `07 B37`, asserted as a REGRESSION guard rather than as a new fact: E01·T02 set it in the
    /// xcconfig and E18·T08 asserted its value. This asserts nobody re-added it somewhere else.
    func testTheEncryptionKeyHasExactlyOneHome() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption")
                       as? Bool, false)
        // A second declaration would be a plist file added to override the build setting — the
        // second home `07 B5` exists to prevent.
        XCTAssertNil(Bundle.main.url(forResource: "Info", withExtension: "plist",
                                     subdirectory: "Overrides"))
    }

    func testTheManifestIsAtTheBundleRootAndThereIsExactlyOne() throws {
        let all = Bundle.main.urls(forResourcesWithExtension: "xcprivacy", subdirectory: nil) ?? []
        XCTAssertEqual(all.count, 1, "01 P32: one manifest, at the app bundle root")
    }
}
```

**Step 1b — write the failing metadata plants.** Before either script exists, write
`/tmp/prove-metadata.sh` — scratch, not committed:

```bash
#!/bin/bash
# Every plant must print CAUGHT; every legal spelling must print OK.
set -uo pipefail
probe() { eval "$2"
  if bash Scripts/check-metadata.sh && swift Scripts/check-banned-lexemes.swift Metadata/; then
    echo "$1: MISSED"; else echo "$1: CAUGHT"; fi
  eval "$3"; }

# §1.13 row 1, in English — the category term with the implied benefit.
probe 'en "brain training"' \
  'printf "Brain training for the curious.\n" >> Metadata/en/description.txt' \
  'git checkout -- Metadata/en/description.txt'

# §14.6 risk 8: the highest exposure is where a translator reaches for the local category term.
probe 'de Gehirnjogging' \
  'printf "Gehirnjogging.\n" >> Metadata/de/subtitle.txt' \
  'git checkout -- Metadata/de/subtitle.txt'
probe 'ja 脳トレ' \
  'printf "脳トレ\n" >> Metadata/ja/keywords.txt' \
  'git checkout -- Metadata/ja/keywords.txt'
probe 'ar ذاكرة' \
  'printf "ذاكرة\n" >> Metadata/ar/description.txt' \
  'git checkout -- Metadata/ar/description.txt'

# Exclamation marks are on the same list, in all twelve.
probe 'exclamation mark in tr' \
  'printf "Yeni!\n" >> Metadata/tr/release_notes.txt' \
  'git checkout -- Metadata/tr/release_notes.txt'

# Structural facts a lexeme checker cannot see.
probe 'subtitle over 30 characters' \
  'printf "A rule-induction puzzle about hidden laws\n" > Metadata/en/subtitle.txt' \
  'git checkout -- Metadata/en/subtitle.txt'
probe 'a missing locale file' 'rm Metadata/ar/keywords.txt' 'git checkout -- Metadata/ar/keywords.txt'
probe 'a localized wordmark' 'printf "ХАНЧ\n" > Metadata/ru/name.txt' 'git checkout -- Metadata/ru/name.txt'
probe 'a screenshot of a screen that renders text' \
  'sed -i "" "s/\"RoundView\"/\"SettingsView\"/" Metadata/screenshots.json' \
  'git checkout -- Metadata/screenshots.json'

# The legal spellings must NOT be caught, or the checkers get switched off.
bash Scripts/check-metadata.sh >/dev/null 2>&1 && echo 'clean tree: OK' || echo 'clean: FALSE POSITIVE'
printf 'Every law is unique to its seed.\n' >> Metadata/en/description.txt
swift Scripts/check-banned-lexemes.swift Metadata/ >/dev/null 2>&1 \
  && echo '"unique" (the IQ word-boundary case): OK' || echo '"unique": FALSE POSITIVE'
git checkout -- Metadata/en/description.txt
printf 'A rule-induction puzzle.\n' >> Metadata/en/description.txt
swift Scripts/check-banned-lexemes.swift Metadata/ >/dev/null 2>&1 \
  && echo 'the APPROVED framing itself: OK' || echo 'approved framing: FALSE POSITIVE'
git checkout -- Metadata/en/description.txt
```

**Step 2 — run them and watch them fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" -only-testing:HunchTests/PrivacyManifestTests | xcbeautify
bash /tmp/prove-metadata.sh
```

The XCTest run must fail on *"no privacy manifest in the built product"* — not on a parse error, which
would mean the file exists and is malformed, a different and more urgent bug. The script prints
`MISSED` on every line because `Metadata/` does not exist and `check-metadata.sh` does not exist;
E18·T08's checker already exits 0 on an absent path and says so, which is the correct starting state
and not a hole.

**Step 3 — implement.** The manifest first (it is four keys), then the English copy, then the eleven
translations, then the two checks, then the review notes.

**Step 4 — green, then re-read all sixty by hand.** §13.12 gate 13 says *re-read every string before
submission*, and a checker that matches tokens cannot see an implication. Record the re-read in
`PROGRESS.md` with the date and who did it.

## Files

| Action | Path |
|---|---|
| create | `App/PrivacyInfo.xcprivacy` — four keys, at the app bundle root, a member of the `Hunch` target |
| create | `HunchTests/PrivacyManifestTests.swift` |
| create | `HunchTests/RecordedPrivacyReason.swift` — the reason code, with the URL and the date it was read |
| create | `Metadata/<locale>/{name,subtitle,description,keywords,release_notes}.txt` — 12 × 5 = 60 files |
| create | `Metadata/review-notes.txt` — English, App Review Notes, itself checked |
| create | `Metadata/screenshots.json` — which screen each shot is of, per locale |
| create | `Scripts/check-metadata.sh` |
| modify | `Scripts/check-source-hygiene.sh` — check 8 gains the `Metadata/` corpus |
| modify | `.github/workflows/ci.yml` — `check-metadata.sh` and the metadata lexeme pass as named steps |
| modify | `PROGRESS.md` — the sixty-unit human re-read, the native review of the eleven, the screenshots reviewed in en / de / ar |
| modify | `DECISIONS.md` — the reason code with its source and date; any §1.13 exception, which only the user may grant |
| modify | `tests.json` — `privacy.manifest`, `privacy.no-tracking`, `metadata.claims-pass`, `metadata.structure`, and gate 13's human re-read as `manual` |

## Implementation notes

### The manifest — four keys, and the one that must not be guessed

```xml
<!-- App/PrivacyInfo.xcprivacy -->
<!-- §14.4: no network of any kind, no analytics, no crash SDK. The claim below is not a promise;
     it is a consequence, and check 5 plus T12's airplane-mode playthrough are the evidence. -->
<key>NSPrivacyTracking</key>            <false/>
<key>NSPrivacyTrackingDomains</key>     <array/>
<key>NSPrivacyCollectedDataTypes</key>  <array/>
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <!-- §12.6: UserDefaults holds preferences only, under `hunch.settings.`; game state is JSON
         in Application Support (§11.13). That distinction is what makes the reason truthful. -->
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string><!-- read from Apple's page; see DECISIONS.md --></string></array>
  </dict>
</array>
```

**The reason code is the one string in this repository that must not be copied from a document — this
one included.** `07 B36` says so explicitly: as of its writing the DocC endpoints returned only key
descriptions and not the reason tables, so every code circulating in guides and blog posts is
unverified. Read the rendered HTML at
`developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api`, find the
row for *"access your app's own `UserDefaults`"*, copy that code, and record in `DECISIONS.md` the
code, the URL and the **date you read it**. A wrong code is a truthfulness problem under a manifest
whose whole content is a truthfulness claim, not a typo.

`RecordedPrivacyReason.userDefaultsOwnContainer` exists so the test asserts against a value with a
provenance comment rather than against a literal in two places. If the code ever changes, one file
changes and one `DECISIONS.md` entry gets a second date.

Three things about the other keys:

- **Empty arrays, present.** `NSPrivacyTrackingDomains` and `NSPrivacyCollectedDataTypes` are declared
  and empty rather than omitted. An omitted key and an empty array read identically to a human and
  differently to a validator, and the whole point of this file is to be read by a validator.
- **No other category.** `testNoOtherCategoryAppears` names the other four explicitly. If one ever
  appears, either it is untrue or the app grew a capability — and both need a conversation, not a
  quick addition.
- **One manifest, at the bundle root** (`01 P32`). Both packages are static, so nothing else needs one;
  `testTheManifestIsAtTheBundleRootAndThereIsExactlyOne` is what notices the day one becomes dynamic.

### The App Privacy questionnaire is a third artefact and nothing checks it

`rejection-triggers.md` §3, and it is the most easily missed item in this task because it lives in a
web form rather than in the repo. Three things must agree and no tool compares them:

| Artefact | Where | Says |
|---|---|---|
| `PrivacyInfo.xcprivacy` | the binary | no tracking, no collection, one required-reason API |
| the App Privacy questionnaire | App Store Connect | **Data Not Collected**, every category |
| the About screen's no-data-collected line | `Localizable.xcstrings`, twelve languages | the same, in words |

Answering the questionnaire is part of the release run, not of this task — but the *answers* are fixed
here and written into `PROGRESS.md` so the release run copies rather than decides. If one of the three
ever changes, all three change in the same commit.

### The sixty units — write from the approved column, not away from the banned one

§1.13's table has two columns and the left one is the famous one. **Write from the right one.** Every
row's approved replacement is a usable sentence about this game, and the reason column is what
generalises to a phrase the table does not list:

| Field | Chars | English, built from §1.13's approved column |
|---|---|---|
| `name` | ≤ 30 | `HUNCH` — the wordmark, **identical in all twelve** (§12.9) |
| `subtitle` | ≤ 30 | row 1's approved replacement: *"A rule-induction puzzle."* |
| `description` | ≤ 4000 | rows 2, 3, 4, 5, 9, 11, 12, 14 supply the paragraphs: what the task is; the machine with a hidden law; how few probes; eight families and 27,015 laws generated on the device; probe, work out the law, say it back; no reflexes required and only SIEVE is timed; laws found and probes used, nothing sent anywhere; pay once, no ads, no purchases, no accounts |
| `keywords` | ≤ 100 total | nouns from the game's own vocabulary. **Not** a category term, and the category-term risk is exactly what §1.13 row 1 is about |
| `release_notes` | ≤ 4000 | first release: one sentence. Row 13's reason applies — no superlative, no exclamation mark |

Five rules that decide the copy, all of them §1.12's:

1. **No second person.** The Loom never addresses the player. That is a tone rule in the app and it
   carries to the listing, where it also happens to be the safest register available: a sentence that
   describes the *task* cannot promise the *player* anything.
2. **No exclamation marks, in any of the twelve.** They are on the banned-lexeme list and the checker
   matches them per locale.
3. **Nouns over verbs; ≤ 8 words per line where a line is a claim.** The description is prose and may
   be longer, but every sentence in it should survive being read aloud flatly.
4. **Never name a mechanic where a drawing works** — which is why the screenshots carry the weight and
   the description does not explain the Bench.
5. **The listing must describe the model the binary ships.** Paid once, no IAP, no free tier (§1.4 P5,
   §14.5 decision 1). "Free", "premium" and "try before you buy" are on the banned list for exactly
   this reason, and a configured-but-unused IAP product is a review question you do not want.

**The eleven translations follow §14.5 decision 6**: machine-draft, then native review — and the
native review is a gate, recorded, not a plan. §14.6 risk 8 is explicit that this is where the highest
claims exposure lives, because a well-meaning translator reaches for the local category term. The
checker catches the tokens on the list; the native reviewer catches the ones that are not.

### `Scripts/check-metadata.sh` — the structural half

A lexeme checker cannot see a 31-character subtitle, a missing locale, or a name that got translated.
Those need a parse, so they are a separate program (`hunch-build-and-ci`'s "to add a gate" step 2), and
it asserts:

```bash
#!/bin/bash
# Scripts/check-metadata.sh — the sixty App Store units, structurally.
# §12.9 fixes the field set and the locale set; §1.13 binds the CONTENT and that is
# Scripts/check-banned-lexemes.swift's job, in directory mode. Two programs, one corpus.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$PWD}"
meta="$root/Metadata"
locales='ar de en es fr it ja ko pt-BR ru tr zh-Hans'          # the brief's twelve, sorted
fields='name subtitle description keywords release_notes'
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

[ -d "$meta" ] || { echo "No Metadata/ — nothing to check."; exit 0; }

# 1. Completeness: 12 × 5 = 60 files, no more and no fewer.
missing=''
for l in $locales; do for f in $fields; do
  [ -f "$meta/$l/$f.txt" ] || missing="$missing
  $l/$f.txt"
done; done
[ -n "${missing//[[:space:]]/}" ] && report 'Missing metadata unit (§12.9: 5 fields × 12 locales):' "$missing"

extra=$(find "$meta" -name '*.txt' | while IFS= read -r p; do
  rel="${p#"$meta"/}"; case " $locales " in *" ${rel%%/*} "*) : ;; *) echo "  $rel" ;; esac
done)
[ -n "${extra//[[:space:]]/}" ] && report 'A metadata file in a locale that is not one of the twelve:' "$extra"

# 2. Field limits. App Store Connect truncates silently; a truncated subtitle is a claim you
#    did not write.
overlong=$(for l in $locales; do
  for pair in "name 30" "subtitle 30" "keywords 100" "description 4000" "release_notes 4000"; do
    set -- $pair; f=$1; limit=$2; file="$meta/$l/$f.txt"
    [ -f "$file" ] || continue
    n=$(LC_ALL=en_US.UTF-8 awk '{ printf "%s", $0 } END { print "" }' "$file" | wc -m | tr -d ' ')
    [ "$n" -le "$limit" ] || printf '  %s/%s.txt  %s chars, limit %s\n' "$l" "$f" "$n" "$limit"
  done
done)
[ -n "$overlong" ] && report 'Metadata field over its App Store Connect limit:' "$overlong"

# 3. The wordmark. §12.9: "HUNCH" in all twelve locales including Arabic — a wordmark, not a word.
wrong=$(for l in $locales; do
  [ -f "$meta/$l/name.txt" ] || continue
  [ "$(tr -d '\n' < "$meta/$l/name.txt")" = "HUNCH" ] || printf '  %s/name.txt\n' "$l"
done)
[ -n "$wrong" ] && report 'The app name is a wordmark and is identical in twelve locales (§12.9):' "$wrong"

# 4. Screenshots are wordless BY CONSTRUCTION: every shot is of a play surface, and check 7
#    already proves those six files render no character in any locale.
play='RoundView|EchoRoundView|SieveRoundView|BenchView|AssayInspectorView|InscriptionView'
bad=$(jq -r --arg p "$play" '.shots[] | select(.screen | test($p) | not) | "  \(.locale): \(.screen)"' \
        "$meta/screenshots.json" 2>/dev/null || true)
[ -n "$bad" ] && report 'A screenshot of a screen that renders text (§12.9: screenshots carry 0 words):' "$bad"

[ "$status" -eq 0 ] && echo "Metadata: clean (60 units, 12 locales)"
exit "$status"
```

Two details that came out of running it and are load-bearing:

- **`wc -m`, not `wc -c`.** App Store Connect counts characters and half of these files are not ASCII;
  `wc -c` passes a Japanese subtitle that is three times over the limit.
- **The screenshot check is a *screen-selection* check, not an OCR.** §12.9 fixes screenshots at zero
  words, and the mechanical way to guarantee that is to shoot only surfaces that hygiene check 7
  already proves render no character. `screenshots.json` names the screen per shot and the check
  intersects that list with check 7's six files. Shooting Settings for a "look how few options" shot is
  the failure this catches, and it is a tempting one.

### Extending the lexeme pass over the metadata

E18·T08 shipped the checker's directory mode and left `Metadata/` absent. Wiring it is two lines and a
step:

```bash
# check-source-hygiene.sh, inside check 8's existing --fast guard
if ! swift Scripts/check-banned-lexemes.swift Metadata/; then
  report 'Banned lexeme in App Store metadata (§1.13):' 'see check-banned-lexemes output above'
fi
```

Directory mode scans every file under the path against **all twelve** locale lists rather than
inferring a locale per file — E18·T08's ruling, and it is the right one here for a second reason: the
metadata tree is named by locale, so a file misfiled under the wrong directory would otherwise be
checked against the wrong list and pass.

**`Metadata/review-notes.txt` is inside the scanned tree on purpose.** It is written in English, read
by a human at Apple, and it is still a statement about the product — `hunch-release`'s Never list has
"never write a claim … in a review reply" for the same reason.

Add the checker as its **own named CI step** for the metadata corpus, separate from the catalog one, so
a failure names which corpus rather than hiding inside "source hygiene". No `continue-on-error`.

### App Review notes — the most HUNCH-specific risk on the list

`rejection-triggers.md` §12, and it is in no guide. **A play surface with zero text in any locale can
read to a reviewer as an unfinished UI.** §1.4 P1 forbids tooltips, hint text, difficulty labels and
legends; §14.4 forbids tutorial screens and coach marks. A reviewer opens the app, sees an unlabelled
instrument panel and no instructions, and Guidelines 2.1 (App Completeness) and 4.2 (Minimum
Functionality) are both available to them.

Three or four sentences, English, in `Metadata/review-notes.txt`:

- the game is wordless **by design**, and the play surface renders no character in any locale;
- round 1 of band 1 **is** the tutorial and teaches by play (§14.2, §12.5);
- the verdict ring, the ribbon and the Assay are the entire feedback vocabulary; Settings, the Codex
  and the Profile carry all readable text;
- no account is needed and no demo credentials exist — **say it**, because an empty demo-account field
  is otherwise a query.

Keep it free of claims. It goes through the same checker as everything else, which is the mechanical
statement of that sentence.

### What this task does not re-assert

`InfoPlistTests` (E18·T08) already proves there is no `NS*UsageDescription` of any kind — which covers
`NSUserTrackingUsageDescription`, the key `07 B38` says must be **absent** rather than empty — no
`UIFileSharingEnabled`, no `LSSupportsOpeningDocumentsInPlace`, and that `ITSAppUsesNonExemptEncryption`
is `false`. **Do not write a second copy of any of those.** `testTheEncryptionKeyHasExactlyOneHome`
here is a different assertion: not the value, but that no override plist appeared beside the build
setting. Two tests for one fact is the drift this library exists to stop; two tests for two facts that
look alike is correct and needs a comment saying which is which.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchTests/PrivacyManifestTests` green, all six tests.
- [ ] `bash /tmp/prove-metadata.sh` prints `CAUGHT` on all nine plants and `OK` on all three legal spellings — including `"unique"` in `en`, which is the `IQ` word-boundary case, and the approved framing *"A rule-induction puzzle."* itself.
- [ ] `bash Scripts/check-metadata.sh` prints `Metadata: clean (60 units, 12 locales)` and exits 0.
- [ ] `swift Scripts/check-banned-lexemes.swift Metadata/` exits 0, and it runs as its own named step in `.github/workflows/ci.yml` with no `continue-on-error`.
- [ ] `find Metadata -name '*.txt' | wc -l` → `61` (60 units plus the review notes), and `ls Metadata` shows exactly the twelve locale directories plus `review-notes.txt` and `screenshots.json`.
- [ ] `for l in Metadata/*/; do tr -d '\n' < "$l/name.txt"; echo; done | sort -u` → one line, `HUNCH`.
- [ ] `PropertyListSerialization` parses `App/PrivacyInfo.xcprivacy`, and `/usr/libexec/PlistBuddy -c Print` on the **built** `Hunch.app` shows the manifest at the bundle root.
- [ ] `DECISIONS.md` carries the required-reason code, the exact URL it was read from, and the date — and states that it was read from Apple's rendered page rather than copied from any document, `07 B36` included.
- [ ] `PROGRESS.md` records: the sixty-unit human re-read against §1.13 with a date; the native review of the eleven translations per §14.5 decision 6; the screenshots reviewed in en / de / ar; and the three App Privacy answers that the release run will copy rather than decide.
- [ ] No `Scripts/banned-lexemes.allow` entry was added. If one was, it has three fields, its third resolves to a real `DECISIONS.md` anchor, and **the user granted it in writing** — §1.13's default is deletion.
- [ ] `tests.json` carries `privacy.manifest`, `privacy.no-tracking`, `metadata.claims-pass` and `metadata.structure` with runnable commands, and §13.12 gate 13's human re-read as `manual`; **no existing entry was removed, re-worded or weakened.**
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Reject any suggestion that replaces `RecordedPrivacyReason` with a string literal, or that merges `check-metadata.sh` into the lexeme checker: they answer different questions and one of them needs `jq`. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T11: a truthful PrivacyInfo.xcprivacy, 60 metadata units in twelve languages, and the claims pass extended over them"`

## Out of scope

- `ITSAppUsesNonExemptEncryption`, `UIDeviceFamily`, portrait-only and the zero-`NS*UsageDescription` assertion — **E01·T02** set them, **E18·T08** asserts them. This task adds one regression guard and duplicates nothing.
- `Localizable.xcstrings`, the ≤ 250-key budget, the twelve-locale completeness and the catalog's own lexeme pass — **E18·T01/T03/T08**.
- `Scripts/check-banned-lexemes.swift` itself, its folding, its word-boundary rule and `banned-lexemes.allow` — **E18·T08**. This task points it at a second corpus.
- The en / de / ar review screenshots taken by the XCUITest bundle — **E18·T09**. This task fixes which *screens* the store shots are of and proves the rule mechanically; it does not take them.
- The app icon, which App Review also reads — **T10**.
- The App Privacy questionnaire, the age rating, the price tier and the actual submission — **`/hunch-release`, user-invoked only.** This task fixes the answers and writes them down so the release run copies rather than decides.
- Archiving, exporting, uploading or tagging — **`/hunch-release`**, and never from an unmerged branch.
