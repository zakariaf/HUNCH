# DIRECTION A — "PHOSPHOR"

*A dead machine in a dark room.* The room is not styled; it is simply unlit. The Loom's chrome is **etched, not printed** — hairlines cut into a matte plate that reflects nothing — and the only thing in the building with power is the mark itself. Glyphs arrive as thin luminous strokes with a phosphor smear, the way an oscilloscope trace sits *above* its bezel rather than on it. The player is not browsing an app; they are **operating an instrument**: one accent, rationed; no shadows, no cards, no elevation; luminance is the only depth cue. Nothing is friendly, nothing is hostile, and nothing hurries.

### The emotional argument — three sentences

This direction makes the player feel **trusted and alone with a mechanism**: the machine does not explain itself, does not congratulate, and answers exactly what was asked, so every reading feels earned rather than granted. Because the marks are the only light in the room, attention has nowhere else to go — the glyph becomes the whole world for 200 ms at a time, and the reject shudder lands in the body. It costs **warmth and welcome**: PHOSPHOR has no way to be delightful, its light theme is a translation rather than a design, and a player who wanted company will read patience as coldness.

## 1. Token set

Flat, named, exhaustive. `Theme.token(_:)` resolves against the active theme; **no literal hex in view code**. Rows marked **c** are canon (§13.2/§13.3) and quoted verbatim; rows marked ‡ are new here, with ratios computed under WCAG 2.1 sRGB-linear relative luminance against **that theme's own `ground`**.

### 1.1 Colour

| Token | Dark | : 1 | Light | : 1 | High Contrast | : 1 | Use |
|---|---|---|---|---|---|---|---|
| `ground` **c** | `#0B0A08` | — | `#F4EFE4` | — | `#000000` | — | the room |
| `ground.raised` **c** | `#15120D` | 1.06 | `#FBF7EE` | 1.06 | `#0A0A0A` | 1.10 | Bench, sheets, Codex plates |
| `ground.sunken` **c** | `#050504` | 1.06 | `#EBE4D5` | 1.07 | `#000000` | 1.00 | Assay well, throat vignette |
| `surface.cell` ‡ | `#100E0A` | 1.03 | `#F7F3EA` | 1.04 | `#000000` | 1.00 | ramp cell / rule-tile interior, unlit |
| `surface.cell.lit` ‡ | `#1C1811` | 1.12 | `#FDFBF6` | 1.11 | `#141414` | 1.14 | ramp cell admitted, row pressed |
| `stroke.primary` **c** | `#EFE3D0` | **15.6** | `#1A1712` | **15.6** | `#FFFFFF` | **21.0** | glyph keyline, rule-tile stroke, body text |
| `stroke.secondary` **c** | `#6B6153` | **3.3** | `#6E6659` | **4.9** | `#B0B0B0` | **9.7** | chrome rules, tick marks, labels |
| `stroke.hairline` **c** | `#3A342B` | 1.6 | `#D6CDBC` | 1.5 | `#5A5A5A` | 3.3 | decorative rules, Assay grid — **never state-bearing** |
| `accent.brass` **c** | `#C9922F` | **7.2** | `#8A5E14` | **5.0** | `#FFC24D` | **13.1** | admit, the Seal, marks, streak |
| `accent.brass.press` ‡ | `#8A6420` | 3.7 | `#5E3F0C` | 8.4 | `#C99433` | 7.8 | Seal / brass control while the finger is down |
| `accent.cold` **c** | `#7FD8E0` | **12.1** | `#0E5F72` | **6.3** | `#7FE9FF` | **15.0** | reject, strike, counterexample, barred |
| `accent.cold.press` ‡ | `#4E9AA2` | 6.1 | `#093F4C` | 10.0 | `#4FB8CC` | 9.1 | cold control pressed |
| `hue.amber` **c** | `#E69F00` | 9.5 † | `#E69F00` | 1.8 † | `stroke.primary` | 21.0 | glyph hue rank 1 |
| `hue.teal` **c** | `#009E73` | 6.4 † | `#009E73` | 2.7 † | `stroke.primary` | 21.0 | glyph hue rank 2 |
| `hue.frost` **c** | `#56B4E9` | 8.6 | `#56B4E9` | 2.0 † | `stroke.primary` | 21.0 | glyph hue rank 3 |
| `hue.rose` **c** | `#CC79A7` | 6.5 | `#CC79A7` | 2.7 † | `stroke.primary` | 21.0 | glyph hue rank 4 |

