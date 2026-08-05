# T08 — The banned-lexeme test

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | LOCALIZATION → Banned-lexeme test |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns check 8, `Scripts/banned-lexemes.txt` and the rule that a checker needing a parse or a toolchain becomes a **separate program** rather than another grep — which is exactly what diacritic folding forces here (`SKILL.md`, "Six more checkers are separate programs"). `references/source-hygiene.md` §3 is the conventions, §4 the prove-it-can-fail drill, §7 the shape of the three existing standalone checkers, and it also records the E01·T06 gap this task closes: `test($w; "i")` gives case-insensitivity only. |

## Objective

At the end of this task no value in any of the twelve languages can contain a banned lexeme or an
exclamation mark without failing the build, matched **case- and diacritic-insensitively** — closing
the gap E01·T06 recorded and deferred — and `Info.plist` is proved to carry zero localizable
strings, no `NS*UsageDescription` of any kind, and neither `UIFileSharingEnabled` nor
`LSSupportsOpeningDocumentsInPlace`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §1.13 | the fourteen banned framings, the per-locale token list verbatim, that **exclamation marks are on the same list**, and that a token clears only by a written exception in `DECISIONS.md` — the default is deletion |
| `GAME_DESIGN.md` | §1.13 (Enforcement) | *"an engineering artifact, not a review checklist"* — a test over the catalog **plus the App Store metadata files**, failing the build on any match |
| `GAME_DESIGN.md` | §11.11 P8 | the same test stated again as a Profile rule, and *why* the axis identifiers never enter the catalog: *Retention* and *Flexibility* land on "memory" and "ability" in several of the twelve |
| `GAME_DESIGN.md` | §12.9 (`Info.plist`) | zero localizable strings; **no `NS*UsageDescription` of any kind**; neither `UIFileSharingEnabled` nor `LSSupportsOpeningDocumentsInPlace`; `CFBundleDisplayName` is "HUNCH" in all 12 locales including Arabic |
| `GAME_DESIGN.md` | §11.5, §12.6 | there is no export and no `Documents/` content, which is what those two absent keys assert |
| `GAME_DESIGN.md` | §14.6 risk 8 | the risk this task retires: the highest banned-lexeme exposure is exactly where a translator reaches for the local category term |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B36`, `B37` | the privacy manifest and `ITSAppUsesNonExemptEncryption`; what a truthful `Info.plist` looks like |

The token list is §1.13's and has exactly one home on disk, `Scripts/banned-lexemes.txt`. Do not
inline it into a script and do not transcribe it from memory:

```bash
sed -n '/^`en` brain/,/^Exclamation marks/p' GAME_DESIGN.md
```

## TDD — the test comes first

Two halves again: a standalone checker, proved by planting; and a real Swift test for `Info.plist`,
because the built plist **is** reachable from a host-app test bundle even though the catalog is not.

**Step 1 — write the failing test.** Create `HunchTests/InfoPlistTests.swift` — the wizard-made
host-app bundle, which `01 P22`/`P40` say stays nearly empty and this is exactly what it is for:

```swift
import Foundation
import XCTest

/// §12.9: `Info.plist` contains zero localizable strings, and that is a verifiable privacy claim.
/// This is `XCTestCase` and not `@Test` because it must run inside the **app**, against the plist
/// the build actually produced — a package test would see its own bundle and prove nothing.
final class InfoPlistTests: XCTestCase {

