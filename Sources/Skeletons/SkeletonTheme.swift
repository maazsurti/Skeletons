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

    /// The delay, in seconds, between one block's sweep and the next block's. The blocks on
    /// screen cross in a wave rather than together. Zero puts them all back in phase. Read in
    /// `.component` alignment only; a `.window` screen sweeps every block together.
    public var shimmerStagger: TimeInterval

    /// The stripe's lean from vertical, in degrees: `0` is an upright band, `45` a quarter-turn
    /// diagonal, and a negative value leans it the other way. Read as at most 80° either side, so
    /// the band keeps its width. The default is `20`. Right-to-left layouts mirror it.
    public var shimmerAngle: CGFloat {
        get { angle }
        set { angle = min(max(newValue, -Self.maxShimmerAngle), Self.maxShimmerAngle) }
    }

    /// How the highlight lines up across the skeletons on a screen.
    public var shimmerAlignment: SkeletonShimmerAlignment

    /// The stripe's tangent: how much of its `shimmerAngle` it gains across for each point down.
    var shimmerTangent: CGFloat {
        tan(shimmerAngle * .pi / 180)
    }

    /// The steepest a stripe may lean, in degrees.
    static let maxShimmerAngle: CGFloat = 80

    private var angle: CGFloat

    /// The shortest rest, in seconds, the band takes between one pass and the next. It is added to
    /// the pass, so every repeat begins with the whole band off the window for at least this long.
    /// Negative values are read as zero.
    public var shimmerMinRest: TimeInterval

    /// The text VoiceOver reads for a skeleton container.
    public var loadingText: String

    /// Sweeps run from the trailing edge when this returns true.
    public var isRightToLeft: () -> Bool

    /// The gap a layout uses between its elements when one is not named.
    public var spacing: CGFloat

    /// The corner radius a card uses when it does not name its own.
    public var cardRadius: CGFloat

    /// The soft shadow a card can draw.
    public var shadow: SkeletonShadow

    /// The height of one line box for a font size. Set it to your app's font metrics so a line block
    /// lands exactly where the label it replaces will.
    public var lineHeight: (CGFloat) -> CGFloat

    /// The fill of a loading field or picker row.
    public var fieldSurface: UIColor

    /// The border a loading field or picker row draws.
    public var fieldBorder: UIColor

    /// The colour of the label and icon that stay readable inside a loading field.
    public var fieldText: UIColor

    /// The font that label is drawn in.
    public var fieldTextFont: UIFont

    /// The height a loading field uses when it does not name its own.
    public var fieldHeight: CGFloat

    /// The corner radius a loading field uses when it does not name its own.
    public var fieldRadius: CGFloat

    /// The inset from a loading field's leading and trailing edges when it does not name its own.
    public var fieldPadding: CGFloat

    public init(
        base: UIColor = SkeletonTheme.defaultBase,
        highlight: UIColor = SkeletonTheme.defaultHighlight,
        cornerRadius: CGFloat = 8,
        shimmerDuration: TimeInterval = 1.7,
        shimmerStagger: TimeInterval = 0.10,
        shimmerMinRest: TimeInterval = 0.25,
        shimmerAlignment: SkeletonShimmerAlignment = .component,
        shimmerAngle: CGFloat = 20,
        loadingText: String = "Loading",
        isRightToLeft: @escaping () -> Bool = {
            UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        },
        spacing: CGFloat = 8,
        cardRadius: CGFloat = 16,
        shadow: SkeletonShadow = .card,
        lineHeight: @escaping (CGFloat) -> CGFloat = { ceil(UIFont.systemFont(ofSize: $0).lineHeight) },
        fieldSurface: UIColor = SkeletonTheme.defaultFieldSurface,
        fieldBorder: UIColor = SkeletonTheme.defaultFieldBorder,
        fieldText: UIColor = SkeletonTheme.defaultFieldText,
        fieldTextFont: UIFont = UIFont.systemFont(ofSize: 16),
        fieldHeight: CGFloat = 54,
        fieldRadius: CGFloat = 12,
        fieldPadding: CGFloat = 14
    ) {
        self.base = base
        self.highlight = highlight
        self.cornerRadius = cornerRadius
        self.shimmerDuration = shimmerDuration
        self.shimmerStagger = shimmerStagger
        self.shimmerMinRest = shimmerMinRest
        self.shimmerAlignment = shimmerAlignment
        self.angle = min(max(shimmerAngle, -Self.maxShimmerAngle), Self.maxShimmerAngle)
        self.loadingText = loadingText
        self.isRightToLeft = isRightToLeft
        self.spacing = spacing
        self.cardRadius = cardRadius
        self.shadow = shadow
        self.lineHeight = lineHeight
        self.fieldSurface = fieldSurface
        self.fieldBorder = fieldBorder
        self.fieldText = fieldText
        self.fieldTextFont = fieldTextFont
        self.fieldHeight = fieldHeight
        self.fieldRadius = fieldRadius
        self.fieldPadding = fieldPadding
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

    /// A field's own fill: white on a light screen, a quiet lift on a dark one.
    public static let defaultFieldSurface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.06)
            : UIColor(white: 1, alpha: 1)
    }

    /// A field's 1 pt border, muted in both appearances.
    public static let defaultFieldBorder = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.18)
            : UIColor(white: 0.85, alpha: 1)
    }

    /// The placeholder inside a field, muted in both appearances.
    public static let defaultFieldText = UIColor.placeholderText

    nonisolated(unsafe) public static var current = SkeletonTheme()
}

/// How the highlight lines up across the skeletons on one screen.
public enum SkeletonShimmerAlignment: Sendable {

    /// Each container runs its own wave: the components below the top one cross a stagger apart,
    /// and a card's blocks draw one slash of their own.
    case component

    /// Every skeleton on the window crosses at once, on one line that runs across cards,
    /// sections and containers.
    case window
}

/// The soft shadow a skeleton card can draw, so a placeholder card reads as the raised card it
/// stands in for.
public struct SkeletonShadow {
    public var color: UIColor
    public var opacity: Float
    public var radius: CGFloat
    public var offset: CGSize

    public init(
        color: UIColor = .black,
        opacity: Float = 0.05,
        radius: CGFloat = 9,
        offset: CGSize = CGSize(width: 0, height: 5)
    ) {
        self.color = color
        self.opacity = opacity
        self.radius = radius
        self.offset = offset
    }

    /// No shadow.
    public static let none = SkeletonShadow(opacity: 0, radius: 0, offset: .zero)

    /// A raised card's shadow.
    public static let card = SkeletonShadow()

    /// Draws this shadow on `view`. The view keeps its own corner radius; it must not clip to
    /// bounds, or the shadow is cut off.
    public func apply(to view: UIView) {
        view.layer.shadowColor = color.cgColor
        view.layer.shadowOpacity = opacity
        view.layer.shadowRadius = radius
        view.layer.shadowOffset = offset
    }
}
