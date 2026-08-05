# key.md — the generic chrome button

Owning symbol: `HunchUI/Chrome/Key.swift` → `struct Key<Sigil: View>: View` plus `enum KeyState`.
Nothing else draws a chrome button. Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row C, *Key*.

Contents: [1 The six sites](#1-the-six-sites) · [2 Anatomy](#2-anatomy) · [3 The six states](#3-the-six-states) ·
[4 Implementation](#4-implementation) · [5 Interaction](#5-interaction) · [6 VoiceOver](#6-voiceover) ·
[7 Reduce Motion](#7-reduce-motion) · [8 High Contrast and Bold Text](#8-high-contrast-and-bold-text) ·
[9 Dynamic Type](#9-dynamic-type) · [10 Wrong](#10-wrong)

---

## 1. The six sites

Six named sites, **four distinct rectangles** — 44 × 44 serves three of them, which is the point: the
player's thumb learns one target size and the exceptions are both large.

| # | Site | Rect | Where | §|
|---|---|---|---|---|
| 1 | commit-bar key | 44 × 44 | PROBE · twin · Bench; Dial · Seal; twin/replay · Seal; SIEVE pause | §4.1, §4.2, §8.4, §9.2 |
| 2 | mode-rack key | **168 × 108** | the Frame, 2 × 2, 12 pt gutters, 13.5 pt side margins | §12.4 |
| 3 | shelf key | **168 × 52** | the Frame — Codex (leading), Profile (trailing) | §12.4 |
| 4 | palette stamp | **68 × 44**, AX3+ **165 × 56** | the Bench palette | §4.2, §13.11 |
| 5 | facet stamp | 44 × 44 | `CodexRootView`'s facet bar, five of them | §11.2 |
| 6 | utility key | 44 × 44 | play · Settings · Anomaly · back · chevron | §12.3, §12.4 |

`C.Key.rect(_ site: Site, in: RenderEnv)` is the single accessor. The palette stamp is the only site
whose rectangle changes with the environment, and it changes by **substitution** at AX3, not by
scaling — a 68 × 44 stamp multiplied by `Prim.artScaleCeiling` is 92 × 59, which is not 165 × 56 and does not fit the
2 × 2 grid §13.11 requires.

**There is no seventh size.** A new chrome button is one of these six or it is a new inventory row
with its own reference file. The commit bar on a Pro Max is 60 pt *tall* (§6.2) and the key inside it
is still 44 × 44, centred — the bar grows, the target does not.

Sites 1, 5 and 6 draw their sigil at **24 pt inside the 44 pt hit rect** (§12.8). Sites 2 and 3 draw
at their own scale; the mode sigil on a rack key is `hunch-sigil-drawing`'s, and the throat sigil on
the play key is a 44 pt throat drawing owned by `hunch-bench-instruments/references/throat.md`.

---

## 2. Anatomy

Three layers, outside in. Every value below is a token; none of them is stated here.

| Layer | Paint | Weight / radius |
|---|---|---|
| interior | `surface.cell` idle, `surface.cellLit` pressed and selected | `Radius.chrome` |
| border | `stroke.secondary` | `env.weight(.thin)`, drawn with `.strokeBorder` |
| sigil | `stroke.primary`; `opacity.disabled` when disabled | the sigil's own weights |

**Why the border is `stroke.secondary` and not `stroke.hairline`.** The border carries the suspended
arc (§3 below), so it is state-bearing, and `hunch-design-tokens/references/palette.md` §1 declares
`stroke.hairline` never state-bearing. §3's inventory row says "hairline 1 pt border" using
*hairline* as a word for a thin line; the token named `weight.hairline` is the **separator** weight
and is thinner (`dimensions-strokes-opacity.md` §1). The key's border is `weight.thin`. Getting this
backwards produces a key whose outline sits at `stroke.hairline`'s ratio — the lowest in the
palette — and disappears on a dimmed panel.

**The interior is a ground step, never a tint.** PHOSPHOR §3 fixes the pressed state as
`surface.cellLit`. A tinted press would spend accent budget (three elements per screen, §13.1) on
something that is not a verdict, and the commit bar has three keys.

---

## 3. The six states

`enum KeyState { case idle, pressed, selected, barred, disabled, suspended(Double) }` — a single
enum, not a bag of `Bool`s (`03 W28`). The associated `Double` is `probesUsed / par`, clamped to
`0...1`, so a suspended key cannot exist without its progress.

| State | Geometry | Colour channel | Second channel |
|---|---|---|---|
| **idle** | border + sigil at full | — | — |
| **pressed** | interior steps to `surface.cellLit` | — | ground step |
| **selected** | border steps to `stroke.primary`, interior to `surface.cellLit` | — | border weight unchanged, ink changes |
| **barred** | the machined bar crosses the key | `accent.cold` | the bar itself |
| **disabled** | sigil at `opacity.disabled`; **border stays full** | — | — |
| **suspended** | border becomes an arc filled to the fraction; sigil lights | — | arc extent |

**Barred is not drawn here.** It is `hunch-shared-marks/references/machined-bar.md`, and it is
deliberately the identical drawing used by the barred Seal (§4.3, §12.4) so the idiom is learned
once. The gates that decide *when* a mode key is barred are §9.10's and belong to the serving layer;
this component renders the bar, it does not decide it.

**Suspended is not drawn here either** — the arc is
`hunch-shared-marks/references/arc-meter.md`, in its continuous, linear variant. This file owns only
that the arc *replaces* the border rather than sitting inside it, which is what makes the state
readable at a glance across a 2 × 2 rack.

**Disabled keeps its border at full ink, and that is this skill's ruling.** §13.11 states no High
Contrast substitution for `opacity.disabled`, so a uniformly-dimmed key measures `Opacity.disabled`
of its resting contrast and can fall below the state-bearing floor the High Contrast theme guarantees
(`hunch-design-tokens/references/palette.md` §1's "High Contrast floors" paragraph; the opacity is
`dimensions-strokes-opacity.md` §5). Dimming the sigil says *this control is not available*; dimming
the border says *there may not be a control here*, which is a different and wrong sentence. Only the
sigil dims.

`barred` and `disabled` are different states and must not be merged. Barred is a machine refusing
with a reason (`SealBar` carries which one); disabled is a control that is not applicable. The
Anomaly key under `.clockBehind` is barred, not disabled — it draws a full static ring (§12.4).

---

## 4. Implementation

```swift
// Modules/Sources/HunchUI/Chrome/Key.swift
struct Key<Sigil: View>: View {
    let site: Key.Site
    let state: KeyState
    let action: () -> Void
    @ViewBuilder let sigil: () -> Sigil

    @Environment(\.renderEnv) private var env

    var body: some View {
        Button(action: action) {
            sigil()
                .opacity(state == .disabled ? Opacity.disabled : 1)
                .frame(width: C.Key.rect(site, in: env).width,
                       height: C.Key.rect(site, in: env).height)
                .background(interior)
                .overlay(frame)
                .overlay(MachinedBar(isPresent: state == .barred))   // shared-marks, one owner
                .contentShape(Rectangle())                            // the whole rect, not the sigil
        }
        .buttonStyle(.plain)          // the ONLY correct style: .bordered/.borderedProminent tint blue
        .disabled(state == .disabled || state == .barred)
        .accessibilityRespondsToUserInteraction(state == .barred)     // §12.8: findable while refusing
    }

    private var interior: some View {
        RoundedRectangle(cornerRadius: Radius.chrome, style: .continuous)
            .fill(env.palette.surface(state.isLit ? .cellLit : .cell).color)
    }

    @ViewBuilder private var frame: some View {
        switch state {
        case .suspended(let fraction):
            ArcMeter(fraction: fraction, style: .continuous)          // shared-marks
        default:
            RoundedRectangle(cornerRadius: Radius.chrome, style: .continuous)
                .strokeBorder(env.palette.stroke(state == .selected ? .primary : .secondary).color,
                              lineWidth: env.weight(.thin))
            //   ^^^^^^^^^^^^ strokeBorder, not stroke: .stroke centres the line on the path and
            //   spends half a point outside the frame, eroding §12.8's ≥ 8 pt inter-target gutter.
        }
    }
}
```

`.contentShape(Rectangle())` is load-bearing: without it a 24 pt sigil inside a 44 pt frame is only
tappable on the sigil, and the 44 pt minimum becomes a lie that no snapshot test catches.

---

## 5. Interaction

- **Tap** fires `action`. There is no long-press, no double-tap-to-mean-something-else and no
  context menu anywhere in the app (§12.8).
- **Swipe toward the trailing edge** on a *suspended* mode-rack key discards the round and starts
  fresh (§12.4). It reuses the Bench's clear-a-rail gesture deliberately. It is the only gesture on
  any key, and it must have a tap route: there is none, and that is correct — discarding is rare and
  destructive, and tapping resumes.
- **Confirm-by-repeat exists twice in the whole app** and neither is here: the optional Seal confirm
  (§12.6) and SIEVE's paused abandon chevron (§9.2). A key that asks twice anywhere else is wrong.
- Press feedback is a ground step within `Dur.tap`; the audio and haptic cues are
  `hunch-motion-and-feedback/references/feedback-target.md`.

---

## 6. VoiceOver

The key is a `Button`, so the `.isButton` trait, the tap and the `.notEnabled` state come free —
which is the reason it is a `Button` and not a `Rectangle` with `.onTapGesture`.

| State | Trait | Value |
|---|---|---|
| idle | `.isButton` | — |
| selected | `+ .isSelected` | — |
| barred | `+ .notEnabled`, `accessibilityRespondsToUserInteraction(true)` | the reason, from `SealBar` |
| disabled | `+ .notEnabled` | — |
| suspended | `.isButton` | the probe fraction, spoken: "12 of 23 probes" |

Labels come from `Localizable.xcstrings` through `Loc`, and their count is budgeted in §12.9 — Frame
8, Codex root 6, Codex shelf 3. **Never build a label by concatenating fragments** (§12.9 trap 3):
one format string per sentence, plural variations for every count.

A hint is added only where the action is not implied by the label. "Resumes the suspended round" on a
suspended mode key earns one; "Opens Settings" on the Settings key does not.

---

## 7. Reduce Motion

Nothing on a key translates, scales or rotates at any time, so most of §13.7.4 does not apply. Three
things do:

- The press ground step is a colour change, not motion, and is unchanged.
- The suspended arc is static; it never sweeps in.
- **The onboarding breath is a gap in §13.7.4.** §12.5 beat 1 gives the PROBE key a slow opacity
  breath, and it is the only lit pixel on screen — the whole of beat 1's teaching. §13.7.4 does not
  list it, and neither its rate nor its opacity pair is a chrome value: both belong beside the other
  pulses in `hunch-design-tokens/references/dimensions-strokes-opacity.md` §5 and
  `durations-and-easing.md`. The substitution must be **static at full ink**, not at the dim end and
  not removed: the breath's message is *press me* and its dim half carries no information, so
  freezing it at the bright end loses nothing. Add the row to
  `hunch-motion-and-feedback/references/reduce-motion.md`; that skill owns the table, this file owns
  only the observation that the row is missing.

---

## 8. High Contrast and Bold Text

- Border: read it from `env.weight(.thin)`, never compute it. Bold Text scales, High Contrast offsets,
  and the four resolved values are `dimensions-strokes-opacity.md` §2's `weight.thin` row — that
  table is the one home and this file does not carry a copy.
- `surface.cellLit` under High Contrast is a very small step against `ground.base` (`palette.md` §1).
  That is why it is the *second* channel behind the border ink change on `selected` — never the only
  one.
- Bold Text is the system's only signal that this player wants heavier marks (§13.11), and it reaches
  a key entirely through `env.weight(_:)` and `env.type(_:)`. Nothing here branches on it.
- Differentiate Without Color changes nothing on a key, because no key state is encoded by colour in
  the first place. `barred` reads as a bar; `selected` reads as an ink step; `suspended` reads as an
  arc.

---

## 9. Dynamic Type

Keys carry no text, so they do not scale with type — with one exception and one reflow:

| Category | Effect |
|---|---|
| xSmall … xxxLarge | reference rectangles |
| accessibility1 | palette stamp substitutes 68 × 44 → 165 × 56 and the palette becomes 2 × 2 (§13.11) |
| accessibility2 … 5 | the mode rack reflows 2 × 2 → 1 × 4 and scrolls; key rectangles are unchanged |

Both changes are **layout**, not scale. The 44 pt hit rect is a floor, never a value to multiply, and
`env.artScale` never reaches a key.

---

## 10. Wrong

- **`.buttonStyle(.bordered)`, `.borderedProminent`, `.plain` with a system `.tint`, or any
  `Label`-shaped stock button.** All of them paint with the system accent, which is not in the
  palette and which no hex grep will catch.
- **`.stroke` instead of `.strokeBorder`.** Half the line lands outside the frame; adjacent keys end
  up closer than §12.8's 8 pt minimum.
- **A seventh rectangle.** Six sites, four rectangles. If a new button does not fit one, the layout
  is wrong, not the key.
- **`accent.brass` or `accent.cold` as a key's border or interior.** Accent is a *verdict* register
  (§13.2) and is rationed to three elements per screen; the machined bar is the only accent a key
  ever carries.
- **`hue.*` anywhere on a key.** Forbidden on chrome outright — and `HueColor` will not convert, so
  this is a compile error, not a review note.
- **Merging `barred` and `disabled`,** or spelling either as `isEnabled: Bool`. `SealBar` exists
  precisely because "which rail is empty" is a question a `Bool` cannot answer (`08 §3`).
- **Dimming the whole key when disabled.** Only the sigil dims — §3 above.
- **Scaling a key by `artScale`, or by the Codex page's `C.CodexPage.tileScale`.** Chrome holds its
  geometry.
- **A bare `1.35`, or any other spelling of the art ceiling, anywhere in this component.** The
  palette stamp's AX1 substitution is a rectangle swap keyed on `env.isArtScaleClamped`, never a
  multiplication (§1, `render-env.md` §3).
- **A rounded-rect card, a shadow, a gradient, an SF Symbol, or a rounded corner above
  `Radius.chrome`.** §13.1 lists every one as a PR-rejection offence.
- **`.onTapGesture` on a shape instead of a `Button`.** It silently drops the `.isButton` trait,
  `.notEnabled`, the press feedback and Magic Tap eligibility.
