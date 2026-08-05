# T10 — Determinism, in-process and cross-process

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | §14.1 Determinism |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns brief invariant #4 and rules that cross-process determinism is proved by a **committed golden fixture** written by a separate `swift run` tool, not by re-running in a child process — the exit test is the cheap second opinion. It also owns the `.copy("Fixtures")`/`subdirectory:` trap that kills fixture suites, the ban on asserting a golden *order* out of an RNG anywhere else, and `06 T49`'s exit-test mechanics. |

## Objective

`generate` is proved byte-identical twice over: generated twice in one process, and against 512
tuples whose answers were written to disk by a **different process on a different day**. The tool
that writes them ships in the repository so the golden can be regenerated deliberately and never
accidentally.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.3 | The purity decision, and the brief's requirement that the same `(seed, mode, difficulty)` produce a byte-identical puzzle across runs *and across processes* |
| `GAME_DESIGN.md` | §5.7 | "Generator purity — determinism asserted at `avoid: []`" |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | The two-test structure, the golden's exact path, and why the golden is stronger than a child-process re-run |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §7.9 | `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])` is the hand-rolled substitute for the banned snapshot library |
| `ios-swift-guide/06-TESTING.md` | T42, T49, T54 | Never assert an RNG order except where identity is the property; exit-test mechanics and their `Sendable`+`Codable` capture rule; the fixture `subdirectory:` trap |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P20 | Why the tool target must be absent from `products:` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LawGenerationTests/DeterminismTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Determinism", .tags(.unit, .presubmission))
struct DeterminismTests {

    // MARK: in-process

    @Test("Generating twice in one process gives bit-identical tables", arguments: Band.allCases)
    func sameProcessIsBitIdentical(_ band: Band) throws {
        for index in 0..<512 {
            let seed = Corpora.seed(band: band, index: index)
            let target = Corpora.targetDelta(band: band, index: index)
            let first = generate(seed: seed, band: band, targetDelta: target,
                                 mode: .probe, avoid: [], in: Corpora.index)
            let second = generate(seed: seed, band: band, targetDelta: target,
                                  mode: .probe, avoid: [], in: Corpora.index)
            #expect(first == second)
            #expect(Law(first).table.words == Law(second).table.words)
        }
    }

    @Test("Interleaving other generations does not perturb a result")
    func generationIsNotOrderDependent() throws {
        let seed = Corpora.seed(band: .contextual, index: 7)
        let target = Corpora.targetDelta(band: .contextual, index: 7)
        let alone = generate(seed: seed, band: .contextual, targetDelta: target,
                             mode: .probe, avoid: [], in: Corpora.index)
        for band in Band.allCases {
            _ = generate(seed: 0xDEADBEEF, band: band, targetDelta: band.centre,
                         mode: .drift, avoid: [], in: Corpora.index)
        }
        let after = generate(seed: seed, band: .contextual, targetDelta: target,
                             mode: .probe, avoid: [], in: Corpora.index)
        #expect(alone == after)
    }

