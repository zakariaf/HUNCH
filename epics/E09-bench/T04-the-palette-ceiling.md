# T04 — The palette ceiling

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 `Palette ceiling` · `Palette sufficiency` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This is a **core** type, not a view concern, and the boundary predicate says so: it is a pure function of values you can write down. The skill also owns the `Band`/`Family` collapse — there is one `enum Band` and `tileClasses(Family(servedBand))` is therefore `RuleTileClass.required(for: band)`, with no `Family` type to convert through. |
| `hunch-bench-instruments` | Owns what a palette stamp *is* and which tile class each production needs; the ceiling decides which of its four stamps are drawn and which are `.notEnabled`. |
| `hunch-swift-testing` | The `required(for:)` set is **derived from the generator over a seeded corpus** rather than hand-listed, which is a `Corpora`-shaped test; this skill owns the T21 deviation (parameterise over bands, loop inside) that the derivation test uses. |

## Objective

At the end of this task the palette knows which tile classes a player may hold, derived from the
highest band they have ever been **served** plus one, and the round refuses to arm unless the palette
can express the band it is about to serve. Before this task all four stamps are drawn unconditionally;
after it, a beginner's palette is short, a veteran's is full, and neither can read the round's family
off their own toolbox.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.4 | The Decision: *"the palette unlocks tile classes at the player's lifetime maximum band + 1, never at the current round's band. Reason: a veteran always sees the full palette regardless of what they are being served and cannot read the family off the toolbox; a beginner literally cannot express a band-5 law, which is fine, because they will never be served one."* Plus the production → tile mapping |
| `GAME_DESIGN.md` | §10.4 | *"The palette ceiling is derived from the highest band ever **served**, not the highest ever cleared"*, why clearing is the wrong predicate (`reach` plus jitter can serve two bands above the last cleared one), the serve-time assertion `paletteTileClasses(player) ⊇ tileClasses(Family(servedBand))`, and *"If the assertion would fail, the palette is raised to satisfy it and the round proceeds."* Also: calibration rounds 1–5 unlock the full palette, and resetting the ladder returns the palette to its **band-2 opening state** |
| `GAME_DESIGN.md` | §10.6 | The Anomaly temporarily unlocks the full palette for that round only, then reverts |
| `GAME_DESIGN.md` | §5.2 | The eight families and their example laws — the evidence for which tile class each band needs, and why `required(for:)` must be derived rather than transcribed |
| `GAME_DESIGN.md` | §10.10 | H20 `Palette sufficiency` — *"asserted at serve time, not at generation time"*, for every served round in the Level-B matrix **and** every calibration round |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | The band → tile-class switch has no `default:` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/BenchTests/PaletteCeilingTests.swift`:

```swift
import Foundation
import Testing
import Bench
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Palette ceiling", .tags(.unit, .presubmission))
struct PaletteCeilingTests {

    // §4.4: "lifetime maximum band + 1". §10.4: reset "returns the palette to its band-2
    // opening state", so a fresh player whose first served band is 1 holds the band-2 palette.
    @Test("A fresh player opens on the band-2 palette")
    func openingState() {
        let fresh = PaletteCeiling.opening
        #expect(fresh.maxBandEverServed == .literal)
        #expect(fresh.ceilingBand == .pair)
        #expect(fresh.unlocked == RuleTileClass.required(upTo: .pair))
        #expect(fresh.unlocked == [.ramp])
    }

    // The ceiling is `served + 1`, clamped at the top of the ladder.
    @Test("The ceiling is one band above the lifetime maximum served, clamped",
          arguments: Band.allCases)
    func ceilingIsServedPlusOne(_ band: Band) {
        let ceiling = PaletteCeiling(maxBandEverServed: band)
        let expected = Band(rawValue: min(band.rawValue + 1, Band.systemic.rawValue))!
        #expect(ceiling.ceilingBand == expected)
    }

    // Monotone: the palette only ever grows.
    @Test("Unlocked classes are monotone in the lifetime maximum")
    func monotone() {
        for (lower, higher) in zip(Band.allCases, Band.allCases.dropFirst()) {
            let a = PaletteCeiling(maxBandEverServed: lower).unlocked
            let b = PaletteCeiling(maxBandEverServed: higher).unlocked
            #expect(a.isSubset(of: b))
        }
    }

