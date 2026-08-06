# SPEC.md

The self-contained specification derived from `hunch-claude-code-prompt.md`. Where this file and
`GAME_DESIGN.md` disagree, **`GAME_DESIGN.md` wins** — it is canon and this is the index into it.

## What is being built

HUNCH: an offline iPhone rule-induction puzzle. The Loom holds a hidden predicate over a
256-glyph deck and answers each probe with one bit. The player deduces the law and states it
back by assembling rule-tiles. 27,015 distinct laws across eight bands, one law family each.

Full design: `GAME_DESIGN.md` (14 sections). Engineering rules: `ios-swift-guide/` (365 numbered
rules, cited by id). Drawing and code standards: `.claude/skills/` (13 skills). Delivery board:
`epics/` (20 epics, 190 tasks).

## Named artefacts

| Artefact | Path | Owner |
|---|---|---|
| App shell (`@main` and nothing else) | `App/HunchApp.swift` | E01·T02 |
| Build settings, all of them | `Config/*.xcconfig` | E01·T02 |
| Pure domain package, no UIKit/SwiftUI | `HunchCore/` | E01·T03 |
| Seeded RNG | `HunchCore/Sources/LawGeneration/SplitMix64.swift` | E01·T05 |
| Test helpers, never a product | `HunchCore/Sources/HunchTestSupport/` | E01·T03,T04 |
| The ten hygiene checks | `Scripts/check-source-hygiene.sh` | E01·T06 |
| SwiftUI feature modules | `Modules/` | E03·T06 |
| Design tokens, the only home for a value | `HunchCore/Sources/Tokens/` | E03·T01 |
| The ghost frame — **five of six sites shipped** (throat seed, ribbon `prev`, twin split ring, sheet, counterexample); E09 owns the sixth, the Bench's ghost toggle. There is one drawing. | `Modules/Sources/HunchUI/Marks/GhostFrame.swift` | E04·T07 |
| §6.1's transition table, the only writer of a phase | `HunchCore/Sources/Rounds/RoundPhase+Advance.swift` | E07·T07 |
| The one point at which round state becomes true | `Round.commit(_:)`, `Modules/Sources/LoomFeature/Round.swift` | E08·T01 |
| Test helpers for `Modules/`, never a product | `Modules/Sources/ModulesTestSupport/` | E08·T01 |

The complete annotated tree is `ios-swift-guide/08-APPLIED-TO-HUNCH.md` §1.

## Hard constraints

Violating any of these is a failed build, not a style question.

1. **No network.** No `URLSession`, `Network`, CloudKit, WebKit, analytics or crash SDK. Check 5.
2. **No third-party dependencies.** Zero SPM packages, zero CocoaPods.
3. **No text on the play surface**, in any of the twelve locales. Check 7.
4. **Every value is a token.** No literal colour, dimension, opacity or duration outside
   `Tokens/`. Check 9.
5. **Determinism.** The same `(seed, band, targetδ, mode)` produces a byte-identical puzzle
   across runs and processes. Randomness is a threaded parameter. Check 6.
6. **`swift test` under 10 seconds.** Enforced in CI, not hoped for.
7. **No IAP, ads, lives, timers-as-monetisation, accounts or notifications.**
8. **iPhone only, portrait only, under 15 MB.**
9. **No cognitive-improvement or health claim**, anywhere, in any locale. Check 8 against
   `Scripts/banned-lexemes.txt`.

## Verification, per requirement

| Requirement | How it is proven | Where |
|---|---|---|
| Generator invariants at scale | 10,000 laws per band: satisfiable, falsifiable, non-degenerate, constructible | E06 |
| Simulated player converges, holds ~80 % | `ResponseHarness` (10⁶ rounds) and `ReasonerHarness` | E11 |
| `difficulty(of:)` predicts failure | Spearman ρ ≥ 0.75 overall, ≥ 0.45 within band | E11 |
| Determinism across processes | committed golden fixture + reference vectors | E01·T05, E06·T10 |
| Localization completeness | check 8 over the String Catalog, 12 locales | E18 |
| Persistence round-trip and migration | `Fixtures/v1/` must load green forever | E07 |
| No network | check 5, in the build phase and CI | E01·T06 |

## Explicitly out of scope

iPad, landscape, macOS, multiplayer, accounts, iCloud/sync, leaderboards, IAP, ads, any network
code, a level editor, share/export, third-party dependencies, image assets, audio assets,
bundled fonts, tutorial screens, a difficulty picker, widgets, notifications. Full list with
reasons: `GAME_DESIGN.md` §14.4.
