# T04 — Mode sigils, key states and gates

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Mode sigils, key states, gates |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**: this task draws. The sigil's stroke roles resolve through `env.weight(_:)` and its two inks are `stroke.secondary` / `stroke.primary` — the whole palette a sigil is allowed. The arc meter's fraction, the bar's ink and the disabled opacity are all tokens, and the resolution order (Bold Text ×1.25 *then* High Contrast +0.5) is this skill's. |
| `hunch-sigil-drawing` | Owns the construction grammar and the 22-mark catalogue. `references/mode-sigils.md` is §12.4's four clauses rendered — the drawings, what the sigil contributes inside each `KeyState` (almost nothing), the sites list `[22, 24, 44, 72]`, the VoiceOver table, and the explicit ban on restating §9.10's thresholds in the sigil layer. The harness `scripts/check-sigil-distinctness.js` is what proves a transcription is faithful. |
| `hunch-chrome-and-meta` | Owns `KeyState` — six cases, one home, `references/key.md` §3 — and the ruling that `barred` and `disabled` are different states that must not be merged. It also owns §5's gesture list, which is where the trailing-swipe discard is already written down. |
| `hunch-shared-marks` | The bar across a barred mode key is `MachinedBar.draw`, **the identical drawing** the barred Seal uses, and the suspended border is `ArcMeter.draw`. §12.4 says "identical" and then draws it again — `references/ownership.md` names that as the failure mode this skill exists to prevent. |

## Objective

At the end of this task each of the four rack keys draws its mode sigil in exactly three of
`KeyState`'s six cases — barred under the same machined bar the Seal wears, idle, and suspended with
its border replaced by an arc filled to `probesUsed / par` — and which key is barred is decided by
`ModeUnlock`, a pure function of archive evidence that reads no round count, no ability and no clock.
A trailing swipe on a suspended key discards the round, reusing the Bench's clear-a-rail gesture.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | **§9.10** | **the single source for mode unlocks**: DRIFT on a page at band ≥ 3, ECHO at ≥ 5 pages, SIEVE at ≥ 8 — plus the shipped inequality `unlockThreshold(.echo) >= minimumPoolSize + 2` and the three reasons the numbers are not arbitrary |
| `GAME_DESIGN.md` | §12.4 | the four sigil clauses and what each is built from; the three key states; *"This section renders them; it does not set them"*; the trailing-swipe discard reusing §4.2's rail-clear gesture; the decision that modes unlock on archive evidence and that the bar idiom carries the whole message with no text explaining it |
| `GAME_DESIGN.md` | §4.3 | the machined bar on the Seal — the drawing §12.4 calls identical |
| `GAME_DESIGN.md` | §7.2, §9.3, §10.3 | the other end of the same guarantee: DRIFT's served band clamps to 3–8 and SIEVE's to 1–6, so no unlocked mode can be asked for a law it cannot produce |
| `GAME_DESIGN.md` | §8.2 | ECHO's pool has a functional floor of 3 members, which is what the `≥ minimumPoolSize + 2` inequality is about |
| `GAME_DESIGN.md` | §11.1, §11.2 | what a `CodexPage` records and what `codex-index.json` holds — the evidence `ModeUnlock` reads |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §3 | `ModeUnlock` is a pure function of values and therefore core; `Mode` is a `UInt8`-backed enum rendered `Text(verbatim: mode.wordmark)` |

**Never restate the three thresholds outside `ModeUnlock`.** §9.10 says so in its own words —
*"No other section states a threshold; every other section that mentions one cross-references here"* —
and `mode-sigils.md` repeats the ban for the drawing layer.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/ArchiveTests/ModeUnlockTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import Archive
import HunchTestSupport

@Suite("Mode gates are archive evidence and nothing else — §9.10", .tags(.unit, .presubmission))
struct ModeUnlockTests {

    // MARK: - The three gates

    @Test("PROBE is ungated at first launch")
    func probeIsAlwaysUnlocked() {
        #expect(ModeUnlock.unlocked(from: .empty).contains(.probe))
        #expect(ModeUnlock.unlocked(from: .empty) == [.probe])
    }

