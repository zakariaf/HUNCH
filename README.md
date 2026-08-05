# HUNCH

A rule-induction puzzle for iPhone. A machine — the Loom — admits some glyphs and rejects others
according to a law it will never state. You probe it, read the transcript, and when you think you
know the law you assemble it from rule-tiles and commit. Correct, and the law is inscribed in your
Codex. Wrong, and the Loom answers with a single counterexample.

Nothing is explained in words, because there are none: the play surface renders zero text in every
one of the twelve shipped languages. Verdicts are ring geometry, budgets are tick marks, and the law
itself is a diagram. The game runs entirely on device, offline, forever.

## Requirements

- **Xcode 26.6** (Swift 6.3.3, iOS 26.5 SDK)
- **iOS 18.0** deployment floor
- **No third-party dependencies.** Not one, in either package. This is a hard constraint, enforced
  by `Scripts/check-source-hygiene.sh` and by CI.

## Build

`Config/Local.xcconfig` is gitignored, and a fresh clone will not sign without it. Create it:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
CODE_SIGN_STYLE = Automatic
HUNCH_BUNDLE_ID_PREFIX = com.yourdomain
```

Everything else lives in `Config/Base.xcconfig` and is committed. If the project builds for you and
not for a colleague, this file is the first thing to check.

## The two loops

```bash
swift test --package-path HunchCore                       # the fast loop: under 10 s, no simulator
xcodebuild test -scheme Hunch -testPlan Presubmission      # the full loop
```

`swift test --package-path Modules` is **not** a command in this repo — the UI package is built
through the app target, not standalone.

## Layout

Two local SwiftPM packages and a thin app shell. `HunchCore` holds the game's logic and imports
neither UIKit nor SwiftUI; `Modules` holds the SwiftUI feature modules; `App` is the composition
root and little else.

The annotated tree is `ios-swift-guide/08-APPLIED-TO-HUNCH.md` §1. It is not copied here, so that
there is one description of the layout rather than two that disagree.

## Persistence

**No SwiftData. No Core Data.** State is `Codable` JSON, written atomically behind a
`PersistenceStore` protocol and sharded per `GAME_DESIGN.md` §11.13.

The reasoning, recorded because a future reader will ask: the Codex in total sits above the
threshold at which flat JSON stops being appropriate, but each shard sits well below it, and shards
load lazily — only the shelf you open is parsed. That keeps the launch cost to a small index file
while leaving the domain package free of a persistence framework, which is what allows `swift test`
to run in seconds with no simulator. The cost is that change notification is hand-written rather
than free, and the archive layer pays it in one place.

## The documents

| File | What it is |
|---|---|
| `GAME_DESIGN.md` | Canon. The full specification of the game. |
| `hunch-claude-code-prompt.md` | The original brief this was built from. |
| `ios-swift-guide/` | Seven files of numbered engineering rules, cited by id. |
| `design/` | The design system scope and the chosen art direction. |
| `epics/` | The delivery board: twenty epics, one directory each. |
| `.claude/skills/` | Thirteen skills that hold the drawing and engineering standards. |
| `CLAUDE.md` | Commands, rules and the gotchas that cost real time. |
| `SPEC.md` | The index into canon: named artefacts, hard constraints, how each is verified. |
| `DECISIONS.md` | Every judgement call made on your behalf, with its reason. |
| `PROGRESS.md` | Current phase, what is done, what is next, known issues. |
| `tests.json` | Every invariant this repo asserts, with its status. |

## What it does not do

No network of any kind. No accounts, no sync, no leaderboards, no analytics, no advertising, no
in-app purchases, no notifications. There is nothing to opt out of, and the privacy manifest says
so because it is true.
