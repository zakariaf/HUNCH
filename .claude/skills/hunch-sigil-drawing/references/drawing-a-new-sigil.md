# Drawing a new sigil, and shipping it in Swift

The procedure, the one renderer all 22 marks go through, and the write-back that stops the next
person redrawing what you just drew.

1. [The procedure](#the-procedure)
2. [The Swift, HunchCore side](#the-swift-hunchcore-side)
3. [The Swift, app side](#the-swift-app-side)
4. [The tests](#the-tests)
5. [The write-back contract](#the-write-back-contract)
6. [Worked example](#worked-example)
7. [What would be wrong](#what-would-be-wrong)

---

## The procedure

**1. Prove it is undrawn.** `node ../scripts/check-sigil-distinctness.js --keys`. If a key exists,
the answer is that drawing — open its catalogue file and use it. Do not draw a variant.

**2. Prove it is a sigil.** A mark generated from `(fill, shape, pips, hue)` is a glyph and
belongs to `hunch-glyph-renderer`. A mark composed at more than one site by more than one screen
is a shared idiom and belongs to `hunch-shared-marks`. A sigil is an *authored identity* that
stands for a mode, a family, an axis or a facet, and nothing else in the app is one.

**3. Write the sentence before the geometry.** One line: *the primitives, the verb, and the move
it depicts*. If the sentence needs a fourth primitive or a second verb, the sigil is wrong
(`sigil-grammar.md` G2, G3). If the verb is already taken with the same primitive set, it is a
collision at the semantic level and no amount of pixel-shuffling will fix it.

**4. Compose from `MACRO` only.** `sigil-grammar.md` §4 is the vocabulary. Keep every centre-line
inside `authorBound`, and use `role` names, never weights.

**5. Add the entry to `SIGILS`** in `../scripts/check-sigil-distinctness.js`, at the end of its
set. Never renumber, never repurpose a key: keys are referenced from Swift raw values and from
four catalogue files.

**6. Measure.** `node ../scripts/check-sigil-distinctness.js --new <key>`. It gates three things —
pairwise distance ≥ `T`, ink coverage inside `[0.030, 0.34]`, and stage containment. `--svg <key>`
dumps the drawing if it fails and you want to see why. **A failure is a design answer, not an
obstacle**: two sigils that measure the same are the same sigil to a player glancing at a 22 pt
Codex strip.

**7. Write it back.** Add the prose section — meaning, states, VoiceOver, Reduce Motion, High
Contrast, wrongs — to exactly one of the four catalogue files, add the `case` **and its
transcribed coordinates** to Swift, and regenerate the parity fixture with `--json`. The harness
fails on a key with no section and on a key with two; the parity test fails if the Swift and
`SIGILS` disagree by a coordinate. This is the step the whole skill exists for; see §5 below.

## The Swift, HunchCore side

`HunchCore/Sources/Sigils/` — platform-free, no `import SwiftUI`, no `import UIKit`, exercised by
`swift test` with no simulator. One value type, one pure function, twenty-two cases.

```swift
// HunchCore/Sources/Sigils/Sigil.swift
public enum Sigil: String, CaseIterable, Sendable {
    case modeProbe = "mode.probe", modeDrift = "mode.drift"
    case modeEcho = "mode.echo",   modeSieve = "mode.sieve"
    case familyLiteral = "family.literal", familyPair = "family.pair"
    // … the raw value is the catalogue key in check-sigil-distinctness.js, and a test asserts it
}

public struct SigilPoint: Sendable, Equatable { public var x, y: Double }   // box fractions, y down

public struct SigilStroke: Sendable, Equatable {
    public enum Role: Sendable { case contour, verb, ghost, bar }
    public enum Form: Sendable, Equatable {
        case polyline([SigilPoint], closed: Bool)
        case filledPolygon([SigilPoint])
        case circle(centre: SigilPoint, radius: Double, filled: Bool)
        case arc(centre: SigilPoint, radius: Double, from: Double, to: Double)  // degrees, cw from East
    }
    public struct Dash: Sendable, Equatable { public var on, off: Double }

    public let form: Form
    public let role: Role
    public let opacity: Double
    public let dash: Dash?
}

/// `SkeletonSpec` must itself be `Sendable, Equatable` or the synthesis here does not fire.
public enum SigilDetail: Sendable, Equatable { case family, skeleton(SkeletonSpec) }

public enum SigilCatalogue {
    /// Pure, total, deterministic. Rotation is already applied.
    ///
    /// **Not authored by hand.** Every coordinate below is a transcription of `SIGILS` in
    /// `check-sigil-distinctness.js`, which is the normative home, and `catalogueMatchesTheHarness`
    /// asserts the transcription point for point against the committed `--json` fixture. Editing a
    /// number here without regenerating the fixture fails that test; editing both without editing
    /// `SIGILS` fails it too, because the fixture is generated from `SIGILS` and nothing else.
    public static func strokes(for sigil: Sigil, detail: SigilDetail = .family) -> [SigilStroke] { … }
}

extension SigilStroke.Role {
    /// The one weight rule: a sigil takes the glyph's own size regime (§13.5).
    ///
    /// Returns the *unresolved* token. `48` is the regime boundary and is the glyph renderer's,
    /// not a value this file may restate — `hunch-glyph-renderer/references/geometry.md` owns it,
    /// so ship this as `C.Glyph.isSmallRegime(side:)` the day that symbol exists.
    public func weight(boxSide side: Double) -> StrokeWeight {
        switch self {
        case .contour: .thin
        case .ghost: .hairline
        case .verb: side < 48 ? .bodySm : .body
        case .bar: side < 48 ? .body : .heavy
        }
    }
}
```

`StrokeWeight` is the **unresolved** token from `hunch-design-tokens`; it becomes a number only
at the call site, through `env.weight(_:)`.

## The Swift, app side

The adapter is the only file that knows SwiftUI exists — the same shape as the token layer's
`Color` adapter (scope §4.2).

```swift
// Hunch/Rendering/SigilRenderer.swift
import SwiftUI
import HunchCore

struct SigilRenderer {
    let env: RenderEnv                       // injected; never a singleton, never @Environment inside

    /// Draws one sigil into `box`.
    ///
    /// The context is taken **by value**, never `inout`: `fill` and `stroke` are non-mutating, this
    /// renderer sets no clip, opacity or transform, and an `inout` context is a licence for a future
    /// edit to leak one back to the host. Same rule, same reason as
    /// `hunch-shared-marks/references/ownership.md` §3.
    func draw(
        _ sigil: Sigil,
        detail: SigilDetail = .family,
        lit: Bool,
        into context: GraphicsContext,
        box: CGRect
    ) {
        let side = min(box.width, box.height)
        let ink = (lit ? env.palette.stroke.primary : env.palette.stroke.secondary).color
        let origin = CGPoint(x: box.midX, y: box.midY)
        let place = { (p: SigilPoint) in
            CGPoint(x: origin.x + p.x * side, y: origin.y + p.y * side)
        }

        for stroke in SigilCatalogue.strokes(for: sigil, detail: detail) {
            let paint = GraphicsContext.Shading.color(ink.opacity(stroke.opacity))
            var path = Path()
            switch stroke.form {
            case let .polyline(points, closed):
                path.addLines(points.map(place))
                if closed { path.closeSubpath() }
            case let .filledPolygon(points):
                path.addLines(points.map(place))
                path.closeSubpath()
                context.fill(path, with: paint)
                continue
            case let .circle(centre, radius, filled):
                let c = place(centre), r = radius * side
                path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                if filled { context.fill(path, with: paint); continue }
            case let .arc(centre, radius, start, end):
                path.addArc(center: place(centre), radius: radius * side,
                            startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
            }
            // butt cap, miter join, zero radius — PHOSPHOR §2 pass C, for every mark in the app
            var style = StrokeStyle(lineWidth: env.weight(stroke.role.weight(boxSide: side)),
                                    lineCap: .butt, lineJoin: .miter, miterLimit: 10)
            if let dash = stroke.dash { style.dash = [dash.on * side, dash.off * side] }
            context.stroke(path, with: paint, style: style)
        }
    }
}
```

**A sigil is drawn in a `Canvas`, never as a `Shape`.** A `Shape` yields one `Path` under one
`StrokeStyle`, and every sigil carries at least two roles at different weights. Wrapping it as a
`Shape` forces either one weight for the whole mark or one `Shape` per role, and the second is
four views where one `Canvas` would do.

```swift
// WRONG — collapses contour, verb and ghost to a single weight the moment it is stroked
struct SigilShape: Shape { func path(in r: CGRect) -> Path { … } }
```

`SigilRenderer` takes `env` as a stored property because `RenderEnv` is the seven-axis record
every token resolves against (`hunch-design-tokens/references/render-env.md`). Reading
`@Environment` inside the renderer would make it untestable and would leave the drawing dependent
on where it was instantiated.

## The tests

Swift Testing, not XCTest. All three run without a simulator and cost microseconds, which is what
keeps `swift test` under 10 s.

**The parity test is the load-bearing one.** A substring match on the raw value — `js.contains("'\(sigil.rawValue)':")`
— proves the *key* exists in the harness and says nothing whatever about the coordinates, so every
number in `SigilCatalogue` could drift silently while the test stayed green. It is replaced by a
decode-and-compare against the fixture the harness generates.

```swift
import Foundation
import Testing
@testable import HunchCore

/// The shape `check-sigil-distinctness.js --json` emits. Decoding-only, test-target-local:
/// nothing in the shipping app reads JSON geometry, so these types do not belong in Sources.
private struct HarnessDump: Decodable {
    struct Point: Decodable, Equatable { var x, y: Double }
    struct Stroke: Decodable {
        var role: String
        var opacity: Double
        var form: String
        var closed: Bool?
        var filled: Bool?
        var points: [Point]?
        var centre: Point?
        var size: Point?
        var radius: Double?
        var from: Double?
        var to: Double?
    }
    struct Sigil: Decodable { var rotate: Double; var strokes: [Stroke] }
    var sigils: [String: Sigil]
}

@Suite struct SigilCatalogueTests {
    /// Generated: `node check-sigil-distinctness.js --json > Fixtures/sigils.json`.
    /// CI asserts it is current; see the write-back contract below.
    private static func dump() throws -> HarnessDump {
        let url = try #require(Bundle.module.url(
            forResource: "sigils", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(HarnessDump.self, from: Data(contentsOf: url))
    }

    @Test func everySigilStaysInsideItsStage() throws {
        let half = SigilMetrics.stage / 2
        for sigil in Sigil.allCases {
            for stroke in SigilCatalogue.strokes(for: sigil) {
                for point in stroke.form.extremePoints {
                    #expect(abs(point.x) <= half && abs(point.y) <= half,
                            "\(sigil.rawValue) leaves the stage")
                }
            }
        }
    }

    /// The harness is the normative home of the geometry. This asserts Swift has not forked it —
    /// point for point, not key for key.
    @Test func catalogueMatchesTheHarness() throws {
        let dump = try Self.dump()
        #expect(Set(dump.sigils.keys) == Set(Sigil.allCases.map(\.rawValue)),
                "the fixture and Sigil.allCases disagree about which sigils exist")

        for sigil in Sigil.allCases {
            let expected = try #require(dump.sigils[sigil.rawValue], "\(sigil.rawValue) missing")
            let actual = SigilCatalogue.strokes(for: sigil)
            try #require(actual.count == expected.strokes.count,
                         "\(sigil.rawValue): \(actual.count) strokes, harness has \(expected.strokes.count)")

            for (index, pair) in zip(actual, expected.strokes).enumerated() {
                let (mine, theirs) = pair
                #expect(mine.role.harnessName == theirs.role,
                        "\(sigil.rawValue) stroke \(index): role")
                #expect(abs(mine.opacity - theirs.opacity) < 1e-6,
                        "\(sigil.rawValue) stroke \(index): opacity")
                #expect(mine.form.matches(theirs),
                        "\(sigil.rawValue) stroke \(index): geometry has forked from SIGILS")
            }
        }
    }

    @Test func strokesAreDeterministic() {
        // No RNG, no clock, no dictionary iteration order anywhere in a drawing.
        for sigil in Sigil.allCases {
            #expect(SigilCatalogue.strokes(for: sigil) == SigilCatalogue.strokes(for: sigil))
        }
    }
}
```

`SigilStroke.Form.matches(_:)` and `Role.harnessName` are `private` helpers in the same test file.
`matches` compares against the fixture's `1e-6` rounding with a tolerance one order looser, and it
**must not have a `default:` arm** (`03 W29`): a new `Form` case has to be classified here before
the test compiles again, which is the only thing that stops a new primitive shipping unproven.

Two notes on `Bundle.module`: the fixture is declared `.copy("Fixtures")` in the manifest, not
`.process`, so the lookup passes `subdirectory:` (`06 T54`, `hunch-build-and-ci/references/package-manifests.md` §6).

The raster half of the proof is the harness (`node`, in CI) and the DEBUG snapshot gallery
(scope §4.4), which draws every sigil × every state × 3 themes × {normal, Bold Text}. **Do not
port the rasteriser to Swift** — a second implementation of the same measurement is a second
thing to keep right, and the harness already reads `T` from the Swift when the Swift exists.

## The write-back contract

**Four** artefacts, one edit each, in this order. The harness fails if any of the first two is
missing; the parity test fails if the last two disagree.

| # | Artefact | Edit | Enforced by |
|---|---|---|---|
| 1 | `../scripts/check-sigil-distinctness.js` → `SIGILS` | the entry: `set`, `sites`, `verb`, `parts` | it *is* the geometry |
| 2 | one of the four catalogue `.md` files | a row in the drawings table plus its state / VoiceOver / wrongs treatment | `DOC` check: no section, or two, fails |
| 3 | `HunchCore/Sources/Sigils/Sigil.swift` | the `case` with the key as raw value, **and** the transcribed coordinates in `SigilCatalogue.strokes(for:)` | `catalogueMatchesTheHarness` |
| 4 | `HunchCore/Tests/SigilsTests/Fixtures/sigils.json` | regenerate; never hand-edit | the CI freshness step below |

**Row 3 is the one the old contract left out**, and it is where the geometry actually forks: the
table used to name only "the `case` with the key as raw value", so where the Swift *coordinates*
came from was never stated and the obvious move was to type them from the prose. They come from
`SIGILS`, by transcription, and row 4 is what proves it.

```bash
# Regenerate after any SIGILS edit — this is the whole of step 4.
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --json \
  > HunchCore/Tests/SigilsTests/Fixtures/sigils.json

# CI freshness gate: the fixture must be what the harness emits today, byte for byte.
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --json \
  | diff -u HunchCore/Tests/SigilsTests/Fixtures/sigils.json - \
  || { echo "::error::sigil fixture is stale — regenerate it"; exit 1; }
```

`--json` rounds every coordinate to 6 dp so the fixture is byte-stable across Node versions, and
emits keys in catalogue order rather than sorted, because that order **is** §4's append-only
contract — a sorted dump would hide a renumbering.

The measurement is not the point; **the record is.** A sigil measured distinct and then not
written down is a sigil the next session will invent again, differently, and the harness will
then dutifully prove the second one distinct from the first.

## Worked example

A sixth Codex facet, "duplicates only" (pages with `timesFound > 1`). Suppose it is wanted.

1. `--keys` → no such key. It is undrawn.
2. It stands for a facet, so it is a sigil, and it belongs in `codex-facet-stamps.md`.
3. Sentence: *"a re-strike ring doubled on one rim — the mark a re-found page already takes
   (§11.3) — verb `repeat`."*
4. Collision check before drawing: `repeat` is already `mode.echo`'s verb over `ring` + `arc`.
   Same primitives, same verb → **G3 violation, stop.** The fix is a different move, not a
   different radius: `timesFound` renders as re-strike *rings* (§11.3, capped at 5+), so the
   honest drawing is two concentric closed rings — verb `double`. But `double` over `arc` is
   `facet.anomaly`. Two rejections in a row is the signal that the facet bar is full: §11.2 fixes
   it at five stamps, §12.9 budgets five VoiceOver keys, and a sixth costs a catalogue key against
   an asserted 250. **The answer is that this facet is not drawn**, and that decision is recorded
   here rather than rediscovered.

This is the procedure working. Most new-sigil requests should end at step 3 or 4.

## What would be wrong

- **Drawing first and checking after.** The verb collision in step 4 costs one line to find and
  an afternoon to find in pixels.
- **Two Swift enum cases for one catalogue key**, or a raw value that does not match. The test
  fails, but only if the case was added — a sigil drawn straight into a view bypasses everything.
- **Hand-editing `SigilCatalogue.strokes(for:)` or the fixture.** `SIGILS` is the geometry; the
  Swift transcribes it and the fixture proves the transcription. Editing either alone turns a
  caught fork into a green build with two drawings.
- **Asserting parity with a substring match.** `js.contains("'key':")` is what the old test did,
  and it would have passed on a `SigilCatalogue` with every coordinate wrong.
- **Porting the rasteriser to Swift** so the check "lives in the codebase". The harness reads the
  Swift; the Swift does not reimplement the harness.
- **Hardcoding a weight in `SigilRenderer`** because `env` was inconvenient to thread. Check 9 of
  `Scripts/check-source-hygiene.sh` fails the build on a numeric `lineWidth:`.
- **`.blur`, `.shadow`, `.ultraThinMaterial` or a gradient on a sigil.** Luminance is the only
  depth cue (§13.1); bloom is for glyph-bearing regions and a sigil is chrome.
- **Loading a sigil from an asset catalogue, an SF Symbol or a font.** No image assets, and
  §13.1 forbids SF Symbols on the play surface. The sigils *are* the icon set.
- **Making `SigilCatalogue.strokes` depend on `RenderEnv`.** Geometry is theme-invariant; only
  weight and ink resolve against the environment. A geometry fork by theme is a second art
  direction (`hunch-design-tokens/SKILL.md`).
