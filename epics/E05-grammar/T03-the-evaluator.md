# T03 — The evaluator

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Evaluator |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | It owns the naming ruling this task ships: there is **no `Loom` type** — the verdict is a pure function of `(law, prev, cur)`, so a `struct Loom { let law: Law }` is `04 A19`'s pass-through and the shipped spelling is `Law.admits(_ glyph: Glyph, after previous: Glyph) -> Bool` (`N9`, third-person verb) beside `Verdict.admit` (`N29`). |
| `hunch-swift-testing` | The 65,536-pair agreement test is a seeded-corpus suite with a deliberate loop inside — the `T21` deviation — and it must pay `T21` back with a reproducing seed and an `Attachment` of the offending AST in every failure. The skill also owns where the reference evaluator lives (`HunchTestSupport`, a `.target` absent from `products:`) so a second evaluator can never ship. |

## Objective

`Law.admits(_:after:)` exists and answers in constant time from the resolved table, never by walking the AST. §3.5's two sequencing rules — `prev` is the previously **probed** glyph regardless of verdict, and the seed glyph primes position 0 without being a probe — stop being prose and become `Law.verdicts(seededBy:probes:)`, the single function every mode's ribbon calls.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.5 | The whole task. `previous` = previously *probed* glyph regardless of verdict (overruling the brief), the three reasons, the stated cost, and "the Loom is **always primed**: at round start a seed glyph is drawn deterministically from the round seed and shown in the throat. It is `prev` for probe 1. It is not a probe, carries no verdict, and is not scored." |
| `GAME_DESIGN.md` | §3.5 | "the seed glyph appears in **every band**, contextual or not", because priming only in contextual bands would leak the family before the first probe. |
| `GAME_DESIGN.md` | §3.6 | "**Never walk the AST per glyph.**" |
| `GAME_DESIGN.md` | §4.5 | "All 65,536 ordered pairs are reachable — any glyph may follow any glyph", which is why the agreement test is exhaustive over pairs rather than sampled. |
| `GAME_DESIGN.md` | §5.5 | The band-5 worked round: 15 probes, **"Every verdict below is machine-verified."** This is the golden fixture. |
| `GAME_DESIGN.md` | §5.6 | The band-3 worked round: six probes, six verdicts. |
| `GAME_DESIGN.md` | §2 | `glyphID = fill*64 + shape*16 + pips*4 + hue` and the rank-1…4 ordering of every enum, which is how the worked rounds' prose glyphs become IDs. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 | The "the Loom → no type" row and the shipped signature. |
| `ios-swift-guide/06-TESTING.md` | T18a, T21, T23, T53 | Attachments, the loop deviation, `Codable` parameterisation, promoting a found failure into a named case. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawsTests/EvaluatorTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Evaluator", .tags(.unit, .presubmission))
struct EvaluatorTests {

    // MARK: - The GDD's two machine-verified worked rounds

    /// GDD §5.5, band 5. Hidden law `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle,hexagon}`.
    /// Seed glyph: hollow triangle, two pips, teal = 0*64 + 1*16 + 1*4 + 1 = **21**.
    /// Glyph ids below are §2's formula applied to the table's own prose, and every verdict is
    /// the GDD's own column — "every verdict below is machine-verified".
    @Test("The band-5 worked round reproduces all fifteen verdicts")
    func workedRoundBandFive() {
        let law = Law(Corpora.workedRoundBandFive.node)
        let seed = Deck.glyph(id: 21)
        let probes: [Int] = [24, 24, 28, 28, 16, 20, 40, 28, 16, 4, 56, 16, 36, 251, 158]
        let expected: [Verdict] = [
            .admit, .reject, .admit, .reject, .reject,   //  1…5
            .admit, .reject, .admit, .reject, .reject,   //  6…10
            .admit, .reject, .reject, .admit, .admit,    // 11…15
        ]
        let actual = law.verdicts(seededBy: seed, probes: probes.map(Deck.glyph(id:)))
        #expect(actual == expected)
    }

