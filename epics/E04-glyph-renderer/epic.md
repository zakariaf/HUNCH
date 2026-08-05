# E04 — Glyph renderer and the shared marks

| | |
|---|---|
| **id** | E04 |
| **title** | Glyph renderer and the shared marks |
| **branch** | `epic/E04-glyph-renderer` |
| **depends on** | E02 (Glyph, Deck, the four nested enums) · E03 (`Tokens`, `RenderEnv`, `Palette`, `C`, the `HunchUI` target and the SwiftUI adapter) |
| **gate** | All 256 glyphs render as pairwise-distinct greyscale rasters at 44 pt @2× with the shipped constant `T` measured and recorded in `DECISIONS.md`; a palette substitution moves no geometry for all 256; the DEBUG snapshot gallery renders every component × state × three themes with no literal in view code |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, the deck is **visible**. `GlyphShape` and `GlyphRenderer` turn `(glyph, side, RenderEnv)` into a drawing whose four registers — silhouette, contour pips, interior texture, index stroke — are spatially disjoint and readable with the other three removed, at every size the app ships and in all three themes. §13.5.1's proof stops being an assertion: all 256 are rasterised, converted to a single-ink coverage mask, and the minimum pairwise ink difference over 32,640 pairs is **measured**, giving the constant `T` that the GDD asserts as shipped and never states. Alongside it, the seven idioms every other screen reuses — verdict ring, ghost frame, machined bar, link arc and return elbow, cancel hatch, tick row, arc meter — each get exactly one owning `public static func draw` under `Modules/Sources/HunchUI/Marks/`, recorded in `SPEC.md` and defended by two greps in `check-source-hygiene.sh`. And the DEBUG snapshot gallery exists: one scrolling screen that draws everything built so far × every state × three themes × {normal, Bold Text, Reduce Motion} plus greyscale, which is the visual-regression corpus for every epic after this one.

## Why now

Nothing has been rendered yet. `DESIGN-SYSTEM-SCOPE.md` §2(c) names that as the sharpest gap in the design — §13.5.1's `T` is "falsifiable in form, undetermined in fact, and choosing it requires rendering all 256" — and every drawing task from E08 onward composes a glyph or one of the seven marks. E08's throat, Dial ramps and ribbon tiles are glyphs in boxes; E09's Bench, Assay and Seal are marks in rails; E12–E14's three modes redraw the same vocabulary at 36, 44, 52 and 72 pt; E15's Codex draws it at 44 and 220. If the renderer arrives after any of them, the mark gets drawn twice and the two copies diverge — which is exactly the failure `hunch-shared-marks` exists to prevent and exactly what §2(g) records as already having happened in the GDD (the machined bar specified twice, the ghost frame in four places, with no statement of which file draws it).

It sits after E02 and E03 because it needs `Glyph`, `Deck` and the four nested enums to draw, and `RenderEnv`, `Palette`, `StrokeWeight` and the `C` namespace to resolve every value it draws with. It sits before E08 because the play surface is thin over it.

## Scope

