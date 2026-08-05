# fill-textures.md — the interior texture register

Contents: [1 The three patterns](#1-the-three-patterns) ·
[2 Why coverage is pitch-invariant](#2-why-coverage-is-pitch-invariant-and-what-that-does-not-buy) ·
[3 The clip](#3-the-clip) · [4 Measured, every size](#4-measured-every-size) ·
[5 The anchor rule](#5-the-anchor-rule) · [6 What breaks it](#6-what-breaks-it)

`fill` is rank 1–4 as monotone ink density: `hollow` → `dotted` → `striped` → `solid`,
nominally 0 → 22.7 → 38.6 → 100 % (§2, §13.5). It is the only channel whose value is a
*statistic of the drawing* rather than a countable feature, which is why it is the one
that needs measuring.

---

## 1. The three patterns

Everything is pinned to one pitch so that the ladder is a property of the pattern and not
of the size (§13.5). All four values are ratios; none is a token in the design-token sense
and none belongs in `hunch-design-tokens`.

| Value | Rank | Geometry | Nominal coverage | Texture kind |
|---|---|---|---|---|
| `hollow` | 1 | nothing | 0 % | none |
| `dotted` | 2 | hex-packed discs, `dotRadius = 0.25 · pitch`, spacing `pitch` | 22.7 % | discrete |
| `striped` | 3 | parallel lines at **+45° in the screen frame**, `stripeWeight = 0.386 · pitch`, spacing `pitch` | 38.6 % | continuous, linear |
| `solid` | 4 | flat field | 100 % | continuous, area |

`pitch = max(5 pt, 0.22 · R)`. The 5 pt floor binds for `R < 22.7`, i.e. **`S < 61.4`** —
which is every shipped site except the throat and the Codex hero.

**Texture *kind* is a second discriminator and it is not redundant.** §13.5.1 lists the
`fill` discriminator as coverage **and** kind {none, discrete, linear, area}. Coverage
alone is a scalar and scalars get compressed; kind is categorical and survives any amount
of compression. A viewer who cannot tell 22.7 % from 38.6 % can still tell dots from
lines. Keep both, and never "simplify" `dotted` into a lighter `striped`.

---

## 2. Why coverage is pitch-invariant, and what that does not buy

The hex lattice's unit cell is `pitch × (pitch·√3/2)`, area `0.866 · pitch²`. One disc of
radius `0.25 · pitch` has area `π · 0.0625 · pitch²`. So

```
dotted  = π · 0.0625 / 0.866            = 0.2267   →  22.7 %
striped = 0.386 · pitch / pitch          = 0.386    →  38.6 %
```

**`pitch` cancels in both.** The coverage ratio is therefore exactly size-invariant, at
every size, in the continuum — the 5 pt floor changes how many samples land inside the
body, and nothing else.

What that does **not** buy is a size-invariant raster. Coverage is a mean over an area,
and a mean over ~3 dots has a variance a mean over ~40 dots does not. §13.5's *"identically
at every size from 24 pt to 220 pt"* is true of the arithmetic and false of the pixels:

| S | inset radius | dots across the widest chord |
|---|---|---|
| 24 | 6.63 | 2.7 |
| 36 | 11.07 | 4.4 |
| 44 | 14.03 | 5.6 |
| 48 | 13.26 | 5.3 |
| 96 | 31.02 | 7.9 |
| 220 | 76.90 | 8.6 |

Note S = 48. The inset is `1.5 × bodyWeight` and the weight steps 1.5 → 3.0 at the regime
boundary, so **the interior shrinks as the glyph grows** — 14.03 pt of inset radius at
S = 44 against 13.26 at S = 48. Expected, and correct: a heavier silhouette needs a wider
gap or the texture reads as part of the outline. But it means the texture is at its
tightest at S = 48–52, not at the smallest size, which is not where anyone looks for it.

---

## 3. The clip

The texture is clipped to the silhouette **inset `1.5 × bodyWeight` from the centre-line**,
via `C.Glyph.fillClipScale(cornerCount:side:in:)`. Because offsetting a regular polygon is
a change of apothem, the clip is the same polygon at another radius scale — exact, and one
`GlyphShape(shape:radiusScale:)` rather than a `Path` inset.

`1.5 × bodyWeight` is not a taste value. It is **exactly the halo's half-width**, since the
halo is stroked at `3 × bodyWeight` with a round join. The halo's inner edge therefore
lands precisely on the clip boundary and deposits nothing inside it — which is why §4's
`hollow` row measures 0.0 % with bloom on at every size, in every theme.

> This is the single constraint linking the two numbers. If the halo ever widens past ×3,
> the fill inset must widen with it or bloom starts adding ink to `hollow`. See
> `bloom-and-squash.md` §3.

---

## 4. Measured, every size

`node scripts/render-all-256.js --size N` prints one size; the table below is the whole
range, dark theme, no Bold Text, bloom on, as **min–max over the four shapes**.

Two regions, and which one is quoted decides whether the ladder holds:

- **inset** — the fill clip itself. This is the region the `fill` register paints, and it
  is what "22.7 %" is a claim about.
- **interior** — everything inside the silhouette centre-line, so the body stroke's inner
  half and the halo's inner half are both counted.

| S | region | `hollow` | `dotted` | `striped` | `solid` |
|---|---|---|---|---|---|
| 24 | inset | 0.0 | 19.1–25.5 | 39.9–42.5 | 100.0 |
| 24 | interior | 16.2–31.0 | **30.1**–35.8 | 38.5–41.2 | 55.2–72.0 |
| 36 | inset | 0.0 | 19.9–24.0 | 36.3–39.9 | 100.0 |
| 36 | interior | 13.4–25.6 | 29.5–35.8 | 38.9–41.8 | 69.2–82.4 |
| 44 | inset | 0.0 | 21.4–27.2 | 37.6–39.7 | 100.0 |
| 44 | interior | 11.0–21.1 | 27.8–35.4 | 38.9–41.4 | 73.6–85.3 |
| 48 | inset | 0.0 | 21.4–23.3 | 37.4–39.5 | 100.0 |
| 48 | interior | 19.5–**36.4** | **32.0**–42.1 | **41.1**–45.5 | 60.7–75.3 |
| 52 | inset | 0.0 | 22.0–30.6 | 37.5–39.3 | 100.0 |
| 52 | interior | 18.1–33.8 | **32.1**–42.4 | **40.1**–44.4 | 62.1–76.8 |
| 72 | inset | 0.0 | 17.1–23.6 | 38.0–39.1 | 100.0 |
| 96 | inset | 0.0 | 21.5–23.4 | 37.9–39.2 | 100.0 |
| 128 | inset | 0.0 | 22.0–25.8 | 38.6–39.3 | 100.0 |
| 220 | inset | 0.0 | 22.0–25.9 | 38.6–39.2 | 100.0 |

**Three things to take from this.**

1. **The inset ladder never inverts, at any size, with bloom on or off.** Worst rung is
   `dotted → striped` at S = 52: 30.6 % against 37.5 %, a 6.9 pp gap. `dotted` runs
   17.1–30.6 against a nominal 22.7 because a lattice of 3–6 samples is coarse, not
   because the geometry drifts.
2. **The interior ladder inverts at S = 24, 48 and 52**, where the stroke is heaviest
   relative to `R`. At S = 48 `hollow`'s interior reads 36.4 % — all of it rim — against
   `dotted`'s 32.0 %.
3. **Which means the mean is the wrong statistic, and §13.5.1 already knew that.** The
   shipped test is a **pairwise L1 over the raster**, not a comparison of means, and L1 is
   spatially sensitive: at S = 48 `hollow` and `dotted` differ by 23.41 pt² of ink even
   though their interior means differ by 4 pp, because `hollow`'s ink is all at the rim and
   `dotted`'s is spread. Quote the inset means when describing the design; quote
   `check-coverage-separation.js` when asserting the design works.

The one place the raster measurement agrees that the channel is weak is **S = 24**, where
`dotted` vs `striped` falls to 1.82 pt² — the smallest single-channel change anywhere in
the deck. No shipped site draws a glyph at 24 pt (the smallest is 36), so this is a floor
on the vocabulary rather than a bug. `triple-encoding-proof.md` §3 has the full channel
ranking per size.

---

## 5. The anchor rule

**Both lattices are anchored at `bodyCentre`.** Row `j = 0` passes through it; stripe
`m = 0` passes through it.

`DIRECTION-A-PHOSPHOR.md` §5's loop starts its rows at `C[1] − r` and steps by `dy`, so the
row parity and the sub-pitch phase both depend on `r`, which depends on `R`, which depends
on `S`. Two glyphs of the same `fill` at two sizes would then carry differently-phased
lattices — the pattern would move when the mark is resized, and `fill` would stop being a
value and start being a value-plus-a-size. Anchoring at `bodyCentre` makes the texture a
pure function of `(fill, S)`, which is what a snapshot test needs and what the Assay's 256
simultaneous cells need.

The same rule holds for the stripe offset: `t = (p − bodyCentre) · n`, then
`|t − round(t/pitch)·pitch| ≤ stripeWeight/2`. Never `t` measured from the clip's bounding
box.

**`striped` runs at +45°, the same angle as `teal`'s index stroke.** That is not a
collision — the two live in spatially disjoint registers, which is the whole point of §2's
register table — but it does mean a reviewer will eventually ask. The answer is that the
index register is below the body and the texture is inside it, and no ray of the drawing
contains both.

---

## 6. What breaks it

- **Widening the texture in the halo pass.** Pass B strokes the body outline and the index
  stroke only. Re-stroking a dot lattice at 3× turns 22.7 % into something near 100 % and
  deletes the rung the greyscale proof rests on.
- **A gradient or a bitmap inside the body.** §13.1 names this specifically: the fill
  register is game state and must be a flat pattern. There is no image asset in the app.
- **Insetting by a constant instead of by `1.5 × bodyWeight`.** The inset is coupled to the
  halo (§3) and to the regime switch. A constant inset makes the halo bleed into `hollow`
  at one size and the texture collide with the stroke at another.
- **Filling the clip and then stroking the silhouette on top with a *ground* colour** to
  fake the gap. It reads identically in the dark theme and wrongly everywhere else, and it
  destroys the mark on any non-`ground` backdrop — the Codex page and the ECHO tray both
  sit on `ground.raised`.
- **Changing `dotRadius` or `stripeWeight` to "make it read better" at one size.** Both are
  fixed ratios of `pitch` chosen so the coverage cancels. Move either and the ladder is no
  longer 22.7 / 38.6 at any size, including the one you were looking at.
- **Scaling the pattern by `env.artScale`.** Dynamic Type scales `S`; `pitch` is derived
  from `R` which is derived from `S`, so the pattern already scales exactly once. Applying
  `artScale` again compounds it.
