public import Glyphs

/// The abstract syntax tree of §3.2's BNF. Five productions, one coupler, **no `NOT`**.
///
/// The type is deliberately narrower than the grammar in three places, because a value that
/// cannot exist needs no guardrail: `Subset4` rejects the empty and full masks, `Contextual`
/// fixes `cur` on the leading side, and there is no negation case at all — §3.1's
/// complement-closure proof makes one unnecessary.
public indirect enum LawNode: Hashable, Sendable, Codable {
    case atom(Atom)
    case relational(Relational)
    case contextual(Contextual)
    case coupled(LawNode, Coupler, LawNode)
    case guarded(Guard)
    case aggregate(Aggregate)
}

extension LawNode {
    public struct Atom: Hashable, Sendable, Codable {
        public var attribute: Glyph.Attribute
        public var subset: Subset4

        public init(attribute: Glyph.Attribute, subset: Subset4) {
            self.attribute = attribute
            self.subset = subset
        }
    }

    /// `RANK a ⋈ RANK b`, attributes distinct.
    ///
    /// Both operand orders are **representable**: the Bench hands you whichever the player
    /// built, and RNF rule 3 reorders it and flips the comparator to compensate. Order is a
    /// normalisation concern, so `structuralFault` never reports it — only equal operands,
    /// which are constant and therefore outside the grammar (§3.3).
    public struct Relational: Hashable, Sendable, Codable {
        public var leading: Glyph.Attribute
        public var comparator: Comparator
        public var trailing: Glyph.Attribute

        public init(leading: Glyph.Attribute, comparator: Comparator, trailing: Glyph.Attribute) {
            self.leading = leading
            self.comparator = comparator
            self.trailing = trailing
        }
    }

    /// `RANK a(cur) ⋈ PREV RANK b`. The BNF fixes `cur` on the leading side, so the converse
    /// reading is reached by flipping the comparator and is **unrepresentable** here — RNF
    /// rule 3 made into a type rather than a pass (§3.4, §4.2).
    public struct Contextual: Hashable, Sendable, Codable {
        public var current: Glyph.Attribute
        public var comparator: Comparator
        public var previous: Glyph.Attribute

        public init(
            current: Glyph.Attribute, comparator: Comparator, previous: Glyph.Attribute
        ) {
            self.current = current
            self.comparator = comparator
            self.previous = previous
        }
    }

    public struct Guard: Hashable, Sendable, Codable {
        public var gate: Glyph.Attribute
        public var gateValue: UInt8  // 0...3, the rank-1 index into the attribute's values
        public var branch: Glyph.Attribute
        public var then: Subset4
        public var otherwise: Subset4

        public init(
            gate: Glyph.Attribute, gateValue: UInt8, branch: Glyph.Attribute,
            then: Subset4, otherwise: Subset4
        ) {
            self.gate = gate
            self.gateValue = gateValue
            self.branch = branch
            self.then = then
            self.otherwise = otherwise
        }
    }

    public enum Aggregate: Hashable, Sendable, Codable {
        case count(Count)
        case parity(Parity)

        public struct Count: Hashable, Sendable, Codable {
            public var attributes: AttributeSet
            public var rankIn: Subset4
            public var countIn: CountSet

            public init(attributes: AttributeSet, rankIn: Subset4, countIn: CountSet) {
                self.attributes = attributes
                self.rankIn = rankIn
                self.countIn = countIn
            }

            // CountSet's arity is not stored on the wire: it is a property of the sibling
            // `attributes` field, and decoding validates against it. Relaxing the type to a
            // bare UInt8 would let a 4-arity mask decode under a 3-attribute set.
            private enum CodingKeys: String, CodingKey {
                case attributes, rankIn, countIn
            }

            public init(from decoder: any Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                attributes = try c.decode(AttributeSet.self, forKey: .attributes)
                rankIn = try c.decode(Subset4.self, forKey: .rankIn)
                let raw = try c.decode(UInt8.self, forKey: .countIn)
                guard let set = CountSet(rawValue: raw, over: attributes.count) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .countIn, in: c,
                        debugDescription:
                            "countSet 0b\(String(raw, radix: 2)) is not a non-empty proper "
                            + "subset of 0…\(attributes.count)")
                }
                countIn = set
            }

            public func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(attributes, forKey: .attributes)
                try c.encode(rankIn, forKey: .rankIn)
                try c.encode(countIn.rawValue, forKey: .countIn)
            }
        }

        public struct Parity: Hashable, Sendable, Codable {
            public var attributes: AttributeSet
            public var isOdd: Bool

            public init(attributes: AttributeSet, isOdd: Bool) {
                self.attributes = attributes
                self.isOdd = isOdd
            }
        }
    }
}

/// One `(attribute, comparator, operand)` triple — the spelling §3.4's duplicate-leaf cap is
/// written in.
public struct Leaf: Hashable, Sendable {
    public enum Operand: Hashable, Sendable {
        case subset(Subset4)
        case rank(Glyph.Attribute)
        case previousRank(Glyph.Attribute)
        case value(UInt8)
    }

    public var attribute: Glyph.Attribute
    public var comparator: Comparator?
    public var operand: Operand
}

/// A fault, not a `Bool` (`W28`). `var isWellFormed: Bool` cannot answer *which* cap was
/// broken, and both the Seal bar and the generator's rejection loop need to know.
public enum StructuralFault: Hashable, Sendable {
    case depthExceeded(Int)
    case tooManyLeaves(Int)
    case tooManyRelationalTerms(Int)
    case tooManyContextualTerms(Int)
    case tooManyLeavesOnAttribute(Glyph.Attribute, Int)
    case duplicateLeaf
    case couplerOverNonTerm
    case relationalOperandsEqual(Glyph.Attribute)
    case guardGateEqualsBranch(Glyph.Attribute)
    case guardBranchesEqual(Glyph.Attribute)
}
