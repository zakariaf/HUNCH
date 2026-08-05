# wedge.md — six comparators, pictorial, never ASCII

Contents: [1 Geometry](#1-geometry) · [2 The six drawings](#2-the-six-drawings) ·
[3 States](#3-states) · [4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) ·
[6 Reduce Motion](#6-reduce-motion) · [7 High Contrast and RTL](#7-high-contrast-and-rtl) ·
[8 Wrong](#8-wrong)

**Owner:** `WedgeView` and `WedgeShape` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`.
**L2:** `C.Wedge`. Its container and hit rect: `bridge.md` §1. Values: `hunch-design-tokens`.

---

## 1. Geometry

The wedge sits in a 44 × 44 hit rect and **draws inside a 24 pt mark box** centred in it — the same
proportion §12.8 fixes for the instrument-bar chevron and the play key. Everything below is
expressed as a fraction of that mark box's side `W`, so the drawing is identical at 24 pt on the
Bench, at 18.7 pt on a Codex page (× `C.RuleTile.codexScale`) and at 32.4 pt under Dynamic Type.

| Property | Value | Source |
|---|---|---|
| hit rect | 44 × 44 | `C.Bridge.wedgeBox` |
| mark box side `W` | 24 pt | `C.Wedge.markSide`; × `env.artScale` |
| stroke | `weight.body` | PHOSPHOR §1.3 applies `w.body` to the wedge and the coupler strands |
| cap / join | butt cap, miter join | §13.3 — chrome uses round caps, but the wedge is *content*, and a mitred apex is what makes the point read as a point |
| ink | `stroke.primary` | chrome register; a `hue.*` here will not compile |

**The wedge's limbs are derived, not chosen.** The apex sits at the midpoint of one edge of the mark
box and the two limbs run to the **two far corners**. At a square box that is an included angle of
`2 · atan(0.5) = 53.13°`, and it stays correct at any aspect ratio because it is a construction
rather than a constant. There is nothing to keep in sync.

```swift
extension C.Wedge {
    public static let markSide = 24.0        // inside the 44 pt hit rect
    /// The underbar of `lte` / `gte`, as a fraction of the mark box side.
    public static let underbarInset = 0.10
    /// The two bars of `eq` / `neq` sit on the mark box's vertical thirds.
    public static let barFraction = 1.0 / 3.0
}
```

---

## 2. The six drawings

Canon §4.2 fixes the vocabulary: *"drawn pictorially and never as ASCII: `eq` two parallel bars;
`neq` two bars with a slash; `lt`/`gt` a wedge whose wide end physically opens toward the larger
side; `lte`/`gte` the same wedge with an underbar."* The construction below is that sentence made
exact.

| Comparator | Drawing | Construction in the mark box |
|---|---|---|
| `eq` | two parallel bars | full-width horizontals at `y = W/3` and `y = 2W/3` |
| `neq` | the same two bars, slashed | `eq` plus a stroke from the bottom-leading corner to the top-trailing corner |
| `lt` | wedge, wide end **trailing** | apex at the leading edge midpoint, limbs to the two trailing corners |
| `gt` | wedge, wide end **leading** | apex at the trailing edge midpoint, limbs to the two leading corners |
| `lte` | `lt` + underbar | plus a full-width horizontal at `y = W · (1 − underbarInset)` |
| `gte` | `gt` + underbar | the same underbar |

**"The wide end physically opens toward the larger side" is the whole mnemonic**, and it is why the
wedge is a construction and not an icon: `lt` means *the leading socket's rank is less than the
trailing socket's*, so the mark's mouth faces the trailing socket, which is the larger one. A player
reads the direction off the geometry without knowing the word.

The `neq` slash runs bottom-leading → top-trailing at 45°, the same angle as `teal`'s index stroke —
which is harmless because the wedge is chrome in `stroke.primary` and the index stroke is a `hue.*`
inside a glyph, two registers that §13.2 keeps apart by type. It is also the same angle as the ramp
cell's diagonal cancel hatch; those never appear inside one mark box, and the hatch crosses a whole
cell while the slash crosses two bars.

---

## 3. States

The wedge has exactly one axis of state — which of the six it is — plus the tile's own presentation:

| State | Drawing |
|---|---|
| the six comparators | §2 |
| **read-only** | identical drawing, no hit target (Codex page, Inscription) |
| **pressed** | interior steps to `surface.cellLit` for `Dur.tap`; the mark does not move |

There is no disabled wedge: a Bridge always has a comparator, and cycling is always legal. A tap
cycles `eq → neq → lt → lte → gt → gte → eq` — the order `Comparator`'s cases are declared in
(§2's enum list), so the cycle and the serialisation agree and neither needs a second table.

---

## 4. SwiftUI

`Shape`, not `Canvas`: it is one stroked path, `Shape.path(in:)` runs off the main actor, and a
`Shape` animates and hit-tests for free.

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

/// The six comparators as one construction (`wedge.md` §2). Nothing here is an icon.
struct WedgeShape: Shape {
    let comparator: Comparator

    func path(in rect: CGRect) -> Path {
        let box = markBox(in: rect)
        var path = Path()
        switch comparator {
        case .eq, .neq:
            for fraction in [C.Wedge.barFraction, 1 - C.Wedge.barFraction] {
                let y = box.minY + box.height * fraction
                path.move(to: CGPoint(x: box.minX, y: y))
                path.addLine(to: CGPoint(x: box.maxX, y: y))
            }
            if comparator == .neq {
                path.move(to: CGPoint(x: box.minX, y: box.maxY))
                path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
            }
        case .lt, .lte, .gt, .gte:
            let opensTrailing = comparator == .lt || comparator == .lte
            let apexX = opensTrailing ? box.minX : box.maxX
            let farX = opensTrailing ? box.maxX : box.minX
            path.move(to: CGPoint(x: farX, y: box.minY))
            path.addLine(to: CGPoint(x: apexX, y: box.midY))
            path.addLine(to: CGPoint(x: farX, y: box.maxY))
            if comparator == .lte || comparator == .gte {
                let y = box.minY + box.height * (1 - C.Wedge.underbarInset)
                path.move(to: CGPoint(x: box.minX, y: y))
                path.addLine(to: CGPoint(x: box.maxX, y: y))
            }
        }
        return path
    }

    private func markBox(in rect: CGRect) -> CGRect {
        let side = min(rect.width, rect.height, C.Wedge.markSide)
        return CGRect(
            x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    }
}

struct WedgeView: View {
    let env: RenderEnv
    let comparator: Comparator

    var body: some View {
        WedgeShape(comparator: comparator)
            .stroke(
                env.palette.stroke.primary.color,
                style: StrokeStyle(
                    lineWidth: env.weight(.body), lineCap: .butt, lineJoin: .miter))
            .frame(width: C.Bridge.wedgeBox.width, height: C.Bridge.wedgeBox.height)
    }
}
```

`markBox` clamps to `C.Wedge.markSide` **and** to the rect, so shrinking the container shrinks the
mark rather than clipping it — the failure mode that turns `gte` into `gt` at a Codex thumbnail size.

Note the switch has no `default:` (`03 W29`): adding a seventh comparator must break the build here,
because a silently-unhandled comparator would render as an empty box on a textless surface.

---

## 5. VoiceOver

- Traits `.button`; label `"Comparator"`; value the localized comparator name — `"greater than"`,
  `"not equal to"` (§13.10).
- One custom action, `"Cycle"`. The tap gesture and the action must call the same function, or
  VoiceOver and touch will disagree about the order.
- The value is a **complete localized string per comparator**, not `"greater"` + `"than"` assembled
  at the call site — the same fragment rule the glyph label follows (§2).
- The wedge is not a stop on any rotor; it is reached inside the Bridge, which is a stop on
  **"Rails"**.

---

## 6. Reduce Motion

Cycling crossfades between two comparator drawings over `Dur.micro`, in both modes. **Never rotate
or flip the mark to get from `lt` to `gt`** — a rotation reads as a transition *between meanings*
rather than a replacement, and under Reduce Motion it is a rotation, which §13.12 gate 9 checks by
hand: nothing translates, scales or rotates anywhere.

The pressed state is an interior step, not a scale, so it needs no substitution.

---

## 7. High Contrast and RTL

**High Contrast.** `weight.body` 3.0 → 3.5 through `env.weight(.body)`, or 4.25 with Bold Text also
on. The mark box does not grow, so the `eq` bars' gap closes from `W/3` to `W/3 − 0.5`: at
`W = 24` that is 7.5 pt of clear space, still more than twice the stroke. Check this at the Codex
scale too — `24 × 0.78 = 18.7`, gap `6.2 − 0.5 = 5.7` against a 3.5 pt stroke, which is the tightest
shipped case and the one the snapshot gallery must show.

**RTL.** The wedge mirrors *with its rail*, so its wide end still physically opens toward the larger
socket (§12.8). This is automatic if and only if the construction is written in `minX`/`maxX` of a
rect that SwiftUI has already flipped — which is why §4's code says `opensTrailing`, not
`opensRight`. The meaning is positional and is therefore **preserved** by the mirror, not inverted
by it.

---

## 8. Wrong

- **An ASCII operator.** `>`, `>=`, `≥`, `!=` — any of them is a character on the play surface, and
  `PlaySurfaceTextTests` fails the build (§12.9). This is the single most likely regression on this
  component because the temptation is a one-line `Text`.
- **An SF Symbol.** `lessthan.circle` is a text-shaped asset with a font behind it, and §13.1 forbids
  SF Symbols on the play surface outright.
- **Hard-coding the limb angle** as 53° or 60°. It is `2 · atan(0.5)` by construction, and writing
  the number down means the day the mark box stops being square, the mark stops meeting its corners.
- **Rotating between `lt` and `gt`.** It reads as a transition between meanings and it violates the
  Reduce Motion gate.
- **Testing `left`/`right`.** The RTL mirror is carried by `leading`/`trailing`; a `left` test
  inverts the mnemonic in Arabic, which is exactly the failure the mirror rule exists to prevent.
- **A `default:` in the comparator switch.** A seventh comparator must break the build, not render
  an empty box.
- **Clipping instead of scaling.** Shrinking the container must shrink the mark; a clipped `gte`
  loses its underbar and becomes `gt`, which is a different law.
- **Colouring the wedge with a hue, or accenting it.** It is chrome. `stroke.primary`, always.
