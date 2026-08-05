# E03 — Design tokens and RenderEnv

| | |
|---|---|
| **id** | E03 |
| **title** | Design tokens and RenderEnv |
| **branch** | `epic/E03-tokens` |
| **depends on** | E01 (bootstrap, `HunchCore` package, hygiene script, CI workflow) |
| **gate** | Every §13.2 contrast ratio recomputed from the hex by WCAG 2.1 relative luminance matches `palette.md` §1 to 2 dp in all three themes · the High Contrast state-bearing floor clears 9.7 : 1 and the primary pair is exactly 21.00 : 1 · the resolution-order test proves `3.0 → 3.75 → 4.25` and rejects `4.375` · `Scripts/check-source-hygiene.sh` exits 1 on a hex literal planted outside `HunchCore/Sources/Tokens/` |
| **tasks** | 6 |
| **status** | not started |

---

## Goal

When this epic merges, every colour, stroke weight, space step, radius, type role, opacity and
duration in HUNCH has exactly one home — `HunchCore/Sources/Tokens/` — and that home is a
platform-free, host-testable SwiftPM target with no SwiftUI in it. Three things exist that did not
before: **the register split as a type** (`AccentColor` and `HueColor` are distinct structs whose
initialisers are internal to the module, so `accent.*` reaching a glyph body is a compile error
rather than a review note); **`RenderEnv`**, the seven-axis record that every L1 and L2 accessor is a
function of, carrying the ruling the GDD never states — Bold Text multiplies ×1.25 first, High
Contrast adds a flat +0.5 pt last, and Dynamic Type is not in that chain at all; and **the
enforcement**, a grep that fails the build on a literal outside `Tokens/` plus a test suite that
recomputes every published contrast ratio from its own hex instead of quoting it.

## Why now

E03 sits at position 3, pulled forward from §14.3's phase 2 ordering, for two reasons that are both
about *cost of being late*.

- **Every drawing task in the project cites it.** E04's glyph renderer resolves `env.weight(.body)`
  before it strokes anything; E08's play surface, E09's Bench, E15's Codex and E16's Profile all
  read `C.<component>` members. A literal written into a `Canvas` before the token layer exists is
  a literal that has to be found again later, and §2(a) of `design/DESIGN-SYSTEM-SCOPE.md` is the
  list of the ones that already got away.
- **Register segregation must be structural before the first `Canvas` compiles.** Making
  `GlyphCanvas.draw` take a `HueColor` is free on the day the function is written and a
  refactor on every day after it. E04·T01 is the first function that takes one.

It unblocks **E04** (glyph renderer and shared marks) directly, and is a hard prerequisite for
E08, E09, E15, E16, E17·T06, E19·T06/T08/T09 and E20·T09. It also creates the `Modules` package and
its first target, which is what E10·T01's composition root will be added to.

## Scope

| In | Out — and who owns it instead |
|---|---|
| L0 `Prim`: every hex in the app, the three scalar constants, Okabe–Ito verbatim | — |
| L1 colour (`Palette`), weight (`StrokeWeight`), length/radius/opacity (`Space`), type (`TypeRole`), time (`Dur`, `Easing`) | — |
| `AccentColor` / `HueColor` as distinct types with module-internal initialisers | Applying them to a drawing: **E04** (glyph), **E04·T07–T08** (shared marks), **E09** (Bench) |
| `RenderEnv`: the seven axes, the resolution order, the nine derived predicates | Reading the system flags that fill it: **E10·T01** wires `RenderEnvReader` into the composition root; **E17·T06** wires the Settings theme picker to `ThemePreference` |
| `C.<component>` — one namespace per row of `DESIGN-SYSTEM-SCOPE.md` §3, plus the §2(a) scattered-literal inventory | Every other L2 member. `C.Glyph.pitch/pipRadius/bleed` → **E04**; `C.Throat.*`, `C.Ramp` cell rects, `C.Seal.railPulse`, `C.Assay.litInk` → **E08/E09**; `C.Key.rect`, `C.ShelfPlate.*` → **E15/E17**; `C.Reveal.lawGhostInk`, `C.Ribbon.revealBeat1Ink` → **E09·T10** |
| The `Modules` package, the `HunchUI` target, the ~30-line SwiftUI adapter, `Typography.swift` | Every other `HunchUI` file. `GlyphShape`/`GlyphCanvas` → **E04**; `Loc.swift` + the String Catalog → **E18·T01**; `LoomGrain.metal` → **E20·T07** |
| Checks 9, 10 and 11 of `Scripts/check-source-hygiene.sh` proved failing; `check-tokens.swift` in CI | The script itself and checks 1–8 → **E01·T06**; the workflow → **E01·T07** |
| The §14.1 rows *Palette tokens*, *Register segregation*, *Strokes, corners, grid*, *Typography* | *High Contrast theme* (§13.11) → **E19·T09**, which proves the theme on rendered glyphs; E03 ships only its palette and weight arms. *Reduce Motion table* → **E20·T08**. *Dynamic Type* per-screen behaviour → **E19·T06**; E03 ships only `artScale` and its 1.35 ceiling. *System settings* → **E19·T08**; E03 ships only the axes and predicates |
| — | **No drawing of any kind.** Nothing in this epic renders a pixel. The first raster is E04·T06 |

## Tasks, in execution order

