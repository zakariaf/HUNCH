# T02 — L1 semantic layer and the register types

| | |
|---|---|
| **Epic** | E03 — Design tokens and RenderEnv |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 *Palette tokens* · *Register segregation* · *Strokes, corners, grid* · *Typography* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | It owns the L1 layer outright. `references/palette.md` §1 is the ten-token × three-theme table and §4 is the register split as a type; `references/dimensions-strokes-opacity.md` §§1, 3–5 are the weights, the space scale, the radii and the opacities; `references/type-ramp.md` §1 is the seven roles; `references/durations-and-easing.md` §§2–3 are the durations and easings; `references/tokens-swift-layout.md` §3 is all five files already typechecked. |
| `hunch-swift-code` | Five new top-level types across five files, each needing the `P24`/`W13`/`W29`/`N22` calls: one type per file named for it, designated initialiser in the primary declaration so the memberwise init stays internal, a `switch` with no `default:` over the three themes, and state types nested in their owner. |

`hunch-design-tokens` is first: every value in this task has exactly one published home and this
task's only job is to transcribe it into Swift without inventing a second one.

## Objective

The whole L1 layer exists as five files in `HunchCore/Sources/Tokens/`: `Palette` selecting ten
colour tokens across three themes, `StrokeWeight` carrying five weights with their Bold Text
eligibility as metadata *on the token*, `Space`/`Radius`/`Opacity` holding the 4 pt grid and the
opacity ladder, `TypeRole` holding the seven roles with `relativeTo:` and tracking in em, and
`Dur`/`Easing` holding time. `AccentColor` and `HueColor` ship as distinct structs whose
initialisers are internal to the module, so from this commit onward handing an accent to a glyph
drawing function is a compile error and not a review note.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.2 | the ten semantic colour tokens, the three themes, the register-segregation rule, the light-theme keyline decision (†), theme selection |
| `GAME_DESIGN.md` | §13.3 | the five stroke weights and their application lists; the 4 pt grid and its nine steps; the 16 pt margin and the 343 pt column arithmetic; 2 pt chrome radius, 12 pt sheet, **zero** on glyph silhouettes; miter joins and butt caps |
| `GAME_DESIGN.md` | §13.4 | the seven type roles — size, weight, width, tracking in em, face, `relativeTo:`, and which two are uppercased |
| `GAME_DESIGN.md` | §13.7 | the motion vocabulary the `Dur`/`Easing` tables make exhaustive |
| `GAME_DESIGN.md` | §13.11 | Bold Text's ×1.25 on strokes and +1 notch on type weights; the High Contrast hue → `stroke.primary` substitution; the Reduce Transparency scrim |
| `hunch-design-tokens/references/palette.md` | §1, §4, §5, §6 | the measured table, the register types, the alias list (no alias may acquire an independent value), and theme selection |
| `hunch-design-tokens/references/dimensions-strokes-opacity.md` | §1, §3, §4, §5 | the five weights and the all-five Bold Text ruling with its two reasons; the space scale; the radii; the opacity ladder and the seven PHOSPHOR opacities that are L2 and not here |
| `hunch-design-tokens/references/type-ramp.md` | §1, §2, §4, §5 | the seven roles, the `bolder` saturation, locale-aware uppercasing, the mandatory mono numeral |
| `hunch-design-tokens/references/durations-and-easing.md` | §1, §2, §3 | `Duration` never `Double`; the seventeen durations plus six Reduce Motion substitutions; the ten easings and the single overshoot |
| `hunch-design-tokens/references/light-theme.md` | §2, §7 | why `glyphKeyline` is `nil` outside light, and the rule that **no** dimension, weight, radius, duration or easing token varies by theme |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | `W13`, `W29`, `W16`, `W18` | designated init in the primary declaration; no `default:` over an enum you own; caseless enums for constants; `let` |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | `N22` | `Palette.Ground`, `TypeRole.Weight`, `RenderEnv.Theme` are nested in their owner |

## TDD — the test comes first

**Step 1 — write the failing tests.** Five files, one per source file (`06 T5b`).

Create `HunchCore/Tests/TokensTests/PaletteTests.swift`:

