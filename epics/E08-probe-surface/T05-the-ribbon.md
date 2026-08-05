# T05 — The ribbon

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 PROBE → *The ribbon* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `C.Ribbon`'s `tileGlyph`, `pitch`, `spoolCap` and `trailingInset` are L2 members created here, and the tile's 44 pt size is what selects `weight.bodySm` for the glyph body — a token-layer consequence, not a drawing choice. Load it first. |
| `hunch-bench-instruments` | `references/ribbon.md` is normative: the geometry table, the seven tile states, the **four surfaces one drawing** rule (PROBE ribbon, ECHO rail, ECHO cast, SIEVE tail), the two accessibility shapes and the eight ways to get it wrong. |
| `hunch-shared-marks` | Three of the seven marks land on every tile — `VerdictRing.draw`, `GhostFrame.draw`, `LinkArc.draw` (which owns the return elbow too). Each is called, never redrawn; the split doubled ring is the ring's `State`, not a new drawing. |

## Objective

`RibbonView` draws the transcript as 44 pt tiles at 50 pt pitch with link arcs in the 6 pt gaps, the trailing-most tile always wearing the ghost mark, twins under a doubled ring that draws **split** when the two verdicts differ, pinned to the trailing edge and re-pinned after every verdict — one lane on the SE, two with a return elbow on the Pro Max. The tile model that decides all of this is a pure value, tested without a simulator.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.2 | Region, lanes, tile size, pitch, visible-history counts, the trailing pin and its re-pin, the spool cap |
| `GAME_DESIGN.md` | §6.6 layers 2 and 4 | The permanent ghost mark on the trailing tile; the doubled ring, and the **split** ring when a twin's two verdicts differ |
| `GAME_DESIGN.md` | §6.11 cases 2 and 3 | The seed glyph never gains a verdict ring; a twin is an *adjacent* re-probe only |
| `GAME_DESIGN.md` | §6.5 | The tile buds off the throat and travels 260–420 ms; the ribbon re-pins |
| `GAME_DESIGN.md` | §12.8 | The ribbon is above y = 220 and read-only in the reach argument; ribbon-load is a mitigation with a Dial equivalent |
| `GAME_DESIGN.md` | §13.10 | Tile traits, label, value and the "Load into the Dial" action; the "Probes" rotor steps backward, newest first |
| `hunch-bench-instruments` | `references/ribbon.md` §1, §3–§8 | Geometry, states, the SwiftUI shape, VoiceOver, Reduce Motion, High Contrast |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/RibbonModelTests.swift`. Everything the ribbon *decides* is in this model; the view only draws it.

```swift
import Testing
import HunchCore
import ModulesTestSupport
import HunchUI

@Suite("The ribbon's tile model", .tags(.unit, .presubmission))
struct RibbonModelTests {

    private func tiles(_ probes: [Probe], seed: Glyph = Fixtures.seedGlyph) -> [RibbonTileModel] {
        RibbonTileModel.tiles(probes: probes, seedGlyph: seed)
    }

    @Test("At probe 0 the ribbon is the seed glyph alone, ghost-marked and unringed")
    func probeZero() {
        let t = tiles([])
        #expect(t.count == 1)
        #expect(t[0].glyph == Fixtures.seedGlyph)
        #expect(t[0].isSeed)
        #expect(t[0].wearsGhostMark)          // §6.6 layer 2
        #expect(t[0].ring == nil)             // §6.11 case 2 — the seed never gains a verdict ring
    }

    @Test("The ghost mark is always on the trailing-most tile, and only there")
    func ghostMarkFollowsPrev() {
        let t = tiles([Probe(glyph: Deck.glyph(id: 1), verdict: .admit, isTwin: false),
                       Probe(glyph: Deck.glyph(id: 2), verdict: .reject, isTwin: false)])
        #expect(t.count == 3)                 // seed + two probes
        #expect(t.filter(\.wearsGhostMark).count == 1)
        #expect(t.last?.wearsGhostMark == true)
        #expect(t[0].wearsGhostMark == false)
    }

    @Test("An admit closes its ring and a reject breaks it")
    func verdictRings() {
        let t = tiles([Probe(glyph: Deck.glyph(id: 1), verdict: .admit, isTwin: false),
                       Probe(glyph: Deck.glyph(id: 2), verdict: .reject, isTwin: false)])
        #expect(t[1].ring == .closed)
        #expect(t[2].ring == .broken)
    }

    @Test("A twin pair draws as one unit under a doubled ring")
    func twinDoubledRing() {
        let g = Deck.glyph(id: 7)
        let t = tiles([Probe(glyph: g, verdict: .admit, isTwin: false),
                       Probe(glyph: g, verdict: .admit, isTwin: true)])
        #expect(t[1].twinGroup == t[2].twinGroup)
        #expect(t[1].twinGroup != nil)
        #expect(t[2].ring == .doubled)
    }