    @Test("DRIFT unlocks on the first page at band ≥ 3, and not on pages below it")
    func driftGate() {
        for band in Band.allCases where band.rawValue < 3 {
            let evidence = ArchiveEvidence(pageCount: 40, highestBandWithAPage: band)
            #expect(!ModeUnlock.unlocked(from: evidence).contains(.drift),
                    "band \(band.rawValue) must not unlock DRIFT even at 40 pages")
        }
        for band in Band.allCases where band.rawValue >= 3 {
            let evidence = ArchiveEvidence(pageCount: 1, highestBandWithAPage: band)
            #expect(ModeUnlock.unlocked(from: evidence).contains(.drift),
                    "one band-\(band.rawValue) page must unlock DRIFT")
        }
    }

    @Test("ECHO unlocks at exactly 5 pages", arguments: 0...10)
    func echoGate(_ pages: Int) {
        let evidence = ArchiveEvidence(pageCount: pages, highestBandWithAPage: .literal)
        #expect(ModeUnlock.unlocked(from: evidence).contains(.echo) == (pages >= 5))
    }

    @Test("SIEVE unlocks at exactly 8 pages", arguments: 0...12)
    func sieveGate(_ pages: Int) {
        let evidence = ArchiveEvidence(pageCount: pages, highestBandWithAPage: .literal)
        #expect(ModeUnlock.unlocked(from: evidence).contains(.sieve) == (pages >= 8))
    }

    @Test("§9.10's shipped inequality: ECHO's threshold clears the pool floor plus two")
    func echoThresholdClearsThePoolFloor() {
        #expect(ModeUnlock.threshold(for: .echo).pages >= EchoPool.minimumPoolSize + 2)
        // …and 5 is the *smallest* number satisfying it, which is why the constant is 5 and not 6.
        #expect(ModeUnlock.threshold(for: .echo).pages == EchoPool.minimumPoolSize + 2)
    }

    @Test("a gate is monotone: evidence can only ever add modes, never remove them")
    func gatesAreMonotoneInEvidence() {
        var previous: Set<Mode> = []
        for pages in 0...12 {
            let unlocked = ModeUnlock.unlocked(from: .init(pageCount: pages, highestBandWithAPage: .exclusive))
            #expect(previous.isSubset(of: unlocked), "unlocks went backwards at \(pages) pages")
            previous = unlocked
        }
    }

    // MARK: - What a gate may NOT read

    @Test("evidence carries only archive facts — no rounds, no ability, no serving state, no clock")
    func evidenceIsArchiveOnly() {
        // A compile-time assertion in test form: these are the ONLY stored properties.
        let mirror = Mirror(reflecting: ArchiveEvidence(pageCount: 0, highestBandWithAPage: nil))
        #expect(Set(mirror.children.compactMap(\.label)) == ["pageCount", "highestBandWithAPage"])
    }

    @Test("two evidences with the same archive facts unlock identically, whatever else changed")
    func gatesArePureOverEvidence() {
        let a = ArchiveEvidence(pageCount: 7, highestBandWithAPage: .relational)
        let b = ArchiveEvidence(pageCount: 7, highestBandWithAPage: .relational)
        #expect(ModeUnlock.unlocked(from: a) == ModeUnlock.unlocked(from: b))
    }

    // MARK: - The Clear Codex consequence (T08 wires it; the rule is here)

    @Test("emptying the archive re-locks DRIFT, ECHO and SIEVE and leaves PROBE")
    func clearingTheArchiveRelocks() {
        #expect(ModeUnlock.unlocked(from: .init(pageCount: 40, highestBandWithAPage: .systemic)) == Set(Mode.allCases))
        #expect(ModeUnlock.unlocked(from: .empty) == [.probe])
    }
}
```

And `Modules/Tests/MetaFeatureTests/ModeKeyStateTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("The rack key's three states — §12.4, key.md §3", .tags(.unit, .presubmission))
struct ModeKeyStateTests {

