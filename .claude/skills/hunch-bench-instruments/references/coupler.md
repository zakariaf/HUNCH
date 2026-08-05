# coupler.md — three diagrams, not three symbols

Contents: [1 Geometry](#1-geometry) · [2 The three drawings](#2-the-three-drawings) ·
[3 States](#3-states) · [4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) ·
[6 Reduce Motion](#6-reduce-motion) · [7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `CouplerView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`. **L2:** `C.Coupler`.
The rails it joins: `rule-tile.md` §4. Values: `hunch-design-tokens`.

---

## 1. Geometry

*"The junction between the two rails is a circular node."* (§4.2) The Bench stacks rail 1 above
rail 2, so the coupler sits **between them vertically**, centred on the rails' shared centre line.

| Property | Value | Source |
|---|---|---|
| hit rect | 44 × 44 | §12.8's floor; the node is a tap target |
| node diameter | 32 pt | `C.Coupler.nodeDiameter`; the circle inside the 44 pt rect |
| strand weight | `weight.body` | PHOSPHOR §1.3 — the wedge and the coupler strands share it |
| the AND weld | `weight.heavy` | §13.3, §4.2 — a heavier line means state, and AND is the welded one |
| node rim | `weight.thin` in `stroke.hairline` | the circle is a container, not content |
| ink | `stroke.primary` | chrome register |
| vertical band | 44 pt between the two rails | the coupler's own band in the Bench stack |

```swift
extension C.Coupler {
    public static let nodeDiameter = 32.0        // inside a 44 pt hit rect
    public static let strandSpread = 0.34        // fraction of the node diameter, OR/XOR
    public static let weldWeight = StrokeWeight.heavy
    public static let strandWeight = StrokeWeight.body
}
```

`strandSpread` is the only free constant: it is the perpendicular distance each OR strand bows away
from the axis, as a fraction of the node diameter, so the drawing is scale-invariant. At 32 pt that
is 10.9 pt of separation between the two strands — wider than three times the 3 pt stroke, which is
the legibility floor the snapshot gallery checks at the Codex scale (`32 × 0.78 = 25`, spread 8.5 pt
against a 3 pt stroke).

---

## 2. The three drawings

*"Tap to cycle: **AND** = a solid welded bar; **OR** = a forked bar, two strands that split and
rejoin; **XOR** = a forked bar whose two strands cross and terminate — you may take one path but not
both. Diagrams, not symbols, and all three are commutative, matching the semantics."* (§4.2)

| Coupler | Drawing | Construction, on the node's vertical axis |
|---|---|---|
| **AND** | one solid welded bar | a single stroke through the node at `weight.heavy` — one path, no choice |
| **OR** | two strands split and **rejoin** | the axis splits at the node's leading third, bows ± `strandSpread · d`, and rejoins at the trailing third — two paths, both available |
| **XOR** | two strands **cross and terminate** | the same split, but the strands cross at the node centre and each ends at the opposite side's rim — two paths, one usable |

The three are readable as a sequence: one path, two paths that reunite, two paths that do not. That
progression is the whole explanation, and it is why these are diagrams: an `∧` `∨` `⊕` set would be
three characters on a textless surface and would carry no ordering at all.

**All three are commutative and the drawing must be symmetric about the axis**, matching the
semantics (§4.2). An asymmetric OR would imply an order between the rails that the grammar does not
have — and the RNF fold sorts commutative operands, so a drawn asymmetry would contradict the AST
the tile round-trips to (§3.4, G10).

---

## 3. States

| State | When | Drawing |
|---|---|---|
| **and** / **or** / **xor** | on the Bench, two rails filled | §2 |
| **read-only** | Codex page, Inscription, reveal | identical drawing, no hit target |
| **absent** | a Fork or a Tally occupies the whole Bench | **not drawn at all** — not greyed, not disabled, not an empty node |

Absent is the state to get right: *"A Fork or a Tally occupies the whole Bench and has no coupler"*
(§4.2). A disabled coupler beside a Fork would imply a combinator the grammar cannot express, and
the palette's own ceiling — `MAX_DEPTH = 2`, `MAX_LEAVES = 4` — is what makes the Bench and the
grammar the same language (§4.4).

A coupler is never inert and never bars the Seal: all three states are always legal.

---

## 4. SwiftUI

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

struct CouplerShape: Shape {
    let coupler: Coupler

    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height, C.Coupler.nodeDiameter)
        let node = CGRect(
            x: rect.midX - d / 2, y: rect.midY - d / 2, width: d, height: d)
        let spread = d * C.Coupler.strandSpread
        var path = Path()
        switch coupler {
        case .and:
            path.move(to: CGPoint(x: node.midX, y: node.minY))
            path.addLine(to: CGPoint(x: node.midX, y: node.maxY))
        case .or, .xor:
            let top = CGPoint(x: node.midX, y: node.minY)
            let bottom = CGPoint(x: node.midX, y: node.maxY)
            for side in [-1.0, 1.0] {
                let control = CGPoint(x: node.midX + side * spread, y: node.midY)
                path.move(to: top)
                if coupler == .or {
                    path.addQuadCurve(to: bottom, control: control)
                } else {
                    // cross at the centre, terminate on the far rim
                    path.addLine(to: CGPoint(x: node.midX - side * spread, y: node.maxY))
                }
            }
        }
        return path
    }
}

struct CouplerView: View {
    let env: RenderEnv
    let coupler: Coupler
    let isReadOnly: Bool
    let onCycle: () -> Void

    var body: some View {
        Button(action: onCycle) {
            CouplerShape(coupler: coupler)
                .stroke(
                    env.palette.stroke.primary.color,
                    lineWidth: env.weight(coupler == .and ? .heavy : .body))
                .background {
                    Circle().strokeBorder(
                        env.palette.stroke.hairline.color, lineWidth: env.weight(.thin))
                }
        }
        .buttonStyle(.plain)
        .frame(width: Space.targetMin, height: Space.targetMin)
        .contentShape(.rect)
        .disabled(isReadOnly)
        .accessibilityLabel(Loc.couplerControl)
        .accessibilityValue(Loc.couplerName(coupler))
        .accessibilityAction(named: Loc.cycle, onCycle)
    }
}
```

The switch has no `default:` (`03 W29`): a fourth combinator must break the build here rather than
render an empty node. `Coupler` is `HunchCore`'s three-case enum from §2's locked vocabulary, and
the cycle order is its declaration order — `and → or → xor → and` — so cycling and serialisation
agree without a second table.

---

## 5. VoiceOver

- Traits `.button`; label `"Coupler"`; value `"and"` / `"or"` / `"exclusive or"` (§13.10).
- One custom action, `"Cycle"`, calling the same function the tap does.
- The coupler is a stop on the **"Rails"** rotor, between rail 1 and rail 2 — that placement is what
  makes the rotor a *reading order* for the draft rather than a list of controls (§13.10).
- `"exclusive or"` is a complete localized string, not `"exclusive"` + `"or"`.
- When the coupler is **absent** it must be removed from the accessibility tree entirely, not hidden
  with an empty label: a silent stop on the Rails rotor is a dead swipe every time a Fork is on the
  Bench.

---

## 6. Reduce Motion

Cycling crossfades between two coupler drawings over `Dur.micro`, in both modes. Do not animate the
strands morphing from one topology to another: an OR bowing into an XOR reads as the two strands
*moving through* an intermediate state that means neither, and under Reduce Motion it is motion the
substitution table has no row for.

The pressed state is an interior step on the node, not a scale.

---

## 7. High Contrast

- `weight.heavy` 4.0 → 4.5 and `weight.body` 3.0 → 3.5 through `env.weight(_:)`; with Bold Text also
  on, 5.5 and 4.25. The AND weld stays visibly heavier than the OR/XOR strands at every combination,
  which is the property that makes the three readable without colour — check it against the resolved
  matrix in `dimensions-strokes-opacity.md` §2 rather than assuming it.
- The node rim is `stroke.hairline`, which is **never state-bearing** (§13.2) and sits at 3.04 : 1
  under High Contrast. That is fine here precisely because the rim carries no state: the strands do.
- No hue is present, so the hue collapse does not touch the coupler.

**Differentiate Without Colour** changes nothing: all three states are already pure topology.

---

## 8. Wrong

- **`∧`, `∨`, `⊕`, `&&`, `AND`.** Characters on a textless surface;
  `PlaySurfaceTextTests` fails the build (§12.9).
- **An asymmetric OR or XOR.** The combinators are commutative and the RNF fold sorts their
  operands; an asymmetric drawing asserts an order the AST does not have.
- **A disabled coupler beside a Fork or a Tally.** It is *absent* — not drawn, not in the
  accessibility tree.
- **Making the AND weld the same weight as the strands.** `weight.heavy` versus `weight.body` is one
  of the three channels; equal weights leave only topology, which is thinner than it needs to be.
- **Animating a topology morph.** Crossfade; there is no meaningful in-between state.
- **A fourth state — NAND, implication, "none".** The grammar has three (§2's `enum Coupler`), and
  the `default:`-free switch is what keeps that true.
- **Putting the coupler inside a rail.** It is between the rails and is its own stop on the Rails
  rotor; nesting it makes the rotor's reading order wrong.
- **A hue or an accent on the node.** Chrome register, `stroke.primary`, always.
