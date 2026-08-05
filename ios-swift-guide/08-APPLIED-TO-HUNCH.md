# Applying This Guide to HUNCH

Files 01–07 are general. This one is the projection of them onto one project: HUNCH, the offline rule-induction game specified by `hunch-claude-code-prompt.md` (architecture, constraints, verification) and `GAME_DESIGN.md` (every system and every number). Where the brief and the guide disagree, §7 names the conflict and rules on it; everywhere else this file only says *which* rule fires and *what it produces here*. It restates nothing.

Two facts govern everything below. **The brief is a harder constraint than the guide** — it is the client. And **`GAME_DESIGN.md` §0.4 already assigns a single normative owner to every quantity**, which means the module boundaries are *given*, not discovered, and `01 P12`'s "don't pre-create modules" fires differently than it does on a blank repo (§7.3).

---

## 1. The tree

```text
E03/                                       # repo root. Product name is HUNCH; rename the dir if it is ever cut loose.
├── .gitignore  .swift-format              # ONE .swift-format at the root covers both packages (01 P39)
├── CLAUDE.md  SPEC.md  DECISIONS.md  PROGRESS.md  tests.json    # brief-mandated, repo root, not in a target
├── Hunch.xcodeproj                        # at the ROOT (01 P41). No .xcworkspace — one project.
├── Presubmission.xctestplan  Nightly.xctestplan  Prerelease.xctestplan   # named after the cadence tag (07 B24)
│
├── Config/                                # outside App/ so an .xcconfig can never ship as a resource (01 P38)
│   ├── Base.xcconfig                      # SWIFT_VERSION = 6.0 · IPHONEOS_DEPLOYMENT_TARGET = 18.0 · UIDeviceFamily = 1
│   │                                      # portrait-only · ITSAppUsesNonExemptEncryption = NO (07 B37)
│   │                                      # zero NS*UsageDescription keys — the app requests nothing (design §12.9)
│   ├── Debug.xcconfig  Local.xcconfig     # -Onone; Local is gitignored and #include?'d from Base
│   └── Release.xcconfig                   # -Osize (07 B12, the 15 MB budget) + $(inherited) -warnings-as-errors (07 B18)
│
├── App/                                   # buildable folder, sole member of the Hunch target. Five files, forever (01 P8).
│   ├── HunchApp.swift                     # @main. Names AppDependencies.live(); imports HunchAppFeature only (01 P9)
│   ├── Assets.xcassets  AppIcon.icon      # AppIcon + launch colour ONLY. No glyph asset, ever. (01 P33, P37)
│   ├── Hunch.entitlements                 # empty; no capability is requested
│   └── PrivacyInfo.xcprivacy              # no collection, no tracking; UserDefaults reason code (01 P32, 07 B36)
│
├── HunchCore/                             # PACKAGE 1 — the brief's package. Zero SwiftUI/UIKit. Host-testable. name: "HunchCore"
│   ├── Package.swift                      # platforms: [.iOS(.v18), .macOS(.v15)] · swiftLanguageModes: [.v6]
│   │                                      # NO .defaultIsolation on any target here (01 P17, 05 R7, 04 A22)
│   ├── Sources/
│   │   ├── Glyphs/                        # leaf; empty dependencies:. The visual vocabulary as data.
│   │   │   Glyph.swift                    #   struct Glyph + NESTED Fill/Shape/Pips/Hue enums (§3, collision)
│   │   │   Deck.swift                     #   caseless enum: all 256, glyph(id:), canonical fill→shape→pips→hue order
│   │   │   Bitboard.swift                 #   Bitboard256 (4×UInt64), Bitboard65536 (1024×UInt64), lift/tile
│   │   ├── Laws/
│   │   │   LawNode.swift                  #   indirect enum — the AST. Codable. ~40 B on disk.
│   │   │   Law.swift                      #   LawNode + resolved LawTable + cached Metrics; NOT Codable (§3)
│   │   │   LawTable.swift                 #   the "extension" of §2's terminology — `extension` is a keyword (§3)
│   │   │   MaskTable.swift                #   the 54 KB resident precompute: atom/relational/ctx-row/aggregate masks
│   │   │   RenderedNormalForm.swift       #   RNF fold, commutative sort, same-attribute merge, constant fold
│   │   │   LawIndex.swift                 #   band-partitioned 9,767-table index + 17,248 contextual hashes
│   │   ├── LawGeneration/                 # SplitMix64 · Band (the collapsed Band/Family type, §3) · Difficulty
│   │   │                                  # Generator (pure over its five args) · Guardrail (G1…G10) · Counterexample
│   │   ├── Bench/                         # core, not UI: G10 lives here and the generator depends on it
│   │   │   BenchLayout.swift              #   Codable draft: rails, tiles, coupler, sockets. UInt8 raw values only.
│   │   │   RuleTile.swift                 #   enum RuleTile { ramp/bridge/fork/tally } with nested payload structs
│   │   │   SealBar.swift                  #   enum SealBar — why the Seal is barred, as data (§3)
│   │   ├── Rounds/                        # RoundPhase (§6.1 verbatim + a pure transition fn) · Outcome · Ribbon
│   │   │                                  # Score · RoundSnapshot (stores the LawNode, never a recipe)
│   │   │                                  # DriftSchedule/SieveSchedule/EchoCast — per-mode pure state, phase 5
│   │   ├── Ladder/
│   │   │   Ability.swift                  #   baseline: Double? — "undefined, not 0" as a type (§3)
│   │   │   AbilityEstimator.swift         #   pure: (Ability, Mode, servedDelta, Bool) -> Ability
│   │   │   ServingPolicy.swift            #   the 13 steps, in order; returns a Serving value
│   │   │   Calibration.swift              #   the 1/2/4/6/8 gallop, palette-sufficiency assertion
│   │   ├── Archive/                       # CodexPage · RoundRecord · Profile · AnomalyLedger
│   │   │   Anomaly.swift                  #   utcDayIndex + anomalySeed. No Calendar, no Locale, no TimeZone.
│   │   ├── Persistence/
│   │   │   PersistenceStore.swift         #   the brief's protocol (04 A41, W44's first question)
│   │   │   StoreFile.swift                #   the ten-file tree of §11.13 as an enum (§3)
│   │   │   FilePersistenceStore.swift     #   actor. Atomic writes to Application Support. (§4)
│   │   │   InMemoryPersistenceStore.swift #   ships; previews use it; imports no Testing (§6)
│   │   │   SchemaMigration.swift          #   migrate_vN_to_vN+1, staging-dir-then-replace
│   │   └── HunchTestSupport/              # .target, NOT .testTarget (01 P20); absent from products: (06 T5a)
│   │       Unimplemented.swift            #   Issue.record doubles (06 T38) — the only `import Testing` here
│   │       ApproximateEquality.swift      #   hand-rolled; swift-numerics is banned (§7.9)
│   │       Corpora.swift                  #   seeded law/glyph corpora, `let` and Sendable (§5)
│   └── Tests/                             # one test target per source target, path-mirrored (06 T5b)
│       GlyphsTests/ LawsTests/ LawGenerationTests/ BenchTests/ RoundsTests/ LadderTests/
│       ArchiveTests/ PersistenceTests/
│       PersistenceTests/Fixtures/v1/      # resources: [.copy("Fixtures")] → lookups pass subdirectory: (06 T54)
│       LawGenerationTests/Fixtures/determinism-seeds-v1.json   # the cross-process golden (§5)
│
├── Modules/                               # PACKAGE 2 — the app side. dependencies: [.package(path: "../HunchCore")]
│   ├── Package.swift                      # defaultLocalization: "en" (01 P35); UI targets get .defaultIsolation(MainActor.self)
│   ├── Sources/
│   │   ├── HunchNavigation/               # NO SwiftUI — so NavigationDepthTests runs on the host
│   │   │   Route.swift  Screen.swift  NavigationGraph.swift        # 04 A32/A36
│   │   ├── HunchUI/                       # the DesignSystem target (01 P7). SwiftUI only; no UIKit.
│   │   │   Palette.swift Stroke.swift Typography.swift             # design §13.2–§13.4; Okabe–Ito verbatim
│   │   │   GlyphShape.swift               #   Shape conformance: silhouette per Glyph.Shape
│   │   │   GlyphCanvas.swift              #   Canvas: body + fill texture + contour pips + index stroke
│   │   │   RuleTileCanvas.swift           #   RampView/BridgeView/ForkView/TallyView + CouplerView
│   │   │   AssayCanvas.swift RibbonCanvas.swift ParTickRow.swift ThroatView.swift
│   │   │   LoomGrain.metal                #   §13.6's stitchable colorEffect
│   │   │   Loc.swift                      #   THE single localization accessor (§12.9); #bundle + resolved locale
│   │   │   Resources/Localizable.xcstrings   # ONE catalog, ≤250 keys, 12 languages; checked in CI (§5)
│   │   ├── Feedback/                      # nonisolated by default except the two @MainActor players
│   │   │   Cue.swift  CuePlayer.swift     #   the shared cue vocabulary; protocol + SilentCuePlayer
│   │   │   SynthesizedCuePlayer.swift     #   AVAudioEngine + AVAudioSourceNode; VoiceBank (§4, the one escape hatch)
│   │   │   HapticCuePlayer.swift          #   CHHapticEngine, 11 cached pattern players
│   │   ├── LoomFeature/                   # the play surface. Zero Text/Label/AttributedString outside .accessibility*
│   │   │   Round.swift                    #   @MainActor @Observable final class Round — A18 triggers 1+2 (§7.8)
│   │   │   RoundView.swift BenchView.swift AssayInspectorView.swift InscriptionView.swift
│   │   │   EchoRoundView.swift SieveRoundView.swift SievePauseOverlay.swift        # phase 5
│   │   ├── CodexFeature/  Codex.swift CodexRootView.swift CodexShelfView.swift CodexPageView.swift
│   │   ├── MetaFeature/   FrameView.swift AnomalyView.swift ProfileView.swift StatisticsView.swift
│   │   │                  SettingsView.swift AboutView.swift ResetConfirmAlert.swift
│   │   └── HunchAppFeature/               # composes the features; the only target App/ imports (01 P9)
│   │       AppDependencies.swift          #   the composition root — live(), preview() (04 A2)
│   │       AppView.swift  Router.swift    #   one Router per NavigationStack (04 A33)
│   └── Tests/  HunchNavigationTests/ HunchUITests/ LoomFeatureTests/ CodexFeatureTests/
│
├── HunchTests/                            # wizard-made, stays nearly empty (01 P22, P40)
├── HunchUITests/                          # XCUITest — must be XCTest (06 T43): screenshots en/de/ar, accessibility audit
└── Scripts/check-source-hygiene.sh        # 07 B34a, extended with HUNCH's four extra greps (§5)
```

