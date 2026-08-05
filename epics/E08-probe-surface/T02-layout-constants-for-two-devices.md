# T02 — Layout constants for two devices

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 PROBE → *Play surface layout* · §14.1 ACCESSIBILITY → *Targets and reach* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Every space, inset and gutter in the layout resolves to `Space.*` or to a `C.<Component>` member; the skill also owns `env.artScale` and the rule that art scales while chrome does not, which is what decides whether a region grows under Dynamic Type. Load it first — the other two assume its vocabulary. |
| `hunch-bench-instruments` | Standing rule 4 ("art scales, chrome does not; above AX2 an instrument pages rather than shrinks") and the reach argument that makes the throat and the ribbon legal above y = 220 are this skill's, and this task is where both become code. |
| `hunch-chrome-and-meta` | `instrument-bar.md` §2 is the ruling that `y 20–64` is the bar *at Dynamic Type Large on the reference device*, not a constant — the single most likely defect in this task. |

## Objective

`PlaySurfaceLayout` turns a screen size and its safe-area insets into §6.2's seven named regions, on both reference devices, with the surplus height going to the throat and the ribbon while the Dial, the handle and the commit bar lay out upward from the bottom safe edge. `RoundView` exists as the shell that positions its (still empty) regions from it, and the 460 pt reach predicate is asserted rather than remembered.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.2 | The region table for both devices, the surplus-height decision, `nominalPitch` / `rowWidth` / `tickPitch`, the thumb-reach paragraph and the visible-history counts |
| `GAME_DESIGN.md` | §4.1 | The SE reference table §6.2 is "canon verbatim" of, including the Dial's row arithmetic |
| `GAME_DESIGN.md` | §12.8 | The three reach tiers, the ≥ 44 pt target floor, the ≥ 8 pt inter-target floor and its intra-group exemption, and the Dynamic Type table |
| `GAME_DESIGN.md` | §6.7 | "The throat and the ribbon do not move" between Dial mode and Bench mode — the constraint this layout has to make structurally true |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | Why `tickPitch` is `HunchUI`'s and `Band.par`/`Band.cap` are `HunchCore`'s |
| `hunch-chrome-and-meta` | `references/instrument-bar.md` §1–§2 | The three slots, the resolved height, and `centre = screenWidth − 88` versus §6.2's `rowWidth` |

Do not restate a coordinate anywhere but in this one type. Every other file in the epic asks the layout.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/PlaySurfaceLayoutTests.swift`:

```swift
import Testing
import CoreGraphics
import ModulesTestSupport
import HunchUI

@Suite("PlaySurfaceLayout — §6.2 region for region", .tags(.unit, .presubmission))
struct PlaySurfaceLayoutTests {

    private static let se = PlaySurfaceLayout(
        size: CGSize(width: 375, height: 667), safeAreaTop: 20, safeAreaBottom: 0)
    private static let proMax = PlaySurfaceLayout(
        size: CGSize(width: 440, height: 956), safeAreaTop: 62, safeAreaBottom: 34)

    @Test("iPhone SE 2/3 — 375 × 667, safe 375 × 647")
    func seRegions() {
        let l = Self.se
        #expect(l.instrumentBar == CGRect(x: 0, y: 20, width: 375, height: 44))
        #expect(l.throat        == CGRect(x: 0, y: 64, width: 375, height: 112))
        #expect(l.ribbon        == CGRect(x: 0, y: 176, width: 375, height: 52))
        #expect(l.bezelGap      == nil)
        #expect(l.dial          == CGRect(x: 0, y: 236, width: 375, height: 272))
        #expect(l.benchHandle   == CGRect(x: 0, y: 516, width: 375, height: 44))
        #expect(l.commitBar     == CGRect(x: 0, y: 604, width: 375, height: 63))
        #expect(l.ribbonLanes == 1)
    }

    @Test("iPhone 16 Pro Max — 440 × 956, safe y 62…922")
    func proMaxRegions() {
        let l = Self.proMax
        #expect(l.instrumentBar == CGRect(x: 0, y: 62, width: 440, height: 44))
        #expect(l.throat        == CGRect(x: 0, y: 106, width: 440, height: 200))
        #expect(l.ribbon        == CGRect(x: 0, y: 306, width: 440, height: 114))
        #expect(l.bezelGap      == CGRect(x: 0, y: 420, width: 440, height: 50))
        #expect(l.dial          == CGRect(x: 0, y: 470, width: 440, height: 342))
        #expect(l.benchHandle   == CGRect(x: 0, y: 820, width: 440, height: 44))
        #expect(l.commitBar     == CGRect(x: 0, y: 868, width: 440, height: 54))
        #expect(l.ribbonLanes == 2)
    }

