# T08 — ECHO scoring

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | ECHO scoring (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Places the whole of this in `HunchCore/Sources/Rounds/` as a value with no clock and no store, and owns the ruling that the *success* flag is integer arithmetic while the *reported* `setF1` is a `Double` — one quantity, two representations, and only one of them may be compared for equality. It also decides that the Profile transcript is its own `Sendable` value rather than a tuple, because a tuple's fields are positional and this one crosses an epic boundary. |
| `hunch-swift-testing` | §8.7's worked round is the epic's gate and it has to reproduce to the digit — five assertions in one test, each one of which can be wrong on its own. The skill also owns the ban on swift-numerics, which matters on every line here, and the rule that a threshold test is parameterised across its boundary rather than sampled at one convenient point. |

## Objective

At the end of this task an ECHO round has a number: `setF1² · (0.70 + 0.30·order) · replayF`, with
`order` measured by longest increasing subsequence over the intersection, marks at 3 / 2 / 1, and
success for the Rasch update defined as the *right set* regardless of order. Both degenerate answers —
an empty rail and a flooded one — are legal, scored, and strictly dominated.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.7 (the code block and the three paragraphs after it) | `truth`, `answer`, `hit`, `prec`, `rec`, `setF1` (0 if `hit == 0`), `order` by LIS over the intersection by cast index, `replayF`, `score_ECHO`; success iff `setF1 == 1.0`; order is never a pass/fail condition and is a bounded 30 % of score; marks 3 / 2 / 1; the emitted transcript `(hit, falseIncludes, A, order, replayed)` |
| `GAME_DESIGN.md` | §8.7 (worked round) | ℓ = 5, truth `[2,5,6,10]`, answer `[2,6,5,9]` → hit 3, setF1 0.75, order 0.667, score 506, 1 mark, transcript `(3, 1, 4, 0.667)` |
| `GAME_DESIGN.md` | §8.5 (closing paragraph) | there is **no strike mechanic in ECHO**; a commit is final, because ECHO's answer is a transcript and not a hypothesis |
| `GAME_DESIGN.md` | §8.10 EMPTY-RAIL, RAIL-OVERFILL | both legal, no confirmation prompt, `setF1 = 2A/(L+A)` for a flooded rail — 0.53 at ℓ = 5, below the 1-mark threshold |
| `GAME_DESIGN.md` | §8.8 clauses (3) and (4) | `setF1²` is the dominant term and order contributes at most 30 % — the two properties that make the mode not a memory task |
| `GAME_DESIGN.md` | §6.9 | canon's rounding convention: multiply, then round **once**, at the end |
| `GAME_DESIGN.md` | §11.9 (Retention row) | the sample formula lives **there**, not here; this section owns the transcript quantities and nothing else |
| `GAME_DESIGN.md` | §9.10 (Strikes row) | ECHO: none |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §7.9 | `isApproximatelyEqual(_:_:absoluteTolerance:)`; swift-numerics is banned |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/EchoScoreTests.swift`:

```swift
import Testing
@testable import Rounds
import HunchTestSupport

@Suite("EchoScore — §8.7", .tags(.unit, .presubmission))
struct EchoScoreTests {

    /// The epic's gate. §8.7's worked round, every published figure, in one test.
    @Test("§8.7's worked round reproduces to the digit")
    func workedRoundFromSectionEightSeven() {
        let score = EchoScore(truth: [2, 5, 6, 10], answer: [2, 6, 5, 9], replayed: false)

        #expect(score.hit == 3)
        #expect(isApproximatelyEqual(score.precision, 0.75, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(score.recall, 0.75, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(score.setF1, 0.75, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(score.order, 2.0 / 3.0, absoluteTolerance: 1e-9))
        #expect(score.points == 506)
        #expect(score.marks == 1)
        #expect(!score.isSuccess)

        let transcript = score.transcript
        #expect(transcript.hit == 3)
        #expect(transcript.falseIncludes == 1)
        #expect(transcript.lawfulCount == 4)
        #expect(isApproximatelyEqual(transcript.order, 2.0 / 3.0, absoluteTolerance: 1e-9))
        #expect(!transcript.replayed)

        // §11.9's Retention form, computed inline because that table is E16·T05's to own.
        // E16·T05 REPLACES the next line with `ProfileSample.retention(transcript)` and deletes nothing.
        let retention = max(0, Double(transcript.hit - transcript.falseIncludes)
                               / Double(transcript.lawfulCount))
        #expect(isApproximatelyEqual(retention, 0.50, absoluteTolerance: 1e-9))
    }

    @Test("a perfect answer is 1000, three marks and a success")
    func perfectAnswer() {
        let score = EchoScore(truth: [1, 4, 7, 9], answer: [1, 4, 7, 9], replayed: false)
        #expect(score.setF1 == 1.0)
        #expect(score.order == 1.0)
        #expect(score.points == 1000)
        #expect(score.marks == 3)
        #expect(score.isSuccess)
    }

    @Test("the right set in the wrong order is still a success, and still two marks")
    func rightSetWrongOrder() {
        let score = EchoScore(truth: [1, 4, 7, 9], answer: [9, 7, 4, 1], replayed: false)
        #expect(score.setF1 == 1.0)
        #expect(score.isSuccess)                       // §8.7: order is never a pass/fail condition
        #expect(isApproximatelyEqual(score.order, 0.25, absoluteTolerance: 1e-9))
        #expect(score.marks == 2)
        #expect(score.points == round(1000 * 1.0 * (0.70 + 0.30 * 0.25)))
    }

    @Test("a perfect answer after a replay is two marks, not three")
    func replayCostsTheThirdMark() {
        let score = EchoScore(truth: [1, 4, 7, 9], answer: [1, 4, 7, 9], replayed: true)
        #expect(score.setF1 == 1.0)
        #expect(score.order == 1.0)
        #expect(score.isSuccess)                       // the replay costs score, never success
        #expect(score.marks == 2)
        #expect(score.points == 600)
    }

    @Test("EMPTY-RAIL is legal, scores 0, earns 0 marks and is a failure")
    func emptyRail() {
        let score = EchoScore(truth: [1, 4, 7, 9], answer: [], replayed: false)
        #expect(score.hit == 0)
        #expect(score.setF1 == 0.0)
        #expect(score.order == 0.0)
        #expect(score.points == 0)
        #expect(score.marks == 0)
        #expect(!score.isSuccess)
        #expect(score.transcript.falseIncludes == 0)
    }

    @Test("RAIL-OVERFILL is legal and dominated: setF1 = 2A/(L+A)", arguments: LoadIndex.allCases)
    func railOverfill(_ load: LoadIndex) {
        let truth = Array(0..<load.lawfulCount)
        let score = EchoScore(truth: truth, answer: Array(0..<load.length), replayed: false)
        let expected = 2.0 * Double(load.lawfulCount) / Double(load.length + load.lawfulCount)
        #expect(isApproximatelyEqual(score.setF1, expected, absoluteTolerance: 1e-9))
        #expect(score.marks == 0)                      // below the 1-mark threshold at every row
        #expect(!score.isSuccess)
    }

    @Test("flooding is strictly dominated by the honest subset it contains", arguments: LoadIndex.allCases)
    func floodingIsDominated(_ load: LoadIndex) {
        let truth = Array(0..<load.lawfulCount)
        let flooded = EchoScore(truth: truth, answer: Array(0..<load.length), replayed: false)
        let honest = EchoScore(truth: truth, answer: truth, replayed: false)
        #expect(honest.points > flooded.points)
        #expect(honest.marks > flooded.marks)
    }

    @Test("the 1-mark threshold is exactly 0.70 and is inclusive")
    func oneMarkThreshold() {
        // A = 5, |answer| = 5, hit = 4  →  setF1 = 8/10 = 0.80  → 1 mark
        #expect(EchoScore(truth: [0, 1, 2, 3, 4], answer: [0, 1, 2, 3, 9], replayed: false).marks == 1)
        // A = 5, |answer| = 5, hit = 3  →  setF1 = 6/10 = 0.60  → 0 marks
        #expect(EchoScore(truth: [0, 1, 2, 3, 4], answer: [0, 1, 2, 8, 9], replayed: false).marks == 0)
        // A = 10, |answer| = 10, hit = 7 → setF1 = 14/20 = 0.70 exactly → 1 mark, inclusive
        #expect(EchoScore(truth: Array(0..<10), answer: Array(0..<7) + [10, 11, 12],
                          replayed: false).marks == 1)
    }

    @Test("order is the longest increasing subsequence of the intersection, by cast index")
    func orderIsLIS() {
        // intersection in answer order [2, 6, 5]; LIS by cast index is length 2.
        #expect(isApproximatelyEqual(EchoScore(truth: [2, 5, 6, 10], answer: [2, 6, 5, 9],
                                                replayed: false).order, 2.0 / 3.0,
                                     absoluteTolerance: 1e-9))
        // A strictly increasing intersection is order 1 even with intrusions between its members.
        #expect(EchoScore(truth: [1, 5, 8], answer: [1, 99, 5, 98, 8], replayed: false).order == 1.0)
        // A strictly decreasing intersection of length 3 has LIS 1.
        #expect(isApproximatelyEqual(EchoScore(truth: [1, 5, 8], answer: [8, 5, 1], replayed: false).order,
                                     1.0 / 3.0, absoluteTolerance: 1e-9))
    }

    @Test("intrusions never enter the LIS, only the intersection does")
    func intrusionsDoNotEnterTheLIS() {
        // 99 and 98 are not in truth; including them would give LIS 5 and order > 1.
        let score = EchoScore(truth: [1, 5, 8], answer: [1, 99, 5, 98, 8], replayed: false)
        #expect(score.hit == 3)
        #expect(score.order <= 1.0)
        #expect(score.order == 1.0)
    }

    @Test("the score is rounded exactly once, at the end (§6.9)")
    func roundsOnce() {
        // 1000 · 0.5625 · 0.90 = 506.25 — rounding setF1² or the order term first gives 506 ≠ 507.
        let score = EchoScore(truth: [2, 5, 6, 10], answer: [2, 6, 5, 9], replayed: false)
        #expect(score.points == 506)
        #expect(score.points != Int(1000 * 0.56 * 0.9))
    }

    @Test("the score is monotone in hit for a fixed answer length", arguments: 0...4)
    func monotoneInHit(_ hit: Int) {
        let truth = [0, 1, 2, 3]
        let answer = Array(truth.prefix(hit)) + Array((10..<(10 + 4 - hit)))
        let score = EchoScore(truth: truth, answer: answer, replayed: false)
        if hit > 0 {
            let weaker = EchoScore(truth: truth,
                                   answer: Array(truth.prefix(hit - 1)) + Array((10..<(10 + 5 - hit))),
                                   replayed: false)
            #expect(score.points >= weaker.points)
        }
    }

    @Test("success is set equality, computed on integers and never on a Double comparison")
    func successIsIntegerExact() {
        #expect(EchoScore(truth: [3, 1], answer: [1, 3], replayed: false).isSuccess)
        #expect(!EchoScore(truth: [3, 1], answer: [1, 3, 5], replayed: false).isSuccess)
        #expect(!EchoScore(truth: [3, 1], answer: [1], replayed: false).isSuccess)
    }

    @Test("there is no strike API in ECHO — a commit is final")
    func noStrikes() {
        #expect(!Mode.echo.hasStrikes)
        #expect(Mode.echo.declarationsPerRound == 1)
    }

    @Test("the replay penalty is 0.6 and lives here, with the formula")
    func replayPenalty() {
        #expect(EchoScore.replayPenalty == 0.6)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter EchoScoreTests`
Missing symbols only. If the worked round fails on the *value* rather than on a missing symbol, the
formula is wrong — do not adjust the expectation. 506 is published in §8.7 and is the epic's gate.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/EchoScore.swift` |
| create | `HunchCore/Sources/Rounds/EchoTranscript.swift` |
| modify | `HunchCore/Sources/Glyphs/Mode.swift` — `hasStrikes`, `declarationsPerRound` |
| modify | `Modules/Sources/LoomFeature/EchoRound.swift` — commit builds an `EchoScore` at t = 0 |
| create | `HunchCore/Tests/RoundsTests/EchoScoreTests.swift` |
| modify | `tests.json` — six entries |

## Implementation notes

### The closed form, and why it changes how everything is compared

Substituting `prec = hit/|answer|` and `rec = hit/A` into `2·prec·rec/(prec + rec)` gives

```
setF1 = 2·hit / (|answer| + A)
```

which is §8.10's own formula for RAIL-OVERFILL (`2A/(L+A)`) falling straight out, and it means every
threshold in this file is a comparison between two integers:

| Question §8.7 asks | Written as a `Double` | Written exactly |
|---|---|---|
| `setF1 == 1` | `setF1 == 1.0` — a float equality | `2·hit == answer.count + A`, which given `hit ≤ min(|answer|, A)` is `hit == answer.count && hit == A` |
| `setF1 >= 0.70` | `setF1 >= 0.70` — the 0.70 boundary is representable only approximately | `20·hit >= 7·(answer.count + A)` |
| `order == 1` | `order == 1.0` | `lis == hit` |

Use the exact forms for **every branch** and reserve the `Double` for the reported value and for the
score arithmetic. `isSuccess` decides whether the Rasch update fires (E11·T02) and marks decide what
the Codex burnishes (E15·T06); neither may hinge on whether `2.0/(4+4)*3` happens to land on `0.75`.
Compute `setF1` once as a `Double` for `points` and for the transcript, and never compare it.

### `order`

```swift
/// §8.7: LIS over the intersection, by cast index, divided by `max(1, hit)`.
/// The intersection is taken **in answer order** — that is what makes this a measure of the
/// player's ordering rather than of the cast's.
func longestIncreasingSubsequence(_ indices: [Int]) -> Int
```

`indices` is `answer.filter(truthSet.contains)` — answer order preserved, intrusions removed. `n ≤ 14`,
so the O(n²) dynamic program is correct, obvious and fast enough; the patience-sorting variant buys
nothing and is one more place to be subtly wrong. **Strictly** increasing, not non-decreasing: cast
indices are distinct, so the distinction cannot be exercised by real input, but writing `<` rather than
`<=` is what keeps the function honest if it is ever reused.

Two properties the tests pin because both are plausible mistakes:

- **Intrusions are removed before the LIS, not after.** Running the LIS over the whole answer would let a well-placed intrusion lengthen the subsequence, and `order` could exceed 1.
- **`max(1, hit)` is the denominator, not `A`.** A player who places two of four lawful indices in the right relative order has `order = 1` — order measures the ordering of what they got right, and completeness is `setF1`'s job. Dividing by `A` would double-charge the same error and quietly break §8.8's clause (4).

### The score

```swift
public var points: Int {
    Int((1000 * setF1 * setF1 * (0.70 + 0.30 * order) * replayFactor).rounded())
}
```

One rounding, at the end — canon §6.9's convention, and the reason §8.7's worked round is 506 rather
than 507: `1000 · 0.5625 · 0.900 = 506.25`, and rounding either factor first loses the quarter that
decides it. `.rounded()` is half-away-from-zero, which is what `round(…)` means in both sections.

`setF1 * setF1` rather than `pow(setF1, 2)` — same value, no `Foundation` dependency in a file that
otherwise needs none.

### Marks

```swift
public var marks: Int {
    if isSuccess && lis == hit && !replayed { 3 }
    else if isSuccess { 2 }
    else if 20 * hit >= 7 * (answer.count + lawfulCount) { 1 }
    else { 0 }
}
```

Read the ladder in §8.7's own order and resist collapsing it. Three details it encodes:

- **A replay costs the third mark but not success.** `isSuccess` never mentions `replayed`, so the ability update is untouched by the accommodation — which is the whole reason §14.5 open decision 8 can call the free replay an accommodation rather than a difficulty setting.
- **Order gates the third mark and nothing else.** §8.7: order is a bounded 30 % of score and is *never* a pass/fail condition.
- **The 1-mark rung is `setF1 ≥ 0.70`, inclusive**, and it is reachable without success — which is what §8.7's worked round earns.

### The transcript

```swift
public struct EchoTranscript: Hashable, Sendable {
    public let hit: Int
    public let falseIncludes: Int      // |answer \ truth| == answer.count − hit
    public let lawfulCount: Int        // A
    public let order: Double
    public let replayed: Bool
}
```

A value, not a tuple: it crosses an epic boundary (E16·T05 consumes it) and a five-element tuple's
fields are positional, so a reordering is a silent behaviour change. `lawfulCount` rather than `A` for
the same reason `targetδ` becomes `targetDelta` — a single-letter property cannot be greped.

**The Retention sample is not computed here.** §8.7 is explicit: *"The sample formula that turns them
into a Retention increment, and the step size that applies it, are §11.9's single normative table —
not defined here, and there is no per-mode EWMA constant in this section."* The test above therefore
writes §11.9's expression **inline**, with a comment naming E16·T05 as the owner. When E16·T05 ships
`ProfileSample.retention(_:)`, that one line becomes a call and the assertion — 0.50 — does not move.
Do not pre-empt it by adding a `retentionSample` property to `EchoTranscript`; that is the two-spellings
failure §11.9's preamble exists to prevent.

### No strikes

§8.5's closing paragraph and §9.10's Strikes row agree: ECHO has none, because *"ECHO's answer is a
transcript, not a hypothesis, and a second attempt at the same transcript is a memory retry, not a
reasoning retry."* Two consequences to ship rather than to remember:

- `Mode.echo.hasStrikes == false` and `declarationsPerRound == 1`, asserted. Where PROBE and DRIFT read `strikes` in the score path, ECHO's path has no such term — there is no `× 0.6 if a strike was taken` factor here, and `replayF` is not a strike in disguise: it is priced at the same 0.6 by coincidence of design, not by sharing a constant. Declare `EchoScore.replayPenalty` separately from canon's strike multiplier, and put that sentence in its doc comment, or someone will unify them.
- `EchoRound.commit()` transitions `recalling → adjudicating` and there is no path back. Everything after the Seal press is decoration over a settled `EchoScore` — the commit clock, exactly as in PROBE (§6.1's first invariant).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EchoScoreTests` green — all fourteen, including the gate test with all five published figures and the Retention 0.50 line.
- [ ] `grep -n "setF1 ==\|setF1 >=\|order ==" HunchCore/Sources/Rounds/EchoScore.swift` returns nothing — every branch is integer arithmetic.
- [ ] `grep -n "strike" HunchCore/Sources/Rounds/EchoScore.swift Modules/Sources/LoomFeature/EchoRound.swift` returns nothing.
- [ ] `grep -n "retention" HunchCore/Sources/Rounds/EchoTranscript.swift` returns nothing — §11.9 owns that formula.
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh HunchCore/Sources/Rounds/EchoScore.swift` exits 0.
- [ ] `tests.json` carries six entries: the worked round, success iff the right set, the three mark rungs, LIS correctness, EMPTY-RAIL, and RAIL-OVERFILL's domination.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T08: ECHO scoring, the LIS order term and the Profile transcript"`

## Out of scope

- The Retention sample and the Profile update — **E16·T05/T06**; this task emits the transcript and asserts §11.9's arithmetic inline until then.
- The Rasch update that consumes `isSuccess` and `servedDelta` — **E11·T02**.
- Latching `burnished` on a 3-mark round — **E15·T06**; T09 emits the request.
- The reveal that renders the score — **T09**.
- `RoundRecord` and the statistics counters — **E07·T09**, **E16·T11**.
