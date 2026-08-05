# T10 — Discoverability layers 1–5

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T09 |
| **Delivers** | §14.1 PROBE → *The ribbon* (the ghost mark and split-ring halves) · §14.1 PROBE → *The twin key* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-shared-marks` | Three of the five layers *are* marks — the ghost frame (six sites, including the throat's seed and the ribbon's trailing tile) and the verdict ring's `doubled` and `split` states. The skill's rule that a mark has one owning function is what makes "the same idiom means the same thing" checkable rather than hoped for. |
| `hunch-bench-instruments` | The layers live on four instruments this epic built (throat, ribbon, commit bar, spool sheet), and the skill's standing rule 2 — every state readable with no colour and no brightness discrimination — is the reason each layer is a shape and not a hint. |
| `hunch-swift-testing` | This task is mostly a test. The parameterisation over `Band.allCases`, the tag placement and the `tests.json` obligation are this skill's, and so is the rule that a test is never weakened to reach green. |

## Objective

The five wordless layers §6.6 uses to make contextuality discoverable — the seed glyph, the permanent ghost mark, the twin key, the split doubled ring, the sheet's verdict sort — are wired into the surface and **asserted to be identical in every band**, so that none of them can leak the family it exists to make findable.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.6 | All six layers, the requirement that they are present in **every** band so none of them leaks the family, and that all of them are shapes rather than words |
| `GAME_DESIGN.md` | §6.6 layer 3 | The twin key from round 1 of band 1; bands 1–4 teach that the Loom is consistent, band 5 contradicts it, and the contradiction lands because the expectation was built for free |
| `GAME_DESIGN.md` | §6.6 layer 5 | The verdict sort asks the only question that matters: *can the same glyph appear on both sides?* |
| `GAME_DESIGN.md` | §5.2 | Which bands are contextual (5 and 7) — used **only** to build the test's corpus, never read by shipping code |
| `hunch-shared-marks` | `references/ghost-frame.md`, `references/verdict-ring.md` | The one drawing each layer shares, and the ring's `doubled` / `split` states |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/DiscoverabilityTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import HunchUI
import LoomFeature

/// §6.6's five wordless layers, asserted band by band. The claim under test is not "each layer
/// exists" — the component suites already prove that — but that **no layer is band-conditional**,
/// because a layer that appeared only in a contextual band would announce the family it exists to
/// make findable.
@Suite("Discoverability layers 1–5 are present in every band", .tags(.unit, .presubmission))
@MainActor
struct DiscoverabilityTests {

    @Test("Layer 1 — the seed glyph is in the throat, ghost-framed, before probe 1",
          arguments: Band.allCases)
    func layer1_seedGlyph(_ band: Band) {
        let round = Fixtures.round(band: band)
        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.probesUsed == 0)
        let tiles = RibbonTileModel.tiles(probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
        #expect(tiles[0].isSeed)
        #expect(tiles[0].wearsGhostMark)
    }

    @Test("Layer 2 — the trailing-most tile wears the ghost mark at every probe count",
          arguments: Band.allCases)
    func layer2_ghostMark(_ band: Band) {
        let round = Fixtures.round(band: band)
        for step in 0..<6 {
            let tiles = RibbonTileModel.tiles(probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
            #expect(tiles.filter(\.wearsGhostMark).count == 1, "probe \(step)")
            #expect(tiles.last?.wearsGhostMark == true, "probe \(step)")
            round.probe(Deck.glyph(id: UInt8(step)))
            round.landVerdict(); round.endVerdictBeat()
        }
    }

    @Test("Layer 3 — the twin key is live from probe 0 in every band", arguments: Band.allCases)
    func layer3_twinKey(_ band: Band) {
        let round = Fixtures.round(band: band)
        #expect(round.isTwinAvailable)
        round.probeTwin()
        #expect(round.probesUsed == 1)
    }

    @Test("Layer 4 — a twin whose verdicts differ draws SPLIT, in every band",
          arguments: Band.allCases)
    func layer4_splitRing(_ band: Band) {
        let g = Deck.glyph(id: 7)
        let agreeing = RibbonTileModel.tiles(
            probes: [Probe(glyph: g, verdict: .admit, isTwin: false),
                     Probe(glyph: g, verdict: .admit, isTwin: true)],
            seedGlyph: Fixtures.seedGlyph)
        let differing = RibbonTileModel.tiles(
            probes: [Probe(glyph: g, verdict: .admit, isTwin: false),
                     Probe(glyph: g, verdict: .reject, isTwin: true)],
            seedGlyph: Fixtures.seedGlyph)
        #expect(agreeing.last?.ring == .doubled)
        #expect(differing.last?.ring == .split)
    }

    @Test("Layer 5 — the verdict sort is reachable from probe 0 in every band",
          arguments: Band.allCases)
    func layer5_verdictSort(_ band: Band) {
        let round = Fixtures.round(band: band)
        round.toggleSpool()
        round.toggleSpool()
        #expect(round.sheet == .verdictSorted)
        #expect(round.probesUsed == 0)
    }

    /// The invariant behind all five, stated where it can actually be violated. `Round` is the one
    /// type in the chain that *knows* its band — it needs `par` and `cap` — so it is the one type
    /// that could branch on it. The same gesture sequence must leave every affordance in the same
    /// state at every band.
    @Test("The same gestures leave the same affordances in every band")
    func affordancesAreBandIndependent() {
        struct Affordances: Hashable {
            let twinAvailable: Bool
            let sheetReachable: Bool
            let sheetSorted: Bool
            let ghostMarkIndex: Int
            let ghostMarkCount: Int
        }

        let observed = Set(Band.allCases.map { band -> Affordances in
            let round = Fixtures.round(band: band)
            for id in 0..<3 {
                round.probe(Deck.glyph(id: UInt8(id)))
                round.landVerdict()
                round.endVerdictBeat()
            }
            round.toggleSpool()
            round.toggleSpool()
            let tiles = RibbonTileModel.tiles(probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
            return Affordances(
                twinAvailable: round.isTwinAvailable,
                sheetReachable: round.sheet != .closed,
                sheetSorted: round.sheet == .verdictSorted,
                ghostMarkIndex: tiles.firstIndex(where: \.wearsGhostMark) ?? -1,
                ghostMarkCount: tiles.filter(\.wearsGhostMark).count)
        })

        #expect(observed.count == 1)   // one distinct answer across all eight bands
    }
}
```