    @Test("The regions tile the safe area exactly, in order, with no overlap",
          arguments: [Self.se, Self.proMax])
    func regionsTileTheSafeArea(_ l: PlaySurfaceLayout) {
        let boxes = l.orderedRegions
        #expect(boxes.first?.minY == l.safeTop)
        #expect(boxes.last?.maxY == l.safeBottom)
        for (upper, lower) in zip(boxes, boxes.dropFirst()) {
            #expect(upper.maxY <= lower.minY)                       // no overlap
        }
        // Every point of the safe area is either a region or a declared gap: the sum of the
        // regions plus the sum of the gaps is the safe height, on both devices.
        let regionHeight = boxes.reduce(0) { $0 + $1.height }
        let gapHeight = zip(boxes, boxes.dropFirst()).reduce(0) { $0 + ($1.1.minY - $1.0.maxY) }
        #expect(regionHeight + gapHeight == l.safeBottom - l.safeTop)
    }

    @Test("Surplus height goes to the throat and the ribbon, never to the commit bar")
    func surplusGoesToTheEvidence() {
        let se = Self.se, big = Self.proMax
        let surplus = (big.safeBottom - big.safeTop) - (se.safeBottom - se.safeTop)
        let evidenceGain = (big.throat.height + big.ribbon.height)
                         - (se.throat.height + se.ribbon.height)
        #expect(surplus > 0)
        #expect(evidenceGain > surplus / 2)                          // the majority of it
        #expect(big.commitBar.height <= se.commitBar.height)          // the controls do not inflate
        #expect(big.benchHandle.height == se.benchHandle.height)
        #expect(big.instrumentBar.height == se.instrumentBar.height)
    }

    @Test("Every interactive target is within 460 pt of the bottom safe edge",
          arguments: [Self.se, Self.proMax])
    func reach(_ l: PlaySurfaceLayout) {
        for region in l.interactiveRegions {
            #expect(l.safeBottom - region.minY <= 460)
        }
        // §12.8 tier 3: everything above y = 220 is read-only, and these two are above it.
        #expect(l.readOnlyRegions.contains(l.throat))
        #expect(l.readOnlyRegions.contains(l.ribbon))
        #expect(l.interactiveRegions.contains(l.throat) == false)
        #expect(l.interactiveRegions.contains(l.ribbon) == false)
    }

    @Test("The Dial's top edge barely moves across a 289 pt difference in screen height")
    func theDialStaysInTheThumbArc() {
        let seReach = Self.se.safeBottom - Self.se.dial.minY          // 411
        let bigReach = Self.proMax.safeBottom - Self.proMax.dial.minY // 452
        #expect(bigReach - seReach < 60)
        #expect(bigReach <= 460)
    }
}
```

And `Modules/Tests/HunchUITests/TickPitchTests.swift` — the epic gate's row 5:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import HunchUI

@Suite("The par row is length-proportional at constant pitch", .tags(.unit, .presubmission))
struct TickPitchTests {

    @Test("tickPitch = min(nominalPitch, rowWidth / N), and inside PROBE it never clamps",
          arguments: Band.allCases)
    func pitchIsNeverClampedInProbe(_ band: Band) {
        for layout in [PlaySurfaceLayout.reference(.compact), .reference(.large)] {
            let total = band.par(for: .probe)
            let pitch = layout.tickPitch(total: total)
            #expect(pitch == layout.nominalTickPitch)                       // unclamped
            #expect(pitch * Double(total) <= layout.tickRowWidth)           // and it fits
        }
    }

    @Test("The row's length is proportional to par, which is the only difficulty signal")
    func lengthIsProportionalToPar() {
        let layout = PlaySurfaceLayout.reference(.compact)
        let short = layout.tickRowLength(total: Band.literal.par(for: .probe))
        let long = layout.tickRowLength(total: Band.systemic.par(for: .probe))
        let parRatio = Double(Band.systemic.par(for: .probe)) / Double(Band.literal.par(for: .probe))
        #expect(long / short == parRatio)
    }

    @Test("The clamp engages only past the row's budget — DRIFT band 8's 40 ticks")
    func theClampEngagesAtFortyTicks() {
        let se = PlaySurfaceLayout.reference(.compact)
        let big = PlaySurfaceLayout.reference(.large)
        #expect(se.tickPitch(total: 40) == se.tickRowWidth / 40)
        #expect(big.tickPitch(total: 40) == big.tickRowWidth / 40)
        #expect(se.tickPitch(total: 40) < se.nominalTickPitch)
        // The tick stays 2 pt wide, so the gap must stay positive and legible.
        #expect(se.tickPitch(total: 40) - C.TickRow.tickWidth >= 5)
    }

    @Test("Dynamic Type scales tick heights and never the pitch")
    func artScaleNeverReachesThePitch() {
        let layout = PlaySurfaceLayout.reference(.compact)
        let plain = layout.tickPitch(total: Band.systemic.par(for: .probe))
        let large = layout.tickPitch(total: Band.systemic.par(for: .probe), artScale: 1.35)
        #expect(plain == large)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/PlaySurfaceLayoutTests -only-testing:HunchUITests/TickPitchTests
```

