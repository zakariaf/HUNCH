# DIRECTION B — "PLATE"

**The Loom is not glowing at you. You are drawing it.**

§13.1 commits to *a dead machine in a dark room* and renders the Loom as a glowing instrument. PLATE takes the identical archaeological premise — an artefact someone else built, which still answers — and draws the other conclusion: you are not operating it, you are **documenting** it. The surface is a technical plate in a field notebook. Warm laid paper, ink-black strokes, the constant line weight of a lithograph or a patent drawing, one second plate in oxidised copper. Light-first, because that is where phones actually are.

**The emotional argument, in three sentences.** A glowing instrument says the machine is alive and you are its operator — a power fantasy the rest of HUNCH refuses, since nothing else in this game flatters you. A drawn plate says the machine is older than you and indifferent, and that the only available response is to observe carefully and write it down, which is exactly what a probe is. The reveal is therefore not the machine lighting up for you but your drawing turning out to be right, and being right is felt as **pressure** — a second plate landing in register, paper taking the impression — never as light.

## 1. What PLATE wins, with numbers

**The ink-density ladder stops lying.** §13.5 claims coverage `0 → 22.7 → 38.6 → 100 %` is the rank order "identically at every size". It is not: a glyph is monochrome in its own hue, and the four Okabe–Ito hues span 1.62 : 1 in luminance. Cross-hue ΔL\* margin between adjacent fill ranks, as optical mixing on the ground:

| Ground / ink set | hollow→dotted | **dotted→striped** | striped→solid |
|---|---|---|---|
| GDD dark `#0B0A08`, raw Okabe–Ito | +26.8 | **+0.8** | +10.4 |
| GDD light `#F4EFE4`, raw Okabe–Ito | +4.1 | **+1.3** | +10.8 |
| **PLATE light `#EFE7D5`** | +7.8 | **+5.5** | +39.9 |
| **PLATE dark `#1B1815`** | +25.7 | **+4.2** | +15.3 |

A **dotted teal** patch is 0.8 ΔL\* lighter than a **striped amber** patch on the shipping dark theme — inside a patch JND (≈2.3 ΔL\*). The fill channel's rank order is not currently readable across hues. PLATE improves it 6.9× because its palette is built the way ink actually behaves, which is the whole argument in one number.

**Daylight:** 15.15 : 1 ink on paper loses nothing at 400 nits outdoors, where a 1.06 : 1 ground shift on `#0B0A08` is simply gone — and the Bench, the Assay well and the throat vignette all depend on that shift. **The Codex genuinely becomes a book of plates** and the extension thumbnails become printed constellations rather than a database view (§9). **And it sidesteps the trope:** dark ground + neon accent + scanline + bloom is the most-shipped indie-puzzle look of the last decade; PLATE's shader has no scanline and no time term at all.

> **Decision: overrule the brief's dark-first mandate** — the same class of override as §4.5's two strikes. Reason: the brief's dark-first instruction and the brief's archaeological premise point opposite ways, and §13.5's own coverage ladder is measurably broken on the dark ground. Only one of the two survives without a patch.

## 2. Palette — three complete themes

WCAG 2.1 relative luminance against that theme's `ground`. No literal hex in view code; `Theme.token(_:)` resolves.

