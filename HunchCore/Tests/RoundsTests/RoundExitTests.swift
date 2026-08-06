import Testing

import Glyphs
import HunchTestSupport
import Rounds

/// §6.10's leaving rules as a total function. The value of writing it this way is that the four
/// actions differ in ways a player can *feel*, and every one of those differences is a place two
/// call sites could quietly disagree.
@Suite("Leaving a round", .tags(.unit, .presubmission))
struct RoundExitTests {

    @Test("Abandoning at zero probes discards outright, with the seed back in the pool")
    func zeroProbesDiscards() {
        let action = RoundExit.action(mode: .probe, probesUsed: 0, intent: .abandon)
        #expect(action == .discard)
        let effects = RoundExit.effects(of: action)
        #expect(effects.writesRecord == false)
        #expect(effects.returnsSeedToPool)
        // No evidence was produced, so inscribing it would let a player leave a fingerprint by
        // doing nothing at all.
    }

    @Test("One probe or more settles as abandoned", arguments: [1, 5, 40])
    func oneProbeSettles(_ probes: Int) {
        let action = RoundExit.action(mode: .probe, probesUsed: probes, intent: .abandon)
        #expect(action == .settleAbandoned)
        #expect(RoundExit.effects(of: action).writesRecord)
    }

    /// §10.1: an abandon is an **interruption** signal, not a failure signal. Scoring it as a
    /// loss would let a player farm the adaptive engine downward by quitting hard rounds.
    @Test("No exit updates ability, and every exit leaves the target sticky")
    func leavingNeverMovesTheLadder() {
        for mode in Mode.allCases {
            for probes in [0, 3] {
                for intent in [RoundExit.Intent.suspend, .abandon] {
                    let effects = RoundExit.effects(
                        of: RoundExit.action(mode: mode, probesUsed: probes, intent: intent))
                    #expect(effects.updatesAbility == false)
                    #expect(effects.stickyTarget)
                }
            }
        }
    }

    /// A stream cannot be paused into a file and resumed as the same stream.
    @Test("SIEVE has no suspend slot", arguments: Mode.allCases)
    func sieveDoesNotSuspend(_ mode: Mode) {
        let action = RoundExit.action(mode: mode, probesUsed: 4, intent: .suspend)
        #expect(action == (mode == .sieve ? .suspendUnavailable : .suspend))
        #expect(RoundExit.effects(of: action).writesSnapshot == (mode != .sieve))
    }

    @Test("Suspending writes a snapshot and no record; abandoning does the opposite")
    func suspendAndAbandonAreOpposites() {
        let suspend = RoundExit.effects(of: .suspend)
        let abandon = RoundExit.effects(of: .settleAbandoned)
        #expect(suspend.writesSnapshot && !suspend.writesRecord)
        #expect(abandon.writesRecord && !abandon.writesSnapshot)
    }
}

/// §6.10's re-entry, which has to feel like the round never stopped.
@Suite("The re-entry beat", .tags(.unit, .presubmission))
struct ReEntryBeatTests {

    @Test("Four steps, in reading order, inside 900 ms")
    func theBeatIsOrdered() {
        let steps = ReEntryBeat.Step.allCases
        #expect(steps == [.parTicks, .ribbon, .dockedCounterexample, .throat])
        let onsets = steps.map { ReEntryBeat.onset(of: $0).milliseconds }
        #expect(onsets == onsets.sorted())
        #expect(onsets[0] == 0)
        #expect(onsets[onsets.count - 1] < ReEntryBeat.duration.milliseconds)
    }

    /// The throat is last because it is the only thing the player is about to act on — and
    /// input is locked until then, so the beat cannot be outrun into a probe against a surface
    /// that has not finished re-reading itself.
    @Test("The throat arrives last and input is locked throughout")
    func inputIsLockedForTheWholeBeat() {
        #expect(ReEntryBeat.locksInput)
        #expect(
            ReEntryBeat.onset(of: .throat).milliseconds
                > ReEntryBeat.onset(of: .ribbon).milliseconds)
    }

    /// Replaying §6.9's crossing would fire the round's one non-verdict event for something
    /// that happened before the app was killed — a player resuming at probe 20 of 23 would
    /// watch their par row invert as though they had just spent the probe that did it.
    @Test("The par crossing is restored, never replayed")
    func theCrossingIsRestored() {
        #expect(ReEntryBeat.restoresParCrossingWithoutReplaying)
    }
}
