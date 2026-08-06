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

## E08 — the PROBE play surface, run on two simulators

Gate row 9, run on **iPhone SE (3rd gen)** and **iPhone 16 Pro Max**, `Debug`, light appearance.
The app now opens directly on one round of §12.5's fixed opening law (`shape ∈ {triangle}`,
seed `glyphID` 22), which is what E08 built; E10·T01 replaces that with the run frame.

Verified by eye, both devices: the instrument bar's par row centred in its slot with 7 ticks at
band 1; the throat's seed glyph at 96 / 128 pt inside its dashed ghost frame with the backward
chevron; the ribbon pinned to its trailing edge; the four Dial ramps in canonical order with
their headers and one lit cell each; the three commit keys inside the commit bar. On a seeded
eight-probe transcript (a temporary harness, reverted in the same session): the chain's link
arcs, the brass admit rings and the cold broken reject rings, the par row inverted past par and
the cap row emptying below it.

**Four defects found by putting the components on a live surface, all fixed here:**

1. **Every verdict ring in the game drew at about one point across.** `VerdictRing.arcs` read
   `Ring.radiusScale` as an absolute radius instead of as a multiple of the body radius. This is
   what E04's note below called "renders faintly" — it was not faint, it was a dot at the glyph's
   centre. Now pinned by `VerdictRingGeometryTests`, which asserts the drawn radius of every
   state and that none is under 4 pt.
2. **A settled admit ring at 1.00 R is invisible on a circle glyph**, because `GlyphShape` draws
   the silhouette at exactly that radius. §13.7.4 already names both settled radii — 1.18 R
   closed, 1.00 R broken — and they are now the settled radii in every motion mode.
3. **The regions drifted up the screen by the top safe-area inset on the large device.**
   `.ignoresSafeArea()` inside the `GeometryReader` makes the proxy report zero insets; outside
   it, the proxy reports the full height with a zero *top* inset and a real *bottom* one. A plain
   reader plus one `- safeTop` at the placement site is deterministic on both devices.
4. **A `hollow` fill cell drew nothing**, and a commit key could grow past its own region.

**Not verified by hand:** the tap-through itself — composing on the Dial, pressing PROBE and
watching the tile land — because the play surface carries no text and no accessibility
identifiers yet, so there is nothing for a UI test to address and no way to drive a tap from
`simctl`. Every step of that path is covered by the unit suites (`DialTests`, `RoundTests`,
`InputGateTests`, `VerdictCueTests`, `SpoolSheetTests`). E19·T02 adds the identifiers and
E10·T03 the end-to-end UI test; this row is finished there, not here.

## Known issues

- The verdict ring's `.reject` cancel stroke renders faintly in the DEBUG gallery. The mark's
  geometry is spec-correct and the gallery's ring centre was the actual bug (fixed: the ring is
  concentric with the glyph *body*, not the canvas). **Resolved in E08:** the real cause was
  `arcs` treating `radiusScale` as a length, so every ring drew at about a point across.
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
