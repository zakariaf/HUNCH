# T09 — Full palette and type application

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | Palette tokens · Register segregation · Typography (ART / MOTION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | It owns all three halves of this task. `references/tokens-swift-layout.md` §6.1 is checks 9 and 10 verbatim and the `TOKENS-EXEMPT` convention this sweep must drive to a written allowlist; §3 is `AccentColor`/`HueColor` with `init` internal to `Tokens` — the compile error this task re-proves — and `TypeRole` with `resolved(in:)`, which is what `env.type(_:)` returns; §6.2 is the arithmetic suite the negative build sits beside. `references/type-ramp.md` owns the seven roles, `relativeTo:`, tracking in **em**, and `minimumScaleFactor` at 1.0 everywhere. `references/render-env.md` §2 is the resolution order the gallery makes visible. |
| `hunch-chrome-and-meta` | The type roles have *sites*, and this is the skill that knows them: `references/numeral-readout.md` for "SF Mono for every numeral, always", `references/stock-controls.md` for the four screens permitted a stock component and the container neutralisation that stops `Form` painting `systemGroupedBackground` and the system blue, `references/instrument-bar.md` and `key.md` for the six-state enumeration every component must draw in the gallery. A sweep that does not know where a role is *allowed* cannot tell a missing application from a correct absence. |
| `hunch-swift-testing` | The snapshot gallery is this skill's — the `.snapshot` tag, the registry-plus-render-test shape, the ruling that `swift-snapshot-testing` is banned and hand-rolled golden fixtures fill the image role (`08 §7.9`), and the rule about `tests.json` entries never being removed or weakened. It also owns the fact that a negative-compilation check is **not** a test and must be a script, because a file that must fail to compile cannot live in a target that must compile. |

## Objective

At the end of this task there is no literal left: every colour, weight, space, radius, opacity and
duration in all eighteen screens resolves through a token, every one of the seven type roles reaches
the screen through `env.type(_:)` and one modifier, and the remaining `TOKENS-EXEMPT` comments are an
enumerated, reasoned list in `DECISIONS.md` rather than a habit. Register segregation stops being a
convention and stops being merely a grep: a build that is **required to fail** proves that passing an
`AccentColor` where a `HueColor` is wanted does not compile, and the same script proves the legal
spelling still does. And the DEBUG snapshot gallery is re-shot with every row populated — three themes
× three modifier states, plus greyscale — and its per-specimen coverage committed as a golden fixture,
which is the shipped visual-regression corpus this project has instead of image snapshots.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.2 | *"Named tokens only; no literal hex in view code"*; the three themes; **register segregation as a hard rule** — `accent.*` never touches a glyph body, a ramp cell or an index stroke, `hue.*` never touches chrome, a rule-tile frame, a tick mark or the Seal — and the sentence that makes it structural: *"which is why the registers are separate Swift types rather than a convention"* |
| `GAME_DESIGN.md` | §13.2 (the † Decision) | the light-theme keyline under every hue; `hue.amber` and `accent.brass` are 1.22 : 1 apart in luminance, so **nothing may be built that assumes those two are told apart by brightness** |
| `GAME_DESIGN.md` | §13.4 | the seven roles, their sizes, weights, widths, tracking in em and faces; monospaced numerals mandatory wherever a value changes without a layout pass; `relativeTo:`; `minimumScaleFactor` **1.0 everywhere, no exceptions**; `uppercased(with: locale)` and never a display transform |
| `GAME_DESIGN.md` | §13.11 | Bold Text steps every role one weight and glyph/rule-tile strokes ×1.25; High Contrast's substitutions; the three themes' floors |
| `GAME_DESIGN.md` | §13.5.1 | the greyscale claim the greyscale sheet is the human check on |
| `GAME_DESIGN.md` | §12.2 | the eighteen screens this sweep covers |
| `design/DESIGN-SYSTEM-SCOPE.md` | §3, §4.4 | the component inventory — every row is a gallery row — and the gallery's definition: every component × every state × 3 themes × {normal, Bold Text, Reduce Motion}, plus greyscale, *"the visual-regression corpus"* |
| `.claude/skills/hunch-design-tokens/references/tokens-swift-layout.md` | §2, §3, §6 | path → symbol, the register types, checks 9 and 10, the arithmetic suite |
| `.claude/skills/hunch-design-tokens/references/type-ramp.md` | all | the seven roles and their application rules |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B18`, `B19`, `B34a` | warnings-as-errors on Release, so an unused symbol in `#if DEBUG` gallery code is a build failure later; a new check must be proved able to fail |

**What already exists.** E03·T01–T06 shipped `Prim`, `Palette`, `StrokeWeight`, `Space`, `TypeRole`,
`Motion` and `C`, plus checks 9 and 10 and the arithmetic suite. E04·T09 shipped the gallery registry
with most rows `.ownedBy`. **This task adds no token and changes no value.** If a hex changes here,
something is wrong: `check-tokens.swift` is the three-way divergence check and it would say so.

## TDD — the test comes first

Three deliverables, three shapes, and the middle one is the interesting case: **a build that must
fail is not a test.** Swift Testing has no `#expect(doesNotCompile:)`, a fixture that must not compile
cannot be a member of a target that must, and `06`'s exit tests are a runtime mechanism. So the
negative build is a script that drives `swiftc -typecheck` twice — once expecting failure with a named
diagnostic, once expecting success — and it is proved by planting exactly the change that would make
the segregation stop being structural.

**Step 1a — write the failing negative-build script.** `Scripts/check-register-segregation.sh`, with
its two fixtures. Write the plant script first — `/tmp/prove-registers.sh`, scratch, not committed:

```bash
#!/bin/bash
# Every line must print CAUGHT. A MISSED line means the type split has stopped being structural.
set -uo pipefail
probe() { eval "$2"
  if Scripts/check-register-segregation.sh >/tmp/r.out 2>&1; then echo "$1: MISSED"; else echo "$1: CAUGHT"; fi
  eval "$3"; }

# The exact regression this exists to catch: someone makes an initialiser public "just for previews".
probe 'AccentColor.init made public' \
  'sed -i "" "s|    init(_ rgb: RGB8) { self.rgb = rgb }|    public init(_ rgb: RGB8) { self.rgb = rgb }|" HunchCore/Sources/Tokens/Palette.swift' \
  'git checkout -- HunchCore/Sources/Tokens/Palette.swift'

# The other way the split dies: the two registers collapse into one typealias.
probe 'HueColor aliased to AccentColor' \
  'printf "\npublic typealias HueColor = AccentColor\n" >> HunchCore/Sources/Tokens/Palette.swift' \
  'git checkout -- HunchCore/Sources/Tokens/Palette.swift'

# The negative fixture must actually be wrong. If someone "fixes" it, the check silently passes.
probe 'negative fixture repaired' \
  'sed -i "" "s/accent.brass/hue.amber/" Scripts/NegativeCompilation/RegisterLaundering.swift.fixture' \
  'git checkout -- Scripts/NegativeCompilation/RegisterLaundering.swift.fixture'

# The POSITIVE control must not be caught: the legal spelling still has to compile.
Scripts/check-register-segregation.sh >/dev/null 2>&1 && echo 'clean tree: OK' || echo 'clean: FALSE POSITIVE'
```

**Step 1b — write the failing Swift tests.** Create
`Modules/Tests/HunchUITests/TypeApplicationTests.swift`:

```swift
import Testing
import SwiftUI
import Tokens
@testable import HunchUI

@Suite("Every type role reaches the screen through env.type(_:) — §13.4", .tags(.unit, .presubmission))
struct TypeApplicationTests {

    @Test("the seam resolves the role rather than copying its fields", arguments: TypeRole.allRoles)
    func theSeamResolves(_ role: TypeRole) {
        let bold = RenderEnv(isBoldTextEnabled: true)
        let applied = HunchType.resolve(role, in: bold)
        #expect(applied.weight == role.weight.bolder)     // §13.11: one notch, clamped at bold
        #expect(applied.size == role.size)                // Bold Text touches weight, never size
        #expect(applied.trackingEm == role.trackingEm)    // tracking is stored in em, always
    }

    @Test("tracking is applied at the scaled size, never at the nominal one")
    func trackingScales() {
        let ax5 = RenderEnv(typeMultiplier: 3.1)
        let section = HunchType.resolve(.section, in: ax5)
        let scaledSize = section.size * ax5.typeMultiplier
        #expect(HunchType.tracking(section, atScaledSize: scaledSize)
                == scaledSize * TypeRole.section.trackingEm)
        // A fixed-point tracking collapses at AX5, which is the whole reason em is stored.
        #expect(HunchType.tracking(section, atScaledSize: scaledSize)
                != section.size * TypeRole.section.trackingEm)
    }

    @Test("uppercasing is locale-aware and is never a display transform", arguments: ["tr", "en"])
    func turkishDottedI(_ tag: String) {
        let locale = Locale(identifier: tag)
        let out = HunchType.display("instrument", role: .section, locale: locale)
        #expect(out == "instrument".uppercased(with: locale))
        if tag == "tr" { #expect(out.hasPrefix("İ")) }    // not "I"
    }

    @Test("every role declares relativeTo:, and numeral is the mono one", arguments: TypeRole.allRoles)
    func everyRoleIsDynamicType(_ role: TypeRole) {
        #expect(role.textStyle != nil)
        #expect((role.face == .mono) == (role == .numeral))
    }

    @Test("minimumScaleFactor is 1.0 at every site, with no exception")
    func nothingShrinks() {
        #expect(HunchType.minimumScaleFactor == 1.0)
    }

    @Test("every numeral-bearing site in §13.4 names TypeRole.numeral")
    func monospacedNumeralsEverywhere() {
        // §13.4's own list, as a registry so the sweep is checkable rather than remembered.
        for site in NumeralSite.allCases {
            #expect(site.role == .numeral, "\(site) draws a changing value in a proportional face")
        }
        #expect(NumeralSite.allCases.contains(.profilePortrait) == false)  // §11.11 P2: no numeral
    }
}
```

And `Modules/Tests/HunchUITests/GalleryCorpusTests.swift`, which is the corpus half:

```swift
import Testing
import SwiftUI
import Tokens
@testable import HunchUI

@Suite("The gallery is the shipped visual-regression corpus", .tags(.snapshot, .presubmission))
@MainActor
struct GalleryCorpusTests {

    @Test("no inventory row is still owned by a future epic")
    func everyRowIsPopulated() {
        let unpopulated = GalleryRow.allCases.filter {
            if case .ownedBy = $0.status { return true }
            return false
        }
        #expect(unpopulated.isEmpty, "still claimed, not drawn: \(unpopulated)")
    }

    @Test("the matrix is still nine cells plus greyscale, and greyscale is a sheet toggle")
    func theMatrixIsUnchanged() {
        #expect(GalleryMatrix.all.count == 9)
        #expect(Set(GalleryMatrix.all.map(\.env.theme)) == Set(RenderEnv.Theme.allCases))
        #expect(GalleryMatrix.greyscale)
    }

    @Test("every specimen's coverage matches the committed golden, cell by cell",
          arguments: GalleryMatrix.all)
    func coverageMatchesTheGolden(cell: GalleryMatrix.Cell) throws {
        let golden = try GalleryGolden.load()                 // Fixtures/gallery-coverage-v1.json
        for row in GalleryRow.allCases {
            guard case .populated(let specimens) = row.status else { continue }
            for specimen in specimens {
                let raster = try markRaster(size: specimen.size, env: cell.env) { context in
                    specimen.draw(&context, specimen.size, cell.env)
                }
                let key = GalleryGolden.Key(row: row, specimen: specimen.name, cell: cell)
                let expected = try #require(golden[key], "no golden for \(key)")
                #expect(isApproximatelyEqual(raster.coverage, expected,
                                             absoluteTolerance: GalleryGolden.tolerance),
                        "\(key): \(raster.coverage) vs \(expected)")
            }
        }
    }

    @Test("the golden covers every specimen in every cell — no silent gaps")
    func theGoldenIsTotal() throws {
        let golden = try GalleryGolden.load()
        var expected = 0
        for cell in GalleryMatrix.all {
            for row in GalleryRow.allCases {
                guard case .populated(let specimens) = row.status else { continue }
                expected += specimens.count
                _ = cell
            }
        }
        #expect(golden.count == expected)
    }

    @Test("greyscale changes no coverage — §13.5.1's claim is about colour, not geometry")
    func greyscaleIsAColourOperation() throws {
        for row in GalleryRow.allCases {
            guard case .populated(let specimens) = row.status else { continue }
            for specimen in specimens {
                let colour = try markRaster(size: specimen.size, env: RenderEnv()) { c in
                    specimen.draw(&c, specimen.size, RenderEnv())
                }
                let grey = try markRaster(size: specimen.size, env: RenderEnv(), monochrome: true) { c in
                    specimen.draw(&c, specimen.size, RenderEnv())
                }
                #expect(colour.coverageMask == grey.coverageMask)
            }
        }
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
bash /tmp/prove-registers.sh
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" \
  -only-testing:HunchUITests/TypeApplicationTests \
  -only-testing:HunchUITests/GalleryCorpusTests | xcbeautify
bash Scripts/check-source-hygiene.sh
```

The script prints `MISSED` on every line before it exists. The Swift run fails on `cannot find
'HunchType' in scope` and on `everyRowIsPopulated` listing every row still `.ownedBy` — which is the
correct first failure and is also this task's to-do list. Two failures to read rather than fix:

- **`coverageMatchesTheGolden` failing on a row you did not touch** is a real regression from an
  earlier epic, surfaced by the first run that renders every row in every cell. Fix the drawing, not
  the golden.
- **`greyscaleIsAColourOperation` failing** means a mark's *geometry* depends on colour — usually a
  drawing that branches on `theme == .highContrast` to change a shape rather than reading a
  substitution. §13.5.1's whole claim rests on this and E04·T06 proved it for glyphs; a failure here is
  a mark outside the glyph that broke it.

**Step 3 — implement.** The sweep, then the seam, then the script, then the gallery rows, then the
golden.

**Step 4 — green, then page it.** Open the gallery on a device in all three themes and on the
greyscale sheet, and fix what you see rather than logging it. A corpus nobody looks at is a scroll view.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/HunchType.swift` — the one type-application seam: `resolve`, `tracking`, `display`, the `View`/`Text` modifier |
| create | `Modules/Sources/HunchUI/NumeralSite.swift` — §13.4's numeral-bearing sites as a registry |
| modify | `Modules/Sources/**` — the sweep: every `.font(`, every literal, every raw role |
| modify | `Modules/Sources/HunchUI/DebugGallery/GalleryRow.swift` — every row flipped from `.ownedBy` to `.populated` |
| modify | `Modules/Sources/HunchUI/DebugGallery/GallerySpecimen.swift` — the specimen lists for rows B, C and D |
| create | `Modules/Tests/HunchUITests/Fixtures/gallery-coverage-v1.json` — the golden, produced by a tool run and committed |
| create | `Modules/Tests/HunchUITests/GalleryGolden.swift` — the loader and the tolerance |
| create | `Scripts/check-register-segregation.sh` |
| create | `Scripts/NegativeCompilation/RegisterLaundering.swift.fixture` — must **not** compile |
| create | `Scripts/NegativeCompilation/RegisterCorrect.swift.fixture` — must compile |
| modify | `Scripts/check-source-hygiene.sh` — check 13, the type seam |
| modify | `.github/workflows/ci.yml` — the negative build as its own named step |
| create | `Modules/Tests/HunchUITests/TypeApplicationTests.swift` |
| create | `Modules/Tests/HunchUITests/GalleryCorpusTests.swift` |
| modify | `DECISIONS.md` — the `TOKENS-EXEMPT` allowlist, each entry with its reason |
| modify | `PROGRESS.md` — the gallery review in three themes plus greyscale, dated, with the defects found |
| modify | `tests.json` — `tokens.no-literals`, `tokens.type-role-seam`, `tokens.register-segregation-negative-build`, `tokens.gallery-corpus` |

## Implementation notes

### The sweep, and how to make it finite

Eighteen screens is not a thing you eyeball. Drive it from the two checks that already exist and one
new one, and let the compiler and the grep enumerate the work:

```bash
# 1. What is left. Check 9's own regex, without the TOKENS-EXEMPT filter, so exemptions show up too.
bash Scripts/check-source-hygiene.sh 2>&1 | sed -n '/Literal value outside Tokens/,/^$/p'
grep -rn 'TOKENS-EXEMPT' Modules/Sources App --include='*.swift'

# 2. Every font application that is not the seam.
grep -rn '\.font(' Modules/Sources App --include='*.swift' | grep -v 'HunchType.swift'

# 3. Every raw role reference that skipped resolution. `TypeRole.numeral` is the UNRESOLVED token;
#    `env.type(.numeral)` is the value. tokens-swift-layout.md §2's table says so in one line.
grep -rnE 'TypeRole\.[a-z]' Modules/Sources App --include='*.swift' \
  | grep -v 'env\.type(' | grep -v '/Tokens/'
```

Every hit in (1) is either a token that should have been named or an exemption that must be written
into `DECISIONS.md` with a reason. **The end state is a short, enumerated allowlist, not zero** — the
launch-screen colour sets (E17·T05) are already one sanctioned duplication, and pretending the number
is zero is how a real exemption gets buried in a comment. Every surviving `TOKENS-EXEMPT` gets a line
in `DECISIONS.md` naming the file, the value, and why no token can express it.

### `HunchType` — one seam, because §13.4 has five rules that are easy to apply four of

```swift
// Modules/Sources/HunchUI/HunchType.swift
/// The ONE place a `TypeRole` becomes pixels. Every rule §13.4 states is applied here, together,
/// so no call site can honour four of five: `relativeTo:` for Dynamic Type, tracking computed at
/// the *scaled* size from the stored em, the Bold Text weight step, `monospacedDigit` for the
/// mono face, `uppercased(with: locale)` where the role says so, and `minimumScaleFactor` 1.0.
@MainActor
public enum HunchType {
    public static let minimumScaleFactor = 1.0

    public static func resolve(_ role: TypeRole, in env: RenderEnv) -> TypeRole {
        env.type(role)                                   // never a hand-rolled copy of the ladder
    }
}

extension View {
    /// `Text(verbatim: Loc.probes).hunchType(.numeral, in: env)`
    public func hunchType(_ role: TypeRole, in env: RenderEnv) -> some View { … }
}
```

Three reasons it is a seam rather than a convention:

- **The five rules travel together.** `.font(.system(size: 15, design: .monospaced))` at a call site
  honours the face and silently drops `relativeTo:`, the tracking, the Bold Text step and the
  monospaced-digit feature. Every one of those failures is invisible until AX5 or Turkish.
- **`env.type(_:)` is the resolution, and `TypeRole.numeral` is not.** `tokens-swift-layout.md` §2's
  table has a row for exactly this: `StrokeWeight.body` and `TypeRole.numeral` are the *unresolved*
  tokens. Grep (3) above is the whole enforcement.
- **Uppercasing is locale-aware or it is a bug in Turkish.** `"i".uppercased()` is `"I"`; the correct
  answer is `"İ"`. §13.4 says `String.uppercased(with: locale)`, never a display transform and never
  the font's small-caps feature — and §12.9 trap 6 adds that Arabic, Japanese, Korean and Simplified
  Chinese take a per-script profile with no small caps and no negative tracking at all.

Check 13 is the grep that keeps the seam a seam:

```bash
# 13. Type roles reach the screen through one seam — §13.4, owner hunch-design-tokens.
hits=$(grep -rn '\.font(' --include='*.swift' Modules/Sources App \
       | grep -v '/HunchUI/HunchType.swift' || true)
[ -n "$hits" ] && report 'A font applied outside HunchType (§13.4: one seam, five rules):' "$hits"

hits=$(grep -rnE 'TypeRole\.[a-z][A-Za-z]*' --include='*.swift' Modules/Sources App \
       | grep -v 'env\.type(' | grep -v 'HunchCore/Sources/Tokens/' \
       | grep -v '/HunchUI/HunchType.swift' || true)
[ -n "$hits" ] && report 'An unresolved TypeRole used as a value — call env.type(_:):' "$hits"

hits=$(grep -rn 'minimumScaleFactor' --include='*.swift' Modules/Sources App \
       | grep -v 'HunchType.minimumScaleFactor' || true)
[ -n "$hits" ] && report 'minimumScaleFactor is 1.0 everywhere, no exceptions (§13.4):' "$hits"
```

### The build that must fail

§13.2 says the registers are *"separate Swift types rather than a convention"*, and E03·T02 made
`AccentColor.init` and `HueColor.init` internal to `Tokens` so laundering is a compile error outside
the module. **Nothing currently proves that.** A test cannot: a file that must fail to compile cannot
be a member of a target that must compile. So:

```bash
#!/bin/bash
# Scripts/check-register-segregation.sh — §13.2's register split, proved by a build that must fail.
#
# Two fixtures, two expectations. The negative one MUST fail to typecheck with a diagnostic that
# names the two types; the positive one MUST typecheck. Asserting only the first is not enough —
# a fixture that fails for an unrelated reason (a typo, a missing import) would pass this check
# forever while proving nothing.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$PWD}"
fixtures="$root/Scripts/NegativeCompilation"
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

build="$root/.build/registers"
mkdir -p "$build"
swift build --package-path "$root/HunchCore" --target Tokens -c debug \
  --scratch-path "$build" >/dev/null 2>&1 || { echo 'Tokens did not build'; exit 1; }
modules="$build/debug/Modules"

typecheck() {   # typecheck <file>  → prints diagnostics, returns swiftc's status
  xcrun swiftc -swift-version 6 -typecheck -I "$modules" "$1" 2>&1
}

# 1. The negative fixture must FAIL, and for the right reason.
out=$(typecheck "$fixtures/RegisterLaundering.swift.fixture"); rc=$?
if [ "$rc" -eq 0 ]; then
  report 'Register laundering COMPILES — §13.2 segregation is no longer structural:' \
         "$fixtures/RegisterLaundering.swift.fixture"
elif ! printf '%s' "$out" | grep -q "AccentColor"; then
  report 'The negative fixture failed for the wrong reason (a check that cannot fail correctly):' "$out"
fi

# 2. The positive control must SUCCEED. A check that rejects the legal spelling gets deleted.
out=$(typecheck "$fixtures/RegisterCorrect.swift.fixture") || \
  report 'The legal spelling no longer compiles — this is a real regression:' "$out"

[ "$status" -eq 0 ] && echo 'Register segregation: structural (negative build fails, positive build passes)'
exit "$status"
```

```swift
// Scripts/NegativeCompilation/RegisterLaundering.swift.fixture
// THIS FILE MUST NOT COMPILE. It is not a target member; `.fixture` keeps it out of every glob.
// §13.2: "accent.* never touches a glyph body, a ramp cell or an index stroke."
import Tokens

func drawIndexStroke(in hue: HueColor) {}

func laundered(_ env: RenderEnv) {
    // error: cannot convert value of type 'AccentColor' to expected argument type 'HueColor'
    drawIndexStroke(in: env.palette.accent.brass)

    // error: 'init' is inaccessible due to 'internal' protection level
    _ = HueColor(env.palette.accent.brass.rgb)
}
```

```swift
// Scripts/NegativeCompilation/RegisterCorrect.swift.fixture
// THIS FILE MUST COMPILE. It is the positive control: a check that only ever expects failure
// passes forever the day the fixture stops parsing.
import Tokens

func drawIndexStroke(in hue: HueColor) {}

func correct(_ env: RenderEnv) {
    drawIndexStroke(in: env.palette.hue.amber)      // the hue register, on the hue channel
    _ = env.palette.accent.brass.rgb                // reading .rgb is legal; MINTING is not
}
```

`.rgb` being readable is deliberate and is the reason check 10 exists alongside the types: the split
stops you *constructing* a register colour, and the grep stops you round-tripping one through `RGB8`.
Both, or neither works.

### The gallery, re-shot as a corpus

E04·T09 built the registry and populated rows A. This task populates the rest and turns the sheet into
something that can regress:

- **Every `.ownedBy` becomes `.populated`.** `everyRowIsPopulated` is the list of work and the proof
  it is done. A row whose component genuinely has no visual state is still populated — with one
  specimen — rather than left claimed.
- **Every component draws in all six of its states** where `hunch-chrome-and-meta`'s key file
  enumerates six (`idle`, `pressed`, `selected`, `barred`, `disabled`, `suspended`); a five-state
  specimen list is how `disabled` ships unlooked-at.
- **The golden is a coverage scalar per (row, specimen, cell), committed as JSON** with
  `outputFormatting: [.sortedKeys, .prettyPrinted]` so a diff is readable. That is `08 §7.9`'s ruling
  applied: `swift-snapshot-testing` is banned, hand-rolled golden fixtures fill the `.json` role, and
  the image role is filled by a human paging the sheet. A coverage scalar catches the failures a human
  misses — a mark that vanished in one theme, a stroke that doubled under Bold Text — and misses the
  ones a human catches, which is why both halves ship.
- **The tolerance is a stated constant, not a guess.** `GalleryGolden.tolerance` is absolute, small,
  and documented as covering rasteriser jitter between OS versions and nothing else. If a change needs
  the tolerance raised, the change is the finding.

**Regenerating the golden is a deliberate act.** `Scripts/regenerate-gallery-golden.sh` writes the
file; it is never run from CI, and `check-source-hygiene.sh` check 2 (`record: .all`) is the precedent
for why — a corpus that re-records itself asserts nothing, forever, silently.

### The four things to look for on the sheet, and what each one catches

E04·T09 listed these for a smaller sheet; at eighteen screens they find different bugs:

1. **The greyscale sheet.** Every mark must stay distinguishable from its neighbours *and* from the
   chrome it sits on. This is where a `hue.amber` that has crept onto a chrome rule becomes obvious:
   at 1.22 : 1 against `accent.brass` it is invisible in colour and identical in grey.
2. **The High Contrast column.** Every hue is `stroke.primary`, so any surface that draws a glyph
   without its index stroke is 4× ambiguous. There must be no such surface.
3. **The Bold Text column.** Strokes ×1.25, then High Contrast's flat +0.5 where both are on. The
   ladder must still read as one ladder, and — the new one at this scale — **chrome hairlines must not
   have thickened**, because `respondsToBoldText` is false on them and a hairline that grew is a token
   someone re-declared locally.
4. **The three themes side by side.** The light theme's keyline reads as an ink outline around a hue,
   not as a second stroke; the bloom bed is absent in light and present in dark; nothing has gained a
   shadow, an elevation or a material.

Record what you found and fixed in `PROGRESS.md`. "Reviewed, no defects" is legitimate; "not reviewed"
is not.

### Three sweep findings to expect, because they are the ones that survive nine epics

- **A `Color(...)` inside a `#if DEBUG` block.** Check 9 covers `Modules/Sources` including
  `DebugGallery/`, so it is caught — but only if the gallery files are in the roots the check walks.
  Confirm with a planted literal in `SnapshotGalleryView.swift` rather than assuming.
- **A `.font(.caption)` on a stock `Form` row.** The four screens permitted stock components are still
  ours to type: `stock-controls.md` §1's neutralisation sets the role, and a system font that slipped
  through reads as "almost right" in English and wrong in German at AX3.
- **A numeral in a proportional face.** §13.4's list is specific — probe counts, par/cap, Seal marks,
  the Anomaly tally and streak, the Codex instrument strip, the Profile stat block, the statistics
  screen, the Settings version — and `NumeralSite` is that list as a registry so the sweep is a test
  rather than a re-read. The Profile *portrait* is on the list of places that carry **no** numeral at
  all (§11.11 P2), which is why the registry asserts its absence too.

## Acceptance criteria

- [ ] `bash /tmp/prove-registers.sh` prints `CAUGHT` on all three plants and `OK` on the clean tree.
- [ ] `Scripts/check-register-segregation.sh` on a clean tree prints its success line and exits 0; it is a named step in `.github/workflows/ci.yml` with no `continue-on-error`.
- [ ] `xcodebuild test … -only-testing:HunchUITests/TypeApplicationTests` green, all six; `…/GalleryCorpusTests` green, all five, with a non-zero case count.
- [ ] `bash Scripts/check-source-hygiene.sh` green with checks 9, 10 and 13 in the roster, and check 13 demonstrated red on a planted `.font(.body)` and on a planted bare `TypeRole.numeral` before being reverted.
- [ ] `grep -rn '\.font(' Modules/Sources App --include='*.swift' | grep -v HunchType.swift` returns nothing.
- [ ] `grep -rn 'TOKENS-EXEMPT' Modules/Sources App --include='*.swift'` returns exactly the set enumerated in `DECISIONS.md`, each with a reason and a named owner.
- [ ] `grep -rn 'minimumScaleFactor' Modules/Sources App | grep -v 'HunchType'` returns nothing.
- [ ] `GalleryRow.allCases` contains **zero** `.ownedBy` rows, and `GalleryRow.allCases.count` still equals `DESIGN-SYSTEM-SCOPE.md` §3's row count.
- [ ] `Modules/Tests/HunchUITests/Fixtures/gallery-coverage-v1.json` is committed, sorted-key pretty-printed, and covers every (row, specimen, cell) triple; `theGoldenIsTotal` proves the count.
- [ ] `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` still green — this task changed no value.
- [ ] The gallery was opened on a device in all three themes plus greyscale; `PROGRESS.md` records the review, the four things looked for, and every defect fixed.
- [ ] `tests.json` carries `tokens.no-literals`, `tokens.type-role-seam`, `tokens.register-segregation-negative-build` and `tokens.gallery-corpus`, each with a runnable command.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Reject any suggestion that deletes `RegisterCorrect.swift.fixture` as unused: it is the positive control and without it the negative check passes the day the fixture stops parsing. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T09: the final token and type-role sweep, the negative register build, and the gallery re-shot as the corpus"`

## Out of scope

- **The token layers themselves** — `Prim`, `Palette`, `StrokeWeight`, `Space`, `Radius`, `Opacity`, `TypeRole`, `Dur`, `Easing`, `C`, `RenderEnv` and the resolution order — **E03·T01–T06**. This task changes no value; `check-tokens.swift` would say so if it did.
- Checks 9 and 10 themselves, and the `TOKENS-EXEMPT` convention — **E03·T06** / **E01·T06**. This task drives the exemptions to a written list and adds check 13.
- The gallery registry, the matrix and the specimen shape — **E04·T09**. This task populates the remaining rows and adds the golden.
- The greyscale distinctness proof and the constant `T` — **E04·T06**. `greyscaleIsAColourOperation` here is the *composed-surface* sibling of that test, not a second copy of it.
- The AX5 × five-locale truncation and overflow suite — **E19·T07**/**T11**.
- The High Contrast theme's own gate — **E19·T09**.
- The app icon, which is the one place this app has pixels — **T10**.
