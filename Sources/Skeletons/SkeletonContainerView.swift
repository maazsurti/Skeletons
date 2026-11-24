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
