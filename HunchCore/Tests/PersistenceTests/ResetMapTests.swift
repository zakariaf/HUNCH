import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Laws
import Persistence

/// §12.6's five destructive actions. The single most important property is negative: none of
/// them may touch the Anomaly ledger, because `highWaterDay` is the entire anti-cheat and a
/// reset that cleared it would BE the exploit.
@Suite("The reset map", .tags(.unit, .presubmission))
struct ResetMapTests {
    /// Run every reset against a fully-populated store and assert the ledger is byte-identical
    /// afterwards — the assertion §11.13 asks the fixture suite to make.
    @Test("No reset touches anomaly.json or anomaly.hw", arguments: ResetAction.allCases)
    func anomalyLedgerSurvivesEveryReset(_ action: ResetAction) async throws {
        var seeded: [StoreFile: Data] = [:]
        for file in StoreFile.allCases { seeded[file] = Data(file.fileName.utf8) }
        let store = InMemoryPersistenceStore(seeded: seeded)

        for file in action.deletes { try await store.remove(file) }
        for file in action.rewrites { try await store.save(Data(), to: file) }

        let ledger = try await store.load(.anomaly)
        let sidecar = try await store.load(.anomalyHighWater)
        #expect(ledger == Data("anomaly.json".utf8), "\(action) altered the ledger")
        #expect(sidecar == Data("anomaly.hw".utf8), "\(action) altered the sidecar")
    }

    @Test("Reset everything deletes all eighteen non-immune files and no more")
    func resetEverythingScope() {
        let deleted = ResetAction.resetEverything.deletes
        #expect(deleted.count == StoreFile.allCases.count - 2)
        #expect(!deleted.contains(.anomaly))
        #expect(!deleted.contains(.anomalyHighWater))
        #expect(deleted.contains(.lawIndex))  // derived, regenerated on next launch
    }

    @Test("Clear Codex removes the eight shelves and empties the index, and nothing else")
    func clearCodexScope() {
        let action = ResetAction.clearCodex
        #expect(action.deletes == Set(Band.allCases.map(StoreFile.codexShelf)))
        #expect(action.rewrites == [.codexIndex])
        #expect(!action.deletes.contains(.ladder))
        #expect(!action.deletes.contains(.profile))
    }

    /// The correction made in the design phase: the palette ceiling reads `maxBandEverServed`
    /// from ServingState in ladder.json, NOT from the archive — so clearing the Codex leaves
    /// the toolbox a player earned.
    @Test("Clearing the Codex does not drop the palette ceiling; resetting the ladder does")
    func paletteCeilingOwnership() {
        #expect(!ResetAction.clearCodex.affectsPaletteCeiling)
        #expect(ResetAction.resetLadder.affectsPaletteCeiling)
        #expect(ResetAction.resetEverything.affectsPaletteCeiling)
    }

    @Test("Resetting the ladder keeps the Codex — it is for a shared device, not a wipe")
    func resetLadderKeepsTheCodex() {
        let action = ResetAction.resetLadder
        #expect(action.rewrites == [.ladder])
        for band in Band.allCases {
            #expect(!action.deletes.contains(.codexShelf(band)))
        }
    }

    @Test("The three content resets are independent of one another")
    func contentResetsAreIndependent() {
        let stats = ResetAction.clearStatistics
        let profile = ResetAction.resetProfile
        #expect(stats.rewrites.isDisjoint(with: profile.rewrites))
        #expect(!stats.rewrites.contains(.codexIndex))
        #expect(!profile.rewrites.contains(.statistics))
    }
}
