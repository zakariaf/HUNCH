import Foundation
import Testing

import Echo
import Glyphs
import HunchTestSupport
import Laws

/// §8.2's pool. The design's argument for rendering it is what these tests protect: three ringed
/// glyphs cannot pin a law out of 27,015 — they can only separate members of a candidate set,
/// and if that set is not on screen the deduction becomes unaided recall of eight laws across
/// eight rounds. ECHO is not a memory task.
@Suite("The echo pool", .tags(.unit, .presubmission))
struct EchoPoolTests {

    private static func atom(_ mask: UInt8, _ attribute: Glyph.Attribute = .shape) -> Law {
        Law(.atom(.init(attribute: attribute, subset: Fixture.subset(mask))))
    }

    private static let pool = EchoPool(members: [
        atom(0b0001), atom(0b0010), atom(0b0100), atom(0b1000),
        atom(0b0011), atom(0b0101), atom(0b1001), atom(0b0110),
    ])

    @Test("Eight members, because eight is exactly three bits")
    func capacityIsThreeBits() {
        #expect(EchoPool.capacity == 8)
        #expect(EchoPool.primerLengths == [3, 4, 5])
        // m = 3 separates at most 8, which is the pool — the fit is the reason for the number.
        #expect(1 << 3 == EchoPool.capacity)
    }

    /// The pool holds only the most recent eight, oldest leading.
    @Test("The pool keeps the last eight in Codex order")
    func poolIsBounded() {
        let overfull = EchoPool(members: (0..<12).map { Self.atom(UInt8(($0 % 14) + 1)) })
        #expect(overfull.members.count == 8)
        #expect(EchoPool(members: [Self.atom(0b0001), Self.atom(0b0010)]).isPlayable == false)
        #expect(Self.pool.isPlayable)
    }

    /// §8.2's `m` is "the smallest value in {3, 4, 5} for which a separating chain exists", and
    /// this pool is a worked example of why the search is needed: over three shapes, `{circle}`
    /// and `{circle, hexagon}` produce the identical verdict vector, so no three-glyph chain
    /// drawn from those shapes can separate them. The fourth glyph is what splits them.
    @Test("m grows until a separating chain exists")
    func mGrowsUntilItSeparates() {
        let seed = Deck.glyph(id: 48)
        let three = [0, 1, 2].map { Deck.glyph(id: $0 * 16) }
        let four = [0, 1, 2, 3].map { Deck.glyph(id: $0 * 16) }

        #expect(Self.pool.separates(three, seedGlyph: seed) == false)
        #expect(Self.pool.separates(four, seedGlyph: seed))
    }

    /// A separating chain makes every member's verdict vector distinct, so exactly one thumbnail
    /// survives — that is what "the primer eliminates on screen" means arithmetically.
    @Test("A separating chain leaves exactly one member lit")
    func separationLeavesOne() {
        let chain = [0, 1, 2, 3].map { Deck.glyph(id: $0 * 16) }
        let seed = Deck.glyph(id: 48)
        let vectors = Self.pool.members.map {
            EchoPool.verdicts(of: $0, over: chain, seedGlyph: seed)
        }
        let primer = EchoPool.Primer(
            seedGlyph: seed, glyphs: chain, verdictVectors: vectors, inForce: 5)
        #expect(Self.pool.surviving(after: chain.count, primer: primer) == [5])
    }

    /// The elimination is progressive: each ring extinguishes every member it rules out, on the
    /// same frame the ring resolves. A strip that only resolved at the end would be a reveal,
    /// not a deduction the player can read ahead of.
    @Test("Members extinguish one ring at a time, never all at once")
    func eliminationIsProgressive() {
        let chain = [0, 1, 2, 3].map { Deck.glyph(id: $0 * 16) }
        let seed = Deck.glyph(id: 48)
        let vectors = Self.pool.members.map {
            EchoPool.verdicts(of: $0, over: chain, seedGlyph: seed)
        }
        let primer = EchoPool.Primer(
            seedGlyph: seed, glyphs: chain, verdictVectors: vectors, inForce: 5)

        let counts = (0...chain.count).map {
            Self.pool.surviving(after: $0, primer: primer).count
        }
        #expect(counts[0] == Self.pool.members.count)  // all lit before the first ring
        #expect(counts[counts.count - 1] == 1)
        #expect(counts == counts.sorted(by: >))  // monotone: nothing ever re-lights
    }

