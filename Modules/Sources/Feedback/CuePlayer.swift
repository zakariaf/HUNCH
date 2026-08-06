/// Anything that can respond to a game event.
///
/// `@MainActor` on the method rather than on the protocol: the *vocabulary* is data and stays
/// nonisolated, while playing a cue happens where the frame happens.
public protocol CuePlayer: Sendable {
    @MainActor func play(_ cue: Cue)
}

/// Sound off, haptics off — and a complete implementation, not a stub.
///
/// Every verdict in the game is carried by geometry first (a ring that closes or breaks), so
/// silence costs the player redundancy and never information. That property is why this type
/// can be the default everywhere and why the tests are silent by construction.
public struct SilentCuePlayer: CuePlayer {
    public init() {}
    @MainActor public func play(_ cue: Cue) {}
}

/// Records what was asked for, in order.
///
/// **Ships in the target**, not in a test-support module: it imports no testing framework, and
/// previews and the DEBUG gallery use it to show a cue trace beside a beat.
@MainActor
public final class RecordingCuePlayer: CuePlayer {
    public private(set) var cues: [Cue] = []

    public init() {}

    public func play(_ cue: Cue) { cues.append(cue) }

    public func reset() { cues.removeAll() }
}