---

## 2. The module boundary, as a rule you can check

> **The boundary rule.** A file may live in `HunchCore/` **iff** it (a) imports nothing but `Swift`/`Foundation`, and (b) its behaviour is a pure function of values you can write down in a test — no `Date()`, no `UUID()`, no `.random`, no file path, no bundle, no screen geometry. If either half fails, it belongs in `Modules/`. Both halves are mechanical: (a) is a grep, (b) is the reason the grep list in §5 bans five symbols outright.

Four things in this design look like core logic and are not:

| Looks core | Actually app-layer | Failure mode the split prevents |
|---|---|---|
| **The par tick row and the sheet grid** — §6.2 gives them pixel geometry and an invariant (`sheetCells ≥ 1 + max cap`) | `HunchUI`. `Band.par`/`Band.cap` are core; `tickPitch = min(nominalPitch, rowWidth/N)` is layout | Screen geometry in the core makes `swift test` depend on a device idiom, and the 10-second suite starts needing a simulator |
| **The Assay's pinned `prev` slice** | `LawTable.row(after:)` is core; the *pin*, the scrubber and the evidence overlay unlock at band 4 are `AssayCanvas` | Putting the pin in the core makes a pure table view stateful and gives `LawTable` a `var` |
| **The counterexample's presentation** | Selection is core (§4.5 is fully deterministic and testable); the two-ring animation and the 960 ms beat are `LoomFeature` | Timing constants in the core invite `Task.sleep` into a package whose entire value is that it has no clock |
| **`Codex` (the observable archive)** | `CodexPage` is core; `Codex` — lazy shelf loading, dedup authority, `@Observable` — is `CodexFeature` | `@Observable` is a macro over a `@MainActor` class; it drags Observation and main-actor isolation into a target that must stay nonisolated |

