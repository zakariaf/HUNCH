public import Foundation

public import Glyphs
public import Tokens

/// §9.5's lifecycle. Two things about it are unusual and both are deliberate: the reach boundary
/// crosses with **no visible cue**, and abandoning is the only two-tap action in the game.
public enum SievePhase: Equatable, Sendable {
    case arming
    case priming
    case streaming(SieveStream.Reach)
    case paused
    case fouling
    case reveal
    case settled
}

extension SievePhase {
    public enum Event: Equatable, Sendable {
        case built
        case primed
        case reachChanged(SieveStream.Reach)
        case paused
        case resumed
        case abandonConfirmed
        case thirdFoul
        case streamResolved
        case freezeComplete
        case revealComplete
    }

    public static func advance(_ phase: SievePhase, on event: Event) -> SievePhase? {
        switch (phase, event) {
        case (.arming, .built): .priming
        case (.priming, .primed): .streaming(.tell)
        case (.streaming, .reachChanged(let reach)): .streaming(reach)
        case (.streaming, .paused): .paused
        case (.paused, .resumed): .streaming(.body)
        // The **only** two-tap action in the game, and it is reachable only from a stopped
        // stream — a confirmation on a moving conveyor would be a confirmation nobody reads.
        case (.paused, .abandonConfirmed): .reveal
        case (.streaming, .thirdFoul): .fouling
        case (.fouling, .freezeComplete): .reveal
        case (.streaming, .streamResolved): .reveal
        case (.reveal, .revealComplete): .settled
        default: nil
        }
    }

    /// §9.5: resuming replays the last three resolved glyphs at `r₀` before continuing. A stream
    /// that resumed at full speed would charge the player for the pause.
    public static let runUpGlyphs = 3

    /// §9.5: the reach boundary crosses with **no visible cue**. The composition changes and the
    /// player is not told, because being told would turn the run-out's fine discrimination into
    /// an announced exam.
    public static let reachChangeIsInvisible = true

    /// §9.5: the stream halts mid-lane for 400 ms on the third foul.
    public static let foulFreeze = Dur.sieveFoulFreeze
}

/// §9.8's void allowance. A terminated run is not automatically a loss — but it is not free
/// either, and the third one is scored.
public enum SieveVoid {
    /// Consecutive terminated runs that are **not** scored.
    public static let allowance = 2

    public static func isScored(consecutiveVoids: Int) -> Bool {
        consecutiveVoids > allowance
    }

    /// §9.8 and §10.7: a deliberately abandoned run **is** scored, as a foul-out at the last
    /// resolved glyph — because there the exit is a confirmed two-tap choice rather than an
    /// interruption, and the distinction between the two is the whole reason the confirmation
    /// exists.
    public static let abandonIsScored = true
}
