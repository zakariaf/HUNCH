# T08 — Per-band |H| enumeration test

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | Per-band \|H\| enumeration · Band table |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | This is the epic's gate test and it breaks two of the skill's defaults on purpose. It parameterises over `Band.allCases` but must **not** run in parallel, because band *b*'s G4 exclusion set has to be complete before *b* is counted — and the skill forbids `.serialized` as a flake fix, so the ordering has to come from the shape of the test rather than from a trait. It also owns the rule this task's failure mode depends on: **never weaken or delete an entry to reach green.** 27,015 is a locked constant; the enumeration is what moves. |

## Objective

Eight assertions — one per band — prove that the enumerated law space is exactly §5.2's `|H|` column, and that the eight sum to the permanent ceiling of 27,015. Not one assertion on a 9,767-table blob: when band 6 is wrong, the failure must say "band 6", because the six stateless families have six different skeleton sets and a blob assertion tells you nothing about which one drifted.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.2 | The definition of `\|H\|(b)` in full: it closes over G1–G3, G5–G7, G10 and G8's band-membership clause, plus G4 against **strictly lower bands only**; it deliberately does not close over G4-against-its-own-band (circular), G8's `targetδ` proximity clause (per-request) or G9 (per-player, per-day); "enumeration therefore runs in **ascending band order**, so band `b`'s exclusion set is complete and frozen before band `b` is counted"; and "**enumerated exhaustively over the real 256-glyph deck**, not estimated". |
| `GAME_DESIGN.md` | §5.2 | The three enforced-by-theorem jumps: band 3 is exactly the XOR of two 2-element subsets (108, tolerance-free); band 4's marginal deficit 1.0; band 8's symmetry-not-flatness argument and the COUNT law at deficit 0.286 that proves flatness positions rather than gates. |
| `GAME_DESIGN.md` | §3.6 | "The enumeration is a shipped test that asserts the exact **per-band** counts against the band table of §5 — **six assertions plus two, not one assertion on a 9,767-table blob.**" And: "Total law space: 27,015 distinct laws." |
| `GAME_DESIGN.md` | §3.3 | The class inventories the sub-counts must agree with — 56 / 36 / 96 / 8,736 / 1,214, and the in-window column 40 / 18 / 48 / — / 337, of which **40 is band 1 and 337 is band 8 verbatim** because those two families are exactly their bare class. |
| `GAME_DESIGN.md` | §5.7 | `Band populations \|H\| (1→8) = 40, 1,272, 108, 2,322, 6,934, 5,688, 10,314, 337` and `Total distinct laws = 27,015`. Locked. |
| `GAME_DESIGN.md` | §5.7 "Known limitations" | Bands 3 and 8 are thin — 108 and 337 — and both exceed twice the novelty guard. That is why these two numbers in particular are load-bearing rather than decorative. |
| `ios-swift-guide/06-TESTING.md` | T21, T22, T27 | The loop deviation, the Cartesian trap, and why `.serialized` is not the answer to an ordering requirement. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawGenerationTests/BandPopulationTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

/// The eight counts of §5.2, asserted one band at a time.
///
/// **Ordering is load-bearing, and it is structural rather than a trait.** §5.2 requires
/// ascending band order so band `b`'s G4 exclusion set is complete and frozen before `b` is
/// counted. `Corpora.index` is built once, in ascending order, as a `static let`; every test
/// below reads that finished value, so the tests themselves may run in any order and in
/// parallel. `.serialized` would hide the requirement rather than satisfy it (`06 T27`).
@Suite("Band populations", .tags(.unit, .presubmission))
struct BandPopulationTests {

    // MARK: - Six stateless bands, six assertions

    @Test("Band 1 LITERAL enumerates to 40")
    func literal() {
        // §3.3: the atomic class is 56 forms, 40 of them inside the admit window, and band 1
        // is exactly its bare class — so this number appears twice in the GDD and must agree.
        #expect(Corpora.index.statelessRun(Band.literal.statelessRun!).count == 40)
        #expect(Band.literal.population == 40)
    }

