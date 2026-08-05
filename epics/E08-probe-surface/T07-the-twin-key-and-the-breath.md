# T07 — The twin key and the breath

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P2 (the breath) over a P0 spine (the twin key) |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | §14.1 PROBE → *The twin key* (P0) · §14.1 PROBE → *The breath* (P2) |
| **Status** | not started |

> The row split is deliberate: §14.1 prices *the twin key* P0 and *the breath* P2. Build the key
> first and commit it; the breath is the droppable half and must be removable without touching the
> key. Do not merge the two into one property.

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The breath's period, pulse length and static-lift opacity are L2 `C.TwinKey` members; the 0.6·par threshold is **not** a token at all — it is `HunchCore`'s scoring constant and must be cited, not re-typed. Load it first. |
| `hunch-bench-instruments` | The commit bar and its three keys are this skill's surface, and §12.8 tier 1 ("the thing that ends a decision is always in the same place under the same thumb") is why the twin key's position is fixed rather than convenient. |
| `hunch-motion-and-feedback` | The twin's verdict response is the ordinary one at **0.7 × amplitude** plus the doubled ribbon ring — a twin must not read as a fresh discovery — and the breath needs its Reduce Motion row written at the same time as the animation, not after. |

## Objective

The twin key re-probes the glyph currently in the throat, unchanged, costing one probe, never blocked and never refunded; probe 1 therefore defaults to a twin-of-seed at one tap. Past 0.6·par, if the key has never been pressed this round, it breathes on the same rule in every band and stops permanently on first use.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.1 | The twin as the third mitigation; "no repeat guard" — re-probing is not blocked or refunded, because under previous-probed semantics the twin is the most informative probe in the game |
| `GAME_DESIGN.md` | §6.3 | The twin key costs one probe and re-feeds the throat glyph unchanged; the probe-1-defaults-to-a-twin-of-seed decision and its three reasons |
| `GAME_DESIGN.md` | §6.6 layer 3 and its decision | The twin key from round 1 of band 1; four bands of agreeing with itself; **the breath** — its trigger, its 1.2 s pulse every 8 s, no arrow / badge / modal / text, the same rule in every band, stopping permanently on first use, and the Reduce Motion substitution |
| `GAME_DESIGN.md` | §6.11 cases 2 and 3 | Twin at probe 0 is legal and probes the seed glyph; a twin is an *adjacent* re-probe only |
| `GAME_DESIGN.md` | §13.7.2 | The twin micro-response at 0.7 × amplitude |
| `GAME_DESIGN.md` | §13.10 | The twin key's traits, label and value |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/TwinKeyTests.swift`:

