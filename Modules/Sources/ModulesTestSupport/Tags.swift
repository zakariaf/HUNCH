public import Testing

// The third and last copy of the eight-tag vocabulary (06 T29). Copies: HunchTestSupport,
// the Xcode HunchTests target, and here. There is no fourth — which is why this file moved out
// of HunchUITests and into the package's one test-support target when a second test target
// arrived: two test targets each declaring @Tag would have been the fourth and fifth.
extension Tag {
    @Tag public static var unit: Self
    @Tag public static var integration: Self
    @Tag public static var snapshot: Self
    @Tag public static var ui: Self
    @Tag public static var performance: Self
    @Tag public static var presubmission: Self
    @Tag public static var nightly: Self
    @Tag public static var prerelease: Self
}
