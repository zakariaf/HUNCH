# T09 — Vertex sigils

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | Vertex sigils (PROFILE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The sigils' ink follows the portrait's — `stroke.secondary` → `stroke.primary` under High Contrast, weights through `env.weight(_:)` so Bold Text's ×1.25 and High Contrast's flat +0.5 resolve in the right order — and the spoke stub takes the portrait's own spoke opacity, which is a token, never a copied number. |
| `hunch-sigil-drawing` | Owns all five drawings. `references/profile-vertex-sigils.md` already resolves the collision P3's wording walks into — drawn bare, `profile.restraint` *is* the machined bar and `profile.induction` *is* `family.literal` — with the vertex-rotation ruling, and `scripts/check-sigil-distinctness.js` is the gate that proves it worked. |
| `hunch-accessibility` | The sigils are the one set where the mark *is* its own element: §11.11's five approved behavioural sentences are the labels, the identifiers are never spoken and never enter the catalog, and the AX3 reflow must keep every 44 × 44 hit rect. This skill owns wording and element identity. |

## Objective

At the end of this task the five axes have faces: a ramp silhouette, a link arc, the Fork's railway
switch, the Seal's bar and a tick strip, each rotated to its own locked vertex angle so it is
provably distinct from the mark it quotes and from its four siblings. The axis identifiers appear
nowhere in the app and never enter the String Catalog in any form, and the ring of five reflows to a
vertical list at AX3 with every 44 × 44 hit rect intact.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.11 P3 | the five idioms, one clause each; and *"The axis names never appear in the app"* |
| `GAME_DESIGN.md` | §11.11 | the five approved VoiceOver sentences, verbatim and localized — descriptions of what you did, never of what you are |
| `GAME_DESIGN.md` | §11.11 P8 | the banned-lexeme grep, and why *Retention* and *Flexibility* land on "memory" and "ability" in several of the twelve languages |
| `GAME_DESIGN.md` | §11.10 | the five locked vertex angles the rotation reads |
| `GAME_DESIGN.md` | §12.9 | the five accessibility keys carrying the sentences, and the rule that the identifiers never enter the catalog |
| `GAME_DESIGN.md` | §13.11 | the AX3 reflow from a ring to a vertical list, each keeping its 44 × 44 hit rect; the card itself does not scale |
| `hunch-sigil-drawing` | `references/profile-vertex-sigils.md` | the whole task: P3's collision, the vertex-modifier ruling, the five drawings with their verbs, the three placement constraints, VoiceOver, Reduce Motion, High Contrast |
| `hunch-sigil-drawing` | `references/drawing-a-new-sigil.md` §5 | the four write-back artefacts — `SIGILS`, one catalogue section, the `case` in `Sigil.swift`, the regenerated parity fixture |
| `hunch-chrome-and-meta` | `references/profile-contour.md` §8, §9 | placement on the card, the fixed non-trembling radius, and the contour's own `.accessibilityHidden(true)` |

## TDD — the test comes first

**Step 1 — write the failing test.** Three artefacts: the harness gate (a script, run first), a
parity test, and a placement test.

Run the distinctness harness before writing any Swift — a failure there is a design answer, not an
obstacle:

```bash
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --new profile.induction
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --new profile.retention
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --new profile.flexibility
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --new profile.restraint
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --new profile.tempo
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js            # full run
```

`Modules/Tests/HunchUITests/SigilParityTests.swift` — extend E15·T09's suite rather than starting a
second one:

```swift
@Test("the five Profile vertex sigils match the harness fixture",
      .tags(.unit, .presubmission), arguments: ProfileAxis.allCases)
func profileVertexSigilMatchesTheHarness(_ axis: ProfileAxis) throws {
    let fixture = try SigilFixture.load()                    // scripts/…--json, committed
    let key = "profile.\(axis)"
    let expected = try #require(fixture[key])
    #expect(Sigil.profileVertex(axis).normalisedPath.commands == expected.commands)
}

@Test("each vertex sigil is rotated to its own locked angle — §11.10, and the rotation IS the identity",
      .tags(.unit, .presubmission), arguments: 0..<5)
func rotationIsTheIdentity(_ i: Int) {
    let axis = ProfileAxis.allCases[i]
    #expect(isApproximatelyEqual(Sigil.profileVertex(axis).rotation,
                                 ProfileGeometry.angle(forVertex: i), absoluteTolerance: 1e-12))
}

@Test("each vertex sigil is distinct from the mark it quotes", .tags(.unit, .presubmission))
func distinctFromTheQuotedMark() {
    // Drawn bare, profile.restraint IS the machined bar and profile.induction IS family.literal.
    #expect(Sigil.profileVertex(.restraint).normalisedPath != Sigil.machinedBar.normalisedPath)
    #expect(Sigil.profileVertex(.induction).normalisedPath != Sigil.family(.literal).normalisedPath)
    #expect(Sigil.profileVertex(.tempo).normalisedPath != Sigil.facet(.threeMarks).normalisedPath)
    #expect(Sigil.profileVertex(.flexibility).normalisedPath != Sigil.family(.guarded).normalisedPath)
}
```

`Modules/Tests/MetaFeatureTests/VertexSigilPlacementTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import Archive
import Tokens
import MetaFeature
import ModulesTestSupport

@Suite("Vertex sigil placement — §13.11 and profile-contour.md §8", .tags(.unit, .presubmission))
@MainActor
struct VertexSigilPlacementTests {

    @Test("every sigil keeps a 44 × 44 hit rect at every type size",
          arguments: [1.0, 1.35, 2.0, 3.1])
    func hitRectsSurviveEveryTypeSize(_ multiplier: Double) {
        let layout = ProfileContour.sigilLayout(in: .preview(typeMultiplier: multiplier))
        #expect(layout.count == 5)
        #expect(layout.allSatisfy { $0.hitRect.width >= 44 && $0.hitRect.height >= 44 })
    }

    @Test("at AX3 and above the ring becomes a vertical list; below it stays a ring")
    func reflowsAtAX3() {
        let ring = ProfileContour.sigilLayout(in: .preview(typeMultiplier: 1.35))   // AX2
        let list = ProfileContour.sigilLayout(in: .preview(typeMultiplier: 2.35))   // AX3
        #expect(Set(ring.map { $0.hitRect.midX }).count > 1)          // a ring: five different x
        #expect(Set(list.map { $0.hitRect.midX }).count == 1)         // a list: one column
        #expect(list.map { $0.hitRect.midY } == list.map { $0.hitRect.midY }.sorted())
    }

    @Test("the rotation travels into the AX3 list — the angle is the identity, not the arrangement")
    func rotationSurvivesTheReflow() {
        let list = ProfileContour.sigilLayout(in: .preview(typeMultiplier: 2.35))
        for (i, item) in list.enumerated() {
            #expect(isApproximatelyEqual(item.rotation, ProfileGeometry.angle(forVertex: i),
                                         absoluteTolerance: 1e-12))
        }
    }

    /// profile-vertex-sigils.md §"Placement": rᵢ caps at 1.55·R0 = 148.8 pt on a card whose centre is
    /// at y = 140, so a maximal Induction contour leaves the card. The sigil must not follow it.
    @Test("the sigil sits at a fixed radius and does not follow rᵢ, and does not tremble")
    func sigilRadiusIsFixed() {
        let starved = ProfileContour.sigilLayout(for: .preview(values: [0.0, 0.5, 0.5, 0.5, 0.5]))
        let maximal = ProfileContour.sigilLayout(for: .preview(values: [1.0, 0.1, 0.1, 0.1, 0.1]))
        #expect(zip(starved, maximal).allSatisfy { $0.0.hitRect == $0.1.hitRect })
        #expect(starved.allSatisfy { $0.tremblesWithTheContour == false })
        #expect(maximal.allSatisfy { ProfileContour.cardBounds.contains($0.hitRect) })
    }

    @Test("each sigil is its own accessibility element with the .image trait, never .button")
    func accessibilityIdentity() {
        let elements = ProfileContour.accessibilityElements(for: .preview)
        #expect(elements.filter { $0.kind == .vertexSigil }.count == 5)
        #expect(elements.filter { $0.kind == .vertexSigil }.allSatisfy { $0.traits == [.image] })
        #expect(elements.first { $0.kind == .contour }?.isHidden == true)
    }

    @Test("the five labels are the approved sentences and none of them names an axis")
    func labelsAreSentencesNotNames() {
        let labels = ProfileContour.accessibilityElements(for: .preview)
            .filter { $0.kind == .vertexSigil }.map(\.label)
        #expect(labels.count == 5)
        #expect(Set(labels).count == 5)
        let banned = ["induction", "retention", "flexibility", "restraint", "tempo"]
        #expect(labels.allSatisfy { label in
            banned.allSatisfy { !label.lowercased().contains($0) }
        })
    }
}
```

**Step 2 — run it and watch it fail.** The harness fails first, on distinctness, and that failure is
the design work — a bare machined bar will not pass. `swift test --package-path Modules --filter SigilParityTests`
and `--filter VertexSigilPlacementTests` then fail on missing symbols. Do not write the Swift before
the harness is green: the coordinates come *from* `SIGILS`, and hand-drawn coordinates that are later
reconciled with the harness are how a fork starts.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `.claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` — five entries in `SIGILS` |
| modify | `.claude/skills/hunch-sigil-drawing/references/profile-vertex-sigils.md` — the five prose sections, one owning section per key |
| modify | `HunchCore/Sources/Sigils/Sigil.swift` — five `case`s and `Sigil.profileVertex(_:)` |
| modify | `Modules/Tests/HunchUITests/Fixtures/sigils-v1.json` — regenerated with `--json`, committed |
| create | `Modules/Sources/MetaFeature/VertexSigilLayout.swift` — the ring, the AX3 list, the hit rects |
| modify | `Modules/Sources/MetaFeature/ProfileContour.swift` — place the five, hide the contour |
| create | `Modules/Tests/MetaFeatureTests/VertexSigilPlacementTests.swift` |
| modify | `Modules/Tests/HunchUITests/SigilParityTests.swift` |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — **five keys**, carrying §11.11's sentences, keyed `profile.vertex.1` … `.5` |
| modify | `Scripts/check-source-hygiene.sh` — check 13: the axis identifiers appear nowhere in the catalog and in no `Text`/`Label`/`accessibilityLabel` argument |
| modify | `tests.json` — five entries |

## Implementation notes

### The collision, and the ruling that resolves it

§11.11 P3 names five idioms and four of them are bare quotes of marks that already exist:
`profile.retention` is the link arc, `profile.restraint` is the machined bar, `profile.tempo` is the
tick row, and *"a ramp silhouette"* is `family.literal`'s entire drawing. Drawn bare, three of the
five are duplicates of shipped marks and the distinctness harness fails.

`profile-vertex-sigils.md`'s ruling: **every vertex sigil is drawn with its quoted idiom rotated to
that vertex's own locked angle** from §11.10 — −90°, −18°, 54°, 126°, 198°. Two things follow. The
five become pairwise distinct *and* distinct from their bare sources by rotation alone, which is not
a new trick — it is exactly the mechanism the hue channel already uses (index stroke 0° / 45° / 90° /
135°, §13.5) — so the app is not learning a second idea. And the set reads as one set: five marks at
five angles around a portrait is legible as *the vertices* before any one of them is identified.

This is a faithful reading of P3, not a departure: P3 fixes the *vocabulary*, and every one of the
five still is exactly the idiom P3 names.

### The five drawings

Take them from `profile-vertex-sigils.md` §"The five drawings" — the primitive set, the verb and the
pre-rotation composition are given there per key, composed from the shared `MACRO` vocabulary. Three
differences from their sources are load-bearing and are worth restating as doc comments:

- **`profile.flexibility` has no gate cell**, which is what separates it from `family.guarded`; its
  branches are diagonal where the guard's are orthogonal. A guard names a gate; an axis measures how
  fast you leave a track.
- **`profile.restraint`'s bar overhangs the plate**, and the plate beneath is empty — which no live
  barred control ever is.
- **`profile.tempo` carries a baseline and a filled/unfilled split**, where `facet.threeMarks` is
  three bare Seal marks at `verb` weight and no baseline.

### The four write-back artefacts

`drawing-a-new-sigil.md` §5's contract, one edit each, and the harness fails on any of them missing:

1. the entry in `SIGILS` — the **only** place coordinates live;
2. the prose section in `profile-vertex-sigils.md`, exactly one owning section per key;
3. the `case` in `HunchCore/Sources/Sigils/Sigil.swift`;
4. the regenerated parity fixture (`--json`), which is what stops the Swift coordinates forking from
   `SIGILS`.

### Placement — three constraints, all from `profile-vertex-sigils.md`

1. **The sigil sits at a fixed radius that does not tremble.** §11.10's tremble is an amplitude on
   the *contour's* vertex radius, expressing confidence in the value. An axis's identity has no
   confidence, and a trembling icon is unreadable at 24 pt.
2. **The sigil is not pinned to `rᵢ`.** `rᵢ` caps at `1.55 · R0 = 148.8 pt` on a card whose centre is
   at `y = 140`, and Induction sits straight up at −90°, so a maximal Induction contour passes above
   the card's top edge. `sigilRadiusIsFixed` asserts both halves: the rect does not move with the
   value, and it stays inside the card.
3. **Each keeps a 44 × 44 hit rect** and, at AX3, reflows from the ring to a vertical list. The
   rotation travels with the drawing into that list — `rotationSurvivesTheReflow` — because the angle
   is the identity, not the arrangement.

The spoke stub inside each sigil box is drawn as part of the sigil, coincident with §11.10's existing
spoke and **at the portrait's own spoke opacity** (`C.Profile.spokeInk`, cited, never copied). It
exists so the mark still reads as a vertex once the ring is gone at AX3, and it adds no ink the
portrait did not already have.

### VoiceOver — the one place the axes are described in words

The five approved behavioural sentences from §11.11 **are** the vertices' accessibility labels. Not
hints, not values — labels. Traits are `.image`, never `.button`: `ProfileView` has no primary action
(§12.2).

**Do not copy the five sentences into this task file, into a comment, or anywhere but the catalog
values.** Read them from §11.11's table and key them `profile.vertex.1` … `profile.vertex.5` —
positional keys, so that neither the key nor the value ever contains an axis identifier. That is what
makes P8's banned-lexeme grep survivable: *Retention* and *Flexibility* land on "memory" and
"ability" in several of the twelve languages, and both words fail the build.

`labelsAreSentencesNotNames` asserts the negative directly, and hygiene check 13 asserts it over the
whole catalog including the other eleven locales:

```bash
# check 13
grep -riE '"(induction|retention|flexibility|restraint|tempo)"|>\s*(Induction|Retention|Flexibility|Restraint|Tempo)\s*<' \
  Modules/Sources/HunchUI/Resources/Localizable.xcstrings && exit 1
grep -rnE '(Text|Label|accessibilityLabel|accessibilityIdentifier)\([^)]*(Induction|Retention|Flexibility|Restraint|Tempo)' \
  Modules/Sources && exit 1
```

`hunch-chrome-and-meta`'s `profile-contour.md` §9 proposes a three-valued qualitative
`accessibilityValue` — *more than your usual · about your usual · less than your usual* — at a cost of
+3 catalog keys. **That belongs to E19**, which owns the element map and the ≈228-key budget. Ship
the labels here; leave the values to E19·T01 and note the proposal in `DECISIONS.md`.

### Reduce Motion, High Contrast, Bold Text, Dynamic Type

No vertex sigil animates, in either setting — the §13.7.4 Profile row and §11.10's dash substitution
both belong to the *contour*, and the sigils sit still through both because their position does not
depend on `rᵢ`. So no new row in §13.7.4 is needed and none may be added.

High Contrast steps `stroke.secondary` → `stroke.primary` **with the contour**, and the stub follows
the spokes *whatever they resolve to* — that coupling is the rule, not the number. Bold Text's ×1.25
and High Contrast's flat +0.5 resolve in `hunch-design-tokens`' order through `env.weight(_:)`;
`profile.tempo`'s unfilled ticks are `weight.hairline` against filled ticks at `verb`, and the two
must stay clearly apart once both settings have resolved. Recompute rather than quote:
`swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift`.

Dynamic Type: the box stays at its authored size up to AX2; at AX3 the ring reflows and nothing
inside the box scales independently.

## Acceptance criteria

- [ ] `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` passes on a full run — pairwise distance ≥ `T`, ink coverage, stage containment, one owning section per key, and the mirrored moduli still matching.
- [ ] `swift test --package-path Modules --filter SigilParityTests` green, all three new cases, against a regenerated committed fixture.
- [ ] `swift test --package-path Modules --filter VertexSigilPlacementTests` green, all seven tests.
- [ ] `Scripts/check-source-hygiene.sh` check 13 is present, passes, and was demonstrated to fail on a planted `"Tempo"` value in `Localizable.xcstrings`.
- [ ] `Localizable.xcstrings` gained exactly five keys, named positionally, and the catalog is still ≤ 250.
- [ ] `grep -rn "profile.induction\|profile.tempo" HunchCore/Sources/Sigils/Sigil.swift` shows the five cases; `grep -rn "CGPoint\|addLine" HunchCore/Sources/Sigils/Sigil.swift` shows coordinates coming from the fixture and not typed by hand.
- [ ] The AX3 reflow, High Contrast and Bold Text are checked in the simulator on `ProfileView` and the screenshots are in `PROGRESS.md`.
- [ ] `tests.json` carries five entries: harness distinctness, parity with the fixture, the rotation-is-the-identity rule, the fixed non-trembling radius, and the axis-names-absent grep.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes reusing `MachinedBar.draw` for `profile.restraint`, reject it: shared *token*, separate *drawing*, and the harness is the proof.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T09: the five Profile vertex sigils, rotated to their locked angles"`

## Out of scope

- The contour, the normalisation and the spline — **T08**.
- Tremble, the morph and the ghost — **T10**.
- The three-valued qualitative `accessibilityValue` per vertex, and the whole VoiceOver element map — **E19·T01**.
- The eight family sigils, the four mode sigils and the five facet stamps — **E15·T09**, **E17·T04**, **E15·T08**.
- The banned-lexeme test across twelve languages — **E18·T08**; check 13 here is the narrower axis-identifier grep.
