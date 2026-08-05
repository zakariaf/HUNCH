# T03 — `RenderEnv` and the resolution order

| | |
|---|---|
| **Epic** | E03 — Design tokens and RenderEnv |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 *Palette tokens* · *Dynamic Type* (the `artScale` ceiling only) · *System settings* (the axes and predicates only) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | It owns the resolution order outright — the GDD never states it, and `references/render-env.md` §2 is the ruling with its three reasons. `references/render-env.md` §§1, 3 are the seven axes and the nine derived predicates; `references/dimensions-strokes-opacity.md` §2 is the resolved 5 × 4 matrix, every cell computed. This is the one task in the epic where getting an *order* wrong produces plausible-looking numbers. |
| `hunch-swift-code` | The extension shape (`W7`: no access level on an extension, members carry it), `05 R8`'s explicit isolation on anything visible outside its file, and the ruling that nothing in `HunchCore` is a class — `RenderEnv` is a value and there is no `.current`. |

## Objective

`RenderEnv` stops being a record and becomes the axis every token resolves against: `env.weight(_:)`,
`env.type(_:)`, `env.palette`, `env.artScale` and nine derived predicates, all pure functions of the
seven fields. The resolution order the GDD leaves open is decided and asserted — Bold Text
multiplies ×1.25 first, High Contrast adds a flat +0.5 pt last, so `weight.body` under both is
**4.25** and never 4.375 — and Dynamic Type is kept out of that chain entirely, clamped at 1.35 and
applied only to lengths.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.11 | the five accessibility settings and their concrete deltas: Reduce Transparency (shader off, bloom off, flat 0.85 α scrim), Bold Text (×1.25 strokes, +1 type notch), Differentiate Without Colour (adds geometry, moves no token), High Contrast (+0.5 pt, hue substitution, shader off), the 1.35× (AX2) art ceiling |
| `GAME_DESIGN.md` | §13.5, §13.6 | what the bloom and shader predicates gate: the widened stroke, the per-region blur layer, `amt` and `t` |
| `GAME_DESIGN.md` | §13.4 | `minimumScaleFactor` is 1.0 everywhere — the reason `artScale` never touches text |
| `design/DESIGN-SYSTEM-SCOPE.md` | §2(d), §4.3 | the gap this task closes, and the multiply-then-add ruling `3.0 → 3.75 → 4.25` |
| `hunch-design-tokens/references/render-env.md` | §1, §2, §3, §6 | the seven axes and why the eighth is not added; the four resolution stages; the predicate table; what `RenderEnv` is not |
| `hunch-design-tokens/references/dimensions-strokes-opacity.md` | §2 | the resolved matrix — twenty values, all exact in binary, plus the two stage-4 derived rules |
| `hunch-design-tokens/references/light-theme.md` | §3, §4 | why `isImpressionDepthEnabled` and `isBloomBedEnabled`/`isScanlineEnabled` are predicates rather than `theme ==` at a call site |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | `A29` | injected, never global: there is no `RenderEnv.current`, and a `static var` holding one would be both a singleton and a data race |

## TDD — the test comes first

**Step 1 — write the failing tests.** One new suite plus three additions to suites T02 created.

Create `HunchCore/Tests/TokensTests/RenderEnvTests.swift`:

