# T08 — Shared marks, part 2

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | §14.1 PROBE → **The ribbon** (its link arcs and return elbow) · §14.1 PROBE → **Par tick row + par crossing** (the row itself) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-shared-marks` | Owns the four marks this task ships. Read `references/link-arc.md`, `references/cancel-hatch.md`, `references/tick-row.md` and `references/arc-meter.md` in full, and re-read `references/ownership.md` §5 — a new site for an existing mark is a new `case` or a defaulted parameter, never a second function. Run its Step 0 block first; T07's three files must appear and nothing may be declared twice. |
| `hunch-design-tokens` | The cancel hatch's weight is `C.Ramp.cancelHatchWeight(in:)` — a **substitution** that returns a raw `Double` precisely so it never picks up Bold Text's ×1.25, because at 2.5 pt its coverage would cross `dotted`'s 22.7 % and put a fifth rung on the `fill` ladder. The skill owns that ruling, and it owns the tick row's inks and the arc meter's four. |

## Objective

The remaining four shared idioms get their one owner each: the link arc and its return elbow, the cancel hatch in both variants, the tick row in all four modes, and the arc meter across its three track kinds and five styles. When this task lands, `DESIGN-SYSTEM-SCOPE.md` §2(g) is closed — every one of the seven idioms named there has a declared owner, a `C.<Mark>` namespace, a row in `SPEC.md` and a grep that fails the build on a second declaration — and T07's deferred `CancelHatch.draw(variant: .slash)` call inside the transient reject ring is opened.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.1, §6.2, §8.4 | link arcs assert adjacency in time; the spool sheet wraps "with a return elbow **so adjacency survives the wrap**"; verdict sort drops all arcs; arcs are exempt from the 44 pt hit-target floor |
| `GAME_DESIGN.md` | §4.2, §4.3, §8.4, §13.11 | the cancel hatch's four sites: unlit ramp cell, inert ramp, eliminated ECHO pool member, the transient reject ring; 1.0 pt → 2.0 pt under High Contrast |
| `GAME_DESIGN.md` | §13.5 | `striped` runs at +45°, which is why the hatch runs at −45° |
| `GAME_DESIGN.md` | §5.4, §6.2, §6.9 | the tick row's length is the only difficulty signal the player gets; `tickPitch = min(nominalPitch, rowWidth/N)`; the crossing inverts the row and the cap row begins emptying from the trailing end; **no audio and no haptic on the crossing** |
| `GAME_DESIGN.md` | §9.2, §11.2, §11.7, §11.8, §12.4 | the arc meter's five sites; linear vs log-scaled with notches at \|H\| ≤ 512; the 24-segment rollover; `.clockBehind` is full and static |
| `hunch-shared-marks` | the four reference files | geometry, states, the Swift, environment behaviour and each `C.<Mark>` namespace |
| `hunch-shared-marks` | `references/cancel-hatch.md` §2 | the two arithmetic constraints — perpendicular to `striped`, and coverage below `dotted`'s 22.7 % — with the four-row table that must be recomputed if either number moves |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Create `Modules/Tests/HunchUITests/Marks/CancelHatchTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Cancel hatch", .tags(.snapshot, .presubmission))
@MainActor
struct CancelHatchTests {

    private static let cell = CGRect(x: 6, y: 6, width: 56, height: 44)

