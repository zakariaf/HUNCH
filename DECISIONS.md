# DECISIONS.md

Every judgement call made on the user's behalf, one entry each, newest last. This is the audit
trail: if a choice is not here, it was not a choice.

## E01 — Foundations

| # | Decision | Reason |
|---|---|---|
| 1 | **Proprietary LICENSE**, not an OSI licence. | `GAME_DESIGN.md` §14.5 decision 1 and §14.4: paid once, closed source. An OSI licence would be actively wrong, and it is irreversible after publication. Reverse this before any public push if the intent is in fact to open-source. |
| 2 | `50-apps-challenge-slides.html` left untracked. | Unrelated to HUNCH. `hunch-claude-code-prompt.md` **is** committed, because `SPEC.md` cites it and a cited artefact outside the repository is a broken reference. |
| 3 | **`SDKROOT` and `SUPPORTED_PLATFORMS` restated in `Base.xcconfig`.** | The wizard writes `SDKROOT` into the *project-level* `buildSettings`, which `07 B5` requires us to empty. With it emptied there is no default to inherit: every target resolved to macOS and the scheme offered no iOS destination at all. This is not `07 B13`'s "restating a default" — there is no default left. |
| 4 | **`PRODUCT_NAME = $(TARGET_NAME)`**, not the literal `Hunch`. | Base applies to all three targets, so a literal makes all three emit `Hunch.swiftmodule` and the build fails with "Multiple commands produce". |
| 5 | **Four extra xcconfigs**: `UnitTests`, `UnitTestsRelease`, `UITests`, `UITestsRelease`. | A unit-test bundle needs `TEST_HOST`/`BUNDLE_LOADER`; a UI-test bundle sets `USES_XCTRUNNER`; Xcode rejects a target carrying both. xcconfig has no per-target conditional (only sdk/arch/variant/config), so per-target files are the only spelling that keeps `07 B5`'s zero-inline-settings rule intact. |
| 6 | **`SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` on the UI-test target.** | `XCTestCase`'s designated initialisers are nonisolated, so inheriting Base's `MainActor` default is a hard error on every subclass. `08 §4` scopes that setting to `App/` anyway. |
| 7 | **`HunchUITests` renamed `HunchAutomationTests`.** | `06 T5b` mirrors source paths, so `HunchUI`'s package tests will be `Modules/Tests/HunchUITests` (E03·T06). Two bundles with one name makes `-only-testing:HunchUITests` ambiguous. |
| 8 | **`HunchTestSupportTests` added** to the reference manifest's target list. | `06 T5b` asks for one test target per source target, and `isApproximatelyEqual` is what every floating-point assertion in the project routes through. An untested comparison helper silently falsifies every test that uses it. |
| 9 | **`Corpora.swift` deferred from T04 to after T05**, as a second commit against T04. | Its `seed(band:index:)` is built on `SplitMix64`, which is T05's deliverable. Stubbing it in T04 would have invented a derivation and then changed it — and this derivation is frozen (below). |
| 10 | **`SplitMix64.gamma = 0x9E3779B97F4A7C15`**, the reference 2⁶⁴/φ constant. | `GAME_DESIGN.md` §11.6 fixes the *finaliser* and is silent on the *increment*. Two spellings of `next()` are two different games; the cross-process golden fixture (E06·T10) freezes this one. |
| 11 | **`Corpora.seed` vectors frozen from the shipped implementation.** | Recorded, not asserted from memory: the first spelling of `derivationIsFrozen` carried an invented constant and failed, which is why the assertion exists. Changing the derivation now invalidates every recorded `(band, index)` repro in the project's history. |
| 12 | **Check 4 hardened to fail when `swift package describe` fails.** | Reproduced: with a cyclic dependency, `describe` writes to stderr and yields no JSON, a `jq` filter over nothing finds nothing, and the script printed "Source hygiene: clean" over a broken manifest. A check that cannot fail is worse than no check. |
| 13 | **`banned-lexemes.txt` matching is case-insensitive but NOT diacritic-insensitive.** | `test($w; "i")` folds case only. §1.13 requires both. The compensating measure is that every accented form is listed explicitly (`memoria`/`memória`, `concentración`/`concentração`). Real diacritic folding is a change to check 8 with a written decision, not a quiet regex tweak. |
| 14 | **No `includeTags` on the Nightly and Prerelease plans.** | XCTest cases carry no Swift Testing tags, so a tag filter selects zero of them and reports a green run over nothing. Those two plans filter by target instead. |
| 15 | **CI's gate ladder lists only scripts that exist**, with the rest commented and attributed to the task that creates them. | A CI step whose script is missing either fails every build or is guarded into uselessness. Both are worse than adding the line when the script lands. |

## E03 — Design tokens

| # | Decision | Reason |
|---|---|---|
| 16 | **`HunchCore` gains a ninth source target, `Tokens`**, which `08 §1`'s tree does not list. | `DESIGN-SYSTEM-SCOPE.md` §4.4 rules the token layer into `HunchCore` so that `swift test` can assert every contrast ratio with no simulator; `package-manifests.md` §2 is the manifest of record and does list it. |
| 17 | **`Tokens` does not depend on `Glyphs`**, even though `Palette.Hue` mirrors `Glyph.Hue`'s four cases. | That mapping is one four-arm `switch` owned by the renderer. One switch is cheaper than a package dependency edge, and it keeps `Tokens` a leaf. |
| 18 | **The environment resolution order is Select → Scale → Offset → Derive.** `weight(.body)` under Bold Text *and* High Contrast is `3.0 × 1.25 + 0.5 = 4.25`, never `(3.0 + 0.5) × 1.25 = 4.375`. | The GDD states both modifiers (§13.11) and never their order. §13.11 spells Bold Text multiplicatively with worked values that must hold (`hairline` 0.5 → 0.625) and High Contrast as a flat `+0.5 pt`; an offset that also got multiplied would silently become `+0.625` and the two accessibility settings would stop composing independently. Asserted both ways, the second negatively. |
| 19 | **§13.11's "9.7 : 1 High Contrast floor" is asserted at the measured 9.68.** | The binding member of the state-bearing set, `stroke.secondary` on `#B0B0B0`, measures **9.683**, and `hunch-design-tokens` already documents it as 9.68. "9.7" is a rounded restatement of that measurement, not an independent threshold — asserting `>= 9.7` fails a palette that is exactly as specified. All four ratios are additionally pinned individually so a palette edit cannot hide inside a loose inequality. |
| 20 | **Parity of naming: `ContrastTests.swift` rather than `PaletteContrastTests.swift`.** | The suite spans `Palette`, `Prim` and `C`; naming it after one of the three would misdescribe it. |
