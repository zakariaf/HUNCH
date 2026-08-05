# T09 — DEBUG snapshot gallery

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T06, T08 |
| **Delivers** | §14.1 ART / MOTION → **Palette tokens** (the artefact that proves every token resolves in all three themes with no literal in view code) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The gallery's whole point is that it renders *tokens*, in three themes × three modifier states, with **no literal anywhere in view code** — the skill owns check 9's grep, the resolution order the gallery makes visible, and the greyscale claim the sheet is the human check on. |
| `hunch-glyph-renderer` | Rows A1 of the inventory: 256 glyphs × 2 size regimes × the state list. The skill owns which sizes actually ship (36 / 44 / 52 / 72 / 96 / 128 / 220) and the rule that 36 pt is the floor of the vocabulary, both of which the gallery's specimen sizes must match rather than invent. |
| `hunch-chrome-and-meta` | The gallery is a screen, so it obeys the chrome rules it is displaying: stock controls only where they are permitted, `Text` only outside the play-surface files, `.strokeBorder` not `.stroke` for framed cells, and the six-state enumeration discipline the skill states for every component. |
| `hunch-swift-testing` | The skill owns the snapshot gallery as the visual-regression corpus and the `.snapshot` tag; the coverage test below is a package test in `Modules/Tests/HunchUITests` and must not enter `HunchCore`'s ten-second budget. |

## Objective

One DEBUG-only scrolling screen draws every component built so far — the glyph in all its states and shipped sizes, and all seven shared marks in all of theirs — across three themes × {normal, Bold Text, Reduce Motion}, plus a greyscale rendering of the same sheet. Before this task the only way to look at the renderer is to run a test and read numbers; after it, the visual-regression corpus exists, `DESIGN-SYSTEM-SCOPE.md` §2(c)'s "nothing has been rendered yet" is closed, and the registry makes a later epic's failure to add its own component a **test failure** rather than an omission nobody notices.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `design/DESIGN-SYSTEM-SCOPE.md` | §3 | the component inventory — every row is a gallery row, and rows A (marks) are what exists today |
| `design/DESIGN-SYSTEM-SCOPE.md` | §4.4 | the gallery itself: "every component in §3 × every state × 3 themes × {normal, Bold Text, Reduce Motion}, plus the same in greyscale … the direct fix for §2(c), it determines §13.5.1's missing `T`, it is the visual-regression corpus" |
| `GAME_DESIGN.md` | §13.2, §13.11 | the three themes and the three modifier settings the matrix walks |
| `GAME_DESIGN.md` | §13.5.1 | the greyscale claim the greyscale sheet is the human check on |
| `hunch-shared-marks` | `references/ownership.md` §6(d) | the gallery is the only mechanism that catches a mark drawn two ways when a grep cannot see it |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B18, B19, B34a | `#if DEBUG`, warnings-as-errors on Release, and the hygiene script the gallery must not break |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Create `Modules/Tests/HunchUITests/GalleryCoverageTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Snapshot gallery coverage", .tags(.unit, .presubmission))
struct GalleryCoverageTests {

    /// Every row of DESIGN-SYSTEM-SCOPE.md §3 is either populated here or explicitly
    /// claimed by a later epic. This is the mechanism that turns "we forgot to add the
    /// Assay to the gallery" from an omission nobody notices into a red test.
    @Test("Every inventory row is populated or claimed", arguments: GalleryRow.allCases)
    func everyInventoryRowIsPopulatedOrClaimed(row: GalleryRow) {
        switch row.status {
        case .populated(let specimens):
            #expect(!specimens.isEmpty)
        case .ownedBy(let epic):
            #expect(!epic.isEmpty)                       // e.g. "E09·T05 — the Assay"
        }
    }

    /// The three marks and the glyph that E04 ships are populated NOW. When a later epic
    /// builds its component it flips its own row and this list grows; nothing here may
    /// ever move back to `.ownedBy`.
    @Test("E04's own rows are populated")
    func e04sOwnRowsArePopulated() {
        let mine: [GalleryRow] = [
            .glyph, .verdictRing, .ghostFrame, .machinedBar,
            .linkArc, .cancelHatch, .tickRow, .arcMeter,
        ]
        for row in mine {
            guard case .populated(let specimens) = row.status else {
                Issue.record("\(row) is not populated by E04")
                continue
            }
            #expect(!specimens.isEmpty)
        }
    }

    /// Every specimen must render in every cell of the matrix. A specimen that only draws
    /// in the dark theme is a specimen that hides the bug the gallery exists to find.
    @Test("The matrix is three themes × three modifier states, plus greyscale")
    func theMatrixIsThreeThemesByThreeModifierStates() {
        #expect(Set(GalleryMatrix.all.map(\.env.theme)) == Set(RenderEnv.Theme.allCases))
        #expect(GalleryMatrix.all.count == RenderEnv.Theme.allCases.count * 3)
        #expect(GalleryMatrix.all.contains { $0.env.isBoldTextEnabled })
        #expect(GalleryMatrix.all.contains { $0.env.isReduceMotionEnabled })
        #expect(GalleryMatrix.greyscale)                 // the fourth axis is a toggle
    }

    /// Every state a component declares must appear. `VerdictRing.State` has no
    /// `CaseIterable` conformance — it has associated values — so the gallery declares its
    /// own exhaustive list and this test is what stops that list rotting.
    @Test("The verdict ring's specimen list covers every case of its state enum")
    func theVerdictRingSpecimenListCoversEveryCase() throws {
        guard case .populated(let specimens) = GalleryRow.verdictRing.status else {
            Issue.record("verdict ring not populated"); return
        }
        let names = Set(specimens.map(\.name))
        for expected in ["admit", "reject", "twin", "counterexample", "restrike", "day"] {
            #expect(names.contains { $0.hasPrefix(expected) })
        }
    }
}
```