    // THE invariant: "a veteran always sees the full palette regardless of what they are
    // being served and cannot read the family off the toolbox."
    @Test("Serving a low band after a high one does not shrink the palette")
    func aVeteranCannotReadTheFamilyOffTheToolbox() {
        let veteran = PaletteCeiling.opening.raised(toServe: .systemic)
        let afterAnEasyRound = veteran.raised(toServe: .literal)

        #expect(afterAnEasyRound.unlocked == veteran.unlocked)
        #expect(afterAnEasyRound.maxBandEverServed == .systemic)
        #expect(afterAnEasyRound.unlocked == Set(RuleTileClass.allCases))
    }

    // §10.4: "If the assertion would fail, the palette is raised to satisfy it and the
    // round proceeds." H20, asserted at serve time.
    @Test("Serving any band leaves the palette sufficient for it", arguments: Band.allCases)
    func raisingIsSufficient(_ served: Band) {
        let raised = PaletteCeiling.opening.raised(toServe: served)
        #expect(raised.unlocked.isSuperset(of: RuleTileClass.required(for: served)))
        #expect(raised.isSufficient(for: served))
        #expect(!PaletteCeiling.opening.isSufficient(for: .contextual))   // the gallop's own trap
    }

    // §10.4's worked case: "A player who wins bands 1 and 2 has lifetime max 2, hence a
    // ceiling of band 3 — two Ramps and a coupler, NO BRIDGE — and round 3 is band 4
    // RELATIONAL, which cannot be stated without one."
    @Test("The galloping ladder's round 3 is unwinnable without the raise")
    func theGallopsOwnTrap() {
        let afterTwoWins = PaletteCeiling.opening
            .raised(toServe: .literal)
            .raised(toServe: .pair)
        #expect(afterTwoWins.ceilingBand == .exclusive)
        #expect(!afterTwoWins.unlocked.contains(.bridge))
        #expect(!afterTwoWins.isSufficient(for: .relational))

        let served = afterTwoWins.raised(toServe: .relational)
        #expect(served.unlocked.contains(.bridge))
        #expect(served.isSufficient(for: .relational))
    }

    // §10.4 / §10.6: calibration and the Anomaly grant the FULL palette for the round only,
    // and reverting must not lower `maxBandEverServed`.
    @Test("A temporary full-palette grant reverts without disturbing the lifetime maximum")
    func temporaryGrantsRevert() {
        let player = PaletteCeiling.opening.raised(toServe: .pair)
        let granted = player.grantingFullPalette()

        #expect(granted.unlocked == Set(RuleTileClass.allCases))
        #expect(granted.maxBandEverServed == player.maxBandEverServed)
        #expect(granted.reverted() == player)
    }

    // §10.4: resetting the ladder zeroes ServingState, so the ceiling returns to opening.
    @Test("Resetting the ladder returns the palette to its opening state")
    func resetReturnsToOpening() {
        let veteran = PaletteCeiling.opening.raised(toServe: .systemic)
        #expect(veteran.reset() == PaletteCeiling.opening)
    }
}

@Suite("Palette sufficiency, derived from the generator", .tags(.unit, .presubmission))
struct PaletteSufficiencyTests {

    // `required(for:)` is DERIVED, not transcribed: every law the generator emits at a band
    // must be buildable from that band's required classes, and every required class must be
    // witnessed by at least one law — or the set is too big and the palette leaks.
    // T21 deviation: parameterise over bands, loop the corpus inside (08 §7.4).
    @Test("required(for:) is exactly the set of classes the band's laws use",
          arguments: Band.allCases)
    func requiredSetIsTight(_ band: Band) throws {
        var witnessed = Set<RuleTileClass>()
        let required = RuleTileClass.required(for: band)

        for index in 0..<Corpora.lawsPerBand {
            let seed = Corpora.seed(band: band, index: index)
            let law = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
            let used = BenchLayout(law).tileClasses

            guard used.isSubset(of: required) else {
                Attachment.record(law, named: "band\(band.rawValue)-index\(index).json")
                Issue.record("""
                    band \(band.rawValue) law uses \(used.subtracting(required)) which \
                    required(for:) omits — reproduce with Corpora.seed(band: .\(band), index: \(index))
                    """)
                return
            }
            witnessed.formUnion(used)
        }

        #expect(witnessed == required, "required(for:) is wider than the generator ever emits")
    }

