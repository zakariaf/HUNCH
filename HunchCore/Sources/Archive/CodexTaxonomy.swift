public import Foundation

public import Glyphs
public import Laws

/// §11.2's three levels — **band → skeleton → canonical key** — all derived from structures
/// canon already defines, all textless.
///
/// Date is **not** a browsing axis. It is one field on a page and one facet, because browsing by
/// when you found something makes the Codex a log, and §11.4's whole argument is that it is a
/// map.
public enum CodexTaxonomy {

    /// Eight shelves, no more, ever — canon locks exactly one family per band, so a shelf **is**
    /// a family and a family is a conceptual move.
    public static let shelves = Band.allCases

    /// §11.4: a shelf is sealable exactly when `|H| ≤ 512`, which is precisely where a full slot
    /// map is renderable and a real terminal state is reachable in tens of hours rather than
    /// thousands.
    public static let slotMapCeiling = 512

    public static func isSealable(_ band: Band) -> Bool {
        band.population <= slotMapCeiling
    }

    /// The three sealable shelves — bands 1, 3 and 8 — and their 485 pages, which is the whole
    /// completion state. There is no global 100 %, no prestige and no reset-for-a-star.
    public static var sealableShelves: [Band] { shelves.filter(isSealable) }

    public static var sealablePages: Int {
        sealableShelves.reduce(0) { $0 + $1.population }
    }

    /// §11.4's accretion-shelf fill: `log₂(1+n) / log₂(1+|H|)`, with inscribed notches. Log
    /// because a linear arc on a 10,314-law shelf never visibly moves, and an arc that never
    /// moves is an arc that says nothing.
    public static func accretionFill(found: Int, of population: Int) -> Double {
        guard population > 0 else { return 0 }
        return log2(1 + Double(found)) / log2(1 + Double(population))
    }

    public static let accretionNotches = [8, 32, 128, 512, 2_048, 8_192]

    /// §11.2's within-section order: `(attrOrdinal, cmpOrdinal, subsetBitmask)` in canonical
    /// `fill → shape → pips → hue` order. **Deterministic, so a law's slot never moves** — which
    /// is what makes "visible absence" mean anything: a hole that wandered would be a hole
    /// nobody could learn.
    public struct CanonicalKey: Comparable, Hashable, Sendable {
        public let attribute: Int
        public let comparator: Int
        public let payload: Int

        public init(attribute: Int, comparator: Int, payload: Int) {
            self.attribute = attribute
            self.comparator = comparator
            self.payload = payload
        }

        public static func < (lhs: CanonicalKey, rhs: CanonicalKey) -> Bool {
            (lhs.attribute, lhs.comparator, lhs.payload)
                < (rhs.attribute, rhs.comparator, rhs.payload)
        }
    }
}

/// §11.2's thumbnail: **the extension, not the syntax.** A 16 × 16 deck grid in `glyphID` order —
/// the Assay signature the player already knows.
///
/// Two consequences fall out of that choice: no two thumbnails can collide, because the
/// extension *is* identity; and a filling shelf becomes a wall of constellations whose texture
/// is readable, because canonical-key adjacency puts near-neighbours in extension space side by
/// side.
public enum ExtensionThumbnail {

    /// Contextual laws project: cell *i* carries the fraction of the 256 `prev` values under
    /// which glyph *i* is admitted, quantised to four levels drawn as **hollow / dotted /
    /// striped / solid** — the fill ink-density ladder from §2, reused, monotone, colour-free.
    ///
    /// The ladder is reused rather than invented because the player has already learned that
    /// more ink means more, on a surface where it meant exactly that.
    public static func level(fraction: Double) -> Glyph.Fill {
        switch fraction {
        case ..<0.25: .hollow
        case ..<0.50: .dotted
        case ..<0.75: .striped
        default: .solid
        }
    }

    /// The marginal projection: for each of the 256 glyphs, the fraction of contexts admitting
    /// it. A stateless law's projection is its own extension at 0 or 1, so the same drawing
    /// serves both arities without a branch at the call site.
    public static func projection(of law: Law) -> [Double] {
        switch law.table.arity {
        case .stateless:
            let row = law.table.row(after: Deck.glyph(id: 0))
            return (0..<256).map { row.contains($0) ? 1 : 0 }
        case .contextual:
            var counts = [Int](repeating: 0, count: 256)
            for previous in Deck.all {
                let row = law.table.row(after: previous)
                for id in 0..<256 where row.contains(id) { counts[id] += 1 }
            }
            return counts.map { Double($0) / 256 }
        }
    }
}
