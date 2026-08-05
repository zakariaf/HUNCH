# T09 — The 10,000-law suite

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | §14.1 10,000-law suite |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-testing` | This suite **is** the `T21` deviation the skill documents, and the skill states its exact terms: parameterise over `Band.allCases`, loop `Corpora.lawsPerBand` inside, and pay `T21`'s protection back with a reproducing seed in the message and an `Attachment` of the offending AST. It also owns the promotion rule — every failure becomes a permanent `knownBadSeeds` case — and the ten-second budget this suite spends 12 % of. |

## Objective

Eighty thousand laws — ten thousand per band — are generated and checked against every guardrail in
about 1.2 seconds, with each failure naming the one seed that reproduces it and attaching the AST
that caused it. The generator's fallback rate is measured over the same corpus and asserted under
2 % per band.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.3 | The ten guardrails the suite checks, and the 2 % fallback budget as a monitored test statistic |
| `GAME_DESIGN.md` | §5.7 | "10,000-law suite, all 8 bands ≈ 1.2 s (budget: `swift test` < 10 s)" |
| `GAME_DESIGN.md` | §14.1 | The suite's own inventory row: satisfiable, falsifiable, non-degenerate, structurally distinct, constructible |
| `ios-swift-guide/06-TESTING.md` | T18a, T21, T22, T23, T53, T58 | Attachments, the loop ban, the Cartesian trap, `Codable` parameterised arguments, promotion, never deleting a slow test |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5, §7.4 | The T21 deviation as ruled for HUNCH, with the exact sketch this suite is built from |

## TDD — the test comes first

This task is a test. "Watch it fail" here means watching it fail **for a real reason** at least
once: before writing the suite, plant a deliberate defect — flip G3's window to `[0.05, 0.60]` in a
local edit — run the suite, confirm it names a band, a seed and an attachment, then revert. A corpus
suite that has never been seen to fail is a corpus suite nobody knows the failure message of.

**Step 1 — write the suite.** Create
`HunchCore/Tests/LawGenerationTests/GeneratorTests.swift` — the home
`hunch-swift-testing` gives brief invariant #1:

```swift
import Foundation                     // Attachment's Attachable conformance for Encodable
import Testing
import Glyphs
import Laws
import Bench
import LawGeneration
import HunchTestSupport

@Suite("Generator guardrails over the corpus", .tags(.unit, .presubmission))
struct GeneratorTests {

    /// The deliberate `T21` deviation (`08 §5`, `08 §7.4`): eight parameterised cases, ten thousand
    /// laws looped inside each. Parameterising the inner axis would mean 80,000 runner nodes, which
    /// costs more in overhead than every assertion in this file costs to evaluate.
    @Test("Every guardrail holds across the band", arguments: Band.allCases)
    func guardrailsHold(_ band: Band) throws {
        for index in 0..<Corpora.lawsPerBand {
            let seed = Corpora.seed(band: band, index: index)
            let target = Corpora.targetDelta(band: band, index: index)
            let report = generateReporting(seed: seed, band: band, targetDelta: target,
                                           mode: .probe, avoid: [], in: Corpora.index)
            let node = report.law
            let law = Law(node)
            let context = GuardrailContext(
                band: band, targetDelta: target, avoid: [], index: Corpora.index,
                exemptions: report.usedAnchor ? [.proximity, .novelty] : [])

            let failure: String? =
                if Band(classifying: node) != band { "wrong family: \(Band(classifying: node))" }
                else if node.renderedNormalForm != node { "not in RNF" }
                else if let g = firstFailure(for: law, in: context) { "guardrail \(g)" }
                else if !node.satisfiesStructuralCaps { "structural cap violated" }
                else { nil }

            guard let failure else { continue }
            Attachment.record(node, named: "band\(band.rawValue)-index\(index).json")   // 06 T18a
            Issue.record("""
                \(failure) — reproduce with \
                Corpora.seed(band: .\(band), index: \(index)) = 0x\(String(seed, radix: 16)), \
                targetDelta \(target)
                """)
            return                       // one named seed is enough; promote it, then re-run
        }
    }

