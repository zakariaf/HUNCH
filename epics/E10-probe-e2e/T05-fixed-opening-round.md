# T05 — The fixed opening round

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Fixed opening round (ONBOARDING) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The opening round is a *bypass* of the generator, and the only way that stays honest is if the bypass is a named value in `HunchCore/Sources/Rounds/` that never calls `generate` and never consults `avoid`. This skill owns where it goes, what it is called, and the caseless-enum-namespace ruling (`W16`) that keeps it from becoming a `Constants.swift`. |

`hunch-bench-instruments` is **not** loaded here: the Dial preset is a *value* (the seed glyph) in this
task; the Dial's retains-the-last-probe behaviour and its geometry are E08·T04's.

## Objective

At the end of this task the first round any player ever sees is a single named configuration —
mode `probe`, band 1, seed `0x48554E4348`, law `shape ∈ {triangle}`, seed glyph 22, par 7, cap 12 — built
without the generator, without the serving policy and without the novelty ring. A failed opening round
re-runs the same *configuration* with a different band-1 law of the same shape, whose seed glyph is still
one the law admits.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.5 (The opening round is fixed) | mode, band, seed, generator bypassed, the Opening Law and its four difficulty facts, the forced seed glyph and its `glyphID` arithmetic, par and cap, and the Dial preset rule |
| `GAME_DESIGN.md` | §12.5 (Failure of the opening round) | the re-run: a *different* band-1 law, still `attr ∈ {single value}`, still with the seed glyph forced to an admitted glyph |
| `GAME_DESIGN.md` | §5.2 | the band-1 row this law is the exemplar of — `|H|`, δ range, the exemplar itself |
| `GAME_DESIGN.md` | §2 | `glyphID = fill*64 + shape*16 + pips*4 + hue` and the canonical attribute order |
| `GAME_DESIGN.md` | §5.7 | par and cap as locked constants, read from `Band`, never copied |
| `GAME_DESIGN.md` | §6.3 | "at probe 0 the Dial is pre-loaded with the seed glyph"; probe 1 defaults to a twin-of-seed |
| `GAME_DESIGN.md` | §14.5 open decision 4 | band 1 needs no G4 exclusion set, which is *why* the opening round is safe to arm before `lowerBandIndex.bin` finishes building |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | W16, N47 | caseless enum namespace; document the complexity of anything that looks like a lookup |

Do not restate the seed, the glyph id or the δ in prose anywhere else in the codebase — this file is the
one home, and the test below is what proves the arithmetic rather than a comment.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/OpeningRoundTests.swift`:

```swift
import Testing
@testable import Rounds
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("The fixed opening round — §12.5", .tags(.unit, .presubmission))
struct OpeningRoundTests {

    @Test("the seed glyph is 22, and 22 is hollow triangle two pips frost (§2's arithmetic)")
    func seedGlyphIdentity() {
        let seed = Deck.glyph(id: OpeningRound.seedGlyphID)
        #expect(seed.fill == .hollow)
        #expect(seed.shape == .triangle)
        #expect(seed.pips == .two)
        #expect(seed.hue == .frost)
        #expect(Deck.glyphID(of: seed) == OpeningRound.seedGlyphID)
    }

    @Test("the Opening Law is the band-1 exemplar: p = 0.250, deficit 0, three free attributes")
    func openingLawIsTheBandOneExemplar() {
        let law = Law(OpeningRound.law)
        #expect(isApproximatelyEqual(law.admitRate, 0.250, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(law.marginalDeficit, 0.0, absoluteTolerance: 1e-9))
        #expect(law.freeAttributeCount == 3)
        #expect(law.leafCount == 1)
        #expect(isApproximatelyEqual(difficulty(of: law), 0.023, absoluteTolerance: 0.0005))
        #expect(Band.literal.difficultyRange.contains(difficulty(of: law)))
    }

    @Test("the law admits the seed glyph, so the very first probe is a positive (§12.5 beat 2)")
    func seedGlyphIsAdmitted() {
        let law = Law(OpeningRound.law)
        let seed = Deck.glyph(id: OpeningRound.seedGlyphID)
        #expect(law.admits(seed, after: seed))
    }

