import Foundation
import Testing

/// The app test bundle is hosted by the app, so `Bundle.main` is the app bundle and its
/// Info.plist is the one the build system generated from Config/Base.xcconfig (01 P30).
/// This suite asserts the settings LANDED — reading the xcconfig back proves nothing
/// (hunch-build-and-ci/references/xcconfig.md §5, §7).
@Suite("Generated Info.plist", .tags(.unit, .presubmission))
struct BuildSettingsTests {
    private func value(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    @Test("iPhone only — one device class, GAME_DESIGN.md §14.4")
    func deviceFamilyIsIPhoneOnly() throws {
        let families = try #require(value("UIDeviceFamily") as? [Int])
        #expect(families == [1])
    }

    @Test("Portrait only — the layout is tuned to a 375 pt thumb arc, §14.4")
    func portraitOnly() throws {
        let orientations = try #require(value("UISupportedInterfaceOrientations") as? [String])
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }

    @Test("Export compliance is declared, so TestFlight never stalls on it (07 B37)")
    func encryptionComplianceIsDeclared() throws {
        let declared = try #require(value("ITSAppUsesNonExemptEncryption") as? Bool)
        #expect(declared == false)
    }

    @Test("The bundle identifier resolved — a missing Local.xcconfig leaves a leading dot")
    func bundleIdentifierResolved() throws {
        let identifier = try #require(Bundle.main.bundleIdentifier)
        #expect(!identifier.isEmpty)
        #expect(!identifier.hasPrefix("."))
        #expect(identifier.hasSuffix(".hunch"))
    }

    @Test("The display name is the wordmark, untranslated (§12.9)")
    func displayNameIsTheWordmark() throws {
        let name = (value("CFBundleDisplayName") as? String) ?? (value("CFBundleName") as? String)
        #expect(name == "Hunch" || name == "HUNCH")
    }
}
