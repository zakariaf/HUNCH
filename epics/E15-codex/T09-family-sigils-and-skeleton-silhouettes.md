# T09 — The eight family sigils and the skeleton silhouettes

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Taxonomy and browse (the wordless half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-sigil-drawing` | It owns the geometry. `SIGILS` in `scripts/check-sigil-distinctness.js` is the **normative home** of every coordinate; `references/family-sigils.md` holds the eight drawings, the family/skeleton unification and the warning that `family.pair` and `family.exclusive` are the closest pair in the whole library; `references/drawing-a-new-sigil.md` §5 holds the four-artefact write-back contract this task exists to execute. The skill's step-0 block also proves the eight keys are already authored, so this task **transcribes**, it does not design. |
| `hunch-design-tokens` | The four stroke roles (`contour`, `verb`, `ghost`, `bar`) resolve to `weight.*` through `env.weight(_:)` and the ink is `stroke.secondary` / `stroke.primary` — never a number, never `hue.*`, never `accent.*`. This skill owns the Bold Text × 1.25 then High Contrast + 0.5 order that the `ghost` role at hairline is most at risk from. |
| `hunch-swift-testing` | The parity test decodes a `.copy("Fixtures")` resource, which is `06 T54`'s exact trap (`subdirectory:` or every `#require` fails at once); and it owns the rule that a fixture is generated, never hand-written. |

## Objective

At the end of this task the eight `family.*` marks exist in Swift as transcribed coordinates, proved
point-for-point identical to the harness that authored them, and a shelf's plate sigil and its
section dividers are visibly one drawing at two levels of detail. Before this task `CodexRootView`
calls a renderer that draws nothing; after it, eight bands are eight pictures and the Codex's
navigation is wordless without being blank.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `hunch-sigil-drawing/references/family-sigils.md` | whole file | The eight drawings with their §5.2 move, verb and parts; the ruling that *"a family sigil is the most reduced skeleton of its family; a skeleton silhouette is the same drawing with that skeleton's variables bound"*; the sites table (44 pt plate, 24 pt shelf bar, 24 pt divider); the four design decisions (`family.relational` lights nothing, `family.exclusive`'s complementary pattern is a theorem, `family.contextual` takes the link arc, `family.systemic`'s tie bar is the sigil) |
| `hunch-sigil-drawing/references/sigil-grammar.md` | G1–G6, §3, §4, §5, §6, §7 | Quote-don't-invent; ≤ 3 primitives; exactly one verb and no shared (primitive set, verb) pair; no bare quote; distinctness is measured; one home for the geometry. Plus the box/stage/`authorBound` moduli, the primitive vocabulary, the role → weight map, and the rule that a sigil never mirrors under RTL |
| `hunch-sigil-drawing/references/drawing-a-new-sigil.md` | §2, §3, §4, §5 | The `HunchCore/Sources/Sigils/` shape (`Sigil`, `SigilPoint`, `SigilStroke`, `SigilDetail`, `SigilCatalogue`), the app-side `SigilRenderer` and why it is a `Canvas` and never a `Shape`, the three tests, and the four-artefact write-back contract |
| `GAME_DESIGN.md` | §11.2 | The 44 pt plate sigil, the 24 pt shelf-bar sigil, and the skeleton drawn *"at 24 pt in the leading margin with a hairline divider"*; large shelves get 10–40 sections, band 1 gets four |
| `GAME_DESIGN.md` | §5.2 | The eight families and the conceptual move each demands — the design brief for each drawing, quoted by the catalogue and restated nowhere |
| `GAME_DESIGN.md` | §5.3 step 3 | The generator owns the family's skeleton list; the index → spec map is **its**, not this task's |
| `GAME_DESIGN.md` | §12.9 | `CodexShelfView` and `CodexPageView` carry no title: *"a shelf is titled by its family sigil"*. The eight family identifiers never enter the catalog |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | `SigilStroke.Form`'s switches carry no `default:`, so a new primitive cannot ship unclassified |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/SigilsTests/SigilCatalogueTests.swift`.
`references/drawing-a-new-sigil.md` §4 gives the parity suite; this is that suite plus the four
family-specific assertions this task owes.

```swift
import Foundation
import Testing
import Sigils
import LawGeneration            // Band

/// The shape `check-sigil-distinctness.js --json` emits. Decoding-only and test-local: nothing in
/// the shipping app reads JSON geometry.
private struct HarnessDump: Decodable {
    struct Point: Decodable, Equatable { var x, y: Double }
    struct Stroke: Decodable {
        var role: String
        var opacity: Double
        var form: String
        var closed: Bool?
        var filled: Bool?
        var points: [Point]?
        var centre: Point?
        var radius: Double?
        var from: Double?
        var to: Double?
    }
    struct Entry: Decodable { var rotate: Double; var strokes: [Stroke] }
    var sigils: [String: Entry]
}

@Suite("The sigil catalogue and its parity with SIGILS", .tags(.unit, .presubmission))
struct SigilCatalogueTests {

    /// Generated: `node check-sigil-distinctness.js --json > Fixtures/sigils.json`.
    /// `.copy("Fixtures")` preserves the directory, so the lookup passes `subdirectory:` (06 T54).
    private static func dump() throws -> HarnessDump {
        let url = try #require(Bundle.module.url(forResource: "sigils",
                                                 withExtension: "json",
                                                 subdirectory: "Fixtures"))
        return try JSONDecoder().decode(HarnessDump.self, from: Data(contentsOf: url))
    }

    @Test("every sigil stays inside its stage — no ink collides with a key border")
    func staysInsideTheStage() {
        let half = SigilMetrics.stage / 2
        for sigil in Sigil.allCases {
            for stroke in SigilCatalogue.strokes(for: sigil) {
                for point in stroke.form.extremePoints {
                    #expect(abs(point.x) <= half && abs(point.y) <= half, "\(sigil.rawValue) leaves the stage")
                }
            }
        }
    }

    @Test("the Swift has not forked from SIGILS — point for point, not key for key")
    func catalogueMatchesTheHarness() throws {
        let dump = try Self.dump()
        #expect(Set(dump.sigils.keys) == Set(Sigil.allCases.map(\.rawValue)))

        for sigil in Sigil.allCases {
            let expected = try #require(dump.sigils[sigil.rawValue], "\(sigil.rawValue) missing")
            let actual = SigilCatalogue.strokes(for: sigil)
            try #require(actual.count == expected.strokes.count,
                         "\(sigil.rawValue): \(actual.count) strokes, harness has \(expected.strokes.count)")
            for (i, pair) in zip(actual, expected.strokes).enumerated() {
                let (mine, theirs) = pair
                #expect(mine.role.harnessName == theirs.role, "\(sigil.rawValue) stroke \(i): role")
                #expect(abs(mine.opacity - theirs.opacity) < 1e-6, "\(sigil.rawValue) stroke \(i): opacity")
                #expect(mine.form.matches(theirs), "\(sigil.rawValue) stroke \(i): geometry has forked")
            }
        }
    }

    @Test("strokes are deterministic — no RNG, no clock, no dictionary iteration order")
    func strokesAreDeterministic() {
        for sigil in Sigil.allCases {
            #expect(SigilCatalogue.strokes(for: sigil) == SigilCatalogue.strokes(for: sigil))
        }
    }

    // MARK: the eight this task owns

    @Test("every band maps to a family sigil, and the map is a bijection")
    func everyBandHasASigil() {
        let sigils = Band.allCases.map(Sigil.family)
        #expect(sigils.count == Band.allCases.count)
        #expect(Set(sigils).count == sigils.count)
        #expect(sigils.allSatisfy { $0.rawValue.hasPrefix("family.") })
    }

    @Test("family.relational lights nothing — 'the law names no value' (§5.2)")
    func relationalLightsNothing() {
        let strokes = SigilCatalogue.strokes(for: .familyRelational)
        #expect(strokes.contains { $0.form.isFilled } == false,
                "a lit cell would contradict the family's own move")
    }

    @Test("family.contextual carries a link arc and family.relational does not — the thinnest margin")
    func contextualIsRelationalPlusTheArc() {
        #expect(SigilCatalogue.strokes(for: .familyContextual).contains { $0.form.isArc })
        #expect(SigilCatalogue.strokes(for: .familyRelational).contains { $0.form.isArc } == false)
    }

    @Test("skeleton detail binds blanks and adds no stroke of its own")
    func skeletonBindsRatherThanAdds() throws {
        for band in Band.allCases {
            let sigil = Sigil.family(band)
            let family = SigilCatalogue.strokes(for: sigil, detail: .family)
            let spec = try #require(Skeleton.first(in: band), "the generator lists no skeleton for \(band)")
            let skeleton = SigilCatalogue.strokes(for: sigil, detail: .skeleton(spec))
            #expect(skeleton.count >= family.count)
            #expect(skeleton.prefix(family.count).map(\.role) == family.map(\.role),
                    "\(sigil.rawValue): skeleton detail reordered the family's own strokes")
        }
    }

    @Test("band 1's four skeletons differ only by their attribute header (§11.2)")
    func bandOneSkeletonsDifferByHeaderOnly() throws {
        let specs = Skeleton.all(in: .literal)
        try #require(specs.count == 4)
        let drawings = specs.map { SigilCatalogue.strokes(for: .familyLiteral, detail: .skeleton($0)) }
        #expect(Set(drawings.map(\.count)).count == 1, "same stroke count")
        #expect(Set(drawings.map { $0.map(\.role) }).count == 1, "same role sequence")
        #expect(Set(drawings.map { $0.map(\.form) }).count == 4, "and four distinct geometries")
    }

    @Test("the raw value is the harness key, verbatim, for all eight")
    func rawValuesAreHarnessKeys() {
        #expect(Band.allCases.map { Sigil.family($0).rawValue } == [
            "family.literal", "family.pair", "family.exclusive", "family.relational",
            "family.contextual", "family.guarded", "family.composite", "family.systemic",
        ])
    }
}
```

`SigilStroke.Form.matches(_:)`, `Role.harnessName`, `Form.extremePoints`, `Form.isFilled` and
`Form.isArc` are `private` helpers in this file. **`matches` must have no `default:` arm** (`W29`):
a new `Form` case has to be classified here before the suite compiles again, which is the only thing
that stops a new primitive shipping unproven.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SigilCatalogueTests`

Expect missing `Sigil`, `SigilCatalogue`, `SigilMetrics`, `SigilStroke`, `Skeleton.all(in:)`, and a
missing `Fixtures/sigils.json`. **If `catalogueMatchesTheHarness` passes on an empty catalogue,** the
`Set` comparison has been written the wrong way round — both directions must be asserted, which the
`Set(dump.sigils.keys) == Set(Sigil.allCases…)` line does.

**Step 3 — implement.** Run the harness *first*:

```bash
d=.claude/skills/hunch-sigil-drawing
node $d/scripts/check-sigil-distinctness.js                 # whole matrix; must exit 0
node $d/scripts/check-sigil-distinctness.js --svg family.pair       # eyeball the close pair
node $d/scripts/check-sigil-distinctness.js --svg family.exclusive
node $d/scripts/check-sigil-distinctness.js --json > HunchCore/Tests/SigilsTests/Fixtures/sigils.json
```

Then transcribe `SIGILS`'s eight `family.*` entries into `SigilCatalogue.strokes(for:detail:)`, and
only then write the renderer.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Sigils/Sigil.swift` — `Sigil`, `SigilPoint`, `SigilStroke`, `SigilDetail`, `SigilMetrics`, `SigilCatalogue` (**extend, if E12·T05 already created it for `mode.*`**) |
| modify | `HunchCore/Sources/Sigils/Sigil.swift` — `static func family(_ band: Band) -> Sigil` |
| modify | `HunchCore/Sources/LawGeneration/Skeleton.swift` — `SkeletonSpec: Hashable, Sendable`, `Skeleton.all(in:)`, `Skeleton.first(in:)` (the generator already samples from this list; expose it) |
| create | `HunchCore/Tests/SigilsTests/SigilCatalogueTests.swift` |
| create | `HunchCore/Tests/SigilsTests/Fixtures/sigils.json` — **generated**, never hand-edited |
| modify | `HunchCore/Package.swift` — the `Sigils` target and `SigilsTests` with `resources: [.copy("Fixtures")]` |
| modify | `Modules/Sources/HunchUI/SigilRenderer.swift` — the real `draw(_:detail:lit:into:box:)` T02 stubbed |
| create | `Modules/Sources/CodexFeature/SkeletonDivider.swift` — the 24 pt leading sigil plus a hairline rule |
| modify | `.github/workflows/*.yml` — the `--json` freshness diff step |
| modify | `Scripts/check-source-hygiene.sh` — the same freshness diff, so a local run catches it too |
| modify | `tests.json` · `DECISIONS.md` — see *Acceptance criteria* |

## Implementation notes

### This task transcribes; it does not design

Run the skill's step-0 block before anything else. All eight `family.*` keys are **already in the
catalogue** with cleared distinctness, so `drawing-a-new-sigil.md` §1's first instruction applies:
*"If a key exists, the answer is that drawing — open its catalogue file and use it. Do not draw a
variant."* What is missing is rows 3 and 4 of the write-back contract — the Swift and the parity
fixture — and that is precisely where the geometry historically forks, because the obvious move is to
type the coordinates from the prose.

If the harness exits non-zero, **stop and fix the drawing, not the threshold.** `T` is
`C.Glyph.minimumPairwiseInkDifference` and the script exits 2 rather than invent one; a failure is a
design answer.

### One drawing, two detail levels

```swift
public enum SigilDetail: Sendable, Equatable { case family, skeleton(SkeletonSpec) }
```

`family-sigils.md`'s ruling, and the reason it matters: large shelves get 10–40 skeleton sections
(§11.2), so cutting silhouettes as separate art is ~200 drawings that must still look like their
shelf six months on. `.skeleton(spec)` **binds what `.family` leaves blank** — nothing is added:

| Element | `.family` | `.skeleton` |
|---|---|---|
| `notch` | empty rect | that attribute's own header drawing |
| `ladder` lit cells | the family's canonical pattern | the skeleton's actual subset |
| `wedge` | the generic leading-opening wedge | the actual comparator of the six |
| `couplerOpen` | hollow node | the actual `and` / `or` / `xor` |
| `ghostPlate` | present iff the family is contextual | unchanged |

`skeletonBindsRatherThanAdds` is what pins "binds, does not add": the family's own strokes keep their
roles and their order, and the skeleton's extra strokes come after. `bandOneSkeletonsDifferByHeaderOnly`
is the direct assertion of §11.2's *"band 1 gets four sections, one per attribute"* — at band 1 the
attribute **is** the skeleton.

**Do not enumerate skeletons here.** The map from `CodexPage.skeleton: UInt16` to a `SkeletonSpec` is
the generator's (§5.3 step 3). This task's only edit in `LawGeneration/` is to make the list readable
— if E06·T06 kept it `private`, promote the accessor; do not copy the list.

### `SkeletonSpec` must be `Hashable, Equatable, Sendable`

`SigilDetail`'s synthesized `Equatable` does not fire otherwise, and `SigilCatalogue.strokes` becomes
uncacheable and untestable in one step. If `LawGeneration`'s skeleton type is currently a closure or
a tuple, that is the change: make it a value.

### The renderer is a `Canvas`, and the context is by value

`drawing-a-new-sigil.md` §3 has the shipping implementation; transcribe it into
`Modules/Sources/HunchUI/SigilRenderer.swift` (§1's tree, not the skill file's illustrative
`Hunch/Rendering/` path). Three points not to sand off:

- **A sigil is never a `Shape`.** Every one carries at least two roles at different weights, and a
  `Shape` yields one path under one `StrokeStyle`.
- **`GraphicsContext` is taken by value**, not `inout` — the renderer sets no clip, opacity or
  transform, and an `inout` context is a licence for a future edit to leak one back to the host.
- **`env` is a stored property**, injected. Reading `@Environment` inside the renderer makes it
  untestable and makes the drawing depend on where it was instantiated.

### Ink and weight, and the one risk

`stroke.secondary` when the host is not lit, `stroke.primary` when it is. That is the entire palette
of a sigil; `hue.*` and `accent.*` are both forbidden and the type split makes the first
uncompilable. Weights come from the role map (`sigil-grammar.md` §5), which reuses the **glyph's own
size regime** — `U < 48` versus `U ≥ 48` — so a 24 pt divider and a 44 pt plate sigil take different
`verb` weights from one drawing.

The risk `family-sigils.md` names: the `ghost` role sits at `weight.hairline`, the lightest rung, and
must stay clearly under `contour` once Bold Text's × 1.25 and High Contrast's flat + 0.5 have both
resolved. `hunch-design-tokens` owns that order; do not write either number here, and check the
resolved pair in the DEBUG snapshot gallery at `U = 24`.

### Sites and states

`sites: [24, 44]`. Three placements, all in the Codex:

| Site | `U` | Detail | State |
|---|---|---|---|
| shelf plate, leading (`CodexRootView`) | 44 | `.family` | idle · lit when sealed |
| shelf instrument bar (`CodexShelfView`) | 24 | `.family` | depictive |
| skeleton divider, leading margin of a section | 24 | `.skeleton` | depictive |

A **sealed** shelf takes a doubled rim on the *plate* (T07's drawing, `shelf-plate.md`'s ownership);
the sigil lights to `stroke.primary` and gains no rim. An **empty** Codex draws one dashed plate with
**no** family sigil at all — an empty shelf has no family to name yet (T02 asserts this).

`depictive` is a placement in this skill's own signature, **not** a seventh `KeyState`. Six cases,
one home, `hunch-chrome-and-meta/references/key.md` §3.

### VoiceOver

The plate is the control; the family sigil is **not separately focusable** (`.image`, merged into the
host's label). The skeleton divider is `.staticText, .isHeader` and is reached by the `.headings`
rotor. No new `Localizable.xcstrings` key: the eight family identifiers are internal, exactly like
the five Profile axis names, and §12.9 budgets none for them.

### The write-back contract, in full

Four artefacts, in this order. Rows 1 and 2 are already done for these eight keys; rows 3 and 4 are
this task.

| # | Artefact | Edit | Enforced by |
|---|---|---|---|
| 1 | `scripts/check-sigil-distinctness.js` → `SIGILS` | already present | it *is* the geometry |
| 2 | `references/family-sigils.md` | already present | the harness's `DOC` check |
| 3 | `HunchCore/Sources/Sigils/Sigil.swift` | the eight `case`s **and the transcribed coordinates** | `catalogueMatchesTheHarness` |
| 4 | `HunchCore/Tests/SigilsTests/Fixtures/sigils.json` | regenerate; never hand-edit | the CI freshness diff |

```bash
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --json \
  | diff -u HunchCore/Tests/SigilsTests/Fixtures/sigils.json - \
  || { echo "::error::sigil fixture is stale — regenerate it"; exit 1; }
```

`--json` rounds to 6 dp so the fixture is byte-stable across Node versions, and emits keys in
catalogue order rather than sorted, because that order **is** the append-only contract.

### If `Sigil.swift` already exists

E12·T05 draws DRIFT's mode sigil and E13/E14 draw ECHO's and SIEVE's, so `Sigil`, `SigilCatalogue`
and `SigilRenderer` may already be on disk with four `mode.*` cases. In that case: **add the eight
cases and their coordinates, add `SigilDetail`'s `.skeleton` arm, regenerate the fixture, and delete
nothing.** `catalogueMatchesTheHarness` will then be covering twelve keys, which is correct — the
harness has twenty-two and the suite asserts key-set equality with `Sigil.allCases`, so it fails
loudly until the remaining ten (E16·T09's five vertex marks, T08's four facet stamps plus the off
state) land. Record that expected-red state in `DECISIONS.md` if the epics land out of order, or
scope `allCases` equality to the keys shipped so far and tighten it in E16·T09 — the second is
cleaner and is the recommendation.

## Acceptance criteria

- [ ] `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` exits 0, and its `closest pairs` line still names `family.pair` / `family.exclusive` with a margin above `T`.
- [ ] `swift test --package-path HunchCore --filter SigilCatalogueTests` green, all nine tests.
- [ ] The `--json` freshness diff produces no output.
- [ ] `grep -rn "hue\.\|accent\.\|lineWidth: [0-9]\|#[0-9A-Fa-f]\{6\}" Modules/Sources/HunchUI/SigilRenderer.swift HunchCore/Sources/Sigils/` returns nothing.
- [ ] `grep -rn "default:" HunchCore/Tests/SigilsTests/SigilCatalogueTests.swift` returns nothing.
- [ ] `grep -c "case family" HunchCore/Sources/Sigils/Sigil.swift` reports 8.
- [ ] `grep -rn "LITERAL\|SYSTEMIC\|RELATIONAL" Modules/Sources/HunchUI/Resources/Localizable.xcstrings` returns nothing — no family name entered the catalog.
- [ ] `Modules/Sources/CodexFeature/SkeletonDivider.swift` draws at `U = 24` with `.skeleton(spec)` and carries `.isHeader`.
- [ ] `DECISIONS.md` records the `Sigil.allCases` scoping choice if the sigil epics land out of order.
- [ ] `tests.json` carries: sigil parity against the fixture, stage containment, determinism, the band → sigil bijection, and band 1's four header-only skeletons.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T09: the eight family sigils, skeleton detail and the SIGILS parity fixture"`

## Out of scope

- **The four `mode.*` sigils** — **E12·T05** (DRIFT), **E17·T04** (the rack, key states and the gates).
- **The five `profile.*` vertex sigils** — **E16·T09**.
- **The five `facet.*` stamps** — **T08**, which follows the identical write-back contract.
- **The shelf plate, its states, its arc and its rim** — **T02** and **T07**.
- **Where the divider sits in the grid and how the scrubber snaps to it** — **T04**. This task draws the divider; T04 places it.
- **`SkeletonSpec`'s contents and the generator's skeleton list** — **E06·T06**. This task only makes it readable and `Equatable`.
- **The DEBUG snapshot gallery** — **E04·T09**; add the eight rows to it there if it exists, and note the addition here if it does not.
