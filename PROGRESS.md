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

## E11 — the ladder, measured

The Level-A harness plays a simulated Rasch player against the **real** serving policy and the
**real** estimator, 20,000 rounds per point, seeded and reproducible. Measured realised success
rate, against H3's 0.80 ± 0.03:

| `θ_true` | realised rate | modal band share | longest same-band run |
|---|---|---|---|
| −3.0 | 0.663 | 0.791 | 23 |
| −2.0 | 0.817 | 0.799 | 54 |
| −1.0 | 0.810 | 0.490 | 48 |
| 0.0 | 0.804 | 0.505 | 13 |
| 1.0 | 0.801 | 0.518 | 13 |
| 2.0 | 0.801 | 0.519 | 13 |
| 3.0 | 0.801 | 0.519 | 13 |
| 4.0 | 0.804 | 0.525 | 16 |

Two things worth saying plainly.

**π₀ = 0.44 works.** Across the whole servable range the composed loop — target, pressure,
jitter, quantisation, band clamps, both guards and the estimator — lands within 0.004 of 0.800.
That is the number §10.3 says is 0.75 without the centring, and it is the one number in the
design that no unit test could have established: every part can be individually right and the
composition still miss.

**The ladder is censored at both ends, and the floor is the interesting one.** Below band 1 there
is nothing easier to serve, so a player at `θ = −3` realises 0.66 and sits on band 1 for 79 % of
rounds. That is not a defect and it is not a surprise — it is §10.7's own argument for the floor
rescue, arrived at independently: *at the floor the tooling opens, because the difficulty cannot
close further*. §10.8's family-rotation claim is likewise a mid-ladder claim; both ends pin the
band and there is nothing left to rotate. Both are now named tests rather than a bound that
quietly excludes its worst case.

## E08–E12 — where the app stands

The app opens on a playable PROBE surface on both reference simulators: instrument bar with a
seven-tick par row, the seed glyph ghost-framed in the throat, the ribbon pinned to its trailing
edge, four Dial ramps with their headers and one lit cell each, the Bench handle, and three
commit keys. `swift test` is **380 core + 205 module tests in 0.4 s**, well inside the 10 s
budget, and 70 invariants in `tests.json`.

What is model-complete and asserted, per epic:

- **E08** — the round machine, the phase table as the only writer of a phase, the throat's
  single-register crossfade, the Dial, the ribbon's chain model, the 420/320 ms beat with its
  single-slot queue, the twin key and its breath, the par crossing, the spool sheet, and §6.6's
  five discoverability layers proved band-independent.
- **E09** — the Bench's two-mode layout with the evidence provably immobile, the four tile
  canvases and their marks as constructions, the gesture inventory as a lint, the palette
  ceiling, the Assay as a *slice* wired to the draft and never to the law, the machined bar, and
  two strikes with extension-identity judging.
- **E10** — the composition root, the snapshot written at t = 0 of every beat, the re-entry beat,
  the exit rules as a total function, the onboarding ledger, the elastic cap, the five nudges,
  and §6.11's twenty-nine rows accounted for exactly once.
- **E11** — the symmetric estimator, the thirteen-step policy, calibration, anti-frustration and
  anti-boredom, and the Level-A harness measuring **0.801–0.804** against H3's 0.80 ± 0.03.
- **E12** — the two-law pair guardrails, the hinge and its three triggers, the DRIFT budget,
  the lifecycle whose central row is invisible, the dead-law counterexample, and the reveal.

**Not built, and named rather than implied:** the views for the Bench's rails (the tile canvases
exist; the draft that decides which are on which rail is E09's remaining wiring), DRIFT's own
`Round`-equivalent, and every mode after DRIFT. The E10 composition root routes all three launch
routes to the opening round because the Frame is E17's and the served round is E11's serving
*layer*, which is one task short.

## E13–E17 — the four modes, the archive and the Frame

