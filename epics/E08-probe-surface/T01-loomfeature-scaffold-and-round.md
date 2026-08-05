# T01 — LoomFeature scaffold and Round

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (E04 and E07 are merged) |
| **Delivers** | §14.1 PROBE → *Round state machine* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task creates a target and the one class in it. §1's boundary predicate decides that `Round` is app-layer while its phase table is core; §2's naming pass fixes the name as the bare domain noun `Round` and bans `RoundViewModel`; `04 A18`/`A19`/`A20` decide how thin it has to be. |
| `hunch-swift-concurrency` | `LoomFeature` is one of the five targets that take `.defaultIsolation(MainActor.self)`, `Round` is on the `@MainActor` roster, and the "where mutable state goes" ladder is what justifies a class here at all rather than a value threaded through a call. |

## Objective

`Modules/Sources/LoomFeature/` exists and contains `Round` — a `@MainActor @Observable final class` that owns one round's live state and delegates every rule to `HunchCore`. At the end of this task a test can construct a round, feed it glyphs, and read back a ribbon, a phase, a probe count and a score, with no view, no clock, no disk and no simulator involved.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.1 | The eight phases, the five outcomes, the transition table, and the two invariants: the model never waits on an animation, and no wall-clock quantity affects score, marks or the Rasch update |
| `GAME_DESIGN.md` | §6.4 | `verdict(cur) = law.evaluate(cur, prev)`; `prev(1) = seedGlyph`, primed and not a probe; `prev(n)` is the previously **probed** glyph regardless of verdict |
| `GAME_DESIGN.md` | §6.9 | Scoring and marks — read from `HunchCore`, never recomputed here |
| `GAME_DESIGN.md` | §6.11 cases 1–4 | Declare at probe 0, twin at probe 0, non-adjacent repeat, cap reached on an admit |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §3, §4, §7.8 | The tree, the boundary rule's "`RoundPhase` looks app-layer and is core" row, the `Round` naming ruling, the `@MainActor` roster, and A18's earned exception |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A18, A19, A20 | When a screen-scoped observable is earned; the pass-through test; extract the logic and test *that* |
| `ios-swift-guide/05-CONCURRENCY.md` | R7, R8, R17 | Default isolation per target; write `@MainActor` explicitly on anything visible outside its file |

Never restate a value the spec owns: par, cap, the mark thresholds and the score formula all come from `HunchCore` (E06·T07).

## TDD — the test comes first

**Step 1 — write the failing test.**

First, the one fixture file the whole epic shares. Create `Modules/Sources/ModulesTestSupport/Fixtures.swift` (a `.target`, absent from `products:`, exactly as `HunchTestSupport` is on the core side — `06 T5a`):

```swift
// Modules/Sources/ModulesTestSupport/Fixtures.swift
import HunchCore

/// The one place in `Modules/` that builds a `LawNode` by hand.
/// If an initialiser signature differs from what E05 shipped, fix it HERE and nowhere else.
public enum Fixtures {
    /// §12.5's fixed opening law: `shape ∈ {triangle}` at band 1. The only law written down in the
    /// GDD, so it needs no generator and no seed.
    public static let openingLaw = Law(LawNode.atom(attribute: .shape, admits: [.triangle]))

    /// §12.5's seed glyph — `glyphID` 22, hollow triangle, two pips.
    public static let seedGlyph = Deck.glyph(id: 22)

    /// A law that is contextual, for the twin and split-ring cases: `RANK pips(cur) > PREV RANK pips`.
    public static let contextualLaw = Law(
        LawNode.contextual(attribute: .pips, comparator: .gt, previous: .pips)
    )

    @MainActor
    public static func round(
        law: Law = openingLaw,
        band: Band = .literal,
        seedGlyph: Glyph = seedGlyph
    ) -> Round {
        Round(law: law, band: band, mode: .probe, seedGlyph: seedGlyph,
              seed: 0x4855_4E43_48, targetDelta: band.difficultyRange.lowerBound)
    }
}
```

