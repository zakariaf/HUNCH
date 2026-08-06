public import Glyphs
public import Laws

/// §4.3's Assay: a 16 × 16 micro-grid of the **entire deck** in canonical `glyphID` order, so
/// its geometry becomes memorable and the draft's extension becomes a constellation.
///
/// It gives three things with no text: the draft's admit rate as density, unsatisfiability (all
/// dark) and tautology (all lit) instantly, and — for a contextual draft — the extension
/// **conditioned on the pinned `prev`**, which is the clearest non-verbal statement of what
/// "contextual" means, because scrubbing the pin morphs the picture.
public struct Assay: Equatable, Sendable {
    public static let side = 16
    public static let cellCount = 256

    /// Which glyphs the draft admits, given the pin.
    public let lit: Bitboard256

    /// The glyph the extension is conditioned on. **Defaults to the seed glyph** — the round's
    /// own `prev(1)` — so the first thing a player sees is the slice that their next probe will
    /// actually be judged against.
    public let pinned: Glyph

    public init(lit: Bitboard256, pinned: Glyph) {
        self.lit = lit
        self.pinned = pinned
    }

    /// **A slice of the pair table, never a projection of it.**
    ///
    /// For a draft admitting `p` of the 65,536 pairs the lit count here is the row count for the
    /// pinned `prev`, which in general differs from `p / 256`. The unconditional marginal
    /// projection is a different picture with a different job — it is what a Codex page
    /// thumbnail renders — and quoting one for the other makes a contextual draft look like a
    /// stateless one, which is the single fact the tool exists to make visible.
    public static func live(for law: Law, pinned: Glyph) -> Assay {
        Assay(lit: law.table.row(after: pinned), pinned: pinned)
    }

    public var litCount: Int { lit.count }

    /// Density, 0…1 — what the constellation reads as before anything is counted.
    public var admitRate: Double { Double(litCount) / Double(Self.cellCount) }

    /// All dark. The Seal is barred for exactly this (§4.3), and the picture says why with no
    /// message: the draft admits nothing at all.
    public var isUnsatisfiable: Bool { litCount == 0 }

    /// All lit — a draft that admits everything is equally constant and equally barred.
    public var isTautology: Bool { litCount == Self.cellCount }

    public func isLit(_ id: Int) -> Bool { lit.contains(id) }

    /// Row-major in canonical `glyphID` order: `id = row * 16 + column`.
    public static func position(of id: Int) -> (row: Int, column: Int) {
        (row: id / side, column: id % side)
    }
}
