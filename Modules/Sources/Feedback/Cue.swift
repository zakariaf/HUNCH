public import Glyphs

/// What happened **in the game** — never what to play.
///
/// One enum drives both players. A verdict is one event that happens to have a sound and a
/// feel; two enums would let them diverge, and the whole design rests on their landing on the
/// same frame.
///
/// The counts do not match on purpose: twelve cases, fifteen audio cues, eleven haptic
/// patterns. `.verdict(_:isTwin:)` covers four sounds and three feels, while `.codexInscribe`
/// has a sound and no feel. Model the event; let each player resolve it. That is also what
/// makes `SilentCuePlayer` a legitimate implementation rather than a stub — a player with Sound
/// and Haptics both off loses redundancy, not information.
public enum Cue: Hashable, Sendable {
    case probeSubmit
    case verdict(Verdict, isTwin: Bool)
    case declare
    case bar
    case strike
    /// 1…3 — parameterises audio and haptic together.
    case lawDeclaredCorrectly(marks: Int)
    case lawBroken
    case driftMoment
    /// 1…5, capped.
    case streak(step: Int)
    case codexInscribe
    case sieveTick
    case sieveHit
    case sieveMiss
}
