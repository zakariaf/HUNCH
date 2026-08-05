# T04 — The Dial

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | §14.1 PROBE → *The Dial* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `C.Ramp`'s `dialCell`, `dialCellLarge`, `headerWidth(Large)` and `dialGutter(Large)` are created here at L2, and the surface they sit on (`surface.cellLit`) is L1. A hex, a `lineWidth:` or an `.opacity(` in a ramp file is a build failure. Load it first. |
| `hunch-bench-instruments` | `references/ramp.md` is normative: the ramp has **seven** interactive instances of one drawing and the Dial is instance 1, so building a Dial-only cell here is the drift the skill exists to stop. `references/attribute-header.md` owns the leading 44 pt, which the GDD never specifies. |
| `hunch-glyph-renderer` | A ramp cell is *a picture of one channel* — the silhouette for `shape`, the interior texture for `fill`, the contour nodes for `pips`, the index stroke for `hue` — which is why no attribute emblem has to be learned. The cell asks the renderer for one register; it never re-derives a silhouette. |

## Objective

`RampView` exists in `.single` mode with `RampCell` drawing one register per rank, and `DialView` stacks four of them in canonical `fill → shape → pips → hue` order at 70 × 48 (82 × 62 on Pro Max). The Dial is preloaded with the seed glyph at probe 0, retains the last probe afterwards, and adopts a ribbon or sheet glyph wholesale on a load.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.1 | The ramp as the atom of both UIs; single-select on the Dial, multi-select on the Bench; the three mitigations that make the modal probe one or two taps; the SE cell arithmetic |
| `GAME_DESIGN.md` | §6.2 | Cell sizes and gutters on both devices |
| `GAME_DESIGN.md` | §6.3 | The action table — a Dial tap is free and redraws the throat in 80 ms; a ribbon tap loads wholesale; the Dial is preloaded with the seed glyph at probe 0 |
| `GAME_DESIGN.md` | §12.8 | ≥ 44 pt targets; the 6 pt intra-ramp gutter exemption; the Dynamic Type table (70 × 48 → 84 × 58, gutter 6 → 4 at accessibility1, scroll above AX2) |
| `GAME_DESIGN.md` | §13.10 | Ramp container and cell traits, labels and values; the "Attributes" rotor |
| `hunch-bench-instruments` | `references/ramp.md` §1–§8 | The seven instances, the geometry table, the four cell states, the four select modes, the SwiftUI shape and the eight ways to get it wrong |

## TDD — the test comes first

**Step 1 — write the failing test.**

`Modules/Tests/LoomFeatureTests/DialTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import LoomFeature

@Suite("The Dial composes, retains and adopts", .tags(.unit, .presubmission))
@MainActor
struct DialTests {

    @Test("At probe 0 the Dial is preloaded with the seed glyph, so probe 1 is one tap")
    func preloadedWithTheSeed() {
        let round = Fixtures.round()
        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.probesUsed == 0)
    }

    @Test("Single-select: a tap moves that ramp's selection and nothing else")
    func singleSelectMovesOneRamp() {
        let round = Fixtures.round()
        let before = round.draft
        round.select(.shape, rank: 4)
        #expect(round.draft.shape.rank == 4)
        #expect(round.draft.fill == before.fill)
        #expect(round.draft.pips == before.pips)
        #expect(round.draft.hue == before.hue)
        #expect(round.lastTouched == .shape)
    }

    @Test("The Dial retains the last probe: the default action is a minimal edit")
    func retainsTheLastProbe() {
        let round = Fixtures.round()
        let probed = Deck.glyph(id: 137)
        round.select(.fill, rank: probed.fill.rank)
        round.select(.shape, rank: probed.shape.rank)
        round.select(.pips, rank: probed.pips.rank)
        round.select(.hue, rank: probed.hue.rank)

        round.probe(round.draft)
        round.endVerdictBeat()

        #expect(round.draft == probed)          // still there — one tap away from the next experiment
    }

    @Test("Ribbon-load adopts a glyph wholesale and does not disturb the last-touched attribute")
    func ribbonLoadAdoptsWholesale() {
        let round = Fixtures.round()
        round.select(.hue, rank: 3)
        round.probe(round.draft)
        round.endVerdictBeat()
        round.select(.fill, rank: 2)
        let touched = round.lastTouched

        round.load(ribbonIndex: 0)              // index 0 is the seed tile

        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.lastTouched == touched)   // nothing was *touched*; see DECISIONS.md
        #expect(round.changedRegister == nil)   // a wholesale adoption is not a single-register edit
    }

    @Test("Loading out of range is a no-op, not a crash")
    func outOfRangeLoadIsIgnored() {
        let round = Fixtures.round()
        let before = round.draft
        round.load(ribbonIndex: 99)
        #expect(round.draft == before)
    }
}
```

