import Testing

import Bench
import HunchTestSupport
import Laws

/// §4.2's "14 usable states per ramp", and the predicate the Bench and the Seal must share.
@Suite("The Bench's rank set", .tags(.unit, .presubmission))
struct RankSetTests {

    @Test("Exactly two of the sixteen subsets are inert")
    func fourteenUsableStates() {
        let inert = RankSet.all.filter(\.isVacuous)
        #expect(RankSet.all.count == 16)
        #expect(inert.count == 2)
        #expect(inert.contains(.empty))
        #expect(inert.contains(.full))
    }

    /// The draft has to be able to pass *through* "nothing lit" on the way from one subset to
    /// another, which is why this is not `Subset4` — that type refuses the two degenerate
    /// values by construction, which is right for a law and wrong for an editing buffer.
    @Test("A draft passes through the inert states rather than being blocked at them")
    func toggleThroughEmpty() {
        var set = RankSet(ranks: [1])
        set = set.toggling(rank: 1)
        #expect(set == .empty)
        #expect(set.isVacuous)
        set = set.toggling(rank: 3)
        #expect(set == RankSet(ranks: [3]))
        #expect(set.isVacuous == false)
    }

    @Test("The usable fourteen are exactly the grammar's subsets")
    func usableStatesAreTheGrammars() {
        let usable = RankSet.all.filter { !$0.isVacuous }
        #expect(usable.count == 14)
        #expect(usable.allSatisfy { $0.subset4 != nil })
        #expect(RankSet.empty.subset4 == nil)
        #expect(RankSet.full.subset4 == nil)
        #expect(Set(usable.compactMap(\.subset4)).count == Subset4.all.count)
    }

    @Test("Membership and count agree with the bitmask", arguments: RankSet.all)
    func membershipMatchesTheMask(_ set: RankSet) {
        #expect(set.count == (0..<4).filter { set.contains(rank: $0) }.count)
        for rank in 0..<4 {
            #expect(set.toggling(rank: rank).contains(rank: rank) != set.contains(rank: rank))
        }
        // Out of range is inert, not a trap: a ramp with a fifth stop is a bug in the caller.
        #expect(set.toggling(rank: 9) == set)
        #expect(set.contains(rank: -1) == false)
    }
}
