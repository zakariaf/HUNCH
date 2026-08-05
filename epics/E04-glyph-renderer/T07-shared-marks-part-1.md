# T07 — Shared marks, part 1

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 PROBE → **Admit / reject encoding** · §14.1 PROBE → **The Seal + machined bar** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Marks are `accent.*` or `stroke.*` and **never** a `HueColor` — the register split is a distinct Swift type, so a miss will not compile. The skill also owns `env.weight(_:)`, which is how a mark inherits Bold Text and High Contrast without reading either setting, and the L2 rule that puts `C.VerdictRing`, `C.GhostFrame` and `C.MachinedBar` in `C.swift` holding geometry only. |
| `hunch-shared-marks` | Owns all seven marks and the one-owner rule this task exists to establish. Read `references/ownership.md` first (the declaration, the site census, the shared signature, the checks), then `references/verdict-ring.md`, `references/ghost-frame.md` and `references/machined-bar.md` in full. Run its Step 0 block before writing: if a mark has two declarations, stop and merge before drawing anything. |

## Objective

Three of the seven shared idioms get exactly one owning `public static func draw` each, under `Modules/Sources/HunchUI/Marks/`: the verdict ring in all of its states, the ghost frame that carries the whole contextual grammar, and the machined bar that `DESIGN-SYSTEM-SCOPE.md` §2(g) names as the headline example of an idiom specified twice with no declared owner. Before this task, "the identical drawing used for the barred Seal" is a sentence in §12.4; after it, it is a function call, a row in `SPEC.md`, and two greps in `check-source-hygiene.sh` that fail the build on a second declaration.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.7.2 | admit expands and stays closed, reject contracts and breaks; the ring's radii and weights; the decision that direction and closure *are* the encoding and colour, tone and haptic are three redundant copies; the gap doubles under Differentiate Without Colour |
| `GAME_DESIGN.md` | §4.5 | the counterexample's two rings — solid is the Loom's verdict, dashed is yours — on one glyph |
| `GAME_DESIGN.md` | §11.3, §11.8 | the Codex re-strike rim (five rings, then one filled meaning 5+) and the Anomaly ribbon cell's six day states |
| `GAME_DESIGN.md` | §4.2, §4.3, §8.4, §12.4 | the ghost frame's six sites, and the sentence its diegetic claim rests on |
| `GAME_DESIGN.md` | §4.3, §12.4, §13.3 | the machined bar: `heavy` 4 pt, "physically barred", "the identical drawing", no error text and no modal |
| `hunch-shared-marks` | `references/ownership.md` §§1–8 | the census, the file set, the shared signature and its six invariants, the `C` namespace map, the promotion rule, the checks |
| `hunch-shared-marks` | `references/verdict-ring.md` | the radii, the break geometry, the states table, the `Day` mapping, the environment behaviour, `C.VerdictRing` |
| `hunch-shared-marks` | `references/ghost-frame.md` | the frame, the chevron, why `[3, 3]` never scales, why `stroke.secondary` and not primary or hairline |
| `hunch-shared-marks` | `references/machined-bar.md` | the overhang, butt caps, horizontal-always, the retraction and its RTL reversal |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Create `Modules/Tests/HunchUITests/Marks/VerdictRingTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Verdict ring", .tags(.snapshot, .presubmission))
@MainActor
struct VerdictRingTests {

    private static let radius = 35.52          // a 96 pt throat's body radius
    private static let centre = CGPoint(x: 60, y: 60)

    /// The gaps fall on the INTER-CARDINALS. Pips are contour nodes on exactly the compass
    /// rays (§2, §13.5), so a gap on a pip ray would read as a missing pip — the one
    /// collision the register-disjointness rule exists to prevent.
    @Test("A broken ring gaps on the diagonals and never on a compass ray")
    func aBrokenRingGapsOnTheDiagonals() throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 120, height: 120)) { context in
            VerdictRing.draw(into: context, centre: Self.centre, bodyRadius: Self.radius,
                             state: .reject, role: .settled, env: env)
        }
        let ring = C.VerdictRing.settledRejectRadius * Self.radius
        for compass in [-90.0, 0, 90, 180] {
            #expect(raster.coverage(at: Self.centre, radius: ring, degrees: compass) > 0.5)
        }
        for diagonal in [-45.0, 45, 135, -135] {
            #expect(raster.coverage(at: Self.centre, radius: ring, degrees: diagonal) < 0.1)
        }
    }

    /// Differentiate Without Colour doubles the gap. That is the ONLY thing it changes.
    @Test("Differentiate Without Colour doubles the gap and changes nothing else")
    func differentiateWithoutColourDoublesTheGap() throws {
        func gapDegrees(_ env: RenderEnv) throws -> Double {
            try markRaster(size: CGSize(width: 120, height: 120)) { context in
                VerdictRing.draw(into: context, centre: Self.centre, bodyRadius: Self.radius,
                                 state: .reject, role: .settled, env: env)
            }
            .angularGap(at: Self.centre,
                        radius: C.VerdictRing.settledRejectRadius * Self.radius)
        }
        let plain = try gapDegrees(RenderEnv())
        let differentiated = try gapDegrees(RenderEnv(isDifferentiateWithoutColorEnabled: true))
        #expect(isApproximatelyEqual(differentiated, 2 * plain, absoluteTolerance: 2))
    }

    /// Admit expands and stays closed; reject contracts and breaks. The settled radii are
    /// §13.7.4's static-substitution radii, so the Reduce Motion crossfade lands on the
    /// state the surface will hold.
    @Test("Admit settles outside the body and reject settles on it")
    func admitSettlesOutsideTheBodyAndRejectSettlesOnIt() {
        #expect(C.VerdictRing.settledAdmitRadius > 1)
        #expect(C.VerdictRing.settledRejectRadius == 1)
        #expect(C.VerdictRing.transientAdmitRadius > C.VerdictRing.settledAdmitRadius)
    }

    /// A twin is the verdict's ring DOUBLED — the pair must read as one unit at 36 pt.
    /// Counted as ink runs along an outward ray, which is the same reading a player makes.
    @Test("A twin draws two concentric rings and a plain verdict draws one",
          arguments: [true, false])
    func aTwinDrawsTwoConcentricRings(admitted: Bool) throws {
        let env = RenderEnv()
        func rings(_ state: VerdictRing.State) throws -> Int {
            try markRaster(size: CGSize(width: 160, height: 160)) { context in
                VerdictRing.draw(into: context, centre: Self.centre, bodyRadius: Self.radius,
                                 state: state, role: .settled, env: env)
            }
            .inkRunCount(alongRayFrom: Self.centre, degrees: -90)
        }
        #expect(try rings(admitted ? .admit : .reject) == 1)
        #expect(try rings(.twin(admitted: admitted)) == 2)
    }

    /// §11.3: five rings, then ONE FILLED ring meaning 5+. Not six rings, not a numeral.
    @Test("The re-strike rim caps at five and then fills",
          arguments: [1, 3, 5, 6, 12])
    func theRestrikeRimCapsAtFiveAndThenFills(count: Int) throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 200, height: 200)) { context in
            VerdictRing.draw(into: context, centre: Self.centre, bodyRadius: Self.radius,
                             state: .restrike(count: count), role: .settled, env: env)
        }
        let runs = raster.inkRunCount(alongRayFrom: Self.centre, degrees: -90)
        #expect(runs == (count > C.VerdictRing.restrikeCap ? 1 : count))
    }

    /// A mark never mutates the caller's context. One that sets `opacity` on it dims the
    /// whole host — which is how a Bench dims on one hatched cell.
    @Test("The ring never leaks graphics state")
    func theRingNeverLeaksGraphicsState() throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 160, height: 160)) { context in
            VerdictRing.draw(into: context, centre: Self.centre, bodyRadius: Self.radius,
                             state: .reject, role: .transient, progress: 0.4, env: env)
            context.fill(Path(CGRect(x: 0, y: 0, width: 10, height: 10)),
                         with: .color(env.palette.stroke.primary.color))
        }
        #expect(raster.meanCoverage(in: CGRect(x: 2, y: 2, width: 6, height: 6)) > 0.98)
    }
}
```