| Token | **Light (canonical)** | : 1 | **Dark** | : 1 | **High Contrast** | : 1 | Use |
|---|---|---|---|---|---|---|---|
| `ground` | `#EFE7D5` (L .803) | — | `#1B1815` (L .009) | — | `#FFFFFF` | — | the sheet |
| `ground.raised` | `#F4EFE2` | 1.07 | `#221E19` | 1.07 | `#FFFFFF` | 1.00 | Bench sheet, Codex rows |
| `ground.sunken` | `#E8E0CD` | 1.07 | `#141210` | 1.06 | `#EDEDED` | 1.17 | inside a platemark, Assay well |
| `stroke.primary` | `#16120C` | **15.15** | `#EDE4CF` | **13.97** | `#000000` | **21.0** | ink plate: glyph keyline, rule-tiles, body text |
| `stroke.secondary` | `#5C554A` | **5.98** | `#8C8271` | **4.67** | `#333333` | **12.63** | graduated scales, tick marks, labels |
| `stroke.hairline` | `#C6BCA6` | 1.53 | `#3E382F` | 1.52 | `#767676` | 4.54 | platemark, registration marks, Assay grid — **never state-bearing** |
| `accent.verdigris` | `#1F6F5F` | **4.88** | `#8FE0C8` | **11.50** | `#00403A` | **11.70** | copper plate: admit, Seal, marks, streak, registration |
| `hue.amber` | `#3F2800` | **11.26** | `#E9A100` | **8.05** | `stroke.primary` | 21.0 | rank 1, index 0° |
| `hue.teal` | `#003424` | **11.25** | `#00C792` | **8.07** | `stroke.primary` | 21.0 | rank 2, index 45° |
| `hue.frost` | `#285B77` | **5.98** | `#4DA3D3` | **6.31** | `stroke.primary` | 21.0 | rank 3, index 90° |
| `hue.rose` | `#693B54` | **7.25** | `#D67FAF` | **6.32** | `stroke.primary` | 21.0 | rank 4, index 135° |

**High Contrast is white, not black:** iOS *Increase Contrast* raises contrast, it does not invert polarity (*Smart Invert* does, and the OS owns it), so a light-first direction whose HC flipped to black would ship a third artefact and surprise the users least able to absorb surprise. **One accent, not two:** PLATE is a **two-plate press**, ink and copper; a third ink is a different, costlier product, and §13.2's `accent.cold` exists mostly to colour *reject*, which PLATE encodes as the copper plate **failing to print** (§8). Damage — strike, counterexample, barred Seal — is a **foul bite**: `stroke.primary` rendered with a ragged stochastic hairline and a torn edge. A texture, not a hue: achromatic by construction, zero colour budget.

## 3. The four hues, re-specified for a paper ground

§13.2's light theme leaves raw Okabe–Ito at **1.8–2.7 : 1** and patches it with a `stroke.primary` keyline under every glyph. The patch concedes the argument — it admits the hue ink is not carrying the silhouette, then keeps the ink anyway.

**Method — Okabe–Ito at constant chromaticity, luminance-banded.** Each hue is scaled in **linear** RGB by a per-hue factor `k`. Linear scaling multiplies `Y` exactly and leaves CIE `(x, y)` **unchanged**, so every hue keeps its Okabe–Ito chromaticity and its position on every dichromat confusion line; only lightness moves. The four `k` are solved to (a) clear 4.5 : 1 on the ground, (b) hold a cross-hue ladder margin ≥ 4 ΔL\*, (c) stay ≥ 1.35 : 1 in luminance from `accent.verdigris`, (d) maximise the minimum simulated-dichromat ΔE (Viénot 1999; protan, deutan, tritan; all six pairs).

| Hue | Okabe–Ito | `Y` | **PLATE light** | `k` | `Y` | on paper | **PLATE dark** | `Y` | on board |
|---|---|---|---|---|---|---|---|---|---|
| `amber` | `#E69F00` | .416 | **`#3F2800`** | .062 | .0257 | **11.26 : 1** | **`#E9A100`** | .428 | **8.05 : 1** |
| `teal` | `#009E73` | .257 | **`#003424`** | .100 | .0258 | **11.25 : 1** | **`#00C792`** | .429 | **8.07 : 1** |
| `frost` | `#56B4E9` | .405 | **`#285B77`** | .229 | .0927 | **5.98 : 1** | **`#4DA3D3`** | .330 | **6.31 : 1** |
| `rose` | `#CC79A7` | .293 | **`#693B54`** | .231 | .0677 | **7.25 : 1** | **`#D67FAF`** | .330 | **6.32 : 1** |

**PLATE's set is more colourblind-safe than raw Okabe–Ito on this ground, not less** — minimum pairwise ΔE over all six pairs:

| Set on `#EFE7D5` | protan | deutan | tritan | **min** | worst contrast |
|---|---|---|---|---|---|
| raw Okabe–Ito + §13.2 keyline patch | 23.2 | 16.6 | 10.9 | **10.9** | 1.83 : 1 |
| **PLATE light** | 13.7 | 17.7 | 13.8 | **13.7** | **5.98 : 1** |