```swift
import Testing

import Tokens

@Suite("Palette — L1 colour", .tags(.unit, .presubmission))
struct PaletteTests {

    @Test("each theme selects its own grounds, surfaces and strokes")
    func themeSelection() {
        let dark = Palette(theme: .dark)
        #expect(dark.ground.base == Prim.soot900)
        #expect(dark.ground.raised == Prim.soot800)
        #expect(dark.ground.sunken == Prim.soot950)
        #expect(dark.surface.cell == Prim.soot850)
        #expect(dark.surface.cellLit == Prim.soot750)
        #expect(dark.stroke.primary == Prim.bone100)
        #expect(dark.stroke.secondary == Prim.bone500)
        #expect(dark.stroke.hairline == Prim.bone700)

        let light = Palette(theme: .light)
        #expect(light.ground.base == Prim.paper200)
        #expect(light.ground.raised == Prim.paper100)
        #expect(light.ground.sunken == Prim.paper300)
        #expect(light.surface.cell == Prim.paper150)
        #expect(light.surface.cellLit == Prim.paper50)
        #expect(light.stroke.primary == Prim.bone900)
        #expect(light.stroke.secondary == Prim.bone450)
        #expect(light.stroke.hairline == Prim.bone200)

        let contrast = Palette(theme: .highContrast)
        #expect(contrast.ground.base == Prim.neutral1000)
        #expect(contrast.ground.raised == Prim.neutral900)
        #expect(contrast.ground.sunken == Prim.neutral1000)
        #expect(contrast.surface.cell == Prim.neutral1000)
        #expect(contrast.surface.cellLit == Prim.neutral850)
        #expect(contrast.stroke.primary == Prim.neutral0)
        #expect(contrast.stroke.secondary == Prim.neutral400)
        #expect(contrast.stroke.hairline == Prim.neutral600)
    }

    @Test("`bone` serves both themes — one artefact at two exposures")
    func boneCrossesThemes() {
        #expect(Palette(theme: .dark).stroke.primary == Prim.bone100)
        #expect(Palette(theme: .light).stroke.primary == Prim.bone900)
    }

    /// The one sanctioned crossing between the registers, and it lives inside `Palette.init`
    /// rather than at a call site precisely so no call site can forget it.
    @Test("hue collapses to stroke.primary under High Contrast and nowhere else",
          arguments: RenderEnv.Theme.allCases)
    func hueCollapsesOnlyUnderHighContrast(theme: RenderEnv.Theme) {
        let palette = Palette(theme: theme)
        if theme == .highContrast {
            #expect(palette.hue.ranked.allSatisfy { $0.rgb == palette.stroke.primary })
        } else {
            #expect(palette.hue.amber.rgb == Prim.okabeItoAmber)
            #expect(palette.hue.teal.rgb == Prim.okabeItoTeal)
            #expect(palette.hue.frost.rgb == Prim.okabeItoFrost)
            #expect(palette.hue.rose.rgb == Prim.okabeItoRose)
        }
    }

    /// §13.5 pins index-stroke rotation 0/45/90/135° to hue rank 1…4. `ranked` is that order
    /// and the renderer indexes into it, so a reorder here silently re-labels every glyph.
    @Test("ranked is amber, teal, frost, rose — in that order")
    func rankOrderIsPinned() {
        let palette = Palette(theme: .dark)
        #expect(palette.hue.ranked == [palette.hue.amber, palette.hue.teal,
                                       palette.hue.frost, palette.hue.rose])
        #expect(palette.hue.ranked.count == 4)
    }

    @Test("the glyph keyline exists in light only, and is stroke.primary",
          arguments: RenderEnv.Theme.allCases)
    func keylineIsLightOnly(theme: RenderEnv.Theme) throws {
        let palette = Palette(theme: theme)
        guard theme == .light else {
            #expect(palette.glyphKeyline == nil)
            return
        }
        let keyline = try #require(palette.glyphKeyline)
        #expect(keyline == palette.stroke.primary)
    }

    @Test("a palette is a value: two built from the same theme are equal")
    func paletteIsAValue() {
        #expect(Palette(theme: .dark) == Palette(theme: .dark))
        #expect(Palette(theme: .dark) != Palette(theme: .light))
    }
}
```

