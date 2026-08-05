# counterexample.md — the glyph your law and the Loom read differently

Contents: [1 Geometry](#1-geometry) · [2 States](#2-states) ·
[3 The two rings](#3-the-two-rings-are-the-whole-point) · [4 SwiftUI](#4-swiftui) ·
[5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `CounterexampleView` in `Modules/Sources/LoomFeature/CounterexampleView.swift`.
**L2:** `C.Counterexample`. Canon: §6.8's first-strike sheet, §4.5 (selection), §11.3.

Everything it is made of is already owned elsewhere, which is exactly why this file exists — a
composite with no owner gets improvised, and this one is drawn once per round at most:

| Part | Owner |
|---|---|
| the glyph itself | `hunch-glyph-renderer` — it is a shipped site at `C.Counterexample.side` |
| the two concentric rings | `hunch-shared-marks/references/verdict-ring.md`, variant `.counterexample(loomAdmits:)` |
| the ghost frame on the leading glyph, contextual bands | `hunch-shared-marks/references/ghost-frame.md` |
| the join between the two glyphs, contextual bands | `hunch-shared-marks/references/link-arc.md`, `.arc` |
| every beat and its cue | `hunch-motion-and-feedback/references/reveal-beats.md` §5 |
| the "Counterexample" rotor and the announcement | `hunch-accessibility` |
| which glyph is chosen | `HunchCore` — §4.5, pure and tested |

This file owns the **geometry, the phase's states and the dock**, and nothing else.

---

## 1. Geometry

```swift
extension C.Counterexample {
    /// It travels to centre at this size — the same 96 pt the SE throat uses, and the
    /// reason this is a glyph-renderer shipped site with its own bleed check.
    public static let side = 96.0
    /// Contextual bands draw **two** glyphs joined by the link arc.
    public static let pairSpacing = Space.s24
    /// The docked island's outline is doubled — two strokes, not one heavy one, so it
    /// reads as *outside the transcript* rather than as an emphasised tile.
    public static let dockedOutlineCount = 2
    public static let dockedSide = 44.0
    /// The Bench dims behind it while it is on screen (§6.8).
    public static let benchDimInk = 0.30
}
```

The travel is Assay cell → screen centre → below the ribbon's trailing end. Three positions, and the
third one persists:

| Phase | Where | Size |
|---|---|---|
| rises | its own cell in the live Assay | the Assay's cell side, `C.Assay.cellSide(_:)` |
| presented | screen centre, over a Bench at `C.Counterexample.benchDimInk` | `C.Counterexample.side` |
| docked | **below** the ribbon's trailing end, as a marginal island | `C.Counterexample.dockedSide` |

**Below the ribbon, not in it.** The island sits outside the transcript's own row and keeps its
doubled outline for the rest of the round. That geometry is the argument: it is evidence, it is not a
probe, and the picture has to say so without a caption.

In contextual bands the presentation is **two** glyphs joined by the link arc, the leading one
wearing the ghost frame — the same pair idiom the ribbon uses for a contextual probe, so nothing new
has to be learned at the worst possible moment.

---

## 2. States

The phase is `RoundPhase.counterexample` (`HunchCore`), input locked, **first strike only**. Four
states in one pass, and it never runs twice in a round:

| State | When | Drawing |
|---|---|---|
| **rising** | the strike beat has fired | the glyph leaves its Assay cell; the Bench dims behind it |
| **ringed** | both verdicts are on screen | two concentric rings — see §3 |
| **docking** | the presentation is over | it travels to the margin below the ribbon and shrinks |
| **island** | the rest of the round | docked, doubled outline, non-interactive except to VoiceOver |

**It is not a probe, and four things follow.** It does not increment `probesUsed`, it does not become
`prev`, it draws **no link arc into the chain**, and it is never eligible as the nearest-glyph
reference for a later selection. All four are `HunchCore`'s to enforce; a view that draws a chain arc
from it has contradicted the model rather than decorated it.

The Bench **auto-collapses to the Dial** as the dock completes. The round continues — this is a
counterexample presentation, not a reveal, and modelling it as a `RevealPhase` is the mistake
`hunch-motion-and-feedback/references/reveal-beats.md` §5 calls out.

---

## 3. The two rings are the whole point

Inner ring = **your declaration's** verdict. Outer ring = **the Loom's**. §4.5 guarantees they
disagree, which is why `VerdictRing`'s variant takes one `Bool` and not two verdicts: a same-verdict
counterexample is not a thing, and making it representable would be the first step to drawing one.

The contradiction is legible **with no colour at all** — the rings use the same open/closed aperture
idiom as every probe verdict, so one expands and stays closed while the other contracts and breaks.
Under Differentiate Without Colour they additionally take distinct dash patterns, solid for the Loom
and dashed for yours; that pattern is `hunch-shared-marks`' and is **always on**, not gated on the
setting.

Do not add a third cue, a label, a legend or a colour pair. Three redundant encodings already carry
it (geometry, tone, haptic) and a fourth that is *only* colour is a regression.

---

## 4. SwiftUI

```swift
// Modules/Sources/LoomFeature/CounterexampleView.swift
import HunchCore
import SwiftUI

@MainActor
struct CounterexampleView: View {
    enum Stage: Hashable, Sendable { case rising, ringed, docking, island }

    let env: RenderEnv
    let counterexample: Counterexample     // HunchCore — §4.5's choice, already made
    let stage: Stage
    let namespace: Namespace.ID

    private var side: Double {
        stage == .island ? C.Counterexample.dockedSide : C.Counterexample.side
    }

    var body: some View {
        ZStack {
            HStack(spacing: C.Counterexample.pairSpacing) {
                if let context = counterexample.context {
                    GlyphCanvas(env: env, glyph: context, side: side, changedRegister: nil)
                }
                GlyphCanvas(env: env, glyph: counterexample.glyph, side: side, changedRegister: nil)
            }
            // Every shared mark is a `draw(into:)` function, never a `View`
            // (`hunch-shared-marks/SKILL.md`). One `Canvas` carries all three.
            Canvas { context, size in
                let bodyRadius = C.Glyph.radius(side: side)
                let trailing = CGPoint(x: size.width - side / 2, y: size.height / 2)

                if counterexample.context != nil {
                    let leading = CGPoint(x: side / 2, y: size.height / 2)
                    GhostFrame.draw(
                        into: context,
                        box: CGRect(x: 0, y: (size.height - side) / 2, width: side, height: side),
                        env: env
                    )
                    LinkArc.draw(into: context, from: leading, to: trailing, kind: .arc, env: env)
                }
                VerdictRing.draw(
                    into: context,
                    centre: trailing,
                    bodyRadius: bodyRadius,
                    state: .counterexample(loomAdmits: counterexample.loomAdmits),
                    role: .settled,
                    env: env
                )
                if stage == .island {
                    DoubledOutline.draw(into: context, box: CGRect(origin: .zero, size: size), env: env)
                }
            }
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Loc.counterexample)
        .accessibilityValue(Loc.counterexampleReading(counterexample))
        .accessibilityIdentifier(LoomAnchor.counterexample.rawValue)
    }
}
```

`stage` is driven by the round's phase, never by an animation completing — the strike, the selection
and the score were all committed before the first frame (`hunch-motion-and-feedback`'s standing rule).
`Counterexample` is a `Sendable` struct in `HunchCore` carrying the glyph, the optional context glyph,
`loomAdmits`, and the id of the nearest ribbon probe it was chosen against.

**`DoubledOutline` is this file's own mark and its only one**, because nothing else in the app draws
one — it lives beside `CounterexampleView` as a `draw(into:)` function in the same single-entry shape
the shared marks use, so that if a second site ever needs it there is already one thing to move into
`hunch-shared-marks`:

```swift
enum DoubledOutline {
    /// Two concentric strokes at `env.weight(.thin)`, `C.Counterexample.dockedOutlineCount`
    /// of them, gapped by the resolved weight. Never one heavy stroke: at
    /// `weight.heavy` a single line reads as a machined bar, which means *barred*.
    static func draw(into context: GraphicsContext, box: CGRect, env: RenderEnv) {
        let weight = env.weight(.thin)
        var ctx = context
        for i in 0..<C.Counterexample.dockedOutlineCount {
            let inset = weight / 2 + Double(i) * weight * 2
            ctx.stroke(
                Path(box.insetBy(dx: inset, dy: inset)),
                with: .color(env.palette.stroke.secondary.color),
                style: StrokeStyle(lineWidth: weight)
            )
        }
    }
}
```

---

## 5. VoiceOver

One element, not three — the pair plus its rings is a single reading, and splitting it would make the
contradiction something the user has to assemble from two focus stops.

| Traits | Label | Value |
|---|---|---|
| `.image` | `"Counterexample"` | the glyph label, then **both readings**: *"Your law rejects it; the Loom admits it."* |

- The announcement is `hunch-accessibility/references/voiceover-elements.md`'s first-strike row, in
  the fixed order **verdict → evidence → bookkeeping**. This file owns *that it is announced once, on
  the dock*, not the wording.
- The **"Counterexample" rotor** exists only after the first strike and has exactly two stops: this
  glyph, then the nearest ribbon tile it was chosen against —
  `hunch-accessibility/references/rotors-and-gestures.md`. §13.12 gate 6 asserts the rotor is absent
  before the strike, so an always-present rotor with an empty body fails the gate.
- The docked island stays focusable for the rest of the round. It is the only evidence on screen the
  player did not create, and hiding it once it is small would delete it for exactly the users who
  cannot see it is still there.

---

## 6. Reduce Motion

The rise, the travel and the dock are three translations, and §13.12 gate 9 forbids translation
anywhere. **All three become crossfades between the same three positions** — the glyph appears at
centre, then appears docked; it never slides. The rows and their durations are
`hunch-motion-and-feedback/references/reduce-motion.md` §2's; no duration is restated here.

What must survive the substitution, because it is information rather than motion:

- **Both rings, at both radii.** The contradiction is the whole event.
- **The doubled outline on the island**, so its status is still readable at the end of the round.
- **The pair and its link arc** in contextual bands. Collapsing to one glyph deletes the context that
  makes the counterexample a counterexample.

---

## 7. High Contrast

- All four `hue.*` collapse to `stroke.primary`, so the two glyphs of a contextual pair become
  distinguishable by silhouette, fill and pips only — which they already are, because the pair always
  differs in at least one non-hue register (§4.5's Hamming rule).
- The rings keep `accent.brass` / `accent.cold`; High Contrast collapses `hue.*`, never `accent.*`.
- Bloom and the shader are off, so the dimmed Bench behind the presentation is a flat
  `C.Counterexample.benchDimInk` step rather than a defocus.
- The doubled outline widens with `env.weight(_:)` like every other stroke, and it must stay two
  strokes: at `weight.heavy + 0.5` a single line reads as a machined bar, which means *barred*.

---

## 8. Wrong

- **Improvising it.** It is drawn at most once per round and it is the only place two verdicts appear
  on one glyph; if it is not read out of this file it will be re-derived differently every time.
- **Letting it become `prev`, increment `probesUsed`, or draw a link arc into the chain.** It is
  evidence, not a probe (§4.5).
- **Docking it *in* the ribbon.** Below the trailing end, as a marginal island. Inside the row it
  reads as a probe the player made.
- **A single outline on the island, or a heavier one instead of a doubled one.** Doubled means
  *outside the transcript*; heavy means *barred*.
- **Two `Verdict` parameters on the ring instead of one `Bool`.** It makes an agreeing counterexample
  representable, and §4.5 guarantees there is no such thing.
- **Selecting it in the view.** §4.5 is pure, tested and lives in `HunchCore`: restrict to
  disagreements, prefer false negatives, minimise Hamming distance to the nearest ribbon glyph,
  tie-break on lowest `glyphID`.
- **Modelling the phase as a `RevealPhase`.** The round continues; there is no reveal.
- **Revealing the law.** The counterexample is the entire disclosure. §4.5: *"the law is never
  revealed."*
- **Any text on it.** It sits on the play surface; `PlaySurfaceTextTests` fails the build.
- **Showing it on the second strike.** First strike only — the second ends the round, and the lost
  reveal is the sheet that runs.
