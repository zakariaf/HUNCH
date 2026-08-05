# T07 — The Seal and the machined bar

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 `The Seal + machined bar` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | **First.** `C.Seal` lands here — the depression, the mark strike interval and scale, the brass bloom, and `C.Seal.railPulse`. `weight.heavy` is what makes the bar the heaviest mark on the surface, and that is the property that makes "barred" readable with no colour at all; it resolves through `env.weight(.heavy)` and never as a number. |
| `hunch-bench-instruments` | `references/seal.md` is this task: the two variants, the four states, the three things that follow from §4.3's refusal, the `.disabled` trap, and the ruling on `AccessibilityTraits` having no `notEnabled` member. |
| `hunch-shared-marks` | `MachinedBar.draw` is the **one owning function** for a drawing the GDD specifies twice — §4.3 for the Seal and §12.4 for a barred mode-rack key, where it says "the identical drawing" and then draws it again. That duplication is the failure mode the skill exists to stop. |
| `hunch-accessibility` | The barred Seal is the worked example in this skill's own code block: never `.disabled(true)`, because `.disabled` deletes the tap and the tap **is** the refusal — the rail pulse and the announcement both hang off it. `accessibilityRespondsToUserInteraction(true)` makes it discoverable while it is refusing. |

## Objective

At the end of this task the Bench has a Seal that is physically barred until the draft is a law, that
knows *which* rail is at fault and pulses exactly that one when pressed, and that says nothing —
no error text, no error state, no modal. Before this task the commit bar's trailing key is a
placeholder; after it, §6.7's nine-tap worked declaration is reproducible step by step in a test, with
the bar in the right state at every tap.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.3 | *"The Seal is **physically barred** by a machined bar across it while any rail is inert, any socket unbound, or the draft's extension is constant. Pressing a barred Seal pulses the offending rail and nothing else. No error text, no error state, no modal: the machine simply is not ready."* Plus: a ramp with 0 or 4 cells lit draws at one inert state |
| `GAME_DESIGN.md` | §6.7 | The nine-tap worked declaration with the bar's state annotated at taps 1, 3, 6, 7 and 9, and *"the machined bar is doing real work mid-build, not only at the end"* |
| `GAME_DESIGN.md` | §6.5, §6.11 case 11 | *"Seal is edge-triggered with no queue; the second tap is discarded"* — the PROBE and twin keys hold a single-slot queue and the Seal must not |
| `GAME_DESIGN.md` | §6.11 cases 12, 13 | Barred Seal pressed → the offending rail pulses once, no text, no modal, no error state. Draft's extension constant → the Seal stays barred |
| `GAME_DESIGN.md` | §13.7.2 | The barred-Seal micro-response: *"the offending rail pulses 3 × 90 ms, 0.5 → 1.0 opacity; nothing else moves, no error text, no modal"* |
| `GAME_DESIGN.md` | §13.7.4 | The barred-Seal rail-pulse substitution and the key-depression substitution (an interior step, never a translation — §13.12 gate 9) |
| `GAME_DESIGN.md` | §12.8, §13.10 | `accessibilityRespondsToUserInteraction` on the barred Seal; the label/value split; Magic Tap = Seal on the Bench |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | The `SealBar` switch has no `default:` — this is the epic's gate row 3 |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 | *"A `Bool isSealBarred` cannot answer 'which rail pulses?', so §4.3's behaviour would need a second parallel field"* — `N10`'s negative-name ban deviates here because the machine state **is** the bar |

## TDD — the test comes first

**Step 1 — write the failing tests.** The predicate is core; the refusal is view.

Create `HunchCore/Tests/BenchTests/SealBarTests.swift`:

