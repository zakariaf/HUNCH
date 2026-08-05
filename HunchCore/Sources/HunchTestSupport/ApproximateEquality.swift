public import Testing

/// Hand-rolled because `swift-numerics` is a third-party dependency and the brief bans them,
/// and because `XCTAssertEqual(_:_:accuracy:)` has no Swift Testing equivalent (08 §7.9).
///
/// `#expect(a == b)` on two `Double`s is a defect even when it passes. Every use site states
/// its tolerance *and why it is that number*.
public func isApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    absoluteTolerance: Double,
    relativeTolerance: Double = 0
) -> Bool {
    // First, before the finiteness guard: .infinity == .infinity must be true, while
    // .infinity - .infinity is NaN and would fail every comparison below.
    if a == b { return true }
    guard a.isFinite, b.isFinite else { return false }  // NaN is never equal to anything
    let difference = (a - b).magnitude
    return difference <= absoluteTolerance
        || difference <= relativeTolerance * Swift.max(a.magnitude, b.magnitude)
}

/// `#_sourceLocation` — with the underscore. The unprefixed `#sourceLocation` is the compiler's
/// line-control directive and does not parse in this position. Without the forward, every float
/// failure in the project points at this file instead of at the test (06 T17).
public func expectApproximatelyEqual(
    _ a: Double,
    _ b: Double,
    absoluteTolerance: Double,
    relativeTolerance: Double = 0,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        isApproximatelyEqual(
            a,
            b,
            absoluteTolerance: absoluteTolerance,
            relativeTolerance: relativeTolerance
        ),
        comment ?? "\(a) is not within \(absoluteTolerance) of \(b)",
        sourceLocation: sourceLocation
    )
}
