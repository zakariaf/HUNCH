import Foundation
import Testing

import Glyphs
import HunchAppFeature
import ModulesTestSupport
import Persistence

/// The first frame, decided from state alone. A route that reads a flag someone remembered to
/// set shows the wrong screen the first time somebody forgets.
@Suite("The launch route", .tags(.unit, .presubmission))
struct AppLaunchRouteTests {

    @Test("A fresh install opens the round, not the Frame")
    func freshInstallSkipsTheFrame() {
        #expect(AppLaunchRoute.decide(suspended: [], hasPlayed: false) == .openingRound)
    }

    @Test("A returning player with nothing suspended sees the Frame")
    func returningPlayerSeesTheFrame() {
        #expect(AppLaunchRoute.decide(suspended: [], hasPlayed: true) == .frame)
    }

    @Test("A live snapshot wins over both", arguments: [Mode.probe, .drift, .echo])
    func aSnapshotAlwaysResumes(_ mode: Mode) {
        #expect(
            AppLaunchRoute.decide(suspended: [mode], hasPlayed: true) == .resumeRound(mode))
        #expect(
            AppLaunchRoute.decide(suspended: [mode], hasPlayed: false) == .resumeRound(mode))
    }

    /// Two suspended rounds must resolve the same way every launch. Reading whichever the file
    /// system listed first is the version that shows a different screen on two devices with the
    /// same state.
    @Test("Two suspended rounds resolve deterministically, PROBE first")
    func theChoiceIsDeterministic() {
        #expect(
            AppLaunchRoute.decide(suspended: [.drift, .probe], hasPlayed: true)
                == .resumeRound(.probe))
        #expect(
            AppLaunchRoute.decide(suspended: [.echo, .drift], hasPlayed: true)
                == .resumeRound(.drift))
    }

    /// SIEVE has no suspend slot (§6.10): a stream cannot be paused into a file and resumed as
    /// the same stream, so it is not one of the three.
    @Test("SIEVE is not a resumable mode")
    func sieveDoesNotResume() {
        #expect(AppLaunchRoute.decide(suspended: [.sieve], hasPlayed: true) == .frame)
    }
}
