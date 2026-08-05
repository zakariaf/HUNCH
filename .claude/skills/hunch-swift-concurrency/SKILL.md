---
name: hunch-swift-concurrency
description: "Rules HUNCH's isolation — default isolation per target, the MainActor roster, the exactly two justified actors, Sendable conformances, the seeded RNG that never escapes one synchronous call tree, and the single documented unchecked-Sendable hatch for the audio render thread. Use when a concurrency diagnostic appears, when adding async, actor, Sendable, nonisolated, Task or @concurrent, or when choosing between a Sendable struct, @MainActor @Observable, Mutex and actor for a piece of mutable state. Not for general code style or naming — see the code skill."
allowed-tools: Read, Grep, Glob
metadata:
  version: "1.0"
  owns: "default isolation per target, the MainActor roster, the two actors, the RNG scoping rule, the one escape hatch"
---

## Isolation as it exists right now

```!
r="${CLAUDE_PROJECT_DIR:-.}"
for m in "$r/HunchCore/Package.swift" "$r/Modules/Package.swift"; do
  [ -f "$m" ] && { echo "== ${m#"$r"/}"; grep -n 'platforms\|swiftLanguageModes\|defaultIsolation\|enableUpcomingFeature' "$m"; }
done
echo "== escape hatches (budget: exactly 1 — VoiceBank)"
grep -rn --include='*.swift' -E '@unchecked Sendable|nonisolated\(unsafe\)|@preconcurrency import|Task\.detached|assumeIsolated' \
  "$r/HunchCore" "$r/Modules" "$r/App" 2>/dev/null || echo "  none found (or no Swift yet)"
echo "== actors (budget: exactly 2 — FilePersistenceStore, LawIndexLoader)"
grep -rn --include='*.swift' -E '^[[:space:]]*(public |package )?actor ' \
  "$r/HunchCore" "$r/Modules" 2>/dev/null || echo "  none found (or no Swift yet)"
```

Trust that listing over anything below it. Both budgets are exact: a third actor or a second hatch is a design change, not a fix.

## The rule

**Isolation is decided per *target*, in the two `Package.swift` manifests and in `Config/Base.xcconfig`, and nowhere else.** `HunchCore` is nonisolated top to bottom and holds no class at all. Everything `@MainActor` is `@MainActor` because it is a `View` or it owns state a `View` reads. Rule numbers below are `ios-swift-guide/05-CONCURRENCY.md`; look one up with `grep -n '^\*\*R17\.' ios-swift-guide/05-CONCURRENCY.md`.

| Target | Default isolation | |
|---|---|---|
| every `HunchCore` target | **none** | `01 P17`, `05 R7`, `04 A22`, `08 §4` |
| `HunchNavigation`, `Feedback` | **none** | a route graph and a cue vocabulary are values |
| `HunchUI`, `LoomFeature`, `CodexFeature`, `MetaFeature`, `HunchAppFeature` | `.defaultIsolation(MainActor.self)` | |

A new target gets `MainActor` **iff** it declares a `View` or owns state a `View` reads directly. Write `@MainActor` explicitly on every declaration visible outside its own file even inside a `MainActor` target (`05 R8`) — the declaration has to read correctly without knowing the build setting.

## Where mutable state goes

`05 R17`'s ladder, with HUNCH's instance counts. Stop at the first row that applies.

| Situation | Answer | Instances in HUNCH |
|---|---|---|
| A domain value — glyph, law, table, band, phase, layout, page | plain `struct`/`enum` + `: Sendable`, no isolation | all of `HunchCore` |
| State a `View` reads | `@MainActor @Observable final class` | `Round`, `Codex`, `Ladder`, `Router` |
| Small shared mutable state, synchronous access | `Mutex` | **zero.** Reaching here means you have a value that should be threaded through a call, not stored |
| Cohesive state *with behaviour*, callers already `async`, critical section must `await` | `actor` | **exactly two** — see `references/isolation-plan.md` §3 |
| A real-time audio render callback | documented `@unchecked Sendable` | **exactly one** — `05 R17` has no row for this; `08 §7.7` is the ruling |

Admitting a third actor means: it fails the value-threading test, it satisfies all three clauses of row 4, and it is recorded in `DECISIONS.md`. Anything less is `05 R18`.

## The RNG — determinism is a scoping problem, not a concurrency problem

An RNG is mutable state, so strict concurrency asks where it lives. The answer is that **it never lives anywhere**: it is created inside one synchronous call and dies at the closing brace (`08 §4`).

```swift
// RIGHT — `generate` is synchronous and nonisolated. `rng` is a local `var`, threaded by `inout`.
public func generate(seed: UInt64, band: Band, targetDelta: Double,
                     mode: Mode, avoid: Set<UInt64> = []) -> LawNode {
    var rng = SplitMix64(seed: seed ^ (UInt64(band.rawValue) << 32) ^ mode.salt)
    return sampleLaw(band: band, targetDelta: targetDelta, avoid: avoid, using: &rng)
}
```

```swift
// WRONG — each of these breaks determinism, and only the last one is a compiler error.
@MainActor @Observable final class Round { var rng = SplitMix64(seed: 0) }
//   ↑ the law now depends on how many times SwiftUI evaluated a body.
actor RandomSource { func next() -> UInt64 { … } }
//   ↑ makes `generate` async, infects every caller, and reorders draws under contention.
nonisolated(unsafe) var shared = SplitMix64(seed: 0)
//   ↑ an escape hatch and a real data race, to avoid passing one argument.
static var seedState = SplitMix64(seed: 0)
//   ↑ error: static property 'seedState' is not concurrency-safe … [#MutableGlobalVariable]
```