Create `HunchCore/Tests/TokensTests/StrokeWeightTests.swift`:

```swift
import Testing

import Tokens

@Suite("StrokeWeight — L1 weight, unresolved", .tags(.unit, .presubmission))
struct StrokeWeightTests {

    @Test("the five base weights are §13.3's ladder and it ascends")
    func baseLadder() {
        let ladder = [StrokeWeight.hairline, .thin, .bodySm, .body, .heavy].map(\.base)
        #expect(ladder == [0.5, 1.0, 1.5, 3.0, 4.0])
        #expect(ladder == ladder.sorted())
    }

    /// §13.11's prose scopes ×1.25 to "glyph and rule-tile stroke weights"; its worked examples
    /// include `hairline`, which is chrome-only. The examples are the operative version —
    /// `dimensions-strokes-opacity.md` §1 gives the two reasons. All five step, or the gap that
    /// makes the AND welded bar read heavier than a body stroke collapses to 0.25 pt.
    @Test("all five L1 weights respond to Bold Text")
    func allFiveRespondToBoldText() {
        #expect([StrokeWeight.hairline, .thin, .bodySm, .body, .heavy]
            .allSatisfy(\.respondsToBoldText))
    }

    /// The opt-out exists for L2 weights — the pip knockout ring is a 1 pt geometric separator
    /// that must stay 1 pt or it eats the pip.
    @Test("respondsToBoldText travels on the token and defaults to true")
    func eligibilityIsTokenMetadata() {
        #expect(StrokeWeight(base: 1.0).respondsToBoldText)
        #expect(!StrokeWeight(base: 1.0, respondsToBoldText: false).respondsToBoldText)
    }
}
```

Create `HunchCore/Tests/TokensTests/SpaceTests.swift`:

```swift
import Testing

import Tokens

@Suite("Space, Radius, Opacity — L1 length and ink", .tags(.unit, .presubmission))
struct SpaceTests {

    @Test("the nine-step scale is §13.3's, ascends, and is built on 4 pt")
    func gridScale() {
        // Fully qualified: `Space.s8` is a static member of `Space`, not of `Double`, so a
        // leading-dot form in an array of `Double` would not resolve.
        let scale = [
            Space.s4, Space.s8, Space.s12, Space.s16, Space.s20,
            Space.s24, Space.s32, Space.s44, Space.s64,
        ]
        #expect(scale == [4, 8, 12, 16, 20, 24, 32, 44, 64])
        #expect(scale == scale.sorted())
        #expect(scale.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
    }

    /// Named-for-value, not semantic: the scale is a grid. `space.cozy` would assign a meaning
    /// the GDD never assigned, and semantic spacing is L2.
    @Test("the named lengths are aliases of scale steps, never new values")
    func namedLengthsAreAliases() {
        #expect(Space.marginOuter == Space.s16)
        #expect(Space.ruleInset == Space.s16)
        #expect(Space.targetMin == Space.s44)
        #expect(Space.boundaryAbove == Space.s24)
        #expect(Space.boundaryBelow == Space.s16)
    }

    /// §13.3's Dial arithmetic on the 375 pt reference device, with the 1 pt rounding absorbed
    /// by the header. Asserting the sum rather than the total is what keeps the four cells and
    /// three gutters from drifting apart from the column they have to fit inside.
    @Test("the content column is the Dial's own arithmetic")
    func contentColumnIsDialArithmetic() {
        #expect(Space.columnContent == 45 + 4 * 70 + 3 * 6)
    }

    /// §13.1 makes rounding a glyph silhouette a PR-rejection offence: corner count is the
    /// `shape` channel and rounding erodes it. Here it is a test instead.
    @Test("radius: zero on glyphs, 2 pt chrome, 12 pt sheet")
    func radii() {
        #expect(Radius.glyph == 0)
        #expect(Radius.chrome == 2)
        #expect(Radius.sheet == 12)
        #expect(Radius.chrome < Radius.sheet)
    }

    @Test("the impression ladder descends, and its outer edge is opaque")
    func impressionLadder() {
        let ladder = [
            Opacity.impressionOuter, Opacity.impressionMid,
            Opacity.impressionInner, Opacity.impressionFaint,
        ]
        #expect(ladder == ladder.sorted(by: >))
        #expect(Opacity.impressionOuter == 1.0)
    }

    @Test("every opacity is a fraction")
    func opacitiesAreFractions() {
        let inks = [
            Opacity.halo, Opacity.bloomBed, Opacity.disabled, Opacity.pressed,
            Opacity.scrimFlat, Opacity.scrimBlurred, Opacity.impressionOuter,
            Opacity.impressionMid, Opacity.impressionInner, Opacity.impressionFaint,
        ]
        #expect(inks.allSatisfy { $0 > 0 && $0 <= 1 })
    }
}
```

