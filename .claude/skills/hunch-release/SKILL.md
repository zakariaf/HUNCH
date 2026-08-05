---
name: hunch-release
description: "Runs HUNCH's release procedure — version and build numbers, the pre-archive gates, archive, sign, upload, and the App Store Connect metadata that gets builds rejected. Invoke deliberately; it has side effects and is user-invoked only."
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(Scripts/check-source-hygiene.sh:*) Bash(swift test:*) Bash(xcodebuild -showBuildSettings:*) Bash(xcrun swift-format lint:*) Bash(git status:*) Bash(git log:*) Bash(git describe:*)
metadata:
  version: "1.0"
  owns: "the gate order before an archive, version and build-number handling at release time, the archive/export/upload commands, and HUNCH's rejection surface"
---

## What this build would carry

```!
r="${CLAUDE_PROJECT_DIR:-.}"
if [ -f "$r/Config/Base.xcconfig" ]; then
  grep -hE '^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)' "$r/Config/Base.xcconfig"
else
  echo "NO Config/Base.xcconfig — nothing is archivable yet; hunch-build-and-ci builds it first."
fi
echo "last tag:     $(git -C "$r" describe --tags --abbrev=0 2>/dev/null || echo '(none)')"
echo "dirty paths:  $(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
```

Read those lines before anything else, and trust them over any version written down. A non-zero dirty count means this archive could never be reproduced from a tag — commit or stash first.

`hunch-build-and-ci` owns the xcconfigs, the manifests, the checkers and the workflow. This skill only sequences them, and owns everything after the last gate. Citations below: a bare `§n` is a section of `GAME_DESIGN.md`; `07 Bnn` and `08 §n` are numbered rules in `ios-swift-guide/`.

## Two of these steps are irreversible

An uploaded `CURRENT_PROJECT_VERSION` can never be reused, and a metadata string that clears review is a public claim under `GAME_DESIGN.md §1.13`. **Gates A1–A9 are read-only and safe to run at any time. Stop before section B and get the user's word that this build is meant to ship** — a green suite is not permission, and the whole reason this skill is user-invoked only is that finished-looking code is not a release decision.

## A. Gates — every one green before anything is archived

- [ ] **A1 Clean tree, on a commit worth tagging.** The dynamic block above.
- [ ] **A2 Fast suite.** `swift test --package-path HunchCore`, under ten seconds (`08 §5`). The budget timer belongs to `hunch-swift-testing`.
- [ ] **A3 Level-B calibration, full matrix.** `§14.5` decision 5 makes it a hard gate before *any* archive, not a nightly nicety. See the section below — this is the gate that passes when it did not run.
- [ ] **A4 Simulator suite, `Prerelease` plan.** `07 B24` — the plan name is the cadence tag, capitalised.
- [ ] **A5 Source hygiene, every check in the roster.** `Scripts/check-source-hygiene.sh`. The roster and its count live in `hunch-build-and-ci/SKILL.md`; do not re-enumerate them here, and do not tick this gate against a remembered count — a run that reports fewer checks than that table lists is itself the failure. Check 10 is the one that gets counted out of existence, and it is register laundering: `HueColor(` / `AccentColor(` minted outside `Tokens`.
- [ ] **A6 Zero warnings in a Release build.** The brief's phase-8 gate. `-warnings-as-errors` is already on Release (`07 B18`) and is written **first**; any `-Wwarning <group>` exemption goes **after** it (`07 B19` — flags apply left to right; `08 §7.12` states the opposite and is wrong, per `hunch-build-and-ci`).
- [ ] **A7 Localization complete in all twelve.** No `new`/`needsReview` state, key count under budget, zero banned lexemes per locale (`§1.13`, `§12.9`) — check 8 of A5, not a package test.
- [ ] **A8 Screens reviewed as pixels.** Simulator screenshots in en, de and ar, plus the two pseudolocales (`07 B40`). The play surface must be wordless in all three (`§1.13` P1).
- [ ] **A9 Accessibility audit green.** `performAccessibilityAudit` in `HunchUITests`, `issueHandler` not blanket-returning `true` (`07 B46`) — `hunch-accessibility` owns what it asserts.

Commands, exact pass conditions and the "what a failure actually means" column: `references/release-checklist.md` §2.

## The gate that passes when it did not run

A3's suite is condition-gated, so a plain `swift test` reports green over a matrix that never executed. A skipped test is not a passing test.

```swift
// HunchCore/Tests/LadderTests/CalibrationTests.swift — the shape 08 §5 specifies.
import Foundation
import Testing

@Suite(
    "Level B calibration",
    .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"),
    .tags(.integration, .nightly),
    .timeLimit(.minutes(15))
)
struct CalibrationTests { /* the H-numbered assertions; hunch-swift-testing owns them */ }
```

```bash
# ✗ Green in ~10 s, and the entire ~9-minute matrix was silently skipped.
swift test --package-path HunchCore

# ✓ The pre-archive gate. Read the run summary and confirm the suite reports cases, not zero.
HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter CalibrationTests
```

## B. Version, archive, export

**`MARKETING_VERSION` is edited by a human in `Config/Base.xcconfig` at release time. `CURRENT_PROJECT_VERSION` is passed on the command line and never committed** (`07 B27`). `agvtool` and a `PlistBuddy` run-script phase are both wrong here — one dirties the tree from CI, the other re-runs on every incremental build (`07 B15`).

