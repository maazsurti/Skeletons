import UIKit

/// The colours, timing and copy every skeleton draws with. Set `SkeletonTheme.current` once at
/// launch, before the first skeleton appears.
public struct SkeletonTheme {

    /// The fill of a placeholder block.
    public var base: UIColor

    /// The highlight that sweeps across the blocks.
    public var highlight: UIColor

    /// The corner radius a block uses when it does not name its own.
    public var cornerRadius: CGFloat

    /// How long one sweep takes, in seconds.
    public var shimmerDuration: TimeInterval

    /// The text VoiceOver reads for a skeleton container.
    public var loadingText: String

    /// Sweeps run from the trailing edge when this returns true.
    public var isRightToLeft: () -> Bool

    public init(
        base: UIColor = SkeletonTheme.defaultBase,
        highlight: UIColor = SkeletonTheme.defaultHighlight,
        cornerRadius: CGFloat = 8,
        shimmerDuration: TimeInterval = 1.2,
        loadingText: String = "Loading",
        isRightToLeft: @escaping () -> Bool = {
            UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        }
    ) {
        self.base = base
        self.highlight = highlight
        self.cornerRadius = cornerRadius
        self.shimmerDuration = shimmerDuration
        self.loadingText = loadingText
        self.isRightToLeft = isRightToLeft
    }

    /// A light grey block fill that lifts in dark mode.
    public static let defaultBase = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.14)
            : UIColor(white: 0.92, alpha: 1)
    }

    /// The sweep's highlight, brighter than the block fill in both appearances.
    public static let defaultHighlight = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.28)
            : UIColor(white: 1, alpha: 1)
    }

    nonisolated(unsafe) public static var current = SkeletonTheme()
}