    @Test("Band 2 PAIR enumerates to 1,272")
    func pair() {
        #expect(Corpora.index.statelessRun(Band.pair.statelessRun!).count == 1_272)
    }

    @Test("Band 3 EXCLUSIVE enumerates to 108, and it is a theorem")
    func exclusive() {
        // §5.2: "exactly the XOR of two 2-element subsets on distinct attributes … Exactly 108
        // laws, tolerance-free." 6 attribute pairs × 36 ordered (S₁,S₂) halved by the identity
        // A XOR B = Ā XOR B̄ = 18 per pair × 6.
        #expect(Corpora.index.statelessRun(Band.exclusive.statelessRun!).count == 108)
    }

    @Test("Band 4 RELATIONAL enumerates to 2,322")
    func relational() {
        #expect(Corpora.index.statelessRun(Band.relational.statelessRun!).count == 2_322)
    }

    @Test("Band 6 GUARDED enumerates to 5,688")
    func guarded() {
        #expect(Corpora.index.statelessRun(Band.guarded.statelessRun!).count == 5_688)
    }

    @Test("Band 8 SYSTEMIC enumerates to 337")
    func systemic() {
        // §3.3: the aggregate class is 1,214 forms, 337 distinct extensions in window, and
        // band 8 is exactly its bare class — the second number the GDD states twice.
        #expect(Corpora.index.statelessRun(Band.systemic.statelessRun!).count == 337)
    }

    // MARK: - Two contextual bands, two assertions

    @Test("Band 5 CONTEXTUAL enumerates to 6,934")
    func contextual() {
        #expect(Corpora.index.contextualRun(Band.contextual.contextualRun!).count == 6_934)
    }

    @Test("Band 7 COMPOSITE enumerates to 10,314")
    func composite() {
        #expect(Corpora.index.contextualRun(Band.composite.contextualRun!).count == 10_314)
    }

    // MARK: - The sums, and the properties that make the counts well-founded

    @Test("The stateless six sum to 9,767 and all eight to 27,015")
    func totals() {
        #expect(Corpora.index.statelessCount == 9_767)
        #expect(Corpora.index.contextualCount == 17_248)
        #expect(Corpora.index.statelessCount + Corpora.index.contextualCount == 27_015)
        #expect(Band.allCases.map(\.population).reduce(0, +) == 27_015)
    }

    @Test("Every enumerated band matches its declared population", arguments: Band.allCases)
    func declarationMatchesEnumeration(_ band: Band) {
        let enumerated = if let run = band.statelessRun { Corpora.index.statelessRun(run).count }
                         else { Corpora.index.contextualRun(band.contextualRun!).count }
        #expect(enumerated == band.population)
    }

    @Test("G4 is by strictly lower bands only — the bands are pairwise disjoint")
    func bandsAreDisjoint() {
        // §3.6: comparing a band against itself would reject 100 % of candidates at five of the
        // eight bands and drive the fallback rate to 1.00. Disjointness is the property that
        // makes "strictly lower" both sufficient and necessary.
        var seen = LawSet()
        for run in 0..<LawIndex.statelessRunCount {
            for table in Corpora.index.statelessRun(run) {
                #expect(seen.contains(table) == false)
                seen.insert(table)
            }
        }
        #expect(seen.count == 9_767)
    }

    @Test("Enumeration is exhaustive over the real deck, never sampled", arguments: Band.allCases)
    func exhaustive(_ band: Band) {
        // §5.2: "enumerated exhaustively over the real 256-glyph deck, not estimated."
        // Every survivor is a real table over the real universe, and no candidate was skipped.
        #expect(band.enumeratedTables().count == band.population)
        #expect(band.enumerationWasSampled == false)
    }

