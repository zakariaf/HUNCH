# The five Profile vertex sigils

`profile.induction` · `profile.retention` · `profile.flexibility` · `profile.restraint` ·
`profile.tempo`.

§11.11 P3 gives each one clause. Scope §2(e) lists all five as undrawn. This file draws them,
and resolves the collision P3's wording walks into.
Coordinates: `../scripts/check-sigil-distinctness.js` → `SIGILS`.

1. [P3's clause, and the problem with taking it literally](#p3s-clause-and-the-problem-with-taking-it-literally)
2. [The five drawings](#the-five-drawings)
3. [Placement is not this skill's](#placement-is-not-this-skills)
4. [VoiceOver](#voiceover)
5. [Reduce Motion](#reduce-motion)
6. [High Contrast, Bold Text, Dynamic Type](#high-contrast-bold-text-dynamic-type)
7. [What would be wrong](#what-would-be-wrong)

---

## P3's clause, and the problem with taking it literally

> **P3** … Each vertex carries a small vector sigil drawn from the game's existing vocabulary:
> Induction = a ramp silhouette, Retention = a link arc, Flexibility = the Fork's railway switch,
> Restraint = the Seal's bar, Tempo = a tick strip. — §11.11

Four of those five are **bare quotes of marks that already exist elsewhere in the app**: the link
arc, the machined bar and the tick row are three of the eight shared idioms in
`hunch-shared-marks`, and "a ramp silhouette" is `family.literal`'s entire drawing. Drawn bare,
`profile.restraint` *is* the machined bar and `profile.induction` *is* the band-1 family sigil.
That is `sigil-grammar.md`'s rule G4 stated as a concrete failure, and the harness catches it.

**Ruling — the vertex modifier.** Every Profile vertex sigil is drawn with its quoted idiom
**rotated to that vertex's own locked angle** from §11.10:

| Vertex | θ (§11.10, locked, clockwise from top) |
|---|---|
| Induction | −90° |
| Retention | −18° |
| Flexibility | 54° |
| Restraint | 126° |
| Tempo | 198° |

Two things follow. The five become pairwise distinct **and** distinct from their bare sources by
rotation alone — which is not a new trick, it is the mechanism the hue channel already uses
(index stroke 0° / 45° / 90° / 135°, §13.5), so the app is not learning a second idea. And the
set reads as one set: five marks at five angles around a portrait is legible as *the vertices*
before any one of them is identified.

This is a faithful reading of P3, not a departure: P3 fixes the *vocabulary* each sigil is drawn
from, and every one of the five still is exactly the idiom P3 names.

## The five drawings

| Key | P3's idiom | Verb | Drawing, before rotation |
|---|---|---|---|
| `profile.induction` | a ramp silhouette | `one` | blank `notch` + `ladder`, two adjacent cells lit — a rung climbed, matching the axis's ladder-of-bands |
| `profile.retention` | a link arc | `return` | `linkArc`: two filled nodes joined by a half-circle above them — the ribbon adjacency that says *this one came back to that one* |
| `profile.flexibility` | the Fork's railway switch | `split` | `fork` with **diagonal** branches and no gate cell: a line arriving and taking one of two ways |
| `profile.restraint` | the Seal's bar | `bar` | a `plate` with the machined `bar` lying across it, overhanging both edges — the barred Seal, held |
| `profile.tempo` | a tick strip | `count` | `tickRow`: seven ticks on a hairline baseline, four filled and three unfilled — probes against par |

Three notes on why each differs from its source rather than merely from its siblings:

- **`profile.flexibility` has no gate cell**, which is exactly what separates it from
  `family.guarded`: a guard names a gate, an axis measures how fast you leave a track. Its
  branches are diagonal where `family.guarded`'s are orthogonal.
- **`profile.restraint`'s bar overhangs the plate.** That overhang *is* the machined-bar idiom —
  a bar laid across, not a line struck through — and the plate beneath is empty, which no live
  barred control ever is.
- **`profile.tempo` carries a baseline and a filled/unfilled split**, where `facet.threeMarks` is
  three bare Seal marks at `verb` weight and no baseline. Same family, different statement.

## Placement is not this skill's

This skill owns the drawing inside the 24-unit box. **Where the box goes on the 375 × 280 card is
`hunch-chrome-and-meta/references/profile-contour.md`'s.** Three constraints that file must
honour, recorded here because they were discovered while drawing:

1. **The sigil sits at a fixed radius that does not tremble.** §11.10's tremble is an amplitude on
   the *contour's* vertex radius, expressing confidence in the value. An axis's identity does not
   have a confidence, and a trembling icon is unreadable at 24 pt.
2. **The vertex radius can leave the card.** §11.10 caps `rᵢ` at `1.55 · R0 = 148.8 pt` on a card
   whose centre is at y = 140. Induction sits at −90°, straight up, so a maximal Induction
   contour passes above the card's top edge. The sigil must not be pinned to `rᵢ`.
3. **Each sigil keeps a 44 × 44 hit rect** and, at AX3, reflows from the ring to a vertical list
   (§13.11). The rotation travels with the drawing into that list.

The spoke stub inside the sigil box is drawn as part of the sigil, coincident with §11.10's
existing spoke on the portrait and **at the portrait's own spoke opacity**, which
`hunch-chrome-and-meta/references/profile-contour.md` owns — cite it, do not copy the number. The
stub exists so the mark still reads as a vertex once the ring is gone at AX3, and it adds no ink
the portrait did not already have.

## VoiceOver

This is the one set where **the sigil is its own accessibility element** — §13.11 gives each a
44 × 44 hit rect, and §11.11 gives each an approved sentence.

| Element | Traits | Label |
|---|---|---|
| vertex sigil ×5 | `.image` (not `.button`: `ProfileView` has no primary action, §12.2) | §11.11's approved behavioural sentence, verbatim |

The five sentences are in §11.11's table. **Do not copy them into this file, into a comment, or
into `Localizable.xcstrings`.** §11.11 is explicit: the identifiers *Induction, Retention,
Flexibility, Restraint, Tempo* are internal, *"never enter `Localizable.xcstrings`"*, and that is
what makes P8's banned-lexeme grep survivable — *Retention* and *Flexibility* land on "memory"
and "ability" in several of the twelve languages, two words P8 fails the build on. §12.9 budgets
these as five accessibility keys carrying the sentences, never the names.

The sentences describe **what you did, never what you are**. A label such as "Retention: high" is
a grade, and P1–P8 exist to make grades unrepresentable.

## Reduce Motion

No vertex sigil animates, in either setting. §13.7.4's Profile row — *"Profile morph: 2.4 s
continuous morph → new shape instantly; 240 ms crossfade"* — is the contour's, and §11.10's
tremble-becomes-a-dash-pattern substitution is the contour's. The sigils sit still through both,
because their position does not depend on `rᵢ` (see above), so there is nothing to substitute and
no new row is needed in §13.7.4.

## High Contrast, Bold Text, Dynamic Type

- **High Contrast** — §11.10 substitutes the portrait's contour, fill and spoke treatment as one
  set; `hunch-chrome-and-meta/references/profile-contour.md` holds the three values. The sigils
  step `stroke.secondary` → `stroke.primary` with the contour, and **the stub follows the spokes,
  whatever they resolve to** — that coupling is the rule, not the number. Roles take the flat
  `+0.5 pt` after Bold Text's `×1.25` (`hunch-design-tokens/SKILL.md` owns the order).
- **Bold Text** — all roles respond. `profile.tempo`'s three unfilled ticks are `ghost`
  (`weight.hairline`) against filled ticks at `verb`, and the property that had to survive is that
  the two stay clearly apart once Bold Text and High Contrast have both resolved. They do at every
  shipped size. The resolved weights are `hunch-design-tokens`' arithmetic — recompute rather than
  quote: `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift`.
- **Dynamic Type** — the portrait card *"does not scale with type: it is a drawing, not text"*
  (§13.11), so `U` stays 24 up to AX2. At AX3 the ring reflows to a list and each sigil keeps its
  44 × 44 rect; `U` still does not change. Nothing inside the box scales independently.

## What would be wrong

- **Drawing the five bare, as P3's sentence reads.** Restraint would be the machined bar and
  Induction would be `family.literal`. This is the collision the whole skill exists to catch.
- **Rotating for visual balance, or dropping the rotation in the AX3 list.** The angle is the
  identity; §11.10 locks the five angles and this drawing depends on them.
- **Pinning the sigil to the trembling vertex radius**, or to `rᵢ` at all.
- **Writing the axis names anywhere a translator or a player can reach** — a label, a hint, an
  accessibility identifier, a comment in a `.strings` file. P8 is a build-failing grep.
- **Adding a numeral, a ring, a gridline or a tick scale** to the portrait to make a sigil read.
  P2 forbids all four, and a tick scale is what turns a self-portrait into a radar chart.
- **Making a sigil larger when its axis value is larger.** P1: uniform improvement is invisible;
  there is no "bigger".
- **Reusing `profile.tempo` as the Codex's 3-marks facet stamp**, or the reverse. They are two
  drawings with two verbs; `facet.threeMarks` lives in `codex-facet-stamps.md`.
