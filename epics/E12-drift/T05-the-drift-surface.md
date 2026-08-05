# T05 — The DRIFT surface

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | Lifecycle + budgets (DRIFT) — the surface half · Mode sigils (the DRIFT one, consumed by E17·T04) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First**, because this task draws. The seam marker's hairline weight, the 20 pt silhouette's box and the sigil's stroke all resolve through `RenderEnv`; a literal `lineWidth:` outside `Tokens/` fails the hygiene grep, and the seam marker must survive High Contrast (where the hairline is the state-bearing mark the skill forbids at low ratio) without inventing a second drawing. |
| `hunch-bench-instruments` | `references/ribbon.md` owns the ribbon — the seam marker is a mark **inside** it, at a tile boundary, and adding it anywhere else would be a second ribbon. The same file owns the throat, the Dial and the commit bar this task must prove it did not touch. |
| `hunch-sigil-drawing` | `references/mode-sigils.md` already specifies `mode.drift` — *two offset law-plates, the trailing one in the dashed hollow ghost frame*, verb `stack` — and this task is where it is actually drawn. The skill's distinctness harness must be run against the 22 authored marks before it is committed, and the drawing recorded back into the library so **E17·T04 reuses it rather than reinventing it**. |

## Objective

At the end of this task a DRIFT round is playable on PROBE's surface: the same six regions at the same
coordinates on both reference devices, the same throat, ribbon, Dial, handle and commit bar, with
exactly two differences — the DRIFT mode sigil in the instrument bar and the seam marker in the ribbon.
A parity test asserts the difference set is exactly those two, so the mode's central claim is enforced
by the build rather than by review.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.5 | The whole task: the six regions verbatim, "the only differences are the mode sigil and the seam marker", the mode sigil identifying DRIFT and **never the hinge**, and the tick row counting against `par_DRIFT` |
| `GAME_DESIGN.md` | §7.1 | The decision this task enforces: no controls, no chrome, no timer — because an interface element that changed at the hinge would be announcing the change |
| `GAME_DESIGN.md` | §7.3 | The seam marker: a vertical hairline carrying a 20 pt silhouette of the accepted tile layout, written **only** by trigger (b), and the only visible trace of a hinge before the reveal |
| `GAME_DESIGN.md` | §6.2 | The region table for both devices, which DRIFT reuses unchanged |
| `GAME_DESIGN.md` | §12.2 | Screen 3, `RoundView`, is *"the PROBE / DRIFT play surface"* — DRIFT adds **no screen** |
| `GAME_DESIGN.md` | §12.4 | The mode sigil's clause — two offset law-plates, the trailing one in the ghost frame |
| `GAME_DESIGN.md` | §12.9 | Zero characters on the play surface; `PlaySurfaceTextTests` covers `RoundView.swift`, so nothing here may render text |
| `hunch-sigil-drawing` | `references/mode-sigils.md`, `references/sigil-grammar.md` | The construction grammar, the sites `[22, 24, 44, 72]`, and the rule that the sigil's drawing is identical in every key state |
| `hunch-shared-marks` | `references/ghost-frame.md` | `GhostFrame.draw` is the one owner of the dashed hollow frame and backward chevron the DRIFT sigil's trailing plate wears |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/DriftSurfaceParityTests.swift`:

