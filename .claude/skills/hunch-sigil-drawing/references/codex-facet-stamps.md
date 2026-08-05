# The five Codex facet stamps

`facet.mode.off` · `facet.unfractured` · `facet.anomaly` · `facet.attributes` ·
`facet.threeMarks`.

§11.2 gives the facet bar one line — *"5 stamps at 44 pt: mode (cycles through 4 sigils + off),
unfractured-only, anomaly-only, attribute-participation (four ramp headers), 3-marks-only"* — and
a parenthesis each. Scope §2(e) lists them as undrawn. This file draws them.
Coordinates: `../scripts/check-sigil-distinctness.js` → `SIGILS`.

1. [Five stamps, four keys](#five-stamps-four-keys)
2. [The drawings](#the-drawings)
3. [States](#states)
4. [The no-NOT rule](#the-no-not-rule)
5. [VoiceOver](#voiceover)
6. [Reduce Motion, High Contrast, Bold Text](#reduce-motion-high-contrast-bold-text)
7. [What would be wrong](#what-would-be-wrong)

---

## Five stamps, four keys

The **mode** stamp has no drawing of its own: it displays `mode.probe` / `mode.drift` /
`mode.echo` / `mode.sieve` (see `mode-sigils.md`), or `facet.mode.off` when the facet is
inactive. That is why the bar has five stamps and this file has four new drawings plus the off
state.

All five sit in the `CodexRootView` facet bar, y 624–667, at 44 pt each (§11.2), with the sigil
drawn at `U = 24` inside a 44 × 44 key. `CodexShelfView`'s bar shows facet *state* in the same
stamps (§11.2, "facet state").

## The drawings

| Key | §11.2's clause | Verb | Drawing |
|---|---|---|---|
| `facet.mode.off` | "…+ off" | `contain` | one `ring` at the ring modulus, `contour` weight, empty — the throat with nothing in it, which is *any mode* |
| `facet.unfractured` | "unfractured-only" | `contain` | the Codex page frame, closed: a rect stroked with a filled closure node at its top-leading corner |
| `facet.anomaly` | "anomaly-only" | `double` | two concentric arcs at 0.28 and 0.37 with a 40° gap — the doubled rim an anomaly page takes (§11.1, §11.2) |
| `facet.attributes` | "attribute-participation (four ramp headers)" | `quad` | four blank `notch` rects in a 2 × 2 quad; participating attributes fill |
| `facet.threeMarks` | "3-marks-only" | `count` | three Seal-mark bars at `verb` weight, no baseline (§11.1: "Seal marks as 1–3 pips") |

Three of these carry a decision:

- **`facet.unfractured` quotes reveal beat 7.** §13.7.1 beat 7: *"The Codex page frame draws
  itself — a hairline rectangle stroked from the top-leading corner, clockwise."* The closure node
  marks that corner, so the stamp is *a page frame that closed*. A fracture is the same frame
  broken (§11.1, PHOSPHOR §3: a diagonal across the leading frame), so the stamp and the thing it
  filters are the same drawing in two states — which is the cheapest possible way to be legible.
- **`facet.attributes` is a 2 × 2 quad of *blank* notches, not four `AttributeHeaderView`
  drawings — and it is this file's, not the bench skill's.** §11.2's phrase is "four ramp
  headers", and `hunch-bench-instruments/references/ramp.md` §1 reads it as a depictive reuse in
  which the stamp calls `AttributeHeaderView`. **That reading loses, for three reasons.** (a) The
  facet stamp is a 44 × 44 key drawing its sigil at `U = 24`
  (`hunch-chrome-and-meta/references/key.md` §1, site 5), so each quadrant is about 12 pt; a
  register-true attribute header is specified legible at 44, 34 and 52 pt and nothing smaller
  (`attribute-header.md` §2 constraint 3). (b) The owner that reuse names,
  `hunch-chrome-and-meta/codex-page.md`, is `CodexPageView` and does not cover the facet bar,
  which lives in `CodexRootView` — so the drawing it points at has no home. (c) The quad is
  already in `SIGILS` with a distinctness clearance and a `DOC` owner; deleting it would leave
  the stamp with no drawing at all. The **quad's cells are the *slots*, and ink is the state** —
  it says *these four, independently*, which is the facet's actual semantics, where a column of
  four under a tie bar is `family.systemic` and the two would collide.
  `hunch-bench-instruments` should drop the facet stamp from `ramp.md` §1's depictive reuses,
  from `attribute-header.md` §1's five surfaces and from its constraint 3.
- **`facet.threeMarks` is exactly three, at `verb` weight, with no baseline.**
  `profile.tempo` is seven ticks on a hairline baseline, four filled. Same idiom family, two
  different statements: marks earned versus probes against par.

## States

Six per stamp, on top of `sigil-grammar.md` §6's shared set:

| State | Drawing |
|---|---|
| inactive (`KeyState.idle`) | sigil at `stroke.secondary`; the key's border is `key.md` §2's |
| active (`KeyState.selected`) | sigil at `stroke.primary`; the **key**, not the sigil, takes `surface.cellLit` |
| pressed | the key's interior steps; sigil unchanged |
| disabled | whole sigil at `opacity.disabled` when the facet would return an empty set |
| cycling (mode stamp only) | swaps between the four mode sigils and `facet.mode.off` |
| partial (`facet.attributes` only) | 1–3 of the four notches filled |

The first four are `enum KeyState` and are owned by `hunch-chrome-and-meta/references/key.md` §3;
only the last two are this file's, because only they change what the *sigil* draws.

`facet.attributes` has 16 renderings (2⁴ participation subsets) of **one** drawing. **The
filled/empty distinction is ink, never opacity** — full versus none — because this is the one
sigil whose cell pattern is *state-bearing* rather than depictive, and a live ramp's unlit-cell
treatment plus a cancel hatch is unreadable in a quadrant this small (`hunch-bench-instruments`
owns the live ramp's treatment; this stamp is not one). Two channels (position, fill) and no
accent, the same construction §13.3's Settings switch uses for the same reason.

The harness renders `facet.attributes` in its all-empty identity state. **A new participation
subset is not a new sigil** and does not go in the catalogue.

## The no-NOT rule

§3.1: *"there is no `NOT` node in the AST or the UI … a negation operator is the single hardest
thing to render unambiguously without text."* That constraint reaches the facet bar.

**A facet stamp draws the thing it retains, never a negation of the thing it excludes.**
"Unfractured-only" is a closed frame, not a crossed-out fracture. "Anomaly-only" is the anomaly
rim, not a struck-through calendar. There is no slash, no cross, no prohibition ring anywhere in
the set — the cancel hatch belongs to an unlit ramp cell (§4.2) and means *not admitted*, which
is a different sentence.

## VoiceOver

Each stamp is a control. §12.9 budgets `CodexRootView` at six VoiceOver control labels total, and
the five facets consume five of them; a sixth facet would cost a key against the 250 catalogue
budget and must be budgeted before it is drawn.

| Element | Traits | Label | Value |
|---|---|---|---|
| mode stamp | `.button`, `.isSelected` when not off | the shared facet label | the mode wordmark, or "off" |
| unfractured, anomaly, 3-marks | `.button`, `.isSelected` when active | the shared facet label | "on" / "off" |
| attribute stamp | `.button`, `.isSelected` when any attribute participates | the shared facet label | the participating attributes, from §12.9's existing 4 attribute-name keys |

Mode names are wordmarks and cost nothing (§12.9). Attribute names already exist in the catalogue
for the glyph label (§13.10). **No new key is needed for any stamp in this file.**

## Reduce Motion, High Contrast, Bold Text

- **Reduce Motion** — the mode stamp's cycle is the only change of any kind in the set, and it is
  a swap. Under `isReduceMotionEnabled` the swap is instant inside §13.7.4's default crossfade;
  at normal motion it is the same crossfade at `dur.crossfade`. Nothing translates, scales or
  rotates, so §13.7.4 needs no new row.
- **High Contrast** — flat `+0.5 pt` on every role after Bold Text's `×1.25`. `facet.anomaly`'s
  two arcs are `0.09 · U` apart, which at the stamp's `U` stays clear of a `contour` resolved
  under both settings, so the rims do not merge. That clearance is why the radii are 0.28 and
  0.37 rather than something tighter. **The resolved weight is `weight.thin` through the
  resolution ladder — do not write the number here**; `hunch-design-tokens` owns both, and the
  harness measures the clearance.
- **Bold Text** — all roles respond.
- **Differentiate Without Colour** — inactive versus active is a luminance step on the sigil
  *plus* a ground step on the key. Two channels, no accent, so nothing is lost.

## What would be wrong

- **Drawing a negation.** A slash, a cross, a barred circle, a "no" glyph. §3.1 removed NOT from
  the language; putting it back in the chrome teaches a symbol that means nothing anywhere else.
- **Adding a sixth facet without budgeting a catalogue key.** §12.9's 250 is asserted by test.
- **Cataloguing `facet.attributes`' 16 subsets as 16 sigils.** One drawing, one state parameter.
- **Drawing `facet.attributes` by calling `AttributeHeaderView` four times.** That is the reading
  §2 rejects: the quadrants are ~12 pt and the header drawing is not specified legible there. The
  quad's cells are slots; ink is the state.
- **Using opacity to mark a non-participating attribute.** At this size, ink versus no ink is the
  only channel that survives High Contrast and daylight.
- **Reusing `facet.threeMarks` for the Seal's own marks**, or the reverse. The Seal's marks are
  `hunch-bench-instruments/references/seal.md`'s drawing; this is a stamp that quotes them.
- **Letting `facet.mode.off` drift toward `mode.probe`.** They differ by one stroke and an offset
  centre. Both are in the harness; check before touching either.
- **Giving a stamp a hint that explains the filter.** The Codex is wordless above the strip; a
  hint is text with extra steps.
