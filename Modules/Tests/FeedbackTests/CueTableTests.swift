import Foundation
import Testing

import Feedback
import Glyphs
import ModulesTestSupport

/// §13.8's table. The scheme's whole claim is that **with no context whatsoever, admit is up and
/// settled and reject is down and unresolved** — so the tests are about intervals, not about
/// numbers that happen to be in a table.
@Suite("The cue table", .tags(.unit, .presubmission))
struct CueTableTests {

    /// Just, not tempered: a beat-free perfect fifth is *audibly* locked and a tempered one is
    /// not, and the whole point of `admit` is that it resolves.
    @Test("The scale is five-limit just intonation on D3")
    func theScaleIsJust() {
        #expect(Scale.root == 146.83)
        // 3/2 and 2/1 to within a cent of exact — which is what "beat-free" means.
        #expect(abs(Scale.fifth / Scale.root - 1.5) < 0.001)
        #expect(abs(Scale.octave / Scale.root - 2.0) < 0.001)
        #expect(abs(Scale.fourth / Scale.root - 4.0 / 3.0) < 0.001)
        // The tritone is 45/32 and is reserved exclusively for rejection.
        #expect(abs(Scale.tritone / Scale.root - 45.0 / 32.0) < 0.001)
    }

    /// **Reject is a tritone a fifth below admit.** A reject built on a minor second is not a
    /// near-miss of this design, it is the opposite of it: a minor second above the same root is
    /// a *rise*, and the whole scheme rests on the fall.
    @Test("Admit rises and reject falls, with no context at all")
    func admitRisesAndRejectFalls() {
        let admit = Cue.verdict(.admit, isTwin: false).spec
        let reject = Cue.verdict(.reject, isTwin: false).spec

        #expect(admit.voices[0].frequency == Scale.fifth)
        #expect(reject.voices[0].frequency == Scale.unison)
        #expect(reject.voices[1].frequency == Scale.tritone)
        #expect(Scale.admitIsAboveReject)
        // …and reject carries a sub-octave, which is what makes the fall audible on a phone
        // speaker that cannot reproduce 73 Hz — the harmonic is inferred.
        #expect(reject.voices.contains { $0.frequency < Scale.root })
    }

    /// A twin marks a repeat **without new information**, so it must not sound like a discovery:
    /// the verdict cue, quieter, with one added partial at the octave.
    @Test("A twin is the verdict cue, quieter, plus one octave partial")
    func theTwinIsMarkedNotAnnounced() {
        let plain = Cue.verdict(.admit, isTwin: false).spec
        let twin = Cue.verdict(.admit, isTwin: true).spec

        #expect(twin.voices.count == plain.voices.count + 1)
        #expect(twin.voices[twin.voices.count - 1].frequency == Scale.octave)
        #expect(twin.peak < plain.peak)
    }

    /// The DRIFT cue is the mode in one sound: the partner slides and the beat rate climbs from
    /// zero, so the pitch audibly *slides off* rather than changing to something else.
    @Test("The drift cue slides rather than steps")
    func driftSlides() {
        let spec = Cue.driftMoment.spec
        #expect(spec.voices.count == 2)
        let beat = abs(spec.voices[0].frequency - spec.voices[1].frequency)
        #expect(beat > 0 && beat < 8)  // a beat you can hear as a beat, not as two notes
    }

    /// A reward that kept growing would eventually be the loudest thing in the game.
    @Test("The streak chord grows and caps at five partials")
    func streakCaps() {
        #expect(Cue.streak(step: 1).spec.voices.count == 2)
        #expect(Cue.streak(step: 5).spec.voices.count == 6)
        #expect(Cue.streak(step: 9).spec.voices.count == 6)
    }

    /// Every cue has a spec, and none of them peaks above the mix ceiling.
    @Test("Every cue is specified and sits under the ceiling")
    func everyCueIsSpecified() {
        let cues: [Cue] = [
            .probeSubmit, .verdict(.admit, isTwin: false), .verdict(.reject, isTwin: true),
            .declare, .bar, .strike, .lawDeclaredCorrectly(marks: 3), .lawBroken,
            .driftMoment, .streak(step: 3), .codexInscribe, .sieveTick, .sieveHit, .sieveMiss,
        ]
        for cue in cues {
            let spec = cue.spec
            #expect(spec.voices.isEmpty == false)
            #expect(spec.peak <= MixPolicy.ceilingDbfs)
            #expect(spec.decay > .zero)
        }
    }