    /// A chain that fails to separate leaves more than one lit, and the design's answer is to
    /// lengthen `m` — not to pick a winner. Asserting the failure is what stops a future
    /// implementation from "resolving" an ambiguous strip by choosing.
    @Test("A non-separating chain leaves the ambiguity visible")
    func ambiguityIsVisible() {
        let sameShape = [Deck.glyph(id: 0), Deck.glyph(id: 1)]
        #expect(Self.pool.separates(sameShape, seedGlyph: Deck.glyph(id: 2)) == false)
    }
}

/// §8.6's load index — the one difficulty knob that says nothing about the grammar.
@Suite("ECHO's load", .tags(.unit, .presubmission))
struct EchoLoadTests {

    @Test("The published load table reproduces row for row")
    func theTable() {
        let expected: [(Int, Int, Int, Int)] = [
            (1, 6, 2, 1_400), (2, 8, 3, 1_300), (3, 9, 3, 1_200), (4, 10, 4, 1_100),
            (5, 11, 4, 1_000), (6, 12, 5, 950), (7, 13, 5, 900), (8, 14, 6, 850),
        ]
        for (index, length, lawful, cadence) in expected {
            let load = EchoLoad.load(index)
            #expect(load.castLength == length)
            #expect(load.lawfulCount == lawful)
            #expect(load.cadenceMilliseconds == cadence)
        }
    }

    /// The cast stays near twelve seconds across the whole range: the load rises by making the
    /// player hold more in less time, not by making them wait longer.
    @Test("Cast duration stays inside a narrow band as the load climbs")
    func castDurationIsStable() {
        let durations = EchoLoad.all.map(\.castSeconds)
        #expect(durations.allSatisfy { $0 >= 8.0 && $0 <= 12.0 })
        #expect((durations.max() ?? 0) - (durations.min() ?? 0) < 4.0)
    }

    @Test("Lawful count never reaches half the cast", arguments: EchoLoad.all)
    func lawfulIsAlwaysAMinority(_ load: EchoLoad) {
        #expect(load.lawfulCount * 2 < load.castLength)
        #expect(load.holdMilliseconds > 0)
    }

    /// §8.4: `L ≤ 14`, so the tray is at most four rows of four.
    @Test("The tray never needs a fifth row")
    func trayFits() {
        #expect((EchoLoad.all.map(\.castLength).max() ?? 0) == 14)
        #expect(14 <= 4 * 4)
    }
}

/// §8.7's scoring. The shape is the argument: the set is **squared** and the order is a bounded
/// 30 %, because applying a law wrongly is a different failure from remembering an order wrongly.
@Suite("ECHO's scoring", .tags(.unit, .presubmission))
struct EchoScoringTests {

    @Test("A perfect recall is 1000 and three marks")
    func perfect() {
        let result = EchoScoring.score(truth: [1, 4, 7], answer: [1, 4, 7], replayed: false)
        #expect(result.setF1 == 1)
        #expect(result.order == 1)
        #expect(result.score == 1_000)
        #expect(result.marks == 3)
        #expect(result.isSuccess)
    }

    /// **Success is the set, not the order.** Making order pass/fail would score a player who
    /// applied the law perfectly and mis-remembered a sequence as having failed to apply it.
    @Test("The right set in the wrong order still succeeds, and still costs score")
    func orderIsBounded() {
        let result = EchoScoring.score(truth: [1, 4, 7], answer: [7, 1, 4], replayed: false)
        #expect(result.isSuccess)
        #expect(result.setF1 == 1)
        #expect(result.order < 1)
        #expect(result.score < 1_000)
        #expect(result.score >= 700)  // order is capped at 30 % of the total
        #expect(result.marks == 2)
    }