`Modules/Sources/ModulesTestSupport/Tags.swift` mirrors the eight `@Tag static var` declarations from `HunchTestSupport` — kind (`unit`, `integration`, `snapshot`, `ui`, `performance`) and cadence (`presubmission`, `nightly`, `prerelease`). `HunchTestSupport` is absent from `HunchCore`'s `products:`, so `Modules/` cannot import it; `06 T29` treats same-named tags in different modules as equivalent, which is what keeps `-only-testing-tags presubmission` selecting both packages.

Then create `Modules/Tests/LoomFeatureTests/RoundTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import LoomFeature

@Suite("Round — the screen-scoped machine", .tags(.unit, .presubmission))
@MainActor
struct RoundTests {

    @Test("A fresh round is probing, empty, and already holding the seed glyph")
    func freshRound() {
        let round = Fixtures.round()
        #expect(round.phase == .probing)
        #expect(round.probesUsed == 0)
        #expect(round.ribbon.probes.isEmpty)
        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.strikes == 0)
    }

    @Test("The verdict is committed synchronously, at t = 0 of the beat")
    func verdictCommitsBeforeAnyAnimation() {
        let round = Fixtures.round()
        let triangle = Deck.glyph(id: 22)

        round.probe(triangle)

        // The model never waits on an animation (§6.1). One statement later the probe is in.
        #expect(round.probesUsed == 1)
        #expect(round.ribbon.probes.count == 1)
        #expect(round.ribbon.probes[0].glyph == triangle)
        #expect(round.ribbon.probes[0].verdict == Fixtures.openingLaw.admits(triangle,
                                                                             after: Fixtures.seedGlyph))
        #expect(round.phase == .adjudicating(round.ribbon.probes[0].verdict))
    }

    @Test("`prev` is the previously probed glyph, regardless of that probe's verdict")
    func previousIsTheLastProbedGlyph() {
        let round = Fixtures.round(law: Fixtures.contextualLaw, band: .contextual)
        let first = Deck.glyph(id: 0)      // whatever it is, it is `prev` for the second probe
        let second = Deck.glyph(id: 200)

        round.probe(first)
        round.endVerdictBeat()
        round.probe(second)

        #expect(round.ribbon.probes[0].verdict
                == Fixtures.contextualLaw.admits(first, after: Fixtures.seedGlyph))
        #expect(round.ribbon.probes[1].verdict
                == Fixtures.contextualLaw.admits(second, after: first))
    }

    @Test("Score and marks are read from HunchCore, never recomputed on the screen")
    func scoringDelegates() {
        let round = Fixtures.round()
        for _ in 0..<3 {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        let expected = Score(probesUsed: round.probesUsed, par: round.band.par(for: .probe), strikes: 0)
        #expect(round.score == expected.points)
        #expect(round.marks == expected.marks)
    }

    @Test("The cap-th verdict resolves in full, then the round is exhausted",
          arguments: [Band.literal, Band.contextual, Band.systemic])
    func capEndsTheRoundAfterTheVerdict(_ band: Band) {
        let round = Fixtures.round(band: band)
        let cap = band.cap(for: .probe)

        for index in 0..<cap {
            round.probe(Deck.glyph(id: UInt8(index % 256)))
            #expect(round.ribbon.probes.count == index + 1)      // a paid-for bit is never withheld
            round.endVerdictBeat()
        }

        #expect(round.probesUsed == cap)
        #expect(round.phase == .revealing(.exhausted))
    }

    @Test("Probing is refused once the round has left `probing`")
    func probingIsRefusedOutsideProbing() {
        let round = Fixtures.round(band: .literal)
        for _ in 0..<round.band.cap(for: .probe) {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        let settled = round.probesUsed
        round.probe(Fixtures.seedGlyph)
        #expect(round.probesUsed == settled)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/RoundTests
```

