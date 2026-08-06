public import Foundation

public import Glyphs

/// §13.10's element map, as a value.
///
/// It exists because the table is the contract: every control has a trait, a label and a value,
/// and "the whole Bench is operable with rotor plus single-finger double-tap" is only true if no
/// element is missing one. A view that forgets a label ships an unlabelled button, which
/// VoiceOver reads as its own frame position.
public enum AccessibilityElement: String, CaseIterable, Hashable, Sendable {
    case throat
    case ribbonTile
    case dialRamp
    case dialCell
    case probeKey
    case twinKey
    case probeTally
    case benchHandle
    case paletteStamp
    case rail
    case rampTile
    case rampCell
    case bridgeSocket
    case ghostToggle
    case wedge
    case coupler
    case forkDock
    case tallyToggle
    case counterDial
    case assay
    case seal
    case echoPrimer
    case echoRail
    case echoTrayTile
    case sieveGate
    case sieveTail

    public struct Traits: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let button = Traits(rawValue: 1 << 0)
        public static let image = Traits(rawValue: 1 << 1)
        public static let staticText = Traits(rawValue: 1 << 2)
        public static let updatesFrequently = Traits(rawValue: 1 << 3)
        public static let adjustable = Traits(rawValue: 1 << 4)
        public static let container = Traits(rawValue: 1 << 5)
        public static let selected = Traits(rawValue: 1 << 6)
    }

    public var traits: Traits {
        switch self {
        case .throat: [.image, .updatesFrequently, .adjustable]
        case .ribbonTile, .probeKey, .twinKey, .benchHandle, .paletteStamp, .bridgeSocket,
            .wedge, .coupler, .echoTrayTile, .sieveGate:
            .button
        case .dialCell, .rampCell, .ghostToggle, .tallyToggle: [.button, .selected]
        case .dialRamp, .rail, .rampTile, .forkDock, .echoRail, .echoPrimer, .sieveTail:
            .container
        case .probeTally: [.staticText, .updatesFrequently]
        case .counterDial: .adjustable
        case .assay: [.image, .updatesFrequently]
        case .seal: .button
        }
    }

    /// Custom actions, which is how a gesture the design rules out is still reachable. The
    /// **only** non-tap in the declaration UI is the rail's trailing swipe, and it has one.
    public var customActions: [String] {
        switch self {
        case .ribbonTile: ["Load into the Dial"]
        case .rail: ["Clear rail"]
        case .wedge, .coupler: ["Cycle"]
        case .assay: ["Inspect", "Read by attribute"]
        case .echoRail: ["Return to the tray"]
        case .sieveGate: ["Admit"]
        default: []
        }
    }

    /// Every element carries a label. There is no case that does not, and that is the point.
    public var hasLabel: Bool { true }
}

/// §13.10's four custom rotors — **and there is no fifth.**
public enum AccessibilityRotor: String, CaseIterable, Hashable, Sendable {
    /// Rail 1, rail 2, coupler, Seal — cuts a full declaration traversal from ~22 gestures to
    /// ~16, which is the single largest structural win on the Bench.
    case rails
    /// Jumps between the Dial's four ramps.
    case attributes
    /// Steps backward through the ribbon, newest first, announcing glyph and verdict.
    case probes
    /// **Exists only after a strike**, with two stops: the counterexample glyph and the nearest
    /// ribbon tile it was chosen against. A rotor that was always present would be a rotor that
    /// is empty most of the time, which is a dead swipe.
    case counterexample

    public var isAlwaysAvailable: Bool { self != .counterexample }

    public var stopCount: Int? {
        switch self {
        case .rails: 4
        case .attributes: 4
        case .probes: nil  // as many as the ribbon holds
        case .counterexample: 2
        }
    }
}

/// §13.10's announcement order — **verdict → evidence → bookkeeping** — so a fast player can
/// move on after two words.
public enum AnnouncementOrder {
    public enum Stage: Int, CaseIterable, Comparable, Sendable {
        case verdict
        case evidence
        case bookkeeping

        public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Verdicts interrupt. Anything queued behind a verdict would arrive after the player had
    /// already acted on it.
    public static let verdictIsHighPriority = true
}

/// §13.10's Magic Tap: **Probe on the Dial, Seal on the Bench** — the single largest VoiceOver
/// win in the app, because it collapses the most frequent action to one gesture from anywhere.
public enum MagicTap {
    public enum Action: Equatable, Sendable {
        case probe
        case seal
        case none
    }

    public static func action(isBenchOpen: Bool, isSealBarred: Bool) -> Action {
        guard isBenchOpen else { return .probe }
        // A Magic Tap on a barred Seal does nothing rather than firing the bar's pulse: the
        // pulse says *which rail*, and a VoiceOver player cannot see a rail pulse.
        return isSealBarred ? .none : .seal
    }
}
