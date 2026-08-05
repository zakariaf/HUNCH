# T01 — The `Feedback` target and the cue vocabulary

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | Cue table (AUDIO) — its vocabulary half |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/feedback-target.md` is this task's specification end to end: §2 fixes that **one** enum drives both media and that `Cue` names *what happened in the game*, §3 gives the four implementations and the ruling that the composite fires **haptics first, then audio**, §4 gives the isolation (target default none; the two players `@MainActor` explicitly), §6 gives the injection shape, §7 gives `RecordingCuePlayer`. `references/audio-cues.md` §3 and `references/haptic-patterns.md` §3–§4 are the two row inventories this task turns into types. |
| `hunch-swift-code` | Where the files go (`Modules/Sources/Feedback/`, the routing table), and the naming bans this task is one call away from tripping: `N25` names the abstraction for what it is and the implementations for how they do it, `N26` bans `AudioManager`, `HapticsService` and `CueManager`, and `04 A29`/`08 §6` ban a `CuePlayer.shared`. It also owns the composition root that T06 will re-wire. |

`hunch-design-tokens` is **not** loaded. This task declares no duration, no colour and no geometry; a
cue's *timing* is `hunch-motion-and-feedback`'s beat sheets and its *parameters* are §13.8 / §13.9's.

## Objective

At the end of this task `Modules/Sources/Feedback/` holds the complete cue **vocabulary**: a
`CompositeCuePlayer` that fans one `Cue` out to both media in the one order that is correct, a
`Cue.representatives` list that covers every case and every parameterisation, and two `CaseIterable`
row-identity enums — `AudioRow` with §13.8's fifteen rows and `HapticRow` with §13.9's eleven cached
players — that make the many-to-one mapping between game events and spec rows a typed fact instead of
a comment. Nothing yet makes a sound: T03 fills the voice table and T05 fills the pattern table, and
both get an exhaustive `switch` that turns a missing row into a compile error.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.8 | The cue table is the single normative source for every sound; its **fifteen rows** are `AudioRow`'s cases and nothing else |
| `GAME_DESIGN.md` | §13.9 | The pattern table is the single normative source for every haptic; its rows, and the ruling that `twin` is composed rather than cached, fix `HapticRow` |
| `GAME_DESIGN.md` | §6.4 | Any one channel alone is sufficient — the reason `SilentCuePlayer` is a legitimate implementation and not a stub, and the reason both Settings toggles are honest |
| `GAME_DESIGN.md` | §12.6 (FEEDBACK) | `Haptics` and `Sound` are two states each; `Level` is Normal / Low. This task consumes nothing of them yet — it only leaves the seam where T04 and T06 do |
| `.claude/skills/hunch-motion-and-feedback/references/feedback-target.md` | §2, §3, §4, §6, §7 | The enum's shape, the four implementations, the composite's firing order, isolation, injection, `RecordingCuePlayer` |
| `.claude/skills/hunch-motion-and-feedback/references/audio-cues.md` | §3 | The fifteen cues and where each fires — the forward index `AudioRow` is keyed on |
| `.claude/skills/hunch-motion-and-feedback/references/haptic-patterns.md` | §3, §4 | The eleven patterns, and §4's arithmetic: `twin` is not a cached player, `sieve.hit`/`sieve.miss` share a table row but are two players |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §3 (audio and haptic cues), §4 | The file set, `N25`'s naming shape, and `Feedback`'s **no default isolation** |
| `ios-swift-guide/06-TESTING.md` | `T5b`, `T29`, `T30` | Test targets mirror source paths, so `Modules/Tests/FeedbackTests` is required, not optional; same-named tags in different modules are equivalent |

**What already exists, and must not be re-created.** E08·T06 shipped `Modules/Sources/Feedback/` with
`Cue.swift` and `CuePlayer.swift` (`protocol CuePlayer: Sendable { @MainActor func play(_ cue: Cue) }`,
`SilentCuePlayer`, `RecordingCuePlayer`) and wired `Round` to fire through it. E09·T10 shipped
`RevealCuePoint`, `RevealCueSchedule.absolute(for:)` and `RevealHapticSchedule.events(for:)` in
`LoomFeature`. **Read those files first**; this task extends them and re-declares none of them.

## TDD — the test comes first

`Modules` is never host-built (E03·T06): `swift test --package-path Modules` fails with
`'bundle()' is only available in macOS 12 or newer` and the fix is not `.macOS(.v15)`. Every test
below runs in the simulator through `xcodebuild test`.

**Step 1 — write the failing test.** First add the target to `Modules/Package.swift` (a `.testTarget`
named `FeedbackTests` depending on `Feedback`) and add it to `Presubmission.xctestplan` by membership.
Then create `Modules/Tests/FeedbackTests/Tags.swift` mirroring the eight `@Tag static var`
declarations (`06 T29`: same-named tags in different modules are equivalent, which is what keeps
`-only-testing-tags presubmission` selecting this target too).

Then create `Modules/Tests/FeedbackTests/CueVocabularyTests.swift`:

```swift
import Testing
import HunchCore
@testable import Feedback