| # | Title | P | Size | Deps | One line |
|---|---|---|---|---|---|
| T01 | L0 `Prim` primitives | P0 | S | — | `RGB8` with WCAG luminance, every hex in the app, Okabe–Ito verbatim, the three scalars — and `.sRGB` pinned as the reason none of it may move |
| T02 | L1 semantic layer and the register types | P0 | M | T01 | Ten colour tokens × three themes behind `Palette(theme:)`; `AccentColor`/`HueColor`; five weights carrying `respondsToBoldText`; the nine-step space scale; three radii; seven type roles; the duration and easing tables |
| T03 | `RenderEnv` and the resolution order | P0 | M | T02 | The seven axes made behaviour: `resolved(in:)` multiplying before it offsets, `artScale` clamped at 1.35 and kept out of the weight chain, and the nine derived predicates |
| T04 | L2 `C.<component>` namespaces | P0 | M | T03 | One namespace per §3 row, the §2(a) scattered literals landed, and the rule that L2 names L1 and never `Prim` |
| T05 | Contrast and token tests | P0 | M | T02 | Every ratio recomputed from its own hex in all three themes; the HC floor; the 21 : 1 pair; the 1.22 : 1 amber/brass adjacency asserted so nothing may ever rely on luminance to separate the registers |
| T06 | `Modules` package and the SwiftUI adapter | P0 | M | T04, T05 | The second package, `HunchUI`, the four-file adapter that is the only code knowing SwiftUI exists, `Typography.swift`, and checks 9/10/11 proved failing |

T05 depends only on T02 and may be executed before or alongside T03/T04; the order above is the
committing order, and each task ends in its own commit.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E03-tokens

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E03-tokens
gh pr create --title "E03 — Design tokens and RenderEnv" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

Write `.github/pr-body.md` on this branch before step 3: the gate commands and their output, the
`DECISIONS.md` entries this epic adds, and the task list with its commit SHAs.

**Do not start E04 until this PR is merged.** E04·T01 imports `Tokens` and takes a `HueColor`; a
second branch built on an unmerged one is a rebase waiting to happen. If a check fails, fix it on
`epic/E03-tokens` and push again — never merge red, and never disable or weaken a check to get
green (`hunch-build-and-ci`: a gate that can be waived is documentation).

## The gate

Every one of these must pass on the branch before the PR may merge. Run them in this order; the
cheapest failure is reported first.

| # | What must be true | Command that proves it |
|---|---|---|
| 1 | No literal colour, dimension, opacity or duration outside `Tokens/`, and no register colour minted outside it | `Scripts/check-source-hygiene.sh` → `Source hygiene: clean`, exit 0 |
| 2 | The same script **fails** when a literal is planted | `printf '\nlet x = Color(red: 1, green: 0, blue: 0)\n' >> Modules/Sources/HunchUI/RGB8+Color.swift && Scripts/check-source-hygiene.sh; echo "exit=$?"` → check 9 names that file, `exit=1`. Then `git checkout -- Modules/Sources/HunchUI/RGB8+Color.swift` |
| 3 | `palette.md` ↔ `Prim.swift` ↔ §13.2 agree, every ratio recomputed | `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` → exit 0 |
| 4 | Every §13.2 ratio matches to 2 dp in all three themes; the HC state-bearing floor ≥ 9.68 (§13.11's "9.7"); `stroke.primary` vs `ground.base` under High Contrast is exactly 21.00 | `swift test --package-path HunchCore --filter ContrastTests` |
| 5 | The resolution order is `3.0 → 3.75 → 4.25`, never `4.375`; the whole 5 × 4 matrix is exact and monotone; `artScale` never reaches a weight | `swift test --package-path HunchCore --filter RenderEnvTests` and `--filter StrokeWeightTests` |
| 6 | L2 names no L0 | `grep -rn 'Prim\.' HunchCore/Sources/Tokens/C.swift` → no output |
| 7 | The whole fast suite is still green and under 10 s | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 8 | The iOS side compiles, including the adapter and `Typography.swift`, and its four suites run | `set -o pipefail; xcodebuild build -scheme Hunch -destination 'generic/platform=iOS' \| xcbeautify`, then `xcodebuild test -scheme Hunch -testPlan Presubmission -destination "id=$UDID"` where `$UDID` is resolved at runtime by the workflow (`07 B29` — never a hardcoded name+OS pair) |
| 9 | CI is green on the PR | `gh pr checks --watch` |

## Definition of done

- [ ] `HunchCore/Sources/Tokens/` holds nine files: `RGB8`, `Prim`, `RenderEnv`, `Palette`,
      `StrokeWeight`, `Space`, `TypeRole`, `Motion`, `C` — and no other directory in the repo holds
      a hex, a `lineWidth:` literal, a `cornerRadius:` literal, a literal `.opacity(` or a
      `Duration.milliseconds(` call.
- [ ] `Tokens` is a leaf target: `swift build --package-path HunchCore --target Tokens` succeeds
      with no `dependencies:` in its manifest entry and no `.defaultIsolation`.
- [ ] `AccentColor` and `HueColor` have module-internal initialisers; the documented laundering
      drill in `T02` fails to compile with `initializer is inaccessible`.
- [ ] All nine gate rows above pass, and their commands are pasted into `.github/pr-body.md`.
- [ ] `tests.json` carries an entry for each of: the contrast matrix, the High Contrast floor, the
      resolution order, and the register adjacency — no entry deleted or weakened.
- [ ] `DECISIONS.md` records every decision this epic makes, at minimum: the `Tokens` target added
      to `HunchCore` (not in `08 §1`'s tree); `Palette.swift`/`Stroke.swift` moving out of `HunchUI`
      into `HunchCore/Sources/Tokens`; multiply-then-offset with its three reasons; `C.Assay.cellSide`
      landing in E03 rather than with its owning skill; the two deliberate `06 T5b` naming
      deviations (`ContrastTests.swift`, `ComponentTokenTests.swift`); the `HunchUITests` →
      `HunchAutomationTests` rename of the Xcode UI-test bundle; and `Modules`' product being
      `HunchUI` until E10·T01 introduces `HunchAppFeature`.
- [ ] `PROGRESS.md` records the epic as merged with its PR number.
