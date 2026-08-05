# T10 — App icon and launch screen

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T09 |
| **Delivers** | App icon (§14.5 decision 7) · the cold-launch budget re-measured |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-sigil-drawing` | The icon is a sigil in everything but its output format, and this skill owns the grammar it must obey: `references/sigil-grammar.md`'s stage box, its four ink roles and the ink budget that stops a mark going muddy at small sizes; `references/mode-sigils.md` gives `mode.probe` — *one stroke entering a ring* — and the ruling that a shipped drawing is **never redrawn** (`mode.probe`'s proportions are carried verbatim from the mockup precisely so the two cannot diverge). `scripts/check-sigil-distinctness.js` is the existing harness for "is this mark still legible at 22 pt", and the icon's 29 pt check is the same question with a different `T`. |
| `hunch-glyph-renderer` | The glyph half-entering the ring must be a real glyph, from the shipped four-pass renderer, at a size in the shipped ladder — not an outline someone traced. The skill owns the pass order (halo, ink, pip knockout, index stroke **last**), the two size regimes, and `C.Glyph.bleed(side:in:)`, which decides how much of the glyph can sit outside the ring before its index stroke clips. Its "Never" list has *never give a glyph an image asset* on it, which is exactly what this task is one careless export away from doing. |
| `hunch-design-tokens` | Brass on near-black is `accent.brass` on `ground.base` in the **dark** palette, and the icon is the second and last sanctioned duplication of a token value outside `Tokens/` — E17·T05 established the first (the launch colour sets) and its rule: the duplication is written into `palette.md` so `check-tokens.swift` knows about it and the day the palette moves, the asset moves with it. |
| `hunch-build-and-ci` | `08 §1`'s tree says `App/Assets.xcassets` holds `AppIcon` **plus the launch colours and nothing else**; `01 P33`/`P37` ban a glyph asset in any form; and an icon with an alpha channel is `ITMS-90717`, an upload rejection that burns a build number before review sees the build. This skill also owns the run-script rules that decide whether the icon is generated at build time (it is not) or committed (it is). |

## Objective

At the end of this task the app has an icon: the throat ring in `accent.brass` on `ground.base`, with
one glyph half-entering it, **rendered by the shipped drawing code** rather than drawn again in a
graphics tool — so it cannot drift from the machine it depicts — opaque, with no alpha channel
anywhere, and legible at 29, 60 and 1024 pt with all three sizes reviewed by eye and one of them
checked mechanically. And the cold-launch budget E17·T05 measured is re-measured against everything
this epic has added: an audio engine, a haptic engine, a Metal library and a gallery, none of which may
appear on the launch path.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §14.5 decision 7 | *"the throat ring in brass on near-black with one glyph half-entering it, tested at 29, 60 and 1024 pt before anything else is drawn"* — and the two rejected options with their reasons: a single glyph is the game's own language but illegible at 29 pt; the ring alone is legible and generic |
| `GAME_DESIGN.md` | §13.2 | `accent.brass` and `ground.base`, dark theme; register segregation — the ring is chrome-register, the glyph is hue-register, and the icon is the one composition where they are adjacent |
| `GAME_DESIGN.md` | §13.1 | what the icon may not be: no gradient, no soft shadow, no rounded-rect card, no material, no emoji, no SF Symbol, no system blue |
| `GAME_DESIGN.md` | §13.5 | the glyph's geometry, the four registers, the bleed — the icon's glyph is a real glyph or it is a lie about the game |
| `GAME_DESIGN.md` | §12.2 (screen 1) | `LaunchSurface`: wordmark, one brass hairline, dark ground, **storyboard, no code**, exit auto ≤ 400 ms — **E17·T05 shipped it; this task re-measures it and re-authors nothing** |
| `GAME_DESIGN.md` | §12.9 | `CFBundleDisplayName` is "HUNCH" in all twelve locales including Arabic — a wordmark, not a word; the icon carries no character in any locale either |
| `GAME_DESIGN.md` | §14.4 | no image assets — the icon is the single, stated exception and is not a precedent for a second |
| `.claude/skills/hunch-release/references/rejection-triggers.md` | §7 | `ITMS-90717`: an icon with an alpha channel or transparency is an **upload** rejection, before review; the single most common way to burn a build number on a first submission |
| `.claude/skills/hunch-sigil-drawing/references/sigil-grammar.md` | stage, ink roles, ink budget | the drawing grammar the composition obeys |
| `.claude/skills/hunch-bench-instruments/references/throat.md` | §1 | the throat ring's geometry and the sizes it ships at; the Frame's idle Loom is a 128 pt throat ring with **one glyph drifting through it**, which is the icon's own composition already shipped |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B15`, `B17`, `B44`, `B45` | why the icon is generated by a committed tool run rather than by a build phase; images belong in an asset catalog; the size implications |

