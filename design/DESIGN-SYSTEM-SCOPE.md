# HUNCH — Design System Scope

Scope decision for a one-engineer, one-binary, zero-dependency SwiftUI game whose play surface is 100 % custom-drawn. Against `GAME_DESIGN.md` §2, §4, §12, §13. 2026-07-27.

---

## 1. What §13 already is — the honest audit

**§13 is a complete design *specification* and roughly 70 % of a design *system*.** A spec says what the values are; a
system makes them the only place the values exist, and names the things they are applied to. §13 does the first exhaustively and the second not at all.

| Layer | § | Verdict — all of these are finished |
|---|---|---|
| Semantic colour | 13.2 | 10 tokens × 3 themes with hexes **and measured WCAG ratios against `ground`**, the register-segregation rule, the light-theme keyline decision. A finished semantic colour layer. |
| Weights, space, grid, corners | 13.3 | 5 named stroke weights with exhaustive application lists; 4 pt base and 9-step scale; 16 pt margin and the 343 pt column arithmetic; 2 pt chrome radius / 12 pt sheet / **0 on glyphs**; butt-vs-round caps. |
| Type ramp | 13.4 | 7 roles: size, weight, width, tracking-in-em, face, usage, `relativeTo:`, `minimumScaleFactor 1.0`, locale-aware uppercasing. More rigorous than most shipped systems. |
| Glyph geometry | 13.5 | A fully parametric component spec (`bodyCentre`, `R`, `pitch`, coverage %, node radius, index-stroke length and rotation) plus §13.5.1's falsifiable proof and two shipped tests. **The one component in the app that is completely specified.** |
| Motion | 13.7 | An 8-beat reveal with t/dur/easing per beat, a lost variant, two micro-responses, a transition table, and §13.7.4 — a *complete* Reduce Motion substitution table with an invariant test for SIEVE. §13.7.4 is effectively a state matrix for motion. |
| Audio · Haptics | 13.8, 13.9 | 15 cues (frequency, waveform, attack, decay, peak, buses, ceiling, session policy) and 11 patterns (event kind, time, intensity, sharpness). Both carry normative-source clauses that supersede conflicting numbers elsewhere. |
| VoiceOver | 13.10 | ~25 elements with traits/label/value/actions, 4 rotors, Magic Tap, fixed announcement order, a 16-gesture walkthrough, a 10 000-law parity invariant. **The closest thing the GDD has to a component inventory** — but indexed by accessibility element, not by drawing, and it omits every non-interactive mark. |
| A11y settings | 13.11 | Dynamic Type per screen, Reduce Transparency, Bold Text, Differentiate Without Colour, High Contrast — each with concrete numeric deltas. |
| Acceptance | 13.12 | 13 gates, each mapped to `tests.json`. |

Three things §13 has that most shipped systems do not: **measured** contrast rather than claimed contrast; a redundancy
proof falsifiable by a shipped test; normative-source clauses that pre-resolve cross-section conflicts. Plus §2's
locked-terminology table — a naming system for *concepts*, and a genuine asset, with no counterpart for identifiers or drawings.

---

## 2. What is missing

Your three are confirmed. Two need correcting upward, and I am adding five.

**(a) Tokens exist only as prose — CONFIRMED, and the colour table is the least of it.** §13.2 declares the contract
("named tokens only; no literal hex in view code; `Theme.token(_:)` resolves against the active theme") without building
it. The larger drift surface is the **component-level** numbers, absent from §13 entirely: 25 % unlit / 40 % under HC,
30 % + slash for inert, 0.78× Codex rule-tiles, 12 % Profile spokes, 6 % interior fill, Assay cells at 3.5 / 4 / 9.5 /
23 pt, tremble `A = R0·0.05`, the 1.06 : 1 ground shift — spread over six sections, each destined for Swift twice.

**(b) No component inventory — CONFIRMED, and the ramp count is wrong: seven, not four.** Dial (single-select), Bench
Ramp tile (multi-select), Fork **gate** dock (exactly-one), Fork **then** dock, Fork **else** dock — §4.2 gives the lit
and dim docks *each* a full ramp on the same attribute, two instances, not one — and the Tally rank ramp: five
interactive. Plus two depictive reuses that must not drift from the real drawing: the Codex facet bar's
attribute-participation stamp (§11.2, "four ramp headers") and the Profile's *Induction* sigil (§11.11 P3, "a ramp silhouette").

