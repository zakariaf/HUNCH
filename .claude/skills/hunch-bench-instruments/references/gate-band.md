# gate-band.md — SIEVE's 375 × 88 target, and the one place motion is the mechanic

Contents: [1 Geometry](#1-geometry) · [2 The actionable rule](#2-the-actionable-rule) ·
[3 States](#3-states) · [4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) ·
[6 Reduce Motion](#6-reduce-motion) · [7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `GateBandView` in `Modules/Sources/HunchUI/GateBandView.swift`, composed by
`SieveRoundView`. **L2:** `C.GateBand`. The travelling glyph: `hunch-glyph-renderer`. The ring
that resolves in the sump: `hunch-shared-marks/references/verdict-ring.md`. The tail below it: `ribbon.md` §3.
The speed curve, the reaches and the guardrails are core — `SieveSchedule` in
`HunchCore/Sources/Rounds/`.

---

## 1. Geometry

*"Glyphs travel top to bottom on a fixed vertical conveyor. **The tap target is not the moving
glyph.**"* (§9.2) That sentence is the component.

| Region | y | Content |
|---|---|---|
| the lip | 64–96 | spawn; 32 pt of fade-in |
| the lane | 96–420 | 324 pt of travel; glyph drawn at 72 pt |
| **the gate** | **420–508** | **88 pt tall, the full 375 pt width — the entire actionable target** |
| the sump | 508–556 | exit; the ring resolves here, then the glyph dissolves over `C.GateBand.sumpDissolve` |
| the tail | 560–604 | the last 6 resolved glyphs at 36 pt with their rings |

```swift
extension C.GateBand {
    public static let height = 88.0
    public static let centreY = 464.0            // 420 + 88 / 2
    /// A glyph is actionable while its centre is within ±44 pt of the centre line.
    public static let actionableRadius = 44.0
    /// Centre-to-centre spacing, fixed at every speed (§9.2).
    public static let glyphPitch = 132.0
    public static let laneGlyph = 72.0
    public static let hairline = StrokeWeight.hairline
    /// The sump dissolve, and the inert seed's hold before the stream starts (§9.4).
    /// L2 — nothing outside SIEVE has either.
    public static let sumpDissolve = Dur.zoom
    public static let seedHold = Duration.milliseconds(1500)
}
```

The band is drawn as **two brass hairlines with edge ticks** (§9.2). `accent.brass` on chrome is
legal and deliberate here: brass is the *admit* accent (§13.2), and the band **is** the admit
affordance — tapping it means *admit this one*. SIEVE spends its per-screen accent ration on the
gate, which is why nothing else on that surface is brass.

---

## 2. The actionable rule

Three invariants, all asserted by test (§9.2, §9.4 S4):

1. **Actionable window.** A glyph is actionable exactly while its centre is within ±44 pt of
   `C.GateBand.centreY`.
2. **At most one glyph is ever actionable.** Pitch is fixed at `P = 132 pt` centre-to-centre at every
   speed, and `P > 88 pt`, so two glyphs cannot occupy the band. This is a hard invariant, not a
   consequence to be hoped for — `S4` re-asserts `P > gate height` at every rate `r`.
3. **Taps outside the gate are discarded silently.** No foul, no sound, no haptic. *A fumble costs
   nothing.*

The target is 375 × 88 pt — 8.5× the 44 pt minimum in its short axis — and it sits inside the
right-thumb comfort arc (y > 240, §4.1). **Not tapping is a decision**: it means *reject*, and it is
the only control in the app whose null action is meaningful, which is why the band must never
"helpfully" catch a near-miss from outside.

Timing is core and not this view's: `window(n) = 0.667 / r(n)` seconds actionable,
`preview(n) = 340 / v(n)` seconds visible above the gate, both from `SieveSchedule`. At band 6 with
tempo step 3 the window is **226 ms** and the total decision time is **1.10 s** from first sight to
last chance.

---

## 3. States

| State | When | Drawing |
|---|---|---|
| **idle** | streaming, nothing in the band | the two brass hairlines and their edge ticks |
| **actionable** | a glyph's centre is inside ±44 pt | the band's hairlines step to full ink; the glyph is inside it |
| **tapped** | a tap landed inside the band while actionable | a **`Dur.pulse` ring only — no scale, no shudder** (§13.7.2) |
| **paused** | the pause key was pressed | a 70 % scrim over the surface; the conveyor holds (§13.11, §12.7) |

The **tapped** state is the app's shortest response, deliberately: §13.7.2 caps the tap response at
`Dur.micro` and spends it on *"a ring only, no scale, no shudder"*. Every glyph resolves its true
verdict as it leaves the gate whether the player acted or not, so the tap's own feedback must not
compete with the resolution arriving in the sump.

A **seed glyph is held inert in the gate for `C.GateBand.seedHold`** before the stream starts in
contextual bands, priming position 0 (§9.4). It is not actionable and it is not scored.

The commit bar carries **pause** (trailing, 44 pt) during `streaming` and nothing else; in `paused`
the same slot gains a chevron (leading, 44 pt) that abandons the run on a second, confirming tap —
*deliberately two taps, and reachable only from a stopped stream* (§9.2).

---

## 4. SwiftUI

The band is **one hit target and one accessibility element**, which makes it the simplest component
in this skill and the easiest to over-build.

```swift
// Modules/Sources/HunchUI/GateBandView.swift
import HunchCore
import SwiftUI

struct GateBandView: View {
    let env: RenderEnv
    let actionable: Glyph?          // nil when nothing is in the band
    let onAdmit: () -> Void

    var body: some View {
        Canvas { context, size in
            let ink = env.palette.accent.brass.rgb.color
            let weight = env.weight(.hairline)
            for y in [weight / 2, size.height - weight / 2] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(ink), lineWidth: weight)
            }
            EdgeTicks.draw(&context, in: size, ink: ink, weight: weight)
        }
        .frame(height: C.GateBand.height)
        .contentShape(.rect)                    // the whole band, always
        .onTapGesture { if actionable != nil { onAdmit() } }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits([.isButton, .updatesFrequently])
        .accessibilityLabel(Loc.gate)
        .accessibilityValue(actionable.map(Loc.glyphLabel) ?? "")
        .accessibilityAction(named: Loc.admit, onAdmit)
    }
}
```

Two things the sketch does on purpose. `.contentShape(.rect)` covers the **whole** band, including
where there is no glyph — the target is the band, not the mark. And the tap is gated on `actionable
!= nil` *inside* the handler rather than by `.disabled()`, so a tap during the idle state is
discarded silently instead of the element vanishing from the accessibility tree between glyphs.

The conveyor itself — spawn, travel, sump, dissolve — is `SieveRoundView`'s, driven by
`SieveSchedule`'s glyph index rather than by wall-clock, *so a run is reproducible from its seed and
unaffected by a dropped frame* (§9.3). Never drive it from a `TimelineView` cadence that a stutter
can skew.

---

## 5. VoiceOver

§13.10:

| Traits | Label | Value | Actions |
|---|---|---|---|
| `.button`, `.updatesFrequently` | `"Gate"` | the glyph label of whatever is actionable, **announced on gate entry** | **`"Admit"`** |

- The announcement fires on **gate entry**, not on spawn: entry is when the decision becomes
  available, and announcing at the lip would burn most of a 226 ms window on speech.
- The **resolution** is announced in the sump (§9.8) — verdict first, in the fixed
  verdict → evidence → bookkeeping order, so a player can move on after one word.
- The tail is a separate container element listing the last six resolved glyphs with their verdicts
  (`ribbon.md` §5); together they are the whole non-visual model of a SIEVE run.
- The `"Admit"` custom action and the tap must call the same function. There is no second way to
  admit.

---

## 6. Reduce Motion

**This is the one row in §13.7.4 where motion is the mechanic, so it is replaced, not removed.**

> the lane keeps its four stations and a glyph **crossfades lip → lane → gate → sump** at the
> identical cadence. Nothing translates; the *information the travel carried* is untouched. The gate
> dwell is byte-identical, the ±44 pt actionable rule is byte-identical, and the **preview count** —
> how many glyphs are visible above the gate at once — is unchanged at every band and tempo step.
> Scoring and difficulty are unchanged.

Collapsing the lane to a single centre slot would delete the **preview**, and the preview is not
decoration: §9.3 budgets worst-case decision time as `preview + window` = 0.87 s + 0.226 s = 1.10 s,
and a one-slot substitution leaves roughly one inter-glyph period (≈ 0.34 s at band 6, tempo step 3).
That would cut the hardest decision in the game to a third of its length **for exactly the players
who asked for less motion**.

A shipped test asserts `preview(n) + window(n)` is identical with Reduce Motion on and off for every
band 1–6 × tempo step 0–3 × every `n`, and that the station a glyph occupies at time `t` is the same
in both (§13.12 gate 9). That test is the reason this substitution can be trusted; write it before
the substitution, not after.

---

## 7. High Contrast

- `accent.brass` is **not** collapsed under High Contrast (only `hue.*` is), and it measures
  13.08 : 1 there — so the band's two hairlines get *more* legible, not less.
- `weight.hairline` 0.5 → 1.0 through `env.weight(.hairline)`. The band's hairlines are the one
  place `stroke.hairline`'s "never state-bearing" rule does not apply, because they are drawn in
  `accent.brass`, not in `stroke.hairline` — the *weight* is hairline, the *ink* is an accent. Keep
  those two separate when reading §13.2.
- The travelling glyph collapses its hue to `stroke.primary` and lengthens its index stroke by the
  ratio `hunch-glyph-renderer/references/geometry.md` owns; at `S = 72` that is 19.7 → 29.4 pt, and at the
  tail's `S = 36`, 9.8 → 14.7 pt.
- The shader is off, so the lane has no grain and the band reads flat — which is correct: at 21 : 1
  the marks do not need a room.

**Differentiate Without Colour** does not change the band; it doubles the broken reject ring's gap in
the sump and the tail, which is `hunch-shared-marks`' business.

---

## 8. Wrong

- **Making the moving glyph the target.** *"The tap target is not the moving glyph."* A 72 pt mark
  travelling at up to 390 pt/s is not a target; a stationary 375 × 88 pt band is.
- **Fouling or beeping on a tap outside the band.** Discarded silently — a fumble costs nothing
  (§9.2). This is a fairness property, not a nicety.
- **Letting two glyphs be actionable.** `P = 132 > 88` is a hard invariant; anything that varies the
  pitch with speed breaks it and the S4 test exists to catch it.
- **Driving the conveyor from wall-clock.** Rate ramps in **glyph index**, so a run is reproducible
  from its seed and a dropped frame changes nothing (§9.3).
- **Collapsing the lane to one slot under Reduce Motion.** It deletes the preview and cuts the
  hardest decision in the game to a third of its length for the players least able to absorb it.
- **`.disabled()` between glyphs.** The element must stay in the accessibility tree; gate the action,
  not the element.
- **Announcing at the lip.** Speech would consume most of a 226 ms window. Announce on gate entry,
  resolve in the sump.
- **Spending brass anywhere else on the SIEVE surface.** The ration is three accent elements per
  screen and the gate has taken the one that matters.
- **Serving SIEVE above band 6.** Bands 7 and 8 are not learnable from a passive stream in 45
  seconds; ability above band 6 is absorbed by the tempo step, not by the law (§9.3). The clamp is
  core's, but a view that renders a band-7 law here is a bug worth catching.
