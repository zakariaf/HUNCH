import Testing

import HunchTestSupport
import Laws

/// `Band` is where §5.7's locked constants live in code. Everything derivable is derived, so
/// there is never a second row to disagree with the first.
@Suite("Band", .tags(.unit, .presubmission))
struct BandTests {
    @Test("Eight bands, one family each, raw values 1…8 (§5.2 is a bijection)")
    func eightBands() {
        #expect(Band.allCases.count == 8)
        #expect(Band.allCases.map(\.rawValue) == Array(1...8))
        #expect(Band.literal < Band.systemic)
    }

    @Test("§5.7's locked par row, and cap DERIVED as ceil(1.6 x par)")
    func parAndCap() {
        #expect(Band.allCases.map(\.par) == [7, 13, 16, 20, 23, 23, 26, 29])
        #expect(Band.allCases.map(\.cap) == [12, 21, 26, 32, 37, 37, 42, 47])
    }

    @Test("§5.2's band populations sum to the 27,015 total law space")
    func populations() {
        #expect(
            Band.allCases.map(\.population)
                == [40, 1_272, 108, 2_322, 6_934, 5_688, 10_314, 337])
        #expect(Band.allCases.reduce(0) { $0 + $1.population } == 27_015)
    }

    /// §5.4's headline argument: band 8's hypothesis space is SMALLER than band 2's, and it is
    /// still the hardest band. A difficulty function based on entropy would rank it easier.
    @Test("Band 8 carries fewer bits than band 2 — entropy is not difficulty (§5.4)")
    func entropyIsNotDifficulty() {
        #expect(Band.systemic.informationContent < Band.pair.informationContent)
        #expect(Band.systemic.par > Band.pair.par)
        expectApproximatelyEqual(Band.systemic.informationContent, 8.40, absoluteTolerance: 0.01)
        expectApproximatelyEqual(Band.pair.informationContent, 10.31, absoluteTolerance: 0.01)
    }

    /// §5.4's par derivation, checked against the locked row. `k` and `d` are design-time
    /// priors, so this is what would catch a regenerated pair that no longer reproduces par.
    @Test("par reproduces ceil(k · log2|H| + d) for every band (§5.4)")
    func parDerivationHolds() {
        for band in Band.allCases {
            let derived = Int(
                (band.frictionCoefficient * band.informationContent + Double(band.discoveryCost))
                    .rounded(.up))
            #expect(derived == band.par, "\(band): derived \(derived), locked \(band.par)")
        }
    }

    @Test("The difficulty ranges tile [0.000, 1.000) exactly, half-open (§5.7)")
    func rangesTileExactly() {
        var expected = 0.0
        for band in Band.allCases {
            expectApproximatelyEqual(
                band.difficultyRange.lowerBound, expected, absoluteTolerance: 1e-12)
            expected += 0.125
            expectApproximatelyEqual(
                band.difficultyRange.upperBound, expected, absoluteTolerance: 1e-12)
        }
        expectApproximatelyEqual(expected, 1.0, absoluteTolerance: 1e-12)
        // No band contains another's centre.
        for a in Band.allCases {
            for b in Band.allCases where a != b {
                #expect(!a.difficultyRange.contains(b.centre))
            }
        }
    }

    @Test("The admit window is G3's, identical in every band")
    func admitWindow() {
        for band in Band.allCases {
            #expect(band.admitWindow == 0.15...0.60)
        }
    }

    @Test("Bands 5 and 7 are the contextual ones — G7's scope")
    func contextualBands() {
        #expect(Band.allCases.filter(\.isContextual) == [.contextual, .composite])
    }

    /// Band 8 is 4, not the family minimum of 3: §5.2's published δ of 0.928 for the parity
    /// exemplar only reproduces at 4. The effect is that m1 is zero for every aggregate, which
    /// is §5.2's own argument — band 8 is hard by symmetry, not by size.
    @Test("§5.1's m1 subtrahends, with band 8 pinned by its published δ")
    func minLeaves() {
        #expect(Band.allCases.map(\.minLeaves) == [1, 2, 2, 1, 1, 3, 2, 4])
    }
}