Create `Modules/Tests/HunchUITests/Marks/GhostFrameTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Ghost frame", .tags(.snapshot, .presubmission))
@MainActor
struct GhostFrameTests {

    /// The dash is a texture pinned in POINTS at every size. A dash that scaled with the
    /// box would make the 36 pt ECHO seed and the 168 pt DRIFT sigil different marks, and
    /// §4.2's "the player has already met that exact mark" stops being true.
    @Test("The dash period is identical at every size", arguments: [36.0, 44, 168])
    func theDashPeriodIsIdenticalAtEverySize(side: Double) throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: side + 20, height: side + 20)) { ctx in
            GhostFrame.draw(into: ctx,
                            box: CGRect(x: 10, y: 10, width: side, height: side), env: env)
        }
        let period = raster.dashPeriod(alongEdgeY: 10 + env.weight(.thin) / 2,
                                       from: 10, to: 10 + side)
        #expect(isApproximatelyEqual(period, C.GhostFrame.dash.reduce(0, +),
                                     absoluteTolerance: 0.6))
    }

    /// The chevron means "earlier in reading order", so it mirrors under RTL while the
    /// glyph inside the frame never does. Getting this backwards swaps teal and rose in
    /// Arabic — the exact failure §2 names.
    @Test("The chevron mirrors under RTL and the frame does not")
    func theChevronMirrorsUnderRTLAndTheFrameDoesNot() throws {
        let env = RenderEnv()
        let box = CGRect(x: 10, y: 10, width: 44, height: 44)
        func raster(_ layout: LayoutDirection) throws -> MarkRaster {
            try markRaster(size: CGSize(width: 64, height: 64)) { ctx in
                GhostFrame.draw(into: ctx, box: box, layout: layout, env: env)
            }
        }
        let ltr = try raster(.leftToRight)
        let rtl = try raster(.rightToLeft)
        #expect(ltr.samples != rtl.samples)
        #expect(ltr.samples == rtl.mirroredHorizontally().samples)
    }

    /// The chevron is one weight heavier than the frame: a dashed 1 pt rectangle and a
    /// 1 pt chevron read as one broken outline, and the chevron has to be the thing that
    /// POINTS. Its size is proportional with a floor that holds the 36 pt ECHO seed.
    @Test("The chevron is heavier than the frame and floored at the small end")
    func theChevronIsHeavierThanTheFrameAndFlooredAtTheSmallEnd() throws {
        let env = RenderEnv()
        #expect(env.weight(.bodySm) > env.weight(.thin))
        func armReach(_ side: Double) -> Double {
            2 * max(C.GhostFrame.chevronFloor, C.GhostFrame.chevronRatio * side)
        }
        #expect(armReach(36) >= 2 * C.GhostFrame.chevronFloor)     // the floor holds it
        #expect(armReach(168) > armReach(44))                      // and it scales above it
        #expect(armReach(168) < 168 / 2)                           // never past the box centre
    }

    /// `role` exists so a call site declares which site it is and so the gallery can label
    /// the row. It must NOT branch the geometry: a depiction that is not the mark is not
    /// a depiction (§4.2's diegetic claim).
    @Test("Role does not branch the geometry", arguments: GhostFrame.Role.allCases)
    func roleDoesNotBranchTheGeometry(role: GhostFrame.Role) throws {
        let env = RenderEnv()
        let box = CGRect(x: 10, y: 10, width: 44, height: 44)
        let reference = try markRaster(size: CGSize(width: 64, height: 64)) { ctx in
            GhostFrame.draw(into: ctx, box: box, role: .marker, env: env)
        }
        let subject = try markRaster(size: CGSize(width: 64, height: 64)) { ctx in
            GhostFrame.draw(into: ctx, box: box, role: role, env: env)
        }
        #expect(subject.samples == reference.samples)
    }
}
```