    @Test("a locked mode is BARRED, never disabled — key.md §3")
    func lockedIsBarred() {
        let model = FrameModel(unlocked: [.probe], hasStreak: false, anomaly: .playable,
                               suspended: [:], runNotches: 0)
        #expect(model.keyState(for: .drift) == .barred)
        #expect(model.keyState(for: .probe) == .idle)
    }

    @Test("a suspended round makes the key .suspended(probesUsed / par), clamped to 0…1")
    func suspendedCarriesItsFraction() {
        let model = FrameModel(unlocked: Set(Mode.allCases), hasStreak: false, anomaly: .playable,
                               suspended: [.probe: .init(probesUsed: 5, par: 20)], runNotches: 0)
        #expect(model.keyState(for: .probe) == .suspended(0.25))
    }

    @Test("past par the fraction clamps at 1 rather than overflowing the arc")
    func fractionClamps() {
        let model = FrameModel(unlocked: Set(Mode.allCases), hasStreak: false, anomaly: .playable,
                               suspended: [.probe: .init(probesUsed: 31, par: 20)], runNotches: 0)
        #expect(model.keyState(for: .probe) == .suspended(1.0))
    }

    @Test("a barred mode cannot also be suspended — the state is a single enum, not a bag of Bools")
    func barredBeatsSuspended() {
        let model = FrameModel(unlocked: [.probe], hasStreak: false, anomaly: .playable,
                               suspended: [.drift: .init(probesUsed: 3, par: 25)], runNotches: 0)
        #expect(model.keyState(for: .drift) == .barred)
    }

    @Test("tapping a suspended key resumes; a trailing swipe discards; there is no tap route to discard")
    func gestureInventory() {
        let key = ModeKeyBehaviour(state: .suspended(0.5))
        #expect(key.tap == .resume)
        #expect(key.trailingSwipe == .discard)
        #expect(key.actions == [.resume, .discard])          // exactly two, no long-press, no double-tap
    }

    @Test("an idle key has one action and a barred key has none that changes state")
    func gestureInventoryForOtherStates() {
        #expect(ModeKeyBehaviour(state: .idle).actions == [.start])
        #expect(ModeKeyBehaviour(state: .barred).actions == [])
        #expect(ModeKeyBehaviour(state: .barred).tap == .none)   // pressing does nothing and says nothing
    }
}
```

And `Modules/Tests/HunchUITests/ModeSigilParityTests.swift` — the transcription guard:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport

@Suite("The four mode sigils match the harness catalogue", .tags(.unit, .presubmission))
struct ModeSigilParityTests {

    @Test("every mode has a sigil and the four keys are the harness's",
          arguments: Mode.allCases)
    func everyModeHasASigil(_ mode: Mode) {
        let sigil = Sigil(mode)
        #expect(Sigil.allCases.contains(sigil))
        #expect(sigil.rawValue == "mode.\(mode.wordmark.lowercased())")
    }

    @Test("the Swift transcription is point-for-point identical to SIGILS", arguments: Mode.allCases)
    func transcriptionMatchesTheFixture(_ mode: Mode) throws {
        let fixture = try SigilFixture.load()                    // the committed `--json` dump
        let strokes = SigilCatalogue.strokes(for: Sigil(mode))
        #expect(strokes == fixture[Sigil(mode).rawValue])
    }

    @Test("the sigil's drawing is identical in every key state — only its ink changes",
          arguments: Mode.allCases)
    func geometryIsStateInvariant(_ mode: Mode) {
        let idle = SigilCatalogue.strokes(for: Sigil(mode))
        for state in [KeyState.idle, .pressed, .selected, .barred, .disabled, .suspended(0.4)] {
            #expect(SigilCatalogue.strokes(for: Sigil(mode)) == idle, "\(state) changed the geometry")
        }
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter ModeUnlockTests` and
`swift test --package-path Modules --filter "ModeKeyStateTests|ModeSigilParityTests"`