```swift
import Testing

import Tokens

@Suite("RenderEnv — the seven axes and the resolution order", .tags(.unit, .presubmission))
struct RenderEnvTests {

    // MARK: - the ruling

    /// The whole of §2(d). §13.11 gives Bold Text a ×1.25 and High Contrast a flat +0.5 pt and
    /// says both can be on; nothing says which happens first. Multiply, then offset.
    @Test("Bold Text multiplies before High Contrast adds")
    func boldTextMultipliesBeforeHighContrastAdds() {
        let both = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        #expect(both.weight(.body) == 4.25)
        #expect(both.weight(.body) != 4.375)
    }

    /// Every cell of `dimensions-strokes-opacity.md` §2, computed rather than estimated.
    /// All twenty values are exact in binary (1.25 = 5/4), so `==` is correct here and a
    /// tolerance would hide a real error.
    @Test("the resolved matrix is exact in all four environment states")
    func resolvedMatrixIsExact() {
        let rows: [(StrokeWeight, Double, Double, Double, Double)] = [
            (.hairline, 0.500, 0.625, 1.000, 1.125),
            (.thin, 1.000, 1.250, 1.500, 1.750),
            (.bodySm, 1.500, 1.875, 2.000, 2.375),
            (.body, 3.000, 3.750, 3.500, 4.250),
            (.heavy, 4.000, 5.000, 4.500, 5.500),
        ]
        let plain = RenderEnv()
        let bold = RenderEnv(isBoldTextEnabled: true)
        let contrast = RenderEnv(theme: .highContrast)
        let both = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)

        for (token, neither, boldOnly, contrastOnly, together) in rows {
            #expect(token.resolved(in: plain) == neither)
            #expect(token.resolved(in: bold) == boldOnly)
            #expect(token.resolved(in: contrast) == contrastOnly)
            #expect(token.resolved(in: both) == together)
        }
    }

    /// The property the order was chosen to preserve. A scale that stopped ascending in one
    /// environment would stop being a scale.
    @Test("the ladder ascends in every environment state")
    func ladderStaysALadder() {
        let environments = [
            RenderEnv(),
            RenderEnv(isBoldTextEnabled: true),
            RenderEnv(theme: .highContrast),
            RenderEnv(theme: .highContrast, isBoldTextEnabled: true),
        ]
        for env in environments {
            let ladder = [StrokeWeight.hairline, .thin, .bodySm, .body, .heavy]
                .map { env.weight($0) }
            #expect(ladder == ladder.sorted())
        }
    }

    /// Eligibility is a property of the token and applies to stage 2 only. High Contrast's flat
    /// offset applies to every weight, opted out or not.
    @Test("respondsToBoldText gates the scale, never the offset")
    func optOutSkipsScaleButNotOffset() {
        let fixed = StrokeWeight(base: 1.0, respondsToBoldText: false)
        #expect(fixed.resolved(in: RenderEnv(isBoldTextEnabled: true)) == 1.0)
        #expect(fixed.resolved(in: RenderEnv(theme: .highContrast)) == 1.5)
        #expect(fixed.resolved(in: RenderEnv(theme: .highContrast, isBoldTextEnabled: true)) == 1.5)
    }

    // MARK: - Dynamic Type is not in the chain

    @Test("artScale clamps to 1.0 … 1.35 and never reaches a stroke weight")
    func dynamicTypeStaysOutOfTheWeightChain() {
        let ax5 = RenderEnv(typeMultiplier: 3.1)
        #expect(ax5.artScale == 1.35)
        #expect(ax5.weight(.body) == 3.0)

        let small = RenderEnv(typeMultiplier: 0.8)
        #expect(small.artScale == 1.0)

        #expect(RenderEnv(typeMultiplier: 1.2).artScale == 1.2)
    }

    // MARK: - type

    @Test("Bold Text steps the type weight one notch and changes nothing else")
    func typeStepsWeightOnly() {
        let bold = RenderEnv(isBoldTextEnabled: true)
        let resolved = bold.type(.body)
        #expect(resolved.weight == .medium)
        #expect(resolved.size == TypeRole.body.size)
        #expect(resolved.width == TypeRole.body.width)
        #expect(resolved.trackingEm == TypeRole.body.trackingEm)
        #expect(resolved.face == TypeRole.body.face)
        #expect(resolved.textStyle == TypeRole.body.textStyle)
        #expect(resolved.isUppercased == TypeRole.body.isUppercased)

        #expect(bold.type(.display).weight == .bold)
        #expect(bold.type(.section).weight == .semibold)
        #expect(RenderEnv().type(.body).weight == TypeRole.body.weight)
    }

    // MARK: - the derived predicates

    @Test("bloom and the shader are off under Reduce Transparency, High Contrast and Low Power",
          arguments: RenderEnv.Theme.allCases)
    func passesAreGated(theme: RenderEnv.Theme) {
        let plain = RenderEnv(theme: theme)
        #expect(plain.isBloomEnabled == (theme != .highContrast))
        #expect(plain.isShaderEnabled == (theme != .highContrast))

        for env in [RenderEnv(theme: theme, isReduceTransparencyEnabled: true),
                    RenderEnv(theme: theme, isLowPowerModeEnabled: true)] {
            #expect(!env.isBloomEnabled)
            #expect(!env.isShaderEnabled)
            #expect(!env.isBloomBedEnabled)
            #expect(!env.isScanlineEnabled)
        }
    }

    /// Pass A and the scanline are dark-only: a blurred bright mark on a bright ground reads as
    /// a printing fault, and a scanline is a CRT artefact that paper does not have.
    @Test("the bed and the scanline are dark-only; the impression is light-only")
    func depthModelIsPerTheme() {
        #expect(RenderEnv(theme: .dark).isBloomBedEnabled)
        #expect(RenderEnv(theme: .dark).isScanlineEnabled)
        #expect(!RenderEnv(theme: .dark).isImpressionDepthEnabled)

        #expect(RenderEnv(theme: .light).isBloomEnabled)
        #expect(!RenderEnv(theme: .light).isBloomBedEnabled)
        #expect(!RenderEnv(theme: .light).isScanlineEnabled)
        #expect(RenderEnv(theme: .light).isImpressionDepthEnabled)

        #expect(!RenderEnv(theme: .highContrast).isBloomBedEnabled)
        #expect(!RenderEnv(theme: .highContrast).isImpressionDepthEnabled)
    }

    @Test("Reduce Motion freezes the shader clock and moves nothing else")
    func reduceMotionFreezesShaderTime() {
        let reduced = RenderEnv(isReduceMotionEnabled: true)
        #expect(reduced.isShaderTimeFrozen)
        #expect(reduced.isShaderEnabled)
        #expect(reduced.weight(.body) == RenderEnv().weight(.body))
    }

    /// The axis that moves no value. It is in the record because the component skills need it and
    /// because a seven-axis record that silently dropped one would be the failure this design
    /// exists to prevent.
    @Test("Differentiate Without Colour changes no token")
    func differentiateWithoutColourMovesNoValue() {
        let plain = RenderEnv()
        let differentiated = RenderEnv(isDifferentiateWithoutColorEnabled: true)
        #expect(differentiated.weight(.body) == plain.weight(.body))
        #expect(differentiated.palette == plain.palette)
        #expect(differentiated.artScale == plain.artScale)
    }

    @Test("palette is the only way to read a colour and follows the theme",
          arguments: RenderEnv.Theme.allCases)
    func paletteFollowsTheme(theme: RenderEnv.Theme) {
        #expect(RenderEnv(theme: theme).palette == Palette(theme: theme))
    }

    @Test("a default RenderEnv is the dark theme with nothing enabled")
    func defaultsAreTheShippedNormalCase() {
        let env = RenderEnv()
        #expect(env.theme == .dark)
        #expect(!env.isReduceMotionEnabled)
        #expect(!env.isReduceTransparencyEnabled)
        #expect(!env.isBoldTextEnabled)
        #expect(!env.isDifferentiateWithoutColorEnabled)
        #expect(!env.isLowPowerModeEnabled)
        #expect(env.typeMultiplier == 1.0)
    }
}
```

