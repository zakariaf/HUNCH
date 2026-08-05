# T05 — Tray and rail

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | Tray and rail (ECHO) · Targets and reach (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load first: the tray cell, the rail pitch and the glyph sizes are all L2 members of `C.Echo` / `C.Ribbon` and a literal `84` in a view fails hygiene check 9. It also owns `env.artScale` and its 1.35× ceiling, which is what decides the tray pages rather than grows. |
| `hunch-bench-instruments` | `references/ribbon.md` §3 already declares ECHO's rail as one of four surfaces of **one** drawing and already lists `placed` as a tile state. This task adds the fifth surface — the tray — to the same component rather than writing a second tile. The skill also owns the ruling that the tray tile is a *toggle*, which is the whole reach argument. |
| `hunch-accessibility` | The tray tile is the only control in the game whose `.isSelected` trait carries game state, and the rail tile's `"Return to the tray"` custom action is the alternative to a gesture VoiceOver cannot make. `references/voiceover-elements.md` §6 is the element index, and a row that is not in it is a row that drifts. |
| `hunch-shared-marks` | The rail's link arcs are `LinkArc.draw` with the `.arc` variant — one owning function, six sites, and `references/link-arc.md` names the ECHO rail as one of them. Drawing a second arc here is the §2(g) divergence in one commit. |

## Objective

At the end of this task the recall surface exists and is complete: a tray re-presenting every cast
glyph as an 84 × 72 pt cell in canonical `glyphID` order — the Assay's order, so it is already
spatially familiar — and a rail holding the ordered answer, with tap to lift and tap to return. The
tray tile carries a `placed` state and is a toggle, which is what makes the whole of ECHO playable
without reaching above `y = 220`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.3 (final paragraph) | the tray holds all `L` cast glyphs re-presented as tiles in canonical `glyphID` order — the Assay's order, therefore already spatially familiar; not cast order, not shuffled, a deterministic neutral index. The rail holds the player's answer, initially empty. A tap lifts a tile to the trailing end of the rail; tapping a rail tile returns it; the Seal commits |
| `GAME_DESIGN.md` | §8.4 (rail and tray rows, and the paragraph under the table) | rail y 172–252, 44 pt tiles + link arcs, horizontal scroll, leading→trailing in every locale; tray y 260–572, 4-column grid of 84 × 72 pt cells (`4·84 + 3·8 = 360` in 375), rows filled leading→trailing, glyph at 52 pt, at most 4 rows and at maximum load the final row is short by two; negative space 572–604; commit bar 604–667; every target ≥ 44 × 44, the smallest being the tray cell; at AX2+ the tray becomes a two-column pager |
| `GAME_DESIGN.md` | §12.8 (the three reach tiers, and the two-controls paragraph) | commit controls at 604–667 on every surface; composition controls at `y ≥ 220`; everything above 220 read-only, with exactly two undo-shaped exceptions — one of which is ECHO's rail, whose same-effect route inside the arc is the tray tile's second tap |
| `GAME_DESIGN.md` | §13.10 / §8.4 | the rail container, rail tile and tray tile element rows: traits, labels, values, and the one custom action |
| `GAME_DESIGN.md` | §2 (locked terminology), §11.2 | canonical `glyphID` order is `fill → shape → pips → hue`, and it never mirrors — it is an index, not a reading direction |
| `GAME_DESIGN.md` | §8.10 RAIL-OVERFILL | placing all `L` tiles is legal; there is no cap below `L` |
| `GAME_DESIGN.md` | §12.8 (RTL table) | the rail's leading edge mirrors; the glyphs inside it never do |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | the rail's *contents* are a core value; the rail's *geometry* is `HunchUI` |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/RoundsTests/EchoRailTests.swift`:

```swift
import Testing
@testable import Rounds
import HunchTestSupport

@Suite("EchoRail — the ordered answer", .tags(.unit, .presubmission))
struct EchoRailTests {

    @Test("a placed index lands at the trailing end, in placement order")
    func placementOrder() {
        var rail = EchoRail()
        rail.place(4); rail.place(0); rail.place(9)
        #expect(rail.placed == [4, 0, 9])          // §8.7's `answer`: placement order, not sorted
    }

    @Test("returning a tile removes it and closes the gap without reordering the rest")
    func returnClosesTheGap() {
        var rail = EchoRail()
        for index in [4, 0, 9, 2] { rail.place(index) }
        rail.remove(0)
        #expect(rail.placed == [4, 9, 2])
    }

    @Test("placing an already-placed index is a no-op, not a duplicate")
    func placingTwiceIsANoOp() {
        var rail = EchoRail()
        rail.place(3); rail.place(3)
        #expect(rail.placed == [3])
    }

    @Test("position(of:) is 1-based for VoiceOver and nil for an unplaced tile")
    func positionLookup() {
        var rail = EchoRail()
        rail.place(7); rail.place(1)
        #expect(rail.position(of: 7) == 1)
        #expect(rail.position(of: 1) == 2)
        #expect(rail.position(of: 5) == nil)
    }

    @Test("there is no cap below L — RAIL-OVERFILL is legal", arguments: LoadIndex.allCases)
    func railAcceptsEveryCastGlyph(_ load: LoadIndex) {
        var rail = EchoRail()
        for index in 0..<load.length { rail.place(index) }
        #expect(rail.placed.count == load.length)
    }

    @Test("the rail round-trips through Codable, because §8.9 persists its contents")
    func roundTrips() throws {
        var rail = EchoRail()
        for index in [5, 2, 11] { rail.place(index) }
        let data = try JSONEncoder().encode(rail)
        #expect(try JSONDecoder().decode(EchoRail.self, from: data) == rail)
    }
}
```

`Modules/Tests/LoomFeatureTests/EchoTrayAndRailTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature
import ModulesTestSupport

@Suite("Tray and rail — §8.4", .tags(.unit, .presubmission))
@MainActor
struct EchoTrayAndRailTests {

    @Test("the tray is a 4-column grid of 84 × 72 cells that fits the SE exactly")
    func trayGeometry() {
        let tray = TrayLayout(count: 14, width: Device.se.width, env: .reference)
        #expect(tray.columns == 4)
        #expect(tray.cell == CGSize(width: C.Echo.trayCellWidth, height: C.Echo.trayCellHeight))
        #expect(tray.contentWidth == 4 * C.Echo.trayCellWidth + 3 * C.Echo.trayGutter)
        #expect(tray.contentWidth <= Device.se.width)
        #expect(tray.frame.minY == C.Echo.trayTop)
    }

    @Test("at maximum load the tray is four rows and the last is short by two")
    func maximumLoadLayout() {
        let tray = TrayLayout(count: LoadIndex.eight.length, width: Device.se.width, env: .reference)
        #expect(LoadIndex.eight.length == 14)
        #expect(tray.rows == 4)
        #expect(tray.itemsInLastRow == 2)
        #expect(tray.contentHeight <= C.Echo.trayHeight)
    }

    @Test("tiles are in canonical glyphID order, not cast order", arguments: LoadIndex.allCases)
    func canonicalOrder(_ load: LoadIndex) {
        let cast = Fixtures.echoCast(load: load)
        let tray = TrayModel(cast: cast.presentation(cadence: load.cadence))
        #expect(tray.tiles.map(\.glyph.glyphID) == tray.tiles.map(\.glyph.glyphID).sorted())
        #expect(tray.tiles.map(\.glyph) != cast.glyphs || cast.glyphs == cast.glyphs.sorted { $0.glyphID < $1.glyphID })
        #expect(Set(tray.tiles.map(\.castIndex)) == Set(0..<load.length))
    }

    @Test("tapping a tray tile lifts it to the trailing end of the rail")
    func tapLifts() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.tapTray(castIndex: 6)
        round.tapTray(castIndex: 2)
        #expect(round.rail.placed == [6, 2])
        #expect(round.trayState(of: 6) == .placed(position: 1))
        #expect(round.trayState(of: 2) == .placed(position: 2))
    }

    @Test("tapping a placed tray tile returns it — the toggle that carries the reach argument")
    func trayTileIsAToggle() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.tapTray(castIndex: 6)
        round.tapTray(castIndex: 6)
        #expect(round.rail.placed.isEmpty)
        #expect(round.trayState(of: 6) == .available)
    }

    @Test("tapping a rail tile returns it, with the identical effect as the tray toggle")
    func railTapReturns() {
        let a = Fixtures.echoRound(phase: .recalling)
        a.tapTray(castIndex: 3); a.tapTray(castIndex: 8); a.tapRail(castIndex: 3)

        let b = Fixtures.echoRound(phase: .recalling)
        b.tapTray(castIndex: 3); b.tapTray(castIndex: 8); b.tapTray(castIndex: 3)

        #expect(a.rail == b.rail)                    // §12.8: a same-effect route inside the arc
    }

    @Test("the rail draws a link arc between consecutive placements")
    func railLinkArcs() {
        let round = Fixtures.echoRound(phase: .recalling)
        for index in [1, 4, 7] { round.tapTray(castIndex: index) }
        #expect(RenderProbe(EchoRoundView(round: round, env: .reference)).linkArcCount == 2)
    }

    @Test("at AX2 and above the tray pages at two columns rather than shrinking")
    func trayPagesAtAX2() {
        let tray = TrayLayout(count: 14, width: Device.se.width, env: .ax2)
        #expect(tray.columns == 2)
        #expect(tray.isPaged)
        #expect(tray.cell.width >= C.Echo.trayCellWidth)      // it grew; it did not shrink
    }
}

@Suite("ECHO reach and targets — §12.8", .tags(.unit, .presubmission))
@MainActor
struct EchoReachTests {

    private var surface: RenderProbe { RenderProbe(EchoRoundView(round: Fixtures.echoRound(phase: .recalling),
                                                                 env: .reference)) }

    @Test("every hit target is at least 44 × 44, and the smallest is the tray cell")
    func targetFloor() {
        let targets = surface.hitTargets
        #expect(!targets.isEmpty)
        #expect(targets.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        #expect(targets.map(\.height).min() == C.Echo.trayCellHeight)
    }

    @Test("inter-target spacing is at least 8 pt everywhere")
    func interTargetSpacing() {
        #expect(surface.minimumInterTargetGap >= 8)
    }

    @Test("every target except the rail sits at y ≥ 220, and the rail has a same-effect route")
    func reachTiers() {
        let aboveTheLine = surface.hitTargets.filter { $0.minY < 220 }
        #expect(aboveTheLine.allSatisfy { $0.role == .railTile })
        #expect(surface.roles(at: .commitBar) == [.replayKey, .seal])
        #expect(EchoRoundView.railActionHasTrayEquivalent)     // asserted, not assumed
    }

    @Test("the pool strip and the primer strip are exempt because they are not targets")
    func readOnlyStripsAreExempt() {
        #expect(!surface.hitTargets.contains { $0.role == .poolMember || $0.role == .primerGlyph })
    }
}

@Suite("Tray and rail — VoiceOver", .tags(.unit, .presubmission))
@MainActor
struct EchoTrayAccessibilityTests {

    @Test("the rail is a container whose value counts placements against L, not against 16")
    func railContainerValue() {
        let round = Fixtures.echoRound(phase: .recalling, load: .five)   // L = 11
        round.tapTray(castIndex: 0); round.tapTray(castIndex: 5)
        let rail = AccessibilityProbe(EchoRoundView(round: round, env: .reference)).element(.rail)
        #expect(rail.label == Loc.rail)
        #expect(rail.value == Loc.railPlacement(placed: 2, of: 11))
    }

    @Test("a rail tile is a button valued by position and carries the return action")
    func railTileElement() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.tapTray(castIndex: 4)
        let tile = AccessibilityProbe(EchoRoundView(round: round, env: .reference)).element(.railTile(0))
        #expect(tile.traits.contains(.isButton))
        #expect(tile.value == Loc.railPosition(1))
        #expect(tile.customActions == [Loc.returnToTheTray])
    }

    @Test("a tray tile is selected when placed and says where it went")
    func trayTileElement() {
        let round = Fixtures.echoRound(phase: .recalling)
        round.tapTray(castIndex: 4)
        let probe = AccessibilityProbe(EchoRoundView(round: round, env: .reference))
        #expect(probe.element(.trayTile(4)).traits.contains(.isSelected))
        #expect(probe.element(.trayTile(4)).value == Loc.trayPlaced(position: 1))
        #expect(!probe.element(.trayTile(5)).traits.contains(.isSelected))
        #expect(probe.element(.trayTile(5)).value == Loc.trayNotPlaced)
    }

    @Test("the surface renders no character outside an accessibility modifier")
    func noTextOnThePlaySurface() throws {
        for path in SourcePath.echoViewSurface {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            #expect(source.textViewsOnlyInsideAccessibilityModifiers)
        }
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter EchoRailTests`, then
`xcodebuild test … -only-testing:LoomFeatureTests/EchoTrayAndRailTests` and `…/EchoReachTests` and
`…/EchoTrayAccessibilityTests`. Missing symbols only.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/EchoRail.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Echo` tray and rail geometry |
| create | `Modules/Sources/LoomFeature/EchoTrayView.swift` |
| create | `Modules/Sources/LoomFeature/TrayLayout.swift` |
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` — the `echoRail` and `echoTray` surfaces and the `placed` tile state |
| modify | `Modules/Sources/LoomFeature/EchoRound.swift` — `tapTray`, `tapRail`, `trayState(of:)` |
| modify | `Modules/Sources/LoomFeature/EchoRoundView.swift` — the recall layout |
| modify | `Modules/Sources/HunchUI/Loc.swift` — six accessibility strings |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — six keys |
| create | `HunchCore/Tests/RoundsTests/EchoRailTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/EchoTrayAndRailTests.swift` |
| modify | `tests.json` — five entries |

## Implementation notes

### The rail is a value; the rail is also a ribbon

Split them cleanly. `EchoRail` in `HunchCore` is `[Int]` of cast indices in placement order with four
operations and no geometry — it is what §8.9 persists and what §8.7 calls `answer`. `RibbonCanvas`
in `HunchUI` draws it, as the fifth surface of the one ribbon component:

| Surface | Tile side | Rings | Placeable |
|---|---|---|---|
| PROBE / DRIFT ribbon | `C.Ribbon.tileGlyph` | yes | no |
| ECHO cast (T04) | `C.Ribbon.tileGlyph` | **no** | no |
| ECHO rail | `C.Ribbon.echoRailGlyph` | no | yes — tap returns |
| ECHO tray | `C.Echo.trayCellHeight` cell, `C.Echo.trayGlyph` glyph | no | yes — tap toggles |
| SIEVE tail | `C.Ribbon.tailGlyph` | yes | no |

`references/ribbon.md` §8's first "wrong" is re-implementing the ribbon for ECHO's rail; its `placed`
state is already in the state table. Add the surface case and the `placed` drawing there, and let
`EchoTrayView` own only the *grid*, which is genuinely new.

### The tray's order, and why it is the only defensible one

Canonical `glyphID` order — `fill·64 + shape·16 + pips·4 + hue` — is the Assay's order (§4.3, §11.2),
so the player has already spent every round of PROBE reading the same index. §8.3 rules out the two
alternatives explicitly and both would be design errors, not preferences:

- **Cast order** would hand the player the answer's ordering component for free, and `order` is 30 % of the score.
- **Shuffled** would make the tray a search task on top of a recall task, and re-shuffling between a replay and the rail would make it a different search each time.

A deterministic neutral index is the only ordering under which the tray adds no information and
removes no information. Sort by `glyphID`; do not mirror under RTL (the deck order is an index, not a
reading direction — §12.8's RTL table); do fill rows leading→trailing, which does mirror.

### The toggle, and the reach argument it carries

§12.8 tier 3 says everything above `y = 220` is read-only, and names exactly two exceptions, both
undo-shaped. ECHO's rail is one: it sits at 172–252, and its one action — return a placed tile — has
a same-effect route inside the thumb arc, because **the tray tile is a toggle**. So:

```swift
func tapTray(castIndex: Int) {
    guard phase == .recalling else { return }
    if rail.contains(castIndex) { rail.remove(castIndex) } else { rail.place(castIndex) }
}

func tapRail(castIndex: Int) {
    guard phase == .recalling else { return }
    rail.remove(castIndex)
}
```

`EchoRoundView.railActionHasTrayEquivalent` is a static `Bool` computed from the two functions' shared
implementation, asserted by `EchoReachTests.reachTiers`. It looks like a tautology and is not: the
moment someone gives the rail a second action (reorder, insert, swap) the assertion has to be updated
by hand, and updating it is the point at which they notice they have broken §12.8. Keep the tray tile
a toggle rather than a "place" button plus a separate "remove" gesture — a long-press to remove is
precisely the gesture VoiceOver cannot make (§4.2, §12.8), which is why the declaration UI bans it.

### Dynamic Type: the tray pages, it does not shrink

§13.11: art scales to a 1.35× ceiling, and at AX2 and above ECHO's tray becomes a **two-column
pager**. The rule that matters is the one `hunch-bench-instruments` states for the Bench and
`references/environment-settings.md` repeats for the tray: the grid *pages rather than grows*, and
reach for a multi-cell grid is measured at its **nearest** row because the grid is entered from below.
So the cell grows with `env.artScale`, the column count drops to two, and the rows that no longer fit
go onto a second page — never a smaller cell, never a scaled-down glyph, never `minimumScaleFactor`.
The pool strip wraps to two rows of four at the same threshold (T02).

### The three accessibility elements, and one number in the spec that is illustrative

`references/voiceover-elements.md` §6 and §13.10 give the rail container `"2 of 16 placed"`. **16 is
not a constant** — `L ≤ 14` at every row of the `ℓ` table — so it is an example of the format, and the
shipped string interpolates `(placed, of: L)`. Ship `Loc.railPlacement(placed:of:)` as one format
string with two interpolations; never concatenate fragments (§12.9 trap 3, and the reason `Loc` exists
at all).

Six keys total — `rail`, `railPlacement`, `railPosition`, `returnToTheTray`, `trayPlaced`,
`trayNotPlaced` — against §12.9's budget of 4 VoiceOver control labels for ECHO plus the shared glyph
label. Two of the six (`rail`, `returnToTheTray`) are the labelled controls; the other four are values
and formats, which §12.9 counts in the same 77.

The tray tile takes `.isButton` **and** `.isSelected` when placed, in that order in source, so a
reviewer reads the element the way VoiceOver speaks it (`hunch-accessibility` step 4). The rail tile
takes the one custom action; nothing on this surface needs a rotor, because the tray's traversal order
*is* `glyphID` order and the rail's *is* placement order — both already useful.

### Commit bar

604–667, replay key leading at 44 pt and Seal trailing at 44 pt (§8.4). The Seal is E09·T07's drawing
with its ECHO variant already declared (`references/seal.md`: same drawing, same states, two variants).
This task lays the bar out and leaves the replay key **inert** — T06 gives it behaviour. Laying it out
now is what keeps the reach test honest from this commit forward rather than one task later.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EchoRailTests` green, all six.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/EchoTrayAndRailTests` green, all eight, on both reference devices.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/EchoReachTests` green, all four — this is gate 8 of the epic.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/EchoTrayAccessibilityTests` green, all four.
- [ ] `grep -rn "84\|72\|52\b" Modules/Sources/LoomFeature/EchoTrayView.swift Modules/Sources/LoomFeature/TrayLayout.swift` returns nothing.
- [ ] `Localizable.xcstrings` gained exactly six keys, all 12 locales present with no `"state": "new"`, and the total is still ≤ 250 (`Scripts/check-source-hygiene.sh` check 8).
- [ ] `tests.json` carries five entries: placement order, the toggle's equivalence to the rail tap, the 44 pt floor, the `y ≥ 220` rule with its single named exception, and the AX2 pager.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T05: the tray, the rail, the placed toggle and the reach rule"`

## Out of scope

- Making the replay key do anything — **T06**; this task lays it out inert.
- Scoring what is on the rail, including EMPTY-RAIL and RAIL-OVERFILL — **T08**; this task only makes both states reachable.
- The reveal's "misses draw as an empty slot opening in the rail" — **T09**.
- The Seal's drawing, its barred states and its marks strike-in — **E09·T07/T10**; ECHO's Seal is never barred, because there is no draft to be incomplete.
- The four rotors and the global announcement order — **E19·T01**; this task ships the three element rows §13.10 already fixes.