## TDD — the test comes first

The deliverable is a PNG, and a PNG is exactly the kind of artefact that drifts silently from the code
it was supposed to come from. So the tests are about *provenance* and *legibility*, and both can fail:

- **Provenance** — the shipped asset is byte-identical to a fresh render from the shipped drawing code.
  Plant a hand-edited pixel and the check goes red. That is the mechanical form of "rendered from the
  shipped drawing code rather than redrawn".
- **Opacity** — every pixel's alpha is 255 and the file carries no alpha channel at all. Plant a
  transparent corner and the check goes red, here, rather than at `ITMS-90717` after an archive.
- **Legibility** — measured at 29 pt @3×, where the question is whether the ring's stroke survives
  rasterisation and whether the composition is still separable from a plain ring.

**Step 1 — write the failing test.** Create `HunchTests/AppIconTests.swift` — the wizard-made host-app
bundle, which `01 P22`/`P40` keep nearly empty and this is the second thing it is for (E18·T08 put
`InfoPlistTests` there for the same reason: it must read the *built product*):

```swift
import CoreGraphics
import ImageIO
import XCTest
@testable import HunchUI

/// XCTest, in the app bundle, because every assertion here is about the artefact the build
/// produced — not about a struct. A package test would render its own copy and prove nothing.
final class AppIconTests: XCTestCase {

    private func shippedIcon() throws -> CGImage {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "icon-1024", withExtension: "png"),
                                "the icon is not in the built product")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    // MARK: provenance — the assertion that makes "from the shipped drawing code" checkable

    @MainActor
    func testTheShippedIconIsWhatTheDrawingCodeProduces() throws {
        let shipped = try shippedIcon()
        let rendered = try XCTUnwrap(AppIconArtwork.render(side: 1024))
        XCTAssertEqual(shipped.width, rendered.width)
        XCTAssertEqual(shipped.height, rendered.height)
        // A hash, not a pixel walk: a mismatch is a mismatch and the diff is the regenerate step.
        XCTAssertEqual(try sha256(of: shipped), try sha256(of: rendered),
                       "the committed icon is not what AppIconArtwork draws — re-run "
                       + "Scripts/render-app-icon.swift rather than editing the PNG")
    }

    // MARK: opacity — ITMS-90717, caught here instead of at upload

    func testTheIconIsFullyOpaqueAndCarriesNoAlphaChannel() throws {
        let image = try shippedIcon()
        XCTAssertEqual(image.alphaInfo, .noneSkipLast,
                       "an icon with an alpha channel is ITMS-90717, an upload rejection")
        let pixels = try samples(of: image)
        XCTAssertTrue(pixels.allSatisfy { $0.alpha == 255 })
        // …and not merely opaque-by-flattening: the corners must be the ground, not black-on-white.
        XCTAssertEqual(pixels.first!.rgb, Palette(theme: .dark).ground.base)
    }

    func testTheIconIs1024SquareSRGB() throws {
        let image = try shippedIcon()
        XCTAssertEqual(image.width, 1024)
        XCTAssertEqual(image.height, 1024)
        XCTAssertEqual(image.bitsPerComponent, 8)
        XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
    }

    // MARK: legibility — the 29 pt question, asked mechanically

    @MainActor
    func testTheRingSurvivesRasterisationAt29pt() throws {
        // 29 pt @3× is 87 px. The ring's stroke must land on at least one whole device pixel or
        // it dissolves into the ground and the icon becomes a brass smudge.
        let strokePx = AppIconArtwork.ringStrokeWidth(side: 87)
        XCTAssertGreaterThanOrEqual(strokePx, 1.0)
        let raster = try XCTUnwrap(AppIconArtwork.render(side: 87))
        let coverage = try inkCoverage(of: raster, against: Palette(theme: .dark).ground.base)
        // Not a dot, not a blob. The band is stated, and it is the same shape of budget
        // `check-sigil-distinctness.js` uses for the 22 sigils.
        XCTAssertGreaterThan(coverage, AppIconArtwork.minimumInkCoverage)
        XCTAssertLessThan(coverage, AppIconArtwork.maximumInkCoverage)
    }

    @MainActor
    func testTheGlyphIsSeparableFromAPlainRingAtEverySize() throws {
        // §14.5 rejected "the empty throat ring" as generic. If the glyph is not distinguishable
        // at 29 pt, we shipped the option we rejected.
        for side in [87.0, 180.0, 1024.0] {              // 29 @3×, 60 @3×, 1024 @1×
            let withGlyph = try XCTUnwrap(AppIconArtwork.render(side: side))
            let ringOnly = try XCTUnwrap(AppIconArtwork.render(side: side, includeGlyph: false))
            let distance = try l1Distance(withGlyph, ringOnly)
            XCTAssertGreaterThanOrEqual(distance, AppIconArtwork.separationFloor,
                                        "at \(side) px the icon is indistinguishable from a bare ring")
        }
    }

    // MARK: the composition is the shipped one, not a lookalike

    @MainActor
    func testTheGlyphComesFromTheShippedRendererAndIsHalfEntering() throws {
        XCTAssertEqual(AppIconArtwork.glyph, Glyph(id: AppIconArtwork.glyphID))
        // "half-entering": the glyph's centre sits on the ring's contour, within a stated tolerance.
        let overlap = AppIconArtwork.glyphOverlapFraction
        XCTAssertEqual(overlap, 0.5, accuracy: 0.05)
        // And it is a real glyph: all four registers are drawn, index stroke included.
        XCTAssertEqual(AppIconArtwork.drawnRegisters, Set(Glyph.Attribute.allCases))
    }

    @MainActor
    func testTheIconUsesTheTwoTokensAndNoOthers() throws {
        let dark = Palette(theme: .dark)
        XCTAssertEqual(Set(AppIconArtwork.inks), [dark.accent.brass.rgb, dark.ground.base,
                                                  AppIconArtwork.glyphHue.rgb])
    }
}
```

