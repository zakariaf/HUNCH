# The workflow, the test plans, and CI-versus-local

1. [`.github/workflows/ci.yml`, complete](#1-githubworkflowsciyml-complete)
2. [Why the jobs split where they do](#2-why-the-jobs-split-where-they-do)
3. [The gate ladder, in order](#3-the-gate-ladder-in-order)
4. [The three test plans and their configurations](#4-the-three-test-plans-and-their-configurations)
5. [The nightly workflow](#5-the-nightly-workflow)
6. [The ten-second timer](#6-the-ten-second-timer)
7. [Green on CI, red locally — and the reverse](#7-green-on-ci-red-locally--and-the-reverse)
8. [What is deliberately not in CI](#8-what-is-deliberately-not-in-ci)

---

## 1. `.github/workflows/ci.yml`, complete

```yaml
name: CI
on:
  pull_request:
  push: { branches: [main] }

concurrency:                            # cancels superseded runs; directly saves macOS minutes
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # Linux costs roughly a tenth of macOS (07 B32), and everything in this job is pure text.
  lint:
    runs-on: ubuntu-latest
    container: swift:6.3.3              # the toolchain ships the formatter; on Linux it is `swift format`
    steps:
      - uses: actions/checkout@v4
      - name: Format
        run: swift format lint --strict --recursive App HunchCore/Sources HunchCore/Tests Modules/Sources Modules/Tests
      - name: Source hygiene (text checks only)
        run: Scripts/check-source-hygiene.sh --fast

  test:
    runs-on: macos-26                   # 07 B28 — never macos-latest
    env:
      SIM_NAME: iPhone 16               # confirm with `xcrun simctl list devices available`
    steps:
      - uses: actions/checkout@v4
      - run: sudo xcode-select -s /Applications/Xcode_26.6.app   # 07 B29 — the image default is 26.5

      # No dependency cache: zero third-party packages means nothing to restore, and caching
      # .build is 07 B34's mtime fragility bought for nothing. There is no Package.resolved,
      # so hashFiles() on it would return "" and pin every run to one stale key.

      # ── the gate ladder, cheapest first ────────────────────────────────────
      - run: Scripts/check-source-hygiene.sh
      - run: Scripts/check-pbxproj-clean.sh Hunch.xcodeproj
      - run: .claude/skills/hunch-swift-code/scripts/check-boundary.sh --all
      - run: swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift
      - run: Scripts/check-inventory.sh          # bodies: source-hygiene.md §7.1–§7.3
      - run: Scripts/check-symbols.sh
      - run: Scripts/check-skills.sh
      - run: node .claude/skills/hunch-glyph-renderer/scripts/check-coverage-separation.js
      - run: node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js
      - name: Sigil parity fixture is current
        run: |
          node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --json \
            | diff -u HunchCore/Tests/SigilsTests/Fixtures/sigils.json - \
            || { echo "::error::sigil fixture is stale — regenerate with --json"; exit 1; }

      # 01 P23: swift test is the inner loop, so CI runs it too. No simulator, no host app.
      # Build first, so the timer measures the suite and not a cold compile.
      - name: Build HunchCore
        run: swift build --package-path HunchCore --build-tests
      - name: Fast suite, timed
        run: |
          start=$SECONDS
          swift test --package-path HunchCore
          elapsed=$(( SECONDS - start ))
          echo "fast suite: ${elapsed}s"
          if [ "$elapsed" -ge 10 ]; then
            echo "::error::fast suite took ${elapsed}s, the budget is 10s — gate the offender .nightly or make it faster"
            exit 1
          fi

      - name: Resolve simulator                       # 07 B30 — never a hardcoded name+OS pair
        id: sim
        run: |
          set -o pipefail
          udid=$(xcrun simctl list devices available --json \
            | jq -r --arg n "$SIM_NAME" '.devices | to_entries[] | select(.key | test("iOS-26"))
                     | .value[] | select(.name == $n) | .udid' | head -1)
          if [ -z "$udid" ]; then
            echo "::error::no available iOS 26 runtime for $SIM_NAME"; xcrun simctl list devices available; exit 1
          fi
          echo "udid=$udid" >> "$GITHUB_OUTPUT"

      - name: App and UI tests
        run: |
          set -o pipefail                             # 07 B31 — without it, a failing test goes green
          xcodebuild test \
            -scheme Hunch \
            -testPlan Presubmission \
            -destination "id=${{ steps.sim.outputs.udid }}" \
            -resultBundlePath TestResults.xcresult \
            -derivedDataPath DerivedData \
            CURRENT_PROJECT_VERSION=${{ github.run_number }} \
            | xcbeautify --renderer github-actions

      - if: always()                                  # 07 B33 — `get object` is deprecated
        run: xcrun xcresulttool get test-results summary --path TestResults.xcresult --compact
```

Deliberately absent, each for a stated reason:

| Not here | Why |
|---|---|
| `actions/cache` | nothing to cache — zero external dependencies, no `Package.resolved` (`07 B34`) |
| `-skipMacroValidation` | it buys trust for *package* macros; `@Observable` and `@Entry` ship with the toolchain (`07 B30a`) |
| a SwiftLint job | `03 W56` adds SwiftLint only when you have a team and want rules a formatter cannot express |
| any archive, export or upload step | `/hunch-release` owns those, and it is user-invoked so nobody ships because the code looked ready |
| `continue-on-error` anywhere | a gate that can be waived is documentation |

---

## 2. Why the jobs split where they do

- **Lint on Linux.** Formatting is a parse, not a build, so it needs no SDK. The `--fast` hygiene subset joins it because checks 1–3 and 5–7 are pure text (`07 §9.1` says so explicitly) and failing in 20 cheap seconds beats failing in four expensive minutes.
- **Everything else on macOS**, because check 4 needs `swift package describe`, check 8 needs `jq` on a `.xcstrings`, `check-tokens.swift` needs a Swift toolchain, and the fast suite's exit tests (`06 T49`) need a host platform.
- **Both runners for tests** (`01 P23`, `06 §18`). The `xcodebuild` step never runs a package test; the `swift test` step never runs a UI test. Dropping either loses a whole half of the suite.

The full script runs again in the macOS job rather than being skipped as "already done" — the Linux run only covered the text subset, and a two-second grep is not worth the reasoning about which checks already passed.

---

## 3. The gate ladder, in order

Cheapest first, so the most common failure is reported in seconds and no simulator is ever booted for a build that a grep would have rejected.

1. `check-source-hygiene.sh` — ten checks, seconds, catches the most.
2. `check-pbxproj-clean.sh` — a build setting escaped into `project.pbxproj` (`07 B6`).
3. `check-boundary.sh --all` — a `HunchCore` file imported SwiftUI or reached for a `Date()`.
4. `check-tokens.swift` — `palette.md`, `Prim.swift` and canon diverged, or a stated ratio no longer recomputes.
5. `check-inventory.sh`, `check-symbols.sh`, `check-skills.sh` — a component with no owner, a reference file citing a token spelling nobody defines, a `SKILL.md` whose frontmatter stopped parsing. **All three are written out in `source-hygiene.md` §7.1–§7.3**; they were named here for a release before they existed, which made three of these steps assertions about scripts that were not on disk.
6. `check-coverage-separation.js` and `check-sigil-distinctness.js` — the two drawing harnesses, plus the sigil parity fixture's freshness. Node, no toolchain, a second or two.
7. `swift build` then the timed `swift test` — the fast suite and its budget.
8. `xcodebuild test -testPlan Presubmission` — the simulator half.

Adding a gate means adding a step here **and** a row to `SKILL.md`'s roster. A checker that exists but is not in this list is a script nobody runs — and a step here naming a script nobody wrote is worse, because it reads as coverage.

---

## 4. The three test plans and their configurations

Three plans at the repo root, each named after the cadence tag it includes, capitalised (`07 B24`, `08 §1`). The plan name *is* the tag name, which is what keeps this file and `06-TESTING.md` in step mechanically instead of by promise.

**The split with `hunch-swift-testing`, because both skills say "test plan".** This file owns the `.xctestplan` **files** and their **configurations** — the schemes, the environment variables, the pseudolanguages, the execution order, and what CI invokes. `hunch-swift-testing/references/test-plan.md` §3 owns the **tags** and **which suites each plan selects**. Neither table repeats the other's column; "add a Nightly configuration" is here, "add a suite to Nightly" is there.

| Plan | Includes tag | Configurations | Runs |
|---|---|---|---|
| `Presubmission.xctestplan` | `.presubmission` | one: **Random** execution order (`07 B25`) | every PR |
| `Nightly.xctestplan` | `.nightly` | **Default** · **RTL** (Application Language = Right-to-Left Pseudolanguage) · **Double Length** (Double Length Pseudolanguage) · **Calibration** (`HUNCH_CALIBRATION=1` in the configuration's environment variables) | scheduled |
| `Prerelease.xctestplan` | `.prerelease` | Default + Sanitizers | before an archive, by `/hunch-release` |

For what each plan contains — which invariants, which suites, which fuzzer — read `hunch-swift-testing/references/test-plan.md` §3 rather than inferring it from the tag name.

- **The pseudolanguage configurations are how RTL and truncation coverage becomes free** (`07 B26`, `B40`). Setting Application Language by hand means doing it once and forgetting; a configuration runs the whole UI suite in both directions on every nightly. Cost is linear — two configurations is two full runs — which is exactly why they are on `Nightly` and not on the PR plan.
- **Do not invent a tag at this end.** A plan whose include-tag names something `06 T30` never declared selects nothing and reports a green run over zero tests. There is no `.smoke`.
- **A plan governs the `xcodebuild` run only.** `swift test` never reads one, so the fast suite's gating is `.enabled(if:)` in Swift (`hunch-swift-testing/references/budget.md` §3). The `Calibration` configuration's environment variable is what flips the same switch on the simulator side.
- **Schemes:** one shared umbrella scheme, `Hunch`, committed under `Hunch.xcodeproj/xcshareddata/xcschemes/` (`01 P43`). `07 B23`'s per-module schemes are deliberately skipped: `swift test --package-path HunchCore` already *is* the per-module inner loop, and a scheme per package target would be six more files to keep shared for no feedback that is not already faster.
- **The UI test target is `HunchAutomationTests`**, not `HunchUITests` — see `package-manifests.md` §3 for why the wizard's name has to give way.

```bash
xcodebuild -scheme Hunch -showTestPlans
xcodebuild -scheme Hunch test -testPlan Nightly --only-test-configuration RTL
```

The inconsistent dashes are Apple's: `-testPlan` takes one, `--only-test-configuration` takes two.

---

## 5. The nightly workflow

A second file, `.github/workflows/nightly.yml`, on `schedule:` plus `workflow_dispatch:`. Same runner pin and same `xcode-select` step; the differences are the plan, the calibration gate and the time limit.

```yaml
      - name: Calibration and integration suites
        env:
          HUNCH_CALIBRATION: "1"        # 06 §18 play 7 — the trait reads this
        run: |
          set -o pipefail
          swift test --package-path HunchCore --filter LadderTests
          xcodebuild test -scheme Hunch -testPlan Nightly \
            -destination "id=${{ steps.sim.outputs.udid }}" \
            -resultBundlePath NightlyResults.xcresult | xcbeautify --renderer github-actions
```

Level B's full matrix is roughly nine minutes (`08 §5`), which is why it is gated rather than deleted (`06 T58`). The accessibility audit (`07 §14`, `B46`) lives here too, as `XCTestCase` methods in `HunchAutomationTests` tagged `.ui .nightly`.

---

## 6. The ten-second timer

The brief's number, and the stated rationale for the two-package split. `hunch-swift-testing/references/budget.md` §1 owns the rule and the three legitimate responses to a failure; this file owns only where it runs — the `Fast suite, timed` step above.

Two details that decide whether the number means anything:

- **`swift build --build-tests` first.** Otherwise the timer measures a cold compile and reports 90 seconds on a suite that takes two.
- **`::error::` rather than a bare `exit 1`.** The annotation lands on the PR, so the person who added the slow test sees the number without opening the log.

Raising the budget is never one of the three responses.

---

## 7. Green on CI, red locally — and the reverse

| Symptom | Cause | Fix |
|---|---|---|
| tests fail on CI, pass locally | different Xcode — the image's default is 26.5, not 26.6 (`07 B29`) | the `xcode-select` step; check `xcodebuild -version` in the log |
| `Unable to find a destination` | a hardcoded `name`+`OS` pair, or the image bumped runtimes (`07 B30`) | the UDID resolution step; it prints the available list on failure |
| CI green over failing tests | a missing `set -o pipefail` before `\| xcbeautify` (`07 B31`) | the single most expensive silent bug in iOS CI; it hides for months |
| a check passes locally, fails on CI | a stale artefact locally, or a check reading a file only CI generates | run the checker on a clean clone before blaming CI |
| the build differs Debug vs CI | a value typed into the Build Settings tab beating the xcconfig (`07 B5`) | `check-pbxproj-clean.sh`, then `-showBuildSettings` |
| the hygiene phase fails only in Xcode | the script sandbox, not the check (`source-hygiene.md` §5) | read the log for `deny(1)`, fix the declared inputs — never disable sandboxing |
| a test plan reports zero tests and green | the include-tag names a tag nobody declared (`07 B24`) | the tag vocabulary is `06 T30`'s eight, declared once per package |
| `swift test` fails on `Modules` | that package is iOS-only and is not host-buildable (`package-manifests.md` §5) | do not run it; `Modules` is tested through the simulator |

---

## 8. What is deliberately not in CI

- **Archiving, export, signing, upload, the App Thinning Size Report** — `/hunch-release`, typed by the user. `07 B44`'s point stands: size cannot be measured from the `.app`, the `.xcarchive` or the `.ipa`, so a "size check" step here would report a number that means nothing.
- **Screenshot review in en/de/ar.** The brief asks a human to look at them (`<verification>`, phase 7). CI can capture them; only a person can say a screen is wrong.
- **Coverage thresholds.** `06` owns whether coverage is collected; a percentage gate rewards asserting nothing over asserting little.
- **Any retry.** A blanket retry converts a flake into a fact you no longer measure (`06 T35`, `T63`).