| In | Out — and who owns it |
|---|---|
| `GlyphShape` — the silhouette as a `SwiftUI.Shape`, reusable as a clip and a mask | `Glyph`, `Deck`, `Glyph.Shape`/`.Fill`/`.Pips`/`.Hue` themselves — **E02·T01–T02** |
| `GlyphRenderer` — the four-pass draw list; `GlyphCanvas` — the picture view with its bleed | `Prim`, `Palette`, `RenderEnv`, `StrokeWeight`, `Space`/`Radius`/`Opacity`, `Dur`/`Easing`, the `RGB8 → Color` adapter — **E03·T01–T06** |
| Contour pips, the knockout ring, progressive N→E→S→W accretion | Ramp cells, ribbon tiles, ECHO tray cells, Assay cells — the boxes a glyph sits *in* — **E08, E09, E13** (`hunch-bench-instruments`) |
| Fill textures and the measured ink ladder | The Codex extension thumbnail's four ink densities, which reuse the fill ladder as a *projection*, not as a glyph — **E15·T03** |
| The index stroke and its High Contrast substitution | The full §13.11 High Contrast sweep across all 18 screens and its 9.7 : 1 audit — **E19·T09** |
| Size regimes, bloom passes A and B, `BloomedRegion`, the exclusion matrix | Wiring a bloom layer into the throat / ribbon / SIEVE tail regions on a real screen — **E08·T03, E08·T05, E14·T02** |
| The two §13.5.1 tests and the measurement of `T` | Reusing `T` as a ratio for the sigil set — **E15·T09** (`hunch-sigil-drawing`) |
| The seven shared marks, one owning function each, plus `C.VerdictRing`…`C.ArcMeter` | Every *composition* of them: the Seal, the Bench rails, the par row on a screen, the shelf plate, the Anomaly ribbon — **E08, E09, E15, E16, E17** |
| The mark ownership table in `SPEC.md` and hygiene checks 11–14 | The rest of `check-source-hygiene.sh` (checks 1–10) — **E01·T06, E03·T06** |
| The DEBUG snapshot gallery and its registry | Populating gallery rows for components that do not exist yet — each later epic adds its own row as it builds it |
| Reduce Motion / Reduce Transparency / Bold Text / High Contrast *as inputs to a drawing* | The animations themselves, their durations, their substitutions and their cue points — **E08·T06, E09·T10, E09·T12, E20** (`hunch-motion-and-feedback`) |
| The RTL rule for glyphs (they never mirror) and for the two marks that do | Chrome mirroring, the String Catalog, the locale override — **E18** |
| — | VoiceOver labels for the hosts that own a glyph — **E19·T01–T02**. A glyph is `.accessibilityHidden(true)` here and that is the whole of this epic's accessibility surface for it. |

## The task list

Execute in this order. Each task ends with `/simplify`, then `/code-review`, then one commit.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [GlyphShape — the silhouette](T01-glyphshape-the-silhouette.md) | P0 | M | — | Regular polygons inscribed in `R = 0.37·S` at conventional orientation, miter joins and zero radius always, in the screen frame §13.5 has to be read in |
| T02 | [Contour pips](T02-contour-pips.md) | P0 | M | T01 | Node `k` where the ray from `bodyCentre` meets the silhouette, filled N→E→S→W, with the 1 pt `ground` knockout ring; pip accretion is game state and never mirrors |
| T03 | [Fill textures](T03-fill-textures.md) | P0 | M | T01 | Hollow / dotted / striped / solid clipped to the silhouette inset `1.5 × bodyWeight`, with the ink ladder verified by rasterisation at 24, 44, 96 and 220 pt |
| T04 | [The index stroke](T04-the-index-stroke.md) | P0 | S | T01 | One `body`-weight stroke at four rotations, never thinning with the silhouette, never mirroring, with High Contrast substituting the longer length |
| T05 | [GlyphCanvas, size regimes and bloom](T05-glyphcanvas-size-regimes-and-bloom.md) | P1 | M | T02, T03, T04 | The four passes in one `Canvas`, the 48 pt regime step, the double stroke, one blur layer per glyph-bearing *region*, and the exclusion matrix |
| T06 | [Triple-encoding proof and the constant T](T06-triple-encoding-proof-and-t.md) | P0 | M | T05 | Render all 256 at 44 pt @2×, measure the pairwise floor over six environments, ratify `T`, record it in `DECISIONS.md` and `tests.json` |
| T07 | [Shared marks, part 1](T07-shared-marks-part-1.md) | P0 | M | T01 | Verdict ring in all seven states, ghost frame, machined bar — one owning function each, plus the ownership table and hygiene checks 11–12 |
| T08 | [Shared marks, part 2](T08-shared-marks-part-2.md) | P0 | M | T07 | Link arc and return elbow, cancel hatch, tick row, arc meter — the other four owners, closing §2(g) |
| T09 | [DEBUG snapshot gallery](T09-debug-snapshot-gallery.md) | P1 | M | T06, T08 | One scrolling DEBUG screen: every built component × every state × three themes × {normal, Bold Text, Reduce Motion} plus greyscale, with a registry that makes a later epic's omission a test failure |

