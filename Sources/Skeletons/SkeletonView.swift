import UIKit

/// One placeholder block. The host screen places it inside its own cards and cells; the view draws
/// only its own fill, corner radius and shimmer, and never constrains itself beyond the size its
/// factory was given.
@MainActor
public final class SkeletonView: UIView {

    private let fill = UIView()

    /// The band's container. It carries the sweep's x translation, so the stripe's rotation never
    /// meets the animation: one layer moves, the other is only ever tilted.
    private let highlight = CALayer()

    /// The stripe itself: a gradient tilted 45°, drawn taller than the block so its ends leave the
    /// block as it crosses.
    private let band = CAGradientLayer()

    private var widthFraction: CGFloat?
    private var fractionConstraint: NSLayoutConstraint?
    private var sweepSignature: String?
    private var isPulsing = false

    /// The place this block's component takes in its screen's wave, read once and kept while the
    /// block stays on screen.
    var sweepPlace: SweepOrder.Place?

    /// The window group this block was placed by, kept after the block leaves the window.
    weak var looseGroup: LooseSweepGroup?

    /// The window-wide wave this block joined, kept after the block leaves the window so it can
    /// leave the group it joined.
    weak var windowClock: WindowSweepClock?

    weak var cornerSource: UIView?

    /// Whether this block is on screen and should take a place in the wave.
    var isSweeping: Bool {
        window != nil && !isHidden && isShimmering && bounds.width > 0 && bounds.height > 0
    }

    /// Pins the Reduce Motion setting, for the tests that check the pulse. Nil reads the system
    /// setting.
    nonisolated(unsafe) static var reduceMotionOverride: Bool?

    private var isReduceMotionEnabled: Bool {
        SkeletonView.reduceMotionOverride ?? UIAccessibility.isReduceMotionEnabled
    }

    private static let sweepKey = "shimmer"

    // MARK: - Factories

    /// A single line of placeholder text. Without `width` or `widthFraction` the line takes
    /// whatever width its container gives it. `radius` rounds the line; it falls back to the
    /// theme's radius.
    public static func line(
        height: CGFloat = 14,
        width: CGFloat? = nil,
        widthFraction: CGFloat? = nil,
        radius: CGFloat? = nil,
        corners: CACornerMask = .skeletonAllCorners
    ) -> SkeletonView {
        let view = SkeletonView(cornerRadius: radius, corners: corners)
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        if let width {
            view.setPreferredWidth(width)
        } else if let widthFraction {
            view.widthFraction = widthFraction
        }
        return view
    }

    /// A round block, for avatars, icons and thumbnails.
    public static func circle(diameter: CGFloat) -> SkeletonView {
        let view = SkeletonView(cornerRadius: diameter / 2)
        view.setPreferredWidth(diameter)
        view.heightAnchor.constraint(equalToConstant: diameter).isActive = true
        return view
    }

    /// A block of any size. Give it constraints from the host screen, or `height` here.
    public static func block(height: CGFloat? = nil, cornerRadius: CGFloat? = nil) -> SkeletonView {
        let view = SkeletonView(cornerRadius: cornerRadius)
        if let height {
            view.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        return view
    }

    // MARK: - Lifecycle

    /// A block filled with the theme's base colour. `cornerRadius` falls back to the theme's.
    /// `corners` names which corners round.
    public init(
        cornerRadius: CGFloat? = nil,
        corners: CACornerMask = .skeletonAllCorners
    ) {
        super.init(frame: .zero)

        let theme = SkeletonTheme.current
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        fill.isUserInteractionEnabled = false
        fill.backgroundColor = theme.base
        fill.layer.cornerRadius = cornerRadius ?? theme.cornerRadius
        fill.layer.cornerCurve = .continuous
        fill.layer.maskedCorners = corners
        fill.clipsToBounds = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        fill.layer.addSublayer(highlight)
        highlight.addSublayer(band)
        NSLayoutConstraint.activate([
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.trailingAnchor.constraint(equalTo: trailingAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        paintHighlight()
        observeAppearance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The app builds its UI in code; init(coder:) is not supported")
    }

    /// Runs or stops this block's shimmer. A stopped block is drawn as a flat fill.
    public var isShimmering = true {
        didSet {
            guard isShimmering != oldValue else { return }
            updateAnimation(force: true)
        }
    }

    public override var isHidden: Bool {
        didSet { updateAnimation(force: false) }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        sweepPlace = nil
        updateAnimation(force: true)
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        fractionConstraint?.isActive = false
        fractionConstraint = nil
        guard let superview, let widthFraction else { return }
        let constraint = widthAnchor.constraint(equalTo: superview.widthAnchor, multiplier: widthFraction)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        fractionConstraint = constraint
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if let cornerSource {
            cornerSource.layoutIfNeeded()
            fill.layer.cornerRadius = cornerSource.layer.cornerRadius
        }
        highlight.frame = CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height)
        layOutBand()
        updateAnimation(force: false)
    }

    private func observeAppearance() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SkeletonView, _) in
            view.paintHighlight()
            view.updateAnimation(force: true)
        }
    }

