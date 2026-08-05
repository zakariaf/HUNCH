# T09 — The High Contrast theme

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | High Contrast theme (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**. `references/palette.md` owns the three-theme colour table, the measured High Contrast floors and the nine cells where canon's stated ratios disagree with the arithmetic; `references/render-env.md` §2 owns **substitution beats modification** — a High Contrast value terminates resolution and is never also scaled by Bold Text. `scripts/contrast.swift` recomputes every ratio from the hex. |
| `hunch-glyph-renderer` | Owns the index stroke and the greyscale distinctness proof. Under High Contrast all four hues collapse to one ink, so the index stroke's rotation carries the **entire** hue channel alone — which is why §13.11 lengthens it here, and why `references/triple-encoding-proof.md`'s harness has to be re-run in this theme rather than assumed to transfer. |
| `hunch-accessibility` | `references/environment-settings.md` §6 owns the consequence this task must not break: **any surface that draws a glyph without its index stroke is 4× ambiguous under High Contrast.** There is no such surface today and there must not be one. |

## Objective

At the end of this task High Contrast is a fully realised theme rather than a palette swap: all four
hues render as `stroke.primary`, the index stroke lengthens from `0.273·S` to `0.409·S`, the shader is
off, every stroke takes its +0.5 pt offset, and unlit ramp cells sit at 40 % under a 2 pt cancel hatch.
Every state-bearing token clears its floor, the primary pair clears 21 : 1, and **all 256 glyphs are
still pairwise distinguishable** with the hue channel carried by rotation alone.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.11 (High Contrast theme) | all four `hue.*` render as `stroke.primary`; the index stroke goes `0.273·S` → `0.409·S`; shader off; all stroke weights +0.5 pt; unlit ramp cells 25 % → 40 % and their diagonal cancel hatch 1.0 → 2.0 pt; every token clears 9.7 : 1 and the primary pair clears 21 : 1 |
| `GAME_DESIGN.md` | §13.2 | the palette, the Okabe–Ito subset used verbatim, and the note that High Contrast drops all four hues to the foreground stroke colour and doubles the index stroke — *the game remains fully playable with hue rendered in one colour* |
| `GAME_DESIGN.md` | §2 | hue's non-colour encoding **is** the index stroke rotating 0° → 45° → 90° → 135°; colour is the redundant copy |
| `GAME_DESIGN.md` | §12.6 (DISPLAY · Theme) | High Contrast is a *theme*, one of four segmented values, and there is deliberately no separate toggle; it is forced on when `isDarkerSystemColorsEnabled` and the player has made no explicit choice |
| `GAME_DESIGN.md` | §13.5.1 | the triple-encoding proof and the pairwise greyscale distinctness this task re-runs in a third theme |
| `GAME_DESIGN.md` | §13.12 gate 10 | High Contrast on: every foreground/background pair clears the floor, hue is index-stroke-only, all 256 glyphs remain distinguishable |
| `.claude/skills/hunch-design-tokens/references/palette.md` | §1, §2 | the measured High Contrast column and the state-bearing set's real floor of 9.68, which is what §13.11's "9.7 : 1" is rounding |
| `.claude/skills/hunch-design-tokens/references/render-env.md` | §2 | the substitution table: `hue.*` → `stroke.primary`, unlit cell 0.40, hatch 2.0, index stroke `0.409·S` — each terminating resolution |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/HighContrastTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI

@Suite("The High Contrast theme — §13.11, §13.12 gate 10", .tags(.unit, .presubmission))
struct HighContrastTests {

    private let hc = RenderEnv(theme: .highContrast)
    private let palette = Palette(theme: .highContrast)

    // MARK: the hue collapse

    @Test("all four hues render as stroke.primary, and only under High Contrast",
          arguments: RenderEnv.Theme.allCases)
    func hueCollapsesUnderHighContrastOnly(_ theme: RenderEnv.Theme) {
        let p = Palette(theme: theme)
        for hue in HueColor.allCases {
            if theme == .highContrast {
                #expect(p.hue(hue).rgb == p.stroke.primary)
            } else {
                #expect(p.hue(hue).rgb != p.stroke.primary)
            }
        }
    }

    @Test("with hue collapsed, the index stroke carries the whole channel — so it lengthens")
    func indexStrokeLengthens() {
        #expect(C.Glyph.indexStrokeLength(in: RenderEnv()) == 0.273 * C.Glyph.boxSide)
        #expect(C.Glyph.indexStrokeLength(in: hc) == 0.409 * C.Glyph.boxSide)
    }

    @Test("the index stroke's four rotations are unchanged — length is what moves, not angle")
    func indexStrokeRotationsAreUntouched() {
        for hue in HueColor.allCases {
            #expect(C.Glyph.indexStrokeAngle(hue, in: hc) == C.Glyph.indexStrokeAngle(hue, in: RenderEnv()))
        }
    }

    // MARK: substitution beats modification

    @Test("a High Contrast substitution terminates resolution and is never also scaled by Bold Text")
    func substitutionsAreNotScaled() {
        let both = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        #expect(C.Ramp.unlitOpacity(in: both) == C.Ramp.unlitOpacity(in: hc))
        #expect(C.Ramp.cancelHatchWeight(in: both) == C.Ramp.cancelHatchWeight(in: hc))
        #expect(C.Glyph.indexStrokeLength(in: both) == C.Glyph.indexStrokeLength(in: hc))
    }

    @Test("the +0.5 pt offset applies to the weight axis, AFTER Bold Text's multiplier")
    func weightOffsetIsLast() {
        #expect(RenderEnv(theme: .highContrast).weight(.body) == 3.5)
        #expect(RenderEnv(theme: .highContrast, isBoldTextEnabled: true).weight(.body) == 4.25)
    }

    @Test("unlit ramp cells sit at 40 % under a 2 pt hatch")
    func unlitCellsAndHatch() {
        #expect(C.Ramp.unlitOpacity(in: hc) == 0.40)
        #expect(C.Ramp.cancelHatchWeight(in: hc) == 2.0)
    }

    @Test("the shader is off")
    func shaderIsOff() { #expect(hc.isShaderEnabled == false) }

    @Test("bloom is off, because a halo on a maximum-contrast stroke is noise")
    func bloomIsOff() {
        #expect(hc.isBloomEnabled == false)
        #expect(hc.isBloomBedEnabled == false)
    }

    // MARK: the contrast floors — gate 10, first half

    @Test("every state-bearing token clears the floor", arguments: Palette.stateBearingTokens)
    func stateBearingTokensClearTheFloor(_ token: PaletteToken) {
        let ratio = contrastRatio(palette.color(token), palette.ground.base)
        #expect(ratio >= 9.68, "\(token) is \(String(format: "%.2f", ratio)) : 1")
    }

    @Test("the primary pair clears 21 : 1")
    func primaryPairIsMaximal() {
        #expect(isApproximatelyEqual(contrastRatio(palette.stroke.primary, palette.ground.base),
                                     21.0, absoluteTolerance: 0.01))
    }

    @Test("the two tokens below the floor are the two that are declared not state-bearing")
    func theTwoDeliberateExceptions() {
        let below = PaletteToken.allCases.filter {
            contrastRatio(palette.color($0), palette.ground.base) < 9.68
        }
        #expect(Set(below) == [.strokeHairline, .accentBrassPress, .accentColdPress])
        #expect(below.allSatisfy { !$0.isStateBearing })
    }

    // MARK: no glyph without its index stroke

    @Test("every glyph-drawing call path draws the index stroke — a glyph without it is 4× ambiguous here")
    func noGlyphIsDrawnWithoutItsIndexStroke() {
        for regime in GlyphSizeRegime.allCases {
            #expect(GlyphCanvas.passes(for: regime, in: hc).contains(.indexStroke))
        }
    }
}
```

Create `Modules/Tests/HunchUITests/HighContrastDistinctnessTests.swift` — **gate 10, second half**,
re-running E04·T06's harness in the third theme:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI

@Suite("All 256 glyphs stay distinguishable under High Contrast — §13.12 gate 10",
       .tags(.snapshot, .nightly))
struct HighContrastDistinctnessTests {

    @Test("pairwise greyscale L1 distance clears T with all four hues collapsed to one ink")
    func pairwiseDistinctUnderHighContrast() throws {
        let rasters = try Deck.all.map {
            try GlyphRaster.render($0, side: 44, scale: 2, env: RenderEnv(theme: .highContrast))
                .greyscale8Bit()
        }
        var worst = (a: 0, b: 0, distance: Int.max)
        for i in 0..<rasters.count {
            for j in (i + 1)..<rasters.count {
                let d = rasters[i].l1Distance(to: rasters[j])
                if d < worst.distance { worst = (i, j, d) }
            }
        }
        #expect(worst.distance >= GlyphRaster.separationThreshold,
                "closest pair is \(Deck.all[worst.a]) vs \(Deck.all[worst.b]) at L1 \(worst.distance)")
    }

    @Test("the closest pair under High Contrast differs only in hue, and the index stroke is what separates it")
    func hueOnlyPairsAreSeparatedByRotation() throws {
        let base = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .teal)
        let rose = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .rose)   // 45° vs 135°
        let a = try GlyphRaster.render(base, side: 44, scale: 2, env: RenderEnv(theme: .highContrast)).greyscale8Bit()
        let b = try GlyphRaster.render(rose, side: 44, scale: 2, env: RenderEnv(theme: .highContrast)).greyscale8Bit()
        #expect(a.l1Distance(to: b) >= GlyphRaster.separationThreshold)
    }
}
```