```swift
import Testing
import HunchCore
import Feedback
import ModulesTestSupport
import LoomFeature

@Suite("The twin key", .tags(.unit, .presubmission))
@MainActor
struct TwinKeyTests {

    @Test("Twin re-feeds the throat glyph unchanged and costs exactly one probe")
    func twinRefeedsTheDraft() {
        let round = Fixtures.round()
        round.select(.hue, rank: 4)
        let draft = round.draft

        round.probe(draft)
        round.landVerdict(); round.endVerdictBeat()
        round.probeTwin()

        #expect(round.probesUsed == 2)
        #expect(round.ribbon.probes[1].glyph == draft)
        #expect(round.draft == draft)                  // unchanged: the twin does not edit
        #expect(round.ribbon.probes[1].isTwin)
    }

    @Test("Twin at probe 0 probes the seed glyph and is not marked as a twin — §6.11 case 2")
    func twinAtProbeZero() {
        let round = Fixtures.round()
        round.probeTwin()
        #expect(round.probesUsed == 1)
        #expect(round.ribbon.probes[0].glyph == Fixtures.seedGlyph)
        #expect(round.ribbon.probes[0].isTwin == false)   // no adjacent *probe* to be a twin of
    }

    @Test("Twin is never blocked and never refunded — there is no repeat guard")
    func noRepeatGuard() {
        let round = Fixtures.round()
        for expected in 1...5 {
            round.probeTwin()
            #expect(round.probesUsed == expected)
            round.landVerdict(); round.endVerdictBeat()
        }
        #expect(round.isTwinAvailable)                    // still live after five in a row
    }

    @Test("The twin key is available in every band, from probe 0", arguments: Band.allCases)
    func availableEverywhere(_ band: Band) {
        let round = Fixtures.round(band: band)
        #expect(round.isTwinAvailable)
    }

    @Test("A twin shares the single input slot with the PROBE key")
    func twinUsesTheSameQueue() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)                   // locks
        round.probeTwin()                                 // queued
        round.probeTwin()                                 // dropped
        round.landVerdict(); round.endVerdictBeat()
        #expect(round.probesUsed == 2)
    }
}

@Suite("The breath", .tags(.unit, .presubmission))
@MainActor
struct BreathTests {

    @Test("It fires past 0.6·par on the same rule in every band", arguments: Band.allCases)
    func sameRuleEveryBand(_ band: Band) {
        let round = Fixtures.round(band: band)
        let threshold = Int((Score.threeMarkFraction * Double(band.par(for: .probe))).rounded(.down))

        while round.probesUsed < threshold {
            round.probe(Deck.glyph(id: UInt8(round.probesUsed % 256)))
            round.landVerdict(); round.endVerdictBeat()
            #expect(round.isBreathing == false)
        }
        round.probe(Deck.glyph(id: 9))
        round.landVerdict(); round.endVerdictBeat()
        #expect(round.isBreathing)
    }

    @Test("It stops permanently on first use, and does not come back")
    func stopsForever() {
        let round = Fixtures.round(band: .literal)
        while round.isBreathing == false && round.probesUsed < round.band.cap(for: .probe) - 2 {
            round.probe(Deck.glyph(id: 3)); round.landVerdict(); round.endVerdictBeat()
        }
        #expect(round.isBreathing)

        round.probeTwin(); round.landVerdict(); round.endVerdictBeat()
        #expect(round.isBreathing == false)

        round.probe(Deck.glyph(id: 3)); round.landVerdict(); round.endVerdictBeat()
        #expect(round.isBreathing == false)               // permanently, not until the next probe
    }

    @Test("A twin pressed early means it never breathes at all")
    func earlyUseSuppressesIt() {
        let round = Fixtures.round(band: .systemic)
        round.probeTwin(); round.landVerdict(); round.endVerdictBeat()
        while round.probesUsed < round.band.par(for: .probe) {
            round.probe(Deck.glyph(id: 5)); round.landVerdict(); round.endVerdictBeat()
            #expect(round.isBreathing == false)
        }
    }

    @Test("Under Reduce Motion it is a static opacity lift, not a pulse")
    func reduceMotionSubstitution() {
        #expect(BreathPresentation(reduceMotion: false) == .pulse)
        #expect(BreathPresentation(reduceMotion: true) == .staticLift)
    }

    @Test("The breath is a function of (probesUsed, par, everUsed) and of nothing else")
    func itCannotLeakTheFamily() {
        // Identical (probesUsed, par) at different bands must give the identical answer, or the
        // breath becomes a contextuality tell — §6.6's decision.
        let a = Round.breathes(probesUsed: 14, par: 23, twinEverUsed: false)
        let b = Round.breathes(probesUsed: 14, par: 23, twinEverUsed: false)
        #expect(a == b)
        #expect(Round.breathes(probesUsed: 14, par: 23, twinEverUsed: true) == false)
        #expect(Round.breathes(probesUsed: 13, par: 23, twinEverUsed: false) == false)
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:LoomFeatureTests/TwinKeyTests -only-testing:LoomFeatureTests/BreathTests
```

Expect `value of type 'Round' has no member 'probeTwin'`. If `Score.threeMarkFraction` does not exist, that is the right kind of failure too — see the notes.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/LoomFeature/Round.swift` |
| modify | `Modules/Sources/LoomFeature/CommitKey.swift` |
| create | `Modules/Sources/LoomFeature/BreathPresentation.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` |
| modify | `HunchCore/Sources/Rounds/Score.swift` (only if `threeMarkFraction` is not already named) |
| create | `Modules/Tests/LoomFeatureTests/TwinKeyTests.swift` |
| modify | `DECISIONS.md` |

## Implementation notes

**`probeTwin()` is one line of policy over `probe(_:)`** — it re-feeds `draft` — and the whole of its
design is in what it does *not* do:

```swift
/// §6.3: one probe, re-feeds the glyph currently in the throat, unchanged.
/// Never blocked and never refunded (§4.1's "no repeat guard"): under previous-probed semantics
/// the twin is the most informative probe in the game, so a guard against it would be a bug.
public func probeTwin() {
    twinEverUsed = true          // latched here, on the *press*, not on the verdict
    probe(draft)
}
```

Three consequences to get right:

1. **`isTwin` is decided by adjacency in `probe(_:)`, not by which key was pressed.** At probe 0 there is no previous *probe*, so a twin-of-seed is not marked as a twin pair — the seed tile is not a probe and never gains a verdict ring (§6.11 case 2). Record that ruling in `DECISIONS.md`; it is the one place §6.3's phrase "probe 1 defaults to a twin-of-seed" and §6.11's "the seed glyph itself never gains a verdict ring" have to be reconciled, and they reconcile cleanly: the *default action* is a twin of the seed; the *ribbon marking* needs two adjacent probes.
2. **`twinEverUsed` latches on the press**, so a player who presses twin and immediately backgrounds the app does not get the breath back on resume.
3. **No refund, no cooldown, no cap exemption.** The twin costs one probe like anything else. If E09's Bench or E10's snapshot ever needs to know a twin happened, it reads `Probe.isTwin`, which E07·T08 already stores.

**The breath — a predicate, not a timer.**

```swift
/// §6.6's decision. Same rule in **every** band, so it cannot leak contextuality: at bands 1–4 it
/// costs one mildly wasted probe, which is itself the lesson of §6.6 layer 3.
static func breathes(probesUsed: Int, par: Int, twinEverUsed: Bool) -> Bool {
    !twinEverUsed && Double(probesUsed) > Score.threeMarkFraction * Double(par)
}