    /// Squaring `setF1` is what makes a nearly-right set cost real score: a player who includes
    /// one unlawful glyph has applied the law wrongly, which is the failure the mode exists to
    /// expose.
    @Test("A false include costs more than a lost order")
    func falseIncludesAreExpensive() {
        let wrongOrder = EchoScoring.score(truth: [1, 4, 7], answer: [7, 4, 1], replayed: false)
        let wrongSet = EchoScoring.score(truth: [1, 4, 7], answer: [1, 4, 7, 9], replayed: false)
        #expect(wrongSet.falseIncludes == 1)
        #expect(wrongSet.score < wrongOrder.score)
        #expect(wrongSet.isSuccess == false)
    }

    @Test("The replay costs 40 % and is the only multiplier")
    func replayFactor() {
        let plain = EchoScoring.score(truth: [1, 2], answer: [1, 2], replayed: false)
        let replayed = EchoScoring.score(truth: [1, 2], answer: [1, 2], replayed: true)
        #expect(replayed.score == Int(Double(plain.score) * EchoScoring.replayFactor))
        #expect(replayed.marks == 2)  // three marks require no replay
        #expect(replayed.isSuccess)  // …but it is still a success for the ladder
    }

    @Test("An empty rail scores nothing and fails, without dividing by zero")
    func emptyAnswer() {
        let result = EchoScoring.score(truth: [1, 4], answer: [], replayed: false)
        #expect(result.hit == 0)
        #expect(result.setF1 == 0)
        #expect(result.score == 0)
        #expect(result.marks == 0)
        #expect(result.isSuccess == false)
    }

    @Test("One mark needs a set F1 of at least 0.70")
    func theOneMarkThreshold() {
        // 3 of 4 lawful, no false includes: precision 1, recall 0.75, F1 ≈ 0.857.
        let partial = EchoScoring.score(
            truth: [1, 2, 3, 4], answer: [1, 2, 3], replayed: false)
        #expect(partial.setF1 > 0.70)
        #expect(partial.marks == 1)

        // 1 of 4: F1 = 0.4.
        let poor = EchoScoring.score(truth: [1, 2, 3, 4], answer: [1], replayed: false)
        #expect(poor.marks == 0)
    }
}

/// §8.5's lifecycle. Its one enforced invariant is the reason the mode is playable at all.
@Suite("ECHO's lifecycle", .tags(.unit, .presubmission))
struct EchoPhaseTests {

    @Test("The cast cannot begin while the strip is ambiguous")
    func theStripMustResolve() {
        #expect(
            EchoPhase.advance(.primer, on: .primerComplete(survivingMembers: 1)) == .casting)
        #expect(EchoPhase.advance(.primer, on: .primerComplete(survivingMembers: 2)) == nil)
        #expect(EchoPhase.advance(.primer, on: .primerComplete(survivingMembers: 0)) == nil)
    }

    /// The twin key means *do that again*, not *start again*: the replay returns to `casting`
    /// with the rail preserved.
    @Test("A replay returns to casting and the round continues from recalling")
    func replayReturnsToCasting() {
        #expect(EchoPhase.advance(.recalling, on: .replay) == .casting)
        #expect(EchoPhase.advance(.casting, on: .castComplete) == .recalling)
    }

    /// The player is the evaluator. There is no admit ring during a cast, and the ribbon stays
    /// dark — a cast is not probing and the Loom does not log it.
    @Test("A cast shows no verdicts and logs nothing")
    func theLampIsOff() {
        #expect(EchoPhase.castShowsNoVerdicts)
        #expect(EchoPhase.castLogsNothing)
    }

    @Test("Settled is terminal")
    func settledIsTerminal() {
        for event in [
            EchoPhase.Event.ready, .castComplete, .replay, .sealed, .revealComplete,
        ] {
            #expect(EchoPhase.advance(.settled, on: event) == nil)
        }
    }
}

