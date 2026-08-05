---
name: hunch-chrome-and-meta
description: "Draws HUNCH's chrome and archive surfaces — the generic key at its six sizes, the instrument bar, rules and section boundaries, scrims, numeral readouts, the stock Form and List screens, Codex shelf plates and page composites, extension thumbnails and the Profile contour. Use when building the SwiftUI for Settings, Statistics, About, the Codex, the Frame or the Profile, or any framing around the play surface. Not for the play surface itself, which is the bench, marks and glyph skills."
allowed-tools: Read, Grep, Glob, Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*)
metadata:
  version: "1.0"
  owns: "Rows C and D of design/DESIGN-SYSTEM-SCOPE.md §3 — geometry, states, interaction and accessibility for the key, instrument bar, rule and section boundary, scrim, numeral readout, stock controls, shelf plate, extension thumbnail, Profile contour and Codex page composite. Plus the L2 namespaces C.Key, C.InstrumentBar, C.Scrim, C.Toggle, C.ShelfPlate, C.Thumbnail, C.Profile, C.CodexPage."
---

## Step 0 — read the chrome as it exists right now

**Before anything else, run `bash ${CLAUDE_SKILL_DIR}/scripts/current-state.sh`.** It lists every
`.swift` file under `HunchUI`, `MetaFeature` and `CodexFeature`.

**Trust that listing over anything written here.** Each reference file names the one Swift symbol that owns its drawing; if the symbol is missing from the listing, the reference file is the spec and the file is yours to create. If it is present, read it before drawing a second copy — a second copy is the drift this skill exists to prevent.

## The rule

**This skill owns geometry, state and behaviour. It owns no values.** Every colour, stroke weight, space, radius, opacity, duration and type role is a named token and `hunch-design-tokens` is the authority. Where a number appears in a reference file it is either (a) an **L2 component token** this skill declares, with its `GAME_DESIGN.md` citation attached, or (b) a **geometric constant** — a coordinate, a ratio, a count — which is not a value in the token sense at all. Anything else is a bug in the reference file.

L2 lands in `HunchCore/Sources/Tokens/C.swift` under `C.Key`, `C.InstrumentBar`, `C.Scrim`, `C.Toggle`, `C.ShelfPlate`, `C.Thumbnail`, `C.Profile`, `C.CodexPage`. L2 references L1 only; a view or an L2 member that names a `Prim` is a bug.

## To draw a chrome or archive surface

1. **Find the row.** Open `design/DESIGN-SYSTEM-SCOPE.md` §3 rows C and D, then this skill's reference file for that row. If what you are drawing is not a row, it is not a component: it is an atom (`hunch-shared-marks`), an instrument (`hunch-bench-instruments`), or it should not exist. Adding a row means adding a reference file and an owning symbol, or `Scripts/check-inventory.sh` fails.
2. **Enumerate the states before you draw one.** A key has six; a shelf plate four; a Codex page four. A component drawn in its idle state and patched later is how a state ends up rendered two ways.
3. **Resolve, never type.** `env.palette.stroke.primary`, `env.weight(.thin)`, `Space.s16`, `Radius.chrome`, `Opacity.scrim(in: env)`, `Dur.push`. A literal outside `Tokens/` fails `check-source-hygiene.sh` check 9.
4. **Write the accessibility contract in the same pass as the geometry** — trait, label, value, custom actions, and the behaviour under Reduce Motion, High Contrast, Bold Text and AX5. Every reference file below carries all of it. A component that gets its VoiceOver treatment in a later commit gets it wrong.
5. **One symbol per row.** Name it in the reference file. Nothing else may draw that idiom (`ownership.md` in `hunch-shared-marks` is the same mechanism for atoms).

## Where the detail lives

| Read | When |
|---|---|
| `references/key.md` | before drawing any tappable chrome rectangle — six sites, four rectangles, six states, and why there is no seventh size |
| `references/instrument-bar.md` | before laying out the top of any screen, or when a screen needs a second destination beside the play key |
| `references/rules-and-boundaries.md` | before drawing any line whose job is to separate two things |
| `references/scrim.md` | when one surface covers another — the Bench and the SIEVE pause, and nowhere else |
| `references/numeral-readout.md` | before rendering any digit as a pixel, anywhere |
| `references/stock-controls.md` | in `SettingsView`, `StatisticsView`, `AboutView` or `ResetConfirmAlert` — the only four screens permitted a stock component |
| `references/shelf-plate.md` | in `CodexRootView`, including its empty state |
| `references/extension-thumbnail.md` | when drawing the 16×16 deck signature at 60 pt or 40 pt |
| `references/profile-contour.md` | in `ProfileView` — the spline, the tremble, the ghost, and the eight rules that stop it reading as a grade |
| `references/codex-page.md` | in `CodexPageView`, or when the Inscription docks a newly minted page |

