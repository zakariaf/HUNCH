# T01 — The String Catalog and `Loc`

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (inside this epic) |
| **Delivers** | LOCALIZATION → String Catalog |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns check 8 — the String Catalog check — and the rule that this check is a **source lint and not a package test**, because a `.xcstrings` is compiled to `.lproj` at build time and the source file is repo-relative and therefore invisible from inside a test bundle (`08 §5`). `references/source-hygiene.md` §2 is check 8's exact jq, §3 the conventions any check you append must follow, §4 the prove-it-can-fail drill. It also owns the `resources:` declaration in `Modules/Package.swift` (`references/package-manifests.md`). |
| `hunch-swift-code` | Decides where `Loc` lives and what it is called. `Loc` fails the `HunchCore` boundary predicate on *both* halves — it names a `Bundle` and it reads a `Locale` — so it is `Modules/Sources/HunchUI/` and nowhere else (`08 §2`). The skill also owns the one-top-level-type-per-file rule (`01 P24`) and the banned filenames (`01 P28`) that decide the two-file split below. |

## Objective

At the end of this task `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` exists as a real,
checked-in, English-complete artifact declared in `Modules/Package.swift`, and every user-facing
string in the app is reached through exactly one accessor — `Loc`, a value carrying a bundle and a
locale — over a closed key space, `LocKey`. Check 8 runs against a real catalog for the first time
since E01, and a new hygiene check makes the enum and the catalog unable to drift apart.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 (the inventory table) | the 94 / 134 / ≈ 228 split, the hard budget of 250, and why the budget is 250 and not 220 |
| `GAME_DESIGN.md` | §12.9 (Language override, point 2) | that **every** user-facing string goes through one accessor carrying the bundle and the locale, and why a bare `Text("literal")` is a bug even though it *is* extracted |
| `GAME_DESIGN.md` | §12.9 (The traps, named — trap 1) | the two spellings that must both be impossible: a `String`-typed `Text(` argument, and a bare literal outside the accessor |
| `GAME_DESIGN.md` | §13.10 (glyph label) | `GLYPH_LABEL` is one format string with four positional interpolations — the shape every interpolating accessor copies |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 (the tree), §2 (boundary), §5 (check 8) | `Loc.swift` and `Resources/Localizable.xcstrings` under `HunchUI`; why the catalog checks are `Scripts/` and not tests |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P24`, `P25`, `P28`, `P34`, `P35`, `P36` | one top-level type per file; banned filenames; **String Catalog symbol generation off**; `defaultLocalization`; the single-accessor rule |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B39` | `Text(someString)` is never extracted — the grep that exists because of it |
| `.claude/skills/hunch-accessibility/references/voiceover-elements.md` | §9 | that a `Loc` accessor returns an **already-resolved `String`**, so every call site is `Text(verbatim:)` |

The key counts, the budget and the six play-surface file names are §12.9's and are not restated in
code comments — cite the section.

## TDD — the test comes first

This task has two halves and each gets its own kind of proof. The runtime half is a Swift Testing
suite; the source-lint half is the plant-a-violation drill, which is what `hunch-build-and-ci`
`references/source-hygiene.md` §4 requires of every check and is the only proof a lint can have.

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/CatalogResolutionTests.swift`:

```swift
import Foundation
import Testing
import HunchUI

/// The catalog is compiled into `.lproj` bundles at build time and the source `.xcstrings` is not
/// in any test bundle — so this suite asserts what a *test* can see (resolution) and check 8 and
/// the reconciliation lint assert what only a *script* can see (the file's shape). Neither
/// replaces the other; together they are §12.9's "mechanically enforced rather than remembered".
@Suite("String Catalog resolution", .tags(.unit, .presubmission))
@MainActor
struct CatalogResolutionTests {

    /// The single most valuable assertion in this epic. A `LocKey` whose case exists but whose
    /// catalog entry does not resolves *to its own raw value* and ships that way, silently,
    /// forever — because the key is a runtime `String` and Xcode's extractor never sees it.
    @Test("Every key resolves to a value that is not its own key", arguments: LocKey.allCases)
    func everyKeyResolves(_ key: LocKey) {
        let value = Loc.english[key]
        #expect(!value.isEmpty)
        #expect(value != key.rawValue, "\(key.rawValue) fell back to its key — no catalog entry")
    }

