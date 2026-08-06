public import Glyphs
public import Laws

/// §4.3's **evidence overlay**: probed glyphs ringed, and any cell the draft gets *wrong*
/// against the transcript flashed.
///
/// It unlocks at **band 4**, not band 1. A free consistency check trivialises the low bands,
/// where the reasoning *is* the game; from band 4 up nobody can hold a 65,536-entry pair table
/// in their head and the tool is load-bearing rather than a shortcut.
public struct AssayEvidence: Equatable, Sendable {

    /// §4.3's gate, plus the two ways it opens early. Both are deliberate: the Anomaly is one
    /// shared round a day and is meant to be a different experience, and §10.7's floor rescue
    /// opens the tool **permanently** for a player the ladder has failed.
    public static func isUnlocked(
        band: Band, isAnomaly: Bool = false, floorRescueGranted: Bool = false
    ) -> Bool {
        band >= .relational || isAnomaly || floorRescueGranted
    }

    /// Glyphs already probed, at the pinned context.
    public let probed: Bitboard256
    /// Cells where the draft and the transcript **disagree** — the draft admits a glyph the Loom
    /// rejected, or rejects one it admitted.
    public let contradicted: Bitboard256

    public init(probed: Bitboard256, contradicted: Bitboard256) {
        self.probed = probed
        self.contradicted = contradicted
    }

    public static let none = AssayEvidence(probed: .empty, contradicted: .empty)

    /// - Parameter transcript: `(glyph, previous, verdict)` per probe. `previous` matters: a
    ///   probe judged after a different `prev` is evidence about a *different row*, and folding
    ///   it into this row would show a contradiction the player has not actually created.
    public static func overlay(
        draft: Law, pinned: Glyph, transcript: [(glyph: Glyph, previous: Glyph, verdict: Verdict)]
    ) -> AssayEvidence {
        var probed = Bitboard256.empty
        var contradicted = Bitboard256.empty
        for entry in transcript where entry.previous == pinned {
            probed.insert(entry.glyph.id)
            let draftAdmits = draft.admits(entry.glyph, after: entry.previous)
            if Verdict(admits: draftAdmits) != entry.verdict {
                contradicted.insert(entry.glyph.id)
            }
        }
        return AssayEvidence(probed: probed, contradicted: contradicted)
    }

    public var isConsistent: Bool { contradicted.isEmpty }
}
