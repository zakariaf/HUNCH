# bridge.md — two sockets, a wedge, and the whole contextual grammar in one toggle

Contents: [1 Geometry](#1-geometry) · [2 The asymmetry rule](#2-the-asymmetry-rule) ·
[3 States](#3-states) · [4 SwiftUI](#4-swiftui) · [5 VoiceOver](#5-voiceover) ·
[6 Reduce Motion](#6-reduce-motion) · [7 High Contrast](#7-high-contrast) · [8 Wrong](#8-wrong)

**Owner:** `BridgeView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`. **L2:** `C.Bridge`.
The comparator: `wedge.md`. The frame and its six states: `rule-tile.md`. The socket picker:
`attribute-header.md` §5. The dashed hollow frame and backward chevron:
`hunch-shared-marks/references/ghost-frame.md` — the Bridge calls it and never redraws it.

---

## 1. Geometry

A Bridge occupies one rail. Three parts on one baseline, leading → trailing:

```
┌ rule-tile frame ────────────────────────────────────────────────┐
│  [ leading socket 88×44 ]   [ wedge 44×44 ]   [ trailing socket │
│         cur, no toggle                          88×44 + ghost ] │
└─────────────────────────────────────────────────────────────────┘
```

| Part | Size | Note |
|---|---|---|
| socket | 88 × 44 | 44 pt for the bound attribute header + 44 pt of socket well; the well is what a ghost frame can wrap |
| wedge | 44 × 44 | `wedge.md`; a tap cycles the comparator |
| ghost toggle | 44 × 44 hit rect, 24 pt drawing | **trailing socket only**; the chevron draws at 24 pt inside a 44 pt target, matching §12.8's chevron rule |
| gutter | `Space.s8` between parts | inter-target, so the 8 pt floor applies |

`88 + 8 + 44 + 8 + 88 = 236` inside the 291 pt rail (§4.2), leaving the ghost toggle and the tile's
own padding inside `Space.s16` of slack. Widths multiply by `env.artScale`; above AX2 the Bench is a
single-rail pager and the Bridge gets the full 343 pt column (§13.11).

```swift
extension C.Bridge {
    public static let socket = C.Size(width: 88, height: 44)
    public static let wedgeBox = C.Size(width: 44, height: 44)
    public static let ghostToggleGlyph = 24.0        // inside a 44 pt hit rect
    public static let partGutter = Space.s8
}
```

---

## 2. The asymmetry rule

**The leading socket is always `cur` and carries no ghost toggle.** This is RNF rule 3 made physical
(§3.4, §4.2), and it costs nothing: every one of the 96 contextual forms is
`RANK a(cur) ⋈ PREV RANK b`, so all 96 are reachable as *leading attribute × trailing attribute ×
wedge* = 4 × 4 × 6, exhaustively (§4.4). A player who wants the converse reading flips the wedge.

Putting the toggle on the leading socket would make the only expressible contextual family the
transposed one, and the tile would render a law RNF forbids — a draft the backward fuzzer over
200,000 Bench configurations is written to catch (§4.4). The asymmetry is not a simplification; it
is the grammar's own orientation.

The ghost toggle is **the entire contextual grammar**, and its symbol was introduced diegetically:
the dashed hollow frame and backward chevron are the same drawing the seed glyph wears at probe 0,
the same one the trailing-most ribbon tile always carries, and the same one the split doubled ring
sits under (§6.6, layers 1, 2, 4, 6). Symbol identity does the naming that words are forbidden from
doing — so drawing a *different* ghost mark here silently costs the game its only wordless
explanation of contextuality.

---

## 3. States

| Part | States |
|---|---|
| socket | **empty** · **bound** (an attribute header inside it) · **picking** (the four headers shown, one tap away) |
| ghost toggle | **on** (`prev`) · **off** (`cur`) · **absent** (leading socket) |
| wedge | six comparators — `wedge.md` §2 |
| tile | the six of `rule-tile.md` §3 |

**Picking.** Tap an empty socket → the four attribute headers appear *inside it* → tap one (§4.2).
The picker is not a menu, a popover or a sheet: it is four 44 × 44 headers laid out in the socket's
own well, which is why the socket is 88 pt wide and why the picker needs no new chrome. On AX2+ the
picker wraps to 2 × 2 inside the widened socket.

**Ghost on.** The trailing socket gains the dashed hollow frame and the backward chevron, and its
bound header now reads `prev` rather than `cur`. Nothing else in the tile changes — the comparator
and the leading socket are untouched — because the toggle changes *which glyph* the trailing rank is
read from, not what the comparison is.

A Bridge with an unbound socket is one of the reasons the Seal is barred (§4.3). The predicate is
core (`SealBar`), not a view test.

---

## 4. SwiftUI

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

struct BridgeView: View {
    let env: RenderEnv
    let bridge: RuleTile.Bridge          // HunchCore: leading, trailing, comparator, isGhosted
    let isReadOnly: Bool
    let onBind: (BridgeSocket, Glyph.Attribute) -> Void
    let onCycleComparator: () -> Void
    let onToggleGhost: () -> Void

    var body: some View {
        HStack(spacing: C.Bridge.partGutter) {
            SocketView(
                env: env, socket: .leading, bound: bridge.leading,
                isGhosted: false, isReadOnly: isReadOnly,
                onBind: { onBind(.leading, $0) })

            Button(action: onCycleComparator) {
                WedgeView(env: env, comparator: bridge.comparator)
            }
            .buttonStyle(.plain)
            .frame(width: C.Bridge.wedgeBox.width, height: C.Bridge.wedgeBox.height)
            .disabled(isReadOnly)
            .accessibilityLabel(Loc.comparatorControl)
            .accessibilityValue(Loc.comparatorName(bridge.comparator))
            .accessibilityAction(named: Loc.cycle, onCycleComparator)

            SocketView(
                env: env, socket: .trailing, bound: bridge.trailing,
                isGhosted: bridge.isGhosted, isReadOnly: isReadOnly,
                onBind: { onBind(.trailing, $0) })
                .overlay(alignment: .topTrailing) {
                    GhostToggle(env: env, isOn: bridge.isGhosted, action: onToggleGhost)
                        .disabled(isReadOnly)
                }
        }
    }
}
```

`SocketView` owns the empty/bound/picking switch and calls `GhostFrame.draw(in:box:env:)` from
`hunch-shared-marks` when `isGhosted`. `BridgeSocket` is a two-case enum in `HunchCore` — a `Bool`
named `isLeading` would let a call site put a toggle on the wrong side, which is the one mistake
this tile cannot survive.

---

## 5. VoiceOver

§13.10, verbatim:

| Element | Traits | Label | Value |
|---|---|---|---|
| socket | `.button` | `"Leading socket"` / `"Trailing socket"` | `"pips, this glyph"` · `"pips, previous glyph"` · `"empty"` |
| ghost toggle | `.button` `.isSelected` | `"Previous glyph"` | `"on"` / `"off"` |
| wedge | `.button` | `"Comparator"` | `"greater than"` — action `"Cycle"` |

- The socket's value **states which glyph it reads**, not just the attribute. That clause is the
  only way a VoiceOver player learns the contextual grammar, since they cannot see the dashed frame.
- The picker's four headers become focusable *inside* the socket when it is tapped (§13.10's
  walkthrough step 3) — they are not a separate screen and must not post `.screenChanged`.
- The Bridge contributes to the Bench container's single narrated sentence via `LawNarrator`; it
  never narrates itself.

---

## 6. Reduce Motion

- The picker appears and disappears with a `Dur.micro` crossfade — never a scale, a slide or a
  spring. Under Reduce Motion the crossfade is already the substitution and nothing changes.
- The ghost toggle switches instantly; the frame crossfades in over `Dur.micro`.
- The wedge cycles with a crossfade between the two comparator drawings, not a rotation — see
  `wedge.md` §6, where the reason is that rotating `lt` gives you `gt` and a rotation would read as
  a *transition between meanings*.

---

## 7. High Contrast

- `weight.thin` frames take the flat `+0.5` pt.
- The **ghost frame's dash** must stay legible at the heavier weight: the dash pattern is expressed
  as a ratio of the socket's perimeter, not as a fixed `[6, 4]`, so a +0.5 pt stroke does not close
  the gaps. `hunch-shared-marks/references/ghost-frame.md` owns that expression.
- No hue is present anywhere in a Bridge, so High Contrast's hue collapse does not touch it.

**Differentiate Without Colour** changes nothing: `cur` versus `prev` is already carried by the
dashed frame and the chevron, two non-colour channels.

---

## 8. Wrong

- **A ghost toggle on the leading socket.** It makes the transposed family the only expressible one
  and renders a law RNF forbids (§3.4, §4.2, §4.4).
- **A new ghost mark.** The dashed hollow frame and backward chevron already mean `prev` at four
  other sites; drawing a second one here destroys the diegetic teaching that §6.6 is built on.
- **A popover, menu or sheet for the socket picker.** The four headers appear *in the socket*.
  Anything else is new chrome on a surface that has none, and it breaks the "no new screen"
  expectation VoiceOver's walkthrough depends on.
- **An ASCII comparator** — `>`, `>=`, `!=`. §4.2 forbids it and §12.9's play-surface text test fails
  the build. See `wedge.md`.
- **A `Bool` for the socket side.** Use the two-case enum; the asymmetry is load-bearing.
- **Deciding "socket unbound → Seal barred" in the view.** `SealBar` is data, in core.
- **Mirroring the wedge's meaning under RTL.** The wedge mirrors *with* its rail so its wide end
  still opens toward the larger socket; the meaning is positional and is therefore preserved by the
  mirror, not inverted by it (§12.8).
- **Letting the trailing socket change the comparator when it is ghosted.** The toggle changes which
  glyph the rank is read from, and nothing else. Coupling them would make 96 forms unreachable.
