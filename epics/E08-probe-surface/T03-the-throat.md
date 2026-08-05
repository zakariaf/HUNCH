# T03 — The throat

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 PROBE → *The throat* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `C.Throat`'s members (`glyphSide`, `glyphSideLarge`, `submitContraction`, `registerCrossfade`) are L2 and are created here; the ring's expansion factor is **not** a `C.Throat` member and the skill's layering rule is what stops you declaring it twice. Load it first. |
| `hunch-bench-instruments` | `references/throat.md` is this component's normative file: the three sizes, the four presentation states, the read-only ruling, the well's headroom arithmetic and the eight ways to get it wrong. |
| `hunch-glyph-renderer` | §3 of `throat.md` imposes a *shape requirement on the renderer* — the four registers must be four separately drawable passes over one geometry, or "only the changed register animates" is unimplementable. This task is where that requirement is cashed. |

## Objective

`ThroatView` draws the live draft glyph at 96 pt (128 pt on Pro Max) inside a well that clears the transient admit ring, wearing the seed's dashed frame and backward chevron before probe 1, and animating **only** the register a Dial edit changed. A horizontal swipe on it steps the last-touched attribute by ±1, wrapping off, with an equivalent `.adjustable` action for VoiceOver.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.2 | The region and the two glyph sizes |
| `GAME_DESIGN.md` | §6.3 | The throat *is* the draft; the swipe steps the last-touched attribute ±1, wrapping off; only the changed register animates, and why that is epistemics rather than polish |
| `GAME_DESIGN.md` | §6.5 | The submit contraction at t = 0 and the adjudication hold's rotating hairline aperture, constant regardless of verdict, band or contextuality |
| `GAME_DESIGN.md` | §6.6 layer 1 | The seed glyph in the throat, dashed frame plus backward chevron, in every band |
| `GAME_DESIGN.md` | §12.8 | Tier 3 — everything above y = 220 is read-only; the throat's one gesture is legal only because the Dial can do the same thing |
| `GAME_DESIGN.md` | §13.10 | Traits `.image`, `.updatesFrequently`, `.adjustable`; label, value and the ±1 rank action |
| `hunch-bench-instruments` | `references/throat.md` §1–§8 | Everything above, as geometry |
| `hunch-shared-marks` | `references/ghost-frame.md`, `references/verdict-ring.md` | `GhostFrame.draw`, `VerdictRing.draw` and `C.VerdictRing.transientAdmitRadius` — called here, never redrawn |

## TDD — the test comes first

**Step 1 — write the failing test.** Two suites, because the stepping rule is model behaviour and the headroom rule is geometry.

`Modules/Tests/LoomFeatureTests/DraftSteppingTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import LoomFeature

@Suite("The draft steps by one rank and wraps off", .tags(.unit, .presubmission))
@MainActor
struct DraftSteppingTests {

    @Test("A swipe steps the last-touched attribute by ±1 and changes nothing else")
    func stepsOneAttribute() {
        let round = Fixtures.round()
        round.select(.pips, rank: 2)                 // a Dial tap sets the last-touched attribute
        let before = round.draft

        round.stepDraft(by: 1)

        #expect(round.draft.pips.rank == before.pips.rank + 1)
        #expect(round.draft.fill == before.fill)
        #expect(round.draft.shape == before.shape)
        #expect(round.draft.hue == before.hue)
        #expect(round.changedRegister == .pips)
    }

    @Test("Wrapping is off: the ends are sticky, not circular",
          arguments: Glyph.Attribute.allCases)
    func wrappingIsOff(_ attribute: Glyph.Attribute) {
        let round = Fixtures.round()

        round.select(attribute, rank: 1)
        round.stepDraft(by: -1)
        #expect(round.draft[attribute].rank == 1)     // clamped at the bottom, never wrapped to 4

        round.select(attribute, rank: 4)
        round.stepDraft(by: +1)
        #expect(round.draft[attribute].rank == 4)     // clamped at the top, never wrapped to 1
    }

    @Test("The last-touched attribute is the most recent edit, not the first")
    func lastTouchedIsTheNewest() {
        let round = Fixtures.round()
        round.select(.fill, rank: 3)
        round.select(.hue, rank: 2)
        round.stepDraft(by: 1)
        #expect(round.changedRegister == .hue)
    }

    @Test("Before any edit the gesture is live, not dead")
    func lastTouchedHasADefault() {
        let round = Fixtures.round()
        let before = round.draft
        round.stepDraft(by: 1)
        #expect(round.draft != before)                // §6.3's gesture works from the first frame
        #expect(round.changedRegister == .fill)       // canonical order's first — see DECISIONS.md
    }

    @Test("A step that changes nothing reports no changed register")
    func aClampedStepAnimatesNothing() {
        let round = Fixtures.round()
        round.select(.shape, rank: 4)
        round.stepDraft(by: 1)
        #expect(round.changedRegister == nil)         // nothing moved, so nothing crossfades
    }
}
```