    @Test("When a twin's two verdicts differ the ring draws SPLIT — §6.6 layer 4")
    func twinSplitRing() {
        let g = Deck.glyph(id: 7)
        let t = tiles([Probe(glyph: g, verdict: .admit, isTwin: false),
                       Probe(glyph: g, verdict: .reject, isTwin: true)])
        #expect(t[2].ring == .split)
        #expect(t[2].twinGroup != nil)
    }

    @Test("A non-adjacent repeat is drawn normally, with no doubled ring — §6.11 case 3")
    func nonAdjacentRepeatIsNotATwin() {
        let g = Deck.glyph(id: 7)
        let t = tiles([Probe(glyph: g, verdict: .admit, isTwin: false),
                       Probe(glyph: Deck.glyph(id: 8), verdict: .reject, isTwin: false),
                       Probe(glyph: g, verdict: .admit, isTwin: false)])
        #expect(t.allSatisfy { $0.twinGroup == nil })
        #expect(t[3].ring == .closed)
    }

    @Test("The ribbon is pinned to its trailing edge and re-pins on every append")
    func pinnedToTrailing() {
        var probes: [Probe] = []
        for id in 0..<5 {
            probes.append(Probe(glyph: Deck.glyph(id: UInt8(id)), verdict: .admit, isTwin: false))
            let t = tiles(probes)
            #expect(t.pinnedIndex == t.count - 1)
        }
    }

    @Test("Two lanes wrap with a return elbow on the large device, one lane never wraps")
    func lanesAndElbows() {
        let probes = (0..<20).map { Probe(glyph: Deck.glyph(id: UInt8($0)), verdict: .admit, isTwin: false) }
        let single = RibbonLayoutModel(tiles: tiles(probes), lanes: 1, perLane: 7)
        let double = RibbonLayoutModel(tiles: tiles(probes), lanes: 2, perLane: 8)

        #expect(single.lane(of: 12) == 0)
        #expect(single.wrapsAfter(index: 6) == false)      // it scrolls; it does not wrap
        #expect(double.lane(of: 0) == 0)
        #expect(double.lane(of: 9) == 1)
        #expect(double.wrapsAfter(index: 7))               // return elbow at the lane boundary
    }

