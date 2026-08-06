public import Glyphs
public import Laws
public import LoomFeature

/// The one place in `Modules/` that builds a `LawNode` by hand.
///
/// If an initialiser signature ever differs from what `HunchCore` ships, it is fixed HERE and
/// nowhere else — that is the whole reason a `Modules`-side support target exists, given that
/// `HunchTestSupport` is absent from `HunchCore`'s `products:` and cannot be imported.
public enum Fixtures {

    /// §12.5's fixed opening law: `shape ∈ {triangle}` at band 1. The only law written down in
    /// the GDD, so it needs no generator and no seed — which makes it the one fixture whose
    /// expected verdicts a reader can check by eye.
    public static let openingLaw = Law(
        .atom(.init(attribute: .shape, subset: triangleOnly)))

    /// §12.5's seed glyph — `glyphID` 22: hollow triangle, two pips, frost.
    public static let seedGlyph = Deck.glyph(id: 22)

    /// `RANK pips(cur) > PREV RANK pips` — the contextual law the twin and split-ring cases
    /// need, because its verdict for a glyph depends on what was probed before it.
    public static let contextualLaw = Law(
        .contextual(.init(current: .pips, comparator: .gt, previous: .pips)))

    @MainActor
    public static func round(
        law: Law = openingLaw,
        band: Band = .literal,
        seedGlyph: Glyph = seedGlyph
    ) -> Round {
        Round(
            law: law, band: band, mode: .probe, seedGlyph: seedGlyph,
            seed: 0x4855_4E43_48, targetDelta: band.difficultyRange.lowerBound)
    }

    /// `{triangle}` — bit 1 of the four, `Glyph.Shape.triangle`'s ordinal.
    ///
    /// Spelled through the failing initialiser rather than force-unwrapped: `Subset4` rejects
    /// its two degenerate values by design, and `NeverForceUnwrap` is on for this package too.
    private static let triangleOnly: Subset4 = {
        guard let subset = Subset4(rawValue: 1 << UInt8(Glyph.Shape.triangle.rawValue)) else {
            preconditionFailure("{triangle} is a legal <subset4> — §3.2")
        }
        return subset
    }()
}
