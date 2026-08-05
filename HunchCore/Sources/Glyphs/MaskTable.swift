/// Every predicate the grammar can name, precomputed as a mask over the deck.
///
/// §3.6: *never walk the AST per glyph.* A law's extension is assembled from these in a
/// handful of word operations, which is what makes the build budget 20 ns rather than 256
/// evaluations. Forms, not distinct extensions — all 1,214 aggregates are here, not only the
/// 337 in the admit window, because the player may build any of them on the Tally.
public struct MaskTable: Sendable {

    /// The one resident copy. `static let` of an immutable `Sendable` value — rung 1 of
    /// `05 R50`, named in `08 §4` beside `Deck.all`, and not a singleton in the sense the
    /// brief bans: there is no mutable state and nothing to substitute.
    ///
    /// Lazily initialised by `swift_once` on first touch, so the cost lands on whichever
    /// caller gets there first. If it ever approaches a frame, §3.6's named fix is that the
    /// aggregates can be built from the atom masks — not that this becomes mutable.
    public static let resident = MaskTable()

    public let atomMasks: [Bitboard256]  // 56  = 4 attributes × 14 subsets
    public let relationalMasks: [Bitboard256]  // 36  = 6 pairs × 6 comparators
    public let contextualRowMasks: [Bitboard256]  // 384 = 96 forms × 4 rows
    public let countMasks: [Bitboard256]  // 1,204
    public let parityMasks: [Bitboard256]  // 10  = 5 attribute sets × 2 bits

    /// The five legal `<attrSet>` masks in ascending order: a subset of the four attributes
    /// with `|set| ≥ 3`. Bit *v* means the attribute with raw value *v*.
    public static let attributeSets: [UInt8] = [0b0111, 0b1011, 0b1101, 0b1110, 0b1111]

    /// Offsets into `countMasks`, attribute-set-major. A 3-attribute set has 14 subsets × 14
    /// countSets = 196; the 4-attribute set has 14 × 30 = 420.
    ///     4 × 196 + 420 = 1,204     ✓ §3.3
    public static let countSetOffsets: [Int] = [0, 196, 392, 588, 784]

    /// The mask payload in bytes — §3.6's ≈54 KB. Excludes the five array headers, which is
    /// what the design's table counts.
    public var byteCount: Int {
        (atomMasks.count + relationalMasks.count + contextualRowMasks.count
            + countMasks.count + parityMasks.count) * 32
    }

    // ── Index layouts ────────────────────────────────────────────────────────────────────
    // Every layout is arithmetic rather than a search, and every ordering is one already fixed
    // elsewhere. A mask that is correct but filed under the wrong index produces a law whose
    // extension is plausible and wrong, which is why each is asserted a bijection.

    /// Attribute-major, subset ascending. `<subset4>` is a bitmask where bit *v* means the
    /// value with ordinal *v*; `0000` and `1111` are forbidden by the BNF, so the 14 legal
    /// values are `1...14` and the index is dense.
    public static func atomIndex(_ attribute: Glyph.Attribute, subset: UInt8) -> Int {
        precondition(
            (1...14).contains(subset),
            "subset 0b\(String(subset, radix: 2)) is ∅ or full — §3.2 forbids both")
        return Int(attribute.rawValue) * 14 + Int(subset) - 1
    }

    /// The standard strictly-upper-triangular index for n = 4, over the six unordered pairs
    /// `(fill,shape) (fill,pips) (fill,hue) (shape,pips) (shape,hue) (pips,hue)`.
    public static func pairOrdinal(_ a: Int, _ b: Int) -> Int {
        precondition(a < b, "relational operands must be in canonical order")
        return a * (2 * 4 - a - 1) / 2 + (b - a - 1)
    }

    /// Accepts either operand order and normalises with `Comparator.flipped` — §3.4 step 3's
    /// rule made total, so `relational(.pips, .lt, .shape)` and `relational(.shape, .gt, .pips)`
    /// are one form and one index.
    public static func relationalIndex(
        _ a: Glyph.Attribute, _ comparator: Comparator, _ b: Glyph.Attribute
    ) -> Int {
        precondition(a != b, "§3.2 forbids RANK a ⋈ RANK a — it is constant")
        let (lo, hi, cmp) =
            Int(a.rawValue) < Int(b.rawValue)
            ? (Int(a.rawValue), Int(b.rawValue), comparator)
            : (Int(b.rawValue), Int(a.rawValue), comparator.flipped)
        return pairOrdinal(lo, hi) * 6 + Int(cmp.rawValue)
    }