Then the source lint that makes the claim mechanical rather than remembered — append to `Scripts/check-source-hygiene.sh` as **check 15**:

```bash
# 15. §6.6's five discoverability layers must not be band-conditional.
#     None of the files that draw them may mention `band` at all.
layer_files="Modules/Sources/HunchUI/RibbonTileModel.swift
Modules/Sources/HunchUI/SpoolSheetLayout.swift
Modules/Sources/LoomFeature/BreathPresentation.swift"
for f in $layer_files; do
  if grep -nE '\bband\b|Band\.' "$f" >/dev/null 2>&1; then
    echo "check 15: $f reads the band; §6.6 requires every discoverability layer to be band-independent"
    fail=1
  fi
done
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/DiscoverabilityTests
bash Scripts/check-source-hygiene.sh
```

Both must fail first. If `DiscoverabilityTests` is green on the first run, some of it is tautological — most likely `affordancesAreBandIndependent`, which is only meaningful because `Round` is a type that *could* branch on the band. Prove it can fail: on a scratch commit, make `Round.isTwinAvailable` return `false` at `Band.contextual`, watch the suite go red, then revert. A test that cannot fail is not a test.

**Step 3 — implement** whatever wiring is still missing.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Tests/LoomFeatureTests/DiscoverabilityTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` (only if a layer is not yet mounted) |
| modify | `tests.json` |
| modify | `SPEC.md` |
| modify | `PROGRESS.md` |

## Implementation notes

**This task is mostly assertion, and that is the point.** T03, T05, T07 and T09 each built one or two of the layers in isolation and each proved *its own* behaviour. What nothing has proved is the property §6.6 actually claims: that the five are **the same in every band**. That claim is what makes them safe to ship — a layer that appeared only where the law is contextual would be a tell, and the game would be teaching by leaking instead of by structure.

**The five, and where each already lives:**

| Layer | §6.6 | Owner | What T10 adds |
|---|---|---|---|
| 1 · the seed glyph | *"something is already in the throat that the player did not put there"* | `ThroatView` + `Round.draft` (T03) | the band-parameterised assertion |
| 2 · the ghost mark | *"the Loom's memory has a permanent, visible, one-slot address"* | `RibbonTileModel.wearsGhostMark` (T05) | the "exactly one, always the last" assertion at every probe count |
| 3 · the twin key | *"a third of the commit bar, from round 1 of band 1"* | `Round.probeTwin` (T07) | availability at probe 0 in every band |
| 4 · the split doubled ring | *"a rendered contradiction; no colour required, no text possible"* | `RibbonTileModel.ring` + `VerdictRing` (T05, E04·T07) | `.doubled` versus `.split` in every band |
| 5 · the verdict sort | *"the interface lets the player ask, and the answer is the family"* | `Round.sheet` + `verdictSorted` (T09) | reachability from probe 0 in every band |

If a layer turns out not to be mounted in `RoundView` — most likely layer 1's ghost frame on the throat, which is easy to build in `ThroatView` and forget to pass `isSeed` to — mount it here and note it in the commit message.

**Layer 6 is not this task's.** The Bench's ghost toggle and the Assay conditioned on a pinned ghost are E09·T02 and E09·T05, and they are drawn in the *identical* dashed-frame-and-chevron idiom as layers 1, 2 and 4 — which is the whole mechanism: symbol identity does the naming that words are forbidden from doing. Add a line to `SPEC.md` recording that the ghost frame now has five of its six sites shipped and that E09 owns the sixth, so nobody draws a second one.

**The band is not a secret from the code, it is a secret from the *presentation*.** `Round` knows its band — it needs `par` and `cap` — and that is fine. What must never happen is a *drawing* or an *affordance* branching on it. Check 15 enforces that on the three files where the temptation is real; keep the list short and specific rather than grepping all of `Modules/`, or the check becomes noise and someone will disable it.

**`tests.json`.** Add four entries with their commands and current status: the five discoverability layers, the tick-pitch invariant (T02/T08), the sheet-capacity invariant (T09) and the constant-hold invariant (T06). The brief mandates `tests.json` as a structured pass/fail list of every invariant, and an entry is never deleted or weakened to reach green.

## Acceptance criteria

- [ ] `DiscoverabilityTests` (six cases; five of them parameterised over all eight bands) green on both destinations.
- [ ] The temporary band-conditional edit described in step 2 was made, observed to fail the suite, and reverted — recorded in `PROGRESS.md` in one line.
- [ ] `bash Scripts/check-source-hygiene.sh` passes, and fails when `Band.contextual` is planted in `RibbonTileModel.swift`.
- [ ] `grep -rn 'Band\.' Modules/Sources/HunchUI/RibbonTileModel.swift Modules/Sources/HunchUI/SpoolSheetLayout.swift Modules/Sources/LoomFeature/BreathPresentation.swift` returns nothing.
- [ ] `tests.json` carries the four new invariants, each with the command that proves it.
- [ ] `SPEC.md` records the ghost frame's six sites and which epic owns each.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; `DiscoverabilityTests` green on both destinations; the hygiene script green.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T10: §6.6 layers 1–5 wired and asserted band-independent"`

Then run the epic's gate table end to end, paste its output into `.github/pr-body.md`, and open the PR.

## Out of scope

- Layer 6 — the Bench's ghost toggle and the pinned-ghost Assay — **E09·T02, E09·T05**.
- The breath, which is §6.6's *decision* rather than one of its six layers — **T07**. Its band-independence is asserted there; check 15 covers its file here because the two claims are the same claim.
- Band 5's first contradiction actually landing in play — that is a *round*, and it needs the Bench, the declaration and the reveal: **E09**, then **E10·T09**'s edge-case suite.
- The five nudges and the 13-beat opening script, which are onboarding rather than discoverability — **E10·T06, E10·T08**.
- VoiceOver's rendering of the split ring (`"twin, admitted then rejected"`), without which layer 4 is lost entirely in audio — **E19·T01**. Note the obligation in `SPEC.md` so E19 cannot miss it.
