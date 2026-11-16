import UIKit

/// One placeholder block. The host screen places it inside its own cards and cells; the view draws
/// only its own fill, corner radius and shimmer, and never constrains itself beyond the size its
/// factory was given.
@MainActor
public final class SkeletonView: UIView {

    private let fill = UIView()
    private let highlight = CAGradientLayer()

    private var widthFraction: CGFloat?
    private var fractionConstraint: NSLayoutConstraint?
    private var sweepGeometry: String?
    private var isPulsing = false

    private static let sweepKey = "shimmer"

    // MARK: - Factories

    /// A single line of placeholder text. Without `width` or `widthFraction` the line takes
    /// whatever width its container gives it. `radius` rounds the line; it falls back to the
    /// theme's radius.
    public static func line(
        height: CGFloat = 14,
        width: CGFloat? = nil,
        widthFraction: CGFloat? = nil,
        radius: CGFloat? = nil
    ) -> SkeletonView {
        let view = SkeletonView(cornerRadius: radius)
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        if let width {
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        } else if let widthFraction {
            view.widthFraction = widthFraction
        }
        return view
    }

    /// A round block, for avatars, icons and thumbnails.
    public static func circle(diameter: CGFloat) -> SkeletonView {
        let view = SkeletonView(cornerRadius: diameter / 2)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: diameter),
            view.heightAnchor.constraint(equalToConstant: diameter),
        ])
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
    public init(cornerRadius: CGFloat? = nil) {
        super.init(frame: .zero)

        let theme = SkeletonTheme.current
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        fill.isUserInteractionEnabled = false
        fill.backgroundColor = theme.base
        fill.layer.cornerRadius = cornerRadius ?? theme.cornerRadius
        fill.layer.cornerCurve = .continuous
        fill.clipsToBounds = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        fill.layer.addSublayer(highlight)
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
        highlight.frame = CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height)
        updateAnimation(force: false)
    }

    private func observeAppearance() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SkeletonView, _) in
            view.paintHighlight()
            view.updateAnimation(force: true)
        }
    }

    // MARK: - Animation

    /// Where the highlight's leading edge sits in the block's own coordinates for a sweep across a
    /// window `windowWidth` wide, with the block starting at `originX` in that window.
    static func sweepTravel(
        windowWidth: CGFloat,
        bandWidth: CGFloat,
        originX: CGFloat,
        isRightToLeft: Bool
    ) -> (from: CGFloat, to: CGFloat) {
        let fromLeading = -bandWidth - originX
        let fromTrailing = windowWidth - originX
        return isRightToLeft ? (fromTrailing, fromLeading) : (fromLeading, fromTrailing)
    }

    /// Restarts whatever this block should currently be running: the shared sweep, the Reduce
    /// Motion pulse, or nothing while it is off-window or hidden.
    private func updateAnimation(force: Bool) {
        guard let window, !isHidden, isShimmering, bounds.width > 0, bounds.height > 0 else {
            stopSweep()
            stopPulse()
            return
        }

        if UIAccessibility.isReduceMotionEnabled {
            stopSweep()
            startPulse()
            return
        }

        stopPulse()

        let theme = SkeletonTheme.current
        let duration = max(theme.shimmerDuration, 0.2)
        let geometry = [
            String(Double(window.bounds.width)),
            String(Double(bounds.width)),
            String(Double(bounds.height)),
            String(Double(convert(bounds, to: window).minX)),
            String(duration),
            String(theme.isRightToLeft()),
        ].joined(separator: "|")

        guard force || geometry != sweepGeometry else { return }
        sweepGeometry = geometry

        let band = bandWidth
        let travel = SkeletonView.sweepTravel(
            windowWidth: window.bounds.width,
            bandWidth: band,
            originX: convert(bounds, to: window).minX,
            isRightToLeft: theme.isRightToLeft()
        )

        highlight.frame = CGRect(x: 0, y: 0, width: band, height: bounds.height)

        let sweep = CABasicAnimation(keyPath: "transform.translation.x")
        sweep.fromValue = travel.from
        sweep.toValue = travel.to
        sweep.duration = duration
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sweep.beginTime = ShimmerTimeline.startTime(duration: duration)
        highlight.add(sweep, forKey: Self.sweepKey)
    }

    private func stopSweep() {
        sweepGeometry = nil
        highlight.removeAnimation(forKey: Self.sweepKey)
    }

    /// The sweep attached right now, so a test can check it runs and stops.
    var activeSweep: CAAnimation? {
        highlight.animation(forKey: Self.sweepKey)
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

    private func paintHighlight() {
        let colour = SkeletonTheme.current.highlight.resolvedColor(with: traitCollection)
        highlight.colors = [
            colour.withAlphaComponent(0).cgColor,
            colour.withAlphaComponent(0.9).cgColor,
            colour.withAlphaComponent(0).cgColor,
        ]
        highlight.locations = [0, 0.5, 1]
        highlight.startPoint = CGPoint(x: 0, y: 0.5)
        highlight.endPoint = CGPoint(x: 1, y: 0.5)
    }
}
