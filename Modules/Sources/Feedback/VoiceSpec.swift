public import Foundation

public import Glyphs

/// §13.8's cue table — **the single normative source for every sound in the app.**
///
/// The mode sections own *beat positions*: which cue fires at which millisecond of which
/// animation. Where any of them states a frequency, an interval or a duration, those numbers are
/// superseded here. A reject built on a minor second is not a near-miss of this design, it is the
/// opposite of it: the whole scheme rests on **reject being a tritone a fifth below admit**,
/// which is a fall, where a minor second above the same root is a rise.
public enum Scale {

    /// Five-limit **just** intonation on D3. Just, not tempered, because a beat-free perfect
    /// fifth is *audibly* locked and a tempered one is not — and the whole point of `admit` is
    /// that it resolves.
    public static let root = 146.83

    public static let unison = root  // 1/1
    public static let minorThird = 176.20  // 6/5
    public static let fourth = 195.77  // 4/3
    public static let fifth = 220.25  // 3/2
    public static let minorSeventh = 264.29  // 9/5
    public static let octave = 293.66  // 2/1

    /// **Reserved exclusively for rejection.** 45/32, a just tritone.
    public static let tritone = 206.48

    /// With no context whatsoever, admit is *up and settled* and reject is *down and
    /// unresolved*. That is the whole design, and it survives being heard once.
    public static let admitIsAboveReject = fifth > tritone
}

public struct VoiceSpec: Equatable, Sendable {
    public enum Waveform: String, Equatable, Sendable {
        case sine, triangle, square
    }

    public let frequency: Double
    public let waveform: Waveform
    /// Relative to the cue's peak, dB.
    public let gain: Double

    public init(frequency: Double, waveform: Waveform, gain: Double = 0) {
        self.frequency = frequency
        self.waveform = waveform
        self.gain = gain
    }
}

public struct CueSpec: Equatable, Sendable {
    public let voices: [VoiceSpec]
    public let attack: Duration
    public let decay: Duration
    /// dBFS.
    public let peak: Double

    public init(voices: [VoiceSpec], attack: Duration, decay: Duration, peak: Double) {
        self.voices = voices
        self.attack = attack
        self.decay = decay
        self.peak = peak
    }
}