**(c) Nothing rendered — CONFIRMED, and the sharpest instance:** §13.5.1 asserts pairwise L1 luminance distance ≥ `T`,
"`T` asserted as a shipped constant", and **never states `T`** — falsifiable in form, undetermined in fact, and choosing
it requires rendering all 256. Second instance, scale: `dotted` at S = 24 pt gives `R = 8.9`, `pitch = 5`,
`dotRadius = 1.25` inside a 2.25 pt inset — perhaps three visible dots. §13.5's "identical from 24 pt to 220 pt" is true
of the *math* and unverified of the *raster*; the Codex thumbnail (3.5 pt cells) and SIEVE tail (36 pt) live down there.

**(d) The environment→value resolution order is undefined.** §13.11 steps Bold Text weights **×1.25** and High Contrast
**+0.5 pt**; both can be on. `3.0 × 1.25 + 0.5 = 4.25` vs `(3.0 + 0.5) × 1.25 = 4.375`, and nothing says which — same gap
for Dynamic Type's ≤ 1.35× art multiplier against either. Exactly what a token layer exists to answer once.

**(e) ~17 marks are named but never drawn.** Four mode sigils are specified (§12.4); **eight family sigils** and the
skeleton silhouettes (§11.2) are not, the **five Profile vertex sigils** get one clause each (§11.11 P3), the **five Codex
facet stamps** a parenthesis. In a wholly textless navigation, the largest remaining *design* gap — drawing, not tokens.

**(f) The light theme is specified but unreviewed**, and §14.2 cuts it from the MPP; mark its hexes provisional until
something renders in it. **(g) Shared idioms have no declared owner** — the machined bar is specified twice, §4.3 (Seal)
and §12.4 (mode key, "the identical drawing"), with no statement of which file owns the drawing; likewise the ghost frame
(four sites), cancel hatch (three), tick row (seven). **(h) No naming rule for identifiers** — §13.2 uses dotted
lowercase (`ground.raised`), §13.3 bare camelCase (`bodySm`), §13.4 bare lowercase (`display`): three conventions in
three consecutive tables.

---

## 3. The component inventory

Derived from the GDD. **Marks** are drawn atoms with no touch target; **instruments** are composed and interactive; **chrome** frames them; **meta** is the archive layer.