Create `HunchCore/Tests/TokensTests/TypeRoleTests.swift`:

```swift
import Testing

import Tokens

@Suite("TypeRole — L1 type", .tags(.unit, .presubmission))
struct TypeRoleTests {

    private static let allRoles: [TypeRole] = [
        .display, .title, .section, .body, .caption, .numeral, .micro,
    ]

    @Test("there are seven roles and each declares a distinct relativeTo: style")
    func sevenRolesSevenStyles() {
        #expect(Self.allRoles.count == 7)
        #expect(Set(Self.allRoles.map(\.textStyle)).count == 7)
    }

    @Test("§13.4's sizes at Large")
    func sizes() {
        #expect(TypeRole.display.size == 28)
        #expect(TypeRole.title.size == 20)
        #expect(TypeRole.section.size == 13)
        #expect(TypeRole.body.size == 17)
        #expect(TypeRole.caption.size == 13)
        #expect(TypeRole.numeral.size == 15)
        #expect(TypeRole.micro.size == 11)
    }

    /// Mandatory wherever a value changes without a layout pass. A proportional digit that
    /// shifts a column on every probe is a bug, not a preference.
    @Test("numeral is the only mono role")
    func numeralIsTheOnlyMonoRole() {
        #expect(TypeRole.numeral.face == .mono)
        #expect(Self.allRoles.filter { $0.face == .mono } == [TypeRole.numeral])
    }

    @Test("section and micro are the only uppercased roles")
    func uppercasedRoles() {
        #expect(TypeRole.section.isUppercased)
        #expect(TypeRole.micro.isUppercased)
        #expect(Self.allRoles.filter(\.isUppercased).count == 2)
    }

    /// Tracking is stored in em and applied as `scaledSize × trackingEm`. Fixed-point tracking
    /// collapses at AX5 — `micro` at 0.16 em is 1.76 pt at Large and 4.6 pt at AX5, and freezing
    /// it turns a letterspaced head into a cramped one exactly where legibility matters most.
    @Test("tracking scales with the scaled size")
    func trackingIsRelative() {
        let atLarge = TypeRole.micro.tracking(atScaledSize: TypeRole.micro.size)
        let atAX5 = TypeRole.micro.tracking(atScaledSize: TypeRole.micro.size * 2.6)
        #expect(atLarge == TypeRole.micro.size * TypeRole.micro.trackingEm)
        #expect(atAX5 > atLarge)
        #expect(TypeRole.body.tracking(atScaledSize: 100) == 0)
    }

    /// `Weight` is Int-backed and Comparable precisely so `bolder` is one saturating
    /// expression rather than a switch that will be wrong the day a role changes weight.
    @Test("bolder steps one notch and clamps at bold")
    func bolderSaturates() {
        #expect(TypeRole.Weight.regular.bolder == .medium)
        #expect(TypeRole.Weight.medium.bolder == .semibold)
        #expect(TypeRole.Weight.semibold.bolder == .bold)
        #expect(TypeRole.Weight.bold.bolder == .bold)
        #expect(TypeRole.Weight.regular < TypeRole.Weight.bold)
    }
}
```

Create `HunchCore/Tests/TokensTests/MotionTests.swift`:

```swift
import Testing

import Tokens

@Suite("Dur, Easing — L1 time", .tags(.unit, .presubmission))
struct MotionTests {

    @Test("durations are Duration values, not ambiguous numbers")
    func durationsAreTyped() {
        #expect(Dur.admit == .milliseconds(260))
        #expect(Dur.reject == .milliseconds(250))
        #expect(Dur.reveal == .milliseconds(1840))
        #expect(Dur.revealLost == .milliseconds(1020))
    }

    /// The play surface has exactly two recurring animations and both stay inside the budget;
    /// the two reveal sheets are the sanctioned once-per-round exceptions.
    @Test("the recurring pair sits at or under 260 ms and the reveals are the only outliers")
    func durationBudget() {
        #expect(Dur.admit <= .milliseconds(260))
        #expect(Dur.reject <= .milliseconds(260))
        let long = [Dur.reveal, Dur.revealLost]
        #expect(long.allSatisfy { $0 > .milliseconds(900) })
        #expect(Dur.streak <= .milliseconds(900))
    }

    @Test("six Reduce Motion substitutions exist and none collides with a normal duration")
    func reduceMotionSubstitutionsAreDistinct() {
        // `Dur.reduceMotionRing` is a static member of `Dur`; the elements are `Duration`
        // values, so every one has to be written out in full.
        let substitutions = [
            Dur.reduceMotionReveal, Dur.reduceMotionRing, Dur.reduceMotionSwap,
            Dur.reduceMotionStrike, Dur.reduceMotionExpand, Dur.reduceMotionMorph,
        ]
        #expect(substitutions.count == 6)
        #expect(Set(substitutions).count == 6)
        #expect(!substitutions.contains(Dur.crossfade))
    }

    /// `ease.settle` is the only overshoot in the app — 8 pt, reveal beat 2, nowhere else.
    /// Under-damping is what an overshoot *is*, so the invariant is expressible.
    @Test("settle is the only under-damped spring")
    func settleIsTheOnlyOvershoot() {
        let springs: [(String, Easing)] = [
            ("snap", .snap), ("settle", .settle), ("dock", .dock),
            ("sheet", .sheet), ("zoom", .zoom), ("shared", .shared),
        ]
        let underDamped = springs.filter { _, easing in
            guard case .spring(_, let damping) = easing else { return false }
            return damping < 0.85
        }
        #expect(underDamped.map(\.0) == ["settle"])
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter TokensTests`.
Expect `cannot find 'Palette' in scope`, `cannot find 'RenderEnv' in scope` and four more of the
same shape. If `PaletteTests` fails on an *argument* error rather than a missing symbol, the
`arguments: RenderEnv.Theme.allCases` parameterisation is malformed — fix that first, because a
suite that cannot enumerate its themes will report green over two of the three.

**Step 3 — implement.** Six source files, in this order so each compiles against the last:
`RenderEnv.swift` (the record only) → `Palette.swift` → `StrokeWeight.swift` → `Space.swift` →
`TypeRole.swift` → `Motion.swift`.

