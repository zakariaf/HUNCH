# PROGRESS.md

Current phase, what is done, what is next, known issues. Updated at the end of every task.

## Phase

**E01 — Foundations, bootstrap and CI.** 8 of 9 tasks complete.

## Done

| Task | What landed | Verification |
|---|---|---|
| T01 | `README.md`, `.gitignore`, `LICENSE`, `.swift-format`; first commit on `main` | 25/25 bootstrap checks green |
| T02 | `Hunch.xcodeproj` (3 targets, synchronized folders), `Config/*.xcconfig`, `App/` shell | 5 tests green; pbxproj clean; 0 inline settings |
| T03 | `HunchCore` package, `HunchTestSupport`, the eight-tag vocabulary | 3 tests, `swift test` 5.5 s |
| T04 | `isApproximatelyEqual`, `unimplemented`, then `Corpora` | 23 tests |
| T05 | `SplitMix64` + the `HunchCore` library product | published reference vectors reproduced |
| T06 | `check-source-hygiene.sh` (10 checks), `banned-lexemes.txt`, build phase | 8 checks proven to fail; 2 false-positive controls clean |
| T07 | `ci.yml`, `nightly.yml`, three `.xctestplan`s, scheme conversion | `-testPlan Presubmission` runs 5 tests |
| T08 | `CLAUDE.md`, `SPEC.md`, `DECISIONS.md`, `PROGRESS.md`, `tests.json` | `check-tests-json.sh` green |

## Next

**T09 — the library checkers** (`check-inventory.sh`, `check-symbols.sh`, `check-skills.sh`),
then E02.

## Known issues

- `xcodebuild build -destination 'generic/platform=iOS'` fails on signing: `Config/Local.xcconfig`
  carries an empty `DEVELOPMENT_TEAM`. Simulator builds and tests are unaffected. Fill it in to
  build for a device.
- The pre-commit hook is not versioned (`.git/hooks` is outside the work tree). Documented in
  `CLAUDE.md`.
- Check 8 (String Catalog) and check 7 (play-surface text) are inert until `Modules/` exists in
  E03. Both are written and will engage without edit.