```swift
import Testing
@testable import HunchUI
@testable import LoomFeature
import Rounds
import LawGeneration

@Suite("DRIFT is PROBE's surface, region for region — §7.5", .tags(.unit, .presubmission))
struct DriftSurfaceParityTests {

    @Test("Every region is at the identical rect in both modes, on both devices",
          arguments: [PlaySurfaceLayout.DeviceClass.compact, .large])
    func regionsAreIdentical(_ device: PlaySurfaceLayout.DeviceClass) {
        let probe = PlaySurfaceLayout.reference(device, mode: .probe)
        let drift = PlaySurfaceLayout.reference(device, mode: .drift)
        for region in PlaySurfaceRegion.allCases {
            #expect(probe.rect(of: region) == drift.rect(of: region),
                    "\(region) moved between PROBE and DRIFT on \(device)")
        }
    }

    @Test("The SE regions are §7.5's, verbatim")
    func seRegions() {
        let l = PlaySurfaceLayout.reference(.compact, mode: .drift)
        #expect(l.rect(of: .instrumentBar).minY == 20 && l.rect(of: .instrumentBar).maxY == 64)
        #expect(l.rect(of: .throat).minY == 64    && l.rect(of: .throat).maxY == 176)
        #expect(l.rect(of: .ribbon).minY == 176   && l.rect(of: .ribbon).maxY == 228)
        #expect(l.rect(of: .dial).minY == 236     && l.rect(of: .dial).maxY == 508)
        #expect(l.rect(of: .benchHandle).minY == 516 && l.rect(of: .benchHandle).maxY == 560)
        #expect(l.rect(of: .commitBar).minY == 604   && l.rect(of: .commitBar).maxY == 667)
    }

    @Test("The difference set between the two compositions is exactly two elements")
    func exactlyTwoDifferences() {
        let probe = RoundComposition(mode: .probe, hingeFired: false, seamMarkerIndex: nil)
        let drift = RoundComposition(mode: .drift, hingeFired: false, seamMarkerIndex: 7)
        #expect(drift.elementIDs.symmetricDifference(probe.elementIDs)
                == ["mode-sigil-drift", "mode-sigil-probe", "seam-marker"])
    }

    @Test("DRIFT adds no control: the commit bar holds the same three keys")
    func commitBarIsUnchanged() {
        let drift = RoundComposition(mode: .drift, hingeFired: true, seamMarkerIndex: nil)
        #expect(drift.commitBarKeys == [.probe, .twin, .bench])
        #expect(drift.commitBarKeys.count == 3)
    }

    @Test("DRIFT adds no timer and no progress readout beyond the par row")
    func noTimer() {
        let drift = RoundComposition(mode: .drift, hingeFired: true, seamMarkerIndex: 3)
        #expect(drift.elementIDs.contains(where: { $0.contains("timer") || $0.contains("clock") })
                == false)
        #expect(drift.instrumentBarElements == ["chevron", "par-tick-row", "cap-tick-row",
                                                "mode-sigil-drift"])
    }

    // MARK: the hinge is invisible

    @Test("NOTHING in the composition changes when the hinge fires")
    func theHingeIsInvisible() {
        let before = RoundComposition(mode: .drift, hingeFired: false, seamMarkerIndex: nil)
        let after  = RoundComposition(mode: .drift, hingeFired: true,  seamMarkerIndex: nil)
        #expect(before == after)
    }

    @Test("The mode sigil identifies DRIFT and never the hinge")
    func sigilIsAFunctionOfModeAlone() {
        #expect(ModeSigil.drift.path(in: .init(x: 0, y: 0, width: 24, height: 24))
             == ModeSigil.drift.path(in: .init(x: 0, y: 0, width: 24, height: 24)))
        #expect(RoundComposition(mode: .drift, hingeFired: true, seamMarkerIndex: nil).modeSigil
             == RoundComposition(mode: .drift, hingeFired: false, seamMarkerIndex: nil).modeSigil)
    }

    // MARK: the seam marker

    @Test("The seam marker appears only when trigger (b) wrote an index")
    func seamMarkerOnlyForCapture() {
        #expect(RoundComposition(mode: .drift, hingeFired: true, seamMarkerIndex: nil)
                    .elementIDs.contains("seam-marker") == false)
        #expect(RoundComposition(mode: .drift, hingeFired: true, seamMarkerIndex: 4)
                    .elementIDs.contains("seam-marker") == true)
    }

    @Test("It sits on the boundary after its tile, not on the tile")
    func seamMarkerGeometry() {
        let ribbon = RibbonLayout.reference(.compact)
        let x = SeamMarker.offset(afterTile: 4, in: ribbon)
        #expect(x == ribbon.leadingEdge(ofTile: 5))
        #expect(SeamMarker.silhouetteSide == 20)
    }

    @Test("The seam marker is not a hit target and never loads a glyph")
    func seamMarkerIsNotATarget() {
        #expect(SeamMarker.isAccessibilityElement == true)      // it is read
        #expect(SeamMarker.acceptsTouch == false)               // it is not pressed
    }
}
```

And `Modules/Tests/HunchUITests/DriftSigilTests.swift`:

```swift
@Suite("mode.drift — §12.4 and the sigil grammar", .tags(.unit, .presubmission))
struct DriftSigilTests {

    @Test("The drawing is two plates, the trailing one in the ghost frame")
    func twoPlates() {
        let parts = ModeSigil.drift.parts
        #expect(parts.filter(\.isPlate).count == 2)
        #expect(parts.contains { $0.isGhostFrame })
        #expect(parts.first { $0.isGhostFrame }?.isTrailing == true)
    }

    @Test("The ghost plate reuses GhostFrame.draw and does not restate the dash pattern")
    func reusesTheGhostFrame() {
        #expect(ModeSigil.drift.ghostPlateOwner == "GhostFrame.draw")
    }

    @Test("It is legible at the harness gate size of 22 pt and at all four sites",
          arguments: [22, 24, 44, 72])
    func legibleAtEverySite(_ side: Int) {
        #expect(ModeSigil.drift.path(in: .init(x: 0, y: 0, width: side, height: side)).isEmpty == false)
    }

    @Test("It survives greyscale against every mark already authored")
    func distinctFromEveryAuthoredMark() {
        #expect(SigilDistinctness.minimumDistance(of: .drift, against: .authored) >= SigilDistinctness.floor)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter DriftSurfaceParity`
