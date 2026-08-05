# T06 — Triple-encoding proof and the constant T

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | §14.1 ACCESSIBILITY → **Triple-encoding proof** · §14.1 ART / MOTION → **Glyph geometry** (the claim it makes falsifiable) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-glyph-renderer` | Owns `T`. `references/triple-encoding-proof.md` is the whole task: the claim, why single-ink is the adversarial model, the measured channel ranking, the six-environment floor table, the two shipped tests and the six things that would invalidate the proof. It also carries the ratification procedure — adopt the Swift test, run it once, and if it disagrees with the JS model, **the disagreement is the finding**. |
| `hunch-swift-testing` | The suite is `.snapshot`-tagged and lives in `Modules/Tests/HunchUITests`, not in `HunchCore`'s ten-second budget; the skill owns the tag vocabulary, the three test plans, the `tests.json` obligation and the rule that an entry is never deleted or weakened to reach green. |
| `hunch-design-tokens` | `T` is a member of `C.Glyph`, so the layering rule applies: L2 holds geometry, never a colour or a duration. The skill also owns the measured luminance figures the proof's §1 correction rests on, and `check-tokens.swift`, which is where a luminance is recomputed rather than quoted. |

## Objective

§13.5.1's two tests ship, and the constant `T` — which the GDD asserts as shipped and never states — is **measured** against the real SwiftUI rasteriser, ratified against the analytic model, and recorded in `C.Glyph`, `DECISIONS.md` and `tests.json`. Before this task the triple-encoding claim is falsifiable in form and undetermined in fact; after it, "all 256 glyphs are pairwise-distinct greyscale rasters at 44 pt @2×" is a command anyone can run, in the six environments that matter, with the worst case named.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.5.1 | the claim, the four achromatic discriminators, and the two shipped tests: bit-identical coverage masks under a monochrome render, and pairwise L1 ≥ `T` at 44 pt @2× |
| `GAME_DESIGN.md` | §13.12 | acceptance items **1** and **2**, each with a matching `tests.json` entry, gating every release build |
| `GAME_DESIGN.md` | §2 | `teal` and `rose` are luminance-adjacent, so hue is not recoverable from luminance and the index stroke *is* the channel |
| `hunch-glyph-renderer` | `references/triple-encoding-proof.md` §§1–6 | the method, the ranking, `T`, the two tests, the ratification procedure, what would invalidate it |
| `hunch-glyph-renderer` | `references/fill-textures.md` §4 | why the pairwise raster distance and not a comparison of means |
| `design/DESIGN-SYSTEM-SCOPE.md` | §2(c) | the gap this closes: "falsifiable in form, undetermined in fact, and choosing it requires rendering all 256" |

## TDD — the test comes first

**Step 1 — write the failing tests.** Two suites, and neither belongs in `HunchCore` — both need a rasteriser.

Create `Modules/Tests/HunchUITests/DeckSeparationTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("The deck separates by geometry alone")
@MainActor
struct DeckSeparationTests {

