# T05 — SplitMix64

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T03 |
| **Delivers** | Seeded RNG (§14.1 CORE SYSTEMS) |
| **Status** | not started |

> **Order note.** T05 runs **before** T04. `Corpora.seed(band:index:)` is a `SplitMix64` derivation (`hunch-swift-testing/references/determinism.md` §2), so T04 cannot compile until this task lands. Nothing moved between tasks; only the order did.

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-concurrency` | It owns the RNG scoping rule — the reason determinism is a *scoping* problem and not a concurrency problem, the four wrong answers with what each breaks, and the gotcha that canon fixes the finaliser but **not** the increment, so the gamma is a decision this task makes and records. |
| `hunch-swift-code` | Nothing in `HunchCore` is a class; every public value type writes `: Sendable` explicitly; naming (`N15`'s preposition row gives `using rng:` its label, matching `shuffled(using:)`). |
| `hunch-swift-testing` | `references/determinism.md` §1–§2 is the five-consequence list this task codifies, and §9 is why the tests assert invariants and reference vectors rather than a golden order out of the generator. |

## Objective

`SplitMix64` exists as a `struct` of one `UInt64` conforming to `RandomNumberGenerator` and `Sendable`, with its finaliser exposed so `anomalySeed(day:)` can *call* it instead of re-typing it. The rule that randomness is always a parameter — `using rng: inout some RandomNumberGenerator` — is written down in the file that would otherwise be the temptation to break it, and the `LawGeneration` target and the `HunchCore` library product come into existence around it.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.6 | **The single normative home of the finaliser** — the two multipliers and the 30/27/31 shift sequence, inside `anomalySeed(day:)`. Read them from there; do not transcribe them from this file or from Wikipedia. |
| `GAME_DESIGN.md` | §5.3 | Step 1: `rng = SplitMix64(seed ^ (UInt64(band) << 32) ^ mode.salt)`. The generator is pure over its five arguments and nothing else. |
| `GAME_DESIGN.md` | §5.7 | "Generator purity" and "Seeded RNG" as locked constants; determinism asserted at `avoid: []`. |
| `GAME_DESIGN.md` | §14.1 | The `Seeded RNG` row: *SplitMix64 conforming to `RandomNumberGenerator`; every puzzle reproducible.* |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 | The declaration and the five consequences, verbatim: `generate` is synchronous and `nonisolated`; randomness is a parameter; the four banned symbols; no RNG in an `@Observable`; determinism is a scoping problem. |
| `ios-swift-guide/05-CONCURRENCY.md` | `R13`, `R17`, `R18`, `R21` | Why a bare `nonisolated async` is the trap this design cannot fall into; why an actor for an RNG is wrong; explicit `Sendable`. |

Print the finaliser rather than retyping it:

```bash
sed -n '/^func anomalySeed/,/^}/p' GAME_DESIGN.md
```

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawGenerationTests/SplitMix64Tests.swift`:

```swift
import Testing
import HunchTestSupport
import LawGeneration

/// Reference vectors, not a golden order (06 T42). SplitMix64's outputs for seed 0 are published
/// with the algorithm, so this suite compares against a foreign artefact rather than against
/// whatever this implementation happened to produce on the day it was written — which is the
/// difference between a known-answer test and a change detector.
@Suite("SplitMix64", .tags(.unit, .presubmission))
struct SplitMix64Tests {
    @Test("Reproduces the published vectors for seed 0")
    func referenceVectors() {
        var rng = SplitMix64(seed: 0)
        #expect(rng.next() == 0xE220_A839_7B1D_CDAF)
        #expect(rng.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(rng.next() == 0x06C4_5D18_8009_454F)
    }

    /// The finaliser maps 0 to 0 — every step is a xor-shift or a multiply, and all of them fix
    /// zero. That is exactly why the gamma is added to the state BEFORE the finaliser runs: an
    /// implementation that finalised first would return 0 forever from seed 0 and look fine on
    /// every other seed. This assertion is the one that catches the transposition.
    @Test("The finaliser fixes zero, which is why the gamma is added first")
    func finaliserFixesZero() {
        #expect(SplitMix64.mix(0) == 0)
        #expect(SplitMix64.mix(SplitMix64.gamma) == 0xE220_A839_7B1D_CDAF)
    }

    @Test("A copy advances independently — the generator is a value, not a reference")
    func valueSemantics() {
        var original = SplitMix64(seed: 0x48_554E_4348)
        var copy = original
        _ = copy.next()
        _ = copy.next()
        #expect(original.next() == 0xDFB8_B157_4CD4_1C48)
    }

    @Test("Two generators from one seed produce the same stream")
    func sameSeedSameStream() {
        var first = SplitMix64(seed: 0xC0FF_EE00_0000_0001)
        var second = SplitMix64(seed: 0xC0FF_EE00_0000_0001)
        let a = (0..<256).map { _ in first.next() }
        let b = (0..<256).map { _ in second.next() }
        #expect(a == b)
        #expect(Set(a).count == 256)   // no immediate short cycle
    }

    @Test("Different seeds diverge on the first draw")
    func differentSeedsDiverge() {
        var first = SplitMix64(seed: 0)
        var second = SplitMix64(seed: 1)
        #expect(first.next() != second.next())
    }

    /// The shape every consumer must use: randomness is a PARAMETER, threaded by `inout`
    /// (08 §4 consequence 2, N15's preposition row). If this stops compiling because someone
    /// stored an RNG somewhere, that is the bug.
    @Test("Threading the generator through `using:` reproduces a draw sequence")
    func randomnessIsAParameter() {
        func draw(_ count: Int, using rng: inout some RandomNumberGenerator) -> [Int] {
            (0..<count).map { _ in Int.random(in: 0..<256, using: &rng) }
        }
        var first = SplitMix64(seed: 0xDEAD_BEEF)
        var second = SplitMix64(seed: 0xDEAD_BEEF)
        #expect(draw(64, using: &first) == draw(64, using: &second))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SplitMix64Tests`

