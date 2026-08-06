public import Glyphs

/// §8.5's lifecycle. The transition worth naming is `primer → casting`, which carries an
/// **asserted invariant**: exactly one strip member is lit when the cast begins. If it were ever
/// two, the round would be asking the player to apply a law nobody has identified.
public enum EchoPhase: String, CaseIterable, Equatable, Sendable {
    case arming
    case priming
    case primer
    case casting
    case recalling
    case adjudicating
    case reveal
    case settled
}

extension EchoPhase {
    public enum Event: Equatable, Sendable {
        case ready
        case primingComplete
        case primerComplete(survivingMembers: Int)
        case castComplete
        case replay
        case sealed
        case adjudicated
        case revealComplete
    }

    public static func advance(_ phase: EchoPhase, on event: Event) -> EchoPhase? {
        switch phase {
        case .arming:
            if case .ready = event { return .priming }
            return nil
        case .priming:
            if case .primingComplete = event { return .primer }
            return nil
        case .primer:
            // **The invariant, enforced rather than asserted in a comment**: the cast cannot
            // begin while the strip is ambiguous. A primer that failed to separate is a round
            // that must not start, and §8.2's answer is to lengthen `m` or drop the two oldest
            // members — never to begin anyway.
            if case .primerComplete(let surviving) = event {
                return surviving == 1 ? .casting : nil
            }
            return nil
        case .casting:
            if case .castComplete = event { return .recalling }
            return nil
        case .recalling:
            switch event {
            // One replay, and the rail is **preserved**: the twin key means *do that again*,
            // not *start again*.
            case .replay: return .casting
            case .sealed: return .adjudicating
            default: return nil
            }
        case .adjudicating:
            if case .adjudicated = event { return .reveal }
            return nil
        case .reveal:
            if case .revealComplete = event { return .settled }
            return nil
        case .settled:
            return nil
        }
    }

    /// §8.3: **the ribbon stays dark during a cast.** A cast is not probing and the Loom does
    /// not log it — which is diegetic, and is the entire reason the mode has an ordering
    /// component at all.
    public static let castLogsNothing = true

    /// There is no admit ring during a cast: the player is the evaluator. That is the mode's
    /// whole claim, and it is the one thing that must never be softened by "just a hint".
    public static let castShowsNoVerdicts = true
}
