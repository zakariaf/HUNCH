# tick-row.md — `TickRow.draw`

<!-- inventory: Tick row | TickRow.draw -->

Contents: [1 Geometry](#1-geometry) · [2 Modes](#2-modes) · [3 The par crossing](#3-the-par-crossing) ·
[4 The Swift](#4-the-swift) · [5 Environment behaviour](#5-environment-behaviour) ·
[6 The `C.TickRow` namespace](#6-the-ctickrow-namespace) · [7 What would be wrong](#7-what-would-be-wrong)

Seven sites: par row (§6.2, §6.9) · cap row (§6.9) · Codex `bestProbes` strip (§11.1) · Inscription
strip (§11.8) · ECHO cast ticks (§8.4) · SIEVE foul ticks (§9.2) · Profile *Tempo* sigil (§11.11 P3).

**This row is the only running state readout on a surface with no text.** §5.4 makes its *length* the
only difficulty signal the player gets — 7 ticks at band 1, 29 at band 8, uncountable at a glance past
about seven (§10.5). Everything below protects that one property.

---

## 1. Geometry

Ticks are **filled rectangles**, 2 pt wide, on a **shared baseline**, differing by **height**:

| Element | Height | Where |
|---|---|---|
| taken tick | **11 pt** | par row, cast ticks, foul ticks, `bestProbes` strip |
| remaining tick | **4 pt** | the same rows, same baseline |
| cap stop | **7 pt** | the cap row, below the par row |
| crossed rule | **2 pt** | the par row after the crossing, one solid bar |

**State is a height step, not a tint** — PHOSPHOR mockup, exhibit 3, and the reasoning is worth
carrying: the row previously ran taken ticks in `stroke.secondary` against remaining ticks in
`stroke.hairline`, which is a state gap of barely two to one on a 2 × 11 pt mark **and** a hairline
doing state duty, which `palette.md` forbids outright. (Recompute the gap rather than trusting a
number written here: `swift .claude/skills/hunch-design-tokens/scripts/contrast.swift`.) Both states
now carry the same ink and differ by length. Both clear the 3 : 1 graphical floor, the count is read
off the length of the filled run, and the row survives greyscale, every dichromacy and a monochromat.

**Pitch** (§6.2, and it is `HunchUI`'s not `HunchCore`'s — `08-APPLIED-TO-HUNCH.md` §2 puts
`Band.par`/`Band.cap` in core and `tickPitch` in layout):

```
tickPitch = min(nominalPitch, rowWidth / total)      // nominalPitch 9 pt SE · 10 pt Pro Max
                                                     // rowWidth    288 pt SE · 348 pt Pro Max
```

At PROBE's longest par (29) that is a fixed 9 pt pitch and a 261 pt row on SE — inside 288, so within
PROBE the row's length is exactly proportional to par and §10.5's signal is intact. The clamp engages
only in DRIFT, where `par` reaches **40** at band 8: `40 × 9 = 360 > 288`, so the pitch compresses to
`288 / 40 = 7.2` pt. The tick stays 2 pt, leaving ≥ 5.2 pt of gap, and DRIFT's tick count already
identifies the mode by design.

**Ink is `stroke.secondary` for both states.** `palette.md` §1's use column: *"chrome rules, tick
marks, labels"*.

---

## 2. Modes

| Mode | Drawing | Sites |
|---|---|---|
| `.count(filled:total:)` | `total` ticks, the first `filled` at 11 pt and the rest at 4 pt | par row, `bestProbes` strip, cast ticks (all filled), foul ticks (`total` 3) |
| `.crossed(total:)` | one 2 pt rule spanning `total × pitch − 7` | the par row after the crossing |
| `.cap(remaining:total:)` | `remaining` stops at 7 pt, drawn from the **leading** end; spent stops are **absent**, never dimmed | the cap row |
| `.silhouette(total:)` | `total` ticks all at 4 pt | the Inscription's par reference drawn beneath your count (§11.8) |

**The cap row's `total` is `cap − par`**, not `cap`: it is the budget that remains after par, which is
what "begins emptying" means. At band 5 that is `37 − 23 = 14` stops.

**A spent cap stop is an absence.** Dimming it would put a second, weaker copy of the same information
on the row and reintroduce exactly the tint channel §1 removed.

**Length-proportional vs fixed-count** (scope §3) is not a branch in this function. Both come out of the
one pitch formula: a fixed-count row (3 fouls, `L` cast positions) simply has a `rowWidth` its `total`
never threatens, so the clamp does not engage.

---

## 3. The par crossing

On the probe that fills the last par tick, at t = 260–420 ms of the verdict beat (§6.5, §6.9): the par
row goes `.count` → `.crossed`, and on the same frame the cap row lights fully and begins emptying from
the trailing end with the next probe. *"The instrument bar's only animated element reverses direction,
once, permanently, at the exact probe where score begins to decay and the page drops to one mark."*

**No audio, no haptic** (§6.9's decision): the crossing lands on the same frame as a verdict, and the
verdict owns those two channels absolutely. A second cue there would teach the player that "sometimes
the admit tone is different", which is a lie about the law. **Do not wire a cue to this.**

**The transition is a crossfade in both motion modes.** §13.7.4 has no row for the crossing because
nothing translates, scales or rotates: the two drawings crossfade over `Dur.micro` (120 ms). The
substitution is the identity, which is the same shape §13.7.4 gives the Assay's live morph — *"cells
switch instantly; the whole Assay crossfades over 120 ms"*. Recorded here because a reader will look for
the row and not find it.

---

## 4. The Swift

```swift
import SwiftUI
import Tokens

public enum TickRow {
    public enum Mode: Hashable, Sendable {
        case count(filled: Int, total: Int)
        case crossed(total: Int)
        case cap(remaining: Int, total: Int)
        case silhouette(total: Int)
    }

    /// Draws one tick row, baseline-aligned to the bottom of `frame`.
    ///
    /// `nominalPitch` and `frame.width` are device geometry and come from the host (§6.2): pitch is
    /// `min(nominalPitch, frame.width / total)`, so the row's length stays proportional to `total`
    /// wherever that clamp does not engage — which is everywhere in PROBE and only at DRIFT band 8
    /// otherwise. That proportionality is §10.5's difficulty signal and is the row's whole job.
    ///
    /// The context is taken by value; nothing set here escapes to the caller.
    ///
    /// - Complexity: O(total).
    public static func draw(
        into context: GraphicsContext,
        frame: CGRect,
        mode: Mode,
        nominalPitch: CGFloat,
        layout: LayoutDirection = .leftToRight,
        env: RenderEnv
    ) {
        // `let`: `fill` is non-mutating and this mark sets nothing on the context, so a `var`
        // would be an unmutated variable — `03 W18`, and a Release build failure under
        // `-warnings-as-errors`.
        let ctx = context
        let shading = GraphicsContext.Shading.color(env.palette.stroke.secondary.color)
        let scale = env.artScale                      // heights only — never the pitch, see §5
        for bar in bars(mode: mode, frame: frame, nominalPitch: nominalPitch,
                        scale: scale, layout: layout) {
            ctx.fill(Path(bar), with: shading)
        }
    }
}
```

`bars(mode:frame:nominalPitch:scale:layout:)` is `private` and returns `[CGRect]`. Returning rectangles
rather than a `Path` keeps the row expressible as a `fill`, which is what makes the 2 pt tick exact:
a 2 pt *stroke* would centre on a line and land on half-pixels at the odd pitches the clamp produces.

---

## 5. Environment behaviour

**VoiceOver.** No element. §13.10 gives the probe tally `.staticText` `.updatesFrequently`, label
"Probes", value **"12 of 23 expected, 37 maximum"**. Numbers *are* spoken even though they are never
drawn — accessibility labels are audio and the no-text rule constrains rendered pixels only (§2,
§13.10). Two announcements ride on this row and fire **once per round each**: *"Past the expected probe
count."* at the crossing and *"Five probes remaining."* at cap − 5.

**Dynamic Type — heights scale, pitch does not, and this is load-bearing.** `env.artScale` multiplies
the four heights (11 → 14.85 pt at the 1.35 ceiling, inside the 44 pt instrument bar) and **never** the
pitch. If pitch scaled, PROBE's band-8 row would need `29 × 12.15 = 352` pt against 288 and the clamp
would engage, compressing the pitch to 9.93 pt — and then band 1 (7 ticks, unclamped at 12.15 pt) would
render 85 pt against band 8's 288 pt, a ratio of 3.39 where the true par ratio is 4.14. **Dynamic Type
would silently distort the only difficulty signal the player is given.** §6.2 states that the clamp
engages only in DRIFT; holding the pitch is what keeps that true at every type size.

**Reduce Motion.** Nothing. The row does not translate, scale or rotate in either mode; the crossing is
a crossfade already (§3).

**High Contrast.** Ink resolves to `stroke.secondary`'s High Contrast value (`palette.md` §1's measured
column). **Heights and the 2 pt width are unchanged.** §13.11's `+0.5` applies to *stroke weights*; a
tick is a filled rectangle, like an Assay cell or a glyph box, and widening it would eat the ≥ 5.2 pt
gap the clamped DRIFT row is already down to while adding no information the resolved ink does not
already carry.

**Bold Text.** Nothing, for the same reason. The state channel here is length, and Bold Text has no
length to give it.

**Differentiate Without Colour.** Nothing. Both states already share one ink.

**Bloom.** Never — chrome, above the play surface's shader band and outside every glyph-bearing region.

**RTL.** The row does **not** mirror. §2 renders instrument scales leading-to-trailing in source order in
every locale, and this row is an instrument scale: probe 1 is at the leading end everywhere. `layout` is
in the signature for exactly one thing — the cap row empties from the **trailing** end (§6.9), and
"trailing" is a reading-order word.

---

## 6. The `C.TickRow` namespace

| Member | Value | Home of the number |
|---|---|---|
| `takenHeight` | `11` pt | PHOSPHOR mockup, exhibit 3 |
| `remainingHeight` | `4` pt (`Space.s4`) | PHOSPHOR mockup, exhibit 3 |
| `capHeight` | `7` pt | PHOSPHOR mockup, `drawBar()` |
| `crossedRuleHeight` | `2` pt | PHOSPHOR mockup, `drawBar()` |
| `tickWidth` | `2` pt | §6.2 — *"The tick itself stays 2 pt wide"* |
| `crossedRuleInset` | `7` pt off the trailing end | PHOSPHOR mockup, `drawBar()` |

`nominalPitch` (9 / 10 pt) and `rowWidth` (288 / 348 pt) are **device layout**, not tokens: they come
from the host, per §6.2 and `08-APPLIED-TO-HUNCH.md` §2's boundary rule — screen geometry in `HunchCore`
would make `swift test` depend on a device idiom.

`takenHeight` is the one value in this skill that is off the 4 pt grid. It is kept because it was
*measured* against the 44 pt instrument bar rather than chosen, and because moving it to 12 would
compress the 11 : 4 length ratio the state channel depends on.

---

## 7. What would be wrong

- **Distinguishing taken from remaining by tint.** It fails the 3 : 1 graphical floor and puts a
  hairline in a state-bearing role. The measured version of this mistake is in the mockup's own note.
- **Scaling the pitch with `env.artScale`.** §5's arithmetic: it engages the clamp inside PROBE and
  distorts the row's length, which *is* the difficulty signal.
- **Dimming a spent cap stop instead of omitting it.** Two channels for one fact, one of them the tint
  the row exists to avoid.
- **Widening the tick under High Contrast or Bold Text.** It eats the DRIFT clamp's 5.2 pt gap for no
  new information.
- **Wiring audio or a haptic to the par crossing.** §6.9 forbids it by name: the verdict owns those
  channels on that frame.
- **Drawing the Anomaly's 28-cell ribbon as ticks.** §11.8 draws rings — `VerdictRing`, state `.day`.
  Scope §3's "Anomaly tally" row is the Inscription's appended strip, which *is* a tick row.
- **Stroking the ticks instead of filling them.** A 2 pt stroke centres on a line and lands on
  half-pixels at the clamped pitches.
- **A per-tick animation.** The row has one animated moment, the crossing, and it is a crossfade.
- **Mirroring the row under RTL** — or forgetting that the cap row still empties from the trailing end.
- **Adding a numeral.** §13.4 permits numerals in seven named chrome sites and never on the play
  surface; §5.4's P1 makes par uncountable on purpose.
- **Writing a hex or a contrast ratio into this file.** `palette.md`'s measured column is the one
  home. The heights and the pitch formula stay: those are this mark's own geometry.
