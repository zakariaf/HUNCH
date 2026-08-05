# T05 — Contrast and token tests

| | |
|---|---|
| **Epic** | E03 — Design tokens and RenderEnv |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 (only — this task may run before or alongside T03 and T04) |
| **Delivers** | §14.1 *Palette tokens* (the verification half) · *Register segregation* (the luminance-adjacency half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `references/palette.md` §1 is the measured column every expectation in this task comes from, §2 is the register of the nine cells where §13.2's stated ratios are arithmetically wrong, and §4's last bullet is why the amber/brass adjacency has to be asserted rather than assumed. `scripts/contrast.swift` prints the whole matrix, so nothing here is typed from memory. |
| `hunch-swift-testing` | This is the epic's gate suite. The skill fixes the tag pair (`.unit`, `.presubmission`), the `06 T21` loop rule this suite has to stay inside, `#require` versus `#expect`, and the `tests.json` obligation — every invariant gets a structured entry and no entry is ever weakened to reach green. |

## Objective

The epic's gate becomes executable: a suite that recomputes every published contrast ratio from its
own hex, in all three themes, and fails if any of them has moved by 0.01. It also ships the three
assertions the design cannot afford to leave as prose — the High Contrast state-bearing floor, the
exact 21 : 1 primary pair, and the fact that `hue.amber` and `accent.brass` are only **1.22 : 1**
apart, so nothing may ever be built that assumes luminance separates the two registers.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.2 | the ten tokens' hexes and the register-segregation rule; the prose claim that amber and brass are "1.36 : 1 apart", which is wrong and is asserted against |
| `GAME_DESIGN.md` | §13.1 | the 1.06 : 1 ground shift — luminance is the only depth cue in dark |
| `GAME_DESIGN.md` | §13.11 | "every token clears 9.7 : 1; the primary pair clears 21 : 1" under High Contrast |
| `GAME_DESIGN.md` | §13.12 | gate 10: under High Contrast every foreground/background pair ≥ 4.5 : 1 |
| `hunch-design-tokens/references/palette.md` | §1 | **the expectation table.** Every `: 1` in it is computed, not quoted, and this suite is the second computation |
| `hunch-design-tokens/references/palette.md` | §2 | the nine wrong cells and the one wrong prose claim, each with its measured value and its (nil) design consequence |
| `hunch-design-tokens/references/light-theme.md` | §2 | hue-against-keyline — 7.93 / 5.22 / 7.74 / 5.84, the measurement that makes the light theme work and that canon never takes |
| `hunch-swift-testing/references/test-plan.md` | — | tags, the `tests.json` obligation, and why this runs on the host with no simulator |

## TDD — the test comes first

This task **is** the test. There is no implementation step: T01 and T02 already shipped everything
it asserts, so step 2's failure mode is different from every other task in the epic — the suite must
fail only if a value is *wrong*, and a green first run is the expected outcome for most rows. Write
every row before running anything, then verify each expectation against
`swift .claude/skills/hunch-design-tokens/scripts/contrast.swift` rather than trusting the
transcription.

**Step 1 — write the test.** Create `HunchCore/Tests/TokensTests/ContrastTests.swift`:

```swift
import Testing

import Tokens

/// The epic gate. Every expectation below is `palette.md` §1's **measured** column, and every
/// one of them is recomputed here from the token's own hex by WCAG 2.1 sRGB relative luminance.
/// The number therefore exists in exactly two places on purpose: the reference table a human
/// reads, and the assertion that recomputes it. `scripts/check-tokens.swift` is the third leg,
/// keeping `palette.md`, `Prim.swift` and §13.2 in agreement.
///
/// Quote this file's expectations, never §13.2's ratio columns — nine of those cells disagree
/// with their own hexes (`palette.md` §2).
@Suite("Contrast — every §13.2 ratio, recomputed", .tags(.unit, .presubmission))
struct ContrastTests {

    /// Rounded to two places, because "matches the table to 2 dp" is the gate's wording and a
    /// tolerance would let a real 0.009 drift through unreported.
    private func ratio(_ colour: RGB8, over palette: Palette) -> Double {
        let raw = colour.contrastRatio(against: palette.ground.base)
        return (raw * 100).rounded() / 100
    }

    // MARK: - the three themes, row by row

    @Test("dark: every token against #0B0A08")
    func darkMatrix() {
        let p = Palette(theme: .dark)
        #expect(ratio(p.ground.raised, over: p) == 1.06)
        #expect(ratio(p.ground.sunken, over: p) == 1.03)
        #expect(ratio(p.surface.cell, over: p) == 1.03)
        #expect(ratio(p.surface.cellLit, over: p) == 1.12)
        #expect(ratio(p.stroke.primary, over: p) == 15.61)
        #expect(ratio(p.stroke.secondary, over: p) == 3.26)
        #expect(ratio(p.stroke.hairline, over: p) == 1.61)
        #expect(ratio(p.accent.brass.rgb, over: p) == 7.20)
        #expect(ratio(p.accent.brassPress.rgb, over: p) == 3.70)
        #expect(ratio(p.accent.cold.rgb, over: p) == 12.06)
        #expect(ratio(p.accent.coldPress.rgb, over: p) == 6.10)
        #expect(ratio(p.hue.amber.rgb, over: p) == 8.79)
        #expect(ratio(p.hue.teal.rgb, over: p) == 5.78)
        #expect(ratio(p.hue.frost.rgb, over: p) == 8.58)
        #expect(ratio(p.hue.rose.rgb, over: p) == 6.47)
        #expect(p.glyphKeyline == nil)
    }

    @Test("light: every token against #F4EFE4")
    func lightMatrix() throws {
        let p = Palette(theme: .light)
        #expect(ratio(p.ground.raised, over: p) == 1.07)
        #expect(ratio(p.ground.sunken, over: p) == 1.10)
        #expect(ratio(p.surface.cell, over: p) == 1.04)
        #expect(ratio(p.surface.cellLit, over: p) == 1.11)
        #expect(ratio(p.stroke.primary, over: p) == 15.58)
        #expect(ratio(p.stroke.secondary, over: p) == 4.94)
        #expect(ratio(p.stroke.hairline, over: p) == 1.38)
        #expect(ratio(p.accent.brass.rgb, over: p) == 4.96)
        #expect(ratio(p.accent.brassPress.rgb, over: p) == 8.35)
        #expect(ratio(p.accent.cold.rgb, over: p) == 6.32)
        #expect(ratio(p.accent.coldPress.rgb, over: p) == 10.02)
        // Raw hue contrast is below 3 : 1 and is SUPPOSED to be: the index stroke is the hue
        // channel and colour is the redundant copy. The silhouette is carried by the keyline.
        #expect(ratio(p.hue.amber.rgb, over: p) == 1.96)
        #expect(ratio(p.hue.teal.rgb, over: p) == 2.98)
        #expect(ratio(p.hue.frost.rgb, over: p) == 2.01)
        #expect(ratio(p.hue.rose.rgb, over: p) == 2.67)
        #expect(ratio(try #require(p.glyphKeyline), over: p) == 15.58)
    }

    @Test("high contrast: every token against #000000")
    func highContrastMatrix() {
        let p = Palette(theme: .highContrast)
        #expect(ratio(p.ground.raised, over: p) == 1.06)
        #expect(ratio(p.ground.sunken, over: p) == 1.00)
        #expect(ratio(p.surface.cell, over: p) == 1.00)
        #expect(ratio(p.surface.cellLit, over: p) == 1.14)
        #expect(ratio(p.stroke.primary, over: p) == 21.00)
        #expect(ratio(p.stroke.secondary, over: p) == 9.68)
        #expect(ratio(p.stroke.hairline, over: p) == 3.04)
        #expect(ratio(p.accent.brass.rgb, over: p) == 13.08)
        #expect(ratio(p.accent.brassPress.rgb, over: p) == 7.77)
        #expect(ratio(p.accent.cold.rgb, over: p) == 15.00)
        #expect(ratio(p.accent.coldPress.rgb, over: p) == 9.06)
        #expect(p.hue.ranked.allSatisfy { ratio($0.rgb, over: p) == 21.00 })
        #expect(p.glyphKeyline == nil)
    }

    // MARK: - the gates

    /// §13.11's "clears 9.7 : 1" is rounding 9.68 — `palette.md` §1's High Contrast floors
    /// paragraph. The floor is on the **state-bearing set only**: `stroke.hairline` (3.04) is
    /// declared never state-bearing, and a press state is a transient echo of a control that
    /// already cleared the floor at rest.
    @Test("the High Contrast state-bearing floor")
    func highContrastFloor() throws {
        let p = Palette(theme: .highContrast)
        let stateBearing: [RGB8] =
            [p.stroke.primary, p.stroke.secondary, p.accent.brass.rgb, p.accent.cold.rgb]
            + p.hue.ranked.map(\.rgb)
        // `#require` for the test's precondition, `#expect` for the assertion it came for.
        let floor = try #require(stateBearing.map { $0.contrastRatio(against: p.ground.base) }.min())
        #expect(floor >= 9.68)

        // Deliberately below the floor, and named here so nobody "fixes" them upward.
        #expect(ratio(p.stroke.hairline, over: p) < 9.68)
        #expect(ratio(p.accent.brassPress.rgb, over: p) < 9.68)
        #expect(ratio(p.accent.coldPress.rgb, over: p) < 9.68)
    }

    /// §13.11: "the primary pair clears 21 : 1". White on black is exactly 21.0 by the formula,
    /// so this is asserted unrounded — it is the one cell where an inequality would hide a
    /// substituted near-white.
    @Test("the primary pair is exactly 21 : 1 under High Contrast")
    func primaryPairIsExact() {
        let p = Palette(theme: .highContrast)
        #expect(p.stroke.primary.contrastRatio(against: p.ground.base) == 21.0)
        #expect(p.stroke.primary == Prim.neutral0)
        #expect(p.ground.base == Prim.neutral1000)
    }

    /// §13.12 gate 10.
    @Test("every High Contrast foreground clears 4.5 : 1")
    func highContrastForegroundsClear45() {
        let p = Palette(theme: .highContrast)
        let foregrounds: [RGB8] =
            [p.stroke.primary, p.stroke.secondary,
             p.accent.brass.rgb, p.accent.brassPress.rgb,
             p.accent.cold.rgb, p.accent.coldPress.rgb]
            + p.hue.ranked.map(\.rgb)
        #expect(foregrounds.allSatisfy { $0.contrastRatio(against: p.ground.base) >= 4.5 })
    }

    /// **The register assertion.** §13.2 claims these sit "1.36 : 1 apart in luminance"; measured,
    /// in the dark theme, they are 1.22 : 1 — closer than canon believed and far too close for
    /// brightness to carry any part of the distinction. Register segregation and ring geometry
    /// carry all of it. Nothing may ever be built that assumes a luminance gap here, and no
    /// verdict may ever be encoded by brightness alone.
    @Test("hue.amber and accent.brass are 1.22 : 1 apart, and that is the whole margin")
    func registersAreNotSeparatedByLuminance() {
        let p = Palette(theme: .dark)
        let amberBrass = p.hue.amber.rgb.contrastRatio(against: p.accent.brass.rgb)
        #expect((amberBrass * 100).rounded() / 100 == 1.22)
        #expect(amberBrass < 1.5)

        // The other adjacency canon states, which IS correct.
        let frostCold = p.hue.frost.rgb.contrastRatio(against: p.accent.cold.rgb)
        #expect((frostCold * 100).rounded() / 100 == 1.41)
    }

    /// `light-theme.md` §2's third row — the measurement that is not in canon and without which
    /// the light theme silently becomes monochrome: the hue must read as a distinct band *inside*
    /// the ink outline, not be swallowed by it. Worst case is teal at 5.22 : 1.
    @Test("in light, every hue reads as a band inside the keyline")
    func hueReadsInsideTheKeyline() throws {
        let p = Palette(theme: .light)
        let keyline = try #require(p.glyphKeyline)
        #expect((p.hue.amber.rgb.contrastRatio(against: keyline) * 100).rounded() / 100 == 7.93)
        #expect((p.hue.teal.rgb.contrastRatio(against: keyline) * 100).rounded() / 100 == 5.22)
        #expect((p.hue.frost.rgb.contrastRatio(against: keyline) * 100).rounded() / 100 == 7.74)
        #expect((p.hue.rose.rgb.contrastRatio(against: keyline) * 100).rounded() / 100 == 5.84)
        #expect(p.hue.ranked.allSatisfy { $0.rgb.contrastRatio(against: keyline) >= 4.5 })
    }

    /// Dark carries the silhouette in the hue itself — worst is teal at 5.78 : 1 — which is why
    /// no keyline is drawn there. This is the assertion behind §13.2's "Dark needs none".
    @Test("in dark, the worst hue still clears 4.5 : 1 unaided")
    func darkNeedsNoKeyline() throws {
        let p = Palette(theme: .dark)
        let worst = try #require(
            p.hue.ranked.map { $0.rgb.contrastRatio(against: p.ground.base) }.min())
        #expect(worst >= 4.5)
        #expect(p.glyphKeyline == nil)
    }

    /// §13.1's depth model, measured. It is not a token — it is what two tokens already imply —
    /// and it is here rather than in `C.swift` so it cannot go stale against the hexes.
    /// `palette.md` §2 notes that the dark step is 1.03, not §13.2's claimed 1.06, which is
    /// precisely why the light theme gets depth from an impression instead (`light-theme.md` §3).
    @Test("the ground shift, per theme")
    func groundShift() {
        let dark = Palette(theme: .dark)
        #expect(ratio(dark.ground.raised, over: dark) == 1.06)
        #expect(ratio(dark.ground.sunken, over: dark) == 1.03)

        let light = Palette(theme: .light)
        #expect(ratio(light.ground.raised, over: light) == 1.07)
        #expect(ratio(light.ground.sunken, over: light) == 1.10)

        let contrast = Palette(theme: .highContrast)
        #expect(ratio(contrast.ground.raised, over: contrast) == 1.06)
        #expect(ratio(contrast.ground.sunken, over: contrast) == 1.00)
    }

    /// Documenting test. §13.2's ratio columns are wrong in nine cells; the hexes are all right.
    /// Asserting the divergence — rather than quietly using the measured value — means that if
    /// anyone ever "corrects" `palette.md` back toward canon, this fires and names the cell.
    @Test("the four canon cells that matter are still wrong, and still harmless")
    func canonRatiosDivergeFromTheirOwnHexes() {
        let dark = Palette(theme: .dark)
        #expect(ratio(dark.hue.amber.rgb, over: dark) != 9.5)   // canon says 9.5; it is 8.79
        #expect(ratio(dark.hue.teal.rgb, over: dark) != 6.4)    // canon says 6.4; it is 5.78

        let light = Palette(theme: .light)
        #expect(ratio(light.stroke.hairline, over: light) != 1.5)   // canon says 1.5; it is 1.38

        let contrast = Palette(theme: .highContrast)
        #expect(ratio(contrast.stroke.hairline, over: contrast) != 3.3)  // canon says 3.3; it is 3.04
    }
}
```

**Step 2 — verify each expectation against the script, not against the file you copied it from.**

```bash
swift .claude/skills/hunch-design-tokens/scripts/contrast.swift            # the whole matrix
swift .claude/skills/hunch-design-tokens/scripts/contrast.swift '#C9922F' '#0B0A08'
swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift        # must exit 0
```

Then break one deliberately and watch the suite fail: change `Prim.bone100`'s last byte in
`Prim.swift`, run `swift test --package-path HunchCore --filter ContrastTests`, confirm
`darkMatrix` reports `15.61` against something else and that `check-tokens.swift` also exits 1
naming the row, then `git checkout -- HunchCore/Sources/Tokens/Prim.swift`. A gate suite that has
never been seen to fail is a green tick over an absence of evidence.

**Step 3 — there is no implementation step.** If a row fails on the first honest run, the bug is in
`Prim.swift` or `Palette.swift`, not in the expectation — `palette.md` §1's column and
`contrast.swift` are two independent computations of the same number and they agree.

**Step 4 — record it.** Add the four `tests.json` entries listed under acceptance.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/TokensTests/ContrastTests.swift` |
| modify | `tests.json` — four structured invariant entries |
| modify | `DECISIONS.md` — the `ContrastTests.swift` naming deviation |

