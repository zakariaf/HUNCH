# T01 — Bench layout, palette and the handle

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | §14.1 `The Bench` (the surface and its regions) · `Micro-responses + transitions` (the Dial ↔ Bench row of §13.7.3) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First.** This task creates the `C.Bench` L2 namespace and consumes `C.Key.rect(.paletteStamp, in:)`, `C.Assay.gridSide(.benchWell)` and `C.RuleTile.railContent`. Every region in this file is either an L2 member with its §4.2 citation or a derived sum; a literal here fails `check-source-hygiene.sh` check 9. |
| `hunch-bench-instruments` | Owns the Bench's geometry, states and interaction, and its standing rule 4 ("art scales, chrome does not; above AX2 an instrument **pages** rather than shrinks") is what turns the Bench into a single-rail pager. Its `references/seal.md` §1 fixes the commit bar at y 604–667 on **every** surface, which is the constraint the Bench's commit bar inherits rather than restates. |
| `hunch-motion-and-feedback` | Owns the Dial ↔ Bench transition — `references/transitions.md` §2 is the only interactive transition in the app, with its three required properties (follows the finger, interruptible, resolves by velocity) and its Reduce Motion substitution (the handle becomes a plain button, not a shorter drag). |
| `hunch-chrome-and-meta` | The palette stamp is a **key site**, not a Bench-local rectangle: `references/key.md` row 4 owns 68 × 44 and its AX3+ substitution to 165 × 56, and warns that `.stroke` versus `.strokeBorder` is what silently breaks §12.8's 8 pt inter-target floor between two adjacent stamps. |
| `hunch-accessibility` | §6.7 requires the handle to be exposed as a button so the drag is never required; this skill owns that the handle is an element with a label, a trait and a value, and that a gesture VoiceOver cannot make needs a custom action beside it. |

## Objective

At the end of this task `BenchView` exists as a real drawer over the Dial, with its rails, its Assay
column, its palette and its Dial/Seal commit bar laid out region for region on both reference devices,
and it can be opened and closed by tap or by drag without the throat or the ribbon moving one point.
Before this task there is no Bench; after it there is an empty one whose regions, handle and palette
are asserted, and whose draft survives a round trip to the Dial verbatim.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.2 | The Bench's SE region table: instrument bar, throat, ribbon, the 228–560 Bench with 291 pt rails and the Assay's 64 pt trailing column, the 560–604 palette of four tile stamps, the 604–667 commit bar (Dial leading · Seal trailing) |
| `GAME_DESIGN.md` | §6.2 | The Pro Max derivation rule — surplus height goes to the throat and the ribbon; the Dial, handle and commit bar keep their heights and lay out **upward from the bottom safe edge**. The handle at y 516–560 (SE) / 820–864 (Pro Max) |
| `GAME_DESIGN.md` | §6.7 | Entering (handle tap, upward drag, or the Bench key — all three equivalent), the 380 ms transition and what moves in it, **the throat and the ribbon do not move**, availability from probe 0 with no gate, backing out with the draft preserved verbatim, and that opening/editing/expanding/closing all cost zero probes |
| `GAME_DESIGN.md` | §13.7.3 | The Dial ↔ Bench row: interactive drag on the handle, the Dial slides down 332 pt, follows the finger, interruptible |
| `GAME_DESIGN.md` | §13.7.4 | The Dial ↔ Bench substitution: a crossfade, and **the handle becomes a plain button** |
| `GAME_DESIGN.md` | §12.8 | Reach tier 1 (the commit bar is in the same place on every surface), tier 2 (composition controls at y ≥ 220), tier 3 (everything above y = 220 is read-only); the AX2+ single-rail pager |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24, P25 | One top-level type per file, and the three sanctioned exceptions |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A18, A19, A20 | `Round` is the one earned observable here; the pure part (phase transitions, the draft) stays in `HunchCore` and is tested there |

Never restate a value this table owns. Read §4.2's region block and §6.2's table; put each number in
`C.Bench` with its citation, or derive it.