Randomness is a parameter, never an ambient: every function that needs it takes `using rng: inout some RandomNumberGenerator`. The single point of nondeterminism in the whole app is `SeedSource`, and it lives at the composition root in `HunchAppFeature`. If band-8 generation ever measures slow, the offload passes the **seed** across the isolation boundary, never the generator — `references/sendable-and-rng.md` §6.

## The one escape hatch

`AVAudioSourceNode`'s render block may not allocate, may not lock and may not touch main-actor state, so `@MainActor`, `Mutex` and `actor` are all wrong. `VoiceBank` — a fixed 8-slot voice array with an atomic head index (`GAME_DESIGN.md §13.8`) — carries `@unchecked Sendable` plus a comment naming the exact synchronisation mechanism. That comment is not documentation, it is the build gate: `Scripts/check-source-hygiene.sh` check 3 fails on an undocumented hatch (`05 R26`/`R29`, `07 B34a`). Full implementation and the render-block contract: `references/real-time-audio.md`.

## Where the detail lives

| Read this | When |
|---|---|
| `references/isolation-plan.md` | before editing either `Package.swift`, adding a target, adding an actor, or deciding whether a type is `@MainActor` |
| `references/sendable-and-rng.md` | when a `Sendable` or `sending` diagnostic fires, when writing anything that draws a random number, or when tempted to inject a clock |
| `references/real-time-audio.md` | before touching `Feedback/` — `VoiceBank`, the render block, engine lifecycle, interruptions, route changes |
| `references/diagnostics.md` | when the compiler has already emitted something — exact diagnostic text mapped to the HUNCH fix, plus the triage that comes first |

## Gotchas

- **Swift 6 language mode gives you three of the five approachable features, not five** (`05 R3`). `NonisolatedNonsendingByDefault` and `InferIsolatedConformances` must be listed explicitly on every target in both manifests, and `SWIFT_APPROACHABLE_CONCURRENCY = YES` must be in `Config/Base.xcconfig`. Until they are, a bare `nonisolated func … async` runs *off* the caller's actor — and the identical source silently changes thread the day someone adds the flag.
- **`GlyphShape.path(in:)` does not run on the main actor.** `Shape.path` is one of the few SwiftUI entry points that genuinely runs off it (`05 §9`), and HUNCH draws everything through `Shape` and `Canvas`. A `path(in:)` must be a pure function of the `Glyph` the shape already stores. Reading `Round`, `@State` or `@Environment` from inside it is the data race. Same for `.visualEffect` and the `LoomGrain` `colorEffect` — capture a copy in the capture list.
- **`Atomic` and `Mutex` need `import Synchronization`, iOS 18+.** `Modules/Package.swift` must declare `platforms: [.iOS(.v18)]` in its own right; `Config/Base.xcconfig`'s `IPHONEOS_DEPLOYMENT_TARGET = 18.0` does not reach the package manifest. This is the reason the floor is 18 and not the guide's default (`08 §7.7`).
- **Canon fixes SplitMix64's finaliser and not its increment.** `GAME_DESIGN.md §11.6` owns the multipliers and the shift sequence, which `anomalySeed(day:)` uses; the `next()` gamma is stated nowhere. Choose it once, record it in `DECISIONS.md`, and let the cross-process golden fixture freeze it — two spellings of `next()` are two different games. `anomalySeed` must *call* the finaliser, not re-type it.
- **`await` is not a critical section** (`05 R12`). `Round` writes a snapshot after every verdict; anything read before `await store.save(…)` must be captured before the first suspension or re-read after it. Data-race safety is not logic-race safety.
- **`@Observable` is a macro over a `@MainActor` class**, so it drags Observation and main-actor isolation into whatever target holds it. That is the entire reason `CodexPage` is core and `Codex` is `CodexFeature` (`08 §2`).
- **`Task { }` in a tap handler is correct; inside an already-`async` function it is a bug** (`05 R37`). The idle-timer and interruption plumbing in `Feedback` is full of the first kind.
- **There is no `Clock` in HUNCH and adding one is a regression** (`08 §5`). No wall-clock quantity affects score, marks or the Rasch update; SIEVE's timing is a pure `SieveSchedule` value plus one `ContinuousClock.sleep` at the view edge. The only injected time source is `Now`.

## Never

- Never put `.defaultIsolation(MainActor.self)` on a `HunchCore` target, and never `import SwiftUI`, `Observation` or `UIKit` there — the boundary rule is `08 §2` and the arrow is enforced by the manifests.
- Never add a third actor, or a second `@unchecked Sendable`, without a `DECISIONS.md` entry. `nonisolated(unsafe)`, `Task.detached`, `assumeIsolated` and `@preconcurrency import` have a budget of zero.
- Never store an RNG — not in a class, not in an actor, not in a `static var`, not in a property wrapper.
- Never write `Date()`, `UUID()`, `.random(`, `SystemRandomNumberGenerator` or `Task.sleep` under `HunchCore/Sources/`. CI greps for the first four (`08 §5` check 6).
- Never write a bare `nonisolated func … async`. Say `@concurrent` or `nonisolated(nonsending)` (`05 R13`/`R15`).
- Never make an actor for a counter, a flag or a cache with synchronous accessors (`05 R18`), and never hand-roll a `SerialExecutor` (`05 R19`).
- Never use `DispatchQueue` in new code (`05 R20`). `Task { @MainActor in }` or `await MainActor.run { }`.
- Never allocate, lock, `await`, log or touch main-actor state inside the audio render block.
- Never fix a `sending` diagnostic by adding `: Sendable` before checking for latent isolation (`05 R52`) — in HUNCH the answer is usually a missing `@MainActor` on the caller.
- Never copy a rule's text out of `ios-swift-guide/05-CONCURRENCY.md` into code, a comment or another skill. Cite `05 R<n>`; the guide is the one copy.