## Implementation notes

**Why the numbers are written down here at all.** Everywhere else in this library, restating a value
creates a second source of truth. This suite is the exception and the reason is structural: a test
that recomputed the expectation from the same code under test would assert nothing. So the
expectation column is `palette.md` §1 — a *measured* table, produced by a script, checked in CI by a
third program — and this suite is an independent recomputation of it from the shipped hexes. Three
legs, and each catches what the others cannot:

| Leg | Catches |
|---|---|
| `Scripts/check-source-hygiene.sh` checks 9–10 | a hex that escaped `Tokens/` |
| `check-tokens.swift` | `palette.md` and `Prim.swift` disagreeing, and a canon-marked row whose hex no longer matches §13.2 |
| `ContrastTests` | a hex that moved without its ratio moving, in the built code rather than in a document |

**Rounding, and what to do if a cell fails by 0.01.** `(raw * 100).rounded() / 100` rounds half away
from zero, which is what `contrast.swift`'s `%.2f` does. If a cell ever fails by exactly one
hundredth, print the unrounded value and compare against `contrast.swift`'s unrounded output before
changing anything — and **do not loosen the comparison to a tolerance.** A tolerance wide enough to
absorb a rounding edge is wide enough to absorb a real drift, and the whole point of this suite is
that §13.2 shipped with nine cells nobody recomputed.

