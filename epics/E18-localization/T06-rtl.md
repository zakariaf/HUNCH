# T06 — RTL

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | LOCALIZATION → RTL |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Loaded first, because this task touches drawings and the component skills assume its vocabulary. It also owns `RenderEnv`'s seven fields — and the ruling this task needs: `layoutDirection` is **not** one of them and is not being added, because `RenderEnv` is the accessibility-and-theme record and mirroring is a layout concern read from SwiftUI's own environment at the one drawing that needs it. |
| `hunch-accessibility` | It owns §12.8's mirroring table — the two columns of what mirrors in Arabic and what does not mirror in any locale — and the `leading`/`trailing`-only rule. The reasons in that table are accessibility reasons: mirroring the index stroke swaps `teal` and `rose`, and mirroring pip accretion breaks the N→E→S→W order a VoiceOver user counts through. |
| `hunch-glyph-renderer` | It owns the four registers and the screen-frame convention, and it already states the rule this task asserts: *"this is why RTL mirrors layout and never mirrors a glyph"* (`references/geometry.md` §7). E04·T02 shipped `coverageMask(_:side:scale:env:layout:)` with a `layout:` parameter for exactly this test, and E04·T02's own acceptance criteria already require `GlyphCanvas.swift` to contain no reference to `LayoutDirection` at all. |

## Objective

At the end of this task the chrome mirrors in Arabic and the drawings never do, and both halves are
asserted rather than reviewed: every one of the 256 glyphs rasterises bit-identically under
`.leftToRight` and `.rightToLeft`, the ribbon, the ramps and the Assay put source index 0 at the
**leading** edge in both directions, and the Bridge's wedge is the single drawing in the app that
reads `layoutDirection` — so that its wide end still physically opens toward the larger socket after
its rail has mirrored.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.8 (RTL — mirror the chrome, never the glyph) | the two-column table verbatim: what mirrors, what does not, and the wedge's row in both columns |
| `GAME_DESIGN.md` | §12.8 (final paragraph) | `leading`/`trailing` only, `left`/`right` never; ramps, the Assay and the ribbon render **leading-to-trailing in source order** in every locale |
| `GAME_DESIGN.md` | §2 | the index stroke's four rotations *are* the four hues, so mirroring swaps `teal` and `rose`; pip accretion N→E→S→W is game state |
| `GAME_DESIGN.md` | §13.5 | the glyph's four registers and the screen-frame convention the raster test measures in |
| `GAME_DESIGN.md` | §4.2 | the Bridge's leading socket is always `cur` and carries no ghost toggle — the positional meaning the wedge's flip preserves |
| `GAME_DESIGN.md` | §11.2 | Codex grid reading order mirrors; the **plate's internal rule-tile layout does not**, because it is the law's rendering |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 | why the Assay's pinned slice is app-layer and the table is core — the source order this task asserts belongs to the core value, the visual direction to the view |

The mirroring table is §12.8's and is not restated in code. Cite it in the one comment that needs it
and in the test suite's doc comment.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/MirroringTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import Glyphs
import Tokens
import HunchUI
import HunchCore

/// §12.8's table, both columns, as assertions. The left column ("mirrors in Arabic") is checked by
/// frame geometry; the right column ("does not mirror, in any locale") is checked by rasterising
/// the same drawing in both directions and demanding they are identical.
@Suite("RTL — the chrome mirrors, the glyph never does", .tags(.snapshot, .presubmission))
@MainActor
struct MirroringTests {

    // MARK: - The right-hand column: drawings that must be byte-identical in both directions

    /// The whole deck. `coverageMask` already takes a `layout:` (E04·T02) precisely so this test
    /// could be written; if a single glyph differs, a hue has been swapped in Arabic.
    @Test("All 256 glyphs rasterise identically in both layout directions")
    func glyphsNeverMirror() throws {
        let env = RenderEnv(theme: .dark)
        for glyph in Deck.all {
            let ltr = try coverageMask(glyph, side: 44, scale: 2, env: env, layout: .leftToRight)
            let rtl = try coverageMask(glyph, side: 44, scale: 2, env: env, layout: .rightToLeft)
            #expect(ltr.inkDifference(from: rtl) == 0, "\(glyph) mirrored")
        }
    }

