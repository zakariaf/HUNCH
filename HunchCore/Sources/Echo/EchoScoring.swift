public import Foundation

/// §8.7's scoring. ECHO is the only mode that asks the player to **use** a law rather than find
/// one, and the score's shape says so: the *set* is squared and the *order* is a bounded 30 %.
public enum EchoScoring {

    public struct Result: Equatable, Sendable {
        public let hit: Int
        public let falseIncludes: Int
        public let lawfulCount: Int
        public let setF1: Double
        public let order: Double
        public let replayed: Bool
        public let score: Int
        public let marks: Int

        /// **Success for the Rasch update iff `setF1 == 1.0`** — the right set, regardless of
        /// order. Order is never a pass/fail condition; making it one would score a player who
        /// applied the law perfectly and mis-remembered a sequence as having failed to apply it.
        public var isSuccess: Bool { setF1 == 1.0 }
    }

    /// One replay, at ×0.6. The twin key already means *do that again* in PROBE.
    public static let replayFactor = 0.6

    /// - Parameters:
    ///   - truth: the ordered lawful cast indices.
    ///   - answer: the ordered cast indices on the rail.
    public static func score(truth: [Int], answer: [Int], replayed: Bool) -> Result {
        let truthSet = Set(truth)
        let matched = answer.filter { truthSet.contains($0) }
        let hit = Set(matched).count
        let falseIncludes = answer.count - matched.count

        let precision = Double(hit) / Double(max(1, answer.count))
        let recall = Double(hit) / Double(max(1, truth.count))
        let setF1 =
            hit == 0 ? 0 : 2 * precision * recall / (precision + recall)

        // The longest increasing subsequence of the correctly-included indices, by cast index:
        // how much of the order the player got right, among the glyphs they got right at all.
        let order = hit == 0 ? 0 : Double(longestIncreasingSubsequence(matched)) / Double(hit)

        let raw =
            1_000 * setF1 * setF1 * (0.70 + 0.30 * order) * (replayed ? replayFactor : 1.0)
        let score = Int(raw.rounded(.toNearestOrAwayFromZero))

        let marks: Int =
            if setF1 == 1, order == 1, !replayed {
                3
            } else if setF1 == 1 {
                2
            } else if setF1 >= 0.70 {
                1
            } else {
                0
            }

        return Result(
            hit: hit, falseIncludes: falseIncludes, lawfulCount: truth.count, setF1: setF1,
            order: order, replayed: replayed, score: score, marks: marks)
    }

    static func longestIncreasingSubsequence(_ values: [Int]) -> Int {
        var tails: [Int] = []
        for value in values {
            var low = 0
            var high = tails.count
            while low < high {
                let mid = (low + high) / 2
                if tails[mid] < value { low = mid + 1 } else { high = mid }
            }
            if low == tails.count { tails.append(value) } else { tails[low] = value }
        }
        return tails.count
    }
}
