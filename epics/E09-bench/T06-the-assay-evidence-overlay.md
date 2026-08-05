# T06 — The Assay evidence overlay

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | §14.1 `Assay evidence overlay` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First.** The overlay adds two ink states to a grid whose lattice is deliberately not state-bearing; the flash's ink and the ring's weight resolve through `env`, and the wrong-cell flash must not borrow `dur.ringAdmit` because the number happens to match. |
| `hunch-bench-instruments` | `references/assay-grid.md` §3 owns the overlay as one of the Assay's five states, states that the ring is `VerdictRing`'s drawing **at cell scale** rather than a new mark, and carries the band-4 reasoning: *"a free consistency check trivialises the low bands, where the reasoning is the game."* |
| `hunch-shared-marks` | The probed-glyph ring is `VerdictRing.draw` — the same function the ribbon, the primer, the counterexample and the Anomaly ribbon call. A ring drawn locally at cell scale is a second geometry within a year. |
| `hunch-swift-code` | The **grant** is game state and belongs in `HunchCore` as a `Codable` value with three inputs; the **overlay drawing** is view state in `AssayCanvas`. Getting that split backwards is how the floor rescue's permanent grant ends up unpersisted. |

## Objective

At the end of this task a player at band 4 or above sees which cells of the Assay they have already
probed and which cells their current draft gets *wrong* against the transcript — and a player at bands
1–3 does not, unless it is the Anomaly or unless §10.7's floor rescue has permanently opened the tool.
Before this task the Assay shows only the draft; after it, it can also show the evidence, exactly
where the design says the tool becomes load-bearing rather than trivialising.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.3 | The Decision: *"the Assay's evidence overlay — ringing probed glyphs and flashing any cell the draft gets wrong against the ribbon — unlocks at band 4, not band 1. Reason: a free consistency check trivialises the low bands, where the reasoning is the game; from band 4 up nobody can hold a 65,536-entry pair table in their head and the tool is load-bearing."* |
| `GAME_DESIGN.md` | §6.7 | *"Every ribbon admit is lit in the Assay, every ribbon reject dark"* — the consistency relation the overlay makes visible |
| `GAME_DESIGN.md` | §10.6 | The Anomaly *"always grants the Assay evidence overlay (canon §4.3 unlocks it at band 4; the Anomaly is always band ≥ 4, so this is consistent, not an exception)"* |
| `GAME_DESIGN.md` | §10.7 | The floor rescue: three consecutive losses at band 1 serves the family's deterministic anchor law **and unlocks the Assay evidence overlay permanently for that player**. *"At the floor, the tooling opens because the difficulty cannot close further."* |
| `GAME_DESIGN.md` | §3.5 | `prev` is the previously **probed** glyph regardless of verdict, and the seed glyph primes position 0 — which is how a ribbon entry maps to an Assay cell in a contextual band |
| `GAME_DESIGN.md` | §13.10 | The Assay stays **one** element; the overlay changes its value, never its element count |

## TDD — the test comes first

**Step 1 — write the failing tests.** The grant is core; the wrong-cell derivation is core; the flash
is view.

Create `HunchCore/Tests/BenchTests/AssayEvidenceGrantTests.swift`:

```swift
import Testing
import Bench
import Glyphs
import Laws
import Rounds
import HunchTestSupport

@Suite("Assay evidence grant", .tags(.unit, .presubmission))
struct AssayEvidenceGrantTests {

    // §4.3: band 4, not band 1. The exact boundary, both sides of it.
    @Test("Granted from band 4 up, withheld below, on an ordinary round",
          arguments: Band.allCases)
    func bandThreshold(_ band: Band) {
        let grant = AssayEvidenceGrant.none
        let granted = grant.isGranted(band: band, isAnomaly: false)
        #expect(granted == (band >= .relational))
    }

    @Test("Bands 1, 2 and 3 are withheld — the reasoning is the game there")
    func lowBandsAreWithheld() {
        for band in [Band.literal, .pair, .exclusive] {
            #expect(!AssayEvidenceGrant.none.isGranted(band: band, isAnomaly: false))
        }
    }

    // §10.6: "always grants" — and the Anomaly is always band ≥ 4, so this is consistent,
    // not an exception. Assert it holds at every band anyway, so a future band-3 Anomaly
    // would not silently change behaviour.
    @Test("The Anomaly always grants it", arguments: Band.allCases)
    func anomalyAlwaysGrants(_ band: Band) {
        #expect(AssayEvidenceGrant.none.isGranted(band: band, isAnomaly: true))
    }

    // §10.7: "unlock the Assay evidence overlay permanently for that player."
    @Test("The floor rescue grants it permanently, at every band")
    func floorRescueIsPermanent() {
        let rescued = AssayEvidenceGrant.none.grantingFloorRescue()
        for band in Band.allCases {
            #expect(rescued.isGranted(band: band, isAnomaly: false))
        }
    }

    // Permanent means it latches: nothing turns it off again.
    @Test("The floor-rescue grant latches and cannot be revoked")
    func grantLatches() {
        var grant = AssayEvidenceGrant.none
        grant = grant.grantingFloorRescue()
        grant = grant.grantingFloorRescue()
        #expect(grant.hasFloorRescue)
        #expect(grant == AssayEvidenceGrant.none.grantingFloorRescue())
        // Round-trips, because it lives in ladder.json.
        #expect(try! JSONDecoder().decode(AssayEvidenceGrant.self,
                                          from: JSONEncoder().encode(grant)) == grant)
    }
}

@Suite("Assay evidence derivation", .tags(.unit, .presubmission))
struct AssayEvidenceTests {

    // §6.7: "Every ribbon admit is lit in the Assay, every ribbon reject dark."
    // A wrong cell is exactly a disagreement between the draft and the transcript.
    @Test("A draft consistent with the transcript has no wrong cells")
    func consistentDraftIsClean() throws {
        let law = try #require(Corpora.statelessAtom)
        let ribbon = Corpora.ribbon(under: law, probes: 8, seed: 0xA55A)
        let evidence = AssayEvidence(draft: law, ribbon: ribbon, pinnedGhost: ribbon.seedGlyph)

        #expect(evidence.wrongCells.isEmpty)
        #expect(evidence.probedCells.count == Set(ribbon.probes.map(\.glyph)).count)
    }

    // The overlay's whole job: it names the cells that prove the draft false.
    @Test("A draft that contradicts one probe flashes exactly that cell")
    func oneContradictionOneFlash() throws {
        let hidden = try #require(Corpora.statelessAtom)
        let ribbon = Corpora.ribbon(under: hidden, probes: 8, seed: 0xBEEF)
        let wrong = try #require(Corpora.atomDisagreeingOnExactlyOne(of: ribbon, under: hidden))

        let evidence = AssayEvidence(draft: wrong.draft, ribbon: ribbon,
                                     pinnedGhost: ribbon.seedGlyph)
        #expect(evidence.wrongCells == [wrong.glyphID])
    }

    // §3.5: `prev` is the previously PROBED glyph regardless of verdict, and the seed
    // glyph primes position 0. In a contextual band the ring lands on the cell for `cur`,
    // and only for probes whose `prev` equals the pinned ghost.
    @Test("In a contextual band the overlay rings only probes taken after the pinned ghost")
    func contextualRingsAreConditioned() throws {
        let law = try #require(Corpora.workedBand5Law)
        let ribbon = Corpora.ribbon(under: law, probes: 12, seed: 0x1234)
        let pin = try #require(ribbon.probes.first?.glyph)

        let evidence = AssayEvidence(draft: law, ribbon: ribbon, pinnedGhost: pin)
        let expected = Set(ribbon.pairs.filter { $0.prev == pin }.map { Int($0.cur.glyphID) })
        #expect(evidence.probedCells == expected)
    }

    // A counterexample is NOT a probe (§4.5) and therefore is never ringed as one.
    @Test("A docked counterexample never appears in the overlay")
    func counterexampleIsNotEvidence() throws {
        let law = try #require(Corpora.statelessAtom)
        var ribbon = Corpora.ribbon(under: law, probes: 6, seed: 0x777)
        let ce = try #require(Corpora.counterexample(for: ribbon, under: law))
        ribbon.dock(ce)

        let evidence = AssayEvidence(draft: law, ribbon: ribbon, pinnedGhost: ribbon.seedGlyph)
        #expect(!evidence.probedCells.contains(Int(ce.glyph.glyphID)))
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter 'AssayEvidenceGrantTests|AssayEvidenceTests'
```