    // MARK: - Animation

    /// Where the highlight's container sits in the block's own coordinates for a pass across the
    /// window. The travel is the window's, carried into the block's coordinates, so every block is
    /// crossed by the same band whatever its width, and the band sits clear of the window at both
    /// ends of the pass.
    ///
    /// The band is a stripe leaning `shimmerAngle` from vertical, so over `height` points of the
    /// block it shifts by half the reach across, and it covers `reach` points across on top of its
    /// own width: half the reach hangs past each end, and the pass runs that much further to start
    /// and finish with nothing of it on the window. `anchor` places the stripe on its line, so
    /// every block on the line draws one stripe, tilted together.
    static func sweepTravel(
        windowWidth: CGFloat,
        bandWidth: CGFloat,
        height: CGFloat,
        reach: CGFloat,
        anchor: CGFloat,
        tangent: CGFloat,
        isRightToLeft: Bool
    ) -> (from: CGFloat, to: CGFloat) {
        let shift = height / 2 * abs(tangent)
        let leading = -bandWidth - anchor - shift
        let trailing = windowWidth + reach - anchor - shift
        return isRightToLeft ? (trailing, leading) : (leading, trailing)
    }

    /// Where a block sits on its line. `lineOriginY` is the top of the line: the block's component
    /// for `.component` alignment, and the window for `.window`, so one line crosses every block of
    /// a card, or of the screen. `reach` is how far across the stripe carries over `lineHeight`, and
    /// `tangent` is signed, so a right-to-left line leans the other way.
    static func sweepLine(
        blockFrame: CGRect,
        lineOriginY: CGFloat,
        lineHeight: CGFloat,
        tangent: CGFloat
    ) -> (anchor: CGFloat, reach: CGFloat) {
        (
            blockFrame.minX + tangent * (blockFrame.minY - lineOriginY),
            abs(tangent) * lineHeight
        )
    }

    /// The pass a line takes, so the band moves at the pace the themed duration gives it: a lean or
    /// a taller line that adds travel lengthens the pass instead of speeding the band up.
    static func sweepPass(themed: TimeInterval, travelled: CGFloat, reference: CGFloat) -> TimeInterval {
        guard reference > 0 else { return themed }
        return themed * TimeInterval(Double(travelled / reference))
    }