    /// §12.6: Level is **two states, not a slider**, because the mix is already ceiling-limited
    /// and a continuous gain under a limiter is a control nobody can set correctly by ear.
    @Test("The mix is ceiling-limited, which is why Level is two states")
    func mixPolicy() {
        #expect(MixPolicy.ceilingDbfs == -6.0)
        #expect(MixPolicy.polyphonyCap == 6)
        #expect(MixPolicy.voiceSlots > MixPolicy.polyphonyCap)
        // Sound off means the engine is never instantiated: a muted engine still takes the
        // audio session, which is what interrupts a podcast.
        #expect(MixPolicy.soundOffMeansNoEngine)
    }
}

/// §13.9's patterns. The claim they carry is that the four verdict-adjacent feels occupy
/// *different corners* of the intensity/sharpness square — which is what makes them separable by
/// hand alone, with the screen off.
@Suite("The haptic table", .tags(.unit, .presubmission))
struct HapticTableTests {

    /// Admit is soft, round and low; reject is hard, bright and doubled. A soft low double would
    /// be admit's texture repeated, which is the failure §13.9 names.
    @Test("Admit and reject are opposite in both axes and in event count")
    func admitAndRejectAreOpposite() {
        guard let admit = Cue.verdict(.admit, isTwin: false).haptic,
            let reject = Cue.verdict(.reject, isTwin: false).haptic
        else { return #expect(Bool(false), "both verdicts must have a pattern") }

        #expect(admit.events.count == 1)
        #expect(reject.events.count == 2)
        #expect(admit.events[0].sharpness < reject.events[0].sharpness)
        #expect(admit.events[0].intensity > reject.events[0].intensity)
    }

    /// **The only high-intensity, low-sharpness event in the game.** Everything else that is
    /// strong is also bright, which is what makes the bar feel like a wall rather than a hit.
    @Test("The bar is the only heavy dull event")
    func theBarIsUnique() {
        guard let bar = Cue.bar.haptic else { return #expect(Bool(false)) }
        let event = bar.events[0]
        #expect(event.intensity >= 0.90)
        #expect(event.sharpness <= 0.20)

        let others: [Cue] = [
            .probeSubmit, .verdict(.admit, isTwin: false), .verdict(.reject, isTwin: false),
            .strike, .lawBroken, .sieveHit, .sieveMiss,
        ]
        for cue in others {
            for other in cue.haptic?.events ?? [] where other.intensity >= 0.90 {
                #expect(other.sharpness > 0.20, "a second heavy dull event: \(cue)")
            }
        }
    }

    /// The hand counts the marks: N transients, one per 80 ms.
    @Test("The correct-declaration pattern has one transient per mark")
    func marksAreCounted() {
        for marks in 1...3 {
            #expect(Cue.lawDeclaredCorrectly(marks: marks).haptic?.events.count == marks)
        }
    }

    /// Eleven patterns, not thirteen. A metronomic tick at three a second would be a buzz, and
    /// the page being inscribed is meant to sit underneath everything else — so both are
    /// deliberately silent to the hand.
    @Test("Two cues have a sound and no feel, on purpose")
    func twoCuesAreSilentToTheHand() {
        #expect(Cue.sieveTick.haptic == nil)
        #expect(Cue.codexInscribe.haptic == nil)
        #expect(Cue.sieveTick.spec.voices.isEmpty == false)
    }

    /// §12.6: no Light tier. Eleven half-strength spellings would be eleven more designs
    /// carrying no information the visuals do not already carry.
    @Test("There is no intensity tier, and no haptics degrades silently")
    func policy() {
        #expect(HapticPolicy.hasIntensityTiers == false)
        #expect(HapticPolicy.degradesSilently)
        #expect(HapticPolicy.patternCount == 11)
    }
}
