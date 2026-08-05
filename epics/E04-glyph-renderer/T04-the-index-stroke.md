# T04 — The index stroke

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | §14.1 ART / MOTION → **Glyph geometry** (the `hue` register) · §14.1 LOCALIZATION → **RTL** · §14.1 ACCESSIBILITY → **High Contrast theme** (the glyph's index-length substitution) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | High Contrast's `0.273·S → 0.409·S` is a **substitution**: it terminates resolution and is never also scaled by Bold Text or offset by the High Contrast stroke delta. The skill owns "substitution beats modification" and the four-stage resolution order this task must not break. |
| `hunch-glyph-renderer` | Owns the `hue` register. `references/geometry.md` §7 has the three load-bearing properties (never thins, butt caps, a 135° sweep not a cycle); §5.1 has the overlap with the S pip node that forces the draw order; §6 has the bleed the stroke creates. |

## Objective

The `hue` channel is drawn: one straight stroke of weight `body`, centred at `(0, +0.43·S)` in the screen frame, of length `0.273·S` — `0.409·S` under High Contrast — rotated 0° / 45° / 90° / 135° by hue rank, with butt caps, drawn last and never knocked out. Before this task hue exists only as a colour, which is exactly what §2 says it must not be; after it, hue is recoverable from geometry alone, and `teal` against `rose` — the pair canon fears, eight greyscale levels apart — is separated by a 90° rotation, the maximum available.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 | hue's register is the index register below the body; the rotation table; "the index stroke is not decoration, it **is** the hue channel and colour is the redundant copy"; RTL: mirroring would swap `teal` and `rose` in Arabic |
| `GAME_DESIGN.md` | §13.5 | position `y = −0.43·S` (y-up), length `0.273·S`, High Contrast `0.409·S`, weight stays `body` when the silhouette drops to `bodySm` |
| `GAME_DESIGN.md` | §13.3 | butt caps on glyph geometry "so a 45° index stroke has an honest length" |
| `GAME_DESIGN.md` | §13.11 | the High Contrast theme: hue → `stroke.primary`, index stroke 12 → 18 pt at the ribbon tile |
| `GAME_DESIGN.md` | §12.8, §13.5.1 | RTL; index-stroke rotation as the `hue` channel's achromatic discriminator |
| `hunch-glyph-renderer` | `references/geometry.md` §7 | the three properties and why each is easy to lose |
| `hunch-glyph-renderer` | `references/geometry.md` §5.1 | frost's tip lands inside the S pip disc: the index stroke is drawn last and is never knocked out |
| `hunch-design-tokens` | `references/render-env.md` §2 | substitution beats modification; `0.409·S` is not `0.273·S` × anything |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Append to `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift` (these are `geometry.md` §8's two suites, which are normative for this task):

```swift
    /// The hue channel is deliberately the heaviest non-colour mark on the glyph: at
    /// S < 48 the silhouette drops to `bodySm` and the index stroke does not follow it.
    @Test("The index stroke never thins with the silhouette",
          arguments: [24.0, 36, 44, 47.9, 48, 52, 96, 128, 220])
    func indexStrokeNeverThinsWithTheSilhouette(side: Double) {
        let env = RenderEnv()
        #expect(isApproximatelyEqual(C.Glyph.indexStroke(in: env), env.weight(.body),
                                     absoluteTolerance: 1e-9))
        if side < 48 {
            #expect(C.Glyph.bodyStroke(side: side, in: env) < C.Glyph.indexStroke(in: env))
        }
    }

    /// High Contrast SUBSTITUTES the longer stroke; resolution terminates there. Bold Text
    /// moves the weight and must not move the length — otherwise the two settings stop
    /// being independent and §13.11's stated value silently becomes something else.
    @Test("High Contrast substitutes the index LENGTH and never also scales it")
    func highContrastSubstitutesTheIndexLength() {
        let plainHC = RenderEnv(theme: .highContrast)
        let boldHC = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        #expect(isApproximatelyEqual(C.Glyph.indexLength(side: 44, in: boldHC),
                                     C.Glyph.indexLength(side: 44, in: plainHC),
                                     absoluteTolerance: 1e-9))
        #expect(C.Glyph.indexStroke(in: boldHC) > C.Glyph.indexStroke(in: plainHC))
        #expect(isApproximatelyEqual(C.Glyph.indexStroke(in: boldHC), boldHC.weight(.body),
                                     absoluteTolerance: 1e-9))
        // The substitution is longer than the base in every theme that is not it.
        #expect(C.Glyph.indexLength(side: 44, in: plainHC)
                    > C.Glyph.indexLength(side: 44, in: RenderEnv()))
    }

    /// The register sits BELOW the body in the screen frame. §13.5 states it as −0.43·S
    /// in a y-up frame; reading it literally floats the stroke above the mark.
    @Test("The index register sits below the body", arguments: [36.0, 44, 96, 220])
    func theIndexRegisterSitsBelowTheBody(side: Double) {
        #expect(C.Glyph.indexCentreOffset(side: side) > 0)
        #expect(C.Glyph.indexCentreOffset(side: side)
                    > C.Glyph.radius(side: side) + C.Glyph.centreOffset(side: side))
    }
```

Create `Modules/Tests/HunchUITests/GlyphIndexStrokeTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("The index stroke", .tags(.snapshot, .presubmission))
@MainActor
struct GlyphIndexStrokeTests {

    private static let side = 96.0

    /// Rank order is a 135° SWEEP, not a cycle: 0 → 45 → 90 → 135 is a total order the
    /// eye can rank, where 0 → 90 → 180 → 270 would make rank 1 and rank 4 the same line.
    /// Measured off the raster as the ink's principal axis inside the index register, so
    /// it tests the shipped drawing rather than a constant.
    @Test("Rotation is a 135° sweep by hue rank", arguments: Glyph.Hue.allCases)
    func rotationIsA135DegreeSweepByHueRank(hue: Glyph.Hue) throws {
        let env = RenderEnv()
        let mask = try coverageMask(Glyph(fill: .hollow, shape: .circle, pips: .one, hue: hue),
                                    side: Self.side, env: env)
        let statistics = mask.indexRegionStatistics(side: Self.side, env: env)
        let rank = try #require(Glyph.Hue.allCases.firstIndex(of: hue))
        #expect(isApproximatelyEqual(statistics.axisDegrees, Double(rank) * 45,
                                     absoluteTolerance: 2))
    }

    /// Butt caps, so a 45° stroke has an honest length. Round caps would add one stroke
    /// width to `teal` and `rose` and nothing to `amber` and `frost`, which would make the
    /// LENGTH of the stroke a fifth channel nobody specified.
    @Test("Every rotation draws the same length", arguments: Glyph.Hue.allCases)
    func everyRotationDrawsTheSameLength(hue: Glyph.Hue) throws {
        let env = RenderEnv()
        let mask = try coverageMask(Glyph(fill: .hollow, shape: .circle, pips: .one, hue: hue),
                                    side: Self.side, env: env)
        let measured = mask.indexRegionStatistics(side: Self.side, env: env).extentAlongAxis
        #expect(isApproximatelyEqual(measured, C.Glyph.indexLength(side: Self.side, in: env),
                                     absoluteTolerance: 1.5))
    }

    /// Glyphs never mirror. The renderer takes no layout direction at all, so the proof is
    /// that the raster is IDENTICAL under both — which is a stronger statement than "we
    /// did not mirror it" and catches a mirroring `Canvas` host as well.
    @Test("A glyph renders bit-identically under RTL", arguments: Glyph.Hue.allCases)
    func aGlyphRendersBitIdenticallyUnderRTL(hue: Glyph.Hue) throws {
        let env = RenderEnv()
        let glyph = Glyph(fill: .striped, shape: .triangle, pips: .three, hue: hue)
        let ltr = try coverageMask(glyph, side: Self.side, env: env, layout: .leftToRight)
        let rtl = try coverageMask(glyph, side: Self.side, env: env, layout: .rightToLeft)
        #expect(ltr.samples == rtl.samples)
    }

    /// `teal` and `rose` are eight greyscale levels apart and are separated ENTIRELY by
    /// 45° against 135°. This is the pair the whole colourblind case is argued over.
    @Test("Teal and rose are separated by a 90° rotation")
    func tealAndRoseAreSeparatedByA90DegreeRotation() throws {
        let env = RenderEnv()
        func axis(_ hue: Glyph.Hue) throws -> Double {
            try coverageMask(Glyph(fill: .hollow, shape: .circle, pips: .one, hue: hue),
                             side: Self.side, env: env)
                .indexRegionStatistics(side: Self.side, env: env).axisDegrees
        }
        let separation = try axis(.rose) - axis(.teal)
        #expect(isApproximatelyEqual(separation, 90, absoluteTolerance: 3))
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter GlyphGeometryTests
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/GlyphIndexStrokeTests
```

Failures must be missing `C.Glyph.indexLength` / `indexStroke` / `indexCentreOffset`, a missing index pass, and a missing `indexRegionStatistics`.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift` — `indexPath(bodyCentre:)`, `indexRotation(_:)`, and the index stroke as the last draw call |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `indexCentreOffset(side:)`, `indexLength(side:in:)`, `indexStroke(in:)` |
| modify | `Modules/Tests/HunchUITests/Support/CoverageMask.swift` — add `indexRegionStatistics(side:env:)` |
| create | `Modules/Tests/HunchUITests/GlyphIndexStrokeTests.swift` |
| modify | `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift` |

## Implementation notes

### The three members

```swift
/// Signed y offset of the index register from the box centre. §13.5's `−0.43·S`, negated
/// into the screen frame (DECISIONS.md, "The screen-frame reading of §13.5").
public static func indexCentreOffset(side S: Double) -> Double { 0.43 * S }

/// High Contrast **substitutes** the longer stroke; it is never also scaled.
public static func indexLength(side S: Double, in env: RenderEnv) -> Double {
    (env.theme == .highContrast ? 0.409 : 0.273) * S
}

/// Never `bodySm`: the hue channel is the heaviest non-colour mark on the glyph.
public static func indexStroke(in env: RenderEnv) -> Double { env.weight(.body) }
```

At S = 44 those lengths are exactly canon's **12 pt / 18 pt**; at S = 96, 26.2 / 39.3 pt. Do not write either pair down anywhere: they are `0.273 · S` and `0.409 · S` evaluated, and §13.11 quotes the 12 → 18 step as an illustration of the ratio, not as a second definition.

### The path

The index register is positioned from the **box** centre, not from `bodyCentre` — a detail that is easy to lose because every other register is positioned from `bodyCentre`:

```swift
private func indexPath(bodyCentre: CGPoint) -> Path {
    let centre = CGPoint(
        x: bodyCentre.x,
        y: bodyCentre.y - C.Glyph.centreOffset(side: side) + C.Glyph.indexCentreOffset(side: side))
    let theta = Self.indexRotation(glyph.hue) * .pi / 180
    let half = C.Glyph.indexLength(side: side, in: env) / 2
    let delta = CGPoint(x: cos(theta) * half, y: sin(theta) * half)
    var path = Path()
    path.move(to: CGPoint(x: centre.x - delta.x, y: centre.y - delta.y))
    path.addLine(to: CGPoint(x: centre.x + delta.x, y: centre.y + delta.y))
    return path
}

private static func indexRotation(_ hue: Glyph.Hue) -> Double {
    switch hue {
    case .amber: 0
    case .teal: 45
    case .frost: 90
    case .rose: 135
    }
}
```

Stroked with `StrokeStyle(lineWidth: C.Glyph.indexStroke(in: env), lineCap: .butt)`. **Butt, never round.** Round caps add `indexWeight` to the diagonal rotations and nothing to 0° and 90°, which would make the stroke's *length* a fifth channel — and the raster test above is the one that catches it, because it measures extent along the axis against `indexLength`.

### It is drawn last, and it is never knocked out

The index stroke and the S pip node touch: on `circle` and `hexagon` — the two shapes that put their S node at full `R` — `frost`'s upper tip sits `0.0235·S` from the node centre, which at S = 44 is **1.82 pt against a `pipRadius` of 3.0: inside the disc**. `teal` and `rose` reach inside the knockout ring at S ≤ 44.

So the order is: pass D's `ground` knockout ring, then the pip discs, **then** the index stroke. Drawing the stroke earlier lets the ring bite a notch out of the hue channel on a quarter of the deck, in the one register the colourblind case rests on. T02 wrote the comment; this task adds the call at the end of `draw`; T05 asserts the order with a raster test.

### Three properties, each easy to lose

1. **It never thins with the silhouette.** At S < 48 the body drops to `weight.bodySm` and the index stroke stays at `weight.body`, making it the heaviest non-colour mark on the glyph — deliberately, because it *is* the hue channel.
2. **Butt caps, so a 45° stroke has an honest length.**
3. **A 135° sweep, not a cycle.** 0 → 45 → 90 → 135 is a total order the eye can rank. This is also why RTL mirrors layout and never mirrors a glyph: mirroring would map 45° to 135° and swap `teal` and `rose` in Arabic — a change of game state, not of reading direction.

### High Contrast, and the bleed it creates

`0.409 · S` is a substitution in the token resolution order: it **terminates** resolution and is never scaled by Bold Text nor offset by `Prim.highContrastStrokeOffset`. That offset applies to the *weight*, which is a different axis.

The consequence is a layout fact T05 must handle and this task must not hide: under High Contrast `frost` needs `0.1345·S` of vertical bleed — 12.9 pt at the throat against a flat `0.08·S`'s 7.7, and 29.6 against 17.6 at the Codex hero. **Clipping the tip of the hue channel under the setting that exists to make the hue channel readable is the worst version of this bug.** T05 ships `C.Glyph.bleed(side:in:)`; until then, do not add a `.frame` or a `.clipped()` anywhere on the path from a host to the `Canvas`.

### `indexRegionStatistics` — the test helper

```swift
struct IndexRegionStatistics {
    /// Principal axis of the inked pixels inside the index register, in degrees,
    /// normalised to [0, 180). Computed from the second moments, so it is robust to
    /// antialiasing and to a stroke width change.
    let axisDegrees: Double
    /// Tip-to-tip inked extent along that axis, in points. Equals `indexLength` under
    /// butt caps and `indexLength + indexWeight` under round ones.
    let extentAlongAxis: Double
}

func indexRegionStatistics(side: Double, env: RenderEnv) -> IndexRegionStatistics
```

The region is the horizontal band around `C.Glyph.indexCentreOffset(side:)` of half-height `indexLength/2 + indexStroke`, which contains the whole index register and no part of the silhouette — the registers are spatially disjoint by construction, and if this band ever picks up silhouette ink, that is a §2 violation and the test should fail loudly rather than be widened.

Second moments: accumulate `Σw`, `Σw·x`, `Σw·y`, `Σw·x²`, `Σw·xy`, `Σw·y²` over the band with `w = coverage`, then `axis = 0.5 · atan2(2·μxy, μxx − μyy)`. Normalise into `[0, 180)` and remember the screen frame is y-down, so a **positive** angle here corresponds to §13.5's clockwise-from-East convention and needs no sign flip.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GlyphGeometryTests` green, including the three new index cases.
- [ ] `xcodebuild test … -only-testing:HunchUITests/GlyphIndexStrokeTests` green: measured axis within 2° of 0 / 45 / 90 / 135 for the four hues at 96 pt.
- [ ] The measured tip-to-tip extent equals `C.Glyph.indexLength(side:in:)` within 1.5 pt for **all four** rotations — the butt-cap proof.
- [ ] `ltr.samples == rtl.samples` for all four hues on a striped triangle with three pips — the whole glyph is bit-identical under RTL.
- [ ] `grep -n 'lineCap' Modules/Sources/HunchUI/GlyphCanvas.swift` shows `.butt` on the index stroke and nowhere `.round` on glyph geometry.
- [ ] `C.Glyph.indexLength(side: 44, in: RenderEnv(theme: .highContrast, isBoldTextEnabled: true))` equals the value without Bold Text — the substitution terminates resolution.
- [ ] `bash Scripts/check-source-hygiene.sh` passes.
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T04: the index stroke — four rotations, butt caps, HC substitutes the length"`

## Out of scope

- **The draw-order assertion** (knockout before the stroke) — T05, where both passes coexist in one ordered draw list.
- **`C.Glyph.bleed(side:in:)` and any layout that pads for the stroke** — T05.
- **Pass B's widened index stroke** — T05. The halo re-strokes the body outline and the index stroke only, at ×3.
- **The greyscale separation measurement that puts `teal ↔ rose` third among hue pairs at 53.46 pt²** — T06.
- **The rest of the High Contrast theme** — E19·T09: the 9.7 : 1 audit, unlit cells 25 → 40 %, the hatch 1 → 2 pt, shader off. This task ships only the glyph's two High Contrast facts (hue → `stroke.primary`, already in `Palette`; and the length substitution, here).
- **Chrome mirroring under RTL and the locale override** — E18·T05–T06.