And two that look app-layer and are core:

- **`BenchLayout` and its parser.** They render as tiles, so they read like UI. But G10 (`LawNode(BenchLayout(law)) == law.renderedNormalForm`) is a *generation-time guardrail* — the generator refuses to emit a law the Bench cannot express. If `BenchLayout` lived in `Modules/`, `HunchCore` would depend on the UI package, the dependency arrow would invert, and G10 could only be tested in the simulator. It is core.
- **`RoundPhase` and its transition table.** §6.1's state machine is 9 phases with locked-input windows and durations. The *durations* are `HunchUI`; the *transitions* are a pure function `(RoundPhase, Event) -> RoundPhase` and belong in core, tested exhaustively. This is `04 A20` — extract the logic into a plain type and test that, not the view.

`Modules/` may import `HunchCore`. `HunchCore` may import nothing of ours. Enforced by `dependencies:` in the two manifests (`04 A3`), which is why the boundary needs no lint rule: leave the arrow out and the `import` stops compiling.

---

## 3. The naming pass

The design's §2 locks a vocabulary for seven authors. Locked *terminology* is not locked *type count*, and three of these words do not survive contact with Swift as written.

| Design term | Swift | Rule and reasoning |
|---|---|---|
| glyph, its four attributes | `struct Glyph: Hashable, Sendable, Codable` with **nested** `Glyph.Fill`, `Glyph.Shape`, `Glyph.Pips`, `Glyph.Hue`, cases verbatim from §2 | **Collision: `Shape`.** `HunchUI` imports SwiftUI and `HunchCore`; a top-level `Shape` is ambiguous with `SwiftUI.Shape` at every use site in the renderer. `N22` (nest state types in their owner) fixes it at the declaration and costs nothing — `Glyph.Shape.triangle`, or `.triangle` inferred. `HunchCore::Shape` (N23, SE-0491) stays in reserve for an ambiguity that survives nesting; it should never be needed. |
| the deck | `enum Deck` caseless, `Deck.all: [Glyph]`, `Deck.glyph(id:)` | `W16`. `- Complexity: O(1)` on the subscript (`N47`). |
| a law's truth table — "**extension**" | `struct LawTable: Hashable, Sendable` | **Collision: `extension` is a keyword.** The design already anticipated this ("`table` in code"); make it a real type, not a `[UInt64]`. `Extension.swift` would also trip `01 P28`'s banned-file grep. |
| the law | `indirect enum LawNode` (the AST, `Codable`, stored) **plus** `struct Law` (node + resolved `LawTable` + cached `Metrics`, never `Codable`) | `N2`/`N47`. `difficulty(of: Law) -> Double` reads `law.marginalDeficit` and `law.admitRate`, both of which need the table — as computed properties on the AST they would be O(n) behind a dot, and a contextual table costs 2 µs to build. Resolving once in `Law.init(_ node:)` keeps the design's published signature literally true *and* O(1). |
| the Loom | **no type** | The verdict is a pure function of `(law, prev, cur)`. A `struct Loom { let law: Law }` wrapping it is `04 A19`'s pass-through: delete it and nothing fails. "Loom" survives as `LoomFeature`, `ThroatView` and the fiction. Ship `Law.admits(_ glyph: Glyph, after previous: Glyph) -> Bool` (`N9`, third-person verb) beside `Verdict.admit` (`N29`). |
| admit / reject | `enum Verdict: Sendable { case admit, reject }` | Cases are imperative verbs, which `N29` would normally reject — but `N36` (precedent beats purity) applies: the domain locks them and `verdict == .admit` reads correctly. |
| band **and** family | **one type**: `enum Band: Int, CaseIterable, Comparable, Sendable { case literal = 1, pair, exclusive, relational, contextual, guarded, composite, systemic }`, with `par(for:)`, `cap(for:)`, `population`, `difficultyRange` | §5.3 fixes "strictly one family per band, no reprises", so `Band` and `Family` are in bijection. Two types for one concept is `W28`'s smell in a different costume, and `Family(band)` would be an identity function that eventually drifts. Keep both *words* in prose; ship one type. Record the collapse in `DECISIONS.md`. |
| `targetδ`, `δ_served`, `θ` | `targetDelta`, `servedDelta`, `ability` | Greek identifiers compile. They cannot be typed reliably, greped, or read aloud (`N1`), and `δ_served` additionally breaks `N33` (no underscores). |
| probe (noun and verb), twin | `struct Probe { let glyph: Glyph; let verdict: Verdict; let isTwin: Bool }`; `func probe(_ glyph: Glyph)` and `func probeTwin()` on `Round` | `N6`: side effects → imperative verb. `func twin()` would be a noun promising purity. |
| the Bench, rule-tiles, the coupler | `struct BenchLayout: Codable`, `enum RuleTile { case ramp(Ramp), bridge(Bridge), fork(Fork), tally(Tally) }`, `enum Coupler: UInt8 { case and, or, xor }`; SwiftUI counterparts are `RampView`, `BridgeView`, `ForkView`, `TallyView` | **Collision: `Ramp` is both a data payload and a widget.** `N39` allows the `View` suffix precisely to break a collision with a model type; this is that case. |
| `Bench.layout(for:)` / `parse(_:)` | `BenchLayout.init(_ law: LawNode)` and `LawNode.init?(_ layout: BenchLayout)` | A `Bench` caseless-enum namespace holding two static functions is a `Utils` with a better name. `N14`: a value-preserving conversion drops the label. G10 then reads `#expect(LawNode(BenchLayout(law)) == law.renderedNormalForm)` — one line, both directions. |
| the Seal, barred | `func seal()`; `var sealBar: SealBar?` where `enum SealBar { case inertRail(Int), unboundSocket(Int), constantExtension }` | A `Bool isSealBarred` cannot answer "which rail pulses?", so §4.3's behaviour would need a second parallel field — `W28` exactly. `N10`'s negative-name ban deviates here because the machine state *is* the bar. |
| the Codex, a page, a shelf | `@MainActor @Observable final class Codex`; `struct CodexPage: Codable`; `struct CodexShelf` | `N40`: `…Store` is for a type that gatekeeps a collection; the Codex *is* the archive, so it takes the bare domain noun. Never `CodexManager`, never `CodexStore`. |
| the Anomaly | `enum Anomaly` caseless (`dayIndex(_:)`, `seed(day:)`), `struct AnomalyLedger: Codable` | `W16`. Both functions are pure over `TimeInterval`/`Int64`. |
| the Profile, its axes | `struct Profile: Codable, Sendable` with `enum Axis: CaseIterable { case induction, retention, flexibility, restraint, tempo }` | These five identifiers are code-only — §12.9 forbids them entering the String Catalog in any form, visible or spoken. |
| the four modes | `enum Mode: UInt8, Codable, Sendable { case probe, drift, echo, sieve }`, rendered `Text(verbatim: mode.wordmark)` | §6.10 already demands a `UInt8` raw value, not `String`. The second half matters as much: `Text(mode.wordmark)` with a `String` is not extracted (`07 B39`), and `Text("PROBE")` with a literal *is* extracted — which is wrong, because §12.9 ships the mode names as untranslated wordmarks. `verbatim:` is the only spelling that is right on both counts. |
| ability, "core" | `struct Ability { var baseline: Double?; var offset: [Mode: Double]; var scoredRounds: [Mode: Int] }` | Two findings. `core` collides with the module name `HunchCore` at every reading; `baseline` is the role (`N4`). And §10.4 says "`core` is **undefined**, not 0" — `var core: Double` cannot say that, so cold start becomes a sentinel someone will compare against `0.0`. `Double?` is the type-level statement (`W28`). |
| the ten on-disk files | `enum StoreFile { case manifest, codexIndex, codexShelf(Band), anomaly, profile, ladder, statistics, round(Mode), lawIndex }` | §11.13's tree and §11.13's reset map both become exhaustive `switch`es with no `default:` (`W29`), so adding a file to the tree is a compile error in the reset map. |
| the persistence seam | `protocol PersistenceStore: Sendable` — the brief's name, kept | `W44`'s *first* question, not its size tiebreak: a repository boundary keeps its protocol at any member count. The `…Store` suffix survives `N26` for the reason `N40` gives. |
| audio and haptic cues | `enum Cue`; `protocol CuePlayer: Sendable`; `SynthesizedCuePlayer`, `HapticCuePlayer`, `SilentCuePlayer` | `N25`: name the abstraction for what it is, implementations for how they do it — the `RemoteUserStore`/`InMemoryUserStore` shape. `AudioManager` and `HapticsService` are both `N26` bans. |