| Component | Appears in | States | Variants | Spec |
|---|---|---|---|---|
| ***A. Marks*** | | | | |
| **Glyph** | throat 96/128 · ribbon tile 44 · Dial & Bench ramp cells · ECHO tray 52 / rail 44 / primer 44 / seed 36 · SIEVE lane 72 / tail 36 · counterexample · Frame idle Loom | plain · bloomed · admit/reject-animating · ghosted · eliminated (25 % + hatch) · monochrome | 256 values × 2 size regimes (< 48 pt → `bodySm`) × 3 themes | §2, §13.5 |
| **Verdict ring** | throat · ribbon tile · counterexample (two concentric: solid = Loom, dashed = yours) · ECHO primer · SIEVE sump + tail · Codex re-strike rim | expanding-closed (admit) · contracting-broken (reject) · doubled (twin) · open · dashed · 5+ filled | gap ×2 under Differentiate Without Colour; ×0.7 amplitude for twin | §4.5, §13.7.2, §13.11, §11.3 |
| **Ghost frame** (dashed hollow + backward chevron) | Bridge trailing socket · ribbon `prev` marker · Assay pin thumbnail · ECHO seed glyph · DRIFT mode sigil | on · off · read-only | live vs depictive | §4.2, §4.3, §8.4, §12.4 |
| **Machined bar** | barred Seal · barred mode-rack key | present · retracting (reveal beat 0) · absent | — | §4.3, §12.4, §13.3 (`heavy`) |
| **Link arc / return elbow** | ribbon adjacency · sheet row wrap · ECHO rail · contextual counterexample join · Profile *Retention* sigil | normal · dropped (verdict sort) | arc vs elbow | §4.1, §6.2, §11.11 |
| **Cancel hatch** | unlit ramp cell (diagonal) · inert ramp (hairline slash) · ECHO eliminated pool member | 1.0 pt normal · 2.0 pt High Contrast | diagonal vs slash | §4.2, §4.3, §8.4, §13.11 |
| **Tick row** | par row · Codex `bestProbes` strip · Inscription · ECHO cast ticks · SIEVE foul ticks · Anomaly tally · Profile *Tempo* sigil | filled · unfilled · past-par | length-proportional (`pitch = min(9, width/N)`) vs fixed-count | §6.2, §8.4, §9.2, §11.1 |
| **Arc meter** | shelf fill arc · mode-key suspended arc · Anomaly 24-segment rollover · streak ring · SIEVE stream progress | empty · partial · full · static-locked (`.clockBehind`) | continuous vs 24-segment; linear vs log-scaled fill | §9.2, §11.2, §11.8, §12.4 |
| **Mode sigil** ×4 | rack key 168×108 · instrument bar · Codex strip · facet stamp | idle · barred · suspended (arc to `probesUsed/par`) · lit | PROBE / DRIFT / ECHO / SIEVE | §12.4 |
| **Family sigil** ×8 + skeleton silhouettes | shelf plate 44 pt · shelf instrument bar · shelf dividers 24 pt | — | 8 families; 10–40 skeletons per shelf | §11.2 — **undrawn** |
| ***B. Instruments*** | | | | |
| **Ramp** *(the atom of both UIs)* | Dial 70×48 · Bench Ramp tile 56×44 · Fork gate dock · Fork then dock · Fork else dock · Tally rank ramp · *(depictive: facet stamp, Profile* Induction *sigil)* | cell: lit / unlit (25 % + hatch; HC 40 % + 2 pt) / dim (else track) / disabled · ramp: inert (30 % + slash) / pulsing (barred) / read-only | select-mode: single · multi · exactly-one · rank-4 — scale: 1.0 live / 0.78 Codex / ≤ 1.35 AX — device: SE / Pro Max | §4.1, §4.2, §13.11 |
| **Attribute header** | leading 44 pt of every ramp · inside an empty Bridge socket (as a picker) · Tally column · facet stamp | bound · unbound · counted / uncounted (min 3) · selected | 4 attributes | §4.1, §4.2 |
| **Rule-tile** *(abstract base)* | Bench rails · Codex page 0.78× · Inscription reveal | live · read-only · revealing (staggered) · **burnished** (brass stroke) · cleared · empty rail (dashed + 1.6 s pulse) | Ramp / Bridge / Fork / Tally | §4.2, §11.1, §13.7.1 |
| **Bridge** | Bench rail · Codex page · reveal | socket empty / bound · ghost on / off | leading socket is always `cur` (RNF rule 3) | §4.2 |
| **Wedge** | Bridge tile | 6 comparators, pictorial, never ASCII | `eq neq lt lte gt gte` | §4.2, §13.10 |
| **Fork** | whole Bench · Codex page | gate exactly-one · then lit · else dim | attribute of the gate | §4.2 |
| **Tally** | whole Bench · Codex page | attr toggles (≥ 3) · rank ramp · counter dial 5-stop | count mode ↔ parity mode (dial collapses to 2) | §4.2 |
| **Coupler** | between the two rails · Codex page · reveal | AND welded bar (`heavy` 4 pt) · OR forked · XOR crossed · read-only · absent (Fork/Tally) | 3 | §4.2, §13.3 |
| **Assay grid** | Bench column 4 pt (64²) · inspector 23 pt · Codex page 9.5 pt (152²) · Codex thumbnail 3.5 pt (60²) · shelf-plate recents 40 pt · ECHO pool 40 pt | live-morphing · all-dark (unsat) · all-lit (taut) · evidence overlay (band ≥ 4) · read-only | pinned-`prev` slice vs marginal projection (4 ink levels) · overlays: fracture notch, anomaly rim, dashed empty slot · **never bloomed** | §4.3, §11.1, §11.2, §13.5 |
| **Seal** | Bench commit bar · ECHO commit bar | ready · barred · depressed 2 pt · marks striking (1–3) | PROBE/DRIFT vs ECHO | §4.2, §4.3, §13.7.1 |
| **Throat** | PROBE/DRIFT/ECHO live · Frame idle Loom (scenery, 8 s crossfade) · play-key sigil 44 pt | live · animating · empty · idle | 96 (SE) / 128 (Pro Max, Frame) / 44 (key) | §4.1, §6.2, §12.4 |
| **Ribbon** (tile · arcs · spool cap) | PROBE/DRIFT · ECHO rail (placeable) · ECHO cast (dark) · SIEVE tail (6 × 36) · spool sheet 7×10 | admitted · rejected · seed · twin · loaded · placed · pinned-to-trailing | 1 lane (SE) / 2 lanes + elbow (Pro Max) · chain order vs verdict sort | §4.1, §6.2, §8.4, §9.2 |
| **Gate band** | SIEVE only, 375 × 88 | idle · actionable glyph present · tapped · paused | — | §9.2 |
| ***C. Chrome · D. Meta*** | | | | |
| **Key** *(generic button)* | commit bars 44 · mode rack 168×108 · shelf 168×52 · palette stamp 68×44 (AX 165×56) · facet 44 · play / Settings / Anomaly 44 | idle · pressed · selected · **barred** · disabled · suspended | 6 sizes; hairline 1 pt border, 2 pt radius | §4.1, §11.2, §12.4 |
| **Instrument bar** | every screen, y 20–64 | with / without play key | 3 slots: leading sigil · centre indicator · trailing key | §4.1, §6.2, §9.2, §12.4 |
| **Rule / section boundary** | everywhere | — | rule = 0.5 pt hairline inset 16; boundary = rule + 24 above / 16 below | §13.3 |
| **Scrim** | Bench (0.6 α blur → 0.85 α flat) · SIEVE pause (70 %) | — | 2 | §12.2, §13.11 |
| **Numeral readout** | 7 named sites; never the play surface, never the portrait | — | mono, `monospacedDigit`, always | §13.4, §11.12 |
| **Stock `Form` / `List` / `Alert`** | Settings (19 rows) · Statistics (19) · About · ResetConfirmAlert (5 variants) | system | **the only stock components in the app** | §11.12, §12.2, §12.6 |
| **Shelf plate** | CodexRootView ×8, 64 pt | empty (one dashed plate) · accretion · sealable · sealed (doubled rim) | linear arc (\|H\| ≤ 512) vs log-scaled arc with notches | §11.2, §11.4 |
| **Extension thumbnail** | shelf grid 60² · shelf plate recents 40² · ECHO pool 40² | held · empty slot (dashed) · faceted-out | stateless vs contextual projection (hollow/dotted/striped/solid) · fracture notch · anomaly rim | §11.2 |
| **Profile contour** | ProfileView only (P6: never at round end) | unformed (day 1) · trembling (∝ 1 − n/24) · morphing (2.4 s) · settled · HC · Reduce Motion (dash gap ∝ A) | + 5 spokes @ 12 % · ghost @ 12 % dashed · 5 vertex sigils · stat block | §11.10, §11.11 |
| **Codex page composite** | CodexPageView · Inscription | live-inscribing · settled · burnished · fractured | rule-tiles 0.78× + Assay + instrument strip + find log | §11.1 |

