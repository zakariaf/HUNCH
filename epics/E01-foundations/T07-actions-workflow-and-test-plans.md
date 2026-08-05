# T07 — Actions workflow and the three test plans

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03, T06, T09 |
| **Delivers** | Fast loop (§14.1 VERIFICATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns the workflow and the `.xctestplan` **files and configurations**. `references/ci-workflow.md` §1 is `ci.yml` complete, §3 is the gate ladder in order, §4 is the three plans and their configurations, §5 is the nightly file, §6 is the ten-second timer, §8 is what is deliberately not in CI. |
| `hunch-swift-testing` | It owns which *tests* each plan selects and the eight-tag vocabulary the include-filters name (`references/test-plan.md` §2–§3), and `references/budget.md` §1 and §3 own the ten-second rule and the three legitimate responses to a failure. Neither table repeats the other's column: "add a Nightly configuration" is the build skill's, "add a suite to Nightly" is this one's. |

## Objective

`.github/workflows/ci.yml` runs on every pull request and on `push` to `main`, executing the full gate ladder cheapest-first and failing the build if the fast suite crosses ten seconds; `.github/workflows/nightly.yml` runs the calibration cadence on a schedule. Three `.xctestplan` files exist at the repo root, each named after the cadence tag it filters on. From this commit the loop is self-hosting: E01's own PR gets checks.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B24`, `B25`, `B26`, `B28`–`B34` | Plans named after the cadence tag; Random execution order somewhere; plan configurations; `macos-26` never `macos-latest`; explicit `xcode-select`; never a hardcoded simulator name+OS pair; `set -o pipefail` before every formatter pipe; `xcresulttool get test-results`. |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P23`, `P43` | Both runners on CI, always; shared schemes and `.xctestplan` files are committed. |
| `ios-swift-guide/06-TESTING.md` | `T29`, `T30`, `T58` | The eight tags; a tag that is never declared is a compile error in a test and a *silent nothing* in a plan; slow tests are gated, never deleted. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | The four rules that defend the ten-second budget, the fourth of which is "CI times the suite and fails over budget". |
| `GAME_DESIGN.md` | §5.7 | The budget itself, and the ≈1.2 s the 10,000-law suite is allowed to spend of it. |
| `GAME_DESIGN.md` | §14.5 decision 5 | CI cadence: *fast subset on every commit, full matrix nightly and as a hard gate before any archive.* This task implements the adopted default. |

## TDD — the test comes first

A workflow's test is a run. There are two, and both must fail first.

**Step 1a — write the budget assertion so it can fail.** Before wiring anything, prove the timer is not decorative:

```bash
# A deliberate over-budget suite, added, measured, removed.
cat > HunchCore/Tests/HunchTestSupportTests/BudgetProbe.swift <<'EOF'
import Testing
@Suite("Budget probe", .tags(.unit, .presubmission))
struct BudgetProbe {
    @Test("burns eleven seconds on purpose") func burn() {
        let deadline = Date().addingTimeInterval(11)
        while Date() < deadline { _ = (0..<10_000).reduce(0, +) }
    }
}
EOF
swift build --package-path HunchCore --build-tests
start=$SECONDS; swift test --package-path HunchCore; echo "elapsed=$(( SECONDS - start ))s"
rm HunchCore/Tests/HunchTestSupportTests/BudgetProbe.swift
```

`elapsed` must print ≥ 11. Wire the timer, re-run with the probe in place, and confirm the step fails with the `::error::` annotation and a non-zero exit. Then delete the probe — it is scratch, it is never committed, and it is the only `Date()` this project ever writes inside a test directory.

**Step 1b — write the "the plan selects something" assertion.** `07 B24`'s trap is that a plan whose include-tag names a tag nobody declared selects nothing and reports **a green run over zero tests**. So the acceptance is a count, not an exit code:

```bash
set -o pipefail
xcodebuild test -scheme Hunch -testPlan Presubmission -destination "id=$UDID" \
  -resultBundlePath /tmp/TR.xcresult | xcbeautify
xcrun xcresulttool get test-results summary --path /tmp/TR.xcresult --compact | jq '.totalTestCount'
```

Before the plan exists this fails with `Unknown test plan "Presubmission"`. After it exists but with a mistyped include-tag it "passes" with `0` — which is the failure this assertion catches and an exit code never would. It must print **5** in E01 (`HunchTests`' `BuildSettingsTests`, T02).

**Step 2 — run both and watch them fail.** As above.

**Step 3 — implement** the two workflow files and the three plans.

**Step 4 — green, then refactor.** Push the branch, open the PR, and watch the checks. E01's own PR is the first real run.

## Files

| Action | Path |
|---|---|
| create | `.github/workflows/ci.yml` |
| create | `.github/workflows/nightly.yml` |
| create | `Presubmission.xctestplan` |
| create | `Nightly.xctestplan` |
| create | `Prerelease.xctestplan` |
| modify | `Hunch.xcodeproj/xcshareddata/xcschemes/Hunch.xcscheme` — convert the Test action to use test plans |

## Implementation notes

### `ci.yml`

Paste `ci-workflow.md` §1 and apply the E01 adaptations below. Everything not listed is verbatim, including the three things that get argued about: lint on Linux (roughly a tenth the cost of macOS), both runners for tests (the `xcodebuild` step never runs a package test and the `swift test` step never runs a UI test), and no cache step at all.

| # | Adaptation | Why |
|---|---|---|
| 1 | **Lint roots**: `App HunchCore/Sources HunchCore/Tests HunchTests HunchAutomationTests`. Add `Modules/Sources Modules/Tests` in E03·T06, in the same commit that creates them. | `swift format lint --recursive` on a path that does not exist is an error, and a workflow that names a directory nobody wrote is `source-hygiene.md` §8's first bullet. List **source roots, not package roots** — `--recursive HunchCore` walks into `HunchCore/.build` and lints thousands of generated files. |
| 2 | **Synthesise `Config/Local.xcconfig`** before any `xcodebuild` step: `printf 'HUNCH_BUNDLE_ID_PREFIX = com.hunch.ci\nCODE_SIGNING_ALLOWED = NO\n' > Config/Local.xcconfig` | The file is gitignored (`01 P43`) and `PRODUCT_BUNDLE_IDENTIFIER = $(HUNCH_BUNDLE_ID_PREFIX).hunch` resolves to a leading dot without it — an invalid bundle identifier, and `BuildSettingsTests.bundleIdentifierResolved` (T02) is the test that catches it. One visible step beats a magic default. |
| 3 | **Omit the "Sigil parity fixture is current" step.** | It diffs `check-sigil-distinctness.js --json` against `HunchCore/Tests/SigilsTests/Fixtures/sigils.json`, which E15·T09 creates. A gate step and its artefact land in the same commit; a step naming a file nobody wrote reads as coverage. Leave a one-line `# E15·T09 adds the sigil parity step here` comment in its place. |
| 4 | **Keep every other ladder step.** All of them are green on this repository today — verified: `check-boundary.sh --all` exits 0 with "nothing to audit yet", `check-tokens.swift` prints `clean — 17 rows` with assertion B skipped until `Prim.swift` exists, `check-coverage-separation.js` prints `PASS`, `check-sigil-distinctness.js` prints `OK - 22 sigils, 231 pairs`. | A checker that exists and is not in the ladder is a script nobody runs. |
| 5 | **`SIM_NAME`** — set it, then confirm it against the runner: the UDID step already prints `xcrun simctl list devices available` on failure, which is the whole reason it is written that way. | `07 B30`: a hardcoded `name`+`OS` pair is the single most common iOS CI breakage. The image's runtimes change monthly. |

The gate ladder's order is not cosmetic (`ci-workflow.md` §3): cheapest first, so the most common failure is reported in seconds and no simulator is ever booted for a build a grep would have rejected.

```
check-source-hygiene.sh → check-pbxproj-clean.sh → check-boundary.sh --all → check-tokens.swift
  → check-inventory.sh → check-symbols.sh → check-skills.sh
  → check-coverage-separation.js → check-sigil-distinctness.js
  → swift build --build-tests → the timed swift test → xcodebuild test -testPlan Presubmission
```

The full hygiene script runs **again** in the macOS job rather than being skipped as "already done": the Linux run only covered the `--fast` text subset, and a two-second grep is not worth reasoning about which checks already passed.

### The ten-second timer

`budget.md` §1 owns the rule; this file owns where it runs.

```yaml
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
```

Two details decide whether the number means anything:

- **`swift build --build-tests` first**, or the timer measures a cold compile and reports ninety seconds on a suite that takes two.
- **`::error::` rather than a bare `exit 1`**, so the annotation lands on the PR diff and the person who added the slow test sees the number without opening the log.

When it fails the fix is exactly one of three: gate the offender `.nightly`, find the real I/O or the real sleep, or delete the shared state that forced a `.serialized`. **Raising the budget is never one of them, and neither is deleting the test** (`06 T58`).

### The three test plans

Create them in Xcode — Product ▸ Scheme ▸ Edit Scheme ▸ Test ▸ **Convert to use Test Plans**, then add the other two — and save all three at the **repo root** beside `Hunch.xcodeproj` (`08 §1`). They are JSON and Xcode owns the file: configure them in the plan editor and let it write, rather than hand-authoring a schema you would then have to keep current. Commit all three (`01 P43`).

| Plan | Include tag | Test targets in E01 | Configurations | Runs |
|---|---|---|---|---|
| `Presubmission.xctestplan` | `.presubmission` | `HunchTests` | one, **Random** execution order (`07 B25`) | every PR |
| `Nightly.xctestplan` | `.nightly` | `HunchTests`, `HunchAutomationTests` | **Default** · **RTL** (Application Language = Right-to-Left Pseudolanguage) · **Double Length** (Double Length Pseudolanguage) · **Calibration** (`HUNCH_CALIBRATION=1` in that configuration's environment variables) | scheduled |
| `Prerelease.xctestplan` | `.prerelease` | `HunchAutomationTests` | Default + Sanitizers | before an archive, by `/hunch-release` |

Four things about that table:

- **The plan name *is* the tag name, capitalised.** That is what keeps this file and `06-TESTING.md` in step mechanically instead of by promise. There is no `.smoke` and inventing a tag at this end selects nothing.
- **Tag filters select Swift Testing tests; target membership selects XCTest bundles.** `HunchAutomationTests` is `XCTestCase` and always will be — XCUITest and `performAccessibilityAudit` have no Swift Testing path and are not getting one (`06 T43`, `08 §7.10`). It therefore joins `Nightly` and `Prerelease` by *membership*, not by tag.
- **The pseudolanguage configurations are how RTL and truncation coverage becomes free** (`07 B26`, `B40`). Cost is linear — two configurations is two full runs — which is exactly why they are on `Nightly` and not on the PR plan. They assert nothing in E01 and everything from E18 onward.
- **A plan governs the `xcodebuild` run only.** `swift test` never reads one, so the fast suite's nightly gating is `.enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1")` in Swift (E11·T11), and the `Calibration` configuration's environment variable is what flips the same switch on the simulator side.

**Schemes:** one shared umbrella scheme, `Hunch`, committed under `Hunch.xcodeproj/xcshareddata/xcschemes/`. `07 B23`'s per-module schemes are deliberately skipped — `swift test --package-path HunchCore` already *is* the per-module inner loop, and a scheme per package target would be six more files to keep shared for no feedback that is not already faster.

Verify:

```bash
xcodebuild -scheme Hunch -showTestPlans          # lists exactly three
xcodebuild -scheme Hunch test -testPlan Nightly --only-test-configuration RTL --dry-run
```

The inconsistent dashes are Apple's: `-testPlan` takes one, `--only-test-configuration` takes two.

### `nightly.yml`

`ci-workflow.md` §5. A second file on `schedule:` plus `workflow_dispatch:`, with the same runner pin and the same `xcode-select` step. The differences are the plan, the calibration gate and the time limit:

```yaml
- name: Calibration and integration suites
  env:
    HUNCH_CALIBRATION: "1"        # the .enabled(if:) trait reads this
  run: |
    set -o pipefail
    swift test --package-path HunchCore --filter LadderTests
    xcodebuild test -scheme Hunch -testPlan Nightly \
      -destination "id=${{ steps.sim.outputs.udid }}" \
      -resultBundlePath NightlyResults.xcresult | xcbeautify --renderer github-actions
```

In E01 `--filter LadderTests` matches nothing and `swift test` exits 0 over zero tests — which is correct and temporary (E11 creates `LadderTests`), but write it now so E11 adds a suite rather than a workflow. **`HUNCH_CALIBRATION` is set on nightly only**: Level B's full matrix is roughly nine minutes, which is why it is gated rather than deleted, and it is a hard gate before any archive.

`workflow_dispatch:` is not optional — a nightly you cannot trigger by hand is a nightly nobody debugs.

### What is deliberately not in CI

Do not add any of these, and do not accept a review comment asking for them (`ci-workflow.md` §8):

- **Archiving, export, signing, upload, the App Thinning Size Report** — `/hunch-release`, typed by the user. Size cannot be measured from the `.app`, the `.xcarchive` or the `.ipa`, so a "size check" step here would report a number that means nothing.
- **Screenshot review in en/de/ar** — CI can capture them; only a person can say a screen is wrong.
- **Coverage thresholds** — a percentage gate rewards asserting nothing over asserting little.
- **Any retry, and any `continue-on-error`** — a blanket retry converts a flake into a fact you no longer measure.
- **`actions/cache`** — there are zero third-party dependencies and therefore no `Package.resolved`; `hashFiles('**/Package.resolved')` returns the empty string and every run would share one permanent key.
- **`-skipMacroValidation`** — it buys trust for *package* macros; `@Observable` and `@Entry` ship with Apple's toolchain, so the flag accepts a security trade for nothing.
- **A SwiftLint job** — one author, and the hygiene script already covers the forbidden-API case.

### Opening the PR

This task is what makes step 3 of the epic's git workflow meaningful. Write `.github/pr-body.md` — the gate, the pasted output of each gate command, and the `DECISIONS.md` entries this epic added — commit it with the epic's last commit, then:

```bash
git push -u origin epic/E01-foundations
gh pr create --title "E01 — Foundations, bootstrap and CI" --body-file .github/pr-body.md
gh pr checks --watch
```

If the first run is red, read `xcrun xcresulttool get test-results summary` from the artefact rather than guessing, fix on the same branch, and push again.

## Acceptance criteria

- [ ] `.github/workflows/ci.yml` triggers on `pull_request` and on `push: { branches: [main] }`, and carries the `concurrency` group with `cancel-in-progress: true`.
- [ ] Every `xcodebuild … | xcbeautify` pipeline in both files is preceded by `set -o pipefail` — `grep -B2 'xcbeautify' .github/workflows/*.yml | grep -c 'pipefail'` equals the number of pipes. Without it CI goes green on failing tests and stays that way for months.
- [ ] Every script named by a `run:` step exists and is executable: `grep -ohE 'Scripts/[a-z-]+\.sh|\.claude/skills/[^ ]+\.(sh|swift|js)' .github/workflows/*.yml | sort -u | xargs -I{} test -x {} || echo MISSING`.
- [ ] `grep -c 'macos-latest\|continue-on-error\|skipMacroValidation\|actions/cache' .github/workflows/*.yml` is `0`.
- [ ] `grep -n 'Xcode_26.6' .github/workflows/*.yml` appears in both files (`07 B29` — the image's *default* Xcode is 26.5).
- [ ] The timed step fails, with the `::error::` annotation, when the eleven-second budget probe is present — demonstrated and recorded in `PROGRESS.md`, probe deleted.
- [ ] `xcodebuild -scheme Hunch -showTestPlans` lists exactly `Presubmission`, `Nightly`, `Prerelease`.
- [ ] `xcrun xcresulttool get test-results summary --path TestResults.xcresult --compact | jq '.totalTestCount'` after a Presubmission run prints **5**, not 0.
- [ ] `HUNCH_CALIBRATION` appears in `nightly.yml` and in `Nightly.xctestplan`'s Calibration configuration, and **nowhere in `ci.yml`**.
- [ ] `gh pr checks --watch` on E01's own PR reports every check green.

## Close the task

1. `swift test --package-path HunchCore` green locally and in the timed CI step, under 10 s.
2. **Run `/simplify`** — on YAML its useful scope is duplication between `ci.yml` and `nightly.yml` (the checkout, `xcode-select` and simulator-resolution steps). Do **not** let it factor the gate ladder into a single `run:` block: separate steps are what make the PR's check list name the failing gate.
3. **Run `/code-review`** — the findings that matter are a missing `pipefail`, a step naming a file that does not exist, and a plan whose include-tag is misspelled.
4. Commit: `git commit -m "E01/T07: ci.yml, nightly.yml and the three test plans"`

## Out of scope

- **`Scripts/check-tests-json.sh` and its CI step** — T08, which creates `tests.json`. It adds one step to the ladder created here.
- **The sigil parity fixture step** — E15·T09.
- **`Modules/Sources` and `Modules/Tests` in the lint roots, and the third input to the build phase** — E03·T06.
- **`swift test --package-path Modules`** — not a command in this repo, ever. That package is iOS-only and is tested through the simulator (`package-manifests.md` §5).
- **The accessibility audit steps** — E19·T11 adds `performAccessibilityAudit` methods to `HunchAutomationTests`, tagged into `Nightly` by target membership.
- **Any archive gate** — E20·T12 and `/hunch-release`.
- **Branch protection rules on `main`** — a repository setting, not a workflow. If enabled, enable it *after* E01 merges; T01 must be able to push directly.
