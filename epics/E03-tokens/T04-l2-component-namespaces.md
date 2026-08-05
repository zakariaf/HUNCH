# T04 — L2 `C.<component>` namespaces

| | |
|---|---|
| **Epic** | E03 — Design tokens and RenderEnv |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | §14.1 *Palette tokens* (the L2 half — the scattered-literal inventory of `DESIGN-SYSTEM-SCOPE.md` §2(a)) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | It owns the L2 *layer* — the naming rule, the L2 → L1 → L0 direction, and the rule that a substitution terminates resolution. `references/tokens-swift-layout.md` §3's `C` block ships two worked namespaces already typechecked; `references/dimensions-strokes-opacity.md` §5 is the authoritative map of which PHOSPHOR opacity became which L2 member and **which owning skill creates it** — that table is what stops this task absorbing seven values it does not own; §6 is the matching list for dimensions. |
| `hunch-swift-code` | Thirty-three nested caseless enums in one file is a `P24` judgement call, and `W16` (constants in a caseless enum) plus `P28` (`Constants.swift` is banned — `C` names what it holds) are the rules that make it the right one. |

## Objective

`C.swift` exists with one namespace per row of `design/DESIGN-SYSTEM-SCOPE.md` §3's thirty-three
component rows, so that from now on the question "where does this literal go?" is a lookup rather
than a decision. Five of those namespaces are populated with the scattered-literal inventory §2(a)
names — the values that today live in six different GDD sections and were each destined to be typed
into Swift twice — and the file references L1 only, never `Prim`, with that direction enforced by a
new check 11 in T06.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `design/DESIGN-SYSTEM-SCOPE.md` | §3 | the thirty-three component rows — this is the list of namespaces, verbatim and complete |
| `design/DESIGN-SYSTEM-SCOPE.md` | §2(a), §4.1 | the scattered-literal inventory this task absorbs, and the rule that L2 references L1 only, never L0 |
| `GAME_DESIGN.md` | §4.2 | the unlit ramp cell — 25 % opacity plus a diagonal cancel hatch, "readable with no colour and no brightness discrimination" |
| `GAME_DESIGN.md` | §4.3 | the inert ramp — 30 % with a hairline slash, **one state not two**; and the Bench-column Assay at 4 pt cells, expanding to a 23 pt read-only inspector |
| `GAME_DESIGN.md` | §11.1 | the Codex page's rule-tiles at 0.78× the live Bench, and that page's Assay at 9.5 pt cells |
| `GAME_DESIGN.md` | §11.2 | the extension thumbnail — the 16 × 16 deck grid at 3.5 pt cells |
| `GAME_DESIGN.md` | §11.10 | the Profile contour's ink: spokes, interior fill, the inner offset contour, their High Contrast values, and the tremble amplitude's two scalars |
| `GAME_DESIGN.md` | §13.5, §13.11 | the glyph body-weight regime and the ×3 halo; the High Contrast substitutions for the unlit cell and the cancel hatch |
| `hunch-design-tokens/references/tokens-swift-layout.md` | §3 (`C` block) | `C.Glyph` and `C.Ramp` complete and typechecked — paste, do not retype |
| `hunch-design-tokens/references/dimensions-strokes-opacity.md` | §5, §6 | the seven PHOSPHOR opacities and their owners; the named component dimensions and their owners. **Both tables are exclusions from this task** |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | `W16`, `W18` | caseless enums, `static let` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/TokensTests/ComponentTokenTests.swift`:

```swift
import Testing

import Tokens

@Suite("C — L2 component tokens", .tags(.unit, .presubmission))
struct ComponentTokenTests {

    // MARK: - stage 4: derived from the already-resolved weight

    /// The size regime is a **rule**, not a token: below 48 pt the silhouette drops to `bodySm`.
    @Test("the glyph body weight follows the size regime, resolved")
    func bodyStrokeFollowsTheSizeRegime() {
        let plain = RenderEnv()
        #expect(C.Glyph.bodyStroke(side: 96, in: plain) == plain.weight(.body))
        #expect(C.Glyph.bodyStroke(side: 44, in: plain) == plain.weight(.bodySm))
        #expect(C.Glyph.bodyStroke(side: 48, in: plain) == plain.weight(.body))
    }

