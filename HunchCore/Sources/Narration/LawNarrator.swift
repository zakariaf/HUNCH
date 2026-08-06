public import Glyphs
public import Laws

/// §13.10's Bench narration — **the only place in the app where a law appears in words**, and
/// it is audio-only, so the no-text rule is intact.
///
/// Three rules, and the third is the one worth a test:
///
/// 1. It describes **only the player's own draft or an already-revealed law**, never a hidden
///    law mid-round. The type cannot enforce that — both are `Law` — so the call sites do, and
///    `NarrationScope` makes the intent visible at each one.
/// 2. It uses the same string fragments as the Codex page, so a narrated law and a rendered law
///    are the same law in two media.
/// 3. **Parity**: it says nothing a sighted player cannot read off the tiles. Asserted by
///    walking laws and checking that the narration's own structure matches the AST the Bench
///    would lay out — one sentence per term, one clause per leaf, in RNF order.
public enum LawNarrator {

    /// Which law is being narrated, stated at the call site. A hidden law has no case here.
    public enum Scope: Equatable, Sendable {
        /// The draft on the Bench right now.
        case playerDraft
        /// A law the round has already revealed, or a Codex page.
        case revealed
    }

    /// One narration, as **structure** rather than as a string.
    ///
    /// Keeping it structured is what makes the parity test possible at all: comparing two
    /// sentences is comparing two translations, and comparing two clause lists is comparing two
    /// readings of the same AST.
    public struct Narration: Equatable, Sendable {
        public enum Clause: Equatable, Sendable {
            /// `attr ∈ {…}` — one Ramp.
            case admits(Glyph.Attribute, Subset4)
            /// `RANK a ⋈ RANK b` — a Bridge with both sockets on the current glyph.
            case compare(Glyph.Attribute, Comparator, Glyph.Attribute)
            /// `RANK a(cur) ⋈ PREV RANK b` — a Bridge with the trailing socket ghosted.
            case compareWithPrevious(Glyph.Attribute, Comparator, Glyph.Attribute)
            /// A Fork: the gate, then each branch.
            case guarded(gate: Glyph.Attribute, gateValue: UInt8, branch: Glyph.Attribute)
            /// A Tally.
            case aggregate(counted: Int)
        }

        public let clauses: [Clause]
        public let coupler: Coupler?
        public let scope: Scope
    }

    public static func narrate(_ law: Law, scope: Scope) -> Narration {
        var clauses: [Narration.Clause] = []
        var coupler: Coupler?
        walk(law.node, into: &clauses, coupler: &coupler)
        return Narration(clauses: clauses, coupler: coupler, scope: scope)
    }

    private static func walk(
        _ node: LawNode, into clauses: inout [Narration.Clause], coupler: inout Coupler?
    ) {
        switch node {
        case .atom(let atom):
            clauses.append(.admits(atom.attribute, atom.subset))
        case .relational(let relational):
            clauses.append(
                .compare(relational.leading, relational.comparator, relational.trailing))
        case .contextual(let contextual):
            clauses.append(
                .compareWithPrevious(
                    contextual.current, contextual.comparator, contextual.previous))
        case .coupled(let left, let junction, let right):
            coupler = junction
            walk(left, into: &clauses, coupler: &coupler)
            walk(right, into: &clauses, coupler: &coupler)
        case .guarded(let guardNode):
            clauses.append(
                .guarded(
                    gate: guardNode.gate, gateValue: guardNode.gateValue,
                    branch: guardNode.branch))
        case .aggregate(let aggregate):
            clauses.append(.aggregate(counted: aggregate.countedAttributeCount))
        }
    }
}

extension LawNode.Aggregate {
    /// How many attributes the Tally counts — the one number its narration needs.
    public var countedAttributeCount: Int {
        switch self {
        case .count(let count): count.attributes.count
        case .parity(let parity): parity.attributes.count
        }
    }
}
