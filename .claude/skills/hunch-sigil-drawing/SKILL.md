---
name: hunch-sigil-drawing
description: "Designs the app's wordless sigils under one construction grammar — four mode sigils, eight family sigils with their skeleton silhouettes, five Profile vertex sigils, five Codex facet stamps — proves each new drawing distinct from the ones already shipped, and records it back into the library so it is never reinvented. Use when a sigil is undrawn, ambiguous, or being invented for the first time. Glyphs are generated from four attributes, not designed; for those see the glyph skill."
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(node:*), Bash(paste:*), Bash(echo:*)
metadata:
  version: "1.0"
  owns: "the sigil construction grammar, the 22 authored marks, the distinctness harness"
---

## Sigils already drawn — do not redraw any of these

```!
d="${CLAUDE_SKILL_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/skills/hunch-sigil-drawing}"
keys=$(node "$d/scripts/check-sigil-distinctness.js" --keys 2>/dev/null | paste -sd' ' -)
if [ -n "$keys" ]; then echo "$keys"
else echo "HARNESS UNREACHABLE — do not treat this as an empty catalogue. The 22 authored keys are the SIGILS table in scripts/check-sigil-distinctness.js; read it before drawing anything."; fi
```

If the mark you want is in that list, the answer is that drawing. Open its catalogue file
(`references/mode-sigils.md`, `family-sigils.md`, `profile-vertex-sigils.md`,
`codex-facet-stamps.md`) and use it. **Do not draw a variant, a "cleaner version", or a second
one at a different size.** One drawing, scaled.

## The rule

**A sigil is a diagram of a move, built only from idioms the player has already met, authored once
in a normalised box and scaled to every site.** §12.4 states this for the four mode sigils; it
holds for all twenty-two, because a mark invented from nothing has to be taught and there is
nowhere in a wordless app to teach it.

Geometry lives in **one place**: `scripts/check-sigil-distinctness.js` → `SIGILS`. Every reference
file cites keys from it and states no coordinates. Colours, weights, opacities and durations
belong to `hunch-design-tokens` — cite the token name, never a value.

## To draw a sigil

1. **Prove it is undrawn** — the list above.
2. **Prove it is a sigil.** Generated from `(fill, shape, pips, hue)` → it is a glyph,
   `hunch-glyph-renderer`. Composed at many sites by many screens → it is a shared idiom,
   `hunch-shared-marks`. A sigil is an authored identity for a mode, a family, an axis or a facet.
3. **Write the sentence before the geometry** — the primitives, the verb, the move. Three
   primitives maximum, one verb, and no two sigils may share a (primitive set, verb) pair.
4. **Compose from `MACRO`** in the harness (`references/sigil-grammar.md` §4). Every part is a
   drawing another skill owns; you place it, you do not redesign it.
5. **Measure** — `node ${CLAUDE_SKILL_DIR}/scripts/check-sigil-distinctness.js --new <key>`.
   Gates pairwise distance ≥ `T`, ink coverage, stage containment — and, on a full run, that every
   key has exactly one owning section and that the moduli mirrored into `sigil-grammar.md` still
   match. A failure is a design answer, not an obstacle.
6. **Write it back** — four artefacts, one edit each: the entry in `SIGILS`, the prose section
   into exactly one catalogue file, the `case` in `HunchCore/Sources/Sigils/Sigil.swift`, and the
   regenerated parity fixture (`--json`). The harness fails on a key with no owning section, and
   on a key claimed by two; the fixture is what stops the Swift coordinates forking from `SIGILS`.
   The contract is `references/drawing-a-new-sigil.md` §5.

Full procedure, the Swift that ships it, and the tests: `references/drawing-a-new-sigil.md`.

## Where the detail lives

| Read this | When |
|---|---|
| `references/sigil-grammar.md` | **first, always** — the six rules, the primitive vocabulary, the box and stage moduli, the stroke roles, and `T`'s unit conversion |
| `references/mode-sigils.md` | PROBE · DRIFT · ECHO · SIEVE — the four canon specifies (§12.4), and what the sigil does inside each `KeyState` |
| `references/family-sigils.md` | the eight shelf sigils *and* the skeleton silhouettes, which are one drawing at two levels of detail |
| `references/profile-vertex-sigils.md` | the five vertex marks, and why §11.11 P3's five bare quotes cannot be drawn bare |
| `references/codex-facet-stamps.md` | the facet bar's five stamps, and the no-NOT rule that governs them |
| `references/drawing-a-new-sigil.md` | when actually adding one — procedure, `SigilCatalogue` + `SigilRenderer`, the three tests, the four-artefact write-back contract |

`node ${CLAUDE_SKILL_DIR}/scripts/check-sigil-distinctness.js` — no arguments runs the whole
matrix; `--new <key>` checks one candidate; `--svg <key>` dumps a drawing; `--keys` lists them;
`--json` dumps the catalogue as stroke lists, which is the Swift's parity fixture.
It reads `C.Glyph.minimumPairwiseInkDifference` from `HunchCore/Sources/Tokens/C.swift`, then
from `hunch-glyph-renderer`'s reference files, **converts it out of pt² into the harness's own
mean-|Δ| unit in one place**, and **exits 2 rather than invent one** — an unresolved `T` is a
missing input, not a pass. It prints the source and the conversion on every run.

## What a sigil does per state — which is almost nothing

**The sigil is never the thing with the states.** A key-borne sigil sits inside a
`KeyState`, and that enum has exactly one home: `hunch-chrome-and-meta/references/key.md` §3.
Read the cases there; do not re-enumerate them here or in a reference file.

