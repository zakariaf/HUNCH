# T07 — Targets and reach

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | Targets and reach (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | `references/rotors-and-gestures.md` §8 owns the minimum target and the spacing rule and names the audit pass that enforces them; `references/environment-settings.md` §2 owns the rule that **targets never shrink to make room** and that above AX2 a grid pages rather than growing — which is why this task runs after T06 and not before it. |
| `hunch-bench-instruments` | Owns the geometry every assertion here reads: the ramp cell (the smallest shipped target), the ribbon tile, ECHO's tray and rail, SIEVE's gate band. This task must **cite** those constants and never restate one — a target inventory that hard-codes a cell size is a second source of truth that goes stale the first time a component moves. |

## Objective

At the end of this task every interactive target in HUNCH is at least 44 × 44 pt with at least 8 pt
between independent targets, on both reference devices, and the three reach tiers of §12.8 hold: commit
controls in the commit bar, composition controls at y ≥ 220, and **everything above y = 220 read-only
or undo-shaped** — with the ribbon's load and ECHO's rail return each carrying a same-effect route
inside the thumb arc.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.8 (Targets) | minimum 44 × 44 pt; the smallest shipped is 56 × 44 (the Bench ramp cell, §5.7); the chevron and play key draw at 24 pt inside a 44 × 44 hit rect; inter-target spacing ≥ 8 pt; the Dial's 6 pt gutter is *between cells of one ramp*, which are a single semantic group and not independent targets |
| `GAME_DESIGN.md` | §12.8 (One-handed portrait on the SE) | the three tiers verbatim, the y-values for each surface, and the rule that reach for a multi-cell grid is measured at its **nearest** row |
| `GAME_DESIGN.md` | §12.8 (the two exceptions) | the ribbon (176–228) loads a tile into the Dial, which the Dial can always compose directly; ECHO's rail (172–252) returns a placed tile, which **tapping its tray tile a second time also does** |
| `GAME_DESIGN.md` | §6.2 | the PROBE/DRIFT surface region by region on both devices; surplus height goes to the throat and ribbon while the commit bar keeps its height and lays out upward from the bottom safe edge |
| `GAME_DESIGN.md` | §4.1, §4.2, §8.4, §9.2, §12.4 | the commit bar's contents on each surface; the Bench's rails and palette; ECHO's tray; SIEVE's 375 × 88 gate; the Frame's rack and shelf |
| `GAME_DESIGN.md` | §5.7 | the locked constants the smallest-target claim is measured against |
| `GAME_DESIGN.md` | §13.12 gate 8 | every target ≥ 44 × 44 pt at AX5 in five locales — the snapshot half is T11's; this task is the reference-size half |

## TDD — the test comes first

Every layout constant already exists as a value (E08·T02, E09·T01, E13·T05, E14·T02, E17·T03). This
task walks them. That is the difference between an audit and a second source of truth: the inventory
**is** the shipped layout, read back.

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/TargetsAndReachTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI

@Suite("Targets and reach — §12.8", .tags(.unit, .presubmission))
struct TargetsAndReachTests {

    // Both reference devices, every surface, from the shipped layout constants.
    private static let devices: [ReferenceDevice] = [.iPhoneSE, .iPhoneProMax]

    @Test("every interactive target is at least 44 × 44 pt",
          arguments: devices, Surface.allCases)
    func minimumTargetSize(_ device: ReferenceDevice, _ surface: Surface) {
        for target in TargetInventory.targets(on: surface, device: device) where target.isInteractive {
            #expect(target.frame.width  >= Space.targetMin, "\(target.id) is \(target.frame.width) pt wide")
            #expect(target.frame.height >= Space.targetMin, "\(target.id) is \(target.frame.height) pt tall")
        }
    }

    @Test("the smallest shipped target is 56 × 44 — the Bench ramp cell")
    func smallestShippedTarget() throws {
        let all = Surface.allCases.flatMap { TargetInventory.targets(on: $0, device: .iPhoneSE) }
            .filter(\.isInteractive)
        let smallest = try #require(all.min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
        #expect(smallest.frame.size == CGSize(width: 56, height: 44))
        #expect(smallest.id == .benchRampCell)
    }

    @Test("independent targets are at least 8 pt apart", arguments: devices, Surface.allCases)
    func interTargetSpacing(_ device: ReferenceDevice, _ surface: Surface) {
        let targets = TargetInventory.targets(on: surface, device: device).filter(\.isInteractive)
        for (a, b) in targets.pairs() where a.semanticGroup != b.semanticGroup {
            #expect(a.frame.distance(to: b.frame) >= Space.s8, "\(a.id) and \(b.id) are \(a.frame.distance(to: b.frame)) pt apart")
        }
    }

    @Test("cells of one ramp are a single semantic group, so their 6 pt gutter is legal")
    func rampCellsAreOneGroup() {
        let cells = TargetInventory.targets(on: .round, device: .iPhoneSE).filter { $0.id == .dialRampCell }
        #expect(Set(cells.map(\.semanticGroup)).count == Glyph.Attribute.allCases.count)   // one group per ramp
    }

    // MARK: the three reach tiers

    @Test("tier 1 — every surface's commit controls live in the commit bar",
          arguments: devices, Surface.allCases)
    func commitControlsAreInTheCommitBar(_ device: ReferenceDevice, _ surface: Surface) {
        let commit = TargetInventory.targets(on: surface, device: device).filter { $0.tier == .commit }
        #expect(!commit.isEmpty, "\(surface) has no commit control")
        for target in commit {
            #expect(device.commitBar.contains(target.frame), "\(target.id) is outside the commit bar")
        }
    }

    @Test("tier 2 — composition controls sit at y ≥ 220, measured at the grid's NEAREST row",
          arguments: devices, Surface.allCases)
    func compositionControlsAreReachable(_ device: ReferenceDevice, _ surface: Surface) {
        for target in TargetInventory.targets(on: surface, device: device) where target.tier == .composition {
            #expect(target.nearestRowMinY >= 220, "\(target.id) starts at y = \(target.nearestRowMinY)")
        }
    }

    @Test("tier 3 — everything above y = 220 is read-only, or undo-shaped with a route inside the arc",
          arguments: devices, Surface.allCases)
    func aboveTheLineIsReadOnlyOrUndoShaped(_ device: ReferenceDevice, _ surface: Surface) {
        for target in TargetInventory.targets(on: surface, device: device) where target.frame.minY < 220 {
            switch target.tier {
            case .readOnly:
                #expect(!target.isInteractive, "\(target.id) is above the line and responds to touch")
            case .undoShaped(let sameEffectRoute):
                #expect(TargetInventory.route(sameEffectRoute, device: device).frame.minY >= 220,
                        "\(target.id)'s same-effect route is also above the line")
            case .commit, .composition:
                Issue.record("\(target.id) is a \(target.tier) control above y = 220")
            }
        }
    }

    @Test("there are exactly two undo-shaped controls, and they are the ones §12.8 names")
    func exactlyTwoUndoShapedControls() {
        let undoShaped = Surface.allCases
            .flatMap { TargetInventory.targets(on: $0, device: .iPhoneSE) }
            .filter { if case .undoShaped = $0.tier { true } else { false } }
        #expect(Set(undoShaped.map(\.id)) == [.ribbonTile, .echoRailTile])
    }

    @Test("the ribbon's load has the Dial as its same-effect route, and ECHO's rail return has the tray tile")
    func theTwoSameEffectRoutes() throws {
        let ribbon = try #require(TargetInventory.target(.ribbonTile, device: .iPhoneSE))
        let rail = try #require(TargetInventory.target(.echoRailTile, device: .iPhoneSE))
        #expect(ribbon.tier == .undoShaped(sameEffectRoute: .dialRampCell))
        #expect(rail.tier == .undoShaped(sameEffectRoute: .echoTrayTile))
        // The tray tile is a TOGGLE: tapping a placed tile a second time returns it.
        #expect(TargetInventory.echoTrayTileIsAToggle)
    }

    @Test("the Frame's idle Loom is deliberately unreachable and responds to nothing")
    func idleLoomIsScenery() throws {
        let loom = try #require(TargetInventory.target(.frameIdleLoom, device: .iPhoneSE))
        #expect(!loom.isInteractive)
        #expect(loom.frame.maxY < 300)
    }

    // MARK: the device rule

    @Test("every interactive target is within 460 pt of the bottom safe edge, on both devices",
          arguments: devices)
    func everythingIsWithinReach(_ device: ReferenceDevice) {
        for surface in Surface.allCases {
            for target in TargetInventory.targets(on: surface, device: device) where target.isInteractive {
                #expect(device.safeBottom - target.frame.midY <= 460, "\(target.id) on \(surface)")
            }
        }
    }

    @Test("the chevron and the play key draw at 24 pt inside a 44 × 44 hit rect")
    func smallGlyphsBigHitRects() throws {
        for id in [TargetID.leadingChevron, .playKey] {
            let target = try #require(TargetInventory.target(id, device: .iPhoneSE))
            #expect(target.frame.size == CGSize(width: 44, height: 44))
            #expect(target.drawnSize == CGSize(width: 24, height: 24))
        }
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter TargetsAndReachTests`

Missing `TargetInventory`, `TargetID`, `ReachTier`, `Surface`, `ReferenceDevice.commitBar/safeBottom`,
`CGRect.distance(to:)`. Two accidental passes to guard against: every `arguments:`-driven test passes
against an inventory that returns `[]`, so **before implementing anything else, make
`TargetInventory.targets(on:device:)` return the real lists and confirm `commitControlsAreInTheCommitBar`
fails on the surface you have not filled in yet.** And `exactlyTwoUndoShapedControls` passes against an
inventory with no tiers at all — check it fails with an empty set against the expected two.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/TargetInventory.swift` — `TargetID`, `Target`, `ReachTier`, `Surface`, and one `targets(on:device:)` per surface, composed from the shipped layout constants |
| modify | `Modules/Sources/HunchUI/ReferenceDevice.swift` *(E08·T02)* — `commitBar`, `safeBottom` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — `.contentShape` / frame corrections where a target measures under 44 |
| modify | `Modules/Sources/LoomFeature/BenchView.swift`, `EchoRoundView.swift`, `SieveRoundView.swift` — same |
| modify | `Modules/Sources/MetaFeature/FrameView.swift`, `AnomalyView.swift`, `ProfileView.swift` — same, plus the play key's 24-in-44 rect |
| modify | `Modules/Sources/CodexFeature/CodexRootView.swift`, `CodexShelfView.swift`, `CodexPageView.swift` — same |
| create | `Modules/Tests/HunchUITests/TargetsAndReachTests.swift` |
| modify | `tests.json` — the targets-and-reach entry (gate 8's reference-size half) |
| modify | `DECISIONS.md` — only if a shipped component had to move to clear a tier |

## Implementation notes

### The inventory reads the layout; it does not restate it

```swift
// Modules/Sources/HunchUI/TargetInventory.swift
public struct Target: Sendable {
    public let id: TargetID
    public let frame: CGRect                 // from the surface's own layout constants
    public let drawnSize: CGSize             // may be smaller than the hit rect (chevron, play key)
    public let isInteractive: Bool
    public let tier: ReachTier
    public let semanticGroup: SemanticGroup  // cells of one ramp share one group
    /// For a multi-cell grid, reach is measured at its NEAREST row (§12.8) — the grid is entered
    /// from below, and above AX2 it pages rather than growing (T06).
    public var nearestRowMinY: CGFloat { … }
}

public enum ReachTier: Hashable, Sendable {
    case commit                                        // the commit bar, on every surface
    case composition                                   // y ≥ 220
    case readOnly                                      // above the line, responds to nothing
    case undoShaped(sameEffectRoute: TargetID)         // above the line, but always has another way
}
```

`ReachTier` is the type that makes §12.8's rule structural: an interactive target above y = 220 must
be `.undoShaped`, and `.undoShaped` **cannot be constructed without naming another target**, which the
test then checks is inside the arc. There is no case for "above the line and interactive and that's
fine", so the rule is not a thing a reviewer has to remember.

Every `frame` is computed from the component's own layout constants — `Layout.dial(device:)`,
`Layout.bench(device:)`, `EchoLayout.tray(device:)`, `SieveLayout.gate(device:)` — never re-typed. If a
number appears literally in `TargetInventory.swift`, the file has become a second source of truth and
the next layout change will not reach it.

### The three tiers, and what each one actually protects

1. **Commit controls live in the commit bar, y 604–667, on every surface.** PROBE · twin · Bench on the
   Dial; Dial · Seal on the Bench; twin/replay · Seal in ECHO; pause in SIEVE. *The thing that ends a
   decision is always in the same place under the same thumb* — which is also why the Magic Tap has
   exactly two targets (T05) and why they are the two commit acts.
2. **Composition controls live at y ≥ 220.** The Dial's ramps, the Bench's rails and palette, the
   Frame's mode rack and shelf, ECHO's tray, SIEVE's gate. Reach for a multi-cell grid is measured at
   its **nearest** row, not its farthest, because the grid is entered from below.
3. **Everything above y = 220 is read-only.** Instrument bars, the throat, the ribbon, ECHO's primer
   strip, the Frame's idle Loom. The Loom is deliberately unreachable and is scenery, not a control.

### The two exceptions, and why they are not exceptions

Two controls sit above the line and both are **undo-shaped**, so each has a same-effect route inside
the arc:

- **The ribbon (176–228)** loads a tile into the Dial. The Dial can always compose that glyph
  directly — §4.1 calls ribbon-load a *mitigation*, not the route. The same-effect route is
  `.dialRampCell`, which is tier 2.
- **ECHO's rail (172–252)** returns a placed tile. **Tapping its tray tile a second time also does
  it** — the tray tile carries a placed state and is a toggle — so the whole of ECHO is playable
  without reaching above y = 220. The same-effect route is `.echoTrayTile`, and
  `TargetInventory.echoTrayTileIsAToggle` asserts the toggle actually exists rather than being a
  claim in prose.

Nothing else above the line responds to touch, and `exactlyTwoUndoShapedControls` is what stops a
third appearing quietly.

### Both devices

On a Pro Max the same layout **letterboxes vertically**: the commit bar stays pinned to the safe-area
bottom and the Loom region absorbs the extra height, so reach does not degrade with device size. That
is why `everythingIsWithinReach` is parameterised over both devices rather than being written once for
the SE — a rule that only holds on the smaller device is a rule that will break the day a larger one
ships.

### Spacing, and the one legal 6 pt gutter

Inter-target spacing is ≥ 8 pt **between independent targets**. The Dial's 6 pt gutter is between
*cells of one ramp*, which are a single semantic group and not independent targets — a single-select
control with four positions, like a segmented control. `SemanticGroup` carries that, and
`rampCellsAreOneGroup` asserts the four ramps are four groups rather than one, so the exemption cannot
be widened to "any two cells anywhere are one group".

### What to do when a target measures under 44

Fix the **hit rect**, not the drawing. `.contentShape(Rectangle())` inside a `.frame(minWidth: 44,
minHeight: 44)` gives a 24 pt chevron a 44 pt target without touching a single stroke. Do **not** grow
the mark to reach 44, and do not shrink a neighbour to make room — §12.8 is explicit that targets never
shrink and rows grow instead. If a genuine conflict appears, it is a layout bug in the owning epic and
the fix belongs there with a `DECISIONS.md` entry.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter TargetsAndReachTests` green, all eleven tests, parameterised over **both** devices and **every** surface.
- [ ] `TargetInventory.swift` contains no numeric literal other than `0` and `1` — every frame is composed from a layout constant. Read the file and confirm.
- [ ] The smallest shipped interactive target measures exactly 56 × 44 and is the Bench ramp cell.
- [ ] `ReachTier` has no case that is both interactive and above the line without naming a route — read the enum and confirm.
- [ ] Exactly two targets are `.undoShaped`, and they are the ribbon tile and ECHO's rail tile.
- [ ] `grep -Rn 'contentShape' Modules/Sources --include='*.swift'` shows one per target whose drawn size is smaller than its hit rect, and no others.
- [ ] `tests.json` carries the targets-and-reach entry, `source: "§12.8"`.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T07: targets ≥ 44 × 44 and the three reach tiers, on both devices"`

## Out of scope

- The AX5 hit-region audit in five locales — **T11**; this task is the reference-size half of gate 8.
- Each surface's layout constants — **E08·T02**, **E09·T01**, **E13·T05**, **E14·T02**, **E17·T03**. A target that cannot be made 44 × 44 without moving a region is their bug.
- The Dynamic Type re-flows that keep targets legal above AX2 — **T06**.
- Left-hand keys, which mirror only the commit-bar order and the handle side — **E17·T06**; mirroring does not change a target's size or tier.
- The gesture inventory (no drag, pinch, long-press) — **E09·T03**.
