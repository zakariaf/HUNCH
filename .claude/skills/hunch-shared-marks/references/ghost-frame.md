# ghost-frame.md — `GhostFrame.draw`

<!-- inventory: Ghost frame | GhostFrame.draw -->

Contents: [1 Geometry](#1-geometry) · [2 Roles, and why there are no visual states](#2-roles-and-why-there-are-no-visual-states) ·
[3 The Swift](#3-the-swift) · [4 Environment behaviour](#4-environment-behaviour) ·
[5 The `C.GhostFrame` namespace](#5-the-cghostframe-namespace) · [6 What would be wrong](#6-what-would-be-wrong)

Sites: Bridge trailing socket · ribbon `prev` marker · Assay pin thumbnail · ECHO seed glyph ·
DRIFT mode sigil · Bridge palette stamp. Spec: §4.2, §4.3, §8.4, §12.4.

**This mark carries the whole contextual grammar.** §4.2: *"tapping it re-frames that socket as the
previous glyph, drawn with the dashed hollow frame and backward chevron already used to mark `prev`
in the ribbon ten probes earlier. That one toggle is the entire contextual grammar, and its symbol
was introduced diegetically."* The argument only holds if the drawing is byte-identical at every
site. That is this file's entire job.

---

## 1. Geometry

Two parts, drawn into a square box of side `side` (the glyph box the frame is marking).

**The frame.** A rectangle inset by half the resolved stroke weight, so the stroke sits wholly inside
the box and never bleeds into a neighbouring tile or outside a hit rect. **Corner radius 0.** Dashed
`[3, 3]` pt. `env.weight(.thin)` in `stroke.secondary`.

**The backward chevron**, on the leading edge, vertically centred. With `u = max(4, 0.09 · side)`:

```
apex   (u,  mid)
arms   (2u, mid − u)  and  (2u, mid + u)
```

`env.weight(.bodySm)` in `stroke.secondary`, `butt` caps, `miter` join. At `side = 44` that is apex
`(4, 22)` and arms `(8, 18)` / `(8, 26)` — the PHOSPHOR mockup's `ghostFrame(44)` exactly, and it
scales without the mockup's fixed 8 pt chevron disappearing on the 168 pt DRIFT key.

**Why the chevron is one weight heavier than the frame.** A dashed 1 pt rectangle and a 1 pt chevron
read as one broken outline; the chevron has to be the thing that *points*. The mockup draws 1.4 pt;
this normalises to `weight.bodySm` (1.5) so the chevron is on the weight ladder and picks up Bold Text
and High Contrast through the same accessor as everything else.

**Why `[3, 3]` and why it never scales.** The dash is a texture, and this app pins textures to an
absolute pitch at every size so the same mark reads the same from 24 pt to 220 pt (§13.5's
`pitch = max(5 pt, 0.22·R)` and the coverage ladder that depends on it). A dash that scaled with the
box would make the 36 pt ECHO seed and the 168 pt DRIFT sigil different marks, which is exactly the
diegetic claim §4.2 is making.

**`[3, 3]` is this mark's signature.** No other dashed mark in the app may use it: the counterexample
ring is `[4, 3]` (`verdict-ring.md` §5), and the empty-rail outline and the Anomaly `.absent` ring —
`hunch-bench-instruments` and `hunch-chrome-and-meta` — must pick something else. A dashed rectangle
in `[3, 3]` means *previous glyph*, everywhere, and nothing else.

**Colour is `stroke.secondary`, not `stroke.primary`.** The ghost marks a glyph that is *not the live
one*; drawing it at primary would make the pin compete with the throat. `stroke.secondary` clears the
3 : 1 graphical floor in all three themes and `stroke.hairline` does not — which is why the frame is
state-bearing at secondary and never at hairline (`palette.md` declares hairline **never**
state-bearing). The three measured ratios are `palette.md` §1's column; do not copy them here.

---

## 2. Roles, and why there are no visual states

Scope §3 lists the ghost frame's states as *"on · off · read-only"* and its variants as *"live vs
depictive"*. Stated as drawings:

- **`off` is not a drawing.** The socket is `cur`, the ribbon tile is not the pin, so the host does
  not call this function. There is no "off" ghost frame.
- **`read-only` is not a drawing either.** It says the host does not wrap the frame in a button — a
  Codex page's Bridge tile (§11.1: "no cell responds to touch") draws the identical frame. Read-only
  is an accessibility and hit-testing fact, and it belongs to the host.
- **`live` vs `depictive` is a role, and it changes exactly one thing: nothing.** The DRIFT mode sigil
  and the Bridge palette stamp draw the same frame at their own `side`. That is the point — §12.4
  builds the DRIFT sigil "from idioms the player has already met", and an approximation would break
  the sentence.

So the mark has **one drawing**, parameterised by `side` and by the layout direction. `role` exists
in the signature only so a call site declares which it is and so the snapshot gallery can label the
row; it must not branch the geometry.

---

## 3. The Swift

```swift
import SwiftUI
import Tokens

public enum GhostFrame {
    /// Where this frame is being drawn. Present for the snapshot gallery and for call-site clarity;
    /// it deliberately does not change the geometry, because §4.2's diegetic claim depends on every
    /// site drawing the identical mark.
    public enum Role: Hashable, Sendable {
        case socket, marker, pin, seed, depictive
    }

    /// Draws the dashed hollow frame and its backward chevron.
    ///
    /// `box` is the glyph box being marked, in the host's coordinate space. `layout` decides which
    /// edge is leading: the chevron means *earlier in reading order*, so it mirrors under RTL while
    /// the glyph inside it does not (§2).
    ///
    /// The context is taken by value; nothing set here escapes to the caller.
    ///
    /// - Complexity: O(1) — two sub-paths.
    public static func draw(
        into context: GraphicsContext,
        box: CGRect,
        role: Role = .marker,
        layout: LayoutDirection = .leftToRight,
        env: RenderEnv
    ) {
        // `let`, not `var`: `stroke` is non-mutating, so this mark sets nothing on the context at
        // all. A `var` here is an unmutated variable, and `03 W18` says fix that rather than
        // silence it — with `-warnings-as-errors` in Release it is a build failure (`07 B19`).
        let ctx = context
        let ink = GraphicsContext.Shading.color(env.palette.stroke.secondary.color)

        let frameWeight = env.weight(.thin)
        ctx.stroke(
            Path(box.insetBy(dx: frameWeight / 2, dy: frameWeight / 2)),
            with: ink,
            style: StrokeStyle(lineWidth: frameWeight, dash: C.GhostFrame.dash)
        )

        let u = max(C.GhostFrame.chevronFloor, C.GhostFrame.chevronRatio * box.width)
        let mid = box.midY
        let x = { (offset: CGFloat) -> CGFloat in
            layout == .rightToLeft ? box.maxX - offset : box.minX + offset
        }
        var chevron = Path()
        chevron.move(to: CGPoint(x: x(2 * u), y: mid - u))
        chevron.addLine(to: CGPoint(x: x(u), y: mid))
        chevron.addLine(to: CGPoint(x: x(2 * u), y: mid + u))
        ctx.stroke(
            chevron,
            with: ink,
            style: StrokeStyle(lineWidth: env.weight(.bodySm), lineCap: .butt, lineJoin: .miter)
        )
    }
}
```

`layout` is a `SwiftUI.LayoutDirection` passed by the host from `@Environment(\.layoutDirection)`. It
is **not** on `RenderEnv`: `RenderEnv` is the seven accessibility axes and adding an eighth for
layout would put a SwiftUI type into `Tokens`, which is a leaf target with no dependencies
(`hunch-design-tokens`, `tokens-swift-layout.md` §4).

---

## 4. Environment behaviour

**VoiceOver.** No element. §13.10 gives the Bridge's ghost toggle its own row — `.button`
`.isSelected`, label "Previous glyph", value "on" / "off" — and that element is the *toggle*, owned by
`hunch-bench-instruments`. The ribbon `prev` marker reaches VoiceOver as part of the ribbon tile's
value; the ECHO seed glyph as "seed glyph" (§13.10, ribbon tile row); the Assay pin through the
Assay's value, which quotes the **slice** ("Admits 64 of 256 glyphs, with this previous glyph") and
never the marginal projection (§4.3, §13.10). A label on the frame would say "previous glyph" twice.

**Reduce Motion.** Nothing. The ghost frame never animates: it appears and disappears with its host,
and the host's transition is already in §13.7.4's table. In particular the frame does **not** get a
marching-ants dash offset — an animated dash is the one thing a dashed mark invites and there is no
row for it in §13.7.4, so it does not exist.

**High Contrast.** `stroke.secondary` resolves to its High Contrast value (`palette.md` §1's measured
column — no hex, no ratio in this file) and both weights pick up the flat `+0.5` through
`env.weight(_:)`. The dash does **not** change: `[3, 3]` against a resolved `weight.thin` frame stroke
is still legibly dashed, and lengthening the dash would move the mark's identity under a setting that
is supposed to preserve it.

**Bold Text.** Both weights scale ×1.25 through `env.weight(_:)`. The dash stays `[3, 3]`, so the
frame gets heavier and stays clearly broken — the dash is a texture in points and the weight is a
token; only one of the two moves.

**Differentiate Without Colour.** Nothing changes — the mark is already colour-free by construction:
dash pattern and chevron are two independent non-colour channels.

**RTL.** The chevron mirrors; the frame is symmetric so mirroring is a no-op on it. This is the
correct half of §2's rule: the chevron is a *reading-order* mark meaning "the one before this", so it
follows layout, while the glyph inside the frame never mirrors because its index-stroke rotation is
game state. Getting this backwards swaps `teal` and `rose` in Arabic — the exact failure §2 names.

**Dynamic Type.** The host passes `box` already scaled by `env.artScale`. The chevron's `0.09 · side`
therefore scales with it and its 4 pt floor holds the small end.

---

## 5. The `C.GhostFrame` namespace

| Member | Value | Home of the number |
|---|---|---|
| `dash` | `[3, 3]` pt | PHOSPHOR mockup, `ghostFrame()`; fixed at every size |
| `chevronRatio` | `0.09` × box side | this skill — reproduces the mockup exactly at `side = 44` |
| `chevronFloor` | `4.0` pt | this skill — keeps the 36 pt ECHO seed chevron legible |

Weights and colour are not here: `env.weight(.thin)`, `env.weight(.bodySm)`,
`env.palette.stroke.secondary`. The frame inset is not a token either — it is `resolvedWeight / 2`, a
geometric relationship derived from the already-resolved weight, exactly like the light-theme keyline's
`+1.0` (`hunch-design-tokens`, resolution order stage 4).

---

## 6. What would be wrong

- **A second dashed-rectangle drawing anywhere.** The empty rail, the Anomaly `.absent` cell and the
  Assay's dashed empty slot are all dashed rectangles or rings. They belong to other skills and must
  not use `[3, 3]`, and they must not be drawn by copying this file.
- **Scaling the dash with the box.** The 36 pt seed and the 168 pt DRIFT sigil would become different
  marks, and §4.2's "the player has already met that exact mark" stops being true.
- **Drawing the frame at `stroke.hairline`.** `palette.md` declares hairline never state-bearing, and
  the ghost frame is the entire contextual grammar. In the dark theme it does not clear the 3 : 1
  graphical floor, so it is not a channel — read the measured figure in `palette.md` §1.
- **Writing a hex or a contrast ratio into this file.** One home, `palette.md`'s measured column.
- **Drawing it at `stroke.primary`.** The pin would compete with the throat, and §13.1 rations light:
  the bright things on a play surface are the live glyph, the ribbon tiles and one lit cell per ramp.
- **A rounded corner.** At 2 pt it starts reading as a key, and §13.1 makes rounded-rect cards a
  PR-rejection offence.
- **Mirroring the chevron under RTL — or failing to.** It means "earlier in reading order". Pinning it
  to the physical left edge is as wrong as mirroring the glyph inside it.
- **Branching the geometry on `role`.** A depiction that is not the mark is not a depiction.
- **Animating the dash.** There is no row for it in §13.7.4, so there is no such animation.
- **Giving the frame an accessibility element.** The Bridge's toggle already has one (§13.10) and the
  other five sites belong to their hosts' values.