    /// The gate, in the environment that is actually the worst — High Contrast + Bold
    /// Text, because thickening every stroke shrinks a pip's MARGINAL contribution and
    /// `pips two ↔ three` is the deck's floor. Runs per PR: a geometry regression that
    /// only shows up nightly is a geometry regression that ships.
    @Test("All 256 are pairwise distinct in the worst environment",
          .tags(.snapshot, .presubmission))
    func allTwoFiftySixArePairwiseDistinctInTheWorstEnvironment() throws {
        let env = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        let floor = try Self.pairwiseFloor(in: env)
        #expect(floor.value >= C.Glyph.minimumPairwiseInkDifference,
                "floor \(floor.value) pt² at \(floor.pair)")
    }

    /// The full six-environment matrix of triple-encoding-proof.md §4. 32,640 pairs each.
    @Test("All 256 are pairwise distinct in every shipped environment",
          .tags(.snapshot, .nightly), arguments: RenderEnv.separationMatrix)
    func allTwoFiftySixArePairwiseDistinct(env: RenderEnv) throws {
        let floor = try Self.pairwiseFloor(in: env)
        #expect(floor.value >= C.Glyph.minimumPairwiseInkDifference,
                "\(env.theme) bold=\(env.isBoldTextEnabled) floor \(floor.value) pt² at \(floor.pair)")
    }

    /// The raster frame must contain the whole drawing in every environment, or the
    /// measurement silently flatters the deck by cutting the index-stroke tips — which
    /// are exactly the discriminating pixels for the `hue` channel.
    @Test("The measurement frame covers the analytic bleed",
          .tags(.unit, .presubmission), arguments: RenderEnv.separationMatrix)
    func theMeasurementFrameCoversTheAnalyticBleed(env: RenderEnv) {
        let side = 44.0
        let bleed = C.Glyph.bleed(side: side, in: env)
        #expect(bleed.y <= CoverageMask.frameHalfMargin * side)
        #expect(bleed.x <= CoverageMask.frameHalfMargin * side)
    }

    private static func pairwiseFloor(
        in env: RenderEnv
    ) throws -> (value: Double, pair: String) {
        let masks = try Deck.all.map { try coverageMask($0, side: 44, scale: 2, env: env) }
        var floor = Double.infinity
        var pair = ""
        for i in masks.indices {
            for j in masks.index(after: i)..<masks.endIndex {
                let difference = masks[i].inkDifference(from: masks[j])
                if difference < floor {
                    floor = difference
                    pair = "\(Deck.all[i]) vs \(Deck.all[j])"
                }
            }
        }
        return (floor, pair)
    }
}
```

Create `Modules/Tests/HunchUITests/ColourIsAnOutputSubstitutionTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

/// §13.5.1's first test. It is worded `render(g, monochrome: true)` versus `render(g)`,
/// and there is no `monochrome:` parameter in this architecture — nor should there be:
/// monochrome is a PALETTE fact, and a renderer that took a flag would have two code
/// paths to keep in agreement. The equivalent, stronger claim is that colour is a pure
/// output substitution: changing which ink is used moves no geometry.
@Suite("Colour is an output substitution", .tags(.snapshot, .presubmission))
@MainActor
struct ColourIsAnOutputSubstitutionTests {

