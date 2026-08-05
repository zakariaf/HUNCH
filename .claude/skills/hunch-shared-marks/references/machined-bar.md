# machined-bar.md — `MachinedBar.draw`

<!-- inventory: Machined bar | MachinedBar.draw -->

Contents: [1 Geometry](#1-geometry) · [2 States](#2-states) · [3 The Swift](#3-the-swift) ·
[4 Environment behaviour](#4-environment-behaviour) · [5 The `C.MachinedBar` namespace](#5-the-cmachinedbar-namespace) ·
[6 What would be wrong](#6-what-would-be-wrong)

Sites: the barred Seal (§4.3) · a barred mode-rack key (§12.4). Two sites, and they are the reason
this skill exists: §12.4 says *"a machined bar across the key, **the identical drawing** used for the
barred Seal (§4.3)"* and then re-specifies key state in its own table. Two sections, one mark, no
declared owner — `DESIGN-SYSTEM-SCOPE.md` §2(g)'s headline example.

---

## 1. Geometry

One horizontal stroke across the host control, on its vertical midline, spanning the full width plus
a **2 % overhang at each end**:

```
y  = key.midY
x  from key.minX − 0.02·key.width  to  key.maxX + 0.02·key.width
```

`env.weight(.heavy)` in `accent.cold`, **`butt` caps**. PHOSPHOR mockup, `sealMark()`.

**The overhang is the whole idea.** A bar inset inside the control reads as a divider or a strikethrough
of its contents; a bar that runs past both edges reads as something *dropped across* the mechanism from
outside it. §4.3's sentence is *"The Seal is physically barred"*, and §12.4's is *"The bar idiom carries
the whole message; there is no text explaining it."* Two per cent is enough to read and small enough that
the bar never touches a neighbouring key across the mode rack's 12 pt gutters.

**Butt caps, not round.** §13.3 puts `round` caps on chrome, and this is the documented exception: a
machined bar is milled stock with cut ends. Round caps at 4 pt add 2 pt of radius at each end and turn
the overhang into a lozenge.

**Horizontal, always — and that is a semantic requirement, not a layout one.** The other diagonal mark
in this app, the cancel hatch, runs at −45° and means *excluded* (`cancel-hatch.md`). Barred means *not
yet*: the Seal is not wrong, the mode is not forbidden, the machine simply is not ready (§4.3: "No error
text, no error state, no modal"). A diagonal bar would say the wrong thing in the one place the app has
no words to correct it.

---

## 2. States

| State | Drawing | Where |
|---|---|---|
| `absent` | not drawn — the host does not call | Seal ready; mode unlocked |
| `present` | §1, `retraction = 0` | Seal barred while any rail is inert, any socket unbound, or the draft's extension is constant (§4.3); mode key barred per §9.10's gates, rendered by §12.4 |
| `retracting` | §1, translated toward the trailing edge by `retraction × 1.04 × key.width`, clipped to the key plus its overhang | reveal beat 0 — 90 ms, `Easing.easeIn` (§13.7.1) |

`retraction` is a parameter. The bar has no clock; the host runs beat 0 and owns §13.7.4's substitution.

**Clip to the key.** Without a clip the retracting bar sweeps across whatever sits trailing of the Seal
in the commit bar. Clip to `key.insetBy(dx: -overhang, dy: 0)` so the overhang survives at
`retraction = 0` and the bar vanishes cleanly at `retraction = 1`.

**Under RTL the retraction reverses**, because "trailing" is a reading-order word and the reveal is
telling the player *the machine has let go*. The bar's resting geometry is symmetric, so RTL touches
only the direction of travel.

---

## 3. The Swift

```swift
import SwiftUI
import Tokens

public enum MachinedBar {
    /// Draws the machined bar across a barred control.
    ///
    /// `key` is the control's frame in the host's coordinate space. `retraction` is 0 at rest and 1
    /// when the bar has cleared the trailing edge; reveal beat 0 drives it over 90 ms with
    /// `Easing.easeIn` (§13.7.1). The bar owns no clock.
    ///
    /// The context is taken by value; the clip set here does not escape to the caller.
    ///
    /// - Complexity: O(1) — one sub-path.
    public static func draw(
        into context: GraphicsContext,
        key: CGRect,
        retraction: Double = 0,
        layout: LayoutDirection = .leftToRight,
        env: RenderEnv
    ) {
        guard retraction < 1 else { return }
        var ctx = context

        let overhang = C.MachinedBar.overhangRatio * key.width
        ctx.clip(to: Path(key.insetBy(dx: -overhang, dy: 0)))

        let travel = retraction * (key.width + 2 * overhang)
        let dx = layout == .rightToLeft ? travel : -travel      // trailing edge, either way
        var bar = Path()
        bar.move(to: CGPoint(x: key.minX - overhang - dx, y: key.midY))
        bar.addLine(to: CGPoint(x: key.maxX + overhang - dx, y: key.midY))

        ctx.stroke(
            bar,
            with: .color(env.palette.accent.cold.rgb.color),
            style: StrokeStyle(lineWidth: env.weight(.heavy), lineCap: .butt)
        )
    }
}
```

`accent.cold` is an `AccentColor`, which is what makes register segregation a compile error rather than
a review note (`hunch-design-tokens`): this function cannot be handed a `HueColor`, so the bar can never
be drawn in a glyph hue.

**The retraction sign.** `dx` is subtracted so a positive `travel` always moves the bar toward the
trailing edge: leftward in LTR, rightward in RTL. Writing it as an addition and flipping the sign in one
branch is the version that gets edited wrong later.

---

## 4. Environment behaviour

**VoiceOver.** No element. §13.10 gives the Seal `.button` with `.notEnabled` when barred, label "Seal",
value **"barred, rail 2 is empty"** — the value names the offending rail, and pressing it announces
*"The Seal is barred. Rail 2 is empty."* The barred mode key's element belongs to
`hunch-chrome-and-meta`. A bar with its own label would say "barred" twice and would say it before the
reason, which is the wrong order.

**Audio and haptic on a barred press.** The `bar` cue (§13.8) and the `bar` haptic (§13.9, *"the only
high-intensity low-sharpness event in the game"*). **Both are `hunch-motion-and-feedback`'s and their
parameters are stated there and nowhere else** — this file names the two cues only so nobody wires a
generic tap sound to a barred control. The three-way
discriminability by feel alone — admit *one soft*, reject *two sharp*, `bar` *one blunt heavy* — is a
shipped manual test (§13.9), and it is the reason `bar` may not be re-used for anything else.

**Reduce Motion.** The retraction is reveal beat 0, and §13.7.4 replaces the whole 1,840 ms reveal with
one 260 ms crossfade to the settled composition. So under Reduce Motion the host never passes an
intermediate `retraction`: the bar is `present` before and `absent` after. There is no partial state.

**High Contrast.** `accent.cold` resolves to its High Contrast value (`palette.md` §1's measured
column); `env.weight(.heavy)` picks up the flat `+0.5`. Nothing else changes.

**Bold Text.** `weight.heavy` × 1.25, and with High Contrast as well the flat `+0.5` on top of that —
`hunch-design-tokens` owns the ladder and the resolved number. The property to hold is the *ratio to
the control*: on a 44 pt Seal the fully-resolved bar is still around an eighth of the control's height,
so it reads as a bar rather than as a fill. Recompute it before changing `weight.heavy`.

**Differentiate Without Colour.** Nothing. The bar is already a pure geometry channel — its presence is
the signal, and §4.3 was written so that no colour is required to read it.

**Bloom.** Never. Pass A is one offscreen layer per **glyph-bearing** region — throat, ribbon, tail
(§13.5, PHOSPHOR §2) — and a commit bar is chrome. Glowing the bar would say the machine is powered
where the whole point is that it is held.

**Dynamic Type.** The bar takes the key's frame, which the host has already laid out; keys hold their
44 pt / 168 × 108 pt geometry (§12.4, §13.11). Nothing here multiplies by `artScale`.

---

## 5. The `C.MachinedBar` namespace

| Member | Value | Home of the number |
|---|---|---|
| `overhangRatio` | `0.02` × key width | PHOSPHOR mockup, `sealMark()` — the bar runs `−0.52 … +0.52` of the control |

That is the entire namespace. Weight is `env.weight(.heavy)` (§13.3: *"the machined bar across a barred
Seal, the AND welded bar"*), colour is `env.palette.accent.cold` (§13.2: *"reject, strike,
counterexample, barred"*), and the retraction's 90 ms and `Easing.easeIn` are §13.7.1's, held by
`hunch-motion-and-feedback`.

---

## 6. What would be wrong

- **A second bar drawing for the mode key.** §12.4 says "the identical drawing" and then invites you to
  write it again. Do not.
- **Drawing the AND welded coupler bar with this function.** §13.3 gives both marks `weight.heavy`, and
  that is where the similarity ends: the coupler is a junction diagram with two more states (OR forked,
  XOR crossed) and belongs to `hunch-bench-instruments`. Sharing the token is right; sharing the
  function would drag the coupler's states into a mark that has none.
- **A diagonal bar.** That is the cancel slash, and it means *excluded*. §4.3 abolishes the error state
  outright; a bar that reads as cancellation reinstates it.
- **Round caps.** They lozenge the overhang and lose the milled-stock reading.
- **Insetting the bar inside the key.** It becomes a strikethrough of the sigil rather than a bar across
  the mechanism.
- **Pulsing the bar, or animating it on press.** Pressing a barred Seal pulses **the offending rail** and
  nothing else (§4.3, §13.7.2) — that pulse is `hunch-bench-instruments`'. The bar itself never moves
  except in reveal beat 0.
- **Adding a fourth barred key to a screen.** Three is §13.1's per-screen accent ration, and at first
  launch DRIFT, ECHO and SIEVE are all barred (§12.4, §9.10's gates). The Frame's accent budget is fully
  spent by them; nothing else there — including the Anomaly streak ring — may take one.
- **Using `accent.cold` here to mean an error.** It means *reject, strike, counterexample, barred*
  (§13.2). There is no error state in this app to colour.
- **Giving the bar an accessibility element, or animating it under Reduce Motion.**
- **Writing a hex, a contrast ratio, or a cue's synthesis parameters into this file.** The first two
  are `hunch-design-tokens/references/palette.md`'s; the third is `hunch-motion-and-feedback`'s.