---

## 4. The concurrency plan

**Default isolation, per target** (`01 P17`, `05 R7`): every `HunchCore` target gets **none** — nonisolated, the SwiftPM default. `HunchUI`, `LoomFeature`, `CodexFeature`, `MetaFeature`, `HunchAppFeature` get `.defaultIsolation(MainActor.self)`. `HunchNavigation` and `Feedback` get **none**, because a route graph and a cue vocabulary are values. Every declaration visible outside its own file writes `@MainActor` explicitly anyway (`05 R8`).

**`Sendable`.** Everything in `HunchCore` is a value type and every public one writes `: Sendable` explicitly (`05 R21`): `Glyph`, `Verdict`, `LawNode`, `LawTable`, `Law`, `Band`, `Probe`, `Ribbon`, `BenchLayout`, `RuleTile`, `RoundPhase`, `Outcome`, `Ability`, `ServingState`, `CodexPage`, `RoundSnapshot`, `Profile`, `StoreFile`. Nothing in the core is a class. `MaskTable.resident` (54 KB) and `Deck.all` are `static let` of immutable `Sendable` values — rung 1 of `05 R50`, and *not* the singletons the brief bans, because there is no mutable state and nothing to substitute.

**`@MainActor`.** `Round`, `Codex`, `Ladder`, `AppDependencies`, `Router`, every `View`, `HapticCuePlayer`. `Round` gets `nonisolated init` only if a preview needs to build one off-actor (`05 R35`); it does not today.