Related skills, cited and never copied: `hunch-design-tokens` (every value), `hunch-shared-marks` (arc meter, tick row, machined bar, ghost frame, cancel hatch — this skill composes them and draws none of them), `hunch-bench-instruments` (rule-tiles and the Assay, which the Codex page composes read-only), `hunch-sigil-drawing` (mode, family and facet sigils, most of which are still undrawn), `hunch-motion-and-feedback` (every duration, beat and Reduce Motion substitution), `hunch-accessibility` (the rotor set, the announcement order and the string budget).

## Gotchas

- **`64` is a reference-layout number, not a constant.** §12.4, §11.2 and §9.2 all place regions at `y 20–64`; that is the bar's height *at Dynamic Type Large with no title wrap*. On the four screens whose bar carries a localized title, an AX5 German string wraps and the bar grows. Lay every region out relative to the bar's **resolved** height, never to the literal. Only the play surfaces, which carry no text at all, have a bar that is exactly 44 pt tall forever.
- **`.stroke` on a shape centres the line on its path; `.strokeBorder` insets it.** A 44 pt key stroked with `.stroke` occupies 44 pt of *centre-line* and 45 pt of ink, so two adjacent keys with an 8 pt gutter end up 7 pt apart and §12.8's ≥ 8 pt inter-target rule quietly fails. Every chrome frame uses `.strokeBorder` (or an explicitly inset `Path` in a `Canvas`).
- **A state-bearing line is never `stroke.hairline`.** `hunch-design-tokens/references/palette.md` §1 declares that token never state-bearing, and its measured ratio in both dark and light is at or below the visible threshold on a dimmed panel (PHOSPHOR §6.1) — read the column there, never a copy of it. A key border becomes an arc when a round is suspended, so it is state-bearing and is `weight.thin` in `stroke.secondary`. Separators, and only separators, are hairline.
- **The three sections that say where numerals may be rendered disagree.** §13.4 lists eight sites, §11's preamble says "exactly three", the inventory says seven. §13.4's list is a **typography** rule — *if* a number is rendered it is `type.numeral` — not a licence to render one. Probe counts, par, cap and Seal marks are tick marks and pips on screen and numerals only in VoiceOver. `references/numeral-readout.md` holds the resolved site table; use it, not any of the three.
- **A stock `Form` is the only place in the app where the OS picks a colour, and it picks wrong.** `systemGroupedBackground` and the system blue tint are palette violations that no grep catches, because there is no literal to find. Fix them once, at the container, in `HunchUI` — `references/stock-controls.md` §1.
- **`hue.*` may never touch chrome, which is why the Settings switch is drawn rather than tinted.** Every control on these screens is built from position, fill and ink, and the accent budget (three elements per screen, §13.1) cannot cover a 19-row Settings list. Chrome is `stroke.*` and `surface.*`; `accent.*` appears on exactly four chrome surfaces and each one is named in its reference file. The **Frame** is the screen where the three-element ration is actually reachable — three barred mode keys plus a brass streak ring is four — so `instrument-bar.md` §3.1 states it as an invariant with a test hook rather than as a caution.
- **Text grows on these screens; art does not.** `minimumScaleFactor` is 1.0 everywhere, rows grow and containers reflow (§13.4). Art takes `env.artScale`, clamped at `Prim.artScaleCeiling`. The Profile portrait and the Codex thumbnail are drawings and take *neither* — they hold their geometry at every type size (§13.11).
- **The art ceiling is a token, and a view may not spell it as a number or as a `Prim`.** Where a layout has to branch on it — the Settings pickers, the Codex page's rule-tiles — the only legal spelling is the derived predicate `env.isArtScaleClamped` (`hunch-design-tokens/references/render-env.md` §3). `check-source-hygiene.sh` check 9 greps hexes, `lineWidth:` and `.opacity(`; a bare `1.35` slips straight past it, which is exactly why it accumulated twenty copies before anyone noticed.

## Never

- Never draw a shadow, an elevation, a `.ultraThinMaterial` primary surface or a rounded-rect card. Luminance is the only depth cue in dark, impression the only one in light (§13.1), and each is a PR-rejection offence on sight.
- Never let a panel separate by a ground step alone or a hairline alone. It is always both (PHOSPHOR §3), because the `ground.base` → `ground.raised` step vanishes under auto-dimming and the hairline vanishes in daylight. Both ratios are `palette.md` §1's.
- Never put a `Text`, `Label` or `AttributedString` on a play surface, in any locale, outside an `.accessibility*` modifier. `check-source-hygiene.sh` check 7 fails the build. Chrome and the archive are the *only* places text exists.
- Never invent a seventh key size, a third rule weight, a third scrim or an eighth type role. Each of those sets is closed, and each closure is the reason the surface reads as one instrument.
- Never surface a band number, a percentage of the law space, a global completion meter, a percentile or a rank. §11.2 forbids the global meter, §10.5 the band number, §11.11 P1–P8 every form of grade.
- Never add a share sheet, an export row, a `UIActivityViewController`, a deep link or a local notification. §11.5 and §11's preamble decide against all of them; `CodexPageView` is composed screenshot-clean instead.
- Never copy a value out of `hunch-design-tokens` into a reference file here, and never copy a drawing out of `hunch-shared-marks`. Cite the token name and the owning symbol; each has exactly one home.
