# profile-contour.md — the five-axis self-portrait

Owning symbol: `MetaFeature/ProfileContour.swift` → `struct ProfileContour: View` and
`struct ContourShape: Shape`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row D, *Profile contour*.

Contents: [1 Geometry](#1-geometry) · [2 The normalisation](#2-the-normalisation) ·
[3 The spline](#3-the-spline) · [4 Ink](#4-ink) · [5 Tremble](#5-tremble) · [6 The morph](#6-the-morph) ·
[7 The ghost](#7-the-ghost) · [8 Vertex sigils and the stat block](#8-vertex-sigils-and-the-stat-block) ·
[9 VoiceOver](#9-voiceover) · [10 Environment behaviour](#10-environment-behaviour) ·
[11 The property that must be tested](#11-the-property-that-must-be-tested) · [12 Wrong](#12-wrong)

---

## 1. Geometry

Card **375 × 280 pt**, centre `(187.5, 140)`, `R0 = 96 pt` (§11.10). Five vertices at
`θᵢ = −90° + i · 72°`, locked clockwise from the top:

| i | Axis | θ |
|---|---|---|
| 0 | Induction | −90° |
| 1 | Retention | −18° |
| 2 | Flexibility | 54° |
| 3 | Restraint | 126° |
| 4 | Tempo | 198° |

Screen frame, y down, angles clockwise from East — the same convention the glyph renderer resolved
(`hunch-glyph-renderer/references/geometry.md`). `θ = −90°` therefore lands at the top of the card.
Use one convention for the whole app or the Flexibility and Restraint vertices swap sides and nothing
fails.

L2, all from §11.10: `C.Profile.cardSize`, `.centre`, `.r0`, `.contourWeight`, `.innerOffsetWeight`,
`.innerOffsetInk`, `.fillInk`, `.fillInkHighContrast`, `.spokeInk`, `.spokeInkHighContrast`,
`.ghostInk`, `.ghostWeight`, `.splineTension`, `.trembleFraction`, `.trembleHz`,
`.trembleConfidenceCap`, `.morphDuration`, `.morphHold`, `.morphStagger`, `.morphSpring`.

**Every one of those is L2 and lands in `C.swift`, with its §11.10 citation attached.** None of them
is an L1 weight, opacity, duration or easing: the contour's 2 pt and the tremble's 0.6 Hz are not
positions on `hunch-design-tokens`' ladders, which is exactly why they are declared here instead of
borrowed. Where this component *does* use an L1 value — the stat block's type roles, Bold Text's
multiplier, the High Contrast offset — it reads it through `env`, and this file states no number.

---

## 2. The normalisation — the load-bearing rule

```
v̄  = mean(v₀ … v₄)
rᵢ = R0 · clamp(0.55 + 0.45 · vᵢ / max(0.15, v̄), 0.35, 1.55)
```

§11.10, verbatim. **A uniform rise across all five axes leaves the shape pixel-identical.** Only
asymmetry is visible. You cannot inflate the portrait; you can only bend it.

This is what makes "not a grade" a property of the geometry rather than a rule about copy, and it is
the single thing in this component that a well-meaning refactor is most likely to destroy — replacing
`v̄` with a constant, or clamping against `R0` instead of the mean, both produce a portrait that
grows. §11 has the test that catches it.

`max(0.15, v̄)` is the day-1 guard: at zero rounds every `vᵢ = 0`, so `v̄ = 0`, and the guard makes
every `rᵢ = 0.55 · 96 = 52.8 pt` — a small regular pentagon-spline that reads as *unformed*, not as
*zero*. That distinction is the whole of the day-1 design.

---

## 3. The spline

A **closed Catmull–Rom spline, tension 0.5, converted to cubic Bézier** (§11.10). Not a polygon: *"a
polygon with vertices reads as a radar chart, and a radar chart reads as a score."*

`nonisolated` on the `Shape` is load-bearing for the same reason it is on `GlyphShape`
(`hunch-glyph-renderer/references/geometry.md` §4): `MetaFeature` takes
`.defaultIsolation(MainActor.self)`, `Shape.path(in:)` is a nonisolated protocol requirement, and a
`ContourShape` pinned to the main actor cannot be exercised by a `swift test` suite that has no main
actor to run on.

```swift
nonisolated struct ContourShape: Shape {
    var radii: [Double]           // five, already normalised and trembled
    let centre: CGPoint
    var animatableData: AnimatableVector { get { .init(radii) } set { radii = newValue.values } }

    func path(in rect: CGRect) -> Path {
        let p = (0..<5).map { i -> CGPoint in
            let θ = (-90.0 + Double(i) * 72.0) * .pi / 180
            return CGPoint(x: centre.x + radii[i] * cos(θ), y: centre.y + radii[i] * sin(θ))
        }
        var path = Path()
        path.move(to: p[0])
        for i in 0..<5 {
            let p0 = p[(i + 4) % 5], p1 = p[i], p2 = p[(i + 1) % 5], p3 = p[(i + 2) % 5]
            let s = C.Profile.splineTension / 3          // tension 0.5 → cardinal spline
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) * s, y: p1.y + (p2.y - p0.y) * s),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) * s, y: p2.y - (p3.y - p1.y) * s))
        }
        path.closeSubpath()
        return path
    }
}
```

`animatableData` over the five radii is what makes §6's staggered morph a real interpolation rather
than a crossfade between two static shapes.

---

## 4. Ink

§11.10, and every number here is an L2 token declared in §1:

| Element | Dark / light | High Contrast | L2 member |
|---|---|---|---|
| contour | `accent.brass` at `.contourWeight` | `stroke.primary` | `C.Profile.contourWeight` |
| interior fill | `accent.brass` at `.fillInk` | **transparent** — `.fillInkHighContrast` | `C.Profile.fillInk` |
| inner offset contour | `.innerOffsetInk` at `.innerOffsetWeight`, offset inward, for depth | as dark | `C.Profile.innerOffset*` |
| five spokes | `stroke.secondary` at `.spokeInk` | `.spokeInkHighContrast` | `C.Profile.spokeInk` |
| ghost | dashed at `.ghostInk`, `.ghostWeight` | as dark | `C.Profile.ghost*` |

Every value in that table is §11.10's, declared once in `C.Profile` (§1) and read from there. The
inks are opacities *on a palette colour*, never new colours — there is no hex anywhere in this
component.

**No gridlines, no concentric rings, no ticks, no axis labels, no numerals** (§11.10, §11.11 P2).
Gridlines are precisely what make a radar chart measurable, and the five 12 % spokes exist only to
say *there are five of something*.

The brass contour is a sanctioned accent site. §13.1 rations accent to three elements per screen; the
Profile spends one, on the contour, and the stat block and vertex sigils are `stroke.*`. Register
segregation is satisfied — the contour is not a glyph body, fill, pip, ramp cell or index stroke
(§13.2).

---

## 5. Tremble — confidence renders as motion, never as size

```
Aᵢ = R0 · 0.05 · (1 − min(1, nᵢ / 24))          value noise at 0.6 Hz
rᵢ' = rᵢ + Aᵢ · noise(t, i)
```

§11.10. At day 1, `A = 4.8 pt` on every vertex; at `n ≥ 24` it is zero and the contour is still.
Confidence therefore reads as *steadiness*, which cannot be mistaken for *more*.

**The noise must be deterministic.** HUNCH's determinism requirement is a hard one, and
`Double.random` in a draw call means two devices at the same `t` draw different shapes and no
snapshot is reproducible. Use `SplitMix64` from `HunchCore/LawGeneration`, seeded per vertex index,
sampling at `floor(t · trembleHz)` and interpolating between the two samples:

```swift
func trembleNoise(t: Double, vertex i: Int) -> Double {
    let phase = t * C.Profile.trembleHz
    let k = phase.rounded(.down)
    let f = phase - k                                  // smoothstep between samples
    let a = SplitMix64(seed: UInt64(bitPattern: Int64(k))    &+ UInt64(i)).nextUnitDouble()
    let b = SplitMix64(seed: UInt64(bitPattern: Int64(k + 1)) &+ UInt64(i)).nextUnitDouble()
    let s = f * f * (3 - 2 * f)
    return (a + (b - a) * s) * 2 - 1                    // −1 … +1
}
```

Drive it with a `TimelineView(.animation(minimumInterval: 1.0 / 30))`, not a `Timer` and not
`.repeatForever` — a 0.6 Hz signal does not need 120 Hz, and a `TimelineView` stops when the view
leaves the screen.

**Tremble stops under Reduce Motion and under Low Power Mode.** Reduce Motion is §11.10's own
substitution (below). Low Power is this skill's ruling and the reason is direct: a continuously
redrawing `TimelineView` is exactly the work Low Power Mode is asking us not to do, and
`render-env.md` already suppresses bloom, the shader and long haptics on that axis. The static-dash
substitution is identical in both cases, so no third rendering exists.

---

## 6. The morph

§11.10, on entering the Profile screen only. Never during play, and never at round end (§11.11 P6).

```
phaseAnimator over C.Profile.morphDuration:
  hold          the previous session's contour, for C.Profile.morphHold
  spring        each vertex to its new radius, staggered i · C.Profile.morphStagger,
                under C.Profile.morphSpring
  settle        the contour settles; tremble amplitude updates
```

One `phaseAnimator` over a `MorphPhase` enum, for the same reason §13.7.1's reveal is one — so the
beats cannot drift apart. `lastRenderedRadii` is persisted in `profile.json` (§11.13) precisely so
the hold beat has a previous shape to hold.

`C.Profile.morphSpring` carries §11.10's own response and damping and is **not** `Easing.settle` or
any other L1 spring — this is the only spring in the app outside the six token easings, because it is
a staggered per-vertex morph rather than a UI transition. It is declared in `C.swift` with that
sentence attached, or someone will "fix" it to `ease.settle` and the stagger will lose its shape.

---

## 7. The ghost

The portrait as it stood **90 days ago**, drawn behind at 12 % opacity, 1 pt, dashed, unlabelled
(§11.10). Stored as `ghost: [Double]` + `ghostTakenAt` in `profile.json`.

It is the only temporal comparison in the app, it is self-to-self, and because radii are
mean-normalised **it can only show change of shape, never growth** (§11.11 P5). No legend, no date,
no "90 days ago" caption — a label would turn it into a before/after.

If `ghostTakenAt` is nil (day 1, or after Reset Profile) there is no ghost. Do not draw the current
contour twice.

---

## 8. Vertex sigils and the stat block

**Five vector vertex sigils**, one per axis, drawn from the game's existing vocabulary (§11.11 P3):

| Vertex | Sigil |
|---|---|
| Induction | a ramp silhouette |
| Retention | a link arc |
| Flexibility | the Fork's railway switch |
| Restraint | the Seal's bar |
| Tempo | a tick strip |

All five are `hunch-sigil-drawing/references/profile-vertex-sigils.md` and are currently **undrawn** —
§2(e) of the scope document. This file owns their placement (at their vertex, 44 × 44 hit rect each)
and their accessibility, not their drawing.

**The axis names never appear in the app.** *Induction, Retention, Flexibility, Restraint, Tempo* are
code identifiers only; §12.9 forbids them entering `Localizable.xcstrings` in any form, visible or
spoken. That is what makes §11.11 P8's banned-lexeme test survivable — *Retention* and *Flexibility*
land on "memory" and "ability" in several of the twelve languages, and both words fail the build.

**Stat block:** five rows — rounds, pages, longest run, Anomaly streak, mean probes/par (§12.9).
`type.numeral` per `numeral-readout.md` site 6. **No "highest band" row** (§10.5). One item per line
at AX2 and above (§13.11).

At AX3 the five sigils **reflow from a ring to a vertical list**, each keeping its 44 × 44 hit rect
(§13.11). The portrait itself does not move and does not scale.

---

## 9. VoiceOver

**The five approved behavioural sentences from §11.11 are the vertices' accessibility labels.** Not
hints, not values — labels. They describe what you did, never what you are, and the identifier is
never spoken and is not a fallback.

| Vertex | Label (§11.11, verbatim, localized) |
|---|---|
| Induction | "How deep in the machine's law families your finished rounds sit." |
| Retention | "How often you re-ask a question the ribbon already answered." |
| Flexibility | "How many probes you spend after a verdict contradicts your theory." |
| Restraint | "How often you declare before the evidence closes." |
| Tempo | "Your probes against par." |

**The contour itself is `.accessibilityHidden(true)`.** A closed spline has no spoken form that is
not a grade, and narrating "your shape is pulled toward Restraint" would be a readout §11.11 P6
exists to forbid.

**Proposed, and owned by `hunch-accessibility`:** each vertex takes an `accessibilityValue` drawn
from three qualitative strings — *more than your usual · about your usual · less than your usual* —
thresholded on `rᵢ / R0` against the same mean-normalised quantity the drawing uses. Without it a
non-sighted player gets five sentences and no portrait at all. It must be qualitative and
three-valued: a number or a percentage would be the grade P1 and P2 make impossible, and the phrasing
is self-relative for the same reason the geometry is. Budget: **+3 keys** against §12.9's ≈ 228 and
its hard ceiling of 250. Raise it in `hunch-accessibility/references/voiceover-elements.md` rather
than shipping the strings from here.

---

## 10. Environment behaviour

| Setting | Effect |
|---|---|
| **Reduce Motion** | tremble becomes a **static dash pattern whose gap length scales with `A`** (§11.10); the `C.Profile.morphDuration` morph becomes an instant new shape with a crossfade, and everything else on the screen crossfades too — every substituted duration is §13.7.4's and lives in `hunch-motion-and-feedback/references/reduce-motion.md`. The dash phase must be constant — a time-varying `dashPhase` is an animation by another name |
| **High Contrast** | contour → `stroke.primary`, and `C.Profile.fillInk` / `.spokeInk` substitute to their `…HighContrast` members (§11.10, §4). Weights take the flat High Contrast offset through `env.weight(_:)` |
| **Low Power Mode** | as Reduce Motion, for the tremble only. §5 |
| **Bold Text** | contour and spoke weights take Bold Text's stroke multiplier through `env.weight(_:)` (`render-env.md` §2). The stat block's type steps one notch |
| **Dynamic Type** | **the card does not scale.** §13.11: *"The portrait card holds canon's geometry — 375 × 280 pt, `R0 = 96 pt` — and does not scale with type: it is a drawing, not text."* The sigils reflow at AX3 and the stat block goes one item per line at AX2 |
| **Differentiate Without Color** | no effect. The portrait encodes nothing in colour — the contour is one ink and the ghost is distinguished by dash and opacity |
| **RTL** | **the portrait does not mirror.** Vertex order is locked clockwise from the top (§11.10) and mirroring would swap Retention with Tempo. The stat block and the instrument bar mirror; the drawing does not — the same rule that stops the glyph mirroring (§12.8) |

---

## 11. The property that must be tested

The mean-normalisation is invisible in any single snapshot. One property test catches its removal:

```swift
@Test("A uniform rise across all five axes leaves the shape pixel-identical",
      .tags(.unit, .presubmission))
func uniformRiseLeavesTheShapeIdentical() {
    let base = Profile(values: [0.2, 0.5, 0.3, 0.8, 0.4], counts: .init(repeating: 60, count: 5))
    let risen = base.scalingAllAxes(by: 1.6)          // still ≤ 1.0 everywhere
    // No `==` on Doubles and no `for` loop in a test (06 T21, 06 T42) — `isApproximatelyEqual`
    // is HunchTestSupport's, because swift-numerics is banned (08 §7.9).
    #expect(zip(base.radii(), risen.radii())
        .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-9) })
}
```

There is no `≈` operator in this project and there must not be one: a custom operator hides the
tolerance, and `hunch-swift-testing/references/doubles-and-fixtures.md` §6 requires the tolerance to
be stated at the call site.

The suite belongs to `hunch-swift-testing`; the property belongs here, because it is the geometric
statement of §11.11 P1 and nothing else in the codebase asserts it. A second test asserts
per-axis monotonicity — for each axis, a strictly better transcript never produces a smaller sample
(§11.9) — which is what keeps *more is more of the thing the vertex is named for* true, and therefore
keeps the drawing honest.

---

## 12. Wrong

- **Gridlines, concentric rings, ticks, axis labels or a numeral anywhere on the portrait.** §11.10,
  §11.11 P2. A numeral there would be a grade.
- **A polygon instead of a spline.** A polygon reads as a radar chart and a radar chart reads as a
  score (§11.10).
- **Normalising against `R0` or a constant instead of `v̄`.** §2. The portrait would grow, and the
  whole "not a grade" argument would be a comment rather than a mechanism.
- **Showing the portrait at round end, or anywhere but `ProfileView`.** §11.11 P6.
- **Animating the portrait during play.** §11.10: it never does.
- **The axis names, in the UI, in `Localizable.xcstrings`, in a VoiceOver string, or in App Store
  copy.** §11.11 P3, §12.9. And none of §11.11's banned lexemes — brain, memory, focus, skill, level,
  score, rank, percentile, "get better" — in any of the twelve languages, including in jest. §11.11
  P8 fails the build on a hit.
- **A time series, a sparkline, a second ghost, or a labelled ghost.** §11.11 P5.
- **Any comparison to another player.** There is no other player's data on the device; comparison is
  unavailable rather than suppressed (§11.11 P4).
- **`Double.random` in the tremble.** §5. Determinism is a hard requirement.
- **A `Timer` or `.repeatForever` for the tremble.** §5.
- **Scaling the card with Dynamic Type, or mirroring it under RTL.** §10.
- **Reusing `Easing.settle` for the morph.** §6.
- **A "share your portrait" affordance.** §11.5: no share sheet, no export, no image composer. The
  system screenshot is the whole answer.