`Modules/Tests/HunchUITests/DialLayoutTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import HunchUI

@Suite("The Dial's four ramps, both devices", .tags(.unit, .presubmission))
struct DialLayoutTests {

    @Test("Four ramps in canonical fill → shape → pips → hue order")
    func canonicalOrder() {
        #expect(DialView.attributeOrder == Glyph.Attribute.allCases)
        #expect(DialView.attributeOrder == [.fill, .shape, .pips, .hue])
        #expect(DialView.attributeOrder.count == 4)
    }

    @Test("Cell and header geometry, per device")
    func cellGeometry() {
        let se = RampView.Metrics.dial(deviceClass: .compact, artScale: 1)
        #expect(se.cell == C.Ramp.dialCell)
        #expect(se.headerWidth == C.Ramp.headerWidth)
        #expect(se.gutter == C.Ramp.dialGutter)

        let big = RampView.Metrics.dial(deviceClass: .large, artScale: 1)
        #expect(big.cell == C.Ramp.dialCellLarge)
        #expect(big.headerWidth == C.Ramp.headerWidthLarge)
        #expect(big.gutter == C.Ramp.dialGutterLarge)
    }

    @Test("The row fills its column: header + four cells + three gutters",
          arguments: [RampView.Metrics.dial(deviceClass: .compact, artScale: 1)])
    func rowArithmetic(_ m: RampView.Metrics) {
        let width = m.headerWidth + 4 * m.cell.width + 3 * m.gutter
        #expect(width <= Space.columnContent)
    }

    @Test("Every cell clears the 44 pt floor at every shipped art scale",
          arguments: [PlaySurfaceLayout.DeviceClass.compact, .large], [1.0, 1.2, 1.35])
    func targetFloor(_ device: PlaySurfaceLayout.DeviceClass, _ artScale: Double) {
        let m = RampView.Metrics.dial(deviceClass: device, artScale: artScale)
        #expect(m.cell.width >= 44)
        #expect(m.cell.height >= 44)
    }

    @Test("Four rows fit the Dial region on both devices",
          arguments: [PlaySurfaceLayout.reference(.compact), .reference(.large)])
    func rowsFitTheRegion(_ layout: PlaySurfaceLayout) {
        #expect(layout.dialRow(0).minY == layout.dial.minY)
        #expect(layout.dialRow(3).maxY <= layout.dial.maxY)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/DialTests -only-testing:HunchUITests/DialLayoutTests
```

Expect `cannot find 'DialView' in scope` and `value of type 'Round' has no member 'load'`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/RuleTileCanvas.swift` |
| create | `Modules/Sources/HunchUI/AttributeHeaderView.swift` |
| create | `Modules/Sources/LoomFeature/DialView.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| create | `Modules/Tests/LoomFeatureTests/DialTests.swift` |
| create | `Modules/Tests/HunchUITests/DialLayoutTests.swift` |
| modify | `DECISIONS.md` |

## Implementation notes

**One drawing, seven sites.** `ramp.md` §1 enumerates them: the Dial ramp (×4 on screen), the Bench Ramp tile, the Fork's gate / then / else docks, the Tally's rank ramp and its counter dial. This task builds the drawing and **only** the `.single` select mode; E09·T02 adds `.multi`, `.exactlyOne`, `.stops(_:)` and the inert state to the same type. Building a `DialRamp` here and a `RampView` there is the exact drift the skill exists to prevent — the Fork's else dock is the instance people most often lose, and it is a *full* ramp on the same attribute.

**The cell is a picture of one channel.** `RampCell` asks `hunch-glyph-renderer` for the attribute's own register at that rank and draws nothing in the other three: silhouette for `shape`, interior texture for `fill`, contour nodes for `pips`, index stroke for `hue`. This is §4.1's whole claim — *the ramp is a picture of its own attribute*, so there is no emblem to learn. If E04's renderer cannot draw one register alone, that is the same shape requirement T03 already cashed; fix it there.