Create `Modules/Tests/HunchUITests/Marks/MachinedBarTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Machined bar", .tags(.snapshot, .presubmission))
@MainActor
struct MachinedBarTests {

    private static let key = CGRect(x: 20, y: 20, width: 168, height: 108)

    /// The overhang is the whole idea: a bar inset inside the control reads as a
    /// strikethrough of its contents; a bar running past both edges reads as something
    /// DROPPED ACROSS the mechanism from outside it (§4.3, §12.4).
    @Test("The bar overhangs both ends and sits on the midline")
    func theBarOverhangsBothEndsAndSitsOnTheMidline() throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 220, height: 160)) { ctx in
            MachinedBar.draw(into: ctx, key: Self.key, env: env)
        }
        let extent = raster.horizontalInkExtent(atY: Self.key.midY)
        let overhang = C.MachinedBar.overhangRatio * Self.key.width
        #expect(isApproximatelyEqual(extent.lower, Self.key.minX - overhang,
                                     absoluteTolerance: 0.6))
        #expect(isApproximatelyEqual(extent.upper, Self.key.maxX + overhang,
                                     absoluteTolerance: 0.6))
        // Butt caps: the length is width + 2·overhang, not + one stroke width.
        #expect(isApproximatelyEqual(extent.upper - extent.lower,
                                     Self.key.width + 2 * overhang, absoluteTolerance: 0.6))
        #expect(raster.meanCoverage(in: CGRect(x: Self.key.midX - 4, y: Self.key.minY + 4,
                                               width: 8, height: 8)) < 0.02)
    }

    /// `retraction` is reveal beat 0 and the bar owns no clock. Under RTL the travel
    /// reverses, because "trailing" is a reading-order word.
    @Test("Retraction travels toward the trailing edge in both directions")
    func retractionTravelsTowardTheTrailingEdge() throws {
        let env = RenderEnv()
        func extent(_ layout: LayoutDirection) throws -> ClosedRange<Double> {
            let raster = try markRaster(size: CGSize(width: 220, height: 160)) { ctx in
                MachinedBar.draw(into: ctx, key: Self.key, retraction: 0.5,
                                 layout: layout, env: env)
            }
            let measured = raster.horizontalInkExtent(atY: Self.key.midY)
            return measured.lower...measured.upper
        }
        #expect(try extent(.leftToRight).upperBound < Self.key.maxX)
        #expect(try extent(.rightToLeft).lowerBound > Self.key.minX)
    }

    /// A fully retracted bar is not a faint bar. It is nothing.
    @Test("A fully retracted bar draws nothing")
    func aFullyRetractedBarDrawsNothing() throws {
        let env = RenderEnv()
        let raster = try markRaster(size: CGSize(width: 220, height: 160)) { ctx in
            MachinedBar.draw(into: ctx, key: Self.key, retraction: 1, env: env)
        }
        #expect(raster.maximumCoverage() < 0.02)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/VerdictRingTests \
  -only-testing:HunchUITests/GhostFrameTests \
  -only-testing:HunchUITests/MachinedBarTests
```

