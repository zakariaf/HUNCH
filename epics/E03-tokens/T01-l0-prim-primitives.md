# T01 — L0 `Prim` primitives

| | |
|---|---|
| **Epic** | E03 — Design tokens and RenderEnv |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | nothing (E01 must be merged: `HunchCore/Package.swift` and `Scripts/check-source-hygiene.sh` must exist) |
| **Delivers** | §14.1 *Palette tokens* (the L0 half) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | It owns the L0/L1/L2 layering and is the only place the hexes are written down. `references/palette.md` §3 is the L0 inventory and `references/tokens-swift-layout.md` §3 is the file, already typechecked — you are transcribing, not designing. It also owns the `.sRGB` pin, which is the whole reason this file exists as `RGB8` and not as a `Color`. |
| `hunch-build-and-ci` | Only if `Tokens` is not already a target: `references/package-manifests.md` §2 is `HunchCore/Package.swift` in full, and it is the authority on the target's `swiftSettings`, its absent `dependencies:` and its absent `.defaultIsolation`. |

`hunch-design-tokens` is first and is not optional — every later drawing task assumes its
vocabulary, and this task creates the vocabulary's ground floor.

## Objective

`HunchCore/Sources/Tokens/` exists as a leaf SwiftPM target holding two files: `RGB8`, an
8-bit sRGB colour with WCAG 2.1 relative luminance and contrast ratio on it, and `Prim`, the caseless
enum that holds **every hex in the application** plus the three scalar constants the resolution
order needs. Nothing in the repository outside this directory may contain a hex literal after this
task, and the four Okabe–Ito values are in the tree verbatim, with no re-lighting, in a form a test
can check.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.2 | the ten semantic tokens' hexes across three themes — the source of every `c`-marked value in `palette.md`; and the Okabe–Ito-verbatim rule |
| `GAME_DESIGN.md` | §13.11 | the two modifier scalars: Bold Text ×1.25, High Contrast +0.5 pt; and the 1.35× (AX2) art ceiling |
| `hunch-design-tokens/references/palette.md` | §1, §2, §3 | **normative for values.** §3 is the L0 inventory by family; §1 carries the measured ratio for each; §2 is the register of the nine cells where §13.2's *stated* ratios disagree with its own hexes |
| `hunch-design-tokens/references/tokens-swift-layout.md` | §1, §3, §4 | the file set, the compiling source of `RGB8.swift` and `Prim.swift`, and the SwiftPM target |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | `W16`, `W18`, `W7` | constants live in a caseless enum; `let` everywhere; no access level on an `extension` |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P24`, `P28` | one top-level type per file named for it; `Constants.swift` is a banned filename — `Prim` names what it holds |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | the boundary predicate: this target imports `Foundation` and nothing else, and every value in it is writable in a test |

Do not copy a hex into this task's notes, a comment, a commit message or another file. `palette.md`
§3 is the inventory; read it there.

## TDD — the test comes first

**Step 1 — write the failing tests.** Two files, mirroring the two source files (`06 T5b`).

Create `HunchCore/Tests/TokensTests/RGB8Tests.swift`:

```swift
import Testing

import Tokens

@Suite("RGB8 — the colour arithmetic every ratio in the app is computed with", .tags(.unit, .presubmission))
struct RGB8Tests {

    @Test("hex decomposes into channels and round-trips")
    func hexRoundTrips() {
        let amber = RGB8(hex: 0xE6_9F_00)
        #expect(amber.red == 0xE6)
        #expect(amber.green == 0x9F)
        #expect(amber.blue == 0x00)
        #expect(amber.hex == 0xE6_9F_00)
        #expect(RGB8(hex: amber.hex) == amber)
    }

    @Test("relative luminance is WCAG 2.1 sRGB at both ends of the range")
    func luminanceEndpoints() {
        #expect(RGB8(hex: 0xFF_FF_FF).relativeLuminance == 1.0)
        #expect(RGB8(hex: 0x00_00_00).relativeLuminance == 0.0)
    }

    @Test("the linear/gamma branch is taken at the 0.04045 knee, not above it")
    func luminanceUsesTheLinearSegmentBelowTheKnee() {
        // 10/255 = 0.0392 < 0.04045, so the channel is divided by 12.92, not exponentiated.
        let dim = RGB8(hex: 0x0A_0A_0A)
        let linear = (10.0 / 255.0) / 12.92
        #expect(abs(dim.relativeLuminance - linear) < 1e-12)
    }

    @Test("contrast ratio is symmetric and spans exactly 1.0 … 21.0")
    func contrastRatioIsSymmetricAndBounded() {
        let white = RGB8(hex: 0xFF_FF_FF)
        let black = RGB8(hex: 0x00_00_00)
        #expect(white.contrastRatio(against: black) == 21.0)
        #expect(black.contrastRatio(against: white) == 21.0)
        #expect(white.contrastRatio(against: white) == 1.0)
    }
}
```

Create `HunchCore/Tests/TokensTests/PrimTests.swift`:

```swift
import Testing

import Tokens

@Suite("Prim — L0", .tags(.unit, .presubmission))
struct PrimTests {