† Light theme: every glyph carries a `stroke.primary` keyline at `bodyWeight + 1.0` beneath the hue (canon), so the silhouette edge is 15.6 : 1. Recomputing canon's dark-theme amber and teal from the stated hexes gives 8.8 and 5.8 rather than 9.5 and 6.4; both still clear every gate the design uses, so **no design consequence follows** and canon's numbers are quoted as-is.

**Aliases** — no new values; they exist so view code never reaches past its own register. `focus.ring` = `stroke.primary` 2 pt with 2 pt offset · `assay.lit` = `stroke.primary` @ `opacity.assayLit`, `assay.grid` = `stroke.hairline`, `assay.conflict` = `accent.cold`, `assay.probed` = `stroke.secondary` · `mark.earned` = `accent.brass`, `mark.fracture` = `accent.cold` · `scrim.bench` = `ground` @ `opacity.scrim` · `glyph.keyline` = `stroke.primary`, light theme only.

### 1.2 Dimension and radius (pt)

| Token | Value | Token | Value | Token | Value |
|---|---|---|---|---|---|
| `space.1 … space.9` | 4 / 8 / 12 / 16 / 20 / 24 / 32 / 44 / 64 | `margin.outer` | 16 | `column.content` | 343 |
| `target.min` | 44 × 44 | `glyph.throat` | 96 | `glyph.ribbon` | 44 |
| `glyph.codexThumb` | 44 | `glyph.codexHero` | 220 | `cell.dial` | 70 × 48 |
| `cell.ramp` | 56 × 44 | `stamp.palette` | 68 × 44 (AX3+ 165 × 56) | `assay.well` | 64 (cell 4) |
| `assay.expanded` | 368 (cell 23) | `bench.handle` | 343 × 44 | `rule.inset` | 16 both sides |
| `radius.chrome` | 2 | `radius.sheet` | 12 (top only) | `radius.glyph` | **0, always** |
| `bleed.glyph` | 0.08 · S | `type.scaleCeiling` | 1.35× (AX2) | `pitch.fill` | max(5, 0.22 · R) |

### 1.3 Stroke weight (pt)

| Token | Value | Applied to |
|---|---|---|
| `w.hairline` | 0.5 | chrome rules, Assay grid, empty-rail outline, plate frames |
| `w.thin` | 1.0 | ramp cell borders, rule-tile frames, pip knockout ring |
| `w.bodySm` | 1.5 | glyph body below S = 48, fill hatch at small sizes |
| `w.body` | 3.0 | glyph body at S ≥ 48, index stroke, wedge, coupler strands |
| `w.heavy` | 4.0 | machined bar across a barred Seal, the AND welded bar |
| `w.halo` · modifiers | 3 × the stroke it doubles · Bold Text ×1.25 · HC +0.5 | the widened low-opacity pass; modifiers applied once, at token resolution |

### 1.4 Opacity

| Token | Value | Token | Value | Token | Value |
|---|---|---|---|---|---|
| `opacity.halo` | 0.12 | `opacity.bloomBed` | 0.35 | `opacity.assayLit` | 0.92 |
| `opacity.cellUnlit` | 0.25 (HC 0.40) | `opacity.cellInert` | 0.30 | `opacity.disabled` | 0.35 |
| `opacity.ribbonDim` | 0.20 (beat 1) | `opacity.lawGhost` | 0.40 (beat 3) | `opacity.pressed` | 0.70 |
| `opacity.scrim` | 0.85 flat (0.60 + blur if allowed) | `opacity.railPulse` | 0.50 → 1.00 | `opacity.hairlinePulse` | 0.60 → 1.00 (RM: static) |

### 1.5 Duration (ms) and easing