Failures must be missing `VerdictRing` / `GhostFrame` / `MachinedBar`, missing `C.VerdictRing` / `C.GhostFrame` / `C.MachinedBar` members, and a missing `MarkRaster` helper.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/Marks/VerdictRing.swift` |
| create | `Modules/Sources/HunchUI/Marks/GhostFrame.swift` |
| create | `Modules/Sources/HunchUI/Marks/MachinedBar.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `C.VerdictRing`, `C.GhostFrame`, `C.MachinedBar` |
| create | `Modules/Tests/HunchUITests/Support/MarkRaster.swift` — the mark-drawing rasteriser and its readers |
| create | `Modules/Tests/HunchUITests/Marks/VerdictRingTests.swift` |
| create | `Modules/Tests/HunchUITests/Marks/GhostFrameTests.swift` |
| create | `Modules/Tests/HunchUITests/Marks/MachinedBarTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — add checks 11 and 12 |
| modify | `SPEC.md` — open the drawing-ownership table with the first three rows |

## Implementation notes

### The rule this task establishes

**Each of the seven marks is drawn by exactly one `public static func draw` in exactly one file under `Modules/Sources/HunchUI/Marks/`. Every other file calls it.** The GDD specifies the machined bar twice — §4.3 for the Seal and §12.4 for the mode key, where it says "the identical drawing" and then draws it again — and that is the failure mode. Three consequences this prevents, each a real bug:

1. **The Bench and the Codex cannot disagree.** A Codex page draws rule-tiles at 0.78× with the same ghost frame and the same tick row. A second implementation "for the archive" drifts from the live one and the archive stops being a record of what was played.
2. **The machined bar cannot become two bars.**
3. **Reduce Motion, High Contrast and Bold Text get applied once.** A private copy of a mark is a copy that misses the next accessibility rule.

The site census — **larger than `DESIGN-SYSTEM-SCOPE.md` §2(g) reports**, which is itself part of the finding — is `ownership.md` §2. For this task: verdict ring **8** sites, ghost frame **6** (the scope says four), machined bar **2**.

### The shared signature, and its six invariants

```swift
public static func draw(
    into context: GraphicsContext,      // taken BY VALUE — first parameter, always
    …,                                  // geometry in points, already scaled by the host
    env: RenderEnv                      // last parameter, always
)
```

| Invariant | Why |
|---|---|
| context by value, mutated as a local `var` (or a `let` when nothing is set) | a mark that sets `context.opacity` on the caller dims the whole host |
| `env: RenderEnv` last | one record, seven axes, injected — never `UIAccessibility` inside a mark |
| every time-varying value is a parameter (`progress`, `retraction`) | the host owns the animation and therefore owns §13.7.4 |
| geometry arrives in points, already scaled by `env.artScale` at the host | scaling twice is the classic Dynamic Type bug |
| returns `Void` | a mark that returns a `Path` invites a second consumer to stroke it differently |
| no `@MainActor`, no `async`, no `throws` | pure drawing |

`03 W18` bites here: `GraphicsContext.stroke` and `.fill` are non-mutating, so a mark that sets nothing takes `let ctx = context`, not `var`. With `-warnings-as-errors` on Release an unmutated `var` is a build failure.

**Why `GraphicsContext` and not `Shape`.** Bloom pass A is one offscreen layer per glyph-bearing region; marks are drawn inside their host's `Canvas` so they sit inside that layer. A mark promoted to a `View` sits outside it, and three offscreen passes become as many as sixteen. **Never** give a mark a `Shape`, a `View` or an `AnimatableModifier` alongside `draw` — two entry points is two geometries within a year.

### The verdict ring

**Concentric with the glyph *body*, not with the glyph box.** The host asks the glyph renderer for the body centre and body radius of the mark it is drawing and passes them in. Two copies of `0.37` is exactly the divergence this skill exists to stop.

The radii, all multiples of `R`, live in `C.VerdictRing` (`verdict-ring.md` §5): `settledAdmitRadius`, `settledRejectRadius`, `transientAdmitRadius`, `breakGap`, `breakSeparation`, `twinAmplitude`, `twinRingGap`, `settledInk`, `restrikeCap`, `counterexampleDash`. **The settled radii are §13.7.4's static-substitution radii on purpose** — under Reduce Motion the transient ring is replaced by a crossfade of a static ring, and a crossfade must land on the state the surface will hold.

**The break.** Four arcs, each centred on a compass ray (−90° N, 0° E, +90° S, 180° W) and spanning `90° − gap`, so the four gaps fall on the inter-cardinals. That placement is load-bearing: pips are contour nodes on exactly the compass rays, and a gap on a pip ray would read as a missing pip.

```
gapDegrees = max(14, degrees(3 / ringRadius)) × (env.isDifferentiateWithoutColorEnabled ? 2 : 1)
```

The floor keeps a 36 pt SIEVE tail ring reading as broken. Arcs translate outward along their own centre ray by up to `breakSeparation` during the break sub-beat and never rotate — a rotating break reads as a spinner, and nothing in this app spins.

**Caps are `butt`.** §13.3 puts `round` caps on chrome; a broken ring with round caps grows its arcs back into its own gaps by half a stroke width at each of eight ends — at `bodySm` that is 6 pt of gap eaten, nearly half of a 14° gap at ribbon size, and rejection starts looking like admission.

**The cancel slash** on the transient reject ring is `CancelHatch.draw(variant: .slash)` — T08's function. Until T08 lands, leave the call site as a `// T08:` comment with the exact arguments from `verdict-ring.md` §3 and open it in T08. **Do not** draw the diagonal inline "just for now": it is the fourth site of the cancel hatch and it must share the −45° angle and the pitch arithmetic with the other three.

