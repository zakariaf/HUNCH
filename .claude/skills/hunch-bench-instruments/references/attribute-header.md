# attribute-header.md — the leading 44 pt, and the one drawing canon never specifies

Contents: [1 The gap, stated](#1-the-gap-stated) · [2 The four constraints](#2-the-four-constraints) ·
[3 The sanctioned construction](#3-the-sanctioned-construction) · [4 Geometry](#4-geometry) ·
[5 States](#5-states) · [6 SwiftUI](#6-swiftui) · [7 VoiceOver](#7-voiceover) ·
[8 Reduce Motion and High Contrast](#8-reduce-motion-and-high-contrast) · [9 Wrong](#9-wrong)

**Owner:** `AttributeHeaderView` in `Modules/Sources/HunchUI/RuleTileCanvas.swift`.
**L2:** `C.AttributeHeader`. Values: `hunch-design-tokens`. Register geometry (what "the fill
register" *is*): `hunch-glyph-renderer/references/geometry.md`. Final vetting of the drawing:
`hunch-sigil-drawing`.

---

## 1. The gap, stated

Canon specifies the header's **size** (44 pt leading of every ramp, §4.1), its **sites**, its
**states**, and one hard negative — *"There is no attribute emblem to learn. The ramp is a picture of
its own attribute"* (§4.1). It never says what the header draws. `DESIGN-SYSTEM-SCOPE.md` §2(e)
counts ~17 marks named but never drawn; this is a eighteenth, and it is the one that sits on the
Bench, the Dial, every Fork dock, the Tally and a Codex facet stamp — five surfaces, so an
unspecified drawing here drifts faster than anything else in the app.

Do not invent an emblem. Derive the drawing from the two sentences canon does give, satisfy §2 of
this file, and check it with the snapshot gallery.

---

## 2. The four constraints

Any header drawing must satisfy all four. They are falsifiable; §3's construction is one solution
and not the only one, but a replacement must clear the same four.

1. **Register-true.** It draws *only* inside that attribute's own register of the glyph box (§2's
   spatial disjointness) and draws nothing in the other three. `fill` marks the interior, `shape`
   marks the contour, `pips` marks the compass positions on the contour, `hue` marks the index
   register below the body.
2. **Value-free.** It is not one of the attribute's four values, or it competes with the four cells
   beside it and the ramp reads as five cells with a broken first one.
3. **Legible at every shipped size and in greyscale** — 44 pt (Bench, Dial, docks), 52 pt (Pro Max
   Dial), 34 pt (44 × 0.78, Codex page), and inside a facet stamp at 44 pt.
4. **Pairwise distinct.** The four headers must clear the same greyscale L1 threshold `T` that
   `hunch-glyph-renderer/references/triple-encoding-proof.md` asserts for the 256 glyphs, at 44 pt @2×. Four
   marks is a cheap addition to that existing test, not a new harness.

---

## 3. The sanctioned construction

**The header is the attribute's whole ladder drawn at once, in its own register, in
`stroke.secondary`.** All four values present means no value is selected, which is constraint 2 for
free, and it makes the header a legend for the row beneath it rather than a symbol to memorise.

| Attribute | Register | Drawing |
|---|---|---|
| `fill` | interior | the body circle quartered by two diameters, the four sectors carrying `hollow · dotted · striped · solid` in rank order, clockwise from the top-leading sector |
| `shape` | contour | the four silhouettes concentric and inscribed — circle, triangle, square, hexagon — each at `weight.hairline`, sharing `bodyCentre` |
| `pips` | contour nodes | the four compass nodes N · E · S · W drawn as **unfilled** rings on a hairline contour, so all four positions show and none is filled |
| `hue` | index register | a four-spoke fan at 0° / 45° / 90° / 135° through the index centre, each spoke at `0.273 · S / 2` from the centre — the whole rotation ladder as one rosette |

Four consequences worth naming: the fill header is the only one with interior ink, the shape header
is the only one with nested outlines, the pips header is the only one with unfilled discs, and the
hue header is the only one below the body line — so §2's constraint 4 is satisfied by construction
and the greyscale test is a formality rather than a hope.

The header draws in `stroke.secondary`, never in a `hue.*`: it is chrome, not a glyph, and
`hunch-design-tokens`' register segregation makes the wrong choice a compile error.

---

## 4. Geometry

| Site | Box | Note |
|---|---|---|
| leading of a Bench ramp / Fork dock | 44 × 44 | `C.Ramp.headerWidth` × the cell height (§4.2) |
| leading of a Dial ramp | 44 × 48 SE, 52 × 62 Pro Max | abuts cell 1 with no gutter; the header and its cells are one semantic group (§12.8) |
| inside an empty Bridge socket | 44 × 44, four of them | the socket's picker — see `bridge.md` §3 |
| a Tally attribute row | 44 × 44 | with a counted/uncounted state, `tally.md` §3 |
| a Codex facet stamp | 44 × 44, four drawn together | attribute-participation (§11.2); owned by `hunch-chrome-and-meta`, drawn by this view |
| Codex page rule-tile | × `C.RuleTile.codexScale` | scale the tile, never re-lay the header |

Inside its box the mark occupies a glyph box of side `S = box.height − 2 × Space.s4`, so the header
and the cells beside it share one `bodyCentre` baseline. Lengths multiply by `env.artScale`.

---

## 5. States

| State | Where | Drawing |
|---|---|---|
| **bound** | a ramp whose attribute is fixed | full mark, `stroke.secondary` |
| **unbound** | an empty Bridge socket before a pick | the socket draws its ghost/dashed frame; the header is absent, not greyed |
| **counted** / **uncounted** | Tally rows only, minimum three counted | uncounted takes the ramp's own unlit treatment — ink drop **and** the diagonal cancel hatch — so one hatch drawing serves the whole Bench |
| **selected** | a Bridge socket's picker, after the tap | `.isSelected`, interior steps to `surface.cellLit`; the picker then collapses |

There is no disabled state. A header that cannot be chosen is not drawn — except the Tally's third
counted attribute, which is *counted and not togglable off* and takes `.notEnabled` while keeping
its full drawing, because the minimum-three rule must be visible rather than enforced silently.

---

## 6. SwiftUI

`Shape`, not `Canvas`, for the shape and pips headers — a single stroked path that the system can
hit-test and animate, and `Shape.path(in:)` runs off the main actor so it costs the Bench nothing.
`Canvas` for the fill header, which composes four clipped textures.

```swift
// Modules/Sources/HunchUI/RuleTileCanvas.swift
import HunchCore
import SwiftUI

struct AttributeHeaderView: View {
    enum State: Hashable, Sendable { case bound, counted, uncounted, selected }

    let env: RenderEnv
    let attribute: Glyph.Attribute
    let state: State

    private var side: Double { C.AttributeHeader.side * env.artScale }

    var body: some View {
        Canvas { context, size in
            let box = CGRect(origin: .zero, size: size)
            AttributeLadder(attribute: attribute)
                .draw(in: &context, box: box, env: env)
        }
        .frame(width: side, height: side)
        .background {
            if state == .selected {
                RoundedRectangle(cornerRadius: Radius.chrome)
                    .fill(env.palette.surface.cellLit.color)
            }
        }
        .overlay { if state == .uncounted { CancelMark.hatch(env: env) } }  // hunch-shared-marks
        .opacity(state == .uncounted ? C.Ramp.cellUnlitInk(in: env) : 1)
        .accessibilityLabel(Loc.attributeName(attribute))
        .accessibilityAddTraits(state == .selected || state == .counted ? .isSelected : [])
    }
}
```

`AttributeLadder` is the one type that knows §3's four drawings. It lives beside the view and is
`Sendable`, takes an `inout GraphicsContext`, and reads geometry constants from
`hunch-glyph-renderer` — `bodyCentre`, `R`, the index centre, `pitch` — rather than restating them.
That is the whole anti-drift mechanism for this component: **the header's four drawings are
expressed in the glyph renderer's own coordinates, so a change to the glyph box moves the header
with it.**

---

## 7. VoiceOver

- Label: the localized attribute name — `"Fill"`, `"Shape"`, `"Pips"`, `"Hue"` (§13.10).
- As a ramp's leading element it is **not** separately focusable; the ramp container carries the
  attribute name and the header is decoration (`.accessibilityHidden(true)` inside a ramp). It is
  focusable only where it is itself the control: inside a Bridge socket's picker, on a Tally row, on
  a facet stamp.
- In a Bridge socket picker: `.button`, label the attribute name, value nothing, and the socket
  announces the result — `"pips, this glyph"` (§13.10).
- On a Tally row: `.button` `.isSelected`, value `"counted"` / `"not counted"`.
- On a facet stamp: `.button` `.isSelected`, value `"filtering by fill"` / off.

---

## 8. Reduce Motion and High Contrast

**Reduce Motion.** The header has no animation of its own. The picker's appearance inside a socket
follows the socket (`bridge.md` §6): a `Dur.micro` crossfade, never a scale or a slide.

**High Contrast.** `stroke.secondary` resolves to the theme's own value and every weight takes the
flat +0.5 pt through `env.weight(_:)`. Two consequences to draw deliberately:

- the **shape** header's four concentric silhouettes are its whole content; at +0.5 pt on a 0.5 pt
  hairline the nesting gaps must stay ≥ 1 pt, so the four rings are inset by a fraction of `R`, not
  by a fixed point value;
- the **hue** header's rosette lengthens with the index stroke, by the ratio
  `hunch-glyph-renderer/references/geometry.md` owns, for the same reason the cells do — otherwise the header
  stops matching the row beneath it under exactly the setting that makes rotation the only hue
  channel.

**Differentiate Without Colour** changes nothing here; the header carries no colour information in
any theme.

---

## 9. Wrong

- **Inventing an emblem** — a letter, an icon, a glyph standing for "fill". §4.1's claim is that
  there is nothing to learn; an emblem falsifies it and puts a symbol on a textless surface.
- **Drawing a value.** A single `striped` swatch as the fill header makes the ramp read as five
  cells and makes rank 3 look pre-selected.
- **Drawing outside the register.** A pips header with a filled body, a hue header above the body
  line — either breaks §2's disjointness, which is the property that lets four channels coexist.
- **Colouring it.** The header is chrome and takes `stroke.secondary`; a `hue.*` header would be a
  register violation and will not compile.
- **Hard-coding the header's geometry.** It must be expressed in the glyph renderer's `bodyCentre`,
  `R` and index centre, or the day the glyph box moves the header stays behind.
- **Leaving it focusable inside a ramp.** Two elements for one control doubles every ramp traversal
  and gives the "Attributes" rotor a duplicate stop.
- **Shipping it without the distinctness check.** Four marks added to the existing greyscale test is
  minutes of work; four marks that turn out to be two at 34 pt is a Codex page nobody can read.