PLATE dark scores 16.9 / 14.3 / 8.7, min **8.7** at 6.31 : 1 — measurably the weaker of the two themes. Light gains **+26 % dichromat separation, +227 % worst-case contrast, +323 % ladder margin — and the keyline is deleted.** Enum names are untouched: `Hue.amber` is still `amber` and VoiceOver still says "teal", exactly as HC already renders all four as `stroke.primary` while narrating four names. Only the pigment changes — four inks from a portable set: burnt umber, deep viridian, prussian, madder.

**Register segregation as three luminance bands.** §13.2 checks segregation pairwise and gets a measured 1.22 : 1 and 1.41 : 1. PLATE makes it structural and checkable in one assertion: every ink belongs to exactly one band, and bands never overlap.

| Band | Light `Y` | Dark `Y` | Members | Never touches |
|---|---|---|---|---|
| **ink** | ≤ .010 | ≥ .700 | `stroke.primary`, foul bite | — (serves chrome and glyph keyline both) |
| **hue** | .026 – .093 | .330 – .429 | the four `hue.*` | chrome, rule-tile frame, tick mark, the Seal |
| **copper** | .110 – .140 | ≥ .560 | `accent.verdigris` | glyph body, ramp cell, index stroke |

Minimum inter-band separation: **1.35 : 1** (hue ↔ copper), **4.09 : 1** (ink ↔ hue). A shipped test asserts each token's `Y` lands in its declared band.

## 4. Dimension, stroke, radius, opacity

Layout is **unchanged from §4.1 / §13.3** — the 375 × 667 solve, the 343 pt content column, the Dial's `45 + 4×70 + 3×6`, every target ≥ 70 × 48 pt, right-thumb arc y > 240. PLATE does not relitigate a solved layout; the platemark rides **on** the existing 16 pt margin line, so it costs zero content width. Bold Text steps every stroke ×1.25 per §13.11; Dynamic Type scales art to the 1.35× ceiling and the platemark scales with it while the paper tooth does not; RTL mirrors chrome, platemark and registration crosses, never glyphs or the colour bar.

| Token | Value | Applied to |
|---|---|---|
| `w.hairline` / `w.thin` | 0.5 / 1.0 pt | platemark, registration marks, Assay grid, empty-rail outline / ramp cell borders, rule-tile frames, sheet top edge |
| `w.bodySm` / `w.body` | 1.5 / 3.0 pt | glyph body below S = 48 and fill hatch at small sizes / glyph body at S ≥ 48, index stroke (always), wedge, coupler |
| `w.heavy` / `w.squash` | 4.0 pt / ×1.22 | cancel band across a barred Seal and the AND welded bar / the ink-spread copy beneath every stroked mark |
| `r.glyph` / `r.chrome` / `r.plate` / `r.sheet` | **0** / 1 / 2 / 8 pt | glyph silhouette (miter, zero radius, always — canon) / ramp cells, rule-tiles, buttons, since a printed rule is nearly sharp and 2 pt reads as software / platemark rectangles / Bench sheet top corners |
| `o.full` / `o.mid` | 1.00 / 0.55 | any state-bearing ink / copper plate before registration, and the ribbon at reveal beat 1 |
| `o.low` | **0.30** | unlit ramp cell — **not** §4.2's 0.25; on paper 25 % ink is nearly gone (HC 0.45) |
| `o.faint` / `o.squash` / `o.tooth` | 0.14 / **0.08** / 0.022 | innermost platemark bevel hairline / the ink-spread copy, which is PLATE's entire bloom budget / paper-tooth shader amplitude |

## 5. Duration and easing

**No springs on the play surface** — a press does not bounce. Springs survive only on the Bench sheet drag, which follows a finger. §13.7's 8 pt spring overshoot at reveal beat 2 becomes 8 pt of **misregistration that resolves**: the same "not quite there yet", read mechanically instead of elastically.