**States**: `.admit`, `.reject`, `.twin(admitted:)`, `.counterexample(loomAdmits:)`, `.restrike(count:)`, `.day(Day)`. Two of these have a design argument attached that a reviewer should check:

- `.counterexample(loomAdmits: Bool)` takes **one** `Bool`, not two verdicts, because §4.5 guarantees the two rings disagree — *"Two rings, one glyph, opposite states"*. Passing two verdicts would make a same-verdict counterexample representable, and there is no such thing. Its solid/dashed split is **always on**, never gated on Differentiate Without Colour: §13.11's own reason is that the two contradictory readings must be separable "without either colour or memory", and memory is what a conditional cue requires.
- `.day(Day)` maps §11.8's six Anomaly states. `.failed` draws a broken ring plus `CancelHatch(variant: .hatch)` — §11.8's word "cross-hatch" is prose; a crossed hatch would be a second angle and a second ink coverage, and coverage is a channel the glyph owns.

**No `HunchCore` model import.** `State` speaks `Bool` and `Day` rather than `Verdict` and `AnomalyOutcome`, so `Marks/` needs no dependency edge on the game model to draw a ring; the two mappings are a `switch` owned by one function each in the respective feature module. This is the same trade the tokens skill made keeping `Tokens` independent of `Glyphs`.