    /// `a` and `b` **may be equal** here — `RANK pips(cur) > PREV RANK pips` is §5.2's
    /// entry-level contextual law and must exist — which is why this is 4 × 4 and not the six
    /// pairs above.
    public static func contextualRowIndex(
        _ a: Glyph.Attribute, _ comparator: Comparator,
        previous b: Glyph.Attribute, previousOrdinal: Int
    ) -> Int {
        precondition((0..<4).contains(previousOrdinal))
        let form = (Int(a.rawValue) * 4 + Int(b.rawValue)) * 6 + Int(comparator.rawValue)
        return form * 4 + previousOrdinal
    }

    /// Attribute-set-major, then subset ascending, then countSet ascending.
    public static func countIndex(attributeSet: UInt8, subset: UInt8, countSet: UInt8) -> Int {
        guard let setOrdinal = attributeSets.firstIndex(of: attributeSet) else {
            preconditionFailure("attrSet 0b\(String(attributeSet, radix: 2)) has |set| < 3 — §3.2")
        }
        precondition((1...14).contains(subset), "subset is ∅ or full — §3.2 forbids both")
        let k = attributeSet.nonzeroBitCount
        let countSetCount = (1 << (k + 1)) - 2
        precondition(
            (1...UInt8(countSetCount)).contains(countSet),
            "countSet must be a non-empty proper subset of 0…\(k)")
        return countSetOffsets[setOrdinal] + (Int(subset) - 1) * countSetCount + Int(countSet) - 1
    }

    /// `setOrdinal * 2 + bit`, and `bit` is `0` for **even** — §5.2 reads
    /// *"PARITY {fill,shape,pips,hue} IS even"*.
    public static func parityIndex(attributeSet: UInt8, bit: Int) -> Int {
        guard let setOrdinal = attributeSets.firstIndex(of: attributeSet) else {
            preconditionFailure("attrSet 0b\(String(attributeSet, radix: 2)) has |set| < 3 — §3.2")
        }
        precondition(bit == 0 || bit == 1)
        return setOrdinal * 2 + bit
    }

    // ── Accessors ────────────────────────────────────────────────────────────────────────

    /// - Complexity: O(1).
    public func atom(_ attribute: Glyph.Attribute, subset: UInt8) -> Bitboard256 {
        atomMasks[Self.atomIndex(attribute, subset: subset)]
    }

    /// - Complexity: O(1).
    public func relational(_ a: Glyph.Attribute, _ comparator: Comparator, _ b: Glyph.Attribute)
        -> Bitboard256
    {
        relationalMasks[Self.relationalIndex(a, comparator, b)]
    }

    /// - Complexity: O(1).
    public func contextualRow(
        _ a: Glyph.Attribute, _ comparator: Comparator,
        previous b: Glyph.Attribute, previousOrdinal: Int
    ) -> Bitboard256 {
        contextualRowMasks[
            Self.contextualRowIndex(
                a, comparator, previous: b, previousOrdinal: previousOrdinal)]
    }

    /// - Complexity: O(1).
    public func count(attributeSet: UInt8, subset: UInt8, countSet: UInt8) -> Bitboard256 {
        countMasks[Self.countIndex(attributeSet: attributeSet, subset: subset, countSet: countSet)]
    }

    /// - Complexity: O(1).
    public func parity(attributeSet: UInt8, bit: Int) -> Bitboard256 {
        parityMasks[Self.parityIndex(attributeSet: attributeSet, bit: bit)]
    }

    // ── Build ────────────────────────────────────────────────────────────────────────────