    /// Four glyphs that differ only in `hue` are four different inks over IDENTICAL body,
    /// texture and pip geometry. Outside the index register their coverage masks must
    /// agree exactly. This is simultaneously the monochrome-identity claim and §2's
    /// register-disjointness claim, and it fails the moment a `Path` is computed from a
    /// colour or a register leaks into another's space.
    @Test("Hue moves ink, never geometry",
          arguments: Glyph.Fill.allCases, Glyph.Shape.allCases)
    func hueMovesInkNeverGeometry(fill: Glyph.Fill, shape: Glyph.Shape) throws {
        let env = RenderEnv()
        for pips in Glyph.Pips.allCases {
            let masks = try Glyph.Hue.allCases.map {
                try coverageMask(Glyph(fill: fill, shape: shape, pips: pips, hue: $0),
                                 side: 44, env: env)
                    .excludingIndexRegister(side: 44, env: env)
            }
            for mask in masks.dropFirst() { #expect(mask == masks[0]) }
        }
    }

    /// Differentiate Without Colour moves no token and adds no geometry to a GLYPH — it
    /// doubles a verdict ring's gap and dashes a counterexample's rings, both of which are
    /// marks. A renderer that branched on it would be reading an axis it must ignore.
    @Test("Differentiate Without Colour does not reach the glyph", arguments: Deck.all)
    func differentiateWithoutColourDoesNotReachTheGlyph(glyph: Glyph) throws {
        let plain = try coverageMask(glyph, side: 44, env: RenderEnv())
        let differentiated = try coverageMask(
            glyph, side: 44, env: RenderEnv(isDifferentiateWithoutColorEnabled: true))
        #expect(plain.samples == differentiated.samples)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/DeckSeparationTests \
  -only-testing:HunchUITests/ColourIsAnOutputSubstitutionTests
```

They must fail on the missing `C.Glyph.minimumPairwiseInkDifference`, `RenderEnv.separationMatrix`, `CoverageMask.excludingIndexRegister` and `CoverageMask.frameHalfMargin` — not on a timeout and not on a floor of `+infinity`, which would mean the mask comparison is not running.

**Step 3 — implement**, then measure, then ratify.

**Step 4 — green, then refactor.** With one absolute rule: **never lower `T` to make a test pass.** `T` guards the one claim the accessibility case rests on; a failure means the geometry changed.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Tokens/C.swift` — append `C.Glyph.minimumPairwiseInkDifference` |
| create | `Modules/Tests/HunchUITests/DeckSeparationTests.swift` |
| create | `Modules/Tests/HunchUITests/ColourIsAnOutputSubstitutionTests.swift` |
| create | `Modules/Tests/HunchUITests/Support/RenderEnvMatrices.swift` — `RenderEnv.separationMatrix` |
| modify | `Modules/Tests/HunchUITests/Support/CoverageMask.swift` — `inkDifference(from:)`, `excludingIndexRegister(side:env:)`, `frameHalfMargin` |
| modify | `DECISIONS.md` — record `T`, its units, the six measured floors and the ratification |
| modify | `tests.json` — §13.12 items 1 and 2 |
| modify | `Presubmission.xctestplan`, `Nightly.xctestplan` — no edit needed if they filter on tags; confirm both suites are selected |

## Implementation notes

### The claim, and the one correction to canon

256 = `fill`(4) × `shape`(4) × `pips`(4) × `hue`(4), and all four channels are fully determined by geometry alone:

| Channel | Achromatic discriminator | Values |
|---|---|---|
| `fill` | ink coverage **and** texture kind {none, discrete, linear, area} | 4 |
| `shape` | silhouette corner count {0, 3, 4, 6} | 4 |
| `pips` | count of contour discs at fixed compass rays | 4 |
| `hue` | index-stroke rotation {0°, 45°, 90°, 135°} | 4 |

**Canon's luminance for `teal` is wrong and the correction is stated in the skill rather than inherited**: §13.5 quotes 0.291; computed from `Prim.okabeItoTeal` it is 0.2569, against `rose`'s 0.2930 — about eight 8-bit levels apart, not the same pixel value. It changes nothing about the design and everything about which sentence you are allowed to write: recompute either figure with `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift`; never restate one.

The correction does not weaken the argument, it moves its footing: **single-ink is the right model because it is the adversarial case**, not because two hues happen to coincide.

### Why the measurement is what it is

`CoverageMask` (T02) already renders to one ink level per pixel, normalised by the mark's own resolved ink. Three further choices, each of which makes the measurement **harder** rather than easier, and each of which a well-meaning simplification would undo:

- **The raster includes the bleed** — `S · (0.5 + 0.16)` half-box. Clipping to the S-box would cut the index-stroke tips, which are precisely the `hue` channel's discriminating pixels, and the measurement would flatter the deck. The third test above asserts the analytic bleed fits inside the frame in every environment, so the two cannot drift.
- **The environment matrix is measured, not just the dark default.** Six configurations at S = 44: dark; dark + Bold Text; dark with bloom off; light; High Contrast; High Contrast + Bold Text. **The floor is in the last one and it is 44 % below the dark default.**
- **The gate is the minimum over 32,640 pairs, not a percentile.** A deck where one pair is indistinguishable is a deck with 255 glyphs.

Units: **pt² of ink difference**, not raw 8-bit L1. §13.5.1 words the test in 8-bit L1 at 44 pt @2×, but that number moves the moment anyone changes the raster or the scale and the constant is then silently about a different thing. The two are one multiplication apart and the test message should print both:

```
L1_8bit  =  T_pt²  ×  255  ×  scale²          (8,160 for T = 8.0 pt² at @2×)
```

### `RenderEnv.separationMatrix`

```swift
extension RenderEnv {
    /// The six configurations of `triple-encoding-proof.md` §4. Not the gallery's matrix
    /// (T09), which is 3 themes × {normal, Bold Text, Reduce Motion} — different question,
    /// different set, and merging them would silently drop the bloom-off row.
    static let separationMatrix: [RenderEnv] = [
        RenderEnv(),
        RenderEnv(isBoldTextEnabled: true),
        RenderEnv(isReduceTransparencyEnabled: true),          // dark, bloom off
        RenderEnv(theme: .light),
        RenderEnv(theme: .highContrast),
        RenderEnv(theme: .highContrast, isBoldTextEnabled: true),
    ]
}
```

### What you should measure, and what to do with it

The analytic model's floors, from `triple-encoding-proof.md` §4 — these are what the shipped renderer is being ratified against:

| Environment | min pt² | margin over T = 8.0 | limiting pair |
|---|---|---|---|
| dark, bloom off | 16.52 | 106 % | `hollow/hexagon/two/frost` vs `…/three/frost` |
| dark | 15.95 | 99 % | `hollow/circle/two/frost` vs `…/three/frost` |
| dark + Bold Text | 13.82 | 73 % | same |
| light | 13.05 | 63 % | `hollow/hexagon/two/frost` vs `…/three/frost` |
| High Contrast | 10.36 | 29 % | `hollow/circle/two/frost` vs `…/three/frost` |
| **High Contrast + Bold Text** | **8.94** | **12 %** | same |

High Contrast is the worst case, counter-intuitively: it adds the stroke offset to everything, so the silhouette under a pip node is already inked and the node's *marginal* contribution falls; Bold Text multiplies on top. The setting that exists to make marks more legible makes the `pips` channel measurably less separable — and it is still 12 % clear.

**The ratification procedure, in order:**

1. Adopt the Swift tests above and run the nightly matrix once. Record the shipped renderer's floor **per environment**, and the limiting pair in each.
2. If it agrees with the table to within a few percent, keep `T = 8.0` and it is ratified.
3. If it does not, **the disagreement between the two rasterisers is the finding.** `reference-renderer.js` is an analytic model of the draw list; SwiftUI antialiasing, subpixel coverage rules and miter handling all differ slightly. Chase the disagreement — a limiting pair that moves to a different channel is a geometry bug, not a calibration issue — before touching `T`.
4. Afterwards, never lower it.

Cross-check against the analytic model while you are there:

```bash
node .claude/skills/hunch-glyph-renderer/scripts/check-coverage-separation.js          # ~85 s, six environments
node .claude/skills/hunch-glyph-renderer/scripts/check-coverage-separation.js --sweep  # the size table
```

### The channel ranking is a finding to preserve, not a curiosity

| pt² | change | |
|---|---|---|
| **15.95** | `pips` two ↔ three | ← the floor for the whole deck |
| 40.73 | `hue` teal ↔ frost | the cheapest 45° rotation |
| 53.46 | `hue` **teal ↔ rose** | canon's feared pair — measured, the *third* most separated hue pair |
| 215.67–322.80 | `shape`, all six pairs | 14× the floor |

Three readings, all of which belong in `DECISIONS.md` beside `T`: **`pips` is the weakest channel at 44 pt and above, not `hue`** — so any future economy must not come out of `pips`; the floor is `two ↔ three` for a *geometric* reason (`geometry.md` §5.1's overlap), so `pipRadius`, the index length and the `0.43·S` register offset are the three numbers to re-measure if any of them moves; and **`shape` is 14× the floor** and is the channel to spend from if a variant ever needs one.

### The deck is not provably separable at 24 pt, and that is survivable

`--sweep` shows the floor collapsing to **1.82 pt² at S = 24**, where the `fill` channel gives out: the triangle's inset interior has an apothem of 2.19 pt and holds neither dots nor stripes. §13.5's *"identically at every size from 24 pt to 220 pt"* is true of the arithmetic and false of the raster.

This is survivable only because **no shipped site draws a glyph below 36 pt** — the smallest are the SIEVE tail and the ECHO seed. 24 pt appears in §11.2 as a *rule-tile skeleton* silhouette, which is not a glyph. **Record it in `DECISIONS.md` as a floor on the vocabulary**: 36 pt is the smallest a glyph may ever be drawn, and a new site that wants something smaller gets a different mark, not a shrunken one. Without the entry, someone adds a 28 pt glyph in E15 and nothing fails.

### Cost, and where it runs

32,640 pairs × ~13,456 px is ≈440 M byte operations per environment. Keep `samples` a `[UInt8]` and accumulate the difference in a `UInt64` — a `[Double]` mask makes it minutes instead of seconds. Render the 256 masks **once per environment** and reuse them across all pairs; rendering inside the inner loop is the difference between a second and an hour.

Neither suite enters `HunchCore`'s ten-second budget: both are in the `Modules` package, both are `.snapshot`-tagged, the worst-environment case is `.presubmission` and the six-environment matrix is `.nightly`. Confirm with `bash .claude/skills/hunch-swift-testing/scripts/current-state.sh` that both tags exist in `ModulesTestSupport` before using them.

### `tests.json`

Add the two §13.12 entries — item 1 (pairwise-distinct greyscale rasters) and item 2 (coverage-mask identity) — each naming its suite and its command, and each recording `T` and the measured floor. `tests.json` is a structured pass/fail invariant list; an entry is never deleted or weakened to reach green.

## Acceptance criteria

- [ ] `C.Glyph.minimumPairwiseInkDifference` exists with a doc comment stating **pt² at S = 44**, its 8-bit L1 equivalent, and that it is measured rather than asserted.
- [ ] `xcodebuild test … -only-testing:HunchUITests/DeckSeparationTests` green at `-testPlan Presubmission` (worst environment) and at `-testPlan Nightly` (all six).
- [ ] `xcodebuild test … -only-testing:HunchUITests/ColourIsAnOutputSubstitutionTests` green — 16 fill × shape cases × 4 pips, and all 256 under Differentiate Without Colour.
- [ ] `DECISIONS.md` carries an entry for `T` with: the value, the units and the conversion, the six measured floors from the **shipped** renderer beside the analytic ones, the limiting pair in each, the channel ranking's three readings, and the 36 pt vocabulary floor.
- [ ] `tests.json` carries §13.12 items 1 and 2 with their commands and current status.
- [ ] `node .claude/skills/hunch-glyph-renderer/scripts/check-coverage-separation.js` has been run and its output pasted into the PR body beside the Swift figures.
- [ ] `grep -rn 'minimumPairwiseInkDifference' Modules/Sources` returns nothing — `T` is read by tests, never by drawing code.
- [ ] Fast suite still under 10 s (unchanged: nothing here is in `HunchCore`).

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T06: the triple-encoding proof — T measured, ratified and recorded"`

## Out of scope

- **Changing any geometry to improve a floor.** If the measurement disagrees with the model, the disagreement is the finding; the geometry is T01–T05's and is already asserted by their own tests.
- **`T` as a ratio for the sigil set** — E15·T09. `hunch-sigil-drawing` reuses it as `8.0 / 44² = 0.00413 · S²`, and a sigil set at another size re-derives its own floor with the same script rather than assuming this one.
- **The greyscale *rendering* of the gallery** — T09. This task measures a coverage mask; the gallery shows a designer a greyscale sheet, which is a different artefact for a different purpose.
- **The High Contrast audit of every screen and the 9.7 : 1 floor** — E19·T09.
- **`performAccessibilityAudit`, the AX5 × 5-locale snapshot and the other eleven §13.12 gates** — E19·T11.
- **Any change to `check-coverage-separation.js` or the skill's reference files.** They are the design-time model; the repository is the shipped truth, and when they disagree the resolution is written into `DECISIONS.md`, not into the skill.