| Token | Curve / ms | Where |
|---|---|---|
| `e.press` | `cubicBezier(0.20, 0.00, 0.00, 1.00)` | into contact — accelerate, dead stop. The house curve. |
| `e.lift` | `cubicBezier(0.30, 0.00, 0.20, 1.00)` | out of contact |
| `e.draw` / `e.settle` | `linear` / `cubicBezier(0.40, 0.00, 0.15, 1.00)` | a pen draws at constant speed — frame stroking, registration sweep / fades and crossfades |
| `e.sheet` | `spring(0.32, 0.86)` | Bench drag **only** |
| `d.tick` / `d.beat` / `d.step` / `d.move` | 90 / 140 / 180 / 240 ms | key travel and cross closure / chrome fade / per-beat inner move / tile gather and thumbnail dock |
| `d.verdict` | 250 ms | admit and reject, both non-blocking |
| `d.reveal` | 1840 / 1020 ms | correct / lost — **same skeleton as §13.7.1, so §13.8 audio and §13.9 haptics port byte-for-byte** |
| `d.crossfade` / `d.rm` | 220 / 260 ms | screen transitions / every Reduce Motion substitution |

## 6. Texture logic — what replaces bloom

**Paper tooth (replaces `loomGrain`).** One `.colorEffect`, multiplicative, **no `t` term anywhere** — paper does not shimmer, so Reduce Motion is free and there is nothing to freeze.

```metal
[[ stitchable ]] half4 plateTooth(float2 p, half4 c, float2 size, float amt) {
    float n     = fract(sin(dot(floor(p), float2(12.9898, 78.233))) * 43758.5453);
    float tooth = 1.0 + 0.022 * (n - 0.5);                      // ±1.1 %, 1 px, static
    float laid  = 1.0 + 0.006 * sin(p.x * 0.2617994);           // 24 px wire mark, ±0.3 %
    float2 q    = p * 0.011;
    float c1    = fract(sin(dot(floor(q),     float2(19.19, 47.13))) * 24634.6345);
    float c2    = fract(sin(dot(floor(q*2.7), float2(11.71, 83.31))) * 18391.1113);
    float cloud = 1.0 + 0.018 * ((c1*0.65 + c2*0.35) - 0.5);    // ±0.9 %, 2 octaves, stock
    return half4(c.rgb * half(mix(1.0, tooth * laid * cloud, amt)), c.a);
}
```

No scanline (that is the trope); no vignette (a vignette is a lens, and paper has no lens). Budget ≤ **0.35 ms/frame** at 120 Hz on A15; `amt = 0` under Reduce Transparency, High Contrast, Low Power. ±1.1 % on an sRGB value near 240 is ≈ ±2.6 code levels: above the dither floor, below banding.

**Plate impression.** Every region that would have been a card is **pressed into** the sheet instead — four concentric strokes, no gradients, no layers: outer `0.75 pt` `stroke.hairline` @ 1.00, then `0.5 pt` hairlines inset 1 / 2 / 3 pt at α 0.55 / 0.30 / 0.14, with the interior stepping to `ground.sunken` (1.07 : 1). **Depth is impression, not luminance** — the one knowing departure from §13.1, and it departs toward the physical; soft shadows and `.ultraThinMaterial` stay forbidden. **Registration marks:** four printer's crosses at the platemark corners: 12 pt arms, 0.5 pt `stroke.hairline`, 3 pt centre gap. They are **state-bearing** — through the whole round each cross's vertical arm sits **2 pt out of true**, and they close only at the impression (§7). A `6 × 24 pt` colour bar at the trailing foot shows two solid patches, ink and copper: the legend for the whole two-plate rule, drawn diegetically, wordlessly, once.

**Ink squash (replaces bloom).** Every stroked mark is drawn **twice into the same layer** — once at `weight × 1.22`, α `0.08`, `round` join, then at full weight. Bloom is light spilling out; squash is ink spreading out, and ink spread is hard-edged, so there is **no blur filter, no `drawLayer`, no offscreen pass, ever.** §13.5 spends three offscreen blur layers per frame (throat, ribbon, tail); PLATE spends zero, and the Assay's bloom exclusion stops being a special case. **Dot gain is declined:** real presses gain, PLATE does not, because `fill` coverage is game state and `22.7 %` must be `22.7 %` at 24 pt and at 220 pt.