---

## 4. The token architecture

### 4.1 Layers

Three value layers, plus one orthogonal axis that is **not** a layer — the part most systems get wrong and this product cannot avoid.

- **L0 `Prim`** — literals, no meaning, never referenced from a view: raw sRGB triples, pt scalars, ms, ratios. The
  Okabe–Ito four live here and are used verbatim by L1 in every theme (§13.2 forbids re-lighting), the one legitimate
  case of a primitive crossing themes unchanged.
- **L1 `Theme` / `Weight` / `Space` / `Type` / `Motion`** — §13.2/13.3/13.4/13.7 exactly as written: `ground.raised`,
  `stroke.primary`, `accent.brass`, `hue.teal`, `hairline`…`heavy`, the 9-step space scale, 7 type roles, 8 beat durations.
- **L2 `C.<component>`** — one namespace per row of §3, where §2(a)'s scattered literals go and stop being scattered:
  `C.ramp.cellUnlitOpacity`, `C.assay.cellSize(.benchColumn)`, `C.codexPage.tileScale`. L2 references L1 only, never L0.
- **`RenderEnv` (an axis, not a layer)** — `(theme, reduceMotion, reduceTransparency, boldText,
  differentiateWithoutColor, lowPowerMode, typeMultiplier)`. Every L1 and L2 accessor is a *function* of this record,
  because Hunch's tokens are not constants: High Contrast rewrites hues to `stroke.primary`, Bold Text scales weights,
  Reduce Transparency kills bloom, Dynamic Type scales art to a 1.35× ceiling. Any scheme modelling variation only as
  "modes" loses four of those seven.