then `--filter DriftSigilTests`

Expect missing `PlaySurfaceLayout.reference(_:mode:)`, `RoundComposition`, `ModeSigil`, `SeamMarker`,
`SigilDistinctness`. If E08·T02 named the layout entry point differently, keep its name and add the
`mode:` parameter with a default of `.probe` so no existing call site changes.

**Step 3 — implement** the minimum that turns it green. Run
`node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` before committing the
sigil, and record its coordinates back into `references/mode-sigils.md`'s `SIGILS` table.

**Step 4 — green, then refactor.** Then play a DRIFT round in the simulator on both reference devices
and screenshot both, side by side with a PROBE round of the same band, for `PROGRESS.md`.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/PlaySurfaceLayout.swift` — a `mode:` parameter that changes **nothing** but the tick row's `total`, and `PlaySurfaceRegion.allCases` if E08·T02 left the regions unenumerated |
| create | `Modules/Sources/HunchUI/Sigils/ModeSigil.swift` — the namespace plus `.drift`; E17·T04 adds the other three |
| create | `Modules/Sources/HunchUI/SeamMarker.swift` — the hairline, the 20 pt silhouette, `offset(afterTile:in:)` |
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` — draw the seam marker at its boundary; no other change |
| modify | `Modules/Sources/LoomFeature/Round.swift` — the `mode` it was built for, `DriftSchedule` when that mode is `.drift`, and the arm-time assertion that the band is served |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — the mode sigil slot E08·T08 left open, filled with `ModeSigil.drift` for a DRIFT round |
| create | `Modules/Sources/LoomFeature/RoundComposition.swift` — the element inventory the parity test asserts on |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.SeamMarker` (hairline weight, silhouette box, inset) |
| create | `Modules/Tests/HunchUITests/DriftSurfaceParityTests.swift` |
| create | `Modules/Tests/HunchUITests/DriftSigilTests.swift` |
| modify | `.claude/skills/hunch-sigil-drawing/references/mode-sigils.md` — `mode.drift`'s coordinates recorded into `SIGILS` |
| modify | `tests.json` — region parity, the two-element difference set, the hinge invisibility, sigil distinctness |
| modify | `DECISIONS.md` — `RoundComposition`'s existence and the seam marker's silhouette ruling |

## Implementation notes

### `RoundComposition` — making "no controls, no chrome, no timer" testable

The claim in §7.1 is a *negative* one, and negatives are the hardest thing to assert about a SwiftUI
view. The device is a small value the view is built from:

```swift
/// The inventory of what is on the play surface, as data. `RoundView` renders it; the parity test
/// asserts on it. It exists because §7.5's claim — that DRIFT differs from PROBE in exactly two
/// elements — is otherwise only checkable by reading the view body, which is not a check.
public struct RoundComposition: Equatable, Sendable {
    public let elementIDs: Set<String>
    public let commitBarKeys: [CommitKey]
    public let instrumentBarElements: [String]
    public let modeSigil: ModeSigil
    public init(mode: Mode, hingeFired: Bool, seamMarkerIndex: Int?)
}
```

Two properties make it worth its weight, and both are asserted above:

1. **`hingeFired` is an input and changes nothing.** `RoundComposition(mode:.drift, hingeFired:false, …)
   == RoundComposition(mode:.drift, hingeFired:true, …)` is the mode's whole thesis expressed as an
   equality. If a future change makes any element hinge-conditional, this line fails.
2. **The symmetric difference against PROBE's composition is a three-element set** — the two mode sigils
   (one leaves, one arrives) and the seam marker. Any third element added to either side breaks it.

`RoundView` must be *built from* the composition, not merely accompanied by it, or the value drifts
away from the view it claims to describe. The cheapest honest wiring: `RoundView` iterates
`composition.instrumentBarElements` to place the bar's contents and reads `composition.commitBarKeys`
for the commit bar.

### The mode sigil

`mode.drift` is already specified by §12.4 and by `references/mode-sigils.md`: two `plate` rects offset
diagonally, the trailing one drawn as `ghostPlate` — dashed, with the backward chevron. Three rules:

- **The ghost plate is `GhostFrame.draw`**, not a second dashed-rectangle routine. That mark has one
  owner (E04·T07) and it is the same idiom the seed glyph, the trailing ribbon tile and the Bench's
  ghost toggle wear; the whole reason DRIFT's sigil reads as *"the law behind the law"* is that the
  player has already learned that frame means *previous*.
- **The drawing is identical in every key state.** `sigil-grammar.md` §6: `idle` / `selected` /
  `barred` / `disabled` change the *ink and the surroundings*, never the path. That is why the sigil can
  be authored here and consumed unchanged by E17·T04's rack key.
- **Run the distinctness harness before committing.** `check-sigil-distinctness.js` gates at 22 pt
  against the 22 marks already authored. A sigil that fails it is redrawn, never shipped with a note.

Author **only** `mode.drift` here. PROBE's is already carried over from the mockup; ECHO's and SIEVE's
belong to their epics and to E17·T04. Adding all four now is how a mark that nobody needed yet gets
frozen before its consumer exists.

### The seam marker

§7.3: *a vertical hairline carrying a 20 pt silhouette of the accepted tile layout.* Four decisions:

1. **It is drawn at a tile boundary, not on a tile.** `SeamMarker.offset(afterTile:in:)` returns the
   leading edge of tile `index + 1` in the ribbon's own coordinate space. Drawing it *on* a tile would
   put a second mark inside a 44 pt box that already carries a verdict ring and possibly a doubled ring.
2. **The 20 pt silhouette is the sealed draft's rule-tile silhouettes**, one per rail, at tile-class
   level — Ramp / Bridge / Fork / Tally, which §4.2 already requires to be *"distinct at silhouette
   level"*. It is not a readable rendering of the law: at 20 pt nothing is readable, and the mark's job
   is *"you sealed something here"*, not *"here is what you sealed"*. Record the ruling; E15·T09 draws
   the skeleton silhouettes for the Codex and must reuse this drawing rather than author a second one.
3. **It is written by trigger (b) alone** (§7.3), so `seamMarkerIndex` is `nil` for triggers (a) and (c)
   and the mark simply is not in the composition. That asymmetry is deliberate and is stated in §7.3:
   the marker appears only where the player already knows something happened.
4. **It is read but not pressed.** An accessibility element with a label (E19 owns the wording); not a
   `Button`, not a ribbon-load target, no `onTapGesture`.

Under High Contrast the hairline is the one thing here that must not stay a hairline —
`hunch-design-tokens` forbids `stroke.hairline` carrying state — so resolve the weight through
`RenderEnv` and let the token step it, exactly as the ribbon's link arc does.

### `Round`, parameterised rather than forked

E08·T01's `@MainActor @Observable final class Round` gains the mode it was built for and, when that
mode is `.drift`, a `DriftSchedule`. It does **not** gain a `DriftRound` subclass or a sibling class:

- the phase machine is already two values (`RoundPhase` and now `DriftPhase`), and `Round` switches on
  the mode once, at construction;
- every duration, the input lock, the single-slot queue, the ribbon, the Bench, the Seal and the strike
  path are E08's and E09's and are used **as shipped**. If any of them needs a `if mode == .drift`
  branch, that is a signal the surface claim is being broken — stop and re-read §7.5.

One assertion is added at arm time: `precondition(DriftBudget.servedBands.contains(band))`, with §7.2
cited in the message. E11·T03's clamp is what makes it unreachable; the precondition is what makes a
regression in that clamp loud instead of a divide-by-`nil`.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter DriftSurfaceParity` and `--filter DriftSigilTests` green.
- [ ] The symmetric-difference assertion passes with a set of exactly three ids, and `RoundComposition(hingeFired:)` is proved to have no effect.
- [ ] `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` reports `mode.drift` clear at 22 pt against all 22 authored marks, and its coordinates are in `references/mode-sigils.md`.
- [ ] `grep -rn "if mode == .drift\|mode == \.drift ?" Modules/Sources/HunchUI/` returns nothing outside `PlaySurfaceLayout`'s tick-row `total` and the sigil slot.
- [ ] `Scripts/check-source-hygiene.sh` check 7 still passes — no `Text`, `Label` or `AttributedString` outside `.accessibility*` in `RoundView.swift`, `RibbonCanvas.swift` or `SeamMarker.swift`.
- [ ] `grep -rn "lineWidth: [0-9]\|\.opacity(0\." Modules/Sources/HunchUI/SeamMarker.swift Modules/Sources/HunchUI/Sigils/ModeSigil.swift` returns nothing.
- [ ] Simulator screenshots of a DRIFT round beside a PROBE round of the same band, on SE and Pro Max, are in `PROGRESS.md`.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T05: the DRIFT surface — mode.drift, the seam marker and the PROBE parity test"`

## Out of scope

- The other three mode sigils, the rack key's six states, and the archive-evidence gates — **E17·T04**, which consumes `ModeSigil.drift` unchanged.
- The instrument-bar chevron's suspend action — **E10·T04** / **E17·T09**.
- The seam **sweep** at the reveal, which docks to this marker — **T08**.
- The seam marker's VoiceOver label and its place in the element map — **E19**.
- The Codex page's skeleton silhouettes — **E15·T09**, which reuses this 20 pt drawing.
- Anything that would make an element hinge-conditional. If a task seems to need one, it is wrong.