Create `Modules/Tests/HunchUITests/GalleryRendersTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("The gallery renders", .tags(.snapshot, .presubmission))
@MainActor
struct GalleryRendersTests {

    /// Every specimen, in every matrix cell, produces a non-empty raster. Cheap, and it
    /// catches the two failures a human paging the gallery would miss: a specimen that
    /// throws in one theme, and a specimen that draws nothing because its state resolved
    /// to "do not call" (a legitimate state for a mark, and never for a specimen).
    @Test("Every specimen draws ink in every matrix cell", arguments: GalleryMatrix.all)
    func everySpecimenDrawsInkInEveryMatrixCell(cell: GalleryMatrix.Cell) throws {
        for row in GalleryRow.allCases {
            guard case .populated(let specimens) = row.status else { continue }
            for specimen in specimens {
                let raster = try markRaster(size: specimen.size, env: cell.env) { context in
                    specimen.draw(&context, specimen.size, cell.env)
                }
                #expect(raster.maximumCoverage() > 0.1, "\(row)/\(specimen.name) in \(cell)")
            }
        }
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/GalleryCoverageTests \
  -only-testing:HunchUITests/GalleryRendersTests
```

Both must fail on missing `GalleryRow`, `GalleryMatrix` and `Specimen` — not on an empty `allCases`, which would pass vacuously and is the one failure mode this pair of tests has.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then **look at it**: build DEBUG to a simulator, open the gallery, page all three themes and the greyscale sheet, and fix what you see rather than logging it. The gallery's value is that a human looks; a gallery nobody opens is a test suite with a scroll view.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/DebugGallery/GalleryRow.swift` — the registry, one case per `DESIGN-SYSTEM-SCOPE.md` §3 row |
| create | `Modules/Sources/HunchUI/DebugGallery/GallerySpecimen.swift` — `Specimen` and E04's specimen lists |
| create | `Modules/Sources/HunchUI/DebugGallery/GalleryMatrix.swift` — the nine env cells and the greyscale toggle |
| create | `Modules/Sources/HunchUI/DebugGallery/SnapshotGalleryView.swift` — the scrolling screen |
| create | `Modules/Tests/HunchUITests/GalleryCoverageTests.swift` |
| create | `Modules/Tests/HunchUITests/GalleryRendersTests.swift` |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — the DEBUG-only entry point |
| modify | `PROGRESS.md` — record the gallery, the themes reviewed, and the defects found and fixed |

## Implementation notes

### The registry is the deliverable, not the screen

The screen is a `ScrollView` and a `LazyVStack`; the interesting part is the enum that makes an omission fail a test:

