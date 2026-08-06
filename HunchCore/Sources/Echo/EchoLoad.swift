public import Foundation

/// §8.6's load index. Because the law is the player's own, ECHO's difficulty knob is `ℓ ∈ 1…8`
/// and **not the law** — which is also why ECHO is the only mode whose difficulty says nothing
/// about the grammar.
public struct EchoLoad: Equatable, Sendable {
    public let index: Int
    /// Cast length.
    public let castLength: Int
    /// Lawful glyphs in the cast. **Never displayed, anywhere, at any point** — knowing `A`
    /// turns the recall into a counting problem.
    public let lawfulCount: Int
    public let cadenceMilliseconds: Int

    public static let all: [EchoLoad] = [
        EchoLoad(index: 1, castLength: 6, lawfulCount: 2, cadenceMilliseconds: 1_400),
        EchoLoad(index: 2, castLength: 8, lawfulCount: 3, cadenceMilliseconds: 1_300),
        EchoLoad(index: 3, castLength: 9, lawfulCount: 3, cadenceMilliseconds: 1_200),
        EchoLoad(index: 4, castLength: 10, lawfulCount: 4, cadenceMilliseconds: 1_100),
        EchoLoad(index: 5, castLength: 11, lawfulCount: 4, cadenceMilliseconds: 1_000),
        EchoLoad(index: 6, castLength: 12, lawfulCount: 5, cadenceMilliseconds: 950),
        EchoLoad(index: 7, castLength: 13, lawfulCount: 5, cadenceMilliseconds: 900),
        EchoLoad(index: 8, castLength: 14, lawfulCount: 6, cadenceMilliseconds: 850),
    ]

    public static func load(_ index: Int) -> EchoLoad {
        all[min(all.count - 1, max(0, index - 1))]
    }

    /// The whole cast, in seconds — what the player actually sits through.
    public var castSeconds: Double {
        Double(castLength * cadenceMilliseconds) / 1_000
    }

    /// §8.3's per-glyph envelope: 120 ms in, `cadence − 240` hold, 120 ms out.
    public static let drawInMilliseconds = 120
    public static let withdrawMilliseconds = 120

    public var holdMilliseconds: Int {
        cadenceMilliseconds - EchoLoad.drawInMilliseconds - EchoLoad.withdrawMilliseconds
    }
}
