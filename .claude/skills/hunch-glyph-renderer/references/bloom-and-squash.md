# bloom-and-squash.md — the four passes, and who may move a glyph

Contents: [1 The four passes](#1-the-four-passes) · [2 Pass A is per region](#2-pass-a-is-per-region-never-per-glyph) ·
[3 The 1.5 × coupling](#3-the-15--coupling) · [4 The exclusion matrix](#4-the-exclusion-matrix) ·
[5 The Swift](#5-the-swift) · [6 Squash: scaleEffect vs a new S](#6-squash-scaleeffect-versus-a-new-s) ·
[7 What breaks it](#7-what-breaks-it)

---

## 1. The four passes

`DIRECTION-A-PHOSPHOR.md` §2. **The order is fixed and a reviewer should check it in any
PR that touches drawing.** Passes A and B are the bloom; C and D are the mark.

| Pass | What | Geometry | Paint | Where it lives |
|---|---|---|---|---|
| **A — bed** | a clone of *the whole region's* marks, blurred | one offscreen layer **per glyph-bearing region** | `blur(0.062 · S)`, `opacity.bloomBed`, `plusLighter` | the region's view, **not** `GlyphRenderer` |
| **B — halo** | the glyph's stroked registers re-stroked wide | body outline + index stroke **only**, at `3 ×`, round join | own hue at `opacity.halo` | `GlyphRenderer` |
| **C — ink** | the mark | texture (clipped), light-theme keyline, silhouette, index stroke | own hue, opacity 1, miter join, butt cap, zero radius | `GlyphRenderer` |
| **D — knockout** | pip separation | disc `r = pipRadius + 0.5` stroked at `C.Glyph.pipKnockoutWeight` | `ground` | `GlyphRenderer` |

`opacity.halo` and `opacity.bloomBed` are `hunch-design-tokens`'; the ×3, the `0.062 · S`,
the `+ 0.5` and `pipKnockoutWeight` are geometry and are this skill's.

**Pass D's ring is `C.Glyph.pipKnockoutWeight`, not `weight.thin`.** It looks like the same
number in the dark theme and is not the same thing: `weight.thin` is an L1 design weight and
picks up Bold Text and the High Contrast offset, while `pipKnockoutWeight` is a geometric
separator that **opts out of both**, because a ring that grew would eat into the frost index
tip at exactly the sizes where §5.1's overlap is deepest. `geometry.md` §2 and §5 own the
reasoning; naming `weight.thin` here would silently re-couple it.

**Pass B excludes the fill texture and the pips, deliberately.** Widening a dot lattice at
3× would raise its measured ink coverage toward 100 % and delete the rung that
`triple-encoding-proof.md` rests on. The texture and the pips take their glow from pass A
only, which is a blur of the composited region and therefore does not change any
register's coverage relative to any other's.

**The index stroke is drawn last and is never knocked out.** The two registers touch:
`frost`'s stroke tip lands **inside** the S pip disc on `circle` and `hexagon` at every
shipped size (1.82 pt from the node centre at S = 44, against `pipRadius` 3.0), and `teal`
and `rose` reach inside the knockout ring at S ≤ 44. Drawing the index stroke before pass D
would let the `ground` ring bite a notch out of the hue channel — out of the one register
the whole colourblind case rests on. `geometry.md` §5 has the full distance table.

---

## 2. Pass A is per region, never per glyph

**The blur is not free and the halo is.** The halo is two extra `stroke` calls into the
same layer — genuinely cheap. The blur is not: inside a `Canvas` the only way to blur drawn
geometry is `GraphicsContext.addFilter(.blur(radius:))` around a `drawLayer { }`, and that
is an explicit offscreen layer, exactly as `.blur()` is as a view modifier (§13.5).

So pass A is applied **once per glyph-bearing region — the throat, the ribbon, the tail —
never once per glyph**, at `radius: 0.062 · S` for that region's `S`. Three offscreen
layers per frame, not up to sixteen.

The three regions and their radii:

| Region | `S` | blur radius | note |
|---|---|---|---|
| the throat | 96 (SE) / 128 (Pro Max, Frame) | 5.95 / 7.94 | one glyph, but the region still owns the layer |
| the ribbon | 44 | 2.73 | 7 tiles on screen, one layer for all of them |
| the SIEVE tail | 36 | 2.23 | 6 glyphs |
| the SIEVE lane | 72 | 4.46 | the streaming glyphs |
| **the Assay** | 3.5–23 | — | **excluded entirely, always.** §4 |

A consequence that is easy to get wrong: **the ribbon's bed uses the ribbon's `S`, not each
tile's.** A region with one radius is the entire point; a per-tile radius would need a
per-tile layer and would put the cost back.

---

## 3. The 1.5 × coupling

`fillInset = 1.5 × bodyWeight`, and the halo is stroked at `3 × bodyWeight` with a round
join, so **the halo's half-width is also `1.5 × bodyWeight`**. Its inner edge therefore
lands exactly on the fill clip boundary.

Measured consequence: `hollow`'s coverage inside the fill clip is **0.0 %** with bloom on,
at every size, in every theme (`fill-textures.md` §4). The 0 → 22.7 % rung survives bloom
intact.

`DIRECTION-A-PHOSPHOR.md` §6.4 lists this as the direction's fourth weakness — *"bloom
actively attacks the `fill` ladder … that raises the measured coverage of `hollow` above
0"*. Measurement says the concern is real but mis-attributed: over the fill clip the halo
contributes nothing, and over the whole silhouette interior what compresses the ladder is
the **body stroke's inner half**, not the halo. Turning bloom off at S = 44 moves `hollow`'s
interior ink from 11.0–21.1 % to 9.0–17.5 %, i.e. by 2.0–3.6 pp; the stroke accounts for
the remaining 9–17.5.

**The rule this leaves behind is a hard one anyway.** The two constants are locked to each
other. If the halo ever widens past ×3, `fillInset` must widen with it in the same commit,
or PHOSPHOR §6.4's failure stops being hypothetical.

---

## 4. The exclusion matrix

| Condition | Pass A (bed) | Pass B (halo) | Predicate |
|---|---|---|---|
| default, dark | on | on | — |
| **light theme** | **off** | on | `env.isBloomBedEnabled` is dark-only — a blurred bright mark on a light ground reads as a printing fault, not as light |
| Reduce Transparency | off | off | `env.isBloomEnabled` |
| High Contrast | off | off | `env.isBloomEnabled` |
| Low Power Mode | off | off | `env.isBloomEnabled` |
| `S < 32` | off | off | `C.Glyph.isBloomed(side:in:)` — **this half is geometry and is ours** |
| **the Assay, any size, any state** | **off** | **off** | the Assay's own drawing code never calls either |
| Reduce Motion | **unaffected** | **unaffected** | Reduce Motion freezes the shader's `t`; it does not touch bloom |

**The environment half and the geometry half are separate on purpose.** `RenderEnv` owns
"has this player asked for less"; this skill owns "is the mark big enough for a halo to be
a halo". At S = 24 the body radius is 8.88 pt and a 3 × 1.5 pt halo is 4.5 pt wide — half
the body — so below 32 the halo stops being a glow and starts being a second, blurrier
silhouette.

**Why the Assay is excluded at every size and in every state** (§13.5, and it is canon):
its cells are 3.5–9.5 pt and carry no stroke to widen; and during the correct-declaration
reveal it floods 256 cells at 1.6 ms/cell (§6.8) on top of the throat and the ribbon,
which is precisely the frame that cannot afford a fourth offscreen layer against the
≤ 0.4 ms/frame shader budget. The Assay draws extension cells, not glyphs, so this
exclusion is really a statement about the *bench* skill's code — but it is stated here
because it is a bloom rule and someone reading about bloom needs to find it.

**Reduce Motion is not a bloom setting.** This is the single most common confusion on this
page. Reduce Motion freezes §13.6's shader time at `t = 0` and substitutes every animation
in §13.7.4; it leaves both bloom passes running. Reduce Transparency is the one that kills
them, along with the shader's `amt`, and it turns every material opaque.

---

## 5. The Swift

Pass B is in `GlyphRenderer.draw` — `geometry.md` §4. Pass A belongs to the region:

```swift
/// One glyph-bearing region: the throat, the ribbon, the SIEVE lane, the SIEVE tail.
/// Draws its content twice — once blurred as the bed, once sharp — into ONE offscreen
/// layer, not one per glyph. Never wrap the Assay in this.
struct BloomedRegion<Content: View>: View {
    let side: Double            // the region's glyph size, which sets the blur radius
    let env: RenderEnv
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background {
                if env.isBloomBedEnabled {
                    content
                        .blur(radius: 0.062 * side)
                        .opacity(Opacity.bloomBed)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .compositingGroup()
    }
}
```

Inside a single `Canvas` that draws a whole region itself, the same thing is
`addFilter` + `drawLayer`:

```swift
if env.isBloomBedEnabled {
    var bed = context
    bed.addFilter(.blur(radius: 0.062 * side))
    bed.opacity = Opacity.bloomBed
    bed.blendMode = .plusLighter
    bed.drawLayer { layer in                 // the one offscreen layer for this region
        for placement in placements {
            GlyphRenderer(glyph: placement.glyph, side: side, env: env)
                .draw(into: &layer, canvas: placement.canvas)
        }
    }
}
```

**One caveat worth ratifying rather than assuming.** CSS `blur()` takes the Gaussian
standard deviation, which is why `DIRECTION-A-PHOSPHOR.md`'s mockup CSS matches
`feGaussianBlur stdDeviation` one-for-one. SwiftUI's `blur(radius:)` and
`GraphicsContext.BlurOptions` are documented only as "the radial size of the blur", and
Apple does not state the relationship to σ. So `0.062 · S` is the *mockup's* calibration;
compare the shipped throat against `design/mockup-phosphor.html` once and record the
result, rather than assuming the units are the same.

---

## 6. Squash: `scaleEffect` versus a new `S`

The glyph renderer has **no time axis**. It is a pure function of `(glyph, S, RenderEnv)`,
and every motion in §13.7 — the admit scale 1.00 → 1.04, the reject shudder, the verdict
rings, the reveal's gather — is applied by the *host* to an already-drawn glyph. That
ownership line is `hunch-motion-and-feedback`'s and it is not negotiable here: a glyph that
animates itself cannot be snapshot-tested, cannot be drawn 256 times into the Assay, and
cannot be a `Shape`.

But there are two ways for a host to make a glyph bigger, they look identical in a still,
and picking the wrong one is a real bug in both directions:

| | `.scaleEffect(k)` | render at `S × k` |
|---|---|---|
| what scales | the rasterised output — strokes, halo, texture pitch, everything | nothing; every constant re-derives from the new `S` |
| the weight regime | frozen at the original `S`'s regime | re-selected, and it steps at 48 |
| the dot lattice | scales with the mark | re-pitches, and re-phases about `bodyCentre` |
| reads as | the mark **moving toward you** | the mark **being a different size** |
| use for | §13.7's admit pulse, the reveal's gather, `matchedGeometryEffect` | Dynamic Type, layout, a different site |

**The rule: `.scaleEffect` for motion, a new `S` for size.**

- Using a new `S` for the admit pulse would step the stroke weight mid-animation at any
  site near 48 pt and re-phase the dot lattice on every frame — the texture would crawl.
- Using `.scaleEffect` for Dynamic Type would freeze a 44 pt glyph in the `bodySm` regime
  at AX5, so a player asking for larger art would get a 59 pt glyph drawn with a 2 pt
  stroke and a lattice pitched for a mark two-thirds the size. `env.artScale` multiplies
  the *length* `S` at the drawing site (`hunch-design-tokens`' resolution order §4), and
  the renderer re-derives from it.

Two corollaries:

- **Never scale a stroke weight by `artScale`.** `S` selects the regime; the weight has its
  own axis. Scaling both compounds them.
- **The bleed changes when `S` changes.** A host that re-renders at `S × artScale` must
  re-read `C.Glyph.bleed(side:in:)` with the new side, or the layout that fitted at 44 pt
  clips at 59.

---

## 7. What breaks it

- **Blurring per glyph.** Sixteen offscreen layers where three were budgeted. The symptom
  is a frame-time cliff on the reveal, not a wrong picture, so it survives review.
- **Widening the halo past ×3 without moving `fillInset`.** §3.
- **Re-stroking the texture or the pips in pass B.** `triple-encoding-proof.md` §6.
- **Bloom on the Assay**, at any size, in any state, including the expanded inspector at
  23 pt cells where it would look fine.
- **Wrapping bloom in `isReduceMotionEnabled` instead of `isReduceTransparencyEnabled`.**
  Both are `Bool`s on the same record and the mistake compiles.
- **A bloom bed in the light theme.** `env.isBloomBedEnabled` is dark-only; adding it back
  because the light theme "looks flat" is the change that makes it look like a printing
  fault. Light gets depth from the impression, not from a glow — `hunch-design-tokens`'
  `light-theme.md`.
- **`.clipped()` anywhere between the region and the `Canvas`.** The halo reaches
  `1.5 × weight` outside the silhouette and the index stroke reaches past the S-box at
  every size; both get cut and nothing errors.
- **Compositing the bed with `.normal` instead of `.plusLighter`.** It stops being light
  and starts being a grey smear behind the mark, which on a near-black ground is a stain.