    @Test("The encoded AST is stable, not merely equal")
    func encodedFormIsStable() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for band in Band.allCases {
            let node = generate(seed: Corpora.seed(band: band, index: 0), band: band,
                                targetDelta: band.centre, mode: .probe, avoid: [],
                                in: Corpora.index)
            #expect(try encoder.encode(node) == encoder.encode(node))
            let decoded = try JSONDecoder().decode(LawNode.self, from: encoder.encode(node))
            #expect(decoded == node)
        }
    }

    // MARK: cross-process — the committed golden

    /// `08 §5`: every run compares against bytes written by a *different process on a different
    /// day*, which is the actual claim the brief makes and is strictly stronger than re-running in
    /// a child process.
    @Test("Every golden tuple still resolves to its recorded lawKey")
    func goldenFixtureStillHolds() throws {
        let golden = try DeterminismGolden.loadFixture()          // passes subdirectory: "Fixtures"
        #expect(golden.entries.count == 512)
        #expect(golden.indexChecksum == Corpora.index.checksum,
                "the law index changed; regenerate the golden deliberately, do not edit it")

        for entry in golden.entries {
            let node = generate(seed: entry.seed, band: entry.band, targetDelta: entry.targetDelta,
                                mode: entry.mode, avoid: [], in: Corpora.index)
            let key = Law(node).table.dedupHash
            #expect(key == entry.lawKey,
                    "seed 0x\(String(entry.seed, radix: 16)) band \(entry.band.rawValue) "
                    + "mode \(entry.mode) target \(entry.targetDelta): "
                    + "expected 0x\(String(entry.lawKey, radix: 16)), got 0x\(String(key, radix: 16))")
        }
    }

    @Test("The golden covers every band and every mode")
    func goldenCoverageIsComplete() throws {
        let golden = try DeterminismGolden.loadFixture()
        #expect(Set(golden.entries.map(\.band)) == Set(Band.allCases))
        #expect(Set(golden.entries.map(\.mode)) == Set(Mode.allCases))
        #expect(Set(golden.entries.map(\.seed)).count == golden.entries.count)   // no repeated seeds
    }

    @Test("Regenerating the golden in this process reproduces the committed bytes exactly")
    func regenerationIsByteIdentical() throws {
        let committed = try DeterminismGolden.fixtureData()
        let regenerated = try DeterminismGolden.encode(DeterminismGolden.makeEntries(in: Corpora.index),
                                                       indexChecksum: Corpora.index.checksum)
        #expect(committed == regenerated)
    }

    // MARK: the cheap second opinion

    /// `06 T49`: exit tests spawn a real child process and are macOS-only — which HunchCore is
    /// host-testable on, and that is `06 T3`'s argument made concrete. Captured values must be both
    /// `Sendable` and `Codable`.
    @Test("A child process resolves the same law", .enabled(if: ExitTest.isSupported))
    func childProcessAgrees() async throws {
        let sample = try DeterminismGolden.loadFixture().entries[0]
        await #expect(processExitsWith: .success) { [sample] in
            let node = generate(seed: sample.seed, band: sample.band,
                                targetDelta: sample.targetDelta, mode: sample.mode,
                                avoid: [], in: LawIndex.canonical())
            precondition(Law(node).table.dedupHash == sample.lawKey)
        }
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter DeterminismTests` — the golden does not exist yet, so
`loadFixture()` fails. That is the right failure.

**Step 3 — implement**, in this order, and **as two commits**:

```bash
# commit 1 — the tool and the fixture it writes
swift run --package-path HunchCore DeterminismGolden \
    --out HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json
git add HunchCore/Sources/DeterminismGolden HunchCore/Tests/LawGenerationTests/Fixtures
git commit -m "E06/T10: the determinism golden tool and the v1 fixture it produced"

# commit 2 — the test that reads it
git add HunchCore/Tests/LawGenerationTests/DeterminismTests.swift
git commit -m "E06/T10: determinism asserted in-process and against the committed golden"
```

Two commits, not one, and in that order. The claim is "bytes written by a different process"; making
the fixture's commit strictly older than the test's commit is how a reviewer can see that the
fixture was not produced by the test run that validated it. The epic gate checks exactly this with
`git log`.

**Step 4 — green, then refactor.** Then delete nothing: the tool stays in the repository forever,
because the fixture is only regenerable deliberately if the thing that generates it still exists.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/DeterminismGolden/main.swift` — the `swift run` tool |
| create | `HunchCore/Sources/DeterminismGolden/GoldenFixture.swift` — the `Codable` fixture shape, shared by the tool and the test |
| create | `HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json` — committed, 512 entries |
| create | `HunchCore/Tests/LawGenerationTests/DeterminismTests.swift` |
| modify | `HunchCore/Package.swift` — an `.executableTarget` for the tool, **absent from `products:`**; `resources: [.copy("Fixtures")]` on `LawGenerationTests` |
| modify | `HunchCore/Sources/Laws/LawIndex.swift` — `checksum` and `canonical()` |
| modify | `Scripts/check-source-hygiene.sh` — extend check 4 so the tool target is asserted absent from `products:` alongside `HunchTestSupport` |
| modify | `tests.json` — one entry for Determinism |

## Implementation notes

### The fixture

```json
{
  "schema": 1,
  "indexChecksum": "0x…",
  "entries": [
    { "seed": "0x…", "band": 5, "targetDelta": 0.5312, "mode": "probe", "lawKey": "0x…" }
  ]
}
```

Encoded with `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])` — `08 §7.9`'s
hand-rolled replacement for the banned snapshot library, and the reason
`regenerationIsByteIdentical` can compare raw `Data` rather than decoded values. `UInt64`s are
written as hex strings, not as JSON numbers: a `UInt64` above 2⁵³ does not survive a round trip
through a JSON number in every decoder, and this fixture must be readable by tools that are not
Swift.

**512 tuples**, spread as 64 per band across all four modes and across each band's achievable
`targetδ` range, with no repeated seed. The spread matters: a golden that only samples band 1 proves
determinism for band 1.

`indexChecksum` is what makes the fixture honest. G4 consults the `LawIndex`, so a changed index can
legitimately change a generated law. Without the checksum a stale golden fails with 400
indistinguishable mismatches and someone "fixes" it by regenerating; with it the failure says *the
index changed* in one line, and regenerating becomes a decision rather than a reflex.