## TDD — the test comes first

**Step 1 — write the failing tests.** Two files, because two targets are involved.

Create `Modules/Tests/HunchUITests/BenchGeometryTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI

@Suite("Bench geometry", .tags(.unit, .presubmission))
struct BenchGeometryTests {

    // §6.7: "The throat and the ribbon do not move. … This is the single most important
    // layout constraint in the mode."
    @Test("The throat and the ribbon hold their rects across both modes",
          arguments: PlaySurfaceLayout.Device.allCases)
    func evidenceNeverLeavesTheScreen(_ device: PlaySurfaceLayout.Device) {
        let dial = PlaySurfaceLayout(device: device, mode: .dial)
        let bench = PlaySurfaceLayout(device: device, mode: .bench)

        #expect(dial.throat == bench.throat)
        #expect(dial.ribbon == bench.ribbon)
        #expect(dial.instrumentBar == bench.instrumentBar)
    }

    // §12.8 tier 1: "the thing that ends a decision is always in the same place under the
    // same thumb" — the commit bar does not move either, only its contents change.
    @Test("The commit bar is in the same place in both modes",
          arguments: PlaySurfaceLayout.Device.allCases)
    func commitBarIsInvariant(_ device: PlaySurfaceLayout.Device) {
        let dial = PlaySurfaceLayout(device: device, mode: .dial)
        let bench = PlaySurfaceLayout(device: device, mode: .bench)

        #expect(dial.commitBar == bench.commitBar)
        #expect(dial.commitBarKeys.count == 3)     // PROBE · twin · Bench
        #expect(bench.commitBarKeys.count == 2)    // Dial · Seal
    }

    // §4.2, SE reference: rails 291 pt, the Assay in a 64 pt trailing column.
    @Test("The Bench region splits into rails plus the Assay column with no overlap")
    func benchRegionSplit() {
        let bench = PlaySurfaceLayout(device: .se, mode: .bench)

        #expect(bench.rails.width == C.RuleTile.railContent)
        #expect(bench.assayColumn.width == C.Assay.gridSide(.benchWell))
        #expect(bench.rails.maxX <= bench.assayColumn.minX)
        #expect(bench.assayColumn.maxX <= bench.contentWidth)
        #expect(bench.rails.minY == bench.assayColumn.minY)
    }

    // §4.2: y 228–560 Bench, 560–604 palette, 604–667 commit bar — contiguous, in order,
    // and no region overlaps its neighbour on either device.
    @Test("Bench regions are contiguous and ordered",
          arguments: PlaySurfaceLayout.Device.allCases)
    func regionsAreContiguous(_ device: PlaySurfaceLayout.Device) {
        let bench = PlaySurfaceLayout(device: device, mode: .bench)
        let stack = [bench.instrumentBar, bench.throat, bench.ribbon,
                     bench.benchRegion, bench.palette, bench.commitBar]

        for (above, below) in zip(stack, stack.dropFirst()) {
            #expect(above.maxY <= below.minY, "\(above) overlaps \(below)")
        }
        #expect(bench.commitBar.maxY <= bench.safeArea.maxY)
    }

    // §6.2: the controls lay out UPWARD from the bottom safe edge, so the handle and the
    // commit bar keep their heights and only the throat and ribbon absorb surplus height.
    @Test("Surplus device height goes to the throat and the ribbon, never to the controls") 
    func surplusGoesToEvidence() {
        let se = PlaySurfaceLayout(device: .se, mode: .bench)
        let max = PlaySurfaceLayout(device: .proMax, mode: .bench)

        #expect(max.handle.height == se.handle.height)
        #expect(max.palette.height == se.palette.height)
        #expect(max.throat.height > se.throat.height)
        #expect(max.ribbon.height > se.ribbon.height)
    }

    // §12.8: every interactive target within 460 pt of the bottom safe edge, on both devices.
    @Test("Every Bench target is inside the thumb arc",
          arguments: PlaySurfaceLayout.Device.allCases)
    func targetsAreReachable(_ device: PlaySurfaceLayout.Device) {
        let bench = PlaySurfaceLayout(device: device, mode: .bench)
        for target in bench.interactiveTargets {
            #expect(bench.safeArea.maxY - target.minY <= C.Bench.reachBudget)
            #expect(target.height >= Space.targetMin)
            #expect(target.width >= Space.targetMin)
        }
    }

    // §4.2: a palette of four tile stamps; §13.11: 2 × 2 at AX1+, with the substituted rect,
    // never the reference rect multiplied by artScale.
    @Test("The palette holds four stamps and pages 4 × 1 → 2 × 2 when art scale is clamped")
    func paletteShape() {
        let normal = BenchPalette(env: .fixture(artScale: 1.0))
        let large = BenchPalette(env: .fixture(artScale: Prim.artScaleCeiling))

        #expect(normal.stamps.count == 4)
        #expect(large.stamps.count == 4)
        #expect(normal.columns == 4)
        #expect(large.columns == 2)
        #expect(large.stampRect == C.Key.rect(.paletteStamp, in: .fixture(artScale: Prim.artScaleCeiling)))
        #expect(large.stampRect != normal.stampRect.scaled(by: Prim.artScaleCeiling))
    }
}
```

