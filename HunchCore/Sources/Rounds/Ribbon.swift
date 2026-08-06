public import Glyphs
public import Laws

/// One probe and its frozen verdict.
public struct ProbeRecord: Hashable, Sendable, Codable {
    public var index: UInt8
    public var glyphID: UInt8
    public var verdict: Verdict
    /// A twin is an **adjacent** re-probe only — only adjacency holds the context fixed, which
    /// is the twin's entire purpose (§6.11 edge case 3).
    public var isTwin: Bool

    public init(index: UInt8, glyphID: UInt8, verdict: Verdict, isTwin: Bool) {
        self.index = index
        self.glyphID = glyphID
        self.verdict = verdict
        self.isTwin = isTwin
    }

    public var glyph: Glyph { Deck.glyph(id: Int(glyphID)) }
}

/// The visible probe log. §3.5's semantics live here: `prev` is the previously *probed* glyph,
/// so the ribbon is a chain and every verdict is a pure function of the visible sequence.
public struct Ribbon: Hashable, Sendable {
    public let seedGlyph: Glyph
    public private(set) var probes: [ProbeRecord] = []

    public init(seedGlyph: Glyph) { self.seedGlyph = seedGlyph }

    public var count: Int { probes.count }
    public var isEmpty: Bool { probes.isEmpty }

    /// The context for the next probe: the last probed glyph, or the seed at position 0.
    public var currentContext: Glyph { probes.last?.glyph ?? seedGlyph }

    /// Appends a probe, computing its verdict against `law` under §3.5.
    @discardableResult
    public mutating func probe(_ glyph: Glyph, against law: Law) -> ProbeRecord {
        let previous = currentContext
        let record = ProbeRecord(
            index: UInt8(probes.count),
            glyphID: UInt8(glyph.id),
            verdict: law.verdict(for: glyph, after: previous),
            // Adjacent re-probe only.
            isTwin: probes.last.map { $0.glyphID == UInt8(glyph.id) } ?? false)
        probes.append(record)
        return record
    }

    /// Re-derives every verdict from the stored law and the glyph ids alone.
    ///
    /// This is what makes a resume a live evaluator check over the whole transcript rather than
    /// a trusting reload: tampering with the probe list achieves nothing, because the law
    /// re-derives every verdict (§6.10).
    public static func rehydrate(seedGlyph: Glyph, glyphIDs: [UInt8], law: Law) -> Ribbon {
        var ribbon = Ribbon(seedGlyph: seedGlyph)
        for id in glyphIDs { ribbon.probe(Deck.glyph(id: Int(id)), against: law) }
        return ribbon
    }

    /// A twin pair whose two verdicts DIFFER is §6.6 layer 4's rendered contradiction — the
    /// same glyph giving two answers, which is how a player discovers contextuality at all.
    public var hasSplitTwin: Bool {
        for (index, record) in probes.enumerated() where record.isTwin && index > 0 {
            if probes[index - 1].verdict != record.verdict { return true }
        }
        return false
    }
}
