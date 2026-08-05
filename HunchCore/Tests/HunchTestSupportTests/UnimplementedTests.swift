import Testing

import HunchTestSupport

/// `unimplemented` records an issue against the calling test *and* signals. Verifying the
/// recording half would need `withKnownIssue` around a deliberate failure, which would make
/// this suite report a known issue on every run; the signalling half is what a double's
/// caller actually depends on, so that is what is asserted here (06 T38).
@Suite("Unimplemented doubles", .tags(.unit, .presubmission))
struct UnimplementedTests {
    @Test("The error carries the member name, so a failure names the call site")
    func errorCarriesMemberName() {
        let error = UnimplementedError("PersistenceStore.load(_:)")
        #expect(error.member == "PersistenceStore.load(_:)")
        #expect(error.description == "PersistenceStore.load(_:) was called unexpectedly")
    }

    @Test("UnimplementedError is Equatable on the member name")
    func errorIsEquatable() {
        #expect(UnimplementedError("a") == UnimplementedError("a"))
        #expect(UnimplementedError("a") != UnimplementedError("b"))
    }
}
