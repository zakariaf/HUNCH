public import Foundation

public import Glyphs

/// §13.9's pattern table — **the single normative source for every haptic in the app.**
///
/// As with audio, the mode sections own beat positions only. §6.4's "two short transients at 0
/// and 55 ms, sharpness 0.3" for reject is superseded here, and the difference matters: a soft,
/// low double is *admit's texture doubled*, where reject must read as **hard and bright** — the
/// opposite corner of the intensity/sharpness square from `bar`.
public struct HapticEvent: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case transient
        case continuous
    }

    public let kind: Kind
    /// Seconds from the pattern's start.
    public let time: Double
    public let intensity: Double
    /// For a continuous event, the value it decays to.
    public let intensityEnd: Double?
    public let sharpness: Double
    public let duration: Double?

    public init(
        kind: Kind, time: Double, intensity: Double, intensityEnd: Double? = nil,
        sharpness: Double, duration: Double? = nil
    ) {
        self.kind = kind
        self.time = time
        self.intensity = intensity
        self.intensityEnd = intensityEnd
        self.sharpness = sharpness
        self.duration = duration
    }
}

public struct HapticPattern: Equatable, Sendable {
    public let events: [HapticEvent]

    public init(_ events: [HapticEvent]) { self.events = events }
}

extension Cue {
    /// §13.9's table, transcribed once. `nil` where a cue has a sound and no feel — which is a
    /// real answer, not a gap: `.codexInscribe` is deliberately silent to the hand.
    public var haptic: HapticPattern? {
        switch self {
        case .probeSubmit:
            // Quieter than either verdict: a key click must not compete with the answer.
            return HapticPattern([
                HapticEvent(kind: .transient, time: 0, intensity: 0.28, sharpness: 0.65)
            ])

        case .verdict(let verdict, let isTwin):
            let base: HapticPattern =
                verdict == .admit
                // Soft, round, low. ONE transient.
                ? HapticPattern([
                    HapticEvent(kind: .transient, time: 0, intensity: 0.55, sharpness: 0.30)
                ])
                // Hard, bright, doubled — the opposite corner from `bar`.
                : HapticPattern([
                    HapticEvent(kind: .transient, time: 0, intensity: 0.45, sharpness: 0.90),
                    HapticEvent(
                        kind: .transient, time: 0.075, intensity: 0.30, sharpness: 0.90),
                ])
            guard isTwin else { return base }
            return HapticPattern(
                [HapticEvent(kind: .transient, time: 0, intensity: 0.20, sharpness: 0.50)]
                    + base.events.map {
                        HapticEvent(
                            kind: $0.kind, time: $0.time + 0.060, intensity: $0.intensity,
                            intensityEnd: $0.intensityEnd, sharpness: $0.sharpness,
                            duration: $0.duration)
                    })

        case .bar:
            // **The only high-intensity, low-sharpness event in the game.** A dull heavy thud:
            // no give. Everything else that is strong is also bright.
            return HapticPattern([
                HapticEvent(kind: .transient, time: 0, intensity: 0.90, sharpness: 0.15)
            ])

        case .strike:
            return HapticPattern([
                HapticEvent(kind: .transient, time: 0, intensity: 0.70, sharpness: 0.95),
                HapticEvent(
                    kind: .continuous, time: 0.020, intensity: 0.35, intensityEnd: 0,
                    sharpness: 0.60, duration: HapticEnvelope.strikeTail),
            ])

        case .declare:
            return HapticPattern([
                HapticEvent(
                    kind: .continuous, time: 0, intensity: 0.15, intensityEnd: 0.55,
                    sharpness: 0.10, duration: HapticEnvelope.declareGlide)
            ])

        case .lawDeclaredCorrectly(let marks):
            // N transients, one per 80 ms, where N is the marks earned. The hand counts them.
            return HapticPattern(
                (0..<max(1, min(3, marks))).map { index in
                    HapticEvent(
                        kind: .transient, time: Double(index) * 0.080,
                        intensity: 0.50 + 0.10 * Double(index), sharpness: 0.70)
                })

        case .lawBroken:
            return HapticPattern([
                HapticEvent(kind: .transient, time: 0, intensity: 0.85, sharpness: 1.00),
                HapticEvent(
                    kind: .continuous, time: 0.020, intensity: 0.55, intensityEnd: 0,
                    sharpness: 0.75, duration: HapticEnvelope.brokenSettle),
                HapticEvent(kind: .transient, time: 0.420, intensity: 0.35, sharpness: 0.20),
            ])

        case .driftMoment:
            return HapticPattern([
                HapticEvent(
                    kind: .continuous, time: 0, intensity: 0.30, intensityEnd: 0.05,
                    sharpness: 0.25, duration: HapticEnvelope.driftSlide)
            ])

        case .streak(let step):
            return HapticPattern(
                (0..<max(1, min(5, step))).map { index in
                    HapticEvent(
                        kind: .transient, time: Double(index) * 0.060,
                        intensity: 0.30 + 0.08 * Double(index), sharpness: 0.55)
                })

        case .sieveHit:
            return HapticPattern([
                HapticEvent(kind: .transient, time: 0, intensity: 0.40, sharpness: 0.70)
            ])

        case .sieveMiss:
            return HapticPattern([
                HapticEvent(kind: .transient, time: 0, intensity: 0.25, sharpness: 0.35)
            ])

        // A sound and no feel. §13.9 ships eleven patterns, not thirteen, and these two are the
        // difference: a metronomic tick at up to three a second would be a buzz, and the page
        // being inscribed is meant to sit *underneath* everything else.
        case .sieveTick, .codexInscribe:
            return nil
        }
    }
}

/// §13.9's envelope lengths, named.
///
/// They are named rather than written at the four call sites for the reason the token layer
/// exists at all: a continuous haptic's length is a *design* number, and four copies of it drift.
/// This file is §13.9's single normative source in the same way `Tokens/` is §13's — so the
/// numbers live at the top of it, once.
public enum HapticEnvelope {
    /// The strike's tail, and the shortest continuous event in the game.
    public static let strikeTail = 0.240
    /// The Seal travelling — matched to `declare`'s 180 ms glide.
    public static let declareGlide = 0.180
    /// The law-broken settle, and the longest.
    public static let brokenSettle = 0.400
    /// DRIFT's slide, matched to the partner's 480 ms.
    public static let driftSlide = 0.480
}

/// §13.9's engine policy.
public enum HapticPolicy {
    /// Eleven patterns, precompiled on first use and cached — about 2 KB.
    public static let patternCount = 11

    /// **No Light tier.** §12.6's reasoning: a half-strength spelling of each of the eleven
    /// would be eleven more designs carrying no information the visuals do not already carry.
    /// The toggle gates the engine entirely.
    public static let hasIntensityTiers = false

    /// All calls no-op where the hardware does not support haptics — which is a real device, not
    /// a hypothetical, and the app must be complete without them (§6.4's channel independence).
    public static let degradesSilently = true
}
