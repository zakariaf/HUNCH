# T02 — The four rule-tile canvases

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T01 |
| **Delivers** | §14.1 `The Bench` (the four tile classes, the coupler, the wedge, the ghost toggle, all distinct at silhouette level) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First.** Five new L2 namespaces land in `C.swift` here — `C.Ramp`, `C.Bridge`, `C.Wedge`, `C.Fork`, `C.Tally`, `C.Coupler` — and every ink level in this task (`C.Ramp.cellUnlitInk(in:)`, `C.Ramp.inertInk`, `C.Ramp.cancelHatchWeight(in:)`) is a **substituting** accessor whose High Contrast value terminates resolution and is never also offset by +0.5 pt. This skill also owns the open `opacity.cellUnlit` ruling that `hunch-shared-marks` flags; do not add a sixth call site until it lands. |
| `hunch-bench-instruments` | The five reference files this task implements verbatim: `ramp.md` (seven interactive instances, not four), `bridge.md` (the asymmetry rule), `wedge.md` (six constructions, never an icon), `fork.md` (three ramps, and the turnout that must follow the lit gate cell), `tally.md` (the AX1 overflow and its 2 × 2 wrap), `coupler.md` (three topologies, absent beside a Fork), `rule-tile.md` (the frame, the rail and the six shared states). |
| `hunch-shared-marks` | Every mark inside a tile has exactly one owning `draw(into:)`: `CancelHatch.draw` for the unlit cell's diagonal **and** the inert ramp's slash (one weight, one home), `GhostFrame.draw` for the trailing socket. A tile that draws its own hatch is the §2(g) drift this library exists to stop. |
| `hunch-glyph-renderer` | A ramp cell is *a picture of one channel* — the silhouette for `shape`, the interior texture for `fill`, the contour nodes for `pips`, the index stroke for `hue` — and it asks E04's renderer for that register rather than re-deriving a silhouette. §4.1's whole claim is that there is no attribute emblem to learn. |
| `hunch-accessibility` | One `Button` per cell, socket, wedge, coupler and toggle, because §13.10 makes every cell a `.button` with `.isSelected`; a single `Canvas` per ramp would collapse five elements into one image and take the traits with it. |

## Objective

At the end of this task the Bench's rails can hold any law the grammar can express: four tile classes
distinguishable at silhouette level, a coupler with three topologies, a pictorial wedge cycling six
comparators, and a ghost toggle on the trailing socket that is the entire contextual grammar. Before
this task the rails draw their empty state; after it, every one of §4.4's eight grammar productions
has a drawing and a hit target.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.2 | All five drawings: the Ramp's 44 pt header + four 56 × 44 cells and its 14 usable states; the Bridge's two sockets, wedge and trailing ghost toggle; the Fork's gate / lit / dim docks; the Tally's attribute column, rank ramp, counter dial and parity comb; the coupler's welded / forked / crossed bars |
| `GAME_DESIGN.md` | §4.3 | The unlit cell (ink drop **and** a diagonal cancel hatch); **one** inert state for 0-lit and 4-lit, drawn at `C.Ramp.inertInk` with a hairline slash; the empty rail's dashed outline and pulsing hairline |
| `GAME_DESIGN.md` | §4.4 | Expressiveness parity — which tile constructs which production, and that the Fork's docks accept ramps only, the Tally is a whole-Bench tile, and two rails plus one coupler is the structural ceiling |
| `GAME_DESIGN.md` | §3.4 | RNF rule 3 — contextual is always `cur`-leading, which is why the ghost toggle is on the trailing socket and only there |
| `GAME_DESIGN.md` | §13.3 | Chrome has exactly two rule weights: `weight.hairline` for a divider, `weight.thin` for a tile frame. A heavier line always means state — the machined bar and the AND weld |
| `GAME_DESIGN.md` | §13.11, §12.8 | Bold Text raises rule-tile stroke weights ×1.25; High Contrast's flat +0.5 pt; the AX2+ single-rail pager; the Tally's 2 × 2 column wrap above art scale 1.2 |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | No `default:` in a switch over an enum you own — a seventh comparator or a fourth coupler must break the build, not render an empty box |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24, P25 | One top-level type per file, and the sanctioned exceptions — see the ruling below |

## TDD — the test comes first

Every assertion below is on a **pure** value — a `Shape`'s `path(in:)`, a derived metric, a predicate —
so the whole suite runs without a rendered view. That is deliberate: a drawing test that needs a
snapshot is a drawing test nobody runs.

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/RuleTileCanvasTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI

@Suite("Rule-tile canvases", .tags(.unit, .presubmission))
struct RuleTileCanvasTests {

    private static let box = CGRect(x: 0, y: 0, width: 44, height: 44)

    // MARK: — the wedge, §4.2 / wedge.md §2

    // "drawn pictorially and never as ASCII" — six comparators, six distinct drawings.
    @Test("All six comparators draw a distinct, non-empty path")
    func sixWedgesAreDistinct() {
        let paths = Comparator.allCases.map { WedgeShape(comparator: $0).path(in: Self.box) }
        #expect(paths.count == 6)
        #expect(paths.allSatisfy { !$0.isEmpty })
        for (i, a) in paths.enumerated() {
            for b in paths[(i + 1)...] {
                #expect(a.description != b.description)
            }
        }
    }

    // "lt/gt a wedge whose wide end physically opens toward the larger side" — the apex is
    // at the LEADING edge for lt and the TRAILING edge for gt, so the two are reflections.
    @Test("lt and gt are reflections of each other about the mark box's vertical axis")
    func wedgeDirectionIsPositional() {
        let lt = WedgeShape(comparator: .lt).path(in: Self.box).boundingRect
        let gt = WedgeShape(comparator: .gt).path(in: Self.box).boundingRect
        #expect(lt == gt)                                            // same box
        #expect(WedgeShape.apexX(for: .lt, in: Self.box) < Self.box.midX)
        #expect(WedgeShape.apexX(for: .gt, in: Self.box) > Self.box.midX)
    }

    // "lte/gte the same wedge with an underbar" — strictly more path than lt/gt.
    @Test("lte and gte add an underbar and nothing else")
    func underbarIsAdditive() {
        let lt = WedgeShape(comparator: .lt).path(in: Self.box)
        let lte = WedgeShape(comparator: .lte).path(in: Self.box)
        #expect(lte.elementCount > lt.elementCount)
        #expect(lte.boundingRect.maxY > lt.boundingRect.maxY)
    }

    // wedge.md §3: the cycle order IS Comparator's declaration order, so cycling and
    // serialisation agree without a second table.
    @Test("The wedge cycles in Comparator's declaration order and wraps")
    func wedgeCycleOrder() {
        var seen: [Comparator] = [.eq]
        for _ in 0..<6 { seen.append(seen.last!.cycled()) }
        #expect(Array(seen.prefix(6)) == Comparator.allCases)
        #expect(seen.last == .eq)
    }

    // MARK: — the coupler, §4.2 / coupler.md §2

    @Test("AND is one strand; OR and XOR are two, and all three are symmetric about the axis",
          arguments: Coupler.allCases)
    func couplerTopology(_ coupler: Coupler) {
        let path = CouplerShape(coupler: coupler).path(in: Self.box)
        #expect(CouplerShape.strandCount(coupler) == (coupler == .and ? 1 : 2))
        // "all three are commutative and the drawing must be symmetric about the axis"
        let bounds = path.boundingRect
        #expect(abs(bounds.midX - Self.box.midX) < 0.0001)
    }

    @Test("The AND weld is heavier than the OR and XOR strands")
    func weldIsHeavier() {
        #expect(C.Coupler.weldWeight.points > C.Coupler.strandWeight.points)
    }

    // MARK: — the ramp, §4.2 / ramp.md §3

    // "14 usable states per ramp; 0 lit and 4 lit are inert" — ONE inert state, not two,
    // and the predicate is core (RankSet.isVacuous), not a view test.
    @Test("Exactly two of the sixteen subsets are inert, and both draw identically")
    func fourteenUsableStates() {
        let inert = (0..<16).map { RankSet(bitmask: UInt8($0)) }.filter(\.isVacuous)
        #expect(inert.count == 2)
        #expect(inert.contains(.empty))
        #expect(inert.contains(.full))

        let empty = RampView.drawing(for: .empty, mode: .multi)
        let full = RampView.drawing(for: .full, mode: .multi)
        #expect(empty == full)                      // one inert drawing, not two
        #expect(empty.slash == .hairline)
    }

    // ramp.md §1: SEVEN interactive instances. The Fork's lit and dim docks are each a
    // full ramp, which is the instance most often lost.
    @Test("The ramp has seven interactive instances and no eighth")
    func rampInstanceCensus() {
        #expect(RampView.Instance.allCases.count == 7)
        #expect(RampView.Instance.allCases.contains(.forkThenDock))
        #expect(RampView.Instance.allCases.contains(.forkElseDock))
        #expect(RampView.Instance.allCases.contains(.tallyCounterDial))
    }

