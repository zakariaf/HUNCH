import Testing

import HunchTestSupport

/// The eight tags are the whole vocabulary (06 T30) and adding a ninth is a decision, not a
/// convenience. This suite exists because a tag that is never declared is a COMPILE error in a
/// test but a silent nothing in a test plan: a plan whose include-tag names something nobody
/// declared selects zero tests and reports a green run over them (07 B24).
@Suite("Tag vocabulary", .tags(.unit, .presubmission))
struct TagVocabularyTests {
    @Test("The five kind tags are declared and pairwise distinct")
    func kindTagsAreDistinct() {
        let kinds: Set<Tag> = [.unit, .integration, .snapshot, .ui, .performance]
        #expect(kinds.count == 5)
    }

    @Test("The three cadence tags are declared and pairwise distinct")
    func cadenceTagsAreDistinct() {
        let cadences: Set<Tag> = [.presubmission, .nightly, .prerelease]
        #expect(cadences.count == 3)
    }

    @Test("Kind and cadence are two axes, not one list")
    func theTwoAxesDoNotOverlap() {
        let kinds: Set<Tag> = [.unit, .integration, .snapshot, .ui, .performance]
        let cadences: Set<Tag> = [.presubmission, .nightly, .prerelease]
        #expect(kinds.isDisjoint(with: cadences))
    }
}