**Step 4 — green, then refactor,** then run the register-laundering drill below before committing.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Tokens/RenderEnv.swift` — **the record only**; its behaviour is T03 |
| create | `HunchCore/Sources/Tokens/Palette.swift` |
| create | `HunchCore/Sources/Tokens/StrokeWeight.swift` |
| create | `HunchCore/Sources/Tokens/Space.swift` |
| create | `HunchCore/Sources/Tokens/TypeRole.swift` |
| create | `HunchCore/Sources/Tokens/Motion.swift` |
| create | `HunchCore/Tests/TokensTests/PaletteTests.swift` |
| create | `HunchCore/Tests/TokensTests/StrokeWeightTests.swift` |
| create | `HunchCore/Tests/TokensTests/SpaceTests.swift` |
| create | `HunchCore/Tests/TokensTests/TypeRoleTests.swift` |
| create | `HunchCore/Tests/TokensTests/MotionTests.swift` |
| modify | `DECISIONS.md` — the `Palette.swift`/`Stroke.swift` relocation entry |

## Implementation notes

**Why `RenderEnv.swift` is created here and finished in T03.** `Palette.init(theme:)` takes a
`RenderEnv.Theme`, so the type must exist before `Palette` compiles. This task lands the *record* —
the seven stored `var`s, the nested `Theme` enum, the defaulted memberwise `public init` — and
nothing computed. T03 adds `extension RenderEnv` with `artScale`, `palette`, `weight(_:)`,
`type(_:)` and the six predicates, and adds `resolved(in:)` to `StrokeWeight` and `TypeRole` and
`scrim(in:)` to `Opacity`. The split is deliberate: the record is data and the resolution order is
behaviour, and keeping them apart is what makes T03's resolution-order test fail for the right
reason — a missing `resolved(in:)`, not a missing type.

`RenderEnv.Theme` is `String`-backed and `Codable` because §12.6's theme preference is persisted;
nothing else in `RenderEnv` is. The seven fields are `var` so the app can build one incrementally in
T06's reader; every other token in this task is a `let` (`W18`).

**`Palette.swift` — three things that are structural, not stylistic.**

- **`AccentColor` and `HueColor` are distinct structs with `init(_ rgb: RGB8)` at *internal* access.**
  Not `public`, not `fileprivate`. Internal is exactly right: `Palette` mints them from inside the
  module, and no code in `Modules/` or `App/` can build one at all — which is what makes
  `drawGlyph(_:ink: HueColor)` unable to accept `env.palette.accent.brass`. `palette.md` §4 has the
  three worked call sites, one right and two wrong.
- **`Palette.init(theme:)` is a `switch` over all three cases with no `default:` (`W29`).** A fourth
  theme must break the build. That is the point, and it is also why `Palette`'s stored properties
  and its designated initialiser are both in the primary declaration (`W13`) — which keeps the
  synthesised memberwise initialiser internal, so nothing outside `Tokens` can assemble a `Palette`
  from arbitrary colours.
- **`glyphKeyline` is `RGB8?` and is `nil` in dark and High Contrast.** The renderer branches on
  `nil`, never on `theme` — dark needs no keyline (worst hue is teal at 5.78 : 1) and High Contrast
  needs none (`hue.*` *is* `stroke.primary`, so a keyline would be an invisible stroke under an
  identical one). `light-theme.md` §2 has the arithmetic.

**The laundering drill — run it once, then delete the line.** Register segregation is a compile
error, so the shipped assertion is a compiler diagnostic and not a `#expect`. Prove it exists:

```bash
cat >> HunchCore/Tests/TokensTests/PaletteTests.swift <<'EOF'
// DRILL — must NOT compile. Delete after observing the error.
private let laundered = HueColor(Palette(theme: .dark).accent.brass.rgb)
EOF
swift build --package-path HunchCore --build-tests 2>&1 | grep -c "initializer .* is inaccessible"
git checkout -- HunchCore/Tests/TokensTests/PaletteTests.swift
```

Expect a non-zero count and the message `'init' is inaccessible due to 'internal' protection level`.
`TokensTests` is a separate module and this project never uses `@testable import` (`06 T4`), so the
drill is honest. Record the observed message in the commit body; do not leave the line in the file.

**`StrokeWeight.swift`.** Two stored properties and an initialiser with `respondsToBoldText`
defaulting to `true`. It carries **no** `resolved(in:)` yet — T03 adds it. All five L1 statics set
the default, which is `dimensions-strokes-opacity.md` §1's all-five ruling; the parameter exists for
L2 weights that must opt out.

**`Space.swift` holds three caseless enums** — `Space`, `Radius`, `Opacity` — and that is a stated
`P24` deviation, recorded in `tokens-swift-layout.md` §1: all three are value-only namespaces of
`Double`, none exceeds thirty lines, and splitting them yields two files whose names carry no more
information than a `// MARK:`. `Motion.swift` holds `Dur` and `Easing` for the same reason. Do not
"fix" either by splitting; do not merge them further either.

`Opacity.scrim(in:)` is T03's (it reads `isReduceTransparencyEnabled`). Everything else in `Opacity`
is a constant. **Seven of PHOSPHOR §1.4's opacities do not belong here** —
`dimensions-strokes-opacity.md` §5 maps each to its L2 owner. If you find yourself typing
`opacity.assayLit`, `opacity.cellUnlit`, `opacity.cellInert`, `opacity.ribbonDim`, `opacity.lawGhost`,
`opacity.railPulse` or `opacity.hairlinePulse` into this file, stop: two of them are T04's and five
are later epics'.

