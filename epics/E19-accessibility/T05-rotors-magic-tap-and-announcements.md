# T05 — Rotors, Magic Tap, escape and announcements

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Rotors, Magic Tap, announcements (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | Owns every line of this task. `references/rotors-and-gestures.md` gives the four rotors and the swipe count each one buys, the conditional `CounterexampleRotor` that gate 6 requires, the two Magic Tap sites and why a `isBenchPresented` branch fails on device, the two escape sites and why `RoundView` is not one of them, and the complete custom-action list. `references/voiceover-elements.md` §11 owns the announcement table, the fixed order, and the single `Announcer` outside the six play-surface files. |

## Objective

At the end of this task a VoiceOver player declares canon's band-5 law in **sixteen gestures instead
of twenty-two**: four custom rotors, a Magic Tap that fires the thing the player came to do, and a
two-finger scrub that closes what is open. Every verdict, strike, reveal and bookkeeping event is
announced at the right priority in the fixed order verdict → evidence → bookkeeping, and the reveal
posts exactly three announcements at 640, 1,450 and 1,850 ms with tap-to-skip disabled.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.10 (Rotors, Magic Tap, escape) | the four rotors and their stops; Counterexample exists only after a strike and has two stops; Magic Tap = Probe on the Dial, Seal on the Bench; escape closes the Bench or the expanded Assay; `.headings` on Codex, Profile, Settings |
| `GAME_DESIGN.md` | §13.10 (Announcements) | priority `.high` on verdicts so they interrupt; the fixed order **verdict → evidence → bookkeeping**; the eleven-row announcement table verbatim |
| `GAME_DESIGN.md` | §6.8 (VoiceOver paragraph) | three announcements at **640** (the verdict), **1,450** (beat 4, the law lands) and **1,850** (beat 6, the page and its marks); tap-to-skip disabled because it collides with tap-to-focus; VO players skip with the Magic Tap |
| `GAME_DESIGN.md` | §6.11 row 26 | the same three offsets, restated as an edge case |
| `GAME_DESIGN.md` | §12.6 (VOICEOVER · Announce verdicts) | on by default; gates the admit / reject / twin rows **and nothing else** |
| `GAME_DESIGN.md` | §12.8 | the rotor set is fixed at four and there is no fifth |
| `GAME_DESIGN.md` | §4.2, §12.7 | no drag, pinch, long-press or double-tap-meaning-something-else in the declaration UI — the constraint that makes the sixteen-gesture walkthrough possible; SIEVE's exit is confirm-by-repeat and is not an escape |
| `.claude/skills/hunch-accessibility/references/rotors-and-gestures.md` | §1–§8 | rotor construction, `prepare:`, Magic Tap resolution, escape, the custom-action list, the walkthrough |

## TDD — the test comes first

Rotors, Magic Tap and escape cannot be driven from XCUITest — VoiceOver's own gestures cannot be
synthesised and custom actions are not exposed on `XCUIElement`, which is why §13.12 gates 5 and 6 are
manual. What **is** testable is the value layer: the set of rotors, their stops and their order; the
announcement text, priority and ordering; and the reveal schedule. Model those as values, render them
in the view, and the manual gate is then only checking that the gesture reaches the value.

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/RotorTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI
@testable import LoomFeature

@Suite("The four rotors — §13.10, §12.8", .tags(.unit, .presubmission))
struct RotorTests {

    private let loc = Loc.english

    @Test("there are four rotors and there is no fifth")
    func exactlyFourKinds() {
        #expect(RotorKind.allCases.count == 4)
        #expect(Set(RotorKind.allCases) == [.rails, .attributes, .probes, .counterexample])
    }

    @Test("Counterexample is ABSENT before the first strike — §13.12 gate 6")
    func counterexampleAbsentBeforeAStrike() {
        let round = Round.preview(phase: .probing, strikes: 0)
        #expect(!LoomRotors.specs(for: round).contains { $0.kind == .counterexample })
    }

    @Test("Counterexample appears after a strike with exactly two stops, in order")
    func counterexampleHasTwoStopsAfterAStrike() throws {
        let round = Round.preview(phase: .probing, strikes: 1)
        let spec = try #require(LoomRotors.specs(for: round).first { $0.kind == .counterexample })
        #expect(spec.stops.count == 2)
        #expect(spec.stops[0].anchor == LoomAnchor.counterexample)
        if case let .ribbonTile(id) = spec.stops[1].anchor {
            #expect(id == round.counterexample?.nearestProbeID)
        } else {
            Issue.record("second stop is not the nearest ribbon tile it was chosen against")
        }
    }

    @Test("Probes steps the ribbon NEWEST FIRST and announces glyph plus verdict")
    func probesRotorIsNewestFirst() throws {
        let round = Round.preview(phase: .probing, probes: 5)
        let spec = try #require(LoomRotors.specs(for: round).first { $0.kind == .probes })
        #expect(spec.stops.map(\.anchor) == round.ribbon.probes.reversed().map { LoomAnchor.ribbonTile($0.id) })
        #expect(spec.stops.allSatisfy { !$0.label(loc).isEmpty })
    }

    @Test("every Probes stop carries a prepare: closure — the ribbon is lazy")
    func probesStopsPrepare() throws {
        let round = Round.preview(phase: .probing, probes: 24)
        let spec = try #require(LoomRotors.specs(for: round).first { $0.kind == .probes })
        #expect(spec.stops.allSatisfy { $0.prepare != nil })
    }

    @Test("Rails is four fixed stops in declaration order: rail 1, rail 2, coupler, Seal")
    func railsIsFourFixedStops() throws {
        let spec = try #require(BenchRotors.specs(for: .preview).first { $0.kind == .rails })
        #expect(spec.stops.map(\.anchor) == [BenchAnchor.rail(0), .rail(1), .coupler, .seal])
    }

    @Test("Attributes jumps the Dial's four ramps in canonical order")
    func attributesIsTheFourRamps() throws {
        let round = Round.preview(phase: .probing)
        let spec = try #require(LoomRotors.specs(for: round).first { $0.kind == .attributes })
        #expect(spec.stops.map(\.anchor) == Glyph.Attribute.allCases.map(LoomAnchor.ramp))
    }

    @Test("every rotor's own name comes from loc, never from a literal")
    func rotorNamesGoThroughLoc() {
        for kind in RotorKind.allCases { #expect(!loc.rotorName(kind).isEmpty) }
    }
}
```

Create `Modules/Tests/LoomFeatureTests/AnnouncementTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI
@testable import LoomFeature

@Suite("Announcements — §13.10, §6.8", .tags(.unit, .presubmission))
struct AnnouncementTests {

    private let loc = Loc.english

    @Test("a verdict is one utterance in the order verdict → evidence → bookkeeping")
    func verdictOrderIsFixed() {
        let text = loc.announceVerdict(.admit,
                                       glyph: Glyph(fill: .hollow, shape: .triangle, pips: .three, hue: .amber),
                                       previous: nil, detail: .full, probesUsed: 12, par: 23)
        let verdict = try! #require(text.range(of: loc.admitWord))
        let evidence = try! #require(text.range(of: "triangle"))
        let bookkeeping = try! #require(text.range(of: "12"))
        #expect(verdict.lowerBound < evidence.lowerBound)
        #expect(evidence.lowerBound < bookkeeping.lowerBound)
    }

    @Test("a twin is the same utterance, prefixed")
    func twinIsPrefixed() {
        let g = Glyph(fill: .solid, shape: .square, pips: .two, hue: .rose)
        let plain = loc.announceVerdict(.admit, glyph: g, previous: nil, detail: .full, probesUsed: 3, par: 7)
        let twin = loc.announceTwinVerdict(.admit, glyph: g, previous: nil, detail: .full, probesUsed: 3, par: 7)
        #expect(twin.hasSuffix(plain))
        #expect(twin != plain)
    }

    @Test("verdicts post at .high so they interrupt")
    func verdictsAreHighPriority() {
        let spy = AnnouncerSpy()
        RoundAnnouncer(announcer: spy, loc: loc).verdict(.reject, probe: .preview, round: .preview())
        #expect(spy.posts.count == 1)
        #expect(spy.posts[0].priority == .high)
    }

    @Test("announceVerdicts gates the verdict rows and NOTHING else")
    func announceVerdictsGatesOnlyVerdicts() {
        let spy = AnnouncerSpy()
        let announcer = RoundAnnouncer(announcer: spy, loc: loc, announceVerdicts: false)
        announcer.verdict(.admit, probe: .preview, round: .preview())
        #expect(spy.posts.isEmpty)
        announcer.sealBarred(.inertRail(1))
        announcer.capReached(narration: .preview)
        announcer.streak(4)
        #expect(spy.posts.count == 3)
    }

    @Test("past par and five-from-cap each fire once per round")
    func onceThresholdsFireOnce() {
        let spy = AnnouncerSpy()
        var announcer = RoundAnnouncer(announcer: spy, loc: loc)
        for used in 20...30 { announcer.probeCountDidChange(used: used, par: 23, cap: 37) }
        #expect(spy.posts.filter { $0.text == loc.pastParAnnouncement }.count == 1)
        #expect(spy.posts.filter { $0.text == loc.fiveRemainingAnnouncement }.count == 1)
    }

    @Test("a screen change posts a ScreenChanged notification with the screen's name")
    func screenChangeIsNotAnAnnouncement() {
        let spy = AnnouncerSpy()
        Announcer(spy).screenChanged(to: loc.screenName(.codexRoot))
        #expect(spy.screenChanges == [loc.screenName(.codexRoot)])
        #expect(spy.posts.isEmpty)
    }

    // MARK: the reveal — §6.8

    @Test("a correct reveal posts exactly three announcements, at 640, 1450 and 1850 ms absolute")
    func revealPostsThreeAnnouncements() {
        let schedule = RevealAnnouncementSchedule(outcome: .inscribed)
        #expect(schedule.entries.map(\.offset) == [.milliseconds(640), .milliseconds(1_450), .milliseconds(1_850)])
        #expect(schedule.entries.map(\.kind) == [.verdict, .lawLands, .pageAndMarks])
    }

    @Test("a lost reveal drops the page-and-marks announcement, because there is no page and no mark")
    func lostRevealHasNoPageAnnouncement() {
        let schedule = RevealAnnouncementSchedule(outcome: .broken)
        #expect(schedule.entries.map(\.kind) == [.verdict, .lawLands])
    }

    @Test("tap-to-skip is disabled under VoiceOver; the Magic Tap is the skip")
    func tapToSkipDisabledUnderVoiceOver() {
        #expect(RevealInteraction(isVoiceOverRunning: true).isTapToSkipEnabled == false)
        #expect(RevealInteraction(isVoiceOverRunning: true).skipGesture == .magicTap)
        #expect(RevealInteraction(isVoiceOverRunning: false).isTapToSkipEnabled == true)
    }

    @Test("the reveal is never announced beat by beat — three, not eight")
    func revealIsNotNarratedBeatByBeat() {
        #expect(RevealAnnouncementSchedule(outcome: .inscribed).entries.count == 3)
    }
}
```

Create `Modules/Tests/LoomFeatureTests/EscapeAndMagicTapTests.swift`:

```swift
@Suite("Magic Tap and escape — §13.10", .tags(.unit, .presubmission))
struct EscapeAndMagicTapTests {

    @Test("Magic Tap on a BARRED Seal still fires seal(), which pulses the rail and announces the bar")
    func magicTapOnABarredSealStillFires() {
        let spy = AnnouncerSpy()
        let round = Round.preview(phase: .declaring, sealBar: .inertRail(1), announcer: spy)
        round.seal()
        #expect(round.railPulses == [1])
        #expect(spy.posts.contains { $0.text == round.loc.sealBarredAnnouncement(.inertRail(1)) })
        #expect(round.declarations == 0)                 // it did not declare
    }

    @Test("escape is not available on RoundView — leaving a round is a deliberate act")
    func escapeIsNotOnTheRound() {
        #expect(EscapeSurface.allCases == [.bench, .assayInspector])
    }
}
```

Finally, append **check 11c** to `Scripts/check-source-hygiene.sh` — the counts from
`audit-in-ci.md` §5, which are the mechanical net under the two manual gates:

```bash
# check 11c — the accessibility surface no test can reach. The COUNTS are the assertion.
count() { grep -Rho "$1" Modules/Sources --include='*.swift' | wc -l | tr -d ' '; }

[ "$(count 'accessibilityAction(\.magicTap)')" = "2" ] || fail "expected exactly 2 magic-tap handlers (Dial, commit-bar Seal)"
[ "$(count 'accessibilityAction(\.escape)')"   = "2" ] || fail "expected exactly 2 escape handlers (Bench, Assay inspector)"
[ "$(count 'accessibilityRotor(')"             = "4" ] || fail "expected exactly 4 rotors (§12.8 fixes the set at four)"
grep -Rq 'accessibilitySortPriority' Modules/Sources && fail "sort priority is not used in HUNCH — voiceover-elements.md §12"
```

**Step 2 — run it and watch it fail.**

```
swift test --package-path Modules --filter RotorTests
swift test --package-path Modules --filter AnnouncementTests
swift test --package-path Modules --filter EscapeAndMagicTapTests
Scripts/check-source-hygiene.sh
```

Missing `RotorKind`, `LoomRotors`, `BenchRotors`, `LoomAnchor`, `BenchAnchor`, `RoundAnnouncer`,
`RevealAnnouncementSchedule`, `RevealInteraction`, `EscapeSurface`. Two accidental passes to watch for:
`counterexampleAbsentBeforeAStrike` passes against an implementation that has no rotors at all — check
that `counterexampleHasTwoStopsAfterAStrike` fails first — and `onceThresholdsFireOnce` passes against
an announcer that never posts, so confirm it fails with a count of `0` against an expected `1`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/Announcer.swift` — the one owner, outside the six play-surface files |
| create | `Modules/Sources/LoomFeature/RoundAnnouncer.swift` — the round's announcement policy |
| create | `Modules/Sources/LoomFeature/RevealAnnouncementSchedule.swift` — 640 / 1,450 / 1,850 and the interaction rule |
| create | `Modules/Sources/LoomFeature/LoomAnchor.swift`, `BenchAnchor.swift` — plain `Hashable` enums beside their views |
| create | `Modules/Sources/LoomFeature/LoomRotors.swift`, `BenchRotors.swift` — `RotorKind`, `RotorSpec`, `RotorStop` |
| create | `Modules/Sources/LoomFeature/CounterexampleRotor.swift` — the conditional `ViewModifier` |
| create | `Modules/Sources/HunchUI/SealCommitBar.swift` — the shared commit-bar Seal that carries the second Magic Tap |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — `@Namespace`, three rotors, `.accessibilityRotorEntry` on every target, Magic Tap = probe |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the Rails rotor, `.accessibilityAction(.escape)` |
| modify | `Modules/Sources/LoomFeature/AssayInspectorView.swift` — `.accessibilityAction(.escape)` |
| modify | `Modules/Sources/LoomFeature/SievePauseOverlay.swift` — `.accessibilityAddTraits(.isModal)` |
| modify | `Modules/Sources/LoomFeature/InscriptionView.swift` — drive the reveal schedule; disable tap-to-skip under VoiceOver |
| modify | `Modules/Sources/CodexFeature/CodexRootView.swift`, `CodexShelfView.swift`, `Modules/Sources/MetaFeature/ProfileView.swift` — `.accessibilityAddTraits(.isHeader)` on section labels only |
| modify | `Modules/Sources/HunchUI/Loc.swift` — the nine announcement keys, the four rotor names, the action names |
| create | `Modules/Tests/LoomFeatureTests/{RotorTests,AnnouncementTests,EscapeAndMagicTapTests}.swift` |
| modify | `Scripts/check-source-hygiene.sh` — check 11c |
| modify | `tests.json` — the gate-5 and gate-6 entries (both marked manual, with the lint as their mechanical half) |
| modify | `DECISIONS.md` — the three-announcements ruling and the second Magic Tap's home |

## Implementation notes

### The four rotors, as values then as modifiers

Three parts, and forgetting the third is why a rotor silently does nothing: a `Namespace`, the rotor
declaration, and `.accessibilityRotorEntry(id:in:)` on **each target view**.

```swift
struct RotorSpec: Identifiable, Sendable { let kind: RotorKind; let stops: [RotorStop] ; var id: RotorKind { kind } }
struct RotorStop: Sendable {
    let anchor: LoomAnchor
    let label: @Sendable (Loc) -> String
    let prepare: (@MainActor () -> Void)?      // non-nil wherever the target lives in a lazy stack
}
```

```swift
struct RoundView: View {
    @Namespace private var loomRotor

    var body: some View {
        surface
            .accessibilityRotor(Text(verbatim: loc.rotorName(.probes))) {
                ForEach(round.ribbon.probes.reversed()) { probe in          // newest first
                    AccessibilityRotorEntry(
                        Text(verbatim: loc.glyphLabel(probe.glyph, relativeTo: nil, detail: detail)),
                        id: LoomAnchor.ribbonTile(probe.id),
                        in: loomRotor,
                        prepare: { round.scrollRibbon(to: probe.id) })      // the ribbon is lazy
                }
            }
            .modifier(CounterexampleRotor(counterexample: round.counterexample, namespace: loomRotor))
    }
}
```

Four things that each fail silently if skipped:

- **`prepare:` is not optional for the ribbon.** Its tiles live in a lazy horizontal stack, so an
  off-screen tile has no view to navigate to. Without `prepare` the rotor stops at whatever happens to
  be on screen — which passes a five-probe smoke test and breaks at probe 20. `probesStopsPrepare` is
  the test, and it uses a 24-probe round for exactly that reason.
- **The rotor's own label is a string like any other.** `.accessibilityRotor(Text(verbatim: loc.…))`,
  never `.accessibilityRotor("Rails")` — a `LocalizedStringKey` literal is extracted into the catalog
  and then bypasses `loc`, so it stays English until the next cold launch.
- **"Counterexample" must not exist before the first strike.** §13.12 gate 6 asserts exactly that, so
  an always-present rotor with an empty builder fails the gate while looking correct. Apply the
  modifier conditionally, through `CounterexampleRotor`, and return `content` unchanged when there is
  no counterexample.
- **`LoomAnchor` and `BenchAnchor` are plain `Hashable` enums beside their views.** They are not
  `accessibilityIdentifier`s and not `Route`s — a rotor id is an in-view anchor and has no business in
  `HunchNavigation` (`04 A32`).

Each rotor exists because it removes a *specific* count of swipes: Rails cuts a full declaration
traversal from ~22 gestures to ~16; Attributes jumps four composition groups without walking sixteen
cells; Probes reads the evidence backwards, which is the actual induction task; Counterexample pairs
the two readings that contradict each other. A fifth rotor cannot state such a number, which is why
§12.8 fixes the set at four and check 11c counts them.

### Magic Tap — two sites, and the second one is not where you would first put it

§13.10 assigns Magic Tap to **Probe on the Dial and the Seal on the Bench**. Magic Tap resolves to the
**frontmost handler**, so the Bench's wins while the Bench is up *only if the modifier lives inside the
presented subtree*. Putting both on `RoundView` and branching on an `isBenchPresented` flag is the
version that works in the simulator and fails on device.

**Ruling: the two handler sites are `RoundView.swift` (probe) and `SealCommitBar.swift` (seal), where
`SealCommitBar` is the shared commit-bar component rendered inside `BenchView` and again inside
`EchoRoundView`.** That satisfies three constraints at once: the Bench's handler is inside the
presented subtree; ECHO's commit — which is the Seal on a Bench-shaped commit bar — gets the same
handler without a third site; and check 11c's count stays at exactly 2. Record it in `DECISIONS.md`,
because `rotors-and-gestures.md` §3's snippet writes the second one on `BenchView` and a reader will
otherwise "fix" it and break either ECHO or the lint.

There is no Magic Tap in SIEVE: its only act is the gate, which is a single full-width element and
needs no shortcut.

**Magic Tap on a barred Seal still fires `seal()`**, which pulses the offending rail (§4.3) and posts
"The Seal is barred. Rail 2 is empty." Swallowing it silently would make the one gesture that always
works the one gesture that sometimes does nothing.

### Escape — two sites, and `RoundView` is deliberately not one

```swift
// BenchView          → pull-down
// AssayInspectorView → dismiss
.accessibilityAction(.escape) { dismiss() }
```

Not on `RoundView`. Leaving a round is a deliberate act with a persisted consequence (§12.7 suspends
and returns to the Frame); the leading chevron is that act and it is a plain button. A scrub that
abandons a round is the accident §12.7's SIEVE confirm-by-repeat exists to prevent, one screen over.
`SievePauseOverlay` gets `.accessibilityAddTraits(.isModal)` instead, so VoiceOver stops walking the
frozen lane behind it; its own exit stays §9.2's confirming double chevron.

### The `.headings` rotor

`.headings` carries `CodexRootView`, `CodexShelfView`, `ProfileView`, `StatisticsView` and
`SettingsView`. For the three built on stock `Form`/`List`, `Section(header:)` already emits the
trait — **do not add it by hand**. For the two custom screens, `.accessibilityAddTraits(.isHeader)`
goes on the section label and nowhere else: a heading that is not a section start makes the rotor
useless faster than no headings at all. The play surfaces have no headings, because they have no
sections and no text.

### Announcements

One owner, outside the six play-surface files, because an announcement is an `AttributedString` and
hygiene check 7 fails the build on one in `RoundView`, `EchoRoundView`, `SieveRoundView`, `BenchView`,
`AssayInspectorView` or `InscriptionView`:

```swift
// Modules/Sources/HunchUI/Announcer.swift
@MainActor
public struct Announcer: Sendable {
    public var isEnabled: Bool                                    // §12.6 announceVerdicts

    /// `text` is already resolved by `loc` against the override bundle and locale.
    public func announce(_ text: String,
                         priority: AccessibilitySpeechAnnouncementPriority = .high) {
        guard isEnabled else { return }
        var message = AttributedString(text)
        message.accessibilitySpeechAnnouncementPriority = priority
        AccessibilityNotification.Announcement(message).post()
    }

    public func screenChanged(to name: String) {
        AccessibilityNotification.ScreenChanged(AttributedString(name)).post()
    }
}
```

**The fixed order is inside one utterance, not across three.** "Admit. Hollow triangle, three pips,
amber. Probe 12 of 23." is verdict, then evidence, then bookkeeping, in one announcement, so a fast
player can move on after two words. It is one format string with three interpolations — never three
announcements and never a `+`.

`announceVerdicts` gates the admit / reject / twin rows **and nothing else**. The barred-Seal, cap,
strike, reveal, DRIFT-swap and streak rows are not verdicts and are never gated; neither is any value
read on focus. `announceVerdictsGatesOnlyVerdicts` is the test that keeps that true.

Two rows fire **once per round**: "Past the expected probe count." at par, and "Five probes remaining."
at cap − 5. Hold the two flags on `RoundAnnouncer`, not on the view, or a body re-evaluation re-fires
them.

### The reveal's three announcements

§6.8 is explicit: **640** (the verdict), **1,450** (beat 4, the law lands) and **1,850** (beat 6, the
page and its marks), all absolute from the Seal press, and **tap-to-skip is disabled** because it
collides with tap-to-focus — VoiceOver players skip with the Magic Tap.

`hunch-accessibility/references/voiceover-elements.md` §11 says the reveal is "announced once, at
settle, not beat by beat", and reasons that eight announcements across the reveal would be unreadable.
**Ruling: the GDD wins, and the skill's concern is honoured anyway.** Three is not eight; each of the
three lands on a beat that carries new information (the answer, the law, the page); and the first of
the three *is* the verdict announcement the skill was worried about colliding with. Record it in
`DECISIONS.md` with both sources cited.

```swift
struct RevealAnnouncementSchedule: Sendable {
    enum Kind: Sendable { case verdict, lawLands, pageAndMarks }
    struct Entry: Sendable { let offset: Duration; let kind: Kind }
    let entries: [Entry]

    init(outcome: Outcome) {
        switch outcome {
        case .inscribed: entries = [.init(offset: .milliseconds(640),   kind: .verdict),
                                    .init(offset: .milliseconds(1_450), kind: .lawLands),
                                    .init(offset: .milliseconds(1_850), kind: .pageAndMarks)]
        case .broken, .exhausted: entries = [.init(offset: .milliseconds(640),   kind: .verdict),
                                             .init(offset: .milliseconds(1_450), kind: .lawLands)]
        case .abandoned, .voided: entries = []
        }
    }
}
```

The lost and exhausted sheets skip beats 5–7 (§6.8), so there is no page and no mark to announce; the
schedule drops that entry rather than announcing an empty one. The offsets are **absolute from the
Seal press** and are the same clock E09·T10's `absolute = 640 + local` mapping uses, so the two
documents cannot drift apart: assert `RevealAnnouncementSchedule(outcome: .inscribed).entries[1].offset
== RevealBeat.registration.absoluteOffset`.

Under Reduce Motion the reveal is 900 ms total and every audio and haptic onset past 900 ms is
*dropped, not rescheduled* (§6.8). The same rule applies to the announcements: at 900 ms the schedule
keeps the 640 entry and drops the other two, and the settled composition's values are read on focus
instead. E09·T12 owns the Reduce Motion substitution; this task owns dropping rather than compressing.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter RotorTests` green, all eight tests.
- [ ] `swift test --package-path Modules --filter AnnouncementTests` green, all ten tests.
- [ ] `swift test --package-path Modules --filter EscapeAndMagicTapTests` green.
- [ ] `Scripts/check-source-hygiene.sh` green: exactly 2 Magic Tap handlers, exactly 2 escape handlers, exactly 4 rotors, no `accessibilitySortPriority`. Each count demonstrated to fail on a planted fifth rotor / deleted Magic Tap / third escape before reverting.
- [ ] `grep -Rn 'accessibilityRotor("' Modules/Sources` returns nothing — every rotor name goes through `loc`.
- [ ] `grep -Rn 'isBenchPresented' Modules/Sources/LoomFeature/RoundView.swift` returns nothing.
- [ ] `grep -Rn 'accessibilityAction(.escape)' Modules/Sources/LoomFeature/RoundView.swift` returns nothing.
- [ ] `grep -Rn 'AccessibilityNotification' Modules/Sources --include='*.swift' | grep -v Announcer.swift` returns nothing — one owner.
- [ ] `grep -Rn 'prepare:' Modules/Sources/LoomFeature/RoundView.swift` shows the Probes rotor passing one.
- [ ] `tests.json` carries the gate-5 and gate-6 entries, each `manual: true` with the lint named as its mechanical half, plus the reveal-schedule entry.
- [ ] `DECISIONS.md` carries the three-announcements ruling and the `SealCommitBar` Magic Tap ruling.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T05: four rotors, two Magic Taps, two escapes, and the announcement order"`

## Out of scope

- Running gates 3, 5 and 6 on a device and recording them — **T11**; this task ships the code they exercise.
- SIEVE's gate action and its gate-entry / sump announcements, and ECHO's pool and primer strips — **T10**.
- The reveal beat sheets themselves and their cue points — **E09·T10**; this task attaches to offsets that already exist.
- The Reduce Motion substitution table — **E09·T12**.
- The `announceVerdicts` Settings row as UI — **E17·T07**.
- The nudge scheduler's VoiceOver suppression — **E10·T08** wrote it, **T10** wires and asserts it.
