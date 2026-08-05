---
name: hunch-bench-instruments
description: "Builds HUNCH's interactive play surface — the Bench, the Dial, its instruments, the SIEVE gate band and the counterexample — each with its geometry, states, select modes and size regimes. Use when working on a ramp, socket, rule-tile, wedge, Fork, Tally, coupler, Assay, Seal, throat, ribbon or commit bar. Not buttons, bars, sheets, the Codex or the Profile, which are the chrome skill, and not the glyph inside a cell."
allowed-tools: Read Grep Glob
metadata:
  version: "1.0"
  owns: "rows B of DESIGN-SYSTEM-SCOPE.md §3 — fourteen composed surfaces: their geometry, states, select modes, interaction and accessibility"
---

## The instruments as they exist right now

```!
d=$(ls -d "${CLAUDE_PROJECT_DIR:-.}"/Modules/Sources ./Modules/Sources ../Modules/Sources 2>/dev/null | head -1)
if [ -n "$d" ]; then
  all=$(grep -rn 'struct [A-Za-z]*\(View\|Canvas\|Shape\|Grid\|Band\)\b' "$d" --include='*.swift' | sed "s|$d/||")
  n=$(printf '%s\n' "$all" | grep -c .)
  printf '%s\n' "$all" | head -40
  [ "$n" -gt 40 ] && echo "(… $n drawing types total — grep Modules/Sources for the rest)"
else echo "NO DRAWING CODE YET — every reference file here is normative until Modules/Sources/HunchUI exists."; fi
```

One owning type per row of the table below. If that listing shows two types drawing the same
instrument, the second one is the bug — §2(g) drift starts the moment a second drawing exists.

## The rule

**This skill owns geometry, states and interaction. It owns no values.** Every colour, weight,
space, radius, opacity and duration resolves through `hunch-design-tokens` — load that skill first.
Component-scoped numbers live at **L2**, `C.<Component>.*` in `HunchCore/Sources/Tokens/C.swift`,
created by this skill and referencing L1 only. If you typed a hex, a `lineWidth:` or a
`.opacity(0.25)` while working here, you skipped `hunch-design-tokens`.

The literals that used to float loose in the GDD have owners, and the owner is the token, not the
prose: unlit cell → `C.Ramp.cellUnlitInk(in:)`, inert ramp → `C.Ramp.inertInk` +
`C.Ramp.cancelHatchWeight(in:)`, Codex rule-tiles → `C.RuleTile.codexScale`, Assay cells →
`C.Assay.cellSide(_:)`. **Never restate 0.25, 0.30, 0.78, 3.5, 4, 9.5 or 23 in a view.**

The inert ramp's hairline slash **is** a `CancelHatch.draw(variant: .slash)` and reads the same
weight as the unlit cell's hatch. There is no `C.Ramp.cancelSlashWeight`; one number, one home
(`hunch-shared-marks/references/cancel-hatch.md` §1).

## Where each instrument lives

| Read | When |
|---|---|
| `references/ramp.md` | any ramp on the Dial, a Ramp tile, either Fork dock, the Tally — **and before assuming there are four instances; there are seven** |
| `references/attribute-header.md` | the leading 44 pt of a ramp, an empty Bridge socket's picker, a Tally row, a facet stamp |
| `references/rule-tile.md` | the frame, scale regime or revealing/burnished/cleared state shared by all four tile classes |
| `references/bridge.md` | two sockets and a wedge; the ghost toggle; anything contextual |
| `references/wedge.md` | the six comparators, and any time an ASCII operator is tempting |
| `references/fork.md` | the guard tile — gate dock, then dock, else dock |
| `references/tally.md` | the aggregate tile — attribute toggles, rank ramp, counter dial, parity mode |
| `references/coupler.md` | the AND/OR/XOR node between the two rails |
| `references/assay-grid.md` | the 16×16 deck grid at any of its six sizes, the pinned `prev` slice, the evidence overlay |
| `references/seal.md` | the commit control, the machined bar, the barred-rail pulse |
| `references/throat.md` | the live glyph well, the adjudication aperture, the Frame's idle Loom |
| `references/ribbon.md` | probe tiles, link arcs, the spool sheet, ECHO's rail and cast, SIEVE's tail |
| `references/gate-band.md` | SIEVE's 375 × 88 actionable band and nothing else |
| `references/counterexample.md` | the glyph that rises out of the Assay on a first strike and docks below the ribbon for the rest of the round |

Every file answers the same six questions in the same order: **geometry · states and variants ·
SwiftUI sketch · VoiceOver · Reduce Motion · High Contrast**, then closes with **what would be
wrong**. If a file is missing one of the six, that is a defect in the file.

## What this skill does not draw

**Path convention.** A path beginning `hunch-` is relative to `.claude/skills/` and always carries
its `references/` segment — `hunch-shared-marks/references/machined-bar.md`. Every other path is
repo-relative — `Modules/Sources/HunchUI/Marks/`. A `hunch-` path with no `references/` segment is a
dead link, and a dead link here means the spec read fails and the geometry gets re-derived inline,
which is the drift this skill exists to stop.

The **glyph inside a cell** is `hunch-glyph-renderer`; a ramp cell draws a glyph-with-one-channel and
calls that renderer, it never re-derives a silhouette. The **verdict ring, ghost frame, machined bar,
link arc, cancel hatch, tick row and arc meter** are `hunch-shared-marks`; every instrument here
*calls* them and none of them redraws one. Keys, instrument bars, rules, scrims, numeral readouts,
shelf plates, extension thumbnails, the Profile contour and the Codex page composite are
`hunch-chrome-and-meta`. Timings and cue firing are `hunch-motion-and-feedback`; this skill states
which state an instrument is in, not how long it takes to get there.

