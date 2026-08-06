public import Glyphs

public import Rounds

/// One tile on the ribbon, fully decided before anything is drawn.
///
/// **The model is the whole component; the view is thin over it.** Every rule the ribbon
/// carries — which tile wears the ghost mark, which pair is a twin, whether a twin's ring is
/// doubled or split, whether a link arc may be drawn at all — is a fact about the transcript
/// rather than about pixels, and each is a line of the design that a drawing could quietly
/// lose. Deciding them here means they can be asserted on the host, with no simulator and no
/// snapshot.
public nonisolated struct RibbonTileModel: Equatable, Sendable, Identifiable {

    /// How the tile's verdict ring draws. A ribbon-level vocabulary that maps onto
    /// `VerdictRing.State`; the ribbon never reaches into the mark's own cases.
    public enum Ring: Equatable, Sendable {
        case closed
        case broken
        /// An adjacent repeat whose two verdicts **agree**.
        case doubled
        /// An adjacent repeat whose two verdicts **differ** — one half open, one half closed,
        /// on a single drawing of a single glyph. §6.6 layer 4, and the clearest wordless
        /// statement of contextuality in the game.
        case split
    }

    /// The chain index. The seed is 0 and probe *n* is *n*, which is also `load(ribbonIndex:)`'s
    /// numbering.
    public let id: Int
    public let glyph: Glyph
    /// `nil` for the seed: it was primed, not probed (§6.4).
    public let verdict: Verdict?
    public let isSeed: Bool
    /// The trailing-most tile, always. It **is** the Loom's memory — `prev` — and §6.6 layer 2
    /// wants that address permanently visible. At probe 0 that is the seed; after probe 1 it is
    /// probe 1, which also carries a verdict ring. Both marks on one tile is correct.
    public let wearsGhostMark: Bool
    public let ring: Ring?
    /// Shared by both members of a twin pair; `nil` otherwise.
    public var twinGroup: Int?
    /// False under verdict sort: once the chain order is not the layout order, an arc would
    /// assert an adjacency that is not on screen.
    public var drawsLinkArc: Bool

    /// §7.3's seam marker — a vertical hairline carrying a 20 pt silhouette of the accepted tile
    /// layout, written at the index where a DRIFT round's trigger (b) fired.
    ///
    /// **It appears only for trigger (b)**, where the player already knows something happened:
    /// they were just told they were right. The other two triggers leave no trace at all, which
    /// is the mode — an interface that marked every hinge would be announcing the change, and
    /// DRIFT would measure reading rather than noticing.
    public var carriesSeamMarker = false

    public init(
        id: Int, glyph: Glyph, verdict: Verdict?, isSeed: Bool, wearsGhostMark: Bool,
        ring: Ring?, twinGroup: Int?, drawsLinkArc: Bool, carriesSeamMarker: Bool = false
    ) {
        self.carriesSeamMarker = carriesSeamMarker
        self.id = id
        self.glyph = glyph
        self.verdict = verdict
        self.isSeed = isSeed
        self.wearsGhostMark = wearsGhostMark
        self.ring = ring
        self.twinGroup = twinGroup
        self.drawsLinkArc = drawsLinkArc
    }

    /// The chain: the seed, then one tile per probe in order.
    ///
    /// - Parameter seamMarkerIndex: a DRIFT round's trigger-(b) index, or `nil`. PROBE always
    ///   passes `nil`, which is why the parameter is defaulted rather than threaded: the seam is
    ///   DRIFT's and the ribbon is everyone's.
    public static func tiles(
        probes: [ProbeRecord], seedGlyph: Glyph, seamMarkerIndex: Int? = nil
    ) -> [RibbonTileModel] {
        let lastIndex = probes.count
        var tiles: [RibbonTileModel] = [
            RibbonTileModel(
                id: 0, glyph: seedGlyph, verdict: nil, isSeed: true,
                // §6.11 case 2: the seed never gains a verdict ring, however long the round runs.
                wearsGhostMark: lastIndex == 0, ring: nil, twinGroup: nil, drawsLinkArc: false)
        ]

        for (offset, probe) in probes.enumerated() {
            let index = offset + 1
            // `isTwin` is E07·T08's and means **adjacent** repeat. §6.11 case 3: a non-adjacent
            // repeat is a normal probe and must not gain a doubled ring — the doubling says
            // "these two are one experiment", which is false across an intervening probe.
            let isTwin = probe.isTwin
            let previous = offset > 0 ? probes[offset - 1] : nil
            let ring: Ring =
                if isTwin, let previous {
                    previous.verdict == probe.verdict ? .doubled : .split
                } else {
                    probe.verdict == .admit ? .closed : .broken
                }
            if isTwin, let group = tiles.indices.last {
                tiles[group] = tiles[group].withTwinGroup(index - 1)
            }
            tiles.append(
                RibbonTileModel(
                    id: index, glyph: probe.glyph, verdict: probe.verdict, isSeed: false,
                    wearsGhostMark: index == lastIndex, ring: ring,
                    twinGroup: isTwin ? index - 1 : nil, drawsLinkArc: true,
                    carriesSeamMarker: index == seamMarkerIndex))
        }
        return tiles
    }

    /// §6.2's second spool order: admits block first, rejects second, **chain order preserved
    /// within each block**, link arcs dropped, twin pairs keeping their rings.
    ///
    /// A stable partition rather than a sort: any comparator over the verdict alone would be
    /// free to reorder within a block, and the within-block chain order is the only thing that
    /// still lets a player read the sorted ribbon as a history.
    public static func verdictSorted(_ tiles: [RibbonTileModel]) -> [RibbonTileModel] {
        let seeds = tiles.filter { $0.verdict == nil }
        let admits = tiles.filter { $0.verdict == .admit }
        let rejects = tiles.filter { $0.verdict == .reject }
        return (seeds + admits + rejects).map { $0.withoutLinkArc() }
    }

    func withTwinGroup(_ group: Int) -> RibbonTileModel {
        var tile = self
        tile.twinGroup = group
        return tile
    }

    func withoutLinkArc() -> RibbonTileModel {
        var tile = self
        tile.drawsLinkArc = false
        return tile
    }
}

