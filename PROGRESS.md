# PROGRESS.md

Current phase, what is done, what is next, known issues. Updated at the end of every task.

## Phase

**E04 — Glyph renderer.** Complete. E01, E02, E03 complete. 30 of ~89 tasks across E01–E10.

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

**E05 — the rule grammar**: `LawNode`, the evaluator, RNF, equivalence, the `Band` type and the
lower-band index. Then E06 (generator), E07 (persistence), E08–E10 (the PROBE surface).

## Known issues

- The verdict ring's `.reject` cancel stroke renders faintly in the DEBUG gallery. The mark's
  geometry is spec-correct and the gallery's ring centre was the actual bug (fixed: the ring is
  concentric with the glyph *body*, not the canvas). Re-verify when E08 puts the ring on a real
  round — that is the first place it carries meaning rather than being a specimen.
- `check-symbols.sh` and `check-inventory.sh` still report unresolved `C.*` members and
  undeclared inventory rows for components E05–E16 have not written yet. Both are deferred out
  of CI with the epic that re-enables them named inline.

## Known issues

- `xcodebuild build -destination 'generic/platform=iOS'` fails on signing: `Config/Local.xcconfig`
  carries an empty `DEVELOPMENT_TEAM`. Simulator builds and tests are unaffected. Fill it in to
  build for a device.
- The pre-commit hook is not versioned (`.git/hooks` is outside the work tree). Documented in
  `CLAUDE.md`.
- Check 8 (String Catalog) and check 7 (play-surface text) are inert until `Modules/` exists in
  E03. Both are written and will engage without edit. **Check 7 verified live in E08·T02** by
  planting a `Text("x")` in `RoundView.swift`: it failed, and passed again once removed.
- **E08·T03, checked by eye in the DEBUG gallery.** The "THROAT — one register moves, three
  hold" section draws each attribute as four columns: the base glyph, the stepped glyph, the
  moving register's passes alone, and the held registers' passes alone. The third and fourth
  columns are complementary and neither is empty for fill, shape or pips; for hue the fourth is
  empty by construction, because hue is the ink colour of every pass. That is the renderer-side
  proof that §6.3's crossfade is separable rather than a whole-glyph fade wearing its name.
