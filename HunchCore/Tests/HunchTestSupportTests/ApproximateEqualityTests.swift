import Testing

import HunchTestSupport

/// An untested comparison helper is a silent falsifier of every test that routes through it,
/// which by E11 is every floating-point assertion in the project (06 T5b).
@Suite("Approximate equality", .tags(.unit, .presubmission))
struct ApproximateEqualityTests {
    @Test("Exact equality holds at zero tolerance")
    func exactEquality() {
        #expect(isApproximatelyEqual(1.0, 1.0, absoluteTolerance: 0))
    }

    @Test("Infinities compare equal — the a == b early return runs before the finiteness guard")
    func infinitiesAreEqual() {
        #expect(isApproximatelyEqual(.infinity, .infinity, absoluteTolerance: 0))
        #expect(isApproximatelyEqual(-.infinity, -.infinity, absoluteTolerance: 0))
        #expect(!isApproximatelyEqual(.infinity, -.infinity, absoluteTolerance: .infinity))
    }

    @Test("NaN is equal to nothing, including itself")
    func nanIsNeverEqual() {
        #expect(!isApproximatelyEqual(.nan, .nan, absoluteTolerance: 1))
        #expect(!isApproximatelyEqual(.nan, 0, absoluteTolerance: 1))
    }

    @Test("Absolute tolerance is inclusive at the boundary")
    func absoluteToleranceIsInclusive() {
        #expect(isApproximatelyEqual(1.0, 1.5, absoluteTolerance: 0.5))
        #expect(!isApproximatelyEqual(1.0, 1.5, absoluteTolerance: 0.4))
    }

    @Test("Relative tolerance scales with the larger magnitude")
    func relativeToleranceScales() {
        // 1 % of 1000 is 10, so 1000 vs 1005 is inside and 1000 vs 1015 is not.
        #expect(isApproximatelyEqual(1000, 1005, absoluteTolerance: 0, relativeTolerance: 0.01))
        #expect(!isApproximatelyEqual(1000, 1015, absoluteTolerance: 0, relativeTolerance: 0.01))
    }

    @Test("Signed zeros compare equal")
    func signedZeros() {
        #expect(isApproximatelyEqual(0.0, -0.0, absoluteTolerance: 0))
    }

    @Test("A tolerance of zero is not a licence to be sloppy — 0.1 + 0.2 != 0.3")
    func classicFloatingPointCase() {
        #expect(!isApproximatelyEqual(0.1 + 0.2, 0.3, absoluteTolerance: 0))
        #expect(isApproximatelyEqual(0.1 + 0.2, 0.3, absoluteTolerance: 1e-15))
    }
}
