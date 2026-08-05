# throat.md — the well, the aperture, and the one register that moves

Contents: [1 Geometry](#1-geometry) · [2 States](#2-states) ·
[3 Only the changed register animates](#3-only-the-changed-register-animates) ·
[4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `ThroatView` in `Modules/Sources/HunchUI/ThroatView.swift`. **L2:** `C.Throat`.
The glyph inside it: `hunch-glyph-renderer`. The ring around it:
`hunch-shared-marks/references/verdict-ring.md`. The seed glyph's dashed frame and chevron:
`hunch-shared-marks/references/ghost-frame.md`. The verdict beat: `hunch-motion-and-feedback`.

---

## 1. Geometry

*"Where the live glyph sits"* (§2's locked terminology). Three sizes, and the region is always
taller than the glyph so the ring has room to expand to 1.35 R without clipping.

| Site | Glyph `S` | Region | § |
|---|---|---|---|
| PROBE / DRIFT / ECHO, SE | **96** | y 64–176 (112 pt) | §4.1, §6.2 |
| PROBE / DRIFT / ECHO, Pro Max | **128** | y 106–306 (200 pt) | §6.2 |
| the Frame's idle Loom | **128** | y 72–288, a 128 pt throat ring | §12.4 |
| the play-key sigil | **24** | a 24 pt sigil inside a 44 × 44 key | §12.8 |

```swift
extension C.Throat {
    public static let glyphSide = 96.0            // SE
    public static let glyphSideLarge = 128.0      // Pro Max, and the Frame's idle Loom
    /// §12.8: *"the instrument-bar chevron and the play key draw at 24 pt inside a
    /// 44 × 44 hit rect"*. The **hit rect** is 44; the drawing is 24. The rect itself is
    /// `C.Key.rect(.utility, in:)` — `hunch-chrome-and-meta/references/key.md`.
    public static let keySigilSide = 24.0
    /// Submit contracts the glyph before the hold (§6.5, t = 0, `Dur.tap` `easeIn`).
    public static let submitContraction = 0.92
    /// The idle Loom crossfades to a new glyph every 8 s (§12.4). L2: only the Frame's
    /// idle Loom has a period, so there is nothing to share it with.
    public static let idleCrossfadePeriod = Duration.seconds(8)
    /// One register crossfading while three hold, on a Dial change (§6.3). L2 for the
    /// same reason — no other surface animates a single glyph register.
    public static let registerCrossfade = Duration.milliseconds(80)
}
```

**The ring's expansion factor is not declared here.** The well must clear the transient admit ring,
and that radius is `C.VerdictRing.transientAdmitRadius` (1.35 × body radius, §13.7.2), owned by
`hunch-shared-marks/references/verdict-ring.md` §5. There is no `C.Throat.ringHeadroom`; a second
declaration of the same number is the drift this library exists to stop.

The well is `ground.sunken` with a vignette — the shader's own vignette term does this for the whole
play surface (§13.6), so the throat does **not** draw a second one. `S` multiplies by
`env.artScale`; the region does not, which is why the headroom check is `S × 1.35 × artScale`
against the region height and why the Pro Max region is 200 pt for a 128 pt glyph.

**The throat is one of exactly three bloom regions** — throat, ribbon, tail — each getting one
blurred bed layer per frame at `radius: 0.062 · S`, never one per glyph (§13.5, PHOSPHOR §2). Three
offscreen layers per frame, not sixteen. The pass itself is `hunch-glyph-renderer`'s; the *region
boundary* is this file's, and it is the reason the boundary is drawn where it is.

**The throat is read-only, deliberately.** It sits above §12.8's y = 220 line, out of the thumb arc,
*"view-only in the unreachable top third by design"* (§4.1). Its one gesture — a horizontal swipe
stepping the last-touched attribute by ±1 — is a convenience path with a full Dial equivalent, which
is what makes the placement legal.

---

## 2. States

| State | When | Drawing |
|---|---|---|
| **live** | a draft glyph is loaded; the throat *is* the draft (§6.3) | the glyph at full ink, no ring |
| **animating** | the verdict beat (§6.5) | contraction → hold → verdict ring → tile buds off |
| **empty** | ECHO's recall phase, before a primer resolves | the well and its ring track, no glyph |
| **idle** | the Frame's idle Loom | one glyph drifting through, crossfading every 8 s from a seed derived from launch time; **non-interactive** |

The **seed glyph** at probe 0 is a live throat wearing the dashed hollow frame and the backward
chevron (§6.6 layer 1) — the same drawing the ribbon's trailing tile, the Bench's ghost toggle and
the split doubled ring use. *Before probe 1, in every band, the machine visibly is not empty.*

**The adjudication hold** is the throat's signature state and it occupies the middle of the verdict
beat: *"Nothing moves but a hairline aperture rotating in the throat ring."* (§6.5) It is **constant
regardless of verdict, band, or whether the law is contextual**, because variable latency is a side
channel — a Loom that "thinks harder" about hard glyphs would leak the family before probe 3. Never
make the hold depend on the computation. Its length and the beat's are §6.5's input policy, rostered
once in `hunch-motion-and-feedback/SKILL.md`'s three-clocks table.

---

## 3. Only the changed register animates

*"When a Dial cell changes the fill, the fill texture crossfades and the silhouette, contour nodes
and index stroke hold perfectly still. This is not polish: it is what makes controlled variation
visible as an act, and it is why the register-disjointness of canon §2 is load-bearing here."*
(§6.3)

This is the throat's hardest requirement and the one a naive implementation fails silently: crossfading
the *whole glyph* looks fine in isolation and destroys the epistemics, because controlled variation —
change exactly one attribute, hold three fixed — is *the* inductive move (§4.1).

The implementation consequence is a shape requirement on the renderer, not on this view:
`hunch-glyph-renderer` must expose the four registers as four separately drawable passes over one
geometry, so the throat can animate one and hold three. A renderer with a single `draw(glyph:)`
entry point cannot satisfy §6.3, and finding that out at the throat is finding it out late.

The Dial redraw is `C.Throat.registerCrossfade` (§6.3), which is a different clock from the verdict
beat and from the rings' own `Dur.ringAdmit` / `Dur.reject`; keep the three separate
(`hunch-motion-and-feedback`).

---

## 4. SwiftUI

```swift
// Modules/Sources/HunchUI/ThroatView.swift
import HunchCore
import SwiftUI

struct ThroatView: View {
    enum Presentation: Hashable, Sendable { case live, animating, empty, idle }

    let env: RenderEnv
    let glyph: Glyph?
    let presentation: Presentation
    let isSeed: Bool
    let verdict: Verdict?
    let side: Double
    let ringProgress: Double           // the host's clock: 0 at the verdict frame, 1 at rest
    let onStep: (Int) -> Void          // ±1 on the last-touched attribute

    var body: some View {
        ZStack {
            GlyphCanvas(env: env, glyph: glyph, side: side, changedRegister: changedRegister)
            // The marks draw into one `Canvas` on top of the glyph. They are `draw(into:)`
            // functions, never `View`s — `hunch-shared-marks/SKILL.md`'s single-entry rule.
            Canvas { context, size in
                let box = CGRect(origin: .zero, size: size)
                    .insetBy(dx: (size.width - side) / 2, dy: (size.height - side) / 2)
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let bodyRadius = C.Glyph.radius(side: side)

                if isSeed {
                    GhostFrame.draw(into: context, box: box, env: env)
                }
                if let verdict {
                    VerdictRing.draw(into: context, centre: centre, bodyRadius: bodyRadius,
                                     state: verdict.ringState, role: .transient,
                                     progress: ringProgress, env: env)
                }
                if presentation == .animating {
                    AdjudicationAperture.draw(into: context, centre: centre,
                                              bodyRadius: bodyRadius, env: env)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: side * C.VerdictRing.transientAdmitRadius,
               height: side * C.VerdictRing.transientAdmitRadius)
        .contentShape(.rect)
        .gesture(stepGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits([.isImage, .updatesFrequently])
        .accessibilityLabel(Loc.loomThroat)
        .accessibilityValue(Loc.glyphLabel(glyph) + Loc.verdictSuffix(verdict))
        .accessibilityAdjustableAction { direction in
            onStep(direction == .increment ? 1 : -1)
        }
    }

    private var stepGesture: some Gesture {
        DragGesture(minimumDistance: Space.s24)
            .onEnded { onStep($0.translation.width > 0 ? 1 : -1) }
    }
}
```

Three things the sketch is careful about. **`ringProgress`** is the host's animation clock (`0` at the
verdict frame, `1` at rest), passed down rather than read from a timer here; under Reduce Motion the
host passes `role: .settled`, and the ring ignores progress entirely. **`verdict.ringState`** maps
`Verdict` to `VerdictRing.State` in `HunchCore`, so the view never switches on a verdict to pick a
drawing. **The `Canvas` is `.allowsHitTesting(false)`** — the throat's own `.contentShape(.rect)`
carries the gesture, and a `Canvas` that swallowed touches would break the swipe.

`.accessibilityElement(children: .ignore)` and the `.adjustable` action are the pair: the throat is
one element with a value, and the swipe becomes increment/decrement. Without the adjustable action
the throat's only gesture is unavailable to VoiceOver — and unlike the ribbon-load it *has* a Dial
equivalent, so it degrades rather than breaks, which is exactly why §12.8 allows the gesture to live
above the line at all.

`changedRegister` is what §3 needs: an optional `Glyph.Attribute` naming the one register that just
changed, so `GlyphCanvas` crossfades that pass and holds the other three.

---

## 5. VoiceOver

§13.10:

| Traits | Label | Value | Actions |
|---|---|---|---|
| `.image`, `.updatesFrequently`, **`.adjustable`** | `"Loom throat"` | the glyph label + the last verdict | swipe ↑/↓ steps the last-touched attribute ±1 rank |

- The glyph label is **one localized format string with four interpolations** in canonical
  `fill → shape → pips → hue` order — *"hollow triangle, three pips, teal"* — never concatenated
  fragments, and `pips` is itself a plural-aware String Catalog entry (§2, §13.10).
- The verdict announcement fires at the end of the adjudication hold, at priority `.high` so it interrupts, in
  the fixed order **verdict → evidence → bookkeeping**: *"Admit. Hollow triangle, three pips, amber.
  Probe 12 of 23."* A twin is the same, prefixed *"Twin. "*
- **Magic Tap fires Probe** while the Dial is showing (§13.10).
- Numbers are spoken though never drawn: accessibility labels are audio, and the no-text rule
  constrains rendered pixels only (§2).
- The idle Loom on the Frame is **decorative**: `.accessibilityHidden(true)`. It is scenery, and a
  focus stop that announces a random glyph on the menu screen is noise.

---

## 6. Reduce Motion

**The substitutions are `hunch-motion-and-feedback/references/reduce-motion.md` §2, which declares
itself complete.** Seven of its rows land on the throat — throat scale, submit contraction, admit
ring, reject ring, reject shudder, the Dial register crossfade, the idle Loom, plus the grain freeze.
Read the durations there; there is no second table here, because two tables is how a row goes missing.

What this file owns is the **geometry** the substitutions freeze at, and it is the half that is easy
to get wrong:

| Frozen thing | Radius | Why that one |
|---|---|---|
| static **closed** admit ring | `C.VerdictRing.settledAdmitRadius` — 1.18 R | between rest and full expansion, so a still frame reads as *larger than the glyph*. At the transient 1.35 R it reads as a second, unrelated circle |
| static **broken** reject ring | `C.VerdictRing.settledRejectRadius` — 1.00 R | there was never an expansion to freeze |
| the throat's opacity pulse | no radius change | the scale is dropped entirely, not shortened; gate 9 forbids scaling anywhere |

**The input lock shortens under Reduce Motion and the adjudication hold does not.** Both numbers are
§6.5's input policy rather than animation durations, so neither is a `Dur.*` token and neither is
restated here: `hunch-motion-and-feedback/SKILL.md`'s three-clocks table is their one home. The ring's
own substitution never blocks. Read §13.7.2's timings as offsets into §6.5's window, never as an input
policy.

---

## 7. High Contrast

- The glyph inside collapses all four `hue.*` to `stroke.primary` and lengthens the index stroke by
  the ratio `hunch-glyph-renderer/references/geometry.md` owns — at `S = 96` that is 26.2 → 39.3 pt. The well
  must clear it: the index
  register is centred at `0.43·S` below `bodyCentre` and the stroke is half-length either side, so
  the glyph's true vertical extent is larger than `2R` and the region height must be checked against
  it, not against the body.
- Bloom is **off** entirely under High Contrast — both the widened stroke and the layer filter — so
  the throat draws no bed layer and the region boundary costs nothing.
- The shader is off (`amt = 0`), which removes the vignette: the well then relies on `ground.sunken`
  alone, and under High Contrast `ground.sunken` equals `ground.base`. **The well is invisible in
  High Contrast, and that is correct** — the mark is the only thing in the room, and at 21 : 1 it
  does not need a frame.

**Differentiate Without Colour**: the broken reject ring's gap doubles (§13.7.2); that is
`hunch-shared-marks/references/verdict-ring.md`'s business, not this file's.

---

## 8. Wrong

- **Crossfading the whole glyph on a Dial change.** It looks fine and destroys controlled variation,
  which is the game's central move (§6.3). One register moves; three hold.
- **Making the adjudication hold depend on the computation.** Variable latency leaks the family
  before probe 3. Constant, always, whatever the computation cost (§6.5).
- **One bloom layer per glyph.** The throat is a *region*; one bed layer at `radius: 0.062 · S` for
  the whole region (§13.5).
- **A second vignette.** The shader already draws one over the play surface (§13.6).
- **Making the throat a control.** It is above the thumb line and read-only; its one gesture is a
  convenience with a Dial equivalent (§12.8 tier 3). Adding a tap action there breaks the reach
  argument for the whole surface.
- **Exposing the idle Loom to VoiceOver.** Scenery, hidden.
- **Blocking input on the ring.** The rings outlive the input lock by design and never gate input;
  the *beat* gates input.
- **Sizing the well against `2R`.** The index stroke extends below the body and lengthens 1.5× under
  High Contrast; size the well against the glyph's full extent times
  `C.VerdictRing.transientAdmitRadius`.
- **Re-declaring the ring's 1.35 as a `C.Throat` member.** It is
  `C.VerdictRing.transientAdmitRadius`, and it moves when §13.7.2 moves.
- **Drawing the play-key sigil at 44 pt.** 44 is the *hit rect*; the drawing is 24 (§12.8).
- **Concatenating the glyph label.** One format string, four interpolations, canonical order.