@Suite("The cue vocabulary — §13.8, §13.9", .tags(.unit, .presubmission))
struct CueVocabularyTests {

    // MARK: coverage — the list every spec-table test walks

    @Test("representatives covers every case and every parameterisation")
    func representativesIsTotal() {
        let all = Cue.representatives

        // both verdicts × twin and not
        for verdict in [Verdict.admit, .reject] {
            for isTwin in [false, true] {
                #expect(all.contains(.verdict(verdict, isTwin: isTwin)))
            }
        }
        // the two parameterised cues, at every value they can take
        for marks in 1...3 { #expect(all.contains(.lawDeclaredCorrectly(marks: marks))) }
        for step in 1...5 { #expect(all.contains(.streak(step: step))) }
        // and one of every remaining case
        for cue in [Cue.probeSubmit, .declare, .bar, .strike, .lawBroken,
                    .driftMoment, .codexInscribe, .sieveTick, .sieveHit, .sieveMiss] {
            #expect(all.contains(cue))
        }
        #expect(Set(all).count == all.count)          // no duplicate representative
    }

    // MARK: the two row vocabularies

    @Test("every AudioRow is reachable from some cue, and every cue reaches exactly one")
    func audioRowsAreExactlyCovered() {
        let reached = Set(Cue.representatives.map(\.audioRow))
        #expect(reached == Set(Cue.AudioRow.allCases))
        #expect(Cue.AudioRow.allCases.count == 15)     // §13.8's table has fifteen rows
    }

    @Test("every HapticRow is reachable, and the silent-in-haptics cues reach none")
    func hapticRowsAreExactlyCovered() {
        let reached = Set(Cue.representatives.flatMap(\.hapticRows))
        #expect(reached == Set(Cue.HapticRow.allCases))
        #expect(Cue.HapticRow.allCases.count == 11)    // §13.9's cached players
        #expect(Cue.declare.hapticRows.isEmpty)
        #expect(Cue.codexInscribe.hapticRows.isEmpty)
        #expect(Cue.sieveTick.hapticRows.isEmpty)
    }

    @Test("no cue is silent in both media")
    func everyCueSpeaksSomewhere() {
        for cue in Cue.representatives {
            #expect(cue.channels.isEmpty == false)
        }
    }

    @Test("the mapping is many-to-one in BOTH directions, which is the point of two vocabularies")
    func mappingIsManyToOneBothWays() {
        // one cue → two media
        #expect(Cue.verdict(.admit, isTwin: false).channels == [.audio, .haptic])
        // one cue → one medium
        #expect(Cue.codexInscribe.channels == [.audio])
        // one cue case → three audio rows, because §13.8 gives twin its own row
        #expect(Cue.verdict(.admit,  isTwin: false).audioRow == .admit)
        #expect(Cue.verdict(.reject, isTwin: false).audioRow == .reject)
        #expect(Cue.verdict(.admit,  isTwin: true).audioRow  == .twin)
        #expect(Cue.verdict(.reject, isTwin: true).audioRow  == .twin)
        // …but ONE haptic row, because §13.9 composes twin from the verdict's own player
        #expect(Cue.verdict(.admit,  isTwin: true).hapticRows == [.admit])
        #expect(Cue.verdict(.reject, isTwin: true).hapticRows == [.reject])
        #expect(Cue.verdict(.admit,  isTwin: true).isTwinPrefixed)
        #expect(Cue.verdict(.admit,  isTwin: false).isTwinPrefixed == false)
    }

    @Test("the parameterised rows carry their parameter to the cache key, not to the row")
    func parameterisationIsAtTheKey() {
        #expect(Cue.lawDeclaredCorrectly(marks: 1).hapticRows == [.lawDeclaredCorrectly])
        #expect(Cue.lawDeclaredCorrectly(marks: 3).hapticRows == [.lawDeclaredCorrectly])
        #expect(Cue.lawDeclaredCorrectly(marks: 1) != Cue.lawDeclaredCorrectly(marks: 3))
        #expect(Cue.streak(step: 2) != Cue.streak(step: 5))
    }

    // MARK: the composite

    @Test("the composite fans out to every player, in the order it was given")
    @MainActor
    func compositePreservesOrder() {
        let log = OrderLog()
        let composite = CompositeCuePlayer(TaggedPlayer("haptic", log), TaggedPlayer("audio", log))
        composite.play(.verdict(.admit, isTwin: false))
        #expect(log.entries == ["haptic", "audio"])
    }

    @Test("the composite over zero players is legal and silent")
    @MainActor
    func compositeOverNothingIsSilent() {
        CompositeCuePlayer().play(.bar)                // must not trap
    }

    @Test("RecordingCuePlayer still records through the composite")
    @MainActor
    func recordingThroughTheComposite() {
        let recorder = RecordingCuePlayer()
        CompositeCuePlayer(SilentCuePlayer(), recorder).play(.strike)
        #expect(recorder.cues == [.strike])
    }

    // MARK: isolation

    @Test("Cue is Sendable and crosses an isolation boundary as a value")
    func cueIsSendable() async {
        let cue = Cue.lawDeclaredCorrectly(marks: 2)
        let echoed = await MainActor.run { cue }
        #expect(echoed == cue)
    }
}

// Two hand-written doubles, in the test target: the composite's ordering cannot be observed
// from inside a single player, and `06 T36`/`T52` ban every mocking framework.
@MainActor final class OrderLog { var entries: [String] = [] }

struct TaggedPlayer: CuePlayer {
    let tag: String
    let log: OrderLog
    init(_ tag: String, _ log: OrderLog) { self.tag = tag; self.log = log }
    @MainActor func play(_ cue: Cue) { log.entries.append(tag) }
}
```

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
UDID=$(xcrun simctl list devices available --json | /usr/bin/python3 -c \
  'import json,sys; print(next(d["udid"] for v in json.load(sys.stdin)["devices"].values() for d in v))')
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" -only-testing:FeedbackTests | xcbeautify
```

The first failure must be that the `FeedbackTests` target does not exist — fix the manifest and the
plan, then expect `type 'Cue' has no member 'representatives'`, `no type named 'AudioRow'` and
`cannot find 'CompositeCuePlayer' in scope`. If the run reports **green over zero tests**, the plan's
include-tag names a tag this target never declared (`07 B24`) — fix `Tags.swift` before writing a line
of source.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor** with the tests as the safety net.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/Feedback/Cue.swift` — `representatives`, `channels`, `audioRow`, `hapticRows`, `isTwinPrefixed` |
| create | `Modules/Sources/Feedback/CueRows.swift` — `Cue.AudioRow`, `Cue.HapticRow` |
| modify | `Modules/Sources/Feedback/CuePlayer.swift` — `CompositeCuePlayer` |
| create | `Modules/Sources/Feedback/VoiceSpec.swift` — the value type T03 fills |
| create | `Modules/Sources/Feedback/HapticPattern.swift` — the value type T05 fills |
| modify | `Modules/Package.swift` — the `FeedbackTests` test target |
| modify | `Presubmission.xctestplan` — add `FeedbackTests` by membership |
| create | `Modules/Tests/FeedbackTests/Tags.swift` |
| create | `Modules/Tests/FeedbackTests/CueVocabularyTests.swift` |
| modify | `DECISIONS.md` — the case-count ruling below |
| modify | `tests.json` — the cue-vocabulary entry |

## Implementation notes

### Two vocabularies, and why the second one is not duplication

`Cue` names *what happened in the game*. `AudioRow` and `HapticRow` name *rows of §13.8 and §13.9*.
Those are different things and the mapping between them is many-to-one in both directions — one cue
reaches two media, and one medium's row is reached by several cues. Modelling both as one enum is the
mistake `feedback-target.md` §9 lists first, because it forces either a fifteen-case `Cue` that leaks
the synth into the call sites or an eleven-case one that cannot express a twin.

```swift
extension Cue {
    /// §13.8's fifteen rows, as identities. `CaseIterable`, so T03's table is an exhaustive
    /// switch and adding a row without a spec is a compile error rather than a silent zero.
    public enum AudioRow: CaseIterable, Hashable, Sendable {
        case probeSubmit, admit, reject, twin, declare, bar, strike
        case correct, incorrect, driftMoment
        case sieveTick, sieveHit, sieveMiss, streak, codexInscribe
    }

    /// §13.9's eleven **cached players**. `twin` is deliberately absent — see below.
    public enum HapticRow: CaseIterable, Hashable, Sendable {
        case probeSubmit, admit, reject, bar, strike
        case lawDeclaredCorrectly, lawBroken, driftMoment, streak
        case sieveHit, sieveMiss
    }

    public enum Channel: Hashable, Sendable { case audio, haptic }
}
```

Three asymmetries in that pair, each of which is canon and none of which is an accident:

- **`twin` is an `AudioRow` and is not a `HapticRow`.** §13.8 gives `twin` its own row (the verdict
  cue at a reduced gain with one added octave partial) and `audio-cues.md` §3 rules that it *replaces*
  the verdict cue rather than layering over it. §13.9 gives `twin` a table row but
  `haptic-patterns.md` §4 rules that it is **not** a cached player: it is a prefix transient plus the
  verdict player offset, and caching it would let a twin's verdict drift from a plain verdict's. So
  the audio side gets a row and the haptic side gets `isTwinPrefixed` plus the verdict's own row.
- **`sieveHit` and `sieveMiss` share one row of §13.9's printed table and are two players.** Two
  cases, and §4's arithmetic only closes that way.
- **`lawDeclaredCorrectly` and `streak` are parameterised, and the parameter lives at the cache key,
  not in the row.** `Cue.lawDeclaredCorrectly(marks: 3)` and `(marks: 1)` are the same `HapticRow` and
  different `Cue`s; T05 caches on `(row, n)`.

### `representatives` exists because `Cue` cannot be `CaseIterable`

`Cue` has associated values, so no conformance is synthesised and none should be hand-written — a
`Cue.allCases` that quietly picked one verdict would make every spec-table test a partial walk. Ship
an explicit list instead, and let the first test above be the thing that keeps it total:

```swift
extension Cue {
    /// Every case, at every value its parameters can take. The spec-table tests in T03 and T05
    /// walk this; `CueVocabularyTests.representativesIsTotal` is what stops it going stale.
    public static let representatives: [Cue] =
        [.probeSubmit, .declare, .bar, .strike, .lawBroken, .driftMoment,
         .codexInscribe, .sieveTick, .sieveHit, .sieveMiss]
        + [Verdict.admit, .reject].flatMap { v in [false, true].map { Cue.verdict(v, isTwin: $0) } }
        + (1...3).map { Cue.lawDeclaredCorrectly(marks: $0) }
        + (1...5).map { Cue.streak(step: $0) }
}
```

`marks` is 1…3 and `step` is 1…5 capped, both from canon (§6.9's marks, §13.9's `streak` row). Clamp
at construction rather than trusting call sites — a `streak(step: 9)` must resolve to the capped
pattern, not to an index-out-of-range on the render thread.

### The case count, and the ruling to record

`feedback-target.md` §2 says "Twelve cases" above a listing of **thirteen**. The listing is the
normative half — it is what E08·T06 shipped and what the four modes actually fire — and the count is
the reference file's own arithmetic slip. **Ruling: ship the listing; the count is not load-bearing
and no test asserts it.** What the tests assert instead is total coverage of the two row vocabularies,
which is the property that actually matters and which a case count cannot give you. Record it in
`DECISIONS.md` with both readings named, and fix the reference file's count in the same commit.

### The composite, and the one order that is correct

```swift
public struct CompositeCuePlayer: CuePlayer {
    private let players: [any CuePlayer]
    public init(_ players: any CuePlayer...) { self.players = players }
    @MainActor public func play(_ cue: Cue) { for player in players { player.play(cue) } }
}
```

**Haptics first, then audio**, and the reason is not symmetry: `CHHapticPatternPlayer.start` is cheap,
while scheduling an audio voice can touch the engine's lazy start on the very first cue of a session
(§13.8), and the first `admit` of a session is exactly where the two channels must agree. The
composite itself is order-preserving and order-agnostic — it is the **composition root** that fixes
the order, in T06, and T06's acceptance criteria carry the grep that proves it.

`init` is variadic and therefore accepts zero players; that is legitimate and is tested. It is *not* an
excuse for an `isEnabled` flag on the composite: a player with `Sound` off is a `SynthesizedCuePlayer`
that never starts an engine (T04), not a composite with a hole in it.

### Isolation, and the two things that would break it

`Feedback` takes **no default isolation** in `Modules/Package.swift` — a cue vocabulary is data, and
that is the same reason `HunchNavigation` takes none (`08 §4`). Everything this task adds is a value:
`Cue`, its two row enums, `Channel`, `VoiceSpec`, `HapticPattern`, `CompositeCuePlayer`. The two
engine-owning classes arrive in T02 and T06 and write `@MainActor` explicitly (`05 R8`) even though
nothing else in the target is isolated.

Do not add an `actor` here and do not add a `CuePlayer.shared`. An actor around a cue vocabulary buys
an `await` at every call site for state that does not exist, and a singleton would make "previews are
silent by construction" impossible to state as a fact about the dependency graph (`08 §6`).

### The two spec-table value types, declared here and filled later

```swift
/// One synthesised voice. §13.8 owns every number that goes in it; this type owns none.
/// AD only — there is no sustain and no release field, and that is the enforcement, not a comment.
public struct VoiceSpec: Hashable, Sendable {
    public var frequency: Double          // Hz
    public var waveform: Waveform         // sine, triangle, square
    public var attack: Duration
    public var decay: Duration            // exponential to −60 dB over this
    public var peak: Double               // dBFS, negative
    public var bus: Bus                   // play, chrome, tick
    public var startOffset: Duration      // `correct`'s 90 ms ladder; zero for most rows
}

/// One Core Haptics pattern. §13.9 owns every number that goes in it.
public struct HapticPattern: Hashable, Sendable {
    public var events: [Event]            // transient and continuous, with their control curves
    public var offset: Duration           // twin's +60 ms; zero otherwise
}
```

Declare them; do **not** populate them. `Cue.voices` is T03 and `Cue.hapticPatterns` is T05, and each
of those tasks writes an exhaustive `switch` over its row enum. Leaving them unimplemented here is
deliberate: a table half-filled from memory is how a frequency ends up transcribed twice.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:FeedbackTests/CueVocabularyTests` green, all nine tests.
- [ ] `grep -c 'case ' Modules/Sources/Feedback/CueRows.swift` shows the two enums, and `Cue.AudioRow.allCases.count == 15` / `Cue.HapticRow.allCases.count == 11` are asserted by test, not by comment.
- [ ] `grep -rn 'Manager\|Service\|\.shared' Modules/Sources/Feedback/` returns nothing (`N26`, `04 A29`).
- [ ] `grep -rn 'actor \|@unchecked\|nonisolated(unsafe)' Modules/Sources/Feedback/` returns nothing — the one hatch arrives in T02 and not before.
- [ ] `grep -n 'defaultIsolation' Modules/Package.swift` shows `.defaultIsolation(MainActor.self)` on the UI targets and **not** on `Feedback`.
- [ ] `xcodebuild -scheme Hunch -showTestPlans` still lists three, and `Presubmission` now includes `FeedbackTests` (confirm the run reports a non-zero case count for it).
- [ ] `DECISIONS.md` carries the case-count ruling, and `.claude/skills/hunch-motion-and-feedback/references/feedback-target.md` §2's "Twelve cases" is corrected in the same commit.
- [ ] `tests.json` carries `feedback.cue-vocabulary` with `source: "§13.8, §13.9"` and the `-only-testing` command above.
- [ ] The fast suite is still under 10 s (this task adds nothing to it — `Feedback` is not in `HunchCore`).

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T01: the Feedback target completed — CompositeCuePlayer, representatives, and the two row vocabularies"`

## Out of scope

- `Cue`, `CuePlayer`, `SilentCuePlayer`, `RecordingCuePlayer` and `Round`'s firing sites — **E08·T06**, already shipped. Read them; do not rewrite them.
- `RevealCuePoint`, `RevealCueSchedule` and `RevealHapticSchedule` — **E09·T10**, already shipped in `LoomFeature`.
- `VoiceBank`, `SynthesizedCuePlayer` and the render block — **T02**.
- Every frequency, waveform, attack, decay, peak and bus — **T03**. Not one number is written here.
- Every event kind, time, intensity and sharpness — **T05**.
- Switching `AppDependencies.live()` from the silent player to the real composite — **T06**, once both engines exist.
- The `Sound`, `Level` and `Haptics` Settings rows and their `UserDefaults` keys — **E17·T06**.