    /// `package` rather than `public`: production reads `resident`, and this exists so a test
    /// can measure a build and compare a fresh table against the resident one.
    package init() {
        // planes[attribute][ordinal] = the 64 glyphs with that value. Every other class is a
        // few unions over these.
        var planes = [[Bitboard256]](
            repeating: [Bitboard256](repeating: .empty, count: 4), count: 4)
        for glyph in Deck.all {
            for attribute in Glyph.Attribute.allCases {
                planes[Int(attribute.rawValue)][glyph.ordinal(of: attribute)].insert(glyph.id)
            }
        }

        var atoms = [Bitboard256](repeating: .empty, count: 56)
        for attribute in Glyph.Attribute.allCases {
            for subset in UInt8(1)...UInt8(14) {
                var mask = Bitboard256.empty
                for value in 0..<4 where subset & (1 << UInt8(value)) != 0 {
                    mask = mask | planes[Int(attribute.rawValue)][value]
                }
                atoms[Self.atomIndex(attribute, subset: subset)] = mask
            }
        }
        atomMasks = atoms

        var relationals = [Bitboard256](repeating: .empty, count: 36)
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases where Int(a.rawValue) < Int(b.rawValue) {
                for comparator in Comparator.allCases {
                    var mask = Bitboard256.empty
                    for va in 0..<4 {
                        for vb in 0..<4 where comparator.matches(va + 1, vb + 1) {
                            mask =
                                mask | (planes[Int(a.rawValue)][va] & planes[Int(b.rawValue)][vb])
                        }
                    }
                    relationals[Self.relationalIndex(a, comparator, b)] = mask
                }
            }
        }
        relationalMasks = relationals

        // A row's CONTENTS are { cur : RANK a(cur) ⋈ r+1 } and do not mention `b` at all —
        // `b` chooses WHICH row is used at evaluation time, not what is in it. So of the 384
        // stored rows only 96 are distinct. The 4× redundancy is deliberate: it keeps
        // evaluation a branch-free single lookup, and it is the layout §3.6's 12 KB budgets
        // for. `contextualRowsAreIndependentOfTheSecondAttribute` turns it into a checked
        // invariant rather than a latent inconsistency.
        var contextualRows = [Bitboard256](repeating: .empty, count: 384)
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases {
                for comparator in Comparator.allCases {
                    for previousOrdinal in 0..<4 {
                        var mask = Bitboard256.empty
                        for va in 0..<4 where comparator.matches(va + 1, previousOrdinal + 1) {
                            mask = mask | planes[Int(a.rawValue)][va]
                        }
                        contextualRows[
                            Self.contextualRowIndex(
                                a, comparator, previous: b, previousOrdinal: previousOrdinal)] =
                            mask
                    }
                }
            }
        }
        contextualRowMasks = contextualRows

        // No plane shortcut worth having: walk the deck and count hits per glyph.
        var counts = [Bitboard256](repeating: .empty, count: 1_204)
        var parities = [Bitboard256](repeating: .empty, count: 10)
        for (setOrdinal, attributeSet) in Self.attributeSets.enumerated() {
            let members = Glyph.Attribute.allCases.filter {
                attributeSet & (1 << $0.rawValue) != 0
            }
            let k = members.count
            let countSetCount = (1 << (k + 1)) - 2

            for subset in UInt8(1)...UInt8(14) {
                // hitsPerGlyph[id] = how many counted attributes have RANK in `subset`.
                var hitsPerGlyph = [Int](repeating: 0, count: 256)
                for glyph in Deck.all {
                    var hits = 0
                    for attribute in members
                    where subset & (1 << UInt8(glyph.ordinal(of: attribute))) != 0 {
                        hits += 1
                    }
                    hitsPerGlyph[glyph.id] = hits
                }
                for countSet in 1...countSetCount {
                    var mask = Bitboard256.empty
                    for id in 0..<256 where countSet & (1 << hitsPerGlyph[id]) != 0 {
                        mask.insert(id)
                    }
                    counts[
                        Self.countIndex(
                            attributeSet: attributeSet, subset: subset,
                            countSet: UInt8(countSet))] = mask
                }
            }

            // Parity is over RANKS, 1…4 — §2's table is stated in ranks and every other
            // production says RANK. This is load-bearing: rank = ordinal + 1, so for an
            // attribute set of ODD size the two conventions disagree, and the labelling is
            // exactly what E09's Tally comb renders and what G10 compares node-for-node.
            var evenMask = Bitboard256.empty
            var oddMask = Bitboard256.empty
            for glyph in Deck.all {
                let sum = members.reduce(0) { $0 + glyph.rank(of: $1) }
                if sum % 2 == 0 { evenMask.insert(glyph.id) } else { oddMask.insert(glyph.id) }
            }
            parities[setOrdinal * 2] = evenMask
            parities[setOrdinal * 2 + 1] = oddMask
        }
        countMasks = counts
        parityMasks = parities
    }
}
