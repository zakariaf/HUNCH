public import Glyphs
public import Laws

/// The enumerated law space: every band's surviving extensions, and the exclusion set G4 tests
/// against.
///
/// Threaded explicitly rather than reached for through a `static let`. It is **not** player
/// history — it is a deterministic enumeration, byte-identical in every process, built once and
/// immutable — but reaching for it ambiently would both make it the global state §5.3 exists to
/// forbid and put a multi-second enumeration on the generator's critical path.
public struct LawIndex: Sendable {
    /// The grammar-valid, guardrail-clearing forms of each band, in enumeration order.
    public let forms: [Band: [LawNode]]
    /// Every extension in bands strictly below `band` — G4's exclusion set.
    public let lowerExtensions: [Band: LawSet]

    public init(forms: [Band: [LawNode]], lowerExtensions: [Band: LawSet]) {
        self.forms = forms
        self.lowerExtensions = lowerExtensions
    }

    /// Builds the index for `bands`, in ascending order so each band's exclusion set is
    /// complete and frozen before that band is enumerated (§5.2's well-foundedness argument).
    ///
    /// - Complexity: seconds for the six stateless bands, minutes with 5 and 7. §14.5 open
    ///   decision 4 moves this to a background build at first launch.
    public static func build(bands: [Band] = Band.allCases.filter { !$0.isContextual }) -> LawIndex
    {
        var forms: [Band: [LawNode]] = [:]
        var lowerExtensions: [Band: LawSet] = [:]
        var accumulated = LawSet()

        for band in bands.sorted(by: { $0.rawValue < $1.rawValue }) {
            lowerExtensions[band] = accumulated
            var surviving: [LawNode] = []
            var seen = LawSet()
            for node in BandEnumeration.forms(for: band) {
                guard node.structuralFault == nil else { continue }
                let law = Law(node)
                guard Guardrail.clearsGenerationSet(law, in: band, excluding: accumulated) else {
                    continue
                }
                guard seen.insert(law.table) else { continue }
                surviving.append(node.renderedNormalForm)
            }
            forms[band] = surviving
            for table in seen.tables { accumulated.insert(table) }
        }
        return LawIndex(forms: forms, lowerExtensions: lowerExtensions)
    }

    public func forms(for band: Band) -> [LawNode] { forms[band] ?? [] }
    public func lowerExtensions(for band: Band) -> LawSet { lowerExtensions[band] ?? LawSet() }
}

extension LawIndex {
    /// The δ range a band's laws can actually reach.
    ///
    /// This is NOT `band.difficultyRange`. §5.1's modifiers are bounded above by 0.124, but
    /// several are structurally zero for a whole family — every band-1 law is a single atom, so
    /// `m1` is zero (leafCount == minLeaves) and `m2` is zero (an atom's marginal deficit is
    /// zero *by definition*: vary that attribute and the lamp answers). Band 1 can therefore
    /// only reach the bottom third of its nominal range.
    ///
    /// The serving policy must clamp its target into this range, or the generator burns all 200
    /// attempts and falls back to the anchor every single time — which is silent, because the
    /// anchor is a perfectly good law.
    public func achievableDifficultyRange(for band: Band) -> ClosedRange<Double> {
        let deltas = forms(for: band).map { Difficulty.of(Law($0), in: band) }
        guard let low = deltas.min(), let high = deltas.max() else {
            return band.centre...band.centre
        }
        return low...high
    }

    /// The target clamped into what the band can reach, keeping the caller's intent where it is
    /// satisfiable.
    public func servableTarget(_ requested: Double, for band: Band) -> Double {
        let range = achievableDifficultyRange(for: band)
        return min(max(requested, range.lowerBound), range.upperBound)
    }
}
