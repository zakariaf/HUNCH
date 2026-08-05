# The sigil construction grammar

The rules every sigil obeys, the primitive vocabulary it is built from, and the frames and
weights it is drawn in. Read this before drawing anything. Per-sigil detail is in
`mode-sigils.md`, `family-sigils.md`, `profile-vertex-sigils.md`, `codex-facet-stamps.md`.
Coordinates for every sigil live in `../scripts/check-sigil-distinctness.js` → `SIGILS`.

1. [What a sigil is](#1-what-a-sigil-is)
2. [The six rules](#2-the-six-rules)
3. [The frame](#3-the-frame-box-stage-modulus)
4. [The primitive vocabulary](#4-the-primitive-vocabulary)
5. [Stroke roles and the budgets](#5-stroke-roles-and-the-budgets)
6. [Colour, register and what the host's state costs a sigil](#6-colour-register-and-state)
7. [RTL, rotation and Dynamic Type](#7-rtl-rotation-and-dynamic-type)
8. [What would be wrong](#8-what-would-be-wrong)

---

## 1. What a sigil is

A sigil is **a diagram of a move, drawn from idioms the player has already met.** §12.4 states
this for the four mode sigils — *"Each rack key draws a sigil built only from idioms the player
has already met"* — and this skill extends it to all four sets, because a mark invented from
nothing has to be taught, and there is nowhere to teach it in a wordless app.

Three consequences follow, and they are the whole design:

- **A sigil is not an icon.** It does not depict an object (a book, a gear, a target). It
  depicts a *relation between two parts of the machine*, the way the coupler depicts AND as a
  welded bar rather than as the character `&` (§4.2: *"Diagrams, not symbols"*).
- **A sigil is chrome, not a glyph.** It draws in `stroke.*`, never `hue.*`. A glyph is
  *generated* from `(fill, shape, pips, hue)` and belongs to `hunch-glyph-renderer`; a sigil is
  *authored* and belongs here. Nothing is both.
- **A sigil has no text and no numeral in any of the 12 locales**, at any Dynamic Type size,
  including in its accessibility fallback (the label is audio, §13.10).

## 2. The six rules

**G1 — Quote, do not invent.** Every part of a sigil is a primitive from §4 below, each of which
is an existing drawing owned by another skill. `mode.sieve`'s grate is the one exception canon
itself allows (§12.4: *"new, but self-evident"*). If a candidate needs a seventh new form, the
sigil is wrong before it is drawn.

**G2 — At most three primitives.** Beyond three nothing survives U = 22, the Codex instrument
strip, which is the smallest site any sigil ships at.

**G3 — Exactly one relation verb.** Each sigil states one relation, from the closed list
`enter · stack · repeat · cross · split · compare · contain · count · bar · return · double ·
quad · one`. The `verb` field in `SIGILS` records it. **Two sigils may not share the same
(primitive set, verb) pair** — that is the distinctness rule at the semantic level, upstream of
the pixel harness, and it is the one that a human can check by reading.

**G4 — No bare quote.** A sigil that is one primitive and nothing else *is* that shared mark, and
will be read as one. §11.11 P3 names four sigils as bare quotes — Induction "a ramp silhouette",
Retention "a link arc", Restraint "the Seal's bar", Tempo "a tick strip" — and all four are
composed rather than quoted here. See `profile-vertex-sigils.md` for how, and why that is a
faithful reading of P3 rather than a departure from it.

**G5 — Distinctness is measured, not asserted.** Every drawing clears the pairwise harness
against every other shipped drawing before it is written down:
`node ../scripts/check-sigil-distinctness.js --new <key>`. The threshold `T` is the glyph
renderer's own shipped constant, `C.Glyph.minimumPairwiseInkDifference`
(`hunch-glyph-renderer/references/triple-encoding-proof.md` §4); this skill does not own it and
will not invent one.

**That constant is an ink *area* — pt² at S = 44 — and this harness measures mean |Δ| in 8-bit
levels.** The two are not the same unit and the conversion is exact:
`meanL1 = 255 · pt² / U²`, taken at the harness's comparison side `U = 24`. It is done in one
place, `resolveT` in the harness, and printed on every run so a reader can see which number came
from where. **The reading is the absolute one** — a sigil must differ by the same *area* of ink a
glyph must, at the box side it is compared at — and it is the stricter of the two available
readings. Switching to the scale-invariant reading (`255 · pt² / 44²`) is a design decision and
would be recorded here; do not make it silently in the script.

**G6 — The drawing has exactly one home.** Coordinates live in `SIGILS`. Prose lives in one
catalogue file. The harness fails if a key has no prose section, or has two.

## 3. The frame — box, stage, modulus

Authored in a **normalised box of side `U`, origin at the centre, y down, angles clockwise from
East.** That is the screen frame `hunch-glyph-renderer/references/geometry.md` resolved to, and
using the same one means a sigil and a glyph can be reasoned about in one head.

`U` is a property of the **site**, never of the drawing. The drawing is scaled, never re-cut:

| Site | U | Source |
|---|---|---|
| Codex page instrument strip | 22 | §11.1 |
| instrument bar · shelf divider · facet stamp · Profile vertex | 24 | §11.2, §12.4, §11.11 |
| play key · shelf plate family sigil | 44 | §12.4, §11.2 |
| mode rack key (inside 168 × 108) | 72 | §12.4 |

Moduli, all fractions of `U`. **Their one home is `M` in
`../scripts/check-sigil-distinctness.js`;** the table below is a mirror, and the harness fails if
the two disagree, so it cannot silently rot.

| Name | Value | What it is |
|---|---|---|
| `stage` | 0.90 | no ink outside this centred fraction of the box |
| `authorBound` | 0.40 | no centre-line beyond this; the rest is stroke half-width headroom |
| `ring` | 0.26 | the throat quote — the radius every ring in a sigil uses |
| `ladderW` | 0.60 | the reduced ramp footprint, 4 cells |
| `ladderH` | 0.17 | ditto, height |
| `plateW` | 0.44 | the rule-tile plate footprint |
| `plateH` | 0.30 | ditto, height |
| `notchW` | 0.11 | the blank attribute header |
| `inkMin` | 0.030 | ink-coverage floor at 44 px — §5 |
| `inkMax` | 0.34 | ink-coverage ceiling at 44 px — §5 |

## 4. The primitive vocabulary

Each row is an existing drawing. **The named skill owns it; this skill only places it.** The
macros in `../scripts/check-sigil-distinctness.js` → `MACRO` are mirrors for rasterising, and
carry the owner's path in a comment. If an owner changes their drawing, re-run the harness.

| Primitive | Quoted from | Owner |
|---|---|---|
| `ring` | the throat | `hunch-bench-instruments/references/throat.md` |
| `ladder` (4 cells, lit/unlit) | the ramp | `hunch-bench-instruments/references/ramp.md` |
| `notch` | the attribute header, blank | `hunch-bench-instruments/references/attribute-header.md` |
| `plate` | a rule-tile | `hunch-bench-instruments/references/rule-tile.md` |
| `ghostPlate` (dashed + backward chevron) | the `prev` ghost | `hunch-shared-marks/references/ghost-frame.md` |
| `bar` | the machined bar | `hunch-shared-marks/references/machined-bar.md` |
| `linkArc` | ribbon adjacency | `hunch-shared-marks/references/link-arc.md` |
| `tickRow` | the par row | `hunch-shared-marks/references/tick-row.md` |
| `wedge` | the comparator | `hunch-bench-instruments/references/wedge.md` |
| `couplerAnd / couplerXor / couplerOpen` | the coupler | `hunch-bench-instruments/references/coupler.md` |
| `fork` | the railway switch | `hunch-bench-instruments/references/fork.md` |
| `arc` (decaying, doubled) | the arc meter, the sealed rim | `hunch-shared-marks/references/arc-meter.md` |
| `grate` | nothing — §12.4's one sanctioned invention | this skill, `mode-sigils.md` |

**`couplerOpen` carries a meaning worth knowing:** a hollow node means *the coupler is
unresolved at this level of detail*. `family.composite` uses it because band 7 admits all three
couplers; `family.pair` and `family.exclusive` draw resolved ones because their families fix
them (§5.2: band 3 *is* XOR of two 2-element subsets).

## 5. Stroke roles and the budgets

A sigil names **roles**, not weights. The role → `weight.*` map is the one rule, and it reuses
the glyph's own size regime (§13.5) rather than inventing a second one:

| Role | U < 48 | U ≥ 48 | Carries |
|---|---|---|---|
| `contour` | `weight.thin` | `weight.thin` | frames, sockets, ladders, plates |
| `verb` | `weight.bodySm` | `weight.body` | the one stroke that states the relation |
| `ghost` | `weight.hairline` | `weight.hairline` | dashed frames, dim tracks, cell separators |
| `bar` | `weight.body` | `weight.heavy` | the machined bar only |

The **values** of `weight.*` belong to `hunch-design-tokens`; never write a number. Bold Text
scales them (`respondsToBoldText` is true for all four roles — §13.11 scopes Bold Text to glyph
and rule-tile strokes, and a sigil is made of rule-tile strokes) and High Contrast adds its flat
`+0.5 pt` after, in that order. `hunch-design-tokens/SKILL.md` owns the ladder.

Two budgets, both **owned here**, both asserted by the harness at 44 px:

- **Ink coverage ∈ [0.030, 0.34]** of the box. Below the floor the sigil is a speck at U = 22;
  above the ceiling it is a blob, and PHOSPHOR's whole premise is that ink is rationed.
- **Stage containment** — no ink outside `stage`. A sigil that touches its box collides with the
  key's 1 pt hairline border (§13.3) and with the next stamp in the facet bar.

## 6. Colour, register and what the host's state costs a sigil

`stroke.secondary` idle, `stroke.primary` lit. That is the entire palette of a sigil.

**Never `hue.*`** — that register belongs to glyph bodies, fills, pips and index strokes, and the
type split makes the mistake uncompilable (`hunch-design-tokens/SKILL.md`, scope §4.2).
**Never `accent.*` either**, with one boundary case: when a mode key is *barred*, the machined
bar laid across it is `accent.cold`, and the bar is `hunch-shared-marks`'s drawing, not part of
the sigil. The sigil underneath does not change colour.

**The states belong to the host, not to the sigil.** A key-borne sigil sits inside
`enum KeyState`, whose one home is `hunch-chrome-and-meta/references/key.md` §3. Read the cases
there. This file states only what the *sigil* does inside each of them, and the answer is
two-valued:

| The sigil's contribution | When |
|---|---|
| ink `stroke.secondary` | the host is not lit — `idle`, `pressed`, `barred`, and every depictive placement |
| ink `stroke.primary` | the host is lit — `selected` and `suspended` |
| the whole mark at `opacity.disabled` | `disabled` |

Everything else a reader might call a "sigil state" is the key's drawing with the sigil sitting
unchanged underneath it: `pressed` steps the **key's** interior to `surface.cellLit`; `barred`
lays `hunch-shared-marks`'s machined bar across the key; `suspended` turns the **key's border**
into an arc filled to `probesUsed / par`. None of the three touches the box.

**`depictive` is a placement, not a `KeyState` case.** A Codex-strip sigil, a shelf divider and a
Profile vertex sigil are not on controls, so they have no press, no selection and no bar. That is
a `role` in this skill's own signature and must not be added to the key's enum — six cases there,
and this file does not get a vote.

**No state is carried by the sigil's own geometry changing.** Every one above is a colour step, an
opacity step, or a separate mark drawn over the key. That is what lets one drawing serve every
state and lets the harness compare drawings rather than compositions.

## 7. RTL, rotation and Dynamic Type

**A sigil never mirrors.** The layout that places it mirrors; the box does not. §2 already
exempts instrument scales — *"Ramps, the Assay and the ribbon are instrument scales and render
leading-to-trailing in source order in every locale"* — and most sigils quote exactly those. One
rule for all 22 beats a per-sigil rule nobody will remember, and it keeps a mark that is an
*identity* identical in Arabic and English.

**Rotation is part of the drawing, not part of the layout.** The five Profile vertex sigils are
rotated to §11.10's locked vertex angles. That rotation survives the AX3 reflow from ring to
vertical list (§13.11) and survives RTL, because it is what distinguishes them.

**Dynamic Type reaches a sigil only through `U`.** `U` is a site constant scaled by
`env.artScale` (clamped 1.35, §13.11) where the site scales at all; the mode rack key and the
Profile card do not scale (§13.11: *"it is a drawing, not text"*). Nothing inside the box
responds to type independently.

## 8. What would be wrong

- **Drawing an icon.** A magnifying glass for PROBE, a clock for Tempo, a trophy anywhere. It is
  a different language from the rest of the app and it has to be taught.
- **Inventing a primitive** because the composition is awkward. Change the composition.
- **Reaching for `hue.*` or `accent.*`** to separate two sigils that the harness says collide.
  Colour is not a channel here: `stroke.secondary` and `stroke.primary` are the whole palette,
  and Differentiate Without Colour would erase the distinction anyway.
- **Hand-tuning a sigil per size.** One normalised drawing, scaled. A second set of coordinates
  for U = 22 is a second drawing and will drift from the first within a month.
- **Adding a `Localizable.xcstrings` key.** The catalogue is budgeted at 250 and asserted by test
  (§12.9). A sigil is wordless; its VoiceOver label reuses an existing key.
- **Mirroring under RTL**, or rotating a sigil for visual balance. Rotation means something here.
- **Making a state change the geometry** — a "selected" variant with an extra tick, a "sealed"
  variant with a different ring. Every state, one drawing (§6).
- **Re-enumerating `KeyState` here, or adding `depictive` to it.** Six cases, one home
  (`hunch-chrome-and-meta/references/key.md` §3); `depictive` is a placement in this skill.
- **Writing a hex, a weight, an opacity or a measured contrast ratio into any file in this
  skill.** Cite the token; the value has one home.
- **Skipping the harness because the drawing is "obviously different".** `family.pair` and
  `family.exclusive` are the closest pair in the library and were designed to be different; they
  clear by less than any other pair.