```swift
import Testing
import Bench
import Glyphs
import Laws
import HunchTestSupport

@Suite("The machined bar", .tags(.unit, .presubmission))
struct SealBarTests {

    // §4.3 names exactly three reasons. The gate for this epic asserts they are exhaustive.
    @Test("There are exactly three reasons the Seal is barred")
    func threeReasons() {
        #expect(SealBar.Kind.allCases.count == 3)
        #expect(Set(SealBar.Kind.allCases) == [.inertRail, .unboundSocket, .constantExtension])
    }

    // §6.7's worked declaration, tap by tap. The bar is doing real work mid-build.
    @Test("§6.7's nine taps put the bar in the right state at every step")
    func workedDeclaration() throws {
        var draft = BenchLayout.empty

        // 1 — palette → Bridge stamp: both sockets dashed and empty.
        draft.place(.bridge, onRail: 0)
        #expect(draft.sealBar?.kind == .unboundSocket)

        // 2 — leading socket → `pips`. Still unbound on the trailing side.
        draft.bind(.pips, to: .leading, onRail: 0)
        #expect(draft.sealBar?.kind == .unboundSocket)

        // 3 — trailing socket → `pips`. Complete at the default `eq`, both sockets `cur`
        //     → a tautology. All 256 cells lit, barred on a constant extension.
        draft.bind(.pips, to: .trailing, onRail: 0)
        #expect(draft.sealBar?.kind == .constantExtension)

        // 4 — ghost toggle: RANK pips(cur) == PREV RANK pips. A real law; the bar lifts.
        draft.toggleGhost(onRail: 0)
        #expect(draft.sealBar == nil)

        // 5 — wedge cycled to `gt`. Still a real law.
        draft.setComparator(.gt, onRail: 0)
        #expect(draft.sealBar == nil)

        // 6 — palette → Ramp stamp on rail 1, 0 cells lit → inert.
        draft.place(.ramp, onRail: 1)
        #expect(draft.sealBar == .inertRail(1))

        // 7 — Ramp header → `shape`. Still 0 cells lit, still inert.
        draft.bind(.shape, onRail: 1)
        #expect(draft.sealBar == .inertRail(1))

        // 8 — cell `triangle`: 1 cell lit. No rail inert, no socket unbound, extension
        //     non-constant (32 cells) → §4.3's predicate lifts the bar HERE. §6.7's prose
        //     remarks on the lift at tap 9; see Implementation notes for the ruling.
        draft.toggleCell(rank: Glyph.Shape.triangle.rank, onRail: 1)
        #expect(draft.sealBar == nil)

        // 9 — cell `hexagon`: 2 cells lit, 64 cells. Still unbarred.
        draft.toggleCell(rank: Glyph.Shape.hexagon.rank, onRail: 1)
        #expect(draft.sealBar == nil)
    }

    // §4.3: "one inert state, not two" — and the SAME predicate bars the Seal and dims
    // the ramp, so the two can never disagree.
    @Test("Both inert ramp states bar the Seal, and no other subset does")
    func inertRailIsVacuousness() {
        for bitmask in UInt8(0)...UInt8(15) {
            var draft = BenchLayout.empty
            draft.place(.ramp, onRail: 0)
            draft.bind(.shape, onRail: 0)
            draft.setAdmitted(RankSet(bitmask: bitmask), onRail: 0)

            let isVacuous = RankSet(bitmask: bitmask).isVacuous
            #expect((draft.sealBar == .inertRail(0)) == isVacuous)
        }
    }

    // §4.3: the bar names WHICH rail, because that is the rail that pulses.
    @Test("The bar names the offending rail, and names the first one when both are inert")
    func theBarNamesTheRail() {
        var draft = BenchLayout.empty
        draft.place(.ramp, onRail: 0)
        draft.bind(.shape, onRail: 0)
        draft.setAdmitted(RankSet(ranks: [0, 1]), onRail: 0)
        draft.place(.ramp, onRail: 1)
        draft.bind(.pips, onRail: 1)
        #expect(draft.sealBar == .inertRail(1))

        draft.setAdmitted(.empty, onRail: 0)
        #expect(draft.sealBar == .inertRail(0), "the leading offending rail is named first")
    }

    // §4.4: "the one genuine over-reach is that the player can build a draft whose
    // extension is constant, and the Seal is barred for exactly those."
    @Test("An unsatisfiable draft and a tautological draft both bar on constantExtension")
    func constantExtensionBothWays() throws {
        let unsat = try #require(Corpora.unsatisfiableDraft)
        let taut = try #require(Corpora.tautologicalDraft)
        #expect(unsat.sealBar?.kind == .constantExtension)
        #expect(taut.sealBar?.kind == .constantExtension)
        #expect(LawTable(try #require(unsat.node)).popCount == 0)
        #expect(LawTable(try #require(taut.node)).popCount == 65_536)
    }

    // The Bench fuzzer's forward half, cheaply: a draft the Seal accepts must parse.
    @Test("An unbarred draft always parses to a grammar-valid AST", arguments: Band.allCases)
    func unbarredImpliesParseable(_ band: Band) throws {
        for index in 0..<Corpora.draftsPerBand {
            let draft = Corpora.randomDraft(band: band, index: index)
            guard draft.sealBar == nil else { continue }
            #expect(draft.node != nil,
                    "unbarred but unparseable — Corpora.randomDraft(band: .\(band), index: \(index))")
        }
    }
}
```

