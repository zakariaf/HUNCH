# verdict-ring.md — `VerdictRing.draw`

<!-- inventory: Verdict ring | VerdictRing.draw -->

Contents: [1 Geometry](#1-geometry) · [2 States and roles](#2-states-and-roles) ·
[3 The Swift](#3-the-swift) · [4 Environment behaviour](#4-environment-behaviour) ·
[5 The `C.VerdictRing` namespace](#5-the-cverdictring-namespace) · [6 What would be wrong](#6-what-would-be-wrong)

Sites: throat · ribbon tile · counterexample (two concentric) · ECHO primer · SIEVE sump · SIEVE
tail · Codex re-strike rim · Anomaly ribbon cell. Spec: §4.5, §6.5, §13.7.2, §13.11, §11.3, §11.8.

---

## 1. Geometry

**The ring is concentric with the glyph body, not with the glyph box.** In the screen frame the body
centre sits at `(0, −0.10·S)` and the body radius is `R = 0.37·S` (§13.5, with PHOSPHOR §5's
coordinate resolution: the GDD lists positions y-up and angles screen-frame, and the renderer negates
the y values so apex-up, N-at-top and index-below-body all hold at once).

**Do not recompute those two numbers here.** The host asks `hunch-glyph-renderer` for the body centre
and body radius of the glyph it is drawing and passes them in. Two copies of `0.37` is exactly the
divergence this skill exists to stop, and the glyph renderer is the one that owns them.

Radii, all as multiples of `R`:

| Moment | Radius | Weight | Where it comes from |
|---|---|---|---|
| admit, transient start | `1.00·R` | `env.weight(.body)` | §13.7.2 — "expands R → 1.35 R … weight 3 → 1 pt" |
| admit, transient end | `1.35·R` | `env.weight(.thin)` | §13.7.2 |
| **admit, settled** | **`1.18·R`** | `env.weight(.thin)` | §13.7.4 — the Reduce Motion static radius |
| reject, transient start | `1.35·R` | `env.weight(.bodySm)` | §13.7.2 — "contracts 1.35 R → R" |
| **reject, settled** | **`1.00·R`** | `env.weight(.bodySm)` | §13.7.4 — the Reduce Motion static radius |

**The settled radii are §13.7.4's static-substitution radii on purpose.** Under Reduce Motion the
transient ring is replaced by a crossfade of a static ring, and a crossfade must land on the state
the surface will hold. Choosing any other settled radius would make the Reduce Motion substitution
show a ring the sighted-with-motion player never sees.

**The break.** A rejected ring is four arcs. Each arc is **centred on a compass ray** — `−90° N`,
`0° E`, `+90° S`, `180° W` — and spans `90° − gap`, so the four gaps fall on the **inter-cardinals**
(`±45°`, `±135°`). That placement is load-bearing: pips are contour nodes on exactly the compass rays
(§2, §13.5), and a gap on a pip ray would read as a missing pip. Gap = `C.VerdictRing.breakGap`
(14°), doubled under Differentiate Without Colour (§13.7.2's decision, §13.11), with a floor so a
36 pt SIEVE tail ring still reads as broken:

```
gapDegrees = max(14, degrees(3 / ringRadius)) × (env.isDifferentiateWithoutColorEnabled ? 2 : 1)
```

**The separation.** During the break sub-beat each arc translates **outward along its own centre ray**
by up to `C.VerdictRing.breakSeparation` (3 pt) over 90 ms and fades (§13.7.2). Settled separation is
zero. The arcs never rotate — a rotating break reads as a spinner, and nothing in this app spins.

**The cancel slash.** The transient reject ring takes one −45° stroke across it, drawn by
`CancelHatch.draw(variant: .slash)` at `1.06 × ringRadius` each side of centre. It is on the
**transient** ring only. The verdict *event* earns all three non-colour channels — contraction,
break, cancellation; the settled ribbon tile is a log entry where break plus colour is enough, and a
slash across a 44 pt tile would compete with the glyph's own silhouette.

**Caps are `butt`, joins irrelevant** (single arcs). §13.3 puts `round` caps on chrome, but a broken
ring with round caps grows its arcs back into its own gaps by half a stroke width at each of eight
ends — at `bodySm` that is 6 pt of gap eaten, nearly half of a 14° gap at ribbon size.

---

## 2. States and roles

Two orthogonal axes. **Role** says whether the ring persists; **state** says what it means.

| Role | Meaning | Sites |
|---|---|---|
| `.transient` | the verdict event; the host animates `progress` 0 → 1 and the ring fades out | throat, SIEVE sump |
| `.settled` | the ring the surface holds; `progress` is ignored | ribbon tile, ECHO primer, SIEVE tail, counterexample, Codex rim, Anomaly cell |

| State | Drawing |
|---|---|
| `.admit` | one closed ring |
| `.reject` | four arcs, gapped as §1; transient adds the cancel slash |
| `.twin(admitted:)` | the verdict's ring **doubled** — a second concentric ring outside the first, separated by `2 ×` the resolved ring weight — and, when transient, at **0.7 × amplitude** on the radius travel (§13.7.2: "a twin must not read as a fresh discovery"). §4.1's "doubled ring" in the ribbon is this state, settled |
| `.counterexample(loomAdmits:)` | two concentric rings, **outer = the Loom's verdict, solid; inner = your declaration's verdict, dashed** (§4.5, scope §3). One `Bool` determines both, because §4.5 guarantees they disagree — *"Two rings, one glyph, opposite states"*. Passing two verdicts would make a same-verdict counterexample representable, and there is no such thing |
| `.restrike(count:)` | `min(count, 5)` concentric closed rings on the Codex page rim; at `count ≥ 6` **one filled ring** instead, meaning 5+ (§11.3) |
| `.day(Day)` | the Anomaly ribbon's 11 pt cell (§11.8) — see the mapping below |

`Day` mapping, from §11.8's table:

| `Day` | Drawing | `AnomalyOutcome` |
|---|---|---|
| `.clean` | closed ring | `solvedClean` |
| `.fractured` | closed ring + fracture notch (the notch is `hunch-chrome-and-meta`'s; the ring is ours) | `solvedFractured` |
| `.failed` | broken ring + `CancelHatch.draw(variant: .hatch)` | `failed` |
| `.absent` | dashed empty ring | `missed`, `abandoned` |
| `.awaiting` | hairline ring, host-pulsed (static dash under Reduce Motion) | today, unplayed |
| `.locked` | closed ring, filled, never pulsed | `.clockBehind` (§11.7) |

**Two extensions beyond scope §3's row, both deliberate.** The Anomaly cell and the Codex re-strike
rim are rings drawn at 11 pt and on a page rim; leaving them out would mean chrome ships a second ring
implementation, which is the §2(g) bug in a new place. §11.8's word "cross-hatch" for `.failed` is
prose: it draws the **cancel hatch**, one direction at −45°, because a crossed hatch would be a second
hatch angle and a second ink coverage, and coverage is a channel the glyph owns (see `cancel-hatch.md` §2).

---

## 3. The Swift

```swift
import SwiftUI
import Tokens      // RenderEnv, StrokeWeight, C

public enum VerdictRing {
    public enum Role: Hashable, Sendable { case transient, settled }

    public enum Day: Hashable, Sendable { case clean, fractured, failed, absent, awaiting, locked }

    public enum State: Hashable, Sendable {
        case admit
        case reject
        case twin(admitted: Bool)
        case counterexample(loomAdmits: Bool)
        case restrike(count: Int)
        case day(Day)
    }

    /// Draws one verdict ring concentric with a glyph body.
    ///
    /// `centre` and `bodyRadius` come from `GlyphGeometry`; this function never derives them from a
    /// box side, because `0.37 · S` has exactly one home and it is not here.
    ///
    /// `progress` is the host's animation clock, 0 at the verdict frame and 1 at rest. It is ignored
    /// when `role` is `.settled`, which is also what a Reduce Motion host passes (§13.7.4).
    ///
    /// The context is taken by value: clip, opacity and transform are set on a local copy and do not
    /// escape to the caller.
    ///
    /// - Complexity: O(1) — at most six sub-paths.
    public static func draw(
        into context: GraphicsContext,
        centre: CGPoint,
        bodyRadius: CGFloat,
        state: State,
        role: Role = .settled,
        progress: Double = 1,
        env: RenderEnv
    ) {
        var ctx = context
        for ring in rings(for: state, role: role, progress: progress, bodyRadius: bodyRadius, env: env) {
            ctx.opacity = ring.ink
            ctx.stroke(
                arcs(centre: centre, ring: ring, env: env),
                with: .color(ring.accent.rgb.color),
                style: StrokeStyle(lineWidth: ring.weight, lineCap: .butt, dash: ring.dash)
            )
        }
        if case .reject = state, role == .transient {
            let r = bodyRadius * C.CancelHatch.slashOvershoot
            CancelHatch.draw(
                into: context,
                region: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r),
                variant: .slash,
                bounds: .ellipse,
                paint: .verdict,
                env: env
            )
        }
    }
}
```

`rings(for:role:progress:bodyRadius:env:)` and `arcs(centre:ring:env:)` are `private` in the same file,
as is the `Ring` struct they pass between them (`radius`, `weight`, `accent`, `ink`, `dash`). The public
surface is one function; anything that could stroke a ring a second way stays behind `private`.

**No `HunchCore` import, deliberately.** `State` speaks `Bool` and `Day` rather than `Verdict` and
`AnomalyOutcome`, so `Marks/` needs no package dependency edge to draw a ring. The two mappings —
`Verdict → Bool` and `AnomalyOutcome → Day` — are `switch`es owned by one function each in the
respective feature module, which is the same trade `hunch-design-tokens` made when it kept `Tokens`
independent of `Glyphs` and put `Glyph.Hue → HueColor` in `HunchUI/GlyphCanvas.swift`: one switch
against an edge, and the edge is the more expensive of the two.

**Colour.** `env.palette.accent.brass` for admit, `env.palette.accent.cold` for reject — both
`AccentColor`, which is the register the type system already enforces. The ring never accepts a
`HueColor`: `hue.*` is the glyph body, fill, pips and index stroke and nothing else (`palette.md`).
**`accent.brass` and `hue.amber` are far closer in luminance than canon claims** — `hunch-design-tokens`
measured it and put the figure in its gotchas — so a brass ring around an amber glyph is separated by
register and geometry, never by luminance. Do not add a third cue that assumes otherwise, and do not
copy the ratio here.

**Settled ink** is `C.VerdictRing.settledInk` (0.85), the mark's only opacity: the ribbon is a
transcript and must stay quieter than the throat (PHOSPHOR mockup, exhibit 4). At that opacity the
brass ring still clears the 3 : 1 graphical floor on the dark ground with room to spare — check it with
`hunch-design-tokens`' `contrast.swift` if you move `settledInk`, because that is the constraint the
value is up against.

---

## 4. Environment behaviour

**VoiceOver.** No element. The ring's meaning reaches VoiceOver through its host's value: the throat
is `.image .updatesFrequently .adjustable` with "glyph label + last verdict"; a ribbon tile is a
`.button` valued "admitted" / "rejected" / "seed glyph" / "twin"; the counterexample is announced in
the strike utterance — *"Your law rejects it; the Loom admits it"* (§13.10). Announcement order is
fixed: verdict → evidence → bookkeeping. A label on the ring itself would insert a fragment between
"Reject" and the glyph label and break that order.

**Reduce Motion.** The host passes `role: .settled` and crossfades over `dur.reduceMotionRing`
(160 ms) — §13.7.4's admit and reject rows are exactly that, and §1's settled radii were chosen so the
crossfade lands on the held state. The ring itself does nothing differently. It never reads
`isReduceMotionEnabled`.

**High Contrast.** No substitution — `accent.brass` and `accent.cold` have their own High Contrast
entries in `palette.md` §1, and both clear the state-bearing floor. Every weight picks up the flat
`+0.5` through `env.weight(_:)`. Bloom is off, so the transient admit ring loses its widened pass;
nothing else changes.

**Bold Text.** Weights scale ×1.25 through `env.weight(_:)`. The gap is angular and does not scale, so
a Bold Text broken ring closes slightly. The check is `gap_pt = ringRadius × radians(gapDegrees)`
against the resolved stroke width — run it for the smallest site, the SIEVE tail, where it is tightest
and still an unambiguous break. Do not compensate by widening the gap; that would make Bold Text change
what a verdict looks like.

**Differentiate Without Colour.** The gap doubles to 28°. That is the only change (§13.7.2, §13.11).
The counterexample's solid/dashed split is **always on**, not gated on this flag — §13.11's own reason
is that the two contradictory readings must be separable "without either colour or memory", and memory
is what a conditional cue requires.

**Bloom.** The transient admit ring takes pass B — the same stroke at `× 3` weight and `opacity.halo`
— when `env.isBloomEnabled` and the ring radius is at least 32 pt (`render-env.md` §3; the size gate is
geometry and is applied here, as it is in the glyph renderer). Settled rings never bloom: at ribbon
size a widened brass ring deposits ink inside the glyph's own inset interior and moves the measured
`fill` coverage, which is the discriminator the greyscale proof rests on (PHOSPHOR §6.4).

**RTL.** Nothing mirrors. A ring is radially symmetric and its break is on the diagonals; the compass
rays are the pip rays, which are game state (§2: "layout mirrors, glyphs never do").

**Dynamic Type.** The host scales `bodyRadius` by `env.artScale` before calling. The ring never
multiplies by `artScale` itself — that is how a mark gets scaled twice.

---

## 5. The `C.VerdictRing` namespace

Appended to `HunchCore/Sources/Tokens/C.swift`. `hunch-design-tokens` owns the file and the L2 rule;
these members are this skill's, and these are their only home.

| Member | Value | Home of the number |
|---|---|---|
| `settledAdmitRadius` | `1.18` × body radius | §13.7.4, admit row |
| `settledRejectRadius` | `1.00` × body radius | §13.7.4, reject row |
| `transientAdmitRadius` | `1.35` × body radius | §13.7.2 |
| `breakGap` | `14°` | this skill; floored at 3 pt of arc, doubled under Differentiate Without Colour |
| `breakSeparation` | `3.0` pt | §13.7.2 |
| `twinAmplitude` | `0.70` | §13.7.2 |
| `twinRingGap` | `2.0 ×` resolved weight | this skill — the pair must read as one unit at 36 pt |
| `settledInk` | `0.85` | PHOSPHOR mockup, exhibit 4 |
| `restrikeCap` | `5` | §11.3 |
| `counterexampleDash` | `[4, 3]` pt | this skill — distinct from the ghost frame's `[3, 3]`, so a dashed ring never reads as a ghost |

Weights and colours are **not** here: `env.weight(.body)`, `env.weight(.thin)`, `env.weight(.bodySm)`,
`env.palette.accent.brass`, `env.palette.accent.cold`. Durations are not here either:
`Dur.ringAdmit`, `Dur.ringReject`, `Dur.reduceMotionRing`, and the easings `Easing.easeOut` / `Easing.easeIn`
belong to the host and to `hunch-motion-and-feedback`.

---

## 6. What would be wrong

- **Recomputing `0.37 · S` or `−0.10 · S` in this file.** They belong to `hunch-glyph-renderer`; a
  second copy drifts the ring off the body the first time the glyph box changes.
- **Putting the break gaps on the compass rays.** They would sit on the pip nodes and read as missing
  pips — the one collision §2's register-disjointness rule exists to prevent.
- **Round caps on the arcs.** Half a stroke width regrows into each of eight gap ends and closes a
  broken ring at small sizes. Rejection would start looking like admission on the SIEVE tail.
- **A settled radius that is not §13.7.4's.** The Reduce Motion crossfade would land on a ring that
  does not match the held state, and Reduce Motion would become a different design.
- **Encoding the verdict in colour alone, or adding a fourth channel.** Direction and closure are the
  encoding; colour, tone and haptic are three redundant copies (§13.7.2's decision). A fill, a glow
  colour or a size change would be a fourth channel with no non-colour twin.
- **Blooming a settled ring.** It raises measured ink coverage inside the glyph's inset interior and
  compresses the `hollow` → `dotted` step, which is the discriminator §13.5.1's proof rests on.
- **Making the counterexample's dashes conditional on Differentiate Without Colour.** The two rings
  say opposite things; a player who cannot tell which is theirs has to remember, which is what §13.11
  rules out in the same sentence.
- **Drawing the diagonal inline instead of calling `CancelHatch`.** It is the fourth site of the
  cancel hatch and it must share the −45° angle and the pitch arithmetic with the other three.
- **Animating anything inside this function.** The ring has no clock. The host owns `progress`, and
  therefore owns §13.7.4.
- **Giving the ring an accessibility label, trait or action.** §13.10 indexes by host; a ring element
  duplicates the verdict utterance and breaks the fixed announcement order.
- **A `VerdictRingShape: Shape` alongside this function.** Two entry points, two geometries, one year.
- **Writing a hex or a contrast ratio into this file.** `palette.md`'s measured column is the one
  home, and canon's stated ratios are wrong in nine cells — a copy imports the error silently.