`T07` depends only on `T01` and may be worked in parallel with `T02`–`T06` if you are splitting attention; the commit order above is still the order the branch history should read in.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E04-glyph-renderer

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E04-glyph-renderer
gh pr create --title "E04 — Glyph renderer and the shared marks" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

Update `.github/pr-body.md` with this epic's summary — the gate results, the measured value of `T` and the six-environment floor table — before step 3.

**Do not start the next epic until this PR is merged.** If a check fails, fix it on the same branch and push again. Never merge red, and never disable, weaken or `--filter` around a check to get green — `T` in particular is never lowered to make a test pass; a failure means the geometry changed (`hunch-glyph-renderer`, Never).

## The gate

Every one of these must be true, and each names the command that proves it.

| # | Must be true | Command |
|---|---|---|
| 1 | The fast suite is green and still under 10 s with E04's arithmetic suites added | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | All 256 glyphs are pairwise distinct at 44 pt @2× in the worst environment (High Contrast + Bold Text) | `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -only-testing:HunchUITests/DeckSeparationTests` |
| 3 | The same holds in all six environments of `triple-encoding-proof.md` §4 | the same command with `-testPlan Nightly` |
| 4 | `T` is measured, ratified and recorded | `grep -n 'minimumPairwiseInkDifference' HunchCore/Sources/Tokens/C.swift DECISIONS.md` returns the value and the six measured floors |
| 5 | A palette substitution moves no geometry for all 256 | `-only-testing:HunchUITests/ColourIsAnOutputSubstitutionTests` |
| 6 | Every one of the seven marks has exactly one declaration and no hand-rolled copy | `bash Scripts/check-source-hygiene.sh` (checks 11 and 12) |
| 7 | No literal in any view or mark file | `bash Scripts/check-source-hygiene.sh` (checks 9 and 10), and a deliberately planted `lineWidth: 3` in `Marks/TickRow.swift` fails it |
| 8 | The gallery draws every built row × every state × 3 themes × {normal, Bold Text, Reduce Motion} + greyscale, and every unbuilt §3 row is explicitly claimed by a later epic | `-only-testing:HunchUITests/GalleryCoverageTests`, then launch the DEBUG build and page the gallery |
| 9 | `tests.json` carries §13.12 items 1 and 2 as passing entries | `grep -n '13.12' tests.json` |

## Definition of done

- [ ] Nine tasks committed, each with `/simplify` and `/code-review` run and their findings resolved.
- [ ] `Modules/Sources/HunchUI/` holds `GlyphShape.swift`, `GlyphCanvas.swift`, `BloomedRegion.swift`, `Marks/` with exactly seven files, and `DebugGallery/`.
- [ ] `HunchCore/Sources/Tokens/C.swift` holds the full `C.Glyph` member list and the seven `C.<Mark>` namespaces, with no colour, opacity or duration in any of them.
- [ ] The nine gate rows above all pass, with the commands run and their output pasted into `.github/pr-body.md`.
- [ ] `DECISIONS.md` records: the y-down reading of §13.5 (T01), the inset-versus-interior coverage ruling (T03), the blur-radius calibration against the mockup (T05), and `T` with its six-environment floor table (T06).
- [ ] `SPEC.md` carries the drawing-ownership table: seven marks, seven files, seven symbols.
- [ ] `PROGRESS.md` records the epic and `tests.json` carries §13.12 items 1 and 2.
- [ ] The PR is green on every check and squash-merged; `epic/E04-glyph-renderer` is deleted.
