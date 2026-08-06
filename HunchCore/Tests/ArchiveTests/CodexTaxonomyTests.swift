import Foundation
import Testing

import Archive
import Glyphs
import HunchTestSupport
import Laws

/// §11.2 and §11.4. The Codex is a **map**, not a log, and every property tested here is one of
/// the five things §11.4 says makes that true.
@Suite("The Codex's taxonomy", .tags(.unit, .presubmission))
struct CodexTaxonomyTests {

    /// §11.4's completion state, and the only one. Three sealable shelves, 485 pages, about 53
    /// hours at par-rate play — the design's argument is that a finite modest space deserves
    /// honesty rather than a pretence of infinity.
    @Test("Exactly three shelves are sealable, and they hold 485 pages")
    func sealableShelves() {
        #expect(CodexTaxonomy.sealableShelves == [.literal, .exclusive, .systemic])
        #expect(CodexTaxonomy.sealablePages == 485)
        #expect(Band.literal.population == 40)
        #expect(Band.exclusive.population == 108)
        #expect(Band.systemic.population == 337)
    }

    /// `|H| ≤ 512` is where a full slot map is renderable at all. The five accretion shelves are
    /// exactly the ones where drawing every empty socket would be drawing thousands.
    @Test("Sealability is |H| ≤ 512 and nothing else", arguments: Band.allCases)
    func sealabilityIsPopulation(_ band: Band) {
        #expect(CodexTaxonomy.isSealable(band) == (band.population <= 512))
    }

    /// A linear arc on a 10,314-law shelf never visibly moves, and an arc that never moves says
    /// nothing. Log scaling is what makes the first eight pages feel like progress.
    @Test("The accretion arc moves early and keeps moving")
    func theArcIsLogarithmic() {
        let population = Band.composite.population
        let first = CodexTaxonomy.accretionFill(found: 8, of: population)
        let linear = 8.0 / Double(population)
        #expect(first > linear * 10)
        #expect(first < 0.30)

        // Monotone, and full only at full.
        #expect(CodexTaxonomy.accretionFill(found: 0, of: population) == 0)
        #expect(
            abs(CodexTaxonomy.accretionFill(found: population, of: population) - 1) < 1e-12)
        for found in [1, 8, 32, 128, 512] {
            #expect(
                CodexTaxonomy.accretionFill(found: found, of: population)
                    < CodexTaxonomy.accretionFill(found: found + 1, of: population))
        }
    }

    /// "Visible absence" only means something if a hole stays where it is: a slot that wandered
    /// would be a hole nobody could learn.
    @Test("The canonical key is a total order, so a law's slot never moves")
    func theKeyIsTotal() {
        let keys = [
            CodexTaxonomy.CanonicalKey(attribute: 0, comparator: 0, payload: 2),
            CodexTaxonomy.CanonicalKey(attribute: 0, comparator: 0, payload: 1),
            CodexTaxonomy.CanonicalKey(attribute: 0, comparator: 1, payload: 0),
            CodexTaxonomy.CanonicalKey(attribute: 1, comparator: 0, payload: 0),
        ]
        #expect(keys.sorted() == [keys[1], keys[0], keys[2], keys[3]])
        #expect(Set(keys).count == keys.count)
    }
}

/// §11.2's thumbnail. Its defining choice is that it draws the **extension** — which is what
/// makes collisions impossible, because the extension is identity.
@Suite("The extension thumbnail", .tags(.unit, .presubmission))
struct ExtensionThumbnailTests {

    private static let triangles = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
    private static let contextual = Law(
        .contextual(.init(current: .pips, comparator: .gt, previous: .pips)))

    @Test("A stateless law projects to its own extension, at 0 or 1")
    func statelessProjection() {
        let projection = ExtensionThumbnail.projection(of: Self.triangles)
        #expect(projection.count == 256)
        #expect(Set(projection) == [0, 1])
        #expect(projection.count { $0 == 1 } == 64)
    }

    /// A contextual law projects to fractions, which is the whole reason the ink ladder exists:
    /// the thumbnail has to say *how often* rather than *whether*.
    @Test("A contextual law projects to fractions and uses the whole ladder")
    func contextualProjection() {
        let projection = ExtensionThumbnail.projection(of: Self.contextual)
        #expect(projection.contains { $0 > 0 && $0 < 1 })
        let levels = Set(projection.map(ExtensionThumbnail.level))
        #expect(levels.count > 1)
    }

    /// The ladder is §2's own, reused because the player already learned that more ink means
    /// more — on a surface where it meant exactly that.
    @Test("The ink ladder is monotone in the fraction")
    func theLadderIsMonotone() {
        let samples = [0.0, 0.24, 0.25, 0.49, 0.5, 0.74, 0.75, 1.0]
        let levels = samples.map { ExtensionThumbnail.level(fraction: $0).rawValue }
        #expect(levels == levels.sorted())
        #expect(ExtensionThumbnail.level(fraction: 0) == .hollow)
        #expect(ExtensionThumbnail.level(fraction: 1) == .solid)
    }

    /// Extension is identity, so two different laws cannot draw the same thumbnail — which is
    /// what makes a shelf readable as a wall of constellations rather than a wall of repeats.
    @Test("Two distinct laws cannot share a thumbnail")
    func thumbnailsAreIdentities() {
        let other = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b0100))))
        #expect(
            ExtensionThumbnail.projection(of: Self.triangles)
                != ExtensionThumbnail.projection(of: other))
    }
}
