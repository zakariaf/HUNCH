import Testing

// The tag vocabulary is declared once per MODULE, not once per repo (06 T29 — tags with the
// same name in different modules are treated as equivalent, which is exactly what keeps a
// plan's include-tag filter selecting all of them). HunchTestSupport (E01·T03) is absent from
// HunchCore's products: by design, so this Xcode target cannot import it. Copies: here,
// HunchTestSupport, and ModulesTestSupport (E03·T06). There is no fourth.
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