## Standing rules for every instrument

1. **One `Canvas` per accessibility element.** A `Canvas` is a single element to VoiceOver, so an
   instrument whose parts must each be reachable — ramp cells, sockets, the wedge, the coupler, tray
   tiles — is a `Button` per part, each drawing its own `Canvas` or `Shape`. Draw many marks into one
   `Canvas` only where §13.10 exposes them as one element: the Assay, the ribbon's arcs, the tail,
   the par row. Getting this backwards produces a beautiful surface with one unlabelled blob in it.
2. **Every state is readable with no colour and no brightness discrimination.** Each state carries a
   *geometry* difference first — hatch, slash, bar, ring closure, dash — and colour second. If you
   can only name a colour difference, the state is not yet drawn.
3. **`RenderEnv` is injected, never read.** Views take `let env: RenderEnv` from
   `RenderEnvReader`; there is no `.current`, no singleton, no `UIAccessibility` read below the
   composition root (`04 A24`, `04 A29`).
4. **Art scales, chrome does not.** Lengths multiply by `env.artScale` at the drawing site, clamped
   at 1.35. Stroke weights never do — they have their own axis. Above AX2 an instrument **pages
   rather than shrinks** (§13.11): the Bench becomes a single-rail pager, ECHO's tray a two-column
   pager, the Dial scrolls inside its region.
5. **Leading/trailing only, and glyphs never mirror.** Ramps, the Assay and the ribbon render
   leading-to-trailing in source order in every locale (§2, §12.8). The wedge mirrors *with* its
   rail so its wide end still opens toward the larger socket; the index stroke and pip accretion
   never mirror.
6. **No drag, pinch, long-press or double-tap anywhere in the declaration UI** (§4.2). Every action
   is a tap or a trailing-edge swipe. This is the reason the whole Bench is VoiceOver-operable, so
   adding one drag breaks the accessibility argument, not just a gesture.

## Gotchas

- **The ramp has seven interactive instances and two depictive reuses, not four.** The Fork's lit
  and dim docks are each a *full* ramp on the same attribute (§4.2), which is the instance most
  often lost. `ramp.md` owns the enumeration; a new call site that is not in that table is either a
  mistake or an edit to that table.
- **The Assay is never bloomed — at any size, in any state, in any theme** (§13.5, PHOSPHOR §2).
  Not the bench well, not the inspector at 23 pt, not the Codex page. Its cells carry no stroke to
  widen, and during the reveal it floods 256 cells on top of the throat and the ribbon on the one
  frame that cannot afford a fourth offscreen layer.
- **The live Assay is a *slice* pinned to the ghost; the Codex thumbnail is the unconditional
  marginal projection.** They are different pictures with different jobs and must never be quoted
  for each other (§4.3) — including in the VoiceOver value, where the projection would say 48 while
  the screen shows 64.
- **A ramp has one inert state, not two.** 0 lit and 4 lit both draw at `C.Ramp.inertInk` with a
  hairline slash, because nobody should have to learn the difference between "empty" and "vacuous"
  (§4.3). Two inert drawings is a bug even if both are correct-looking.
- **The Bridge's leading socket is always `cur` and carries no ghost toggle** (RNF rule 3, §4.2). A
  toggle there would make the only expressible contextual family the transposed one and render a
  law the grammar forbids.
- **The attribute header's drawing is the one thing in this skill the GDD never specifies.**
  `attribute-header.md` states the four constraints any drawing must satisfy and the sanctioned
  construction; final vetting is `hunch-sigil-drawing` plus the snapshot gallery's distinctness
  check. Do not quietly invent a fifth emblem — §4.1's whole claim is that there is no attribute
  emblem to learn.
- **A barred control refuses without an error.** No error text, no error state, no modal, no alert —
  a machined bar and a pulse on the offending rail (§4.3). Adding a message is a design regression,
  not a helpful addition, and it puts text on the play surface.

## Never

- Never put a `Text`, `Label` or `AttributedString` on any of these instruments outside an
  `.accessibility*` modifier. `PlaySurfaceTextTests` fails the build (§12.9), and it should.
- Never draw a shared mark yourself. The ring, ghost frame, machined bar, link arc, cancel hatch and
  tick row have exactly one owning function each in `hunch-shared-marks`.
- Never give an instrument a hit target below 44 × 44 pt, and never shrink one to fit Dynamic Type.
  Read-only surfaces (ribbon arcs, primer strip, pool strip, tail) are exempt because they are not
  targets at all — make them exempt by making them non-interactive, not by making them small.
- Never let `accent.*` reach a ramp cell, a glyph body or an index stroke, and never let `hue.*`
  reach a tile frame, a coupler, a tick or the Seal. The types make it a compile error; reaching
  `.rgb` to launder one into the other is check 10.
- Never add a second drawing of an instrument for a new site. Add a size regime or a state to the
  existing one — `read-only`, `depictive`, `scale` — so the two cannot drift.
- Never let a Reduce Motion substitution change what the instrument *shows*. Substitute the
  animation, keep the information: SIEVE's crossfade keeps station, cadence, dwell and preview count
  byte-identical (§13.7.4), and that is the pattern for every row.
