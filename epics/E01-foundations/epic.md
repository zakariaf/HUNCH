# E01 — Foundations, bootstrap and CI

| | |
|---|---|
| **id** | E01 |
| **title** | Foundations, bootstrap and CI |
| **branch** | `epic/E01-foundations` (after T01, which commits directly to `main`) |
| **depends on** | nothing |
| **gate** | `swift test --package-path HunchCore` green in under 10 s · `Scripts/check-source-hygiene.sh` fails on a planted `URLSession` and passes once removed · the Actions workflow runs on E01's own PR and is green · `xcodebuild -showBuildSettings` reports `SWIFT_VERSION = 6.0` and `project.pbxproj` carries zero build settings |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When E01 merges, `main` has commits, `Hunch.xcodeproj` builds an iPhone-only portrait app whose every build setting lives in `Config/*.xcconfig`, `HunchCore` is a Swift 6 package whose fast suite runs on the host in well under a second, `SplitMix64` and the day-one test utilities exist, and every rule this repo states that the compiler cannot check is a numbered gate in `Scripts/` that runs both as an Xcode build phase and in GitHub Actions. The repo documents (`CLAUDE.md`, `SPEC.md`, `DECISIONS.md`, `PROGRESS.md`) and `tests.json` exist and are wired into CI, so the next nineteen epics inherit a loop that cannot silently go green.

## Why now

Nothing else can start. `main` has **zero commits**, so no pull request can be opened against it — E01·T01 is the only task in the whole project that commits directly to the default branch, and every other epic branches from what it lands. The Actions workflow is itself created inside E01 (T07), which makes the loop self-hosting from E01's own PR onward: the workflow file is on the branch, it triggers on `pull_request`, and it gates the PR that introduces it. The two packages, the ten hygiene checks and the ten-second timer are what every later epic's gate is measured with; land them wrong and twenty epics inherit the error.

## Scope

| In | Out — and who owns it |
|---|---|
| `README.md`, `.gitignore`, `LICENSE`, root `.swift-format` committed directly to `main` | — |
| `Hunch.xcodeproj` at the repo root, `App/` buildable folder, `Config/{Base,Debug,Release}.xcconfig` | `PrivacyInfo.xcprivacy`, `AppIcon.icon`, the launch surface's art — **E20·T10, T11** |
| `HunchCore/Package.swift`, `HunchTestSupport`, the tag vocabulary | the `Modules/` package and every UI target — **E03·T06** |
| `SplitMix64` and the "randomness is a parameter" rule | `Band`, `Difficulty`, `Generator`, `Guardrail`, `Counterexample` in the same target — **E05·T06, E06** |
| `isApproximatelyEqual`, the `unimplemented` doubles, `Corpora.seed(band:index:)` | `Corpora.index` (the `LawIndex` static) — **E05·T07**; `Fixture` and the fixture trees — **E06·T10, E07·T05**; `UnimplementedPersistenceStore` — **E07·T01** |
| `Scripts/check-source-hygiene.sh` (all ten checks), `Scripts/check-pbxproj-clean.sh`, `Scripts/banned-lexemes.txt`, the one Xcode run-script phase | making checks 9–10 *able* to fail, i.e. the `Tokens/` module — **E03**; check 7's play-surface files — **E08, E09** |
| `Scripts/check-inventory.sh`, `check-symbols.sh`, `check-skills.sh` | flipping `check-inventory.sh` to `--strict` — the epic that writes the last inventory declaration (**E15**) |
| `.github/workflows/ci.yml` + `nightly.yml`, the three `.xctestplan` files, the ten-second timer | the archive, export, signing and upload steps — **`/hunch-release`, user-invoked only** |
| `CLAUDE.md`, `SPEC.md`, `DECISIONS.md`, `PROGRESS.md`, `tests.json` + its no-shrink check | every later entry in all five — the epic that earns it |

## The task list — in execution order

| # | Task | P | Size | Depends on | One line |
|---|---|---|---|---|---|
| T01 | [Bootstrap `main` with a direct commit](T01-bootstrap-main.md) | P0 | S | — | Four files on the empty default branch, so a PR becomes possible at all |
| T02 | [Xcode project, `Config/*.xcconfig` and the app shell](T02-xcode-project-and-config.md) | P0 | M | T01 | `Hunch.xcodeproj` at the root with a pbxproj carrying zero build settings |
| T03 | [`HunchCore` package skeleton](T03-hunchcore-package-skeleton.md) | P0 | M | T02 | The manifest, `HunchTestSupport`, the eight tags, no `defaultIsolation` anywhere |
| T05 | [SplitMix64](T05-splitmix64.md) | P0 | S | T03 | The seeded RNG, its finaliser, and the rule that an RNG never escapes one call tree |
| T04 | [Day-one test utilities in `HunchTestSupport`](T04-day-one-test-utilities.md) | P0 | S | T03, **T05** | `isApproximatelyEqual`, the `unimplemented` doubles, `Corpora.seed(band:index:)` |
| T06 | [Source-hygiene script and the no-network build phase](T06-source-hygiene-and-build-phase.md) | P0 | M | T02, T05 | The ten checks, the run-script phase, and a planted `URLSession` that proves check 5 fires |
| T09 | [The three library checkers](T09-library-checkers.md) | P0 | S | T01 | `check-inventory.sh`, `check-symbols.sh`, `check-skills.sh` — the skill library lints itself |
| T07 | [Actions workflow and the three test plans](T07-actions-workflow-and-test-plans.md) | P0 | M | T03, T06, T09 | `ci.yml`, `nightly.yml`, the plans, and the `START=$SECONDS` budget gate |
| T08 | [Repo documents and `tests.json`](T08-repo-documents-and-tests-json.md) | P0 | M | T01, T07 | `CLAUDE.md`, `SPEC.md`, `DECISIONS.md`, `PROGRESS.md`, `tests.json` and its no-shrink check |

