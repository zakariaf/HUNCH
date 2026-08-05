public import Glyphs

/// The exhaustive form space of each family, and the guardrail predicate that turns it into
/// §5.2's `|H|`.
///
/// This is what makes the band populations a *measurement* rather than a quoted number. It is
/// deliberately in the shipping target rather than in a test, because the lower-band index
/// (T07) is built from exactly these sets at first launch.
public enum BandEnumeration {
    /// Every syntactic form of `band`'s family, before any guardrail.
    ///
    /// Family membership is exclusive BY CONSTRUCTION (§5.3, "strictly one family per band"),
    /// not by G4 — G4 only looks downward, and band 3 sits above band 2. So band 2's form
    /// space subtracts band 3's shape here; leaving the size-2/size-2 XORs in gives 1,290 and
    /// 90 rather than 1,272 and 108.
    public static func forms(for band: Band) -> [LawNode] {
        switch band {
        case .literal:
            atoms()

        case .pair:
            atomPairs().filter { !isExclusiveShape($0) }

        case .exclusive:
            atomPairs().filter { isExclusiveShape($0) }

        case .relational:
            relationals() + relationalWithAtom()

        case .contextual:
            contextuals() + contextualWithAtom()

        case .guarded:
            guards()

        case .composite:
            contextualWithContextual() + contextualWithRelational()

        case .systemic:
            aggregates()
        }
    }

    /// Band 3 is exactly the XOR of two 2-element subsets on distinct attributes — §5.2 calls
    /// this a theorem, not a guardrail: an XOR's marginals are `{p_T, 1 − p_T}`, so all sixteen
    /// equal `p` **iff** both subsets have size 2.
    public static func isExclusiveShape(_ node: LawNode) -> Bool {
        guard case .coupled(let l, .xor, let r) = node,
            case .atom(let a) = l, case .atom(let b) = r
        else { return false }
        return a.subset.count == 2 && b.subset.count == 2
    }

    public static func atoms() -> [LawNode] {
        Glyph.Attribute.allCases.flatMap { attribute in
            Subset4.all.map { LawNode.atom(.init(attribute: attribute, subset: $0)) }
        }
    }

    static func atomPairs() -> [LawNode] {
        var out: [LawNode] = []
        let attributes = Glyph.Attribute.allCases
        for i in attributes.indices {
            for j in attributes.indices where i < j {
                for s in Subset4.all {
                    for t in Subset4.all {
                        for coupler in Coupler.allCases {
                            out.append(
                                .coupled(
                                    .atom(.init(attribute: attributes[i], subset: s)),
                                    coupler,
                                    .atom(.init(attribute: attributes[j], subset: t))))
                        }
                    }
                }
            }
        }
        return out
    }

    static func relationals() -> [LawNode] {
        var out: [LawNode] = []
        let attributes = Glyph.Attribute.allCases
        for i in attributes.indices {
            for j in attributes.indices where i < j {
                for cmp in Comparator.allCases {
                    out.append(
                        .relational(
                            .init(leading: attributes[i], comparator: cmp, trailing: attributes[j])
                        ))
                }
            }
        }
        return out
    }

    static func relationalWithAtom() -> [LawNode] {
        relationals().flatMap { rel in
            atoms().flatMap { atom in
                Coupler.allCases.map { LawNode.coupled(rel, $0, atom) }
            }
        }
    }

    static func contextuals() -> [LawNode] {
        Glyph.Attribute.allCases.flatMap { current in
            Glyph.Attribute.allCases.flatMap { previous in
                Comparator.allCases.map {
                    LawNode.contextual(.init(current: current, comparator: $0, previous: previous))
                }
            }
        }
    }

    static func contextualWithAtom() -> [LawNode] {
        contextuals().flatMap { ctx in
            atoms().flatMap { atom in Coupler.allCases.map { LawNode.coupled(ctx, $0, atom) } }
        }
    }

    static func contextualWithContextual() -> [LawNode] {
        let all = contextuals()
        var out: [LawNode] = []
        for i in all.indices {
            for j in all.indices where i < j {
                for coupler in Coupler.allCases {
                    out.append(.coupled(all[i], coupler, all[j]))
                }
            }
        }
        return out
    }

    static func contextualWithRelational() -> [LawNode] {
        contextuals().flatMap { ctx in
            relationals().flatMap { rel in Coupler.allCases.map { LawNode.coupled(ctx, $0, rel) } }
        }
    }

    static func guards() -> [LawNode] {
        var out: [LawNode] = []
        for gate in Glyph.Attribute.allCases {
            for branch in Glyph.Attribute.allCases where gate != branch {
                for gateValue in UInt8(0)..<4 {
                    for then in Subset4.all {
                        for otherwise in Subset4.all where then != otherwise {
                            out.append(
                                .guarded(
                                    .init(
                                        gate: gate, gateValue: gateValue, branch: branch,
                                        then: then, otherwise: otherwise)))
                        }
                    }
                }
            }
        }
        return out
    }

    static func aggregates() -> [LawNode] {
        var out: [LawNode] = []
        for set in AttributeSet.all {
            out.append(.aggregate(.parity(.init(attributes: set, isOdd: false))))
            out.append(.aggregate(.parity(.init(attributes: set, isOdd: true))))
            for rankIn in Subset4.all {
                for countIn in CountSet.all(over: set.count) {
                    out.append(
                        .aggregate(
                            .count(.init(attributes: set, rankIn: rankIn, countIn: countIn))))
                }
            }
        }
        return out
    }

    /// Applies G1, G2, G3, G7, G5, G6 in that order, then G4 against the strictly lower bands,
    /// then dedups by extension. Returns the surviving distinct extensions.
    ///
    /// - Complexity: dominated by G5 (2 rebuilds per leaf) and G6 (up to 24 table permutes).
    ///   Bands 5 and 7 are minutes, not seconds — gate them `.nightly`.
    public static func survivors(for band: Band, excluding lower: LawSet) -> LawSet {
        var out = LawSet()
        for node in forms(for: band) {
            guard node.structuralFault == nil else { continue }
            let law = Law(node)
            let table = law.table

            guard table.isSatisfiable, table.isFalsifiable else { continue }  // G1, G2
            guard band.admitWindow.contains(table.admitRate) else { continue }  // G3
            if band.isContextual, table.isSecretlyStateless { continue }  // G7
            guard law.deadLeaves.isEmpty else { continue }  // G5
            guard law.hasLiveNamedAttributes else { continue }  // G6
            guard !lower.contains(table) else { continue }  // G4

            out.insert(table)
        }
        return out
    }
}