    /// GDD §5.6, band 3. `shape ∈ {circle,triangle} XOR fill ∈ {hollow,dotted}`, p = 0.500.
    /// The law names neither pips nor hue, so both are held at rank 1 (`one`, `amber`).
    @Test("The band-3 worked round reproduces all six verdicts")
    func workedRoundBandThree() {
        let law = Law(Corpora.workedRoundBandThree.node)
        let probes: [Int] = [0, 16, 32, 192, 224, 112]   // hollow circle/triangle/square,
                                                          // solid circle/square, dotted hexagon
        let expected: [Verdict] = [.reject, .reject, .admit, .admit, .reject, .admit]
        let actual = law.verdicts(seededBy: Deck.glyph(id: 0), probes: probes.map(Deck.glyph(id:)))
        #expect(actual == expected)
    }

    // MARK: - §3.5's sequencing contract

    @Test("`prev` is the previously PROBED glyph, regardless of verdict")
    func previousIsProbedNotAdmitted() {
        // GDD §3.5 overrules the brief here, so the test must be a case where the two readings
        // actually disagree — a REJECTED probe whose rank differs from the seed's.
        //
        //   law   `RANK pips(cur) > PREV RANK pips`
        //   seed  glyph 12 — pips rank 4
        //   p1    glyph  4 — pips rank 2 → 2 > 4 → reject
        //   p2    glyph  8 — pips rank 3
        //         previously PROBED:   prev = p1, rank 2 → 3 > 2 → admit   ← the design
        //         previously ADMITTED: prev = seed, rank 4 → 3 > 4 → reject ← the brief
        let law = Law(LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
        let verdicts = law.verdicts(seededBy: Deck.glyph(id: 12),
                                    probes: [Deck.glyph(id: 4), Deck.glyph(id: 8)])
        #expect(verdicts == [.reject, .admit])
    }

    @Test("The seed glyph primes position 0, is not a probe, and carries no verdict")
    func seedPrimesWithoutBeingAProbe() {
        let law = Law(Corpora.workedRoundBandFive.node)
        let seed = Deck.glyph(id: 21)
        let verdicts = law.verdicts(seededBy: seed, probes: [Deck.glyph(id: 24)])
        #expect(verdicts.count == 1)                       // one probe in, one verdict out
    }

    @Test("A twin re-probe holds the context fixed and may flip the verdict")
    func twinFlipsAContextualVerdict() {
        // GDD §5.5 probes 1 and 2: the same glyph, two different answers. That is the whole
        // discoverability payload of band 5 and it must survive any refactor of this function.
        let law = Law(Corpora.workedRoundBandFive.node)
        let g = Deck.glyph(id: 24)
        let verdicts = law.verdicts(seededBy: Deck.glyph(id: 21), probes: [g, g])
        #expect(verdicts == [.admit, .reject])
    }

    @Test("A stateless law ignores `prev` entirely", arguments: Corpora.statelessExemplars)
    func statelessIgnoresPrevious(_ exemplar: Corpora.BandExemplar) {
        let law = Law(exemplar.node)
        let cur = Deck.glyph(id: 137)
        let verdicts = Set(Deck.all.map { law.admits(cur, after: $0) })
        #expect(verdicts.count == 1)
    }

    // MARK: - Agreement with a brute-force AST walk over all 65,536 ordered pairs

    /// The `06 T21` deviation, declared: parameterising over `Corpora.evaluatorCorpus` × 65,536
    /// would be millions of runner nodes. The loop is inside, and it pays T21 back with a
    /// reproducing index plus an `Attachment` of the offending AST on the first disagreement.
    @Test("The mask evaluator agrees with a brute-force AST walk on every ordered pair",
          arguments: Corpora.evaluatorCorpus)
    func agreesWithBruteForce(_ entry: Corpora.LawCorpusEntry) throws {
        let law = Law(entry.node)
        for previousID in 0..<256 {
            let previous = Deck.glyph(id: previousID)
            for currentID in 0..<256 {
                let current = Deck.glyph(id: currentID)
                let fast = law.admits(current, after: previous)
                let slow = ReferenceEvaluator.admits(entry.node, current, after: previous)
                guard fast != slow else { continue }
                Attachment.record(entry.node, named: "disagreement-\(entry.index).json")
                Issue.record("""
                    evaluator disagrees at prev=\(previousID) cur=\(currentID): \
                    table says \(fast), AST walk says \(slow) — \
                    reproduce with Corpora.evaluatorCorpus[\(entry.index)]
                    """)
                return
            }
        }
    }

    @Test("Every ordered pair is reachable — the evaluator is total")
    func totality() {
        // GDD §4.5: "All 65,536 ordered pairs are reachable — any glyph may follow any glyph",
        // so there is no unreachable-state escape hatch and no optional verdict.
        let law = Law(Corpora.workedRoundBandFive.node)
        var seen = 0
        for p in 0..<256 { for c in 0..<256 {
            _ = law.admits(Deck.glyph(id: c), after: Deck.glyph(id: p)); seen += 1
        } }
        #expect(seen == 65_536)
    }
}
```

`Corpora.evaluatorCorpus` is a seeded corpus of ≈256 laws spanning all six productions, each entry a `Codable` struct carrying `node` and `index` so a failing case re-runs alone (`06 T23`). It is a `static let`.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter EvaluatorTests`
The first failure must be *"value of type 'Law' has no member 'admits'"*. Once `admits` exists but `verdicts(seededBy:probes:)` does not, the worked-round tests must fail on a missing symbol, and once both exist the failures must be **wrong verdicts**, printed as a list you can diff against §5.5's table. If `workedRoundBandFive` passes on the first run, check that `Corpora.workedRoundBandFive` is really §5.5's two-term law and not a stub.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Laws/Law.swift` — `admits(_:after:)`, `verdicts(seededBy:probes:)` |
| create | `HunchCore/Sources/HunchTestSupport/ReferenceEvaluator.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `LawCorpusEntry`, `evaluatorCorpus`, `statelessExemplars` |
| create | `HunchCore/Tests/LawsTests/EvaluatorTests.swift` |
| modify | `SPEC.md` — §3.5's two sequencing rules, verbatim, as the contract every mode inherits |
| modify | `tests.json` — "Evaluator" |

## Implementation notes

### The shipped surface

```swift
extension Law {
    /// Whether this law admits `glyph` when the previously probed glyph was `previous`.
    ///
    /// One table lookup. The AST is never walked here — it was walked exactly once, in
    /// `Law.init`, to compose the extension from precomputed masks (§3.6).
    ///
    /// A stateless law ignores `previous` entirely; passing any glyph is correct and cheap.
    /// - Complexity: O(1).
    public func admits(_ glyph: Glyph, after previous: Glyph) -> Bool

    /// The verdict for `glyph` after `previous`, as the domain's two-valued type (`N29`).
    /// - Complexity: O(1).
    public func verdict(for glyph: Glyph, after previous: Glyph) -> Verdict

    /// Every verdict in a probe sequence, under §3.5's semantics.
    ///
    /// `seed` primes position 0: it is `prev` for probe 1, it is **not** a probe, it carries no
    /// verdict and it is not scored (§3.5). `prev` for probe *n* is probe *n−1* **regardless of
    /// its verdict** — the design overrules the brief here, and reproducibility of the ribbon is
    /// the reason (§3.5, reason 2).
    ///
    /// - Returns: exactly `probes.count` verdicts.
    /// - Complexity: O(probes.count).
    public func verdicts(seededBy seed: Glyph, probes: [Glyph]) -> [Verdict]
}
```

The index arithmetic is the whole implementation:

```swift
public func admits(_ glyph: Glyph, after previous: Glyph) -> Bool {
    switch table.arity {
    case .stateless:  table.contains(glyph.glyphID)
    case .contextual: table.contains(previous.glyphID * 256 + glyph.glyphID)
    }
}
```

`previous * 256 + cur` is §3.6's index and it is not negotiable — E02's `Bitboard65536` was built to that layout and E15's Codex thumbnails project along it.

### Why `verdicts(seededBy:probes:)` lives here and not in `Rounds`

E07 ships `Probe`, `Ribbon` and twin semantics; E08 ships the verdict beat; E12/E13/E14 each re-derive a sequence. If each of them re-implements "`prev` is the previous element, and the seed primes position 0", one of them will get it wrong and the bug will look like a mode bug. **One function, in core, tested against §5.5's fifteen machine-verified verdicts.** Add a doc line saying so, and add a note to `SPEC.md` that `Ribbon` (E07 T08) and every mode schedule must call it rather than re-walking.

Do **not** put twin detection here: a twin is an *adjacent* re-probe and is a ribbon-rendering and scoring concept (E07 T08). This function does not care that probes 1 and 2 are the same glyph; it only cares that probe 2's `prev` is probe 1.

### `ReferenceEvaluator` — the second implementation that must never ship

```swift
// HunchCore/Sources/HunchTestSupport/ReferenceEvaluator.swift
/// A deliberately naive, per-glyph AST walk. It exists so the mask-driven evaluator has
/// something independent to disagree with, and it lives in `HunchTestSupport` — a `.target`
/// absent from `products:` (`06 T5a`) — so there is exactly one evaluator in the shipped binary.
public enum ReferenceEvaluator {
    /// - Complexity: O(leaves). Deliberately not O(1); do not optimise this file.
    public static func admits(_ node: LawNode, _ current: Glyph, after previous: Glyph) -> Bool
}
```

Write it straight from §3.2's BNF, one `switch` case per production, reading `Glyph`'s attribute values directly. Reuse **nothing** from `LawTable` — not the masks, not `Subset4`'s set algebra beyond `contains`, not the guard's `(gate & then) | (~gate & otherwise)` shape. A reference implementation that shares code with the thing it checks checks nothing.

Two places it will be tempting to share and must not: the aggregate's count (`#{a ∈ set : rank(a) ∈ rankIn}` then membership in `countIn`) and the guard's branch selection. Write both longhand.

### Cost

The agreement test is `|corpus| × 65,536 × 2` evaluations. At 256 laws that is 33.5 M reference walks, which will not fit the 10-second budget in a debug build. Two levers, in this order:

1. Size `Corpora.evaluatorCorpus` so the suite measures **≤ 1.5 s** — start at 64 laws, measure, and grow it to whatever fits. Record the chosen count as `Corpora.evaluatorCorpusSize` and cite it from the test, never a literal (`hunch-swift-testing` "Never restate a value that lives in Swift").
2. If a larger corpus is wanted, add a second suite tagged `.integration, .nightly` with the full sweep and leave the presubmission one small. Do not delete either (`06 T58`).

Measure before choosing. `swift test --package-path HunchCore --filter EvaluatorTests` prints per-test durations.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EvaluatorTests` is green, and the suite's own duration is ≤ 1.5 s.
- [ ] The band-5 worked round test asserts all **fifteen** verdicts in one `#expect`, with the glyph-id list `[24, 24, 28, 28, 16, 20, 40, 28, 16, 4, 56, 16, 36, 251, 158]` and the seed `21`.
- [ ] The band-3 worked round test asserts all **six**.
- [ ] `verdicts(seededBy:probes:)` returns exactly `probes.count` elements for an empty, one-element and fifteen-element input.
- [ ] The mask evaluator and `ReferenceEvaluator` agree on every one of the 65,536 ordered pairs for every law in `Corpora.evaluatorCorpus`.
- [ ] `grep -rn 'ReferenceEvaluator' HunchCore/Sources --include='*.swift' | grep -v HunchTestSupport` returns nothing.
- [ ] `swift package describe --type json --package-path HunchCore` shows no non-test target depending on `HunchTestSupport`.
- [ ] `Law.admits` contains no `for` loop and no `switch` over `LawNode`: `grep -n -A12 'func admits' HunchCore/Sources/Laws/Law.swift` shows a table index and nothing else.
- [ ] `SPEC.md` states §3.5's two sequencing rules and names `Law.verdicts(seededBy:probes:)` as their single owner.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. **Reject any suggestion to deduplicate `ReferenceEvaluator` against `LawTable`** — the duplication is the test.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T03: the mask-driven evaluator and §3.5's sequencing contract"`

## Out of scope

- **Twins, the ribbon, `Probe`, scoring.** E07 T08. A twin is an adjacent re-probe; this task's function does not know the word.
- **The 420 ms verdict beat, the 260 ms adjudication hold and the input lock.** E08 T06. No timing constant enters `HunchCore`.
- **The counterexample.** Selection is E06 T08; presentation is E09 T09.
- **Declaration verdict.** Extension identity is T05; the Seal and two strikes are E09 T08.
- **DRIFT's two-law schedule.** The law swaps outside the AST (§3.5); `DriftSchedule` is E12 T01 and calls this function unchanged.
