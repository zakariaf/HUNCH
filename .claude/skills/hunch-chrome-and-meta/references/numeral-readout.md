# numeral-readout.md — where a digit may become a pixel

Owning symbol: `HunchUI/Chrome/NumeralReadout.swift` → `struct NumeralReadout: View`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row C, *Numeral readout*.

Contents: [1 The disagreement, resolved](#1-the-disagreement-resolved) · [2 The site table](#2-the-site-table) ·
[3 Why SF Mono *and* monospacedDigit](#3-why-sf-mono-and-monospaceddigit) · [4 Formatting](#4-formatting) ·
[5 Implementation](#5-implementation) · [6 VoiceOver](#6-voiceover) · [7 Environment behaviour](#7-environment-behaviour) ·
[8 Wrong](#8-wrong)

---

## 1. The disagreement, resolved

Three sections of `GAME_DESIGN.md` say different things about where numerals appear:

- **§13.4** lists eight: probe counts, par/cap, Seal marks, the Anomaly tally and streak, the Codex
  page's instrument strip, the Profile's stat block, the statistics screen, the Settings version.
- **§11**'s preamble says numerals are permitted in *"exactly three places"*: the instrument strip,
  the statistics screen, and the Anomaly tally.
- **The inventory** (`DESIGN-SYSTEM-SCOPE.md` §3) says *"7 named sites"*.

**§13.4 is a typography rule, not a rendering licence.** It says: *if* a number is rendered as text,
it is `type.numeral`. It does not say the number is rendered. Probe counts, par, cap and Seal marks
are drawn as **tick marks and pips** on the play surface (§4.1: "probe tally as tick marks… No text,
no numerals") and are spoken as numbers only by VoiceOver (§13.10: "numbers are spoken even though
they are never drawn").

**§11's "exactly three" is scoped to the meta layer's textless surfaces** — the Codex browse
hierarchy and the Anomaly ribbon. It does not cover Settings, About or the Profile stat block, all of
which §12.9 budgets strings for.

§2 below is the resolution and the only list to work from.

---

## 2. The site table

Seven sites where a digit is rendered as a pixel. Everywhere else in the app, a count is a tick row,
a pip, an arc or a ring.

| # | Site | What | Role | Fixed by |
|---|---|---|---|---|
| 1 | `CodexPageView` instrument strip | `bestProbes` beside its tick row; the band's `par` | `type.numeral` | §11.1, §11.2 |
| 2 | `CodexPageView` instrument strip + find log | the find date, and a date per re-strike ring | `type.numeral` | §11.1 |
| 3 | `StatisticsView` | 19 labelled rows and column heads | `type.numeral`, heads `type.micro` | §11.12, §12.9 |
| 4 | `AnomalyView` tally | the large lifetime `solvedClean + solvedFractured` count | `type.numeral` | §11.8 |
| 5 | `AnomalyView` streak | the current streak beside its ring | `type.numeral` | §11.8, §13.4 |
| 6 | `ProfileView` stat block | five rows — rounds, pages, longest run, Anomaly streak, mean probes/par | `type.numeral` | §11.12, §12.9 |
| 7 | `AboutView` / Settings ABOUT row | version and build | `type.numeral` | §12.6, §12.9 |

**Two are drawn as geometry beside their numeral, not instead of it** — sites 1 and 5. The Codex
strip carries `bestProbes` as a tick row *with* the numeral beside it (§11.1), and the Anomaly streak
is a ring *with* its count. Both are deliberate: the geometry is the glanceable form, the numeral is
the exact one, and the archive is the one place exactness is worth a digit.

**Not a numeral site, in any circumstance:**

- the entire play surface — `RoundView`, `EchoRoundView`, `SieveRoundView`, `BenchView`,
  `AssayInspectorView`, the Inscription's reveal region (§12.9);
- the Frame's Anomaly key — the arc and the ring, no numeral; the tally lives on `AnomalyView`
  (§12.4);
- the **Profile portrait** — it carries no numeral at all (§11.11 P2), and this is a rule about the
  drawing, not about typography;
- any shelf plate, thumbnail, facet stamp or Codex grid cell (§11.2: textless by construction);
- SIEVE's instrument bar — a lawful count there leaks the law's admit rate `p` (§9.2);
- a global completion meter or percentage anywhere (§11.2: "No global meter anywhere").

---

## 3. Why SF Mono *and* `monospacedDigit`

`type.numeral` is the SF Mono role **and** carries `monospacedDigit` (§13.4); its size, weight,
tracking and `relativeTo:` anchor are `hunch-design-tokens/references/type-ramp.md` §1's row and are
not restated here. SF Mono is already fully monospaced, so the modifier looks redundant. It is not,
and the reason is site-specific:

**SF Mono has no Eastern Arabic digits.** §12.9 trap 7 states that locale-native numerals are
*correct*, not a bug — a player in Arabic sees ٠١٢٣٤٥٦٧٨٩ in the Codex. Those glyphs come from a
system fallback face, and a fallback is proportional unless asked otherwise. `monospacedDigit` is
what keeps the Statistics column and the Codex strip from jumping when the digits are not SF Mono's.

So: read the role, never assemble the font. `env.type(.numeral)` carries both halves and the Bold
Text step; `.font(.system(.subheadline, design: .monospaced))` carries neither correctly.

---

## 4. Formatting

Every number goes through `Date.FormatStyle`, `NumberFormatter` or `Measurement` against the resolved
locale — never string arithmetic (§11.12), and never `"\(n)"`.

| Kind | Spelling |
|---|---|
| a count | `n.formatted(.number)` — locale digits, locale grouping |
| a date | `date.formatted(.dateTime.year().month().day())` (§11.1) |
| a count with a word | a String Catalog entry with **plural variations**, resolved through `Loc` |
| a ratio (probes / par) | one format string with two interpolations, never `"\(a) / \(b)"` |

Four traps, all from §12.9 and all shipped-bug shaped:

1. **Never concatenate translated fragments.** One format string per sentence. "3 of 7 probes" is one
   key with two interpolations.
2. **Plurals are grammar, not an `if`.** Russian needs four categories, Arabic six. Any
   `count == 1 ? … : …` is a bug the lint test fails on.
3. **`Text(mode.rawValue)` is never extracted** and ships English forever. Every user-facing enum
   exposes `var label: LocalizedStringResource`; `rawValue` is for serialisation.
4. **Everything resolves through the one `Loc` accessor**, which carries the override bundle and the
   resolved locale. A bare `Text("Probes")` is extracted but bypasses the override and stays English
   until relaunch.

---

## 5. Implementation

```swift
// Modules/Sources/HunchUI/Chrome/NumeralReadout.swift
struct NumeralReadout: View {
    let value: Int
    let label: LocalizedStringResource?     // nil where the row's own label already names it
    var isLive: Bool = false                // counters that change without a layout pass

    @Environment(\.renderEnv) private var env

    var body: some View {
        Text(value.formatted(.number))
            .font(env.type(.numeral).font)                 // SF Mono + monospacedDigit + Bold Text
            .foregroundStyle(env.palette.stroke.primary.color)
            .lineLimit(nil)
            .minimumScaleFactor(1)                          // §13.4: 1.0 everywhere, no exceptions
            .contentTransition(.identity)                   // §7 — no odometer roll
            .accessibilityLabel(label.map(Text.init) ?? Text(""))
            .accessibilityValue(Text(value.formatted(.number)))
            .accessibilityAddTraits(isLive ? .updatesFrequently : [])
    }
}
```

`.minimumScaleFactor(1)` is written explicitly rather than omitted, because the default is 1 and the
whole risk is that someone later "fixes" a tight column by lowering it. §13.4 makes that a
legibility failure substituted for a layout failure.

State-bearing numerals are `stroke.primary` — the palette's highest-contrast ink in every theme
(`hunch-design-tokens/references/palette.md` §1). A numeral in `stroke.secondary` is a *label's* ink,
not a value's — see `rules-and-boundaries.md` §3.

---

## 6. VoiceOver

Numbers are audio-first in this app: many exist only in speech. Three rules.

- **Speak the number with its unit, as one localized sentence.** §13.10's probe tally is
  `"12 of 23 expected, 37 maximum"` — not "12", not "12 23 37". The label names the quantity, the
  value carries the sentence.
- **`.updatesFrequently` on anything that changes without a layout pass** — the probe tally, the
  SIEVE foul count, the Anomaly tally as it increments. Without it VoiceOver caches a stale value.
- **Never let the accessibility label be the raw digits.** `accessibilityLabel("12")` makes the rotor
  read a column of bare numbers with no idea what they count.

Announcement order is fixed at **verdict → evidence → bookkeeping** (§13.10), so a probe count is
always the *last* thing spoken after a verdict, never the first.

---

## 7. Environment behaviour

| Setting | Effect |
|---|---|
| **Bold Text** | `type.numeral` steps one weight notch (`hunch-design-tokens/references/type-ramp.md` §2). Nothing else changes |
| **Dynamic Type** | the role's own `relativeTo:` anchor (`type-ramp.md` §1); the row grows, the numeral never shrinks. At AX1 Settings rows go label-over-value; at AX2+ the Profile stat block is one item per line (§13.11) |
| **High Contrast** | `stroke.primary` substitutes to the High Contrast column of `palette.md` §1 and needs nothing from this file. Do not additionally embolden — that is Bold Text's axis |
| **Reduce Motion** | see below |
| **RTL** | the numeral mirrors *with its row*; digits themselves are locale-native and are laid out by the system. Never reverse a formatted string by hand |

**No odometer, in any environment.** §13.7's budget is one orchestrated moment per round, and a
rolling digit is a text animation on a screen that already has one (§11.8: "the tally numeral
incrementing" happens on the Inscription, where the reveal owns the timeline). A value that changes
crossfades in place — which is also §13.7.4's default substitution, so Reduce Motion changes nothing
here. `.contentTransition(.numericText())` is the specific spelling to avoid: it is a rolling digit
by another name.

---

## 8. Wrong

- **`Text("\(n)")` or `Text(String(n))`.** No locale digits, no grouping, and it is not a translation
  unit. §12.9 trap 1.
- **`.font(.system(size: 15, design: .monospaced))`** or any hand-assembled font. Bypasses the role,
  the Bold Text step and `relativeTo:` — and it puts a copy of `type-ramp.md`'s size in a view.
- **`.monospacedDigit()` alone.** Gives tabular figures in SF Pro, not the instrument-panel face.
- **A numeral anywhere on the play surface,** including a debug overlay. `check-source-hygiene.sh`
  check 7 fails the build on `Text` in the six play-surface files.
- **A numeral on the Profile portrait.** §11.11 P2 — and a percentage there would be a grade, which
  P1–P8 exist to make impossible.
- **A numeral where the spec says a tick row, a pip, a ring or an arc.** Par, probes, Seal marks,
  fouls and streak are geometry first; sites 1 and 5 are the only two that also carry the digit.
- **`.minimumScaleFactor(0.8)`, `.truncationMode`, or `lineLimit(1)` on a numeral.** §13.4.
- **A percentage, a percentile, a rank, a global completion figure or a band number.** §11.2, §10.5,
  §11.11 P1–P8.
- **`count == 1 ? "page" : "pages"`.** §12.9 trap 4; the lint test fails on it.
- **`.contentTransition(.numericText())`.** §7.
