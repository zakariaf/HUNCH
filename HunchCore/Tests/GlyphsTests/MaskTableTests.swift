import Testing

import Glyphs
import HunchTestSupport

/// The builders compose value planes; this suite transcribes §3.2 literally, glyph by glyph.
/// They are deliberately different code, because the failure that would otherwise ship
/// silently is a mask that is CORRECT but filed under the WRONG index — which produces a law
/// whose extension is plausible and wrong.
@Suite("MaskTable", .tags(.unit, .presubmission))
struct MaskTableTests {
    let table = MaskTable.resident

    @Test("The five counts are §3.3's, and the payload is §3.6's ~54 KB")
    func counts() {
        #expect(table.atomMasks.count == 56)
        #expect(table.relationalMasks.count == 36)
        #expect(table.contextualRowMasks.count == 384)
        #expect(table.countMasks.count == 1_204)
        #expect(table.parityMasks.count == 10)
        #expect(
            table.atomMasks.count + table.relationalMasks.count
                + table.contextualRowMasks.count + table.countMasks.count
                + table.parityMasks.count == 1_690)
        #expect(table.byteCount == 1_690 * 32)  // 54,080 B ≈ 54 KB
    }

    @Test("Every index function is a bijection onto its range")
    func indicesAreBijections() {
        var atom = Set<Int>()
        for a in Glyph.Attribute.allCases {
            for s in UInt8(1)...UInt8(14) { atom.insert(MaskTable.atomIndex(a, subset: s)) }
        }
        #expect(atom == Set(0..<56))

        var rel = Set<Int>()
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases where a != b {
                for c in Comparator.allCases { rel.insert(MaskTable.relationalIndex(a, c, b)) }
            }
        }
        #expect(rel == Set(0..<36))

        var ctx = Set<Int>()
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases {
                for c in Comparator.allCases {
                    for p in 0..<4 {
                        ctx.insert(
                            MaskTable.contextualRowIndex(
                                a, c, previous: b, previousOrdinal: p))
                    }
                }
            }
        }
        #expect(ctx == Set(0..<384))

        var cnt = Set<Int>()
        for set in MaskTable.attributeSets {
            let n = (1 << (set.nonzeroBitCount + 1)) - 2
            for s in UInt8(1)...UInt8(14) {
                for cs in 1...n {
                    cnt.insert(
                        MaskTable.countIndex(
                            attributeSet: set, subset: s, countSet: UInt8(cs)))
                }
            }
        }
        #expect(cnt == Set(0..<1_204))
    }

    @Test("Atom masks match a literal transcription of `attr IN subset`")
    func atomsAreCorrect() {
        for a in Glyph.Attribute.allCases {
            for subset in UInt8(1)...UInt8(14) {
                let mask = table.atom(a, subset: subset)
                for g in Deck.all {
                    let inSubset = subset & (1 << UInt8(g.ordinal(of: a))) != 0
                    #expect(mask.contains(g.id) == inSubset)
                }
            }
        }
    }

    @Test("relationalIndex normalises operand order — §3.4 step 3 made total")
    func relationalIsOrderAgnostic() {
        #expect(
            MaskTable.relationalIndex(.pips, .lt, .shape)
                == MaskTable.relationalIndex(.shape, .gt, .pips))
        #expect(table.relational(.pips, .lt, .shape) == table.relational(.shape, .gt, .pips))
    }

    @Test("Relational masks match `RANK a ⋈ RANK b` transcribed literally")
    func relationalsAreCorrect() {
        for a in Glyph.Attribute.allCases {
            for b in Glyph.Attribute.allCases where a != b {
                for c in Comparator.allCases {
                    let mask = table.relational(a, c, b)
                    for g in Deck.all {
                        #expect(mask.contains(g.id) == c.matches(g.rank(of: a), g.rank(of: b)))
                    }
                }
            }
        }
    }

    /// The 4× redundancy made a checked invariant: a row's contents do not mention `b`.
    @Test("Contextual rows are independent of the second attribute")
    func contextualRowsAreIndependentOfTheSecondAttribute() {
        for a in Glyph.Attribute.allCases {
            for c in Comparator.allCases {
                for p in 0..<4 {
                    let reference = table.contextualRow(a, c, previous: .fill, previousOrdinal: p)
                    for b in Glyph.Attribute.allCases {
                        #expect(
                            table.contextualRow(a, c, previous: b, previousOrdinal: p)
                                == reference)
                    }
                }
            }
        }
    }

    @Test("Contextual rows match `RANK a(cur) ⋈ prevRank` transcribed literally")
    func contextualRowsAreCorrect() {
        for a in Glyph.Attribute.allCases {
            for c in Comparator.allCases {
                for p in 0..<4 {
                    let mask = table.contextualRow(a, c, previous: a, previousOrdinal: p)
                    for g in Deck.all {
                        #expect(mask.contains(g.id) == c.matches(g.rank(of: a), p + 1))
                    }
                }
            }
        }
    }

    @Test("§5.2's entry-level contextual law exists: RANK pips(cur) > PREV RANK pips")
    func entryLevelContextualLawExists() {
        // prev pips rank 2 → admits pips 3 and 4 → 128 of 256.
        let row = table.contextualRow(.pips, .gt, previous: .pips, previousOrdinal: 1)
        #expect(row.count == 128)
        #expect(row.contains(Glyph(fill: .hollow, shape: .circle, pips: .three, hue: .amber).id))
        #expect(!row.contains(Glyph(fill: .hollow, shape: .circle, pips: .two, hue: .amber).id))
    }

    @Test("COUNT masks match a literal transcription")
    func countMasksAreCorrect() {
        for set in MaskTable.attributeSets {
            let members = Glyph.Attribute.allCases.filter { set & (1 << $0.rawValue) != 0 }
            let n = (1 << (members.count + 1)) - 2
            // A representative slice: every attribute set, two subsets, every countSet.
            for subset in [UInt8(0b0011), UInt8(0b1100)] {
                for cs in 1...n {
                    let mask = table.count(
                        attributeSet: set, subset: subset, countSet: UInt8(cs))
                    for g in Deck.all {
                        let hits = members.filter {
                            subset & (1 << UInt8(g.ordinal(of: $0))) != 0
                        }.count
                        #expect(mask.contains(g.id) == (cs & (1 << hits) != 0))
                    }
                }
            }
        }
    }

    /// Parity is over RANKS. For an odd-sized attribute set the two conventions disagree, and
    /// the labelling is what the Tally comb renders — so this freezes it.
    @Test("PARITY is over ranks, and bit 0 is even (§5.2)")
    func parityMasksAreCorrect() {
        for set in MaskTable.attributeSets {
            let members = Glyph.Attribute.allCases.filter { set & (1 << $0.rawValue) != 0 }
            let even = table.parity(attributeSet: set, bit: 0)
            let odd = table.parity(attributeSet: set, bit: 1)
            #expect((even | odd) == .full)
            #expect((even & odd) == .empty)
            for g in Deck.all {
                let sum = members.reduce(0) { $0 + g.rank(of: $1) }
                #expect(even.contains(g.id) == (sum % 2 == 0))
            }
        }
    }

    @Test("§5.2's band-8 exemplar: PARITY of all four is even on half the deck, p = .500")
    func bandEightExemplar() {
        #expect(table.parity(attributeSet: 0b1111, bit: 0).count == 128)
    }

    @Test("A fresh build equals the resident table")
    func freshBuildMatchesResident() {
        let fresh = MaskTable()
        #expect(fresh.atomMasks == table.atomMasks)
        #expect(fresh.relationalMasks == table.relationalMasks)
        #expect(fresh.contextualRowMasks == table.contextualRowMasks)
        #expect(fresh.countMasks == table.countMasks)
        #expect(fresh.parityMasks == table.parityMasks)
    }
}