Create `Modules/Tests/LoomFeatureTests/BenchDrawerTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature

@Suite("Bench drawer", .tags(.unit, .presubmission))
@MainActor
struct BenchDrawerTests {

    // §6.7 "Backing out. … The draft is preserved verbatim — cells, sockets, wedges, ghosts,
    // coupler. Returning finds it exactly as left."
    @Test("Backing out to the Dial preserves the draft verbatim")
    func draftSurvivesTheRoundTrip() throws {
        let round = Round.fixture(band: .contextual)
        round.openBench()

        round.place(.bridge, onRail: 0)
        round.bind(.pips, to: .leading, onRail: 0)
        round.bind(.pips, to: .trailing, onRail: 0)
        round.toggleGhost(onRail: 0)
        round.cycleComparator(onRail: 0)
        round.place(.ramp, onRail: 1)
        round.bind(.shape, onRail: 1)
        round.toggleCell(rank: 1, onRail: 1)
        round.cycleCoupler()

        let saved = round.benchDraft
        round.closeBench()
        #expect(round.phase == .probing)
        round.openBench()

        #expect(round.benchDraft == saved)
    }

    // §6.7 "Availability. The Bench opens at any time, including probe 0. No gate, no
    // minimum, no unlock." and "Cost. Opening, editing, expanding the Assay, and closing
    // the Bench all cost zero probes and advance no counter."
    @Test("The Bench opens at probe 0 and costs nothing")
    func benchIsFreeAndUngated() {
        let round = Round.fixture(band: .literal)
        #expect(round.probesUsed == 0)

        round.openBench()
        #expect(round.phase == .declaring)
        round.place(.ramp, onRail: 0)
        round.closeBench()

        #expect(round.probesUsed == 0)
        #expect(round.ribbon.isEmpty)
    }

    // §13.7.4: the substitution replaces the gesture with a control; it does not shorten it.
    @Test("Under Reduce Motion the handle is a plain button and no drag is required")
    func handleSubstitutesToAButton() {
        let reduced = RenderEnv.fixture(isReduceMotionEnabled: true)
        let normal = RenderEnv.fixture(isReduceMotionEnabled: false)

        #expect(BenchHandle.affordance(in: reduced) == .button)
        #expect(BenchHandle.affordance(in: normal) == .interactiveDrag)
        // The tap path exists in BOTH, because §6.7 makes all three entries equivalent.
        #expect(BenchHandle.acceptsTap(in: reduced))
        #expect(BenchHandle.acceptsTap(in: normal))
    }

    // §13.7.3 / §6.7 — the two durations are two facts. See Implementation notes.
    @Test("The tap transition and the drag settle are separately named")
    func twoTransitionFacts() {
        #expect(C.Bench.tapTransition == .milliseconds(380))
        #expect(BenchDrawer.dragSettle == Dur.sheet)
        #expect(C.Bench.travel > 0)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission \
  -only-testing:HunchUITests/BenchGeometryTests \
  -only-testing:LoomFeatureTests/BenchDrawerTests
```

