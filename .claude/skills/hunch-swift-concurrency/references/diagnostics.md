# Concurrency diagnostics — triage and the HUNCH fix

Read when the compiler has already emitted something. Diagnostic text is what Swift 6.3.3 emits;
older blog posts quote earlier wordings. Rule numbers are `ios-swift-guide/05-CONCURRENCY.md`;
`08 §n` is `ios-swift-guide/08-APPLIED-TO-HUNCH.md`.

1. [Triage first — two questions, not twenty](#1-triage-first--two-questions-not-twenty)
2. [The diagnostics, mapped](#2-the-diagnostics-mapped)
3. [Fixes that are wrong in this project specifically](#3-fixes-that-are-wrong-in-this-project-specifically)
4. [Migrate mode and the `nonisolated async` audit](#4-migrate-mode-and-the-nonisolated-async-audit)
5. [Proposing an escape hatch — the procedure](#5-proposing-an-escape-hatch--the-procedure)
6. [Looking a rule up](#6-looking-a-rule-up)

---

## 1. Triage first — two questions, not twenty

`05 R10`: every diagnostic is one of two questions. Say which out loud before touching anything.

| The compiler is asking | Class | Where the fix lives |
|---|---|---|
| "Can this *value* cross this boundary?" | **A — `Sendable` / `sending`** | `sendable-and-rng.md` §1–§3 |
| "Am I allowed to touch this *state* from here?" | **B — isolation** | `isolation-plan.md` |

Almost every bad fix in the wild is a class-B error misdiagnosed as class-A: `@unchecked Sendable`
bolted onto a type to silence what was really a missing `@MainActor` on the caller. In HUNCH the
prior is even stronger, because `HunchCore` is value types end to end — **if a `Sendable` diagnostic
fires against a HunchCore type, the type is almost certainly fine and the caller's isolation is
under-specified.**

Two checks before any annotation:

- **Latent isolation** (`05 R52`). Was the function always main-actor work that nobody declared?
- **Flow sensitivity** (`05 R23`). These diagnostics are flow-sensitive, not signature-sensitive.
  Deleting a *later* use of the value often clears the error with no annotation at all.

## 2. The diagnostics, mapped

| Diagnostic | Class | The HUNCH fix |
|---|---|---|
| `var 'x' is not concurrency-safe because it is nonisolated global shared mutable state [#MutableGlobalVariable]` | B | `05 R50`'s ladder, and in this project it terminates at rung 1 or 2. `Deck.all` and `MaskTable.resident` are `static let` of immutable `Sendable` values. Rung 5 (`nonisolated(unsafe)`) has a budget of zero — see §5. |
| `static property 'x' is not concurrency-safe …` on an RNG | B | You stored a generator. Delete it; make the function take `using rng: inout some RandomNumberGenerator`. `sendable-and-rng.md` §5. |
| `sending 'x' risks causing data races [#SendingRisksDataRace]` | A | Check latent isolation first (`05 R52`). If the value really is a one-time hand-off, `sending`, not `Sendable` (`05 R22`). Adding `Sendable` to a HunchCore type to fix a call-site error changes that type's design permanently to solve one crossing. |
| `conformance of 'X' to protocol 'P' crosses into main actor-isolated code … [#ConformanceIsolation]` | B | `05 R51`'s order: isolate the *conformance* (`: @MainActor P`), then `nonisolated P`, then isolate the requirement, then the protocol, then make the requirement `async`. `@preconcurrency` on a conformance is last and is a runtime promise, not a compile-time one. In HUNCH this fires on `CuePlayer` and `PersistenceStore` conformers; both protocols are `Sendable` and nonisolated by design, so the fix is on the conforming type's *members*, not on the protocol. |
| `main actor-isolated conformance of 'X' to 'P' cannot be used in nonisolated context [#IsolatedConformances]` | B | `InferIsolatedConformances` did step 1 for you and moved the error to the use site. That is the feature working: some caller was treating a main-actor-only conformance as if it were free. Usually the caller wants `@MainActor`. |
| `stored property 'x' of 'Sendable'-conforming class 'Y' is mutable` | A | Only reachable in `Modules/`. `weak let` (SE-0481) ships in 6.3 and keeps a back-reference from costing the conformance (`05 R21`). If the property genuinely must be mutable, the type is `@MainActor`, not `Sendable`. |
| `call to main actor-isolated … in a synchronous nonisolated context` inside `path(in:)` | B | `Shape.path` runs off the main actor (`05 §9`). Store the value the shape needs — `Glyph`, `Band`, a resolved token — at init. Never reach for `Round`, `@State` or `@Environment` from inside it. |
| `capture of 'x' with non-Sendable type … in a '@Sendable' closure` in `.visualEffect` / a `colorEffect` | A | Capture a copy in the capture list: `.visualEffect { [phase] content, _ in … }` (`05 §9`). |
| `'async' call in a function that does not support concurrency` at a tap handler | B | `Task { }` at a synchronous → asynchronous boundary is correct and not a smell (`05 R37`). Update UI state synchronously *first*, then start the task (`05 R33`). |
| `escaping closure captures mutating 'self'` on a generator threading site | — | You tried to capture an `inout` RNG in a closure. The generator is synchronous and the RNG is a local `var`; restructure so the closure takes `using rng: inout …` as a parameter instead of capturing. |

## 3. Fixes that are wrong in this project specifically

Each of these compiles and each of them is a defect here.

| Tempting fix | What it actually breaks |
|---|---|
| `actor` around the RNG | makes `generate` `async`, infects every caller, and reorders draws under contention — determinism gone (`08 §4`) |
| `@MainActor` on a `HunchCore` type | drags main-actor isolation into a package whose whole value is that it has none; `swift test` starts needing a main-actor context (`04 A22`, `08 §2`) |
| `.defaultIsolation(MainActor.self)` on a `HunchCore` target | same, silently, for everything in the target — and the declarations still read as nonisolated |
| `@unchecked Sendable` on a HunchCore type | the type is a value type; if it is not implicitly `Sendable`, something inside it is a class that should not be there |
| `nonisolated(unsafe)` on anything | budget zero. It converts a compile-time diagnostic into a production heisenbug and deletes the only record that a problem existed (`05 R50`) |
| `Task.detached` to "get off the main thread" | `05 R38`; discards isolation, priority and task-locals. `@concurrent` is the checked answer, and only after profiling (`05 R16`) |
| `MainActor.assumeIsolated` in an audio or haptics callback | asserts and crashes if you are wrong, and neither AVFAudio nor Core Haptics guarantees the thread (`05 R36`) |
| `Task { }` inside an already-`async` function | drops out of structured concurrency; use `async let` or a task group (`05 R37`, `R39`) |
| a `Clock` protocol to make timing testable | the timing leaked into `HunchCore`. Move it out instead (`08 §5`) |
| `@preconcurrency import` | there is no unannotated dependency to accommodate; it reduces checking across a whole file for nothing (`05 R49`) |

## 4. Migrate mode and the `nonisolated async` audit

`05 R13`: since SE-0461, a bare `nonisolated func … async` runs on the *caller's* actor when
`NonisolatedNonsendingByDefault` is on, and off it when it is not. HUNCH is new code, so the rule is
simply **never write the bare form** — say `@concurrent` (always off the caller's actor) or
`nonisolated(nonsending)` (explicitly on it).

The audit still matters at one moment: the commit that adds
`.enableUpcomingFeature("NonisolatedNonsendingByDefault")` to a manifest that lacked it. Use the
compiler, not grep (`05 R14`):

```bash
swiftc -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault:migrate …
# warning: feature 'NonisolatedNonsendingByDefault' will cause nonisolated async global
#          function 'f' to run on the caller's actor; use '@concurrent' to preserve behavior
```

Apply the fix-its, **review each one** — the fix-it preserves *old* behaviour, which is not always
what you want — then flip to the plain `.enableUpcomingFeature` form. Keep this as a second pass for
declarations the compiler cannot see:

```bash
rg -n --type swift -U 'nonisolated\s+func[^\n{]*\basync\b' HunchCore Modules
```

Ship a default-isolation or upcoming-feature change **alone** (`05 R9`), never alongside a language
mode change.

## 5. Proposing an escape hatch — the procedure

The repository budget is one `@unchecked Sendable` (`VoiceBank`) and zero of everything else on
`05 R29`'s list. Before proposing a second:

1. **Classify the diagnostic** (§1). If it is class B, the hatch is the wrong instrument and the
   answer is an isolation annotation.
2. **Walk `05 R17`'s ladder out loud** and say which row fails and why. "It felt cleaner" is not a row.
3. **Name the synchronisation mechanism** — the actual one, in the actual code. If you cannot write
   `real-time-audio.md` §3's four sentences about it, there is no mechanism.
4. **Write the comment before the annotation.** `Scripts/check-source-hygiene.sh` check 3 will fail
   the build without it (`07 B34a`), but the point is that writing it is the test.
5. **Record it in `DECISIONS.md`** with the diagnostic it silences and the review checklist that
   keeps it honest.

`05 R55`'s anti-checklist applies verbatim: never add `@unchecked Sendable`, `@preconcurrency` or
`nonisolated(unsafe)` "to come back to later" — the diagnostic was the only record of the problem.

## 6. Looking a rule up

The guide is the authority; this skill is the shortcut. Print any rule rather than trusting a
paraphrase:

```bash
grep -n '^\*\*R17\.' ios-swift-guide/05-CONCURRENCY.md          # one concurrency rule
grep -n '^\*\*A22\.' ios-swift-guide/04-ARCHITECTURE-AND-STATE.md
grep -n -A20 '^## 4\. The concurrency plan' ios-swift-guide/08-APPLIED-TO-HUNCH.md
sed -n '/^## Checklist/,$p' ios-swift-guide/05-CONCURRENCY.md   # all 56 rules, one line each
```

If this skill and the guide disagree, the guide wins and this skill is the bug — fix it here rather
than working around it.
