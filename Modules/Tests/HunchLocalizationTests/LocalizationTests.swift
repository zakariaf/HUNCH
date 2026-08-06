import Foundation
import Testing

import HunchLocalization
import ModulesTestSupport

/// §12.9's inventory, as a test. The catalog cannot auto-populate from `Loc`'s call sites — Xcode
/// extracts from static literals and `LocKey.rawValue` is a runtime `String` — so *every* entry
/// is authored by hand, and a missing one shows the raw key on screen with nothing warning about
/// it. These tests are the only thing standing between that and a shipped build.
@Suite("The string catalog", .tags(.unit, .presubmission))
struct CatalogResolutionTests {

    private static let catalog: [String: Any] = {
        guard let url = Loc.catalog.url(forResource: "Localizable", withExtension: "xcstrings"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }()

    private static var strings: [String: Any] {
        catalog["strings"] as? [String: Any] ?? [:]
    }

    /// The **authored** English value, read from the catalog file rather than through
    /// `Bundle.localizedString`.
    ///
    /// That is not a convenience: `.xcstrings` is compiled to `.strings` by **Xcode's** build
    /// system, so under plain `swift build` — the ten-second fast path the two-package structure
    /// exists to buy — a runtime lookup returns the key itself. Asserting through the bundle
    /// here would test the build system, pass in the simulator, and say nothing about whether
    /// anybody wrote the string. Runtime *resolution* is asserted in the simulator by E19's
    /// audit; what belongs here is whether the copy exists and has the right shape.
    static func authored(_ key: LocKey) -> String {
        guard let entry = strings[key.rawValue] as? [String: Any],
            let localizations = entry["localizations"] as? [String: Any],
            let english = localizations["en"] as? [String: Any],
            let unit = english["stringUnit"] as? [String: Any],
            let value = unit["value"] as? String
        else { return "" }
        return value
    }

    @Test("Every key has a catalog entry")
    func everyKeyResolves() {
        #expect(Self.strings.isEmpty == false, "the catalog did not load")
        let missing = LocKey.allCases.filter { Self.strings[$0.rawValue] == nil }
        #expect(missing.isEmpty, "missing catalog entries: \(missing.map(\.rawValue))")
    }

    /// The other direction: an entry with no key is a string nobody can display, and it is the
    /// residue of a screen that was cut. It costs translation money in twelve languages.
    @Test("Every catalog entry has a key")
    func noOrphanedEntries() {
        let known = Set(LocKey.allCases.map(\.rawValue))
        let orphans = Self.strings.keys.filter { !known.contains($0) }
        #expect(orphans.isEmpty, "orphaned catalog entries: \(orphans)")
    }

    /// §12.9's hard budget. It is mechanically enforced rather than remembered, because the
    /// no-text discipline is exactly the kind that erodes one convenience label at a time.
    @Test("The catalog stays inside its 250-key budget")
    func budgetHolds() {
        #expect(LocKey.allCases.count <= LocKey.budget)
        #expect(Self.strings.count <= LocKey.budget)
    }

    /// The split that makes "the play surface has zero strings" and "the app has a catalog" both
    /// true: more than half the keys are **audio only** and are never rendered as pixels.
    @Test("The accessibility half of the catalog is never rendered")
    func audioOnlyKeysAreTheMajority() {
        let spoken = LocKey.allCases.filter { !$0.isVisible }
        let visible = LocKey.allCases.filter(\.isVisible)
        #expect(spoken.count > 0)
        #expect(visible.count > 0)
        #expect(spoken.allSatisfy { $0.rawValue.hasPrefix("A11Y_") })
    }

    /// The glyph label is **one format string with four interpolations, never concatenated
    /// fragments**: concatenation fixes English's adjective order into every locale that does
    /// not share it, and there is no way to notice from inside English.
    @Test("The glyph label is a single four-interpolation format")
    func glyphLabelIsOneFormat() {
        let value = Self.authored(.glyphLabel)
        for index in 1...4 {
            #expect(value.contains("%\(index)$@"), "missing interpolation \(index)")
        }
    }

    /// The plural-bearing formats carry positional specifiers, so a translator can reorder them.
    @Test("The value formats use positional or typed specifiers")
    func formatsAreTranslatable() {
        #expect(Self.authored(.formatProbesOfPar).contains("%1$lld"))
        #expect(Self.authored(.formatMarks).contains("%lld"))
    }

    /// §11.11: the five axis identifiers **never enter the catalog in any form**, visible or
    /// spoken. Naming an axis turns a self-portrait into a report card, and a VoiceOver user
    /// would be the only player who ever heard the name.
    @Test("No axis is ever named, in any string")
    func theAxesAreNeverNamed() {
        let forbidden = ["Induction", "Retention", "Flexibility", "Restraint", "Tempo"]
        for key in LocKey.allCases {
            let value = Self.authored(key)
            for name in forbidden {
                #expect(
                    value.localizedCaseInsensitiveContains(name) == false,
                    "\(key.rawValue) names an axis: \(value)")
            }
        }
    }

    /// The four mode names and HUNCH are **wordmarks**, not translation units — they ship
    /// untranslated in all twelve locales, so no catalog entry may *be* one. (The test is over
    /// values, not key names: `A11Y_FORMAT_PROBES_OF_PAR` legitimately contains the letters of
    /// PROBE and is not a wordmark.)
    @Test("No catalog entry is a wordmark")
    func wordmarksAreNotTranslated() {
        for key in LocKey.allCases {
            let value = Self.authored(key).trimmingCharacters(in: .whitespaces)
            #expect(
                LocKey.wordmarks.contains(value) == false,
                "\(key.rawValue) translates a wordmark")
        }
    }
}

/// §12.9's override, and the two things that do not work by default.
@Suite("The language override", .tags(.unit, .presubmission))
struct LanguageOverrideTests {

    @Test("Twelve shipping languages, thirteen picker rows")
    func theLanguageList() {
        #expect(AppLanguage.shipping.count == 12)
        #expect(AppLanguage.allCases.count == 13)
        #expect(AppLanguage.allCases.contains(.system))
    }

    /// The endonyms are constants, not translation units: a picker that translated its own
    /// entries would show a reader the name of their language in a language they cannot read —
    /// the one screen where that is fatal.
    @Test("Every language names itself, in itself")
    func endonymsAreConstants() {
        #expect(AppLanguage.arabic.endonym == "العربية")
        #expect(AppLanguage.japanese.endonym == "日本語")
        #expect(Set(AppLanguage.allCases.map(\.endonym)).count == AppLanguage.allCases.count)
    }

    /// `layoutDirection` is **not** derived from `\.locale` — it comes from the process's
    /// effective localization, fixed at launch — so the root has to set it from the resolved
    /// locale's own script direction.
    @Test("Right-to-left is read from the script, not from the environment")
    func rtlIsExplicit() {
        #expect(AppLanguage.arabic.isRightToLeft)
        #expect(AppLanguage.english.isRightToLeft == false)
        #expect(Loc(bundle: Loc.catalog, locale: Locale(identifier: "ar")).isRightToLeft)
        #expect(Loc(bundle: Loc.catalog, locale: Locale(identifier: "en")).isRightToLeft == false)
    }

    /// An override that silently fell back would ship a language picker where some entries do
    /// nothing — the failure a user cannot report because nothing happened.
    @Test("An override for a missing bundle returns nil rather than falling back")
    func missingOverrideIsVisible() {
        #expect(Loc.overriding(languageTag: "system") != nil)
        #expect(Loc.overriding(languageTag: "xx-YY") == nil)
    }
}