**`TypeRole.swift`.** The type is named `TypeRole` and the token path stays `type.*` — `enum Type`
is legal Swift and unreadable next to metatype syntax. That mismatch is recorded in
`tokens-swift-layout.md` §2 and nowhere else; do not record it a second time. `Weight` is
`Int`-backed and `Comparable` so `bolder` saturates in one expression. `resolved(in:)` is T03's.
`tracking(atScaledSize:)` ships here because it is pure arithmetic over the token.

**`Motion.swift`.** `Duration`, never `Double` — a bare `260` is ambiguous between ms and s and both
spellings appear in the GDD (§13.7 in ms, §11.11's Profile morph in seconds). `HunchCore` gets
`Duration` from the stdlib with no import. `Easing` is platform-free and carries no SwiftUI type;
T06's adapter maps each case to an `Animation`. Ship the six Reduce Motion substitution durations
here even though the *substitution table* is `hunch-motion-and-feedback`'s (E20·T08): each of the
six is shared by two or more components, which is `durations-and-easing.md` §4's own test for L1
rather than L2.

**Nothing in this task varies a dimension, weight, radius, duration or easing by theme.**
`light-theme.md` §7 is the rule and it is what keeps the light theme a second exposure of one
artefact rather than a second art direction. If a value needs a theme fork, it is a colour or it is
an explicit High Contrast *substitution* (T04), never a geometry fork.

**Record in `DECISIONS.md`:** *"`08 §1`'s tree places `Palette.swift` and `Stroke.swift` in
`Modules/Sources/HunchUI`. They ship instead in `HunchCore/Sources/Tokens` as `Palette.swift` and
`StrokeWeight.swift`, per `DESIGN-SYSTEM-SCOPE.md` §4.4, so that the contrast matrix and the
resolution order are asserted by `swift test` with no simulator. `HunchUI` keeps `Typography.swift`
and gains the four-file adapter (E03·T06)."*

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter TokensTests` is green, five new suites present.
- [ ] `HunchCore/Sources/Tokens/` contains exactly eight files: `RGB8`, `Prim`, `RenderEnv`,
      `Palette`, `StrokeWeight`, `Space`, `TypeRole`, `Motion` (`C.swift` arrives in T04).
- [ ] The laundering drill produces `'init' is inaccessible due to 'internal' protection level`,
      and the drill line is not in the committed tree:
      `grep -rn 'HueColor(' HunchCore/Tests/` returns nothing.
- [ ] `grep -n 'default:' HunchCore/Sources/Tokens/Palette.swift` returns nothing (`W29`).
- [ ] `grep -rn 'public init' HunchCore/Sources/Tokens/Palette.swift` shows `init(theme:)` and
      no initialiser on `AccentColor` or `HueColor`.
- [ ] `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` still exits 0.
- [ ] `Scripts/check-source-hygiene.sh` exits 0.
- [ ] `DECISIONS.md` carries the relocation entry.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. Two things it must *not* be allowed to collapse:
   the three-arm `switch` in `Palette.init` (a `default:` would erase `W29`'s compile-time guarantee)
   and the five separate `StrokeWeight` statics (a computed ladder would remove the per-token
   `respondsToBoldText` metadata this task exists to carry).
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E03/T02: L1 palette, weights, space, type and time, with the register split as a type"`

## Out of scope

- Every computed member of `RenderEnv`, `StrokeWeight.resolved(in:)`, `TypeRole.resolved(in:)` and
  `Opacity.scrim(in:)` — **T03**.
- `C.<component>` and every component-scoped opacity, scale or cell size — **T04**.
- The contrast matrix, the High Contrast floor and the register-adjacency assertion — **T05**.
  This task asserts *which `Prim` each token selects*; T05 asserts *what that measures*.
- `Color`, `Font`, `Animation` and every other SwiftUI type — **T06**. Nothing in this task imports
  SwiftUI, and `check-boundary.sh` will say so.
- Applying any of it to a drawing — **E04** onward.
