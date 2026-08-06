public import Foundation

public import Tokens

/// §6.8's resolution sheets, **absolute from the Seal press**, as data.
///
/// §13.7.1 writes the reveal in its own local time starting at its beat 0; the two are the same
/// sheet with `absolute = 640 + local`, and the beat numbers travel with the rows so the two
/// documents cannot drift apart. Encoding them as a table rather than as a chain of
/// `Task.sleep`s is what makes "skippable from t = 1,040 ms and nowhere else" a fact a test can
/// read rather than a comment beside a magic number.
extension Duration {
    /// Whole milliseconds. The beat sheets are stated in them and `Duration`'s components are
    /// seconds plus attoseconds, so the conversion happens once, here.
    public var milliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1_000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}

public enum ResolutionBeats {

    public struct Beat: Equatable, Sendable {
        /// Absolute milliseconds from the Seal press.
        public let at: Int
        /// §13.7.1's own beat number, for the correct sheet. `nil` on sheets that have none.
        public let localBeat: Int?
        public let name: String

        public init(at: Int, localBeat: Int? = nil, name: String) {
            self.at = at
            self.localBeat = localBeat
            self.name = name
        }
    }

    /// **Verdict-blind, and unchanged under Reduce Motion.** Identical in content and duration
    /// for a correct and an incorrect declaration, which is the reason the reveal can be honest
    /// about its own length — the answer is not readable off the clock. Shortening it for some
    /// players would hand them a different game.
    public static let sealHold = Dur.sealHold

    /// The one skip threshold. There is no other.
    public static let skipThreshold = Dur.sealHold + Dur.revealSkip

    /// Correct: 640 ms hold + §13.7.1's 1,840 ms reveal.
    public static let correct: [Beat] = [
        Beat(at: 640, localBeat: 0, name: "seal releases, ring completes, bar retracts"),
        Beat(at: 730, localBeat: 1, name: "chrome out, ribbon to 20 %, Assay holds at full"),
        Beat(at: 870, localBeat: 2, name: "player's tiles gather into one centred stack"),
        Beat(at: 1_130, localBeat: 3, name: "the Loom's tiles converge behind them"),
        Beat(at: 1_450, localBeat: 4, name: "registration — the brass hairline sweeps"),
        Beat(at: 1_630, localBeat: 5, name: "the constellation contracts into the page thumbnail"),
        Beat(at: 1_850, localBeat: 6, name: "seal marks strike in, one per 80 ms"),
        Beat(at: 2_090, localBeat: 7, name: "the page frame draws itself, hairline, clockwise"),
        Beat(at: 2_350, localBeat: 8, name: "drift resolves; the continue affordance fades in"),
    ]

    public static let correctTotal = Dur.sealHold + Dur.reveal

    /// First strike: 640 ms hold + 960 ms counterexample. The round **continues**.
    public static let firstStrike: [Beat] = [
        Beat(at: 640, name: "the Seal ring breaks; the arcs slide 6 pt apart"),
        Beat(at: 1_000, name: "the counterexample rises from its Assay cell and travels to centre"),
        Beat(at: 1_300, name: "it takes two rings at once — the declaration's and the Loom's"),
        Beat(at: 1_600, name: "it docks below the ribbon; the Bench collapses to the Dial"),
    ]

    public static let firstStrikeTotal = Dur.sealHold + Dur.counterexample

    /// Second strike: 640 ms hold + §13.7.1's 1,020 ms lost skeleton.
    public static let secondStrikeTotal = Dur.sealHold + Dur.revealLost

    /// §13.7.4: the 640 ms hold runs unchanged, then **one 260 ms crossfade** to the settled
    /// composition with the marks already struck.
    ///
    /// Audio and haptic onsets keep their absolute positions and the ones past the end are
    /// **dropped rather than rescheduled** — a haptic arriving after the screen has settled is a
    /// second event, not the same one.
    public static let reduceMotionCorrectTotal = Dur.sealHold + Dur.reduceMotionReveal

    /// §6.8: VoiceOver posts three announcements and **disables tap-to-skip**, which collides
    /// with tap-to-focus; VO users skip with the magic tap.
    public static let voiceOverAnnouncements: [Int] = [640, 1_450, 1_850]

    /// Which onsets survive a Reduce Motion reveal.
    public static func survivesReduceMotion(_ beat: Beat) -> Bool {
        beat.at <= reduceMotionCorrectTotal.milliseconds
    }
}
