# T06 — Dynamic Type

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | Dynamic Type (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**. `references/render-env.md` §2 owns the art multiplier and the fact that Dynamic Type is *not* in the resolution chain: `env.artScale` multiplies **lengths** at the drawing site and never a weight, because weight already has an axis and compounding the two makes a Bold Text player at AX2 draw a heavy stroke on a larger glyph — heavier twice. `references/dimensions-strokes-opacity.md` §3 owns `minimumScaleFactor` being 1.0 everywhere. |
| `hunch-accessibility` | `references/environment-settings.md` §2 owns **which screen re-flows, which element re-flows, and at what `DynamicTypeSize`** — including the threshold ruling this task implements, and the trap that `.isAccessibilitySize` is the wrong predicate for every one of those rows. |

## Objective

At the end of this task art scales with the type multiplier to its 1.35× ceiling and then **freezes**,
and every screen that cannot hold its reference layout above that ceiling **re-flows** instead of
shrinking — the Bench to a single-rail pager, ECHO's tray to two columns, the Codex grid from five
columns to two, the mode rack from 2 × 2 to 1 × 4, the Profile stat block to one item per line.
`minimumScaleFactor` is 1.0 everywhere with no exceptions, so a row that cannot fit grows.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.8 (Dynamic Type) | the full category ladder: chrome type %, art scale, and the layout change at each of the four bands; the 1.35× ceiling at accessibility1; the re-flows at accessibility2…5 |
| `GAME_DESIGN.md` | §13.11 (the AX3–AX5 table) | per-screen behaviour: the Dial's ramps scrolling and the commit bar pinned; the Bench pager and the Assay moving to a full-width strip; the Codex thumbnail fixed because it is a picture; the Profile portrait not scaling; the Anomaly ribbon reflowing 28 × 1 → 7 × 4; Onboarding unaffected because it has no text |
| `GAME_DESIGN.md` | §12.8 (chrome text) | `lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`, **no `minimumScaleFactor`** — if a row cannot fit, the row grows |
| `GAME_DESIGN.md` | §2 (Dynamic Type) | the play surface has no text, so the type multiplier drives *art* scale; at AX2 and above the Bench pages rather than shrinking targets |
| `GAME_DESIGN.md` | §11.10, §11.11 P3 | the Profile portrait holds its geometry (a drawing, not text); the five vertex sigils reflow from a ring to a vertical list keeping their hit rects |
| `.claude/skills/hunch-accessibility/references/environment-settings.md` | §2 | the threshold table, row by row, with each row's geometry owner named |
| `.claude/skills/hunch-design-tokens/references/render-env.md` | §2, §3 | `artScale = min(max(typeMultiplier, 1), 1.35)`; `env.isArtScaleClamped`; art never multiplies a weight |

## TDD — the test comes first

Every threshold is a comparison on a `Comparable` value, so every one of them is a pure function and a
host test. No simulator, no snapshot — those are T11's.

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/DynamicTypeLayoutTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import HunchCore
@testable import HunchUI

@Suite("Dynamic Type thresholds and art scale — §12.8, §13.11", .tags(.unit, .presubmission))
struct DynamicTypeLayoutTests {

    // MARK: art scale

    @Test("art scales with the type multiplier and then freezes at the ceiling")
    func artScaleClampsAtTheCeiling() {
        #expect(RenderEnv(typeMultiplier: 1.00).artScale == 1.00)
        #expect(RenderEnv(typeMultiplier: 1.20).artScale == 1.20)
        #expect(RenderEnv(typeMultiplier: 1.35).artScale == Prim.artScaleCeiling)
        #expect(RenderEnv(typeMultiplier: 2.60).artScale == Prim.artScaleCeiling)
        #expect(RenderEnv(typeMultiplier: 0.80).artScale == 1.00)      // never below 1
    }

    @Test("art scale is monotone non-decreasing across the whole multiplier range")
    func artScaleIsMonotone() {
        let scales = stride(from: 0.8, through: 3.2, by: 0.05).map { RenderEnv(typeMultiplier: $0).artScale }
        #expect(zip(scales, scales.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test("above the ceiling the environment reports the clamp, so a view can re-flow instead of grow")
    func clampIsObservable() {
        #expect(RenderEnv(typeMultiplier: 1.20).isArtScaleClamped == false)
        #expect(RenderEnv(typeMultiplier: 1.60).isArtScaleClamped == true)
    }

    // MARK: the re-flow thresholds

    @Test("the re-flows engage at .accessibility2 and not before", arguments: DynamicTypeSize.allCases)
    func reflowThreshold(_ size: DynamicTypeSize) {
        let expected = size >= .accessibility2
        #expect(AXLayout.benchIsSingleRailPager(size) == expected)
        #expect(AXLayout.echoTrayIsTwoColumnPager(size) == expected)
        #expect(AXLayout.codexShelfColumns(size) == (expected ? 2 : 5))
        #expect(AXLayout.modeRackIsSingleColumn(size) == expected)
        #expect(AXLayout.profileStatBlockIsOnePerLine(size) == expected)
        #expect(AXLayout.assayIsFullWidthStrip(size) == expected)
        #expect(AXLayout.anomalyRibbonIsFourRows(size) == expected)
    }

    @Test("the Profile's vertex sigils are the one exception: they reflow at .accessibility3",
          arguments: DynamicTypeSize.allCases)
    func vertexSigilThreshold(_ size: DynamicTypeSize) {
        #expect(AXLayout.vertexSigilsAreAVerticalList(size) == (size >= .accessibility3))
    }

    @Test("the Codex list's rows reflow to two lines at .accessibility3")
    func codexRowThreshold() {
        #expect(AXLayout.codexRowIsTwoLines(.accessibility2) == false)
        #expect(AXLayout.codexRowIsTwoLines(.accessibility3) == true)
    }

    @Test(".isAccessibilitySize is NOT the predicate — AX1 is where art freezes, not where layout re-flows")
    func accessibilitySizeIsNotTheThreshold() {
        #expect(DynamicTypeSize.accessibility1.isAccessibilitySize)
        #expect(AXLayout.benchIsSingleRailPager(.accessibility1) == false)
    }

    // MARK: things that never move

    @Test("the commit bar is pinned and never scrolls, at any size", arguments: DynamicTypeSize.allCases)
    func commitBarIsAlwaysPinned(_ size: DynamicTypeSize) {
        #expect(AXLayout.commitBarScrolls(size) == false)
    }

    @Test("a drawing never scales with type: the Codex thumbnail and the Profile portrait hold",
          arguments: DynamicTypeSize.allCases)
    func drawingsDoNotScaleWithType(_ size: DynamicTypeSize) {
        #expect(AXLayout.codexThumbnailScales(size) == false)
        #expect(AXLayout.profilePortraitScales(size) == false)
    }

    @Test("SIEVE is unchanged at every size — the gate is a fixed target and the lane is timed geometry",
          arguments: DynamicTypeSize.allCases)
    func sieveIsUnchanged(_ size: DynamicTypeSize) {
        #expect(AXLayout.sieveLayout(size) == .reference)
    }

    @Test("the Dial's ramps scroll and its gutters tighten above AX1, and only there")
    func dialAboveTheCeiling() {
        #expect(AXLayout.dialRampsScroll(.xxxLarge) == false)
        #expect(AXLayout.dialRampsScroll(.accessibility1) == true)
        #expect(AXLayout.dialGutterIsTight(.large) == false)
        #expect(AXLayout.dialGutterIsTight(.accessibility1) == true)
    }

    // MARK: nothing shrinks

    @Test("minimumScaleFactor is 1.0 everywhere — the token, not a call-site value")
    func minimumScaleFactorIsOne() {
        #expect(Typography.minimumScaleFactor == 1.0)
    }

    @Test("every type role reports lineLimit(nil) and vertical fixedSize", arguments: TypeRole.allCases)
    func chromeTextNeverTruncates(_ role: TypeRole) {
        #expect(Typography.lineLimit(role) == nil)
        #expect(Typography.fixesVerticalSize(role))
    }
}
```

And append **check 11d** to `Scripts/check-source-hygiene.sh`:

```bash
# check 11d — nothing shrinks to make a row fit. §12.8: if a row cannot fit, the row grows.
grep -Rn 'minimumScaleFactor' Modules/Sources --include='*.swift' && fail "minimumScaleFactor is 1.0 everywhere (§12.8, §13.4)"
grep -Rn 'truncationMode(' Modules/Sources --include='*.swift' && fail "chrome text never truncates (§12.8)"
grep -RnE 'lineLimit\([0-9]' Modules/Sources --include='*.swift' && fail "chrome text is lineLimit(nil) (§12.8)"
# and the art ceiling is a token, not a decimal a grep cannot see
grep -Rn '1\.35' Modules/Sources --include='*.swift' && fail "spell the art ceiling Prim.artScaleCeiling"
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter DynamicTypeLayoutTests`

Missing `AXLayout`, `Typography.minimumScaleFactor`, `Typography.lineLimit(_:)`,
`RenderEnv.isArtScaleClamped`. The trap here is `reflowThreshold`: a stub returning `false`
unconditionally passes for every non-accessibility size and fails only on the four AX cases — that is
still a real failure, but read the output and confirm all four AX rows are red before implementing,
because a stub returning `size >= .accessibility1` fails only *one* row and is easy to mistake for
success.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/AXLayout.swift` — every threshold as a pure function of `DynamicTypeSize` |
| modify | `Modules/Sources/HunchUI/Typography.swift` — `minimumScaleFactor`, `lineLimit(_:)`, `fixesVerticalSize(_:)` as tokens |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the single-rail pager and the Assay's full-width strip at ≥ AX2 |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — the ramps' vertical scroll region above AX1; the commit bar pinned |
| modify | `Modules/Sources/LoomFeature/EchoRoundView.swift` — the tray's two-column pager |
| modify | `Modules/Sources/CodexFeature/CodexShelfView.swift`, `CodexPageView.swift` — 5 → 2 columns; rule-tiles frozen at the ceiling with metadata scrolling below |
| modify | `Modules/Sources/MetaFeature/FrameView.swift` — the mode rack 2 × 2 → 1 × 4, scrolling |
| modify | `Modules/Sources/MetaFeature/ProfileView.swift` — stat block one item per line; vertex sigils ring → list at AX3 |
| modify | `Modules/Sources/MetaFeature/AnomalyView.swift` — the 28-cell ribbon 28 × 1 → 7 × 4 |
| create | `Modules/Tests/HunchUITests/DynamicTypeLayoutTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — check 11d |
| modify | `tests.json` — the Dynamic Type entry (gate 8's non-snapshot half) |
| modify | `DECISIONS.md` — the `.accessibility2` threshold ruling |

## Implementation notes

### The threshold conflict, and the ruling

§12.8's category ladder puts the pager and the re-flows at `accessibility2 … 5`. §13.11's prose says
"above AX2", and §13.11's own table is headed *"Behaviour at AX3 – AX5"* — so it cannot make a claim
about AX2 at all. §12.8 is the section that states the whole ladder and is the layout authority.

**Ruling: the re-flows engage at `.accessibility2` and above**, with two named exceptions that §13.11
states explicitly and §12.8 does not mention — the Profile's vertex sigils at **AX3**, and the Codex
list's two-line rows at **AX3**. Engaging one step early is also the safe direction: it enlarges
targets sooner. Record it in `DECISIONS.md` with both sections cited.

```swift
// Modules/Sources/HunchUI/AXLayout.swift — thresholds are CONDITIONS, so they live here;
// every multiplier, weight and ratio lives in the token layer and is cited, never copied.
public enum AXLayout {
    public static func benchIsSingleRailPager(_ size: DynamicTypeSize) -> Bool { size >= .accessibility2 }
    public static func vertexSigilsAreAVerticalList(_ size: DynamicTypeSize) -> Bool { size >= .accessibility3 }
    …
}
```

`DynamicTypeSize` is `Comparable`, so every one of these is a comparison and not a `switch`.
**`.isAccessibilitySize` is the wrong predicate for every row**: it is `>= .accessibility1`, which is
where *art* hits its ceiling, not where layout re-flows. The `accessibilitySizeIsNotTheThreshold` test
exists to keep somebody from "simplifying" the file into it.

### Art scales; drawings do not; weights never

Three separate rules that are constantly confused with each other:

- **Art scales.** `env.artScale` = `min(max(typeMultiplier, 1), 1.35)` multiplies *lengths* at the
  drawing site — the glyph box `S`, the Assay cell size, the Profile's `R0`. The play surface has no
  text, so the type multiplier drives art scale and nothing else.
- **A drawing never scales with type.** The Codex thumbnail is fixed at its own size and the Profile
  portrait holds §11.10's geometry, because both are *pictures*. `env.artScale` moves art; nothing
  moves a picture. That is not a contradiction of the first rule — a glyph on the play surface is a
  live instrument reading and a Codex thumbnail is an illustration of one.
- **A weight is never multiplied by `artScale`.** Weight has its own axis (Bold Text, T08). Dynamic
  Type reaches weight exactly once, through geometry: `S` selects the regime, and `S < 48` selects
  `weight.bodySm`. Scaling the weight as well would compound the two.

The multiplier is read once, by the one `RenderEnvReader`, as `@ScaledMetric(relativeTo: .body) var
typeUnit = 1` — the only way to get a numeric scale factor. `\.dynamicTypeSize` is an ordinal
category, not a number, and it is what `AXLayout` takes.

### Nothing shrinks, ever

Chrome text never truncates and never shrinks: `lineLimit(nil)`, `fixedSize(horizontal: false,
vertical: true)`, `minimumScaleFactor` 1.0. If a row cannot fit, **the row grows**. This is a token,
not a call-site decision, which is why `Typography.minimumScaleFactor` exists at all and why check 11d
greps for the modifier rather than for a value: a `minimumScaleFactor(1.0)` written at a call site is
correct today and is the line somebody edits to 0.8 next year.

The same rule covers targets: **targets never shrink to make room.** The audit's `.hitRegion` pass at
AX5 is T11's half of gate 8; T07's inventory is the other half at reference size.

### The re-flows, one line each

| Screen | Element | Engages at | What it becomes | Geometry owned by |
|---|---|---|---|---|
| PROBE / DRIFT | the four ramps | > AX1 | scroll vertically inside the Dial's own region | E08·T04 |
| " | commit bar | never | **pinned; never scrolls at any size** | E08·T02 |
| " | Dial gutters | AX1 | tighten one step | E08·T04 |
| Bench | rails | ≥ AX2 | the single-rail pager | E09·T01/T02 |
| " | the Assay | ≥ AX2 | trailing column → full-width strip under the rail | E09·T05 |
| " | palette | ≥ AX2 | a 2 × 2 grid of larger stamps | E09·T01 |
| ECHO | the tray | ≥ AX2 | a two-column pager | E13·T05 |
| SIEVE | gate, lane, tail | never | **unchanged** — a fixed target and timed geometry | E14·T02 |
| Codex shelf | the grid | ≥ AX2 | 5 columns → 2 | E15·T04 |
| Codex list | rows | AX3 | two lines; row height grows | E15·T04 |
| Codex page | rule-tiles | > AX1 | freeze at the art ceiling; metadata scrolls below | E15·T05 |
| Profile | the portrait | never | holds §11.10's geometry | E16·T08 |
| " | vertex sigils | AX3 | ring → vertical list, each keeping its hit rect | E16·T09 |
| " | stat block | ≥ AX2 | one item per line | E16·T08 |
| Frame | mode rack | ≥ AX2 | 2 × 2 → 1 × 4, scrolling | E17·T03 |
| Anomaly | the 28-cell ribbon | ≥ AX2 | holds its cell size, reflows 28 × 1 → 7 × 4 | E16·T04 |
| Statistics, Settings, About | stock `Form` rows | AX1 | label-over-value; toggles keep their targets | stock |
| Onboarding-by-doing | — | — | **unaffected: it has no text by construction** | — |

This task owns the **thresholds and their assertions**; each row's geometry is its own epic's, already
shipped. Where a re-flow does not exist yet because the owning task drew only the reference layout,
add it here against that component's own tokens — never with a new literal.

### Above AX2 a multi-cell grid pages rather than grows

§12.8 measures reach for a multi-cell grid at its **nearest** row, because the grid is entered from
below; above AX2 it *pages* rather than growing. That is what makes the Bench's single-rail pager and
ECHO's two-column tray reach decisions rather than aesthetic ones, and it is why T07's reach audit runs
after this task rather than before it.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter DynamicTypeLayoutTests` green, all thirteen tests, with the threshold tests parameterised over **every** `DynamicTypeSize` case.
- [ ] `Scripts/check-source-hygiene.sh` green with check 11d, and each of its four greps demonstrated to fire on a planted violation before reverting.
- [ ] `grep -Rn 'isAccessibilitySize' Modules/Sources --include='*.swift'` returns nothing.
- [ ] `grep -Rn 'artScale' Modules/Sources --include='*.swift'` shows it applied only to lengths — read every hit and confirm none multiplies a `weight(...)`.
- [ ] `grep -Rn 'dynamicTypeSize' Modules/Sources --include='*.swift'` shows every comparison going through `AXLayout`, with no inline `>= .accessibility` outside that file.
- [ ] `tests.json` carries the Dynamic Type entry, `source: "§12.8, §13.11"`.
- [ ] `DECISIONS.md` carries the `.accessibility2` ruling with §12.8 and §13.11 both cited.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T06: Dynamic Type — art to the ceiling, then re-flow, and nothing shrinks"`

## Out of scope

- The AX5 × 5-locale snapshot that proves zero truncation and zero overflow — **T11**.
- Each re-flowed component's own geometry — the epics named in the table above.
- `RenderEnv`'s arithmetic and the `artScale` clamp's definition — **E03·T03**; this task asserts its *application*.
- Bold Text, Reduce Transparency and Differentiate Without Colour — **T08**.
- Targets, spacing and the reach tiers — **T07**.