And re-arm E17·T05's launch measurement against this epic's additions —
`HunchUITests/LaunchPerformanceTests.swift`, extended rather than replaced:

```swift
/// E17·T05 recorded the ≤ 400 ms baseline. E20 added an AVAudioEngine, a CHHapticEngine, a Metal
/// library and a DEBUG gallery. None of them may appear on the launch path; this is the assertion
/// that says so, and it fails on the regression rather than on a stopwatch.
@MainActor
func testNothingThisEpicAddedIsOnTheLaunchPath() {
    let app = XCUIApplication()
    app.launchArguments += ["-UITest", "-HunchLaunchProbe"]     // dumps a launch-path manifest
    app.launch()
    let manifest = LaunchProbe.read(from: app)
    XCTAssertFalse(manifest.contains("AVAudioEngine"))          // §13.8: lazy on the first cue
    XCTAssertFalse(manifest.contains("CHHapticEngine"))         // T06: lazy on the first cue
    XCTAssertFalse(manifest.contains("MTLLibrary"))             // T07: the shader is not the first frame
    XCTAssertFalse(manifest.contains("GalleryRow"))             // #if DEBUG, and not reached
}
```

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" -only-testing:HunchTests/AppIconTests | xcbeautify
xcodebuild test … -only-testing:HunchUITests/LaunchPerformanceTests | xcbeautify
```

Expect `cannot find 'AppIconArtwork' in scope` and, once it exists, a failing
`testTheShippedIconIsWhatTheDrawingCodeProduces` because no PNG has been generated yet. Two failures
worth stopping on:

- **`testTheIconIsFullyOpaqueAndCarriesNoAlphaChannel` failing on `alphaInfo`** after the first export
  is the normal state, not a surprise: `ImageRenderer` produces a premultiplied-alpha image by default
  and every drawing tool keeps its alpha. The fix is in the exporter's bitmap context, and this is the
  single most valuable assertion in the file.
- **`testTheGlyphIsSeparableFromAPlainRingAtEverySize` failing at 87 px** means the composition is the
  option §14.5 rejected. Do not lower `separationFloor`; change the glyph's size, its position on the
  contour, or its hue rank until the mark reads.

**Step 3 — implement.** `AppIconArtwork` first (it is drawing code and lives with the drawing code),
then the exporter, then the committed PNG, then the catalog entry.

**Step 4 — green, then look at it at all three sizes.** §14.5 says *tested at 29, 60 and 1024 pt*, and
that is a human sentence. Install to a device, look at the Home screen, look at Settings' list, look at
Spotlight, and look at the 1024 in App Store Connect's preview. Record all three in `PROGRESS.md`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/AppIconArtwork.swift` — the composition, in the same `Canvas`/`draw(into:)` vocabulary as every other mark |
| create | `Scripts/render-app-icon.swift` — the committed tool run that writes the PNG |
| create | `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` — the single opaque 1024 × 1024 sRGB image |
| modify | `App/Assets.xcassets/AppIcon.appiconset/Contents.json` — one entry, `ios-marketing`, single size |
| create | `HunchTests/AppIconTests.swift` |
| modify | `Modules/Tests/HunchUITests/LaunchPerformanceTests.swift` — the launch-path assertion |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — the `-HunchLaunchProbe` manifest, `#if DEBUG` |
| modify | `Modules/Sources/HunchUI/DebugGallery/GalleryRow.swift` — an `appIcon` row, three sizes, so the icon is on the sheet like everything else |
| modify | `.claude/skills/hunch-design-tokens/references/palette.md` — the icon's token duplication, alongside E17·T05's launch colours |
| modify | `PROGRESS.md` — the icon reviewed at 29 / 60 / 1024 pt, dated, with the build; the re-measured cold launch |
| modify | `DECISIONS.md` — the icon's derivation from shipped drawing code; the packaging ruling |
| modify | `tests.json` — `icon.derived-from-shipped-code`, `icon.opaque`, `icon.legibility`, `launch.cold-start-budget` |

