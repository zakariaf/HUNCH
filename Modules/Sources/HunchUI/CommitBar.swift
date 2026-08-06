public import SwiftUI

internal import Tokens

/// The three-slot commit bar: **PROBE** (leading) · **twin** (centre) · **Bench** (trailing).
///
/// A *slot* abstraction rather than three children, because §12.6's Left-hand keys setting
/// mirrors exactly two things — the commit bar's order and the Bench handle's side — and
/// mirroring three hard-coded children later means editing every caller. Here it is one flag.
///
/// The bar carries no text of its own in any locale (§12.9): each slot is a key face drawn by
/// its own view, and the only thing this type owns is where the three sit.
public struct CommitBar<Leading: View, Centre: View, Trailing: View>: View {

    /// §12.6: the *layout direction* is the system's and belongs to SwiftUI; **Left-hand keys**
    /// is the player's, applies only to the commit bar and the Bench handle, and composes with
    /// it. Two independent mirrors, so a left-handed player under RTL gets both.
    public var mirrorsKeys: Bool

    private let leading: Leading
    private let centre: Centre
    private let trailing: Trailing

    public init(
        mirrorsKeys: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder centre: () -> Centre,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.mirrorsKeys = mirrorsKeys
        self.leading = leading()
        self.centre = centre()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Space.s4) {
            if mirrorsKeys {
                trailing
                centre
                leading
            } else {
                leading
                centre
                trailing
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Space.marginOuter)
    }
}