Confirm the failure is `cannot find 'PlaySurfaceLayout' in scope` / `value of type 'Round' has no
member 'openBench'` — a missing symbol — and not a malformed assertion. A test that compiles and
passes before `BenchView` exists is testing nothing.

**Step 3 — implement** the minimum that turns them green. Files below.

**Step 4 — green, then refactor** with the tests as the safety net.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/PlaySurfaceLayout.swift` — E08·T02's layout type. Add `Mode`, the Bench regions, `interactiveTargets` and `contentWidth`. **If E08 named the file differently, extend that file; do not create a second layout type.** |
| create | `Modules/Sources/HunchUI/BenchPalette.swift` — the four stamps, their rects and the 4 × 1 → 2 × 2 reflow |
| create | `Modules/Sources/HunchUI/BenchHandle.swift` — the handle, its affordance under Reduce Motion, its accessibility identity |
| create | `Modules/Sources/LoomFeature/BenchView.swift` — the composed surface: rails, coupler slot, Assay column, palette, commit bar |
| create | `Modules/Sources/LoomFeature/BenchDrawer.swift` — the drawer over the Dial, per `transitions.md` §6 |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `benchDraft: BenchLayout`, `openBench()`, `closeBench()`, and the `probing ⇄ declaring` transitions delegated to `HunchCore`'s pure transition function |
| modify | `HunchCore/Sources/Tokens/C.swift` — add the `C.Bench` namespace |
| create | `Modules/Tests/HunchUITests/BenchGeometryTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/BenchDrawerTests.swift` |
| modify | `DECISIONS.md` — the 380 ms / `dur.sheet` ruling |
| modify | `tests.json` — the throat/ribbon layout-identity invariant |

## Implementation notes

### `C.Bench`, and the four numbers that are *not* its

```swift
// HunchCore/Sources/Tokens/C.swift
extension C {
    public enum Bench {
        /// §13.7.3 — the Dial slides down by this much to become the Bench drawer.
        public static let travel = 332.0
        /// §4.2, §6.2 — the pull-up handle's band. Height only; the y origin is laid out
        /// upward from the bottom safe edge by `PlaySurfaceLayout`.
        public static let handleHeight = 44.0
        /// §6.7 — the TAP-driven Dial ↔ Bench transition. Not the drag; see the ruling below.
        public static let tapTransition = Duration.milliseconds(380)
        /// §12.8 — every interactive target lives within this of the bottom safe edge, on
        /// both reference devices (§6.2's measurement: 411 pt SE, 452 pt Pro Max).
        public static let reachBudget = 460.0
    }
}
```

Four numbers that belong to somebody else and must be *called*, never copied:

- **291 pt rails** → `C.RuleTile.railContent`, declared in `rule-tile.md` §1.
- **64 pt Assay column** → `C.Assay.gridSide(.benchWell)`, declared in `assay-grid.md` §1. The
  column is the grid, so a separate `C.Bench.assayColumnWidth` would be a second home for one fact.
- **68 × 44 palette stamp** → `C.Key.rect(.paletteStamp, in: env)`, declared in `key.md` §1.
- **44 × 44 minimum target** → `Space.targetMin`.

### The 380 ms / `dur.sheet` ruling — write it into `DECISIONS.md`

§6.7 says the Dial ↔ Bench change takes **380 ms**. §13.7.3 says it is an interactive drag bounded by
**≤ 320 ms** (`dur.sheet`). These are not in conflict once you read what each sentence describes:

- §6.7's two 380 ms sentences are both about **taps** — "Tap the Bench handle … or tap the Bench key",
  and "Backing out. Tap the Dial key. 380 ms reverse". A tap has no finger to follow, so the whole
  choreography (ramps out, rails up, palette in, Assay in from the trailing edge, commit bar
  crossfade) runs on a fixed 380 ms clock.
- §13.7.3's row is explicitly *"interactive drag on the Bench handle … follows the finger,
  interruptible"*, and its duration is the **settle after release**, bounded by `dur.sheet`.

So: `C.Bench.tapTransition` = 380 ms is the tap path; `BenchDrawer.dragSettle` = `Dur.sheet` is the
release settle. Both are named, both are tested, and neither is a copy of the other. Record it.

### `PlaySurfaceLayout` — one type, two modes

```swift
public struct PlaySurfaceLayout: Sendable {
    public enum Device: CaseIterable, Sendable { case se, proMax }
    public enum Mode: CaseIterable, Sendable { case dial, bench }