    /// The two named reasons, asserted directly so a failure says *why* rather than *where*.
    /// 45° is `teal` and 135° is `rose` (§2); a horizontal mirror maps one onto the other.
    @Test("The index stroke's rotation is unchanged by direction",
          arguments: [Glyph.Hue.amber, .teal, .frost, .rose])
    func indexStrokeDoesNotMirror(_ hue: Glyph.Hue) {
        #expect(GlyphGeometry.indexStrokeAngle(hue, layout: .leftToRight)
             == GlyphGeometry.indexStrokeAngle(hue, layout: .rightToLeft))
    }

    /// Pip accretion is N → E → S → W and it is game state, not reading order.
    @Test("Pip node order is unchanged by direction", arguments: [Glyph.Pips.one, .two, .three, .four])
    func pipAccretionDoesNotMirror(_ pips: Glyph.Pips) {
        #expect(GlyphGeometry.pipNodes(pips, layout: .leftToRight)
             == GlyphGeometry.pipNodes(pips, layout: .rightToLeft))
    }

    // MARK: - The left-hand column: chrome that must mirror

    /// Source order is canonical; the visual direction follows the locale (§12.8). Index 0 sits at
    /// the LEADING edge, which is the largest x in RTL — so the frames' x-origins reverse while
    /// the array does not.
    @Test("The ribbon renders source order leading-to-trailing in both directions")
    func ribbonRendersInSourceOrder() throws {
        let probes = Ribbon.fixture(count: 6).probes
        let ltr = try RibbonLayout(probes: probes, width: 375, layout: .leftToRight).tileFrames
        let rtl = try RibbonLayout(probes: probes, width: 375, layout: .rightToLeft).tileFrames

        #expect(ltr.count == probes.count && rtl.count == probes.count)
        #expect(ltr.map(\.minX) == ltr.map(\.minX).sorted())                 // 0 leftmost
        #expect(rtl.map(\.minX) == rtl.map(\.minX).sorted(by: >))            // 0 rightmost
        #expect(zip(ltr, rtl).allSatisfy { $0.width == $1.width })           // nothing else changed
    }

    /// §12.8: "Assay grid horizontal order (cell 0 sits top-leading)".
    @Test("Assay cell 0 sits top-leading in both directions")
    func assayCellZeroIsTopLeading() {
        let ltr = AssayLayout(side: 64, layout: .leftToRight)
        let rtl = AssayLayout(side: 64, layout: .rightToLeft)
        #expect(ltr.frame(ofCell: 0).minX < ltr.frame(ofCell: 15).minX)
        #expect(rtl.frame(ofCell: 0).minX > rtl.frame(ofCell: 15).minX)
        #expect(ltr.frame(ofCell: 0).minY == rtl.frame(ofCell: 0).minY)      // rows never flip
    }

    /// The wedge is the one drawing that reads direction: it mirrors WITH its rail so its wide end
    /// still opens toward the larger socket (§12.8, both columns of the same row). Comparator
    /// meaning is positional and is therefore preserved by mirroring, not despite it.
    @Test("The wedge flips with its rail and keeps its wide end toward the larger socket",
          arguments: Comparator.allCases)
    func wedgeMirrorsWithItsRail(_ comparator: Comparator) {
        let ltr = WedgeShape(comparator: comparator, layout: .leftToRight)
            .path(in: CGRect(x: 0, y: 0, width: 40, height: 24))
        let rtl = WedgeShape(comparator: comparator, layout: .rightToLeft)
            .path(in: CGRect(x: 0, y: 0, width: 40, height: 24))
        #expect(ltr.boundingRect.size == rtl.boundingRect.size)
        #expect(WedgeShape.wideEndSide(comparator, layout: .leftToRight)
             != WedgeShape.wideEndSide(comparator, layout: .rightToLeft))
    }

    /// §11.2: the Codex plate's internal rule-tile layout is the LAW'S RENDERING and does not
    /// mirror, even though the grid it sits in does.
    @Test("A Codex plate's internal tile layout is identical in both directions")
    func codexPlateInternalsDoNotMirror() throws {
        let law = Corpora.exemplarLaw(band: .relational)
        let ltr = BenchLayout(law).tileFrames(at: 0.78, layout: .leftToRight)
        let rtl = BenchLayout(law).tileFrames(at: 0.78, layout: .rightToLeft)
        #expect(ltr == rtl)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/MirroringTests
```

Expect two shapes of failure and treat them differently:

- **Missing symbols** (`GlyphGeometry.indexStrokeAngle(_:layout:)`, `WedgeShape.wideEndSide`,
  `RibbonLayout.tileFrames`) — the seams this task adds. Add them.
- **`glyphsNeverMirror` failing** — a real bug in an existing drawing, and the most valuable
  outcome this task can have. `coverageMask` renders `GlyphCanvas` inside an environment carrying
  `\.layoutDirection`, so any `HStack` or `.frame(alignment:)` inside the glyph's own drawing will
  mirror it. Fix the drawing, not the test.

**Step 3 — implement.** The layout seams, the wedge's flip, and the `left`/`right` lint.

**Step 4 — green, then refactor.** Then run the app in Arabic (T05's override) and walk the Frame,
the Bench and the Codex. The test covers geometry; a person covers "does it feel like it was built
this way".

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/RibbonCanvas.swift` — `RibbonLayout` extracted as a value that takes `layout:` |
| modify | `Modules/Sources/HunchUI/AssayCanvas.swift` — `AssayLayout.frame(ofCell:)` |
| modify | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — `WedgeShape(comparator:layout:)` and `wideEndSide(_:layout:)` |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the handle side and the palette order use `leading`/`trailing` |
| modify | `Modules/Sources/MetaFeature/FrameView.swift` — instrument-bar key order and the chevron |
| create | `Modules/Tests/HunchUITests/MirroringTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — append the `left`/`right` check and the "only the wedge reads direction" check |
| modify | `tests.json` — six entries (glyphs never mirror, index stroke, pips, ribbon source order, Assay cell 0, wedge) |
| modify | `DECISIONS.md` — why `layoutDirection` is not a `RenderEnv` field |

## Implementation notes

### The one architectural decision, stated once

**Mirroring is a layout concern and is never a drawing concern.** Chrome mirrors for free because it
is built out of SwiftUI stacks with `leading`/`trailing` alignment, and SwiftUI mirrors those from
`\.layoutDirection` without being asked. Drawings do not mirror because a `Canvas`'s coordinate
space is not mirrored by SwiftUI at all — `+x` is `+x` in both directions — which is exactly the
property that makes "the glyph never mirrors" free rather than defended.

That is why `layoutDirection` is **not** added to `RenderEnv`. `RenderEnv` is the seven-field
accessibility-and-theme record every drawing takes; adding direction to it would hand every glyph,
every mark and every rule-tile the ability to mirror itself, which is the thing §12.8 forbids.
Instead, exactly one drawing reads `@Environment(\.layoutDirection)` — the wedge — and a hygiene
check keeps that number at one. Record this in `DECISIONS.md`; it is the kind of decision that gets
reversed by someone adding "just one more field".

### The chrome that mirrors, and how

Nothing in this column needs code. It needs the *absence* of the code that would break it:

| §12.8 row | How it mirrors |
|---|---|
| instrument-bar key order; the chevron | an `HStack` with the leading key first; SF Symbols with `.imageScale` mirror automatically |
| commit bar order (PROBE · twin · Bench) | an `HStack`; the Left-hand keys preference (§12.6) is a *separate* reversal that composes with this one, and E17·T06 owns it |
| Bench handle side; palette order; rail leading edge | `.frame(maxWidth: .infinity, alignment: .leading)` |
| Settings rows, disclosure chevrons | stock `Form`; free |
| Codex grid reading order | `LazyVGrid`; free |
| Assay grid horizontal order | `AssayLayout` computes it, because the Assay is one `Canvas` and a `Canvas` is not mirrored for you |

The two that need real code are the last one and the ribbon, and both for the same reason: they are
single `Canvas`es drawn from a source array, so the mirroring that a stack gets for free has to be
computed. That is `RibbonLayout` and `AssayLayout`, extracted as values so the test above can exist:

```swift
/// Source order is canonical (§12.8); the visual direction follows the locale. Index 0 is at the
/// LEADING edge, which is `maxX - pitch` in RTL and `0` in LTR — and the array is never reversed,
/// because reversing it would also reverse the link arcs, the twin adjacency and the ghost mark.
struct RibbonLayout {
    let probes: [Probe]
    let width: Double
    let layout: LayoutDirection

    var tileFrames: [CGRect] {
        probes.indices.map { index in
            let offset = Double(index) * C.Ribbon.pitch
            let x = layout == .leftToRight ? offset : width - offset - C.Ribbon.tileSide
            return CGRect(x: x, y: 0, width: C.Ribbon.tileSide, height: C.Ribbon.tileSide)
        }
    }
}
```

**Never `probes.reversed()`.** Reversing the array is the tempting one-line version and it is wrong
in three ways at once: the trailing tile is the one that wears the ghost mark (§6.2), a twin is an
*adjacent* re-probe (E07·T08), and the return elbow on the Pro Max's second lane joins the last tile
of lane one to the first of lane two. All three are defined over source order. Mirror the geometry,
never the sequence.

### The wedge — the one drawing that reads direction

§12.8 puts the wedge in **both** columns, and reading it as a contradiction is the mistake to avoid.
It mirrors *with its rail*, so that after the rail has mirrored, the wedge's wide end still opens
toward the larger socket — the comparator's meaning is positional, and mirroring the glyph-level
drawing is what preserves it:

```swift
struct WedgeShape: Shape {
    let comparator: Comparator
    let layout: LayoutDirection

    /// Which physical side the wide end sits on, once the rail has mirrored. This is the whole
    /// claim of §12.8's wedge row, and it is a separate function so the test can assert it without
    /// reading a path.
    static func wideEndSide(_ comparator: Comparator, layout: LayoutDirection) -> HorizontalEdge {
        let towardLeading = comparator.opensTowardLeadingSocket
        return (towardLeading == (layout == .leftToRight)) ? .leading : .trailing
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // …draw in the leading-to-trailing frame…
        guard layout == .rightToLeft else { return path }
        return path.applying(CGAffineTransform(scaleX: -1, y: 1)
            .concatenating(CGAffineTransform(translationX: rect.width, y: 0)))
    }
}
```

The Bridge's **leading socket is always `cur`** and carries no ghost toggle (§4.2, RNF rule 3); the
ghost toggle is on the trailing socket only. Those are positional facts stated in `leading`/
`trailing` terms already, so they need nothing here — but they are why the wedge's flip is safe:
after mirroring, "leading socket" is still the socket the grammar means.

### The two hygiene checks

Determine the next free numbers (`grep -oE '^# +[0-9]+\.' Scripts/check-source-hygiene.sh | tail -1`)
and append both:

```bash
# N. leading/trailing only, left/right never — §12.8's closing rule. SwiftUI's own vocabulary has
#    no `.left` or `.right` for alignment or edges, so any hit is either UIKit reaching in or a
#    hand-rolled assumption about which way x grows.
if [ "${#uiRoots[@]}" -gt 0 ]; then
  sided='\.(left|right)\b|NSTextAlignment|UIRectEdge|leftAnchor|rightAnchor|leftBarButton|rightBarButton'
  hits=$(grep -rHnE "$sided" --include='*.swift' "${uiRoots[@]}" | grep -vE 'RTL-EXEMPT' || true)
  [ -n "$hits" ] && report 'left/right in a mirrored app (§12.8) — use leading/trailing:' "$hits"
fi

# N+1. Exactly one drawing may read layoutDirection: the wedge (§12.8). Mirroring is a LAYOUT
#      concern; a Canvas that can be told about direction is a Canvas that can mirror a glyph.
if [ -d Modules/Sources/HunchUI ]; then
  hits=$(grep -rHn 'layoutDirection\|LayoutDirection' --include='*.swift' Modules/Sources/HunchUI \
         | grep -vE 'RuleTileCanvas\.swift|RibbonCanvas\.swift|AssayCanvas\.swift|LanguageResolution\.swift' || true)
  [ -n "$hits" ] && report 'A drawing that can be told about direction (§12.8):' "$hits"
fi
```

The allowlist in the second check is exactly four files and each earns its place: the wedge lives in
`RuleTileCanvas.swift`, the two mirrored `Canvas`es compute their own geometry, and
`LanguageResolution.swift` is where the value comes from. `GlyphCanvas.swift` is deliberately absent
and E04·T02's acceptance criteria already assert it contains no `LayoutDirection` at all — this
check is that assertion generalised to the whole target.

Prove both by planting: a `.padding(.left, 8)` in `FrameView.swift`, and an
`@Environment(\.layoutDirection)` in `GlyphCanvas.swift`. Paste the output into the PR body.

### What to look at by hand

Run the app in Arabic and check the four things a geometry test cannot see:

1. **The Bench's handle and its drag direction.** The handle side mirrors; the pull-up gesture does
   not, because up is up (§4.2's 380 ms interactive drag).
2. **The par tick row's fill direction.** It fills leading → trailing, which in Arabic means from
   the right — and the crossing inversion at par must still read as an inversion, not a reversal.
3. **The Codex shelf's rail scrubber.** It snaps to skeleton sections (§11.2); in RTL the scrubber
   travels the other way and the sections must stay in the same order.
4. **The counterexample's docked island** below the ribbon, which is pinned to the trailing edge in
   both directions.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/MirroringTests` green — all seven tests, including 256 glyph pairs at zero ink difference.
- [ ] `grep -rn 'LayoutDirection\|layoutDirection' Modules/Sources/HunchUI/GlyphCanvas.swift Modules/Sources/HunchUI/GlyphShape.swift` returns nothing.
- [ ] `grep -rn 'reversed()' Modules/Sources/HunchUI/RibbonCanvas.swift Modules/Sources/HunchUI/AssayCanvas.swift` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` green, and both planted violations — a `.padding(.left,` and an `@Environment(\.layoutDirection)` in `GlyphCanvas.swift` — make it exit 1 naming their checks. Output in `.github/pr-body.md`.
- [ ] `DECISIONS.md` records why `layoutDirection` is not a `RenderEnv` field.
- [ ] `PROGRESS.md` records the four hand-checked items above, run in Arabic on the simulator.
- [ ] `tests.json` carries the six entries.
- [ ] The fast suite is still under 10 s (this suite is `Modules`, not `HunchCore`).

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T06: RTL — chrome mirrors, glyphs never do, and the wedge flips with its rail"`

## Out of scope

- **The drawings themselves.** The index stroke is **E04·T04**, pip accretion **E04·T02**, the
  wedge's six comparator states **E09·T02**, the ribbon **E08·T05**, the Assay **E09·T05**. This
  task adds a `layout:` parameter to three layout seams and one `Shape`, and asserts the rest.
- **The Left-hand keys preference**, which reverses the commit bar independently of locale —
  **E17·T06**. The two compose; neither is the other.
- **Setting `layoutDirection` on the root** — **T05**.
- **Pseudolocale RTL runs (`-AppleTextDirection YES`)** — **T09**. That exercises the *process*
  direction, which is a different path from the in-session override and finds different bugs.
- **Arabic typography — no small caps, no tracking, taller lines** — **T07**.
- **VoiceOver traversal order under RTL** — **E19·T01**. The rotor order follows the element order,
  which follows source order, which this task fixes as canonical.
