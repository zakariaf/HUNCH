# type-ramp.md — L1 typography

Contents: [1 The seven roles](#1-the-seven-roles) · [2 Bold Text](#2-bold-text) ·
[3 Dynamic Type and tracking](#3-dynamic-type-and-tracking) · [4 Uppercasing](#4-uppercasing) ·
[5 Numerals](#5-numerals) · [6 The zero-text rule](#6-the-zero-text-rule)

System faces only — SF Pro (variable width, iOS 16+) and SF Mono via `design: .monospaced`. No
bundled font, no licence file, no bytes toward the 15 MB budget.

---

## 1. The seven roles

§13.4 verbatim. Read one with `env.type(.numeral)`, which returns the role already stepped for Bold
Text. `TypeRole.numeral` alone is the *unresolved* token — correct in a table, wrong at a call site.

| Token | Size @ Large | Weight | Width | Tracking (em) | Face | `relativeTo:` | Where |
|---|---|---|---|---|---|---|---|
| `type.display` | 28 | semibold | condensed | 0.06 | SF Pro | `.largeTitle` | Codex page title, Profile |
| `type.title` | 20 | semibold | condensed | 0.08 | SF Pro | `.title2` | screen titles |
| `type.section` | 13 | medium | condensed | 0.14, **UPPERCASE** | SF Pro | `.caption` | instrument labels, Settings headers |
| `type.body` | 17 | regular | standard | 0 | SF Pro | `.body` | Settings rows, Codex notes |
| `type.caption` | 13 | regular | standard | 0.01 | SF Pro | `.footnote` | secondary metadata |
| `type.numeral` | 15 | regular | standard | 0 | **SF Mono**, `monospacedDigit` | `.subheadline` | every number, always |
| `type.micro` | 11 | medium | condensed | 0.16, **UPPERCASE** | SF Pro | `.caption2` | statistics and Settings section heads, column heads |

There is no eighth role. If a piece of text does not fit one of these, it is either chrome that
should reuse `type.caption`, or it is text that should not exist.

---

## 2. Bold Text

Bold Text steps the **font weight one notch and clamps at `bold`** — `regular → medium → semibold →
bold` — which is stage 2 of the resolution order, the same stage as the ×1.25 on stroke weights.

| Role | weight | under Bold Text |
|---|---|---|
| `type.body`, `type.caption`, `type.numeral` | regular | medium |
| `type.section`, `type.micro` | medium | semibold |
| `type.display`, `type.title` | semibold | bold |

`TypeRole.Weight` is `Int`-backed and `Comparable` precisely so `bolder` is one expression that
saturates rather than a five-arm switch that will be wrong the day a role changes weight.

Nothing else about a role changes under Bold Text: not the size, not the width, not the tracking.
Size is Dynamic Type's axis and tracking is derived from the scaled size.

---

## 3. Dynamic Type and tracking

**Tracking is stored in `em` and applied as `scaledSize × trackingEm`** — `role.tracking(atScaledSize:)`.
Fixed-point tracking collapses at AX5: `type.micro` at 0.16 em is 1.76 pt at Large and 4.6 pt at
AX5, and freezing it at 1.76 turns a letterspaced small-caps head into a cramped one exactly where
legibility matters most.

**`minimumScaleFactor` is 1.0 everywhere, no exceptions.** Text wraps, containers grow, layouts
reflow. A view that shrinks text to fit has substituted a legibility failure for a layout failure.

Every role declares `relativeTo:` its nearest system style, so the OS does the scaling. The role's
`size` is the value at Large and is never multiplied by hand; `env.artScale` is for **art**, and
applying it to text would scale text twice and clamp it at 1.35 into the bargain.

The per-screen AX3–AX5 behaviour table — which screens reflow, which freeze at 1.35×, which scroll —
is §13.11 and belongs to `hunch-accessibility`. Do not restate it here.

---

## 4. Uppercasing

`type.section` and `type.micro` carry `isUppercased: true`. Apply it with
**`String.uppercased(with: locale)`**, never a display transform and never the font's small-caps
feature. Three reasons, all shipped-bug shaped: Turkish dotted-I maps `i → İ` and the naive path
gives `I`; Arabic is caseless and a transform mangles shaping; SF Pro's small-caps feature degrades
non-Latin to full caps. HUNCH ships 12 localisations, so all three will occur.

The localisation accessor and the `Loc.swift` bundle rule are owned elsewhere; this file owns only
"which roles are uppercased, and by which call".

---

## 5. Numerals

**`type.numeral` is SF Mono with `monospacedDigit`, and it is mandatory** wherever a value changes
without a layout pass: probe counts, par/cap, Seal marks, the Anomaly tally and streak, the Codex
page's instrument strip, the Profile stat block, the statistics screen, and the Settings version. A
proportional digit that shifts a column on every probe is a bug, not a preference.

The Profile **portrait** carries no numeral at all. That is a design rule (§11.11 P2), not a
typography one, and the portrait is a drawing that does not scale with type.

---

## 6. The zero-text rule

**No type role may be used on the play surface, in any locale.** Not `type.caption`, not
`type.micro`, not a debug label. The tally is tick marks, verdicts are rings, and the throat, the
Dial, the Bench, the ribbon, the Assay, the gate band and onboarding are all wordless by
construction.

The enforcement is a source lint, not a runtime test: `check-source-hygiene.sh` check 7 fails on
`Text`, `Label` or `AttributedString` outside `.accessibility*` modifiers in the six play-surface
files. Accessibility labels are exempt and required — a wordless surface is not an unlabelled one.

Text lives only in Settings, Codex, Statistics and About.