    public let device: Device
    public let mode: Mode

    // Invariant across `mode` — this is the assertion, made structural.
    public let instrumentBar: CGRect
    public let throat: CGRect
    public let ribbon: CGRect
    public let commitBar: CGRect

    // Mode-dependent.
    public let dialRegion: CGRect      // .dial only; .zero in .bench
    public let benchRegion: CGRect     // .bench only; .zero in .dial
    public let rails: CGRect
    public let assayColumn: CGRect
    public let palette: CGRect
    public let handle: CGRect
}
```

The four invariant rects are computed **once**, before the mode is consulted, and stored. That is
what makes `dial.throat == bench.throat` a property of the type rather than a coincidence two code
paths happen to share — and it is why the test in step 1 will keep passing after somebody edits the
Bench's layout in six months. Laying the two modes out independently and then asserting they agree is
the version of this that rots.

The vertical order is: instrument bar → throat → ribbon → (`dialRegion` | `benchRegion`) → handle
(dial mode) / palette (bench mode) → commit bar. Lay the **bottom three** out upward from
`safeArea.maxY` with their fixed heights (§6.2's decision), lay the top two out downward from
`safeArea.minY`, and give the remainder to the throat and the ribbon in the ratio §4.2 and §6.2 fix
for each device. That is the one rule §6.2 states, applied literally, and it is what makes
`surplusGoesToEvidence` pass without a device-specific branch.

### The drawer

Follow `transitions.md` §6's `BenchDrawer` sketch exactly. Three properties are required and each has
a test:

1. **Follows the finger** — `offset` tracks `value.translation.height` directly, not through a
   `withAnimation` on a `Bool`.
2. **Interruptible** — a new drag during the settle picks up from the current offset. `ease.sheet`'s
   spring gives this; a `withAnimation(.easeInOut)` does not.
3. **Resolves by velocity** — `value.predictedEndTranslation.height < -C.Bench.travel / 3` commits on
   a flick; a slow drag needs half the travel.

Under Reduce Motion the whole gesture is **replaced**: `BenchHandle.affordance(in:)` returns `.button`
and the drawer crossfades at `Dur.crossfade`. Shortening the drag to 40 ms is the failure mode
`reduce-motion.md` §1 rule 3 names explicitly, and §13.12 gate 9 is a hand audit that catches it.

The handle keeps a tap path in **both** modes, because §6.7 makes handle-tap, handle-drag and
Bench-key equivalent and exposes the handle to VoiceOver as a button *"so the drag is never
required"*. `acceptsTap` is therefore unconditional.

### The palette

Four stamps, one per `RuleTileClass`, drawn with the class's own silhouette so a stamp is a picture of
its tile — the Bridge stamp carries `GhostFrame.draw` (`ghost-frame.md` names it as one of the six
ghost-frame sites), so nothing new is invented. Tapping a stamp adds that class **to the next empty
rail** (§4.2's gesture table, `rule-tile.md` §4).

At `env.isArtScaleClamped` the palette reflows 4 × 1 → 2 × 2 and the stamp rect **substitutes** to
`key.md`'s AX3+ rectangle. It does not multiply: `68 × 44 × 1.35 = 92 × 59`, which is neither
`165 × 56` nor a shape that fits the 44 pt palette band. The test asserts the difference, because a
multiply looks right until you measure it.

Which stamps are *present* is T04's business, not this task's. Here all four are drawn and the ceiling
is passed in as a value the view renders; T04 supplies its derivation.

### Accessibility, written in this pass

Per `hunch-accessibility` step 4 — traits, then value, then actions, in source order:

- handle: `.isButton`, label `Loc.benchHandle`, value `Loc.benchOpen`/`Loc.benchClosed`; a custom
  action for the open/close verb so the drag is never the only route.
- palette stamp ×4: `.isButton`, labels `"Ramp tile"` / `"Bridge tile"` / `"Fork tile"` /
  `"Tally tile"` per `voiceover-elements.md`; a disabled stamp keeps its label and gains
  `.notEnabled` — never removed from the tree.
- The Bench container carries the `LawNarrator`'s single sentence as its value (`rule-tile.md` §6).
  That narrator is E19's; leave the hook and a `// E19` marker, do not invent a narration here.

