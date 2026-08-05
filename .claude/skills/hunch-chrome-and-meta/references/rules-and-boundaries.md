# rules-and-boundaries.md — the two lines that separate things

Owning symbol: `HunchUI/Chrome/Rule.swift` → `struct Rule: View` and `struct SectionBoundary<Content>: View`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row C, *Rule / section boundary*.

Contents: [1 Two idioms](#1-two-idioms-and-the-difference-is-spacing) · [2 No third weight](#2-there-is-no-third-rule-weight-in-chrome) ·
[3 hairline vs secondary](#3-strokehairline-versus-strokesecondary--resolving-132) ·
[4 Two channels, never one](#4-panels-separate-by-two-channels-never-one) · [5 What is not a rule](#5-what-is-not-a-rule) ·
[6 Implementation](#6-implementation) · [7 Accessibility](#7-accessibility) · [8 Wrong](#8-wrong)

---

## 1. Two idioms, and the difference is spacing

| Idiom | Geometry | Token |
|---|---|---|
| **rule** | one line, `env.weight(.hairline)` in `stroke.hairline`, inset `space.ruleInset` on **both** sides | §13.3 |
| **section boundary** | the same line, with `space.boundaryAbove` of air above and `space.boundaryBelow` below | §13.3 |

They are the same drawing. A boundary is a rule that has been given room, and the room is the whole
difference — 24 above / 16 below is asymmetric on purpose, so the line reads as belonging to the
section it opens rather than floating between two.

`SectionBoundary` therefore wraps its content and emits the rule + the two spacings as one unit. A
`Rule()` with two hand-written `.padding`s at the call site is how the 24/16 asymmetry gets flipped
in one place and nobody notices.

---

## 2. There is no third rule weight in chrome

PHOSPHOR §3, and it is a hard rule: **a heavier line always means state.**

| Weight | Means | Owner |
|---|---|---|
| `weight.hairline` | a separator. Carries no state, ever | this file |
| `weight.thin` | a rule-tile frame, a ramp cell border, a key border | `hunch-bench-instruments`, `key.md` |
| `weight.heavy` | the machined bar, the AND welded bar | `hunch-shared-marks/references/machined-bar.md` |

The three ladder positions and every resolved value they take under Bold Text and High Contrast are
`hunch-design-tokens/references/dimensions-strokes-opacity.md` §1 and §2. Read them from
`env.weight(_:)`; a number written here would be a second home for a value that has one.

So a line you are tempted to thicken "so it reads better" is a line that has silently acquired
meaning. Fix the meaning, not the weight.

---

## 3. `stroke.hairline` versus `stroke.secondary` — resolving §13.2

§13.2 lists `stroke.secondary` for *"chrome rules, tick marks, labels"* and `stroke.hairline` for
*"decorative rules"*. §13.3 then gives the rule its geometry and fixes it at `stroke.hairline`. Both
cannot be the separator colour.

**The ruling is by role, not by section number.** A **separator** carries no state — that is what a
separator is — and `stroke.hairline` is the token canon declares *never state-bearing*
(`hunch-design-tokens/references/palette.md` §1). A **mark** carries state: a tick is filled or
unfilled, a plate frame is engraved or doubled, a label names a live value. Marks are
`stroke.secondary`, which clears the High Contrast state-bearing floor in every theme; separators are
`stroke.hairline`, which is deliberately below it. Both measured ratios are `palette.md` §1's column
and are not restated here.

So: every separator in the app is `stroke.hairline`. Where §13.2 says "chrome rules" it is describing
the ink that draws ticks and labels, which sit *on* chrome. The two never swap.

---

## 4. Panels separate by two channels, never one

PHOSPHOR §3: panels *"separate by a ground step **and** a hairline, and never by only one of the
two."* Both channels are individually marginal and the direction's own weakness ledger says so:

- the `ground.base` → `ground.raised` step is at or below the visible threshold on many panels below
  30 % brightness and is destroyed by auto-dimming (PHOSPHOR §6.1);
- `stroke.hairline` sits near the bottom of `palette.md` §1's ratio column in both dark and light,
  and vanishes under glare (PHOSPHOR §6.2).

Both ratios live in `hunch-design-tokens/references/palette.md` §1, which is also where §2 records
that canon over-stated the ground step. Together they survive both failures. A panel drawn with a ground step alone is invisible at night; a
panel drawn with a hairline alone is invisible in daylight. There is no third option, because §13.1
forbids shadow, elevation and material as depth cues.

**In the light theme the ground step is replaced, not dropped.** Depth is by impression there — see
`hunch-design-tokens/references/light-theme.md`. The hairline half of the pair is unchanged; the
ground-step half becomes the impression ladder. Read `env.isImpressionDepthEnabled`, never
`theme == .light`.

---

## 5. What is not a rule

- **A row separator inside a stock `Form` or `List`** is the system's, configured rather than drawn:
  `.listRowSeparatorTint(env.palette.stroke.hairline.color)` and an
  `.alignmentGuide(.listRowSeparatorLeading)` of 16, flush at the trailing edge (PHOSPHOR §3's
  Settings-row diagram). `stock-controls.md` §3 owns that. Drawing your own `Rule()` inside a `List`
  row produces two lines.
- **The Codex shelf line** under each plate *is* a rule, inset 16 both sides — `shelf-plate.md`.
- **The skeleton divider** in `CodexShelfView` is a rule with the skeleton silhouette drawn at 24 pt
  in the leading margin beside it (§11.2). The silhouette is `hunch-sigil-drawing`'s and is currently
  undrawn.
- **The Assay's 16 × 16 grid** is `weight.hairline` in `stroke.hairline` but it is not a rule — it is
  a grid, owned by `hunch-bench-instruments/references/assay-grid.md`. Same tokens, different idiom,
  different owner.
- **The fracture** across a Codex plate rim is a `weight.thin` `accent.cold` diagonal (PHOSPHOR §3).
  It is a state mark, not a separator, and it is `codex-page.md`'s.

---

## 6. Implementation

```swift
// Modules/Sources/HunchUI/Chrome/Rule.swift
struct Rule: View {
    @Environment(\.renderEnv) private var env

    var body: some View {
        Rectangle()
            .fill(env.palette.stroke.hairline.color)
            .frame(height: env.weight(.hairline))     // resolved per dimensions-strokes-opacity.md §2
            .padding(.horizontal, Space.ruleInset)
            .accessibilityHidden(true)
    }
}

struct SectionBoundary<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Space.boundaryAbove)
            Rule()
            Spacer(minLength: Space.boundaryBelow)
            content()
        }
    }
}
```

`.frame(height: env.weight(.hairline))` and not a literal is the whole point: Bold Text scales the
hairline and High Contrast offsets it (`dimensions-strokes-opacity.md` §2 has all four resolved
values), and a hardcoded number makes both settings silently do nothing to chrome. A literal here
also fails `check-source-hygiene.sh` check 9.

**Never use `Divider()`.** It takes the system separator colour (a translucent grey that is neither
of our tokens) and the system's own inset, and it ignores both the resolved weight and RTL's
alignment. It is the fastest way to put a colour in the app that no grep will ever find.

---

## 7. Accessibility

- A rule is decorative. `.accessibilityHidden(true)`, always. A separator that appears in the rotor
  costs a swipe and says nothing.
- A **section boundary's** meaning lives in the section header that follows it, which carries
  `.isHeader` and lands on the `.headings` rotor (§13.10). If a boundary has no header, ask whether
  the boundary is doing a header's job visually and a nothing's job aurally — that is the defect this
  bullet exists to catch.
- **High Contrast:** the rule doubles in weight and roughly doubles in contrast — the resolved weight
  is `dimensions-strokes-opacity.md` §2's `weight.hairline` HC column and the ratio is `palette.md`
  §1's. That is the complete High Contrast answer for chrome separation. Do not
  additionally substitute `stroke.secondary`: that would make a separator state-bearing in exactly
  the theme where state must be unambiguous.
- **Reduce Motion:** rules never animate anywhere. The one pulsing hairline in the app is the empty
  Bench rail, and both its loop and its Reduce Motion substitution belong to
  `hunch-bench-instruments/references/rule-tile.md` (the opacity pair is
  `dimensions-strokes-opacity.md` §5's `opacity.hairlinePulse`), not here.
- **Differentiate Without Color:** no effect. Separators are already colour-free.
- **Dynamic Type:** `space.ruleInset`, `space.boundaryAbove` and `space.boundaryBelow` do **not**
  scale. §13.3's grid is a grid, not a semantic ramp, and text growing inside a section does not mean
  the section's frame should grow with it.

---

## 8. Wrong

- `Divider()`, anywhere.
- `Rectangle().frame(height: 0.5)` — a literal, and it stops responding to Bold Text and High
  Contrast. The same goes for any hand-computed *resolved* weight; `env.weight(.hairline)` is the
  only spelling.
- A separator in `stroke.secondary` or `stroke.primary`. That is a mark pretending to be a line.
- A rule inset asymmetrically, except the system row separator inside a stock `List`, which is
  configured rather than drawn (§5).
- 16 above / 24 below on a section boundary. The asymmetry runs the other way and it is what makes
  the line belong to the section beneath it.
- A rule *and* a ground step *and* a shadow. Two channels; the third is a rejection offence (§13.1).
- A rule used as a progress bar, a meter or an underline. Meters are `arc-meter.md`; underlines do
  not exist in this design.
