# palette.md — L1 colour, all three themes, measured

Contents: [1 The table](#1-the-table) · [2 Where canon is wrong](#2-where-canon-is-wrong) ·
[3 L0 primitives](#3-l0-primitives) · [4 Register segregation](#4-register-segregation) ·
[5 Aliases](#5-aliases) · [6 Theme selection](#6-theme-selection) · [7 Adding a colour](#7-adding-a-colour)

Every `: 1` below is **computed**, not quoted: WCAG 2.1 sRGB relative luminance against *that theme's own*
`ground.base`, rounded to two places. Reproduce any cell with
`swift ../scripts/contrast.swift '#RRGGBB' '#GROUND'`; re-check the whole file with
`swift ../scripts/check-tokens.swift`.

Provenance: **c** = a `GAME_DESIGN.md` §13.2 table row, hex quoted verbatim (`check-tokens.swift`
check C compares these cell by cell) · **d** = §13.2's † *decision* paragraph rather than a table
row · **‡** = new in `design/DIRECTION-A-PHOSPHOR.md` §1.1 (all six of its new rows recompute
correctly).

---

## 1. The table

`ground.base` is the reference, so it has no ratio. Under **High Contrast all four `hue.*` are
`stroke.primary`** — that is a substitution, not a re-lighting, and it happens inside `Palette.init`
so no call site can forget it.

| Token | | Dark | : 1 | Light | : 1 | High Contrast | : 1 | Use |
|---|---|---|---|---|---|---|---|---|
| `ground.base` | c | `#0B0A08` | — | `#F4EFE4` | — | `#000000` | — | the room |
| `ground.raised` | c | `#15120D` | 1.06 | `#FBF7EE` | 1.07 | `#0A0A0A` | 1.06 | Bench, sheets, Codex plates |
| `ground.sunken` | c | `#050504` | 1.03 | `#EBE4D5` | 1.10 | `#000000` | 1.00 | Assay well, throat vignette |
| `surface.cell` | ‡ | `#100E0A` | 1.03 | `#F7F3EA` | 1.04 | `#000000` | 1.00 | ramp cell / rule-tile interior, unlit |
| `surface.cellLit` | ‡ | `#1C1811` | 1.12 | `#FDFBF6` | 1.11 | `#141414` | 1.14 | ramp cell admitted, row pressed |
| `stroke.primary` | c | `#EFE3D0` | **15.61** | `#1A1712` | **15.58** | `#FFFFFF` | **21.00** | glyph keyline, rule-tile stroke, body text |
| `stroke.secondary` | c | `#6B6153` | **3.26** | `#6E6659` | **4.94** | `#B0B0B0` | **9.68** | chrome rules, tick marks, labels |
| `stroke.hairline` | c | `#3A342B` | 1.61 | `#D6CDBC` | 1.38 | `#5A5A5A` | 3.04 | decorative rules, Assay grid — **never state-bearing** |
| `accent.brass` | c | `#C9922F` | **7.20** | `#8A5E14` | **4.96** | `#FFC24D` | **13.08** | admit, the Seal, marks, streak |
| `accent.brassPress` | ‡ | `#8A6420` | 3.70 | `#5E3F0C` | 8.35 | `#C99433` | 7.77 | brass control, finger down |
| `accent.cold` | c | `#7FD8E0` | **12.06** | `#0E5F72` | **6.32** | `#7FE9FF` | **15.00** | reject, strike, counterexample, barred |
| `accent.coldPress` | ‡ | `#4E9AA2` | 6.10 | `#093F4C` | 10.02 | `#4FB8CC` | 9.06 | cold control, finger down |
| `hue.amber` | c | `#E69F00` | 8.79 | `#E69F00` | 1.96 † | = `stroke.primary` | 21.00 | glyph hue rank 1, index 0° |
| `hue.teal` | c | `#009E73` | 5.78 | `#009E73` | 2.98 † | = `stroke.primary` | 21.00 | rank 2, index 45° |
| `hue.frost` | c | `#56B4E9` | 8.58 | `#56B4E9` | 2.01 † | = `stroke.primary` | 21.00 | rank 3, index 90° |
| `hue.rose` | c | `#CC79A7` | 6.47 | `#CC79A7` | 2.67 † | = `stroke.primary` | 21.00 | rank 4, index 135° |
| `glyph.keyline` | d | — | — | `#1A1712` | **15.58** | — | — | light only; = `stroke.primary`. See `light-theme.md` §2 |

**Okabe–Ito is verbatim in dark and light and is never re-lit.** `#E69F00 / #009E73 / #56B4E9 /
#CC79A7` are the published values, unmodified. † marks the light theme's raw hue contrast, which is
below 3 : 1 and is *supposed* to be — the silhouette is carried by `glyph.keyline` at 15.58 : 1 and
the hue sits inside an ink outline. The measurement that makes that work is **hue against the
keyline**, and it is not in canon: amber 7.93, teal 5.22, frost 7.74, rose 5.84. All four read as a
distinct band inside the outline. Full derivation in `light-theme.md` §2.

**High Contrast floors.** The state-bearing set is `{stroke.primary 21.00, stroke.secondary 9.68,
accent.brass 13.08, accent.cold 15.00, hue.* 21.00}` — minimum **9.68 : 1**, which is what §13.11's
"clears 9.7 : 1" is rounding. `stroke.hairline` (3.04) and `accent.*Press` (7.77 / 9.06) sit below
that floor deliberately: hairline is declared never state-bearing, and a press state is a transient
echo of a control that already cleared the floor at rest.

---

## 2. Where canon is wrong

Nine ratio cells in §13.2 disagree with the arithmetic. Every hex is right; only the stated ratios
are wrong, so **no design consequence follows** — every gate still clears and no token moves. Quote
this file's column, not §13.2's, and let `check-tokens.swift` keep it that way.

| Cell | §13.2 states | Measured | Δ | Consequence |
|---|---|---|---|---|
| `hue.amber` dark | 9.5 | **8.79** | −0.71 | none; PHOSPHOR §1.1's footnote found the same |
| `hue.teal` dark | 6.4 | **5.78** | −0.62 | none; still the worst dark hue and still ≫ 3 : 1 |
| `hue.teal` light | 2.7 | **2.98** | +0.28 | none; the keyline carries the silhouette either way |
| `stroke.hairline` HC | 3.3 | **3.04** | −0.26 | none; hairline is never state-bearing |
| `hue.amber` light | 1.8 | **1.96** | +0.16 | none |
| `stroke.hairline` light | 1.5 | **1.38** | −0.12 | the light theme's weakest line; `light-theme.md` §3 answers it with the platemark rather than a darker hairline |
| `ground.raised` HC | 1.10 | **1.06** | −0.04 | none |
| `ground.sunken` dark | 1.06 | **1.03** | −0.03 | reinforces `light-theme.md` §3: a ground step alone is not a depth cue |
| `ground.sunken` light | 1.07 | **1.10** | +0.03 | none |

**And one prose claim.** §13.2 says `hue.amber` and `accent.brass` sit "1.36 : 1 apart in luminance".
Measured, in the dark theme, they are **1.22 : 1** apart. (`hue.frost` / `accent.cold` at 1.41 is
correct.) The defence against the amber/brass adjacency is therefore register segregation and ring
geometry *only* — do not design a third cue that assumes a luminance gap, and never encode a verdict
by brightness alone.

---

## 3. L0 primitives

`Prim` is the only place a hex may appear. Names are `<family><lightness>`, lightness ascending as
the colour darkens; the step numbers are ordinal, not perceptual. **A view or an L2 token that names
a `Prim` is a bug** — L2 → L1 → L0, nothing skips.

| Family | Members, light → dark |
|---|---|
| `soot` (dark grounds) | `soot750 #1C1811` · `soot800 #15120D` · `soot850 #100E0A` · `soot900 #0B0A08` · `soot950 #050504` |
| `paper` (light grounds) | `paper50 #FDFBF6` · `paper100 #FBF7EE` · `paper150 #F7F3EA` · `paper200 #F4EFE4` · `paper300 #EBE4D5` |
| `bone` (warm ink, both themes) | `bone100 #EFE3D0` · `bone200 #D6CDBC` · `bone450 #6E6659` · `bone500 #6B6153` · `bone700 #3A342B` · `bone900 #1A1712` |
| `neutral` (High Contrast only) | `neutral0 #FFFFFF` · `neutral400 #B0B0B0` · `neutral600 #5A5A5A` · `neutral850 #141414` · `neutral900 #0A0A0A` · `neutral1000 #000000` |
| `brass` | `brass200 #FFC24D` · `brass300 #C99433` · `brass400 #C9922F` · `brass500 #8A6420` · `brass600 #8A5E14` · `brass800 #5E3F0C` |
| `cold` | `cold200 #7FE9FF` · `cold300 #7FD8E0` · `cold400 #4FB8CC` · `cold500 #4E9AA2` · `cold700 #0E5F72` · `cold800 #093F4C` |
| Okabe–Ito | `okabeItoAmber #E69F00` · `okabeItoTeal #009E73` · `okabeItoFrost #56B4E9` · `okabeItoRose #CC79A7` — no lightness steps exist, because these are never re-lit |

`bone` deliberately serves both themes: `bone100` is the dark theme's `stroke.primary` and `bone900`
is the light theme's, which is the sense in which the two themes are one artefact at two exposures.

---

## 4. Register segregation

§13.2 states it as a hard rule a reviewer enforces. Here it is a **type**, so it is a compile error.

```swift
public struct AccentColor: Hashable, Sendable { public let rgb: RGB8; init(_ rgb: RGB8) { … } }
public struct HueColor:    Hashable, Sendable { public let rgb: RGB8; init(_ rgb: RGB8) { … } }
```

Both initialisers are **internal to the `Tokens` module**, so only `Palette` mints them. A drawing
function that takes a `HueColor` cannot be handed an accent, and there is no public way to build one
from a hex.

```swift
// RIGHT — the renderer's signature does the enforcing.
func drawGlyph(_ g: Glyph, ink: HueColor, keyline: RGB8?, in ctx: inout GraphicsContext) { … }
drawGlyph(g, ink: env.palette.hue.teal, keyline: env.palette.glyphKeyline, in: &ctx)

// WRONG — will not compile. This is the point.
drawGlyph(g, ink: env.palette.accent.brass, keyline: nil, in: &ctx)
//             ^ cannot convert AccentColor to HueColor

// WRONG — compiles, and is check 10 of check-source-hygiene.sh.
drawGlyph(g, ink: HueColor(env.palette.accent.brass.rgb), …)   // HueColor.init is internal, so
//  this only compiles inside Tokens; outside, `.rgb` laundering is what the grep looks for.
```

What each register forbids, unchanged from §13.2:

- `accent.*` never touches a glyph body, fill texture, pip, ramp cell or index stroke.
- `hue.*` never touches chrome, a rule-tile frame, a tick mark, the Seal, or the Settings switch —
  which is why the switch is *drawn* (position + fill) rather than tinted.
- `stroke.primary` legitimately serves both sides. It is plain `RGB8`, and it is the value the
  High Contrast hue substitution and the light-theme keyline both resolve to.

---

## 5. Aliases

No new values; they exist so a call site never reaches past its own register. Each is exactly the
token on the right, and none of them may acquire an independent value.

| Alias | Is | Where |
|---|---|---|
| `focus.ring` | `stroke.primary`, 2 pt, 2 pt offset | any focusable control |
| `assay.grid` / `assay.conflict` / `assay.probed` | `stroke.hairline` / `accent.cold` / `stroke.secondary` | Assay |
| `assay.lit` | `stroke.primary` @ `c.assay.litInk` | Assay |
| `mark.earned` / `mark.fracture` | `accent.brass` / `accent.cold` | Seal, Codex plate |
| `scrim.bench` | `ground.base` @ `Opacity.scrim(in:)` | Bench, SIEVE pause |
| `glyph.keyline` | `stroke.primary`, **light theme only** | glyph renderer |

---

## 6. Theme selection

Settings offers System / Dark / Light / High Contrast, default System (Dark below `.light`, Light
above). If `UIAccessibility.isDarkerSystemColorsEnabled` is true **and the player has made no
explicit choice**, force High Contrast. The mapping from system state to `RenderEnv.Theme` lives in
the app-side environment reader — `render-env.md` §4 — never in `HunchCore`, which has no
`UIAccessibility` to read.

The three themes are **accessibility modes, not brands**. There is no theme builder, no fourth
theme, and no per-theme geometry.

---

## 7. Adding a colour

1. Decide the register. If it is neither accent nor hue, it is chrome and returns `RGB8`.
2. Add the L0 literal to `Prim` under the right family, with its measured `L` in a trailing comment.
3. Add the L1 member to `Palette`'s three `case` arms. All three, or the switch will not compile —
   which is the point of a `switch` over a frozen enum with no `default:` (`03 W29`).
4. Measure: `swift ../scripts/contrast.swift '#NEW' '#GROUND'` for each theme.
5. Add the row to §1 above with the measured ratios and a provenance mark.
6. `swift ../scripts/check-tokens.swift` must exit 0.
7. If the value is only meaningful to one component, stop — it was an L2 token, not this file.