## Implementation notes

### "From the shipped drawing code" is a mechanism, not an intention

The icon depicts the machine. If it is traced in a graphics tool, it depicts the machine *as it was on
the day someone traced it* — and this project has spent nineteen epics making sure no fact has two
homes. So:

```swift
// Modules/Sources/HunchUI/AppIconArtwork.swift
/// §14.5 decision 7's composition, drawn by the same code that draws the Frame's idle Loom:
/// a throat ring with one glyph entering it. Nothing here is a new drawing — the ring is
/// `ThroatRing.draw`, the glyph is `GlyphCanvas`'s four passes, and the two inks are
/// `accent.brass` and `ground.base` from the dark palette.
///
/// It is `@MainActor` and lives in `HunchUI` rather than in `Scripts/` for one reason: an
/// exporter that owns its own drawing is a second implementation, which is the drift this
/// whole library exists to prevent.
@MainActor
public enum AppIconArtwork {
    /// The seed glyph of the opening round (§12.5): hollow triangle, two pips, frost — id 22.
    /// It is already the first mark every player sees, and reusing it costs nothing and means
    /// something.
    public static let glyphID = 22

    public static func draw(into context: inout GraphicsContext, side: Double,
                            includeGlyph: Bool = true) {
        let env = RenderEnv(theme: .dark)               // the icon has one appearance, always
        context.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)),
                     with: .color(env.palette.ground.base.color))   // OPAQUE ground, first
        ThroatRing.draw(into: &context, centre: ringCentre(side), radius: ringRadius(side),
                        ink: env.palette.accent.brass, weight: ringStrokeWidth(side: side))
        guard includeGlyph else { return }
        GlyphCanvas.draw(into: &context, glyph: Glyph(id: glyphID),
                         side: glyphSide(side), origin: glyphOrigin(side), env: env)
    }
}
```