    /// §13.2 and §2 forbid re-lighting Okabe–Ito. This is the assertion that makes the
    /// prohibition mechanical: any edit to the four published values fails here first.
    @Test("Okabe–Ito is verbatim")
    func okabeItoIsVerbatim() {
        #expect(Prim.okabeItoAmber.hex == 0xE6_9F_00)
        #expect(Prim.okabeItoTeal.hex == 0x00_9E_73)
        #expect(Prim.okabeItoFrost.hex == 0x56_B4_E9)
        #expect(Prim.okabeItoRose.hex == 0xCC_79_A7)
    }

    /// `<family><lightness>`, lightness ascending as the colour darkens. The naming rule is
    /// not decoration: `palette.md` §3 orders every family by it, and a member inserted in the
    /// wrong slot silently breaks the reader's ability to pick a neighbouring step.
    @Test(
        "every family's luminance descends as its step number ascends",
        arguments: [
            [Prim.soot750, Prim.soot800, Prim.soot850, Prim.soot900, Prim.soot950],
            [Prim.paper50, Prim.paper100, Prim.paper150, Prim.paper200, Prim.paper300],
            [Prim.bone100, Prim.bone200, Prim.bone450, Prim.bone500, Prim.bone700, Prim.bone900],
            [Prim.neutral0, Prim.neutral400, Prim.neutral600, Prim.neutral850, Prim.neutral900, Prim.neutral1000],
            [Prim.brass200, Prim.brass300, Prim.brass400, Prim.brass500, Prim.brass600, Prim.brass800],
            [Prim.cold200, Prim.cold300, Prim.cold400, Prim.cold500, Prim.cold700, Prim.cold800],
        ]
    )
    func familyLightnessDescends(family: [RGB8]) {
        let luminances = family.map(\.relativeLuminance)
        #expect(luminances == luminances.sorted(by: >))
    }

    /// High Contrast's neutrals are achromatic by construction — a warm neutral would put a
    /// hue back into the theme whose entire job is to have none.
    @Test("the neutral family is achromatic")
    func neutralsAreAchromatic() {
        for neutral in [Prim.neutral0, Prim.neutral400, Prim.neutral600,
                        Prim.neutral850, Prim.neutral900, Prim.neutral1000] {
            #expect(neutral.red == neutral.green)
            #expect(neutral.green == neutral.blue)
        }
    }