    /// §5.3 makes the fallback rate a monitored statistic. Measuring it over the same corpus is
    /// free — `generateReporting` already reports it — and it is the earliest possible warning that
    /// a band's achievable difficulty range and its requested targets have drifted apart.
    @Test("The fallback rate stays under budget in every band", arguments: Band.allCases)
    func fallbackRateIsUnderBudget(_ band: Band) throws {
        var fallbacks = 0
        for index in 0..<Corpora.lawsPerBand {
            let report = generateReporting(seed: Corpora.seed(band: band, index: index),
                                           band: band,
                                           targetDelta: Corpora.targetDelta(band: band, index: index),
                                           mode: .probe, avoid: [], in: Corpora.index)
            if report.usedAnchor { fallbacks += 1 }
        }
        let rate = Double(fallbacks) / Double(Corpora.lawsPerBand)
        #expect(rate < Generation.fallbackRateBudget,
                "band \(band.rawValue): fallback rate \(rate)")
    }

    /// "Structurally distinct" from §14.1's row. Bands 3 and 8 are thin — 108 and 337 laws — so the
    /// expectation is scaled to the band's own population rather than to a flat number.
    @Test("The corpus is structurally diverse for its band", arguments: Band.allCases)
    func corpusIsDiverse(_ band: Band) throws {
        var extensions = Set<UInt64>()
        var skeletons = Set<Skeleton.ID>()
        for index in 0..<Corpora.lawsPerBand {
            let node = generate(seed: Corpora.seed(band: band, index: index), band: band,
                                targetDelta: Corpora.targetDelta(band: band, index: index),
                                mode: .probe, avoid: [], in: Corpora.index)
            extensions.insert(Law(node).table.dedupHash)
            skeletons.insert(Skeleton.identifying(node))
        }
        #expect(skeletons.count == band.skeletons.count)
        #expect(extensions.count >= min(band.population, Corpora.lawsPerBand) / 4)
    }

    @Test("No generated law is a duplicate of the band's anchor more often than the fallback rate",
          arguments: Band.allCases)
    func anchorDoesNotDominate(_ band: Band) throws {
        var anchors = 0
        for index in 0..<Corpora.lawsPerBand {
            let node = generate(seed: Corpora.seed(band: band, index: index), band: band,
                                targetDelta: Corpora.targetDelta(band: band, index: index),
                                mode: .probe, avoid: [], in: Corpora.index)
            if node == band.exemplar { anchors += 1 }
        }
        #expect(Double(anchors) / Double(Corpora.lawsPerBand) < 2 * Generation.fallbackRateBudget)
    }

    /// `06 T53`'s compensation for having no shrinker. Every failure found above is copied in here
    /// and re-runs forever as its own case, with a `Codable` argument so one case runs alone.
    @Test("Known bad seeds stay fixed", arguments: Corpora.knownBadSeeds)
    func knownBadSeedsRegress(_ bad: KnownBadSeed) throws {
        let report = generateReporting(seed: bad.seed, band: bad.band, targetDelta: bad.targetDelta,
                                       mode: bad.mode, avoid: [], in: Corpora.index)
        let context = GuardrailContext(band: bad.band, targetDelta: bad.targetDelta, avoid: [],
                                       index: Corpora.index,
                                       exemptions: report.usedAnchor ? [.proximity, .novelty] : [])
        #expect(firstFailure(for: Law(report.law), in: context) == nil)
        #expect(Band(classifying: report.law) == bad.band)
    }
}
```

**Step 2 — plant the defect and run it.**

```bash
cd /Users/zakariafatahi/50-apps-challenge/E03/HunchCore
# temporarily widen G3's floor in Band.admitWindow, then:
swift test --filter GeneratorTests
git checkout -- Sources/LawGeneration/Band.swift
```

Read the failure. It must name a band, an index, a hex seed and a `targetDelta`, and it must have
written an attachment. If any of those is missing, fix the message before fixing the code.

**Step 3 — implement** whatever is missing: `Corpora.lawsPerBand`,
`Corpora.targetDelta(band:index:)`, `KnownBadSeed`, `Corpora.knownBadSeeds`,
`Generation.fallbackRateBudget`, `LawNode.satisfiesStructuralCaps`.

**Step 4 — green, then measure.**

```bash
cd HunchCore && START=$SECONDS && swift test --filter GeneratorTests && echo "$((SECONDS-START))s"
```

§5.7 budgets ≈1.2 s. Record the actual number in `PROGRESS.md`. If it is materially over, the first
thing to check is that `Corpora.index` is a `static let` built once for the whole suite rather than
per test case — that is the single biggest lever and `08 §5` names it.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/LawGenerationTests/GeneratorTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `lawsPerBand`, `targetDelta(band:index:)`, `knownBadSeeds` |
| create | `HunchCore/Sources/HunchTestSupport/KnownBadSeed.swift` — a `Codable, Sendable, CustomTestStringConvertible` argument type |
| modify | `HunchCore/Sources/LawGeneration/Generator.swift` — `Generation.fallbackRateBudget` |
| modify | `HunchCore/Sources/Laws/LawNode.swift` — `satisfiesStructuralCaps` |
| modify | `PROGRESS.md` — the measured duration and the eight measured fallback rates |
| modify | `tests.json` — one entry for the 10,000-law suite, one for the fallback statistic |

## Implementation notes

### `Corpora.seed(band:index:)` and `Corpora.targetDelta(band:index:)`

`seed` came from E01·T04 and is reproducible from `(band, index)` alone — that is what makes the
failure message actionable. `targetDelta` is new here and it matters more than it looks:

```swift
/// Spreads the requested difficulty across the band's *achievable* range rather than pinning every
/// request to the centre. A suite that only ever asks for the centre never exercises G8's proximity
/// clause at the edges, which is precisely where the fallback rate lives.
public static func targetDelta(band: Band, index: Int) -> Double
```

Sweep it deterministically — for example `lowerBound + (upperBound − lowerBound) · Double(index % 97) / 96`
— so the corpus covers the whole achievable interval and the fallback statistic means something.
`hunch-swift-testing`'s sketch uses `band.centre` for brevity; this is the generalisation, and the
epic notes it as a deliberate difference from the illustrative snippet.

### Why the loop is in the test and not the arguments

`06 T21` says a `for` loop inside a test is a bug, and `08 §7.4` rules that HUNCH breaks it exactly
here. The reasoning is worth carrying: `arguments: Band.allCases, 0..<10_000` is `06 T22`'s
Cartesian product at 80,000 nodes, and the Swift Testing runner's per-node overhead then dominates a
suite whose per-law work is a handful of word operations and one round-trip. The protection `T21`
offers — knowing *which* input failed — is bought back in full by the seed in the message and the
`Attachment` of the AST.

Two rules follow and both are load-bearing:

1. **`return` on the first failure, do not `continue`.** One named seed is enough. A suite that
   records 4,000 issues is a suite nobody reads, and the second failure is usually the first one
   again.
2. **`Attachment.record` needs `import Foundation` in this file.** The `Attachable` conformance for
   `Encodable` comes from Foundation; without it the call does not compile and the tempting fix is
   `print`, which loses the artefact on CI. `hunch-swift-testing` calls this out by name.

### Promotion is the whole point

When this suite fails, the workflow is fixed:

1. Read the seed and band from the message; download the attachment from the CI run.
2. Add a `KnownBadSeed(seed:band:targetDelta:mode:)` to `Corpora.knownBadSeeds`.
3. Run `swift test --filter knownBadSeedsRegress` — it fails.
4. Fix the generator or the guardrail.
5. Both tests go green; the promoted case stays forever.

Skipping step 2 turns a found bug into a bug you will find again with a different seed next month.
`KnownBadSeed` is `Codable` and `CustomTestStringConvertible` so that one case can be re-run alone
from Xcode's test navigator (`06 T23`).

### What "structurally distinct" means here

§14.1's row says "structurally distinct" without a threshold, so the suite states one:

- **every skeleton in the band's list appears** — a skeleton that never surfaces is a skeleton
  weight bug, and the inverse-cardinality weighting exists precisely to prevent it;
- **distinct extensions ≥ a quarter of `min(population, lawsPerBand)`** — scaled, because band 3
  holds 108 laws and band 8 holds 337, so ten thousand draws *must* repeat there, and a flat
  threshold would either be vacuous at band 7 or impossible at band 3.

Both are diversity floors, not distribution tests. The real distribution claims (H10's ρ, H19's
fallback rate under the serving policy) belong to E11's harnesses.

### The fallback statistic is measured twice, on purpose

This task asserts it over a corpus of uniformly swept `targetδ`; E11·T12's H19 asserts it again over
the targets the *serving policy* actually produces. Two different samples, one threshold. If they
disagree, the serving policy is asking for difficulties the band cannot supply — which is exactly
the failure T02's `achievableDifficultyRange` ruling exists to make visible.

### Budget discipline

This suite plus T04's fuzzer are the two largest items in the fast loop. If the total run creeps
over 10 s, the sanctioned moves in order are: confirm `Corpora.index` is built once; move the
fuzzer to nightly (T04 already anticipates this); and only then consider gating the `corpusIsDiverse`
and `anchorDoesNotDominate` passes to nightly, since each re-generates the whole corpus. **Never**
reduce `Corpora.lawsPerBand` — the brief's invariant is ten thousand laws per band.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GeneratorTests` is green.
- [ ] The suite is parameterised over `Band.allCases` with `Corpora.lawsPerBand` looped inside — no
      Cartesian `arguments:` pair anywhere in the file.
