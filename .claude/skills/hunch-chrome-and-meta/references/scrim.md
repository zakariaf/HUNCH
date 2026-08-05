# scrim.md — the two covered surfaces

Owning symbol: `HunchUI/Chrome/Scrim.swift` → `struct Scrim: ViewModifier` with `enum Scrim.Kind { case bench, sievePause }`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row C, *Scrim*. **There are exactly two, and no third is coming.**

Contents: [1 The two](#1-the-two) · [2 Extent](#2-extent) · [3 Implementation](#3-implementation) ·
[4 Interaction](#4-interaction) · [5 VoiceOver — the defect this prevents](#5-voiceover--the-defect-this-component-exists-to-prevent) ·
[6 Environment behaviour](#6-environment-behaviour) · [7 Wrong](#7-wrong)

---

## 1. The two

| Kind | Where | Opacity | Behind it |
|---|---|---|---|
| **bench** | `BenchView` and `AssayInspectorView` cover the round surface | `Opacity.scrim(in: env)` — blurred, or flat under Reduce Transparency (§13.11) | the throat, ribbon, Dial and instrument bar |
| **sievePause** | `SievePauseOverlay` covers a frozen SIEVE lane | `C.Scrim.sievePause`, flat, always (§12.2 screen 18) | the frozen lane, at the frame it stopped on |

`Opacity.scrim(in:)` is L1 and belongs to `hunch-design-tokens`; both of its values and the predicate
that picks between them are `dimensions-strokes-opacity.md` §5's `opacity.scrimBlurred` /
`opacity.scrimFlat` row, and neither is restated here. `C.Scrim.sievePause` is L2 and belongs here,
fixed by §12.2.

**Why the SIEVE scrim does not use `Opacity.scrim(in:)`.** §12.7's whole argument for pausing before
exiting is that *"the decision to leave is made against a frozen screen rather than a moving one"* —
the lane must stay readable through the scrim, and `opacity.scrimFlat` is opaque enough to hide it.
`C.Scrim.sievePause` sits between the two L1 values, loses its blur under Reduce Transparency and
does **not** step, because the blur was never what made the lane readable. One value, every
environment.

---

## 2. Extent

Both scrims cover the **entire safe area**, including the instrument bar.

For the Bench this is a decision, not an oversight: the bar carries the par tick row, which is round
state that is not actionable while declaring, and leaving it undimmed would say it is. The Bench's
exits are the Seal and the pull-down (§12.2 screen 6); the round chevron is not one of them.

For the SIEVE pause the bar carries the foul ticks and the progress arc — both frozen with the lane,
both under the same scrim. The commit bar gains its abandon chevron *above* the scrim (§9.2), because
it is the overlay's own control.

The Bench sheet itself sits above its scrim with `Radius.sheet` on its **top corners only** (§13.3).
The scrim runs edge to edge behind it, not just to the sheet's top edge — a scrim that stopped at the
sheet would leave a bright band under a translucent panel.

---

## 3. Implementation

```swift
// Modules/Sources/HunchUI/Chrome/Scrim.swift
extension View {
    /// Covers `self` and removes it from the accessibility tree while `isPresented`.
    func scrim(_ kind: Scrim.Kind, isPresented: Bool, onDismiss: @escaping () -> Void) -> some View {
        modifier(Scrim(kind: kind, isPresented: isPresented, onDismiss: onDismiss))
    }
}

struct Scrim: ViewModifier {
    enum Kind { case bench, sievePause }

    let kind: Kind
    let isPresented: Bool
    let onDismiss: () -> Void

    @Environment(\.renderEnv) private var env

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(isPresented)          // ← §5. Not optional. Not cosmetic.
            .overlay {
                if isPresented {
                    Rectangle()
                        .fill(env.palette.ground.base.color.opacity(opacity))
                        .background(background)
                        .ignoresSafeArea()
                        .onTapGesture(perform: onDismiss)
                        .accessibilityHidden(true)
                        .transition(.opacity)          // crossfade; nothing translates
                }
            }
            .animation(Easing.easeInOut.animation(for: Dur.crossfade), value: isPresented)
    }

    private var opacity: Double {
        switch kind {
        case .bench: Opacity.scrim(in: env)
        case .sievePause: C.Scrim.sievePause
        }
    }

    @ViewBuilder private var background: some View {
        if kind == .bench, !env.isReduceTransparencyEnabled {
            Rectangle().fill(.ultraThinMaterial)       // legal: a scrim is not a primary surface
        }
    }
}
```

`.ultraThinMaterial` is a rejection offence *as a primary surface* (§13.1). A scrim is not a surface;
it is the absence of one, and §13.11 explicitly specifies the Bench scrim as *"a 0.6 α blur"*. The
distinction is the whole licence, so do not extend it to a panel.

---

## 4. Interaction

- **Tap the scrim to dismiss.** The Bench's documented exit is a pull-down (§13.7.3, an interactive
  drag on the handle), and under Reduce Motion §13.7.4 turns the handle into a plain button — so a
  tap route already has to exist. Putting it on the scrim as well costs nothing and matches every
  sheet the player has ever used.
- **The SIEVE pause scrim does *not* dismiss on tap.** §12.7: resuming needs *"one deliberate tap on
  the gate — the same 375 × 88 pt band the run is played with, never a region SIEVE does not have."*
  Pass `onDismiss` as a no-op there and let the gate own the resume. A tap-anywhere resume on a timed
  run is the exploit §12.7 is closing.
- No drag, pinch, long-press or double-tap on either scrim (§12.8).

---

## 5. VoiceOver — the defect this component exists to prevent

A hand-drawn overlay does **not** remove the content beneath it from the accessibility tree. SwiftUI
does that for a real `.sheet`; it does not do it for a `Rectangle` in an `.overlay`. Without
`.accessibilityHidden(true)` on the covered content, a rotor swipe lands on the Dial's ramp cells
while the Bench is up — controls the player cannot see, cannot reach, and whose activation changes
round state.

The Bench is a custom overlay (§13.7.3 wants an interactive drag in a shared coordinate space, which
a system sheet cannot give), so the hiding is manual and is written into the modifier above. It is
not a detail; it is the reason the scrim is a `ViewModifier` on the covered content rather than a
view you place beside it.

Also:
- The scrim itself is `.accessibilityHidden(true)`. It is not a "dismiss" button — the sheet's own
  escape is two-finger scrub (§13.10), which closes the Bench and the expanded Assay.
- Post `.screenChanged` when the covered surface appears, so focus lands inside it.

---

## 6. Environment behaviour

| Setting | Bench scrim | SIEVE pause scrim |
|---|---|---|
| **Reduce Transparency** | blur off, `opacity.scrimBlurred` → `opacity.scrimFlat` (§13.11) | blur was never on; stays `C.Scrim.sievePause` |
| **Reduce Motion** | the Dial↔Bench transition becomes a `Dur.crossfade` crossfade (§13.7.4); the scrim crossfades with it | the freeze is instantaneous either way — motion is the mechanic here and §9.8 replaces rather than removes it |
| **High Contrast** | see the open question below | `C.Scrim.sievePause`, flat |
| **Low Power Mode** | the blur is a full-screen offscreen pass; treat it as bloom and drop it | unchanged |
| **Bold Text, Dynamic Type, RTL** | no effect. A scrim has no geometry, no text and no direction | same |

**Open question, for `hunch-design-tokens` to answer.** `Opacity.scrim(in:)` currently branches on
Reduce Transparency alone (`dimensions-strokes-opacity.md` §5). A blurred scrim needs a material, and
`render-env.md` §3's other material-suppressing predicates — High Contrast, Low Power Mode — are not
in that branch. The blurred value is therefore reachable in states where the blur will not render,
giving the *lighter* of the two opacities, flat, over the High Contrast theme's maximum-contrast
surface — through which the covered content stays legible. Either `Opacity.scrim(in:)` should take
the same three-way predicate as `isBloomEnabled`, or `opacity.scrimFlat` should be the default and
`opacity.scrimBlurred` the exception. Raise it there; do not fix it by writing a different number
here.

---

## 7. Wrong

- **A third scrim.** Two, named, both in `Scrim.Kind`. A modal that needs a scrim is a modal this app
  does not have — §12.2's inventory is closed and §4.3 abolishes the error modal outright.
- **A scrim without `.accessibilityHidden(true)` on the covered content.** §5.
- **A `.sheet` for the Bench.** It cannot give §13.7.3's interruptible interactive drag or a shared
  coordinate space with the Dial.
- **`.ultraThinMaterial` as the scrim's only layer.** The material is the blur *behind* the tinted
  rectangle; the opacity token is what does the covering. Under Reduce Transparency the material goes
  and the rectangle must still be there.
- **`Color.black.opacity(0.6)`.** Two literals, and `ground.base` is not black in the dark theme and
  is warm paper in the light one, where a black scrim would be a hole in the page (`palette.md` §1
  holds all three values). `check-source-hygiene.sh` check 9 catches the `.opacity(` literal; it
  cannot catch `Color.black`, which is why this bullet exists.
- **Tap-to-resume anywhere on the SIEVE pause scrim.** §4.
- **Animating the scrim with anything but opacity.** Nothing translates, scales or rotates (§13.7.4).
- **Stacking two scrims** — Bench over an expanded Assay, say. The Assay inspector replaces the
  Bench's own presentation rather than layering on it; §12.2 gives it its own dismissal.