```swift
#if DEBUG
/// One case per row of `design/DESIGN-SYSTEM-SCOPE.md` §3. A row is either populated with
/// specimens or explicitly claimed by the epic that will build it. `GalleryCoverageTests`
/// asserts the dichotomy, which is what stops a component shipping without ever having
/// been looked at in three themes.
public enum GalleryRow: CaseIterable, Sendable {
    // A. Marks — E04
    case glyph, verdictRing, ghostFrame, machinedBar, linkArc, cancelHatch, tickRow, arcMeter
    case modeSigil, familySigil
    // B. Instruments
    case ramp, attributeHeader, ruleTile, bridge, wedge, fork, tally, coupler
    case assayGrid, seal, throat, ribbon, gateBand
    // C. Chrome · D. Meta
    case key, instrumentBar, ruleAndBoundary, scrim, numeralReadout, stockControls
    case shelfPlate, extensionThumbnail, profileContour, codexPageComposite

    public enum Status: Sendable {
        case populated([Specimen])
        /// The epic and task that will populate it, e.g. "E09·T05 — the Assay".
        case ownedBy(String)
    }

    public var status: Status { … }
}
#endif
```

Every unpopulated case names its owner from `epics/*/epic.md`, so the gallery doubles as a build-order index. When a later epic builds its component, flipping the row from `.ownedBy` to `.populated` is part of that task's definition of done — and E20·T09's final pass re-shoots the whole sheet as the shipped corpus.

`Specimen` is deliberately a closure and a label, not a `View`:

```swift
public struct Specimen: Sendable {
    public let name: String            // "reject · settled", "hollow triangle two frost"
    public let size: CGSize
    public let draw: @Sendable (inout GraphicsContext, CGSize, RenderEnv) -> Void
}
```

A `View` per specimen would put every mark outside its host's `Canvas` — the exact mistake `ownership.md` §3 warns about — and would make the render test need a view hierarchy per cell.

### The matrix

Three themes × {normal, Bold Text, Reduce Motion} = nine cells, plus greyscale as a **toggle over the whole sheet**, not a tenth cell:

```swift
public enum GalleryMatrix {
    public struct Cell: Sendable, CustomStringConvertible {
        public let env: RenderEnv
        public var description: String { … }      // "dark · bold", "high contrast · reduce motion"
    }
    public static let all: [Cell] = RenderEnv.Theme.allCases.flatMap { theme in
        [RenderEnv(theme: theme),
         RenderEnv(theme: theme, isBoldTextEnabled: true),
         RenderEnv(theme: theme, isReduceMotionEnabled: true)]
    }
    /// Applied to the whole sheet with `.grayscale(1).saturation(0)`, because §13.5.1's
    /// claim is about the composed surface, not about one mark at a time.
    public static let greyscale = true
}
```

**This is not `RenderEnv.separationMatrix`** (T06), which is six configurations chosen to find the worst *measurement* case and includes a bloom-off row. Two different questions, two different sets; merging them silently drops a row from one of them. Say so in a comment on both.

Reduce Motion changes no static drawing — that is the point of including it. A cell that renders differently under Reduce Motion means a mark is reading `isReduceMotionEnabled` to decide *whether to move*, which `hunch-shared-marks` forbids: a mark reads it only where Reduce Motion changes **geometry**.

### What E04 populates

| Row | Specimens |
|---|---|
| `glyph` | all four `Fill` × four `Shape` × four `Pips` × four `Hue` at 44 pt as a 16 × 16 contact sheet, plus one representative glyph at each shipped size — 36, 44, 52, 72, 96, 128, 220 — to show the 48 pt regime step; plus the `ghosted` state (the glyph unchanged under a `GhostFrame`) |
| `verdictRing` | admit and reject × {transient, settled}; twin admitted and rejected; counterexample both ways; restrike at 1, 3, 5 and 6; all six `Day` cases |
| `ghostFrame` | all five `Role` cases at 36, 44 and 168 pt, LTR and RTL |
| `machinedBar` | present; retracting at 0.25, 0.5, 0.75; on both a 44 pt Seal and a 168 × 108 mode key; LTR and RTL |
| `linkArc` | ribbon adjacency (6 pt chord), a counterexample join (wide chord, capped rise), an elbow, structural and depictive, `progress` at 0.5 and 1 |
| `cancelHatch` | hatch on a 56 × 44 cell, hatch on an 11 pt cell, slash on a ramp, slash in an ellipse |
| `tickRow` | `.count` at 7 / 23 / 29 / 40, `.crossed`, `.cap`, `.silhouette` |
| `arcMeter` | each `Style` × {0, 0.4, 1.0} × {linear, logarithmic}, on `.ring`, `.border` and `.custom` tracks |

The 16 × 16 glyph sheet is the one specimen worth its size: it is the same contact sheet `render-all-256.js --out sheet.pgm` prints, so the two can be compared directly when the analytic model and the shipped renderer disagree.

### The rules the gallery itself must obey

