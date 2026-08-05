# HUNCH release checklist — the pre-archive gates and everything after them

Read this while running `/hunch-release`. It carries the commands; `SKILL.md` carries the order and
the stop conditions. App Store Connect metadata is the other reference file,
`rejection-triggers.md`.

Citation convention throughout: a bare `§n` is a section of `GAME_DESIGN.md`; `07 Bnn`, `08 §n`,
`01 Pnn` and `06 Tnn` are numbered rules in `ios-swift-guide/`. Print any rule with
`grep -n '^\*\*B27[. ]' ios-swift-guide/*.md` rather than trusting a paraphrase.

## Contents

1. [Inputs you need before you start](#1-inputs-you-need-before-you-start)
2. [The nine gates A1–A9, with commands and pass conditions](#2-the-nine-gates-with-commands)
3. [Version numbers, archive and the two exports](#3-version-numbers-archive-and-the-two-exports)
4. [The size gate](#4-the-size-gate)
5. [Upload and tag](#5-upload-and-tag)
6. [After the upload](#6-after-the-upload)
7. [When a gate is red](#7-when-a-gate-is-red)

---

## 1. Inputs you need before you start

| Input | Where it comes from | Note |
|---|---|---|
| `ASC_KEY_PATH`, `ASC_KEY_ID`, `ASC_ISSUER_ID` | An App Store Connect API key (`.p8`), downloadable exactly once | `07 B35`. Never in the repo, never in an `.xcconfig` — `Config/Local.xcconfig` is gitignored but still on disk in a build directory. Environment only. |
| `MARKETING_VERSION` | A human edits `Config/Base.xcconfig` in the release commit | `07 B27` |
| `BUILD` | Strictly greater than the last **uploaded** build for this marketing version | App Store Connect is the authority. In CI it is `$GITHUB_RUN_NUMBER`. |
| The toolchain | `xcodebuild -version` must match the pin in `hunch-build-and-ci` | `07 B28`/`B29`. A release archived on a different Xcode than CI tested on is an untested archive. |

Confirm the SDK rather than assuming it — the brief asks for this explicitly:

```bash
xcodebuild -version && xcodebuild -showsdks | grep iphoneos
xcrun simctl list devices available | grep -i iphone      # for the A4 destination
```

---

## 2. The nine gates, with commands

Each row: what to run, what green looks like, and what a failure actually means. The third column is
the one that matters — every one of these has a tempting wrong fix.

### A1 — clean tree

```bash
git status --porcelain && git describe --tags --abbrev=0
```

Green: no output from the first command. A dirty tree means the archive cannot be reproduced from a
tag, so a crash report from this build can never be mapped back to source. Commit or stash; do not
archive "just to see".

### A2 — the fast suite

```bash
START=$SECONDS
swift test --package-path HunchCore
echo "fast suite: $((SECONDS-START))s"
```

Green: all pass, and the elapsed figure is inside the brief's ten-second budget (`08 §5`). Over
budget is a real failure — `hunch-swift-testing` owns what to gate to nightly. Raising the budget is
not a fix; the budget is the reason the two-package split exists.

### A3 — Level-B calibration, full matrix

```bash
HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter CalibrationTests
```

Green: the run summary reports **cases executed**, not zero. `§14.5` decision 5 makes the full matrix
a hard gate before any archive; `08 §5` gates it behind the environment variable so it stays out of
the fast loop. Without the variable the suite is *skipped and reported as success* — the single
easiest way to ship an uncalibrated difficulty engine.

A failure here is a design failure, not a test failure: `§14.6` risk 3 says regenerate the `§5.1`
modifier weights from the harness. Never weaken H10's ρ threshold to clear a release.

### A4 — the simulator suite, `Prerelease` plan

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -testPlan Prerelease \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -resultBundlePath build/Prerelease.xcresult \
  | xcbeautify --renderer github-actions
xcrun xcresulttool get test-results summary --path build/Prerelease.xcresult --compact
```

Green: zero failures **and** a non-zero test count. `set -o pipefail` is not optional — without it the
pipeline's status is `xcbeautify`'s and a failing suite reports success (`07 B31`). Resolve the
destination by `OS=latest` or a UDID, never a hardcoded name+OS pair (`07 B30`). Results come from
`get test-results`, not the deprecated `get object` (`07 B33`). A plan whose include-tag filter names
a tag `06 T29` never declared selects nothing and reports green over zero tests (`07 B24`).

### A5 — source hygiene, every check in the roster

```bash
Scripts/check-source-hygiene.sh
```

Green: `Source hygiene: clean`, exit 0.

**The roster is `hunch-build-and-ci/SKILL.md`'s numbered table, and it is not reproduced here** — a
second copy is how this gate came to be labelled "all nine" while the script had ten. Read the table,
confirm the run reported every row in it, and only then tick the box. The script is the build skill's;
this gate only runs it.

Two rows are worth knowing by name before you start, because they are the ones a release run is
tempted to wave through. **Check 3** is the concurrency escape hatch. **Check 10** is register
laundering — `HueColor(` / `AccentColor(` minted outside `Tokens` — the mechanical half of the §13.2
register split that the type system cannot enforce across the module boundary, and the one grep
standing between a laundered `.rgb` and the App Store.

Check 3 failing means someone added an `@unchecked Sendable`, `nonisolated(unsafe)`, `Task.detached`
or `assumeIsolated` without the justifying comment. `08 §4` says `VoiceBank` should be the only one in
the repository — a second hit is a design question for `hunch-swift-concurrency`, not a comment to
add.

### A6 — zero warnings in Release

```bash
xcodebuild -project Hunch.xcodeproj -scheme Hunch -configuration Release \
  -destination 'generic/platform=iOS' build 2>&1 | grep -c ' warning: '
```

Green: `0`, and the build succeeds. `-warnings-as-errors` is already on Release
(`07 B18`), so a warning is a build failure — the grep is belt-and-braces for anything a
`-Wwarning <group>` exemption downgraded. **The blanket flag is written first and any exemption after
it** (`07 B19`); `08 §7.12` instructs the opposite and is wrong, and `hunch-build-and-ci` carries that
ruling and the reasoning. Written the other way round the exemption is dead and the group errors the
archive. The brief's phase-8 gate is literally "archive builds clean with zero warnings".

### A7 — localization complete in twelve

Covered by A5 check 8. Green means: no key in any of the twelve locales carries a `new` or
`needsReview` state, the key count is inside `§12.9`'s budget, and no per-locale banned lexeme or
exclamation mark appears (`§1.13`). The catalog is compiled to `.lproj` at build time, so this is a
source lint over `Localizable.xcstrings` and can never be a package test (`08 §5`).

The highest-risk locales are the eleven you did not write. `§14.6` risk 8: the banned-lexeme risk is
highest in translation, where a translator reaches for the local category term for "brain game".
`§14.5` decision 6 requires native review of the visible strings before submission — that review is a
gate, and its absence is not something a script can detect.

### A8 — screens reviewed as pixels

Screenshots in en, de and ar, plus the two pseudolocales, reviewed by eye — the brief requires this
before any screen is called done, and again at phase 8. Set Application Language in a second
test-plan configuration rather than by hand (`07 B26`, `07 B40`): Double Length Pseudolanguage catches
truncation, RTL Pseudolanguage catches mirroring, and `Show non-localized strings` renders anything
unextracted in UPPERCASE — which is how `Text(someString)` gets caught (`07 B39`).

What you are looking for, in order: any writing-system glyph on a play surface in any locale
(`§1.4` P1 — this falsifies a pillar); German or Russian Settings rows wrapping past two lines at
AX3; mirrored chrome in Arabic with unmirrored instruments; and any numeral where `§12.9` says a tick
row belongs.

### A9 — accessibility audit

`performAccessibilityAudit` over the main flows, in an `XCTestCase` in `HunchUITests/` — it needs the
out-of-process runner, so it cannot be a `@Test` (`07 §14`, `06 T43`, `08 §7.10`). Green means the
audit ran and did not suppress everything: an `issueHandler` returning `true` unconditionally
suppresses every issue and the test can never fail (`07 B46`). `hunch-accessibility` owns the audit
types and the accepted exceptions.

---

## 3. Version numbers, archive and the two exports

**`MARKETING_VERSION` is committed. `CURRENT_PROJECT_VERSION` never is.** (`07 B27`)

```bash
# Right — overrides the xcconfig for this invocation and dirties nothing.
xcodebuild archive … CURRENT_PROJECT_VERSION="$BUILD"

# Wrong — rewrites files on disk and forces a commit out of the release.
agvtool new-version -all "$BUILD"
```

A `PlistBuddy` run-script phase is worse than either: it has no meaningful inputs or outputs, so it
re-runs on every incremental build anyone ever does (`07 B15`).

### The archive

```bash
xcodebuild archive \
  -project Hunch.xcodeproj \
  -scheme Hunch \
  -destination 'generic/platform=iOS' \
  -archivePath build/Hunch.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  CURRENT_PROJECT_VERSION="$BUILD"
```

One archive, two exports out of it. Never archive twice for the same release — two archives with the
same build number are two different binaries and only one of them was tested.

### ExportOptions-AdHoc.plist — for the size number only

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>            <string>release-testing</string>
    <key>teamID</key>            <string>$(DEVELOPMENT_TEAM)</string>
    <key>thinning</key>          <string>&lt;thin-for-all-variants&gt;</string>
    <key>signingStyle</key>      <string>automatic</string>
    <key>destination</key>       <string>export</string>
</dict>
</plist>
```

### ExportOptions-AppStore.plist — for the upload

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>                          <string>app-store-connect</string>
    <key>teamID</key>                          <string>$(DEVELOPMENT_TEAM)</string>
    <key>destination</key>                     <string>upload</string>
    <key>uploadSymbols</key>                   <true/>
    <key>manageAppVersionAndBuildNumber</key>  <false/>
    <key>signingStyle</key>                    <string>automatic</string>
</dict>
</plist>
```

Four things about those two files, each of which has burnt someone:

- **`destination`** decides whether `-exportArchive` writes an `.ipa` or uploads. `export` is the
  default; `upload` is what makes the App Store plist an irreversible act. Keep them in separate files
  precisely so the Ad Hoc run can never upload by accident.
- **`manageAppVersionAndBuildNumber`** left at its default lets the toolchain pick a build number for
  you, which silently discards the `$BUILD` you injected and breaks the "the tag names what shipped"
  property. Set it `false`.
- **The distribution method names were renamed in Xcode 15** (`app-store` → `app-store-connect`,
  `ad-hoc` → `release-testing`, `development` → `debugging`). Old names are still accepted. Do not
  take that from this file — `xcodebuild -help` prints the accepted values and keys for
  `-exportOptionsPlist` on the toolchain you are actually using, and that is the authority.
- **`thinning` is what produces the size report.** Without
  `&lt;thin-for-all-variants&gt;` there is no `App Thinning Size Report.txt` and §4 has nothing to read.

---

## 4. The size gate

```bash
xcodebuild -exportArchive -archivePath build/Hunch.xcarchive \
  -exportPath build/adhoc -exportOptionsPlist ExportOptions-AdHoc.plist \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

cat "build/adhoc/App Thinning Size Report.txt"
```

**The `.app`, the `.xcarchive` and the `.ipa` all contain things users never download — dSYMs among
them — so none of them is a size measurement** (`07 B44`). The report gives compressed (≈ download)
and uncompressed (≈ installed) figures per variant. Compare the largest variant against the brief's
ceiling in `hunch-claude-code-prompt.md` `<constraints>`, and diff against the previous release's
report — the number that matters is the delta, because a jump means something was added that should
not have been.

Two HUNCH-specific expectations. The app has **no image assets for glyphs and no audio files** — every
glyph is `Canvas`/`Shape` and every cue is synthesised (`08 §1`), so a size jump is almost always
either a bundled resource that should be derived or a data table baked into source as string literals
(`07 B45`). And `lowerBandIndex.bin` is a *derived* file built on device (`§14.5` decision 4); if it
has been shipped as a bundled resource, it is on this line item and it must then be version-locked to
the generator.

App Store Connect is the more authoritative number once the build is processed, and it warns past the
cellular download limit. TestFlight builds are larger than App Store builds, and the final App Store
build can be slightly larger than what you uploaded because Apple adds DRM and re-compresses.

---

## 5. Upload and tag

```bash
xcodebuild -exportArchive -archivePath build/Hunch.xcarchive \
  -exportPath build/appstore -exportOptionsPlist ExportOptions-AppStore.plist \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

This is the irreversible step. `altool` is not the tool — its `--upload-app` is deprecated and
`notarytool` replaced it for notarization; for iOS, `-exportArchive` supersedes both (`07 B35`).

Immediately after a successful upload:

```bash
git tag -a "v${MARKETING_VERSION}-${BUILD}" -m "App Store build ${BUILD}"
git push --tags
```

Tag with the pair, not just the marketing version — a marketing version can carry several uploads and
only the pair identifies a binary. Archive the `.xcarchive` (it holds the dSYMs) somewhere durable
before deleting `build/`.

---

## 6. After the upload

- [ ] The build finishes processing in App Store Connect and appears under TestFlight without a
      **Missing Compliance** banner. If it has one, `ITSAppUsesNonExemptEncryption` is not set in the
      xcconfig and every future build will need a manual click (`07 B37`).
- [ ] Install the TestFlight build on a real device and play one full round **in airplane mode** —
      the brief's phase-8 gate, and the only end-to-end proof of the no-network claim that the grep
      cannot give you.
- [ ] Haptics discriminated face-down by three testers (`§14.3` phase 8).
- [ ] `references/rejection-triggers.md`, top to bottom, before Submit for Review.
- [ ] `PROGRESS.md` and `tests.json` updated; the release recorded in `DECISIONS.md` with the build
      number, the tag, and any written exception granted during the gates.

---

## 7. When a gate is red

The failure mode this whole procedure exists to prevent is a gate being *made* green rather than
*becoming* green. For each gate, the tempting wrong fix and the right one:

| Gate | The tempting fix | What to do instead |
|---|---|---|
| A2 over budget | raise the ten seconds | gate the expensive suite to `.nightly` with `.enabled(if:)` — never delete it (`06 T58`) |
| A3 ρ below threshold | lower the threshold | regenerate the `§5.1` modifier weights from the harness (`§14.6` risk 3) |
| A4 flaky | add a retry, or `.serialized` | a flake is shared mutable state; `hunch-swift-testing`'s Never list covers this |
| A5 check 3 | add a comment to the hatch | ask why there is a second hatch at all (`08 §4`) |
| A5 check 8 | add the token to the exception list | delete the string; an exception needs a written entry in `DECISIONS.md` and the default is deletion (`§1.13`) |
| A6 warning | `-Wwarning` the group | fix it, or put the exemption **after** the blanket flag and name its price (`07 B19`) |
| A7 `needsReview` | mark it reviewed | it is not reviewed; `§14.5` decision 6 says native review of the visible strings |
| A8 truncation | shrink the font | rows grow vertically; nothing truncates and nothing scales down (`§12.9` trap 2) |
| A9 audit issue | blanket-return `true` | suppress the one known element by label and type, everything else fails (`07 B46`) |
| B3 over size | ship anyway | find the delta against the last report; it is a bundled resource or a source literal (`07 B45`) |