**Step 2 — run it and watch it fail.**

```
swift test --package-path Modules --filter HighContrastTests
swift test --package-path Modules --filter HighContrastDistinctnessTests
```

Missing `Palette.stateBearingTokens`, `C.Glyph.indexStrokeLength(in:)`, `C.Ramp.unlitOpacity(in:)`,
`GlyphCanvas.passes(for:in:)`. The one that must not pass accidentally is
`pairwiseDistinctUnderHighContrast`: if the renderer silently ignores `theme` it will produce the dark
rasters and pass, so **before implementing, plant a High Contrast render that drops the index stroke
and confirm the test goes red** — that failure is the entire reason the test exists.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Tokens/Palette.swift` — the High Contrast column, `stateBearingTokens`, `isStateBearing` |
| modify | `HunchCore/Sources/Tokens/C.swift` — the four substitutions: index-stroke length, unlit opacity, hatch weight, and the hue → `stroke.primary` mapping |
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift` — the index stroke's High Contrast length; bloom and shader gated by the existing predicates |
| modify | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — unlit cells and the cancel hatch |
| modify | `Modules/Sources/HunchUI/SnapshotGallery.swift` — the High Contrast column is already there (E04·T09); confirm it renders the lengthened stroke |
| create | `Modules/Tests/HunchUITests/HighContrastTests.swift` |
| create | `Modules/Tests/HunchUITests/HighContrastDistinctnessTests.swift` |
| modify | `Nightly.xctestplan` — include the distinctness suite |
| modify | `tests.json` — the gate-10 entry |
| modify | `DECISIONS.md` — the 9.68 floor against §13.11's stated 9.7, if not already recorded by E03·T05 |