    /// Constraint (a): the hatch must never be parallel to `striped`, which §13.5 draws at
    /// +45°. At −45° the two are exactly perpendicular and the hatch reads over every one
    /// of the four fills. This is also why it is not "a few diagonals whichever way looks
    /// better".
    @Test("The hatch is exactly perpendicular to the striped fill",
          arguments: [CancelHatch.Variant.hatch, .slash])
    func theHatchIsPerpendicularToTheStripedFill(variant: CancelHatch.Variant) throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 68, height: 56)) { ctx in
            CancelHatch.draw(into: ctx, region: Self.cell, variant: variant, env: env)
        }
        let axis = raster.principalAxisDegrees(in: Self.cell)   // normalised to [0, 180)
        #expect(isApproximatelyEqual(axis, 135, absoluteTolerance: 2))          // −45° here
        #expect(isApproximatelyEqual(abs(axis - 45), 90, absoluteTolerance: 2)) // ⟂ `striped`
    }

    /// Constraint (b): coverage is `weight / spacing` and must stay BELOW `dotted`'s
    /// 22.7 %, or the hatch becomes a fifth rung on the `fill` ladder and corrupts a
    /// channel the glyph owns. The High Contrast margin is 2.5 percentage points, and the
    /// row that would break it is High Contrast × Bold Text — which is why the weight is a
    /// substitution returning a raw Double and never a StrokeWeight.
    @Test("Hatch coverage stays below the dotted rung in every environment",
          arguments: [RenderEnv(), RenderEnv(isBoldTextEnabled: true),
                      RenderEnv(theme: .highContrast),
                      RenderEnv(theme: .highContrast, isBoldTextEnabled: true)])
    func hatchCoverageStaysBelowTheDottedRung(env: RenderEnv) {
        let nominalDotted = .pi * pow(C.Glyph.dotRadius(side: 96), 2)
            / (C.Glyph.pitch(side: 96) * C.Glyph.pitch(side: 96) * (3.0 as Double).squareRoot() / 2)
        let coverage = C.Ramp.cancelHatchWeight(in: env) / C.CancelHatch.spacing
        #expect(coverage < nominalDotted)
    }

    /// The substitution terminates resolution: High Contrast gives an explicit value and
    /// Bold Text does not then multiply it.
    @Test("High Contrast substitutes the hatch weight and Bold Text does not scale it")
    func highContrastSubstitutesTheHatchWeight() {
        let hc = RenderEnv(theme: .highContrast)
        let hcBold = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        #expect(C.Ramp.cancelHatchWeight(in: hc) > C.Ramp.cancelHatchWeight(in: RenderEnv()))
        #expect(isApproximatelyEqual(C.Ramp.cancelHatchWeight(in: hcBold),
                                     C.Ramp.cancelHatchWeight(in: hc),
                                     absoluteTolerance: 1e-12))
    }

    /// The angle does not mirror. A mirrored hatch runs at +45°, parallel to `striped`,
    /// and vanishes on a striped mark in Arabic and Hebrew only — a locale-specific
    /// legibility failure nobody would ever find.
    @Test("The hatch does not mirror under RTL")
    func theHatchDoesNotMirrorUnderRTL() throws {
        let env = RenderEnv()
        func raster(_ layout: LayoutDirection) throws -> MarkRaster {
            try markRaster(size: CGSize(width: 68, height: 56), layout: layout) { ctx in
                CancelHatch.draw(into: ctx, region: Self.cell, variant: .hatch, env: env)
            }
        }
        let ltr = try raster(.leftToRight)
        let rtl = try raster(.rightToLeft)
        #expect(ltr.samples == rtl.samples)
    }

    /// `.ellipse` bounds make the slash a diameter chord, which is what the transient
    /// reject ring needs and what makes T07's deferred call site correct.
    @Test("An elliptical slash is a diameter chord")
    func anEllipticalSlashIsADiameterChord() throws {
        let env = RenderEnv()
        let radius = 40.0
        let region = CGRect(x: 10, y: 10, width: 2 * radius, height: 2 * radius)
        let raster = try markRaster(size: CGSize(width: 100, height: 100)) { ctx in
            CancelHatch.draw(into: ctx, region: region, variant: .slash,
                             bounds: .ellipse, paint: .verdict, env: env)
        }
        #expect(isApproximatelyEqual(raster.inkExtentAlongPrincipalAxis(in: region),
                                     2 * radius, absoluteTolerance: 2))
    }
}
```

Create `Modules/Tests/HunchUITests/Marks/TickRowTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Tick row", .tags(.snapshot, .presubmission))
@MainActor
struct TickRowTests {

    private static let frame = CGRect(x: 0, y: 0, width: 288, height: 20)   // SE row width