    private var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    /// The app requests nothing, so there is no usage description of any kind — not a camera, not
    /// a microphone, not tracking. A single one of these keys turns a permissionless app into an
    /// app with a permission dialog and a privacy label.
    func testNoUsageDescriptionOfAnyKind() {
        let offenders = info.keys.filter { $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription") }
        XCTAssertEqual(offenders.sorted(), [], "Info.plist requests a permission")
    }

    /// §11.5 and §12.6: there is no export and nothing in `Documents/`. Either key would give the
    /// app a Files presence it must not silently acquire.
    func testNoFilesPresence() {
        XCTAssertNil(info["UIFileSharingEnabled"])
        XCTAssertNil(info["LSSupportsOpeningDocumentsInPlace"])
    }

    /// The wordmark. "HUNCH" in all 12 locales including Arabic — it is a wordmark, not a word.
    func testDisplayNameIsTheWordmarkInEveryLocale() throws {
        XCTAssertEqual(info["CFBundleDisplayName"] as? String, "HUNCH")
        for tag in ["ar", "de", "ja", "ru", "tr", "zh-Hans"] {
            let lproj = try XCTUnwrap(Bundle.main.path(forResource: tag, ofType: "lproj"))
            let localized = Bundle(path: lproj)?
                .localizedString(forKey: "CFBundleDisplayName", value: "HUNCH", table: "InfoPlist")
            XCTAssertEqual(localized, "HUNCH", "\(tag) localizes the wordmark")
        }
    }

    /// Zero localizable strings means the file that would hold them does not exist.
    func testNoInfoPlistStringsFileIsBundled() {
        for name in ["InfoPlist", "InfoPlist.xcstrings"] {
            XCTAssertNil(Bundle.main.path(forResource: name, ofType: "strings"))
            XCTAssertNil(Bundle.main.path(forResource: name, ofType: "loctable"))
        }
    }

    /// `07 B37`. Absent, it is an export-compliance question at every single upload.
    func testEncryptionDeclarationIsPresentAndFalse() {
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
    }
}
```

**Step 1b — write the checker's failing case.** Before writing
`Scripts/check-banned-lexemes.swift`, prove the current check 8 misses a diacritic:

```bash
# Portuguese "memória" against the list entry "memoria" — a real translator's spelling, and the
# exact hole E01·T06 recorded rather than closed.
jq '.strings["ABOUT_NO_DATA"].localizations["pt-BR"].stringUnit.value = "memória"' \
  Modules/Sources/HunchUI/Resources/Localizable.xcstrings > /tmp/planted.xcstrings
cp /tmp/planted.xcstrings Modules/Sources/HunchUI/Resources/Localizable.xcstrings
bash Scripts/check-source-hygiene.sh; echo "exit=$?"        # currently: CLEAN. That is the bug.
git checkout -- Modules/Sources/HunchUI/Resources/Localizable.xcstrings
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchTests/InfoPlistTests
```

Every assertion must fail for a reason you can name. `testEncryptionDeclarationIsPresentAndFalse`
should already pass — E01·T02 set it — and if it does not, that is a genuine finding and it is fixed
here. If `testDisplayNameIsTheWordmarkInEveryLocale` fails because there are no `.lproj` directories
in `Bundle.main`, the app target has no localizations of its own and only the package does; adjust
the test to assert *that* (no app-level localization exists at all), which is a stronger claim, and
say so in a comment.

**Step 3 — implement** the standalone checker, the completed token file, and the check-8 rewiring.

**Step 4 — green, then refactor.** Re-run the planted `memória` and eleven more plants, one per
locale, and confirm each is caught.

## Files

| Action | Path |
|---|---|
| create | `Scripts/check-banned-lexemes.swift` |
| modify | `Scripts/banned-lexemes.txt` — completed to all twelve locales plus twelve `!` lines |
| modify | `Scripts/check-source-hygiene.sh` — check 8's jq banned-lexeme block replaced by a call to the checker |
| modify | `.github/workflows/ci.yml` — the checker joins the gate ladder |
| create | `HunchTests/InfoPlistTests.swift` |
| modify | `Config/Base.xcconfig` — only if a plist assertion fails and a key must be removed |
| modify | `tests.json` — six entries (banned lexemes, exclamation marks, and the four plist absences) |
| modify | `DECISIONS.md` — the closure of E01·T06's folding gap; any lexeme exception |

## Implementation notes

### Why this is a Swift script and not more jq

§1.13 requires matching that is case- **and** diacritic-insensitive. `jq`'s `test($w; "i")` gives
case only, which E01·T06 recorded honestly as a gap with the compensating measure of listing both
spellings (`memoria`/`memória`, `concentración`/`concentração`) — a measure that works only for the
spellings somebody thought of.

Foundation has the exact primitive:

```swift
value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
```

so the checker becomes a Swift script, which is already a sanctioned shape in this repo —
`swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` runs in the same ladder.
`JSONSerialization` parses the catalog; no dependency is added; nothing new is installed on the
runner. Record in `DECISIONS.md` that E01·T06's gap is closed here, and *keep* the double spellings
in the token file — folding makes them redundant, not wrong, and removing them would be a second
change in the same commit for no gain.

### The matcher, and the trap inside it

```swift
// Scripts/check-banned-lexemes.swift
// §1.13's per-locale list, matched case- and diacritic-insensitively over every localized value in
// Localizable.xcstrings. Exit 1 on any hit. Exceptions clear only by a written DECISIONS.md entry
// plus a line in Scripts/banned-lexemes.allow; the default is deletion.

func fold(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
}

/// Word boundaries for cased scripts, substring for the rest. This is the difference between a
/// checker people trust and a checker people disable: `IQ` folded case-insensitively is `iq`, and
/// a naive `contains` flags "unique", "liquide" and "antiquité" in three of the twelve languages.
/// CJK and Arabic have no `\b` to anchor to, so those tokens match as substrings — which is
/// correct for them, because their morphology attaches rather than spaces.
func matches(_ token: String, in value: String) -> Bool {
    let haystack = fold(value)
    let needle = fold(token)
    guard needle.unicodeScalars.allSatisfy({ CharacterSet.casedScripts.contains($0) }) else {
        return haystack.contains(needle)
    }
    return haystack.range(of: "\\b\(NSRegularExpression.escapedPattern(for: needle))\\b",
                          options: .regularExpression) != nil
}
```

Three details that are all load-bearing:

- **`\b` for cased tokens only.** Without it `IQ` matches *unique* and `train` matches *constraint*,
  and §1.13 lists both `train` and `training` precisely because `\btrain\b` does not match
  *training* — the list already assumes word boundaries.
- **Substring for `脳`, `기억력`, `ذاكرة`.** Those scripts have no word boundary to anchor to and
  their affixes attach; a `\b` there would match nothing at all and the check would report clean
  over four locales.
- **`.widthInsensitive`** folds full-width Latin, which is how a Japanese translator's editor emits
  `ＩＱ`.

`CharacterSet.casedScripts` is a small local extension — Latin, Cyrillic and Greek — and it is
computed from the token, never from the locale, because a `de` value can legitimately contain a
Japanese word and a `ja` value can contain `IQ`.

### The token file, completed

`Scripts/banned-lexemes.txt` is `locale<TAB>lexeme`, `#` for a comment (E01·T06's format). Two
completions this task owns:

1. **Every locale's tokens from §1.13**, transcribed by the `sed` command above rather than from
   memory. E01 could not verify them against a catalog because there was none; now there is.
2. **Twelve `!` lines**, one per locale, because §1.13 puts exclamation marks on the same list and
   the matcher is per-locale with no wildcard. `!` is not a cased token, so it matches as a
   substring, which is what is wanted.

Add `Scripts/banned-lexemes.allow`, `locale<TAB>lexeme<TAB>DECISIONS.md-anchor`, empty on the day
it is created. It is the *only* way a token clears, and requiring the third column means an
exception cannot be added without pointing at the written reason. §1.13: *"A token clears only by a
written exception in `DECISIONS.md`; the default is deletion."*

### Where else the checker runs

§1.13 binds *"the App Store listing, screenshots, keywords, onboarding, Settings, the Codex, the
Profile, release notes and every localisation"*. Take the second argument now, so E20 wires files in
rather than rewriting the checker:

```bash
swift Scripts/check-banned-lexemes.swift Modules/Sources/HunchUI/Resources/Localizable.xcstrings
swift Scripts/check-banned-lexemes.swift Metadata/            # E20·T11 fills this; empty today
```

A directory argument scans every `.txt`/`.md`/`.json` under it against **all twelve** locale lists,
because App Store metadata files are named by locale and a per-file locale inference is one more
thing to get wrong. Ship the directory mode now and let `Metadata/` be absent; the checker exits 0
on an absent path and says so.

### Rewiring check 8

Delete check 8's `while IFS=$'\t' read -r loc word … jq … done` block and replace it with a call:

```bash
    # §1.13's per-locale banned lexemes, case- AND diacritic-insensitive. jq's test($w; "i") gives
    # case only, which E01·T06 recorded as a gap; Scripts/check-banned-lexemes.swift closes it.
    if ! swift Scripts/check-banned-lexemes.swift "$catalog"; then
      report 'Banned lexeme (§1.13):' 'see check-banned-lexemes output above'
    fi
```

Two implementations of one rule is drift waiting to happen; one implementation with two entry points
is not. It sits inside the existing `--fast` guard because it needs a Swift toolchain, exactly like
check 4 — the build-phase subset keeps skipping it and CI keeps running it.

Add it to the gate ladder in `.github/workflows/ci.yml` in its own step as well, positioned with the
other standalone checkers (`references/ci-workflow.md` §3), so a failure names *this* rule in the
step title rather than hiding inside "source hygiene".

### The `Info.plist` half

Everything asserted is an **absence**, which is why it needs a test rather than a grep: a key can
arrive from `GENERATE_INFOPLIST_FILE`'s defaults, from an SDK, or from a target-level setting
somebody typed into the Build Settings tab (`07 B5`) — and none of those is visible in
`Config/*.xcconfig`. The built plist is the only truthful source, and `Bundle.main.infoDictionary`
inside the host-app bundle is the only place to read it.

If an assertion fails, the fix is in `Config/Base.xcconfig` and the failing key tells you which
`INFOPLIST_KEY_*` to remove — never a plist file added to the repo to override it, which would
reintroduce the second home `07 B5` exists to prevent.

Pair the test with a cheap source-side grep in the same commit so the failure is caught before a
build rather than after one:

```bash
hits=$(grep -rn 'INFOPLIST_KEY_NS[A-Za-z]*UsageDescription\|UIFileSharingEnabled\|LSSupportsOpeningDocumentsInPlace' \
       Config App 2>/dev/null || true)
[ -n "$hits" ] && report 'A permission or a Files presence the app must not have (§12.9):' "$hits"
```

## Acceptance criteria

- [ ] `swift Scripts/check-banned-lexemes.swift Modules/Sources/HunchUI/Resources/Localizable.xcstrings` exits 0 on the clean catalog.
- [ ] Twelve planted violations — one token per locale, taken from §1.13 — each make it exit 1 naming the key, the locale and the token. The `pt-BR` plant is **`memória` against the list's `memoria`**, which is the diacritic case E01·T06 could not catch. All twelve outputs in `.github/pr-body.md`.
- [ ] A planted `!` in each of the twelve locales is caught, and a planted `IQ` in `en` is caught while the word `unique` in `en` is **not** — the word-boundary case, both directions, recorded.
- [ ] `awk -F'\t' 'NF!=2 && $0 !~ /^#/ && NF' Scripts/banned-lexemes.txt` returns nothing, and `grep -c '^' Scripts/banned-lexemes.txt` shows at least twelve `!` lines.
- [ ] `Scripts/banned-lexemes.allow` exists and is empty, or every line in it has three fields and its third field resolves to a real anchor in `DECISIONS.md`.
- [ ] `bash Scripts/check-source-hygiene.sh` green, with check 8's banned-lexeme block now a single call and no second copy of the token list anywhere: `grep -rn 'Gehirn\|мозг\|脳' Scripts/ | grep -v banned-lexemes.txt` returns nothing.
- [ ] `xcodebuild test … -only-testing:HunchTests/InfoPlistTests` green — all five tests.
- [ ] `.github/workflows/ci.yml` runs the checker as its own named step, with no `continue-on-error`.
- [ ] `DECISIONS.md` records the closure of E01·T06's folding gap, naming the API used.
- [ ] `tests.json` carries the six entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T08: diacritic-insensitive banned-lexeme checker and the Info.plist absences"`

## Out of scope

- **The English copy review against §1.13's fourteen framings** — **T02**, which is the human half.
  This task is the machine half and it runs over all twelve.
- **The translations themselves** — **T03**. A hit here means a translation is wrong, and the fix is
  a new translation, not an allowlist entry.
- **App Store name, subtitle, description, keywords and what's-new in twelve languages** —
  **E20·T11**, which points the checker's directory mode at `Metadata/`. This task ships that mode
  and leaves the directory absent.
- **`PrivacyInfo.xcprivacy`** — **E20·T11**. `InfoPlistTests` asserts what the plist does **not**
  contain; the privacy manifest is a separate, positive declaration.
- **`ITSAppUsesNonExemptEncryption`'s value** — **E01·T02** set it; this task only asserts it
  survived.
- **The wordless App Store screenshots** — **E20·T11**; the en/de/ar review screenshots are **T09**
  and are a different artifact for a different purpose.