Failures must be missing symbols — `ModeUnlock`, `ArchiveEvidence`, `ModeKeyBehaviour`,
`Sigil(_ mode:)` — or a threshold that is wrong. `echoThresholdClearsThePoolFloor` failing with
"5 != 5" means `EchoPool.minimumPoolSize` is not what §8.2 says; fix that, not the test.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/ModeUnlock.swift` |
| modify | `HunchCore/Sources/Sigils/Sigil.swift` — add the four `mode.*` cases **only if absent** (see the precondition grep below) |
| modify | `Modules/Sources/MetaFeature/FrameModel.swift` — `keyState(for:)` and `ModeKeyBehaviour` |
| create | `Modules/Sources/MetaFeature/ModeRackKey.swift` |
| modify | `Modules/Sources/HunchUI/Sigils/SigilRenderer.swift` — nothing new if E15·T09 shipped it; extend only if the four mode cases are new |
| create | `HunchCore/Tests/ArchiveTests/ModeUnlockTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/ModeKeyStateTests.swift` |
| create | `Modules/Tests/HunchUITests/ModeSigilParityTests.swift` |
| modify | `SPEC.md` — add §9.10's triple to the locked-constants table if E01·T08 did not |
| modify | `tests.json` — four entries: the three gates, the ECHO pool-floor inequality, gate monotonicity, and the suspended arc fraction |

## Implementation notes

### Precondition: the four mode sigils may already be transcribed

E15·T05's Codex page instrument strip draws a mode sigil, and E15·T08's facet bar cycles all four.
Run this **before** writing any Swift:

```bash
grep -rn "modeProbe\|mode\.probe" HunchCore/Sources/Sigils/Sigil.swift
node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js --keys | tr ' ' '\n' | grep '^mode\.'
```

If the four cases are present, **do not redraw them** — `hunch-sigil-drawing/SKILL.md`'s first rule
is that one drawing serves every site, scaled, and the sites list is already `[22, 24, 44, 72]` with
72 being this key. This task then adds only the parity test at the 72 pt site and the key states. If
they are absent, transcribe them from `SIGILS`, regenerate the fixture with `--json`, and follow the
four-artefact write-back contract in `references/drawing-a-new-sigil.md` §5.

`mode.probe`'s proportions come from `design/mockup-phosphor.html` → `modeSigil()` verbatim, so the
mockup and the app cannot diverge. Do not "clean it up".

### `ModeUnlock` — a pure function of two facts

```swift
// HunchCore/Sources/Archive/ModeUnlock.swift

/// Everything a gate is allowed to know. Two stored properties, and `evidenceIsArchiveOnly`
/// asserts there is no third — a gate that could see `roundsPlayed` would be a round-count gate
/// wearing an archive costume, which is exactly what §12.4's decision rules out.
public struct ArchiveEvidence: Hashable, Sendable {
    public let pageCount: Int
    public let highestBandWithAPage: Band?
    public init(pageCount: Int, highestBandWithAPage: Band?)
    public static let empty = ArchiveEvidence(pageCount: 0, highestBandWithAPage: nil)
}

public enum ModeUnlock {
    public struct Threshold: Hashable, Sendable {
        public let pages: Int
        public let minimumBand: Band?
    }

    /// §9.10 is the single source. These three values appear **nowhere else** in the codebase, and
    /// `SPEC.md`'s locked-constants table carries the triple.
    public static func threshold(for mode: Mode) -> Threshold {
        switch mode {
        case .probe: Threshold(pages: 0, minimumBand: nil)
        case .drift: Threshold(pages: 1, minimumBand: .exclusive)   // band 3
        case .echo:  Threshold(pages: 5, minimumBand: nil)
        case .sieve: Threshold(pages: 8, minimumBand: nil)
        }
    }