| Token | ms | Token | ms | Token | ms |
|---|---|---|---|---|---|
| `dur.tap` | 90 | `dur.micro` | 120 | `dur.ringAdmit` | 200 |
| `dur.ringReject` | 160 | `dur.admit` | 260 | `dur.reject` | 250 |
| `dur.crossfade` | 220 | `dur.push` | 280 | `dur.sheet` | 320 |
| `dur.zoom` | 300 | `dur.shared` | 340 | `dur.streak` | 600 |
| `dur.reveal` | 1840 | `dur.revealLost` | 1020 | `dur.grainReseed` | 125 (8 Hz) |
| `dur.reduceMotion` | 260 reveal / 160 rings | `dur.pulse` | 90 × 3 (barred rail) | `dur.drift` | 520 |

| Easing token | SwiftUI | CSS equivalent for the mockup |
|---|---|---|
| `ease.linear` | `.linear` | `linear` |
| `ease.in` | `.easeIn` | `cubic-bezier(.42,0,1,1)` |
| `ease.out` | `.easeOut` | `cubic-bezier(0,0,.58,1)` |
| `ease.inOut` | `.easeInOut` | `cubic-bezier(.42,0,.58,1)` |
| `ease.snap` | `spring(.18,.90)` | `cubic-bezier(.22,.61,.36,1)` |
| `ease.settle` | `spring(.26,.78)` | `cubic-bezier(.34,1.12,.64,1)` — the only overshoot, 8 pt, reveal beat 2 |
| `ease.dock` | `spring(.30,.85)` | `cubic-bezier(.30,.90,.40,1)` |
| `ease.sheet` / `ease.zoom` / `ease.shared` | `spring(.32,.86)` / `(.30,.88)` / `(.34,.86)` | `cubic-bezier(.32,.88,.40,1)` |
| **forbidden** | — | any bounce or rubber-band on a verdict; any symmetric ease on a reveal beat |

---

## 2. Texture logic — how a stroke becomes light

Four passes. Passes A and B are the **bloom**; C and D are the mark. Order is fixed and a reviewer should check it in any PR that touches drawing.

| Pass | What | Geometry | Paint |
|---|---|---|---|
| **A — bed** | a clone of *the whole region's* marks, blurred | one offscreen layer **per glyph-bearing region** (throat, ribbon, tail) | `blur(0.062 · S)`, `opacity.bloomBed`, composited `plus-lighter` |
| **B — halo** | each glyph's stroked registers re-stroked wide | body outline + index stroke only, at `w.halo` (3×), **round join** | own hue, `opacity.halo` |
| **C — ink** | the mark | body outline, fill texture, index stroke, full weight | own hue, opacity 1, **miter join, butt cap, zero radius** |
| **D — knockout** | pip separation | disc `r = pipR + 0.5` stroked `ground` at `w.thin` | leaves a visible hue disc of exactly `pipR` |

Pass A is the expensive one and is the reason it is **per region, not per glyph** — three offscreen layers per frame, never sixteen. The fill texture and the pips take their glow from A only; widening a dot pattern in B would raise measured ink coverage and corrupt the `fill` ladder. **The Assay is excluded from A and B entirely, at every size and in every state** (canon). Bloom is off under Reduce Transparency, High Contrast, Low Power Mode, and below `S = 32`.

CSS for the mockup — `blur()`'s argument *is* the Gaussian standard deviation, so it matches `feGaussianBlur stdDeviation` one-for-one:

```css
:root { --S: 96px; --bloom: calc(var(--S) * 0.062); }   /* 5.95px at the throat */
.region            { position: relative; isolation: isolate; }
.region > .bed     { position: absolute; inset: 0; filter: blur(var(--bloom));
                     opacity: .35; mix-blend-mode: plus-lighter; pointer-events: none; }
.glyph             { overflow: visible; }                /* frost reaches y = 0.567·S */
.glyph .halo       { opacity: .12; stroke-linejoin: round; fill: none; }
.glyph .ink        { stroke-linejoin: miter; stroke-linecap: butt; stroke-miterlimit: 10; }
@media (prefers-reduced-transparency:reduce),(prefers-contrast:more){ .bed,.halo{display:none} }
```

The grain/scanline/vignette is **one** `colorEffect` over the play surface below the chrome bar (§13.6 shader, verbatim), `amt = 0` under Reduce Transparency / High Contrast / Low Power, `t = 0` under Reduce Motion.

---

## 3. Chrome — what an instrument panel means here

