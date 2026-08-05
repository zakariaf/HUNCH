# `Config/*.xcconfig` — the only home for a build setting

1. [The four files](#1-the-four-files)
2. [`Base.xcconfig`, complete](#2-basexcconfig-complete)
3. [`Debug`, `Release`, `Local`](#3-debug-release-local)
4. [What is deliberately absent, and why each absence is a decision](#4-what-is-deliberately-absent-and-why-each-absence-is-a-decision)
5. [Settings whose spelling you must confirm before writing](#5-settings-whose-spelling-you-must-confirm-before-writing)
6. [The three twins that must change together](#6-the-three-twins-that-must-change-together)
7. [Verifying a setting actually took](#7-verifying-a-setting-actually-took)
8. [`Info.plist`: there is none](#8-infoplist-there-is-none)

---

## 1. The four files

```text
Config/                     # outside App/ so an .xcconfig can never be swept into the
  Base.xcconfig             # buildable folder and shipped as a resource (01 P38, 07 B10)
  Debug.xcconfig            # #include "Base.xcconfig"
  Release.xcconfig          # #include "Base.xcconfig"
  Local.xcconfig            # gitignored; #include? "Local.xcconfig" from Base (01 P43)
```

`Base` is set as the **project**-level configuration file; `Debug` and `Release` are set on the **target** for their respective configurations. Nothing is typed into the Build Settings tab, because target-level tab values beat the target xcconfig and produce a `-Onone` release nobody can explain (`07 B5`). `Scripts/check-pbxproj-clean.sh` (`07 B6`) is what makes that mechanical rather than a promise.

**These flags govern `App/` only.** The app target is five files (`08 §1`), so its Swift settings are nearly free — the two packages are governed by `swiftSettings` in their manifests, and `01 P18` requires the two halves to agree. Change `SWIFT_VERSION` here and you owe `swiftLanguageModes` in both manifests in the same commit.

---

## 2. `Base.xcconfig`, complete

```text
// Config/Base.xcconfig — every build setting HUNCH sets, except the per-configuration deltas.
#include? "Local.xcconfig"                  // optional include: no error when absent

// ── Language ─────────────────────────────────────────────────────────────────
SWIFT_VERSION = 6.0                         // 07 B2 — the ".0" is load-bearing
SWIFT_APPROACHABLE_CONCURRENCY = YES        // 07 B4 — five upcoming-feature flags in one switch
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor   // App/ only; packages decide per target (01 P17, 08 §4)
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES              // 03 W43 names the price
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES     // 07 B7b names the price
SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT = YES  // 07 B7a names the price

// ── Platform ─────────────────────────────────────────────────────────────────
// 18.0 is not the guide's default choice — Synchronization/Atomic is iOS 18+, and VoiceBank
// needs it (08 §7.7). Must equal platforms: [.iOS(.v18)] in BOTH manifests.
IPHONEOS_DEPLOYMENT_TARGET = 18.0
TARGETED_DEVICE_FAMILY = 1                  // iPhone only. This is the SETTING; UIDeviceFamily is
                                            // the plist key it generates — writing that name does nothing.
INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait

// ── Product ──────────────────────────────────────────────────────────────────
PRODUCT_NAME = Hunch
PRODUCT_BUNDLE_IDENTIFIER = $(HUNCH_BUNDLE_ID_PREFIX).hunch   // HUNCH_ prefix per 07 B11
MARKETING_VERSION = 0.1.0                   // 07 B27 — a human bumps this at release time
CURRENT_PROJECT_VERSION = 1                 // 07 B27 — CI overrides it on the command line

// ── Compliance ───────────────────────────────────────────────────────────────
// 07 B37. Omit it and every TestFlight build stalls in "Missing Compliance" until someone
// clicks through, per build. NO is truthful: HUNCH ships no cryptography and makes no
// network calls at all.
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO

// ── Localization ─────────────────────────────────────────────────────────────
LOCALIZATION_PREFERS_STRING_CATALOGS = YES  // the 26.6 template already writes this; stated
                                            // because the catalog is a brief requirement (07 §12)

// ── Build hygiene ────────────────────────────────────────────────────────────
ENABLE_USER_SCRIPT_SANDBOXING = YES         // 07 B14 — stays on; see source-hygiene.md §5
GENERATE_INFOPLIST_FILE = YES               // 01 P30 — no Info.plist file exists; see §8
```

Nothing here is a guess about defaults. If a line is not in that file, §4 says why.

---

## 3. `Debug`, `Release`, `Local`

```text
// Config/Debug.xcconfig
#include "Base.xcconfig"

SWIFT_OPTIMIZATION_LEVEL = -Onone
ONLY_ACTIVE_ARCH = YES                      // roughly halves debug build time
ENABLE_TESTABILITY = YES                    // @testable import — HUNCH's tests do not use it
                                            // (06 T4), but previews and the debugger want it
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEBUG   // gates the snapshot gallery, scope §4.4
```

```text
// Config/Release.xcconfig
#include "Base.xcconfig"

// 07 B12 — the Swift default is -O, not -Os; -Osize is the lever for the 15 MB budget.
// Measure band-8 generation on a real device before keeping it: B12 says measure your
// hottest path, and here that is Generator + LawIndex, not drawing.
SWIFT_OPTIMIZATION_LEVEL = -Osize
SWIFT_COMPILATION_MODE = wholemodule
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_NS_ASSERTIONS = NO

// 07 B19 — blanket flag FIRST, targeted exemptions after. Flags apply left to right, so a
// trailing -warnings-as-errors silently overrides an earlier -Wwarning. 08 §7.12 states the
// opposite ordering while giving this exact reasoning; B19 is the reproduced one.
OTHER_SWIFT_FLAGS = $(inherited) -warnings-as-errors -Werror UnknownWarningGroup
```

`-Werror UnknownWarningGroup` is `07 B19`'s free win: a typo in a future `-Wwarning` group name is otherwise accepted silently, and the exemption you thought you wrote never existed.

The equivalent single-file spelling is `OTHER_SWIFT_FLAGS[config=Release]` in `Base` (`07 B7`). Either is correct; `08 §1` puts it in `Release.xcconfig`, so it lives there and not in both.

```text
// Config/Local.xcconfig — gitignored (01 P43 commits every xcconfig EXCEPT this one)
DEVELOPMENT_TEAM = ABCDE12345
CODE_SIGN_STYLE = Automatic
HUNCH_BUNDLE_ID_PREFIX = com.yourname
```

A team ID in a committed file is the usual reason a fresh clone cannot build on someone else's machine. Keep signing here.

---

## 4. What is deliberately absent, and why each absence is a decision

| Not set | Why |
|---|---|
| `SWIFT_STRICT_CONCURRENCY` | At `SWIFT_VERSION = 6.0` it already resolves to `complete` (`07 B2`). Restating it is a line someone will later "fix" to something weaker. |
| `DEAD_CODE_STRIPPING` | Resolves to `YES` for an app target regardless of the spec default (`07 B13`). Confirm on your own project: `xcodebuild -showBuildSettings -scheme Hunch \| grep DEAD_CODE`. |
| Any `INFOPLIST_KEY_NS*UsageDescription` | The app requests no permission of any kind (`08 §1`). An unused usage-description string is a reviewer question you cannot answer. |
| `NSAppTransportSecurity`, any ATS key | There is no networking to configure. Check 5 of the hygiene script is what makes that verifiable. |
| `INFOPLIST_FILE` | No custom plist key exists, so `01 P30`'s carve-out does not apply. See §8. |
| `SWIFT_UPCOMING_FEATURE_*` beyond the three | The other two `MIGRATE`-able features (`InferIsolatedConformances`, `NonisolatedNonsendingByDefault`) are already on via `SWIFT_APPROACHABLE_CONCURRENCY` (`07 B4`). |
| Anything for a formatter or linter | `swift-format` needs no build setting and no build phase (`07 B17`). See `swift-format.md`. |
| `VERSIONING_SYSTEM` | `agvtool` is not used; `CURRENT_PROJECT_VERSION` is injected on the command line (`07 B27`). |

---

## 5. Settings whose spelling you must confirm before writing

Two settings HUNCH needs have names this skill will not assert from memory, because a wrong `INFOPLIST_KEY_*` name is **silently ignored** — the worst failure mode there is (`07 B8`).

- **The launch screen.** HUNCH ships a launch colour only (`08 §1`). The generated-plist family is `INFOPLIST_KEY_UILaunchScreen_*`.
- **String Catalog symbol generation, which must stay OFF** (`01 P34`, `08 §7.11`). `Loc` is the hand-written accessor `§12.9` requires anyway, so generated symbols buy nothing and break `swift build` inside a package.

Read the real names before writing either:

```bash
xcodebuild -showBuildSettings -project Hunch.xcodeproj -target Hunch | grep -i 'LAUNCH\|STRING_CATALOG'
```

Then confirm the value landed by reading the generated plist out of the build products, not by reading the xcconfig back.

---

## 6. The three twins that must change together

| This | Must equal | Rule |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET = 18.0` | `platforms: [.iOS(.v18)]` in `HunchCore/Package.swift` **and** `Modules/Package.swift` | `01 §5b`, `07 B7` |
| `SWIFT_VERSION = 6.0` | `swiftLanguageModes: [.v6]` in both manifests | `01 P18` |
| `MARKETING_VERSION` | the tag and the `PROGRESS.md` entry at release | `07 B27` |

A repo where the app is Swift 5 mode and a package is Swift 6 mode passes CI and fails on the next file you move between them.

---

## 7. Verifying a setting actually took

```bash
# What the build system will really use, after all five precedence layers.
xcodebuild -showBuildSettings -scheme Hunch -configuration Release | grep SWIFT_OPTIMIZATION

# Nothing shadows the xcconfig from the pbxproj.
Scripts/check-pbxproj-clean.sh Hunch.xcodeproj

# An xcconfig is not a member of any target (07 B10) — check Target Membership in the File
# Inspector after adding one, or grep the pbxproj for it appearing in a Sources/Resources phase.
grep -n 'xcconfig' Hunch.xcodeproj/project.pbxproj | grep -v baseConfigurationReference
```

Precedence, lowest to highest (`07 B5`): platform defaults → project xcconfig → project build settings → target xcconfig → target build settings. Only the first and third-from-last exist in this repo, by construction.

---

## 8. `Info.plist`: there is none

`01 P30` — a new project should have no `Info.plist`, and HUNCH keeps that. Every key it needs is one Apple already knows about (`ITSAppUsesNonExemptEncryption`, the orientation list, the launch screen), so `INFOPLIST_KEY_*` covers all of them and `GENERATE_INFOPLIST_FILE = YES` synthesises the file at build time.

`07 B8`'s carve-out — a custom key needs a real four-line plist, because `INFOPLIST_KEY_<anything Apple does not know>` is silently dropped — **does not apply here**, and it is worth knowing why: the carve-out exists for runtime configuration like an API host, and HUNCH has no runtime configuration because it has no network and no remote anything. If you find yourself wanting a custom key, the value almost certainly belongs in Swift as a token or a `HunchCore` constant.

`PrivacyInfo.xcprivacy` is a **separate file** from `Info.plist` and does exist, at `App/PrivacyInfo.xcprivacy` (`01 P32`, `07 B36`). Its contents — the `UserDefaults` required-reason declaration and the no-collection, no-tracking claims — belong to `/hunch-release`, which owns the pre-archive checklist and is user-invoked only. This skill only guarantees it is in the app bundle root and in the target.
