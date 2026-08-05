public import Laws

/// Non-optional constructors for the three validating grammar value types.
///
/// They exist so no test writes `!`. The types reject their degenerate values by design
/// (§3.2), and a test that names a legal literal should not have to unwrap — but it also must
/// not force-unwrap, because `NeverForceUnwrap` is on and suppressing it once per line is
/// noise that would train people to suppress it everywhere.
public enum Fixture {
    /// - Precondition: `raw` is in `1...14`.
    public static func subset(_ raw: UInt8) -> Subset4 {
        guard let value = Subset4(rawValue: raw) else {
            preconditionFailure("0b\(String(raw, radix: 2)) is not a legal <subset4> (§3.2)")
        }
        return value
    }

    /// - Precondition: `raw` names at least three attributes.
    public static func attributeSet(_ raw: UInt8) -> AttributeSet {
        guard let value = AttributeSet(rawValue: raw) else {
            preconditionFailure("0b\(String(raw, radix: 2)) is not a legal <attrSet> (§3.2)")
        }
        return value
    }

    /// - Precondition: `raw` is a non-empty proper subset of `0...arity`.
    public static func countSet(_ raw: UInt8, over arity: Int) -> CountSet {
        guard let value = CountSet(rawValue: raw, over: arity) else {
            preconditionFailure("0b\(String(raw, radix: 2)) is not a legal <countSet> at \(arity)")
        }
        return value
    }
}