Three things it is careful about:

- **The ground is filled first and covers the whole square.** An icon is opaque by construction here,
  not by a flatten step in an exporter, which is what makes `testTheIconIsFullyOpaqueAndCarriesNoAlpha`
  a statement about the drawing rather than about the export settings.
- **`includeGlyph: false` exists for the test**, and it is the cheapest possible way to ask "is this
  distinguishable from the option §14.5 rejected".
- **The dark palette, hardcoded, deliberately.** An icon does not have a theme; passing `env` in from
  outside would invite someone to render a light-theme icon that App Store Connect would then show on
  a white sheet. Record the choice in the doc comment where the next person will read it.

### The one thing the icon may not inherit: bloom

`GlyphCanvas`'s bloom pass is a widened low-opacity stroke plus, in dark, an offscreen blurred bed
(`env.isBloomEnabled` / `isBloomBedEnabled`). At 1024 px it looks lovely. At 87 px it is a smear that
collapses the ink budget and makes the ring and the glyph merge — which is the failure
`testTheRingSurvivesRasterisationAt29pt` catches. The glyph renderer already has an `S ≥ 32` geometry
gate on bloom; the icon renders the small sizes below that gate anyway and the 1024 with bloom **off**,
so all three sizes are the same drawing. Say so in the code, because "turn bloom on for the big one"
is the obvious and wrong improvement: the App Store's 1024 and the Home screen's 87 must be recognisably
the same mark.

### The exporter, and why it is a committed tool run rather than a build phase

```bash
swift Scripts/render-app-icon.swift          # writes App/Assets.xcassets/…/icon-1024.png
```

A run-script build phase would re-run on every incremental build (`07 B15` rule 2, since it has no
meaningful inputs), it would write across the source root, which `ENABLE_USER_SCRIPT_SANDBOXING = YES`
denies (`07 B14`), and it would mutate a file underneath the compiler mid-build (`07 B17`'s third
reason). Every one of those is already ruled on for the formatter and the same reasoning applies
verbatim.

So the PNG is **committed**, and `testTheShippedIconIsWhatTheDrawingCodeProduces` is what makes a
committed artefact safe: it can only be stale for as long as it takes CI to run. Regenerating is a
deliberate act and the failure message says so.

`Scripts/render-app-icon.swift` is a Swift script, which is a sanctioned shape here — E18·T08's
`check-banned-lexemes.swift` and `hunch-design-tokens`' `check-tokens.swift` run the same way, and no
dependency is added. It builds a `CGContext` with `CGImageAlphaInfo.noneSkipLast` — **the whole
opacity guarantee is that one constant** — draws through `AppIconArtwork`, and writes with
`CGImageDestination` at `kUTTypePNG`.

### `AppIcon.icon` versus `AppIcon.appiconset`, ruled

`08 §1`'s tree writes `Assets.xcassets  AppIcon.icon`, which is Xcode 26's Icon Composer document: a
layered artefact with appearance variants, specular highlights and a glass treatment. Every one of
those is on §13.1's forbidden list — *no gradients, no material, no soft shadow* — and a layered
document is a second place the drawing lives.

**Ruling: ship a single-size 1024 × 1024 opaque PNG in an `AppIcon.appiconset`, and record the
deviation from `08 §1`'s spelling in `DECISIONS.md`.** Single-size asset catalogs have been the
supported shape since Xcode 14 — the system derives every smaller size — so this costs nothing and
buys the property the tests rest on: one file, one renderer, no layer stack. If Icon Composer is
adopted later, the same PNG becomes its single flat layer and every appearance variant stays disabled;
the provenance test survives that change unmodified, which is the check that the ruling is not painting
us in.

