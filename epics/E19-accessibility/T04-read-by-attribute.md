# T04 — "Read by attribute"

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | "Read by attribute" (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | Owns the two rulings that are the whole of this task: the Assay's value is the **pinned slice, never the marginal projection** (`references/voiceover-elements.md` §5 — the projection says 48 where the screen shows 64, and it is the number the model layer hands you first), and "Read by attribute" is the answer to a 256-cell grid rather than 256 elements. It also owns §12.6's `announceAssay` row being off by default and why the focus-read value must therefore be complete. |

`hunch-bench-instruments` is deliberately **not** loaded: `references/assay-grid.md` already carries
the slice-versus-projection table and the modifier attachment point, but its geometry is not this
task's, and a row of this task that restated a cell size would be copying it.

## Objective

At the end of this task the Assay speaks its sixteen marginals as **one interruptible announcement** —
*"Of glyphs with shape triangle, 12 of 64 admitted."* — twenty seconds against an impossible 256
swipes, and its `accessibilityValue` quotes the lit count **of the slice on screen**, conditioned on
the pinned ghost exactly as the drawing is, rather than the unconditional projection.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.3 | the live Assay is a **slice** of the pair table pinned to the ghost, never a projection of it; the pin defaults to the seed glyph and scrubs to any of the 256; the unconditional marginal projection is a different picture with a different job |
| `GAME_DESIGN.md` | §13.10 (the Assay row) | the value is the lit count of the slice: *"Admits 64 of 256 glyphs, with this previous glyph"* for a contextual draft, *"Admits 64 of 256 glyphs"* for a stateless one; the two custom actions are "Inspect" and "Read by attribute" |
| `GAME_DESIGN.md` | §13.10 ("Read by attribute") | speaks the sixteen marginals as one interruptible announcement; it leaks nothing because the Assay shows the player's own draft; 20 s against 256 swipes |
| `GAME_DESIGN.md` | §12.6 (VOICEOVER · Announce the Assay) | off by default, because it fires on every Bench edit and is very chatty; it gates the **per-edit announcement only** |
| `GAME_DESIGN.md` | §2 | canonical `fill → shape → pips → hue` order and rank order 1…4 inside each attribute — the order the sixteen marginals are spoken in |
| `.claude/skills/hunch-accessibility/references/voiceover-elements.md` | §5, §11 | the Assay's row; the announcement mechanism and its one owner outside the six play-surface files |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files: the marginal arithmetic in the core, the wording and
the conditioning in the app layer.

`HunchCore/Tests/GlyphsTests/AttributeMarginalTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Attribute marginals over a 256-cell picture — §13.10", .tags(.unit, .presubmission))
struct AttributeMarginalTests {

    @Test("there are exactly sixteen, in canonical attribute order and ascending rank")
    func sixteenInCanonicalOrder() {
        let marginals = Bitboard256.full.marginals()
        #expect(marginals.count == 16)
        #expect(marginals.map(\.attribute) == [Glyph.Attribute.fill, .fill, .fill, .fill,
                                               .shape, .shape, .shape, .shape,
                                               .pips, .pips, .pips, .pips,
                                               .hue, .hue, .hue, .hue])
        #expect(marginals.filter { $0.attribute == .shape }.map(\.rank) == [1, 2, 3, 4])
    }

    @Test("every marginal's denominator is 64, because each value partitions the deck in four")
    func denominatorIsAlwaysSixtyFour() {
        for marginal in Corpora.seededBoard(index: 7).marginals() {
            #expect(marginal.total == 64)
        }
    }

    @Test("an attribute's four numerators sum to the board's popcount", arguments: 0..<32)
    func numeratorsPartitionTheBoard(_ index: Int) {
        let board = Corpora.seededBoard(index: index)
        for attribute in Glyph.Attribute.allCases {
            let admitted = board.marginals().filter { $0.attribute == attribute }.map(\.admitted).reduce(0, +)
            #expect(admitted == board.popCount)
        }
    }

    @Test("every marginal agrees with a brute-force walk of the deck", arguments: 0..<8)
    func agreesWithBruteForce(_ index: Int) {
        let board = Corpora.seededBoard(index: index)
        for marginal in board.marginals() {
            let brute = Deck.all.filter { $0[marginal.attribute].rank == marginal.rank && board.contains($0) }.count
            #expect(marginal.admitted == brute,
                    "\(marginal.attribute) rank \(marginal.rank): \(marginal.admitted) vs \(brute)")
        }
    }

    @Test("the empty and full boards read 0 of 64 and 64 of 64 across all sixteen")
    func degenerateBoards() {
        #expect(Bitboard256.empty.marginals().allSatisfy { $0.admitted == 0 && $0.total == 64 })
        #expect(Bitboard256.full.marginals().allSatisfy { $0.admitted == 64 })
    }
}
```

`Modules/Tests/LoomFeatureTests/AssayVoiceTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI
@testable import LoomFeature

@Suite("The Assay speaks the slice — §4.3, §13.10", .tags(.unit, .presubmission))
struct AssayVoiceTests {

    private let loc = Loc.english

    /// A contextual draft whose pinned-ghost slice and unconditional projection differ. This is the
    /// exact 64-versus-48 case §13.10 names, and it is the whole reason this test exists.
    private func contextualDraft() -> AssayPicture {
        let law = Corpora.contextualLawWhereSliceDiffersFromProjection
        return AssayPicture.slice(LawTable(law).row(after: Corpora.pinnedGhost))
    }

    @Test("the value quotes the on-screen slice, never the unconditional projection")
    func valueIsTheSlice() {
        let picture = contextualDraft()
        #expect(picture.litCount == 64)
        #expect(LawTable(Corpora.contextualLawWhereSliceDiffersFromProjection).marginalLitCount == 48)
        let value = loc.assayLitCount(picture.litCount, isConditioned: picture.isSlice)
        #expect(value.contains("64"))
        #expect(!value.contains("48"))
    }

    @Test("a contextual draft says 'with this previous glyph'; a stateless one does not")
    func conditioningIsSpoken() {
        #expect(loc.assayLitCount(64, isConditioned: true) != loc.assayLitCount(64, isConditioned: false))
        #expect(loc.assayLitCount(64, isConditioned: true).contains(loc.withThisPreviousGlyph))
    }

    // MARK: Read by attribute

    @Test("the announcement is ONE string covering all sixteen marginals in canonical order")
    func oneAnnouncementSixteenMarginals() {
        let picture = contextualDraft()
        let text = loc.readByAttribute(picture.marginals)
        for marginal in picture.marginals {
            #expect(text.contains(loc.marginalSentence(marginal)))
        }
        // sixteen sentences, one utterance
        #expect(text.components(separatedBy: loc.marginalSeparator).count == 16)
    }

    @Test("the marginals are computed from the SAME picture as the value")
    func marginalsShareTheSlice() {
        let picture = contextualDraft()
        #expect(picture.marginals.filter { $0.attribute == .shape }.map(\.admitted).reduce(0, +)
                == picture.litCount)
    }

    @Test("it posts once, at .default priority, so a verdict at .high interrupts it")
    func postedOnceAndInterruptible() {
        let spy = AnnouncerSpy()
        AssayVoice(announcer: spy, loc: loc).readByAttribute(contextualDraft())
        #expect(spy.posts.count == 1)
        #expect(spy.posts[0].priority == .default)
    }

    @Test("the per-edit announcement is gated by announceAssay; the focus-read value is not")
    func announceAssayGatesOnlyThePerEditAnnouncement() {
        let spy = AnnouncerSpy()
        let voice = AssayVoice(announcer: spy, loc: loc, announceAssay: false)
        voice.draftDidChange(contextualDraft())
        #expect(spy.posts.isEmpty)                                   // §12.6: off by default
        voice.readByAttribute(contextualDraft())
        #expect(spy.posts.count == 1)                                // the custom action always speaks
        #expect(!loc.assayLitCount(64, isConditioned: true).isEmpty)  // and the value is always complete
    }

    @Test("the 256 cells are not accessibility elements")
    func cellsAreNotElements() {
        #expect(AssayAccessibility.childBehaviour == .ignore)
        #expect(AssayAccessibility.elementCount == 1)
    }
}
```

**Step 2 — run it and watch it fail.** 

```
swift test --package-path HunchCore --filter AttributeMarginalTests
swift test --package-path Modules   --filter AssayVoiceTests
```

Missing `Bitboard256.marginals()`, `AttributeMarginal`, `loc.assayLitCount(_:isConditioned:)`,
`loc.readByAttribute(_:)`, `AssayVoice`, `AnnouncerSpy`,
`Corpora.contextualLawWhereSliceDiffersFromProjection`. The one that will pass accidentally is
`valueIsTheSlice` if T01's stub already returns a count — check that it fails on the
`!value.contains("48")` half against a deliberately wrong stub, because that is the assertion the
whole task exists for.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Glyphs/AttributeMarginal.swift` — the value and `Bitboard256.marginals()` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `seededBoard(index:)`, `pinnedGhost`, `contextualLawWhereSliceDiffersFromProjection` |
| create | `Modules/Sources/LoomFeature/AssayVoice.swift` — posts the announcement; consumes `Announcer` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — `assayLitCount(_:isConditioned:)`, `readByAttribute(_:)`, `marginalSentence(_:)`, `withThisPreviousGlyph` |
| modify | `Modules/Sources/HunchUI/AssayCanvas.swift` — the value and the two custom actions (T01 left the value stubbed) |
| modify | `Modules/Sources/LoomFeature/AssayInspectorView.swift` — the same two actions inside the presented subtree |
| create | `HunchCore/Tests/GlyphsTests/AttributeMarginalTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/AssayVoiceTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/AnnouncerSpy.swift` — a hand-written double; imports no `Testing` outside the test target |
| modify | `tests.json` — the slice-not-projection entry and the sixteen-marginal entry |
| modify | `DECISIONS.md` — the `.default` priority ruling below |

## Implementation notes

### Slice versus projection, stated once

§4.3 conditions the live Assay on the pinned ghost. For a draft admitting `p` of the 65,536 pairs, the
lit count is the **row count for the pinned `prev`**, which in general differs from `p × 256`. The
unconditional marginal projection is what a **Codex page thumbnail** renders (E15·T03) — a different
picture with a different job — and the two must not be quoted for each other.

The failure mode is not hypothetical and it is not symmetric: the projection is the number the model
layer hands you first, because `LawTable` can produce it without knowing what the screen has pinned.
So the type has to make the wrong one hard to reach:

```swift
// The picture the Assay is DRAWING is the picture the Assay SPEAKS. One value, two consumers.
public enum AssayPicture: Sendable {
    case slice(Bitboard256)          // conditioned on the pinned ghost — the live Assay
    case projection([UInt8])         // the unconditional marginal — Codex thumbnails only

    public var isSlice: Bool { if case .slice = self { true } else { false } }
    public var litCount: Int { … }
    public var marginals: [AttributeMarginal] { … }
}
```

`AssayCanvas` already takes an `AssayPicture` (E09·T05). This task adds `marginals` and the two
accessors, and the accessibility value is derived from **that same value**, so there is no path by
which the drawing and the speech disagree. `marginalsShareTheSlice` is the test that pins it.

### The sixteen marginals

Sixteen, not more and not fewer: four attributes × four ranks. Each value's denominator is always 64,
because each attribute value partitions the 256-glyph deck into four equal classes — which is worth
stating because it makes "12 of 64" a fact the player can compare across attributes without knowing
anything about the draft.

```swift
// HunchCore/Sources/Glyphs/AttributeMarginal.swift
public struct AttributeMarginal: Hashable, Sendable {
    public let attribute: Glyph.Attribute
    public let rank: Int                 // 1…4
    public let admitted: Int             // 0…64
    public var total: Int { 64 }
}

extension Bitboard256 {
    /// Sixteen marginals in canonical `fill → shape → pips → hue` order, ascending rank inside each.
    /// - Complexity: O(1) — sixteen popcounts against `MaskTable`'s atom masks.
    public func marginals() -> [AttributeMarginal] { … }
}
```

Implement it as sixteen `popCount(self & MaskTable.atom(attribute, rank))` operations against E02·T05's
resident masks, not as a walk of the deck. The brute-force walk is the *test*, which is the right way
round.

### The announcement

One string, sixteen sentences, in canonical order, spoken through the one `Announcer` that lives
outside the six play-surface files. An announcement is an `AttributedString`, and hygiene check 7 fails
the build on an `AttributedString` in `RoundView`, `EchoRoundView`, `SieveRoundView`, `BenchView`,
`AssayInspectorView` or `InscriptionView` — so `AssayVoice` composes the text and `Announcer` posts it.

**Ruling: post at `.default`, not `.high`.** §13.10 calls it *interruptible*, and §13.10's announcement
order is fixed at verdict → evidence → bookkeeping with verdicts at `.high` **so they interrupt**. A
20-second marginal read posted at `.high` would either be un-interruptible by the next verdict or would
make "`.high` interrupts" meaningless. `.default` is the spelling of "interruptible" that keeps both
rules true, and any VoiceOver gesture stops it as well. Record it in `DECISIONS.md`.

```swift
// Modules/Sources/LoomFeature/AssayVoice.swift
@MainActor
struct AssayVoice {
    let announcer: Announcer
    let loc: Loc
    var announceAssay: Bool = false                     // §12.6 default

    /// The custom action. Always speaks — it is a deliberate request.
    func readByAttribute(_ picture: AssayPicture) {
        announcer.announce(loc.readByAttribute(picture.marginals), priority: .default)
    }

    /// The per-edit announcement. Gated by §12.6's `announceAssay`, which is off because this fires
    /// on every Bench edit and is very chatty. The FOCUS-READ VALUE is not gated and must be
    /// complete, because that completeness is what makes off-by-default correct.
    func draftDidChange(_ picture: AssayPicture) {
        guard announceAssay else { return }
        announcer.announce(loc.assayLitCount(picture.litCount, isConditioned: picture.isSlice))
    }
}
```

Sixteen sentences are sixteen renderings of **one** format string with three interpolations —
`"Of glyphs with %1$@ %2$@, %3$@ admitted."` — joined by a sentence separator, not by a comma-list.
This is not a violation of trap 3: each sentence is a complete grammatical unit built from one format
string, and what is being joined is a *sequence of sentences*, which every language does with a full
stop.

### What must not be done here

- **Do not expose the 256 cells as elements.** 256 swipes against a 20-second announcement, and it
  would blow §12.9's key budget besides. `children: .ignore`, asserted by `cellsAreNotElements`.
- **Do not make `announceAssay` on by default** to "fix" chattiness complaints. The affordance that
  makes off-by-default correct is the complete value on focus — check *that* instead.
- **Do not re-derive the marginals in the view.** One `AssayPicture`, one `marginals` property, two
  consumers.
- `AssayInspectorView` is a presented subtree: re-inject the environment (`04 A25`) or `loc` and the
  announcer both resolve against nothing and the actions silently do nothing.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AttributeMarginalTests` green, all five tests including the brute-force agreement.
- [ ] `swift test --package-path Modules --filter AssayVoiceTests` green, all seven tests.
- [ ] `grep -Rn 'marginalLitCount\|\.projection' Modules/Sources/HunchUI/AssayCanvas.swift Modules/Sources/LoomFeature/` returns nothing — the live Assay never reaches the projection.
- [ ] `grep -Rn 'AttributedString' Modules/Sources/LoomFeature/{RoundView,BenchView,AssayInspectorView,InscriptionView,EchoRoundView,SieveRoundView}.swift` returns nothing; `Scripts/check-source-hygiene.sh` check 7 is green.
- [ ] `grep -Rn 'priority: .high' Modules/Sources/LoomFeature/AssayVoice.swift` returns nothing.
- [ ] Reading `AssayCanvas.swift`: exactly one `.accessibilityElement(children: .ignore)`, exactly two `.accessibilityAction(named:)`.
- [ ] `tests.json` carries both entries, `source: "§4.3, §13.10"`.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T04: Read by attribute, and the Assay's value pinned to the on-screen slice"`

## Out of scope

- The Assay's drawing, its pin, its ghost scrubber and the band-4 evidence overlay — **E09·T05/T06**.
- The expanded inspector's layout — **E09·T05**; this task only re-attaches the two actions inside it.
- The Codex thumbnail's projection rendering — **E15·T03**, which is the *other* consumer of `AssayPicture` and the reason the enum has two cases.
- `Announcer` itself and the verdict / reveal announcements — **T05**.
- The `announceAssay` Settings row as UI — **E17·T07**.
