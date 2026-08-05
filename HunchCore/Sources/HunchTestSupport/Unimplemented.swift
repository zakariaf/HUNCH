public import Testing

/// Thrown by a test double whose member was reached when the test did not expect it to be.
public struct UnimplementedError: Error, CustomStringConvertible, Equatable {
    public let member: String

    public init(_ member: String) {
        self.member = member
    }

    public var description: String { "\(member) was called unexpectedly" }
}

/// Records an issue against the CALLING test and throws (06 T38).
///
/// A double that silently returns a default is worse than no double: it turns "this dependency
/// was never meant to be touched here" into a passing test over the wrong behaviour.
public func unimplemented(
    _ member: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> Never {
    Issue.record("\(member) was called unexpectedly", sourceLocation: sourceLocation)
    throw UnimplementedError(member)
}

/// For members that cannot throw. Records, then returns the caller's placeholder so the
/// signature is satisfiable — the recorded issue is what fails the test.
public func unimplemented<T>(
    _ member: String,
    returning value: T,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T {
    Issue.record("\(member) was called unexpectedly", sourceLocation: sourceLocation)
    return value
}
