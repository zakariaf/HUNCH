# link-arc.md — `LinkArc.draw`

<!-- inventory: Link arc / return elbow | LinkArc.draw -->

Contents: [1 Geometry](#1-geometry) · [2 Kinds, roles and states](#2-kinds-roles-and-states) ·
[3 The Swift](#3-the-swift) · [4 Environment behaviour](#4-environment-behaviour) ·
[5 The `C.LinkArc` namespace](#5-the-clinkarc-namespace) · [6 What would be wrong](#6-what-would-be-wrong)

Sites: ribbon adjacency (§4.1, §6.2) · spool-sheet row wrap (§6.2) · ECHO rail (§8.4) · contextual
counterexample join (§4.5) · Profile *Retention* sigil (§11.11 P3) · ECHO mode sigil (§12.4).

**What the mark asserts is adjacency in time.** Two tiles joined by an arc were probed one after the
other; a wrap that loses the join loses the chain. §6.2 is explicit about the spool sheet: *"link arcs
and a return elbow at each row end **so adjacency survives the wrap**"*.

---

## 1. Geometry

**The arc** is a quadratic Bézier from `a` to `b` whose control point is offset perpendicular to the
chord by twice the intended rise, so the apex lands at exactly `rise`:

```
chord   = b − a
n       = unit normal of chord, on the bulge side
rise    = min(|chord| / 2, C.LinkArc.maxRise)
control = midpoint(a, b) + n · 2 · rise
```

At the ribbon that is the PHOSPHOR mockup exactly: 44 pt tiles at 50 pt pitch leave a 6 pt gap, so the
arc runs `M (x+44) 26 q 3 −6 6 0` — a 6 pt chord and a 3 pt rise, drawn from the tile's vertical centre.
The `maxRise` cap is what keeps the contextual counterexample's join — two 96 pt glyphs with a much
wider gap — from arching into the throat.

**The return elbow** is the wrap: out from the trailing attachment by `C.LinkArc.elbowReach`, down by
the row pitch, back in to the next row's leading attachment, with `C.LinkArc.elbowRadius` (`Space.s4`)
rounded corners. Three segments and two corners, one sub-path. It is the same mark because it makes the
same assertion; it is a different *kind* because a Bézier cannot express a wrap without overshooting a
row.

**Ink and weight: `stroke.hairline` at `env.weight(.thin)`, `round` caps** (mockup, `drawRibbon`).
§13.3 puts round caps on chrome and the arc is chrome. Using the **hairline colour** is legitimate here
and is worth stating, because §13.2 declares hairline *never state-bearing*: adjacency is not a state of
any tile. Every arc in chain order is drawn; verdict sort drops **all** of them (§6.2). Nothing about a
single tile is ever read off the presence or absence of its arc.

---

## 2. Kinds, roles and states

| Kind | Drawing | Sites |
|---|---|---|
| `.arc` | §1's quadratic | ribbon adjacency, ECHO rail, contextual counterexample join, sheet within-row |
| `.elbow(drop:)` | §1's three-segment wrap | spool-sheet row end, Pro Max two-lane ribbon |

| Role | Ink | Sites |
|---|---|---|
| `.structural` | `stroke.hairline` | every live site |
| `.depictive` | `stroke.secondary` | Profile *Retention* sigil, ECHO mode sigil |

Depictions sit alone on a sigil with no tiles either side, so hairline would be invisible; `secondary`
is the same choice §12.4's other sigils make. The geometry does not change.

**States.** There is exactly one drawing. Scope §3 lists *"normal · dropped (verdict sort)"*, and
`dropped` is not a drawing — the host does not call. The `progress` parameter is an animation input, not
a state: the arc draws over 120 ms as part of the 260–420 ms window of the verdict beat (§6.5).

**The ECHO mode sigil is three arcs, not a new mark.** §12.4 builds it from "the ribbon's link arc":
a ring trailing three decaying concentric arcs. The host calls `draw` three times with decreasing
`opacity`; it does not write a decaying-arc function.

---

## 3. The Swift

```swift
import SwiftUI
import Tokens

public enum LinkArc {
    public enum Kind: Hashable, Sendable {
        case arc
        /// A row wrap. `drop` is the vertical distance to the next row's attachment point.
        case elbow(drop: CGFloat)
    }

    public enum Role: Hashable, Sendable { case structural, depictive }

    /// Joins two attachment points, asserting that they are adjacent in the chain.
    ///
    /// `a` and `b` are points, never tile indices: the same mark joins two ribbon tiles 6 pt apart and
    /// two 96 pt counterexample glyphs, and a grid-aware signature would fit only the first.
    ///
    /// `progress` trims the path for the 120 ms draw-on of §6.5's 260–420 ms window; a Reduce Motion
    /// host passes 1 and crossfades instead (§13.7.4, "ribbon tile slide-in").
    ///
    /// The context is taken by value; the opacity set here does not escape to the caller.
    ///
    /// - Complexity: O(1) — one sub-path.
    public static func draw(
        into context: GraphicsContext,
        from a: CGPoint,
        to b: CGPoint,
        kind: Kind = .arc,
        role: Role = .structural,
        progress: Double = 1,
        opacity: Double = 1,
        env: RenderEnv
    ) {
        guard progress > 0 else { return }
        var ctx = context
        ctx.opacity = opacity

        let ink = role == .structural
            ? env.palette.stroke.hairline
            : env.palette.stroke.secondary

        ctx.stroke(
            path(from: a, to: b, kind: kind).trimmedPath(from: 0, to: progress),
            with: .color(ink.color),
            style: StrokeStyle(lineWidth: env.weight(.thin), lineCap: .round, lineJoin: .round)
        )
    }
}
```

`path(from:to:kind:)` is `private` in the same file. It is not exposed: a public path is an invitation
to stroke the arc a second way, at a second weight, in a second file.

**No `layout` parameter.** The arc takes two points, and the host has already laid those out in the
mirrored coordinate space. §2's rule is that ramps, the Assay and the ribbon *render leading-to-trailing
in source order in every locale*, so under RTL the host hands over mirrored points and the arc is
correct without knowing the direction. The bulge side comes from the sign of the normal, which the host
also fixes: **always on the same side of the row**, so mirroring is a pure reflection and the chain does
not appear to change shape in Arabic.

---

## 4. Environment behaviour

**VoiceOver.** No element, and this is one of two marks the GDD explicitly exempts from the 44 pt hit
target: §8.4 — *"The pool strip and the primer strip are read-only and therefore exempt from the
hit-target floor, exactly as the ribbon's link arcs are."* Adjacency reaches VoiceOver through the
**"Probes" rotor**, which steps backward through the ribbon newest-first announcing glyph + verdict
(§13.10). The order *is* the adjacency; the arc is its picture. In contextual bands the counterexample's
join is carried by the "Counterexample" rotor's two stops — the counterexample glyph and the nearest
ribbon tile it was chosen against.

**Reduce Motion.** §13.7.4's "ribbon tile slide-in" row substitutes a 140 ms crossfade in place, so the
host passes `progress: 1` and crossfades the whole tile-plus-arc. The arc never draws on progressively.
It does not read `isReduceMotionEnabled` itself.

**High Contrast.** `stroke.hairline` resolves to its High Contrast value and `weight.thin` picks up the
flat `+0.5` through `env.weight(_:)`. That is the theme's answer for every hairline in the app and the
arc takes it unchanged. The hex and the measured ratio live in
`hunch-design-tokens/references/palette.md` §1 and nowhere else — quote its **measured** column if you
need the number, never §13.2's, which is wrong for this cell.

**Bold Text.** `weight.thin` × 1.25 through `env.weight(_:)`. At the ribbon's 6 pt chord and 3 pt rise
the arc stays a hair, which is correct: it is connective tissue and must never compete with the tiles
it joins.

**Differentiate Without Colour.** Nothing. The mark is a pure geometry channel.

**Bloom.** Never, even though the arc lives inside the ribbon region and pass A wraps that region. The
arc is drawn **outside** the bed layer: pass A clones the region's *marks* (§13.5, PHOSPHOR §2 pass A),
and a blurred hairline at `opacity.bloomBed` over a 6 pt gap smears into both neighbouring glyphs and
raises their measured interior coverage. Draw arcs into the host's non-bed sub-layer.

**Dynamic Type.** The host scales the tile pitch by `env.artScale`, so the chord grows and the rise
grows with it up to `maxRise`. Nothing here multiplies by `artScale`.

**Two devices.** SE has one ribbon lane; Pro Max has two lanes at 50 pt pitch, and *the chain wraps with
a return elbow* (§6.2). The spool sheet wraps at every row end on both devices — 7 columns × 10 rows,
70 cells, sized against `1 + max(cap, cap_DRIFT) = 65`. Elbow count is therefore a layout fact the host
computes; the mark draws one elbow per call.

---

## 5. The `C.LinkArc` namespace

| Member | Value | Home of the number |
|---|---|---|
| `riseRatio` | `0.5` × chord | PHOSPHOR mockup, `drawRibbon` — a 6 pt gap and a 3 pt rise |
| `maxRise` | `Space.s12` (12 pt) | this skill — caps the contextual counterexample's join |
| `elbowRadius` | `Space.s4` (4 pt) | this skill — the elbow is chrome routing on the 4 pt base grid (§13.3) |
| `elbowReach` | `Space.s8` (8 pt) | this skill — how far the elbow runs past the row before turning |

Weight and colour are not here: `env.weight(.thin)`, `env.palette.stroke.hairline`,
`env.palette.stroke.secondary`. The 120 ms draw-on is §6.5's and belongs to
`hunch-motion-and-feedback`. `riseRatio`, `elbowRadius` and `elbowReach` are expressed against `Space`
so they stay on the grid when someone changes them.

---

## 6. What would be wrong

- **A signature that takes tile indices, a lane number or a pitch.** The mark joins two *points*. The
  moment it knows about the ribbon's grid it cannot draw the counterexample join, and someone writes a
  second function for that.
- **Exposing the `Path`.** A public path gets stroked at a different weight in a different file within a
  release, and then the sheet's arcs and the ribbon's arcs are different marks.
- **Drawing the arc into the bloom bed.** It smears across a 6 pt gap into two glyph interiors and moves
  the measured `fill` coverage that §13.5.1's proof depends on.
- **Making the bulge side depend on layout direction.** The chain would appear to change shape between
  locales. Fix the side to the row and let the host's mirrored points do the work.
- **Drawing an arc under verdict sort.** §6.2 drops them all; a "faded" arc is a third state that says
  adjacency partly holds, which is not a thing.
- **Giving the arc a hit target.** §8.4 exempts it by name. A 6 pt-wide tappable arc between two 44 pt
  targets steals taps from both.
- **Using `stroke.secondary` for a structural arc, or `stroke.hairline` for a sigil.** The first makes
  connective tissue compete with tiles; the second makes a sigil invisible at 24 pt.
- **Writing a decaying-arc function for the ECHO sigil.** It is three calls with three opacities.
- **Animating the draw-on inside this function.** `progress` is the host's.
- **Writing a hex or a contrast ratio into this file.** `palette.md`'s measured column is the one
  home; a copied ratio imports canon's error, which is exactly how this file once claimed the wrong
  figure for High Contrast `stroke.hairline`.
