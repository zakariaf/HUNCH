# T09 — The spool sheet

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | §14.1 PROBE → *The spool sheet* · §14.1 VERIFICATION → *Mode invariants* (the sheet-capacity half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The sheet's cell and gutter sizes are L2 `C.Ribbon`/`C.SpoolSheet` members and its scrim is `hunch-chrome-and-meta`'s token, not a hand-rolled `.opacity`. Load it first. |
| `hunch-bench-instruments` | `references/ribbon.md` §2 owns the sheet: why 70 cells, why seven columns, the three-tap cycle, what verdict sort drops and what it keeps. |
| `hunch-chrome-and-meta` | The sheet is a *sheet* — a covered surface with a scrim and a header — and `references/scrim.md` plus `references/stock-controls.md` decide how it is presented and what it must not become (a modal with text). |
| `hunch-swift-code` | `RoundBudget` is a new `HunchCore` type, so the boundary predicate and the routing table decide where it goes and why the *grid* stays in `Modules/`. |

## Objective

Tapping the spool expands the ribbon into a full-screen read-only sheet: a 7 × 10 grid of 70 cells at 45 pt (51 pt on Pro Max) in chain order with return elbows at every row wrap, a second tap re-sorts it into an admit block and a reject block, a third closes it, and tapping any cell ribbon-loads that glyph and dismisses. The capacity invariant — `sheetCells ≥ 1 + max cap over every mode and band` — is asserted against a core-owned table that a new mode cannot silently escape.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.2 | The whole sheet: 7 × 10, both devices' arithmetic, the header, why 70 and why seven columns, the three-tap cycle, chain order versus verdict sort, tap-to-load, and that it costs nothing and is available from probe 0 |
| `GAME_DESIGN.md` | §6.6 layer 5 | The verdict sort as a discoverability layer — one tap asks *can the same glyph appear on both sides?*, and in a contextual round it does |
| `GAME_DESIGN.md` | §7.7 | `cap_DRIFT` reaching 64 at band 8, which is the number the sheet is really sized against |
| `GAME_DESIGN.md` | §12.8 | The 44 pt target floor — which is why seven columns and not eight |
| `hunch-bench-instruments` | `references/ribbon.md` §2, §8 | The sheet's geometry and the four ways to get it wrong |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | Why the sheet grid is `HunchUI`'s while the cap table is `HunchCore`'s |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/SpoolSheetTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import HunchUI
import LoomFeature

@Suite("The spool sheet", .tags(.unit, .presubmission))
struct SpoolSheetTests {

    @Test("The grid is 7 × 10 and every cell clears the 44 pt hit floor on both devices",
          arguments: [PlaySurfaceLayout.DeviceClass.compact, .large])
    func gridShape(_ device: PlaySurfaceLayout.DeviceClass) {
        let sheet = SpoolSheetLayout(deviceClass: device)
        #expect(sheet.columns == 7)
        #expect(sheet.rows == 10)
        #expect(sheet.cellCount == 70)
        #expect(sheet.cellSide >= 44)
    }

    @Test("The grid spans the screen exactly, on both devices",
          arguments: [(PlaySurfaceLayout.DeviceClass.compact, 375.0),
                      (PlaySurfaceLayout.DeviceClass.large, 437.0)])
    func gridArithmetic(_ device: PlaySurfaceLayout.DeviceClass, _ across: Double) {
        let s = SpoolSheetLayout(deviceClass: device)
        #expect(7 * s.cellSide + 6 * s.gutter + 2 * s.margin == across)
        #expect(s.contentHeight == 10 * s.cellSide + 9 * s.gutter)
    }

    /// §6.2's invariant, and the reason the sheet is a shared surface rather than PROBE's.
    @Test("sheetCells ≥ 1 + the largest cap over every mode and band")
    func capacity() {
        let worst = RoundBudget.worstCaseTranscript          // 1 + max cap, over Mode × Band
        #expect(SpoolSheetLayout(deviceClass: .compact).cellCount >= worst)
        #expect(SpoolSheetLayout(deviceClass: .large).cellCount >= worst)
    }

    @Test("Every mode has a row in the cap table, so a new mode cannot escape the invariant")
    func theCapTableIsExhaustive() {
        for mode in Mode.allCases {
            for band in Band.allCases {
                _ = RoundBudget.cap(mode: mode, band: band)   // total function; nil is a legal answer
            }
        }
        #expect(RoundBudget.cap(mode: .probe, band: .systemic) == Band.systemic.cap(for: .probe))
    }

    @Test("Chain order reads leading→trailing, top→bottom, with a return elbow at each row end")
    func chainOrder() {
        let s = SpoolSheetLayout(deviceClass: .compact)
        #expect(s.position(of: 0) == SpoolSheetLayout.Position(row: 0, column: 0))
        #expect(s.position(of: 6) == SpoolSheetLayout.Position(row: 0, column: 6))
        #expect(s.position(of: 7) == SpoolSheetLayout.Position(row: 1, column: 0))
        #expect(s.drawsReturnElbow(after: 6))
        #expect(s.drawsReturnElbow(after: 5) == false)
        #expect(s.drawsReturnElbow(after: 69) == false)       // nothing follows the last cell
    }

    @Test("Verdict sort blocks admits then rejects and drops the link arcs")
    func verdictSort() {
        let probes = [Probe(glyph: Deck.glyph(id: 1), verdict: .reject, isTwin: false),
                      Probe(glyph: Deck.glyph(id: 2), verdict: .admit, isTwin: false),
                      Probe(glyph: Deck.glyph(id: 3), verdict: .reject, isTwin: false)]
        let tiles = RibbonTileModel.tiles(probes: probes, seedGlyph: Fixtures.seedGlyph)
        let sorted = RibbonTileModel.verdictSorted(tiles)
        #expect(sorted.compactMap(\.verdict) == [.admit, .reject, .reject])
        #expect(sorted.allSatisfy { $0.drawsLinkArc == false })
    }

    @Test("Three spool taps cycle open → sort → closed")
    @MainActor
    func threeTapCycle() {
        let round = Fixtures.round()
        #expect(round.sheet == .closed)
        round.toggleSpool(); #expect(round.sheet == .chainOrder)
        round.toggleSpool(); #expect(round.sheet == .verdictSorted)
        round.toggleSpool(); #expect(round.sheet == .closed)
    }

    @Test("The sheet costs nothing, consumes no probe, and is open from probe 0")
    @MainActor
    func freeAndAlwaysAvailable() {
        let round = Fixtures.round()
        round.toggleSpool()
        round.toggleSpool()
        #expect(round.probesUsed == 0)
        #expect(round.sheet == .verdictSorted)
    }

    @Test("Tapping a cell ribbon-loads that glyph and dismisses the sheet")
    @MainActor
    func tapLoadsAndDismisses() {
        let round = Fixtures.round()
        round.select(.hue, rank: 4)
        round.probe(round.draft); round.landVerdict(); round.endVerdictBeat()
        round.toggleSpool()

        round.loadFromSheet(cellIndex: 0)                     // the seed tile

        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.sheet == .closed)
        #expect(round.probesUsed == 1)                        // still free
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/SpoolSheetTests
```

Expect `cannot find 'SpoolSheetLayout' in scope` and `cannot find 'RoundBudget' in scope`. The capacity case must be *red for the right reason* — a missing symbol — before it is green; a capacity test that passes because it compares 70 to 0 is testing nothing, so implement `RoundBudget` before `SpoolSheetLayout`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/RoundBudget.swift` |
| create | `HunchCore/Tests/RoundsTests/RoundBudgetTests.swift` |
| create | `Modules/Sources/HunchUI/SpoolSheetLayout.swift` |
| create | `Modules/Sources/LoomFeature/SpoolSheetView.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` |
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| create | `Modules/Tests/LoomFeatureTests/SpoolSheetTests.swift` |
| modify | `tests.json` |

## Implementation notes

### `RoundBudget` — a total function over Mode × Band

The sheet is sized against the largest cap in *any* mode, not PROBE's, because it is a shared surface: DRIFT gets PROBE's layout region for region and its cap reaches 64 at band 8. That makes the invariant a cross-epic claim, and a cross-epic claim needs a table a future epic cannot walk past:

```swift
// HunchCore/Sources/Rounds/RoundBudget.swift
/// The hard probe ceiling a mode serves at a band, and the worst-case transcript length every
/// shared surface must hold (§6.2). Exhaustive over `Mode`: adding a mode is a **compile error**
/// here, which is the point — the spool sheet's capacity invariant is asserted over this table.
public enum RoundBudget {
    /// `nil` where the mode does not serve that band, or has not defined its budget yet.
    public static func cap(mode: Mode, band: Band) -> Int? {
        switch mode {
        case .probe: band.cap(for: .probe)
        case .drift: nil        // E12·T04 fills the six-row table of §7.7; 40…64
        case .echo:  nil        // E13 — ECHO has no probe cap; it has a cast length
        case .sieve: nil        // E14 — SIEVE has no probe cap; it has a stream length
        }
    }

    /// 1 + the largest cap over every mode and band: the seed glyph plus the longest possible
    /// probe run. The `1 +` is the seed glyph, which occupies a cell and is not a probe.
    public static var worstCaseTranscript: Int {
        let caps = Mode.allCases.flatMap { mode in
            Band.allCases.compactMap { band in cap(mode: mode, band: band) }
        }
        return 1 + (caps.max() ?? 0)
    }
}
```

What matters is that the enumeration is `Mode.allCases × Band.allCases` and that the `switch` has **no `default:`**. Add `HunchCore/Tests/RoundsTests/RoundBudgetTests.swift` asserting `worstCaseTranscript == 1 + Band.allCases.map { $0.cap(for: .probe) }.max()!` today, so the number is pinned and E12's edit visibly moves it.

Write the forward obligation into E12's path as a comment on the `.drift` case and into this task's Out of scope: **E12·T04 fills that row, and this suite then covers `cap_DRIFT = 64` with no edit here.**

### The grid

Seven columns rather than eight because eight forces a 38 pt cell on the SE, below the 44 pt hit floor, **and every cell is tappable**. 70 ≥ 65 leaves five cells spare, so the longest possible round in any mode is on one screen with no scrolling — which is what the sheet is for. `SpoolSheetLayout` holds `columns`, `rows`, `cellSide`, `glyphSide`, `gutter`, `margin` and `contentHeight` per device class, and exposes `position(of:)` and `drawsReturnElbow(after:)`. It reads no environment; the device class comes from `PlaySurfaceLayout`.

The header at the top carries the spool cap and the sort toggle and nothing else — **no title, no count, no label**. This is a play surface: `PlaySurfaceTextTests` fails the build on a `Text` here, and it should.

### The three-tap cycle

`Round.sheet` is a three-case enum (`closed`, `chainOrder`, `verdictSorted`) and `toggleSpool()` advances it. The sort is not a filter and not a mode switch — it re-orders the same 70 cells. Link arcs are **dropped** in verdict sort, because once the chain order is no longer the layout order an arc would assert an adjacency that is not on screen; twin pairs keep their doubled ring, because a twin is a fact about the glyph and not about the layout.

Reuse `RibbonTileModel.verdictSorted(_:)` from T05. The sheet does not get its own tile model, its own ring logic or its own ghost-mark rule — one drawing, two surfaces.

### Tap to load

`loadFromSheet(cellIndex:)` maps the cell back through the current ordering to a chain index and calls the same `load(ribbonIndex:)` T04 shipped, then closes the sheet. In verdict sort the mapping is not the identity, and that is the one bug worth writing a test for — which is why `tapLoadsAndDismisses` loads cell 0 after a probe rather than in an empty round.

### What the sheet must not become

It costs nothing, consumes no probe and is available from probe 0. It is read-only apart from the cell tap, it has no confirmation, no empty state and no copy. A scrim behind it comes from `hunch-chrome-and-meta/references/scrim.md`; a hand-rolled `.opacity(0.7)` is a hygiene failure. Under Reduce Transparency the scrim is the flat opaque variant that skill already defines — do not invent a second one here.

## Acceptance criteria

- [ ] `SpoolSheetTests` (9 cases) green on both destinations, and `RoundBudgetTests` green in the fast suite.
- [ ] `grep -n 'default:' HunchCore/Sources/Rounds/RoundBudget.swift` returns nothing.
- [ ] `grep -rn '70\|45\|51\|7 \*' Modules/Sources/LoomFeature/SpoolSheetView.swift` returns nothing — all of it is `SpoolSheetLayout`.
- [ ] `grep -n 'Text(\|Label(\|AttributedString' Modules/Sources/LoomFeature/SpoolSheetView.swift` returns nothing and `bash Scripts/check-source-hygiene.sh` check 7 covers the file.
- [ ] `grep -rn 'verdictSorted' Modules/Sources` shows exactly one implementation, in `RibbonTileModel`.
- [ ] `tests.json` carries the sheet-capacity invariant with its command and its current status.
- [ ] By hand in the simulator: probe five times, open the sheet, sort it, tap a cell, land back on the Dial with that glyph loaded and no probe spent. Recorded in `PROGRESS.md`.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s with `RoundBudgetTests` added; `SpoolSheetTests` green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T09: the spool sheet, chain order and verdict sort, with the capacity invariant"`

## Out of scope

- `cap_DRIFT`'s six rows — **E12·T04**, which fills `RoundBudget`'s `.drift` case and inherits this suite's assertion.
- ECHO's and SIEVE's budgets — **E13·T07**, **E14·T01**. Both return `nil` here on purpose: neither mode has a *probe* cap, and pretending otherwise would put a fake number into a shared invariant.
- The ribbon's tile model, rings and ghost mark — **T05**. Reused, not re-implemented.
- The scrim, the sheet transition and its Reduce Motion substitution — the tokens and the substitution row are `hunch-chrome-and-meta` and `hunch-motion-and-feedback`; the app-wide re-verification is **E09·T12** and **E20·T08**.
- VoiceOver labelling of 70 cells and the "Probes" rotor — **E19·T01, E19·T05**.
- Layer 5's band-independence assertion — **T10**. This task builds the sort; T10 proves it is present in every band.
