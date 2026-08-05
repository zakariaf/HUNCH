# ribbon.md — the transcript: tiles, arcs, spool cap and sheet

Contents: [1 Geometry](#1-geometry) · [2 The spool sheet](#2-the-spool-sheet) ·
[3 States and the four surfaces](#3-states-and-the-four-surfaces) · [4 SwiftUI](#4-swiftui) ·
[5 VoiceOver](#5-voiceover) · [6 Reduce Motion](#6-reduce-motion) ·
[7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `RibbonCanvas` in `Modules/Sources/HunchUI/RibbonCanvas.swift`, plus `SpoolSheetView`
in `LoomFeature`. **L2:** `C.Ribbon`. The glyph in a tile: `hunch-glyph-renderer`. The verdict
ring, the link arc and the return elbow, the ghost frame:
`hunch-shared-marks` — three owning functions, called here, redrawn never.

---

## 1. Geometry

*"Visible probe log — tiles + link arcs, horizontally scrolling"* (§2). It is the throat's
downstream, and it is one of the three bloom regions (`throat.md` §1).

| Property | SE 375 × 667 | Pro Max 440 × 956 | § |
|---|---|---|---|
| region | y 176–228 | y 306–420 | §6.2 |
| lanes | **1** | **2**, chain wraps with a return elbow | §6.2 |
| tile glyph | 44 pt | 44 pt | §6.2 |
| pitch | 50 pt | 50 pt | §6.2 |
| visible before scroll | 7 whole tiles + a 25 pt peek of the eighth | 16 (8 per lane) | §6.2 |
| spool cap | 24 pt rail-cap at the **leading** edge | the same | §6.2 |

```swift
extension C.Ribbon {
    public static let tileGlyph = 44.0
    public static let pitch = 50.0
    public static let spoolCap = 24.0
    public static let tailGlyph = 36.0          // SIEVE, six of them
    public static let echoRailGlyph = 44.0
    public static let echoSeedGlyph = 36.0
    /// The ribbon re-pins to its trailing edge after every verdict (§6.2).
    public static let trailingInset = 24.0      // the new tile settles 24 pt off the margin
}
```

The pitch is 50 pt for a 44 pt glyph, so 6 pt separates tiles and the **link arc** lives in that gap.
The ribbon is pinned to its trailing edge and **re-pins after every verdict**; scrolling back is a
standard horizontal scroll, so VoiceOver's three-finger swipe works with no custom gesture — which
is the reason it is a `ScrollView` and not a hand-rolled pager.

The ribbon sits above §12.8's y = 220 line and is therefore **read-only in the reach argument**: its
one gesture, ribbon-load, is *"a mitigation, not the route"* (§4.1), and the Dial can always compose
any glyph directly.

---

## 2. The spool sheet

*"Seven tiles is a viewport, not a ledger."* Tapping the spool expands the ribbon to a full-screen
read-only sheet: a **7 × 10 grid of 70 cells** (§6.2).

| | SE | Pro Max |
|---|---|---|
| cell | 45 pt, glyph 40 pt | 51 pt, glyph 46 pt |
| across | `7 × 45 + 6 × 6 + 2 × 12 = 375` | `7 × 51 + 6 × 8 + 2 × 16 = 437` |
| down | `10 × 45 + 9 × 6 = 504`, at y 72–576 | `10 × 51 + 9 × 8 = 582`, at y 114–696 |
| header | y 20–64, spool cap + sort toggle | the same |

**Why 70 and why seven columns.** The sheet is sized against the largest cap in *any* mode, not
PROBE's: `max(cap, cap_DRIFT) + 1 = 65` — the seed glyph plus 64 probes — so 70 clears it with five
cells spare and *the longest possible round in any mode is on one screen with no scrolling*. Seven
columns rather than eight because eight forces a 38 pt cell on SE, below the 44 pt hit floor, and
**every cell is tappable**. Both facts are asserted by the same test that asserts the tick pitch
invariant: `sheetCells >= 1 + max over modes and bands of cap` (§6.2).

Three spool taps, in order: **open · verdict sort · close.**

- **Chain order** (default): leading→trailing, top→bottom, mirrored under RTL, with link arcs and a
  **return elbow at each row end** so adjacency survives the wrap.
- **Verdict sort**: admits block first, rejects second, chain order preserved within each block.
  Link arcs are **dropped**; twin pairs keep their doubled ring. This is §6.6 layer 5 — one tap asks
  *can the same glyph appear on both sides?*, and in a contextual round it does. The interface lets
  the player ask, and the answer is the family.
- Tap any cell to ribbon-load it into the Dial and dismiss.

The sheet costs nothing, consumes no probe, and is available from probe 0.

---

## 3. States and the four surfaces

**Tile states.** Every one carries geometry before colour:

| State | Drawing |
|---|---|
| **admitted** | closed verdict ring |
| **rejected** | broken verdict ring; gap doubles under Differentiate Without Colour |
| **seed** | the dashed hollow frame + backward chevron; the trailing-most tile **always** carries it (§6.6 layer 2) |
| **twin** | a **doubled** ring over one drawing of one glyph; when the two verdicts differ the ring draws **split** — one half open, one half closed (§6.6 layer 4) |
| **loaded** | this tile is the Dial's current source |
| **placed** | ECHO only: this tray glyph has been placed on the rail |
| **pinned-to-trailing** | the layout state after a verdict re-pin |

**Four surfaces, one drawing.** The ribbon is reused, never re-implemented:

| Surface | Geometry | § |
|---|---|---|
| PROBE / DRIFT ribbon | §1 | §4.1, §6.2 |
| **ECHO rail** — placeable | y 172–252, 44 pt tiles + link arcs, horizontal scroll, leading→trailing in every locale | §8.4 |
| **ECHO cast** — dark | the same tiles with no verdict rings | §8.4 |
| **SIEVE tail** — the last 6 resolved | y 560–604, six glyphs at 36 pt with their rings, leading→trailing | §9.2 |

ECHO's tray tile is a **toggle** carrying a placed state, so returning a placed tile is possible
without reaching the rail above y = 220 — which is what makes the whole of ECHO playable inside the
thumb arc (§12.8).

**The DRIFT moment** re-reads the transcript across the hinge, in three parts: pre-swap tiles
desaturate to `stroke.secondary`, an `accent.brass` rule draws downward through the ribbon at the
swap index, post-swap tiles brighten. Its total is `Dur.drift` and it is inserted into the reveal at
a fixed offset (§13.7.2). **The three part durations, the rule's weight and the offset are
`hunch-motion-and-feedback/references/verdict-motion.md`'s** — this file owns only the three *states*
a tile can be in across the hinge.

---

## 4. SwiftUI

Two different accessibility shapes in one component, and getting them the right way round is the
whole trick:

- **tiles are `Button`s** — §13.10 gives each a label, a value and a `"Load into the Dial"` action;
- **arcs, elbows and the tail are one `Canvas`** — they are not targets, they carry no separate
  information, and the tail is exposed as a single container.

```swift
// Modules/Sources/HunchUI/RibbonCanvas.swift
import HunchCore
import SwiftUI

struct RibbonView: View {
    let env: RenderEnv
    let entries: [RibbonEntry]        // HunchCore: glyph, verdict, isTwin, isSeed
    let laneCount: Int                // 1 on SE, 2 on Pro Max
    let onLoad: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: C.Ribbon.pitch - C.Ribbon.tileGlyph) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    Button { onLoad(index) } label: {
                        RibbonTile(env: env, entry: entry)
                    }
                    .buttonStyle(.plain)
                    .frame(width: C.Ribbon.tileGlyph, height: C.Ribbon.tileGlyph)
                    .accessibilityLabel(Loc.glyphLabel(entry.glyph))
                    .accessibilityValue(Loc.ribbonState(entry))
                    .accessibilityAction(named: Loc.loadIntoDial) { onLoad(index) }
                }
            }
            .background {
                Canvas { context, size in
                    LinkArcs.draw(&context, entries: entries, lanes: laneCount, env: env)
                }
                .accessibilityHidden(true)
            }
            .scrollTargetLayout()
        }
        .defaultScrollAnchor(.trailing)          // pinned to trailing; re-pins on append
    }
}
```

`LinkArcs` is `hunch-shared-marks`' owning function for both the arc and the **return elbow**; the
elbow is what keeps adjacency legible when a two-lane Pro Max ribbon or a 7-wide sheet row wraps.
`.accessibilityHidden(true)` on the arc layer is correct: adjacency is already carried by the
traversal order and by the *"Probes"* rotor.

`.defaultScrollAnchor(.trailing)` is what re-pins after a verdict: it holds the trailing anchor when
the content grows, so the append does the work and no imperative `scrollTo` is needed. Under
**Reduce Motion** the append itself must not animate — wrap the model mutation in
`withAnimation(nil)`, or `LazyHStack`'s default insertion transition will slide the tile in and
quietly violate §13.12 gate 9.

---

## 5. VoiceOver

§13.10:

| Element | Traits | Label | Value | Actions |
|---|---|---|---|---|
| ribbon tile | `.button` | the glyph label | `"admitted"` / `"rejected"` / `"seed glyph"` / `"twin"` | `"Load into the Dial"` |
| ECHO rail | container | `"Rail"` | `"2 of 16 placed"` | — |
| ECHO rail tile | `.button` | the glyph label | `"position 2"` | `"Return to the tray"` |
| ECHO tray tile | `.button` `.isSelected` when placed | the glyph label | `"placed, position 2"` / `"not placed"` | — |
| SIEVE tail | container | `"Tail"` | the last 6 resolved glyphs, each label + `"admitted"` / `"rejected"` | — |
| ECHO primer strip / a primer glyph | container / `.staticText` | `"Primer"` / the glyph label | `"3 glyphs"` / `"admitted"` | — |

- The **"Probes"** rotor steps *backward* through the ribbon, newest first, announcing glyph +
  verdict (§13.10). Newest-first is the useful order and it is not the traversal order, which is why
  it needs a rotor at all.
- The pool strip, the primer strip and the tail are **read-only and exempt from the 44 pt hit
  floor** — exempt because they are not targets, exactly as the link arcs are (§8.4). Exposing them
  as grouped static elements with the canonical labelling is what makes the exemption honest.
- A twin whose two verdicts differ is the game's central discovery; the value must say so —
  `"twin, admitted then rejected"` — because the split ring is invisible in audio and §6.6 layer 4 is
  otherwise lost entirely.

---

## 6. Reduce Motion

Five rows of `hunch-motion-and-feedback/references/reduce-motion.md` §2 land on the ribbon — **tile
slide-in** (a crossfade *in place*), **auto-scroll** (an instant `scrollTo`), **reveal beat 1**,
the **DRIFT moment**, and the **admit / reject ring** on the new tile. Read the durations there.

What this file owns is which of them can be lost by accident, and one of them can:

Nothing on the ribbon translates in either mode after the substitution — which is what §13.12 gate 9
checks, and the slide-in is the row most likely to survive a refactor by accident because a
`LazyHStack` insertion animates by default. Wrap the append in `withAnimation(nil)` under Reduce
Motion, or the framework will slide it for you.

---

## 7. High Contrast

- Tiles are 44 pt glyphs, which is **below the `S = 48` regime boundary**, so the body stroke is
  `weight.bodySm` and the index stroke stays at `weight.body` — the hue channel is deliberately the
  heaviest non-colour mark on the glyph (§13.5). Under High Contrast the index stroke also lengthens
  by the ratio `hunch-glyph-renderer/references/geometry.md` owns, which at the ribbon's 44 pt is exactly
  canon's **12 → 18 pt** (§2) — the anchor the whole ratio was derived from.
- All four hues collapse to `stroke.primary`, so at ribbon size the four hues are told apart by a
  90°-separated rotation and nothing else. Any change that shortens the ribbon tile below 44 pt
  attacks that directly.
- Bloom is off entirely, so the ribbon draws no bed layer.
- The verdict ring's weights take the flat `+0.5` pt.

**Differentiate Without Colour**: admit tiles draw a fully closed ring and reject tiles a broken ring
at **2× the normal gap** (§13.11). That doubling is `hunch-shared-marks/references/verdict-ring.md`'s; the
ribbon only passes the flag.

---

## 8. Wrong

- **Drawing tiles into one `Canvas`.** Every tile is a `.button` with a label, a value and a custom
  action; a monolithic canvas takes all three away and kills the *"Probes"* rotor.
- **Re-implementing the ribbon for ECHO's rail, ECHO's cast or SIEVE's tail.** Four surfaces, one
  drawing, different sizes and states.
- **Dropping the return elbow on a wrap.** Adjacency is the ribbon's only structural information;
  without the elbow a two-lane Pro Max ribbon reads as two unrelated rows.
- **Keeping link arcs in verdict sort.** They are dropped — the chain order is no longer the layout
  order, so an arc would assert an adjacency that is not on screen (§6.2).
- **Losing the split doubled ring** for a twin with differing verdicts. It is a rendered
  contradiction and the clearest wordless statement of contextuality in the game (§6.6 layer 4).
- **Sizing the sheet against PROBE's cap.** It is a shared surface; `cap_DRIFT` reaches 64, and the
  invariant is `sheetCells >= 1 + max cap` over *all* modes.
- **Eight columns in the sheet.** 38 pt cells on SE, below the hit floor, and every cell is tappable.
- **Animating the re-pin under Reduce Motion**, or letting `LazyHStack`'s default insertion animation
  survive the substitution.
- **Making the ribbon the route to a glyph.** Ribbon-load is a mitigation; the Dial can always
  compose directly, and that is what keeps a control above y = 220 legal.