    public static func unlocked(from evidence: ArchiveEvidence) -> Set<Mode> { … }
}
```

`.exclusive` is `Band`'s band-3 case (E05·T06's collapsed `Band`/`Family` type), so the gate reads as
"a page whose band is at least band 3" without a bare `3` anywhere.

**No `default:`** in `threshold(for:)` — adding a fifth mode must be a compile error here (`W29`).

**Where the evidence comes from.** `codex-index.json` is the launch-time dedup authority and holds
per-band counts (§11.13), so `pageCount` and `highestBandWithAPage` are both answerable **without
opening a single shelf file** — which is what keeps the Frame's launch cost at one file and preserves
E15·T01's one-file-per-shelf-open assertion. `Codex` (E15·T01) exposes them; `FrameModel` asks
`Codex`, never the shelves.

### Why the gate must be monotone, and what breaks if it is not

`gatesAreMonotoneInEvidence` looks like a triviality and is not. §11.3 never mints a second page for
a duplicate, so `pageCount` is monotone under play — but it is *not* monotone under Settings, because
"Clear Codex" empties it. The property that must hold is monotonicity **in the evidence**, not in
time: more pages never means fewer modes. That is what makes T08's re-lock correct rather than a
special case — Clear Codex does not "re-lock ECHO and SIEVE" as an action; it writes an empty index
and the gate, being a function, simply answers differently. If `ModeUnlock` ever caches, latches or
takes a `hasEverUnlocked` argument, that stops being true and T08 grows a second code path.

### The three key states, and the two the rack never uses

`KeyState` has six cases and one home (`key.md` §3). A mode rack key uses three:

| §12.4's state | `KeyState` | Who draws it |
|---|---|---|
| Barred | `.barred` | `MachinedBar.draw` — **the identical drawing the Seal wears** (§4.3, §12.4). Called, never copied |
| Idle | `.idle` | the key's own border at `env.weight(.thin)` in `stroke.secondary` (`key.md` §2) |
| Suspended round | `.suspended(probesUsed / par)` | `ArcMeter.draw` in its continuous linear variant, **replacing** the border rather than sitting inside it (`key.md` §3) |

`.pressed` and `.selected` arrive from the `Key` component's own interaction and are not modelled by
`FrameModel`; `.disabled` is never used on the rack — **`barred` and `disabled` are different states
and must not be merged** (`key.md` §3, §10). Barred is a machine refusing with a reason; disabled is
a control that does not apply. The mode key always applies.

The associated `Double` is clamped to `0...1` **inside** `KeyState`, so a suspended key cannot exist
without a valid progress and `fractionClamps` is asserting the type's own guarantee rather than a
call site's discipline.

### The trailing swipe, and why it has no tap route

§12.4: *"To discard and start fresh, swipe the key toward the trailing edge — the same gesture that
clears a rail on the Bench (§4.2). Reuse over invention."* `key.md` §5 adds the ruling that this is
**the only gesture on any key**, and that it deliberately has no tap route: discarding is rare and
destructive, and tapping resumes.

Two consequences:

1. The swipe is `.onEnded` on a `DragGesture` with a trailing-direction predicate that mirrors under
   RTL — `leading`/`trailing`, never `left`/`right` (§12.8). Reuse the Bench's rail-clear
   recogniser rather than writing a second one; if it is not yet factored out of `BenchView`
   (E09·T02), factor it now into `HunchUI` and have both call it.
2. VoiceOver cannot perform a swipe, so the discard is an `.accessibilityAction(named:)` on the key.
   That is `hunch-accessibility/references/rotors-and-gestures.md` §6's rule and it is why the
   declaration UI has no drag, pinch, long-press or double-tap anywhere (§4.2, §12.8) — this is the
   one gesture in the app that needs the custom-action escape hatch, and it gets it here.

### The barred key says nothing about why — in audio too

`mode-sigils.md`'s VoiceOver table: a barred rack key is `.button` + `.notEnabled` with the mode
wordmark as its label and **no hint, no announcement, no "unlock by…"**. §12.4: *"The bar idiom
carries the whole message; there is no text explaining it."* Adding a hint would make the wordless
design a lie told only to sighted players.

The four names are wordmarks, not translation units (§12.9), so they ship untranslated in all twelve
locales and cost no catalogue key — `Text(verbatim: mode.wordmark)` is the only correct spelling
(`08 §3`).

`accessibilityRespondsToUserInteraction(true)` on a barred key: the `Key` component already sets it
(`key.md` §4), so a barred mode key stays *discoverable* while refusing, the same way the barred Seal
does (§12.8).

### The other end of the guarantee

§12.4's second decision explains why DRIFT's gate is a band and not a count, and names the matching
constraint on the serving side: DRIFT's served band clamps to 3–8 and SIEVE's to 1–6 after §10.3's
quantisation, *"so no unlocked mode can ever be asked for a law it cannot produce"*. Those clamps are
**E11·T03**'s and are already shipped. This task does not re-implement them; it adds one cross-check
to `tests.json` naming both ends, so a future edit to either is visibly one half of a pair.

### High Contrast, Bold Text, Differentiate Without Colour, Reduce Motion

All four are already answered by `mode-sigils.md` and `key.md`, and this task must not re-answer
them:

- **No sigil animates, ever.** The only movement near one is the key's — the suspended arc filling
  and the reveal's beat-0 bar retraction — and both belong to `hunch-motion-and-feedback`. §13.7.4
  needs no new row.
- **Differentiate Without Colour changes nothing on a key**, because no key state is encoded by
  colour: `barred` reads as a bar, `suspended` as an arc, `idle` as neither.
- **High Contrast** applies the flat `+0.5` after Bold Text's `×1.25`; no `hue.*` substitution
  applies because a sigil has none.
- **Bold Text** reaches the sigil only through `env.weight(_:)`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ModeUnlockTests` green, all nine tests.
- [ ] `swift test --package-path Modules --filter "ModeKeyStateTests|ModeSigilParityTests"` green.
- [ ] `grep -rn "\b5\b.*pages\|pageCount >= 5\|>= 8" --include=*.swift HunchCore/Sources Modules/Sources | grep -v ModeUnlock.swift` returns nothing — the three thresholds have exactly one home.
- [ ] `grep -rn "roundsPlayed\|Ability\|ServingState\|Date\|Now" HunchCore/Sources/Archive/ModeUnlock.swift` returns nothing.
- [ ] `grep -rn "default:" HunchCore/Sources/Archive/ModeUnlock.swift` returns nothing.
- [ ] `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` exits 0, with the four `mode.*` keys each claimed by exactly one catalogue section.
- [ ] `grep -rn "MachinedBar\|ArcMeter" Modules/Sources/MetaFeature/ModeRackKey.swift` shows calls into `HunchUI/Marks/`, and `hunch-shared-marks`' second-declaration grep is clean.
- [ ] `grep -rn "accessibilityHint" Modules/Sources/MetaFeature/ModeRackKey.swift` returns nothing on the barred path.
- [ ] Simulator walk recorded in the commit message: an empty Codex shows three barred keys; a single band-3 page unbars DRIFT and nothing else; a fifth page unbars ECHO; an eighth unbars SIEVE; a suspended PROBE round draws its arc and a trailing swipe clears it.
- [ ] `SPEC.md` carries §9.10's triple in its locked-constants table.
- [ ] `tests.json` carries the four entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T04: mode sigils on the rack key in three states; ModeUnlock as a pure function of archive evidence"`

## Out of scope

- The rack's *placement* and the Frame's two invariants — **T03**.
- Wiring "Clear Codex" so the archive actually empties — **T08**. This task ships the function that answers differently once it has.
- DRIFT's 3–8 and SIEVE's 1–6 served-band clamps — **E11·T03**.
- The eight family sigils, the five Profile vertex sigils and the five facet stamps — **E15·T09**, **E16·T09**, **E15·T08**.
- The `Key` component itself, `KeyState`, `MachinedBar` and `ArcMeter` — **E04·T07/T08** and the chrome skill; this task composes them.
- The barred Seal, which wears the same bar — **E09·T07**.
- Every VoiceOver label's exact wording — **E19·T01**.