    /// `+1.0` and `×3` are geometric relationships — the keyline must show 0.5 pt on each side
    /// of the hue, and the halo must be three times whatever it doubles. They are computed from
    /// the resolved value and are never themselves scaled or offset.
    @Test("derived values come from the resolved weight, not the base")
    func derivedValuesComeFromTheResolvedWeight() {
        let boldLight = RenderEnv(theme: .light, isBoldTextEnabled: true)
        #expect(C.Glyph.keylineStroke(side: 96, in: boldLight) == 4.75)   // 3.0 × 1.25 + 1.0
        #expect(C.Glyph.haloStroke(side: 96, in: boldLight) == 11.25)     // 3.75 × 3
    }

    /// The renderer branches on `nil`, never on `theme`.
    @Test("there is no keyline outside the light theme", arguments: RenderEnv.Theme.allCases)
    func keylineIsLightOnly(theme: RenderEnv.Theme) {
        let env = RenderEnv(theme: theme)
        #expect((C.Glyph.keylineStroke(side: 96, in: env) == nil) == (theme != .light))
    }

    // MARK: - substitution terminates resolution

    /// §13.11 states an explicit High Contrast value for both of these, so both terminate
    /// resolution: 0.40 is not 0.25 + anything, and 2.0 pt is not 1.0 + 0.5 and not 2.0 + 0.5.
    @Test("High Contrast substitutions do not also take the offset")
    func substitutionsAreNotAlsoOffset() {
        let contrast = RenderEnv(theme: .highContrast)
        #expect(C.Ramp.cellUnlitInk(in: contrast) == 0.40)
        #expect(C.Ramp.cancelHatchWeight(in: contrast) == 2.0)

        for theme in [RenderEnv.Theme.dark, .light] {
            let env = RenderEnv(theme: theme)
            #expect(C.Ramp.cellUnlitInk(in: env) == 0.25)
            #expect(C.Ramp.cancelHatchWeight(in: env) == 1.0)
        }
    }

    /// §4.3: "one inert state, not two" — nobody should have to learn the difference between
    /// "empty" and "vacuous". One member, so one drawing.
    @Test("inert is one value and is dimmer than unlit but not invisible")
    func inertIsOneState() {
        #expect(C.Ramp.inertInk == 0.30)
        #expect(C.Ramp.inertInk > C.Ramp.cellUnlitInk(in: RenderEnv()))
    }

    // MARK: - the scattered-literal inventory

    /// §4.3, §11.1, §11.2 — four sites, four sizes, one member. The Bench column and the
    /// inspector are the same widget at two scales, which is why the inspector needs no new
    /// drawing and why these four belong together.
    @Test("every Assay site reads its cell size from one member")
    func assayCellSites() {
        #expect(C.Assay.cellSide(.benchColumn) == 4)
        #expect(C.Assay.cellSide(.inspector) == 23)
        #expect(C.Assay.cellSide(.codexPage) == 9.5)
        #expect(C.Assay.cellSide(.codexThumbnail) == 3.5)
        #expect(C.Assay.Site.allCases.allSatisfy { C.Assay.cellSide($0) > 0 })
    }

    /// The grid is 16 × 16 at every site, so the site's overall side is derived, never stated
    /// twice. §11.1's 152 pt page Assay and §11.2's 60 pt thumbnail both fall out of this.
    @Test("the Assay's overall side is derived from its cell")
    func assaySideIsDerived() {
        #expect(C.Assay.side(.codexPage) == C.Assay.cellSide(.codexPage) * 16)
        #expect(C.Assay.side(.benchColumn) == 64)
    }

    @Test("the Codex page draws rule-tiles at 0.78× the live Bench")
    func codexTileScale() {
        #expect(C.CodexPage.tileScale == 0.78)
        #expect(C.CodexPage.tileScale < 1)
    }