    /// Attaches whatever this block should currently be running: its screen's sweep, the Reduce
    /// Motion pulse, or nothing while it is off-window or hidden.
    private func updateAnimation(force: Bool) {
        guard let window, !isHidden, isShimmering, bounds.width > 0, bounds.height > 0 else {
            stopSweep()
            stopPulse()
            sweepPlace = nil
            SweepOrder.leftTheWave(self)
            return
        }

        if isReduceMotionEnabled {
            stopSweep()
            startPulse()
            return
        }

        stopPulse()

        let theme = SkeletonTheme.current
        let tangent = theme.shimmerTangent
        let slope = theme.isRightToLeft() ? -tangent : tangent
        let isWindowLine = theme.shimmerAlignment == .window
        let place = SweepOrder.place(of: self)
        let offset = isWindowLine ? 0 : ShimmerTimeline.offset(ordinal: place.ordinal, stagger: theme.shimmerStagger)
        let rest = max(theme.shimmerMinRest, 0)
        let frame = convert(bounds, to: window)
        let component = SweepOrder.component(of: self)
        let componentFrame = component.convert(component.bounds, to: window)
        // A block sits on its line by its own window x, plus how far down the line it starts, so
        // every block of a card — or of the window — draws the same stripe, at any height.
        let line = SkeletonView.sweepLine(
            blockFrame: frame,
            lineOriginY: isWindowLine ? 0 : componentFrame.minY,
            lineHeight: isWindowLine ? window.bounds.height : max(componentFrame.height, bounds.height),
            tangent: slope
        )
        let reach = line.reach
        let themed = max(theme.shimmerDuration, 0.2)
        // The band covers the window's width plus its own width in the themed duration, whatever
        // the lean adds to the travel, so its pace reads the same on a window-wide line as on a
        // component's.
        let pass = isWindowLine
            ? SkeletonView.sweepPass(
                themed: themed,
                travelled: window.bounds.width + bandWidth + reach,
                reference: window.bounds.width + bandWidth
            )
            : themed
        let period = isWindowLine
            ? pass + rest
            : ShimmerTimeline.period(pass: pass, rest: rest, components: place.count, stagger: theme.shimmerStagger)
        let signature = [
            String(Double(window.bounds.width)),
            String(Double(bandWidth)),
            String(Double(bounds.height)),
            String(Double(pass)),
            String(Double(period)),
            String(Double(offset)),
            String(Double(theme.shimmerAngle)),
            String(theme.isRightToLeft()),
        ].joined(separator: "|")

        guard force || signature != sweepSignature else { return }
        sweepSignature = signature

        let travel = SkeletonView.sweepTravel(
            windowWidth: window.bounds.width,
            bandWidth: bandWidth,
            height: bounds.height,
            reach: reach,
            anchor: line.anchor,
            tangent: tangent,
            isRightToLeft: theme.isRightToLeft()
        )

        highlight.frame = CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height)
        layOutBand()
        highlight.add(
            ShimmerTimeline.sweepAnimation(
                from: travel.from,
                to: travel.to,
                pass: pass,
                period: period,
                offset: offset,
                start: place.start
            ),
            forKey: Self.sweepKey
        )
    }

    /// Attaches this block's sweep again after its place in the wave changed.
    func rephase() {
        updateAnimation(force: true)
    }

    private func stopSweep() {
        sweepSignature = nil
        highlight.removeAnimation(forKey: Self.sweepKey)
    }

    /// The sweep attached right now, so a test can check it runs and stops.
    var activeSweep: CAAnimation? {
        highlight.animation(forKey: Self.sweepKey)
    }

    /// The pulse attached right now, so a test can check Reduce Motion still fades the fill.
    var activePulse: CAAnimation? {
        fill.layer.animation(forKey: "opacity")
            ?? fill.layer.animationKeys()?.first.flatMap { fill.layer.animation(forKey: $0) }
    }

    private func startPulse() {
        guard !isPulsing else { return }
        isPulsing = true
        fill.alpha = 1
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            options: [.autoreverse, .repeat, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.fill.alpha = 0.55
        }
    }

    private func stopPulse() {
        guard isPulsing else { return }
        isPulsing = false
        fill.layer.removeAllAnimations()
        fill.alpha = 1
    }

    @objc private func reduceMotionDidChange() {
        updateAnimation(force: true)
    }

    // MARK: - Drawing

    private var bandWidth: CGFloat {
        let windowWidth = window?.bounds.width ?? bounds.width
        return max(windowWidth * 0.35, 80)
    }

    /// The stripe's own width, which is the band's thickness measured square to its slant. Keeping
    /// the gradient at that width makes the band cover `bandWidth` points of the block across,
    /// whatever the block's height.
    private var bandThickness: CGFloat {
        bandWidth * cos(slant.magnitude)
    }

    /// The stripe's length along its slant: long enough to run past the block's top and bottom
    /// corners with the fade still inside the gradient.
    private func bandSpan(height: CGFloat) -> CGFloat {
        (height + 2 * bandWidth) / max(cos(slant.magnitude), 0.1)
    }

    /// The stripe's tilt: its angle from vertical, mirrored for a trailing-to-leading sweep so the
    /// band leans the way the pass runs.
    private var slant: CGFloat {
        let radians = SkeletonTheme.current.shimmerAngle * .pi / 180
        return SkeletonTheme.current.isRightToLeft() ? -radians : radians
    }

    /// Centres the stripe on the block and tips it. Rotating about the centre keeps the band's
    /// place on the block independent of its height, so stacked blocks slant alike.
    private func layOutBand() {
        let height = bounds.height
        guard height > 0, bandWidth > 0 else { return }
        band.bounds = CGRect(x: 0, y: 0, width: bandThickness, height: bandSpan(height: height))
        band.position = CGPoint(x: bandWidth / 2, y: height / 2)
        band.transform = CATransform3DMakeRotation(slant, 0, 0, 1)
    }

    private func paintHighlight() {
        let colour = SkeletonTheme.current.highlight.resolvedColor(with: traitCollection)
        band.colors = [
            colour.withAlphaComponent(0).cgColor,
            colour.withAlphaComponent(0.11).cgColor,
            colour.withAlphaComponent(0.42).cgColor,
            colour.withAlphaComponent(0.9).cgColor,
            colour.withAlphaComponent(0.42).cgColor,
            colour.withAlphaComponent(0.11).cgColor,
            colour.withAlphaComponent(0).cgColor,
        ]
        band.locations = [0, 0.14, 0.3, 0.5, 0.7, 0.86, 1]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
    }
}

extension CACornerMask {
    public static let skeletonAllCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner,
        .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
    ]
}

extension UIView {
    /// The width a placeholder asks for. Held while it fits, yielded when the container is
    /// narrower than the block asserts.
    func setPreferredWidth(_ width: CGFloat) {
        let preferred = widthAnchor.constraint(equalToConstant: width)
        preferred.priority = .skeletonPreferredWidth
        preferred.isActive = true
    }
}

extension UILayoutPriority {
    /// A placeholder's stated width: held while it fits, yielded when the container is narrower.
    static let skeletonPreferredWidth = UILayoutPriority(999)
}