**Actors — exactly two, and both earn it under `05 R17`'s third row.**

- `actor FilePersistenceStore: PersistenceStore` — cohesive state with behaviour, callers already `async`, and file I/O has no business on the main actor. Shape is `04`'s `JSONStore` with `.atomic` writes; the only addition is that `save(_:to:)` switches on `StoreFile` for the write order §11.13 fixes (`round.json` first, snapshot slot cleared last).
- `actor LawIndexLoader` — the 9,767-table enumeration is built once in the background (§14.5 open decision 4) and must not be built twice if two callers race. That is `05 R30` verbatim: cache the `Task`, not the value.

  ```swift
  actor LawIndexLoader {
      private var build: Task<LawIndex, any Error>?
      private let store: any PersistenceStore

      func index() async throws -> LawIndex {
          if let build { return try await build.value }
          let task = Task { [store] in try await LawIndex.loadOrRebuild(from: store) }
          build = task                                   // synchronous — lands before the first suspension
          do { return try await task.value } catch { build = nil; throw error }
      }
  }
  ```

  `LawIndex` itself is an immutable `Sendable` struct, so once built it leaves the actor and is never touched again. Nothing else in this project needs an actor: `05 R18` forbids one for a counter, and every other piece of core state is a value threaded through a pure function.

**The RNG under strict concurrency.** An RNG is mutable state, and the naive fixes — a global, a `static var`, an `@Observable` property, an actor — each destroy either determinism or the ability to call `next()` synchronously. The resolution is that **the generator never lets an RNG escape one synchronous call tree**:

```swift
public struct SplitMix64: RandomNumberGenerator, Sendable {   // a struct of one UInt64 — trivially Sendable
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 { /* §5.3's constants */ }
}

public func generate(seed: UInt64, band: Band, targetDelta: Double,
                     mode: Mode, avoid: Set<UInt64> = []) -> LawNode {
    var rng = SplitMix64(seed: seed ^ (UInt64(band.rawValue) << 32) ^ mode.salt)   // local var, never escapes
    …                                                                              // &rng threaded down
}
```

Five consequences, all of them rules:

1. **`generate` is synchronous and `nonisolated`.** Not `async`. `05 R13`'s trap — a bare `nonisolated async` function now runs on the *caller's* actor — cannot fire on a function that has no suspension point, and `@concurrent` would be wrong for a sub-millisecond pure function. If band-8 generation ever measures slow on an A15, the offload is `@concurrent func makeLaw(seed: UInt64, …) async -> LawNode` which constructs its own `SplitMix64` inside: the **seed** crosses the isolation boundary (a `UInt64`), the generator never does.
2. **Randomness is a parameter, never an ambient.** Every function that needs it takes `using rng: inout some RandomNumberGenerator` — `shuffled(using:)`'s own label (`N15`, preposition row).
3. **`SystemRandomNumberGenerator`, `Int.random`, `Date()` and `UUID()` are banned from `HunchCore` by CI grep** (§5). The only legal source of nondeterminism is `SeedSource`, which lives in `Modules/` (§6).
4. **No RNG is ever stored in an `@Observable` class.** It would make the model's state depend on how many times SwiftUI evaluated a body.
5. **Determinism is therefore not a concurrency problem at all** — it is a *scoping* problem, and the scope is one function call. That is the entire answer to "an RNG is mutable state."

**The one escape hatch in the codebase.** `AVAudioSourceNode`'s render block runs on a real-time audio thread: it may not allocate, may not lock, and may not touch main-actor state. `05 R17`'s ladder has no row for it — `@MainActor` is wrong, `Mutex` is wrong (priority inversion in a render callback), an actor is wrong (no `await` in a render block). The design's own answer is a fixed 8-slot voice array with an atomic head index, so:

```swift
/// Thread-safe by construction, not by lock: the main actor is the sole producer and the
/// audio render thread the sole consumer. Slots are POD, allocated once in `init`, and the
/// only synchronisation is `head`'s release/acquire ordering. Never add a second producer.
final class VoiceBank: @unchecked Sendable { … }   // Atomic<UInt64> (Synchronization, iOS 18) + one allocation
```

That comment is mandatory: `05 R26`/`R29` and `07 B34a`'s check 3 fail the build on an undocumented hatch. It should be the only `@unchecked Sendable`, `nonisolated(unsafe)`, `Task.detached` or `assumeIsolated` in the repository — and because the grep is in CI, "should be" is checkable.