    /// §11.10: five hairline spokes at 12 %, interior fill 6 %, a 1.5 pt inner offset contour at
    /// 20 %. High Contrast lifts the spokes to 25 % and takes the fill to zero, because a 6 %
    /// wash is exactly what Increase Contrast exists to remove.
    @Test("the Profile contour's ink, and its High Contrast substitution")
    func profileContourInk() {
        let plain = RenderEnv()
        #expect(C.ProfileContour.spokeInk(in: plain) == 0.12)
        #expect(C.ProfileContour.interiorFill(in: plain) == 0.06)
        #expect(C.ProfileContour.innerOffsetInk == 0.20)

        let contrast = RenderEnv(theme: .highContrast)
        #expect(C.ProfileContour.spokeInk(in: contrast) == 0.25)
        #expect(C.ProfileContour.interiorFill(in: contrast) == 0)
    }

    /// §11.10's `A = R0 · 0.05 · (1 − min(1, nᵢ/24))`. The two scalars live here; the formula
    /// is E16·T10's, and it must be written from these rather than from the sentence.
    @Test("the tremble scalars")
    func trembleScalars() {
        #expect(C.ProfileContour.trembleScale == 0.05)
        #expect(C.ProfileContour.trembleConfidenceSamples == 24)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ComponentTokenTests`
→ `cannot find 'C' in scope`. If it fails on `C.Assay.Site` not conforming to `CaseIterable`, that is
still the right kind of failure — a missing symbol, not a malformed test.

**Step 3 — implement** `C.swift`.

**Step 4 — green, then refactor,** then run the L2-discipline grep in the acceptance list.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Tokens/C.swift` |
| create | `HunchCore/Tests/TokensTests/ComponentTokenTests.swift` |
| modify | `DECISIONS.md` — the `C.Assay.cellSide` ownership entry, and the test-file naming deviation |

## Implementation notes

**The thirty-three namespaces.** They are §3's rows in §3's order, one nested caseless enum each,
UpperCamel. Generate the list rather than transcribing it:

```bash
awk '/^## 3\. The component inventory/,/^## 4\./' design/DESIGN-SYSTEM-SCOPE.md \
  | grep -E '^\| \*\*' | sed 's/^| \*\*\([^*]*\)\*\*.*/\1/' | grep -v '^\*'
```

| §3 row | Namespace | Populated by |
|---|---|---|
| Glyph | `C.Glyph` | **this task** (weights) + E04·T01–T05 (geometry) |
| Verdict ring | `C.VerdictRing` | E04·T07 |
| Ghost frame | `C.GhostFrame` | E04·T07 |
| Machined bar | `C.MachinedBar` | E04·T07 |
| Link arc / return elbow | `C.LinkArc` | E04·T08 |
| Cancel hatch | `C.CancelHatch` | E04·T08 (geometry — the *weight* substitution is `C.Ramp`'s, below) |
| Tick row | `C.TickRow` | E04·T08 |
| Arc meter | `C.ArcMeter` | E04·T08 |
| Mode sigil | `C.ModeSigil` | E17·T04 |
| Family sigil | `C.FamilySigil` | E15·T09 |
| Ramp | `C.Ramp` | **this task** (inks and hatch weight) + E09·T02 (cell rects) |
| Attribute header | `C.AttributeHeader` | E09·T02 |
| Rule-tile | `C.RuleTile` | E09·T02 |
| Bridge | `C.Bridge` | E09·T02 |
| Wedge | `C.Wedge` | E09·T02 |
| Fork | `C.Fork` | E09·T02 |
| Tally | `C.Tally` | E09·T02 |
| Coupler | `C.Coupler` | E09·T02 |
| Assay grid | `C.Assay` | **this task** (cell sizes) + E09·T05 (grid geometry, lit ink) |
| Seal | `C.Seal` | E09·T07 |
| Throat | `C.Throat` | E08·T03 |
| Ribbon | `C.Ribbon` | E08·T05 |
| Gate band | `C.GateBand` | E14·T02 |
| Key | `C.Key` | E17·T03 |
| Instrument bar | `C.InstrumentBar` | E17·T03 |
| Rule / section boundary | `C.Rule` | E17·T05 |
| Scrim | `C.Scrim` | E14·T07 |
| Numeral readout | `C.NumeralReadout` | E16·T11 |
| Stock `Form`/`List`/`Alert` | `C.StockControl` | E17·T06–T08 |
| Shelf plate | `C.ShelfPlate` | E15·T02 |
| Extension thumbnail | `C.ExtensionThumbnail` | E15·T03 |
| Profile contour | `C.ProfileContour` | **this task** (inks, tremble scalars) + E16·T08 (geometry) |
| Codex page composite | `C.CodexPage` | **this task** (tile scale) + E15·T05 |

An empty namespace carries a one-line doc comment naming the epic and task that fills it — that
comment is the whole value of shipping it empty. It costs nothing at runtime and turns "invent a
place for this number" into "add a member to the namespace that already has an owner", which is the
failure mode §2(a) documents.

**One namespace the mapping table needs that is *not* a §3 row:** `C.Reveal`
(`c.reveal.lawGhostInk`, `dimensions-strokes-opacity.md` §5). Do **not** create it here. It is
`hunch-motion-and-feedback`'s and arrives with E09·T10, and creating it now would put a namespace in
the file that no §3 row justifies — which is exactly the drift the row-per-namespace rule prevents.
`Space.swift`'s doc comment mentions `c.settingsRow.labelInset` as an illustration of semantic
spacing; it is an illustration, not a member, and must not be shipped.

**`C.Glyph` and `C.Ramp` are pasted, not written.** `tokens-swift-layout.md` §3's `C` block ships
both, typechecked. Two placement facts to keep straight:

- `C.Ramp.cancelHatchWeight(in:)` stays in `C.Ramp` even though "Cancel hatch" is its own §3 row.
  The row owns the *mark* — angle, spacing, caps, the diagonal-versus-slash variant — and
  `hunch-shared-marks` draws it in E04·T08. What lives in `C.Ramp` is the *ramp cell's* weight
  substitution, which is the value §13.11 states in the same breath as the 25 → 40 % cell ink.
  Splitting them would put two halves of one sentence in two namespaces.
- `C.Glyph` and the model type `Glyph` (E02·T01, `Glyphs` target) are different modules, and L2 is
  always written fully qualified at a call site (`C.Glyph.bodyStroke(…)`), so there is no ambiguity.
  `Tokens` does not depend on `Glyphs` and must not acquire the edge.

**The four scattered-literal groups this task lands, and how to model each.**

1. **The Assay's four cell sizes.** Model the site as a nested `public enum Site: CaseIterable`
   with `benchColumn`, `inspector`, `codexPage`, `codexThumbnail`, and expose
   `cellSide(_:) -> Double` plus `side(_:) -> Double` where `side = cellSide × 16`. The grid is
   16 × 16 at every site, so deriving the overall side is what keeps §11.1's 152 pt and §11.2's
   60 pt from being stated a second time. A `switch` over `Site` with no `default:` means a fifth
   site is a compile error.
2. **The Codex page's tile scale.** One `static let`. The 291 pt → 227 pt rail arithmetic that
   follows from it is layout and belongs to E15·T05.
3. **The Profile contour's ink.** `spokeInk(in:)` and `interiorFill(in:)` are functions of the
   environment because §11.10 gives both an explicit High Contrast value — substitutions, so they
   terminate resolution and are never also modified. `innerOffsetInk` is a constant. The contour's
   own stroke weights (2 pt brass, 1.5 pt inner offset) are **not** landed here: 1.5 is
   `weight.bodySm` and 2.0 has no L1 token, so the pair is a geometry decision E16·T08 must make
   against the L1 ladder rather than a value to transcribe.
4. **The tremble scalars.** `trembleScale` and `trembleConfidenceSamples`. The amplitude formula
   `A = R0 · 0.05 · (1 − min(1, n/24))` is E16·T10's and must be written from these two members.
   Landing the scalars without the formula is the point: the formula is choreography, the scalars
   are values, and §2(a) lists only the value.

**What this task must not absorb.** `dimensions-strokes-opacity.md` §5 maps seven PHOSPHOR opacities
to L2 and names an owning skill for each; five of the seven — `c.assay.litInk`,
`c.ribbon.revealBeat1Ink`, `c.reveal.lawGhostInk`, `c.seal.railPulse`, `c.ruleTile.emptyRailPulse` —
are created by their owning skill, not here. §6 does the same for dimensions and is explicit that it
states no numbers, because a value written twice is a value that will be edited once. If you are
about to type a glyph pitch, a pip radius, a throat side, a cell rect, a key rect or a shelf-plate
dimension into this file, stop: every one of them belongs to a later epic's owning skill.

**The 1.06 : 1 ground shift is not a token.** §2(a) lists it among the scattered literals, and it is
the one entry on that list that must **not** become a member. It is a *measurement* of two tokens
that already exist — `ground.raised` against `ground.base` — so a `C.something.groundShift = 1.06`
would be a second source of truth for a value the two hexes already determine, and it would go stale
the moment either hex moved. Its home is an assertion, and it is in **T05**. The depth *rule* it
serves is already a predicate: `env.isImpressionDepthEnabled`.

**Record in `DECISIONS.md`:** *"`C.Assay.cellSide(_:)` and `C.Assay.side(_:)` ship in E03·T04 rather
than with `hunch-bench-instruments`, because `DESIGN-SYSTEM-SCOPE.md` §2(a) names the four cell
sizes as part of the scattered-literal inventory this epic exists to absorb and they are spread over
three GDD sections. `hunch-bench-instruments` remains the owner of the Assay's grid geometry and of
any fifth site."* And: *"`C.swift`'s test file is `ComponentTokenTests.swift`, not `CTests.swift`.
`06 T5b` mirrors the source path; a one-letter test-file name is not a name. Second deliberate
deviation from T5b in this epic, after `ContrastTests.swift`."*

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ComponentTokenTests` is green.
- [ ] Exactly thirty-three namespaces, matching §3 row for row:
      `grep -cE '^    public enum [A-Z]' HunchCore/Sources/Tokens/C.swift` prints `33`, and equals
      `awk '/^## 3\. The component inventory/,/^## 4\./' design/DESIGN-SYSTEM-SCOPE.md | grep -cE '^\| \*\*[^*]'`.
- [ ] **L2 names no L0:** `grep -n 'Prim\.' HunchCore/Sources/Tokens/C.swift` returns nothing.
- [ ] Every empty namespace carries a doc comment naming its owning epic and task:
      `grep -B1 -E '^    public enum [A-Z]' HunchCore/Sources/Tokens/C.swift | grep -c '///'` is 33.
- [ ] `grep -n 'default:' HunchCore/Sources/Tokens/C.swift` returns nothing.
- [ ] `Scripts/check-source-hygiene.sh` exits 0 — every literal in this file is inside `Tokens/`.
- [ ] `swift test --package-path HunchCore` green and under 10 s.
- [ ] `DECISIONS.md` carries both entries.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. It will want to delete the twenty-eight empty
   namespaces as dead code. Do not let it: they are the declared owner for every literal the next
   nine epics will otherwise scatter, and the doc comment on each is the reason they exist. Record
   the refusal in the commit body if `/simplify` raises it.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E03/T04: C.<component> — 33 namespaces and the §2(a) scattered-literal inventory"`

## Out of scope

- Every L2 member listed against a later epic in the table above. Adding one now is inventing a
  component dimension inside the token skill, which `hunch-design-tokens`' *Never* list forbids.
- The 1.06 : 1 ground shift — **T05**, as an assertion over two existing tokens.
- The glyph size-regime *drawing* (`GlyphCanvas` choosing `S`) — **E04·T05**. This task ships the
  weight rule; E04 ships the geometry that feeds it a side.
- The `S ≥ 32` bloom gate — **E04·T05**. `env.isBloomEnabled` (T03) is the environment half; the
  size half is geometry.
- The SwiftUI adapter that turns any of this into a `Color`, a `Font` or an `Animation` — **T06**.
