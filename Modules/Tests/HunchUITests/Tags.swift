import Testing

// The third and last copy of the eight-tag vocabulary (06 T29). Copies: HunchTestSupport,
// the Xcode HunchTests target, and here. There is no fourth.
extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var snapshot: Self
    @Tag static var ui: Self
    @Tag static var performance: Self
    @Tag static var presubmission: Self
    @Tag static var nightly: Self
    @Tag static var prerelease: Self
}