- **`#if DEBUG` around every file in `DebugGallery/`**, and the entry point in `AppView.swift` likewise. It never ships, and the Release archive's zero-warning requirement means an unused-symbol warning here is a build failure later.
- **No literal in view code.** This is the row the gallery *delivers*, so it would be absurd for it to break the rule: every colour, weight, space and radius resolves through `env` / `Space` / `Radius` / `Opacity`. `bash Scripts/check-source-hygiene.sh` covers `Modules/Sources` and therefore covers this directory automatically — confirm it, do not assume it.
- **`Text` is legal here** and only because the gallery is not a play surface: check 7 lists the six play-surface files by name and this is not one of them. Specimen labels are `Text(verbatim:)` — they are developer strings, they must never enter the String Catalog, and E18's ≤ 250-key budget must not pay for them.
- **Reach the gallery from a debug affordance, not from the route graph.** `NavigationDepthTests` (E17·T02) asserts `distanceToPlay(screen) ≤ 2` for all 18 screens of §12.2; the gallery is not one of them and must not become a nineteenth. A `#if DEBUG` long-press on the Frame's wordmark, or a launch argument, both work; a `Route` case does not.

### What to look for when you page it

The gallery is the only mechanism that catches a mark drawn two ways when a grep cannot see it. Specifically:

1. **The greyscale sheet.** Every one of the 256 glyphs must remain distinguishable from its neighbours by eye. T06 proved it numerically in the worst environment; this is the human check, and it is how you notice that a pair is *technically* separated and *practically* confusable.
2. **The High Contrast column.** Every hue collapses to `stroke.primary` and the index stroke lengthens — the deck should still read as 256 marks, and the frost index tip must not be clipped anywhere.
3. **The Bold Text column.** Strokes thicken ×1.25 and then take High Contrast's flat +0.5 where both are on; the ladder must still look like one ladder, and the cancel hatch must still look lighter than a `dotted` fill.
4. **The three themes side by side.** The light theme's keyline should read as an ink outline around a hue, not as a second stroke; the bloom bed should be absent in light and present in dark; nothing should have gained a shadow.

Record what you found and fixed in `PROGRESS.md`. "Reviewed, no defects" is a legitimate entry; "not reviewed" is not.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/GalleryCoverageTests -only-testing:HunchUITests/GalleryRendersTests` green.
- [ ] `GalleryRow.allCases.count` equals the number of component rows in `DESIGN-SYSTEM-SCOPE.md` §3 — verified by reading both, and stated in a comment on the enum.
- [ ] Every row that E04 built is `.populated`; every other row is `.ownedBy` with a real `EID·TID` string that matches a task file under `epics/`.
- [ ] `GalleryMatrix.all.count == 9`, spanning all three themes, and the greyscale toggle renders the whole sheet.
- [ ] Every specimen produces ink in all nine cells — no specimen is theme-conditional.
- [ ] `bash Scripts/check-source-hygiene.sh` passes with the gallery present; a planted `Color(red: 1, green: 0, blue: 0)` in `SnapshotGalleryView.swift` fails check 9.
- [ ] `grep -rn 'DebugGallery' Modules/Sources --include='*.swift' | grep -v '#if DEBUG' | grep -v '/DebugGallery/'` shows exactly one reference, in `AppView.swift`, inside `#if DEBUG`.
- [ ] The gallery has been opened on a simulator in all three themes plus greyscale, and `PROGRESS.md` records the review and every defect fixed.
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T09: the DEBUG snapshot gallery — every built component × 3 themes × 3 modifiers, plus greyscale"`

## Out of scope

- **Populating any row E04 did not build.** Rows B, C and D are `.ownedBy` strings pointing at E08, E09, E15, E16 and E17; adding a placeholder drawing for one of them would put a second implementation of that component in the app, which is exactly the bug the registry exists to prevent.
- **Image-snapshot diffing.** `swift-snapshot-testing` is banned as a dependency and `08 §7.9` fills that role with hand-rolled golden fixtures and manual screenshot review. The gallery is the corpus a human reads; `DeckSeparationTests` is the automated half.
- **Screenshots in en / de / ar** — E18·T09, in the XCUITest bundle.
- **`performAccessibilityAudit`** — E19·T11. The gallery is not a screen in §12.2's inventory and is not audited.
- **The final palette-and-type application pass across all 18 screens, and re-shooting the gallery as the shipped corpus** — E20·T09.
- **Adding a `Route` case, a navigation entry or any user-reachable affordance** — the gallery is DEBUG-only and must stay out of the route graph.