`App/Assets.xcassets` then holds `AppIcon` plus E17·T05's two launch colour sets and nothing else —
`08 §1`'s "AppIcon + launch colour ONLY", asserted by an acceptance criterion below and by `01 P33`'s
ban on a glyph asset in any form. **This is the app's only image, and it is not a precedent.**

### Legibility at three sizes — what each one is actually testing

| Size | Where it appears | What can go wrong |
|---|---|---|
| **29 pt** | Settings' list, Spotlight | the ring's stroke falls below one device pixel and dissolves; the glyph and the ring merge into a brass dot |
| **60 pt** | the Home screen | the composition reads, but the glyph's index stroke clips against the icon's edge — `C.Glyph.bleed(side:in:)` is the derivation, and frost's stroke reaches `0.5665·S` |
| **1024 pt** | App Store Connect | nothing rasterises away, so this is where a *composition* problem shows: too much air, an off-centre ring, a glyph that reads as decoration rather than as entering |

The mechanical checks cover the first (stroke width against the 87 px raster, ink coverage in a band)
and the separability of all three. The second and third are eyes, and §14.5's wording — *tested at 29,
60 and 1024 pt* — is a human sentence that a coverage number does not discharge. Record all three.

The glyph's placement — *half-entering* — is the one number this task introduces, and it is stated as
a fraction rather than a point value so it holds at every size:
`AppIconArtwork.glyphOverlapFraction = 0.5`, meaning the glyph's body centre sits on the ring's
contour. `mode-sigils.md`'s rule for `mode.probe` is the precedent and the reasoning transfers exactly:
*a stroke that stops at the contour reads as a pointer; one that crosses it reads as a probe going in.*
A glyph tangent to the ring reads as a glyph next to a ring.

### The cold-launch re-measurement

E17·T05 measured `XCTApplicationLaunchMetric` against a ≤ 400 ms budget and recorded the baseline in
`Presubmission.xctestplan`. This epic added four things that could each blow it, and the re-measurement
is not a formality:

| Risk | Why it would not show in a unit test | The guard |
|---|---|---|
| `AVAudioEngine` instantiated at composition-root construction | `AppDependencies.live()` runs before the first frame | §13.8's lazy start (T04): no audio unit before the first cue |
| `CHHapticEngine()` created in `HapticCuePlayer.init` | the capability check is cheap; the engine is not | T06: the engine is created on the first *permitted* cue, and `isSupported` is a `let` |
| the Metal library compiled on the launch path | `ShaderLibrary` is lazy, but a `TimelineView` on the first frame is not | T07: `amount == 0` returns `self` unmodified, and the surface is not the launch surface |
| the DEBUG gallery's registry evaluated | a `static let` of 30-odd rows is cheap until a specimen list is built eagerly | `#if DEBUG` and reached only from a debug affordance (E04·T09) |

The launch-path assertion is a manifest rather than a stopwatch because a stopwatch on CI hardware is a
flake. `-HunchLaunchProbe` records the type names constructed before the first frame is presented and
writes them where the UI test can read them; the four assertions are absences, and absences are what a
regression here looks like.

Re-run the measurement on the **iPhone SE (3rd generation)** — the same device T07 measured the shader
on and the same reference device §6.2 uses — and record the figure in `PROGRESS.md` next to the
original so the delta is visible. If it regressed, the fix is upstream in whichever of the four moved,
never a lengthened budget: E17·T05 says so and this task does not get to relitigate it.

**The launch screen itself is not re-authored.** `App/LaunchScreen.storyboard`, its two colour sets and
the `INFOPLIST_KEY_UILaunchStoryboardName` wiring are E17·T05's, shipped and unchanged. If the icon
work tempts you to "make the launch screen match" — it already does: one brass hairline on a dark
ground is the same two tokens.

### Five ways to get this wrong, all of which ship

- **Exporting with alpha.** `ITMS-90717`, an upload rejection, after an archive, costing a build
  number. The test is three lines and it is worth more than the rest of this file.
- **Adding a second image asset "while we're in the catalog".** `01 P33`/`P37` and §14.4. The icon is
  the exception; nothing else is.
- **Rounding the icon's own corners.** iOS masks the icon; a pre-rounded square gets rounded twice and
  reads as a shrunken sticker.