    /// The row's LENGTH is the only difficulty signal the player is given (§5.4, §10.5):
    /// 7 ticks at band 1, 29 at band 8. Within PROBE the pitch is unclamped, so length is
    /// exactly proportional to par; the clamp engages only at DRIFT's 40.
    @Test("Length is proportional to total until the clamp engages",
          arguments: [7, 15, 23, 29, 40])
    func lengthIsProportionalToTotalUntilTheClampEngages(total: Int) throws {
        let env = RenderEnv()
        let nominal = 9.0
        let raster = try markRaster(size: CGSize(width: 300, height: 24)) { ctx in
            TickRow.draw(into: ctx, frame: Self.frame, mode: .count(filled: 0, total: total),
                         nominalPitch: nominal, env: env)
        }
        let extent = raster.horizontalInkExtent(atY: Self.frame.maxY - 2)
        let pitch = min(nominal, Self.frame.width / Double(total))
        #expect(isApproximatelyEqual(extent.upper - extent.lower,
                                     Double(total - 1) * pitch + C.TickRow.tickWidth,
                                     absoluteTolerance: 1))
        #expect(extent.upper <= Self.frame.maxX + 0.5)
    }

    /// State is a HEIGHT STEP, not a tint: both states carry one ink and differ by length,
    /// so the count is read off the filled run and the row survives greyscale, every
    /// dichromacy and a monochromat.
    @Test("Taken and remaining differ by height and share one ink")
    func takenAndRemainingDifferByHeightAndShareOneInk() throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 300, height: 24)) { ctx in
            TickRow.draw(into: ctx, frame: Self.frame, mode: .count(filled: 4, total: 12),
                         nominalPitch: 9, env: env)
        }
        let heights = raster.tickHeights(baselineY: Self.frame.maxY)
        #expect(heights.count == 12)
        #expect(heights.prefix(4).allSatisfy { $0 > heights[4] * 1.5 })
        #expect(raster.distinctInkLevels(above: 0.5).count == 1)
    }

    /// Dynamic Type scales the HEIGHTS and never the pitch. If pitch scaled, PROBE's
    /// band-8 row would engage the clamp at AX2 and the length ratio between band 1 and
    /// band 8 would silently stop matching the par ratio — Dynamic Type would distort the
    /// only difficulty signal the player has.
    @Test("artScale moves the heights and never the pitch")
    func artScaleMovesTheHeightsAndNeverThePitch() throws {
        func raster(_ multiplier: Double) throws -> MarkRaster {
            let env = RenderEnv(typeMultiplier: multiplier)
            return try markRaster(size: CGSize(width: 300, height: 40)) { ctx in
                TickRow.draw(into: ctx, frame: Self.frame,
                             mode: .count(filled: 29, total: 29), nominalPitch: 9, env: env)
            }
        }
        let plain = try raster(1.0)
        let large = try raster(2.0)                       // clamps to the 1.35 art ceiling
        let plainExtent = plain.horizontalInkExtent(atY: Self.frame.maxY - 2)
        let largeExtent = large.horizontalInkExtent(atY: Self.frame.maxY - 2)
        #expect(isApproximatelyEqual(largeExtent.upper - largeExtent.lower,
                                     plainExtent.upper - plainExtent.lower,
                                     absoluteTolerance: 1))
        #expect(large.tickHeights(baselineY: Self.frame.maxY)[0]
                    > plain.tickHeights(baselineY: Self.frame.maxY)[0])
    }

    /// A spent cap stop is an ABSENCE, never a dimmed stop — two channels for one fact,
    /// one of them the tint the row exists to avoid. And the cap row empties from the
    /// trailing end, which is the one thing `layout` is in the signature for.
    @Test("The cap row empties from the trailing end and spent stops are absent")
    func theCapRowEmptiesFromTheTrailingEnd() throws {
        let env = RenderEnv()
        func extent(_ layout: LayoutDirection) throws -> ClosedRange<Double> {
            let raster = try markRaster(size: CGSize(width: 300, height: 24)) { ctx in
                TickRow.draw(into: ctx, frame: Self.frame, mode: .cap(remaining: 5, total: 14),
                             nominalPitch: 9, layout: layout, env: env)
            }
            let measured = raster.horizontalInkExtent(atY: Self.frame.maxY - 2)
            return measured.lower...measured.upper
        }
        #expect(try extent(.leftToRight).lowerBound < Self.frame.midX)
        #expect(try extent(.rightToLeft).upperBound > Self.frame.midX)
    }

    /// The crossing replaces the row with ONE solid rule. Two drawings, crossfaded — no
    /// translation, no scale, no rotation, and no audio or haptic (§6.9 forbids it by
    /// name: the verdict owns those channels on that frame).
    @Test("The crossed row is one rule, not a full row of ticks")
    func theCrossedRowIsOneRule() throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 300, height: 24)) { ctx in
            TickRow.draw(into: ctx, frame: Self.frame, mode: .crossed(total: 23),
                         nominalPitch: 9, env: env)
        }
        #expect(raster.inkRunCount(alongScanY: Self.frame.maxY - 1) == 1)
    }
}
```

Create `Modules/Tests/HunchUITests/Marks/LinkArcTests.swift` and `Modules/Tests/HunchUITests/Marks/ArcMeterTests.swift` in the same shape. The assertions each must carry:

**`LinkArcTests`**
- the arc's endpoints are exactly `a` and `b`, at every chord length;
- the apex rise is `min(|chord|/2, C.LinkArc.maxRise)` — measured as the maximum perpendicular deviation from the chord — so the ribbon's 6 pt gap gives a 3 pt rise and the counterexample's 96 pt join does not arch into the throat;
- `progress: 0.5` inks about half the path length and `progress: 0` inks nothing;
- `.elbow(drop:)` reaches the next row's attachment and its corner radius is `C.LinkArc.elbowRadius`;
- `.structural` and `.depictive` produce **identical geometry** and differ only in ink;
- the mark takes no `layout` parameter — the host hands over mirrored points — and the bulge side is a function of the passed normal, not of direction.

**`ArcMeterTests`**
- the track is drawn at `fraction = 0` (an empty meter and no meter are different facts);
- the fill starts at 12 o'clock and runs clockwise for every `Track` case, asserted by finding the first inked angle at a small fraction;
- `.rollover` draws 24 segments with `C.ArcMeter.segmentGap` gaps and **quantises `fraction` down** to a whole segment;
- `.logarithmic` puts notches at the decade milestones inside range and its fraction exceeds the linear one for a small `value / total` on a `> 512` shelf;
- `.streak(accented: false)` and `.streak(accented: true)` differ only in ink;
- nothing mirrors under RTL — an arc meter is a dial, and mirroring the rollover would say the day runs backwards.

**Step 2 — run them and watch them fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/CancelHatchTests -only-testing:HunchUITests/TickRowTests \
  -only-testing:HunchUITests/LinkArcTests -only-testing:HunchUITests/ArcMeterTests
```

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then re-run T07's `VerdictRingTests` — opening the deferred `CancelHatch` call changes the transient reject ring's raster, and the cancel-slash assertion in `verdict-ring.md` §1 becomes checkable: the slash is a chord of `2 × C.CancelHatch.slashOvershoot × ringRadius` on the **transient** ring only, never on a settled one.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/Marks/LinkArc.swift` |
| create | `Modules/Sources/HunchUI/Marks/CancelHatch.swift` |
| create | `Modules/Sources/HunchUI/Marks/TickRow.swift` |
| create | `Modules/Sources/HunchUI/Marks/ArcMeter.swift` |
| modify | `Modules/Sources/HunchUI/Marks/VerdictRing.swift` — open the deferred cancel-slash call |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `C.LinkArc`, `C.CancelHatch`, `C.TickRow`, `C.ArcMeter` |
| create | `Modules/Tests/HunchUITests/Marks/{LinkArc,CancelHatch,TickRow,ArcMeter}Tests.swift` |
| modify | `Modules/Tests/HunchUITests/Support/MarkRaster.swift` — add `principalAxisDegrees(in:)`, `inkExtentAlongPrincipalAxis(in:)`, `tickHeights(baselineY:)`, `distinctInkLevels(above:)`, `inkRunCount(alongScanY:)`, `perpendicularDeviation(fromChord:)` |
| modify | `SPEC.md` — complete the drawing-ownership table to seven rows |

## Implementation notes

### Link arc — what the mark asserts is adjacency in time

Two tiles joined by an arc were probed one after the other; a wrap that loses the join loses the chain. The arc is a quadratic Bézier whose control point is offset perpendicular to the chord by **twice** the intended rise, so the apex lands at exactly `rise`:

```
chord   = b − a
n       = unit normal of chord, on the bulge side
rise    = min(|chord| / 2, C.LinkArc.maxRise)
control = midpoint(a, b) + n · 2 · rise
```

At the ribbon that reproduces the mockup exactly: 44 pt tiles at 50 pt pitch leave a 6 pt gap, a 6 pt chord and a 3 pt rise. The `maxRise` cap is what stops the contextual counterexample's join — two 96 pt glyphs with a much wider gap — arching into the throat.

**The return elbow** is the wrap: out from the trailing attachment by `elbowReach`, down by the row pitch, back in to the next row's leading attachment, with `elbowRadius` rounded corners. Same mark because it makes the same assertion; different *kind* because a Bézier cannot express a wrap without overshooting a row.

Ink is `stroke.hairline` at `env.weight(.thin)`, `round` caps — the arc is chrome. Using the hairline colour is legitimate here and worth stating, because `palette.md` declares hairline *never state-bearing*: **adjacency is not a state of any tile.** Every arc in chain order is drawn; verdict sort drops **all** of them. Nothing about a single tile is ever read off the presence or absence of its arc, so "a faded arc" is a third state that says adjacency partly holds, which is not a thing.

**The signature takes two points, never tile indices, a lane number or a pitch.** The moment it knows about the ribbon's grid it cannot draw the counterexample join, and someone writes a second function for that. And **no `layout` parameter**: §2 renders instrument scales leading-to-trailing in source order in every locale, so the host hands over mirrored points and the arc is correct without knowing the direction. The bulge side is fixed to the row by the host, so mirroring is a pure reflection and the chain does not appear to change shape in Arabic.

**Never draw the arc into the bloom bed.** A blurred hairline at `Opacity.bloomBed` over a 6 pt gap smears into both neighbouring glyphs and raises their measured interior coverage — the discriminator §13.5.1's proof depends on. Arcs go into the host's non-bed sub-layer.

**The ECHO mode sigil is three calls with three opacities**, not a decaying-arc function.

### Cancel hatch — the mark with arithmetic

**Angle: −45° in the screen frame**, for both variants and at every site. `.hatch` is a family of parallel lines at perpendicular spacing `C.CancelHatch.spacing`, clipped to the region; `.slash` is one line through the region centre. `Bounds.ellipse` makes the slash a diameter chord, which is what the reject ring needs.

The two constraints, and neither can be eyeballed:

**(a) Never parallel to `striped`.** §13.5 draws the striped fill at +45°; a hatch at +45° interleaves with the fill and disappears. At −45° they are exactly perpendicular and the hatch reads over all four fills.

**(b) Coverage must stay below `dotted`'s 22.7 %.** For parallel lines of width `w` at perpendicular spacing `s`, coverage is `w/s`:

| Condition | `w` | coverage | vs `dotted` |
|---|---|---|---|
| normal | 1.0 | 10.10 % | clear |
| Bold Text | 1.25 | 12.63 % | clear |
| High Contrast (substitution) | 2.0 | 20.20 % | clear, by 2.5 points |
| High Contrast × Bold Text, **if the substitution were also scaled** | 2.5 | 25.25 % | ✗ **over `dotted`** |

The last row is why the substitution ruling is load-bearing rather than tidy: `C.Ramp.cancelHatchWeight(in:)` returns a raw `Double`, not a `StrokeWeight`, so it never passes through `resolved(in:)` and never picks up Bold Text. **Turning it into a `StrokeWeight` would push the hatch onto the `fill` ladder under two accessibility settings that are commonly on together.** `w` is quoted from that symbol — it is this table's *input*, not a second declaration — and if it ever moves, every row is recomputed in the same commit.

**Read `C.Ramp.cancelHatchWeight(in:)`; do not re-declare it as `C.CancelHatch.weight`.** The namespace names one of the mark's four sites, which is untidy; untidy beats two homes for one number. A rename is safe later; a second declaration is not.

**The slash uses the same weight as the hatch, not `weight.hairline`.** §4.3's "a hairline slash" is prose meaning *thin*; the token named `weight.hairline` is a specific, much lighter value, and the hairline *colour* is declared never state-bearing. An inert ramp already draws at `C.Ramp.inertInk`; the lightest weight at that ink is not a channel.

`Paint` is a closed enum (`.chrome` / `.verdict`) rather than a colour parameter, so a call site cannot reach `.rgb` on an `AccentColor` and launder a register. `env.palette.accent.cold.rgb` **inside this file** is the sanctioned crossing: the register decision was made once, by the enum.

**Spacing does not scale with `env.artScale`.** It is a texture pitch pinned in points exactly like §13.5's `pitch`, and a hatch whose density changed with the type setting would change its coverage and therefore its relationship to the `fill` ladder at AX2.

**No cross-hatch.** §11.8's word for the Anomaly `failed` cell is prose; two angles means two families, double the coverage — straight past `dotted` and onto `striped` — and a second drawing to keep in step.

**The hatch is never dimmed with the cell it marks**, whatever the cell does. That is this mark's own rule and it holds under either reading of the unlit cell; the cell's ink is `hunch-bench-instruments`'.

### Tick row — the only running state readout on a surface with no text

Ticks are **filled rectangles**, `C.TickRow.tickWidth` wide, on a shared baseline, differing by **height**: taken, remaining, cap stop, crossed rule. **State is a height step, not a tint** — the row previously ran taken ticks in `stroke.secondary` against remaining ticks in `stroke.hairline`, which is a state gap of barely two to one on a 2 × 11 pt mark *and* a hairline doing state duty, which `palette.md` forbids outright. Both states now carry one ink; the count is read off the length of the filled run.

**Pitch** is device layout and comes from the host, per `08 §2`'s boundary rule — `Band.par`/`Band.cap` are core, `tickPitch` is not:

```
tickPitch = min(nominalPitch, rowWidth / total)
```

Within PROBE the clamp never engages (29 × 9 = 261 pt inside SE's 288), so the row's length is exactly proportional to par and §10.5's signal is intact. It engages only in DRIFT at par 40, compressing to 7.2 pt with ≥ 5.2 pt of gap left — and DRIFT's tick count already identifies the mode by design.

Four modes: `.count(filled:total:)`, `.crossed(total:)`, `.cap(remaining:total:)`, `.silhouette(total:)`. **The cap row's `total` is `cap − par`**, not `cap` — the budget that remains after par, which is what "begins emptying" means. **A spent cap stop is an absence**, never a dimmed stop.

Return `[CGRect]` from the private layout function and `fill` them. **Never stroke a tick:** a 2 pt stroke centres on a line and lands on half-pixels at the odd pitches the clamp produces.

**Dynamic Type scales the heights and never the pitch**, and the arithmetic is why: with a scaled pitch, PROBE's band-8 row needs `29 × 12.15 = 352` pt against 288, the clamp engages, the pitch compresses to 9.93, and band 1 renders 85 pt against band 8's 288 — a ratio of 3.39 where the true par ratio is 4.14. **Dynamic Type would silently distort the only difficulty signal the player is given.**

**High Contrast and Bold Text change nothing here.** §13.11's `+0.5` applies to *stroke weights*; a tick is a filled rectangle like an Assay cell, and widening it would eat the clamped DRIFT row's 5.2 pt gap while adding no information the resolved ink does not already carry.

**The crossing is a crossfade in both motion modes** and §13.7.4 has no row for it because nothing translates, scales or rotates. **Do not wire a cue to it**: §6.9 forbids audio and haptic by name, because the crossing lands on the same frame as a verdict and a second cue there would teach the player that "sometimes the admit tone is different" — a lie about the law.

**The Anomaly's 28-cell ribbon is rings, not ticks.** Scope §3 lists "Anomaly tally" under the tick row; that site is the Inscription's appended strip, which *is* a tick row. Two different marks, adjacent screens.

### Arc meter — one rule for five sites

**A track, and the leading `fraction` of it filled**, via `track.trimmedPath(from: 0, to: fraction)`. That is the only way a circle, a rounded-rect key border and an open plate arc stay one mark.

**Start at 12 o'clock, fill clockwise, always.** Every one of the five is a dial — hours into a UTC day, probes into par, pages into a shelf, glyphs into a stream. Starting anywhere else makes one of them disagree with the other four for no reason a player could learn.

**Caps are `butt`**: the *length* of the fill is the readout, and round caps add half a stroke width at each end — a measurable fraction of a small ring's circumference, and on the 24-segment rollover they would close the gaps outright.

**The track is always drawn**, at `env.weight(.hairline)` in `stroke.hairline`, even at `fraction = 0`: "no shelf progress" and "no shelf" are different facts.

`Scale` is `.linear` or `.logarithmic`, and the `|H| ≤ 512` rule is expressed **once, here**, so a call site never computes a logarithm. On a 2,063-row shelf a linear arc sits at 0.5 % for months and reads as broken; the log arc shows the first ten finds and the notches say the scale is not linear.

`Style` is a **closed enum** — `.shelfFill`, `.keyBorder`, `.rollover`, `.streak(accented:)`, `.streamProgress` — so a call site cannot pick an ink or a weight, no two sites can drift, and a sixth site is a visible `case`. Note the trap in `.keyBorder`: §12.4's "hairline border" names `env.weight(.thin)`, **not** `weight.hairline`, which is a different value.

`fillInk` is where `AccentColor` is unwrapped, once, behind the enum — the same containment `CancelHatch.Paint` uses.

**`.streak(accented: false)` on the Frame's Anomaly key, `accented: true` on `AnomalyView` and the Inscription.** No conditional. The reason is a reachable violation of §13.1's three-accents-per-screen ration: after "Reset everything" a player has a live streak (the Anomaly ledger is reset-immune by design), an empty Codex, and three barred mode keys — three cold bars plus a brass streak ring is four accents on the Frame. Asserting the invariant on `FrameView` is `hunch-chrome-and-meta`'s job in E17; making it unreachable is this enum's.

**`.rollover` quantises `fraction` down to a whole segment.** A meter showing a partial hour implies a precision the UTC day index does not have. Its known weak point is Bold Text: the gap is a fixed angle, so on a small ring it is barely more than one resolved stroke width of arc. Compute `gap_pt = radius × radians(segmentGap)` for the radius in question rather than trusting a figure written for a different one, and if segmentation has to survive Bold Text, widen `segmentGap` — do not thin the stroke.

### Completing the record

`SPEC.md`'s drawing-ownership table goes to seven rows. `Scripts/check-source-hygiene.sh` needs **no change** — T07's checks 11 and 12 already name all seven marks, which is why they were written that way. Re-run them and confirm they now find seven files under `Marks/` and no second declaration anywhere.

## Acceptance criteria

- [ ] `Modules/Sources/HunchUI/Marks/` contains exactly seven files, each with exactly one `public static func draw`.
- [ ] `xcodebuild test … -only-testing:HunchUITests/CancelHatchTests -only-testing:HunchUITests/TickRowTests -only-testing:HunchUITests/LinkArcTests -only-testing:HunchUITests/ArcMeterTests` green.
- [ ] Hatch coverage `C.Ramp.cancelHatchWeight(in:) / C.CancelHatch.spacing` is below the nominal `dotted` coverage in all four environment rows, **including High Contrast × Bold Text**.
- [ ] The tick row's total inked width is identical at `typeMultiplier` 1.0 and 2.0 while its heights are not — pitch does not scale, heights do.
- [ ] `TickRow` fills rectangles: `grep -n 'ctx.stroke' Modules/Sources/HunchUI/Marks/TickRow.swift` returns nothing.
- [ ] `grep -rn 'func draw' Modules/Sources/HunchUI/Marks/ | wc -l` is 7.
- [ ] `bash Scripts/check-source-hygiene.sh` passes with all seven marks present.
- [ ] T07's `VerdictRingTests` still green with the cancel slash opened, and the slash measures a chord of `2 × slashOvershoot × ringRadius` on the transient ring and is absent from settled rings.
- [ ] `SPEC.md`'s drawing-ownership table has seven rows, and `DESIGN-SYSTEM-SCOPE.md` §2(g)'s four named idioms — machined bar, ghost frame, cancel hatch, tick row — all appear in it.
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T08: link arc, cancel hatch, tick row and arc meter — §2(g) closed, seven marks seven owners"`

## Out of scope

- **The par crossing as an event** — E08·T08 owns when the row flips and what else happens on that frame; this task owns the two drawings it flips between.
- **`tickPitch`'s device constants** (9 / 10 pt nominal, 288 / 348 pt row width) — E08·T02's layout table. They arrive as parameters here.
- **The spool sheet's elbow count, the Pro Max two-lane ribbon, the ECHO rail** — E08·T05, E08·T09, E13·T05. The mark draws one elbow per call; how many there are is layout.
- **The unlit ramp cell's own ink** — `hunch-bench-instruments`, E09·T02. This task owns only the hatch over it, and the rule that the hatch is never dimmed with the cell.
- **The shelf fill arc's notch positions on a real shelf, the Anomaly rollover's clock, SIEVE's stream progress** — E15·T02, E16·T04, E14·T05. `value` and `total` are parameters.
- **`FrameView`'s three-accent invariant** — E17·T03.
- **Audio, haptics and durations** for anything here — E20.