`swift test` is **467 core + 215 module tests in 0.8 s**, 72 invariants in `tests.json`, and the
app builds and runs on both reference simulators. The Frame is real: with a Codex of no pages,
PROBE is lit and DRIFT, ECHO and SIEVE wear the machined bar — §12.4's whole message, verified
on screen, with no words in it.

- **E13 ECHO** — the pool, the primer's on-screen elimination, the load table, the cast's two
  construction invariants, the scoring, the lifecycle whose `primer → casting` transition refuses
  to fire on an ambiguous strip.
- **E14 SIEVE** — the speed curve, the three-reach partition, the one-actionable-glyph invariant
  as arithmetic rather than a guard, the scoring correction, the void allowance.
- **E15 Codex** — the taxonomy, sealability derived from population, the logarithmic accretion
  arc, the extension thumbnail and its contextual ink ladder.
- **E16 Anomaly and Profile** — the UTC derivation and its low-bit band, the high-water ledger,
  the grants and their two-way isolation, the five axes, the Robbins–Monro update, and the
  geometry that makes the portrait unable to grow.
- **E17 Frame and Settings** — the route graph with its two-tap worst case, the mode gates, the
  nineteen-row settings schema with five named reset effects, and the Frame itself.

**Not built, and named rather than implied:** the remaining view layers — ECHO's tray and rail,
SIEVE's conveyor, the Codex's three screens, the Profile's card, the Settings list. Every one of
them has its model complete and asserted underneath it; what is missing is SwiftUI, and E18–E20
(localisation, accessibility, polish) have not started.

## Known issues

- The verdict ring's `.reject` cancel stroke renders faintly in the DEBUG gallery. The mark's
  geometry is spec-correct and the gallery's ring centre was the actual bug (fixed: the ring is
  concentric with the glyph *body*, not the canvas). **Resolved in E08:** the real cause was
  `arcs` treating `radiusScale` as a length, so every ring drew at about a point across.
- **Four canon corrections** are recorded in `DECISIONS.md` rather than silently applied: §6.2's
  three SE reach figures (38), the Pro Max commit bar's height (36), §12.8's Dial cell growth
  (46), and §6.2's tick-clamp band count (103). Each was found by a test that reproduced the
  design's own arithmetic and disagreed with its prose.
- `check-symbols.sh` and `check-inventory.sh` still report unresolved `C.*` members and
  undeclared inventory rows for components E05–E16 have not written yet. Both are deferred out
  of CI with the epic that re-enables them named inline.

## E11 — the ladder, measured

The Level-A harness plays a simulated Rasch player against the **real** serving policy and the
**real** estimator, 20,000 rounds per point, seeded and reproducible. Measured realised success
rate, against H3's 0.80 ± 0.03:

| `θ_true` | realised rate | modal band share | longest same-band run |
|---|---|---|---|
| −3.0 | 0.663 | 0.791 | 23 |
| −2.0 | 0.817 | 0.799 | 54 |
| −1.0 | 0.810 | 0.490 | 48 |
| 0.0 | 0.804 | 0.505 | 13 |
| 1.0 | 0.801 | 0.518 | 13 |
| 2.0 | 0.801 | 0.519 | 13 |
| 3.0 | 0.801 | 0.519 | 13 |
| 4.0 | 0.804 | 0.525 | 16 |

Two things worth saying plainly.

**π₀ = 0.44 works.** Across the whole servable range the composed loop — target, pressure,
jitter, quantisation, band clamps, both guards and the estimator — lands within 0.004 of 0.800.
That is the number §10.3 says is 0.75 without the centring, and it is the one number in the
design that no unit test could have established: every part can be individually right and the
composition still miss.

**The ladder is censored at both ends, and the floor is the interesting one.** Below band 1 there
is nothing easier to serve, so a player at `θ = −3` realises 0.66 and sits on band 1 for 79 % of
rounds. That is not a defect and it is not a surprise — it is §10.7's own argument for the floor
rescue, arrived at independently: *at the floor the tooling opens, because the difficulty cannot
close further*. §10.8's family-rotation claim is likewise a mid-ladder claim; both ends pin the
band and there is nothing left to rotate. Both are now named tests rather than a bound that
quietly excludes its worst case.