---

## 5. The test plan

The brief's seven critical tests, mapped:

| Brief's invariant | Test kind | Where | Tags |
|---|---|---|---|
| 1. Generator invariants, 10,000 laws × 8 bands | seeded-corpus invariant suite | `LawGenerationTests` | `.unit .presubmission` |
| 2. Simulated player, convergence + 80 % + no loss loop | `ResponseHarness` (Level A) fast; `ReasonerHarness` (Level B) gated | `LadderTests` | A: `.unit .presubmission` · B: `.integration .nightly` |
| 3. Difficulty calibration (H10 ρ ≥ 0.75) | Level-B statistic | `LadderTests` | `.integration .nightly` |
| 4. Determinism across runs *and processes* | golden fixture + exit test | `LawGenerationTests` | `.unit .presubmission` |
| 5. Localization completeness, ≤250 keys, banned lexemes | **CI script over `Localizable.xcstrings`**, not a package test | `Scripts/` | — |
| 6. Persistence round-trip and v1 migration | fixture tree + `TestScoping` trait | `PersistenceTests` | `.unit .presubmission` |
| 7. No-network assertion | build phase **and** CI grep | `Scripts/` + Xcode | — |

**Defending the 10-second budget.** The design already budgets the two big items (§5.7: the 10,000-law suite ≈ 1.2 s; §10.10: Level A 10⁶ rounds < 0.4 s; Level-B smoke subset ≈ 0.8 s). Four rules keep it there:

1. **The whole fast suite is `swift test --package-path HunchCore`** — no simulator, no host app (`06 T3`), which is the single largest lever and the brief's stated rationale for the two-target split.
2. **Level B's full matrix (640 k rounds, ~9 min) is declaratively gated**, exactly as `06 §18` play 7 shows: `.enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1")` plus `.tags(.integration, .nightly)` and a `.timeLimit(.minutes(15))` hang guard. It runs nightly and as a hard gate before any archive (§14.5 decision 5). It is not deleted (`06 T58`).
3. **The `LawIndex` is built once for the whole suite**, as `enum Corpora { static let index: LawIndex = … }` in `HunchTestSupport`. A `let` of an immutable `Sendable` value is the one sanctioned piece of shared state under `06 T10`'s parallel-in-one-process model; a `static var` would be a data race.
4. **CI times the suite and fails over budget** — `START=$SECONDS; swift test …; [ $((SECONDS-START)) -lt 10 ]`. A budget nobody measures is a budget that has already been spent.