**Loop discipline.** `06 T21` treats a `for` loop inside a test as a bug, and HUNCH's one sanctioned
deviation is the generator corpus (`08 §7.4`) — not this. The matrices are therefore flat runs of
`#expect`, one per row, so a failure names its own token in the expanded expression. The two places
a collection appears (`hue.ranked`, the state-bearing set) use `allSatisfy`/`min()`, which are
expressions and not loops.

**No simulator, no `@testable`.** Everything here is `public` because `Modules/` consumes it across
a package boundary, so a plain `import Tokens` is enough (`06 T4`). The suite runs on the host inside
the 10-second budget and adds a handful of milliseconds.

**`tests.json`.** Four entries, each with the invariant, the command that runs it and its current
status. These are the epic's gate rows 4 and 5 made machine-readable, and no later task may delete
or weaken one:

1. `tokens.contrast.matrix` — every §13.2 ratio recomputed from its hex matches `palette.md` §1 to
   2 dp in all three themes.
2. `tokens.contrast.highContrastFloor` — the High Contrast state-bearing set's minimum is ≥ 9.68 : 1
   and the primary pair is exactly 21 : 1.
3. `tokens.contrast.registerAdjacency` — `hue.amber` and `accent.brass` are 1.22 : 1 apart; no
   verdict, state or affordance may be encoded by luminance separation between the registers.
