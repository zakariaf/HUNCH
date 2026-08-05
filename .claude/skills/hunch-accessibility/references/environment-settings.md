# environment-settings.md — what changes, on which screen, under which setting

Contents: [1 Ownership](#1-ownership) · [2 Dynamic Type](#2-dynamic-type) · [3 Bold Text](#3-bold-text) ·
[4 Differentiate Without Color](#4-differentiate-without-color) · [5 Reduce Transparency](#5-reduce-transparency) ·
[6 High Contrast](#6-high-contrast) · [7 Reduce Motion is not here](#7-reduce-motion-is-not-here) ·
[8 Reading the settings](#8-reading-the-settings) · [9 The three VOICEOVER rows](#9-the-three-voiceover-rows) ·
[10 Testing](#10-testing) · [11 What would be wrong](#11-what-would-be-wrong)

---

## 1. Ownership

This file answers **which screens and elements change, and at what threshold**. It contains no numeric delta, on
purpose.

| Question | Owner |
|---|---|
| what a weight, colour, opacity or duration becomes | `hunch-design-tokens/references/render-env.md` §2 and `palette.md` |
| the resolution order (Bold Text ×, then High Contrast +) and the derived predicates | `render-env.md` §2, §3 |
| the geometry of a mark that changes shape | the drawing's own skill — glyph, marks, bench, chrome |
| **which screen re-flows, which element re-flows, and at what `DynamicTypeSize`** | here |
| the Reduce Motion substitution for any animation | `hunch-motion-and-feedback/references/reduce-motion.md` |
| the gates that prove all of it | `audit-in-ci.md` |

If you find yourself about to write a number here, the number has a home somewhere else and this file should cite the
token name instead. That is `M4`, and it is the whole reason the split exists.

---

## 2. Dynamic Type

**The threshold conflict, ruled.** §12.8's ladder puts the pager and the re-flows at `accessibility2 … 5`; §13.11's
prose says "above AX2", and §13.11's own table is headed *"Behaviour at AX3 – AX5"* — so it cannot make a claim about
AX2 at all. §12.8 is the section that states the whole category ladder and is the layout authority. **Ruling: the
re-flows engage at `.accessibility2` and above**, except the Profile's vertex sigils, which §13.11 puts explicitly at
AX3 and §12.8 does not mention. Engaging one step early is also the safe direction — it enlarges targets sooner.

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize
private var isPagerLayout: Bool { dynamicTypeSize >= .accessibility2 }
private var isVertexListLayout: Bool { dynamicTypeSize >= .accessibility3 }
```

`DynamicTypeSize` is `Comparable`, so this is a comparison, not a `switch`. `.isAccessibilitySize` is `>= .accessibility1`
and is the **wrong** predicate for every row below — AX1 is where art hits its ceiling, not where layout re-flows.

| Screen | Element | Threshold | What changes | Geometry owned by |
|---|---|---|---|---|
| PROBE / DRIFT | the four ramps | > AX1 (art frozen at the ceiling) | ramps scroll vertically inside the Dial's own region | `hunch-bench-instruments/references/ramp.md` |
| " | commit bar | — | **pinned; never scrolls, at any size** | `hunch-chrome-and-meta/references/instrument-bar.md` |
| " | Dial gutters | AX1 | tighten one step | `hunch-bench-instruments/references/ramp.md` |
| " | the play surface | any | **no text exists**, so the type multiplier drives *art* scale only, via `env.artScale` | `render-env.md` §2 |
| Bench | rails | ≥ AX2 | canon's **single-rail pager** engages | `hunch-bench-instruments/references/rule-tile.md` |
| " | the Assay | ≥ AX2 | moves from the trailing column to a full-width strip under the rail | `hunch-bench-instruments/references/assay-grid.md` |
| " | palette | ≥ AX2 | becomes a 2 × 2 grid of larger stamps | `hunch-chrome-and-meta/references/stock-controls.md` |
| ECHO | the tray | ≥ AX2 | becomes a two-column pager | `hunch-bench-instruments/references/ribbon.md` |
| SIEVE | gate, lane, tail | any | **unchanged** — the gate is a fixed 375 × 88 target and the lane is timed geometry | `hunch-bench-instruments/references/gate-band.md` |
| Codex list | rows | AX3 | reflow to two lines; row height grows | `hunch-chrome-and-meta/references/codex-page.md` |
| " | glyph thumbnail | never | fixed; **it is a picture, not text** | `hunch-glyph-renderer` |
| Codex page | rule-tiles | > AX1 | freeze at the art ceiling; metadata scrolls below them | `hunch-chrome-and-meta/references/codex-page.md` |
| Profile | the portrait card | never | holds canon's geometry; **a drawing does not scale with type** | `hunch-chrome-and-meta/references/profile-contour.md` |
| " | the five vertex sigils | AX3 | reflow from a ring to a vertical list, each keeping a 44 × 44 hit rect | " |
| " | stat block | ≥ AX2 | one item per line | " |
| Frame | mode rack | ≥ AX2 | 2 × 2 becomes 1 × 4, scrolling | `hunch-chrome-and-meta/references/key.md` |
| Anomaly | the 28-cell ribbon | ≥ AX2 | holds its cell size and reflows 28 × 1 → 7 × 4 | `hunch-shared-marks/references/tick-row.md` |
| Statistics, Settings, About | stock `Form` rows | AX1 | rows go label-over-value; toggles keep 44 × 44 | stock |
| Onboarding-by-doing | — | — | **unaffected: it has no text by construction** | — |

Three rules that hold on every row. **Chrome text never truncates and never shrinks** — `lineLimit(nil)`,
`fixedSize(horizontal: false, vertical: true)`, and `minimumScaleFactor` stays 1.0 everywhere
(`hunch-design-tokens/references/type-ramp.md`). If a row cannot fit, the row grows. **A drawing never scales with
type** — the Codex thumbnail and the Profile portrait are pictures; only `env.artScale` moves art, and it is clamped.
And **targets never shrink to make room**: the audit's `.hitRegion` pass at AX5 is gate 8's other half.

---

## 3. Bold Text

Bold Text steps every type role one weight **and** steps glyph and rule-tile stroke weights. The multiplier and the
clamp live in `render-env.md` §2; the eligibility flag is `respondsToBoldText`, a property *of the token*, not of the
call site.

What this skill owns is **which marks are eligible, and why the play surface honours a text setting at all.** The
eligible set is exactly: glyph body, index stroke and pip ring; rule-tile strokes. Chrome hairlines, the Assay grid,
tick rows and the shader are *not* eligible.

The reasoning is worth keeping, because it is the thing someone will try to "fix": the play surface has no text, so
Bold Text is the **only signal iOS gives us that this player wants heavier marks**. Honouring it on the glyph is more
useful than ignoring it because "there is no text here". Extending it to chrome hairlines would thicken the very rules
§13.1 wants recessive and undo the *marks glow, chrome does not* commitment.

---

## 4. Differentiate Without Color

**True by construction, and then made truer.** §13.5.1 already proves every one of the glyph's four channels survives
greyscale, so nothing on the play surface depends on chromatic discrimination before the setting is read. The setting
**changes no token** — `render-env.md` §1 keeps `isDifferentiateWithoutColorEnabled` in the record anyway, because
components need it and a seven-axis record that silently dropped an axis is the failure the design exists to prevent.

| Element | What is added when on | Geometry owned by |
|---|---|---|
| ribbon admit tile | ring drawn fully closed | `hunch-shared-marks/references/verdict-ring.md` |
| ribbon reject tile | ring broken at twice the normal gap | " |
| the counterexample's two rings | distinct dash patterns — **solid = the Loom's verdict, dashed = your declaration's** | " |

The counterexample row is the one that carries real information: two contradictory readings of one glyph become
separable without colour *and without memory*. Do not re-encode it as two colours plus a legend.

The verdict itself is never colour in the first place — §13.7.2 makes admit *expand and stay closed* and reject
*contract and break*, with colour, tone and haptic as three redundant copies of that. Anything you add here must be a
fourth copy, never a first.

---

## 5. Reduce Transparency

| Screen / element | What happens |
|---|---|
| every play surface | the shader is off (`env.isShaderEnabled` is false) |
| every glyph-bearing region | bloom is off — both the widened stroke and the layer filter |
| the Bench scrim | blur becomes a flat opaque fill |
| `SievePauseOverlay` scrim | same |
| every material anywhere | becomes an opaque raised ground |

Read the **predicates**, never the flag: `env.isBloomEnabled`, `env.isBloomBedEnabled`, `env.isShaderEnabled`
(`render-env.md` §3). Each folds Reduce Transparency together with High Contrast and Low Power Mode, which is the
mechanism that stops eight files disagreeing about what "transparency off" means. A view that writes
`if env.isReduceTransparencyEnabled` has re-derived a predicate that already exists and will drift from it.

Low Power Mode reaches the same three predicates by a different route and is **not** an accessibility setting — do not
collapse them into one branch.

---

## 6. High Contrast

High Contrast is a **theme**, not a toggle (§12.6: Theme is a four-value segmented control, and there is deliberately
no separate switch — two controls for one state is how they get out of sync). It is forced on when
`isDarkerSystemColorsEnabled` is true *and* the player has made no explicit choice; that flag is not in SwiftUI's
environment and needs a notification observer at the composition root (`render-env.md` §4).

The accessibility consequence, which is this skill's to state:

- **All four hues collapse to the primary stroke colour, so the hue channel is carried by index-stroke rotation alone.**
  Every other channel is untouched. That makes the index stroke load-bearing in a way it is not in the other two
  themes — and it is why §13.11 lengthens it here rather than leaving it alone.
- **Therefore: any surface that draws a glyph without its index stroke is 4× ambiguous under High Contrast.** There is
  no such surface today and there must not be one. If a size is ever too small for the index stroke, it is too small
  for a glyph, and the right answer is a different mark, not a truncated one.
- Unlit ramp cells and the cancel hatch both step up so an eliminated value stays legible without its colour.
- The shader is off.

Numbers for every one of those: `hunch-design-tokens/references/palette.md` and `render-env.md` §2's substitution
table. **Substitution beats modification** — a High Contrast value terminates resolution and is never also scaled by
Bold Text. Gate 10 asserts the outcome: every foreground/background pair clears the floor, hue is index-stroke-only,
and all 256 glyphs remain distinguishable.

---

## 7. Reduce Motion is not here

Deliberately. §13.7.4 is a complete substitution table keyed to the same beats the animations are, and splitting it
across two skills would put half a table in each. It belongs to
`hunch-motion-and-feedback/references/reduce-motion.md`.

Two things this skill keeps, because they are acceptance rather than choreography: **gate 9** — nothing translates,
scales or rotates anywhere, including SIEVE, plus the automated assertion that `preview(n) + window(n)` and the station
a glyph occupies at time `t` are identical with Reduce Motion on and off — and the fact that Reduce Motion and
VoiceOver are **independent axes**, so SIEVE's crossfade substitution and SIEVE's step pacing can both be on and must
compose. `audit-in-ci.md` §1 owns the gate.

---

## 8. Reading the settings

| Setting | How to read it | Note |
|---|---|---|
| Dynamic Type category | `@Environment(\.dynamicTypeSize)` | for layout thresholds (§2) |
| Dynamic Type multiplier | `@ScaledMetric(relativeTo: .body)` | the only numeric scale factor; `render-env.md` §4 |
| Bold Text | `@Environment(\.legibilityWeight) == .bold` | **there is no `\.accessibilityBoldText`** |
| Reduce Transparency | `@Environment(\.accessibilityReduceTransparency)` | |
| Reduce Motion | `@Environment(\.accessibilityReduceMotion)` | motion skill owns what it does |
| Differentiate Without Color | `@Environment(\.accessibilityDifferentiateWithoutColor)` | |
| **VoiceOver running** | `@Environment(\.accessibilityVoiceOverEnabled)` | prefer it to `UIAccessibility.isVoiceOverRunning` — SwiftUI invalidates on it |
| Darker System Colors | `UIAccessibility` + notification observer, at the composition root | not in SwiftUI's environment |
| Low Power Mode | `ProcessInfo` + notification observer, at the composition root | not an accessibility setting |

The first six are folded into `RenderEnv` by one reader view, once (`render-env.md` §4). **VoiceOver is not among
them and must not be added.** It changes behaviour and structure — SIEVE's pacing, nudge suppression, the SIEVE Tempo
update — not values, and `render-env.md` §6 already rules that the record is not the place for an eighth axis.
Thread it as a parameter to the round instead.

---

## 9. The three VOICEOVER rows

§12.6 ships three preferences under `hunch.settings.`, and each one gates a specific thing:

| Row | Default | Gates |
|---|---|---|
| **Detail** — Full / Terse | Full | the glyph label builder's `detail:` argument. Terse speaks only the attributes that changed since the previous glyph — `voiceover-elements.md` §9 |
| **Announce verdicts** | On | the admit / reject / twin rows of the announcement table, and nothing else. Focus-read values are never gated |
| **Announce the Assay** | Off | the per-edit announcement only. The Assay's `accessibilityValue` is still read on focus |

Off-by-default for the Assay is a considered choice, not an oversight: it fires on every Bench edit and is very chatty.
Do not "fix" it by making it the default; do make sure the value on focus is complete, because that is the affordance
the default relies on.

These are `UserDefaults` preferences, which is the one thing `UserDefaults` holds in this app — game state is JSON
(§12.6). They are read at the app layer and passed down; `HunchCore` never sees them.

---

## 10. Testing

| Claim | How it is proved | Where |
|---|---|---|
| every screen × AX5 × {en, de, tr, ru, ar}: zero truncation, zero horizontal overflow, targets ≥ 44 × 44 | XCUITest snapshot + a second test-plan configuration (`07 B26`, `07 B40`) | `audit-in-ci.md` §4 |
| resolution arithmetic: Bold Text × then High Contrast + | `swift test` over `RenderEnv`, no simulator | `hunch-design-tokens/references/tokens-swift-layout.md` §6 |
| every component × state × 3 themes × {normal, Bold Text, Reduce Motion}, plus greyscale | the DEBUG snapshot gallery | `hunch-swift-testing` |
| High Contrast keeps all 256 glyphs distinguishable | the greyscale L1-distance test | `hunch-glyph-renderer/references/triple-encoding-proof.md` |
| Differentiate Without Color adds the rings it says it adds | snapshot gallery row | `hunch-swift-testing` |

Every one of those is a snapshot or a value test — **none of them needs VoiceOver running**, which is what keeps them
inside the 10-second `swift test` budget or on a nightly plan rather than in a manual pass. The manual passes that
remain are §13.12's gates 3 and 12, and they are listed in `audit-in-ci.md` §6.

---

## 11. What would be wrong

- **Writing a number into this file.** §1 is explicit: every delta has a home in
  `hunch-design-tokens/references/render-env.md` §2 or `palette.md`. A threshold expressed as a
  `DynamicTypeSize` case is a *condition* and belongs here; a multiplier, a weight or a ratio is a
  value and does not.
- **Branching on `theme == .light` or `env.isReduceTransparencyEnabled` at a call site.** §5. Every
  one of those questions already has a derived predicate (`render-env.md` §3), and a re-derived
  predicate drifts from the original the first time a fourth suppressor is added.
- **Using `.isAccessibilitySize` for a layout re-flow.** §2. It is `>= .accessibility1`, which is
  where *art* hits its ceiling, not where layout re-flows — the re-flows engage at `.accessibility2`.
- **Spelling the art ceiling as `1.35`.** It is `Prim.artScaleCeiling`, and a view reads it only
  through `env.isArtScaleClamped` (`render-env.md` §3). `check-source-hygiene.sh` check 9 cannot see
  a bare decimal.
- **Scaling a drawing with Dynamic Type.** §2. The Codex thumbnail and the Profile portrait are
  pictures; `env.artScale` moves art and nothing moves a picture.
- **Shrinking a target, truncating a string or lowering `minimumScaleFactor` to make a row fit at
  AX5.** §2. If a row cannot fit, the row grows — and gate 8 asserts it in five locales.
- **Extending Bold Text eligibility to chrome hairlines, the Assay grid or the shader.** §3. It
  thickens the very rules §13.1 wants recessive and undoes the *marks glow, chrome does not*
  commitment.
- **Adding a Differentiate Without Color cue that is the *first* copy of a distinction rather than
  the fourth.** §4. The verdict is already expand-and-close against contract-and-break; anything
  added here is redundancy, never the channel.
- **Re-encoding the counterexample's two rings as two colours plus a legend.** §4. Two contradictory
  readings of one glyph must be separable without colour *and without memory*.
- **Scaling a High Contrast substitution by Bold Text.** §6. A substitution terminates resolution;
  `Prim.highContrastStrokeOffset` applies to the weight axis, which is a different axis.
- **Drawing a glyph without its index stroke under High Contrast.** §6. All four hues have collapsed
  to one ink, so the mark is 4× ambiguous. If a size is too small for the index stroke it is too
  small for a glyph.
- **Collapsing Low Power Mode into the accessibility branch,** or collapsing §12.6's steady-stream
  toggle into `isVoiceOverRunning`. §5, §9. Neither is an accessibility setting, and both reach the
  same predicate by a different route.
- **Adding VoiceOver as an eighth `RenderEnv` axis.** §8. It changes behaviour and structure, not
  values; thread it as a parameter to the round.
- **Making the Assay announcement on by default.** §9. It fires on every Bench edit. The affordance
  that makes off-by-default correct is the complete value on focus — check that instead.
