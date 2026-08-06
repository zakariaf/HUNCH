public import Foundation

/// **The one accessor** every user-facing string goes through.
///
/// It carries a bundle *and* a locale, and both are load-bearing. `String(localized:)`,
/// `LocalizedStringResource` and a bare `Text("literal")` all resolve against `Bundle.main`'s
/// **launch-time** localization, not against `\.locale` — so a language override that only
/// reached this helper would leave every `Text` literal in English until relaunch, which is most
/// of the app's strings.
///
/// The `AppleLanguages` write is kept for the **next cold launch only** and is explicitly not
/// the mechanism for the current session. Writing it and hoping is the version that appears to
/// work on the simulator and fails on a device that was not restarted.
public struct Loc: Sendable {

    public let bundle: Bundle
    public let locale: Locale

    public init(bundle: Bundle, locale: Locale = .autoupdatingCurrent) {
        self.bundle = bundle
        self.locale = locale
    }

    /// The catalog's own bundle. `Bundle.module` is internal to this target, which is why the
    /// accessor cannot take it as a default argument — and why exposing it here is the only way
    /// a feature module can reach the strings at all.
    public static let catalog = Bundle.module

    public static let current = Loc(bundle: catalog)

    public func callAsFunction(_ key: LocKey) -> String {
        bundle.localizedString(forKey: key.rawValue, value: nil, table: nil)
    }

    /// Resolve against a specific `.lproj`, which is what the language override needs.
    ///
    /// - Returns: `nil` when the override bundle does not exist — a caller that silently fell
    ///   back would ship a language picker where some entries do nothing.
    public static func overriding(languageTag: String, in bundle: Bundle = Loc.catalog) -> Loc? {
        guard languageTag != "system" else {
            return Loc(bundle: bundle, locale: .autoupdatingCurrent)
        }
        guard let path = bundle.path(forResource: languageTag, ofType: "lproj"),
            let override = Bundle(path: path)
        else { return nil }
        return Loc(bundle: override, locale: Locale(identifier: languageTag))
    }

    /// §12.9: `layoutDirection` is **not** derived from `\.locale`. It comes from the process's
    /// effective localization, fixed at launch, so setting `\.locale` to `ar` mirrors nothing —
    /// it has to be set explicitly on the root from the resolved locale's own script direction.
    public var isRightToLeft: Bool {
        locale.language.characterDirection == .rightToLeft
    }
}

/// §12.9's twelve shipping locales, plus the system option.
public enum AppLanguage: String, CaseIterable, Hashable, Sendable {
    case system
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case italian = "it"
    case turkish = "tr"
    case russian = "ru"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case arabic = "ar"

    /// The endonyms are **constants, not translation units**: a language picker that translated
    /// its own entries would show a reader the name of their language in a language they cannot
    /// read, which is the one screen where that is fatal.
    public var endonym: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .portugueseBrazil: "Português (Brasil)"
        case .italian: "Italiano"
        case .turkish: "Türkçe"
        case .russian: "Русский"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .arabic: "العربية"
        }
    }

    public var isRightToLeft: Bool { self == .arabic }

    /// Twelve languages, and the picker shows thirteen rows because "System" is one of them.
    public static var shipping: [AppLanguage] { allCases.filter { $0 != .system } }
}