## Implementation notes

### The whole theme in five substitutions

Every one of these **terminates resolution**. A High Contrast value is never also scaled by Bold Text
and never also offset — that is `render-env.md` §2's *substitution beats modification*, and
`substitutionsAreNotScaled` is the test that keeps it true:

| Substitution | Becomes | Not |
|---|---|---|
| `hue.*` | `stroke.primary` | a re-lit hue |
| index-stroke length | `0.409 · S` | `0.273 · S` × anything |
| unlit ramp cell ink | 0.40 | 0.25 + anything |
| cancel hatch weight | 2.0 pt | 1.0 + 0.5, or 2.0 + 0.5 |
| the shader | off | dimmed |

The **one** thing that is an offset rather than a substitution is the stroke weight: `+0.5 pt`, flat,
applied on the weight axis *after* Bold Text's multiplier. `weight.body` with both on is
`3.0 × 1.25 + 0.5 = 4.25`, not `(3.0 + 0.5) × 1.25 = 4.375`. E03·T05 already asserts that arithmetic;
`weightOffsetIsLast` asserts it survives contact with this theme.

### Why the index stroke lengthens, and the rule that follows

All four hues collapse to the primary stroke colour, so **the hue channel is carried by index-stroke
rotation alone.** Every other channel — fill texture, silhouette, pip count — is untouched. That makes
the index stroke load-bearing in a way it is not in the other two themes, and it is why §13.11
lengthens it here rather than leaving it alone.

The rule that follows, and it is a standing constraint on all future work: **any surface that draws a
glyph without its index stroke is 4× ambiguous under High Contrast.** There is no such surface today
and there must not be one. If a size is ever too small for the index stroke, it is too small for a
glyph, and the right answer is a different mark, not a truncated one.
`noGlyphIsDrawnWithoutItsIndexStroke` walks every size regime and asserts the pass is present in each.

Note what does **not** change: the four rotations. 0° / 45° / 90° / 135° are game state — mirroring or
re-mapping them swaps `teal` and `rose`, which is a two-hue data corruption dressed as a rendering
choice, and it is the same reason §12.8 forbids mirroring the index stroke under RTL.