extension Cue {
    /// §13.8's table, transcribed once.
    public var spec: CueSpec {
        switch self {
        case .probeSubmit:
            return CueSpec(
                voices: [VoiceSpec(frequency: Scale.fourth, waveform: .triangle)],
                attack: .milliseconds(1), decay: .milliseconds(55), peak: -26)

        case .verdict(let verdict, let isTwin):
            // A twin is the verdict cue at ×0.72 with one added partial at the octave: it marks
            // a repeat **without new information**, so it must not sound like a discovery.
            let base: CueSpec =
                verdict == .admit
                ? CueSpec(
                    voices: [
                        VoiceSpec(frequency: Scale.fifth, waveform: .sine),
                        VoiceSpec(frequency: 330.37, waveform: .sine),
                        VoiceSpec(frequency: 660.75, waveform: .sine, gain: -18),
                    ], attack: .milliseconds(4), decay: .milliseconds(260), peak: -16)
                : CueSpec(
                    voices: [
                        VoiceSpec(frequency: Scale.unison, waveform: .sine),
                        VoiceSpec(frequency: Scale.tritone, waveform: .sine),
                        VoiceSpec(frequency: 73.42, waveform: .triangle, gain: -12),
                    ], attack: .milliseconds(2), decay: .milliseconds(190), peak: -18)
            guard isTwin else { return base }
            return CueSpec(
                voices: base.voices + [VoiceSpec(frequency: Scale.octave, waveform: .sine)],
                attack: base.attack, decay: base.decay,
                peak: base.peak + Cue.twinGainDb)

        case .declare:
            return CueSpec(
                voices: [VoiceSpec(frequency: Scale.unison, waveform: .sine)],
                attack: .milliseconds(8), decay: .milliseconds(340), peak: -14)

        case .bar:
            return CueSpec(
                voices: [VoiceSpec(frequency: 110.12, waveform: .square)],
                attack: .milliseconds(1), decay: .milliseconds(45), peak: -28)

        case .strike:
            return CueSpec(
                voices: [VoiceSpec(frequency: Scale.tritone, waveform: .square)],
                attack: .milliseconds(1), decay: .milliseconds(120), peak: -20)

        case .lawDeclaredCorrectly:
            return CueSpec(
                voices: [
                    VoiceSpec(frequency: Scale.unison, waveform: .sine),
                    VoiceSpec(frequency: Scale.minorThird, waveform: .sine),
                    VoiceSpec(frequency: Scale.fifth, waveform: .sine),
                    VoiceSpec(frequency: Scale.octave, waveform: .sine),
                ], attack: .milliseconds(6), decay: .milliseconds(520), peak: -12)

        case .lawBroken:
            return CueSpec(
                voices: [
                    VoiceSpec(frequency: Scale.unison, waveform: .sine),
                    VoiceSpec(frequency: Scale.tritone, waveform: .triangle),
                ], attack: .milliseconds(8), decay: .milliseconds(900), peak: -16)

        case .driftMoment:
            // The partner slides 195.77 → 190.00 over 480 ms and the beat rate climbs from 0 to
            // 5.8 Hz: the pitch audibly *slides off*, which is the mode in one sound.
            return CueSpec(
                voices: [
                    VoiceSpec(frequency: Scale.fourth, waveform: .sine),
                    VoiceSpec(frequency: 190.00, waveform: .sine),
                ], attack: .milliseconds(30), decay: .milliseconds(620), peak: -18)

        case .streak(let step):
            // The chord *grows*, and caps at five partials — a reward that kept growing would
            // eventually be the loudest thing in the game.
            let partials = [Scale.fifth, Scale.octave, 367.08, 440.49, 587.32]
            return CueSpec(
                voices: [VoiceSpec(frequency: Scale.unison, waveform: .sine)]
                    + partials.prefix(min(max(0, step), 5)).map {
                        VoiceSpec(frequency: $0, waveform: .sine)
                    },
                attack: .milliseconds(6), decay: .milliseconds(600), peak: -14)

        case .codexInscribe:
            return CueSpec(
                voices: [
                    VoiceSpec(frequency: Scale.minorSeventh, waveform: .sine),
                    VoiceSpec(frequency: 396.44, waveform: .sine),
                ], attack: .milliseconds(10), decay: .milliseconds(700), peak: -20)

        case .sieveTick:
            return CueSpec(
                voices: [VoiceSpec(frequency: Scale.octave, waveform: .sine)],
                attack: .milliseconds(1), decay: .milliseconds(22), peak: -30)

        case .sieveHit:
            return CueSpec(
                voices: [VoiceSpec(frequency: 440.50, waveform: .sine)],
                attack: .milliseconds(2), decay: .milliseconds(90), peak: -22)

        case .sieveMiss:
            return CueSpec(
                voices: [VoiceSpec(frequency: 110.12, waveform: .triangle)],
                attack: .milliseconds(1), decay: .milliseconds(140), peak: -22)
        }
    }

    /// ×0.72 in linear gain — about −2.85 dB.
    public static let twinGainDb = -2.85
}

/// §13.8's mix and session policy.
public enum MixPolicy {
    /// A fixed voice array with an atomic head index, oldest-stolen. SIEVE at maximum speed asks
    /// for about twelve cues a second and the cap holds.
    public static let voiceSlots = 8
    public static let polyphonyCap = 6

    /// The mix is ceiling-limited here, which is why §12.6's Level is **two states and not a
    /// slider**: a continuous gain below a limiter is a control nobody can set correctly by ear.
    public static let ceilingDbfs = -6.0
    public static let lowLevelDb = -8.0

    /// **Sound off means the engine is never instantiated**, not muted. A muted engine still
    /// takes the audio session, which is what interrupts a podcast.
    public static let soundOffMeansNoEngine = true
}
