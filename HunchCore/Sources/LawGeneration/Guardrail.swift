public import Glyphs
public import Laws

/// §5.3's ten guardrails, cheap → expensive, which is the order the generator runs them in.
public enum Guardrail: String, CaseIterable, Sendable {
    case satisfiable = "G1"
    case falsifiable = "G2"
    case admitWindow = "G3"
    case notSecretlyEasier = "G4"
    case noDeadTerms = "G5"
    case attributeLiveness = "G6"
    case genuinelyContextual = "G7"
    case bandFidelity = "G8"
    case novelty = "G9"
    case constructible = "G10"

    /// Cheap first. G5 is 2 rebuilds per leaf and G6 up to 24 table permutes, so both sit
    /// behind the four word-ops that reject most candidates outright.
    public static let evaluationOrder: [Guardrail] = [
        .satisfiable, .falsifiable, .admitWindow, .genuinelyContextual,
        .noDeadTerms, .attributeLiveness, .notSecretlyEasier, .bandFidelity,
        .novelty, .constructible,
    ]

    /// Two clauses are per-REQUEST rather than properties of the law, and §5.2 excludes them
    /// when defining `|H|`: G8's `targetδ` proximity and G9's novelty. G4-against-its-own-band
    /// is excluded too, and is why the index is built in ascending band order.
    public static let perRequest: Set<Guardrail> = [.novelty]
}

extension Guardrail {
    /// The guardrails that decide whether a law is a MEMBER of its band — everything §5.2
    /// counts, i.e. G1–G3, G5–G7, G10 and G8's membership clause, plus G4 against the strictly
    /// lower bands.
    ///
    /// The proximity and novelty clauses are deliberately absent: they are per-request, and
    /// including them would make `|H|` a moving number rather than a fixed one.
    public static func clearsGenerationSet(
        _ law: Law, in band: Band, excluding lower: LawSet
    ) -> Bool {
        let table = law.table
        guard table.isSatisfiable, table.isFalsifiable else { return false }  // G1, G2
        guard band.admitWindow.contains(table.admitRate) else { return false }  // G3
        if band.isContextual, table.isSecretlyStateless { return false }  // G7
        guard law.deadLeaves.isEmpty else { return false }  // G5
        guard law.hasLiveNamedAttributes else { return false }  // G6
        guard !lower.contains(table) else { return false }  // G4, strictly lower bands only
        // G8's membership clause: the canonical form's difficulty is inside the band.
        let delta = Difficulty.of(law, in: band)
        guard band.difficultyRange.contains(delta) else { return false }
        return true
    }

    /// The two per-request clauses, applied on top of the generation set.
    public static func clearsRequest(
        _ law: Law, in band: Band, targetDelta: Double, avoid: Set<UInt64>,
        proximityTolerance: Double = 0.02
    ) -> Bool {
        // G8's proximity clause.
        guard abs(Difficulty.of(law, in: band) - targetDelta) <= proximityTolerance else {
            return false
        }
        // G9 — the caller-supplied set, nothing else.
        return !avoid.contains(law.key.rawValue)
    }
}
