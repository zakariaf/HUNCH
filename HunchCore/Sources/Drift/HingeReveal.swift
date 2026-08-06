public import Foundation

public import Tokens

/// §7.9's reveal — five steps, and the whole of it is **decoration over settled state**.
/// Adjudication commits to disk before the animation starts, so it can be skipped, interrupted,
/// or replayed from the Codex without changing anything.
public enum HingeReveal {

    public enum Step: String, CaseIterable, Sendable {
        /// A hairline sweeps the ribbon leading→trailing and stops at `t_hinge`.
        case seam
        /// Every tile is re-evaluated under both laws: the ones `L₁` explains rise, the ones
        /// `L₂` explains fall, the ones both explain hold. The ribbon becomes two lanes forking
        /// at the seam — a picture of *your evidence was about two different machines*.
        case split
        /// Tiles probed after `t_evidence` that lie in the agreement set drop to 25 % and take
        /// the diagonal cancel hatch. **No count, no label**: the player simply sees how long
        /// the useless run was.
        case deadStretch
        /// `L₁` assembles above the seam and `L₂` below, except the shared leaves do not
        /// redraw — they *slide down*. **Only the edited leaf animates.**
        case morph
        /// Two laws, one moving part, three seconds of silence.
        case hold
    }

    public static func duration(of step: Step) -> Duration {
        switch step {
        case .seam: .milliseconds(500)
        case .split: .milliseconds(400)
        case .deadStretch: .milliseconds(300)
        case .morph: .milliseconds(900)
        case .hold: .seconds(3)
        }
    }

    /// The tile displacement in the split. Equal and opposite, because neither law is the
    /// privileged one — the picture is a fork, not a correction.
    public static let splitDisplacement = 18.0
    public static let deadStretchOpacity = 0.25

    /// **The single moving part.** One ramp cell extinguishing while another ignites, one wedge
    /// rotating, or one gate cell moving — because `L₂` is a one-leaf edit of `L₁` (§7.2), and
    /// that is what makes the reveal land in one glance instead of asking the player to diff two
    /// diagrams.
    public static let animatedLeafCount = 1

    /// Reduce Motion replaces steps 1–4 with four crossfades of the **same total duration**.
    /// The two-lane geometry and the single changed leaf remain, because they are *information*,
    /// not motion — dropping them would make the accessible reveal a different, worse reveal.
    public static var reduceMotionTotal: Duration {
        Step.allCases.filter { $0 != .hold }.reduce(Duration.zero) { $0 + duration(of: $1) }
    }

    public static var total: Duration {
        Step.allCases.reduce(Duration.zero) { $0 + duration(of: $1) }
    }
}