## E08–E12 — where the app stands

The app opens on a playable PROBE surface on both reference simulators: instrument bar with a
seven-tick par row, the seed glyph ghost-framed in the throat, the ribbon pinned to its trailing
edge, four Dial ramps with their headers and one lit cell each, the Bench handle, and three
commit keys. `swift test` is **380 core + 205 module tests in 0.4 s**, well inside the 10 s
budget, and 70 invariants in `tests.json`.

What is model-complete and asserted, per epic:

- **E08** — the round machine, the phase table as the only writer of a phase, the throat's
  single-register crossfade, the Dial, the ribbon's chain model, the 420/320 ms beat with its
  single-slot queue, the twin key and its breath, the par crossing, the spool sheet, and §6.6's
  five discoverability layers proved band-independent.
- **E09** — the Bench's two-mode layout with the evidence provably immobile, the four tile
  canvases and their marks as constructions, the gesture inventory as a lint, the palette
  ceiling, the Assay as a *slice* wired to the draft and never to the law, the machined bar, and
  two strikes with extension-identity judging.
- **E10** — the composition root, the snapshot written at t = 0 of every beat, the re-entry beat,
  the exit rules as a total function, the onboarding ledger, the elastic cap, the five nudges,
  and §6.11's twenty-nine rows accounted for exactly once.
- **E11** — the symmetric estimator, the thirteen-step policy, calibration, anti-frustration and
  anti-boredom, and the Level-A harness measuring **0.801–0.804** against H3's 0.80 ± 0.03.
- **E12** — the two-law pair guardrails, the hinge and its three triggers, the DRIFT budget,
  the lifecycle whose central row is invisible, the dead-law counterexample, and the reveal.

**Not built, and named rather than implied:** the views for the Bench's rails (the tile canvases
exist; the draft that decides which are on which rail is E09's remaining wiring), DRIFT's own
`Round`-equivalent, and every mode after DRIFT. The E10 composition root routes all three launch
routes to the opening round because the Frame is E17's and the served round is E11's serving
*layer*, which is one task short.

## E13–E17 — the four modes, the archive and the Frame

`swift test` is **467 core + 215 module tests in 0.8 s**, 72 invariants in `tests.json`, and the
app builds and runs on both reference simulators. The Frame is real: with a Codex of no pages,
PROBE is lit and DRIFT, ECHO and SIEVE wear the machined bar — §12.4's whole message, verified
on screen, with no words in it.

- **E13 ECHO** — the pool, the primer's on-screen elimination, the load table, the cast's two
  construction invariants, the scoring, the lifecycle whose `primer → casting` transition refuses
  to fire on an ambiguous strip.
- **E14 SIEVE** — the speed curve, the three-reach partition, the one-actionable-glyph invariant
  as arithmetic rather than a guard, the scoring correction, the void allowance.
- **E15 Codex** — the taxonomy, sealability derived from population, the logarithmic accretion
  arc, the extension thumbnail and its contextual ink ladder.
- **E16 Anomaly and Profile** — the UTC derivation and its low-bit band, the high-water ledger,
  the grants and their two-way isolation, the five axes, the Robbins–Monro update, and the
  geometry that makes the portrait unable to grow.
- **E17 Frame and Settings** — the route graph with its two-tap worst case, the mode gates, the
  nineteen-row settings schema with five named reset effects, and the Frame itself.

**Not built, and named rather than implied:** the remaining view layers — ECHO's tray and rail,
SIEVE's conveyor, the Codex's three screens, the Profile's card, the Settings list. Every one of
them has its model complete and asserted underneath it; what is missing is SwiftUI, and E18–E20
(localisation, accessibility, polish) have not started.

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