Create `Modules/Tests/HunchUITests/SealViewTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI

@Suite("The Seal", .tags(.unit, .presubmission))
struct SealViewTests {

    // seal.md §3.2 and §13.7.2: the refusal is a pulse ON THE RAIL, and nothing else moves.
    @Test("A barred press pulses the offending rail and moves nothing else")
    func refusalIsARailPulse() {
        let response = SealView.response(to: .inertRail(1), in: .fixture())
        #expect(response.pulsedRail == 1)
        #expect(response.pulseCount == 3)
        #expect(response.movesTheSeal == false)
        #expect(response.presentsAnything == false)
    }

    // §4.3 abolishes the error state. This is the assertion that keeps it abolished.
    @Test("Refusing presents no text, no alert, no modal and no error state",
          arguments: SealBar.Kind.allCases)
    func noErrorSurface(_ kind: SealBar.Kind) {
        let response = SealView.response(to: SealBar.sample(kind), in: .fixture())
        #expect(response.message == nil)
        #expect(response.alert == nil)
        #expect(response.errorState == nil)
    }

    // seal.md §4: NOT `.disabled(isBarred)` — .disabled would stop the action firing and
    // the action IS the refusal.
    @Test("A barred Seal stays enabled and responds to user interaction")
    func barredSealIsStillLive() {
        let barred = SealView.Model(bar: .constantExtension, marks: 0)
        #expect(barred.isEnabled)
        #expect(barred.respondsToUserInteraction)
        #expect(barred.accessibilityValueKind == .barredReason)
        #expect(SealView.Model(bar: nil, marks: 0).accessibilityValueKind == .ready)
    }

    // §6.5 / §6.11 case 11: edge-triggered, no queue. "A queued second declaration would
    // be catastrophic."
    @Test("The Seal has no input queue and discards a second tap inside the lock")
    func edgeTriggered() {
        var seal = SealInput()
        #expect(seal.accept(at: .zero) == .commit)
        #expect(seal.accept(at: .milliseconds(40)) == .discarded)
        #expect(seal.queuedTaps == 0)
    }

    // §13.7.4 / §13.12 gate 9: nothing translates anywhere, so the depression becomes an
    // interior step under Reduce Motion.
    @Test("The depression is a translation normally and an interior step under Reduce Motion")
    func depressionSubstitution() {
        #expect(SealView.pressOffset(in: .fixture(isReduceMotionEnabled: false)) == C.Seal.depression)
        #expect(SealView.pressOffset(in: .fixture(isReduceMotionEnabled: true)) == 0)
    }

    // §5.4: 1…3 marks. A fourth is score inflation with no meaning behind it.
    @Test("The Seal draws at most three marks")
    func markCeiling() {
        #expect(C.Seal.maxMarks == 3)
        #expect(SealView.Model(bar: nil, marks: 9).drawnMarks == 3)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter SealBarTests
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:HunchUITests/SealViewTests
```

