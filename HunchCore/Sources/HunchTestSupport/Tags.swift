public import Testing

// The vocabulary is fixed at eight on two axes (06 T29, T30, 07 B24). It is declared once per
// PACKAGE, not once per repo: HunchTestSupport is absent from products: by design, so the
// Modules package gets its own copy (E03·T06) and the Xcode HunchTests target a third
// (E01·T02). 06 T29 treats same-named tags in different modules as equivalent, which is what
// keeps one include-tag filter selecting all three.
//
// Never write an alias (`static var slow: Self { integration }`). It compiles, and it silently
// selects nothing at runtime.
extension Tag {
    // Kind — what the test is.
    @Tag public static var unit: Self
    @Tag public static var integration: Self
    @Tag public static var snapshot: Self
    @Tag public static var ui: Self
    @Tag public static var performance: Self

    // Cadence — when it runs.
    @Tag public static var presubmission: Self
    @Tag public static var nightly: Self
    @Tag public static var prerelease: Self
}
