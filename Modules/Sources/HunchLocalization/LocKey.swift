public import Foundation

/// The **closed key space** for every user-facing string in the app.
///
/// It is an enum, and `CaseIterable`, for one specific reason: Xcode extracts catalog keys from
/// *static string literals* at `String(localized:)` and `Text("…")` call sites, and `LocKey`'s
/// raw value is a **runtime** `String`. Two consequences follow and neither is obvious:
///
/// - the catalog will **never** auto-populate from `Loc`'s call sites, so every entry is
///   authored by hand; and
/// - a case with no catalog entry resolves to its own raw value — `"SETTINGS_ROW_THEME"`, on
///   screen — and no compiler, no extractor and no build warning says a word.
///
/// That is the whole justification for the enum and for `everyKeyResolves`. A future contributor
/// will otherwise "simplify" this away and ship a screen full of shouting identifiers.
public enum LocKey: String, CaseIterable, Hashable, Sendable {

    // ── Settings: 7 section headers ───────────────────────────────────────────────────────
    case settingsSectionDisplay = "SETTINGS_SECTION_DISPLAY"
    case settingsSectionFeedback = "SETTINGS_SECTION_FEEDBACK"
    case settingsSectionPlay = "SETTINGS_SECTION_PLAY"
    case settingsSectionVoiceOver = "SETTINGS_SECTION_VOICEOVER"
    case settingsSectionLanguage = "SETTINGS_SECTION_LANGUAGE"
    case settingsSectionData = "SETTINGS_SECTION_DATA"
    case settingsSectionAbout = "SETTINGS_SECTION_ABOUT"

    // ── Settings: 19 row labels ───────────────────────────────────────────────────────────
    case settingsRowTheme = "SETTINGS_ROW_THEME"
    case settingsRowGrain = "SETTINGS_ROW_GRAIN"
    case settingsRowReduceMotion = "SETTINGS_ROW_REDUCE_MOTION"
    case settingsRowLeftHandKeys = "SETTINGS_ROW_LEFT_HAND_KEYS"
    case settingsRowHaptics = "SETTINGS_ROW_HAPTICS"
    case settingsRowSound = "SETTINGS_ROW_SOUND"
    case settingsRowLevel = "SETTINGS_ROW_LEVEL"
    case settingsRowConfirmSeal = "SETTINGS_ROW_CONFIRM_SEAL"
    case settingsRowSteadyStream = "SETTINGS_ROW_STEADY_STREAM"
    case settingsRowVoiceOverDetail = "SETTINGS_ROW_VOICEOVER_DETAIL"
    case settingsRowAnnounceVerdicts = "SETTINGS_ROW_ANNOUNCE_VERDICTS"
    case settingsRowAnnounceAssay = "SETTINGS_ROW_ANNOUNCE_ASSAY"
    case settingsRowAppLanguage = "SETTINGS_ROW_APP_LANGUAGE"
    case settingsRowClearStatistics = "SETTINGS_ROW_CLEAR_STATISTICS"
    case settingsRowClearCodex = "SETTINGS_ROW_CLEAR_CODEX"
    case settingsRowResetProfile = "SETTINGS_ROW_RESET_PROFILE"
    case settingsRowResetLadder = "SETTINGS_ROW_RESET_LADDER"
    case settingsRowResetEverything = "SETTINGS_ROW_RESET_EVERYTHING"
    case settingsRowAbout = "SETTINGS_ROW_ABOUT"

    // ── Settings: 11 option labels ────────────────────────────────────────────────────────
    case optionThemeSystem = "OPTION_THEME_SYSTEM"
    case optionThemeDark = "OPTION_THEME_DARK"
    case optionThemeLight = "OPTION_THEME_LIGHT"
    case optionThemeHighContrast = "OPTION_THEME_HIGH_CONTRAST"
    case optionMotionSystem = "OPTION_MOTION_SYSTEM"
    case optionMotionAlways = "OPTION_MOTION_ALWAYS"
    case optionLevelNormal = "OPTION_LEVEL_NORMAL"
    case optionLevelLow = "OPTION_LEVEL_LOW"
    case optionDetailFull = "OPTION_DETAIL_FULL"
    case optionDetailTerse = "OPTION_DETAIL_TERSE"
    case optionLanguageSystem = "OPTION_LANGUAGE_SYSTEM"

    // ── Reset alerts: 5 × (title, body, verb) + one shared cancel ─────────────────────────
    case alertClearStatisticsTitle = "ALERT_CLEAR_STATISTICS_TITLE"
    case alertClearStatisticsBody = "ALERT_CLEAR_STATISTICS_BODY"
    case alertClearStatisticsVerb = "ALERT_CLEAR_STATISTICS_VERB"
    case alertClearCodexTitle = "ALERT_CLEAR_CODEX_TITLE"
    case alertClearCodexBody = "ALERT_CLEAR_CODEX_BODY"
    case alertClearCodexVerb = "ALERT_CLEAR_CODEX_VERB"
    case alertResetProfileTitle = "ALERT_RESET_PROFILE_TITLE"
    case alertResetProfileBody = "ALERT_RESET_PROFILE_BODY"
    case alertResetProfileVerb = "ALERT_RESET_PROFILE_VERB"
    case alertResetLadderTitle = "ALERT_RESET_LADDER_TITLE"
    case alertResetLadderBody = "ALERT_RESET_LADDER_BODY"
    case alertResetLadderVerb = "ALERT_RESET_LADDER_VERB"
    case alertResetEverythingTitle = "ALERT_RESET_EVERYTHING_TITLE"
    case alertResetEverythingBody = "ALERT_RESET_EVERYTHING_BODY"
    case alertResetEverythingVerb = "ALERT_RESET_EVERYTHING_VERB"
    case alertCancel = "ALERT_CANCEL"