It must fail on `cannot find 'Round' in scope` / `no such module 'LoomFeature'`, not on a malformed suite. If it fails because `Fixtures` does not compile, fix `Fixtures.swift` against the shipped `LawNode` API and re-run — that file is expected to need one adjustment, and it is the only one.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Package.swift` |
| create | `Modules/Sources/LoomFeature/Round.swift` |
| create | `Modules/Sources/ModulesTestSupport/Fixtures.swift` |
| create | `Modules/Sources/ModulesTestSupport/Tags.swift` |
| create | `Modules/Tests/LoomFeatureTests/RoundTests.swift` |
| modify | `DECISIONS.md` |
| modify | `SPEC.md` |

## Implementation notes

**The manifest.** `LoomFeature` is a new target in `Modules/Package.swift` with `.defaultIsolation(MainActor.self)` — it declares views and owns state a view reads (`01 P17`, `05 R7`, `08 §4`). It depends on `HunchCore` and `HunchUI`. `ModulesTestSupport` is a plain `.target` and **must not** appear in `products:`; `LoomFeatureTests` depends on it and on `LoomFeature`.

**Why a class at all.** `04 A18`'s triggers 1 and 2 both fire: the round is an eight-phase machine with locked-input windows, two strikes, a Bench draft and a snapshot written after every verdict, and that state is read by four sibling views (throat, Dial, ribbon, instrument bar) that must agree on it frame by frame. That is the *earned* screen-scoped observable. `A19`'s pass-through test still has to pass: delete `Round` and the phase timing, the input lock and the snapshot cadence all break — the phase *table*, the ribbon and the score do not, because they are `HunchCore`'s.

**The shape.**

```swift
// Modules/Sources/LoomFeature/Round.swift
import HunchCore
import Observation

/// One live PROBE round. Thin over `HunchCore`: this type owns *when* things happen on a screen,
/// never *what* they mean. Phases come from `RoundPhase.advance(_:on:)`, verdicts from
/// `Law.admits(_:after:)`, scoring from `Score`. `04 A18` trigger 1+2; see `DECISIONS.md`.
@MainActor
@Observable
public final class Round {
    public let law: Law
    public let band: Band
    public let mode: Mode
    public let seedGlyph: Glyph
    public let seed: UInt64
    public let targetDelta: Double

    public private(set) var phase: RoundPhase
    public private(set) var ribbon: Ribbon
    public private(set) var strikes: Int = 0

    /// The throat *is* the draft (§6.3). Starts at the seed glyph so probe 1 is one tap.
    public private(set) var draft: Glyph

    public var probesUsed: Int { ribbon.probes.count }
    public var previousGlyph: Glyph { ribbon.probes.last?.glyph ?? seedGlyph }

    public init(law: Law, band: Band, mode: Mode, seedGlyph: Glyph,
                seed: UInt64, targetDelta: Double) { … phase = .probing; draft = seedGlyph … }

    /// Feed the Loom. One probe, one verdict, committed here and displayed later.
    public func probe(_ glyph: Glyph) {
        guard phase == .probing else { return }
        let verdict = law.admits(glyph, after: previousGlyph)
        let isTwin = ribbon.probes.last?.glyph == glyph        // adjacency only — §6.11 case 3
        commit(Probe(glyph: glyph, verdict: verdict, isTwin: isTwin))
    }

    /// **The one point at which round state becomes true.** Everything downstream — the beat, the
    /// cue, the snapshot (E10·T02), the announcement — hangs off this call and off nothing else.
    private func commit(_ probe: Probe) {
        ribbon.append(probe)
        phase = RoundPhase.advance(phase, on: .verdict(probe.verdict))
        if probesUsed >= band.cap(for: .probe) { pendingExhaustion = true }
    }