### What is deliberately empty

The rails render `RailView`'s **empty** state — a dashed outline at `weight.hairline` pulsing on
`C.RuleTile.emptyRailPulsePeriod` — because T02 has not drawn a tile yet. That empty pulse is the only
looping animation on the Bench; if you find yourself adding a second, one of them is decoration
(`rule-tile.md` §9).

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/BenchGeometryTests -only-testing:LoomFeatureTests/BenchDrawerTests` is green.
- [ ] `PlaySurfaceLayout` computes `instrumentBar`, `throat`, `ribbon` and `commitBar` **before**
      branching on `mode` — verified by reading the initializer, and the reason is in a comment.
- [ ] `grep -n '291\|332\|380\|460\|68\|64' Modules/Sources/HunchUI/PlaySurfaceLayout.swift` returns
      nothing outside a `// §` citation comment; every number resolves through `C.*` or `Space.*`.
- [ ] `bash Scripts/check-source-hygiene.sh` passes with the new files present.
- [ ] `DECISIONS.md` contains the 380 ms / `dur.sheet` entry with both citations.
- [ ] `tests.json` has an entry named `bench.throat-and-ribbon-hold-position` pointing at
      `BenchGeometryTests.evidenceNeverLeavesTheScreen`.
- [ ] Building the app and opening the Bench in the simulator on an iPhone SE (3rd gen) shows the
      throat glyph and the ribbon in exactly the same place before and after — checked by screenshot,
      not by eye across two runs.
- [ ] `grep -rn 'Text(\|Label(\|AttributedString' Modules/Sources/LoomFeature/BenchView.swift` returns
      only hits inside `.accessibility*` modifiers.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:HunchUITests/BenchGeometryTests -only-testing:LoomFeatureTests/BenchDrawerTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T01: Bench layout, palette and the handle; the throat and ribbon hold their rects across both modes"`

## Out of scope

- **Drawing any rule-tile.** `RampView`, `BridgeView`, `ForkView`, `TallyView` and `CouplerView` are
  **T02**. This task ships empty rails.
- **The gesture lint.** The exhaustive gesture inventory and hygiene check 11 are **T03**.
- **Which stamps are unlocked.** `PaletteCeiling` is **T04**; here the ceiling is a parameter.
- **The Assay's contents.** The 64 pt column is laid out here and filled in **T05**.
- **The Seal.** The commit bar's trailing key is drawn in **T07**; here it is a placeholder rect with
  the right geometry and the right accessibility identity.
- **The Dial, throat, ribbon and par tick row.** All **E08**; this task only asserts that they do not
  move.
- **The single-rail pager above AX2.** Declared here as a reflow hook; the full Dynamic Type pass is
  **E19·T06**.