### The contrast floor, measured rather than stated

The state-bearing set is `{stroke.primary, stroke.secondary, accent.brass, accent.cold, hue.*}` and its
real minimum is **9.68 : 1**, which is what §13.11's "clears 9.7 : 1" is rounding. Two tokens sit below
that floor **deliberately**, and the test names them rather than excluding them silently:

- `stroke.hairline` — declared never state-bearing (a heavier line always means state, so a hairline
  never does);
- `accent.brassPress` and `accent.coldPress` — a press state is a transient echo of a control that
  already cleared the floor at rest.

Every ratio is **recomputed from the hex by WCAG 2.1 relative luminance**, never quoted from §13.2:
nine cells of canon's ratio column disagree with the arithmetic, every hex is right, and no design
consequence follows from any of them — which is exactly why nobody would catch them by eye.
`hunch-design-tokens/scripts/contrast.swift` is the reference implementation and E03·T05 already ships
the assertion; this task extends it to the High Contrast column and to gate 10's wording.

### Re-running the distinctness harness

E04·T06 rendered all 256 at 44 pt @2×, converted to 8-bit luminance, asserted pairwise L1 ≥ `T`, and
**determined and recorded `T`** in `DECISIONS.md`. That proof was run in the dark theme, where hue
contributes real luminance separation. Under High Contrast it does not — so the proof does not
transfer and has to be re-run, not assumed.

The interesting pairs are the ones differing **only in hue**: under High Contrast their bodies, fills
and pips are pixel-identical and the entire L1 distance comes from a rotated line segment.
`hueOnlyPairsAreSeparatedByRotation` tests the worst of them explicitly (45° against 135°, `teal`
against `rose` — the pair that is already luminance-adjacent in the dark theme) so that a failure names
the mechanism rather than a glyph id.

This suite renders 256 rasters and does 32,640 comparisons, so it is `.snapshot .nightly`, not
presubmission — the fast suite's 10-second budget is not the place for it, and gate 10 is a
pre-release gate.

### High Contrast is a theme, not a toggle

§12.6 makes Theme a four-value segmented control with deliberately **no separate High Contrast
switch**, because two controls for one state is how they get out of sync. It is forced on when
`isDarkerSystemColorsEnabled` is true *and* the player has made no explicit choice — and that flag is
not in SwiftUI's environment, so it needs a notification observer at the composition root
(`UIAccessibility.darkerSystemColorsStatusDidChangeNotification`). E17·T06 ships the Settings row and
E03·T03 ships `ThemePreference.theme(colorScheme:isDarkerSystemColorsEnabled:)`; this task only has to
not re-derive either.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter HighContrastTests` green, all eleven tests.
- [ ] `swift test --package-path Modules --filter HighContrastDistinctnessTests` green over all 32,640 pairs, and the failure message names the closest pair.
- [ ] Every state-bearing token measures ≥ 9.68 : 1 against `ground.base`, recomputed from the hex; the primary pair measures 21.00 : 1 to 2 dp.
- [ ] Exactly three tokens sit below the floor, and each has `isStateBearing == false`.
- [ ] `C.Glyph.indexStrokeLength(in:)` returns `0.409 · S` under High Contrast and is **not** further scaled with Bold Text also on.
- [ ] `RenderEnv(theme: .highContrast, isBoldTextEnabled: true).weight(.body) == 4.25`.
- [ ] `GlyphCanvas.passes(for:in:)` contains `.indexStroke` for every size regime under High Contrast.
- [ ] The snapshot gallery's High Contrast column shows the lengthened index stroke and the 2 pt hatch.
- [ ] `tests.json` carries the gate-10 entry, `source: "§13.12 gate 10"`, with both commands.
- [ ] The fast suite is still under 10 s (the distinctness suite is nightly and does not count against it).

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T09: the High Contrast theme, with hue carried by rotation alone"`

## Out of scope

- The palette's hex values, the three-theme table and `check-tokens.swift` — **E03·T01/T05**.
- The greyscale distinctness harness, `GlyphRaster`, and the determination of `T` — **E04·T06**; this task re-runs it in a third theme.
- The index stroke's drawing and its four rotations — **E04·T04**.
- The Theme Settings row and the darker-system-colours observer — **E17·T06**, **E10·T01**.
- Bold Text, Reduce Transparency and Differentiate Without Colour — **T08**; they compose with this theme but are not it.
- The shader itself — **E20·T07**.