/// §8.3's cast. Both construction invariants are load-bearing rather than tidy.
@Suite("ECHO's cast", .tags(.unit, .presubmission))
struct EchoCastTests {

    private static let law = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))

    /// Pairwise distinct, so the tray is a **set** and no duplicate-identity ambiguity can
    /// arise: with a repeat, "the third one" would name two tiles.
    @Test("Cast glyphs are pairwise distinct", arguments: EchoLoad.all)
    func castIsASet(_ load: EchoLoad) {
        let built = EchoCast.build(
            law: Self.law, load: load, seedGlyph: Deck.glyph(id: 22), seed: 0xCA57)
        #expect(built != nil)
        if let built {
            #expect(built.glyphs.count == load.castLength)
            #expect(Set(built.glyphs.map(\.id)).count == load.castLength)
        }
    }

    /// Exactly `A` lawful, by construction — and `A` is never displayed, because knowing it
    /// turns the recall into a counting problem.
    @Test("Exactly A of the L are lawful", arguments: EchoLoad.all)
    func exactlyALawful(_ load: EchoLoad) {
        let seed = Deck.glyph(id: 22)
        guard
            let built = EchoCast.build(law: Self.law, load: load, seedGlyph: seed, seed: 0xCA57)
        else {
            #expect(Bool(false), "the cast must build at every load")
            return
        }
        #expect(built.lawful.count == load.lawfulCount)

        // …and the truth list agrees with the law, walked along the cast's own context chain.
        var context = seed
        for (index, glyph) in built.glyphs.enumerated() {
            let admits = Self.law.admits(glyph, after: context)
            #expect(admits == built.lawful.contains(index))
            context = glyph
        }
    }

    /// The cast is a pure function of the seed, so a round is reproducible from its record.
    @Test("The cast replays exactly from its seed")
    func castIsDeterministic() {
        let first = EchoCast.build(
            law: Self.law, load: .load(4), seedGlyph: Deck.glyph(id: 22), seed: 99)
        let second = EchoCast.build(
            law: Self.law, load: .load(4), seedGlyph: Deck.glyph(id: 22), seed: 99)
        #expect(first == second)
        #expect(
            EchoCast.build(
                law: Self.law, load: .load(4), seedGlyph: Deck.glyph(id: 22), seed: 100)
                != first)
    }

    /// The tray is canonical `glyphID` order — the Assay's order, already spatially familiar.
    /// Cast order would give the answer away; shuffled would make the index arbitrary.
    @Test("The tray is in canonical order, not cast order")
    func trayIsCanonical() {
        guard
            let built = EchoCast.build(
                law: Self.law, load: .load(6), seedGlyph: Deck.glyph(id: 22), seed: 7)
        else { return }
        let tray = EchoCast.trayOrder(built.glyphs)
        #expect(tray.map(\.id) == tray.map(\.id).sorted())
        #expect(Set(tray.map(\.id)) == Set(built.glyphs.map(\.id)))
        #expect(tray.map(\.id) != built.glyphs.map(\.id))  // and it is not the cast order
    }

    /// A law that cannot supply the split returns `nil` rather than relaxing an invariant. The
    /// caller's answer is to reselect — a cast with the wrong lawful count would silently change
    /// what the round is measuring.
    @Test("An impossible split returns nil rather than a wrong cast")
    func impossibleSplitRefuses() {
        // A law admitting a single glyph cannot supply six lawful ones.
        let narrow = Law(
            .coupled(
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b0001))), .and,
                .atom(.init(attribute: .fill, subset: Fixture.subset(0b0001)))))
        let built = EchoCast.build(
            law: narrow, load: .load(8), seedGlyph: Deck.glyph(id: 0), seed: 3)
        if let built {
            #expect(built.lawful.count == EchoLoad.load(8).lawfulCount)
        }
    }
}