    /// §12.9: the hard budget is 250 and the count is ≈ 228. Check 8 asserts this over the file;
    /// this asserts it over the key space, so adding a case without a catalog entry is caught
    /// twice and removing a catalog entry without its case is caught by the reconciliation lint.
    @Test("The key space is inside §12.9's hard budget")
    func keySpaceIsInsideBudget() {
        #expect(LocKey.allCases.count <= 250)
    }

    /// A duplicated raw value would make two cases resolve to one entry, which is how a key count
    /// silently under-reports and how two screens acquire one shared string nobody intended.
    @Test("Raw values are unique")
    func rawValuesAreUnique() {
        let raws = LocKey.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    /// The accessor carries a bundle. Passing `nil` or `Bundle.main` would resolve against the
    /// app's launch-time localization, which is §12.9's trap 2 and the whole reason `Loc` exists.
    @Test("The accessor resolves against HunchUI's own bundle, never Bundle.main")
    func resolvesAgainstItsOwnBundle() throws {
        let url = try #require(Loc.english.bundleURL)
        #expect(url != Bundle.main.bundleURL)
        #expect(FileManager.default.fileExists(atPath: url.appending(path: "en.lproj").path()))
    }

    /// An interpolating accessor is one format string with positional arguments, never a `+`.
    /// This is §12.9 trap 3 and §13.10's `GLYPH_LABEL` shape; the assertion is that the four
    /// arguments all land and that none of them is dropped by a malformed format string.
    @Test("An interpolating accessor substitutes every argument")
    func interpolationSubstitutesEveryArgument() {
        let label = Loc.english.glyphLabel(fill: "hollow", shape: "triangle",
                                           pips: "three pips", hue: "teal")
        for fragment in ["hollow", "triangle", "three pips", "teal"] {
            #expect(label.contains(fragment))
        }
        #expect(!label.contains("%"))          // an unsubstituted specifier survives as a literal %
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/CatalogResolutionTests
```

It must fail on **missing symbols** — `LocKey`, `Loc.english`, `Loc.subscript`,
`Loc.glyphLabel(fill:shape:pips:hue:)` — not on a malformed expectation. If it fails instead with
`could not find bundle`, the `resources:` declaration in `Modules/Package.swift` is missing and that
is the first thing to fix.

**Step 2b — plant the lint's violations.** Before writing the reconciliation check, prove check 8
can now fail against a *real* catalog. This is the proof E01·T06 deferred here by name.

```bash
# Baseline.
bash Scripts/check-source-hygiene.sh; echo "exit=$?"          # expect clean, exit=0

# (a) key budget — append 60 dummy keys with jq, run, revert.
# (b) untranslated — set one entry's en localization "state" to "new", run, revert.
# (c) duplicate English — give two keys the same en value, run, revert.
# Each run MUST exit 1 and name check 8 and the offending key.
git checkout -- Modules/Sources/HunchUI/Resources/Localizable.xcstrings
```

Paste all four outputs into `.github/pr-body.md`. Then add the reconciliation check and prove it the
same way, by deleting one `LocKey` case and by deleting one catalog entry.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net. The mechanical `Loc.` → `loc[.`
migration in the *Implementation notes* belongs to step 4, not step 3: get one screen resolving
first, then sweep.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` |
| create | `Modules/Sources/HunchUI/LocKey.swift` |
| create | `Modules/Sources/HunchUI/Loc.swift` |
| modify | `Modules/Package.swift` — `resources: [.process("Resources")]` on the `HunchUI` target |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — install `\.loc` in `hunchEnvironment(_:)` |
| modify | every file under `Modules/Sources/` that spells `Loc.<name>` — the mechanical migration to `loc[.<name>]` |
| modify | `Scripts/check-source-hygiene.sh` — append the `LocKey` ↔ catalog reconciliation check |
| create | `Modules/Tests/HunchUITests/CatalogResolutionTests.swift` |
| modify | `tests.json` — three entries (key budget, twelve-locale resolution as `pending` until T03, enum/catalog reconciliation) |
| modify | `DECISIONS.md` — the `loc[.key]` call-site spelling, and the two-form accessor split |

## Implementation notes

### Do not turn on "Generate String Catalog Symbols"

`01 P34` and `08 §7.11` both rule it off, and E01·T02 already set it off in `Config/`. The reason is
mechanical, not stylistic: generated symbols are produced by **Xcode's** build system, so a package
target that references them cannot be built by plain `swift build` — which is the ten-second fast
path the whole two-package structure exists to buy. `Loc` is the hand-written accessor §12.9
requires anyway. Verify before writing a line:

```bash
xcodebuild -showBuildSettings -scheme Hunch | grep -i STRING_CATALOG_GENERATE_SYMBOLS
```

### The trap that makes `CatalogResolutionTests` mandatory

Xcode extracts catalog keys from **static string literals** at `String(localized:)` and
`Text("…")` call sites. `LocKey.rawValue` is a runtime `String`. That means:

- the catalog will **never** auto-populate from `Loc`'s call sites, so every entry is authored by
  hand (T02) or by script; and
- a `LocKey` case with no catalog entry resolves to its own raw value — `"SETTINGS_ROW_THEME"` on
  screen — and no compiler, no extractor and no build warning says a word.

That is the entire justification for `LocKey: CaseIterable` and for the `everyKeyResolves` test.
Write both comments into the source; a future contributor will otherwise "simplify" the enum away.

### `LocKey` — the closed key space

```swift
// Modules/Sources/HunchUI/LocKey.swift
/// Every key in `Localizable.xcstrings`, and nothing else. §12.9's inventory is the authority for
/// which strings exist; this enum is that inventory made a compile-time fact.
///
/// The raw value is the catalog key. It is SCREAMING_SNAKE and it is **not** the English text:
/// keying on English means changing a comma in English orphans eleven translations.
public enum LocKey: String, CaseIterable, Sendable {

    // MARK: - Visible (§12.9's first block). T02 authors the English for every case here.
    case labelAbout                 = "LABEL_ABOUT"
    case labelCodex                 = "LABEL_CODEX"
    case screenTitleSettings        = "SCREEN_TITLE_SETTINGS"
    case settingsSectionDisplay     = "SETTINGS_SECTION_DISPLAY"
    case settingsRowTheme           = "SETTINGS_ROW_THEME"
    // …

    // MARK: - Accessibility (§12.9's second block). Audio only; never rendered as pixels.
    case glyphLabel                 = "GLYPH_LABEL"
    case a11ySeal                   = "A11Y_SEAL"
    // …
}
```

Two rules for the enum, both enforced by the reconciliation check:

1. **A case exists iff a catalog entry exists.** Adding a string is two edits in one commit.
2. **Cases are grouped by §12.9's inventory rows, in that order, with a `MARK` per row.** The
   inventory is the audit trail for the count; an enum sorted alphabetically cannot be audited
   against it.

Generate the first draft rather than typing it — the keys that already exist are whatever E08–E17's
call sites named:

```bash
grep -rhoE '\bLoc\.[a-zA-Z0-9_]+' Modules/Sources | sort -u
```

### `Loc` — one accessor, two resolution forms

```swift
// Modules/Sources/HunchUI/Loc.swift
import Foundation

/// THE single localization accessor (§12.9). It carries a **bundle** and a **locale**, because
/// `String(localized:)`, `LocalizedStringResource` and `Text("literal")` all resolve against
/// `Bundle.main`'s launch-time localization otherwise — so an override that only reached this type
/// would leave every string English until relaunch (§12.9, trap 2).
///
/// Every accessor returns an already-resolved `String`. Call sites are therefore
/// `Text(verbatim:)`; re-wrapping in the localizing `Text` overload is a second lookup that fails
/// silently and yields the key.
public struct Loc: Sendable, Hashable {
    public let locale: Locale
    /// The bundle the catalog resolves inside. In the default case this is `HunchUI`'s own
    /// resource bundle; under an override (T05) it is that bundle's `<tag>.lproj`.
    public let bundleURL: URL

    public init(locale: Locale, bundleURL: URL) {
        self.locale = locale
        self.bundleURL = bundleURL
    }

    /// The system-resolved accessor: whatever the process was launched in.
    public static let system = Loc(locale: .autoupdatingCurrent, bundleURL: #bundle.bundleURL)

    /// Test-only convenience, but it ships: previews install nothing and must not crash.
    public static let english = Loc(locale: Locale(identifier: "en"), bundleURL: #bundle.bundleURL)

    // MARK: - Form 1 — plain keys

    /// Dynamic-key resolution. `String.LocalizationValue(stringLiteral:)` accepts a runtime String
    /// and treats the whole of it as the key; this is the only form that works over `LocKey`.
    public subscript(_ key: LocKey) -> String {
        String(localized: LocalizedStringResource(
            String.LocalizationValue(stringLiteral: key.rawValue),
            bundle: .atURL(bundleURL),
            locale: locale))
    }

    // MARK: - Form 2 — interpolating and plural-bearing keys

    /// §13.10's `GLYPH_LABEL`: one format string, four positional interpolations, never a `+`.
    public func glyphLabel(fill: String, shape: String, pips: String, hue: String) -> String {
        String(format: self[.glyphLabel], locale: locale, fill, shape, pips, hue)
    }
}
```

**Why there are two forms, and why that is not a smell.** A plural variation is selected by
Foundation *at lookup time* from the substituted arguments; the arguments therefore have to reach
the lookup, and they cannot when the key is a runtime `String`. So:

- **plain keys** use form 1 (dynamic key, `.atURL`, `locale:`) — §12.9's literal spelling;
- **interpolating keys with no plural** use form 1 followed by
  `String(format:locale:arguments:)` with **positional** specifiers (`%1$@`), which is what lets a
  translator reorder the four fragments of `GLYPH_LABEL` — the exact thing §12.9 trap 3 exists to
  permit;
- **plural-bearing keys** must use a `StaticString` key so the interpolation reaches the lookup:

  ```swift
  public func pipCount(_ count: Int) -> String {
      String(localized: "PIP_COUNT", defaultValue: "\(count) pips",
             bundle: Bundle(url: bundleURL), locale: locale)
  }
  ```

  T07 ships the plural entries; T01 ships this shape and one worked example so the pattern exists
  before eight accessors copy it. Record the two-form split in `DECISIONS.md` with this reasoning —
  it will read like an inconsistency to anyone who has not hit the plural-selection problem.

`#bundle` is Swift 6.1+'s spelling and resolves correctly in both a package resource bundle and a
framework. If the toolchain on the runner rejects it, `Bundle.module` is the equivalent inside a
SwiftPM target — change it in one place and record the substitution.

### The call-site spelling — a deliberate deviation, recorded

E08–E17 wrote `Loc.benchHandle`, `Loc.seal`, `Loc.rotorRails` at their call sites, and the
`hunch-accessibility` reference files show the same. Those are *static* members on a type that must
now carry a **runtime-resolved locale**, and a static member cannot. The skill anticipated exactly
this: *"if `Loc` ships as an injected value carrying the resolved locale, the call becomes `loc.x`
and nothing else changes."*

Ship one further step: **`loc[.benchHandle]`**, not `loc.benchHandle`. It removes ~200 one-line
forwarding accessors, it makes "add a string" mean "add an enum case plus a catalog entry" and
nothing else, and it is what makes the reconciliation check a two-line grep. The migration is
mechanical:

```bash
# Plain accessors: Loc.foo → loc[.foo]. Run it, then compile; the interpolating ones (which take
# arguments and are therefore followed by `(`) are left alone by the negative lookahead.
grep -rlZ 'Loc\.' Modules/Sources \
  | xargs -0 perl -pi -e 's/\bLoc\.([a-z][A-Za-z0-9]*)\b(?!\()/loc[.$1]/g'
```

Then install the value once, in the composition root, so every view and every `@MainActor` model
reads the same one:

```swift
// Modules/Sources/HunchUI/LocEnvironment.swift  (or beside Loc, if the file stays one type)
extension EnvironmentValues { @Entry public var loc: Loc = .system }
```

`04 A26`: `HunchUI` components read `@Environment(\.loc)` and the `@Entry` default covers previews,
which install nothing. Non-`View` owners — `Round`, `Codex`, the announcement posters — take
`loc: Loc` in `init` from `AppDependencies`, the same way they already take `now` and `cues`. Record
the deviation and this reasoning in `DECISIONS.md`, and note in it that the `Loc.x` spelling in
`hunch-accessibility/references/*.md` is superseded by `loc[.x]`.

### The catalog file

A String Catalog is JSON with a stable shape. Author it, do not hope for extraction:

```json
{
  "sourceLanguage" : "en",
  "version" : "1.0",
  "strings" : {
    "SETTINGS_ROW_THEME" : {
      "extractionState" : "manual",
      "comment" : "§12.6 DISPLAY. Settings row label. ≤ 22 chars in English; budget +40 %.",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Theme" } }
      }
    }
  }
}
```

Three details that decide whether check 8 can ever be green:

- **`"extractionState": "manual"`** on every entry. Without it Xcode marks hand-authored entries
  stale on the next build and check 8 fails on `needsReview` forever.
- **`"state": "translated"`**, never `"new"`. `"new"` is exactly what check 8 fails on, which is
  the mechanism T03 relies upon.
- **A `comment` on every entry naming its screen and its budget.** It is the only context a
  translator gets, and T03's reviewers will ask for it if it is not there.

The `Package.swift` edit is one line on the `HunchUI` target:

```swift
resources: [.process("Resources")],
```

`.process`, not `.copy` — `.process` is what compiles the `.xcstrings` into `.lproj` directories.
With `.copy` the file ships verbatim, every lookup misses, and every key resolves to itself, which
is precisely the failure `everyKeyResolves` is written to catch.

### The reconciliation check

Determine the next free number before writing it — the roster has grown since E01 and checks are
appended, never renumbered:

```bash
grep -oE '^# +[0-9]+\.' Scripts/check-source-hygiene.sh | tail -1
```

Call it **N**. Append, following `source-hygiene.md` §3's conventions (`|| true` on every grep,
one `report` per category, never end on `grep -q … && exit 1`):

```bash
# N. LocKey and the catalog are one inventory in two files — §12.9, owner hunch-build-and-ci.
#    Neither may hold a key the other does not. The enum's raw values are the catalog's keys.
if [ "$fast" -eq 0 ] && [ -f "$catalog" ] && [ -f Modules/Sources/HunchUI/LocKey.swift ]; then
  enumKeys=$(grep -oE '= "[A-Z0-9_]+"' Modules/Sources/HunchUI/LocKey.swift \
             | tr -d '="' | sort -u || true)
  fileKeys=$(jq -r '.strings | keys[]' "$catalog" | sort -u || true)
  onlyEnum=$(comm -23 <(echo "$enumKeys") <(echo "$fileKeys") || true)
  onlyFile=$(comm -13 <(echo "$enumKeys") <(echo "$fileKeys") || true)
  [ -n "$onlyEnum" ] && report 'LocKey cases with no catalog entry (they resolve to their own key):' "$onlyEnum"
  [ -n "$onlyFile" ] && report 'Catalog entries with no LocKey case (unreachable, and they cost budget):' "$onlyFile"
fi
```

It sits inside the `--fast` guard because it needs `jq`, exactly like check 8.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/CatalogResolutionTests` green — every `LocKey` case resolves, none falls back to its raw value, raw values are unique, the bundle is not `Bundle.main`.
- [ ] `bash Scripts/check-source-hygiene.sh` green, and its output for the four planted violations — key budget, `"state": "new"`, duplicate English, and one missing `LocKey` case — is pasted into `.github/pr-body.md`, each run exiting 1 and naming its check.
- [ ] `jq '.strings | length' Modules/Sources/HunchUI/Resources/Localizable.xcstrings` is ≤ 250 and equals `grep -c '= "' Modules/Sources/HunchUI/LocKey.swift`.
- [ ] `jq -r '[.strings[].extractionState] | unique' …/Localizable.xcstrings` is `["manual"]`.
- [ ] `grep -rn '\bLoc\.' Modules/Sources | grep -v 'Loc\.swift'` returns nothing — no static call site survives the migration.
- [ ] `xcodebuild -showBuildSettings -scheme Hunch | grep -i STRING_CATALOG_GENERATE_SYMBOLS` shows it off or absent, and `swift build --package-path Modules` still resolves (`08 §7.11`).
- [ ] `grep -n 'resources:' Modules/Package.swift` shows `.process("Resources")` on `HunchUI` and nowhere else.
- [ ] `tests.json` carries the three entries, each with a runnable `command`.
- [ ] The fast suite is still under 10 s (this task adds nothing to `HunchCore`).

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T01: the String Catalog, LocKey, the Loc accessor and the reconciliation check"`

## Out of scope

- **The English wording of any string** — **T02**. This task ships the machinery and whatever
  English the existing call sites already carried; T02 rewrites all of it.
- **The eleven other languages** — **T03**.
- **The two `Text(` traps and `PlaySurfaceTextTests`** — **T04**.
- **The override, `.lproj` resolution, `layoutDirection` and `AppleLanguages`** — **T05**. `Loc` is
  built to carry an overridden bundle and locale here; nothing sets them yet.
- **Plural variations** — **T07**. This task ships one worked plural accessor as the pattern; the
  catalog entries that make it work are T07's.
- **The banned-lexeme checker and the `Info.plist` assertions** — **T08**.
- **Which accessibility strings exist and what they say** — **E19·T01–T05**. This task's `LocKey`
  holds whatever E08–E17 already named; E19 completes the element map, and check 8 fails on every
  key it adds until it is translated, which is the point.
