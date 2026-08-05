# T08 — Declaration verdict and two strikes

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | §14.1 `Declaration verdict` · `Two strikes` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The verdict is a pure function of values, so it is core — and the skill's boundary predicate is what keeps the 640 ms hold, the animation and the strike *presentation* out of it. It also owns `A18`/`A19`/`A20`: `Round` stays thin enough that deleting it breaks phase timing and snapshot cadence, and the phase transitions themselves stay in `HunchCore` and are tested there. |
| `hunch-bench-instruments` | The declaration is what the Seal commits, and this task wires `SealView`'s `onCommit` to the adjudication. The skill's rule that a barred control refuses without an error is what stops "wrong declaration" growing an error surface here. |
| `hunch-swift-testing` | The correctness claim — *arrangement, spelling, coupler choice and complement direction are all irrelevant* — is a property over a seeded corpus, not three hand-picked examples, and this skill owns the corpus shape and the T21 deviation the corpus test uses. |

## Objective

At the end of this task pressing an unbarred Seal produces a verdict: **correct iff
`extension(declared) == extension(hidden)`**, compared in the common space with lifting, so a player
who spells the same law differently is right. Before this task the Seal commits nothing; after it, the
first wrong declaration takes a strike and the round continues, the second ends it, and a third
declaration is structurally impossible.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.5 | *"**Correct iff `extension(declared) == extension(hidden)`**, compared in the common space with lifting. Purely semantic. Tile arrangement, spelling, coupler choice and complement direction are all irrelevant."* Plus: all 65,536 ordered pairs are reachable, so there is no "correct on reachable states but judged wrong" failure mode |
| `GAME_DESIGN.md` | §4.5 | The two-strike Decision: *"On the **first** incorrect declaration the counterexample is revealed and the round continues; the probe count keeps running and the player may declare again. On the **second**, the round ends"* |
| `GAME_DESIGN.md` | §6.1 | The phase table: `declaring —Seal(unbarred)→ sealing`; `sealing —correct→ revealing(.inscribed)`; `sealing —wrong, strikes == 0→ counterexample`; `sealing —wrong, strikes == 1→ revealing(.broken)`. And the invariant: *"Every verdict — probe or declaration — is computed and committed to `RoundState` at t = 0 ms of its beat sheet and merely displayed later"* |
| `GAME_DESIGN.md` | §6.8 | *"**Two declarations per round, hard.** No third."* |
| `GAME_DESIGN.md` | §6.9 | `penalty = (strikes == 1) ? 0.6 : 1.0`, multiply then round once; only `Outcome.inscribed` scores; marks and the fracture are **independent** records |
| `GAME_DESIGN.md` | §6.11 cases 1, 14, 15 | Declare at probe 0 is legal (`probesUsed = max(1, 0)`); a differently-spelled equivalent is correct; a stateless declaration against a contextual law is judged by lifting and is wrong unless genuinely equivalent |
| `GAME_DESIGN.md` | §3.6 | Extension identity is the *only* comparison, with lifting to the larger arity; the 64-bit dedup hash with a full compare on collision |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A20 | Extract the logic into a plain type and test that, not the view |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Create `HunchCore/Tests/RoundsTests/DeclarationVerdictTests.swift`:

```swift
import Testing
import Bench
import Glyphs
import Laws
import Rounds
import HunchTestSupport

@Suite("Declaration verdict", .tags(.unit, .presubmission))
struct DeclarationVerdictTests {

    // §4.5: "A player who lights {triangle, square, hexagon} matches a hidden law whose
    // canonical spelling excludes circle." Complement direction is irrelevant.
    @Test("The complement of a subset is the same law")
    func complementDirectionIsIrrelevant() throws {
        let hidden = try #require(LawNode.atom(.shape, RankSet(ranks: [0])))            // ∈ {circle}
        let declared = try #require(LawNode.atom(.shape, RankSet(ranks: [1, 2, 3])))    // ∉ {circle}
        #expect(adjudicate(declared, against: Law(hidden)) == .incorrect)               // NOT equal

        let sameSet = try #require(LawNode.atom(.shape, RankSet(ranks: [1, 2, 3])))
        let spelledOtherWay = try #require(Corpora.complementSpelling(of: sameSet))
        #expect(adjudicate(spelledOtherWay, against: Law(sameSet)) == .correct)
    }

    // §4.5: "Tile arrangement … irrelevant." Swap the rails; same law.
    @Test("Swapping the two rails does not change the verdict")
    func arrangementIsIrrelevant() throws {
        let a = try #require(Corpora.pairLaw)                    // X AND Y
        let swapped = try #require(Corpora.swappingRails(a))     // Y AND X
        #expect(swapped != a, "the layouts differ")
        #expect(adjudicate(swapped, against: Law(a)) == .correct)
    }

    // §4.5: "coupler choice … irrelevant" — where two different couplers happen to yield
    // the same extension, both are correct. RNF's constant-fold is what makes this real.
    @Test("Two drafts with different couplers but one extension are both correct")
    func couplerChoiceIsIrrelevant() throws {
        let (viaOr, viaXor) = try #require(Corpora.couplerCoincidence)
        #expect(LawTable(viaOr) == LawTable(viaXor))
        #expect(adjudicate(viaXor, against: Law(viaOr)) == .correct)
    }

    // §6.11 case 15: "Judged by lifting the stateless table to pair space. Wrong unless
    // genuinely equivalent."
    @Test("A stateless declaration against a contextual law is judged by lifting")
    func statelessAgainstContextual() throws {
        let hidden = try #require(Corpora.workedBand5Law)
        let stateless = try #require(LawNode.atom(.pips, RankSet(ranks: [2, 3])))
        #expect(adjudicate(stateless, against: Law(hidden)) == .incorrect)

        // …and the degenerate case is still correct: a contextual law that happens to be
        // stateless lifts to the same table.
        let secretlyStateless = try #require(Corpora.secretlyStatelessContextualLaw)
        #expect(adjudicate(try #require(secretlyStateless.statelessTwin),
                           against: Law(secretlyStateless)) == .correct)
    }

    // §3.6: extension identity is the ONLY comparison. Over a seeded corpus, verdict
    // agrees with table equality for every band — no syntactic shortcut anywhere.
    // T21 deviation: parameterise over bands, loop inside (08 §7.4).
    @Test("Verdict is table equality and nothing else", arguments: Band.allCases)
    func verdictIsTableEquality(_ band: Band) throws {
        for index in 0..<Corpora.lawsPerBand {
            let hidden = Law(generate(seed: Corpora.seed(band: band, index: index),
                                      band: band, targetDelta: band.centre, mode: .probe))
            let declared = Corpora.nearbyDraft(for: hidden, index: index)
            let expected: DeclarationVerdict =
                LawTable(declared).lifted == hidden.table.lifted ? .correct : .incorrect
            guard adjudicate(declared, against: hidden) == expected else {
                Attachment.record(declared, named: "band\(band.rawValue)-index\(index).json")
                Issue.record("verdict disagreed with table equality at band \(band.rawValue), index \(index)")
                return
            }
        }
    }
}
```

Create `HunchCore/Tests/RoundsTests/TwoStrikesTests.swift`:

```swift
import Testing
import Rounds
import Laws
import HunchTestSupport

@Suite("Two strikes", .tags(.unit, .presubmission))
struct TwoStrikesTests {

    // §6.1's transition table, the three rows that leave `sealing`.
    @Test("A correct declaration goes straight to revealing(.inscribed)")
    func correctPath() throws {
        var state = RoundState.fixture(strikes: 0)
        state = try #require(state.applying(.sealed(.correct)))
        #expect(state.phase == .revealing(.inscribed(marks: state.marks, fracture: false)))
        #expect(state.declarationsUsed == 1)
    }

    @Test("The first wrong declaration takes a strike and returns to probing")
    func firstStrikeContinues() throws {
        var state = RoundState.fixture(strikes: 0, probesUsed: 9)
        state = try #require(state.applying(.sealed(.incorrect)))
        #expect(state.phase == .counterexample)
        #expect(state.strikes == 1)

        state = try #require(state.applying(.counterexampleBeatCompleted))
        #expect(state.phase == .probing)
        #expect(state.probesUsed == 9, "a counterexample is not a probe")
        #expect(state.canDeclare, "no forced probe before re-declaring")
    }

    @Test("The second wrong declaration ends the round")
    func secondStrikeEnds() throws {
        var state = RoundState.fixture(strikes: 1)
        state = try #require(state.applying(.sealed(.incorrect)))
        #expect(state.phase == .revealing(.broken))
        #expect(state.strikes == 2)
        #expect(!state.canDeclare)
    }

    // §6.8: "Two declarations per round, hard. No third."
    @Test("A third declaration is impossible")
    func hardCeiling() {
        var state = RoundState.fixture(strikes: 1)
        state = state.applying(.sealed(.incorrect))!
        #expect(state.declarationsUsed == 2)
        #expect(state.applying(.sealed(.correct)) == nil, "the transition does not exist")
        #expect(state.applying(.sealed(.incorrect)) == nil)
    }

    // §6.9: penalty is 0.6 on exactly one strike; marks and fracture are INDEPENDENT.
    @Test("One strike costs 40 % of score and marks a fracture, and the two are independent")
    func scoringWiring() {
        let clean = RoundState.fixture(strikes: 0, probesUsed: 13, par: 23).settledScore
        let fractured = RoundState.fixture(strikes: 1, probesUsed: 13, par: 23).settledScore
        #expect(clean.score == 1000)
        #expect(fractured.score == 600)
        #expect(clean.marks == 3 && fractured.marks == 3)
        #expect(clean.fracture == false && fractured.fracture == true)
    }

    // §6.11 case 1: declare at probe 0 is legal and scores 1000 / 3 marks.
    @Test("Declaring at probe 0 is legal and does not divide by zero")
    func declareAtProbeZero() {
        let result = RoundState.fixture(strikes: 0, probesUsed: 0, par: 7).settledScore
        #expect(result.score == 1000)
        #expect(result.marks == 3)
    }

    // §6.1: "the model never waits on an animation" — the verdict is committed before the
    // phase's beat sheet starts, not when it ends.
    @Test("The verdict is committed on entry to sealing, not on exit")
    func committedAtTZero() throws {
        var state = RoundState.fixture(strikes: 0)
        state = try #require(state.applying(.sealed(.correct)))
        #expect(state.settledOutcome != nil, "outcome resolved the instant the Seal was pressed")
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter 'DeclarationVerdictTests|TwoStrikesTests'
```

`cannot find 'adjudicate' in scope` and `value of type 'RoundState' has no member
'declarationsUsed'` are the right failures.

**Step 3 — implement.**

**Step 4 — green, then refactor.** `verdictIsTableEquality` runs the generator
`8 × Corpora.lawsPerBand` times; measure it and gate it to `.nightly` with a smoke subset in
presubmission if it costs more than ~0.3 s.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/Declaration.swift` — `DeclarationVerdict`, `adjudicate(_:against:)` |
| modify | `HunchCore/Sources/Rounds/RoundPhase.swift` — the three `sealing` exits and the `counterexample` exit in the pure transition function; `Event.sealed(_:)` and `.counterexampleBeatCompleted` |
| modify | `HunchCore/Sources/Rounds/RoundState.swift` — `strikes`, `declarationsUsed`, `canDeclare`, `settledOutcome`, `settledScore` |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `seal()` wires `SealView.onCommit` to `adjudicate` and commits at t = 0 |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the Seal's `onCommit` |
| create | `HunchCore/Tests/RoundsTests/DeclarationVerdictTests.swift` |
| create | `HunchCore/Tests/RoundsTests/TwoStrikesTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `complementSpelling(of:)`, `pairLaw`, `swappingRails(_:)`, `couplerCoincidence`, `secretlyStatelessContextualLaw`, `nearbyDraft(for:index:)` |
| modify | `tests.json` — the extension-identity invariant and the two-declaration ceiling |

## Implementation notes

### `adjudicate` is three lines and reuses everything

```swift
public enum DeclarationVerdict: Hashable, Sendable { case correct, incorrect }

/// §4.5. Purely semantic: extension identity in the common space, with lifting.
/// Arrangement, spelling, coupler choice and complement direction are all irrelevant
/// because none of them survives into a `LawTable`.
public func adjudicate(_ declared: LawNode, against hidden: Law) -> DeclarationVerdict {
    LawTable(declared).lifted == hidden.table.lifted ? .correct : .incorrect
}
```

That is the whole algorithm, and every clause of §4.5's "irrelevant" list is delivered by *not writing
anything*. Do not add:

- an RNF comparison — `renderedNormalForm` equality is a *stronger* test than extension identity and
  would reject the equivalent phrasings §4.5 explicitly accepts (that stronger test is G10's job, on
  the generator's side, for a different reason);
- a "close enough" tolerance — there is no such thing;
- a fast path that compares `lawKey` hashes only. The 64-bit hash is a **dedup** key with a full
  compare on collision (§3.6); using it alone as a verdict makes a hash collision a false *correct*,
  which is the one error mode a puzzle game may not have. If you want the hash as a pre-filter, keep
  the full compare behind it and say so in a comment.

Lifting comes from E05·T04/T05 (`Bitboard65536`, `lift(T) = TILE * T`, comparison always at the larger
arity). This function calls it; it does not re-implement it.

### The declared law comes from the Bench, and it is already parsed

`BenchLayout` → `LawNode?` is `LawNode.init?(_ layout:)` from E06·T03. The Seal is unbarred, so
by T07's `unbarredImpliesParseable` test the parse succeeds — but write it as `guard let node =
LawNode(draft) else { … }` and treat `nil` as a programmer error with a `preconditionFailure` in
DEBUG, not as a silent no-op. A Seal that lifts its bar and then does nothing is worse than a barred
one.

### The strike accounting lives in the pure transition function

```
sealing --correct-----------------> revealing(.inscribed(marks:fracture:))
sealing --incorrect, strikes == 0--> counterexample     (strikes := 1)
sealing --incorrect, strikes == 1--> revealing(.broken) (strikes := 2)
counterexample --beat completed----> probing            (Bench collapses; draft preserved)
```

Four rows, added to E07·T07's exhaustive `(RoundPhase, Event) -> RoundPhase?` function. The
**`Optional` return is the ceiling**: `applying(.sealed(_))` from a state with `declarationsUsed == 2`
returns `nil`, which is why "no third declaration" is a property of the transition table rather than a
guard somebody can forget to write at a call site. `canDeclare` is a derived `Bool` on `RoundState`
for the view; it is not a second source of truth.

`fracture` is `strikes >= 1` **at settle**, and `marks` is E06·T07's threshold read of `probesUsed`
against `par` — **independent** records (§6.9's Decision). A 3-mark fractured page exists and is drawn
with three marks and a crack; conflating them destroys information about a round that was solved
efficiently *after* a wrong turn.

### Committed at t = 0

§6.1's invariant is the reason this task is core-heavy and view-light: `Round.seal()` calls
`adjudicate`, applies the transition, computes the score and marks, and hands the results to the
persistence writes (T11) — **all before the first frame of the 640 ms hold**. The phase then carries
the already-settled outcome, and every subsequent animation is decoration over it. Killing the app
mid-hold loses nothing.

Concretely, `Round.seal()` must not be `async`, must not `await` anything, and must not schedule the
commit inside an animation completion. If `/code-review` finds a `withAnimation { … commit() }`, that
is a defect, not a style note.

### What is deliberately *not* here

There is no error surface for a wrong declaration. The counterexample is the entire disclosure (§4.5:
*"the law is never revealed"*), and it is T09's. Between this task and T09 the incorrect path
transitions correctly and shows nothing — that is a legitimate intermediate state for one commit, and
the test suite is what says the model is right before the picture is.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'DeclarationVerdictTests|TwoStrikesTests'` green.
- [ ] `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` passes.
- [ ] `grep -n 'renderedNormalForm\|lawKey' HunchCore/Sources/Rounds/Declaration.swift` returns
      nothing, or returns a hash pre-filter with the full compare visibly behind it.
- [ ] `grep -c 'default:' HunchCore/Sources/Rounds/RoundPhase.swift` returns `0`.
- [ ] `grep -n 'async\|await\|withAnimation' Modules/Sources/LoomFeature/Round.swift` shows nothing
      inside `seal()`.
- [ ] `tests.json` carries `declaration.extension-identity`, `declaration.two-per-round-hard` and
      `declaration.strike-penalty-0.6`.
- [ ] In the simulator: build a draft that is equivalent to but differently spelled from a band-1 law
      and watch it be accepted.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter 'DeclarationVerdictTests|TwoStrikesTests'`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T08: declaration verdict by extension identity, and the two-declaration ceiling"`

## Out of scope

- **Extension identity, lifting and the dedup hash as algorithms.** **E05·T05**. This task calls them.
- **`par`, `cap`, the score formula and the mark thresholds.** **E06·T07**. This task asserts the
  wiring — 0.6 on one strike, marks independent of fracture — not the arithmetic.
- **Counterexample selection.** **E06·T08**. **Presentation** is **T09**.
- **The 640 ms hold and everything after it.** **T09** and **T10**.
- **Writing the Codex page, the θ update, the Profile accumulators and the novelty ring.** **T11**
  wires those to the same t = 0; this task computes the outcome they consume.
- **The cap-reached path (`revealing(.exhausted)`).** Transition already exists from E07·T07; its beat
  sheet is **T10**.
- **`Outcome.abandoned` and `.voided`.** **E10·T04** and **E10·T02**.