**The 10,000-law suite is a loop inside a test, and that is deliberate.** `06 T21` says a `for` loop inside a test is a bug. Parameterising here would mean `arguments: Band.allCases, 0..<10_000` — 80,000 test-case nodes (`06 T22`'s Cartesian trap at scale), which costs more in runner overhead than the assertions cost to evaluate. So: parameterise over the **eight bands**, loop the ten thousand laws inside, and buy back everything `T21` was protecting with the seed:

```swift
@Test("Generator guardrails hold across the band", .tags(.unit, .presubmission), arguments: Band.allCases)
func guardrailsHold(_ band: Band) throws {
    for i in 0..<10_000 {
        let seed = Corpora.seed(band: band, index: i)          // reproducible from (band, i)
        let law = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
        let table = LawTable(law)
        guard table.isSatisfiable, table.isFalsifiable, band.admitWindow.contains(table.admitRate),
              LawNode(BenchLayout(law)) == law.renderedNormalForm else {
            Attachment.record(law, named: "band\(band.rawValue)-seed-\(String(seed, radix: 16)).json")  // 06 T18a
            Issue.record("guardrail failed at band \(band.rawValue), seed 0x\(String(seed, radix: 16))")
            return
        }
    }
}
```

Every failure names the one seed that reproduces it, and that seed is then promoted into `@Test(arguments: knownBadSeeds)` as a permanent regression case — which is `06 T53`'s "compensate for the missing shrinker by promoting every failure into a named test", applied verbatim. The 200,000-configuration Bench fuzzer (§4.4, backward direction) gets the same treatment and moves to `.nightly` if it measures over ~1 s.

**Determinism across processes.** Two tests, because the brief asks for two properties. Same-process: generate twice, compare `LawTable`s bit-for-bit. **Cross-process: a golden fixture.** `LawGenerationTests/Fixtures/determinism-seeds-v1.json` maps 512 `(seed, band, targetDelta, mode)` tuples to the resulting `lawKey`; it is produced by a separate `swift run` tool and committed, so every run compares against bytes written by a *different process on a different day* — which is the actual claim, and stronger than re-running in a child process. The exit test (`06 T49`, macOS-only, which HunchCore is) is the cheap second opinion, and it is available precisely because the logic is in a host-testable package.

**Persistence and migration.** `Fixtures/v1/` is a whole `Application Support/Hunch/` tree declared `resources: [.copy("Fixtures")]` — and every lookup therefore passes `subdirectory: "Fixtures"`, which is `06 T54`'s trap and the reason fixture suites die. A `TestScoping` trait (`06 T20`) copies the tree into a fresh temp directory per test and removes it after; no `deinit`, no shared path. Three assertions: v1 loads green under the current schema forever; each of §11.13's five reset actions leaves exactly the specified file set with `anomaly.json` and `anomaly.hw` byte-identical; and a round-trip of every `StoreFile` case (`06 T55`'s malformed sibling included — a truncated `codex-b4.json` must quarantine and rebuild, not crash).

**Clock and RNG injection.** The RNG is a parameter (§4). Time is smaller than the guide assumes: §6.1 fixes that *no wall-clock quantity affects score, marks or the Rasch update*, and §9's speed curve is a function of glyph index, not of elapsed seconds. So there is **no `Clock` abstraction anywhere** — SIEVE's timing is a pure `SieveSchedule` value plus one `ContinuousClock.sleep` at the view edge, and the only injected time source is `06 §13`'s minimal shape:

```swift
public struct Now: Sendable {                       // dates only: firstFoundAt, lastPlayed, the UTC day index
    public var date: @Sendable () -> Date
    public static let live = Self { Date() }
    public static func fixed(_ date: Date) -> Self { Self { date } }
}
```

This matters twice over: `swift-clocks` is a third-party dependency and therefore banned, so re-implementing `TestClock` would have been real work. Designing the timing out is cheaper and truer to P4.

**CI source hygiene.** `07 B34a`'s script runs with four HUNCH-specific checks appended, all of them things no test can see: (5) no `URLSession`/`Network`/`CFNetwork`/`NWConnection` anywhere (the brief's build phase, duplicated in CI); (6) no `SystemRandomNumberGenerator`, `\.random(`, `Date()` or `UUID()` under `HunchCore/Sources/`; (7) no `Text`, `Label` or `AttributedString` outside `.accessibility*` modifiers in the six play-surface files (§12.9's `PlaySurfaceTextTests`, which is a source lint and not a runtime test); (8) `Localizable.xcstrings` has ≤ 250 keys, zero `"state": "new"`/`"needsReview"` entries in any of the 12 locales, and zero per-locale banned lexemes from §1.13's list. Checks 7 and 8 are *not* package tests because neither artifact exists in a test bundle — a String Catalog is compiled to `.lproj` at build time and the source is repo-relative.

---

## 6. Dependency injection

One composition root (`04 A2`), in `HunchAppFeature`, named once by `@main`:

```swift
// App/HunchApp.swift — the app target's only Swift file.
import HunchAppFeature
import SwiftUI

@main
struct HunchApp: App {
    @State private var dependencies = AppDependencies.live()
    var body: some Scene { WindowGroup { AppView().hunchEnvironment(dependencies) } }
}
```

```swift
// Modules/Sources/HunchAppFeature/AppDependencies.swift
@MainActor
public struct AppDependencies {
    public let store: any PersistenceStore
    public let now: Now
    public let seeds: SeedSource            // the ONLY nondeterminism in the app, and it lives here
    public let ladder: Ladder               // @Observable: Ability + ServingState + the novelty rings
    public let codex: Codex                 // @Observable: the archive, lazy per shelf
    public let cues: any CuePlayer

    public static func live() -> AppDependencies {
        let store = FilePersistenceStore(directory: .applicationSupportDirectory.appending(path: "Hunch"))
        return AppDependencies(store: store, now: .live, seeds: .live,
                               ladder: Ladder(store: store), codex: Codex(store: store),
                               cues: CompositeCuePlayer(SynthesizedCuePlayer(), HapticCuePlayer()))
    }

    /// Previews and integration tests. Deterministic by construction: fixed seed, fixed date, silent cues.
    public static func preview(seed: UInt64 = 0xC0FFEE, date: Date = .distantPast) -> AppDependencies { … }
}

extension View {
    /// 04 A28 — the module that knows what the graph contains is the module that installs it.
    public func hunchEnvironment(_ dependencies: AppDependencies) -> some View { … }
}
```

- **`SeedSource` is where "no singletons" actually bites.** `struct SeedSource: Sendable { var next: @Sendable () -> UInt64 }` with `.live` calling `SystemRandomNumberGenerator` and `.fixed(_:)` returning a constant. It is the single point at which the app becomes nondeterministic, it lives in `Modules/`, and §5's grep therefore bans `SystemRandomNumberGenerator` from `HunchCore` outright. `04 A29`'s rule is not "no singletons" but "no singleton inside a boundary you test across" — this is that boundary, made one line wide.
- **Previews get the real types, not fakes.** `InMemoryPersistenceStore` ships in `HunchCore/Sources/Persistence/` and imports no `Testing`; `AppDependencies.preview(seed:date:)` composes it with `Now.fixed`, `SeedSource.fixed` and `SilentCuePlayer`. The `Issue.record`-ing `unimplemented` doubles (`06 T38`) live in `HunchTestSupport`, which is absent from `products:` and named by no non-test target — asserted by `07 B34a`'s check 4, so `import Testing` cannot reach the release binary (`06 T5/T5a`).
- **Re-inject into every presentation.** `AssayInspectorView`, `ResetConfirmAlert` and `SievePauseOverlay` are presented subtrees and start a new environment hierarchy — `04 A25`, the single most common environment bug. `HunchUI` components read `@Environment(\.…)` in the optional form (`04 A26`) because they are used from previews that install nothing.
- **Routers are not in the graph.** One `@Observable Router` per `NavigationStack` (`04 A33`), owned by the screen that hosts it; `Route` is a `Codable` enum in `HunchNavigation` (`04 A32`) and navigation restores through `@SceneStorage` holding an encoded `[Route]` (`04 A39`).
- **Custom environment values use `@Entry`** (`04 A27`): `@Entry var glyphScale: CGFloat = 1.0`, `@Entry var theme: Theme = .dark`, `@Entry var storeHealth: StoreHealth = .healthy` (the §11.13 disk-full hairline).

---

## 7. Where the constraints fight the guide

1. **"Two targets" (brief) vs. an eight-file app shell (`01 P8`) and 18 screens.** Read the brief's "two targets" as *two build products* — one package the fast tests run against, one app. Nothing in the brief's stated rationale ("`swift test` runs in seconds with no simulator") requires the UI to be inside the app target, and putting it there would make 18 screens untestable and unpreviewable. Resolution: the tree in §1. Cost: one manifest more than the brief pictures.
2. **"One local package" (`01 P14`) vs. "zero SwiftUI in HunchCore" + "`swift test` under 10 s".** One package means `swift test` compiles the SwiftUI targets too, on the *host*, where iOS-only modifiers do not exist. Resolution: two packages, `HunchCore/` and `Modules/`, and it is a named deviation. `P14`'s three costs are (a) `package` access only works within a package, (b) a versioning obligation, (c) N manifests to keep in step with shared dependencies. (b) is void — nothing consumes these. (c) is void — the brief bans third-party dependencies outright, so there is nothing to keep in step. Only (a) survives, and it costs `public` on a UI module consumed by exactly one app. `P14` itself notes that a local package depending on a local package builds fine.
3. **`01 P12` ("don't pre-create modules") vs. a 3,490-line design that already names every system.** `P12` protects you from inventing a boundary whose shape you have not learned. Here the shapes are given: §0.4's ownership table *is* the module list. The rule still bites at the edges — do not create `Feedback`, `EchoRound`, `SieveSchedule` or `MetaFeature` before phase 5/6 of §14.3 demands them. Create the target on the day its owner section is being implemented, not on day one.
4. **`06 T21` (no loops in tests) vs. 10,000-law and 200,000-configuration suites.** Resolved in §5: parameterise over bands, loop inside, and pay `T21`'s protection back with a reproducing seed in every failure message plus an `Attachment.record` of the offending AST.
5. **`04 A40` (SwiftData for a small offline app; plain JSON "under ~1000 records") vs. a 27,015-page Codex at ~3.8 MB.** The Codex is *above* the JSON threshold in total and *below* it per file — §11.13 shards into eight shelves loaded lazily, with only `codex-index.json` (216 KB worst case) resident. The shard boundary is what keeps `A40`'s ruling true, so it needs an assertion, not a comment: a test that opening a shelf parses exactly one shelf file, and that no single file exceeds 512 KB.
6. **`04 A45`/`A42` (`@Query` is the default) is inapplicable.** With no SwiftData there is no `@Query` to lose, but `A42`'s bill still arrives: `Codex` re-implements change notification by hand. Affordable here only because writes are round-boundary events (a page every few minutes), not per-keystroke. Record which side of `A45` you are on in the README, as `A45` asks.
7. **`05 R17`'s state ladder has no row for a real-time audio callback.** Resolved in §4: a lock-free `VoiceBank` with `Atomic` and one documented `@unchecked Sendable`. This is the reason iOS 18 is the right floor and not merely the guide's default — `Synchronization` is iOS 18+.
8. **`04 §7`'s "no per-screen view models" vs. the round.** `A18`'s triggers 1 and 2 both fire: the round is a nine-phase machine with locked-input windows, two strikes, a Bench draft, and a snapshot written after every verdict. A screen-scoped `@Observable` is *earned*. Name it `Round` — the bare domain noun, because the round is the thing (`N40`) — not `RoundViewModel` (`A19`, `N40`). The pure part (`RoundPhase` transitions, scoring, the ribbon) stays in `HunchCore` and is tested there (`A20`), so `Round` is thin enough that the `A19` pass-through test still passes: delete it and the phase timing, input locking and snapshot cadence all break.
9. **`06`'s toolbox assumes three packages the brief bans.** `swift-clocks` → designed out (§5, no clock). `swift-snapshot-testing` → the `.json` snapshot role is filled by hand-rolled golden fixtures encoded with `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])`; the image-snapshot role is filled by §14.3 phase 7's manual screenshot review in en/de/ar, which the brief mandates anyway. `swift-numerics` → `06`'s own migration table notes that `XCTAssertEqual(_:_:accuracy:)` has **no Swift Testing equivalent**, and this project compares floating point constantly (δ, θ, π₀ = 0.44, Spearman ρ, the 0.02 G8 tolerance). Write `isApproximatelyEqual(_:_:absoluteTolerance:)` — five lines — in `HunchTestSupport` on day one, before the first `#expect(a == b)` on a `Double` ships.
10. **"Swift Testing, not XCTest" (brief) vs. `06 T43`.** XCUITest and `performAccessibilityAudit` have no Swift Testing path and are not getting one — Xcode's build system rejects `import Testing` in a UI test target. `HunchUITests/` is therefore `XCTestCase`, and that is not a violation of the brief: the brief's rule governs *new unit tests*, which all live in the two packages.
11. **`01 P34` (generated symbols break `swift build` inside a package).** Leave "Generate String Catalog Symbols" **off**. `Loc` (§1) is the hand-written accessor §12.9 requires anyway, so the generated symbols would buy nothing and cost the fast path.
12. **`07 B18`/`B19` and the brief's "archive builds with zero warnings".** `OTHER_SWIFT_FLAGS[config=Release] = $(inherited) -warnings-as-errors`, and any `-Wwarning <group>` exemption must be written **before** it — flags apply left to right, so a trailing blanket flag silently overrides an earlier exemption.