**Rules.** Exactly two kinds. A *divider* is `w.hairline` in `stroke.hairline`, inset `rule.inset` both sides. A *section boundary* is the same line with `space.6` (24) of air above and `space.4` (16) below. There is no third rule weight anywhere in chrome; a heavier line always means state (`w.thin` rule-tile frame, `w.heavy` machined bar). Panels never carry shadow, blur or elevation — they separate by a 1.06 : 1 ground step **and** a hairline, and never by only one of the two.

**Labels and small caps.** The small-caps register is achieved by the `section` (13 / medium / condensed / 0.14 em) and `micro` (11 / medium / condensed / 0.16 em) roles, **uppercased through `String.uppercased(with: locale)` — never the font's small-caps feature and never a display transform** (SF Pro's small-caps degrades non-Latin to full caps; Turkish dotted-I and Arabic caselessness both break the naive path). Tracking is stored in em and applied as `.tracking(scaledSize * em)`. Labels are `stroke.secondary`, sit on a 20 pt band flush to the 16 pt margin, and take `space.3` (12) of air before the first row beneath them. Numerals are SF Mono `monospacedDigit`, always.

**A Settings row.**

```
┌ ground.raised · radius.chrome 2 · no shadow · height ≥ 44 ────────┐
│←16→│ SOUND                                      [ switch ] │←16→│
└──── 0.5 pt stroke.hairline, inset 16 leading, flush trailing ─────┘
```
`body` 17 / `stroke.primary` leading; secondary value in `caption` / `stroke.secondary` on a second line when present; control trailing with its own ≥ 44 × 44 hit rect. Pressed state is `surface.cell.lit` — a ground step, not a tint. **The switch is drawn, not tinted:** a 51 × 31 track with a `w.hairline` frame and a 27 pt slug; ON = slug filled `stroke.primary`, at the trailing end; OFF = slug hollow with a `w.thin` frame at `opacity.disabled`, at the leading end. Two independent non-colour channels (position, fill) and **no accent** — because `accent.*` is rationed to three elements per screen and a Settings list has eight toggles. RTL mirrors the track; the slug's travel mirrors with it.

**A Codex shelf plate.** The Codex list is a specimen shelf, and a page is a plate on it.

```
┌ ground.raised · 0.5 pt engraved frame @ 0.5 α · radius 2 · height 72 ┐
│ [44 pt Assay marginal, 16×16 @ 2.75 pt, hairline frame] │ FAMILY · BAND  (micro, secondary)
│                                                          │ Title (body 17, primary)
│                                                          │ 2026-07-27 · 15 probes (numeral, secondary)   ▍▍▍ marks
└────────────── 0.5 pt shelf line, inset 16 ───────────────────────────┘
```
The thumbnail is the law's *unconditional marginal projection*, never the live Assay slice (§4.3 — the two must not be quoted for each other). Marks render as 3 pt tick bars, `w.body`, 4 pt apart. **Accent rationing applies per screen, so in a list the brass belongs to at most one plate — the row just inscribed; every other plate draws its marks in `stroke.primary`.** A `fracture` is a single `w.thin` `accent.cold` diagonal breaking the plate's leading frame between the thumbnail and the text column — geometry first, colour second.

---

## 4. Verdict, themes, and the constraint ledger

**Verdict is ring geometry, and colour is the third copy.** *Admit*: the ring stays closed and expands R → 1.35 R over `dur.ringAdmit`, weight 3 → 1, `accent.brass`. *Reject*: the ring contracts 1.35 R → R over `dur.ringReject`, then breaks into four arcs that separate 3 pt (doubled under Differentiate Without Colour), `accent.cold`, plus a 130 ms ∓2 pt horizontal shudder that is not a bounce. Greyscale, the two are still opposite: *closed and growing* vs *broken and shrinking*.

