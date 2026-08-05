# seal.md — the commit control, and the machine that simply is not ready

Contents: [1 Geometry](#1-geometry) · [2 States](#2-states) · [3 Barred, and what refusing looks like](#3-barred-and-what-refusing-looks-like) ·
[4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `SealView` in `Modules/Sources/HunchUI/SealView.swift`. **L2:** `C.Seal`.
The bar across it: `hunch-shared-marks/references/machined-bar.md` — *"the identical drawing"* also used on a
barred mode-rack key (§12.4), one owning function. The reveal's eight beats:
`hunch-motion-and-feedback/references/reveal-beats.md`. Why it is barred: `SealBar` in
`HunchCore/Sources/Bench/SealBar.swift`, as data.

---

## 1. Geometry

The Seal is the trailing key of a commit bar, and the commit bar is at y 604–667 on **every**
surface (§12.8 tier 1: *"the thing that ends a decision is always in the same place under the same
thumb"*).

| Site | Position | Size |
|---|---|---|
| Bench commit bar | trailing; the Dial key leads | 44 × 44 minimum, drawn to the bar's key size |
| ECHO commit bar | trailing; twin/replay leads | the same (§8.4) |
| Pro Max | y 868–922, keys 60 pt tall | the same drawing, taller key (§6.2) |

The key chrome — border, radius, press state — is `hunch-chrome-and-meta/references/key.md`. This file owns
what makes a Seal a Seal: the bar, the depression, the marks and the refusal.

```swift
extension C.Seal {
    /// The physical depression on press and on reveal beat 0 (§13.7.1).
    public static let depression = 2.0
    /// Seal marks: 1…3, struck in at reveal beat 6, one per 80 ms (§13.7.1, §5.4).
    public static let markStrikeInterval = Duration.milliseconds(80)
    public static let markStrikeScale = 1.25          // → 1.00 over `Dur.tap`
    /// The brass bloom behind each arriving mark. L2 — nothing else blooms on a key.
    public static let markBloom = Duration.milliseconds(60)
    public static let maxMarks = 3
    /// The offending rail's pulse when a barred Seal is pressed — PHOSPHOR's
    /// `opacity.railPulse`, owned here because only the Seal causes it.
    public static let railPulse = 0.50                // → 1.00, 3 × Dur.pulse
}
```

---

## 2. States

| State | When | Drawing |
|---|---|---|
| **ready** | the draft is complete and its extension is not constant | key at full ink; `accent.brass` mark register available |
| **barred** | any rail inert, any socket unbound, or the extension constant (§4.3) | a **machined bar** across the key at `weight.heavy` |
| **depressed** | finger down, and reveal beat 0 | the key sinks by `C.Seal.depression` |
| **marks striking** | reveal beat 6 | 1–3 marks arrive one per `C.Seal.markStrikeInterval`, each scaling `C.Seal.markStrikeScale` → 1.00 over `Dur.tap` behind a `C.Seal.markBloom` brass bloom |

Two variants: PROBE/DRIFT (declare a law) and ECHO (commit a recall) — same drawing, same states,
different verb behind it (§4.3, §8.4).

**The bar retracts off the trailing edge at reveal beat 0**, over `Dur.tap` `Easing.easeIn`, if one was there
(§13.7.1). That retraction is the only time a bar animates; everywhere else it appears and
disappears with the state.

**Marks are `accent.brass`**, the same brass the registration beat steps the tiles to — an accent on
chrome, which is legal because `accent.*` is a **verdict** register and a mark is a verdict, not a
status (§13.2). Accent rationing is three elements per screen (PHOSPHOR §3); on the Bench the Seal
has spent one of them.

---

## 3. Barred, and what refusing looks like

*"The Seal is physically barred by a machined bar across it while any rail is inert, any socket
unbound, or the draft's extension is constant. Pressing a barred Seal pulses the offending rail and
nothing else. No error text, no error state, no modal: the machine simply is not ready."* (§4.3)

Three things follow, and all three are easy to lose:

1. **The reason is data, in core.** `SealBar` is an enum in `HunchCore/Sources/Bench/` naming *which*
   rail and *why*. The view reads it to decide which rail to pulse and what to announce. A view-side
   re-derivation will disagree with the bar on some subset and nobody will find out.
2. **The refusal is a pulse on the rail, not a response on the Seal.** 3 × `Dur.pulse`,
   `C.Seal.railPulse` 0.5 → 1.0, and *nothing else moves* (§13.7.2). The Seal itself does not
   shudder, flash or shake — the machine is not annoyed, it is not ready.
3. **The Seal has no input queue and is edge-triggered** (§6.5). The PROBE and twin keys hold a
   single-slot queue; the Seal must not, because *"a queued second declaration would be
   catastrophic"* — the second tap would land on a round that has already ended.

Adding an error message here would put text on the play surface, add a state the design abolished,
and replace a mechanism with an apology.

---

## 4. SwiftUI

```swift
// Modules/Sources/HunchUI/SealView.swift
import HunchCore
import SwiftUI

struct SealView: View {
    let env: RenderEnv
    let bar: SealBar?              // nil == ready; the enum names the reason
    let marks: Int                 // 0…3, struck in during the reveal
    let onCommit: () -> Void
    let onRefuse: (SealBar) -> Void

    @State private var isPressed = false

    private var isBarred: Bool { bar != nil }

    var body: some View {
        Button {
            if let bar { onRefuse(bar) } else { onCommit() }
        } label: {
            ZStack {
                SealFace(env: env, marks: marks)
                if isBarred {
                    // `draw(into:)`, never a `View` — one entry point per mark
                    // (`hunch-shared-marks/SKILL.md`).
                    Canvas { context, size in
                        MachinedBar.draw(into: context,
                                         key: CGRect(origin: .zero, size: size),
                                         env: env)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: Space.targetMin, minHeight: Space.targetMin)
        .offset(y: pressOffset)
        .accessibilityLabel(Loc.seal)
        .accessibilityValue(bar.map(Loc.sealBarReason) ?? Loc.sealReady)
        .accessibilityRespondsToUserInteraction(true)
        // NOT `.disabled(isBarred)`. See §5: SwiftUI has no `notEnabled` trait to add,
        // and `.disabled(true)` would swallow the refusal that pulses the offending rail.
    }

    /// Reduce Motion forbids translation anywhere (§13.12 gate 9), and §13.7.4 has no row
    /// for the key depression — so the depression becomes an interior step instead.
    private var pressOffset: CGFloat {
        isPressed && !env.isReduceMotionEnabled ? C.Seal.depression : 0
    }
}
```

Note what the sketch refuses to do: it never calls `.disabled(true)` on a barred Seal. `.disabled`
would stop the button's action firing, and the action *is* the refusal — the rail pulse and the
*"The Seal is barred"* announcement both hang off it. §12.8 requires the opposite of a dead control:
`accessibilityRespondsToUserInteraction` is set on the barred Seal *so it is discoverable while it
is refusing*. The bar is a state of a live control, not an absence of one.

`SealFace` draws the key and the marks; `MachinedBar` is `hunch-shared-marks`' single owning
function, called here and on a barred mode-rack key and nowhere else.

---

## 5. VoiceOver

§13.10:

| Traits | Label | Value |
|---|---|---|
| `.button`, `.notEnabled` **when barred** | `"Seal"` | `"ready"` / `"barred, rail 2 is empty"` |

**The one place canon's spelling does not map to an API, and how it resolves.** SwiftUI's
`AccessibilityTraits` has **no `notEnabled` member** — UIKit's `UIAccessibilityTraitNotEnabled` is
reachable only through `.disabled(true)`, which also stops the button's action and therefore
swallows the refusal. So the barred state is carried by the **value** (`"barred, rail 2 is empty"`,
which is §13.10's own value column) plus `accessibilityRespondsToUserInteraction(true)`, and the
control stays enabled. Do not reach for `.accessibilityAddTraits(.isNotEnabled)` — it does not
compile — and do not "fix" it with `.disabled`.

- The value names the reason, from `SealBar`, in the same words the announcement uses:
  *"The Seal is barred. Rail 2 is empty."* (§13.10).
- **Magic Tap fires the Seal on the Bench** (and Probe on the Dial) — *"the single largest VoiceOver
  win in the app"* (§13.10). It must route through the same function the button does, including the
  refusal path.
- The Seal is the last stop on the **"Rails"** rotor, after rail 1, rail 2 and the coupler — the
  rotor is a reading order for the draft that ends at the commit.
- On success the announcement order is fixed, **verdict → evidence → bookkeeping**:
  *"Correct. {narration}. Inscribed. Three marks. Fifteen probes."*

---

## 6. Reduce Motion

Four rows of `hunch-motion-and-feedback/references/reduce-motion.md` §2 land on the Seal — **marks
strike-in**, **barred-rail pulse**, **key depression**, and both **law reveal** rows. Read the
durations there. What is this file's:

- **The marks are *already struck*, not struck faster.** The substitution replaces the arrival, not
  the information: the count is on screen from the first frame of the crossfade.
- **The depression becomes an interior step to `surface.cellLit`, never a translation.** §13.12
  gate 9 forbids translation anywhere and §13.7.4 lists no key depressions, so this row was a gap in
  canon; it is closed once, in the motion skill's table, and applied by
  `hunch-chrome-and-meta/references/key.md` to every key in the app.
- **The bar does not get its own substitution.** It is simply absent in the settled composition the
  reveal crossfades to, so its retraction has nothing to substitute.

---

## 7. High Contrast

- `weight.heavy` 4.0 → 4.5 (5.5 with Bold Text), so the machined bar stays the heaviest mark on the
  surface, which is the property that makes "barred" readable with no colour at all.
- `accent.brass` is 13.08 : 1 under High Contrast and is **not** collapsed — High Contrast collapses
  `hue.*`, never `accent.*` (§13.2). The marks keep their brass.
- The key border is `weight.thin` + 0.5.

**Differentiate Without Colour** changes nothing on the Seal: the bar is geometry and the marks are
counted, not coloured.

---

## 8. Wrong

- **Any error text, error state, modal, alert, toast or shake.** §4.3 abolishes the error state. The
  machine is not ready; it does not explain.
- **`.disabled(true)` on a barred Seal.** The button's action stops firing, so the rail never pulses
  and the announcement never posts — the refusal disappears and the player is told nothing.
- **Giving the Seal an input queue.** Edge-triggered, no queue — §6.5 calls a queued second
  declaration catastrophic, and it is.
- **Re-deriving the bar reason in the view.** `SealBar` is core, and it is the same predicate the
  rail pulse and the Assay's constant-extension state read.
- **Pulsing the Seal instead of the rail.** The refusal points at the problem; a Seal that reacts
  to itself points at nothing.
- **Drawing the machined bar here.** One owning function, in `hunch-shared-marks`, shared with the
  mode-rack key — that is exactly the §2(g) drift this library exists to stop.
- **Translating the depression under Reduce Motion.** Gate 9 says nothing translates *anywhere*.
- **More than three marks, or a mark that is not `accent.brass`.** 1–3 is §5.4's scale; a fourth
  mark is a score inflation with no meaning behind it.
