# cancel-hatch.md — `CancelHatch.draw`

<!-- inventory: Cancel hatch | CancelHatch.draw -->

Contents: [1 Geometry](#1-geometry) · [2 The two arithmetic constraints](#2-the-two-arithmetic-constraints) ·
[3 Variants and sites](#3-variants-and-sites) · [4 The Swift](#4-the-swift) ·
[5 Environment behaviour](#5-environment-behaviour) · [6 The `C.CancelHatch` namespace](#6-the-ccancelhatch-namespace) ·
[7 What would be wrong](#7-what-would-be-wrong)

Sites: unlit ramp cell (`.hatch`, §4.2) · inert ramp (`.slash`, §4.3) · eliminated ECHO pool member
(`.hatch`, §8.4) · the transient reject verdict ring (`.slash`, §13.7.2 and PHOSPHOR mockup exhibit 4).

**Cancelled means excluded.** It is not "barred" (that is `machined-bar.md`, horizontal, and means *not
yet*) and it is not "disabled". §4.3 abolishes the error state outright, so there is no third reading
for this mark to be confused with.

---

## 1. Geometry

**Angle: −45° in the screen frame**, up toward the trailing edge, for both variants and at every site.

**Variant `.hatch`** — a family of parallel −45° lines at perpendicular spacing
`C.CancelHatch.spacing` (9.9 pt), clipped to the region. On the PHOSPHOR mockup's 44 × 44 ramp cell
that is the five lines at a 14 pt axis step (`14 / √2 = 9.9`).

**Variant `.slash`** — one −45° line through the region centre, clipped to the region. On the reject
ring the region is the square of side `2.12 × ringRadius` clipped as an **ellipse**, which makes the
slash a diameter chord of length `2 × 1.06 × ringRadius` — the mockup's `verdictRing(..., cancel:true)`
exactly.

**Weight: `C.Ramp.cancelHatchWeight(in: env)`** — a **substitution**, not a scaled weight, per §13.11.
That symbol lives in `C.swift` under `C.Ramp` because `hunch-design-tokens` shipped it there as its
worked example of the substitution rule, and **its two values live only there**. It names one of this
mark's four sites, which is untidy; untidy beats two homes for one number. **Read it; do not re-declare
it as `C.CancelHatch.weight`, and do not copy what it returns into this file** — §2's table quotes it
as an input and says so.

**The slash uses the same weight as the hatch, not `weight.hairline`.** §4.3's phrase is *"a hairline
slash"*, and that is prose meaning *thin*: the token named `weight.hairline` is a specific, much
lighter value and `palette.md` declares the hairline *colour* never state-bearing. An inert ramp
already draws at `C.Ramp.inertInk`; the lightest weight at that ink is the only remaining channel
saying *this rail is vacuous*, and it is not a channel. One weight for both variants of one mark.

**Caps `butt`, no join.** Round caps would extend each line by half a weight at both ends and lift
coverage; see §2.

---

## 2. The two arithmetic constraints

These are the reason this mark cannot be eyeballed, and the reason its numbers may not be changed
without redoing the sums.

**(a) The hatch must never be parallel to `striped`.** §13.5 draws the `striped` fill as parallel lines
at **+45°**. A cancel hatch at +45° over a striped glyph interleaves with the fill and disappears; at
−45° the two are exactly perpendicular and the hatch reads over every one of the four fills. This is
also why the hatch is not "a few diagonal lines whichever way looks better".

**(b) The hatch's ink coverage must stay below `dotted`'s 22.7 %.** §13.5.1's greyscale proof rests on
`fill` being readable as ink coverage on the ladder {0, 22.7, 38.6, 100 %}. A hatch laid over or beside a
glyph at a coverage that lands *on* the ladder is a fifth rung and corrupts the channel. For parallel
lines of width `w` at perpendicular spacing `s`, coverage is `w / s`:

**`w` is quoted from `C.Ramp.cancelHatchWeight(in:)`, which is its only home** — the column below is
this derivation's *input*, not a second declaration of the token. If that symbol's values ever move,
every row here is recomputed in the same commit.

| Condition | `w` | coverage | vs `dotted` 22.7 % |
|---|---|---|---|
| normal | 1.0 | **10.10 %** | clear |
| Bold Text | 1.25 | 12.63 % | clear |
| High Contrast (substitution) | 2.0 | **20.20 %** | clear, by 2.5 points |
| High Contrast × Bold Text, **if the substitution were also scaled** | 2.5 | **25.25 %** | ✗ **over `dotted`** |

The last row is why `hunch-design-tokens`' "substitution beats modification" ruling is load-bearing
here and not merely tidy: `C.Ramp.cancelHatchWeight` returns a raw `Double`, not a `StrokeWeight`, so it
never passes through `resolved(in:)` and never picks up Bold Text's ×1.25 or High Contrast's flat +0.5.
**Changing it to a `StrokeWeight` would push the hatch onto the `fill` ladder under two accessibility
settings that are commonly on together.** The PHOSPHOR mockup makes the same point about the attribute
header's old emblem: a 45° hatch at a 4 pt axis step gives a 2.83 pt perpendicular pitch and 49.5 %
coverage — *"a density on no rung of the ladder at all"*.

**If you change `spacing` or the weight, recompute both rows and the High Contrast one.** The margin is
2.5 percentage points.

---

## 3. Variants and sites

| Site | Variant | Region | Paint | Note |
|---|---|---|---|---|
| unlit ramp cell | `.hatch` | the 56 × 44 cell (Bench) | `.chrome` | §4.2. **The hatch is never dimmed with the cell**, whatever the cell does — see §7. The cell's ink is `hunch-bench-instruments`'; only the hatch is ours |
| inert ramp | `.slash` | the whole ramp | `.chrome` | §4.3 — 0 lit or 4 lit is **one** inert state, not two |
| eliminated ECHO pool member | `.hatch` | the 40 × 40 thumbnail | `.chrome` | §8.4 |
| transient reject verdict ring | `.slash` | ellipse of radius `1.06 · r` | `.verdict` | `verdict-ring.md` §1. Settled rings do not take it |
| Anomaly `failed` day cell | `.hatch` | the 11 pt cell | `.chrome` | §11.8 writes "cross-hatch"; see §7 |

`.hatch` on an 11 pt cell at 9.9 pt spacing gives one or two lines. That is correct and deliberate: at
that size the cell is read as *marked* rather than *textured*, and adding a second angle to make it look
busier is what §7 forbids.

---

## 4. The Swift

```swift
import SwiftUI
import Tokens

public enum CancelHatch {
    public enum Variant: Hashable, Sendable { case hatch, slash }

    /// How the region is clipped. `.ellipse` makes the slash a diameter chord, which is what the
    /// transient reject ring needs.
    public enum Bounds: Hashable, Sendable { case rect, ellipse }

    /// Which register the mark draws in. A closed enum rather than a colour parameter, so a call site
    /// cannot reach `.rgb` on an `AccentColor` and launder a register (`check-source-hygiene.sh`
    /// check 10).
    public enum Paint: Hashable, Sendable { case chrome, verdict }

    /// Strikes a region as excluded.
    ///
    /// The −45° angle is fixed at every site and is exactly perpendicular to §13.5's `striped` fill, so
    /// the mark never disappears into a striped glyph. Coverage is held below `dotted`'s 22.7 % — see
    /// this file's §2 before changing `spacing` or the weight.
    ///
    /// The context is taken by value; the clip set here does not escape to the caller.
    ///
    /// - Complexity: O(region.width / spacing) for `.hatch`, O(1) for `.slash`.
    public static func draw(
        into context: GraphicsContext,
        region: CGRect,
        variant: Variant,
        bounds: Bounds = .rect,
        paint: Paint = .chrome,
        env: RenderEnv
    ) {
        var ctx = context
        ctx.clip(to: bounds == .ellipse ? Path(ellipseIn: region) : Path(region))

        let ink = paint == .chrome ? env.palette.stroke.secondary : env.palette.accent.cold.rgb
        let weight = C.Ramp.cancelHatchWeight(in: env)   // the substitution's one home
        let style = StrokeStyle(lineWidth: weight, lineCap: .butt)
        let shading = GraphicsContext.Shading.color(ink.color)

        for line in lines(in: region, variant: variant) {
            ctx.stroke(line, with: shading, style: style)
        }
    }
}
```

`lines(in:variant:)` is `private`. It walks the −45° family from the region's leading-bottom corner and
returns one segment for `.slash`.

**`env.palette.accent.cold.rgb` inside this file is the sanctioned crossing**, not a laundering: the
register decision was made by the `Paint` enum, in `Tokens`-adjacent code, once. What check 10 forbids is
a *call site* doing it to smuggle an accent onto a glyph. Keeping the conversion here is what makes the
call site's `paint: .verdict` unambiguous.

---

## 5. Environment behaviour

**VoiceOver.** No element. The cancelled state reaches VoiceOver through the host's value: a ramp cell
is `.button` `.isSelected` valued "admitted" or not (§13.10); an inert rail contributes "barred, rail 2
is empty" to the Seal's value; the ECHO tray tile is valued "placed, position 2" / "not placed". The
hatch is the visual half of a state VoiceOver already speaks.

**Reduce Motion.** Nothing. The hatch never animates — not on the cell that gains it, not on the rail
that pulses (that pulse is opacity on the *rail*, `hunch-bench-instruments`', and §13.7.4 gives it a
200 ms crossfade to `accent.cold` @ 0.5 α).

**High Contrast.** The weight substitutes rather than scaling — `C.Ramp.cancelHatchWeight(in:)`
returns the High Contrast value directly and resolution terminates there (§13.11). Spacing is
unchanged, so coverage moves with the weight exactly as §2's table computes. Ink is
`stroke.secondary`, whose measured High Contrast ratio is `palette.md` §1's and is not restated here.

**Bold Text.** Nothing, deliberately. See §2's fourth row.

**Differentiate Without Colour.** Nothing. The mark exists *because* the state must be readable with no
colour and no brightness discrimination — §4.2's own words for the unlit cell: *"so the state is
readable with no colour and no brightness discrimination"*.

**Bloom.** Never. The hatch is chrome, it sits on cells and thumbnails rather than inside a
glyph-bearing region's bed layer, and widening it at `opacity.halo` would move its coverage.

**Dynamic Type.** Spacing does **not** scale with `env.artScale`. It is a texture pitch, pinned in
points exactly like §13.5's `pitch = max(5 pt, 0.22 · R)`, and a hatch whose density changed with the
type setting would change its coverage and therefore its relationship to the `fill` ladder at AX2.

**RTL.** The angle does not mirror. A mirrored hatch would run at +45°, parallel to `striped`, and would
vanish on a striped mark in Arabic and Hebrew only — a locale-specific legibility failure nobody would
find. §2 puts instrument scales in source order in every locale; this is the same rule applied to a
texture.

---

## 6. The `C.CancelHatch` namespace

| Member | Value | Home of the number |
|---|---|---|
| `angleDegrees` | `−45` | PHOSPHOR mockup; constrained to be perpendicular to §13.5's `striped` |
| `spacing` | `9.9` pt perpendicular | PHOSPHOR mockup — a 14 pt axis step; coverage is `weight / spacing` |
| `slashOvershoot` | `1.06` × radius | PHOSPHOR mockup, `verdictRing(..., cancel:true)` |

Weight is **not** here — it is `C.Ramp.cancelHatchWeight(in:)`, §1. Colour is
`env.palette.stroke.secondary` / `env.palette.accent.cold`.

---

## 7. What would be wrong

- **Changing `spacing` or the weight without redoing §2's table.** The High Contrast margin to `dotted`
  is 2.5 percentage points, and crossing it puts a fifth rung on the `fill` ladder and breaks §13.5.1's
  proof and its two shipped tests.
- **Turning `C.Ramp.cancelHatchWeight` into a `StrokeWeight`.** It would pick up Bold Text and land at
  25.25 % coverage under High Contrast — over `dotted`. §13.11's substitution is what holds it.
- **Drawing the hatch at +45°.** Parallel to `striped`, invisible on a striped mark.
- **A cross-hatch.** §11.8's word for the Anomaly `failed` cell is prose. Two angles means two families,
  double the coverage (20.2 % normal, 40.4 % under High Contrast — straight past `dotted` and onto
  `striped`), and a second drawing to keep in step. One angle, one family.
- **Round caps.** They add half a weight at both ends of every line and raise coverage for free.
- **Dimming the hatch with the cell.** This is the mark's own rule and it holds under either reading of
  the unlit cell. PHOSPHOR's mockup withdrew `opacity.cellUnlit` precisely because a dimmed ink *and* a
  dimmed hatch both fall under the 3 : 1 graphical floor — *"Two channels neither of which clears
  3 : 1 is not two channels."* `hunch-design-tokens` owns whether that withdrawal stands (it still
  ships `C.Ramp.cellUnlitInk(in:)`, which the mockup says should not exist) and owns every number in
  the argument; this file owns only the consequence, which is that the hatch draws at full ink
  regardless.
- **Scaling `spacing` with `env.artScale`.** Coverage would drift with the type setting.
- **Mirroring the angle under RTL.**
- **Using this mark to mean *barred* or *disabled*.** Barred is horizontal and is `machined-bar.md`;
  there is no disabled state in the play surface's six-state set (scope §5: idle / pressed / selected /
  inert / barred / read-only).
- **Re-declaring the weight as `C.CancelHatch.weight`.** One number, one home; a rename is safe, a
  second declaration is not.
- **Writing a hex or a contrast ratio into this file.** `palette.md`'s measured column is the one
  home. §2's coverage table is different and stays: coverage is *this* skill's derivation, and it
  quotes its inputs by symbol.