**Naming, one rule, fixing §2(h):** `layer.category.name[.state]`, lowerCamelCase segments, dot-separated, as nested
caseless Swift enums. `ground.raised` and `stroke.hairline` survive as written; `bodySm` → `weight.bodySm`; `display` →
`type.display`. No abbreviations beyond those §2's locked-terminology table blesses.

### 4.2 Worked example — one colour

```swift
// L0  Prim.brass400 = #C9922F · brass600 = #8A5E14 · brass200 = #FFC24D      (never referenced from a view)
// L1  accent.brass = { dark: brass400, light: brass600, highContrast: brass200 }, register .accent
// L2  C.seal.markInk · C.reveal.sweepInk · C.codexPage.burnishedStroke  ->  accent.brass
// HunchCore/Tokens — platform-free, no SwiftUI import, exercised by `swift test`
struct AccentColor { let rgb: RGB8 }   // distinct types: accent cannot reach a glyph,
struct HueColor    { let rgb: RGB8 }   // hue cannot reach chrome
extension Theme { var accentBrass: AccentColor { switch env.theme {
    case .dark: .init(Prim.brass400); case .light: .init(Prim.brass600); case .highContrast: .init(Prim.brass200) } } }
// App target — a ~30-line adapter, the only file that knows SwiftUI exists
extension AccentColor { var color: Color { Color(.sRGB, red: r, green: g, blue: b) } }
// call site
ctx.stroke(mark, with: .color(t.C.seal.markInk), lineWidth: t.C.seal.markWeight)
```

**Register segregation becomes a compile error, not a review rule.** §13.2 states it as a hard rule enforced by a
reviewer. Making `AccentColor` and `HueColor` *distinct types*, and giving `GlyphRenderer.draw` a `HueColor` parameter,
makes "`accent.*` never touches a glyph body" unrepresentable. Highest return in this document; it costs two structs.

### 4.3 Worked example — one dimension, and the §2(d) fix

```
L0  Prim.Pt.p3_0 = 3.0
L1  weight.body = Weight(base: 3.0, respondsToBoldText: true)      // metadata lives ON the token
L2  C.glyph.bodyStroke(S) = S < 48 ? weight.bodySm : weight.body   // the size regime is a RULE, not a token
    resolved = base × (env.boldText && token.respondsToBoldText ? 1.25 : 1) + (env.highContrast ? 0.5 : 0)
```

**Decision: multiply first, add the High Contrast delta last** — `3.0 → 3.75 → 4.25`. §13.11 gives Bold Text a
multiplicative spelling that must hold for `hairline` (0.5 → 0.625), and a flat +0.5 that also got multiplied would
silently become +0.625. `respondsToBoldText` is a property *of the token*: §13.11 scopes Bold Text to glyph and rule-tile
strokes while High Contrast applies to all, so eligibility must travel with the value, not the call site.

### 4.4 Pipeline or no pipeline — the honest answer

**No pipeline. Three hand-written Swift files in `HunchCore/Tokens`, ~250 lines, plus four tests.**
1. **One consumer, one author.** A pipeline's whole value proposition is distribution — Swift *and* Kotlin *and* CSS, or
   designer *and* engineer. §14.4 rules out every other platform; there is no Figma file and no designer. The transform
   would run once, for one target, emitting a file you can type in an afternoon.
2. **The stated #1 delivery risk (§14.6 risk 7) is not finishing.** Style Dictionary v5 means Node, npm, a lockfile, a
   staleness check and a second build phase in a project whose non-negotiables are "zero SPM packages, zero CocoaPods".
   A dev-only dependency is still a dependency you maintain.
