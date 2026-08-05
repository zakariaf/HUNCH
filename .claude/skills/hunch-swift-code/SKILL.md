---
name: hunch-swift-code
description: "Rules where a Swift file goes across HUNCH's two packages, what its declarations are named, how the code is written and where state lives — the placement table, the HunchCore boundary predicate, the naming pass with its three Swift collisions, and the single composition root. Use before creating a Swift file or typing a declaration, and when reviewing a diff for structure, naming, type choice or state ownership. Load this first for engineering work. Concurrency, tests and the build have their own skills."
allowed-tools: Read, Grep, Glob, Bash(find:*), Bash(grep:*), Bash(sed:*), Bash(sort:*), Bash(echo:*), Bash(${CLAUDE_SKILL_DIR}/scripts/*)
metadata:
  version: "1.0"
  owns: "the HunchCore boundary predicate, the target routing table, the naming pass, type choice, state ownership, the composition root"
---

## Targets as they exist right now

```!
r="${CLAUDE_PROJECT_DIR:-.}"
if [ -d "$r/HunchCore/Sources" ] || [ -d "$r/Modules/Sources" ]; then
  find "$r/HunchCore/Sources" "$r/Modules/Sources" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s|^$r/||" | sort
else
  echo "NO SWIFT ON DISK YET — ios-swift-guide/08-APPLIED-TO-HUNCH.md §1 is the tree to build toward."
fi
```

Trust that listing over any tree written down. A target is created the day its owner section is implemented, never on day one (`01 P12`, `08 §7.3`).

## Five decisions, in this order

Answer them top to bottom. Jumping to 4 is how a well-named type ends up in the wrong package, and moving it later flips its language mode and its default isolation at the same time (`01 P16`–`P18`).

1. **Which package** — the boundary predicate, §1.
2. **Which target** — the routing table in `references/file-placement.md` §2.
3. **Which file** — one top-level type, named for it (`01 P24`); three exceptions only (`01 P25`); banned filenames (`01 P28`).
4. **What it is called** — §2, then `references/naming.md`.
5. **What kind of type it is, and who owns its state** — `references/writing-code.md`, `references/architecture-and-state.md`.

## 1. The boundary predicate — two greps, no judgement

> A file may live in `HunchCore/` **iff** (a) it imports nothing but `Swift`/`Foundation`, and (b) its behaviour is a pure function of values you can write down in a test. Fail either half and it belongs in `Modules/`. — `08 §2`

Run it instead of eyeballing it:

```bash
${CLAUDE_SKILL_DIR}/scripts/check-boundary.sh Modules/Sources/HunchUI/GlyphCanvas.swift   # verdict for a candidate
${CLAUDE_SKILL_DIR}/scripts/check-boundary.sh --all                                       # audit HunchCore, non-zero on violation
```

**Half (b) bans *ambient* sources, not parameters.** `Date()` called inside the core is a violation; a `Date` handed in is data. That is why `FilePersistenceStore` is core — its directory arrives in `init` — while `Codex` is not, because `@Observable` is a macro over a `@MainActor` class and drags Observation into a target that must stay nonisolated.

Four things that look like core logic and are app-layer (the par tick row, the Assay's pinned slice, the counterexample's presentation, `Codex`) and two that look app-layer and are core (`BenchLayout`, `RoundPhase`'s transition function) are `08 §2`'s two tables. Read them before arguing with the script.

`Modules/` may import `HunchCore`; `HunchCore` may import nothing of ours. Leave the arrow out of `Package.swift` and the `import` stops compiling — that is why the boundary needs no lint rule (`04 A3`).

## 2. The naming pass — the three collisions that actually bite

| Design word | Ship | What the obvious spelling breaks |
|---|---|---|
| the glyph's four attributes | **nested** `Glyph.Shape`, `Glyph.Fill`, `Glyph.Pips`, `Glyph.Hue` | A top-level `Shape` plus `import SwiftUI` in `HunchUI` is `error: 'Shape' is ambiguous for type lookup in this context` at every use site — reproduced on Swift 6.3.3. `N22` fixes it at the declaration for nothing. |
| a law's truth table, "**extension**" | `struct LawTable: Hashable, Sendable` | `extension` is a keyword. `Extension.swift` would also trip `01 P28`'s banned-filename grep. |
| the ramp / bridge / fork / tally tiles | `Ramp` payload **and** `RampView` widget | `Ramp` is both a data payload and a widget. `N39` permits the `View` suffix precisely to break a collision with a model type; this is that case. |
| band **and** family | one `enum Band` | §5.3 puts them in bijection, so `Family(band)` is an identity function that will drift (`W28`). Keep both words in prose; ship one type. |

The other seventeen rows of the vocabulary are `08 §3`. `references/naming.md` §1 indexes them term → symbol and points back at the row.

## 3. Where state lives

- **One composition root**, `AppDependencies.live()` in `HunchAppFeature`, named in one line by `@main` (`04 A2`, `08 §6`). It holds the store, `Now`, `SeedSource`, `Ladder`, `Codex` and the cue player, and it is the only place any of them is constructed.
- **`SeedSource` is the single point of nondeterminism in the app**, and it lives in `Modules/`. That is what "no singletons" actually means here (`04 A29`): no ambient state inside a boundary you test across.
- **Four earned observables**: `Round` (`A18` triggers 1 and 2 — a nine-phase machine with locked input, strikes and snapshot cadence), `Codex`, `Ladder`, and one `Router` per `NavigationStack` (`A33`). Every other screen holds `@State private` and reads the model in `body`.
- **The pure part stays in `HunchCore` and is tested there** (`A20`): phase transitions, scoring, the ribbon, the verdict. `Round` must stay thin enough that `A19`'s pass-through test still passes — delete it and phase timing, input locking and snapshot cadence break.
- **Derive, never mirror** (`A14`, `A15`). A value read in `.onAppear`, a `Task`, or a button action forms no dependency and never updates again (`A6`).

## Any of the 365 rules, by ID

Never quote a rule from memory and never copy one into code. Print it:

```bash
grep -n '^\*\*W44[. ]' ios-swift-guide/*.md          # one rule, exact
grep -rn 'A18\|A19' ios-swift-guide/                 # every mention, including citations
```

`Scripts/rule.sh W44` is the repo wrapper for the first form when it exists. Prefix → file, the four cited-but-unheadinged rules, and a symptom → rule-ID index are in `references/guide-index.md`.

## Where the detail lives

| Read this | When |
|---|---|
| `references/file-placement.md` | before creating any file or target — the tree, the routing table, and the twelve places HUNCH deviates from the guide with the ruling for each |
| `references/naming.md` | before typing a declaration name — the vocabulary index, the label/boolean/async procedures, the ban list applied to this project |
| `references/writing-code.md` | choosing struct vs enum vs class vs actor, access level across two packages, error shape, optionals, and what not to metaprogram |
| `references/architecture-and-state.md` | anything touching `@Observable`, `@State`, `@Environment`, navigation, persistence, or the composition root |
| `references/guide-index.md` | a cited rule ID whose text you need, or a question whose rule you do not know |

## Gotchas

- **`enum Band: Int, CaseIterable, Comparable, Sendable` does not compile.** A raw type suppresses SE-0266's synthesized `Comparable` — verified on Swift 6.3.3: *"enum declares raw type 'Int', preventing synthesized conformance of 'Band' to 'Comparable'"*. Write `public static func < (lhs: Band, rhs: Band) -> Bool { lhs.rawValue < rhs.rawValue }`. `08 §3` states the declaration without it.
- **`package` access does not cross the two packages.** Everything `Modules/` exposes to `App/` is `public`; inside `HunchCore` `package` still works. That is the one surviving cost of the two-package deviation (`08 §7.2`, `W6`).
- **A `public struct`'s memberwise initialiser is internal.** Write `public init` by hand on every type the composition root constructs, or it will not compile from another target (`04 A29`).
- **`Text(mode.wordmark)` with a `String` is not extracted for localization; `Text("PROBE")` with a literal *is* extracted, which is wrong.** `Text(verbatim:)` is the only spelling that is right on both counts (`08 §3`).
- **Nothing in `HunchCore` is a class.** The only reference types there are the two actors (`08 §4`). If you are about to type `final class` under `HunchCore/Sources/`, the file is in the wrong package.
- **`LawNode` is `Codable` and `Law` is not.** Persist the AST; the resolved `LawTable` and cached `Metrics` are rebuilt (`08 §3`).
- **There is no `Clock` in this project — and this bullet is its one home.** `Now` is the only injected time source and it vends `Date` only; SIEVE's timing is a pure `SieveSchedule` plus one `ContinuousClock.sleep` at the view edge (`08 §5`). This skill owns it because it owns state ownership and the composition root that constructs `Now`. `hunch-swift-concurrency` and `hunch-swift-testing` each carried a near-identical paragraph citing the same `08 §5`; all three are plausible co-invocations on one task, so the duplication cost level-2 budget three times in one session against a shared ceiling that survives compaction. They cite this bullet instead.
- **`HunchTestSupport` is a `.target`, not a `.testTarget`, and is absent from `products:`** — that is what keeps `import Testing` out of the release binary (`01 P20`, `06 T5a`).

## Never

- Never suffix `ViewModel`, or name a type `…Manager`, `…Provider`, `…Helper`, `…Handler`, `…Service`, `…Info`, `…Data` or `…Protocol` (`N25`, `N26`, `N40`). `AudioManager`, `HapticsService`, `RoundViewModel` and `PersistenceStoreProtocol` are the four this project would otherwise produce.
- Never create `Utils.swift`, `Helpers.swift`, `Constants.swift`, `Extensions.swift`, `Extension.swift`, `Managers.swift`, `Common.swift`, `Shared.swift` or `*+Utilities.swift` (`01 P28`, `N45`).
- Never write `import SwiftUI`, `import UIKit`, `import Observation`, `Date()`, `UUID()`, `.random(` or `SystemRandomNumberGenerator` under `HunchCore/Sources/`, and never write network code of any kind anywhere.
- Never write `default:` in a switch over an enum you own (`W29`). Adding a case to `StoreFile` must break the reset map at compile time; that is the whole point of the enum.
- Never add a second composition root, a singleton for game state, or a `static var` anywhere. `static let` of an immutable `Sendable` value is fine and is not what the brief bans.
- Never add a protocol for a one-implementation seam with three members or fewer (`W44`). `PersistenceStore` and `CuePlayer` keep theirs because they are published boundaries, not because of their member count.
- Never author a macro, a property wrapper or a result builder in this codebase (`W45`–`W50`). `@Observable` and `@Entry` are consumed, never written.
- Never type a colour, stroke weight, radius, opacity, duration or font size in Swift — those are tokens and `hunch-design-tokens` owns them. Never restate an `@MainActor`/`Sendable`/actor rule (`hunch-swift-concurrency`), anything under `Tests/` (`hunch-swift-testing`), or an `.xcconfig`, manifest mechanic or CI grep (`hunch-build-and-ci`).
- Never copy a guide rule's text into code, a comment, a commit message or another skill. Cite the ID and let `references/guide-index.md` print it.
