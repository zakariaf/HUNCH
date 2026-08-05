# shelf-plate.md — the eight plates of `CodexRootView`

Owning symbol: `CodexFeature/ShelfPlate.swift` → `struct ShelfPlate: View`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row D, *Shelf plate*.

Contents: [1 Geometry](#1-geometry) · [2 The four states](#2-the-four-states) · [3 Interaction](#3-interaction) ·
[4 VoiceOver](#4-voiceover) · [5 Environment behaviour](#5-environment-behaviour) · [6 Wrong](#6-wrong)

---

## 1. Geometry

Eight plates, one per band, at `y 64–624` on the 375 × 667 reference device: **64 pt each with a 6 pt
gutter after it** — `8 × 64 + 8 × 6 = 560`, and `64 + 560 = 624` (§11.2). The facet bar occupies
`624–667`.

Each plate is the 343 pt content column (`space.columnContent`), inset `space.marginOuter` on both
sides, at `Radius.chrome`, filled `ground.raised`, framed `env.weight(.hairline)` in
`stroke.hairline`, with a rule inset 16 both sides beneath it (`rules-and-boundaries.md`).

Contents, leading to trailing (§11.2):

```
16 │ [ 44 family sigil ] │ [ 3 pt fill arc, flexible ] │ [ 40 ][ 40 ][ 40 ][ 40 ] │ 16
   └─ 44 ────────────────┴─ 127 ──────────────────────┴─ 172 ───────────────────┘
```

The trailing block is four 40 pt thumbnails with 4 pt gutters: `4 × 40 + 3 × 4 = 172`. That leaves
`343 − 44 − 172 = 127` pt for the fill arc and its air. The arc is 3 pt thick (§11.2) and its length
is the plate's own layout decision; the four thumbnails are pinned to the trailing edge so they line
up down the column of eight plates, which is what makes the recents read as a strip.

**The plate is 64 pt and textless.** PHOSPHOR §3 sketches a 72 pt plate with a family/band label, a
title and a date line — that sketch is **superseded**. §11.2's browse hierarchy is textless by
construction, and §12.9 confirms `CodexShelfView` and `CodexPageView` carry no title at all: *"a
shelf is titled by its family sigil and a page by its law."* PHOSPHOR's 72 pt row is a *page*-shaped
object that does not exist in canon's hierarchy — the page-level object is the 60 pt thumbnail in the
shelf grid (`extension-thumbnail.md`).

What survives from PHOSPHOR §3 is the **accent rationing rule**, which is real and easy to violate:
*in a list the brass belongs to at most one plate — the one just inscribed; every other plate draws
its marks in `stroke.primary`.* Eight brass plates would spend the whole screen's accent budget
(§13.1: three elements) on a list.

---

## 2. The four states

| State | Render | When |
|---|---|---|
| **empty** | **one** dashed plate, and nothing else on the screen | zero pages held, anywhere (§12.2) |
| **accretion** | log-scaled fill arc with inscribed notches | bands 2, 4, 5, 6, 7 — `\|H\| > 512` |
| **sealable** | linear fill arc | bands 1 (40), 3 (108), 8 (337) — `\|H\| ≤ 512` |
| **sealed** | doubled rim | a sealable shelf, complete |

**The empty Codex draws one dashed plate, not eight.** §12.2: *"The Codex with zero pages draws one
dashed plate and nothing else."* No empty-state copy, no illustration, no "start playing" prompt —
the app has no empty-state copy anywhere by decision.

**The arc scale is decided by `|H| ≤ 512`, the same threshold that decides slot maps** (§11.4), and
deliberately so: the shelves whose holes you can see are exactly the shelves the serving layer tries
to fill (§11.3). Linear where a terminal state is reachable; log-scaled where it is not, so an
accretion shelf's early progress is visible instead of a flat line:

```
linear  : fill = n / |H|
log     : fill = log2(1 + n) / log2(1 + |H|)     with notches at n ∈ {8, 32, 128, 512, 2048, 8192}
```

Both are §11.4's, verbatim. The arc itself is
`hunch-shared-marks/references/arc-meter.md` — this file owns only which scale and where the notches
sit.

`|H|` per band is canon's `40 / 1,272 / 108 / 2,322 / 6,934 / 5,688 / 10,314 / 337` (§11.4), and it
belongs to `HunchCore`'s `Band.population`, not to a constant in a view.

---

## 3. Interaction

The whole 343 × 64 plate is **one** target — far above the 44 pt minimum — and tapping it opens
`CodexShelfView`. Consequences:

- The four 40 pt thumbnails are **depictive, never tappable**. That is the only reason a 40 pt
  drawing is legal here: it is not an independent target, so §12.8's 44 pt floor does not apply to
  it. Making one tappable would put a 40 pt target on screen and fail §13.12 gate 8.
- The family sigil and the fill arc are likewise depictive.
- No swipe action, no context menu, no long-press. §12.8 rules all three out.

---

## 4. VoiceOver

One element per plate, `.isButton`, with the shelf's family spoken as its label and its fill as its
value.

**Speaking a family name is permitted; speaking a band number is not.** §10.5 forbids surfacing a
numeric difficulty and §12.9 removes the "highest band" row from the Profile for exactly that reason.
A family is a conceptual move, not a level, and §11.9 is explicit that the Codex shelves are where
that fact lives *"as history rather than a level"*. So: "Relational" — never "Band 4".

| Element | Trait | Label | Value |
|---|---|---|---|
| plate | `.isButton` | the family | "12 of 108 found", plus "sealed" when sealed |
| empty plate | `.isButton`, `.notEnabled` | the empty-shelf label | — |

§12.9 budgets **6** control labels for the Codex root against 8 plates + 5 facet stamps + back + play
key. That works out only if the plate label is *one format string* interpolating the family and the
five facet stamps carry the rest. Numbers in a value are audio-only and are free of the no-text rule
(§13.10) — but they still go through a plural-aware String Catalog entry, never concatenation
(§12.9 trap 3).

---

## 5. Environment behaviour

| Setting | Effect |
|---|---|
| **Reduce Motion** | the fill arc never animates on the root. A newly minted page arrives from the Inscription as a shared element at `Dur.shared`, which becomes a `Dur.crossfade` crossfade (§13.7.4) |
| **High Contrast** | the frame picks up the flat weight offset and `stroke.hairline`'s High Contrast ratio (`dimensions-strokes-opacity.md` §2, `palette.md` §1); the sealed rim is doubled *geometry*, so it survives unchanged. No substitution of its own |
| **Bold Text** | frame and arc weights step through `env.weight(_:)`. Nothing branches |
| **Differentiate Without Color** | no effect — the plate carries no colour-encoded state. Sealed is a doubled rim, fill is an arc extent, the fracture is a diagonal |
| **Dynamic Type** | the plate is a **drawing**; it holds 64 pt at every size. The family sigil and thumbnails hold theirs. §13.11: *"the glyph thumbnail is fixed at 44 pt and never scales (it is a picture, not text)"* — the same reasoning applies to the whole plate |
| **RTL** | the plate mirrors: sigil trailing, thumbnails leading, reading order reversed (§12.8, "Codex grid reading order" mirrors) |

---

## 6. Wrong

- **Eight dashed plates on an empty Codex.** One. §2.
- **A textual label, band number, family name or date on the plate.** §11.2 is textless by
  construction; the family name exists in VoiceOver only.
- **A global completion meter, a "0.3 % of 27,015" bar or a percentage.** §11.2: *"No global meter
  anywhere… Only per-shelf arcs exist."* A figure that is both true and useless.
- **Brass on more than one plate at a time.** §1.
- **A linear arc on an accretion shelf, or a log arc on a sealable one.** The threshold is `|H| ≤ 512`
  and it is the same threshold as the slot map — getting it wrong decouples two things that are
  deliberately coupled.
- **A tappable 40 pt thumbnail.** §3.
- **Reading PHOSPHOR §3's 72 pt plate as the spec.** §1.
- **A rarity colour, a tier badge, a "new" dot or a duplicate count.** §11.4: intrinsic rarity, no
  drops, no rarity colours, no currency. §11.3: no "already collected" state and no dust.
- **Scaling the plate with Dynamic Type.**
- **Sorting or filtering the eight plates.** Band order is fixed; the facet bar filters *within* a
  shelf, never the shelf list.