Add to `HunchCore/Tests/TokensTests/SpaceTests.swift`:

```swift
    /// §13.11: the Bench scrim goes from a 0.6 α blur to a flat 0.85 α ground. The token is a
    /// function of the environment because High Contrast and Reduce Transparency *substitute*
    /// an opacity — there is no multiplicative axis on ink.
    @Test("the scrim follows Reduce Transparency")
    func scrimFollowsReduceTransparency() {
        #expect(Opacity.scrim(in: RenderEnv()) == Opacity.scrimBlurred)
        #expect(Opacity.scrim(in: RenderEnv(isReduceTransparencyEnabled: true)) == Opacity.scrimFlat)
    }
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter RenderEnvTests`.
The first failure must be `value of type 'RenderEnv' has no member 'weight'`. Then, once
`resolved(in:)` exists but before the order is right, deliberately write the *wrong* order once —
`(base + offset) * scale` — and confirm the suite reports `4.375` against an expected `4.25`. That
single observation is the whole point of the task: both orders compile, both look reasonable, and
only one matches §13.11's worked values.

**Step 3 — implement.** Four files touched, none created.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Tokens/RenderEnv.swift` — add `extension RenderEnv` with `artScale`, `palette`, `weight(_:)`, `type(_:)` and the six predicates |
| modify | `HunchCore/Sources/Tokens/StrokeWeight.swift` — add `resolved(in:)` |
| modify | `HunchCore/Sources/Tokens/TypeRole.swift` — add `resolved(in:)` |
| modify | `HunchCore/Sources/Tokens/Space.swift` — add `Opacity.scrim(in:)` |
| create | `HunchCore/Tests/TokensTests/RenderEnvTests.swift` |
| modify | `HunchCore/Tests/TokensTests/SpaceTests.swift` |
| modify | `DECISIONS.md` — the multiply-then-offset ruling |

## Implementation notes

**The four stages, in this order, for every token.** `render-env.md` §2 is the ruling; this is the
shape it takes in code.

```
1. SELECT   theme picks the value; every High Contrast *substitution* lands here
2. SCALE    Bold Text: strokes × 1.25 · type weights + 1 notch, clamped at bold
3. OFFSET   High Contrast: strokes + 0.5 pt, flat
4. DERIVE   geometric relationships from the already-resolved value: keyline + 1.0, halo × 3
```

Stage 4 is not a token and does not live in this task — it lives at the L2 member that needs it
(`C.Glyph.keylineStroke`, `C.Glyph.haloStroke`, T04). Stages 2 and 3 are two lines:

```swift
public func resolved(in env: RenderEnv) -> Double {
    let scaled =
        base * (env.isBoldTextEnabled && respondsToBoldText ? Prim.boldTextStrokeScale : 1)
    return scaled + (env.theme == .highContrast ? Prim.highContrastStrokeOffset : 0)
}
```

**Why multiply first — the three reasons, in decreasing force.** Write them into the doc comment;
this is the one decision in the epic that a future reader will be tempted to reverse.

1. **§13.11's worked values pin the multiplication to the base.** It states `hairline` 0.5 → 0.625
   and `bodySm` 1.5 → 1.875. Both are `base × 1.25` exactly. Adding first would give 1.25 and 2.5.
2. **A flat offset that got multiplied would stop being flat.** §13.11 says "+0.5 pt" — one number,
   for every weight. Under multiply-last it silently becomes +0.625, and the two settings stop being
   independent: turning Bold Text on would change what High Contrast means.
3. **The ladder must stay a ladder.** Both orders preserve monotonicity here, but only
   multiply-first keeps the *ratios* between adjacent weights identical under Bold Text alone,
   which is what makes the scale still read as one scale.

**Substitution beats modification, and it terminates resolution.** Where §13.11 states an explicit
High Contrast value, take it verbatim and stop — it is never *also* scaled or offset. The four in
the GDD: `hue.*` → `stroke.primary` (T02, inside `Palette.init`); unlit ramp cell ink 0.25 → **0.40**;
cancel hatch weight 1.0 → **2.0** pt; index stroke length `0.273·S` → **`0.409·S`**. The first is
already shipped; the second and third land in T04; the fourth is E04·T04's. The `+0.5` offset
applies to L1 `weight.*` only; a component weight that already has a stated High Contrast value has
been resolved by that statement.

**Dynamic Type is not in the chain.** `artScale` is `min(max(typeMultiplier, 1), Prim.artScaleCeiling)`
and it multiplies *lengths* at the drawing site — the glyph box `S`, the Assay cell, the Profile's
`R0`. It never multiplies a weight. Weight already has an axis (Bold Text), and Dynamic Type reaches
weight exactly once, through geometry: `S` selects the regime, `S < 48 → weight.bodySm`. Scaling the
weight as well would compound them and make a Bold Text player at AX2 draw a 5.5 pt stroke on a
1.35×-larger glyph — heavier twice. It also never multiplies text: every role declares `relativeTo:`
and the OS does that scaling, so applying `artScale` to a font size would scale text twice and clamp
it at 1.35 into the bargain.

**The predicates are the mechanism, not a convenience.** `render-env.md` §3 lists nine. Read them;
never re-derive one at a call site and never branch on `theme` where a predicate exists. A predicate
is what stops eight files disagreeing about what Reduce Transparency means. Two pairs are easy to
get backwards:

- `isBloomEnabled` (pass B, the widened low-opacity stroke) is on in **light**; `isBloomBedEnabled`
  (pass A, the blurred region clone — the app's only offscreen layer) is dark-only.
- `isShaderEnabled` gates §13.6's `amt`; `isScanlineEnabled` gates only the `scan` term and is
  dark-only. Grain and vignette stay in light.

The `S ≥ 32` gate on bloom is **geometry** and belongs to the glyph renderer (E04·T05). This task
ships the environment half only, and the doc comment must say so or the two halves will be
re-implemented against each other.

**Isolation and shape.** `extension RenderEnv` carries no access level (`W7`); each member is
`public`. Nothing here is `@MainActor` and nothing is a class — `RenderEnv` is a `Hashable, Sendable`
value built by the composition root and passed down (`A29`). There is no `RenderEnv.current`, no
memoised palette and no cache: `Palette(theme:)` is a handful of struct copies with no allocation,
so building one per draw is free, and a memoised one is a mutable global waiting to happen.

**Do not add an eighth axis.** Seven is the set §13.11 gives, each earning its place by moving a
value or gating a pass. Band, mode, phase, probe count and the current law are game state and are
not render environment: if a value changes during a round, it does not belong in this record.

**Record in `DECISIONS.md`:** *"Resolution order: SELECT → SCALE (Bold Text ×1.25) → OFFSET (High
Contrast +0.5 pt, flat) → DERIVE. `weight.body` under both settings is 4.25, not 4.375. §13.11's
worked values (`hairline` 0.5 → 0.625) pin the multiplication to the base; a flat offset that was
also multiplied would silently become +0.625 and the two settings would stop being independent.
Dynamic Type is outside the chain: `artScale` is clamped to 1.35 and multiplies lengths only."*

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RenderEnvTests` is green, and the suite
      contains an assertion that `env.weight(.body) != 4.375`.