    // ramp.md §2: canon fixes the header and the cell; the Bench gutter is DERIVED so the
    // ramp fills its rail, floored at Space.s4.
    @Test("The Bench ramp fills its rail and never breaks the 44 pt floor")
    func benchRampFits() {
        let gutter = C.Ramp.benchGutter(railContent: C.RuleTile.railContent)
        let used = C.Ramp.headerWidth + 4 * C.Ramp.benchCell.width + 4 * gutter
        #expect(gutter >= Space.s4)
        #expect(used <= C.RuleTile.railContent + 0.0001)
        #expect(C.Ramp.benchCell.width >= Space.targetMin)
        #expect(C.Ramp.benchCell.height >= Space.targetMin)
    }

    // MARK: — the bridge, §4.2 / bridge.md §2

    // RNF rule 3 made physical: the LEADING socket is always `cur` and carries no toggle.
    @Test("The ghost toggle exists on the trailing socket and only there")
    func ghostToggleAsymmetry() {
        #expect(SocketView.hasGhostToggle(.trailing))
        #expect(!SocketView.hasGhostToggle(.leading))
        #expect(BridgeSocket.allCases.count == 2)
    }

    // §4.4: "exhaustive — 4 leading × 4 trailing × 6 wedge" = 96 contextual forms.
    @Test("Every one of the 96 contextual forms is reachable from the tile's controls")
    func contextualFormsAreExhaustive() {
        var reached = Set<LawNode>()
        for leading in Glyph.Attribute.allCases {
            for trailing in Glyph.Attribute.allCases {
                for comparator in Comparator.allCases {
                    var bridge = RuleTile.Bridge()
                    bridge.bind(leading, to: .leading)
                    bridge.bind(trailing, to: .trailing)
                    bridge.isGhosted = true
                    bridge.comparator = comparator
                    reached.insert(try! #require(bridge.node))
                }
            }
        }
        #expect(reached.count == 96)
    }

    // bridge.md §1: 88 + 8 + 44 + 8 + 88 = 236 inside the 291 pt rail.
    @Test("The Bridge's three parts fit inside the rail with the ghost toggle's slack")
    func bridgeFits() {
        let used = 2 * C.Bridge.socket.width + C.Bridge.wedgeBox.width + 2 * C.Bridge.partGutter
        #expect(used <= C.RuleTile.railContent)
        #expect(C.RuleTile.railContent - used >= Space.s16)
    }

    // MARK: — the fork, §4.2 / fork.md §2

    // "the gate cell that is lit routes to the lit track" — a BEHAVIOUR, not a decoration.
    @Test("The turnout's origin follows the lit gate cell")
    func turnoutFollowsTheGate() {
        let metrics = RampView.Metrics.benchTile(env: .fixture(), railContent: C.RuleTile.railContent)
        let origins = (0..<4).map { TurnoutShape.originX(litCellIndex: $0, metrics: metrics) }
        #expect(origins == origins.sorted())
        #expect(Set(origins).count == 4)
        for (i, x) in origins.enumerated() {
            #expect(abs(x - metrics.cellCentreX(rank: i)) < 0.0001)
        }
    }

    // fork.md §1: the two branch docks are independent full ramps on the SAME attribute.
    @Test("Then and else are independent ramps sharing one attribute")
    func forkDocksAreIndependent() {
        var fork = RuleTile.Fork(gate: .init(attribute: .hue, litIndex: 2), branchAttribute: .pips)
        fork.then = RankSet(ranks: [2, 3])
        fork.else = RankSet(ranks: [0])
        #expect(fork.then != fork.else)
        #expect(fork.thenAttribute == fork.elseAttribute)
        #expect(fork.gate.attribute != fork.thenAttribute || true)   // gate may share or differ
        #expect(ForkView.dockCount == 3)
    }

    // fork.md §1: 44 + 8 + 56 + 8 + 44 + 8 + 44 = 212 inside 332, and 212 × 1.35 = 286 < 332,
    // so the Fork fits at the Dynamic Type ceiling without paging. (The Tally does not.)
    @Test("The Fork fits the Bench region at the art-scale ceiling")
    func forkFitsAtCeiling() {
        let stack = ForkView.stackHeight(artScale: Prim.artScaleCeiling)
        #expect(stack <= PlaySurfaceLayout(device: .se, mode: .bench).benchRegion.height)
    }

    // MARK: — the tally, §4.2 / tally.md §1

    // The one tile with a real gap between §12.8's art scale and §13.11's pager.
    @Test("The Tally column packs 2 × 2 above the wrap scale, and only then")
    func tallyColumnWrap() {
        #expect(!TallyView.wrapsColumn(artScale: 1.0))
        #expect(!TallyView.wrapsColumn(artScale: C.Tally.columnWrapScale))
        #expect(TallyView.wrapsColumn(artScale: Prim.artScaleCeiling))

        let wrapped = TallyView.stackHeight(wrapped: true, artScale: Prim.artScaleCeiling)
        #expect(wrapped <= PlaySurfaceLayout(device: .se, mode: .bench).benchRegion.height)
    }

    // tally.md §1: 5 stops must each clear the hit floor; derive the width, never pin it.
    @Test("The counter dial's stops clear the hit floor in both modes")
    func counterDialStops() {
        let count = C.Tally.counterStopWidth(content: C.RuleTile.railContent, stops: 5, gutter: 6)
        let parity = C.Tally.counterStopWidth(content: C.RuleTile.railContent, stops: 2, gutter: 6)
        #expect(count >= Space.targetMin)
        #expect(parity > count)
    }

    // §4.2: "minimum three" counted attributes, and the constraint is VISIBLE, not a silent no-op.
    @Test("The third counted attribute locks visibly rather than refusing silently")
    func tallyMinimumThree() {
        var tally = RuleTile.Tally(counted: [.fill, .shape, .pips])
        #expect(!tally.canUncount(.fill))
        #expect(TallyView.rowState(.fill, in: tally) == .countedLocked)
        tally.count(.hue)
        #expect(tally.canUncount(.fill))
        #expect(TallyView.rowState(.fill, in: tally) == .counted)
    }

    // MARK: — the shared frame, rule-tile.md §3

    @Test("Every tile class draws the same six states from one frame")
    func sharedStates() {
        #expect(RuleTileFrame.Presentation.allCases.count == 3)   // live, readOnly, burnished
        #expect(RailView.State.allCases.count == 3)               // filled, empty, pulsing
        #expect(C.RuleTile.codexScale < 1.0)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:HunchUITests/RuleTileCanvasTests
```

The first failure must be `cannot find 'WedgeShape' in scope`. If a test passes before its type
exists, you have asserted something about a type that already existed — find it and fix the test.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** The refactor pass here is real: five `View` types plus four
`Shape`s in one file wants a hard look at what is shared. Push everything shared into
`RuleTileFrame`, `RampView` and `RampView.Metrics` — not into a free function.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — `RuleTileFrame`, `RailView`, `RampView`, `RampCell`, `BridgeView`, `SocketView`, `GhostToggle`, `WedgeView`, `WedgeShape`, `ForkView`, `TurnoutShape`, `TallyView`, `CombShape`, `CouplerView`, `CouplerShape` |
| create | `Modules/Sources/HunchUI/AttributeHeaderView.swift` — the leading 44 pt of every ramp and the Bridge socket's picker |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.RuleTile`, `C.Ramp`, `C.Bridge`, `C.Wedge`, `C.Fork`, `C.Tally`, `C.Coupler`, and `C.Size` |
| modify | `HunchCore/Sources/Bench/RuleTile.swift` — `RankSet.isVacuous`, `RuleTile.Tally.canUncount(_:)`, `RuleTile.Bridge.node`, `BridgeSocket`, `ForkBranch`, `Comparator.cycled()`, `Coupler.cycled()` — **only what is missing**; E06·T03 shipped the payload structs |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — render `RuleTile` into `RailView`, wire the coupler slot |
| create | `Modules/Tests/HunchUITests/RuleTileCanvasTests.swift` |
| modify | `DECISIONS.md` — the one-file ruling below |
| modify | `tests.json` — the 96-contextual-forms and 14-usable-states invariants |

## Implementation notes

### The one-file ruling, and why it is not laziness

`01 P24` says one top-level type per file. This task puts fifteen in `RuleTileCanvas.swift`. That is
deliberate and it is `08 §1`'s own tree — every one of `ramp.md`, `bridge.md`, `wedge.md`, `fork.md`,
`tally.md` and `coupler.md` names *"`XView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`"* as its
owner. Splitting them into six files would give the four tile classes four places to grow a private
copy of the cell drawing, which is exactly the drift `hunch-bench-instruments`' standing rule 1
exists to stop. `P25`'s third exception — a family of small types that are meaningless apart — applies.
`AttributeHeaderView` is the exception to the exception: it has four call sites outside this file
(the Tally column, the socket picker, the Codex facet stamp, the Dial), so it gets its own file.

Record the deviation in `DECISIONS.md` with both citations. Do not silently break `P24`.

### `RampView` — one drawing, seven sites

The census in `ramp.md` §1 is normative and the test asserts its size. The instance that gets lost is
the Fork's **else** dock: it is a *full, independent* ramp on the same attribute as the then dock, not
a mirror, not a single cell and not a shared selection. Collapsing it makes 8,736 guard forms
unreachable and G10's forward test fails on the first Fork law.

Cell states are four and each carries geometry before colour:

| State | Geometry channel | Ink |
|---|---|---|
| lit | interior steps to `surface.cellLit` | — |
| unlit | **diagonal cancel hatch** via `CancelHatch.draw` | `C.Ramp.cellUnlitInk(in: env)` |
| dim (else dock, admitted) | none — it is admitted, for the else branch | `stroke.secondary` at full opacity, **no hatch** |
| disabled | none | `Opacity.disabled`, not focusable, label retained |

"Dim" is a **colour-register step, not an invented opacity** (`fork.md` §2, `ramp.md` §3). Minting a
`0.55` here fails the light theme, where the register step is smaller and nobody measured it.

**One inert state, not two.** `RankSet.isVacuous` is core and is the same predicate `SealBar` reads
(T07). A view-side `admitted.isEmpty || admitted.count == 4` will disagree with the Seal on some
subset and nobody will find out which.

### `WedgeShape` — a construction, never an icon

`wedge.md` §1: the apex sits at the midpoint of one edge of the 24 pt mark box and the two limbs run
to the **two far corners**. That is an included angle of `2·atan(0.5)` **by construction**; writing
53° down means the day the mark box stops being square the mark stops meeting its corners. `markBox`
clamps to *both* `C.Wedge.markSide` and the rect, so shrinking the container shrinks the mark rather
than clipping it — a clipped `gte` loses its underbar and becomes `gt`, which is a different law.

Write it in `minX`/`maxX` of a rect SwiftUI has already flipped (`opensTrailing`, never `opensRight`),
so RTL mirrors the wedge *with* its rail and the wide end still opens toward the larger socket.

The switch has **no `default:`** (`W29`). A seventh comparator must break the build here.

### `TurnoutShape` — the tile that teaches itself

The incoming line originates at the **x centre of the gate dock's lit cell** and moves when the
selection moves (`fork.md` §2). A player taps a different gate cell, watches the line slide, and has
learned lit-routes-to-lit without a word. A fixed origin still *looks* right and teaches nothing —
which is why `originX(litCellIndex:metrics:)` is a `static` pure function with its own test, not a
closure inside `path(in:)`.

Under Reduce Motion the strands **crossfade** between the two positions; the strand still ends up
under the newly lit cell, it just gets there by crossfade. Substituting by *removing* the move deletes
the teaching.

### `TallyView` — the one tile that does not fit

`tally.md` §1's arithmetic: `200 + 8 + 44 + 8 + 44 = 304` at 1.0×, and `304 × 1.35 = 410` against a
332 pt region. §12.8 puts art scale at its ceiling from `accessibility1`, one category *before*
§13.11's pager engages at AX2 — so there is a real gap and the ruling is the 2 × 2 column wrap above
`C.Tally.columnWrapScale`. New stack: `96 + 8 + 44 + 8 + 44 = 200`, and `200 × 1.35 = 270 < 332`.
The counted/uncounted state is per-header and survives the reflow untouched.

The reflow follows a **system setting**, not a tap, so it is never animated (`tally.md` §6).

The parity comb is **drawn** — two teeth, `stroke.primary` at `weight.body`, in a 24 pt mark box
inside a 44 pt hit rect. Not a `Toggle`, not a `Picker`, not a segmented control: those are
text-shaped system components on a surface with zero text.

`Glyph.Attribute.allCases` is declared in canonical `fill → shape → pips → hue` order in
`HunchCore/Sources/Glyphs/Glyph.swift`. Never sort it at a call site — the column order, the Dial's row
order, the VoiceOver label order and the serialisation order are all that one declaration.

### `CouplerView` — three diagrams that read as a sequence

One path, two paths that reunite, two paths that do not. That progression is the whole explanation.
All three must be **symmetric about the axis** because the combinators are commutative and the RNF
fold sorts their operands — an asymmetric OR asserts an order the AST does not have and contradicts
the tile it round-trips to (G10).

**Absent, not disabled.** A Fork or a Tally occupies the whole Bench and there is no coupler: not
greyed, not an empty node, and **removed from the accessibility tree entirely** (`coupler.md` §5),
because a silent stop on the Rails rotor is a dead swipe every time a Fork is on the Bench.

### Accessibility, in the same pass

One `Button` per interactive part. §13.10's rows, with the container/cell split:

| Element | Traits | Label | Value |
|---|---|---|---|
| ramp (container) | container | the attribute name; `"Rank"` / `"Count"` for the Tally's two | Dial: the current value · tile: `"admits triangle, hexagon"` |
| a cell | `.button`, `.isSelected` when lit | the value name | `"selected"` (Dial) / `"admitted"` (tile) |
| socket | `.button` | `"Leading socket"` / `"Trailing socket"` | `"pips, this glyph"` / `"pips, previous glyph"` / `"empty"` |
| ghost toggle | `.button` `.isSelected` | `"Previous glyph"` | `"on"` / `"off"` |
| wedge | `.button` | `"Comparator"` | the comparator name — action `"Cycle"` |
| coupler | `.button` | `"Coupler"` | `"and"` / `"or"` / `"exclusive or"` — action `"Cycle"` |
| counter dial | `.adjustable` | `"Count"` | `"admits 0, 2 and 3"` |
| turnout | **hidden** | — | — |

Two that are easy to get wrong: the socket's value **states which glyph it reads**, because that
clause is the only way a VoiceOver player learns the contextual grammar; and an **inert** ramp
announces its state on the container — `"inert, admits nothing"` / `"inert, admits every value"` —
which is the one place the two inert causes are distinguished, because audio has no drawing to
collapse them into.

The wording is E19's. Leave `Loc.*` call sites and let E18 fill the catalog; never a bare literal.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/RuleTileCanvasTests` is green, all 18 tests.
- [ ] `grep -c 'default:' Modules/Sources/HunchUI/RuleTileCanvas.swift` returns `0`.
- [ ] `grep -nE '0\.25|0\.30|0\.78|lineWidth: *[0-9]|\.opacity\([0-9]' Modules/Sources/HunchUI/RuleTileCanvas.swift`
      returns nothing.
- [ ] `grep -rn 'struct .*Hatch\|func .*hatch\|GhostFrame' Modules/Sources/HunchUI/RuleTileCanvas.swift`
      shows **calls only** — no second declaration of a shared mark.
- [ ] `grep -rn 'Text(\|Label(\|AttributedString\|Image(systemName' Modules/Sources/HunchUI/RuleTileCanvas.swift`
      returns only hits inside `.accessibility*` modifiers. No SF Symbol, no ASCII operator.
- [ ] `bash Scripts/check-source-hygiene.sh` passes.
- [ ] `DECISIONS.md` records the `RuleTileCanvas.swift` multi-type ruling with its `P24`/`P25` and
      `08 §1` citations.
- [ ] The DEBUG snapshot gallery (E04·T09) renders all four tile classes × their states × three
      themes with no literal in view code — checked by opening it in the simulator.
- [ ] `tests.json` carries `bench.contextual-forms-exhaustive` (96) and `bench.ramp-usable-states` (14).

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:HunchUITests/RuleTileCanvasTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T02: the four rule-tile canvases, the coupler and the pictorial wedge"`

## Out of scope

- **The Seal, the machined bar and `SealBar`.** **T07**. This task ships the tiles; the predicate that
  decides they are incomplete is T07's, and both read the *same* core `RankSet.isVacuous`.
- **The Assay.** **T05**. A tile edit morphs the Assay; the wiring is T05's.
- **The gesture lint.** **T03**.
- **Which classes are unlocked.** **T04**.
- **The glyph fragment inside a cell.** `hunch-glyph-renderer`, shipped in **E04**. `RampCell` calls
  it; it never re-derives a silhouette.
- **The `LawNarrator` sentence** on the Bench container. **E19·T03**; leave the hook.
- **The Codex page's read-only tiles at 0.78×.** **E15·T05**, which scales *this* drawing — which is
  why `C.RuleTile.codexScale` is declared here and applied as a transform, never as a second layout.
- **The single-rail pager above AX2.** **E19·T06**.
