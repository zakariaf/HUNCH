import Foundation
import Testing

import HunchTestSupport
import Persistence

/// §12.6's table, as a value. The reason to encode it is the DATA rows: five destructive actions
/// whose differences are exactly what a player is trusting when they tap one.
@Suite("The settings schema", .tags(.unit, .presubmission))
struct SettingsSchemaTests {

    @Test("Seven sections and nineteen rows")
    func theShape() {
        #expect(SettingsSchema.Section.allCases.count == 7)
        #expect(SettingsSchema.Row.allCases.count == 19)
        for section in SettingsSchema.Section.allCases {
            #expect(SettingsSchema.Row.allCases.contains { $0.section == section })
        }
    }

    /// `UserDefaults` holds preferences only; game state lives in JSON. The two have different
    /// backup, migration and reset semantics, and mixing them is how a "reset" leaves half the
    /// game behind.
    @Test("Only preferences get a defaults key")
    func dataRowsActOnFiles() {
        for row in SettingsSchema.destructiveRows {
            #expect(row.isPreference == false)
            #expect(row.defaultsKey == nil)
        }
        #expect(SettingsSchema.Row.theme.defaultsKey == "hunch.settings.theme")
        #expect(SettingsSchema.destructiveRows.count == 5)
    }

    /// **No reset touches the Anomaly ledger.** The streak is the one thing a reset cannot
    /// launder, which is what makes it mean anything at all — and this is the assertion that
    /// makes "all five leave `anomaly.json` byte-identical" true rather than intended.
    @Test(
        "Not one of the five resets touches the Anomaly ledger",
        arguments: SettingsSchema.destructiveRows)
    func theLedgerIsUntouchable(_ row: SettingsSchema.Row) {
        #expect(SettingsSchema.effects(of: row).touchesAnomalyLedger == false)
    }

    /// The two separable resets, and the separation is the point: a player clearing a shared
    /// device's Codex keeps the toolbox they earned, and one resetting the ladder keeps their
    /// pages. The palette ceiling lives in `ServingState`, so it drops with the ladder and not
    /// with the archive.
    @Test("Clearing the Codex and resetting the ladder are genuinely separable")
    func theTwoAreSeparable() {
        let codex = SettingsSchema.effects(of: .clearCodex)
        #expect(codex.clearsCodex)
        #expect(codex.dropsPaletteCeiling == false)
        #expect(codex.clearsLadder == false)

        let ladder = SettingsSchema.effects(of: .resetLadder)
        #expect(ladder.clearsLadder)
        #expect(ladder.dropsPaletteCeiling)
        #expect(ladder.clearsCodex == false)
    }

    @Test("Reset everything is the union of the others, plus onboarding and settings")
    func resetEverythingIsTheUnion() {
        let all = SettingsSchema.effects(of: .resetEverything)
        #expect(all.clearsStatistics && all.clearsCodex && all.clearsProfile && all.clearsLadder)
        #expect(all.dropsPaletteCeiling)
        #expect(all.clearsSettings)
        #expect(all.rearmsOnboarding)
        #expect(all.touchesAnomalyLedger == false)
    }

    /// Language and theme survive a full reset because they are how the player reads the app at
    /// all — resetting them would make the reset itself unreadable to somebody who needs High
    /// Contrast or a script they can read.
    @Test("Language and theme survive a full reset")
    func twoPreferencesSurvive() {
        #expect(SettingsSchema.preservedAcrossFullReset == [.languageTag, .theme])
        for row in SettingsSchema.preservedAcrossFullReset {
            #expect(row.isPreference)
        }
    }

    @Test("Clearing statistics moves nothing else")
    func clearStatisticsIsNarrow() {
        let effects = SettingsSchema.effects(of: .clearStatistics)
        #expect(effects.clearsStatistics)
        #expect(
            effects
                == {
                    var expected = SettingsSchema.ResetEffects()
                    expected.clearsStatistics = true
                    return expected
                }())
    }
}