extension [RibbonTileModel] {
    /// The tile the ribbon is pinned to. Always the trailing-most one: the ribbon re-pins after
    /// every verdict, so the newest evidence is where the eye already is.
    public var pinnedIndex: Int { Swift.max(0, count - 1) }
}

/// Where the tiles sit: one lane that scrolls, or two that wrap with a return elbow.
///
/// Lanes follow the **region**, not the device name — `PlaySurfaceLayout` supplies both numbers.
/// Dropping the elbow on a wrap makes a two-lane ribbon read as two unrelated rows, and
/// adjacency is the ribbon's only structural information.
public nonisolated struct RibbonLayoutModel: Equatable, Sendable {
    public let tiles: [RibbonTileModel]
    public let lanes: Int
    public let perLane: Int

    public init(tiles: [RibbonTileModel], lanes: Int, perLane: Int) {
        self.tiles = tiles
        self.lanes = lanes
        self.perLane = perLane
    }

    /// A one-lane ribbon scrolls, so every tile is on lane 0 however many there are.
    public func lane(of index: Int) -> Int {
        guard lanes > 1, perLane > 0 else { return 0 }
        return Swift.min(lanes - 1, index / perLane)
    }

    /// True where the chain leaves one lane for the next, which is where the return elbow is
    /// drawn. Never true in a one-lane layout: it scrolls, it does not wrap.
    public func wrapsAfter(index: Int) -> Bool {
        guard lanes > 1, perLane > 0, index >= 0, index + 1 < tiles.count else { return false }
        return lane(of: index) != lane(of: index + 1)
    }
}