3. **Half of §13 has no DTCG type at all.** The 2025.10 stable spec covers color, dimension, duration, cubicBezier,
   number, fontFamily/fontWeight, strokeStyle, border, transition, shadow, gradient, typography — nothing for an 8-beat
   animation *sequence*, a 15-row audio cue table, an 11-pattern haptic table, or glyph geometry. JSON as source of truth
   splits §13 into "the tokens" and "the other half" — worse than one Swift module holding all of it.
4. **The hand-written file is strictly more testable than a generated one.** Values as platform-free types in `HunchCore`
   let `swift test` — the < 10 s loop the build prompt demands — assert every §13.2 contrast ratio, the HC 9.7 : 1 floor,
   the 21 : 1 primary pair, the modifier composition and the space scale, with no simulator. Style Dictionary emits
   constants; it does not check that `#C9922F` on `#0B0A08` really is 7.2 : 1.
5. **Drift is prevented by a grep, not a generator.** The no-network build phase already exists; extend it to fail on
   `#[0-9A-Fa-f]{6}`, `Color(red:`, `.opacity(<literal>)` and `lineWidth: <literal>` outside `Tokens/`. Ten lines of
   shell, zero dependencies, enforcing "no literal hex in view code" mechanically rather than by vigilance.

**Adopt DTCG's vocabulary, not its file format** — name the Swift categories after its `$type` values and keep L0/L1
leaves flat and value-only (no computed properties, at most one alias hop), so a future export to `.tokens.json` is
mechanical rather than archaeological. **Trip-wire for revisiting:** a second consumer appears (marketing site, Android,
a real Figma library) or a designer joins; then export *from* Swift *to* DTCG, never the reverse.

**Two things worth more than any pipeline.** A DEBUG-only **snapshot gallery**: one scrolling screen drawing every
component in §3 × every state × 3 themes × {normal, Bold Text, Reduce Motion}, plus the same in greyscale. It is the
direct fix for §2(c), it determines §13.5.1's missing `T`, it is the visual-regression corpus, and it is half a day in
phase 3. And pin the colour space (`Color(.sRGB, …)`): §13.2's ratios are sRGB relative luminance; a Display P3
constructor moves all of them.

---

## 5. What this product does not need

| Not needed | Why |
|---|---|
| Figma library, design-tool round-trip, token plugins | No designer, one author. Figma's value is the design→code gap; there is no gap. |
| Style Dictionary / Terrazzo / Node in the repo | §4.4. One consumer, a zero-dependency mandate, and a generated file you can hand-write. |
| DTCG JSON as source of truth | Half of §13 has no DTCG type. Keep the vocabulary, skip the file. |
| Multi-brand / white-label theming, a theme builder | The three themes are *accessibility modes*, not brands; §12.6 exposes four values. |
| A component *library* with a props API, Storybook, a doc site | 16 of 18 screens draw into a `Canvas`. §3's inventory plus the snapshot gallery replaces it. |
| Responsive breakpoints | Portrait-only, two device widths; iPad, landscape, macOS, visionOS, watchOS all out of scope (§14.4). Two layout constants, not a system. |
| An icon system, an icon font, SF Symbols in play | §13.1 forbids SF Symbols on the play surface; the build prompt forbids image assets. The sigils *are* the icon set — a drawing problem (§2e), not a distribution problem. |
| Elevation / shadow / material scale | §13.1: luminance is the only depth cue; shadows and `.ultraThinMaterial` are PR-rejection offences. The usual 5–6 elevation tokens collapse to one line: *this category does not exist.* |
| Hover, focus-ring, pointer and keyboard-focus state layers | Touch only; external keyboard and controller support are out of scope. The real state set is six: idle / pressed / selected / inert / barred / read-only. |
| Semantic status colours (success / warning / error / info) | §4.3 abolishes the error state outright — no error text, no error state, no modal, just a machined bar. `accent.brass` / `accent.cold` are **verdicts**, not statuses; merging the registers would be a category error and a §13.2 violation. |
| Content/voice tokens, a copy system; versioning, semver, migration guides, deprecation policy, governance, adoption metrics | 94 visible strings — the String Catalog plus §1.12/§1.13 plus P8's banned-lexeme test *is* the copy system. And: one repo, one binary, one engineer, no downstream consumers to migrate; `DECISIONS.md` is the changelog. |