public var isBreathing: Bool {
    Self.breathes(probesUsed: probesUsed, par: band.par(for: .probe), twinEverUsed: twinEverUsed)
}
```

**The 0.6 is not this task's number.** It is the same fraction §6.9's three-mark threshold uses, and
E06·T07 owns it. Cite it: if `Score` did not name it, add `public static let threeMarkFraction = 0.6`
**there**, beside the mark computation, in one commit, and use it in both places. Writing `0.6` in
`LoomFeature` creates a second home for a locked constant and is exactly what §5.7 exists to prevent.

**The animation, and its substitution written at the same time.** A 1.2 s hairline pulse every 8 s —
no arrow, no badge, no modal, no text. Under Reduce Motion it is a static 30 % opacity lift instead
of a pulse. Both live in `C.TwinKey` as L2 `Duration` and opacity members; `BreathPresentation` is
the two-case enum the view switches on, so the substitution is a value, not an `if` scattered through
a body. The key never grows a second affordance: §6.6 is explicit that the breath is *only* an
opacity/hairline event, and `hunch-bench-instruments`' standing rule — a barred or hinting control
never gains text — applies here even though nothing is barred.

**The key itself.** `CommitKey` (created in T06) is the commit bar's key drawing; the twin key is one
instance of it. §12.8 tier 1 fixes all three keys in the commit bar at y 604–667, and §12.6's
Left-hand keys setting mirrors *only* the commit bar's order — which is why T02 built the bar with
three named slots rather than three children. The twin key's VoiceOver value is the **last-probed
glyph label**, not the draft's, per §13.10; the two differ the moment the player edits after probing.

**The twin's verdict response** is the ordinary admit/reject animation at 0.7 × amplitude, plus the
ribbon's doubled ring, which T05 already draws. Audio is the verdict cue with `isTwin: true` — one
`Cue` case, resolved per medium by the player, exactly as `feedback-target.md` §2 designs it. A twin
must not read as a fresh discovery.

## Acceptance criteria

- [ ] `TwinKeyTests` (5 cases) and `BreathTests` (5 cases) green on both destinations.
- [ ] `grep -rn '0\.6' Modules/Sources` returns nothing; `grep -n 'threeMarkFraction' HunchCore/Sources/Rounds/Score.swift Modules/Sources/LoomFeature/Round.swift` shows one declaration and its uses.
- [ ] `grep -rn 'band' Modules/Sources/LoomFeature/BreathPresentation.swift` returns nothing — the breath cannot see a band.
- [ ] Deleting `isBreathing`, `BreathPresentation` and the key's breath modifier leaves the twin key fully working and the suite green apart from `BreathTests` — verified once, by actually doing it on a scratch branch, because that is what "P2 is individually droppable" means.
- [ ] `bash Scripts/check-source-hygiene.sh` passes checks 7, 9 and 10.
- [ ] `DECISIONS.md` records the probe-0 twin ruling (`isTwin == false`, no verdict ring on the seed) and the latch-on-press choice.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; both new filters green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T07: the twin key, and the breath on one band-independent rule"`

## Out of scope

- ECHO's replay, which reuses the twin key at ×0.6 score — **E13·T06**. The key is designed to be reusable; the replay is not built here.
- The five nudges (idle, no-Bench, barred-Seal, global idle, unvaried) — **E10·T08**. The breath is not one of them: it is a §6.6 discoverability layer, it fires on a probe-count rule rather than an idle timer, and it must not be folded into the nudge vocabulary.
- Suppression under VoiceOver. Nudges are suppressed entirely (E10·T08); the breath's behaviour under VoiceOver is E19·T05's ruling, not this task's — do not pre-empt it.
- The twin's ×0.7 audio and haptic parameters — **E20·T03, E20·T05**. Fire `Cue.verdict(_:isTwin: true)`; the player resolves the amplitude.
- The doubled and split ribbon rings — **T05**.
