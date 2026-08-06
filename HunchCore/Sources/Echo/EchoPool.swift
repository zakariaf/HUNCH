public import Foundation

public import Glyphs
public import Laws

/// §8.2's echo pool: the last **8** laws inscribed in the Codex, in any mode.
///
/// ECHO never generates a law — it *selects* — which is why it bypasses G9's novelty guard by
/// construction. Eight because it is exactly three bits, and three bits is exactly what a
/// three-glyph primer carries.
public struct EchoPool: Equatable, Sendable {

    public static let capacity = 8
    /// Below this the primer cannot separate and ECHO is unavailable for the session.
    public static let minimumForPlay = 3
    /// §9.10's unlock: under five Codex pages ECHO is **absent from the mode rack**, not greyed
    /// with an explanation — a locked door with a sign on it is a worse door.
    public static let unlockPageCount = 5

    /// Codex order, oldest leading. The pool is a function of the **Codex**, not of the session:
    /// switching modes does not move it, and a loss inscribes nothing, so ECHO still holds the
    /// last *successful* laws.
    public let members: [Law]

    public init(members: [Law]) {
        self.members = Array(members.suffix(EchoPool.capacity))
    }

    public var isPlayable: Bool { members.count >= EchoPool.minimumForPlay }

    /// §8.2's primer: `m` glyphs whose verdict vector is **unique across the pool** — it
    /// identifies which member is in force, and no other member could have produced it.
    ///
    /// The uniqueness is what guarantees the strip resolves: `m = 3` separates at most 8
    /// members, `m = 4` at most 16, `m = 5` at most 32, and the pool is 8 — so a separating
    /// chain, when one exists, always extinguishes exactly seven thumbnails.
    public struct Primer: Equatable, Sendable {
        public let seedGlyph: Glyph
        public let glyphs: [Glyph]
        /// One entry per pool member, in pool order.
        public let verdictVectors: [[Verdict]]
        public let inForce: Int

        public init(
            seedGlyph: Glyph, glyphs: [Glyph], verdictVectors: [[Verdict]], inForce: Int
        ) {
            self.seedGlyph = seedGlyph
            self.glyphs = glyphs
            self.verdictVectors = verdictVectors
            self.inForce = inForce
        }

        public var length: Int { glyphs.count }
    }

    public static let primerLengths = [3, 4, 5]

    /// The verdict vector a member produces for a chain. Adjacent pairs supply `prev`, with the
    /// seed glyph priming position 0 — which is what makes a contextual member separable at all.
    public static func verdicts(of law: Law, over chain: [Glyph], seedGlyph: Glyph) -> [Verdict] {
        var context = seedGlyph
        var out: [Verdict] = []
        for glyph in chain {
            out.append(Verdict(admits: law.admits(glyph, after: context)))
            context = glyph
        }
        return out
    }

    /// Whether a chain separates the pool: every member's vector is distinct, so exactly one
    /// thumbnail survives.
    public func separates(_ chain: [Glyph], seedGlyph: Glyph) -> Bool {
        let vectors = members.map {
            EchoPool.verdicts(of: $0, over: chain, seedGlyph: seedGlyph)
        }
        return Set(vectors.map { $0.map(\.rawValue) }).count == members.count
    }

    /// Which members survive after `count` primer glyphs have resolved. The strip eliminates
    /// **on screen**, one ring at a time, and this is what it eliminates against.
    public func surviving(after count: Int, primer: Primer) -> Set<Int> {
        let target = Array(primer.verdictVectors[primer.inForce].prefix(count))
        return Set(
            primer.verdictVectors.indices.filter {
                Array(primer.verdictVectors[$0].prefix(count)) == target
            })
    }
}