### `lawKey`

The 64-bit extension dedup hash from E05·T05 — `Law(node).table.dedupHash`. Not the AST, not the
JSON of the node, not a string of the RNF spelling. Two reasons: the extension is the canonical
form (§3.6), so keying on it means the fixture survives a purely cosmetic change to `LawNode`'s
`Codable` representation; and it is exactly what E11's `avoid` set is keyed on, so a golden mismatch
and a novelty-guard mismatch mean the same thing.

### The tool

An `.executableTarget` in `HunchCore/Package.swift` named `DeterminismGolden`, depending on
`Laws`, `LawGeneration` and `Glyphs`. It must be **absent from `products:`** for the same reason
`HunchTestSupport` is (`01 P20`, `06 T5a`): nothing outside this package may name it, and it must
never reach an app binary. Extend `Scripts/check-source-hygiene.sh` check 4 rather than trusting
review.

Its interface is deliberately awkward to run by accident:

```
swift run DeterminismGolden --out <path>          # writes the fixture
swift run DeterminismGolden --verify <path>       # exits non-zero on any mismatch, writes nothing
```

No default output path, no `--force`, no writing to a path that already exists without `--replace`.
Regenerating this fixture is the one operation in the repository that can silently erase the
evidence for a shipped invariant.

### The exit test

`06 T49`: exit tests are macOS/Linux only and iOS has none, which is why `08 §7.10`'s host-testable
package is what makes them available at all. Three mechanics that bite:

1. **Captured values must be both `Sendable` and `Codable`** — they are encoded, piped and decoded
   into the child. A `GoldenEntry` already is both.
2. **Capture lists only work on Swift 6.3+**; below that the macro captures nothing, silently. Pin
   the guard on `ExitTest.isSupported` and verify the child actually fails when you break it on
   purpose, once, before trusting it.
3. **The child re-builds the index**, so the test calls `LawIndex.canonical()` rather than capturing
   `Corpora.index` — a 305 KB index is not something to pipe through a process boundary.

The exit test is the *cheap second opinion*, not the proof. If it is flaky or unavailable on the CI
image, gate it and keep the golden; if the golden is failing, the exit test's opinion is irrelevant.

### The `subdirectory:` trap

`resources: [.copy("Fixtures")]` preserves the directory, so **every** lookup passes
`subdirectory: "Fixtures"`:

```swift
guard let url = Bundle.module.url(forResource: "determinism-seeds-v1", withExtension: "json",
                                  subdirectory: "Fixtures") else { … }
```

A bare lookup returns `nil` and every `#require` in the suite fails at once. `hunch-swift-testing`
calls this the place fixture suites die, and E07·T05 will hit the same trap with the persistence
tree — solving it once here, in `DeterminismGolden.loadFixture()`, gives that task a working
example.

### What determinism does *not* cover

§5.3 is explicit that seed choice, `avoid` assembly and retry-with-a-fresh-seed live in the serving
layer, are tested separately, and are **not** stable across sessions — that is the point of them.
The golden therefore always passes `avoid: []`, exactly as §5.7's row states. A determinism test
that pinned the serving layer would be asserting the opposite of the design.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DeterminismTests` is green.
- [ ] `HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json` is committed, holds
      512 entries, covers all eight bands and all four modes, and repeats no seed.
- [ ] The fixture's commit is strictly earlier than the test file's commit —
      `git log --format='%h %ad %s' -- HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json`
      and the same for `DeterminismTests.swift`.
- [ ] `swift run --package-path HunchCore DeterminismGolden --verify <path>` exits zero.
- [ ] Regenerating the fixture in-process reproduces the committed bytes exactly.
- [ ] `indexChecksum` is recorded in the fixture and asserted against `Corpora.index.checksum`.
- [ ] The tool target is absent from `products:` and `Scripts/check-source-hygiene.sh` asserts it.
- [ ] The macOS exit test runs and passes, or is explicitly gated with a recorded reason.
- [ ] All `UInt64`s in the fixture are hex strings, not JSON numbers.
- [ ] `tests.json` has a Determinism entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: two commits, as above — the tool and fixture first, then the test.

## Out of scope

- The 10,000-law guardrail corpus — **T09**.
- `SeedSource`, the one nondeterministic thing in the app — **E10·T01**.
- The serving layer's seed choice and `avoid` assembly, which are deliberately *not* stable across
  sessions — **E11·T06**.
- The Anomaly's cross-device determinism (two devices, same UTC date, identical law), which is a
  different claim proved from `utcDayIndex` through `generate` — **E16·T01**.
- Persistence fixtures and the `Fixtures/v1/` tree — **E07·T05**.