- **Putting the wordmark in it.** §12.9 keeps the app wordless in every locale and `CFBundleDisplayName`
  already carries "HUNCH" under the icon on every Home screen. A wordmark in the icon is the same word
  twice.
- **Making the glyph a generic "shape" because a real one is busy at 29 pt.** Then it is not the game's
  language, and §14.5's rejected option 1 was rejected for being illegible *alone*, not for being real.
  If the shipped glyph is illegible at 29 pt in this composition, the answer is a lower-rank glyph —
  `hollow` fill and few pips — not a fake one.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchTests/AppIconTests` green, all seven tests.
- [ ] Planting one edited pixel in `icon-1024.png` makes `testTheShippedIconIsWhatTheDrawingCodeProduces` fail; planting a transparent corner makes `testTheIconIsFullyOpaqueAndCarriesNoAlphaChannel` fail. Both demonstrated and reverted, with the failure messages in the commit body.
- [ ] `sips -g hasAlpha -g pixelWidth -g pixelHeight -g space App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` reports `hasAlpha: no`, `1024 × 1024`, `sRGB`.
- [ ] `ls App/Assets.xcassets` shows `AppIcon.appiconset` plus exactly two colour sets and nothing else (`08 §1`, `01 P33`).
- [ ] `grep -rn 'Image(\|UIImage(\|NSImage(' Modules/Sources App --include='*.swift'` returns nothing — the icon is the only image and it is not loaded by code.
- [ ] `swift Scripts/render-app-icon.swift` reproduces the committed PNG byte-for-byte on a clean checkout.
- [ ] `xcodebuild test … -only-testing:HunchUITests/LaunchPerformanceTests` green: the ≤ 400 ms baseline holds and the four launch-path absences are asserted.
- [ ] `PROGRESS.md` records the icon reviewed at **29, 60 and 1024 pt** on a device and in App Store Connect's preview, with a date and a build number, and the re-measured cold-launch figure beside E17·T05's original.
- [ ] `DECISIONS.md` carries the icon's derivation from shipped drawing code, the `appiconset`-over-`.icon` packaging ruling with `08 §1`'s spelling named, and the glyph choice (id 22, the opening round's seed glyph) with its reason.
- [ ] `palette.md` records the icon's token duplication alongside E17·T05's launch colours, so `check-tokens.swift` knows about both.
- [ ] `GalleryRow.appIcon` is `.populated` at 87, 180 and 1024 px, so the icon is on the sheet like every other mark, and `GalleryCorpusTests` covers it.
- [ ] `tests.json` carries `icon.derived-from-shipped-code`, `icon.opaque`, `icon.legibility` and `launch.cold-start-budget`, each with a runnable command; the 29/60/1024 human review is `manual` with `PROGRESS.md` as its home.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Reject any suggestion that moves `AppIconArtwork` into `Scripts/`: an exporter that owns its own drawing is a second implementation and the provenance test becomes a tautology. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T10: the app icon rendered from the shipped drawing code, opaque and legible at 29/60/1024, and the cold-launch budget re-measured"`

## Out of scope

- `LaunchScreen.storyboard`, its two colour sets and the `INFOPLIST_KEY_UILaunchStoryboardName` wiring — **E17·T05**. This task re-runs that task's measurement and re-authors nothing.
- `XCTApplicationLaunchMetric`'s baseline mechanism and the ≤ 400 ms budget's derivation — **E17·T05**.
- The glyph renderer, its four passes, the bleed and the size regimes — **E04·T01–T05**. The icon calls them.
- The throat ring's geometry and the Frame's idle Loom — **E08**, **E17·T03**.
- The sigil grammar, the 22 sigils and `check-sigil-distinctness.js` — **E17·T04**; this task borrows the ink-budget idea and adds no sigil.
- `PrivacyInfo.xcprivacy`, the App Store metadata and the wordless screenshots — **T11**. The icon is metadata for review purposes but its file is a build input, and the two have different gates.
- Archiving, exporting and anything that would put this icon in front of App Store Connect — **`/hunch-release`, user-invoked only.**
