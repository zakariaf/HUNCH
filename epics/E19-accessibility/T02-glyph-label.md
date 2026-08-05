# T02 — The glyph label

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | Glyph label (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | Owns the label's wording and shape. `references/voiceover-elements.md` §9 is the whole task: one format string with four interpolations, `pips` as its own plural-aware entry, the terse form joined by the locale's list grammar rather than by a comma, the return type `String` and not `LocalizedStringResource`, and the two fallbacks that stop a twin ever speaking an empty string. |

`hunch-design-tokens` is **not** loaded: this task draws nothing. No hue, no register, no geometry
appears in a label — the four value *names* are catalog entries, and their visual encodings are
`hunch-glyph-renderer`'s.

## Objective

At the end of this task `loc.glyphLabel(_:relativeTo:detail:)` speaks any of the 256 glyphs as **one**
localized sentence in canonical `fill → shape → pips → hue` order, with the pips interpolation a
plural-aware String Catalog entry and therefore a complete grammatical unit rather than a glued
fragment. All 256 labels are non-empty and pairwise distinct, which is the audio proof of the same
claim §13.5.1 proves in pixels.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 (canonical ordering) | `fill → shape → pips → hue`, everywhere and forever; the four value names verbatim; "one localized format string with four interpolations, never concatenated fragments" |
| `GAME_DESIGN.md` | §13.10 (glyph label) | `GLYPH_LABEL = "%1$@ %2$@, %3$@, %4$@"` → *"hollow triangle, three pips, teal"*; the pips interpolation is itself a plural-aware entry |
| `GAME_DESIGN.md` | §12.6 (VOICEOVER · Detail) | Full / Terse, default Full; Terse omits attributes unchanged from the previous glyph |
| `GAME_DESIGN.md` | §12.9 trap 3 | never concatenate translated fragments — one format string per sentence, interpolations only |
| `GAME_DESIGN.md` | §12.9 trap 4 | plurals are per-language grammar; Russian needs four categories and Arabic six; any `count == 1 ? … : …` is a bug |
| `GAME_DESIGN.md` | §12.9 (accessibility subtotal) | the glyph label format is **1** key of 134; the 20 attribute and value names are separate keys, already shipped by E18 |
| `.claude/skills/hunch-accessibility/references/voiceover-elements.md` | §9 | the builder's exact shape and the three rules it encodes |

## TDD — the test comes first

The catalog is compiled to `.lproj` at build time, so `swift test` cannot rely on it. Two mechanisms
make this fully testable on the host anyway, and the test uses both:

- every `loc` accessor is written `String(localized:defaultValue:bundle:locale:)`, so a missed lookup
  returns the **English default value** — which is the English copy;
- plural selection cannot be expressed in a `defaultValue`, so a small **fixture bundle** with real
  `.strings` and `.stringsdict` files proves the builder selects a plural *variation* rather than
  branching on the count. The fixture proves the mechanism; E18's completeness test and T11's
  AX5 × 5-locale snapshot prove the copy.

**Step 1 — write the failing test.** Create the fixture first,
`Modules/Tests/HunchUITests/Fixtures/GlyphLabel.bundle/en.lproj/Localizable.stringsdict`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>PIP_COUNT</key>
  <dict>
    <key>NSStringLocalizedFormatKey</key><string>%#@pips@</string>
    <key>pips</key>
    <dict>
      <key>NSStringFormatSpecTypeKey</key><string>NSStringPluralRuleType</string>
      <key>NSStringFormatValueTypeKey</key><string>d</string>
      <key>one</key><string>one pip</string>
      <key>other</key><string>%d pips</string>
    </dict>
  </dict>
</dict></plist>
```

and `…/Fixtures/GlyphLabel.bundle/ru.lproj/Localizable.stringsdict` with `one` / `few` / `many` /
`other` populated so the three categories Russian actually reaches for 1…4 are distinguishable.
Declare the directory `resources: [.copy("Fixtures")]` in `Modules/Package.swift` and **pass
`subdirectory: "Fixtures"` at every lookup** (`06 T54`).

Then create `Modules/Tests/HunchUITests/GlyphLabelTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI

@Suite("The glyph label — §2, §13.10", .tags(.unit, .presubmission))
struct GlyphLabelTests {

    private let en = Loc.english
    private func fixtureLoc(_ identifier: String) throws -> Loc {
        let url = try #require(Bundle.module.url(forResource: "GlyphLabel",
                                                 withExtension: "bundle",
                                                 subdirectory: "Fixtures"))
        return Loc(bundleURL: url, locale: Locale(identifier: identifier))
    }

    // MARK: the full form

    @Test("the full form is one format string, four interpolations, in canonical order")
    func fullFormIsCanonical() {
        let g = Glyph(fill: .hollow, shape: .triangle, pips: .three, hue: .teal)
        #expect(en.glyphLabel(g, relativeTo: nil, detail: .full) == "hollow triangle, three pips, teal")
    }

    @Test("the order is fill → shape → pips → hue for a glyph whose four names are all distinct")
    func orderIsFillShapePipsHue() {
        let g = Glyph(fill: .striped, shape: .hexagon, pips: .one, hue: .rose)
        let label = en.glyphLabel(g, relativeTo: nil, detail: .full)
        let fill = try! #require(label.range(of: "striped"))
        let shape = try! #require(label.range(of: "hexagon"))
        let pips = try! #require(label.range(of: "pip"))
        let hue = try! #require(label.range(of: "rose"))
        #expect(fill.lowerBound < shape.lowerBound)
        #expect(shape.lowerBound < pips.lowerBound)
        #expect(pips.lowerBound < hue.lowerBound)
    }

    // MARK: the strongest assertion in the file

    @Test("all 256 labels are non-empty and pairwise distinct")
    func everyGlyphSpeaksDistinctly() {
        let labels = Deck.all.map { en.glyphLabel($0, relativeTo: nil, detail: .full) }
        #expect(labels.count == 256)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == 256)
    }

    // MARK: pips is a grammatical unit

    @Test("pips is plural-aware in English: one is singular, two/three/four are not")
    func englishPluralCategories() throws {
        let loc = try fixtureLoc("en")
        #expect(loc.pipCount(1) == "one pip")
        #expect(loc.pipCount(2) != loc.pipCount(1))
        #expect(loc.pipCount(3).contains("pips"))
    }

    @Test("pips selects a Russian plural CATEGORY, not an English if — 1 is `one`, 2…4 are `few`")
    func russianPluralCategories() throws {
        let loc = try fixtureLoc("ru")
        let one = loc.pipCount(1), two = loc.pipCount(2), three = loc.pipCount(3), four = loc.pipCount(4)
        #expect(one != two)                                  // `one` ≠ `few`
        // 2, 3 and 4 all fall in `few`, so they differ only by their numeral.
        #expect(two.replacingOccurrences(of: "2", with: "#")
                == three.replacingOccurrences(of: "3", with: "#"))
        #expect(three.replacingOccurrences(of: "3", with: "#")
                == four.replacingOccurrences(of: "4", with: "#"))
    }

    // MARK: terse

    @Test("terse speaks only the attributes that changed")
    func terseSpeaksOnlyTheChange() {
        let a = Glyph(fill: .hollow, shape: .triangle, pips: .three, hue: .teal)
        let b = Glyph(fill: .solid,  shape: .triangle, pips: .three, hue: .teal)
        #expect(en.glyphLabel(b, relativeTo: a, detail: .terse) == "solid")
    }

    @Test("terse joins an enumeration with the locale's list grammar, never with a literal comma")
    func terseUsesTheLocalesListStyle() {
        let a = Glyph(fill: .hollow, shape: .triangle, pips: .three, hue: .teal)
        let b = Glyph(fill: .solid,  shape: .triangle, pips: .three, hue: .rose)
        let expected = ["solid", "rose"].formatted(.list(type: .and, width: .narrow)
                                                    .locale(Locale(identifier: "en")))
        #expect(en.glyphLabel(b, relativeTo: a, detail: .terse) == expected)
    }

    @Test("a twin — nothing changed — falls back to the full label, never to an empty string")
    func twinFallsBackToFull() {
        let g = Glyph(fill: .dotted, shape: .square, pips: .four, hue: .frost)
        #expect(en.glyphLabel(g, relativeTo: g, detail: .terse)
                == en.glyphLabel(g, relativeTo: nil, detail: .full))
    }

    @Test("all four changed also falls back to the full label — terse would be the full form with worse grammar")
    func allFourChangedFallsBackToFull() {
        let a = Glyph(fill: .hollow, shape: .circle,  pips: .one,  hue: .amber)
        let b = Glyph(fill: .solid,  shape: .hexagon, pips: .four, hue: .rose)
        #expect(en.glyphLabel(b, relativeTo: a, detail: .terse)
                == en.glyphLabel(b, relativeTo: nil, detail: .full))
    }

    @Test("detail .full ignores the previous glyph entirely")
    func fullIgnoresPrevious() {
        let a = Glyph(fill: .hollow, shape: .triangle, pips: .three, hue: .teal)
        let b = Glyph(fill: .solid,  shape: .triangle, pips: .three, hue: .teal)
        #expect(en.glyphLabel(b, relativeTo: a, detail: .full)
                == en.glyphLabel(b, relativeTo: nil, detail: .full))
    }

    // MARK: the type

    @Test("the builder returns an already-resolved String, so every call site is Text(verbatim:)")
    func returnsAResolvedString() {
        let value: String = en.glyphLabel(Deck.glyph(id: 0), relativeTo: nil, detail: .full)
        #expect(!value.isEmpty)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter GlyphLabelTests`

Expect missing `loc.pipCount(_:)` and a `glyphLabel` that ignores `detail:` (T01 landed the full form
only). `everyGlyphSpeaksDistinctly` is the one that will pass accidentally against T01's stub — that is
correct and expected, and it is the assertion that must **keep** passing after the plural entry is
introduced, because a plural bug that collapses "one pip" and "1 pips" into the same string would break
distinctness across a fill/shape pair. Confirm `russianPluralCategories` fails on a missing fixture
before writing the fixture, so you know the bundle lookup is live.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/Loc.swift` — `glyphLabel(_:relativeTo:detail:)`, `pipCount(_:)`, `name(_:)` for the four attribute value sets |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — the `PIP_COUNT` plural entry, if E18 shipped it as a flat string |
| create | `Modules/Tests/HunchUITests/Fixtures/GlyphLabel.bundle/{en,ru}.lproj/Localizable.{strings,stringsdict}` |
| create | `Modules/Tests/HunchUITests/GlyphLabelTests.swift` |
| modify | `Modules/Package.swift` — `resources: [.copy("Fixtures")]` on `HunchUITests` if not already declared |
| modify | `HunchCore/Sources/Glyphs/Glyph.swift` — `attributes(differingFrom:) -> [Glyph.Attribute]`, pure and `Sendable` |
| modify | `DECISIONS.md` — the numeral-as-word ruling below |
| modify | `tests.json` — the glyph-label entry |

## Implementation notes

### The builder

```swift
// Modules/Sources/HunchUI/Loc.swift — every accessor returns an ALREADY-RESOLVED String.
public func glyphLabel(_ g: Glyph,
                       relativeTo previous: Glyph?,
                       detail: VoiceOverDetail) -> String {
    let changed = detail == .terse ? (previous.map(g.attributes(differingFrom:)) ?? []) : []

    guard !changed.isEmpty, changed.count < Glyph.Attribute.allCases.count else {
        // Full form: ONE format string, four interpolations, `pips` plural-aware inside its own entry.
        return String(localized: "GLYPH_LABEL",
                      defaultValue: "\(name(g.fill)) \(name(g.shape)), \(pipCount(g.pips.rank)), \(name(g.hue))",
                      bundle: bundle, locale: locale)
    }
    // Terse: an ENUMERATION of the changed values, joined by the locale's own list grammar.
    // Never `joined(separator: ", ")` — that is trap 3 wearing a comma.
    return changed.map { valueName(of: g, $0) }
                  .formatted(.list(type: .and, width: .narrow).locale(locale))
}
```

Three rules the shape encodes, all of them load-bearing:

- **Every label builder takes `relativeTo previous:`**, even where terse is not yet wired, because
  adding the parameter later means touching every call site. T01 already made every call site pass it.
- **An empty changed-set falls back to the full label**, so a twin never speaks an empty string — and
  so does an all-four-changed set, because at that point the terse form is the full form with worse
  grammar and no comma discipline.
- **The return type is `String`, not `LocalizedStringResource`.**
  `LocalizedStringResource(stringLiteral:)` treats its argument as a **key**, so handing it a
  runtime-joined list looks like it works and is really a failed lookup falling back to itself. Call
  sites are `Text(verbatim:)`; re-wrapping a resolved `String` in the localizing `Text` overload is a
  second lookup against `Bundle.main` that fails silently and yields the key.

### The pips entry, and the numeral ruling

§13.10 illustrates the plural entry as `"1 pip" / "3 pips"` and, two lines later, renders the label as
*"hollow triangle, three pips, teal"*. Those are two different spellings of the numeral. **Ruling: the
English variations spell the numeral as a word — `one pip` / `two pips` / `three pips` / `four pips` —
because the rendered example is the string the player actually hears, and "1 pip" reads as a
measurement rather than as part of a sentence.** The `"1 pip"/"3 pips"` line is illustrating
*plural-awareness*, not the copy. Record it in `DECISIONS.md`; the test fixture above uses `%d` on
purpose so it tests the *mechanism* independently of that copy choice, and E18's translations carry
whatever each language's own convention is.

The argument is the pip **count**, an `Int` in 1…4, not a `Glyph.Pips` case:

```swift
public func pipCount(_ count: Int) -> String {
    String(localized: "PIP_COUNT", defaultValue: "\(count) pips", bundle: bundle, locale: locale)
}
```

The range being 1…4 does **not** license dropping a plural category. Russian reaches `one` at 1 and
`few` at 2–4; Arabic reaches `one`, `two` and `few`. A catalog entry declares the categories the
*language* has, not the categories the *data* visits, because the next caller of `PIP_COUNT` may not
be the pips channel. And any `count == 1 ? … : …` anywhere in the codebase is a bug (§12.9 trap 4),
including inside a `defaultValue`.

### `attributes(differingFrom:)` is core

The comparison is a pure function of two glyphs, so it belongs in `HunchCore` beside `Glyph` and
returns the differing attributes **in canonical order** — which is what makes the terse enumeration
deterministic rather than dependent on a `Set`'s iteration order:

```swift
// HunchCore/Sources/Glyphs/Glyph.swift
public func attributes(differingFrom other: Glyph) -> [Attribute] {
    Attribute.allCases.filter { self[$0] != other[$0] }      // allCases is fill, shape, pips, hue
}
```

### What this task does not touch

The four *value* names (`hollow`, `triangle`, `three`, `teal`, …) and the four *attribute* names are
20 catalog keys E18 already shipped. This task consumes them; it does not rewrite them, and it does not
add a twenty-first. The label format is **1** key of §12.9's 134, and adding a second format string for
"a slightly different glyph label" is how a hard 250-key ceiling is discovered at 251.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter GlyphLabelTests` green, all eleven tests.
- [ ] `grep -Rn 'joined(separator' Modules/Sources/HunchUI/Loc.swift` returns nothing.
- [ ] `grep -RnE '== 1 \?|count == 1' Modules/Sources/HunchUI` returns nothing.
- [ ] `grep -Rn 'Text(loc\.' Modules/Sources --include='*.swift'` returns nothing without `verbatim:` — every call site is `Text(verbatim: loc.…)`.
- [ ] `grep -c 'GLYPH_LABEL' Modules/Sources/HunchUI/Loc.swift` is exactly 1 — one format string, one call site inside the builder.
- [ ] `DECISIONS.md` carries the numeral-as-word ruling with §13.10 cited on both sides.
- [ ] `tests.json` carries the glyph-label entry, `source: "§2, §13.10"`, with the 256-distinctness command.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T02: the glyph label — one format string, four interpolations, plural-aware pips"`

## Out of scope

- The twelve translations of `GLYPH_LABEL`, `PIP_COUNT` and the 20 value names — **E18·T03**.
- The `voiceOverDetail` Settings row that selects Full or Terse — **E17·T07**; this task consumes the value.
- The law narration's format strings — **T03**, which is a different sentence with a different owner.
- The visual encoding of any of the four channels — **E04·T01–T04**.
- The ≤ 250-key CI assertion — **E18·T01**; re-run it here, do not re-implement it.