**Dark** is the design. **Light** keeps every geometry and swaps the ground; hue keeps its Okabe–Ito value and gains the `stroke.primary` keyline; bloom drops to `opacity.halo` only, with no bed layer (a blurred bright mark on a light ground reads as a printing fault, not as light). **High Contrast** collapses all four `hue.*` to `stroke.primary`, lengthens the index stroke `0.273·S → 0.409·S` (canon's 12 → 18 pt at the ribbon — a ×1.5 lengthening, which is what "doubles" in §2 actually spells out in §13.5; the numbers are the operative version), kills the shader and both bloom passes, adds +0.5 pt to every stroke, and lifts unlit cells to 0.40 with a 2 pt cancel hatch.

| # | Constraint | How PHOSPHOR satisfies it |
|---|---|---|
| 1 | Zero text on the play surface | The tally is tick marks; verdicts are rings; no role in §13.4 is permitted below the chrome bar. Text lives only in Settings / Codex / Statistics / About. |
| 2 | Triple encoding | fill = ink coverage {0, 22.7, 38.6, 100 %} + texture kind; shape = corner count {0,3,4,6}; pips = contour-node count; hue = index rotation {0,45,90,135}. Greyscale-complete. |
| 3 | Colourblind-safe | Okabe–Ito verbatim, and no decision reads colour at all — hue is the index stroke, colour is the redundant copy. |
| 4 | Vector only | Every mark below is generated from `(fill, shape, pips, hue, size)`; no bitmap, no icon font, no SF Symbol on the play surface. |
| 5 | Targets and reach | `target.min` 44 × 44 everywhere; Dial cells 70 × 48; all controls in the y > 240 thumb arc; the Loom is view-only in the top third by design. |
| 6 | Three themes | §1 above, all tokens resolved in all three; HC is fully playable in one colour. |
| 7 | Register segregation | `accent.*` is forbidden on a glyph body, ramp cell or index stroke; `hue.*` is forbidden on chrome, rule-tile frames, ticks and the Seal — including the Settings switch, which is why it is drawn rather than tinted. |
| 8 | Type / RTL / Motion | Art scales to 1.35× then freezes and scrolls; chrome mirrors and glyphs never do; §13.7.4's substitution table is the complete motion contract. |

---

## 5. The renderer

One function, all 256, no hand-authored path data. **Coordinate note, and the one ambiguity in §13.5 resolved:** the GDD lists positions in a y-up frame (`bodyCentre +0.10·S`, index `−0.43·S`, "below the body") but lists angles in the screen frame (`N = −90°`, triangle apex-up at `−90°`). Both cannot hold at once, so the renderer works in **SVG screen coordinates (y down, angles clockwise from East) and negates the GDD's y values** — body at `−0.10·S`, index at `+0.43·S`. Apex-up, N-at-top and index-below-body all then hold simultaneously, which is the only reading under which every sentence of §13.5 is true.

```js
const SVGNS="http://www.w3.org/2000/svg", rad=d=>d*Math.PI/180, X=(a,b)=>a[0]*b[1]-a[1]*b[0];
const VERTS={circle:null, triangle:[-90,30,150], square:[-135,-45,45,135],      // ascending
             hexagon:[-90,-30,30,90,150,210]};                                  // = convex order
const PIP_RAYS=[-90,0,90,180], PIP_N={one:1,two:2,three:3,four:4};              // N,E,S,W
const ROT={amber:0, teal:45, frost:90, rose:135};

function renderGlyph(fill, shape, pips, hue, size, opt={}) {
  const S=size, hc=!!opt.highContrast, bold=opt.boldText?1.25:1, hcw=hc?0.5:0;
  const bloom=opt.bloom!==false && !hc && S>=32;
  const ink=hc?"var(--stroke-primary)":`var(--hue-${hue})`, gnd="var(--ground)";
  const C=[0,-0.10*S], R=0.37*S, IC=[0,0.43*S];              // screen frame, y down
  const W=(S>=48?3:1.5)*bold+hcw, IW=3*bold+hcw;             // index never thins
  const ILEN=(hc?0.409:0.273)*S, pitch=Math.max(5,0.22*R), pipR=Math.max(3,0.11*R);

  const svg=document.createElementNS(SVGNS,"svg");
  svg.setAttribute("width",S); svg.setAttribute("height",S); svg.setAttribute("aria-hidden","true");
  svg.setAttribute("viewBox",`${-S/2} ${-S/2} ${S} ${S}`);
  svg.style.overflow="visible";                              // frost reaches y = 0.567·S
  const mk=(p,t,a)=>{const e=document.createElementNS(SVGNS,t);
    for(const k in a) e.setAttribute(k,a[k]); p.appendChild(e); return e;};
  const vAt=k=>VERTS[shape].map(a=>[C[0]+k*R*Math.cos(rad(a)), C[1]+k*R*Math.sin(rad(a))]);
  const poly=k=>vAt(k).map(p=>p.map(n=>n.toFixed(3)).join(",")).join(" ");
  const body=(par,a)=>shape==="circle" ? mk(par,"circle",{cx:C[0],cy:C[1],r:R,...a})
                    : mk(par,"polygon",{points:poly(1),"stroke-miterlimit":10,...a});
  const idx=a=>{const h=ILEN/2, u=[Math.cos(rad(ROT[hue])), Math.sin(rad(ROT[hue]))];
    return {x1:(IC[0]-u[0]*h).toFixed(3), y1:(IC[1]-u[1]*h).toFixed(3),
            x2:(IC[0]+u[0]*h).toFixed(3), y2:(IC[1]+u[1]*h).toFixed(3),
            fill:"none", "stroke-linecap":"butt", ...a};};
  const hit=deg=>{                                           // ray from C -> the contour
    const d=[Math.cos(rad(deg)), Math.sin(rad(deg))];
    if(shape==="circle") return [C[0]+d[0]*R, C[1]+d[1]*R];
    const v=vAt(1);
    for(let i=0;i<v.length;i++){ const p=v[i], q=v[(i+1)%v.length];
      const e=[q[0]-p[0],q[1]-p[1]], w=[p[0]-C[0],p[1]-C[1]], den=X(d,e);
      if(Math.abs(den)<1e-9) continue;
      const t=X(w,e)/den, u=X(w,d)/den;
      if(t>0 && u>=-1e-9 && u<=1+1e-9) return [C[0]+d[0]*t, C[1]+d[1]*t]; }
    return [C[0]+d[0]*R, C[1]+d[1]*R];};

  if(bloom){                                                 // PASS B — halo (A is per region)
    const g=mk(svg,"g",{opacity:0.12,"stroke-linejoin":"round",fill:"none",stroke:ink});
    body(g,{"stroke-width":W*3}); mk(g,"line",idx({"stroke-width":IW*3})); }
  if(fill!=="hollow"){                                       // PASS C — texture, inset + clipped
    const n=shape==="circle"?0:VERTS[shape].length;
    const apo=shape==="circle"?R:R*Math.cos(Math.PI/n), k=(apo-1.5*W)/apo;  // exact inward offset
    const id="clip-"+Math.random().toString(36).slice(2,9);
    const cp=mk(mk(svg,"defs",{}),"clipPath",{id});
    shape==="circle" ? mk(cp,"circle",{cx:C[0],cy:C[1],r:R*k}) : mk(cp,"polygon",{points:poly(k)});
    const g=mk(svg,"g",{"clip-path":`url(#${id})`}), r=R*k;
    if(fill==="solid") body(g,{fill:ink,stroke:"none"});
    if(fill==="dotted"){ const rr=0.25*pitch, dy=pitch*Math.sqrt(3)/2;      // hex pack -> 22.7 %
      for(let j=0,y=C[1]-r; y<=C[1]+r+dy; y+=dy, j++)
        for(let x=C[0]-r+(j%2?pitch/2:0); x<=C[0]+r+pitch; x+=pitch)
          mk(g,"circle",{cx:x.toFixed(3),cy:y.toFixed(3),r:rr.toFixed(3),fill:ink}); }
    if(fill==="striped"){ const sw=0.386*pitch, L=2*r,                      // +45° -> 38.6 %
        u=[Math.SQRT1_2,Math.SQRT1_2], nv=[-u[1],u[0]];
      for(let m=-Math.ceil(L/pitch); m<=Math.ceil(L/pitch); m++){
        const o=[C[0]+nv[0]*m*pitch, C[1]+nv[1]*m*pitch];
        mk(g,"line",{x1:(o[0]-u[0]*L).toFixed(3), y1:(o[1]-u[1]*L).toFixed(3),
          x2:(o[0]+u[0]*L).toFixed(3), y2:(o[1]+u[1]*L).toFixed(3),
          stroke:ink, "stroke-width":sw.toFixed(3), "stroke-linecap":"butt"}); } }
  }
  body(svg,{fill:"none",stroke:ink,"stroke-width":W,"stroke-linejoin":"miter"});  // PASS C keyline
  for(let i=0;i<PIP_N[pips];i++){ const [px,py]=hit(PIP_RAYS[i]);                 // PASS D nodes
    mk(svg,"circle",{cx:px.toFixed(3), cy:py.toFixed(3), r:(pipR+0.5).toFixed(3),
                     fill:ink, stroke:gnd, "stroke-width":1}); }
  mk(svg,"line",idx({stroke:ink,"stroke-width":IW}));
  return svg;
}
```

Verified in node against a DOM stub: all 256 render without throwing at S = 24 / 44 / 96 / 220; triangle apex lands at `(0, −0.47·S)`; the rose index runs `(+0.0965S, +0.333S) → (−0.0965S, +0.527S)`, length exactly `0.273·S`, centred on `+0.43·S`; the inset triangle's apothem is exactly `apothem − 1.5·W`; `stripeWeight` at S = 96 is 3.016 pt.

---

## 6. Weaknesses — honest

1. **Night play is the risk, not battery.** On OLED the near-black ground with sparse marks is the cheapest frame we could ask for, so power is a non-issue — but bright thin strokes on black cause **halation for astigmatic eyes** (roughly a third of adults), and our smallest state-bearing marks are 1.5 pt strokes and 4 pt Assay cells. Worse, the whole depth system is a **1.06 : 1 ground step**, which is at or below the visible threshold on many panels below 30 % brightness and is destroyed by auto-dimming; add OLED near-black banding and mura and the Bench can stop reading as a separate panel entirely. Mitigation is the hairline, which is 1.6 : 1 — also marginal. This is the direction's most likely field failure.
2. **Bright daylight inverts the whole premise.** `stroke.primary` at 15.6 : 1 survives sunlight; nothing else does. `ground.raised`, `ground.sunken`, the hairlines and the entire grain/vignette layer disappear under glare, so the app collapses to one flat surface and the instrument fiction goes with it. The answer is the light theme — but the light theme is a *translation* of PHOSPHOR, not a design in its own right: a dead machine in a dark room, lit, is just a technical drawing, and a technical drawing is a thinner idea. A player who lives in the light theme never sees this direction at all.
3. **"Dark + glow + scanlines" is a very well-worn look.** It is adjacent to every CRT/terminal/hacker aesthetic of the last fifteen years — Duskers, Signalis, TIS-100, Pip-Boy, a thousand synthwave dashboards — and the App Store screenshot will be pattern-matched to "retro-futurist" in under a second. Our differentiators are all *subtractions*: no green, no CRT curvature, no typewriter face, no ASCII, no chromatic aberration, one accent rationed to three elements. Every one of those is cheap to lose in a single well-meaning PR, and the direction is only distinctive while all of them hold.
4. **Bloom actively attacks the `fill` ladder.** The halo is a 3× stroke at 12 % laid just inside the contour; at ribbon size (S = 44, W = 1.5, halo 4.5 pt) it deposits ink inside a silhouette whose inset interior is only ~12 pt across. That raises the measured coverage of `hollow` above 0 and compresses the 0 → 22.7 % step, which is the exact discriminator the greyscale proof rests on. Hence bloom off below S = 32 and excluded from the Assay — and it must become a **shipped test**: measured coverage separation of the four fills at 44 pt @2× must meet the same threshold `T` with bloom on as with it off.
5. **The grain beats against `dotted`.** The shader's scanline has a 3 px period and the dot pitch floors at 5 pt = 10 px @2×; at small sizes and at 1.35× type scaling those interfere, and because the grain reseeds at 8 Hz the interference *moves*, so a static fill can shimmer into looking like a different fill. `amt` must be clamped over the ribbon, or the shader restricted to the throat and the surround.
6. **Brass and amber are 3° apart in hue.** Register segregation is the entire defence, and register segregation is invisible to a player in their first ninety seconds: a brass admit ring around an amber glyph reads as one family. The luminance gap is **1.22 : 1** — measured, against the 1.36 : 1 canon asserted before the arithmetic was checked — which is small enough that it carries nothing; the ring geometry and register segregation carry all of it, and the cost is real — one of our four hues is permanently the least legible *as a hue*, and we cannot re-light it because Okabe–Ito is verbatim per canon. If the accent were ever to move, it would move away from amber, not toward it.