**Colour** is `env.palette.accent.brass` / `.cold` — both `AccentColor`, the register the type system already enforces. `accent.brass` and `hue.amber` are far closer in luminance than canon claims, so a brass ring around an amber glyph is separated by register and geometry, never by luminance; do not add a third cue that assumes otherwise, and do not copy a ratio into the file.

**Settled ink** is `C.VerdictRing.settledInk` — the mark's only opacity, because the ribbon is a transcript and must stay quieter than the throat.

### The ghost frame

**This mark carries the whole contextual grammar.** §4.2: *"tapping it re-frames that socket as the previous glyph, drawn with the dashed hollow frame and backward chevron already used to mark `prev` in the ribbon ten probes earlier. That one toggle is the entire contextual grammar, and its symbol was introduced diegetically."* **The argument only holds if the drawing is byte-identical at every site** — which is what `roleDoesNotBranchTheGeometry` asserts.

- **The frame**: a rectangle inset by half the resolved stroke weight so the stroke sits wholly inside the box, **corner radius 0**, dashed `C.GhostFrame.dash`, `env.weight(.thin)` in `stroke.secondary`.
- **The chevron**: on the leading edge, vertically centred, with `u = max(C.GhostFrame.chevronFloor, C.GhostFrame.chevronRatio · side)`, apex at `(u, mid)` and arms at `(2u, mid ∓ u)`, at `env.weight(.bodySm)`, butt caps, miter join. One weight heavier than the frame because a dashed 1 pt rectangle and a 1 pt chevron read as one broken outline and the chevron has to be the thing that points.
- **`[3, 3]` is this mark's signature and never scales.** No other dashed mark may use it: the counterexample ring is `[4, 3]`, and the empty-rail outline and the Anomaly `.absent` ring must pick something else. A dashed rectangle in `[3, 3]` means *previous glyph*, everywhere, and nothing else.
- **`stroke.secondary`, not `primary` and not `hairline`.** The ghost marks a glyph that is *not the live one*; at primary the pin competes with the throat. Hairline is declared never state-bearing and the ghost frame is the entire contextual grammar.
- **`Role` is `Hashable, Sendable, CaseIterable`** — `CaseIterable` because both the test above and T09's gallery enumerate it; it is the one addition to `ghost-frame.md` §3's declaration and it changes no geometry.
- **`layout: LayoutDirection` is a parameter, not an eighth `RenderEnv` axis** — `RenderEnv` is the seven accessibility axes and adding SwiftUI's `LayoutDirection` to it would put a SwiftUI type into `Tokens`, a leaf target with no dependencies. The host passes `@Environment(\.layoutDirection)`.
- **No animated dash.** There is no row for a marching-ants dash in §13.7.4, so there is no such animation.

