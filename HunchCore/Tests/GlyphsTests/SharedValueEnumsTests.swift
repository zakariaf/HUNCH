import Testing

import Glyphs
import HunchTestSupport

/// These four ordinals end up in on-disk bytes — RNF's cmpOrdinal is a stored sort key, the
/// ribbon persists a Verdict per probe, and StoreFile is keyed by Mode. Reordering any case
/// list silently relays out saved data, so the raw values are pinned here.
@Suite("Shared value enums", .tags(.unit, .presubmission))
struct SharedValueEnumsTests {
    @Test("Raw values are frozen — they are on disk (§6.10, §3.4 step 2)")
    func rawValuesArePinned() {
        #expect(Verdict.admit.rawValue == 0)
        #expect(Verdict.reject.rawValue == 1)
        #expect(Coupler.allCases.map(\.rawValue) == [0, 1, 2])
        #expect(Comparator.allCases.map(\.rawValue) == [0, 1, 2, 3, 4, 5])
        #expect(Mode.allCases.map(\.rawValue) == [0, 1, 2, 3])
    }

    @Test("Verdict(admits:) is the evaluator's Bool")
    func verdictFromBool() {
        #expect(Verdict(admits: true) == .admit)
        #expect(Verdict(admits: false) == .reject)
    }

    @Test("matches agrees on ranks and on ordinals — rank == ordinal + 1 is strictly increasing")
    func matchesIsRankAgnostic() {
        for c in Comparator.allCases {
            for a in 1...4 {
                for b in 1...4 {
                    #expect(c.matches(a, b) == c.matches(a - 1, b - 1))
                }
            }
        }
    }

    @Test("flipped means the same thing with the operands swapped (§3.4 step 3)")
    func flippedIsOperandSwap() {
        for c in Comparator.allCases {
            for a in 1...4 {
                for b in 1...4 {
                    #expect(c.matches(a, b) == c.flipped.matches(b, a))
                }
            }
        }
        #expect(Comparator.allCases.allSatisfy { $0.flipped.flipped == $0 })
    }

    @Test("complemented is exact negation — one of the five cases that delete NOT (§3.1)")
    func complementIsExact() {
        for c in Comparator.allCases {
            for a in 1...4 {
                for b in 1...4 {
                    #expect(c.matches(a, b) != c.complemented.matches(a, b))
                }
            }
        }
        #expect(Comparator.allCases.allSatisfy { $0.complemented.complemented == $0 })
    }

    @Test("The mode wordmarks are the untranslated names (§12.9)")
    func wordmarks() {
        #expect(Mode.allCases.map(\.wordmark) == ["PROBE", "DRIFT", "ECHO", "SIEVE"])
    }

    @Test(
        "Every salt is the big-endian ASCII packing of its own wordmark",
        arguments: Mode.allCases)
    func saltIsTheWordmarkPacked(_ mode: Mode) {
        let packed = mode.wordmark.utf8.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        #expect(mode.salt == packed)
        #expect(mode.salt != 0)
    }

    @Test("The four salts are distinct — otherwise two modes share every puzzle")
    func saltsAreDistinct() {
        #expect(Set(Mode.allCases.map(\.salt)).count == 4)
    }
}