    // ── About: 6 rows ─────────────────────────────────────────────────────────────────────
    case aboutVersion = "ABOUT_VERSION"
    case aboutBuild = "ABOUT_BUILD"
    case aboutNoDataCollected = "ABOUT_NO_DATA_COLLECTED"
    case aboutCopyright = "ABOUT_COPYRIGHT"
    case aboutStorageHealthy = "ABOUT_STORAGE_HEALTHY"
    case aboutStorageFailing = "ABOUT_STORAGE_FAILING"

    // ── Screen titles: 6. A shelf is titled by its family sigil and a page by its law. ────
    case titleCodex = "TITLE_CODEX"
    case titleAnomaly = "TITLE_ANOMALY"
    case titleStatistics = "TITLE_STATISTICS"
    case titleProfile = "TITLE_PROFILE"
    case titleSettings = "TITLE_SETTINGS"
    case titleAbout = "TITLE_ABOUT"

    // ── VoiceOver: 4 attributes + 16 values ───────────────────────────────────────────────
    case attributeFill = "A11Y_ATTRIBUTE_FILL"
    case attributeShape = "A11Y_ATTRIBUTE_SHAPE"
    case attributePips = "A11Y_ATTRIBUTE_PIPS"
    case attributeHue = "A11Y_ATTRIBUTE_HUE"
    case valueFillHollow = "A11Y_VALUE_FILL_HOLLOW"
    case valueFillDotted = "A11Y_VALUE_FILL_DOTTED"
    case valueFillStriped = "A11Y_VALUE_FILL_STRIPED"
    case valueFillSolid = "A11Y_VALUE_FILL_SOLID"
    case valueShapeCircle = "A11Y_VALUE_SHAPE_CIRCLE"
    case valueShapeTriangle = "A11Y_VALUE_SHAPE_TRIANGLE"
    case valueShapeSquare = "A11Y_VALUE_SHAPE_SQUARE"
    case valueShapeHexagon = "A11Y_VALUE_SHAPE_HEXAGON"
    case valuePipsOne = "A11Y_VALUE_PIPS_ONE"
    case valuePipsTwo = "A11Y_VALUE_PIPS_TWO"
    case valuePipsThree = "A11Y_VALUE_PIPS_THREE"
    case valuePipsFour = "A11Y_VALUE_PIPS_FOUR"
    case valueHueAmber = "A11Y_VALUE_HUE_AMBER"
    case valueHueTeal = "A11Y_VALUE_HUE_TEAL"
    case valueHueFrost = "A11Y_VALUE_HUE_FROST"
    case valueHueRose = "A11Y_VALUE_HUE_ROSE"

    /// **One localized format string with four interpolations, never concatenated fragments.**
    /// Concatenation fixes English's adjective order into every locale that does not share it.
    case glyphLabel = "A11Y_GLYPH_LABEL"

    // ── VoiceOver: announcements, 9 ───────────────────────────────────────────────────────
    case announceAdmit = "A11Y_ANNOUNCE_ADMIT"
    case announceReject = "A11Y_ANNOUNCE_REJECT"
    case announceStrike = "A11Y_ANNOUNCE_STRIKE"
    case announceCounterexample = "A11Y_ANNOUNCE_COUNTEREXAMPLE"
    case announceSealBarred = "A11Y_ANNOUNCE_SEAL_BARRED"
    case announceInscribed = "A11Y_ANNOUNCE_INSCRIBED"
    case announceRevealed = "A11Y_ANNOUNCE_REVEALED"
    case announceDriftChanged = "A11Y_ANNOUNCE_DRIFT_CHANGED"
    case announceCapReached = "A11Y_ANNOUNCE_CAP_REACHED"

    // ── VoiceOver: value formats, 4 of the 8 that are plural-bearing ──────────────────────
    case formatProbesOfPar = "A11Y_FORMAT_PROBES_OF_PAR"
    case formatMarks = "A11Y_FORMAT_MARKS"
    case formatStreak = "A11Y_FORMAT_STREAK"
    case formatPages = "A11Y_FORMAT_PAGES"

    // ── The five Profile vertex sentences ─────────────────────────────────────────────────
    //
    // §11.11's approved *behavioural* sentences. The identifiers Induction, Retention,
    // Flexibility, Restraint and Tempo **never enter the catalog in any form**, visible or
    // spoken — naming an axis turns a self-portrait into a report card.
    case vertexInduction = "A11Y_VERTEX_1"
    case vertexRetention = "A11Y_VERTEX_2"
    case vertexFlexibility = "A11Y_VERTEX_3"
    case vertexRestraint = "A11Y_VERTEX_4"
    case vertexTempo = "A11Y_VERTEX_5"
}

extension LocKey {
    /// §12.9's hard budget, asserted rather than remembered. It is set one screen's worth above
    /// the count — the most headroom a discipline can survive.
    public static let budget = 250

    /// Whether this key is ever **rendered as pixels**. The accessibility keys are audio only,
    /// which is why the no-text rule and the catalog can both be true at once.
    public var isVisible: Bool {
        !rawValue.hasPrefix("A11Y_")
    }

    /// The four mode names ship **untranslated in all twelve locales**, exactly like HUNCH: they
    /// are wordmarks, not translation units. There is deliberately no case for them.
    public static let wordmarks = ["HUNCH", "PROBE", "DRIFT", "ECHO", "SIEVE"]
}