It must fail on `cannot find 'PlaySurfaceLayout' in scope`. If it fails on `tickPitch(total:artScale:)` having no default argument, that is also the right kind of failure — a missing symbol, not a malformed suite.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/PlaySurfaceLayout.swift` |
| create | `Modules/Sources/HunchUI/CommitBar.swift` |
| create | `Modules/Sources/LoomFeature/RoundView.swift` |
| create | `Modules/Tests/HunchUITests/PlaySurfaceLayoutTests.swift` |
| create | `Modules/Tests/HunchUITests/TickPitchTests.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| modify | `DECISIONS.md` |

## Implementation notes

**The type.** A `struct`, `Equatable`, `Sendable`, initialised from `(size, safeAreaTop, safeAreaBottom)` and holding seven stored `CGRect`s plus the row metrics. It reads no environment and no `UIScreen`; the caller passes what `GeometryReader` and `safeAreaInsets` gave it, which is what makes the whole thing testable on the host.

```swift
public struct PlaySurfaceLayout: Equatable, Sendable {
    public enum DeviceClass: Equatable, Sendable { case compact, large }   // SE · Pro Max

    public let deviceClass: DeviceClass
    public let safeTop: Double, safeBottom: Double
    public let instrumentBar, throat, ribbon, dial, benchHandle, commitBar: CGRect
    public let bezelGap: CGRect?              // Pro Max only — a machined dead band, no controls
    public let ribbonLanes: Int               // 1 · 2
    public let nominalTickPitch: Double       // §6.2
    public let tickRowWidth: Double           // §6.2 — the row's own budget, not the bar's slot

    public init(size: CGSize, safeAreaTop: Double, safeAreaBottom: Double)
    public static func reference(_ deviceClass: DeviceClass) -> Self

    public var orderedRegions: [CGRect]       // top to bottom, gaps excluded
    public var interactiveRegions: [CGRect]   // dial, benchHandle, commitBar
    public var readOnlyRegions: [CGRect]      // instrumentBar, throat, ribbon (§12.8 tier 3)

    public func tickPitch(total: Int, artScale: Double = 1) -> Double
    public func tickRowLength(total: Int) -> Double
    public func dialRow(_ index: Int) -> CGRect
}
```

**The derivation rule, in the order it must be applied.** Getting this order wrong produces a layout that is correct on the SE and wrong on everything else:

1. **The commit bar, the handle and the Dial are laid out upward from `safeBottom`**, at their device-class heights. They must stay inside the thumb arc, which is anchored to the bottom edge and not to the screen height (§6.2's decision).
2. **The instrument bar sits at `safeTop`** at its resolved height — `44` on a play surface, because a play surface has zero text and therefore nothing that can wrap (`instrument-bar.md` §2). Do **not** write `.padding(.top, 64)` or `.offset(y: 64)` anywhere; every region below the bar is positioned relative to the bar's resolved `maxY`.
3. **The throat and the ribbon absorb what is left**, in that order, with the Pro Max bezel gap taken out first. The gap is a machined dead band and carries no controls.
4. **`ribbonLanes` follows the ribbon's height**, not the device name: one lane where the region holds one 44 pt tile row, two where it holds two at 50 pt pitch.

**The Pro Max commit bar — a spec conflict you must resolve and record.** §6.2's table gives the region as `y 868–922`, which is **54 pt**, and then describes the same row as "60 pt tall". Both cannot be true. **The coordinates win**: they are what the region table is for, they are what the safe-area arithmetic closes against (`44 + 200 + 114 + 50 + 342 + 44 + 54` plus the declared gaps = 860 = 922 − 62), and 54 pt still clears §12.8's 44 pt target floor with room for the 4 pt inter-key gutter. Record the conflict and the resolution in `DECISIONS.md` in one line, naming both readings, so the next reader does not "fix" it back.

**The SE Dial's 8 pt residual.** §4.1 gives `4 rows × 60 pt, 8 pt gutters` inside a 272 pt region: `4 × 60 + 3 × 8 = 264`, leaving 8 pt. Put the residual at the **bottom** of the region so `dialRow(0).minY == dial.minY` — the first ramp sits directly under the ribbon and the Dial's top edge is exactly the 411 pt of §6.2's reach paragraph. Assert `dialRow(3).maxY <= dial.maxY`. On Pro Max there is no residual: `4 × 78 + 3 × 10 = 342` exactly.

**`tickRowWidth` is not the bar's centre slot.** `instrument-bar.md` §1: the slot is `screenWidth − 88` (287 SE / 352 Pro Max) and §6.2's `rowWidth` of 288 / 348 is the row's own budget for the pitch arithmetic. Store both facts separately; the row centres inside the slot. At PROBE's longest par the row is 261 pt and nowhere near either bound, so nothing is at risk today — the point is that the two numbers have different owners and must not be merged.

**`RoundView` in this task is a shell.** It reads the layout out of a `GeometryReader`, places six empty regions with `.frame`/`.position`, and installs `CommitBarView` with three slots (leading / centre / trailing) as view builders — a slot abstraction, because §12.6's Left-hand keys setting mirrors *only* the commit bar order and the Bench handle side, and that is impossible to do later against three hard-coded children. It carries **no `Text`, no `Label`, no `AttributedString`** (§12.9), and check 7 of `check-source-hygiene.sh` will start policing it from this commit onward.

**Dynamic Type.** `env.artScale` multiplies *lengths inside* a region — the glyph box, the Dial cell — and never a region origin and never the tick pitch (`tick-row.md` §5 works out why: scaling the pitch engages the clamp inside PROBE and distorts the only difficulty signal the player is given). Above AX2 the Dial scrolls vertically inside its region rather than growing it (§13.11); the region rectangle is unchanged, which is why this type has no `artScale` in its initialiser.

## Acceptance criteria

- [ ] `PlaySurfaceLayoutTests` and `TickPitchTests` are green on both simulators.
- [ ] `grep -rn '\.padding(\.top, 6[0-9])\|offset(y: 6[0-9])\|frame(height: 44)' Modules/Sources/LoomFeature Modules/Sources/HunchUI` returns nothing — no hardcoded bar height or origin.
- [ ] `grep -rn '375\|667\|440\|956\|288\|348' Modules/Sources --include='*.swift' | grep -v PlaySurfaceLayout.swift` returns nothing: the geometry has exactly one home.
- [ ] `grep -n 'Text(\|Label(\|AttributedString' Modules/Sources/LoomFeature/RoundView.swift` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` passes with a deliberately planted `Text("x")` in `RoundView.swift` **failing** check 7, and passing again once removed.
- [ ] `DECISIONS.md` records the Pro Max commit-bar 54-versus-60 resolution and the SE Dial's 8 pt residual placement.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; both `HunchUITests` filters green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T02: PlaySurfaceLayout for both reference devices, with the reach and pitch invariants"`

## Out of scope

- Drawing anything inside a region. The throat is **T03**, the Dial **T04**, the ribbon **T05**, the tick row **T08**.
- Bench-mode geometry — rails at 291 pt, the 64 pt Assay column, the palette at y 560–604 — **E09·T01**. This task must make it *possible* for the throat and ribbon rectangles to be identical in both modes; it does not build the second mode.
- The Dial ↔ Bench interactive drag and the 380 ms transition — **E09·T01**.
- The mode sigil and the chevron's action in the instrument bar — **E17·T04**, **E10·T04**.
- The AX2+ pager substitutions across all screens — **E19·T06**. This task only refuses to grow a region under Dynamic Type.
