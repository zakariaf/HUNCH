import Testing

import HunchTestSupport
import Onboarding

/// §12.5's script, as a shape. Its two hard rules are structural: one affordance per beat, and
/// a second opening round re-arms from beat 6.
@Suite("The opening script", .tags(.unit, .presubmission))
struct OpeningScriptTests {

    @Test("Fourteen beats, 0 through 13, in order and with no gaps")
    func fourteenBeats() {
        #expect(OpeningScript.beats.count == 14)
        #expect(OpeningScript.beats.map(\.index) == Array(0...13))
    }

    /// One affordance per beat. Two would make the beat a screen, and a player learning by doing
    /// cannot be doing two things.
    @Test("Each beat reveals exactly one affordance, and no two reveal the same one")
    func oneAffordancePerBeat() {
        let revealed = OpeningScript.beats.map(\.reveals)
        #expect(Set(revealed).count == revealed.count)
        #expect(revealed.allSatisfy { !$0.isEmpty })
    }

    /// A beat triggered by time alone plays over a player who is already doing something else,
    /// which is why only three of the fourteen are — and why beat 7 is "probe 4 **or** 25 s".
    @Test("Only three beats are driven by time alone")
    func mostBeatsAreDrivenByTheAct() {
        let timed = OpeningScript.beats.filter {
            if case .elapsed = $0.trigger { true } else { false }
        }
        #expect(timed.count == 2)
        let hybrid = OpeningScript.beats.filter {
            if case .actOrElapsed = $0.trigger { true } else { false }
        }
        #expect(hybrid.count == 1)
        #expect(hybrid[0].index == 7)
    }

    /// Beats 0–5 teach what a probe is. Replaying them for a player who has already probed is
    /// the game explaining something they just did.
    @Test("A second opening round re-arms from beat 6")
    func secondRunSkipsTheFirstSix() {
        let second = OpeningScript.beats(from: OpeningScript.reArmBeat)
        #expect(second.count == 8)
        #expect(second[0].index == 6)
        #expect(second.contains { $0.index < 6 } == false)
    }

    /// A menu offered to somebody who has never played is a menu of things that mean nothing.
    @Test("The Frame lights at beat 13 and not before")
    func theFrameArrivesLast() {
        #expect(OpeningScript.frameUnlocksAt == 13)
        #expect(OpeningScript.beats[13].reveals.contains("Frame"))
        #expect(OpeningScript.beats.prefix(13).allSatisfy { !$0.reveals.contains("Frame") })
    }
}
