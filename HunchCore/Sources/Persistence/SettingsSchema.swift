public import Foundation

/// §12.6's settings — **seven sections, nineteen rows**, and this is the single source.
///
/// Everything persists to `UserDefaults` under `hunch.settings.` **except the DATA rows, which
/// act on files**. `UserDefaults` holds preferences only; game state lives in JSON, and the two
/// have different backup, migration and reset semantics.
public enum SettingsSchema {

    public enum Section: String, CaseIterable, Hashable, Sendable {
        case display, feedback, play, voiceOver, language, data, about
    }

    public enum Row: String, CaseIterable, Hashable, Sendable {
        case theme
        case grain
        case reduceMotion
        case leftHandKeys
        case haptics
        case sound
        case level
        case confirmSeal
        case steadyStream
        case voiceOverDetail
        case announceVerdicts
        case announceAssay
        case languageTag
        case clearStatistics
        case clearCodex
        case resetProfile
        case resetLadder
        case resetEverything
        case about

        public var section: Section {
            switch self {
            case .theme, .grain, .reduceMotion, .leftHandKeys: .display
            case .haptics, .sound, .level: .feedback
            case .confirmSeal, .steadyStream: .play
            case .voiceOverDetail, .announceVerdicts, .announceAssay: .voiceOver
            case .languageTag: .language
            case .clearStatistics, .clearCodex, .resetProfile, .resetLadder, .resetEverything:
                .data
            case .about: .about
            }
        }

        /// The DATA rows act on files and are never written to `UserDefaults`.
        public var isPreference: Bool { section != .data && self != .about }

        public var defaultsKey: String? {
            isPreference ? "hunch.settings.\(rawValue)" : nil
        }
    }

    /// §12.6's five destructive actions, each with exactly what it moves.
    ///
    /// The set is what makes them reviewable: two of them are deliberately *separable* — a
    /// player clearing a shared device's Codex keeps the toolbox they earned, and a player
    /// resetting the ladder to re-calibrate keeps their pages.
    public struct ResetEffects: Equatable, Sendable {
        public var clearsStatistics = false
        public var clearsCodex = false
        public var clearsProfile = false
        public var clearsLadder = false
        /// §10.4: `maxBandEverServed` lives in `ServingState`, so the palette drops with the
        /// ladder and **not** with the Codex.
        public var dropsPaletteCeiling = false
        public var clearsSettings = false
        /// **Every reset leaves these two byte-identical.** The Anomaly streak is the one thing
        /// in the game a reset cannot launder, which is what makes it mean anything.
        public var touchesAnomalyLedger = false
        public var rearmsOnboarding = false

        public init() {}
    }

    public static func effects(of row: Row) -> ResetEffects {
        var effects = ResetEffects()
        switch row {
        case .clearStatistics:
            effects.clearsStatistics = true
        case .clearCodex:
            effects.clearsCodex = true
        case .resetProfile:
            effects.clearsProfile = true
        case .resetLadder:
            effects.clearsLadder = true
            effects.dropsPaletteCeiling = true
        case .resetEverything:
            effects.clearsStatistics = true
            effects.clearsCodex = true
            effects.clearsProfile = true
            effects.clearsLadder = true
            effects.dropsPaletteCeiling = true
            effects.clearsSettings = true
            effects.rearmsOnboarding = true
        default:
            break
        }
        return effects
    }

    /// §12.6: "Reset everything" clears every `hunch.settings.*` key **except** these two.
    /// Language and theme are how the player reads the app at all, and resetting them would
    /// make the reset itself unreadable to somebody who needs High Contrast or a script they
    /// can read.
    public static let preservedAcrossFullReset: Set<Row> = [.languageTag, .theme]

    public static var destructiveRows: [Row] {
        Row.allCases.filter { $0.section == .data }
    }
}