- [ ] A deliberately planted defect produces a message naming the band, the index, the hex seed and
      the `targetDelta`, plus an attached AST — verified once by hand and noted in `PROGRESS.md`.
- [ ] Every one of the 80,000 laws is in its requested band, in RNF, satisfies §3.4's structural
      caps, and clears `firstFailure(for:in:)`.
- [ ] The measured fallback rate is under `Generation.fallbackRateBudget` in all eight bands, and the
      eight measured values are recorded in `PROGRESS.md`.
- [ ] Every skeleton of every band appears at least once in the corpus.
- [ ] `Corpora.knownBadSeeds` exists with a `Codable` argument type and is wired to a passing
      parameterised regression test even while empty.
- [ ] The suite's measured duration is recorded in `PROGRESS.md` and the whole fast suite is under
      10 s.
- [ ] `tests.json` has a 10,000-law suite entry and a fallback-rate entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T09: the 10,000-law × 8-band guardrail suite with seed-naming failures"`

## Out of scope

- Determinism, in or across processes — **T10**.
- The Bench fuzzer's 200,000 configurations — **T04**.
- H1–H21, the Level A `ResponseHarness` and the Level B `ReasonerHarness` — **E11·T10–T12**.
- Re-deriving §5.4's `k` and `d` empirically if the harness disagrees by more than 20 % — **E11·T12**.
- Anything about *which* band a player is served — **E11·T03**.