`cannot find 'AssayEvidenceGrant' in scope` is the right failure.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Check the fast suite budget; `AssayEvidence` is O(ribbon), so it
should cost microseconds.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Bench/AssayEvidenceGrant.swift` — the three-input predicate and the latching floor-rescue flag |
| create | `HunchCore/Sources/Bench/AssayEvidence.swift` — `probedCells`, `wrongCells`, derived from the ribbon and the draft |
| modify | `Modules/Sources/HunchUI/AssayCanvas.swift` — draw the rings and the flash when `evidence != nil` |
| modify | `Modules/Sources/HunchUI/AssayModel.swift` — hold the grant, produce the `AssayEvidence?` |
| modify | `Modules/Sources/LoomFeature/Round.swift` — pass the grant through; it is `ladder.json` state (E11 persists it) |
| create | `HunchCore/Tests/BenchTests/AssayEvidenceGrantTests.swift` |
| create | `HunchCore/Tests/BenchTests/AssayEvidenceTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `ribbon(under:probes:seed:)`, `atomDisagreeingOnExactlyOne(of:under:)`, `counterexample(for:under:)` |
| modify | `tests.json` — the band-4 threshold and the floor-rescue permanence |

## Implementation notes

### The grant is a value, and it has exactly three inputs

```swift
/// §4.3, §10.6, §10.7. Persisted inside ServingState in `ladder.json` (E11 owns the file).
public struct AssayEvidenceGrant: Hashable, Sendable, Codable {
    /// §10.7 — three consecutive losses at band 1 opens the tooling permanently. Latches.
    public private(set) var hasFloorRescue: Bool

    public static let none = AssayEvidenceGrant(hasFloorRescue: false)

    /// §4.3's band-4 unlock, §10.6's Anomaly grant, §10.7's permanent rescue.
    public func isGranted(band: Band, isAnomaly: Bool) -> Bool {
        hasFloorRescue || isAnomaly || band >= .relational
    }

    public func grantingFloorRescue() -> Self { Self(hasFloorRescue: true) }
}
```

Three inputs, one line, no `else`. Everything else — which round it is, whether the player is a
veteran, whether they asked for it in Settings — is **not** an input, and adding one is a design
change. In particular there is **no Settings toggle for the overlay**: §12.6's list does not contain
one, and adding one would let a band-2 player switch on the free consistency check the band-4 rule
exists to withhold.

`band >= .relational` needs `Band: Comparable`, which is E05·T06's hand-written `<` (an `Int` raw type
suppresses SE-0266's synthesis — `hunch-swift-code`'s first gotcha).

### The evidence is a derivation, not a cache

```swift
public struct AssayEvidence: Hashable, Sendable {
    /// glyphIDs the player has probed, conditioned on the pinned ghost in contextual bands.
    public let probedCells: Set<Int>
    /// glyphIDs where the DRAFT disagrees with the transcript's recorded verdict.
    public let wrongCells: Set<Int>

    public init(draft: LawNode, ribbon: Ribbon, pinnedGhost: Glyph)
}
```

Two subtleties, both of them in the tests:

1. **Conditioning.** The Assay's picture is a slice through the pair table at the pinned ghost, so the
   overlay must be conditioned the same way or the rings will sit on cells the picture is not talking
   about. In a contextual band a probe contributes a ring **only if its `prev` equals the pinned
   ghost** — which is `Ribbon.pairs`, where `prev` is the previously *probed* glyph regardless of
   verdict and the seed glyph primes position 0 (§3.5). In a stateless band every slice is the same,
   so every probe contributes.
