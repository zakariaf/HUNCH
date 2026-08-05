---
name: hunch-design-tokens
description: "Resolves every colour, stroke weight, space, radius, type role, opacity and duration in HUNCH to a named token in HunchCore/Tokens, and fixes the resolution order across dark, light, High Contrast, Bold Text and Dynamic Type. Use before writing any hex, lineWidth, opacity, font size, radius or duration. Load this first for any drawing task. It owns values, never component geometry."
allowed-tools: Read, Grep, Glob, Bash(swift ${CLAUDE_SKILL_DIR}/scripts/*)
metadata:
  version: "1.0"
  owns: "L0/L1/L2 token layering, RenderEnv, resolution order, register segregation, the three themes"
---

## Tokens as they exist right now

```!
d=$(ls -d "${CLAUDE_PROJECT_DIR:-.}"/HunchCore/Sources/Tokens ./HunchCore/Sources/Tokens ../HunchCore/Sources/Tokens 2>/dev/null | head -1)
if [ -n "$d" ]; then
  all=$(grep -Hn 'static let\|public func\|public var' "$d"/*.swift | sed 's|.*/Tokens/||')
  n=$(printf '%s\n' "$all" | grep -c .)
  printf '%s\n' "$all" | head -60
  [ "$n" -gt 60 ] && echo "(… $n members total — grep HunchCore/Sources/Tokens/ for the rest; C.swift is the L2 tail)"
else echo "TOKENS NOT BUILT YET — references/tokens-swift-layout.md is the file to create, and references/palette.md is normative until it exists."; fi
```

Trust that listing over anything written below it. If it disagrees with a reference file, the Swift wins and the reference file is the bug — fix it and re-run `check-tokens.swift`.

## The rule

**Every colour, length, weight, opacity, duration and type role in HUNCH is a named token in `HunchCore/Sources/Tokens/`. A literal outside that directory is a build failure, not a style opinion.** Enforced by `Scripts/check-source-hygiene.sh` check 9 — see `references/tokens-swift-layout.md` §6 for the grep and the Swift Testing suite that guards the arithmetic.

## To place a value

1. **Name the register first.** Glyph body, fill, pip, index stroke → `hue.*` (a `HueColor`). Verdict, Seal, marks, streak, strike, barred → `accent.*` (an `AccentColor`). Everything else — chrome, rules, ticks, text, grounds → `ground.*` / `surface.*` / `stroke.*`. The registers are *distinct Swift types*, so crossing them will not compile.
2. **Look for an existing L1 token** in the live listing above. Most values already have one.
3. **If none fits, decide the layer.** Is it meaningful to more than one component? → new L1 token, add it to `palette.md` / `dimensions-strokes-opacity.md` *and* the Swift, then run `check-tokens.swift`. Is it one component's business? → **L2**, `C.<Component>.<name>`, owned by that component's skill, referencing L1 only. Never a bare `Prim`.
4. **Resolve, do not hardcode.** `env.weight(.body)`, `env.palette.stroke.primary`, `env.type(.numeral)`, `Space.s16`, `Dur.admit`. If you typed a number, you skipped a step.
5. **Measure any new colour** — `swift ${CLAUDE_SKILL_DIR}/scripts/contrast.swift '#RRGGBB' '#GROUND'` — and write the measured ratio into `palette.md`. A stated ratio nobody recomputed is how canon ended up claiming amber is 9.5 : 1 when it is 8.79 : 1.

## Naming — one convention, resolving §2(h)

§13.2 writes `ground.raised`, §13.3 writes `bodySm`, §13.4 writes `display`. **All three become `category.name[.state]`: lowerCamelCase segments, dot-separated, at least two segments.** So `bodySm` → `weight.bodySm`, `display` → `type.display`, and bare `ground` → `ground.base` (a category cannot also be a token). L2 is `c.<component>.<name>`.

The Swift symbol upper-cases each namespace segment and leaves the leaf alone. The full path→symbol table is in `references/tokens-swift-layout.md` §2; the seven you will actually type:

| Token path | Swift |
|---|---|
| `ground.raised`, `stroke.primary`, `accent.brass`, `hue.teal`, `surface.cell` | `env.palette.ground.raised`, `…stroke.primary`, `…accent.brass`, `…hue.teal`, `…surface.cell` |
| `weight.body` | `env.weight(.body)` — resolved; `StrokeWeight.body` is the *unresolved* token |
| `type.numeral` | `env.type(.numeral)` |
| `space.s16`, `radius.chrome`, `opacity.halo` | `Space.s16`, `Radius.chrome`, `Opacity.halo` |
| `dur.admit`, `ease.settle` | `Dur.admit`, `Easing.settle` |
| `c.ramp.cellUnlitInk` | `C.Ramp.cellUnlitInk(in: env)` |

## The resolution order — the GDD never states it, so this skill does

Four stages, always in this order, for every token:

1. **Select** — the theme picks the value. High Contrast's *substitutions* happen here: `hue.*` → `stroke.primary`, unlit cell 0.25 → 0.40, cancel hatch 1.0 → 2.0 pt, index stroke `0.273·S` → `0.409·S`.
2. **Scale** — Bold Text: stroke weights `×1.25`, type weights `+1 notch` (clamped at `bold`).
3. **Offset** — High Contrast: `+0.5 pt` on every stroke weight. Flat, never scaled.
4. **Derive** — geometric relationships computed from the *already-resolved* weight: the light-theme keyline `+1.0`, the halo `×3`.

**`weight.body` with Bold Text and High Contrast both on is `3.0 × 1.25 + 0.5 = 4.25`. It is not `(3.0 + 0.5) × 1.25 = 4.375`.** §13.11 spells Bold Text multiplicatively with worked values that must hold (`hairline` 0.5 → 0.625) and High Contrast as a flat `+0.5 pt`; an offset that also got multiplied would silently become `+0.625` and the two settings would stop being independent. The full ladder under both: `0.625 / 1.25 / 1.875 / 3.75 / 5.0` before the offset, `1.125 / 1.75 / 2.375 / 4.25 / 5.5` after — every weight takes the same flat `+0.5`, and the ladder is still monotone, which is the property that had to survive. The four-column matrix it comes from is `references/dimensions-strokes-opacity.md` §2.

**Substitution beats modification.** Where §13.11 states an explicit High Contrast value, that value terminates resolution: it is never *also* multiplied or offset. `c.ramp.cancelHatchWeight` under High Contrast is `2.0`, not `2.5`.

**Dynamic Type is not in this chain.** `env.artScale` (clamped to 1.35, canon's AX2 ceiling) multiplies *lengths* — the glyph box `S`, Assay cell size, the portrait `R0`. It never multiplies a stroke weight: weight already has its own axis, and `S` selects the weight regime (`S < 48 → weight.bodySm`), so Dynamic Type reaches weight through geometry exactly once.

## Where the detail lives

| Read this | When |
|---|---|
| `references/palette.md` | before touching any colour — 17 rows × 3 themes, every ratio **measured**, with canon's nine wrong cells named |
| `references/light-theme.md` | when the light theme is on screen, or when a mark must survive daylight — the PLATE graft, the keyline arithmetic, the no-bed/no-scanline rules |
| `references/dimensions-strokes-opacity.md` | before writing a `lineWidth`, `frame`, radius or `.opacity` |
| `references/type-ramp.md` | before writing any `Font`, tracking or `relativeTo:` — and never on the play surface |
| `references/durations-and-easing.md` | before writing any `withAnimation` or `Duration` |
| `references/render-env.md` | when a value must differ under an accessibility setting, or when wiring the env from the app |
| `references/tokens-swift-layout.md` | when creating or editing `HunchCore/Sources/Tokens/*.swift` — the complete, compiling file set, plus the enforcement grep and the test suite |

`swift ${CLAUDE_SKILL_DIR}/scripts/contrast.swift` — no arguments prints the full measured matrix; two hexes prints one ratio; `'#RRGGBB' --vs-all` prints it against all three grounds.
`swift ${CLAUDE_SKILL_DIR}/scripts/check-tokens.swift` — the three-way divergence check: `palette.md` ↔ `Prim.swift` ↔ `GAME_DESIGN.md` §13.2, with every ratio recomputed and the offending row named. Run it after any palette edit and in CI. It is verified to fail on a corrupted ratio and on a corrupted hex.

## Gotchas

- **Nine cells of §13.2's ratio columns disagree with the arithmetic.** The four that matter: dark `hue.amber` is 8.79 : 1 (canon says 9.5), dark `hue.teal` 5.78 (says 6.4), light `stroke.hairline` 1.38 (says 1.5), HC `stroke.hairline` 3.04 (says 3.3). No design consequence follows — every gate still clears — but quote `palette.md`'s measured column, never §13.2's. All of PHOSPHOR's own new rows recompute correctly; the errors are entirely canon's.
- **`hue.amber` and `accent.brass` are 1.22 : 1 apart in the dark theme, not §13.2's 1.36 : 1.** Register segregation and ring geometry carry the distinction; luminance does not. Never add a third cue that assumes they are far apart.
- **The High Contrast "9.7 : 1 floor" is a floor on the state-bearing set only** — `stroke.primary` 21.0, `stroke.secondary` 9.68, `accent.brass` 13.08, `accent.cold` 15.00, `hue.*` 21.0. `stroke.hairline` at 3.04 and `accent.*Press` at 7.77/9.06 sit below it deliberately; hairline is declared never state-bearing.
- **`Prim` is L0 and a view that names one is a bug.** L2 references L1; L1 references L0; nothing skips.
- **`Duration`, never `Double`, for time.** A bare `260` is ambiguous between ms and s and both spellings appear in the GDD.
- **Pin `.sRGB` in the SwiftUI adapter.** Every ratio here is sRGB relative luminance; a Display P3 constructor moves all of them and no test will notice.
- **The light theme changes colour and depth, never geometry.** No dimension, weight, radius or duration token varies by theme. A geometry fork is a second art direction, and this project ships one.

## Never

- Never write a hex literal, `Color(red:)`, `UIColor(`, a numeric `lineWidth:`, `.opacity(0.35)`, `cornerRadius: 2`, `.font(.system(size:))` or a numeric `duration:` outside `HunchCore/Sources/Tokens/`. Check 9 fails the build.
- Never re-light Okabe–Ito. `hue.*` is `#E69F00 / #009E73 / #56B4E9 / #CC79A7` in dark **and** light, verbatim (§13.2, §2). The light-ground contrast problem is solved with the keyline, not with a new pigment.
- Never let `accent.*` touch a glyph body, fill, pip, ramp cell or index stroke, and never let `hue.*` touch chrome, a rule-tile frame, a tick, the Seal or the Settings switch. Reaching `.rgb` to launder one into the other defeats the type split and is check 10.
- Never add `+0.5` before `×1.25`. Never apply `×1.25` to a High Contrast substitution.
- Never scale a stroke weight by `artScale`, and never let `typeMultiplier` past 1.35 into a drawing.
- Never add an elevation, shadow, material or status-colour token. Luminance is the only depth cue in dark; impression is the only depth cue in light; `accent.brass`/`accent.cold` are **verdicts**, not success/error.
- Never invent a component dimension here. Glyph box sizes, cell sizes and tile geometry are L2 and belong to the glyph, marks, bench and chrome skills; this skill owns the layer and the rule, not the members.
- Never copy a value out of this skill into another skill. Cite the token name; the value has exactly one home.
