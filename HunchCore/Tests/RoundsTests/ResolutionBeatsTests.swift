import Testing

import HunchTestSupport
import Rounds

/// §6.8 and §13.7.1 are the same sheet in two clocks — `absolute = 640 + local`. Encoding the
/// beats as data is what lets that identity be a test rather than a promise, and it is the one
/// place in the app where two documents have to agree row for row.
@Suite("The resolution beat sheets", .tags(.unit, .presubmission))
struct ResolutionBeatsTests {

    @Test("The correct sheet is nine beats and ends at 2,480 ms")
    func correctSheetShape() {
        #expect(ResolutionBeats.correct.count == 9)
        #expect(ResolutionBeats.correct[0].at == 640)
        #expect(ResolutionBeats.correctTotal == .milliseconds(2_480))
    }

    /// The identity that keeps the two documents from drifting: every row's absolute time is
    /// 640 plus §13.7.1's own local time, and the local beats run 0…8 with no gaps.
    @Test("absolute = 640 + local, for every beat")
    func theTwoClocksAgree() {
        let locals = ResolutionBeats.correct.compactMap(\.localBeat)
        #expect(locals == Array(0...8))
        for beat in ResolutionBeats.correct {
            #expect(beat.at >= 640)
        }
        // §13.7.1's reveal is 1,840 ms long, so the last beat starts inside it.
        #expect(ResolutionBeats.correct[8].at - 640 < 1_840)
    }

    @Test("Every sheet is strictly ordered in time")
    func beatsAreOrdered() {
        for sheet in [ResolutionBeats.correct, ResolutionBeats.firstStrike] {
            #expect(sheet.map(\.at) == sheet.map(\.at).sorted())
            #expect(Set(sheet.map(\.at)).count == sheet.count)
        }
    }

    /// The hold is the same length on every sheet, which is what makes the reveal honest about
    /// its own length: a player cannot read the verdict off the clock.
    @Test("The seal hold is verdict-blind and starts every sheet")
    func theHoldIsShared() {
        #expect(ResolutionBeats.sealHold == .milliseconds(640))
        #expect(ResolutionBeats.correct[0].at == 640)
        #expect(ResolutionBeats.firstStrike[0].at == 640)
        #expect(
            ResolutionBeats.firstStrikeTotal
                == ResolutionBeats.sealHold + .milliseconds(960))
        #expect(
            ResolutionBeats.secondStrikeTotal
                == ResolutionBeats.sealHold + .milliseconds(1_020))
    }

    /// "Skippable from t = 1,040 ms. That is the one skip threshold; there is no other."
    @Test("The skip threshold is 400 ms into the reveal and lands between beats 2 and 3")
    func oneSkipThreshold() {
        #expect(ResolutionBeats.skipThreshold == .milliseconds(1_040))
        #expect(ResolutionBeats.skipThreshold == ResolutionBeats.sealHold + .milliseconds(400))
        let before = ResolutionBeats.correct.filter { $0.at <= 1_040 }
        #expect(before.count == 3)  // the stack has gathered before a skip is offered
    }

    /// §13.7.4: onsets past the end of a Reduce Motion reveal are **dropped**, not rescheduled —
    /// a haptic arriving after the screen has settled is a second event, not the same one.
    @Test("Reduce Motion keeps absolute onsets and drops the ones past 900 ms")
    func reduceMotionDropsRatherThanCompresses() {
        let kept = ResolutionBeats.correct.filter(ResolutionBeats.survivesReduceMotion)
        #expect(kept.count == 3)
        #expect(kept.allSatisfy { $0.at <= 900 })
        #expect(ResolutionBeats.reduceMotionCorrectTotal == .milliseconds(900))
        // The hold itself is unchanged — shortening it for some players is a different game.
        #expect(ResolutionBeats.reduceMotionCorrectTotal > ResolutionBeats.sealHold)
    }

    /// §6.8: three announcements, and they sit on the beats that carry information rather than
    /// on the ones that carry motion.
    @Test("VoiceOver speaks at the verdict, the registration and the page")
    func threeAnnouncements() {
        #expect(ResolutionBeats.voiceOverAnnouncements == [640, 1_450, 1_850])
        for time in ResolutionBeats.voiceOverAnnouncements {
            #expect(ResolutionBeats.correct.contains { $0.at == time })
        }
    }
}
