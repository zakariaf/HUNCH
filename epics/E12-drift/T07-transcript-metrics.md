# T07 — Transcript metrics

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P1 |
| **Size** | S |
| **Depends on** | T04 |
| **Delivers** | Transcript metrics (DRIFT) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The whole task is a boundary question: these six quantities are derived in `HunchCore` from a transcript, are **stored** (§7.10, §11.1) and must never become *displayable* values. The skill owns where a derived value lives and what it may not know about — and the reason this file must not gain a `description`, a `formatted()` or a `LocalizedStringResource` is its `HunchCore` boundary predicate, not taste. |

`hunch-chrome-and-meta` and `hunch-accessibility` are **not** loaded, deliberately: this task's product
is a value that nothing renders and nothing speaks. If a skill about rendering seems necessary, the
task has gone wrong.

## Objective

At the end of this task a settled DRIFT round derives its six transcript quantities — `t_hinge`,
`t_evidence`, `t_recover`, cling `C`, latency `R` and `deadDeclaration` — and emits exactly the triple
`(R, rec(b), deadDeclaration)`. §7.7's worked band-5 round reproduces end to end, `R = 16` against
`rec(5) = 9`, and a hygiene check proves none of the six can reach a `Text`, a label or the catalog.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.8 | The whole task: the six definitions verbatim, the rule that none is rendered, spoken or stored as a displayable value, the emission of `(R, rec(b), deadDeclaration)` at `settled`, and that `C` and `wasteRate` are harness-only and feed no axis |
| `GAME_DESIGN.md` | §7.7 | The worked transcript: hinge at probe 10, `t_evidence = 11`, `t_recover = 13`, `C = 2`, `t_seal = 27`, `R = 16`, `rec(5) = 9`, and the resulting 0.303 |
| `GAME_DESIGN.md` | §11.9 | The **owner** of the Flexibility sample: `clamp((2L*−L)/(1.5L*), 0, 1)` with `L = R` and `L* = 0.45·par(b)` on **canon's** par. This section supersedes any sample formula stated elsewhere |
| `GAME_DESIGN.md` | §7.10, §11.1 | The metrics *are* persisted — `t_hinge`, `t_evidence`, `t_recover` in the round record and `driftHinge` on the page — so "never stored" means never stored **as a displayable value** |
| `GAME_DESIGN.md` | §10.5 | Difficulty is never a number: exactly three signals, and none of them is a transcript metric |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B34a | The hygiene script's shape; this task appends check 13 |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/DriftTranscriptTests.swift`:

```swift
import Testing
@testable import Rounds
import LawGeneration
import Glyphs
import HunchTestSupport

@Suite("DRIFT's transcript metrics — §7.8", .tags(.unit, .presubmission))
struct DriftTranscriptTests {

    @Test("t_evidence is the first post-hinge probe whose verdict is inconsistent with L₁")
    func evidence() {
        let t = DriftTranscript(schedule: .fixture(.workedBandFive))
        #expect(t.hingeProbe == 10)
        #expect(t.evidenceProbe == 11)
    }

    @Test("t_evidence and t_recover test the same predicate — membership in D")
    func onePredicateTwoOccurrences() {
        let t = DriftTranscript(schedule: .fixture(.workedBandFive))
        #expect(t.probesInsideD.first == t.evidenceProbe)
        #expect(t.probesInsideD.dropFirst().first == t.recoveryProbe)
    }

    @Test("Cling is the run spent inside the agreement set after the first contradiction")
    func cling() {
        let t = DriftTranscript(schedule: .fixture(.workedBandFive))
        #expect(t.recoveryProbe == 13)
        #expect(t.cling == 2)                       // 13 − 11
        #expect(t.cling == t.recoveryProbe! - t.evidenceProbe!)
    }

    @Test("R is the sealing declaration's probe count minus t_evidence")
    func latency() {
        let t = DriftTranscript(schedule: .fixture(.workedBandFive))
        #expect(t.sealProbe == 27)
        #expect(t.latency == 16)
    }

    @Test("deadDeclaration latches on a post-hinge L₁ declaration and on nothing else")
    func deadDeclarationLatches() {
        #expect(DriftTranscript(schedule: .fixture(.workedBandFive)).deadDeclaration == true)
        #expect(DriftTranscript(schedule: .fixture(.cleanRecovery)).deadDeclaration == false)
        #expect(DriftTranscript(schedule: .fixture(.captureThenCleanWin)).deadDeclaration == false)
    }

    // MARK: the undefined cases, which are values and not zeros

    @Test("Never contradicted → t_evidence, t_recover, C and R are all nil")
    func neverContradicted() {
        let t = DriftTranscript(schedule: .fixture(.noPostHingeProbeInsideD))
        #expect(t.evidenceProbe == nil)
        #expect(t.recoveryProbe == nil)
        #expect(t.cling == nil)
        #expect(t.latency == nil)
    }

    @Test("Contradicted but never sealed after it → R is nil, C may still be defined")
    func capLossAfterEvidence() {
        let t = DriftTranscript(schedule: .fixture(.cappedOutAfterEvidence))
        #expect(t.evidenceProbe != nil)
        #expect(t.latency == nil)
    }

    @Test("An undefined R emits no Flexibility sample at all — it is not zero and not one")
    func noSampleWithoutLatency() {
        #expect(DriftTranscript(schedule: .fixture(.noPostHingeProbeInsideD)).profileEmission == nil)
    }

    @Test("The emission is the triple and nothing else")
    func emission() throws {
        let e = try #require(DriftTranscript(schedule: .fixture(.workedBandFive)).profileEmission)
        #expect(e.latency == 16)
        #expect(e.recoveryAllowance == 9)
        #expect(e.deadDeclaration == true)
        #expect(Mirror(reflecting: e).children.count == 3)
    }

    @Test("A hinge that never fired makes every downstream metric nil")
    func unfiredHinge() {
        let t = DriftTranscript(schedule: .fixture(.doubleStrikePreHinge))
        #expect(t.hingeProbe == nil)
        #expect(t.evidenceProbe == nil)
        #expect(t.profileEmission == nil)
    }

    @Test("The metrics carry no display affordance of any kind")
    func notDisplayable() {
        #expect((DriftTranscript.self as Any) is CustomStringConvertible.Type == false)
        #expect((DriftProfileEmission.self as Any) is CustomStringConvertible.Type == false)
    }
}
```

And `HunchCore/Tests/RoundsTests/WorkedDriftRoundTests.swift` — the epic's gate:

```swift
@Suite("§7.7's worked band-5 round, end to end", .tags(.unit, .presubmission))
struct WorkedDriftRoundTests {

    @Test("The transcript, the score, the marks and the Flexibility sample all reproduce")
    func workedRound() throws {
        let t = DriftTranscript(schedule: .fixture(.workedBandFive))

        // §7.8's quantities
        #expect(t.hingeProbe == 10)
        #expect(t.evidenceProbe == 11)
        #expect(t.recoveryProbe == 13)
        #expect(t.cling == 2)
        #expect(t.latency == 16)
        #expect(t.deadDeclaration == true)

        // §7.7's budget and score
        #expect(DriftBudget.par(.contextual) == 32)
        #expect(DriftBudget.recovery(.contextual) == 9)
        let result = DriftScore.settle(band: .contextual, probesUsed: 27, strikes: 1,
                                       latency: t.latency, outcome: .win)
        #expect(result.score == 600)
        #expect(result.marks == 2)
        #expect(result.fracture == true)

        // §11.9's sample, computed here ONLY until E16·T05 ships `FlexibilitySample`.
        // L* = 0.45 · par(5) = 0.45 · 23 = 10.35   ← canon's par, never par_DRIFT
        // (2·10.35 − 16) / (1.5·10.35) = 4.70 / 15.525 = 0.30273…
        let lStar = 0.45 * Double(Band.contextual.par(for: .probe))
        let sample = min(1.0, max(0.0, (2 * lStar - Double(t.latency!)) / (1.5 * lStar)))
        #expect(isApproximatelyEqual(sample, 0.303, absoluteTolerance: 0.0005))
    }

    @Test("Flexibility's L* uses canon's par, never par_DRIFT")
    func lStarUsesCanonPar() {
        #expect(Band.contextual.par(for: .probe) == 23)
        #expect(DriftBudget.par(.contextual) == 32)
        #expect(0.45 * 23.0 != 0.45 * 32.0)          // the two readings differ by 0.135 of a sample
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter DriftTranscript`
then `--filter WorkedDriftRoundTests`