`value of type 'BenchLayout' has no member 'sealBar'` is the right first failure.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then run the epic's gate row 3:
`! grep -rn 'default:' HunchCore/Sources/Bench Modules/Sources/HunchUI/SealView.swift`.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Bench/SealBar.swift` — `SealBar.Kind`, `SealBar.kind`, and `BenchLayout.sealBar` (**only what E06·T03 did not ship**) |
| modify | `HunchCore/Sources/Tokens/C.swift` — the `C.Seal` namespace |
| create | `Modules/Sources/HunchUI/SealView.swift` — `SealView`, `SealFace`, `SealInput` |
| create | `Modules/Sources/HunchUI/Marks/MachinedBar.swift` — **only if E04·T07 did not ship it**; otherwise call it |
| modify | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — `RailPulse` reads the `SealBar`, never re-derives it |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the commit bar's trailing key becomes the real Seal |
| create | `HunchCore/Tests/BenchTests/SealBarTests.swift` |
| create | `Modules/Tests/HunchUITests/SealViewTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `unsatisfiableDraft`, `tautologicalDraft`, `randomDraft(band:index:)`, `draftsPerBand` |
| modify | `DECISIONS.md` — the tap-8 ruling |
| modify | `tests.json` — the `SealBar` exhaustiveness and the worked declaration |

## Implementation notes

### The ruling on tap 8, and why the test says `nil` there

§6.7's table annotates *"the machined bar lifts off the Seal"* on tap **9**. §4.3's predicate is
exhaustive and normative: barred iff **any rail is inert, any socket is unbound, or the extension is
constant**. At tap 8 the draft is `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle}` — no rail
inert (one cell lit is not vacuous), no socket unbound, extension 32 cells and therefore not constant.
The bar lifts at 8.

§6.7's remark at tap 9 is descriptive of the finished state, not a claim that the bar was still down
at 8 — the same table gives no bar annotation at taps 4, 5 or 8, and taps 4 and 5 are unambiguously
unbarred. **The predicate is normative; the prose is a walkthrough.** Record it in `DECISIONS.md` with
both citations, because the next person to read §6.7 will ask.

If you find yourself tempted to special-case tap 8 to match the prose, notice what it would take:
a rule like "at least two cells lit", which contradicts §4.3's fourteen usable states and would make
`shape ∈ {triangle}` — §5.2's own band-1 example family — unstateable.

### `SealBar` — the reason, as data, in core

```swift
public enum SealBar: Hashable, Sendable {
    case inertRail(Int)        // 0-based rail index; the VoiceOver value says "rail 2" for 1
    case unboundSocket(Int)
    case constantExtension

    public enum Kind: CaseIterable, Hashable, Sendable {
        case inertRail, unboundSocket, constantExtension
    }

    public var kind: Kind {
        switch self {                     // no `default:` — the epic's gate row 3
        case .inertRail: .inertRail
        case .unboundSocket: .unboundSocket
        case .constantExtension: .constantExtension
        }
    }
}
```

`BenchLayout.sealBar` evaluates in this order, and the order is the pulse target's order:

1. **Structural first, cheapest first.** Walk the rails leading → trailing; the first inert rail wins,
   then the first unbound socket. Structural faults are local and the pulse can point at them.
2. **Semantic last.** Only when the draft is structurally complete is the extension resolved and
   checked for constancy. Building a `LawTable` for a draft with an unbound socket is both wasteful
   and meaningless.

The predicate `RankSet.isVacuous` is the **same** one the ramp's inert drawing reads (T02). Two
implementations of "inert" is how the Seal and the rail end up disagreeing on some subset and nobody
finds out which.

### The refusal

Three things follow from §4.3 and all three are easy to lose:

1. **The reason is data, in core.** The view reads `SealBar` to decide which rail to pulse and what to
   announce. A view-side re-derivation will disagree with the bar on some subset.
2. **The refusal is a pulse on the rail, not a response on the Seal.** 3 × `Dur.pulse`,
   `C.Seal.railPulse` 0.5 → 1.0, and *nothing else moves*. The Seal does not shudder, flash or shake:
   the machine is not annoyed, it is not ready. A Seal that reacts to itself points at nothing.
3. **Edge-triggered, no queue.** The PROBE and twin keys hold a single-slot queue; the Seal must not,
   because the second tap would land on a round that has already ended.

Adding an error message here would put text on the play surface (check 7 fails the build), add a state
the design abolished, and replace a mechanism with an apology.

