# arc-meter.md — `ArcMeter.draw`

<!-- inventory: Arc meter | ArcMeter.draw -->

Contents: [1 Geometry](#1-geometry) · [2 Tracks, scales and styles](#2-tracks-scales-and-styles) ·
[3 States](#3-states) · [4 The accent ration, and the reachable violation](#4-the-accent-ration-and-the-reachable-violation) ·
[5 The Swift](#5-the-swift) · [6 Environment behaviour](#6-environment-behaviour) ·
[7 The `C.ArcMeter` namespace](#7-the-carcmeter-namespace) · [8 What would be wrong](#8-what-would-be-wrong)

Sites: Codex shelf fill arc (§11.2) · suspended mode-key border (§12.4) · Anomaly 24-segment rollover
(§11.7, §12.4) · streak ring (§11.8, §12.4) · SIEVE stream progress (§9.2).

**Nothing in the GDD draws this mark and neither mockup renders it.** The five sites are each specified
in one clause. This file is therefore more *ruling* than *transcription*, and every number in §7 says
where it came from.

---

## 1. Geometry

**One rule for all five sites: a track, and the leading `fraction` of it filled.** The mark strokes
`track.trimmedPath(from: 0, to: fraction)` over the full track, so a circle, a rounded-rect key border
and an open plate arc are the same drawing with different tracks. That is the only way five very
different outlines stay one mark.

**Start at 12 o'clock, fill clockwise, always.** Every one of the five is a dial: hours into a UTC day,
probes into par, pages into a shelf, glyphs into a stream. Starting anywhere else, or filling
anticlockwise, makes one of them disagree with the other four for no reason a player could learn.

**Caps are `butt`.** The *length* of the fill is the readout. Round caps add half a stroke width at each
end — a measurable fraction of a small ring's circumference at `weight.thin`, and on the 24-segment
rollover they would close the segment gaps outright.

**The track is always drawn**, at `env.weight(.hairline)` in `stroke.hairline`, even at `fraction = 0`.
An empty meter with no track is indistinguishable from no meter, and "no shelf progress" and "no shelf"
are different facts.

---

## 2. Tracks, scales and styles

**Track.**

| Case | Built from | Sites |
|---|---|---|
| `.ring(in: CGRect)` | the circle inscribed in the rect, starting at 12 o'clock, clockwise | streak ring, Anomaly rollover |
| `.border(of: CGRect, cornerRadius:)` | the rounded rect's outline, starting at top centre, clockwise | suspended mode key — §12.4: *"the key's border becomes an arc filled to `probesUsed / par`"*, so the track **is** the 168 × 108 pt key's own 2 pt-radius border |
| `.custom(Path)` | whatever the host laid out, already starting where the fill starts | Codex shelf plate's arc, SIEVE stream progress |

**Scale.**

| Case | `fraction` | Where |
|---|---|---|
| `.linear` | `value / total` | shelves with `|H| ≤ 512` — bands 1 (40), 3 (108), 8 (337); mode key `probesUsed / par`; rollover; stream |
| `.logarithmic` | `log(1 + value) / log(1 + total)`, with **notches** on the track at the images of the decade milestones inside range | shelves with `|H| > 512` — §11.2: *"linear arc (`|H| ≤ 512`) vs log-scaled arc with notches"* |

`|H| ≤ 512` is the same threshold §11.3 uses for the serving layer's soft-avoid and §11.4 for slot
maps, deliberately: the shelves you can see the holes in are the shelves whose arc is honest linearly.
On a 2,063-row shelf a linear arc sits at 0.5 % for months and reads as broken; the log arc shows the
first ten finds and the notches say the scale is not linear.

A notch is a radial tick across the track, `2 ×` the track weight either side, in `stroke.secondary`.

**Style** — a closed enum, so a call site cannot pick an ink or a weight and no two sites can drift:

| Case | Fill ink | Fill weight | Segments |
|---|---|---|---|
| `.shelfFill` | `stroke.primary` | `env.weight(.body)` — the token §11.2's "3 pt fill arc" names | — |
| `.keyBorder` | `accent.brass` | `env.weight(.thin)` — the token §12.4's "hairline border" names; **not** `weight.hairline`, which is a different value (`hunch-chrome-and-meta/references/key.md` §2 has the same trap) | — |
| `.rollover` | `stroke.secondary` | `env.weight(.thin)` | **24** |
| `.streak(accented:)` | `accent.brass` when `accented`, else `stroke.secondary` | `env.weight(.bodySm)` | — |
| `.streamProgress` | `stroke.secondary` | `env.weight(.thin)` | — |

Adding a sixth site means adding a `case` here, in public view, which is the point.

**Segments.** `.rollover` divides the ring into 24 arcs of 15°, each drawn at `15° − C.ArcMeter.segmentGap`
(3°), so the gaps are 3° and the arcs 12°. One segment is one UTC hour (§11.7: *"A 24-segment rollover
arc on the tile shows how far into the UTC day you are"*). `fraction` is quantised **down** to a whole
segment: a meter that shows a partial hour would imply a precision the day index does not have.

---

## 3. States

Scope §3 lists *empty · partial · full · static-locked*. As drawings:

| State | This function |
|---|---|
| empty | `fraction = 0` — track only |
| partial | `0 < fraction < 1` |
| full | `fraction = 1` |
| **static-locked** (`.clockBehind`) | `fraction = 1`, and **the host does not pulse it** |

`.clockBehind` is §11.7's clock-back lock: *"the Anomaly tile locks, rendered textlessly as a full,
static rollover ring with no pulse"*. The absence of the pulse is what distinguishes it from a genuinely
completed day, and the pulse belongs to the host — this mark has no clock and never pulses. If a fourth
visual state is ever needed here, it must be geometry, because the app has no colour left to spend on
the Frame (§4).

---

## 4. The accent ration, and the reachable violation

§13.1 rations the accent to **at most three elements per screen**. On the Frame that budget is already
spoken for: at first launch DRIFT, ECHO and SIEVE are all barred (§12.4, §9.10's gates) and each carries
an `accent.cold` machined bar. Three.

Normally the streak ring cannot make it four: a streak increments only on `solvedClean` of an Anomaly
(§11.8), an Anomaly round is served at bands 4–7 (§11.7), and solving it inscribes a page — which unbars
DRIFT, whose gate is *the first inscribed page at band ≥ 3* (§12.4). So having a streak implies at most
two bars.

**"Reset everything" breaks that.** §12.6's DATA table deletes every other file in the tree, and §11.7's
reset-immunity rule keeps `anomaly.json` **byte-identical** — deliberately, because wiping the ledger
*is* the clock exploit. A player who resets everything therefore has a live streak, an empty Codex, and
three barred keys: three cold bars plus a brass streak ring is **four accents on the Frame**.

**The ruling: `.streak(accented: false)` on the Frame's Anomaly key, `accented: true` on `AnomalyView`
and on the Inscription.** No conditional, no state to get wrong. It also matches §12.4, which already
makes the Frame's key a locator — *"no numeral — the tally lives on `AnomalyView`"* — and §11.8, which
puts the celebration on the view that owns the ribbon and the tally.

`hunch-chrome-and-meta` should assert the invariant directly: `FrameView` draws at most three accented
elements, for every combination of unlock state and streak.

---

## 5. The Swift

```swift
import SwiftUI
import Tokens

public enum ArcMeter {
    public enum Track: Hashable, Sendable {
        case ring(in: CGRect)
        case border(of: CGRect, cornerRadius: CGFloat)
        case custom(Path)
    }

    public enum Scale: Hashable, Sendable { case linear, logarithmic }

    public enum Style: Hashable, Sendable {
        case shelfFill, keyBorder, rollover, streak(accented: Bool), streamProgress
    }

    /// Draws a track and fills the leading `fraction` of it, clockwise from 12 o'clock.
    ///
    /// `value` and `total` are the raw counts; `scale` decides how they become a fraction, so a call
    /// site never computes a logarithm and the `|H| ≤ 512` rule (§11.2) is expressed once, here.
    ///
    /// The context is taken by value; nothing set here escapes to the caller.
    ///
    /// - Complexity: O(1), or O(24) for `.rollover`.
    public static func draw(
        into context: GraphicsContext,
        track: Track,
        value: Double,
        total: Double,
        scale: Scale = .linear,
        style: Style,
        env: RenderEnv
    ) {
        // `let`: `stroke` is non-mutating and this mark sets nothing on the context, so a `var`
        // would be an unmutated variable — `03 W18`, and a Release build failure under
        // `-warnings-as-errors`.
        let ctx = context
        let path = trackPath(track)
        let f = fraction(value: value, total: total, scale: scale, style: style)

        ctx.stroke(
            path,
            with: .color(env.palette.stroke.hairline.color),
            style: StrokeStyle(lineWidth: env.weight(.hairline), lineCap: .butt)
        )
        if case .logarithmic = scale {
            for notch in notches(on: path, total: total) {
                ctx.stroke(
                    notch,
                    with: .color(env.palette.stroke.secondary.color),
                    style: StrokeStyle(lineWidth: env.weight(.hairline), lineCap: .butt))
            }
        }
        guard f > 0 else { return }
        let shading = GraphicsContext.Shading.color(fillInk(style, in: env).color)
        let weight = fillWeight(style, in: env)
        for segment in segments(of: path, fraction: f, style: style) {
            ctx.stroke(segment, with: shading, style: StrokeStyle(lineWidth: weight, lineCap: .butt))
        }
    }
}
```

`trackPath`, `fraction`, `notches`, `fillInk`, `fillWeight` and `segments` are all `private`.
`segments(of:fraction:style:)` returns one trimmed path for a continuous style and 24 trimmed arcs for
`.rollover`; that is the only place `trimmedPath(from:to:)` is called in the app outside `LinkArc`.

**`fillInk` is where `AccentColor` is unwrapped**, once, behind the `Style` enum — the same containment
`CancelHatch.Paint` uses. A call site never names a colour, so a hue can never reach a meter and the
Frame's accent ration cannot be spent by accident.

---

## 6. Environment behaviour

**VoiceOver.** No element. The values reach VoiceOver through the hosts: the Anomaly key and the shelf
plates are `hunch-chrome-and-meta`'s, and the suspended mode key is §12.4's — its arc is `probesUsed /
par`, which the probe tally already speaks as *"12 of 23 expected, 37 maximum"* (§13.10). The rollover
carries no announcement at all: it says how far into the UTC day you are, and there is no moment at
which that is news.

**Reduce Motion.** No mark here ever animates, in either mode, and three of the five need saying:

- **The rollover is recomputed on appear and on foreground, never tweened.** It advances 1/24 per hour;
  animating it would be a permanent moving element on the Frame.
- **SIEVE's stream progress steps once per glyph arrival, with no interpolation, in both modes.**
  §13.7.4's SIEVE row replaces travel with a crossfade at an identical cadence and asserts that the
  station a glyph occupies at time `t` is the same with Reduce Motion on and off; a continuously
  interpolating progress arc would be a second clock on that screen, and it would be the only thing
  still moving under Reduce Motion.
- **The streak bloom is the host's**, and §13.7.4 gives it 600 ms normally and a 180 ms crossfade under
  Reduce Motion. The ring itself is static in both.

**High Contrast.** The four inks this mark can take — `stroke.hairline`, `stroke.secondary`,
`stroke.primary`, `accent.brass` — resolve to their High Contrast values, and every weight picks up the
flat `+0.5`. `palette.md` §1's measured column is where those ratios live; none of them is repeated
here. The track at hairline stays deliberately below the state-bearing floor: it is background, and
`palette.md` declares hairline **never state-bearing** — the *fill* is the state. The segment gaps are
angular and do not scale, so the rollover stays segmented.

**Bold Text.** All weights ×1.25 through `env.weight(_:)`. **`.rollover` is the mark's known weak
point**: the gap is a fixed angle, so on a small ring it is barely more than one resolved stroke width
of arc, and a Bold Text rollover reads as very nearly continuous. The arithmetic is
`gap_pt = radius × radians(C.ArcMeter.segmentGap)` against `env.weight(.thin)` — compute it for the
radius in question rather than trusting a figure written down for a different one. If the segmentation
has to survive Bold Text, widen `segmentGap`, do not thin the stroke, and re-check it against the
segment angle.

**Differentiate Without Colour.** Nothing. Fill length against track length is the channel.

**Bloom.** Never — chrome at every site.

**RTL.** Nothing mirrors, at any site. An arc meter is a dial: mirroring the rollover would say the day
runs backwards, and mirroring the suspended-key arc would say probes count down. This is the same
exemption §2 gives glyphs, for the same reason — the drawing is state, not layout.

**Dynamic Type.** The host lays out the track and has already applied `env.artScale` where the site
scales. Keys and the Anomaly tile hold their geometry (§13.11: the Frame's keys and the Profile's
portrait are drawings, not text). Nothing here multiplies by `artScale`.

---

## 7. The `C.ArcMeter` namespace

| Member | Value | Where it came from |
|---|---|---|
| `startAngleDegrees` | `−90` (12 o'clock) | this skill — one convention for all five sites |
| `clockwise` | `true` | this skill |
| `rolloverSegments` | `24` | §11.7, §12.4 — one per UTC hour |
| `segmentGap` | `3°` of `15°` | this skill; see §6's Bold Text note |
| `notchOverhang` | `2 ×` track weight, each side | this skill |
| `logThreshold` | `512` | §11.2, and the same threshold as §11.3 and §11.4 |

Weights and inks are not here — they are `env.weight(.hairline / .thin / .bodySm / .body)` and
`env.palette.stroke.hairline / .secondary / .primary / .accent.brass`, selected by `Style` (§2). The
600 ms streak bloom is §13.7.4's and belongs to `hunch-motion-and-feedback`.

---

## 8. What would be wrong

- **A second progress drawing for any of the five sites.** They look unrelated — a plate arc, a key
  border, a segmented ring — and that is exactly why they diverge.
- **Letting a call site pass an ink or a weight.** `Style` is closed so that the Frame's accent ration
  cannot be spent by a well-meaning edit, and so that a sixth site is a visible `case`.
- **Drawing the streak ring in `accent.brass` on the Frame.** §4's reachable violation: after "Reset
  everything" that is a fourth accent on a screen §13.1 limits to three.
- **A linear arc on a shelf with `|H| > 512`.** It sits under 1 % for months and reads as broken —
  which is why §11.2 specifies the log variant and §11.4 gives those shelves slot maps.
- **Omitting the track at `fraction = 0`.** "No progress" and "no meter" become the same picture.
- **Animating the rollover, or interpolating SIEVE's stream progress.** Under Reduce Motion they would
  be the only things still moving, on the two screens §13.7.4 works hardest to hold still.
- **Round caps.** They lengthen the readout at both ends and close the rollover's 3° gaps.
- **Starting anywhere but 12 o'clock, or filling anticlockwise.** Five dials that disagree.
- **Mirroring under RTL.**
- **Showing a partial segment on the rollover.** It implies a precision the UTC day index does not have.
- **Adding a numeral beside a meter on the play surface or the Frame.** §12.4 states the Anomaly key
  carries no numeral; §13.4 permits numerals only in the seven named chrome sites.
- **Writing a hex or a contrast ratio into this file.** `palette.md`'s measured column is the one
  home, and canon's stated column is wrong in nine cells — a copy imports the error silently.