Expect missing `DriftTranscript`, `DriftProfileEmission`, and the six `DriftSchedule` fixtures. Build
`.workedBandFive` from §7.7's transcript table literally — the probe list, the two laws and the seed
glyph are all printed there, so the fixture is a transcription exercise and the test is a real
reproduction rather than a restatement.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Then append check 13 to the hygiene script and prove it fails on a
planted `Text(verbatim: "\(transcript.latency)")` before reverting.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/DriftTranscript.swift` — the six derivations and `DriftProfileEmission` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — the six `DriftSchedule` fixtures, `.workedBandFive` transcribed from §7.7 |
| create | `HunchCore/Tests/RoundsTests/DriftTranscriptTests.swift` |
| create | `HunchCore/Tests/RoundsTests/WorkedDriftRoundTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — check 13 |
| modify | `tests.json` — the six metrics, the worked round, the no-display check |
| modify | `DECISIONS.md` — the undefined-`R` ruling and the temporary inline sample arithmetic |

## Implementation notes

### The shape

```swift
/// §7.8's quantities, derived from a settled DRIFT transcript. Every one is an `Int?` or a `Bool`,
/// and every one may legitimately be **undefined** — which is a value, not a zero.
public struct DriftTranscript: Sendable, Equatable, Codable {
    public let hingeProbe: Int?          // t_hinge — nil iff the hinge never fired
    public let evidenceProbe: Int?       // t_evidence
    public let recoveryProbe: Int?       // t_recover
    public var cling: Int? { … }         // C = t_recover − t_evidence — HARNESS ONLY, feeds no axis
    public let sealProbe: Int?           // the settling declaration's probe count
    public var latency: Int? { … }       // R = t_seal − t_evidence
    public let deadDeclaration: Bool

    public init(schedule: DriftSchedule)
    /// The only thing that leaves this type. §7.8: DRIFT emits `(R, rec(b), deadDeclaration)`; the
    /// mapping onto the Flexibility axis and the step size that applies it are §11.9's.
    public var profileEmission: DriftProfileEmission? { … }
}

public struct DriftProfileEmission: Sendable, Equatable {
    public let latency: Int              // §7.8's R
    public let recoveryAllowance: Int    // §7.7's rec(b)
    public let deadDeclaration: Bool
}
```

### One predicate, two occurrences

`t_evidence` is *"the first probe > `t_hinge` whose verdict is inconsistent with `L₁`"*, and `t_recover`
is *"the first probe > `t_evidence` lying inside `D`"*. Those are the **same test**: a probe's verdict
differs between the two laws exactly when its `(prev, cur)` lies in `D = T₁ △ T₂`. So compute the
membership list once —

```swift
let probesInsideD = probes.indices
    .filter { $0 > hingeProbe }
    .filter { pair.disagrees(on: probes.pair(at: $0)) }
```

— and read `t_evidence` off its first element and `t_recover` off its second. Deriving them by two
different-looking expressions is how they eventually disagree; the `onePredicateTwoOccurrences` test
above exists to pin the identity.

Note what this makes true of §7.7's worked transcript, and check it while implementing: probe 12 is a
twin of probe 11 with a different `prev`, and §7.7 annotates it *"consistent — but this pair is **not**
in `D`"*. It is the whole reason `C = 2` rather than `C = 1`, and it is the cleanest available test that
the predicate is over **pairs** in contextual bands and not over glyphs.

### When a metric is undefined, it is `nil`

Three cases, and each is a shipped test:

| Case | What is undefined | Why not a zero |
|---|---|---|
| The hinge never fired (DOUBLE-STRIKE-PRE-HINGE) | everything downstream | there was no second law in force to be contradicted by |
| No post-hinge probe lies in `D` (DEAD-HINGE's probe half) | `t_evidence`, `t_recover`, `C`, `R` | the player was never contradicted, so "how fast they abandoned a dead theory" has no referent |
| Contradicted, then capped out with no further declaration | `R` only | there is no `t_seal` |

**A `nil` R emits no Flexibility sample.** `R = 0` would credit maximum flexibility to a player who was
never shown that anything had changed, and any large substitute would penalise them for the same. §11.9
gives no rule for an undefined `L`, so the honest reading is that DRIFT simply does not sample the axis
that round — Induction and Restraint still do. Record it in `DECISIONS.md` and flag it in the epic's
open questions; it is the one place this task extends the spec rather than implementing it.

`t_seal` is the **settling** declaration's probe count: the winning `L₂` declaration, or the second
strike. A capture is not a settling declaration and never sets it. Neither is a first strike.

### `C` and `wasteRate` are harness-only

§7.8 is explicit: they *"are retained for the simulated-player harness only and feed no axis"*. So they
are `public` (E11·T11's `ReasonerHarness` reads them) and they are **absent from
`DriftProfileEmission`**, which is exactly three fields — the `Mirror` assertion above is a blunt but
effective way of saying a fourth may not be added quietly.

### "Never rendered, spoken or stored as a displayable value"

The metrics *are* persisted — §7.10 lists `t_hinge`, `t_evidence`, `t_recover` in the round record and
§11.1 puts `driftHinge` on the Codex page — so the rule is not *never stored*, it is **never stored as
something a surface can show**. Two mechanisms:

1. **No display affordance on the type.** No `CustomStringConvertible`, no `description`, no
   `formatted()`, no `LocalizedStringResource`, no `Text` initialiser anywhere near it. `HunchCore`
   cannot import SwiftUI anyway; this rule closes the `String` route as well.
2. **Hygiene check 13**, appended to `Scripts/check-source-hygiene.sh`:

   ```bash
   # 13 — no DRIFT transcript metric may reach a rendered or spoken string (§7.8)
   METRICS='tHinge|hingeProbe|tEvidence|evidenceProbe|tRecover|recoveryProbe|cling|latency|deadDeclaration'
   if grep -rnE "(Text\(|Label\(|accessibilityLabel\(|accessibilityValue\()[^)]*($METRICS)" \
        Modules/Sources App; then
     echo "check 13: a DRIFT transcript metric reaches a string (GAME_DESIGN.md §7.8)"; exit 1
   fi
   grep -qE '"(tHinge|cling|latency|deadDeclaration|flexibility)"' \
        Modules/Sources/HunchUI/Resources/Localizable.xcstrings && { echo "check 13: catalog key"; exit 1; }
   ```

   The check deliberately permits `hingeProbe` as a **geometric** input — T08's seam sweep stops at it
   and the split forks there — because that use is a position, not a readout. What it forbids is the
   value reaching a string. Prove it fails on a planted violation before reverting.

### The Flexibility sample is §11.9's, and the inline arithmetic is temporary

`WorkedDriftRoundTests` computes `clamp((2L*−L)/(1.5L*), 0, 1)` inline because E16·T05 does not exist
yet and the epic's gate names 0.303. That is a **second copy of a formula §11.9 owns**, and it must be
labelled as such:

- the expression carries a comment naming §11.9 and E16·T05 as the owner;
- `DECISIONS.md` records that it exists and must be deleted when `FlexibilitySample` lands;
- E16·T05's task file already owns the axis, so its own worked-value test will assert the same 0.303 —
  and when it does, this arithmetic is replaced by a call and the expected number does not move.

Nothing in `HunchCore/Sources` may contain that expression. It lives only in the test.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DriftTranscriptTests` and `--filter WorkedDriftRoundTests` green.
- [ ] §7.7's worked round reproduces every printed number: `t_hinge = 10`, `t_evidence = 11`, `t_recover = 13`, `C = 2`, `R = 16`, `rec(5) = 9`, score 600, 2 marks, fractured, sample 0.303.
- [ ] `Scripts/check-source-hygiene.sh` check 13 exists, is wired into CI and the build phase, and was demonstrated to fail on a planted `Text(verbatim:)` violation.
- [ ] `grep -rn "0.45\|1.5 \*\|2 \* lStar" HunchCore/Sources Modules/Sources` returns nothing — the sample formula is not in shipped code.
- [ ] `grep -n "CustomStringConvertible\|description\|formatted" HunchCore/Sources/Rounds/DriftTranscript.swift` returns nothing.
- [ ] `DriftProfileEmission` has exactly three stored properties.
- [ ] `DECISIONS.md` records the undefined-`R` ruling and the temporary inline arithmetic with its deletion condition.
- [ ] `tests.json` carries the three entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T07: the six DRIFT transcript metrics, the (R, rec, deadDeclaration) emission and hygiene check 13"`

## Out of scope

- The Flexibility sample formula, `L*`, the update rule and `α` — **§11.9 / E16·T05/T06**.
- Induction's and Restraint's samples from a DRIFT round — **E16·T05**.
- `H_live` and the Restraint margin, which is skipped at bands 5 and 7 — **E16·T07**.
- Persisting the metrics into `round-drift.json` and onto the Codex page — **T09** and **E09·T11**.
- `wasteRate`'s use by the Level-B harness — **E11·T11**.
- Any surface that could show a metric. There is none, and adding one is the failure this task prevents.