Two departures from the plan's table, both deliberate and both recorded in `DECISIONS.md` (T08):

- **T05 runs before T04.** `Corpora.seed(band:index:)` *is* a `SplitMix64` derivation (`hunch-swift-testing/references/determinism.md` §2), so T04 cannot compile before T05 exists. Nothing moved between tasks; only the order did.
- **T06 was split, and the second half is T09.** The plan's T06 carried the ten source-hygiene checks *and* the three library checkers. They are different subjects — one lints Swift, one lints the skill library and the design documents — and one task file carrying both is a task file nobody executes top to bottom.

## The git workflow

**T01 is the exception, because there is nothing to branch from.** It commits directly to `main` and pushes. Do that first, alone, and confirm `main` exists on the remote before anything else.

```bash
# T01 ONLY — main has zero commits, so there is no base for a branch or a PR.
git add README.md .gitignore LICENSE .swift-format
git commit -m "E01/T01: bootstrap main with README, .gitignore, LICENSE and .swift-format"
git push -u origin main
```

Everything after T01 uses the standard loop, which every later epic uses unmodified:

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E01-foundations

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E01-foundations
gh pr create --title "E01 — Foundations, bootstrap and CI" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

`.github/pr-body.md` is written at step 3 and committed with the epic's last commit; each epic overwrites it. It states the gate, pastes the gate commands' output, and lists the `DECISIONS.md` entries the epic added.

**Do not start E02 or E03 until this PR is merged.** If a check fails, fix it on the same branch and push again. Never merge red. Never disable a check, add `continue-on-error`, or weaken a `tests.json` entry to reach green — a gate that can be waived is documentation (`hunch-build-and-ci`, *Never*).

## The gate

Every one of these must pass on the branch, and the same commands run in CI on the PR.

| # | What must be true | The command that proves it |
|---|---|---|
| 1 | The fast suite is green and inside budget | `swift build --package-path HunchCore --build-tests && start=$SECONDS && swift test --package-path HunchCore && echo $(( SECONDS - start ))s` — green, and the printed number is `< 10` |
| 2 | Check 5 can actually fail | `printf '\nlet leak = URLSession.shared\n' >> App/HunchApp.swift; Scripts/check-source-hygiene.sh; echo "exit=$?"` → names the file, `exit=1`. Then `git checkout -- App/HunchApp.swift; Scripts/check-source-hygiene.sh; echo "exit=$?"` → `Source hygiene: clean`, `exit=0` |
| 3 | The whole gate ladder is green locally | `Scripts/check-source-hygiene.sh && Scripts/check-pbxproj-clean.sh Hunch.xcodeproj && .claude/skills/hunch-swift-code/scripts/check-boundary.sh --all && Scripts/check-inventory.sh && Scripts/check-symbols.sh && Scripts/check-skills.sh` |
| 4 | The language mode is real, not typed into the UI | `xcodebuild -showBuildSettings -project Hunch.xcodeproj -target Hunch \| grep -E 'SWIFT_VERSION\|SWIFT_STRICT_CONCURRENCY\|IPHONEOS_DEPLOYMENT_TARGET\|TARGETED_DEVICE_FAMILY'` → `6.0`, `complete`, `18.0`, `1` |
| 5 | No build setting escaped into the project file | `Scripts/check-pbxproj-clean.sh Hunch.xcodeproj` → `pbxproj clean` |
| 6 | The simulator half runs | `set -o pipefail; xcodebuild test -scheme Hunch -testPlan Presubmission -destination "id=$UDID" \| xcbeautify` → green, and the run reports **more than zero** tests |
| 7 | CI is green on E01's own PR | `gh pr checks --watch` |

## Definition of done

- [ ] `main` on the remote has T01's commit and `epic/E01-foundations` is merged into it.
- [ ] All seven gate rows above pass, on the branch and in the PR's checks.
- [ ] `swift package describe --package-path HunchCore --type json` shows **no** product containing `HunchTestSupport` and **no** non-test target depending on it.
- [ ] `grep -rn 'defaultIsolation' HunchCore/Package.swift` is empty.
- [ ] Every check in `Scripts/check-source-hygiene.sh` has been *proved able to fail* — one deliberate violation each, reverted — and the proof is recorded in `PROGRESS.md`.
- [ ] `tests.json` parses, `Scripts/check-tests-json.sh` passes, and every E01-owned invariant has an entry whose `status` reflects a command that was actually run.
- [ ] `DECISIONS.md` carries the Band/Family collapse, the two-package deviation, §14.5's eight defaults, the `HunchAutomationTests` rename, the SplitMix64 gamma, the target-ceiling deviation, the check-8 diacritic gap and the licence choice.
- [ ] `PROGRESS.md` records the gate output, not the intention to produce it (`GAME_DESIGN.md` §14.6 risk 7).
- [ ] The PR is squash-merged and the branch deleted.