## 7. The money shot — THE IMPRESSION

**The problem, stated honestly: nothing can light up.** §13.7.1 beat 4 is a brass hairline sweep stepping every tile from `stroke.primary` to `accent.brass` — a luminance event that only works on a dark ground. On paper the same move is a brightening of an already-bright surface: invisible. **The answer: the second plate lands in register, and the paper takes it.** The player's declaration is the **ink plate**; the hidden law is the **copper plate**. Same 1,840 ms skeleton, so audio and haptics port unchanged.

| Beat | t (ms) | Dur | What happens | Easing |
|---|---|---|---|---|
| 0 | 0 | 90 | Seal depresses 2 pt; the cancel band, if any, slides off the trailing edge | `e.press` |
| 1 | 90 | 140 | unlit Bench chrome → 0; ribbon → `o.low`; the Assay holds at full | `e.settle` |
| 2 | 230 | 260 | the player's rule-tiles gather into a centred stack — the **ink plate** — arriving **8 pt out of register**. No overshoot. | `e.press` |
| 3 | 490 | 320 | the hidden law prints **behind** in `accent.verdigris` at `o.mid`, offset `6 + 18·d` pt where `d` is normalised extension disagreement — a near miss lands almost square, a wild guess lands 24 pt off. **The misregistration is evidence**, which §13.7.1 does not carry. | `e.settle` |
| **4** | **810** | **180** | **THE IMPRESSION.** Copper slides to zero offset over 120 ms; at contact, in 40 ms and with **zero luminance increase anywhere**: (a) all four registration crosses close their 2 pt break; (b) the platemark debosses — bevel 0 → 3 pt, interior steps `ground` → `ground.sunken`; (c) **every stroke on screen gains +0.5 pt weight for 40 ms**, then returns; (d) `w.squash` goes ×1.22 → ×1.55 → ×1.22 over 90 ms. The screen becomes momentarily **heavier**, not brighter. | `e.press` |
| 5 | 990 | 220 | the Assay's lit constellation contracts into a 64 pt **stipple** thumbnail and docks below the stack | `e.press` |
| 6 | 1210 | 240 | Seal marks **punch** in, one per 80 ms — no scale-up, because a punch does not grow; each arrives at 1.00 with a 3 pt deboss ring collapsing to 0 over 90 ms | `e.press` |
| 7 | 1450 | 260 | the Codex plate frame draws itself, hairline, from the top-leading corner, clockwise | `e.draw` |
| 8 | 1710 | 130 | a 3 pt global downward drift resolves to 0; the continue affordance fades in | `e.settle` |

**Why it reads as a mechanism unlocking:** beats 2–3 are two plates that visibly *do not line up*, beat 4 is the platen closing, beats 5–7 are the sheet pulled and filed. Registration is the most legible binary in printing — a cross is closed or it is not — and it survives greyscale, High Contrast, 1.35× Dynamic Type and a 44 pt thumbnail, none of which a bloom does. **Round lost, 1,020 ms:** beat 2 unchanged; at beat 3 the copper plate prints **alone** while the ink plate falls 24 pt and fades over 180 ms; at beat 4 the crosses **do not close**, they widen 2 → 5 pt, and the platemark does not deboss; beats 5–7 skipped; beat 8 at t = 890. **Reduce Motion:** one 260 ms crossfade to the settled composition — crosses already closed, platemark already debossed, marks already punched.

## 8. The verdict without luminance

§13.7.2's direction-and-closure encoding is kept, and three further achromatic channels are added because the ring can no longer lean on brightness.