First failure: `error: no such module 'LawGeneration'`. Then, once the target exists: `error: cannot find 'SplitMix64' in scope`. Then, once the type exists but before the finaliser is right, `referenceVectors` fails with a concrete wrong number. All three are the right reason. If `finaliserFixesZero` passes before you have written `mix`, you have a stub returning its argument — check it.

**Step 3 — implement** `SplitMix64.swift` and the two manifest rows.

**Step 4 — green, then refactor.** Then run the whole suite and confirm the ten-second timer is still nowhere near its budget.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/SplitMix64.swift` |
| create | `HunchCore/Tests/LawGenerationTests/SplitMix64Tests.swift` |
| modify | `HunchCore/Package.swift` — uncomment the `LawGeneration` row, add `LawGenerationTests`, create the `HunchCore` library product |

## Implementation notes

### The type

```swift
// HunchCore/Sources/LawGeneration/SplitMix64.swift

/// The project's only random number generator.
///
/// A struct of one `UInt64`, therefore trivially `Sendable` and trivially copied. It is never
/// stored: `generate(seed:band:targetDelta:mode:avoid:)` constructs one as a local `var` and
/// threads `&rng` down a synchronous call tree, and it dies at the closing brace (08 §4).
///
/// - Note: The finaliser is `GAME_DESIGN.md` §11.6's, which is also the single normative
///   derivation of the daily Anomaly. `Anomaly.seed(day:)` (E16·T01) **calls** `mix(_:)`; it
///   does not re-type the constants, because a globally shared law with two derivations is a
///   coin flip at implementation time.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    /// The increment applied to the state before each finalise.
    ///
    /// Canon fixes the finaliser and **not** the increment (§11.6 states one and is silent on
    /// the other), so this is a decision recorded in `DECISIONS.md`: the reference SplitMix64
    /// gamma, the odd 64-bit approximation of 2⁶⁴/φ. Two spellings of `next()` are two different
    /// games; the cross-process golden fixture (E06·T10) freezes this one.
    public static let gamma: UInt64 = 0x9E37_79B9_7F4A_7C15

    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    /// The SplitMix64 finaliser — `GAME_DESIGN.md` §11.6, copied from there and nowhere else.
    public static func mix(_ input: UInt64) -> UInt64 {
        var z = input
        // ← §11.6's three lines go here, verbatim: two multiplies with `&*`, shifts 30, 27, 31.
        return z
    }

    public mutating func next() -> UInt64 {
        state &+= Self.gamma        // increment FIRST — the finaliser fixes zero
        return Self.mix(state)
    }
}
```

Four things to get right, each of which the tests catch:

1. **`&+` and `&*`, never `+` and `*`.** Wrapping arithmetic is the algorithm, not a shortcut. A non-wrapping operator traps at runtime on the first overflow, which for this generator is the second call.
2. **The increment precedes the finalise.** See `finaliserFixesZero` above.
3. **`mix` is `public` and `static`.** Not because this file needs it, but because `Archive/Anomaly.swift` (E16·T01) does, and the alternative is a second transcription of §11.6's constants. That is the one *cross-target* obligation this file carries; the gotcha in `hunch-swift-concurrency` names it.
4. **`private var state`, no accessor.** Nothing outside may read or restore the state. If a future feature wants to resume a stream, it re-derives the seed; it does not serialise the generator.

`Sendable` is written explicitly even though it would be inferred, per `05 R21` — every public type in `HunchCore` says what it is.

### The rule this file codifies

Write it as a doc comment on the type and enforce it everywhere afterwards:

> **Randomness is a parameter, never an ambient.** Every function that needs it takes
> `using rng: inout some RandomNumberGenerator`. No RNG is stored in a class, an actor, a
> `static var` or an `@Observable` property, and none ever crosses an isolation boundary — if
> band-8 generation ever measures slow, the **seed** crosses (a `UInt64`) and the callee builds
> its own generator (`08 §4` consequence 1).

The four wrong answers, and what each breaks, are in `hunch-swift-concurrency`'s "The RNG" section — read them once so the review of a later epic recognises them. Three of the four compile.

Check 6 of the hygiene script (T06) is the mechanical half: `SystemRandomNumberGenerator`, a bare `.random(`, `randomElement()` and `shuffled()` are banned under `HunchCore/Sources/`, and the check filters out lines containing `using:` precisely so the *legal* spelling is never flagged. A check that flags the correct spelling gets suppressed within a week.

### The manifest rows

Uncomment `LawGeneration` (no dependencies — this file imports nothing), add its test target, and create the product:

```swift
products: [
    .library(name: "HunchCore", targets: ["LawGeneration"]),
],
targets: [
    .target(name: "LawGeneration", swiftSettings: coreSettings),
    .target(name: "HunchTestSupport", swiftSettings: coreSettings),
    .testTarget(
        name: "LawGenerationTests",
        dependencies: ["LawGeneration", "HunchTestSupport"],
        swiftSettings: coreSettings
    ),
    .testTarget(name: "HunchTestSupportTests", dependencies: ["HunchTestSupport"], swiftSettings: coreSettings),
]
```

Every later epic appends its own target to `targets:` **and** to the product's target list in the same commit as that target's first file.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SplitMix64Tests` is green with 6 tests.
- [ ] `swift build --package-path HunchCore` emits zero warnings.
- [ ] `grep -n '0xBF58\|0x94D0' HunchCore/Sources/LawGeneration/SplitMix64.swift` shows the two multipliers **once each**, and `grep -rn '0xBF58\|0x94D0' --include='*.swift' HunchCore Modules App` shows them in **no other file** — one home, forever.
- [ ] `grep -rn 'var rng\|let rng' HunchCore/Sources` returns matches only inside function bodies — never a stored property.
- [ ] `swift package describe --package-path HunchCore --type json | jq -r '.products[].targets[]'` lists `LawGeneration` and **not** `HunchTestSupport`.
- [ ] `DECISIONS.md` has an entry naming `0x9E37_79B9_7F4A_7C15` as the chosen gamma, with the reason (canon fixes the finaliser and not the increment) — written now as a note, transcribed into the file in T08.
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh HunchCore/Sources/LawGeneration/SplitMix64.swift` exits 0.

## Close the task

1. `swift test --package-path HunchCore` green, and the whole suite still far under 10 s.
2. **Run `/simplify`** — watch for it "simplifying" `&+` to `+` or inlining `mix` back into `next()`. Both are regressions and both are named above; reject them and re-run the tests.
3. **Run `/code-review`** — the findings that matter are the operator kind, the increment order, and whether anything outside this file can observe the state.
4. Commit: `git commit -m "E01/T05: SplitMix64, the LawGeneration target and the HunchCore product"`

## Out of scope

- **`Band`, `Mode.salt` and the seed-mixing expression `seed ^ (band << 32) ^ mode.salt`** — `Band` is E05·T06 and `Mode` is E02·T06; the expression lives in `generate` (E06·T06), not here. This task ships the generator, not the seeding policy.
- **`Difficulty`, `Generator`, `Guardrail`, `Counterexample`** — E06, in this same target.
- **`ANOMALY_SALT`, `utcDayIndex` and `anomalySeed(day:)`** — E16·T01, in `Archive`. It will add the `LawGeneration` edge to `Archive`'s dependencies when it does; do not add that edge now (`package-manifests.md` §4 rule 3).
- **`SeedSource`** — the single point of nondeterminism in the app, and it lives in `Modules/Sources/HunchAppFeature` (E10·T01). It is *why* `SystemRandomNumberGenerator` is banned from `HunchCore` outright.
- **The cross-process golden fixture that freezes this gamma** — E06·T10.
- **`Corpora.seed(band:index:)`**, which consumes this type — T04, next.