    @Test("the law is already in RNF, so the Bench can spell it exactly once (G10)")
    func lawIsCanonical() {
        #expect(OpeningRound.law == OpeningRound.law.renderedNormalForm)
        #expect(LawNode(BenchLayout(OpeningRound.law)) == OpeningRound.law.renderedNormalForm)
    }

    @Test("par and cap are read from the band, never copied into the opening round")
    func parAndCapComeFromTheBand() {
        #expect(OpeningRound.band == .literal)
        #expect(Band.literal.par == 7)
        #expect(Band.literal.cap == 12)
    }

    @Test("the configuration is fixed: the same value every call, on any device, forever")
    func configurationIsFixed() {
        #expect(OpeningRound.configuration(attempt: 1) == OpeningRound.configuration(attempt: 1))
        #expect(OpeningRound.configuration(attempt: 1).seed == 0x48554E4348)
        #expect(OpeningRound.configuration(attempt: 1).law == OpeningRound.law)
        #expect(OpeningRound.configuration(attempt: 1).seedGlyphID == OpeningRound.seedGlyphID)
        #expect(OpeningRound.configuration(attempt: 1).mode == .probe)
    }

    @Test("the generator is bypassed: a full novelty ring changes nothing")
    func generatorIsBypassed() {
        let key = LawTable(OpeningRound.law).extensionHash
        let saturated = Set<UInt64>([key])
        #expect(OpeningRound.configuration(attempt: 1, avoiding: saturated).law == OpeningRound.law)
    }

    @Test("the Dial preset is the seed glyph, under the normal retains-the-last-probe rule (§6.3)")
    func dialPresetIsTheSeedGlyph() {
        let configuration = OpeningRound.configuration(attempt: 1)
        #expect(configuration.dialPreset == Deck.glyph(id: configuration.seedGlyphID))
    }

    @Test("a re-run is a different band-1 law of the same shape, still admitting its seed glyph",
          arguments: [2, 3])
    func reRunKeepsTheShape(_ attempt: Int) {
        let first = OpeningRound.configuration(attempt: 1)
        let rerun = OpeningRound.configuration(attempt: attempt)

        #expect(rerun.law != first.law)
        #expect(rerun.band == .literal)
        #expect(rerun.mode == .probe)
        #expect(OpeningRound.isSingleValueMembership(rerun.law))
        let law = Law(rerun.law)
        let seed = Deck.glyph(id: rerun.seedGlyphID)
        #expect(law.admits(seed, after: seed))
        #expect(isApproximatelyEqual(law.admitRate, 0.250, absoluteTolerance: 1e-9))
    }

