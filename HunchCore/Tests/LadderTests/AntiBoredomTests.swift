import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Ladder
import Laws

/// §10.8. The interesting claim is not any single trigger but the shape: at the ceiling the game
/// changes the *question* rather than the difficulty, because difficulty has run out.
@Suite("Anti-boredom", .tags(.unit, .presubmission))
struct AntiBoredomTests {

    /// The law does not change; the scoring does. Three marks move from ≤ 0.6·par to ≤ 0.45·par,
    /// which is a question with no ceiling.
    @Test("Ceiling variation tightens the three-mark standard and nothing else")
    func ceilingVariationIsAScoringChange() {
        #expect(AntiBoredom.tightenedThreeMarkFraction < Scoring.threeMarkFraction)
        #expect(
            AntiBoredom.ceilingVariationApplies(
                recentWinsAtCeiling: 8, recentRounds: 10, band: .systemic, deltaClamped: true))
    }

    @Test("It needs all four conditions")
    func everyConditionIsNecessary() {
        #expect(
            AntiBoredom.ceilingVariationApplies(
                recentWinsAtCeiling: 7, recentRounds: 10, band: .systemic, deltaClamped: true)
                == false)
        #expect(
            AntiBoredom.ceilingVariationApplies(
                recentWinsAtCeiling: 9, recentRounds: 10, band: .composite, deltaClamped: true)
                == false)
        #expect(
            AntiBoredom.ceilingVariationApplies(
                recentWinsAtCeiling: 9, recentRounds: 10, band: .systemic, deltaClamped: false)
                == false)
    }

    /// Soft, and it must stay soft: the locked last-50 novelty guard is a §5.7 constant and the
    /// preference borrows attempts from the generator rather than changing it.
    @Test("The novelty preference is soft and bounded by the attempt budget")
    func noveltyPreferenceIsSoft() {
        #expect(AntiBoredom.softNoveltyAttempts == 100)
        #expect(AntiBoredom.softNoveltyThreshold == 150)
        // Band 8 holds 337 laws; 150 lifetime solves is nearly half of them, which is why the
        // threshold sits there rather than at some round number.
        #expect(Band.systemic.population == 337)
        #expect(AntiBoredom.softNoveltyThreshold * 2 < Band.systemic.population * 2)
    }

    /// A textless nudge toward the mode that still has slope in it.
    @Test("The weakest mode surfaces only when it is more than a logit behind")
    func theWeakestModeNudge() {
        var ability = Ability(core: 2)
        ability.drift = -0.9
        #expect(AntiBoredom.weakestMode(ability) == nil)

        ability.drift = -1.4
        ability.echo = -0.2
        #expect(AntiBoredom.weakestMode(ability) == .drift)

        ability.sieve = -2.0
        #expect(AntiBoredom.weakestMode(ability) == .sieve)
    }
}