    /// §13.11's three scalars. They live at L0 because they are literals with no meaning:
    /// `StrokeWeight.resolved(in:)` and `RenderEnv.artScale` are where they acquire one.
    @Test("the modifier scalars are the values §13.11 states")
    func modifierScalars() {
        #expect(Prim.boldTextStrokeScale == 1.25)
        #expect(Prim.highContrastStrokeOffset == 0.5)
        #expect(Prim.artScaleCeiling == 1.35)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter RGB8Tests`
then `--filter PrimTests`.

The first failure must be `no such module 'Tokens'` (the target does not exist yet) and then
`cannot find 'RGB8' in scope`. If instead you see a *malformed test* error — a bad `@Test(arguments:)`
shape or an unparseable tag — fix the test before writing any source. A test that compiles and
passes before `Prim.swift` exists is testing nothing.

**Step 3 — implement** the minimum that turns it green: the target, then `RGB8.swift`, then
`Prim.swift`.

**Step 4 — green, then refactor.** Regenerate the trailing `// L 0.xxxx` comments in `Prim.swift`
from `swift .claude/skills/hunch-design-tokens/scripts/contrast.swift` rather than typing them, and
re-run.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Tokens/RGB8.swift` |
| create | `HunchCore/Sources/Tokens/Prim.swift` |
| modify | `HunchCore/Package.swift` — only if `Tokens` / `TokensTests` are not already there |
| create | `HunchCore/Tests/TokensTests/RGB8Tests.swift` |
| create | `HunchCore/Tests/TokensTests/PrimTests.swift` |
| modify | `DECISIONS.md` — the `Tokens` target entry |

## Implementation notes

**The target first.** `08 §1`'s tree predates `design/DESIGN-SYSTEM-SCOPE.md` §4.4's ruling and does
not list a `Tokens` directory; `hunch-build-and-ci/references/package-manifests.md` §2 does, and it
is the later and more specific document. Check what E01 actually shipped before editing:

```bash
grep -n 'name: "Tokens"' HunchCore/Package.swift
```

If it is absent, add exactly two lines, in the positions §2 gives them:

```swift
.target(name: "Tokens", swiftSettings: coreSettings),           // leaf, no dependencies
.testTarget(name: "TokensTests", dependencies: ["Tokens"], swiftSettings: coreSettings),
```

and add `"Tokens"` to the `HunchCore` library product's `targets:` list. Three properties of that
entry are load-bearing and none of them is a preference:

- **No `dependencies:`.** `Tokens` is a leaf. It does not depend on `Glyphs` even though
  `Palette.Hue` will mirror `Glyph.Hue`'s four cases in T02 — that mapping is one four-arm `switch`
  owned by `HunchUI/GlyphCanvas.swift` in E04, and one switch is cheaper than a package dependency
  edge (`tokens-swift-layout.md` §4).
- **No `.defaultIsolation`.** No `HunchCore` target gets one (`01 P17`, `05 R7`, `08 §4`). Every type
  here is a `Sendable` value and nothing touches the main actor.
- **`swiftSettings: coreSettings`,** the same three upcoming features every other core target gets.
  Do not invent a fourth setting for this target.

Record in `DECISIONS.md`: *"`HunchCore` gains a ninth source target, `Tokens`, which `08 §1`'s tree
does not list. `DESIGN-SYSTEM-SCOPE.md` §4.4 rules the token layer into `HunchCore` so that
`swift test` can assert every contrast ratio with no simulator; `package-manifests.md` §2 is the
manifest of record."*

**`RGB8.swift`.** Paste `tokens-swift-layout.md` §3's `RGB8` block as-is — it typechecks under
`swiftc -swift-version 6 -strict-concurrency=complete`. Four details worth knowing why:

- `init(hex:)` takes a `UInt32` so a row of §13.2 can be read across without transposition. It is
  legal in `Prim.swift` and nowhere else; check 9 of the hygiene script is what makes "nowhere else"
  true, and T06 proves it fires.
- `relativeLuminance` is WCAG 2.1's exact formula with the `0.04045` knee and the `2.4` exponent.
  Do not simplify it to a gamma of 2.2 — every ratio in `palette.md` was computed with this one and
  a different curve moves all of them by a few hundredths, which is exactly the size of the
  divergence §2 of `palette.md` exists to record.
- `contrastRatio(against:)` adds `0.05` to both luminances before dividing, which is what makes the
  range `1.0 … 21.0` closed and the function symmetric.
- The type is `Hashable, Sendable` and has no `Codable` conformance. Colours are never persisted;
  the theme is (`RenderEnv.Theme` is `Codable`, T02).

**`Prim.swift`.** Paste §3's `Prim` block. It is a caseless `enum` (`W16`) of `static let`s (`W18`),
grouped by family with a `// MARK`-free single-line comment per family, and each member carries its
measured luminance in a trailing comment. The doc comment states the rule that matters most: *never
referenced from a view, a component or `C`; only `Palette` and the L1 scales may name a `Prim`.*
T04 lands that rule as check 11.

**Why `.sRGB` is already the subject of this file.** There is no `Color` here and no colour space
parameter — `RGB8` *is* sRGB by construction, and the doc comment says so. The pin becomes
executable in T06's adapter, where a `Color(.displayP3, …)` constructor with the same three numbers
produces a different colour and moves every ratio in `palette.md` with no test noticing. Writing the
reason down here, at the type, is what makes the adapter's one-word difference legible.

**What must not be added.** No elevation, shadow, material or status-colour family (§13.1,
`dimensions-strokes-opacity.md` §6 — the category does not exist). No lightness steps for
Okabe–Ito: there are none because those four are never re-lit, and adding `okabeItoAmber600` is the
first move of the re-lighting `light-theme.md` §6 rejects. No `Prim.Pt` namespace of point scalars —
`DESIGN-SYSTEM-SCOPE.md` §4.3 sketches one, but `Space`, `Radius` and `StrokeWeight` in T02 hold
their values directly, and a `p3_0 = 3.0` indirection buys nothing and reads as noise at every call
site.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RGB8Tests` and `--filter PrimTests` are green.
- [ ] `swift build --package-path HunchCore --target Tokens` succeeds.
- [ ] `grep -n 'name: "Tokens"' HunchCore/Package.swift` shows one `.target(…)` line carrying no
      `dependencies:` — the target is a leaf — and `"Tokens"` appears in the library product's
      `targets:` list.
- [ ] `grep -rn 'import ' HunchCore/Sources/Tokens/` shows `Foundation` and nothing else.
- [ ] `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` exits 0 — check B
      (every hex in `palette.md` appears in `Prim.swift`) now runs for the first time instead of
      being skipped.
- [ ] `Scripts/check-source-hygiene.sh` exits 0: the new hexes are inside `HunchCore/Sources/Tokens/`
      and check 9 excludes exactly that directory.
- [ ] `DECISIONS.md` carries the `Tokens`-target entry.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it. Note that `Prim`'s repetition is *not* a
   simplification target: a family loop or a computed ramp would remove the one property the file
   has, which is that every value is visible and greppable.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E03/T01: Tokens target, RGB8 with WCAG luminance, and the L0 Prim inventory"`

## Out of scope

- `Palette`, `AccentColor`, `HueColor` and theme selection — **T02**. `Prim` knows nothing about
  themes; a `Prim` member that mentioned one would have crossed from L0 to L1.
- `RenderEnv` and anything that resolves — **T02** (the record) and **T03** (the resolution).
  `Prim.boldTextStrokeScale` is a number here; it acquires its meaning in `StrokeWeight.resolved`.
- Every contrast assertion beyond the white/black endpoints — **T05**, which owns the full matrix.
  This task proves the *arithmetic*; T05 proves the *values*.
- The SwiftUI `Color` adapter and the `.sRGB` constructor — **T06**.
