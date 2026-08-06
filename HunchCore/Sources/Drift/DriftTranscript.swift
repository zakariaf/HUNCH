public import Glyphs
public import Laws

/// §7.8's transcript metrics, derived at `settled`.
///
/// **None is rendered, spoken, or stored as a displayable value.** A number attached to *how
/// long you were wrong* is the one piece of feedback in this game that would read as a verdict
/// on the player rather than on the declaration — so the only outward expression is the
/// Profile's Flexibility vertex, a distance on a morphing shape with no axis labels.
public struct DriftTranscript: Equatable, Sendable {

    /// Probe index at which `L₂` took force.
    public let hinge: Int
    /// The first probe after the hinge whose verdict is inconsistent with `L₁` — **the first
    /// moment the change is observable**. Often well after the hinge, because most glyphs agree
    /// under both laws, which is precisely why noticing is hard.
    public let evidence: Int?
    /// The first probe after `evidence` lying inside the disagreement set.
    public let recover: Int?
    /// The probe index at which the round was sealed.
    public let seal: Int?
    /// Whether any post-hinge declaration's extension equalled `L₁`'s.
    public let deadDeclaration: Bool

    public init(
        hinge: Int, evidence: Int?, recover: Int?, seal: Int?, deadDeclaration: Bool
    ) {
        self.hinge = hinge
        self.evidence = evidence
        self.recover = recover
        self.seal = seal
        self.deadDeclaration = deadDeclaration
    }

    /// **Cling** — probes spent inside the agreement set after the first contradiction. Their
    /// verdicts are equally consistent with the dead law and the live one: pure confirmation,
    /// **zero bits**. This is the behaviour DRIFT exists to produce and it has no analogue in
    /// PROBE, where such probes do not exist.
    public var cling: Int? {
        guard let recover, let evidence else { return nil }
        return recover - evidence
    }

    /// **Re-declaration latency** — canon's Flexibility quantity.
    public var redeclarationLatency: Int? {
        guard let seal, let evidence else { return nil }
        return seal - evidence
    }

    /// What DRIFT emits at `settled`. §11.9's table is the **single normative** definition of
    /// what becomes a Flexibility increment; there is no second definition here, no EWMA
    /// constant and no per-mode α. `cling` is retained for the harness only and feeds no axis.
    public struct Emission: Equatable, Sendable {
        public let redeclarationLatency: Int?
        public let recoveryAllowance: Int
        public let deadDeclaration: Bool
    }

    public func emission(recoveryAllowance: Int) -> Emission {
        Emission(
            redeclarationLatency: redeclarationLatency, recoveryAllowance: recoveryAllowance,
            deadDeclaration: deadDeclaration)
    }

    /// Derive the metrics from the transcript itself. The chain of contexts matters: a probe's
    /// verdict under either law depends on what preceded it, and the hinge does not reset it.
    public static func derive(
        probes: [Glyph], seedGlyph: Glyph, hinge: Int, first: Law, second: Law,
        sealedAt: Int?, deadDeclaration: Bool
    ) -> DriftTranscript {
        var context = seedGlyph
        var evidence: Int?
        var recover: Int?

        for (index, glyph) in probes.enumerated() {
            let underFirst = first.admits(glyph, after: context)
            let underSecond = second.admits(glyph, after: context)
            if index > hinge, underFirst != underSecond {
                if evidence == nil {
                    evidence = index
                } else if recover == nil {
                    recover = index
                }
            }
            context = glyph
        }
        // A probe that is itself the first contradiction is both the evidence and, if nothing
        // later disagrees, never recovered from — `cling` stays nil rather than reading zero,
        // because "did not recover" and "recovered instantly" are opposite facts.
        return DriftTranscript(
            hinge: hinge, evidence: evidence, recover: recover, seal: sealedAt,
            deadDeclaration: deadDeclaration)
    }
}
