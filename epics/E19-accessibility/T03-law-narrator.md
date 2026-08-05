# T03 — `LawNarrator`

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | `LawNarrator` (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | Owns the ruling that makes this task possible at all: **`LawNarrator` cannot return a `String` from `HunchCore`**, because a localized lookup needs a bundle and `08 §2` bans bundles from the core. `references/voiceover-elements.md` §10 gives the value-tree shape, the rejected alternative and the exact parity test, and states the never-a-hidden-law rule this task has to assert. |
| `hunch-swift-testing` | Owns the deliberate `T21` deviation this test *is*: parameterise over the eight bands, loop 1,250 laws inside, and pay `T21`'s protection back with a reproducing seed and an `Attachment.record` in every failure. It also owns the ten-second budget this test has to fit inside. |
| `hunch-swift-code` | `08 §3`'s naming pass: `…Narrator` is an `N26` service-object ban, in the same family as `AudioManager` and `CodexManager`, and a value-preserving conversion drops the label (`N14`) exactly as `Bench.layout(for:)` became `BenchLayout.init(_:)`. The §14.1 row is called `LawNarrator`; the shipped type is not. |

## Objective

At the end of this task a law speaks as **one localized sentence** — *"Pips of this glyph is greater
than pips of the previous glyph, and shape admits triangle or hexagon."* — built in `HunchCore` as a
pure value tree and rendered in `HunchUI` from the same String Catalog fragments the Codex page
renders from, so a narrated law and a rendered law are the same law in two media. It describes only
the player's own draft or an already-revealed law, never a hidden law mid-round, and the parity
invariant is asserted by walking 10,000 generated laws.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.10 (The Bench narration) | one localized sentence; the same catalog fragments as the Codex page; only the player's draft or an already-revealed law; the 10,000-law parity invariant, stated as *`parse(Bench.layout(for: law))` and `narrate(law)` describe the same extension* |
| `GAME_DESIGN.md` | §13.12 gate 7 | "The Bench narration matches the rendered tiles for 10,000 generated laws (automated parity test)" |
| `GAME_DESIGN.md` | §3.2, §3.3, §3.4 | the BNF's five productions, the exhaustive predicate inventory and the combinators — the five `Narration` cases are in bijection with them |
| `GAME_DESIGN.md` | §3.6 | RNF: the narration is built from the rendered normal form, so folded-away terms are not narrated |
| `GAME_DESIGN.md` | §4.4 | expressiveness parity — the Bench and the grammar are the same language, which is what makes "the words mean the tiles" checkable |
| `GAME_DESIGN.md` | §12.9 trap 3 | one format string per sentence; the coupler is `"%1$@, and %2$@"` and never a `+` |
| `.claude/skills/hunch-accessibility/references/voiceover-elements.md` | §10 | the `Narration` enum, `loc.narration(_:)`, the rejected `-> String` alternative, the parity test's exact shape |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §3, §5 | the boundary rule; `N14`/`N26`; the `T21` deviation and the 10-second budget |

## TDD — the test comes first

**Step 1 — write the failing test.** Three files.

`HunchCore/Tests/LawsTests/NarrationTests.swift` — the value tree, on the host, no catalog:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Narration — the value tree", .tags(.unit, .presubmission))
struct NarrationTests {

    @Test("an atom narrates its attribute and the ranks it admits, in ascending rank order")
    func atomNarratesItsSubset() {
        let law = LawNode.atom(.shape, admits: [4, 2])                 // hexagon, triangle
        #expect(Narration(law) == .atom(.shape, admits: [2, 4]))
    }

    @Test("a relational node keeps its comparator and says whether it is contextual")
    func relationKeepsItsComparator() {
        let contextual = LawNode.relation(.pips, .gt, contextual: true)
        #expect(Narration(contextual) == .relation(.pips, .gt, contextual: true))
        let stateless = LawNode.relation(.pips, .gt, contextual: false)
        #expect(Narration(stateless) == .relation(.pips, .gt, contextual: false))
        #expect(Narration(contextual) != Narration(stateless))          // "previous glyph" is not decoration
    }

    @Test("the narration is built from the RENDERED NORMAL FORM, so a folded term is never narrated")
    func foldedTermsAreDropped() {
        let redundant = LawNode.coupled(.and,
                                        .atom(.shape, admits: [1, 2, 3, 4]),   // ⊤ — folds away
                                        .atom(.fill,  admits: [4]))
        #expect(Narration(redundant) == Narration(redundant.renderedNormalForm))
        #expect(Narration(redundant) == .atom(.fill, admits: [4]))
    }

    @Test("narration is invariant under RNF: two spellings of one law narrate identically",
          arguments: Corpora.equivalentLawPairs)
    func narrationIsSpellingInvariant(_ pair: Corpora.LawPair) {
        #expect(Narration(pair.a) == Narration(pair.b))
    }

    @Test("a coupled node's children are in RNF's commutative order, so the sentence is stable")
    func coupledChildrenAreOrdered() {
        let a = LawNode.coupled(.or, .atom(.hue, admits: [1]), .atom(.fill, admits: [4]))
        let b = LawNode.coupled(.or, .atom(.fill, admits: [4]), .atom(.hue, admits: [1]))
        #expect(Narration(a) == Narration(b))
    }

    @Test("Narration is Hashable and Sendable and holds no reference type")
    func narrationIsAValue() {
        let n = Narration(LawNode.atom(.fill, admits: [1]))
        #expect(Set([n, n]).count == 1)
    }
}
```

`HunchCore/Tests/LawsTests/NarrationParityTests.swift` — **gate 7**, the 10,000-law walk:

```swift
import Foundation
import Testing
import Bench
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Narration parity — §13.12 gate 7", .tags(.unit, .presubmission))
struct NarrationParityTests {

    /// `06 T21` bans loops in tests; `08 §7.4` already ruled on this exact tension. Parameterising
    /// over `Band.allCases × 0..<1_250` is 10,000 runner nodes that cost more than the assertions.
    /// So: parameterise over the bands, loop inside, and pay T21 back with a reproducing seed and an
    /// Attachment in every failure. 8 × Corpora.narrationLawsPerBand = 10,000.
    @Test("the narration says nothing a sighted player cannot read off the tiles",
          arguments: Band.allCases)
    func narrationMatchesTheRenderedTiles(_ band: Band) throws {
        for index in 0..<Corpora.narrationLawsPerBand {
            let seed = Corpora.seed(band: band, index: index)
            let law = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
            let parsed = try #require(LawNode(BenchLayout(law)))        // value-preserving both ways (N14, G10)

            let failure: String? =
                if LawTable(parsed) != LawTable(law) { "the tiles do not mean the law" }
                else if Narration(parsed) != Narration(law.renderedNormalForm) { "the words do not mean the tiles" }
                else { nil }

            guard let failure else { continue }
            Attachment.record(law, named: "narration-b\(band.rawValue)-index\(index).json")   // 06 T18a
            Issue.record("\(failure) — reproduce with Corpora.seed(band: .\(band), index: \(index))")
            return                                                     // one named seed is enough
        }
    }

    @Test("every promoted parity failure stays a permanent case", arguments: Corpora.knownBadNarrationSeeds)
    func promotedFailuresStayFixed(_ seed: Corpora.BadSeed) throws {
        let law = generate(seed: seed.value, band: seed.band, targetDelta: seed.targetDelta, mode: seed.mode)
        let parsed = try #require(LawNode(BenchLayout(law)))
        #expect(Narration(parsed) == Narration(law.renderedNormalForm))
    }
}
```

`Modules/Tests/LoomFeatureTests/BenchNarrationTests.swift` — the rule that the narration never
describes a hidden law:

```swift
import Foundation
import Testing
import HunchCore
@testable import LoomFeature

@Suite("The narration describes only the player's own law — §13.10", .tags(.unit, .presubmission))
struct BenchNarrationTests {

    @Test("the revealed narration is nil in every phase before .revealing", arguments: RoundPhase.allCases)
    func hiddenLawIsNeverNarrated(_ phase: RoundPhase) {
        let round = Round.preview(phase: phase)
        if case .revealing = phase {
            #expect(round.revealedNarration != nil)
        } else {
            #expect(round.revealedNarration == nil, "\(phase) exposed the hidden law")
        }
    }

    @Test("the Bench narration is derived from the DRAFT and moves when the draft moves")
    func benchNarrationFollowsTheDraft() {
        let round = Round.preview(phase: .probing)
        #expect(round.benchNarration == nil)                        // an empty Bench narrates nothing
        round.place(.ramp(.init(attribute: .shape, admits: [2, 4])), onRail: 0)
        #expect(round.benchNarration == Narration(LawNode.atom(.shape, admits: [2, 4])))
    }

    @Test("the Bench narration never equals the hidden law's narration by construction, only by coincidence")
    func benchNarrationIsNotAChannel() {
        let round = Round.preview(phase: .probing)
        // The draft is empty; the hidden law is a band-5 contextual. Nothing on the Bench can leak it.
        #expect(round.benchNarration == nil)
        #expect(round.revealedNarration == nil)
    }
}
```

**Step 2 — run it and watch it fail.** 

```
swift test --package-path HunchCore --filter NarrationTests
swift test --package-path HunchCore --filter NarrationParityTests
swift test --package-path Modules   --filter BenchNarrationTests
```

Expect missing `Narration`, `Corpora.narrationLawsPerBand`, `Corpora.knownBadNarrationSeeds`,
`Round.revealedNarration`, `Round.benchNarration`. The trap: `hiddenLawIsNeverNarrated` passes
trivially if `revealedNarration` is a stored `nil` — so before implementing, confirm the `.revealing`
branch **fails**, which is what proves the property is being measured rather than asserted into
existence.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/Narration.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `narrationLawsPerBand`, `knownBadNarrationSeeds`, `equivalentLawPairs` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — `narration(_:)` and the per-node format strings |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `benchNarration`, `revealedNarration` |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the Bench container's `accessibilityValue`; each rail's value |
| modify | `Modules/Sources/LoomFeature/InscriptionView.swift` — the revealed tiles' container value |
| modify | `Modules/Sources/CodexFeature/CodexPageView.swift` — the page's container value, **the same function** |
| create | `HunchCore/Tests/LawsTests/NarrationTests.swift` |
| create | `HunchCore/Tests/LawsTests/NarrationParityTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/BenchNarrationTests.swift` |
| modify | `tests.json` — the gate-7 entry |
| modify | `DECISIONS.md` — the `Narration`-not-`LawNarrator` naming, and the budget mitigation if it fires |

## Implementation notes

### Why the type is not called `LawNarrator`, and why it returns no `String`

Two independent rules, and each one alone would be enough:

- **`08 §2`'s boundary rule.** A file may live in `HunchCore` iff it imports nothing but
  `Swift`/`Foundation` **and** its behaviour is a pure function of values you can write down in a
  test — "no file path, no bundle". A localized lookup needs a bundle. So the core emits a **value
  tree** and `HunchUI` renders it.
- **`08 §3`'s naming pass.** `…Narrator` is an `N26` service-object ban, the same shape `AudioManager`
  and `CodexManager` are rejected for; and a value-preserving conversion drops the label (`N14`), which
  is why `Bench.layout(for:)` became `BenchLayout.init(_:)`. The conversion `LawNode → Narration` takes
  the same shape: `Narration.init(_ law: LawNode)`.

There is also a third reason, and it is the one that matters most to this epic: **it is what makes the
parity test a value comparison.** `Narration(parsed) == Narration(law.renderedNormalForm)` runs under
`swift test` with no simulator and no catalog, and it tests **all twelve locales at once**, because it
never touches a translation. The rejected alternative — `LawNarrator.narrate(_:) -> String` in
`HunchCore` — would compare *rendered English* and leave eleven locales untested by the one test whose
whole job is to prove the narration faithful.

Record the naming in `DECISIONS.md`, because §14.1's row is called `LawNarrator` and a reader will
otherwise go looking for a type that does not exist.

### The value tree

```swift
// HunchCore/Sources/Laws/Narration.swift — pure over values. No Foundation bundle, no locale.
public indirect enum Narration: Hashable, Sendable {
    case atom(Glyph.Attribute, admits: [Int])                     // "shape admits triangle or hexagon"
    case relation(Glyph.Attribute, Comparator, contextual: Bool)  // "pips of this glyph is greater than …"
    case guarded(gate: Narration, then: Narration, else: Narration)
    case aggregate(Glyph.Attribute, counts: [Int])
    case coupled(Coupler, Narration, Narration)

    public init(_ law: LawNode) { … }                             // reads the RNF; drops folded-away terms
}
```

Five cases against the BNF's five productions — that bijection is the reason a new grammar production
becomes a compile error here rather than a silently unnarrated law. Three construction rules:

1. **Build from `law.renderedNormalForm`, always.** RNF is idempotent and gives one law exactly one
   layout (E05·T04), so it is also what gives one law exactly one sentence. A narration built from an
   un-normalised node would narrate terms the Bench does not draw.
2. **`admits:` and `counts:` are sorted ascending by rank**, so "triangle or hexagon" never comes out
   as "hexagon or triangle" for the same law spelled two ways.
3. **`relation`'s `contextual` flag is not decoration.** It selects a different format string —
   "of the previous glyph" — and the eight symmetric contextual forms would otherwise narrate
   identically with `cur` and `prev` transposed, which is the same failure G10 avoids by being
   node-identical rather than extension-identical (E06·T04).

`LawNode.init?(_ layout:)` is failable, so the parity test uses `try #require`, not `!`.

### Rendering: one format string per node, and the same one twice

```swift
// Modules/Sources/HunchUI/Loc.swift
public func narration(_ n: Narration) -> String {
    switch n {
    case let .atom(attribute, admits):
        String(localized: "NARRATION_ATOM",
               defaultValue: "\(name(attribute)) admits \(valueList(attribute, admits))",
               bundle: bundle, locale: locale)
    case let .coupled(coupler, lhs, rhs):
        // "%1$@, and %2$@" — one format string, children interpolated. NEVER a `+`.
        String(localized: couplerKey(coupler),
               defaultValue: "\(narration(lhs)), and \(narration(rhs))",
               bundle: bundle, locale: locale)
    …
    }
}
```

`valueList(_:_:)` joins the admitted value names with **the locale's own list grammar**
(`.formatted(.list(type: .or, width: .standard).locale(locale))`), for exactly the reason T02's terse
form does: an enumeration is not a sentence, and `joined(separator: ", ")` is trap 3 wearing a comma.

**`CodexPageView` and `BenchView` call the same function on the same value.** That is not a
convention, it is the mechanism: §13.10's *"a narrated law and a rendered law are the same law in two
media"* is true because there is one `narration(_:)` and one `Narration`, and it stops being true the
moment a second renderer appears. The acceptance criteria grep for exactly one definition.

### `Round`'s two narration properties

```swift
// Modules/Sources/LoomFeature/Round.swift
/// The player's own draft. nil while the Bench is empty.
var benchNarration: Narration? { benchLayout.flatMap(LawNode.init(_:)).map(Narration.init) }

/// The hidden law — and ONLY after it has been revealed. The `switch` is exhaustive with no
/// `default:` (W29), so a new phase is a compile error here rather than a leak.
var revealedNarration: Narration? {
    switch phase {
    case .revealing, .settled: Narration(law.node)
    case .idle, .arming, .probing, .adjudicating, .declaring, .sealing: nil
    }
}
```

The rule is structural: `benchNarration` is built from a `LawNode` **the player owns**, and the round
model never hands `Narration.init` the hidden one outside those two phases. The test walks every
`RoundPhase` case, so adding a phase without deciding this question fails the build.

Two announcements consume `revealedNarration` — "Probe limit reached. Round over. The law was:
{narration}." and "Incorrect. Round over. The law was: {narration}." — and both are T05's; they are
listed here only so that nobody wires a third consumer from a phase where the property is `nil` and
concludes the narration is broken.

### The ten-second budget

This suite generates 10,000 laws, and E06·T09's guardrail suite already generates 10,000. Measure
before and after:

```bash
START=$SECONDS; swift test --package-path HunchCore; echo "$((SECONDS-START))s"
```

If the fast suite crosses 10 s, **do not** move this test to nightly — gate 7 is a presubmission gate.
Share the corpus instead: promote `Corpora.laws(band:)` to a `static let` of immutable `Sendable`
values in `HunchTestSupport` and have both suites read it. A `let` of immutable `Sendable` values is
the one sanctioned piece of shared state under `06 T10`'s parallel-in-one-process model (`08 §5`
rule 3); a `static var` would be a data race. Record the change in `DECISIONS.md` and re-measure.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter NarrationTests` green, all six tests.
- [ ] `swift test --package-path HunchCore --filter NarrationParityTests` green over 8 × `Corpora.narrationLawsPerBand` = **10,000** laws; `#expect(Corpora.narrationLawsPerBand == 1_250)` holds.
- [ ] `swift test --package-path Modules --filter BenchNarrationTests` green, and `RoundPhase.allCases` is walked exhaustively.
- [ ] `grep -rn 'import Foundation' HunchCore/Sources/Laws/Narration.swift` — and nothing else imported; no `Bundle`, no `Locale`, no `String(localized:` anywhere in that file.
- [ ] `grep -Rn 'func narration(' Modules/Sources --include='*.swift' | wc -l` is exactly **1**.
- [ ] `grep -Rn 'narration(' Modules/Sources/CodexFeature/CodexPageView.swift Modules/Sources/LoomFeature/BenchView.swift` shows both calling that one function.
- [ ] `grep -Rn 'Text(.*) + Text(' Modules/Sources/HunchUI/Loc.swift` returns nothing — no concatenated fragments.
- [ ] `swift test --package-path HunchCore` completes in under 10 s, measured and recorded in `PROGRESS.md`.
- [ ] `tests.json` carries the gate-7 entry with `source: "§13.12 gate 7"` and the parity command.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T03: Narration in HunchCore, rendered once, parity over 10,000 laws"`

## Out of scope

- The announcements that interpolate `{narration}` — **T05**.
- The Assay's value and "Read by attribute" — **T04**.
- The Codex page's *drawing* of a law in rule-tiles — **E15·T05**; this task only gives that container its value.
- RNF itself, `BenchLayout` and G10 — **E05·T04**, **E06·T03/T04**. If the parity test fails on a G10 round-trip rather than on the words, the bug is theirs and the fix belongs on their test.
- The twelve translations of the narration format strings — **E18·T03**.
