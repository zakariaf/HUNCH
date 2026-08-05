# The four mode sigils

`mode.probe` · `mode.drift` · `mode.echo` · `mode.sieve`.

**These four are the only sigils canon specifies.** §12.4 gives each a one-line clause and names
the idiom it is built from; this file renders those clauses and adds the states, the
accessibility treatment and the wrongs. Where this file and §12.4 disagree, §12.4 wins and this
file is the bug. Coordinates: `../scripts/check-sigil-distinctness.js` → `SIGILS`.

1. [The four drawings](#the-four-drawings)
2. [What the sigil does on the mode rack key](#what-the-sigil-does-on-the-mode-rack-key)
3. [Sites](#sites)
4. [VoiceOver](#voiceover)
5. [Reduce Motion](#reduce-motion)
6. [High Contrast, Bold Text, Differentiate Without Colour](#high-contrast-bold-text-differentiate-without-colour)
7. [What would be wrong](#what-would-be-wrong)

---

## The four drawings

| Key | §12.4's clause | Verb | Drawing |
|---|---|---|---|
| `mode.probe` | *one stroke entering a ring* | `enter` | ring at `ring` radius, offset trailing; one `verb` stroke running from the leading stage edge **into** the ring, terminating past its leading arc |
| `mode.drift` | *two offset law-plates, the trailing one in the dashed hollow ghost frame* | `stack` | two `plate` rects offset diagonally; the trailing one is `ghostPlate` — dashed with the backward chevron |
| `mode.echo` | *a ring trailing three decaying concentric arcs* | `repeat` | ring offset trailing; three concentric 140° arcs opening toward leading at 1.00 / 0.55 / 0.30 opacity |
| `mode.sieve` | *three strokes falling through a slotted grate, one caught* | `cross` | three horizontal grate bars with two slots; three `verb` strokes descending, two through the slots, the middle one terminating **on** the grate with a filled node |

`mode.probe`'s proportions are not new: they are the drawing already shipped in
`design/mockup-phosphor.html` → `modeSigil()`, carried across verbatim so the mockup and the app
cannot diverge.

**The stroke must enter the ring, not touch it.** A stroke that stops at the contour reads as a
pointer; one that crosses it reads as a probe going in, which is the whole verb. The catalogue
terminates it 0.05·U past the leading arc.

**`mode.sieve`'s grate is the library's one invented form**, sanctioned by §12.4 (*"new, but
self-evident"*). It is self-evident only because *one is caught*: three strokes all passing
through is a comb, not a sieve. The caught stroke carries the meaning and is why it takes the
node.

## What the sigil does on the mode rack key

**The 168 × 108 rack key's states are `enum KeyState`, and its one home is
`hunch-chrome-and-meta/references/key.md` §3.** Read the six cases there. This section states only
what the mode sigil contributes inside them, plus the two gates that are §12.4's rather than the
key's — and **the sigil's own drawing is identical in every case** (`sigil-grammar.md` §6).

| `KeyState` | What the *sigil* does | Owned elsewhere |
|---|---|---|
| `idle` | `stroke.secondary` | key border — `key.md` §2 |
| `pressed` | nothing | the key's interior steps to `surface.cellLit` — `key.md` §3 |
| `selected` | lights to `stroke.primary` | the key's border and interior — `key.md` §3 |
| `barred` | nothing; the sigil stays legible beneath | `hunch-shared-marks/references/machined-bar.md` |
| `disabled` | whole mark at `opacity.disabled` | `key.md` §3 rules that the border stays full |
| `suspended(_)` | lights to `stroke.primary` | the border becomes an arc — `hunch-shared-marks/references/arc-meter.md` |

Two facts about mode keys specifically, because they are §12.4's and not the key component's:

- **When a mode key is barred is §9.10's** — DRIFT on a first band-≥ 3 page, ECHO and SIEVE at
  their own page counts. §12.4 *renders* those gates; §9.10 *sets* them. **Never restate the
  thresholds here**; a second copy is wrong the first time a gate moves.
- **Tapping a suspended key resumes; a trailing swipe discards** (§12.4). That is behaviour, not
  drawing, and it belongs to the Frame.

The suspended arc is an arc meter drawn on the **key border**, outside the sigil box, so it never
enters the harness.

**Depictive placements are not key states.** The Codex page instrument strip (§11.1) and the shelf
plate draw a mode sigil at `stroke.secondary` with no control under it at all.

## Sites

`sites: [22, 24, 44, 72]` — Codex page strip 22, instrument bar and facet stamp 24, play key 44,
mode rack key 72 inside the 168 × 108 key. One drawing, scaled; the harness gates at 22.

The Frame's rack is a 2 × 2 grid in order PROBE · DRIFT / ECHO · SIEVE (§12.4). **That order is
layout and mirrors under RTL; the sigils do not** (`sigil-grammar.md` §7).

## VoiceOver

The mode rack key is the accessibility element; **the sigil is not separately focusable** and
contributes nothing to the tree. Follow §13.10's precedent for the Seal exactly — *"`.button`,
`.notEnabled` when barred"*:

| Element | Traits | Label | Value |
|---|---|---|---|
| rack key, unlocked | `.button` | "Probe" / "Drift" / "Echo" / "Sieve" | — |
| rack key, suspended | `.button` | same | the existing probes-of-par value format (§12.9) |
| rack key, barred | `.button`, `.notEnabled` | same | — |
| instrument-bar sigil | `.image` | merged into the bar's label | — |
| Codex strip sigil | `.image` | merged into the strip's label | — |

The four names ship untranslated in all 12 locales — §12.9: *"The four mode names are
**wordmarks**, not translation units"* — so a mode label costs no catalogue key.

**A barred key says nothing about why.** No hint, no announcement, no "unlock by…". §12.4:
*"The bar idiom carries the whole message; there is no text explaining it."* That holds in audio
too, or the wordless design is a lie told only to sighted players.

## Reduce Motion

**No sigil animates, ever.** Under normal motion the only movement near a mode sigil is the key's
own: the suspended arc filling, and the reveal's beat-0 bar retraction (§13.7.1). Both belong to
`hunch-motion-and-feedback`.

The facet bar's mode stamp cycles PROBE → DRIFT → ECHO → SIEVE → off on tap. Under
`isReduceMotionEnabled` that swap is instant, wrapped in §13.7.4's default crossfade; at normal
motion it is the same crossfade at `dur.crossfade`. Either way nothing translates, scales or
rotates, so the substitution table needs no new row.

## High Contrast, Bold Text, Differentiate Without Colour

- **High Contrast** — no `hue.*` substitution applies (a sigil has none). Every role takes the
  flat `+0.5 pt`, applied *after* Bold Text's `×1.25`; `hunch-design-tokens/SKILL.md` owns the
  order. Both inks resolve to their High Contrast values above the state-bearing floor;
  `hunch-design-tokens/references/palette.md` §1 is the measured column and the only place those
  ratios are written down.
- **Bold Text** — all four roles respond. The densest a sigil ever gets is `verb` at the smallest
  site with Bold Text and High Contrast both on, and it is why `inkMax` is 0.34 rather than
  something more generous. The harness measures it; do not restate the resolved weight here,
  because it is `weight.*` × the resolution ladder and both belong to `hunch-design-tokens`.
- **Differentiate Without Colour** — true by construction: idle-versus-lit is a luminance step
  and every state above is also a geometry or opacity change. The barred bar is the only accent
  in the set and its meaning is carried by the bar, not by `accent.cold`.

## What would be wrong

- **Redrawing `mode.probe`.** It is shipped in the mockup. Change it and the two diverge with
  nothing to catch it.
- **Restating §9.10's unlock gates here.** They live in §9.10; §12.4 renders them. A second copy
  will be wrong the first time a gate moves.
- **Re-enumerating the rack key's states in this file.** `KeyState` has one home,
  `hunch-chrome-and-meta/references/key.md` §3. A second list is how `depictive` gets mistaken for
  a case and `disabled` gets dropped.
- **Letting the suspended arc into the sigil box.** It is the key's border. Inside the box it
  becomes part of the drawing, and then `mode.probe` has two drawings.
- **Giving a barred key a VoiceOver hint explaining the gate.** §12.4 is explicit that the bar
  carries the whole message.
- **Making the sigil change shape when lit.** Colour steps; geometry does not.
- **Adding a fifth mode sigil without a mode.** The four are `enum Mode` (§2), and the facet
  stamp's off state is `facet.mode.off`, which lives in `codex-facet-stamps.md`.