4. `tokens.contrast.lightKeyline` — every hue reads at ≥ 4.5 : 1 *inside* the light theme's keyline.

**Record in `DECISIONS.md`:** *"`ContrastTests.swift` does not mirror a single source file (`06 T5b`);
it is the epic gate suite and is named for the property it proves. It exercises `RGB8` and `Palette`
across three themes, and splitting it into `RGB8Tests` and `PaletteTests` additions would put the
gate in two files. First of two deliberate T5b deviations in E03; the second is
`ComponentTokenTests.swift`."*

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ContrastTests` is green, with 11 tests.
- [ ] The deliberate-corruption drill in step 2 was run and observed to fail, and the tree is clean
      afterwards: `git status --porcelain HunchCore/Sources/Tokens/Prim.swift` is empty.
- [ ] `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` exits 0.
- [ ] Every measurable cell of `palette.md` §1 has an assertion — 15 in dark (`ground.base` is the
      reference and `glyph.keyline` is `nil` there), 16 in light (the keyline included), and 15 under
      High Contrast (11 written out plus the four `hue.*` through `ranked`). Verify against the
      script's printed matrix, which has the same shape.
- [ ] `tests.json` carries all four entries above, with status `pass`.
- [ ] `grep -n 'for ' HunchCore/Tests/TokensTests/ContrastTests.swift` returns nothing.
- [ ] The fast suite is still under 10 s.
- [ ] `DECISIONS.md` carries the naming entry.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. It will want to collapse the three flat matrices into
   one parameterised loop over `(token, theme, expected)` triples. Refuse: `06 T21`, and a loop
   turns forty-five self-describing failures into one that says "row 23".
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E03/T05: the contrast gate — every ratio recomputed, the HC floor, the 1.22:1 register adjacency"`

## Out of scope

- The space scale, the radii, the type roles and the modifier composition — asserted in **T02** and
  **T03**, beside the code they test. This task owns colour measurement only.
- Anything requiring a rendered pixel: greyscale distinctness of the 256 glyphs, the `T` constant,
  and the monochrome coverage-mask identity are **E04·T06**, and the full snapshot matrix
  (component × state × theme × Bold Text/Reduce Motion) is **E04·T09**.
- `performAccessibilityAudit` and §13.12's other twelve gates — **E19·T11**.
- Changing any hex. If a ratio is wrong, the hex is right and the *table* is the bug — fix
  `palette.md`, re-run `check-tokens.swift`, and never re-light Okabe–Ito to reach a number.
