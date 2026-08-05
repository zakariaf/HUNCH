# T07 — The Restraint margin

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | Restraint margin (PROFILE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The count runs against `LawIndex`, which is loaded by an `actor` (`08 §4`'s `LawIndexLoader`) while the count itself must be synchronous inside the declaration path. This skill's state-ownership and boundary sections are what decide that the *counting function* is a pure `nonisolated` function over an already-loaded immutable index, and that the `await` happens once at arm time, not at declaration time. |

## Objective

At the end of this task Restraint's margin term is real: `H_live` is the number of laws in the band's
materialised set still consistent with the whole ribbon at the moment of declaration, counted with a
four-word bitboard compare per candidate, drawn from the lower-band index's band slice, skipped at
bands 5 and 7 where no materialised stateless set exists, and costing about 50 µs at band 4 once per
declaration.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.9 | `m = clamp(1 − log₂(H_live)/log₂(\|H_band\|), 0, 1)`; `H_live` = laws in the band's set still consistent with the whole ribbon at declaration; the bands-5-and-7 skip and its reason; the cost figure — 2,322 tables × a 4-word compare ≈ 50 µs at band 4, **once per declaration** |
| `GAME_DESIGN.md` | §3.6 | the lower-band index: 9,767 stateless tables, band-partitioned, and the 17,248 contextual hashes that are *not* tables and therefore cannot be filtered |
| `GAME_DESIGN.md` | §5.7 | the band partition 40 / 1,272 / 108 / 2,322 / 5,688 / 337 — bands 1, 2, 3, 4, 6 and 8, in that order, behind a six-entry offset header |
| `GAME_DESIGN.md` | §5.2 | `\|H_band\|` for all eight bands — the denominator |
| `GAME_DESIGN.md` | §3.5 | the evaluator's `prev` rule: `prev` is the previously **probed** glyph regardless of verdict, and the seed glyph primes position 0 |
| `GAME_DESIGN.md` | §14.5 open decision 4 | the index is built once in the background with a 3 s A15 budget — which is why the `await` is at arm time |
| `ios-swift-guide/05-CONCURRENCY.md` | R30 | cache the `Task`, not the value — `LawIndexLoader`'s shape, already built in E05·T07 |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/ArchiveTests/RestraintMarginTests.swift`:

```swift
import Foundation
import Testing
import Archive
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("The Restraint margin — §11.9's H_live", .tags(.unit, .presubmission))
struct RestraintMarginTests {

    private let index = Corpora.index          // the one static let, built once for the suite

    private func ribbon(_ pairs: [(Int, Verdict)]) -> ObservedRibbon {
        ObservedRibbon(probes: pairs.map { (Deck.glyph(id: $0.0), $0.1) })
    }

    // MARK: - the count

    @Test("with no probes, every law in the band is still live")
    func emptyRibbonLeavesTheWholeBand() throws {
        for band in [Band.literal, .pair, .exclusive, .relational, .guarded, .systemic] {
            #expect(LiveHypotheses.count(band: band, ribbon: ribbon([]), in: index)
                    == band.population)
        }
    }

    @Test("the count is monotonically non-increasing as probes accumulate")
    func countNeverGrows() throws {
        let law = generate(seed: Corpora.seed(band: .relational, index: 7),
                           band: .relational, targetDelta: Band.relational.centre, mode: .probe)
        let table = LawTable(law)
        var probes: [(Glyph, Verdict)] = []
        var previous = Band.relational.population
        for id in stride(from: 0, to: 96, by: 7) {
            let g = Deck.glyph(id: id)
            probes.append((g, table.admits(g) ? .admit : .reject))
            let live = LiveHypotheses.count(band: .relational,
                                            ribbon: ObservedRibbon(probes: probes), in: index)
            #expect(live <= previous)
            previous = live
        }
        #expect(previous < Band.relational.population)      // it actually narrowed
    }

    @Test("the true law is always still live, at every prefix of its own transcript")
    func theTrueLawSurvives() throws {
        let law = generate(seed: Corpora.seed(band: .guarded, index: 3),
                           band: .guarded, targetDelta: Band.guarded.centre, mode: .probe)
        let table = LawTable(law)
        var probes: [(Glyph, Verdict)] = []
        for id in stride(from: 3, to: 200, by: 11) {
            let g = Deck.glyph(id: id)
            probes.append((g, table.admits(g) ? .admit : .reject))
        }
        #expect(LiveHypotheses.count(band: .guarded,
                                     ribbon: ObservedRibbon(probes: probes), in: index) >= 1)
    }

    @Test("the count agrees with a brute-force filter over the band slice")
    func agreesWithBruteForce() throws {
        let law = generate(seed: Corpora.seed(band: .exclusive, index: 11),
                           band: .exclusive, targetDelta: Band.exclusive.centre, mode: .probe)
        let table = LawTable(law)
        let probes = stride(from: 1, to: 60, by: 4).map { id -> (Glyph, Verdict) in
            let g = Deck.glyph(id: id)
            return (g, table.admits(g) ? .admit : .reject)
        }
        let observed = ObservedRibbon(probes: probes)
        let brute = index.tables(in: .exclusive).count { candidate in
            probes.allSatisfy { candidate.admits($0.0) == ($0.1 == .admit) }
        }
        #expect(LiveHypotheses.count(band: .exclusive, ribbon: observed, in: index) == brute)
    }

    @Test("a repeated glyph never contradicts and never changes the count")
    func repeatsAreFree() throws {
        let probes: [(Int, Verdict)] = [(22, .admit), (30, .reject), (22, .admit), (22, .admit)]
        let deduped: [(Int, Verdict)] = [(22, .admit), (30, .reject)]
        #expect(LiveHypotheses.count(band: .pair, ribbon: ribbon(probes), in: index)
                == LiveHypotheses.count(band: .pair, ribbon: ribbon(deduped), in: index))
    }

    // MARK: - the skip

    @Test("bands 5 and 7 have no materialised set and yield nil",
          arguments: [Band.contextual, .composite])
    func contextualBandsSkip(_ band: Band) {
        #expect(LiveHypotheses.count(band: band, ribbon: ribbon([(22, .admit)]), in: index) == nil)
    }

    @Test("the six materialised bands are exactly the lower-band index's partition")
    func materialisedBandsMatchTheIndex() {
        let materialised = Band.allCases.filter { LiveHypotheses.isMaterialised($0) }
        #expect(materialised == [.literal, .pair, .exclusive, .relational, .guarded, .systemic])
        #expect(materialised.map(\.population).reduce(0, +) == 9_767)      // §5.7
    }

    // MARK: - the margin

    @Test("Restraint falls back to d alone when the count is nil", arguments: [Band.contextual, .composite])
    func restraintUsesDAloneWhereSkipped(_ band: Band) {
        let t = RoundTranscript.probeSolvedClean(band: band, liveHypotheses: nil)
        let s = AxisSampling.samples(for: t).first { $0.axis == .restraint }!
        #expect(isApproximatelyEqual(s.value, 1.00, absoluteTolerance: 1e-12))   // d alone, not 0.6·d
    }

    @Test("the margin rises as the live set narrows")
    func marginRisesAsTheSetNarrows() {
        let wide = Restraint.margin(liveHypotheses: 2_322, band: .relational)
        let narrow = Restraint.margin(liveHypotheses: 8, band: .relational)
        let closed = Restraint.margin(liveHypotheses: 1, band: .relational)
        #expect(wide < narrow)
        #expect(narrow < closed)
        #expect(isApproximatelyEqual(closed, 1.0, absoluteTolerance: 1e-9))
    }

    @Test("H_live of zero is impossible and is guarded rather than logged as −inf")
    func zeroIsGuarded() {
        #expect(Restraint.margin(liveHypotheses: 0, band: .relational).isFinite)
        #expect(isApproximatelyEqual(Restraint.margin(liveHypotheses: 0, band: .relational),
                                     1.0, absoluteTolerance: 1e-9))
    }

    // MARK: - the budget

    @Test("counting band 4 costs under 500 µs — §11.9 budgets ≈50 µs, this is a 10× ceiling",
          .tags(.performance))
    func bandFourIsFast() throws {
        let probes = stride(from: 0, to: 40, by: 3).map { (Deck.glyph(id: $0), Verdict.admit) }
        let observed = ObservedRibbon(probes: probes)
        let start = ContinuousClock.now
        _ = LiveHypotheses.count(band: .relational, ribbon: observed, in: index)
        #expect(ContinuousClock.now - start < .microseconds(500))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter RestraintMarginTests`
Missing symbols (`LiveHypotheses`, `ObservedRibbon`, `LawIndex.tables(in:)`). `agreesWithBruteForce`
is the one that must be watched most carefully: it will pass trivially if `count` returns the brute
force result *by calling the brute force*, so implement the bitboard path and keep the brute force
only inside the test.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/LiveHypotheses.swift` |
| create | `HunchCore/Sources/Archive/ObservedRibbon.swift` |
| create | `HunchCore/Tests/ArchiveTests/RestraintMarginTests.swift` |
| modify | `HunchCore/Sources/Laws/LawIndex.swift` — `tables(in band: Band) -> ArraySlice<LawTable>` reading the six-entry offset header |
| modify | `Modules/Sources/LoomFeature/Round.swift` — hold the loaded `LawIndex` from arm time; count once at the declaration |
| modify | `HunchCore/Sources/Archive/RoundTranscript.swift` — `liveHypotheses` is filled from the count |
| modify | `tests.json` — five entries |

## Implementation notes

### `H_live`, precisely

> laws in the band's set still consistent with the whole ribbon **at the moment of declaration** — §11.9

Three words in that sentence carry the implementation.

- **"the band's set"** — the *served* band's slice of the lower-band index, not the union of bands
  below it. G4's prefix union is a *generation-time* concern; the margin asks how much of the
  hypothesis space the player's own evidence has closed, and that space is the band they were served.
- **"the whole ribbon"** — every probe, from the first, not a suffix and not a window. Repeats are
  free (`repeatsAreFree`), because a stateless law gives one glyph one verdict.
- **"at the moment of declaration"** — once, on the Seal press, before the verdict animation starts.
  Not per probe: per probe would be 20–40 counts a round for a value read once.

### The four-word compare

Build two `Bitboard256`s from the ribbon in one pass, then filter:

```swift
public struct ObservedRibbon: Equatable, Sendable {
    public let admitted: Bitboard256          // glyphs observed admitted
    public let rejected: Bitboard256          // glyphs observed rejected
    public init(probes: [(Glyph, Verdict)])
}

public enum LiveHypotheses {
    public static func isMaterialised(_ band: Band) -> Bool

    /// nil at bands 5 and 7 — §11.9's skip. O(|H_band|), one 4-word compare each.
    public static func count(band: Band, ribbon: ObservedRibbon, in index: LawIndex) -> Int? {
        guard isMaterialised(band) else { return nil }
        return index.tables(in: band).count { table in
            table.bits & ribbon.admitted == ribbon.admitted    // admits everything admitted
                && table.bits & ribbon.rejected == .empty      // rejects everything rejected
        }
    }
}
```

That is the whole algorithm. Two `Bitboard256` ANDs and two comparisons per candidate, which is what
§11.9 prices at ≈50 µs for band 4's 2,322 tables. Do **not** re-evaluate an AST per glyph per
candidate — that is 2,322 × 40 evaluator calls and three orders of magnitude slower.

### Where the `await` goes

`LawIndexLoader` is an `actor` and `index()` is `async` (E05·T07). The count is synchronous and sits
inside the declaration path, which must not suspend — §6.8's 640 ms verdict-blind seal hold starts at
t = 0 and a suspension there is a variable-latency side channel.

So: `Round` `await`s the index **at arm time**, stores the immutable `LawIndex` value, and the count
at declaration is a plain synchronous call. `LawIndex` is an immutable `Sendable` struct precisely so
that it can leave the actor and never be touched again (`08 §4`).

If the index is not yet loaded when the round arms — a cold launch racing the 3 s A15 build (§14.5
open decision 4) — `liveHypotheses` is `nil` for that round and Restraint uses `d` alone. **That is
the same fallback bands 5 and 7 take**, it needs no new code path, and it must never block arming.
Add one test for it in `Round`'s suite: an unloaded index produces a `nil` count and a valid
Restraint sample.

### The bands-5-and-7 skip

The lower-band index holds *tables* for the six stateless bands and only *hashes* for bands 5 and 7
(§3.6, §5.7: 17,248 × 8 B of contextual hashes). A hash cannot be tested for consistency with a
ribbon, so there is nothing to filter. §11.9 rules the term skipped and Restraint uses `d` alone —
**`d`, not `0.6·d`**, because a `0.6·d` would silently make bands 5 and 7 score lower than every other
band on an axis that has nothing to do with the band.

`materialisedBandsMatchTheIndex` asserts the six by summing to 9,767, so the set cannot drift from
§5.7 without failing.

### Why this is P1 and what happens without it

Dropping this task leaves `liveHypotheses` permanently `nil`, Restraint permanently `d` alone, and
every other test in the epic green. That is the whole reason the `Int?` shape is in T05's signature
from the start: the margin is a refinement, not a dependency, and its absence is expressible.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RestraintMarginTests` green, all eleven tests.
- [ ] `agreesWithBruteForce` compares a bitboard implementation against a brute-force filter written only inside the test; `grep -n "allSatisfy" HunchCore/Sources/Archive/LiveHypotheses.swift` returns nothing.
- [ ] `bandFourIsFast` passes on the CI runner with the 500 µs ceiling, and the measured figure is recorded in `DECISIONS.md` beside §11.9's ≈50 µs estimate.
- [ ] `grep -rn "await" Modules/Sources/LoomFeature/Round.swift` shows the index load at arm time and **not** inside the declaration path.
- [ ] `grep -rn "LiveHypotheses.count" Modules/Sources` shows exactly one call site, once per declaration.
- [ ] `tests.json` carries five entries: the count agrees with brute force, it never grows, the true law always survives, bands 5 and 7 skip to `d` alone, and the band-4 budget.
- [ ] The fast suite is still under 10 s — if `RestraintMarginTests` pushes it over, move `bandFourIsFast` and `agreesWithBruteForce` to `.nightly` and say so in `DECISIONS.md`, but never delete them.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes making `count` `async` so it can load the index itself, reject it and point at the seal hold.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T07: the Restraint margin — H_live against the band slice, skipped at bands 5 and 7"`

## Out of scope

- `m`'s formula and `d`'s ladder — **T05**; this task fills the `Int?` they already consume.
- The lower-band index's construction, its offset header and its `.bin` — **E05·T07**.
- `LawIndexLoader` and its `Task` caching — **E05·T07**.
- The declaration verdict, extension identity and two strikes — **E09·T08**.
- The Assay's live slice, which is a *different* consistency question asked of one law rather than of a set — **E09·T05**.