    @Test("Verdict sort blocks admits then rejects, keeps chain order, drops the link arcs")
    func verdictSort() {
        let probes = [Probe(glyph: Deck.glyph(id: 1), verdict: .reject, isTwin: false),
                      Probe(glyph: Deck.glyph(id: 2), verdict: .admit, isTwin: false),
                      Probe(glyph: Deck.glyph(id: 3), verdict: .reject, isTwin: false),
                      Probe(glyph: Deck.glyph(id: 4), verdict: .admit, isTwin: false)]
        let sorted = RibbonTileModel.verdictSorted(tiles(probes))
        let verdicts = sorted.compactMap(\.verdict)
        #expect(verdicts == [.admit, .admit, .reject, .reject])
        // chain order preserved inside each block: ids 2, 4 then 1, 3
        #expect(sorted.filter { $0.verdict != nil }.map(\.id) == [2, 4, 1, 3])
        #expect(sorted.allSatisfy { $0.drawsLinkArc == false })
        #expect(sorted.contains { $0.ring == .doubled } == false)   // no twins in this corpus
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/RibbonModelTests
```

Expect `cannot find 'RibbonTileModel' in scope`. If `Probe`'s memberwise initialiser differs from E07·T08's, adapt the calls — do not add a second `Probe`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/RibbonCanvas.swift` |
| create | `Modules/Sources/HunchUI/RibbonTileModel.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| create | `Modules/Tests/HunchUITests/RibbonModelTests.swift` |

## Implementation notes

**The model is the whole task; the view is thin over it.**

```swift
public struct RibbonTileModel: Equatable, Sendable, Identifiable {
    public enum Ring: Equatable, Sendable { case closed, broken, doubled, split }

    public let id: Int                 // chain index; the seed is 0
    public let glyph: Glyph
    public let verdict: Verdict?       // nil for the seed
    public let isSeed: Bool
    public let wearsGhostMark: Bool    // the trailing-most tile, always — §6.6 layer 2
    public let ring: Ring?
    public let twinGroup: Int?         // both members of a twin pair share it
    public let drawsLinkArc: Bool      // false in verdict sort — the chain order is not the layout order

    public static func tiles(probes: [Probe], seedGlyph: Glyph) -> [RibbonTileModel]
    public static func verdictSorted(_ tiles: [RibbonTileModel]) -> [RibbonTileModel]
}
```

Four rules the constructor encodes, each with a spec line behind it:

1. **Entry 0 is the seed glyph and carries no verdict ring.** It was primed, not probed (§6.4, §6.11 case 2).
2. **The trailing-most entry wears the ghost mark, always.** It *is* the Loom's memory — `prev` — and §6.6 layer 2 wants that address permanently visible. At probe 0 that is the seed; after probe 1 it is probe 1, which also has a verdict ring. Both marks on one tile is correct, not a collision.
3. **`twinGroup` is set only for an adjacent repeat**, which is what `Probe.isTwin` already means (E07·T08). Where the two verdicts agree the ring is `.doubled`; where they differ it is `.split` — one half open, one half closed, on a single drawing of a single glyph. That is a rendered contradiction and the clearest wordless statement of contextuality in the game; losing it is named in `ribbon.md` §8 as a defect.
4. **Verdict sort drops the arcs and keeps the rings.** Once the chain order is no longer the layout order, an arc would assert an adjacency that is not on screen.

**The split ring is not an animation.** It draws in its final state. `VerdictRing.draw`'s `State` gains `.doubled` and `.split` if E04·T07 has not already shipped them (it should have — the ring's seven states include both); if a state is missing, add it **there**, with its snapshot-gallery row, and call it from here.

**Two accessibility shapes in one component, and getting them the right way round is the whole trick.** Tiles are `Button`s — §13.10 gives each a label, a value and a "Load into the Dial" action. Arcs, elbows and the lane background are **one** `Canvas`, `.accessibilityHidden(true)`: they are not targets, they carry no separate information, and adjacency is already carried by the traversal order and the "Probes" rotor. A monolithic canvas over the tiles takes all three away and kills the rotor.

**Pinning.** `.defaultScrollAnchor(.trailing)` on the `ScrollView` is what re-pins after a verdict — it holds the trailing anchor as the content grows, so the append does the work and no imperative `scrollTo` is needed. Under Reduce Motion wrap the model mutation in `withAnimation(nil)`, or `LazyHStack`'s default insertion transition will slide the tile in and quietly violate §13.12 gate 9. This is `ribbon.md` §6's named "row most likely to survive a refactor by accident".

**Lanes follow the region, not the device name.** `RibbonLayoutModel(tiles:lanes:perLane:)` takes both from `PlaySurfaceLayout`. `wrapsAfter(index:)` is true at a lane boundary in the two-lane layout and always false in the one-lane layout, where the ribbon scrolls instead. Dropping the elbow on a wrap makes a two-lane Pro Max ribbon read as two unrelated rows — adjacency is the ribbon's only structural information.

**Four surfaces, one drawing.** ECHO's rail (placeable, 44 pt), ECHO's cast (the same tiles with no verdict rings) and SIEVE's tail (six at 36 pt) are the same component with different sizes and states. Do not add a parameter you have no site for today, but do not close the type against them either: `RibbonTile`'s size and its ring-drawing are already parameters, and that is enough.

**High Contrast, and why 44 pt is a floor.** A 44 pt tile is below the `S = 48` regime boundary, so the body takes `weight.bodySm` while the index stroke stays at `weight.body` — the hue channel is deliberately the heaviest non-colour mark on the glyph. Under High Contrast all four hues collapse to `stroke.primary` and are told apart by a 90°-separated rotation and nothing else, which any shrink below 44 pt attacks directly. Put that in the comment above the size constant.

## Acceptance criteria

- [ ] `RibbonModelTests` (9 cases) green on both destinations.
- [ ] `grep -rn 'VerdictRing\|GhostFrame\|LinkArc' Modules/Sources/HunchUI/RibbonCanvas.swift` shows only *calls* to the mark functions; `bash Scripts/check-source-hygiene.sh` check 12 (no second mark declaration) passes.
- [ ] Every tile is a `Button` with a label, a value and a custom action; the arcs layer is `.accessibilityHidden(true)`.
- [ ] `grep -n '44\|50\|24' Modules/Sources/HunchUI/RibbonCanvas.swift` returns nothing — geometry is `C.Ribbon.*`.
- [ ] With Reduce Motion on, appending a tile does not translate: verified in the DEBUG snapshot gallery row and recorded in `PROGRESS.md`.
- [ ] `bash Scripts/check-source-hygiene.sh` passes checks 7, 9 and 10 with `RibbonCanvas.swift` in the play-surface list.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; `RibbonModelTests` green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T05: the ribbon — tiles, arcs, the permanent ghost mark and the split twin ring"`

## Out of scope

- The spool sheet that the sort belongs to as a *surface* — **T09**. `verdictSorted(_:)` ships here because the ribbon's model owns it and the sheet consumes it.
- The 260–420 ms bud-off travel and the 180 ms compressed variant — **T06**. This task draws a settled ribbon.
- ECHO's rail and cast, SIEVE's tail — **E13·T04–T05**, **E14·T02**. Reuse this component; do not re-implement it.
- The DRIFT moment's three-part re-reading of the transcript — **E12·T08**; its three tile *states* are already expressible here.
- The counterexample's marginal island below the ribbon's trailing end — **E09·T09**.
- The "Probes" rotor and every VoiceOver string — **E19·T01, E19·T05**.