A sigil contributes exactly two things to whatever state its host is in:

- **its ink** — `stroke.secondary` when the host is not lit, `stroke.primary` when it is
  (`selected` and `suspended` are the two `KeyState` cases that light it), and
  `opacity.disabled` over the whole mark under `disabled`;
- **nothing else.** `pressed` steps the *key's* interior to `surface.cellLit`; `barred` lays
  `hunch-shared-marks`'s machined bar over the key; `suspended` turns the *key's border* into an
  arc. All three are the key's drawing, not the sigil's, and the sigil beneath is unchanged.

**`depictive` is not a `KeyState`.** It is the placement of a sigil that is *not on a control* —
the Codex page strip, a shelf divider, a Profile vertex. It draws at `stroke.secondary` and takes
no press, so it is a role in this skill's own signature, never a seventh case of the key's enum.

That is what lets one drawing serve every state, and it is what lets the harness compare
drawings rather than compositions.

## Accessibility, in three rules

- **VoiceOver** — a sigil inside a control is `.image` and contributes to the *control's* label;
  it is never separately focusable. The one exception is the Profile vertex sigil, which §13.11
  gives its own 44 × 44 rect and §11.11 gives an approved behavioural sentence. Follow §13.10's
  Seal precedent for barred keys: `.button`, `.notEnabled`.
- **Reduce Motion** — no sigil animates, in either setting. The only movement near one is the
  key's (suspended arc, facet cycle, reveal beat 0), and that belongs to
  `hunch-motion-and-feedback`. §13.7.4 needs no new row for anything in this skill.
- **High Contrast** — no `hue.*` substitution applies, because a sigil has none. Every role takes
  the flat `+0.5 pt` *after* Bold Text's `×1.25`; `hunch-design-tokens/SKILL.md` owns that order.

## Gotchas

- **§11.11 P3 names four sigils as bare quotes of marks that already exist** — Induction "a ramp
  silhouette", Retention "a link arc", Restraint "the Seal's bar", Tempo "a tick strip". Drawn
  bare, Restraint *is* the machined bar and Induction *is* `family.literal`. All five are rotated
  to §11.10's locked vertex angles for exactly this reason. Read
  `references/profile-vertex-sigils.md` before touching any of them.
- **A family sigil and a skeleton silhouette are one drawing, not two.** §11.2 gives large shelves
  10–40 skeleton sections; cutting those as separate art is ~200 drawings that will drift.
  `familySigil(band:detail:)`, `detail ∈ {family, skeleton}`.
- **`family.pair` and `family.exclusive` are the closest pair in the library** — the harness names
  them at the top of its `closest pairs` list on every run, with the live margin. Do not write the
  margin down anywhere; run the harness. Any edit to either goes through it.
- **The facet bar is full at five.** §11.2 fixes the count, §12.9 budgets five VoiceOver keys
  against an asserted 250-key catalogue. A sixth facet costs a key and must be budgeted first.
- **Family and axis names are internal identifiers.** LITERAL…SYSTEMIC and
  Induction…Tempo are never spoken, never rendered, never in `Localizable.xcstrings` — §11.11 P3
  and §12.9, and P8's banned-lexeme grep fails the build on the translations of *Retention* and
  *Flexibility*.
- **`mode.probe` is already shipped** in `design/mockup-phosphor.html` → `modeSigil()`. Its
  proportions were carried across verbatim so the mockup and the app cannot diverge.
- **A sigil is drawn in a `Canvas`, never as a `Shape`** — every one carries at least two stroke
  roles at different weights, and a `Shape` yields one path under one style.

## Never

- Never restate a coordinate outside `SIGILS`, or a colour, weight, opacity or duration value
  anywhere. Cite the key; cite the token name.
- Never let `hue.*` or `accent.*` touch a sigil. `stroke.secondary` and `stroke.primary` are the
  whole palette. The barred key's `accent.cold` bar is `hunch-shared-marks`'s drawing, laid over
  the key, not part of the sigil.
- Never invent a primitive. `mode.sieve`'s grate is the one form canon sanctions (§12.4, "new,
  but self-evident") and there will not be a second.
- Never draw an icon — a magnifying glass, a clock, a trophy, a book. It is a different language
  from the coupler and the wedge, and it has to be taught.
- Never mirror a sigil under RTL, and never rotate one for visual balance. The layout mirrors; the
  box does not. Rotation means something (§11.10's five angles).
- Never hand-tune a sigil for a small size. One normalised drawing, scaled; a second set of
  coordinates is a second drawing.
- Never let a state change the geometry — no "selected" variant with an extra tick, no "sealed"
  variant with a different ring.
- Never draw a negation. §3.1 removed `NOT` from the language; a slash, a cross or a barred circle
  on a facet stamp puts it back and teaches a symbol that means nothing anywhere else.
- Never add a `Localizable.xcstrings` key for a sigil, and never use an image asset, an SF Symbol
  or an icon font. The sigils *are* the icon set.
- Never skip the harness because a drawing is "obviously different", and never invent a value for
  `T`. It is `C.Glyph.minimumPairwiseInkDifference` and it belongs to `hunch-glyph-renderer`.
- Never write a hex, a stroke weight, an opacity, a duration or a measured contrast ratio into
  this skill. `grep -rn '#[0-9A-Fa-f]\{6\}'` over `.claude/skills/hunch-*/` must return only
  `hunch-design-tokens`. Cite the token name; the value has exactly one home.
- Never re-enumerate `KeyState`. Six cases, one home, `hunch-chrome-and-meta/references/key.md` §3.
