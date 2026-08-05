# codex-page.md — the three-register page composite

Owning symbol: `CodexFeature/CodexPageView.swift` → `struct CodexPageView: View`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row D, *Codex page composite*.

Contents: [1 The band layout](#1-the-band-layout) · [2 Register 1 — the law at 0.78×](#2-register-1--the-law-at-078) ·
[3 Register 2 — the Assay](#3-register-2--the-assay) · [4 Register 3 — the instrument strip](#4-register-3--the-instrument-strip) ·
[5 The find log](#5-the-find-log) · [6 The four states](#6-the-four-states) · [7 Navigation](#7-navigation) ·
[8 Screenshot-clean](#8-screenshot-clean) · [9 VoiceOver](#9-voiceover) · [10 Environment behaviour](#10-environment-behaviour) ·
[11 Wrong](#11-wrong)

A page is **one law, identified by its extension** — one law, one page, forever (§11.1, §3.6). The
view is a composite: it draws almost nothing itself and composes four components that other skills
own. Its job is the band layout, the 0.78× scale, and the read-only contract.

---

## 1. The band layout

`CodexPageView`, 375 × 667 reference device (§11.2):

| Region | y | Height | Contents |
|---|---|---|---|
| instrument bar | 20–64 | 44 | back (leading) · — · play key (trailing). **No title** — a page is titled by its law (§12.9) |
| rule-tiles | 64–316 | 252 | register 1 |
| Assay | 316–472 | 156 | register 2, a 152 pt square with 2 pt each side |
| instrument strip | 472–540 | 68 | register 3 |
| find log | 540–620 | 80 | up to 5 re-strike rings, each tappable for its date |
| prev / next | 620–667 | 47 | a fixed band, not an overlay — §8 |

The bar's height is resolved, not constant (`instrument-bar.md` §2); every region below is laid out
relative to it. This page has no title, so at Large it is exactly 44 — but the play key still grows
under nothing and the safe area differs on a Pro Max, so read it rather than assume it.

---

## 2. Register 1 — the law at 0.78×

The law in the Bench's own rule-tile grammar — Ramp / Bridge / Fork / Tally, coupler, ghost toggle,
wedge — laid out by the same `BenchLayout(law)` that G10 already guarantees round-trips (§11.1). The
player learns nothing new: it is the widget they declared with.

`C.CodexPage.tileScale = 0.78`. §11.1 gives the check: the live Bench's 291 pt rails become 227 pt
(`291 × 0.78 = 226.98`).

**Scale lengths; never scale weights.** A `weight.thin` rule-tile frame at 0.78× is 0.78 pt — below
the hairline, and it disappears. The rule is the same one `render-env.md` states for `artScale`:
weight has its own axis (Bold Text, High Contrast) and a second multiplier compounds them. So the
tile geometry takes the 0.78 factor and `env.weight(_:)` is read unmodified.

**Read-only, absolutely.** No cell responds to touch, there is no Seal and there is no palette
(§11.1). The tile views take their `read-only` state, which is
`hunch-bench-instruments/references/rule-tile.md`'s — this file composes them, it does not draw them.
A page whose cells respond to touch would let a player edit an archived law, which is not a feature
with a missing confirmation; it is a category error.

---

## 3. Register 2 — the Assay

The law's full extension at **9.5 pt cells, 152 × 152 pt** (§11.1) — `hunch-bench-instruments/references/assay-grid.md`
owns the drawing, in its `read-only` state.

For a **contextual** law (bands 5, 7) it shows the marginal projection with a draggable ghost
thumbnail; dragging pins `prev` and the constellation morphs (§11.1). Same widget the player used to
declare, so nothing new is learned. The drag is the one gesture on this screen and it has a
non-gesture route: the ghost thumbnail is also a `.adjustable` accessibility element (§9).

**Never bloomed.** The Assay is excluded from bloom passes A and B at every size and in every state
(PHOSPHOR §2, §13.5).

---

## 4. Register 3 — the instrument strip

Everything §11.1 lists, in one 68 pt band. Every element is a shared mark or a sigil; this file owns
their order and their spacing, nothing else.

| Element | Drawing | Owner |
|---|---|---|
| `bestProbes` as a tick row against the band's `par` | tick row, length-proportional | `hunch-shared-marks/references/tick-row.md` |
| the mono numeral beside it | `type.numeral` | `numeral-readout.md` site 1 |
| Seal marks, 1–3 | pips | `hunch-bench-instruments/references/seal.md` |
| the **fracture** hairline across the rim, if `unfractured == false` | `weight.thin` `accent.cold` diagonal | PHOSPHOR §3 |
| the mode sigil | one of four | `hunch-sigil-drawing/references/mode-sigils.md` |
| a band notch | notch | this file |
| the **anomaly seal** — a doubled rim arc — if `anomalyDay != nil` | arc | `hunch-shared-marks/references/arc-meter.md` |
| the find date | `Date.FormatStyle(.dateTime.year().month().day())` | `numeral-readout.md` site 2 |

`par` is canon's `7 / 13 / 16 / 20 / 23 / 23 / 26 / 29` and lives in `Band.par`, in `HunchCore`. It is
not a constant in a view.

**Re-finding a fractured page clean heals the fracture** (§11.1): `unfractured` latches true and the
crack is not drawn. There is no "was fractured" trace, and a scar that persisted would contradict the
improvement loop.

**A band notch is not a band number.** §10.5 forbids surfacing a numeric difficulty; a notch at one of
eight positions is a position in a family ladder, which §11.9 says the Codex is allowed to carry *as
history*. Never render the digit.

---

## 5. The find log

Up to five re-strike rings, each tappable for its date; a sixth find draws a single filled ring
meaning **5+** (§11.1, §11.3). The rings are `hunch-shared-marks/references/verdict-ring.md`'s
`re-strike` variant.

A **burnish** draws no ring at all. §11.3 defines it exhaustively: an ECHO round settled at 3 marks
sets `burnished = true` and ECHO's bit in `modesSeen`, and touches nothing else — *"it is therefore
not a re-find and draws no re-strike ring."* Its render is register 1's brass stroke (§6). Drawing a
ring for a burnish would claim a find that did not happen.

Each ring is its own 44 pt target and its own accessibility element with the date as its value.

---

## 6. The four states

| State | Render |
|---|---|
| **live-inscribing** | the Inscription's reveal is drawing the page — §13.7.1 beat 7 strokes the page frame from the top-leading corner clockwise, and beat 5 docks the Assay thumbnail. Every beat's duration and easing is `hunch-motion-and-feedback/references/reveal-beats.md`'s; this file owns only *which* geometry each beat touches |
| **settled** | the resting page |
| **burnished** | register 1's strokes draw in `accent.brass` rather than `stroke.primary` |
| **fractured** | the fracture hairline across the strip's rim |

**The burnished page is the app's one sanctioned exception to accent rationing.** §13.1 rations
accent to three elements per screen, and a burnish paints every tile stroke in register 1. It is
legitimate here because the burnish *is* the page's meaning and there is no competing accent on the
screen — no Seal, no verdict ring, no streak, no minted-page key. Say so at the call site, because
the next reader will otherwise assume it is a bug.

The brass is the same brass the reveal's registration beat steps the tiles to (§13.7.1 beat 4), so
the state is already learned by the time a page is first seen burnished.

---

## 7. Navigation

- **Horizontal swipe steps to the adjacent slot in canonical order, including empty slots on
  slot-map shelves** (§11.2). Walking past the holes is the point — an empty slot draws its dashed
  socket and its narration says "empty slot" (`extension-thumbnail.md` §4).
- Back returns to `CodexShelfView`; the play key resumes or starts a round (§12.3).
- No other gesture. No pinch-to-zoom on the Assay — expansion is `AssayInspectorView`'s job on the
  Bench, and a page is already at reading size.

---

## 8. Screenshot-clean

§11.5 decides there is **no share sheet, no share card, no image composer, no
`UIActivityViewController` and no deep link** — and no export either. The stated substitute is that
*"`CodexPageView` is therefore composed to be screenshot-clean — full-bleed, no floating chrome, no
modal, no transient overlay."*

That is a layout constraint, not a sentiment:

- the prev/next affordance is a **fixed band** at `y 620–667`, never a floating overlay;
- nothing animates in or out on top of the page after it settles — no toast, no badge, no "copied"
  confirmation;
- the instrument bar is opaque and part of the composition, not a translucent bar over content;
- the page fills the safe area edge to edge.

---

## 9. VoiceOver

- **The page container's value is the `LawNarrator` sentence.** §13.10 requires it to use the same
  String Catalog fragments as the Bench narration, *"so a narrated law and a rendered law are the
  same law in two media"*, and the 10,000-law parity test asserts it.
- Register 1's tiles are read-only, so they are `.staticText` inside a container, not buttons. Do not
  leave them focusable as buttons that do nothing.
- The Assay keeps its custom actions: **"Inspect"** and **"Read by attribute"** — the latter speaks
  the sixteen marginals as one interruptible announcement instead of exposing 256 cells (§13.10).
- The contextual ghost thumbnail is `.adjustable`; swipe up/down steps `prev`, which is the
  non-gesture route for the drag in §3.
- Each find-log ring is a `.button` with its date as the value.
- `.headings` rotor covers the Codex (§13.10); the page's registers carry `.isHeader` on their strip
  labels where they have one.
- §12.9 budgets no control labels specifically for the page beyond the Codex shelf's three and the
  Assay's three — which is only survivable because the page's identity is the *narration*, generated
  from the AST rather than stored as strings.

---

## 10. Environment behaviour

| Setting | Effect |
|---|---|
| **Reduce Motion** | swipe to an adjacent slot becomes a `Dur.crossfade` crossfade, and so does the shared-element arrival from the Inscription; the Assay's contextual morph switches cells instantly with a `Dur.micro` crossfade of the whole grid (§13.7.4, `hunch-motion-and-feedback/references/reduce-motion.md`) |
| **High Contrast** | `accent.brass` and `accent.cold` both clear the state-bearing floor in the High Contrast column (`hunch-design-tokens/references/palette.md` §1). The fracture is *geometry first* (a break in the rim), so it survives greyscale and Differentiate Without Color with no substitution |
| **Bold Text** | every weight steps through `env.weight(_:)`; the 0.78× factor never touches them (§2) |
| **Dynamic Type** | **rule-tiles freeze at the art ceiling — `env.artScale`, clamped at `Prim.artScaleCeiling` — and metadata scrolls below** (§13.11). Branch on `env.isArtScaleClamped`, never on the number (`render-env.md` §3). The Assay and the thumbnail hold their geometry — they are pictures, not text |
| **Reduce Transparency** | nothing on the page is a material. Bloom is already excluded from the Assay |
| **RTL** | the page's chrome mirrors; **the plate's internal rule-tile layout does not** — it is the law's rendering, and §12.8 lists it under "does not mirror, in any locale" |

---

## 11. Wrong

- **An interactive cell, a Seal, or a palette on a page.** §11.1: read-only.
- **Scaling stroke weights by 0.78.** §2.
- **A floating share, export or "add to favourites" control.** §11.5 and §8. There is nothing to
  favourite either — a page cannot be ranked.
- **A re-strike ring for a burnish.** §5.
- **A band number, a rarity tier, a percentage of the shelf, or a global completion figure.** §10.5,
  §11.2, §11.4.
- **An "already collected" state, dust, or converting a duplicate into anything.** §11.3.
- **Storing or rendering the truth table instead of the AST.** A contextual table is 8 KiB and an AST
  is ~40 B (§11.1); the Assay rebuilds the table on open, in ~2 µs.
- **Keying a DRIFT page on anything but `L₂`.** `driftPartner` and `driftHinge` are payload, never
  identity — otherwise the same law behind two dead laws mints two pages and §11.2's premise breaks
  (§11.1).
- **A title.** §12.9: a page is titled by its law.
- **Drawing a rule-tile, an Assay, a tick row or a verdict ring here.** Every one has an owner listed
  above; this view composes.