- [ ] All twenty cells of `dimensions-strokes-opacity.md` §2 are asserted with `==`, not a tolerance.
- [ ] `swift test --package-path HunchCore --filter SpaceTests` is green with the scrim case added.
- [ ] `grep -n 'theme ==' HunchCore/Sources/Tokens/` shows matches only inside `Palette.swift`,
      `StrokeWeight.swift` and `RenderEnv.swift`'s own predicate definitions — no third file
      branches on the theme.
- [ ] `grep -rn 'static var\|RenderEnv.current' HunchCore/Sources/Tokens/` returns nothing.
- [ ] `swift build --package-path HunchCore --target Tokens` succeeds with no warnings.
- [ ] `DECISIONS.md` carries the resolution-order entry.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. It must not be allowed to fold `resolved(in:)` into a
   single expression that reorders the operations, nor to replace `Prim.boldTextStrokeScale` and
   `Prim.highContrastStrokeOffset` with inline literals: the L0 indirection is what keeps §13.11's
   two numbers in one place.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E03/T03: RenderEnv resolution order — multiply then offset, with artScale outside the chain"`

## Out of scope

- Every component-scoped value, including the two High Contrast substitutions named above — **T04**.
- Reading the system flags that populate the record (`\.legibilityWeight`, `@ScaledMetric`,
  `isDarkerSystemColorsEnabled`, `isLowPowerModeEnabled`) — **T06** builds `RenderEnvReader`;
  **E10·T01** wires it into the composition root.
- §13.11's per-screen Dynamic Type behaviour table — **E19·T06**. This task ships `artScale` and its
  ceiling; which screen reflows, freezes or scrolls is that task's.
- The Reduce Motion *substitution table* (which animation becomes which crossfade) — **E20·T08**.
  This task ships `isReduceMotionEnabled` and `isShaderTimeFrozen`; T02 shipped the six durations.
- Differentiate Without Colour's added geometry — ring gaps doubling, the counterexample's two dash
  patterns — **E08·T06** and **E09·T09**. The axis moves no token and that is asserted here.
