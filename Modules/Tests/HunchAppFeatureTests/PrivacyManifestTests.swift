import Foundation
import Testing

import ModulesTestSupport

/// The two artefacts App Review reads **before it reads any code**.
///
/// Each assertion here is a claim the repository can actually back: "nothing is collected" is
/// provable because check 5 fails the build on a network symbol, and "one required-reason API"
/// is provable because `UserDefaults` holds preferences only while game state lives in JSON.
@Suite("The privacy manifest", .tags(.unit, .presubmission))
struct PrivacyManifestTests {

    private static let manifest: [String: Any] = {
        // Walk up from the test bundle to the repository root: the manifest belongs to the app
        // target, which a package test cannot link.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        let path = url.appendingPathComponent("App/PrivacyInfo.xcprivacy")
        guard let data = try? Data(contentsOf: path),
            let plist = try? PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }()

    @Test("The manifest exists and parses")
    func itParses() {
        #expect(Self.manifest.isEmpty == false)
    }

    /// Nothing collected, and the claim is backed by the absence of any network symbol — which
    /// is itself a build gate rather than a promise.
    @Test("Nothing is collected and nothing is tracked")
    func nothingIsCollected() {
        let collected = Self.manifest["NSPrivacyCollectedDataTypes"] as? [Any]
        #expect(collected?.isEmpty == true)
        #expect(Self.manifest["NSPrivacyTracking"] as? Bool == false)
        // A domain listed with tracking false is a contradiction, and it is the first thing a
        // reviewer notices.
        let domains = Self.manifest["NSPrivacyTrackingDomains"] as? [Any]
        #expect(domains?.isEmpty == true)
    }

    /// Exactly one: `UserDefaults` holds preferences only (§12.6), and game state lives in JSON
    /// under Application Support, which needs no declaration at all.
    @Test("Exactly one required-reason API, and it is UserDefaults")
    func oneRequiredReasonAPI() {
        let accessed = Self.manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        #expect(accessed.count == 1)
        #expect(
            accessed.first?["NSPrivacyAccessedAPIType"] as? String
                == "NSPrivacyAccessedAPICategoryUserDefaults")
        let reasons = accessed.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
        #expect(reasons == ["CA92.1"])
    }
}

/// §12.9's `Info.plist` claims. Each is a **verifiable privacy claim** rather than a preference:
/// the app requests no permissions, so there is no usage description of any kind, and it has no
/// export and no `Documents/` content, so it must not be able to silently acquire a Files
/// presence by somebody adding a key.
@Suite("The Info.plist absences", .tags(.unit, .presubmission))
struct InfoPlistAbsenceTests {

    private static let config: String = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        let path = url.appendingPathComponent("Config/Base.xcconfig")
        return (try? String(contentsOf: path, encoding: .utf8)) ?? ""
    }()

    /// The app requests no permissions, so there is no `NS*UsageDescription` of any kind — and
    /// that absence is what makes "no data is collected" checkable from outside the code.
    @Test("No usage description is declared anywhere")
    func noPermissions() {
        #expect(Self.config.isEmpty == false)
        #expect(Self.config.contains("UsageDescription") == false)
    }

    /// There is no export and no `Documents/` content (§11.5), so neither key may appear —
    /// otherwise the app could acquire a Files presence without anybody deciding to give it one.
    @Test("Neither Files-presence key is declared")
    func noFilesPresence() {
        #expect(Self.config.contains("UIFileSharingEnabled") == false)
        #expect(Self.config.contains("LSSupportsOpeningDocumentsInPlace") == false)
    }

    /// Portrait only: no layout exists for landscape (§6.11 #24), so the lock is the
    /// implementation of that fact rather than a preference.
    @Test("Portrait is locked in the build settings")
    func portraitIsLocked() {
        #expect(Self.config.contains("UIInterfaceOrientationPortrait"))
        #expect(Self.config.contains("UIInterfaceOrientationLandscape") == false)
    }

    /// §1's hard constraint, declared where App Review reads it.
    @Test("Non-exempt encryption is declared as none")
    func noEncryption() {
        #expect(Self.config.contains("ITSAppUsesNonExemptEncryption = NO"))
    }
}