    /// Called by the verdict beat when its input lock expires (T06 owns the clock).
    public func endVerdictBeat() {
        guard case .adjudicating = phase else { return }
        phase = pendingExhaustion
            ? RoundPhase.advance(phase, on: .capReached)
            : RoundPhase.advance(phase, on: .beatCompleted)
    }
}
```

Four things this sketch is careful about:

1. **`RoundPhase.advance` is E07·T07's pure function** and is the only writer of a transition. If a transition you need is missing from its exhaustive `switch`, add it *there* with its test, not with an `if` here. The event case names above (`.verdict`, `.beatCompleted`, `.capReached`) are indicative — use whatever E07·T07 shipped.
2. **`endVerdictBeat()` is public in this task and gets a timer in T06.** Exposing the beat's end as a method is what makes the phase machine testable with no `Task.sleep` (`06 T27` bans sleeping in a test). T06 adds the `Task` that calls it; it does not change the signature.
3. **`pendingExhaustion` exists because §6.11 case 4 is explicit**: the cap-th verdict is delivered in full and *then* the round ends. Transitioning to `revealing(.exhausted)` inside `commit` would swallow the last bit the player paid for.
4. **`isTwin` is adjacency, not equality.** §6.11 case 3: a non-adjacent repeat is drawn normally with no doubled ring. This is E07·T08's semantics; if `Ribbon.append` already computes it, delete the local and use that — one home.

**What `Round` must not grow.** No `Date()`, no `UUID()`, no RNG, no `PersistenceStore` call, no `Task.sleep`, no view type, no formatting, no `Text`. Score and marks are computed properties over `Score` (E06·T07). The Bench draft lands in E09·T01 as a `BenchLayout?` property and nothing more.

**Explicit `@MainActor` on every declaration visible outside the file** (`05 R8`), even though the target's default isolation already supplies it — the declaration has to read correctly without knowing the build setting. Note that `.defaultIsolation` does **not** reach the test target, which is why the suite above is annotated `@MainActor` (`06 T9`).

**`DECISIONS.md` gets one entry** and it needs both halves: *why an observable is allowed here* (A18 triggers 1 and 2, named) and *why it is called `Round`* (`N40`/`08 §3` — the round is the thing; `RoundViewModel` is banned by `A19` and `N40` together). Record the pass-through argument in one sentence so a future reviewer does not have to re-derive it.

## Acceptance criteria

- [ ] `swift build --package-path Modules` succeeds and `Modules/Package.swift` shows `LoomFeature` with `.defaultIsolation(MainActor.self)` and `ModulesTestSupport` absent from `products:`.
- [ ] `xcodebuild … -only-testing:LoomFeatureTests/RoundTests` is green, all seven cases.
- [ ] `grep -rn 'RoundViewModel\|ViewModel' Modules/Sources` returns nothing.
- [ ] `grep -n 'class\|actor' Modules/Sources/LoomFeature/Round.swift` shows exactly one type and it is `@MainActor @Observable final class Round`.
- [ ] `grep -rn 'Date()\|UUID()\|\.random\|Task.sleep\|PersistenceStore' Modules/Sources/LoomFeature/Round.swift` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` passes (checks 3 and 6 in particular — no new escape hatch, no ambient nondeterminism).
- [ ] `DECISIONS.md` contains the `Round` entry naming A18's two triggers and the `N40` bare-domain-noun ruling; `SPEC.md` records `Round.commit(_:)` as the single point at which round state becomes true.

## Close the task

1. `swift test --package-path HunchCore` green and the fast suite still under 10 s; the `LoomFeatureTests` filter green in the simulator.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T01: LoomFeature target and Round, thin over HunchCore's phase machine"`

## Out of scope

- The verdict **beat** — the 420 / 320 ms lock, the 260 ms hold and the single-slot queue are **T06**; this task only exposes `endVerdictBeat()` for it to drive.
- Any view. `RoundView` is **T02**.
- The snapshot write. `Round.commit` is where **E10·T02** hangs it; this task writes nothing to disk.
- `AppDependencies` and the environment wiring — **E10·T01**.
- The declaration half: strikes are a stored property here, but `seal()`, `SealBar`, the counterexample and the reveal are **E09**.
- `RoundPhase`, `Probe`, `Ribbon`, `Score` themselves — **E07·T07–T08**. If one of them is missing behaviour you need, add it there, with its test, in a separate commit.