```bash
# One archive. Everything downstream comes out of it.
xcodebuild archive -project Hunch.xcodeproj -scheme Hunch \
  -destination 'generic/platform=iOS' -archivePath build/Hunch.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  CURRENT_PROJECT_VERSION="$BUILD"
```

- [ ] **B1 Build number strictly greater** than the last upload of this `MARKETING_VERSION`. App Store Connect is the authority, not your shell history.
- [ ] **B2 Export twice from the one archive** — an Ad Hoc export with thinning for the size number, an App Store export for the upload. Both plists are in `references/release-checklist.md` §3.
- [ ] **B3 Size gate.** Read `App Thinning Size Report.txt`, not the `.ipa`, the `.app` or the `.xcarchive` — all three contain things nobody downloads (`07 B44`). Compare against the brief's ceiling in `hunch-claude-code-prompt.md` `<constraints>` and against the previous release's report.
- [ ] **B4 dSYMs preserved.** They live inside the `.xcarchive`. Keep the archive somewhere durable and leave `uploadSymbols` true in the App Store export options, or a crash report from this build can never be symbolicated.

## C. Upload, then metadata

Upload with `-exportArchive` and the App Store options plist (`07 B35`) — no Apple ID password, no app-specific password, no keychain dance. Then tag the commit with the exact `MARKETING_VERSION`/`BUILD` pair that was uploaded.

**Then work `references/rejection-triggers.md` top to bottom before pressing Submit.** It is ordered by how often each one actually bites, and the first four are the ones that bite HUNCH specifically: the claims policy binding all sixty metadata units, the privacy manifest's required-reason `UserDefaults` entry, the encryption-compliance key, and the tracking key that must be *absent*.

## Where the detail lives

| Read this | When |
|---|---|
| `references/release-checklist.md` | running the procedure — every gate's exact command, its pass condition, what a failure means, both export plists, and the post-upload steps |
| `references/rejection-triggers.md` | writing or reviewing anything that goes into App Store Connect, or diagnosing a rejection or an ITMS upload error |

## Gotchas

- **A green `swift test` says nothing about A3.** `.enabled(if:)` skips are reported as successes. Check the case count, every time.
- **You cannot measure app size before archiving.** `07 B44` — so the size gate sits *after* the archive and *before* the upload. Failing it there costs an archive; discovering it after the upload costs a build number you can never reuse.
- **`HUNCH` and the four mode wordmarks ship untranslated in all twelve locales, Arabic included** (`§12.9`). A localizer who "fixes" `CFBundleDisplayName` for `ar` has broken the wordmark, not the localization.
- **Screenshots are metadata for claims purposes.** `§1.13` binds them exactly as it binds the description, and `§12.9` fixes them at zero words — a caption added to make a screenshot "clearer" is both a claims risk and a contradiction of the product.
- **`NSUserTrackingUsageDescription` must be absent, not empty.** Present-but-unused is a Guideline 5.1.2(i) rejection (`07 B38`), and this app has no network and no SDK that could pull it in (`08 §1`).
- **TestFlight blocks testers, not uploads, on Missing Compliance.** `ITSAppUsesNonExemptEncryption` is set once in the xcconfig via `INFOPLIST_KEY_*` (`07 B37`); if you are clicking a compliance prompt per build, that setting is missing.
- **The reason-code strings in a privacy manifest are the one thing `07 B36` could not verify.** Read Apple's rendered required-reason page before shipping rather than copying the code out of any document, this one included.
- **`Prerelease` is a plan name that must equal a declared tag.** A plan filtering on a tag `06 T29` never declared selects nothing and reports a green run over zero tests (`07 B24`).

## Never

- Never archive with a red gate and plan to fix it in the next build. Section B costs a build number that cannot be recovered, and section C costs a public claim.
- Never make a gate green by weakening it. Do not delete an entry from `tests.json`, do not add a banned lexeme to `DECISIONS.md` to clear check 8 without the user's explicit written exception, and do not raise the key-count budget to fit new strings.
- Never write a claim about memory, focus, intelligence, cognition, stress, sleep, ageing or any health outcome into the name, subtitle, description, keywords, what's-new, a screenshot, a review reply, or any of the eleven translations. `§1.13` is a compliance boundary with a $2 M precedent, not a tone preference.
- Never let the listing describe a business model the binary does not ship. Paid-once, no IAP, no free tier (`§1.4` P5, `§14.5` decision 1) — the words "free", "premium" and "try before you buy" are on the banned list for exactly this reason.
- Never commit a `CURRENT_PROJECT_VERSION` bump, and never run `agvtool` (`07 B27`).
- Never add a third-party dependency, a network call, an analytics or crash SDK, or a notification permission to make a release step easier. Each one is a brief violation, and the first two additionally re-open a privacy-manifest obligation this app currently satisfies by being empty.
- Never upload from a dirty tree or an untagged commit. A build you cannot rebuild is a build you cannot debug a crash report against.
- Never restate a value that lives elsewhere. The size ceiling is the brief's, the key budget and the banned lexemes are `GAME_DESIGN.md`'s, the build settings are the xcconfigs', and the gates' scripts are the build skill's. Cite the path; if it can be read in one tool call, write the tool call.
