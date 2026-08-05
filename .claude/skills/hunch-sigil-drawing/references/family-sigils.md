# The eight family sigils, and the skeleton silhouettes

`family.literal` · `family.pair` · `family.exclusive` · `family.relational` ·
`family.contextual` · `family.guarded` · `family.composite` · `family.systemic`.

Scope §2(e) lists these as **undrawn**, together with "the skeleton silhouettes". This file draws
them, and unifies the two so there are not 300 drawings to keep consistent.
Coordinates: `../scripts/check-sigil-distinctness.js` → `SIGILS`.

1. [The unification: one drawing, two levels of detail](#the-unification-one-drawing-two-levels-of-detail)
2. [The eight drawings](#the-eight-drawings)
3. [Skeleton detail](#skeleton-detail)
4. [Sites and states](#sites-and-states)
5. [VoiceOver](#voiceover)
6. [Reduce Motion, High Contrast, Bold Text](#reduce-motion-high-contrast-bold-text)
7. [What would be wrong](#what-would-be-wrong)

---

## The unification: one drawing, two levels of detail

§11.2 defines a skeleton as *"the tile silhouette — 'Bridge with a ghosted leading socket',
'Fork on a hue gate', 'two Ramps under a crossed coupler'"*, drawn at 24 pt in the leading margin
of a shelf sub-section. That is the same object as a family sigil with the structural variables
filled in.

**Ruling: a family sigil is the most reduced skeleton of its family; a skeleton silhouette is the
same drawing with that skeleton's variables bound.** One function, one parameter:

```swift
enum SigilDetail { case family, skeleton(SkeletonSpec) }

/// The context is taken by value, not `inout`, and the box side is `side`, not `U` — one drawing
/// function, the same shape every mark in the app uses (`hunch-shared-marks/references/ownership.md` §3).
func familySigil(_ band: Band, detail: SigilDetail, into context: GraphicsContext, side: CGFloat)
```

Why it matters: large shelves get 10–40 sections (§11.2), so the alternative is roughly 200
hand-cut silhouettes that must all still look like their shelf six months on. They cannot, and
nothing would notice. With one parameterised drawing there is exactly one thing to keep right.

The second consequence is free and load-bearing: a shelf's plate sigil and its section dividers
are visibly the same mark at two resolutions, so the divider reads as *"this section, inside this
family"* without a word.

## The eight drawings

Each sigil diagrams §5.2's **"conceptual move the family demands"** — not the syntax, the move.
That column of §5.2 is the design brief, quoted here and nowhere restated.

| Key | Band | §5.2's move | Verb | Drawing |
|---|---|---|---|---|
| `family.literal` | 1 | "one thing matters" | `one` | blank `notch` + one `ladder`, exactly one cell lit |
| `family.pair` | 2 | "two things matter at once" | `and` | two stacked `notch`+`ladder` rows, both lit high, joined by `couplerAnd` — the welded bar |
| `family.exclusive` | 3 | "truth is not monotone in any attribute" | `cross` | the same two rows with **complementary** lit patterns, joined by `couplerXor` — the crossed strands |
| `family.relational` | 4 | "the law names no value" | `compare` | two sockets, each holding a blank `notch`, a `wedge` between them. **No cell is lit anywhere** |
| `family.contextual` | 5 | "a glyph has no verdict by itself" | `compare-back` | the same bridge with the trailing socket as `ghostPlate`, plus a `linkArc` beneath joining the two — two glyphs, not one |
| `family.guarded` | 6 | "the law is piecewise; your theory has a region" | `split` | a filled gate cell above a `fork`: one line splitting into a lit upper track and a dim lower track |
| `family.composite` | 7 | "hold two of the above at once" | `and-unlike` | a reduced bridge on the upper rail, a `ladder` on the lower, joined by `couplerOpen` — the hollow node, because band 7 fixes no coupler |
| `family.systemic` | 8 | "no attribute is privileged" | `count` | four `notch`es in a column under one vertical tie bar, feeding one shared rank `ladder` |

Four of these carry a design decision worth stating, because each is the reason the sigil is
*true* rather than merely different:

- **`family.exclusive`'s complementary lit pattern is a theorem, not decoration.** §5.2: band 3
  *"is exactly the XOR of two 2-element subsets on distinct attributes"*, and that is what makes
  all sixteen marginals equal. Two 2-cell subsets, drawn opposed, is the family.
- **`family.relational` lights nothing.** *"The law names no value"* is the entire move; a lit
  cell would contradict the sigil's own caption.
- **`family.contextual` takes the link arc** because §4.5 says a contextual counterexample *"is
  two glyphs joined by the link arc"*. Without it, CONTEXTUAL is RELATIONAL with a dashed socket,
  and the harness confirms that is the thinnest margin in the set.
- **`family.systemic`'s tie bar is the sigil.** Every aggregate names an *attribute set*, never
  an attribute (§5.2's symmetry theorem), so the bracket over all four is the family and the
  ladder is incidental.

**`family.pair` and `family.exclusive` are the closest pair in the whole library.** The harness
prints them first in its `closest pairs` list with the live margin against `T`; read the margin
there rather than from a sentence that goes stale the next time either drawing moves. Any change
to either goes through the harness.

## Skeleton detail

`detail: .skeleton(spec)` binds what `.family` leaves blank. Nothing is added; blanks are filled.

| Element | `.family` | `.skeleton` |
|---|---|---|
| `notch` | empty rect | the attribute's own header drawing — §4.1: *"The ramp is a picture of its own attribute"*. Owned by `hunch-bench-instruments/references/attribute-header.md` |
| `ladder` lit cells | the family's canonical pattern above | the skeleton's actual subset |
| `wedge` | the generic leading-opening wedge | the actual comparator of the six |
| `couplerOpen` | hollow node | the actual `and` / `or` / `xor` drawing |
| `ghostPlate` | present iff the family is contextual | unchanged |

Band 1's four sections then differ **only by the header** (§11.2: *"band 1 gets four sections,
one per attribute"*), which is correct: at band 1 the attribute *is* the skeleton.

`skeleton: UInt16` on `CodexPage` (§11.1) is the index into the family's skeleton list; the map
from index to `SkeletonSpec` is the generator's (§5.3 step 3), not this skill's. **Do not
enumerate skeletons here.**

## Sites and states

`sites: [24, 44]`. Three sites, all in the Codex (§11.2):

| Site | U | Detail | State |
|---|---|---|---|
| shelf plate, leading (`CodexRootView`) | 44 | `.family` | idle · lit when sealed |
| shelf instrument bar (`CodexShelfView`) | 24 | `.family` | depictive |
| skeleton divider, leading margin of a section | 24 | `.skeleton` | depictive |

A **sealed** shelf takes a doubled rim on the plate (§11.2) — that is the plate's drawing, owned
by `hunch-chrome-and-meta/references/shelf-plate.md`, not the sigil's. The sigil lights to
`stroke.primary`; it does not gain a rim.

An **empty** Codex draws one dashed plate and nothing else (§12.2). No family sigil is drawn on
it — an empty shelf has no family to name yet.

## VoiceOver

The shelf plate is the control; **the family sigil is not separately focusable**. §12.9 budgets
`CodexRootView` at six VoiceOver control labels for eight plates plus five facets plus back and
play, so the plates share one format string with the existing `band` value format (§12.9's
"value formats (probes-of-par, marks, band, streak)").

| Element | Traits | Label | Value |
|---|---|---|---|
| shelf plate | `.button` | the shared shelf format, band interpolated | pages held, and "sealed" when sealed |
| shelf instrument bar sigil | `.image` | merged into the bar's label | — |
| skeleton divider | `.staticText`, `.isHeader` | reached by the `.headings` rotor (§13.10) | — |

**The eight family names — LITERAL, PAIR, EXCLUSIVE, RELATIONAL, CONTEXTUAL, GUARDED, COMPOSITE,
SYSTEMIC — are never spoken and never enter `Localizable.xcstrings`.** They are internal
identifiers, exactly like the five Profile axis names (§11.11 P3), and §12.9's inventory does not
budget them. §12.9 is explicit that *"`CodexShelfView` and `CodexPageView` have none — a shelf is
titled by its family sigil"*.

## Reduce Motion, High Contrast, Bold Text

- **Reduce Motion** — nothing to substitute; no family sigil moves at any time. The shelf plate's
  fill arc animates on inscription and belongs to `hunch-motion-and-feedback`.
- **High Contrast** — flat `+0.5 pt` on every role after Bold Text's `×1.25`. The `ghost` role at
  `weight.hairline` is the risk: it is the lightest weight on the ladder and it must stay clearly
  under `contour` once both settings resolve. The ratio holds at every shipped `U`; the weights
  are `hunch-design-tokens`' and the resolved numbers are not written down here.
  `stroke.hairline` is *never state-bearing* (`palette.md`), which is why `ghost` only ever draws
  the dim track, the dash and the cell separators.
- **A lit ladder cell is fill-versus-empty, never opacity.** Whatever treatment a *live* ramp cell
  takes when unlit is `hunch-bench-instruments/references/ramp.md`'s and is not this skill's to
  quote. A sigil's cells are depictive, so they use full ink versus none — two channels, no hatch,
  legible at the smallest site where a hatch is not.
- **Bold Text** — all roles respond, as everywhere.

## What would be wrong

- **Drawing a family sigil that depicts the family's *example law*** from §5.2's table. The
  example is one member; the sigil is the family. `fill ∈ {striped}` would put a stripe texture
  in `family.literal`, and then band 1's shelf would be about fill.
- **Cutting skeleton silhouettes as separate art.** One drawing, two detail levels, or the
  divider and the plate drift apart.
- **Enumerating the 10–40 skeletons of a shelf here.** The generator owns the list (§5.3).
- **Lighting a cell in `family.relational`.** It contradicts the family's own move.
- **Speaking or translating a family name.** They are identifiers; §12.9 budgets no key for them.
- **Giving `family.composite` a resolved coupler.** The hollow node means "unresolved", and it is
  the only thing separating COMPOSITE from PAIR at the silhouette level.
- **Using `hue.*` for the four attributes** in a skeleton's headers. The header is the ramp's own
  drawing and is chrome; the attribute is carried by its shape, not by a colour.
