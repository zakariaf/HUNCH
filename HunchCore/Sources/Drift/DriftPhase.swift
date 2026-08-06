public import Glyphs
public import Laws

/// §7.4's lifecycle. PROBE's machine has one running phase; DRIFT has **two**, and the
/// transition between them is invisible.
///
/// > `runningPre` → `runningPost`: `t_hinge` recorded; **no visible change.**
///
/// That row is the mode. If any interface element changed at the hinge, the interface would be
/// announcing the change and DRIFT would measure reading rather than noticing.
public enum DriftPhase: Equatable, Sendable {
    case arming
    case priming
    case runningPre
    case runningPost
    case declaring
    case adjudicating
    case struck
    case hinge
    case settled
}

extension DriftPhase {
    public enum Event: Equatable, Sendable {
        case generated
        case firstDialCommit
        /// Triggers (a) and (c) — invisible.
        case hingeFired
        /// Trigger (b): the declaration is **accepted**, and then the floor moves.
        case capturedFirstLaw
        case declaredSecondLaw
        case declaredFirstLawAfterHinge
        case declaredWrong
        case secondStrike
        case capReached
        case revealComplete
    }

    /// No `default:` — a ninth phase or an eleventh event has to answer this table rather than
    /// inherit an answer.
    public static func advance(_ phase: DriftPhase, on event: Event) -> DriftPhase? {
        switch phase {
        case .arming:
            switch event {
            case .generated: .priming
            case .firstDialCommit, .hingeFired, .capturedFirstLaw, .declaredSecondLaw,
                .declaredFirstLawAfterHinge, .declaredWrong, .secondStrike, .capReached,
                .revealComplete:
                nil
            }
        case .priming:
            switch event {
            case .firstDialCommit: .runningPre
            case .generated, .hingeFired, .capturedFirstLaw, .declaredSecondLaw,
                .declaredFirstLawAfterHinge, .declaredWrong, .secondStrike, .capReached,
                .revealComplete:
                nil
            }
        case .runningPre:
            switch event {
            case .hingeFired, .capturedFirstLaw: .runningPost
            case .declaredWrong: .struck
            case .capReached: .hinge
            case .generated, .firstDialCommit, .declaredSecondLaw,
                .declaredFirstLawAfterHinge, .secondStrike, .revealComplete:
                nil
            }
        case .runningPost:
            switch event {
            case .declaredSecondLaw: .hinge
            case .declaredFirstLawAfterHinge, .declaredWrong: .struck
            case .capReached: .hinge
            case .generated, .firstDialCommit, .hingeFired, .capturedFirstLaw, .secondStrike,
                .revealComplete:
                nil
            }
        case .struck:
            switch event {
            case .secondStrike: .hinge
            case .hingeFired: .runningPost
            case .declaredWrong: .runningPre
            case .generated, .firstDialCommit, .capturedFirstLaw, .declaredSecondLaw,
                .declaredFirstLawAfterHinge, .capReached, .revealComplete:
                nil
            }
        case .hinge:
            switch event {
            case .revealComplete: .settled
            case .generated, .firstDialCommit, .hingeFired, .capturedFirstLaw,
                .declaredSecondLaw, .declaredFirstLawAfterHinge, .declaredWrong, .secondStrike,
                .capReached:
                nil
            }
        case .declaring, .adjudicating, .settled:
            switch event {
            case .generated, .firstDialCommit, .hingeFired, .capturedFirstLaw,
                .declaredSecondLaw, .declaredFirstLawAfterHinge, .declaredWrong, .secondStrike,
                .capReached, .revealComplete:
                nil
            }
        }
    }

    /// §7.1's decision, as a property: **DRIFT adds no controls, no chrome and no timer.** The
    /// mode sigil identifies DRIFT, never the hinge.
    public static let addsNoChrome = true
}

/// §7.6's dead-law counterexample: a **step 0** inserted before canon §4.5's selection.
public enum DeadLawCounterexample {

    /// Prefer a glyph already in the ribbon whose verdict under `L₁` differs from its verdict
    /// under `L₂`. Tie-break by most recent ribbon index, then lowest `glyphID`.
    ///
    /// It renders as the **twin ring** — the ribbon tile and the centred counterexample carry
    /// the identical glyph, one ringed admit and one ringed reject. The player has already seen
    /// that exact visual in PROBE when a twin exposed a contextual law, so *"the same thing gave
    /// two answers"* is already learned and needs no words here either.
    ///
    /// - Returns: `nil` when the disagreement set contains no ribbon member, in which case the
    ///   caller falls through to canon's ordinary rule.
    public static func select(
        first: Law, second: Law, ribbon: [Glyph], seedGlyph: Glyph
    ) -> Glyph? {
        var context = seedGlyph
        var candidates: [(index: Int, glyph: Glyph)] = []
        for (index, glyph) in ribbon.enumerated() {
            if first.admits(glyph, after: context) != second.admits(glyph, after: context) {
                candidates.append((index, glyph))
            }
            context = glyph
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.max { left, right in
            if left.index != right.index { return left.index < right.index }
            return left.glyph.id > right.glyph.id
        }?.glyph
    }

    /// §7.6: if both strikes are spent **before** the hinge fires, the loss reveal still plays
    /// the full hinge with the un-fired `L₂` at 40 % opacity — so a fast loss still teaches the
    /// mode's shape rather than looking like a PROBE round the player got wrong.
    public static let unfiredSecondLawOpacity = 0.40
}