### The machined bar

One horizontal stroke on the control's vertical midline, spanning the full width plus `C.MachinedBar.overhangRatio` at each end, at `env.weight(.heavy)` in `accent.cold`, **butt caps**.

- **The overhang is the whole idea.** Two per cent is enough to read and small enough that the bar never touches a neighbouring key across the mode rack's 12 pt gutters.
- **Butt caps, not round** — this is §13.3's documented exception: a machined bar is milled stock with cut ends, and round caps at 4 pt turn the overhang into a lozenge.
- **Horizontal always, and that is semantic, not layout.** The cancel hatch runs at −45° and means *excluded*; barred means *not yet* — the Seal is not wrong, the mode is not forbidden, the machine simply is not ready. A diagonal bar would say the wrong thing in the one place the app has no words to correct it.
- **Clip to `key.insetBy(dx: -overhang, dy: 0)`** so the overhang survives at `retraction = 0` and the bar vanishes cleanly at `retraction = 1`, instead of sweeping across whatever sits trailing of the Seal in the commit bar.
- **The retraction sign**: `dx` is subtracted so a positive `travel` always moves toward the trailing edge — leftward in LTR, rightward in RTL. Writing it as an addition and flipping the sign in one branch is the version that gets edited wrong later.
- **Never bloom it.** Pass A is per glyph-bearing region and a commit bar is chrome; glowing the bar would say the machine is powered where the whole point is that it is held.
- **`accent.cold` means *reject, strike, counterexample, barred*, not "error".** §4.3 abolishes the error state outright.

`weight.heavy` is shared with the AND welded coupler bar (§4.2) and **they are not the same drawing**: the coupler is a junction diagram with two more states and belongs to `hunch-bench-instruments`. Sharing the token is correct; sharing the function is the bug.

### `MarkRaster` — the test helper

Marks draw into a `GraphicsContext`, not into a view, so they need a different rasteriser from `CoverageMask`:

```swift
/// Renders a closure's drawing into a coverage raster over an opaque ground.
/// Marks take a `GraphicsContext` by value, so this is also where the "never leaks
/// graphics state" assertion gets its teeth: the closure may draw after the mark.
@MainActor
func markRaster(
    size: CGSize, env: RenderEnv = RenderEnv(),
    layout: LayoutDirection = .leftToRight,
    _ body: @escaping (inout GraphicsContext) -> Void
) throws -> MarkRaster
```

with readers: `coverage(at:radius:degrees:)`, `angularGap(at:radius:)`, `inkRunCount(alongRayFrom:degrees:)`, `dashPeriod(alongEdgeY:from:to:)`, `horizontalInkExtent(atY:)`, `meanCoverage(in:)`, `maximumCoverage()`, `mirroredHorizontally()`. Build it on the same `ImageRenderer` + luminance normalisation `CoverageMask` uses; factor the pixel plumbing into one type if `/simplify` says so.

### The ownership record, and the two greps that enforce it

**`SPEC.md`** gets a *Drawing ownership* table — one row per mark, its owning symbol, its file, and its site count from `ownership.md` §2. Open it here with three rows; T08 completes it to seven.

**`Scripts/check-source-hygiene.sh`** gets both of `ownership.md` §6's checks, covering all seven names at once so T08 needs no script change:

```bash
# 11. One declaration per shared mark. A hit is DESIGN-SYSTEM-SCOPE.md §2(g)'s bug, in the
#     file that has it. Owner: hunch-shared-marks.
grep -rnE '(struct|enum|final class) +[A-Za-z]*(VerdictRing|GhostFrame|MachinedBar|LinkArc|ReturnElbow|CancelHatch|TickRow|ArcMeter)' \
  Modules/Sources HunchCore/Sources --include='*.swift' | grep -v '/Marks/' \
  && fail "a shared mark is declared outside Marks/"

# 12. No hand-rolled mark geometry outside Marks/. The tells are a dashed stroke style, a
#     trimmed path and a four-arc loop — each is one of the seven and nothing else in this
#     app draws them. GlyphShape is the sanctioned exception to the second grep.
grep -rn 'StrokeStyle(.*dash' Modules/Sources --include='*.swift' | grep -v '/Marks/' \
  && fail "a dashed mark outside Marks/"
grep -rn 'trimmedPath\|addArc(' Modules/Sources --include='*.swift' \
  | grep -v -e '/Marks/' -e 'GlyphShape' \
  && fail "hand-rolled arc geometry outside Marks/"
```

Verify both by planting a violation and watching the script fail, then removing it — a check nobody has seen fail is a check that does not work.

## Acceptance criteria

- [ ] `Modules/Sources/HunchUI/Marks/` contains exactly three files, each with exactly one `public static func draw` and no `Shape`, `View` or `AnimatableModifier`.
- [ ] `xcodebuild test … -only-testing:HunchUITests/VerdictRingTests -only-testing:HunchUITests/GhostFrameTests -only-testing:HunchUITests/MachinedBarTests` green.
- [ ] The broken ring's gaps measure on the inter-cardinals and the compass rays measure inked — the pip-collision test.
- [ ] The Differentiate Without Colour gap is 2 × the plain gap within 2°.
- [ ] The ghost frame's dash period is identical at 36, 44 and 168 pt.
- [ ] `ltr.samples == rtl.mirroredHorizontally().samples` for the ghost frame — the chevron mirrors and the frame is symmetric.
- [ ] `bash Scripts/check-source-hygiene.sh` passes; a planted `enum VerdictRing` in `Modules/Sources/HunchUI/GlyphCanvas.swift` fails check 11 and a planted `StrokeStyle(dash: [3, 3])` there fails check 12.
- [ ] `grep -rn 'HueColor' Modules/Sources/HunchUI/Marks/` returns nothing — no mark takes a hue.
- [ ] `grep -rn '#[0-9A-Fa-f]\{6\}\|lineWidth: [0-9]\|\.opacity(0' Modules/Sources/HunchUI/Marks/` returns nothing.
- [ ] `SPEC.md` carries the drawing-ownership table with the first three rows.
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T07: verdict ring, ghost frame and machined bar — one owner each, recorded and greped"`

## Out of scope

- **The other four marks** — T08. The cancel-hatch call inside the transient reject ring is left as a named `// T08:` comment and opened there.
- **Every composition of these marks**: the Seal and its barred states (E09·T07), ribbon tiles and their rings (E08·T05), the counterexample's two-ring presentation and its 960 ms beat (E09·T09), the Codex re-strike rim (E15·T06), the Anomaly ribbon (E16·T04), the barred mode key (E17·T04).
- **Animation.** `progress` and `retraction` are parameters; the host owns the clock, the durations and §13.7.4's substitutions — E08·T06, E09·T10, E09·T12.
- **Audio and haptics for admit / reject / `bar`** — E20·T03, E20·T05. This task names the two cues only so nobody wires a generic tap sound to a barred control.
- **Accessibility elements.** A mark never owns one: §13.10's table is indexed by *host* and has no row for a ring, a frame or a bar. That absence is the specification.
- **`Verdict → Bool` and `AnomalyOutcome → Day`** — one `switch` each, owned by the feature module that has the model, in E08 and E16.