`Modules/Tests/HunchUITests/ThroatGeometryTests.swift`:

```swift
import Testing
import CoreGraphics
import ModulesTestSupport
import HunchUI

@Suite("The throat well clears the transient admit ring", .tags(.unit, .presubmission))
struct ThroatGeometryTests {

    @Test("The glyph side is 96 on the compact device and 128 on the large one")
    func nominalSides() {
        #expect(ThroatView.side(in: .reference(.compact), artScale: 1) == C.Throat.glyphSide)
        #expect(ThroatView.side(in: .reference(.large), artScale: 1) == C.Throat.glyphSideLarge)
    }

    @Test("The ring never clips, at every art scale on both devices",
          arguments: [PlaySurfaceLayout.reference(.compact), .reference(.large)],
          [1.0, 1.2, 1.35])
    func theRingFitsTheRegion(_ layout: PlaySurfaceLayout, _ artScale: Double) {
        let side = ThroatView.side(in: layout, artScale: artScale)
        let ringDiameter = 2 * C.Glyph.radius(side: side) * C.VerdictRing.transientAdmitRadius
        #expect(ringDiameter <= layout.throat.height)
        #expect(side > 0)
    }

    @Test("Art scale grows the glyph until the region binds, and then stops")
    func artScaleIsClampedByTheRegion() {
        let layout = PlaySurfaceLayout.reference(.compact)
        let plain = ThroatView.side(in: layout, artScale: 1)
        let scaled = ThroatView.side(in: layout, artScale: 1.35)
        #expect(scaled >= plain)
        #expect(scaled <= C.Throat.glyphSide * 1.35)
    }

    @Test("The ring's expansion factor is declared once, by the ring")
    func noSecondDeclaration() {
        // `C.Throat` must not carry a ring headroom member; it moves when §13.7.2 moves.
        #expect(C.VerdictRing.transientAdmitRadius > 1)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/DraftSteppingTests -only-testing:HunchUITests/ThroatGeometryTests
```

Expect `value of type 'Round' has no member 'stepDraft'` and `cannot find 'ThroatView' in scope`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/ThroatView.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| create | `Modules/Tests/LoomFeatureTests/DraftSteppingTests.swift` |
| create | `Modules/Tests/HunchUITests/ThroatGeometryTests.swift` |
| modify | `DECISIONS.md` |

## Implementation notes

**The model half, on `Round`.** Three additions, all trivial and all testable without a view:

```swift
/// The attribute the player most recently moved. Seeded to `.fill` — canonical order's first —
/// so the throat swipe is live on the first frame rather than a dead gesture until a Dial tap.
public private(set) var lastTouched: Glyph.Attribute = .fill

/// The register that changed on the last edit, or nil if nothing moved. `ThroatView` crossfades
/// exactly this pass and holds the other three (§6.3). Cleared once the crossfade is spent.
public private(set) var changedRegister: Glyph.Attribute?

public func select(_ attribute: Glyph.Attribute, rank: Int)   // a Dial tap
public func stepDraft(by delta: Int)                          // a throat swipe, ±1, wrapping off
```

`stepDraft(by:)` clamps: `newRank = min(4, max(1, current + delta))`. **Wrapping off is a decision, not an omission** — §6.3 says so in three words ("wrapping off"), and a wrapping ramp would make a swipe at rank 4 land on rank 1, which reads as a different glyph arriving rather than as a controlled variation. If the rank moved, set `changedRegister`; if the clamp bound, leave it `nil` so nothing animates.

**Only the changed register animates — the hard requirement.** §6.3: *"When a Dial cell changes the fill, the fill texture crossfades and the silhouette, contour nodes and index stroke hold perfectly still. This is not polish: it is what makes controlled variation visible as an act."* The naive implementation — crossfading the whole glyph — looks fine in isolation and destroys the epistemics, because change-exactly-one-attribute-hold-three-fixed is *the* inductive move (§4.1).

The consequence is on the renderer, not on this view: `GlyphCanvas` must accept a `changedRegister: Glyph.Attribute?` and draw its four passes such that one can crossfade while three hold. E04·T05 built the four-pass draw order; if it exposes only `draw(glyph:)`, extend **it** with the parameter rather than compositing two glyph canvases here — two canvases means two bloom beds in a region that is allowed exactly one (`throat.md` §1). The crossfade is `C.Throat.registerCrossfade`, which is a different clock from the verdict beat and from the rings' own durations; keep the three separate.

