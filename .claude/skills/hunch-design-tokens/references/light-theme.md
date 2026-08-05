# light-theme.md — the light theme as a design, not a translation

Contents: [1 What changed](#1-what-changed) · [2 The keyline, measured](#2-the-keyline-measured) ·
[3 Depth by impression](#3-depth-by-impression) · [4 No bed, no scanline](#4-no-bed-no-scanline) ·
[5 What the paper ground buys](#5-what-the-paper-ground-buys) ·
[6 Grafted, and rejected](#6-grafted-and-rejected) · [7 What does not change](#7-what-does-not-change)

Hexes and ratios are in `palette.md` §1 and are not repeated here. This file owns the *rules* that
make the light theme behave differently from the dark one, and the arithmetic behind each.

---

## 1. What changed

PHOSPHOR's own honest weakness list names the problem: *"the light theme is a translation of
PHOSPHOR, not a design in its own right… a player who lives in the light theme never sees this
direction at all."* Three concrete failures follow from treating it as an inversion:

1. **Depth vanishes.** PHOSPHOR's entire depth system is a ground step plus a hairline. Measured,
   the light steps are 1.07 (`raised`) and 1.10 (`sunken`) and the hairline is **1.38 : 1** — not
   §13.2's claimed 1.5. Under 400 nits of glare all three are gone and the app is one flat sheet.
2. **The accent stops being rationed and starts being invisible.** `accent.brass` on paper is
   4.96 : 1 against 7.20 : 1 on soot. It still clears every gate, but it no longer *glows*, and a
   direction whose thesis is "the marks glow, the chrome does not" has lost its verb.
3. **Bloom inverts.** A blurred bright mark on a bright ground is not light; it is a printing fault.

The graft takes PLATE's *design thinking* — a warm paper ground, depth by **impression**, no bed
layer, no scanline — and PLATE's *arithmetic rigour*, while Okabe–Ito stays verbatim and the ground
stays canon's `#F4EFE4`. The result is a second exposure of one artefact, not a second artefact.

---

## 2. The keyline, measured

§13.2's † decision: in the light theme every glyph carries a `stroke.primary` keyline at
`bodyWeight + 1.0 pt` beneath the hue stroke. Canon asserts the outcome ("15.6 : 1") and stops.
Here is the whole arithmetic, computed:

| Quantity | Measured | Why it is the number that matters |
|---|---|---|
| `glyph.keyline` vs `ground.base` | **15.58 : 1** | the silhouette is state-bearing (`shape` = corner count) and must clear 3 : 1 at every size. It clears it 5.2×. |
| raw hue vs `ground.base` | 1.96 / 2.98 / 2.01 / 2.67 | below 3 : 1 — and that is *correct*, because the index stroke is the hue channel and colour is the redundant copy. Raw hue contrast is decorative. |
| **hue vs keyline** | **7.93 / 5.22 / 7.74 / 5.84** | *not in canon.* The hue must read as a distinct band **inside** the ink outline, or the keyline swallows the pigment and the light theme becomes monochrome by accident. Worst case teal at 5.22 : 1. |

**The rule.** `keylineWeight = resolvedBodyWeight + 1.0` — derived from the already-resolved weight
(stage 4 of the resolution order), so the keyline shows exactly 0.5 pt on each side of the hue at
every setting. Under Bold Text that is `3.0 × 1.25 + 1.0 = 4.75`, not `(3.0 + 1.0) × 1.25 = 5.0`;
the +1.0 is a geometric relationship, never a weight token, and it is never itself multiplied.

**Where the keyline is drawn, and where it is not.** Light theme only. Dark needs none — worst hue
is teal at 5.78 : 1. High Contrast needs none — `hue.*` is already `stroke.primary`, so a keyline
would be an invisible stroke under an identical stroke. `Palette.glyphKeyline` is `nil` in both, so
the renderer branches on `nil`, never on `theme`.

---

## 3. Depth by impression

**Rule: in the light theme a panel is pressed into the sheet; it does not float above it.**
`env.isImpressionDepthEnabled` is the predicate; never branch on `theme` at a call site.

The reasoning is arithmetic, and it is the same argument PHOSPHOR makes against itself in weakness
1 — a 1.03–1.10 : 1 ground step is at or below the visible threshold on many panels below 30 %
brightness, is destroyed by auto-dimming, and is simply absent under glare. On a dark ground a
hairline at 1.61 : 1 rescues it. On paper the hairline is **1.38 : 1**, which rescues nothing.

The impression replaces one weak cue with four concentric ones, none of which depends on a
luminance step surviving:

| Token | Value | Role |
|---|---|---|
| `opacity.impressionOuter` | 1.00 | the platemark edge — the only line that must survive glare |
| `opacity.impressionMid` | 0.55 | first bevel |
| `opacity.impressionInner` | 0.30 | second bevel |
| `opacity.impressionFaint` | 0.14 | innermost bevel; the cue that reads as *depth* rather than as a frame |

All four paint `stroke.hairline`; the interior steps to `ground.sunken`. **The geometry — stroke
weights, the 1 / 2 / 3 pt insets, the corner registration crosses — is component geometry and
belongs to `hunch-chrome-and-meta`.** This file owns only the opacity ladder and the rule.

Still forbidden in both themes, unchanged from §13.1: shadows, elevation, `.ultraThinMaterial` as a
primary surface, and rounded-rect cards. An impression is a *drawn* depth cue in four vector calls,
not a material.

---

## 4. No bed, no scanline

Two passes are switched off in light, and both have predicates so no call site decides:

- **`env.isBloomBedEnabled` is false in light.** Pass A — the blurred clone of a whole
  glyph-bearing region — is dark-only. It is also the only offscreen layer in the app, so the light
  theme costs three fewer `drawLayer` passes per frame. Pass B, the widened low-opacity halo, stays
  on: it is a hard-edged ink spread, not a glow, and it reads correctly on paper.
- **`env.isScanlineEnabled` is false in light.** §13.6's `scan` term goes to zero; grain and
  vignette stay. A scanline is a CRT artefact and belongs to a dark room; on paper it is a printing
  defect nobody asked for, and it is also the single most trope-laden element PHOSPHOR carries.

Both remain false under Reduce Transparency, High Contrast and Low Power, as before. The light
theme narrows the shader; it does not fork it.

---

## 5. What the paper ground buys

`fill` rank order is claimed by §13.5 to hold "identically at every size". Across *different hues*
it does not, on either ground. Cross-hue ΔL\* margin between adjacent fill ranks, ink optically
mixed on the ground, Okabe–Ito verbatim:

| Ground | hollow→dotted | **dotted→striped** | striped→solid |
|---|---|---|---|
| dark `#0B0A08` | +26.82 | **+0.76** | +10.44 |
| light `#F4EFE4` | +4.53 | **+1.72** | +12.87 |

The light ground is **2.26× better** at the ladder's weakest step, and that is a real argument for
it being a design rather than a fallback. Both are still under a patch JND (≈ 2.3 ΔL\*), so neither
ground rescues cross-hue coverage comparison on its own.

That is not a defect, because `fill` carries **two** discriminators, and only one of them is
metric: coverage {0, 22.7, 38.6, 100 %} *and* texture kind {none, discrete, linear, area}. Texture
kind is categorical and survives any ground. A player also never compares a dotted teal patch to a
striped amber patch as flat swatches — a glyph is monochrome in its own hue and carries its own
index angle. **The falsifiable version of this is §13.5.1's `T` constant, and it is owned by
`hunch-glyph-renderer`, not here.** Feed it these two rows; do not re-derive them.

**A correction worth carrying.** `DIRECTION-B-PLATE.md` §1 reports the "GDD light `#F4EFE4`" row as
+4.1 / +1.3 / +10.8. Recomputing reproduces PLATE's other three rows to two decimals but not that
one — those numbers are `#EFE7D5`'s, PLATE's own ground. Canon's light ground is better on all
three steps than PLATE's table credits it with.

---

## 6. Grafted, and rejected

| From PLATE | Verdict | Reason |
|---|---|---|
| Warm paper ground, light-first thinking | **grafted** as the light theme | it is where phones actually are, and canon's `#F4EFE4` already is that ground |
| Depth by impression, not by a luminance step | **grafted** (§3) | the luminance step is measurably below threshold on paper |
| No bed layer in light | **grafted** (§4) | a blurred bright mark on a bright ground reads as a fault |
| No scanline | **grafted** in light (§4) | a scanline is a lens/CRT artefact; paper has neither |
| Arithmetic rigour — every ratio computed, never asserted | **grafted everywhere** | it is why `contrast.swift` and `check-tokens.swift` exist |
| Re-lit hues (`#3F2800` amber etc.) at constant chromaticity | **rejected** | §13.2 and §2 forbid re-lighting Okabe–Ito. The keyline solves the same problem, keeps the published values, and does not make `hue.amber` render as brown |
| One accent (`accent.verdigris`), reject as "the plate fails to print" | **rejected** | HUNCH needs two verdict registers; collapsing them puts reject, strike, barred and counterexample in one achromatic register, which PLATE's own weakness 5 names as its likeliest usability failure |
| High Contrast as white ground | **rejected** | the direction is dark-first; a polarity flip between the theme the player chose and the one Increase Contrast produces is a third artefact |
| Dark-first overruled | **rejected** | the direction is locked as PHOSPHOR |
| 1 pt chrome radius, `w.squash`, dot gain, registration-cross money shot | **rejected** | geometry and motion, not tokens; and forking geometry by theme ships two art directions |

---

## 7. What does not change

**No dimension, weight, radius, duration or easing token varies by theme.** Only colour, four
opacity members and five environment predicates do. This is the rule that keeps the light theme a
second exposure instead of a second product, and it is the one PLATE's weakness 3 warns about:
*"PLATE ships two art directions, doubles the review surface and the snapshot matrix, and will
drift."*

Also unchanged in light: Okabe–Ito verbatim; register segregation; the 4 pt grid and the 343 pt
column; `radius.glyph` 0; miter joins and butt caps on glyph geometry; every duration and every
easing; the Reduce Motion substitution table; the type ramp; and the zero-text rule on the play
surface.