**Structure — one `Button` per cell, never one `Canvas` per ramp.** §13.10 makes every cell a `.button` with `.isSelected`; a single canvas would collapse five accessibility elements into one image and take the trait with it. The container is `.accessibilityElement(children: .contain)` and the Dial's four ramps are the stops of the "Attributes" rotor (E19·T05 wires the rotor; expose the container now so it has something to stop on).

**`Metrics` is built, never assembled at a call site.** `RampView.Metrics.dial(deviceClass:artScale:)` returns `headerWidth`, `cell` and `gutter` already multiplied by `env.artScale`; E09 adds `.benchTile(env:railContent:)` and E15 `.codex(env:)`. A call site that computes `70 * scale` inline is the bug this factory exists to prevent.

**The header abuts its first cell with no gutter**, because the header and its four cells are one semantic group and §12.8 exempts intra-group spacing from the 8 pt inter-target floor for exactly that reason. Between two ramps the gutter is the inter-target one. The attribute header's *drawing* is the one thing in this area the GDD never specifies — read `attribute-header.md`'s four constraints and its sanctioned construction; do not quietly invent a fifth emblem.

**Three additions to `Round`.**

```swift
/// A Dial cell tap. Free, moves one ramp's selection, redraws the throat in
/// `C.Throat.registerCrossfade` (§6.3). Sets `lastTouched` and `changedRegister`.
public func select(_ attribute: Glyph.Attribute, rank: Int)

/// Ribbon-load (§6.3, §4.1's mitigation 2): the Dial and throat adopt that glyph **wholesale**.
/// Out of range is a no-op. Costs nothing and consumes no probe.
public func load(ribbonIndex index: Int)

/// The tile the Dial is currently sourced from, for the ribbon's `loaded` state.
public private(set) var loadedIndex: Int?
```

**A wholesale load leaves `lastTouched` alone and sets `changedRegister` to `nil`.** Two joined decisions, both recorded in `DECISIONS.md`: nothing was *touched*, so the swipe's target should not silently move under the player; and a load is not a controlled variation, so animating one register would be a lie about what happened — the throat crossfades the whole glyph on a load and only on a load, which is the one legitimate use of that transition.

**Dynamic Type.** Cell and header *lengths* multiply by `env.artScale` (≤ 1.35): 70 × 48 → 84 × 58 across xLarge–xxxLarge, gutter 6 → 4 at accessibility1. Above AX2 nothing shrinks — the four ramps **scroll vertically inside the Dial's region** (§13.11), which is why `PlaySurfaceLayout.dial` does not grow. Stroke weights never take `artScale`; they have their own axis.

**High Contrast, and why a `hue` ramp has a floor.** All four `hue.*` render as `stroke.primary`, so a hue ramp's four cells are told apart **only** by index-stroke rotation — which is why a hue cell must never shrink below the size that keeps four rotations distinct. This is a reason not to "save space" by shrinking the Dial, and it belongs in the code comment where someone will be tempted.

## Acceptance criteria

- [ ] `DialTests` (5 cases) and `DialLayoutTests` (5 cases) green on both destinations.
- [ ] `grep -rn 'struct .*Ramp' Modules/Sources` shows exactly one ramp drawing (`RampView` + its private `RampCell`).
- [ ] `grep -rn '70\|48\|82\|62' Modules/Sources --include='*.swift' | grep -v 'C.swift'` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` passes checks 7, 9 and 10 with the new files in the play-surface list.
- [ ] Every Dial cell is a `Button` with `.isSelected` when lit — `grep -n 'Button' Modules/Sources/HunchUI/RuleTileCanvas.swift` shows one per cell, not one per ramp.
- [ ] `DECISIONS.md` records the wholesale-load rules (`lastTouched` unchanged, `changedRegister` nil, whole-glyph crossfade).

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; both new filters green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T04: the Dial — four single-select ramps, retained draft, wholesale load"`

## Out of scope

- `.multi`, `.exactlyOne` and `.stops(_:)` select modes, the inert state and its hairline slash, and `RankSet.isVacuous` — **E09·T02**. Do not add a select mode you have no site for.
- `BridgeView`, `ForkView`, `TallyView`, `CouplerView` — **E09·T02**.
- The ribbon that the load reads from — **T05**. `load(ribbonIndex:)` is written against `Round.ribbon`, which T01 already ships.
- The spool sheet's cell tap, which calls the same `load` — **T09**.
- The "Attributes" rotor and every VoiceOver string — **E19·T02, E19·T05**.
- The AX2+ vertical scroll behaviour verified across all screens — **E19·T06**; wire the scroll container here, verify the matrix there.
