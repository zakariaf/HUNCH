public import Foundation

public import Glyphs

/// A difficulty band and, because §5.3 fixes strictly one family per band with no reprises,
/// also the law family. Two words in prose; one type in code (`08 §3`, `W28`).
///
/// The raw value is the band number 1…8 and is **never rendered** — §10.5 permits exactly three
/// signals of difficulty (the par row's length, the palette ceiling, the Codex shelves) and a
/// numeral is not one of them.
public enum Band: Int, CaseIterable, Sendable, Codable {
    case literal = 1, pair, exclusive, relational, contextual, guarded, composite, systemic
}

extension Band: Comparable {
    // A raw type suppresses SE-0266's synthesized `Comparable` (verified on Swift 6.3.3), so
    // the operator is written by hand.
    public static func < (lhs: Band, rhs: Band) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension Band {
    /// §5.7's locked row. Tabled, not derived: §5.4's `ceil(k·log₂|H| + d)` is the derivation,
    /// and `k`/`d` are design-time priors the harness may regenerate empirically.
    public var par: Int {
        switch self {
        case .literal: 7
        case .pair: 13
        case .exclusive: 16
        case .relational: 20
        case .contextual: 23
        case .guarded: 23
        case .composite: 26
        case .systemic: 29
        }
    }

    /// Computed, never tabled. Two rows that must agree are one row too many.
    public var cap: Int { Int((1.6 * Double(par)).rounded(.up)) }

    /// §5.2's `|H|`, enumerated exhaustively over the real deck. T08 is what proves it.
    public var population: Int {
        switch self {
        case .literal: 40
        case .pair: 1_272
        case .exclusive: 108
        case .relational: 2_322
        case .contextual: 6_934
        case .guarded: 5_688
        case .composite: 10_314
        case .systemic: 337
        }
    }

    /// §5.2's `log₂|H|` column, derived.
    public var informationContent: Double { log2(Double(population)) }

    /// §5.4's friction coefficient — how far a real reasoner falls short of the one-bit-per-
    /// probe bound. A design-time prior; H12 may regenerate it.
    public var frictionCoefficient: Double {
        switch self {
        case .literal: 1.15
        case .pair: 1.15
        case .exclusive: 1.80
        case .relational: 1.40
        case .contextual: 1.35
        case .guarded: 1.40
        case .composite: 1.55
        case .systemic: 2.40
        }
    }

    /// §5.4's discovery cost — probes spent working out *what kind* of law this is before the
    /// search proper begins.
    public var discoveryCost: Int {
        switch self {
        case .literal: 0
        case .pair: 1
        case .exclusive: 3
        case .relational: 4
        case .contextual: 5
        case .guarded: 5
        case .composite: 5
        case .systemic: 8
        }
    }

    /// Half-open, so `[0.000, 1.000)` tiles exactly (§5.7).
    public var difficultyRange: Range<Double> {
        Double(rawValue - 1) * 0.125..<Double(rawValue) * 0.125
    }

    public var centre: Double { (difficultyRange.lowerBound + difficultyRange.upperBound) / 2 }

    /// G3, identical in every band (§5.3). It lives here because that is where callers reach
    /// for it, not because it varies.
    public var admitWindow: ClosedRange<Double> { 0.15...0.60 }

    /// §5.1's `m1` subtrahend.
    ///
    /// For seven bands this is the family's minimum leaf count. **Band 8 is 4, not 3**, and
    /// the epic's reconstructed table says 3 — but §5.2's published δ for the parity exemplar
    /// is 0.928, and only `minLeaves = 4` reproduces it (3 gives 0.9433). The consequence is
    /// coherent rather than a fudge: a 3-attribute COUNT clamps to 0 as well, so leaf count
    /// carries NO difficulty signal anywhere inside band 8 — which is exactly §5.2's own
    /// argument that band 8 is hard by SYMMETRY, not by size. See DECISIONS.md.
    public var minLeaves: Int {
        switch self {
        case .literal: 1
        case .pair: 2
        case .exclusive: 2
        case .relational: 1
        case .contextual: 1
        case .guarded: 3
        case .composite: 2
        case .systemic: 4
        }
    }

    /// Bands 5 and 7 — G7's scope, the two contextual hash runs, and the two bands DRIFT and
    /// SIEVE treat specially.
    public var isContextual: Bool { self == .contextual || self == .composite }
}

extension Band {
    /// §5.2's "Example law" column — the family's deterministic anchor.
    ///
    /// The generator falls back to this when 200 attempts fail. Deliberately the *same* law
    /// §5.2 reaches for when it needs one: inventing a ninth set of fallback laws would be a
    /// second source of truth for "what a band-*b* law looks like".
    ///
    /// It satisfies G1–G7, G8's membership clause and G10 by construction, and is exempt only
    /// from G8's proximity clause and from G9 — a last resort that can itself be vetoed is not
    /// a last resort (§5.3).
    public var anchor: LawNode {
        func subset(_ raw: UInt8) -> Subset4 {
            guard let s = Subset4(rawValue: raw) else { preconditionFailure("bad anchor subset") }
            return s
        }
        func attributeSet(_ raw: UInt8) -> AttributeSet {
            guard let s = AttributeSet(rawValue: raw) else { preconditionFailure("bad anchor set") }
            return s
        }
        switch self {
        case .literal:
            return .atom(.init(attribute: .fill, subset: subset(0b0100)))
        case .pair:
            return .coupled(
                .atom(.init(attribute: .shape, subset: subset(0b1010))), .and,
                .atom(.init(attribute: .pips, subset: subset(0b1100))))
        case .exclusive:
            return .coupled(
                .atom(.init(attribute: .shape, subset: subset(0b0011))), .xor,
                .atom(.init(attribute: .fill, subset: subset(0b0011))))
        case .relational:
            return .relational(.init(leading: .shape, comparator: .eq, trailing: .pips))
        case .contextual:
            return .contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        case .guarded:
            return .guarded(
                .init(
                    gate: .hue, gateValue: 0, branch: .pips,
                    then: subset(0b1100), otherwise: subset(0b0001)))
        case .composite:
            return .coupled(
                .contextual(.init(current: .hue, comparator: .eq, previous: .hue)), .xor,
                .relational(.init(leading: .shape, comparator: .lt, trailing: .pips)))
        case .systemic:
            return .aggregate(.parity(.init(attributes: attributeSet(0b1111), isOdd: false)))
        }
    }
}