2. **The counterexample is not a probe.** §4.5 is explicit: it does not increment `probesUsed`, it
   does not become `prev`, and it is not part of the transcript the overlay reads. `Ribbon.probes`
   must therefore exclude the docked island — which it already does if T09 modelled the dock as a
   separate field rather than as a ribbon entry. The test is here to keep that true.

`AssayEvidence` is recomputed on draft change, like the picture beside it. It is 256 bits of work over
a ribbon of at most 65 entries; caching it is premature and would need invalidation nobody wants.

### The drawing

- **The ring is `VerdictRing.draw` at cell scale**, with the probe's own verdict, not a new mark
  (`assay-grid.md` §3). At `C.Assay.cellSide(.benchWell)` = 4 pt the ring is a hairline circle; at the
  inspector's 23 pt it is legible as the same open/closed aperture idiom the ribbon uses. One
  function, two scales, no second geometry.
- **The wrong-cell flash** is the one animation this task adds, so it needs a row in
  `reduce-motion.md` §2 written in the **same commit** (T12 verifies the table is complete; it does
  not write missing rows for you). Substitution: the cell takes its wrong-state ink **statically**;
  the flash is the arrival, and the arrival is what a Reduce Motion player asked not to see. The
  information — *which* cells are wrong — is unchanged.
- Do not add a third overlay state, a count, a legend or a colour pair. The Assay is monochrome in
  every theme and Differentiate Without Colour changes nothing on it.

### The element count does not change

The Assay stays **one** `.image` element with `children: .ignore`. The overlay changes its **value**:
*"Admits 64 of 256 glyphs, with this previous glyph. Three probed cells disagree."* — one localized
format string, interpolations only, never a glued fragment. The wording is E19's; wire the `Loc` call
site and leave the sentence to the catalog.

Exposing a wrong cell as its own element would be 256 swipes in the worst case and would break the
fixed **verdict → evidence → bookkeeping** announcement order the Bench's other elements rely on.

### The seam with E11 and E16

- `hasFloorRescue` is set by **E11·T07**'s anti-frustration trigger and persisted in `ladder.json`.
  This task ships the value and its latch; E11 calls `grantingFloorRescue()`.
- `isAnomaly` is supplied by **E16·T03**'s grants-and-isolation pass. This task ships the parameter.
- Until both land, `Round` takes the grant as an init parameter defaulting to `.none`, and the
  simulator harness passes `.none` — so the band-4 boundary is what you see when you play.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'AssayEvidenceGrantTests|AssayEvidenceTests'` green.
- [ ] `grep -n 'func isGranted' HunchCore/Sources/Bench/AssayEvidenceGrant.swift` shows exactly two
      parameters plus the latched flag — no fourth input, no Settings read.
- [ ] `grep -rn 'evidenceOverlay\|assayEvidence' Modules/Sources/MetaFeature/SettingsView.swift`
      returns nothing (the file may not exist yet; the check is that it never gains one).
- [ ] `grep -rn 'VerdictRing' Modules/Sources/HunchUI/AssayCanvas.swift` shows a **call**, not a
      declaration.
- [ ] `reduce-motion.md`'s table has a row for the wrong-cell flash, and
      `MotionRow.allCases` (T12) contains it.
- [ ] `tests.json` carries `assay.evidence-band-4-threshold` and `assay.evidence-floor-rescue-permanent`.
- [ ] In the simulator: a band-2 round shows no rings; a band-5 round shows rings on probed cells and
      a flash on a deliberately contradictory draft.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter 'AssayEvidenceGrantTests|AssayEvidenceTests'`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T06: the Assay evidence overlay and its band-4, Anomaly and floor-rescue grants"`

## Out of scope

- **The floor-rescue trigger itself** — three consecutive losses at band 1, the anchor law, the relief
  ladder. **E11·T07**.
- **The Anomaly's grant plumbing and its θ isolation.** **E16·T03**.
- **Persisting the grant.** `ladder.json` and `ServingState` are **E11·T01**.
- **"Read by attribute".** **E19·T04**.
- **The Assay's grid, pin, scrubber and inspector.** **T05**.
- **The counterexample's dock.** **T09**; this task only asserts that the dock never enters the
  overlay.