| Channel | admit | reject |
|---|---|---|
| radius | R → 1.35 R, 200 ms `e.lift` | 1.35 R → R, 160 ms `e.press` |
| closure | closed, with a visible **8° overlap** where the compass arc crosses its own start | at t 160 breaks into 4 arcs separating 3 pt over 90 ms |
| dash | solid | `4 / 3` pt dashed for its whole life — even closed frames differ |
| weight | 3 → 1 pt | 3 → 3 pt |
| **plate** | printed in `accent.verdigris` — **the copper plate takes** | drawn in `stroke.primary` — **the copper plate does not print** |
| cancel | none | a **doubled** 3 pt stroke pair, 5 pt apart, at **−60°**, drawn corner-to-corner across 1.35 R over 90 ms |
| ribbon tile | verdigris ring + a 6 pt verdigris tick, leading-foot corner | **blind emboss**: `stroke.hairline` ring + a 0.5 pt `ground.raised` highlight offset (0.5, 0.5) — an impression with no ink at all |
| Differentiate Without Colour | tick doubles to 12 pt | ring gap 3 → 6 pt; cancel 3 → 4 pt, extends to 1.6 R |

−60° collides with none of the index register's {0°, 45°, 90°, 135°}, is doubled, and sits outside 1.35 R where the index stroke never reaches. Presence-versus-absence of the copper plate is additionally a **19.8 : 1** luminance difference between the two rings, against §13.2's brass/cold pair at a measured 1.22 : 1 — so a monochromat reads the verdict four ways over.

## 9. The Codex as a book of plates, and the chrome

A **page** is a plate: platemark, 12 pt margin, the law in rule-tiles printed centred, colour bar at the foot. Text is permitted here — Codex is chrome — so a page carries plate number, date and band in SF Mono, which is what makes the book real rather than themed. The **extension thumbnail** is a **printed constellation**: the 16 × 16 table as a stipple field, admitted cells as 1.6 pt ink dots on a 4 pt grid, rejected cells as bare paper. At 64 pt it is an astronomical plate; at 343 pt it is the same drawing. This is PLATE's strongest single argument — the Assay's constellation metaphor is *literal* on paper and merely poetic on glass. A **fracture** is a **foul bite**: a 12 pt ragged notch on the trailing-top corner, seeded deterministically from the plate number so a page's damage is stable forever. The Codex **list** is a plate box of `ground.raised` sheets, each with its own platemark and a 44 pt thumbnail. The instrument bar becomes a **plate header**: the probe tally is a graduated printer's scale — 0.5 pt minor ticks 4 pt tall at 6 pt pitch, 1.0 pt major ticks 8 pt tall every fifth — with `par` marked by a 1 pt `accent.verdigris` caret beneath and `cap` by a doubled ink tick. Still zero numerals, zero letterforms. The mode sigil sits inside its own 20 × 20 platemark. Panels separate by platemark plus one ground step: no cards, no shadows. The Bench is a **second sheet laid over the first** — 8 pt top corners, a 1 pt `stroke.hairline` top edge and a 3 pt `ground.sunken` band beneath, a *drawn* sheet edge in four vector calls, not a blur. Typography is §13.4 verbatim with two deltas: `section` and `micro` tracking +0.02 em, because letterspacing reads as engraving; `numeral` unchanged, because monospaced digits are non-negotiable.

## 10. Weaknesses — honest

1. **It contradicts the brief.** Dark-first is a stated instruction and PLATE overrules it. If the brief is load-bearing for reasons outside this document, PLATE is disqualified on sentence one and nothing above matters.
2. **Night play is genuinely worse, and OLED battery is worse.** A near-full-field `#EFE7D5` at 3 a.m. is unpleasant, and on OLED a bright field costs roughly 3–5× the panel power of a dark one. The dark theme exists and is decent; it does not fix the default.
3. **Two artefacts, one game.** Paper does not invert into paper, so PLATE's dark theme is *chalk on prepared board* — a different object with a different emotional register. PLATE ships two art directions, doubles the review surface and the snapshot matrix, and will drift. Direction A's dark and light are one artefact at two exposures. PLATE's dark theme is also measurably the weaker palette (min dichromat ΔE 8.7 against light's 13.7).
4. **The money shot is quieter, and it must be learned.** Registration only pays off for a player who noticed the crosses were broken for the last twelve minutes; a bloom needs no prior. A first-round player may read beat 4 as "things moved slightly", which is the worst possible outcome for the emotional peak of the loop.
5. **One accent makes geometry do more work than it may survive.** `reject`, `strike`, `barred` and `counterexample` all resolve to ink-plus-texture and must be told apart by shape alone — four wordless states in one register, where A has two registers to spend. This is the likeliest place PLATE fails usability testing.
6. **Green accent, dark inks, and an argument that never ends.** `accent.verdigris` beside `hue.teal` is a green-on-green adjacency, provably safe here (1.35 : 1 luminance, disjoint registers, geometry-encoded verdict) and flagged in every accessibility review forever. Relatedly `hue.amber` at `#3F2800` does not look amber: the enum name and the pigment part company, and every new author trips over it once.
7. **Hairlines are more fragile on paper.** A 0.5 pt `stroke.hairline` at 1.53 : 1 on a light ground is one device pixel of pale grey; the same token on a dark ground reads as a bright line. PLATE's chrome degrades faster at small sizes and on poor panels.

