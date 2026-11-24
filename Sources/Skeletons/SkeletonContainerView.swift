import UIKit

/// Holds one screen's skeleton layout and gives VoiceOver a single "Loading" element in place of
/// the individual blocks. The layout itself is whatever the host screen composes.
@MainActor
public final class SkeletonContainerView: UIView {

    private let content: UIView

    /// The block layout the container wraps.
    public init(content: UIView) {
        self.content = content
        super.init(frame: .zero)

        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently
        accessibilityLabel = SkeletonTheme.current.loadingText

        SweepOrder.placeComponents(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The app builds its UI in code; init(coder:) is not supported")
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        skeletonSweepStart = nil
    }

    public override var isHidden: Bool {
        didSet {
            guard isHidden != oldValue, !isHidden else { return }
            restartSweep()
        }
    }

    /// Starts the wave again from the container's leading edge: the clock is cleared and every block
    /// inside takes its place again. Call it from a screen that finishes appearing, or that otherwise
    /// reveals the skeleton late, so the wave starts when the screen settles.
    public func restartSweep() {
        skeletonSweepStart = nil
        clearPlaces(in: self)
    }

    private func clearPlaces(in view: UIView) {
        if let block = view as? SkeletonView {
            block.sweepPlace = nil
            block.rephase()
        }
        view.subviews.forEach(clearPlaces(in:))
    }

    /// The text VoiceOver reads. Nil uses the theme's text.
    public var loadingText: String? {
        didSet {
            accessibilityLabel = loadingText ?? SkeletonTheme.current.loadingText
        }
    }

    /// Runs or stops every shimmer inside the container.
    public var isShimmering = true {
        didSet {
            guard isShimmering != oldValue else { return }
            if isShimmering { restartSweep() }
            applyShimmering(to: self)
        }
    }

    private func applyShimmering(to view: UIView) {
        if let skeleton = view as? SkeletonView {
            skeleton.isShimmering = isShimmering
        }
        view.subviews.forEach(applyShimmering(to:))
    }
}
