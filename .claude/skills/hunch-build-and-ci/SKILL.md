---
name: hunch-build-and-ci
description: "Configures HUNCH's build and CI — xcconfig as the only home for build settings, the two package manifests, the source-hygiene greps that fail the build on a hex literal, a network symbol or a stray Date(), the swift-format delta, and the GitHub Actions workflow. Use when touching an xcconfig, Package.swift, a run-script phase, the three .xctestplan files and their configurations, or the workflow, or when a build behaves differently on CI than locally. Which tests each plan selects is the testing skill's. Archiving, signing and uploading are /hunch-release, which is user-invoked only; tell the user to run it rather than improvising the steps."
allowed-tools: Read, Grep, Glob, Bash(ls:*), Bash(grep:*), Bash(sed:*), Bash(echo:*), Bash(Scripts/*), Bash(xcodebuild:*), Bash(xcrun swift-format:*), Bash(swift build:*)
metadata:
  version: "1.0"
  owns: "Config/*.xcconfig, both Package.swift files, Scripts/check-source-hygiene.sh and the gate roster, the one run-script phase, the three .xctestplan files and their configurations, the workflow, where swift-format runs"
---

## The build surface as it exists right now

```!
r="${CLAUDE_PROJECT_DIR:-.}"
ls "$r"/Config/*.xcconfig "$r"/*.xctestplan "$r"/.swift-format "$r"/.github/workflows/*.yml 2>/dev/null | sed "s|^$r/||"
if [ -f "$r/Scripts/check-source-hygiene.sh" ]; then
  echo "--- checks live in Scripts/check-source-hygiene.sh:"; grep -E '^# +[0-9]+\.' "$r/Scripts/check-source-hygiene.sh"
else
  echo "--- NO Scripts/check-source-hygiene.sh YET — references/source-hygiene.md is the whole script, ten checks. Create it before anything else here."
fi
```

Trust that listing over anything written below it. A check that is not in it is not enforced, whatever a reference file claims.

## The rule

**Every build setting lives in `Config/*.xcconfig` and `project.pbxproj` carries none** (`07 B5`, checked by `Scripts/check-pbxproj-clean.sh`, `07 B6`). **Every rule this library states that the compiler cannot check is a numbered check in `Scripts/check-source-hygiene.sh`**, and it runs in an Xcode phase *and* in CI. **CI runs nothing you cannot run locally in one command** — if a step only exists in YAML, it is not a gate, it is a surprise.

## The gate roster — what fails a build, and who owns each check

Checks 1–4 are `07 B34a`'s; 5–8 are `08 §5`'s HUNCH additions; 9–10 are the token rule made mechanical. The script is in `references/source-hygiene.md` §2, complete and in order.

| # | Fails on | Owner |
|---|---|---|
| 1 | `Helpers.swift`, `Constants.swift`, `*+Utilities.swift` (`01 P28`) | `hunch-swift-code` |
| 2 | `record: .all` reaching `main` (`06 T51`) | `hunch-swift-testing` |
| 3 | `@unchecked Sendable`, `nonisolated(unsafe)`, `Task.detached`, `assumeIsolated` with no justifying comment (`05 R29`) | `hunch-swift-concurrency` |
| 4 | a non-test target or product naming `HunchTestSupport` (`06 T5a`) | `hunch-swift-testing` |
| 5 | `URLSession`, `Network`, `CFNetwork`, `NWConnection`, `CloudKit` anywhere | **this skill** — the brief's mandated grep |
| 6 | `Date()`, `UUID()`, `.random(`, `SystemRandomNumberGenerator` under `HunchCore/Sources/` | `hunch-swift-concurrency` |
| 7 | `Text`, `Label`, `AttributedString` in the six play-surface files outside `.accessibility*` | `hunch-accessibility` |
| 8 | `Localizable.xcstrings`: over 250 keys, any `new`/`needsReview`, a duplicate, a banned lexeme, or ≠ 12 locales | **this skill** — the brief's invariant 5 |
| 9 | a hex, `lineWidth:`, `.opacity(`, `cornerRadius:`, `duration:` literal outside `HunchCore/Sources/Tokens/` | `hunch-design-tokens` |
| 10 | `HueColor(` / `AccentColor(` minted outside `Tokens` | `hunch-design-tokens` |

Six more checkers are separate programs because they need a toolchain, a JS runtime or a parse, not a grep. CI runs them in this order — cheapest first, so the common failure is reported in seconds:

`check-source-hygiene.sh` → `check-pbxproj-clean.sh` → `hunch-swift-code/scripts/check-boundary.sh --all` → `swift hunch-design-tokens/scripts/check-tokens.swift` → `Scripts/check-inventory.sh` (every `DESIGN-SYSTEM-SCOPE.md` §3 row has exactly one reference file and one owning symbol) → `Scripts/check-symbols.sh` + `Scripts/check-skills.sh` (every cited symbol resolves; every `SKILL.md` parses) → `hunch-glyph-renderer/scripts/check-coverage-separation.js` → `hunch-sigil-drawing/scripts/check-sigil-distinctness.js` → the 10-second timer → `xcodebuild test`. All three of the middle scripts are written out in `references/source-hygiene.md` §7; wiring in `references/ci-workflow.md` §3.

## To add or change a build setting

1. **Pick the file.** Common → `Base.xcconfig`. Configuration-specific → `Debug`/`Release`. Machine-specific → `Local.xcconfig`, which is gitignored and `#include?`-d.
2. **Write it once, with `$(inherited)` if it appends** (`07 B9`), no `//` inside the value (`07 B8`), and a `HUNCH_` prefix if it is your own variable (`07 B11`).
3. **Confirm nothing shadows it** — a value typed into the Build Settings tab silently beats the xcconfig (`07 B5`): `xcodebuild -showBuildSettings -scheme Hunch | grep <NAME>`.
4. **Do not restate a default you have not verified is wrong** (`07 B7`, `B13`). Every redundant line is a line someone will later "fix".
5. **If it has a twin, change both in the same commit.** `IPHONEOS_DEPLOYMENT_TARGET` must equal `platforms: [.iOS(.v18)]` in *both* manifests; `SWIFT_VERSION` must agree with `swiftLanguageModes` (`01 P18`).

## To add a gate

1. **Can it be a compile error instead?** Distinct `HueColor`/`AccentColor` types, `dependencies:` in the manifest, a `switch` with no `default:` — all three delete a whole class of check. A grep is the third-best answer, taken only when the first two cannot reach.
2. **Can a package test see it?** Then it is `hunch-swift-testing`'s and does not belong here. Source lints exist only because source files are not in a test bundle.
3. **Append it to `Scripts/check-source-hygiene.sh`** following `references/source-hygiene.md` §3's conventions: `|| true` on every `grep`/`find`, `report` on a hit, never `grep -q … && exit 1` as the last command.
4. **Prove it fails.** Corrupt a file on purpose, run the script, restore. A check that cannot fail is worse than no check (`07 B6`).
5. **Add its row to the roster above** and its step to the workflow, and name the owning skill.

## Where the detail lives

| Read this | When |
|---|---|
| `references/xcconfig.md` | before adding, moving or debugging any build setting — all four files complete, what is deliberately absent, and the settings HUNCH sets that a stock project does not |
| `references/package-manifests.md` | before editing either `Package.swift`, adding a target, or when a package fails to resolve or build on the host |
| `references/source-hygiene.md` | writing, extending or debugging a check; wiring the Xcode run-script phase; when a sandbox denial appears |
| `references/ci-workflow.md` | editing the workflow, an `.xctestplan` file or a plan **configuration**, or when CI passes and local fails (or the reverse). Which tests a plan *selects* is `hunch-swift-testing/references/test-plan.md`'s |
| `references/swift-format.md` | setting up or auditing the formatter, adding the lint job, or after a toolchain bump |

## Gotchas

- **`SWIFT_VERSION = 6.0`, never `6`.** Enforcement is identical either way, but only `6.0` makes the settings table resolve `SWIFT_STRICT_CONCURRENCY` to `complete`, so only `6.0` reports honestly to `-showBuildSettings`, the UI and any audit you write (`07 B2`). The bare `6` you will meet everywhere online is the string to distrust.
- **`08 §7.12` contradicts itself and `07 B19` is right.** In `Config/Release.xcconfig`, write the blanket flag **first**: `OTHER_SWIFT_FLAGS = $(inherited) -warnings-as-errors -Wwarning SomeGroup`. Flags apply left to right, so a *trailing* blanket flag silently overrides an earlier exemption — which is the reasoning §7.12 gives for the opposite instruction. `B19`'s ordering is the reproduced one.
- **The hygiene run-script phase and `ENABLE_USER_SCRIPT_SANDBOXING = YES` fight, and the resolution is deliberate.** The phase declares the three source roots as inputs so the sandbox grants the read, and declares **no outputs**, so it runs on every build (`07 B15` rule 2) — the price the brief's build-phase gate costs. Never turn sandboxing off to fix a denial (`07 B14`). Full wiring and the fallback: `references/source-hygiene.md` §5.
- **There is no `Package.resolved`, so do not key a cache on it.** Zero third-party dependencies means nothing to resolve; `hashFiles('**/Package.resolved')` returns the empty string and every run then shares one permanent cache key. HUNCH's workflow has **no cache step at all** — there is no dependency graph to restore, and caching `.build` is `07 B34`'s mtime fragility for no gain.
- **`-skipMacroValidation` is not needed here** (`07 B30a`). It buys trust for *package* macros; `@Observable` and `@Entry` ship with Apple's toolchain. Adding the flag accepts a security trade for nothing.
- **A test plan governs the `xcodebuild` run only.** `swift test` never reads one, so the fast suite's nightly gating is `.enabled(if:)` in Swift, not plan membership (`hunch-swift-testing/references/budget.md` §3). Both runners run in CI (`01 P23`).
- **A plan whose include-tag names a tag nobody declared selects nothing and reports green over zero tests** (`07 B24`). The eight tags are `06 T30`'s and are declared once per *package*; plan names are the cadence tags capitalised — `Presubmission`, `Nightly`, `Prerelease`.
- **`'bundle()' is only available in macOS 12 or newer` from `Modules/` means you host-built an iOS-only package.** Do not add `.macOS(.v15)` to silence it — that promises a host build that its SwiftUI targets cannot honour. Stop running `swift test --package-path Modules`; `Modules` is tested through the simulator (`07 B22`, `08 §7.2`).
- **`xcbeautify` swallows `xcodebuild`'s exit status without `set -o pipefail`** (`07 B31`) — CI goes green on failing tests and stays that way for months.

## Never

- Never type a build setting into Xcode's Build Settings tab, and never let one land in `project.pbxproj`. There is exactly one home (`07 B5`, `B6`).
- Never add an SPM package, a CocoaPod, a build-tool plugin or `unsafeFlags` (`07 B20`). Zero dependencies is a brief constraint, not a preference, and it is what makes the workflow this short.
- Never put a formatter in a build phase (`07 B17`), and never disable `ENABLE_USER_SCRIPT_SANDBOXING` to make a script work (`07 B14`).
- Never use `macos-latest`, `xcode-select`'s default Xcode, or a hardcoded simulator `name`+`OS` pair (`07 B28`, `B29`, `B30`).
- Never pipe `xcodebuild` without `set -o pipefail`, and never parse results with the deprecated `xcresulttool get object` (`07 B31`, `B33`).
- Never weaken or delete a check to reach green, never add `continue-on-error` to a gate step, and never remove an entry from `tests.json`. (Inside the script, `|| true` on a `grep` is required and means the opposite — see `references/source-hygiene.md` §3.) A gate that can be waived is documentation.
- Never add a network call, an analytics SDK, a crash reporter or `NS*UsageDescription` key. The app requests nothing; check 5 and an empty entitlements file are what make that verifiable.
- Never copy a value out of another skill into an xcconfig, a manifest or the workflow. Cite the token, symbol or rule ID — the value has exactly one home.
- Never archive, export, upload, or touch signing or version numbers from here. That is `/hunch-release`, and it is user-invoked for a reason. **Say the slash command back to the user** — it carries `disable-model-invocation: true`, so it is absent from the model's skill listing entirely and cannot be reached any other way. "Run `/hunch-release`" is the whole correct answer to "ship this to TestFlight"; improvising the archive steps here is the wrong one.