## 11. Two defects found in §13.5 while building the renderer

**The coordinate convention is self-contradictory** — §13.5 gives `bodyCentre = (0, +0.10·S)` and the index at `y = −0.43·S` and says the index sits **below** the body (y-up), but also gives the triangle as "apex up at −90°, +30°, +150°" and pips N at −90° (y-down). Read literally in either single convention the glyph renders index-above-body, or triangle apex-down. The renderer resolves it the only way that satisfies every word: **screen space, y down, body centre `−0.10·S`, index centre `+0.43·S`.** This affects both directions. **The glyph also overflows its box:** index centre `0.43·S` + half-length `0.1365·S` = `0.5665·S`, so `frost` (90°, vertical) bleeds **6.65 % of S** past the bottom edge — 2.9 pt at S = 44, 6.4 pt at S = 96. Either the ribbon tile reserves a 1 : 1.134 box or the index register moves to `0.36·S`. Today it silently clips.

## 12. The renderer — verified headless: 256/256 distinct SVG signatures at S = 96; N pip on the vertex for triangle and hexagon (y = −45.1) and mid-edge for square and circle (y = −34.7); index length 26.21 pt at 0/45/90/135°, 39.26 pt under HC; measured coverage 22.7 % and 38.6 %

```js
const PLATE_LIGHT = { ground:'#EFE7D5', ink:'#16120C', squash:true,  hc:false,
  hue:{ amber:'#3F2800', teal:'#003424', frost:'#285B77', rose:'#693B54' } };
const PLATE_DARK  = { ground:'#1B1815', ink:'#EDE4CF', squash:true,  hc:false,
  hue:{ amber:'#E9A100', teal:'#00C792', frost:'#4DA3D3', rose:'#D67FAF' } };
const PLATE_HC    = { ground:'#FFFFFF', ink:'#000000', squash:false, hc:true,
  hue:{ amber:'#000000', teal:'#000000', frost:'#000000', rose:'#000000' } };

// fill hollow|dotted|striped|solid · shape circle|triangle|square|hexagon · pips one..four · hue amber|teal|frost|rose
function plateGlyph(fill, shape, pips, hue, S, theme = PLATE_LIGHT) {
  const NS = 'http://www.w3.org/2000/svg';
  const el = (n,a) => { const e = document.createElementNS(NS,n); for (const k in a) e.setAttribute(k,a[k]); return e; };
  const uid = 'pg' + (plateGlyph._n = (plateGlyph._n || 0) + 1);
  const R = 0.37*S, cy = -0.10*S, iy = 0.43*S;    // body sits high, index low — see §11
  const w = S >= 48 ? 3 : 1.5, ink = theme.hc ? theme.ink : theme.hue[hue];  // index stays 3 always
  const verts = { circle:null, triangle:[-90,30,150], square:[-45,45,135,225],
                  hexagon:[-90,-30,30,90,150,210] }[shape];
  const P = (deg,r) => [r*Math.cos(deg*Math.PI/180), cy + r*Math.sin(deg*Math.PI/180)];
  const body = s => verts ? el('polygon',{ points: verts.map(a => P(a,R*s).join(',')).join(' ') })
                          : el('circle', { cx:0, cy:cy, r:R*s });
  const svg = el('svg',{ width:S, height:S, overflow:'visible',
    viewBox:`${-S/2} ${-S/2} ${S} ${S}`, 'shape-rendering':'geometricPrecision' });
  const defs = el('defs',{}); svg.appendChild(defs);
  const put = (node,weight) => {              // ink squash: two draws, one layer, never a blur
    if (theme.squash) { const g = node.cloneNode(false);
      g.setAttribute('stroke-width', weight*1.22); g.setAttribute('opacity', 0.08);
      g.setAttribute('stroke-linejoin','round'); svg.appendChild(g); }
    svg.appendChild(node); };

  // FILL — interior texture, inset 1.5x body weight, pitch-pinned so coverage is size-invariant
  if (fill !== 'hollow') {
    const apothem = verts ? R*Math.cos(Math.PI/verts.length) : R;
    const inset = (apothem - 1.5*w)/apothem, pitch = Math.max(5, 0.22*R);
    let paint = ink;
    if (fill !== 'solid') {
      const pat = el('pattern',{ id:uid+'p', patternUnits:'userSpaceOnUse' });
      if (fill === 'dotted') {                // hex packing, r = 0.25 pitch -> 22.7 %
        const h = pitch*Math.sqrt(3);
        pat.setAttribute('width',pitch); pat.setAttribute('height',h);
        [[0,0],[pitch,0],[0,h],[pitch,h],[pitch/2,h/2]].forEach(([x,y]) =>
          pat.appendChild(el('circle',{ cx:x, cy:y, r:0.25*pitch, fill:ink })));
      } else {                                // +45 deg lines, 0.386 x pitch -> 38.6 %
        pat.setAttribute('width',pitch); pat.setAttribute('height',pitch);
        pat.setAttribute('patternTransform','rotate(45)');
        pat.appendChild(el('rect',{ width:0.386*pitch, height:pitch, fill:ink })); }
      defs.appendChild(pat); paint = `url(#${uid}p)`; }
    const f = body(inset); f.setAttribute('fill',paint); svg.appendChild(f); }

  // SHAPE — outer silhouette, miter joins, zero corner radius, always
  const b = body(1);
  b.setAttribute('fill','none');     b.setAttribute('stroke',ink);
  b.setAttribute('stroke-width',w);  b.setAttribute('stroke-linejoin','miter');
  b.setAttribute('stroke-miterlimit','10'); put(b,w);

  // PIPS — filled discs where the compass ray meets the silhouette, N -> E -> S -> W
  const n = { one:1, two:2, three:3, four:4 }[pips], nodeR = Math.max(3, 0.11*R);
  for (let i = 0; i < n; i++) {
    const a = [-90,0,90,180][i]*Math.PI/180, d = [Math.cos(a), Math.sin(a)];
    let t = R;                                // circle: the ray meets it at R
    if (verts) { t = Infinity;
      for (let j = 0; j < verts.length; j++) {          // ray/segment intersection, per edge
        const A = P(verts[j],R), B = P(verts[(j+1)%verts.length],R);
        const ex = B[0]-A[0], ey = B[1]-A[1], den = d[0]*ey - d[1]*ex;
        if (Math.abs(den) < 1e-9) continue;
        const s = (A[0]*ey - (A[1]-cy)*ex)/den, u = (A[0]*d[1] - (A[1]-cy)*d[0])/den;
        if (s > 0 && u >= -1e-9 && u <= 1+1e-9) t = Math.min(t,s); } }
    svg.appendChild(el('circle',{ cx:d[0]*t, cy:cy + d[1]*t, r:nodeR, fill:ink,
      stroke:theme.ground, 'stroke-width':2, 'paint-order':'stroke' })); }   // 1 pt knockout

  // HUE — the index stroke. Colour is the redundant copy; the angle is the channel.
  const L = (theme.hc ? 0.409 : 0.273)*S/2, ia = { amber:0, teal:45, frost:90, rose:135 }[hue]*Math.PI/180;
  put(el('line',{ x1:-L*Math.cos(ia), y1:iy - L*Math.sin(ia), x2:L*Math.cos(ia), y2:iy + L*Math.sin(ia),
                  stroke:ink, 'stroke-width':3, 'stroke-linecap':'butt' }), 3);
  return svg;
}
```