    @Test("Every enumerated law satisfies the guardrails |H| closes over",
          arguments: Band.allCases)
    func survivorsSatisfyTheirGuardrails(_ band: Band) throws {
        for (offset, node) in band.enumeratedNodes().enumerated() {
            let law = Law(node)
            let failure: String? =
                if !law.table.isSatisfiable { "G1" }
                else if !law.table.isFalsifiable { "G2" }
                else if !band.admitWindow.contains(law.admitRate) { "G3 p=\(law.admitRate)" }
                else if !law.deadLeaves.isEmpty { "G5" }
                else if !law.hasLiveNamedAttributes { "G6" }
                else if band.isContextual && law.table.isSecretlyStateless { "G7" }
                else { nil }
            guard let failure else { continue }
            Attachment.record(node, named: "band\(band.rawValue)-offset\(offset).json")
            Issue.record("\(failure) failed at band \(band.rawValue) offset \(offset)")
            return
        }
    }

    @Test("§5.2's theorem bands hold their stated marginal properties")
    func theoremBands() {
        // Band 3: every one of the 108 has all sixteen marginals equal to p (deficit 1.0).
        for node in Band.exclusive.enumeratedNodes() {
            expectApproximatelyEqual(Law(node).marginalDeficit, 1.0, absoluteTolerance: 1e-12)
        }
        // Band 4: for every value of every attribute, admitted and rejected glyphs both exist.
        for node in Band.relational.enumeratedNodes() {
            let marginals = LawTable(node).marginals
            #expect(marginals.allSatisfy { $0 > 0 && $0 < 1 })
        }
        // Band 8: flatness POSITIONS rather than gates — a COUNT law with deficit 0.286 is one
        // of the 337, so the band must contain at least one non-flat member.
        let deficits = Band.systemic.enumeratedNodes().map { Law($0).marginalDeficit }
        #expect(deficits.contains { $0 < 0.999 })
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter BandPopulationTests`
Six of the eight should go green quickly once T07's skeletons are right. Bands 5 and 7 will not — see below. Confirm the failure is a **count mismatch printed as two integers**, not a crash and not a timeout.

**Step 3 — implement.** There is no new production type here: T07 built the runs. The work is closing the contextual gap and adding the enumeration introspection (`enumeratedNodes()`, `enumerationWasSampled`) the assertions read.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/LawGenerationTests/BandPopulationTests.swift` |
| modify | `HunchCore/Sources/LawGeneration/Skeleton.swift` — the resolving clause for the contextual form space |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — `enumeratedNodes()`, `enumeratedTables()`, `enumerationWasSampled` |
| modify | `DECISIONS.md` — the contextual-form-space clause, with the evidence |
| modify | `SPEC.md` — the eight counts and the total as locked, with the enumeration predicate written out |
| modify | `PROGRESS.md` — the eight counts as passing output, not as intention |
| modify | `tests.json` — "Per-band \|H\| enumeration" |

## Implementation notes

### The verified reference result

The enumeration below was run against a reference implementation during planning and **reproduces the six stateless counts exactly**. Use it as the ground truth: if your Swift disagrees, your Swift is wrong.

Predicate, applied in this order to each family's exhaustive form space, in ascending band order:

1. `popCount ≥ 1` (G1) and `popCount ≤ N − 1` (G2)
2. `admitRate ∈ [0.15, 0.60]` (G3), over 256 for stateless bands and 65,536 for contextual ones
3. bands 5 and 7 only: `isSecretlyStateless == false` (G7)
4. `deadLeaves.isEmpty` (G5) — ⊤ **and** ⊥ per leaf
5. `hasLiveNamedAttributes` (G6) — permutation applied to the `cur` and `prev` positions **independently**
6. not present in the union of strictly lower bands' *final* sets (G4); contextual bands contribute nothing to a stateless band's exclusion set and vice versa (§3.6, guaranteed by G7)
7. dedup by extension

| Band | Form space | Candidate forms | Survivors | §5.2 |
|---|---|---|---|---|
| 1 | `<atom>` | 56 | **40** | 40 ✓ |
| 2 | two atoms, distinct attributes, any coupler, minus band 3's shape | 2,184 | **1,272** | 1,272 ✓ |
| 3 | `<atom> XOR <atom>`, distinct attributes, both `\|S\| = 2` | 216 | **108** | 108 ✓ |
| 4 | `<rel>` ∪ (`<rel>` × coupler × `<atom>`) | 36 + 6,048 | **2,322** | 2,322 ✓ |
| 6 | `<guard>` | 8,736 | **5,688** | 5,688 ✓ |
| 8 | `COUNT` ∪ `PARITY` | 1,214 | **337** | 337 ✓ |
| | | **stateless total** | **9,767** | 9,767 ✓ |

Three details that the counts are sensitive to, each of which silently changes the answer:

- **Band 2 excludes band 3's shape.** Family membership is exclusive by construction (§5.3, "strictly one family per band"), not by G4 — G4 only looks *downward*, and band 3 is above band 2. If you leave the size-2/size-2 XORs in band 2 you get 1,290 and 90, not 1,272 and 108.
- **The XOR complement identity halves the count.** `A XOR B` and `Ā XOR B̄` are the same extension. Dedup by extension handles it automatically; a dedup by syntax does not.
- **G6's liveness must be dependence, not symmetry.** Permuting an attribute in both positions at once leaves `RANK a(cur) == PREV RANK a` invariant, which would delete the four in-window symmetric contextual forms and, with them, a slice of bands 5 and 7. T05 already ships the correct definition and its trap test.

### The contextual gap — the one open piece of this epic

Under the same predicate and the form space T07 specifies, bands 5 and 7 enumerate to **6,960** and **10,368**, against §5.2's **6,934** and **10,314**. The excess is 26 and 54, total 80 tables out of 17,328.

What has already been ruled out during planning, so you do not spend the day re-running it:

- Both liveness readings (symmetry and positional dependence) give identical counts.
- Both band-5/band-7 splits (`{bare, ctx+atom}` vs `{bare, ctx+atom, ctx+ctx}`) give the same 17,328 union.
- Assigning duplicates to the higher band instead of the lower one moves band 5 to 6,912, further away.
- Treating a Bridge socket as a leaf and applying the ≤ 2-leaves-per-attribute cap overshoots badly (6,624 / 8,712).
- Structural restrictions on the ctx leaf (`a ≠ b`, atom attribute disjoint from the ctx's, dropping a coupler) all overshoot by hundreds.
- Window endpoints are not the cause: no contextual table has `p` exactly 0.15 or 0.60, since neither `0.15 × 65 536` nor `0.60 × 65 536` is an integer.
- No natural table property (transpose symmetry, constant rows, constant columns, distinct-row count, cur-independence) partitions the excess into 26 and 54.

So the missing piece is a clause in the contextual form space or in the predicate that §3.2/§3.3/§5.3 do not spell out. **§5.7 locks 6,934 / 10,314 / 27,015; the counts are the oracle and the enumeration is what moves.** Work it as follows:

1. Dump the 6,960 and 10,368 survivors with their generating skeletons.
2. Take the difference against the two targets by searching for a *semantic* predicate — 26 and 54 are too small and too oddly-sized for a whole-skeleton exclusion, so look for a per-table property that 80 members share.
3. When you find it, write it into `Skeleton.swift` as a named clause with a citation, and record it in `DECISIONS.md` with the evidence and the ruled-out list above.
4. If — after real effort — no clause is found, **do not adjust the constant.** Escalate: open an issue, mark the two contextual assertions `withKnownIssue("contextual form space is 80 tables over §5.2", .bug(id: …))` so the ratchet reports the day they start passing (`06 T35`), keep the six stateless assertions and the 9,767 total hard, and record the open question in `DECISIONS.md`. A `withKnownIssue` that flips to passing tells you; a weakened constant tells you nothing, and §5.7's numbers feed par, cap, `log₂|H|` and the whole ladder.

### Ordering without `.serialized`

The requirement is that the *enumeration* runs in ascending band order, not that the *tests* do. Satisfy it structurally: `Corpora.index` is a `static let` built once by a single ascending loop, and every assertion reads the finished value. Then the suite parallelises freely and the ordering cannot be broken by a test-runner change. Write that as the suite's doc comment — a reviewer will otherwise reach for `.serialized`, which `06 T27` forbids and which would not actually enforce anything here.

### Cost

The enumeration is ~40,000 contextual candidates at 8 KiB each plus ~16,000 stateless ones. Built once as `Corpora.index`, it is the single largest item in the fast suite. Measure it. If it pushes the suite past 10 s:

- Keep the eight assertions in `.presubmission` reading the cached `LawIndex` produced by T07's loader against a warm on-disk fixture, and
- move the full cold rebuild to a `.tags(.integration, .nightly)` suite with `.timeLimit(.minutes(15))`.

Never drop an assertion to make the budget (`06 T58`). The eight counts are the epic's gate.

### `PROGRESS.md`

Record the eight numbers as *passing output*, not as intentions — §14.6 risk 7's early signal is "`PROGRESS.md` describing intentions rather than passing output". Paste the test run's summary line.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter BandPopulationTests` runs **eight separate count assertions**, one per band, each in its own `@Test` function with the band named in the display string.
- [ ] The six stateless assertions read `40`, `1_272`, `108`, `2_322`, `5_688`, `337` and all six pass.
- [ ] `statelessCount == 9_767`, `contextualCount == 17_248`, and the two sum to `27_015`.
- [ ] The two contextual assertions either pass at `6_934` / `10_314`, or are wrapped in `withKnownIssue` with a `.bug(id:)` and an entry in `DECISIONS.md` — and in **neither** case is `Band.population`, `SPEC.md` or `tests.json` altered away from §5.2.
- [ ] `bandsAreDisjoint` passes: no table appears in two stateless runs.
- [ ] `survivorsSatisfyTheirGuardrails` passes for all eight bands, and a failure attaches the offending node.
- [ ] `theoremBands` passes: all 108 band-3 laws have marginal deficit 1.0, every band-4 marginal is strictly between 0 and 1, and band 8 contains at least one member with deficit < 0.999.
- [ ] `grep -n 'serialized' HunchCore/Tests/LawGenerationTests/BandPopulationTests.swift` returns nothing, and the suite's doc comment explains how ascending order is achieved instead.
- [ ] `DECISIONS.md` records the contextual form-space clause (or the open question with the ruled-out list).
- [ ] `SPEC.md` carries the enumeration predicate in the seven steps above, with each guardrail cited.
- [ ] `PROGRESS.md` carries the eight counts as pasted passing output.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s, or the cold rebuild is gated to `.nightly` with the eight assertions still running in presubmission.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. **Reject any suggestion to collapse the eight assertions into one loop or one blob comparison** — §3.6 asks for "six assertions plus two, not one assertion on a 9,767-table blob", and the whole diagnostic value is knowing *which* band drifted.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T08: eight per-band |H| assertions summing to 27,015"`

## Out of scope

- **The 10,000-law generator suite.** E06 T09. That suite samples the generator; this one enumerates the space.
- **G8's `targetδ` proximity clause and G9.** §5.2 excludes both from `|H|` by definition — one is per-request, the other per-player and per-day. Do not add either to the enumeration predicate.
- **`difficulty(of:)`.** E06 T01. This task asserts *counts*, not positions inside a band.
- **The fallback rate.** "< 2 % per band" (§5.3) is a generator statistic, H19, owned by E11 T12.
- **Codex shelf counts.** The eight shelves' fill arcs and the `|H| ≤ 512` slot-map rule are E15 T07; they read `Band.population`, which this task proves.