### The `.disabled` trap, and the trait that does not exist

§13.10's table says the barred Seal carries `.notEnabled`. SwiftUI's `AccessibilityTraits` **has no
`notEnabled` member** — UIKit's `UIAccessibilityTraitNotEnabled` is reachable only through
`.disabled(true)`, which also stops the button's action firing and therefore swallows the refusal that
pulses the rail and posts the announcement.

The resolution (`seal.md` §5): the control stays **enabled**, the barred state is carried by the
**value** (`"barred, rail 2 is empty"` — §13.10's own value column), and
`accessibilityRespondsToUserInteraction(true)` makes it discoverable while it is refusing. Do not
reach for `.accessibilityAddTraits(.isNotEnabled)`; it does not compile. Do not "fix" it with
`.disabled`.

Magic Tap fires the Seal on the Bench (§13.10, E19·T05) and **must route through the same function the
button does, including the refusal path**. Expose one `commit()`/`refuse(_:)` pair and let both callers
use it.

### The bar itself

`MachinedBar.draw(into:key:env:)` in `Modules/Sources/HunchUI/Marks/` is the one owning function,
shared with the barred mode-rack key (§12.4). The GDD draws it twice and calls it "the identical
drawing"; that is precisely the duplication `hunch-shared-marks` exists to prevent, so if E04·T07
already shipped it, **call it** — a second declaration is the bug.

`weight.heavy` is what keeps the bar the heaviest mark on the surface at every combination of High
Contrast and Bold Text, which is the property that makes "barred" readable with no colour at all.
Check it against the resolved matrix in `dimensions-strokes-opacity.md` §2 rather than assuming it.

The bar retracts off the trailing edge at reveal beat 0 (T10) — the only time it animates. Everywhere
else it appears and disappears with the state, and it has **no Reduce Motion substitution** because it
is simply absent in the settled composition the reveal crossfades to.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SealBarTests` green, all six tests.
- [ ] `xcodebuild test … -only-testing:HunchUITests/SealViewTests` green.
- [ ] `! grep -rn 'default:' HunchCore/Sources/Bench Modules/Sources/HunchUI/SealView.swift` — the
      epic's gate row 3.
- [ ] `grep -n '\.disabled(' Modules/Sources/HunchUI/SealView.swift` returns nothing.
- [ ] `grep -rnE 'alert\(|confirmationDialog|\.sheet\(|Text\(' Modules/Sources/HunchUI/SealView.swift`
      returns only hits inside `.accessibility*` modifiers.
- [ ] `grep -rn 'enum MachinedBar\|struct MachinedBar' Modules/Sources | wc -l` returns `1`.
- [ ] `DECISIONS.md` records the tap-8 ruling with its §4.3 and §6.7 citations.
- [ ] `tests.json` carries `seal.bar-reasons-exhaustive` and `seal.worked-declaration-6.7`.
- [ ] In the simulator: with an empty ramp on rail 2, pressing the Seal pulses rail 2 three times and
      nothing else on the screen changes. With VoiceOver on, the Seal is focusable and reads
      *"Seal, barred, rail 2 is empty."*

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter SealBarTests && xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:HunchUITests/SealViewTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T07: the Seal, the machined bar and the exhaustive SealBar predicate"`

## Out of scope

- **What happens when the Seal is pressed and *not* barred.** The comparison, the strike accounting
  and the two-declaration ceiling are **T08**; the 640 ms hold and everything after it is **T09**/**T10**.
- **The `SealBar` enum's original declaration and the 200,000-configuration Bench fuzzer.** **E06·T03**
  and **E06·T04**. The forward check in `unbarredImpliesParseable` is a cheap sibling, not a
  replacement.
- **Seal marks striking in.** Drawn here as a state; animated at reveal beat 6 in **T10**.
- **"Confirm the Seal", the optional confirming second tap.** §12.6's PLAY section, **E17·T07**.
- **The barred mode-rack key.** **E17·T04**, which calls the same `MachinedBar.draw`.
- **The `bar` haptic and its face-down discriminability.** **E20·T05**; T10 publishes the cue point.