**The well's size, and the one arithmetic that is easy to get wrong.** The region must clear the *transient admit ring*, whose radius is `C.VerdictRing.transientAdmitRadius × R` where `R = C.Glyph.radius(side:)` — **not** `1.35 × S`. On the SE that is `2 × 0.37 × 96 × 1.35 ≈ 95.9` pt inside a 112 pt region. Do **not** declare 1.35 as a `C.Throat` member; it is the ring's and it moves when §13.7.2 moves.

Because `env.artScale` reaches 1.35 and the region does not grow, `side` is clamped by the region:

```swift
static func side(in layout: PlaySurfaceLayout, artScale: Double) -> Double {
    let nominal = layout.deviceClass == .large ? C.Throat.glyphSideLarge : C.Throat.glyphSide
    let ceiling = layout.throat.height / (2 * C.Glyph.radiusRatio * C.VerdictRing.transientAdmitRadius)
    return min(nominal * artScale, ceiling)
}
```

Also size against the glyph's **true vertical extent**, not `2R`: the index stroke is centred `0.43·S` below the body centre and lengthens under High Contrast (`hunch-glyph-renderer/references/geometry.md` owns the ratio). `throat.md` §7 and §8 both name this.

**States.** `Presentation` is `.live | .animating | .empty | .idle`. `.empty` and `.idle` are ECHO's and the Frame's and are declared now so those epics extend a state rather than building a second throat; this task ships `.live` and `.animating`. The seed's `GhostFrame.draw` is drawn when `isSeed` — i.e. at probe 0, in **every** band, which is §6.6 layer 1 and is asserted in T10.

**The adjudication aperture** is the throat's signature state: nothing moves but a hairline aperture rotating in the ring, for a hold that is *constant regardless of verdict, band or contextuality*. The view must not be able to make it conditional — take the hold's presence from `phase == .adjudicating`, never from the verdict or the law. T06 owns the clock; this task owns the drawing.

**Read-only, deliberately.** The throat sits above §12.8's y = 220 line. Its one gesture is a convenience path with a full Dial equivalent, which is what makes the placement legal — adding a tap action here breaks the reach argument for the whole surface. The `Canvas` layer takes `.allowsHitTesting(false)` and the throat's own `.contentShape(.rect)` carries the gesture; a `Canvas` that swallowed touches would eat the swipe.

**Accessibility.** `.accessibilityElement(children: .ignore)`, traits `.image` + `.updatesFrequently` + `.adjustable`, and an `accessibilityAdjustableAction` that calls the same `stepDraft(by:)` the gesture does — one behaviour, two entry points. The label and value strings are `hunch-accessibility`'s and land in E19; wire the modifiers now with the `Loc` accessors so E19 fills catalog entries rather than restructuring the view.

**Bloom.** The throat is one of exactly three bloom regions — throat, ribbon, tail — each getting one blurred bed layer per frame, never one per glyph. The pass is E04·T05's; the *region boundary* is this file's.

## Acceptance criteria

- [ ] `DraftSteppingTests` (5 cases) and `ThroatGeometryTests` (4 cases) green on both destinations.
- [ ] `grep -n 'transientAdmitRadius\|1\.35' HunchCore/Sources/Tokens/C.swift` shows the factor declared exactly once, under `C.VerdictRing`.
- [ ] `GlyphCanvas` takes a `changedRegister` parameter and a snapshot-gallery row (E04·T09) shows one register crossfading with three held — checked by eye once, in the DEBUG gallery, and recorded in `PROGRESS.md`.
- [ ] `grep -n 'Text(\|Label(\|AttributedString' Modules/Sources/HunchUI/ThroatView.swift` returns nothing, and `bash Scripts/check-source-hygiene.sh` passes checks 7, 9 and 10.
- [ ] `grep -n 'onTapGesture' Modules/Sources/HunchUI/ThroatView.swift` returns nothing — the throat is read-only apart from the swipe.
- [ ] `DECISIONS.md` records `lastTouched` defaulting to `.fill` and the reason (a gesture that is dead until a Dial tap is a gesture the player will not find).

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; both new filters green.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T03: the throat — live draft, single-register animation, ±1 swipe"`

## Out of scope

- The verdict ring's animation and the beat's timing — **T06**. This task draws the ring in whatever state it is handed and passes `ringProgress` through.
- The Dial that sets `lastTouched` from a cell tap — **T04**. This task ships `select(_:rank:)` on `Round` because the stepping test needs it; the ramp that calls it is next.
- The Frame's idle Loom (`.idle`) and the play-key sigil at 24 pt — **E17·T03**.
- ECHO's empty throat (`.empty`) — **E13·T04**.
- The glyph's own four registers, the bloom pass and the High Contrast index-stroke substitution — **E04·T02–T05**, **E19·T09**.
- VoiceOver wording — **E19·T02**. Wire the modifiers; do not write the strings.