    // H20, in the shape the harness will assert it: sufficiency holds for every served band
    // once the raise has run.
    @Test("H20 holds for every band after the serve-time raise", arguments: Band.allCases)
    func h20(_ band: Band) {
        let ceiling = PaletteCeiling.opening.raised(toServe: band)
        #expect(ceiling.unlocked.isSuperset(of: RuleTileClass.required(for: band)))
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
swift test --package-path HunchCore --filter 'PaletteCeilingTests|PaletteSufficiencyTests'
```

The failure must be `cannot find 'PaletteCeiling' in scope`. If `RuleTileClass` already exists from
E06·T03 under another name (`RuleTile.Kind` is the likely spelling), **use it** and adjust the test —
do not mint a second enum for one concept.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Re-run the whole `HunchCore` suite and re-check the 10 s budget:
`requiredSetIsTight` runs the generator `8 × Corpora.lawsPerBand` times and is the only expensive
thing this task adds. If it measures over ~0.4 s, tag it `.nightly` and keep a `Band.allCases × 200`
smoke subset in presubmission — never delete it.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Bench/PaletteCeiling.swift` |
| modify | `HunchCore/Sources/Bench/RuleTile.swift` — `RuleTileClass` (only if E06·T03 did not ship it) and `RuleTile.tileClass` |
| modify | `HunchCore/Sources/Bench/BenchLayout.swift` — `var tileClasses: Set<RuleTileClass>` |
| modify | `Modules/Sources/HunchUI/BenchPalette.swift` — draw a locked stamp as `.notEnabled`, never absent |
| modify | `Modules/Sources/LoomFeature/Round.swift` — assert sufficiency in `arming`, before the first frame |
| create | `HunchCore/Tests/BenchTests/PaletteCeilingTests.swift` |
| modify | `tests.json` — the ceiling monotonicity, the veteran invariant and H20 |

## Implementation notes

### The type

```swift
/// §4.4, §10.4. Pure over `maxBandEverServed` and a temporary grant; it has no idea what
/// band the current round is, and that is the whole design.
public struct PaletteCeiling: Hashable, Sendable, Codable {
    public private(set) var maxBandEverServed: Band
    /// §10.4 / §10.6 — calibration rounds 1–5 and the Anomaly round hold this for the
    /// duration of that round only. It is round state, not lifetime state.
    public private(set) var isFullPaletteGranted: Bool

    /// §10.4: reset "returns the palette to its band-2 opening state".
    public static let opening = PaletteCeiling(maxBandEverServed: .literal,
                                               isFullPaletteGranted: false)

    public var ceilingBand: Band {
        Band(rawValue: min(maxBandEverServed.rawValue + 1, Band.systemic.rawValue))!
    }

    public var unlocked: Set<RuleTileClass> {
        isFullPaletteGranted ? Set(RuleTileClass.allCases)
                             : RuleTileClass.required(upTo: ceilingBand)
    }

    public func isSufficient(for served: Band) -> Bool {
        unlocked.isSuperset(of: RuleTileClass.required(for: served))
    }

    /// §10.4: "If the assertion would fail, the palette is raised to satisfy it and the
    /// round proceeds." Raising is the ONLY way `maxBandEverServed` moves, and it never falls.
    public func raised(toServe served: Band) -> PaletteCeiling {
        var copy = self
        copy.maxBandEverServed = max(maxBandEverServed, served)
        return copy
    }
}
```

Three shapes worth noticing:

- **`unlocked` takes no parameter.** There is no `unlocked(forRound:)` overload and there must never
  be one — that signature is the bug §4.4's Decision is written to prevent, and its absence is what
  makes the "veteran cannot read the family off the toolbox" test structural rather than behavioural.
- **`raised(toServe:)` returns a new value.** `PaletteCeiling` is a `Codable` value that lives inside
  `ServingState` (E11·T01) and is persisted in `ladder.json`; nothing here mutates in place or reaches
  for a store.
- **`max(maxBandEverServed, served)`** requires `Band: Comparable`, which — per `hunch-swift-code`'s
  first gotcha — needs a hand-written `<` because the `Int` raw type suppresses SE-0266's synthesis.
  If `Band` still lacks it, add it in E05·T06's file, not here.

### `required(for:)` — derived, and why

The temptation is a hand-written table: band 4 → bridge, band 6 → fork, band 8 → tally. It is right
today and it is a second source of truth for the generator's skeleton sampler, which is where the fact
actually lives. Two homes, one fact.

So the shipped implementation is a switch over `Band` **with no `default:`**, and the shipped *test*
is the derivation: for every band, walk `Corpora.lawsPerBand` generated laws, take
`BenchLayout(law).tileClasses`, and assert the union is **exactly** `required(for: band)` — not a
subset, not a superset. Too small and the palette cannot express a law the generator emits (H20 fails
in the field). Too large and the palette leaks: a player who has been served band 6 would be handed a
Tally they cannot use, which tells them something about band 8 that they have not earned.

`required(upTo:)` is the union over `Band.allCases.filter { $0 <= ceiling }`. Composite (band 7) is
the row to watch: its example law in §5.2 is two Bridges under a coupler, so it needs `.bridge`, but
the skeleton sampler may also emit atom-plus-relational forms that need `.ramp`. The derivation test
is what tells you which — read the failure, do not guess.

### Where it is read, and where it is not

- **`Round.arming`** asserts `ceiling.isSufficient(for: band)` before the first frame is committed
  (§10.4's `assert` line, H20's *"asserted at serve time, not at generation time"*). In DEBUG this is
  a `precondition`; in release the round *raises and proceeds*, because refusing to start a round the
  player can see is worse than a wide palette. Both paths are exercised by the test.
- **`BenchPalette`** reads `ceiling.unlocked` and draws a locked stamp at `Opacity.disabled` with
  `.notEnabled` and its label intact — **never absent**. A hole in the palette is worse than a
  refusing stamp: it changes the palette's *shape*, which is a second signal, and §12.8's rule for a
  disabled cell says keep it in the tree.
- **Nothing else reads it.** In particular no view asks "what band is this round" to decide what to
  draw. `grep -rn 'servedBand\|round.band' Modules/Sources/HunchUI` must return nothing.

### The seam with E11

`maxBandEverServed` belongs to `ServingState`, which is **E11·T01**. This task ships the value and its
algebra; E11 stores it, decays nothing, and calls `raised(toServe:)` inside step 12 of the serving
policy. Until E11 lands, `Round` takes `PaletteCeiling` as an init parameter with `.opening` as the
simulator default, and E10's composition root threads it. Leave a `// E11: ServingState owns the
storage` marker at the one place it is constructed and do not invent a store here.

The Anomaly's grant (§10.6) and calibration's grant (§10.4) are the same mechanism —
`grantingFullPalette()` / `reverted()` — and both are E11/E16's to *call*. Shipping both here, tested,
is what stops each of them growing its own copy.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'PaletteCeilingTests|PaletteSufficiencyTests'` green.
- [ ] `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` still passes.
- [ ] `grep -n 'func unlocked' HunchCore/Sources/Bench/PaletteCeiling.swift` shows **no** parameter
      list containing a `Band` other than through `maxBandEverServed`.
- [ ] `grep -c 'default:' HunchCore/Sources/Bench/PaletteCeiling.swift` returns `0`.
- [ ] `grep -rn 'round\.band\|servedBand' Modules/Sources/HunchUI/BenchPalette.swift` returns nothing.
- [ ] `tests.json` carries `palette.ceiling-monotone`, `palette.veteran-invariant` and
      `palette.sufficiency-H20`, the last cross-referenced to E11's harness row.
- [ ] In the simulator with `PaletteCeiling.opening`, the Bridge, Fork and Tally stamps are visible,
      dimmed and announce `"Bridge tile, dimmed"` — not missing.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter 'PaletteCeilingTests|PaletteSufficiencyTests'`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T04: PaletteCeiling from maxBandEverServed + 1, raised at serve time"`

## Out of scope

- **`ServingState`, `maxBandEverServed`'s persistence, the galloping ladder and the calibration
  grant's trigger.** **E11·T01** and **E11·T05**. This task ships the value they store and call.
- **The Anomaly's grant trigger and its isolation from θ.** **E16·T03**.
- **The floor rescue's permanent Assay overlay.** **T06** of this epic; it is a different grant with a
  different lifetime and it does not touch the palette.
- **Drawing the stamps.** **T01**.
- **`BenchLayout`, `RuleTile` and their payloads.** **E06·T03**.
- **Anything about difficulty, δ or θ.** **E11**.