    @Test("re-runs are deterministic and distinct from each other")
    func reRunsAreDeterministicAndDistinct() {
        #expect(OpeningRound.configuration(attempt: 2) == OpeningRound.configuration(attempt: 2))
        #expect(OpeningRound.configuration(attempt: 2).law != OpeningRound.configuration(attempt: 3).law)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter OpeningRoundTests`

Every failure must be a missing symbol or a wrong *value* — for example a δ that is not 0.023. A δ
mismatch means E06·T01's `difficulty(of:)` disagrees with §5.2's exemplar and that is a real finding, not
a reason to loosen the tolerance.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/OpeningRound.swift` |
| modify | `Modules/Sources/HunchAppFeature/AppLaunchRoute.swift` — `.round(.opening)` resolves to `OpeningRound.configuration(attempt:)` |
| modify | `Modules/Tests/HunchAppFeatureTests/ProbeSnapshotFixture.swift` — replace the literal opening law with `OpeningRound.law` |
| create | `HunchCore/Tests/RoundsTests/OpeningRoundTests.swift` |
| modify | `tests.json` — three entries (exemplar identity, generator bypassed, re-run shape) |

## Implementation notes

### The namespace

```swift
/// §12.5's fixed opening round. The one place in the app where a law is chosen without the generator,
/// the serving policy or `avoid` — deliberately, because the first round must be identical for every
/// player on every device forever.
public enum OpeningRound {
    public static let seed: UInt64 = 0x48554E4348          // "HUNCH"
    public static let band: Band = .literal
    public static let seedGlyphID: UInt8 = 22
    public static let law: LawNode = …                      // shape ∈ {triangle}, already in RNF

    public struct Configuration: Equatable, Sendable {
        public let mode: Mode
        public let band: Band
        public let seed: UInt64
        public let law: LawNode
        public let seedGlyphID: UInt8
        public var dialPreset: Glyph { Deck.glyph(id: seedGlyphID) }
    }

    /// - Complexity: O(1). `avoiding:` is accepted and ignored, which is the point.
    public static func configuration(attempt: Int, avoiding: Set<UInt64> = []) -> Configuration

    public static func isSingleValueMembership(_ node: LawNode) -> Bool
}
```

`avoiding:` is present in the signature and **ignored**. That is not sloppiness: the call site in
`AppLaunchRoute` and, later, E11's serving layer, both want to pass what they always pass, and a
parameter that is visibly discarded with a comment is far harder to misread than an overload that quietly
does not take one. The `generatorIsBypassed` test is what keeps it honest.

### Why the law is a literal `LawNode` and not `generate(...)`

§12.5 says "generator bypassed" and §5.3's generator is pure over five arguments — including `avoid`,
which moves. If the opening law were generated, then a player who suspends the opening round, plays
something else, and resumes could legitimately get a different law (§6.10's whole argument for storing
the resolved node). Write the AST by hand, assert it is its own RNF, and let `LawTable` resolve it.

### The re-run family

§12.5 constrains the re-run to `attr ∈ {single value}` at band 1 with an admitted seed glyph. There are
exactly 16 such laws (4 attributes × 4 values), every one of them `p = 0.250` with deficit 0 — the whole
family is the band-1 exemplar shape. So:

- enumerate the 16 deterministically in canonical attribute order (`fill → shape → pips → hue`, then value
  rank), which needs no RNG at all;
- `configuration(attempt:)` picks index `(attempt − 1) mod 16`, so attempt 1 is `shape ∈ {triangle}` by
  construction and attempts 2 and 3 are distinct from it and from each other;
- the seed glyph is the **lowest `glyphID` the law admits**, which for attempt 1 must come out as 22 —
  assert that rather than special-casing it, because if the enumeration order ever changes the test
  fails instead of the tutorial.

> Check that last claim while implementing: if the lowest admitted `glyphID` for `shape ∈ {triangle}` is
> not 22, do **not** bend the enumeration — keep attempt 1's seed glyph as the stated constant 22 and
> derive only the re-runs' seed glyphs. §12.5 fixes 22 explicitly and that constant wins.

### Three failed openings

After three failed opening rounds the ledger stops re-arming and the player is in band 1 like anyone else
(§12.5). `OpeningRound` exposes the *configurations*; the counting and the stop rule are T07's, because
they live in `OnboardingLedger` inside `ladder.json`.

### Arming order

Band 1 needs no G4 exclusion set (§14.5 decision 4), so the opening round may arm before
`lowerBandIndex.bin` has finished building in the background. Write that as a comment at the arming call
site with the citation — it is the reason first launch has no visible hitch, and somebody will later
"fix" it by awaiting the index if the reason is not written down.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter OpeningRoundTests` green, all ten tests.
- [ ] `grep -rn "0x48554E4348\|48554E4348" HunchCore/Sources Modules/Sources App` returns exactly one file: `OpeningRound.swift`.
- [ ] `grep -rn "generate(" HunchCore/Sources/Rounds/OpeningRound.swift` returns nothing.
- [ ] `grep -rn "= 7\b\|= 12\b" HunchCore/Sources/Rounds/OpeningRound.swift` returns nothing — par and cap come from `Band`.
- [ ] The `ProbeSnapshotFixture` in `Modules/Tests` now references `OpeningRound.law`, so only one spelling of the opening law exists in the repo.
- [ ] `tests.json` carries the three entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T05: the fixed opening round and its re-run family"`

## Out of scope

- The beat script that reveals the surface around this round — **T06**.
- The ledger that measures whether it worked, and the elastic cap — **T07**.
- Cold-start calibration, which begins *after* the opening round — **E11·T05**.
- The Dial's retains-the-last-probe behaviour and its geometry — **E08·T04**.
- The palette holding exactly one stamp at band 2 — **E09·T04** owns the ceiling rule; T06 only asserts what beat 8 shows.
- The daily Anomaly, which is also generator-driven but from a date — **E16·T01**.
