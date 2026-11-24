import UIKit

/// Swaps a skeleton for the content it stands in for, at timings that keep the exchange from
/// flashing: a quick load never shows the skeleton, a skeleton that does appear stays long enough
/// to read, and the two cross-dissolve.
///
/// Both views are placed by the host screen, one over the other; the switcher only changes their
/// opacity.
@MainActor
public final class SkeletonSwitcher {

    /// The timings that decide when a skeleton appears and when it goes.
    public struct Timing {

        /// How long a load may take before the skeleton appears at all.
        public var appearanceDelay: TimeInterval

        /// How long the skeleton stays once it has appeared.
        public var minimumVisible: TimeInterval

        /// The cross-dissolve between the two views.
        public var dissolve: TimeInterval

        public init(
            appearanceDelay: TimeInterval = 0.15,
            minimumVisible: TimeInterval = 0.3,
            dissolve: TimeInterval = 0.2
        ) {
            self.appearanceDelay = appearanceDelay
            self.minimumVisible = minimumVisible
            self.dissolve = dissolve
        }
    }

    private let skeleton: UIView
    private let content: UIView
    private let timing: Timing
    private let scheduler: SkeletonScheduler

    private var appearanceTask: SkeletonScheduledTask?
    private var minimumVisibleTask: SkeletonScheduledTask?
    private var contentHasArrived = false
    private var canRevealContent = false

    /// Whether the skeleton is the view currently on screen.
    public private(set) var isSkeletonVisible = false

    public init(
        skeleton: UIView,
        content: UIView,
        timing: Timing = Timing(),
        scheduler: SkeletonScheduler = MainQueueSkeletonScheduler()
    ) {
        self.skeleton = skeleton
        self.content = content
        self.timing = timing
        self.scheduler = scheduler
        skeleton.alpha = 0
        content.alpha = 1
    }

    /// Starts a load: the skeleton appears after `timing.appearanceDelay` unless content arrives
    /// first. Calling it again while a screen is retrying re-arms the whole exchange.
    public func startLoading() {
        contentHasArrived = false
        cancelPending()

        guard !isSkeletonVisible else {
            scheduleMinimumVisible()
            return
        }

        appearanceTask = scheduler.schedule(after: timing.appearanceDelay) { [weak self] in
            self?.revealSkeleton()
        }
    }

    /// Reports that content is ready. Content that beats the delay replaces the skeleton before it
    /// ever shows; content that arrives after it waits out the minimum the skeleton has to stay.
    public func showContent() {
        contentHasArrived = true
        appearanceTask?.cancel()
        appearanceTask = nil

        guard isSkeletonVisible else {
            revealContent(animated: false)
            return
        }
        guard canRevealContent else { return }
        revealContent(animated: true)
    }

    // MARK: - Steps

    private func revealSkeleton() {
        appearanceTask = nil
        guard !contentHasArrived else { return }

        isSkeletonVisible = true
        restartSweeps(in: skeleton)
        setVisible(content, false)
        setVisible(skeleton, true)
        scheduleMinimumVisible()
    }

    /// Starts each container's wave from its leading edge as the skeleton comes on screen.
    private func restartSweeps(in view: UIView) {
        if let container = view as? SkeletonContainerView {
            container.restartSweep()
        }
        view.subviews.forEach(restartSweeps(in:))
    }

    private func scheduleMinimumVisible() {
        canRevealContent = false
        minimumVisibleTask?.cancel()
        minimumVisibleTask = scheduler.schedule(after: timing.minimumVisible) { [weak self] in
            guard let self else { return }
            minimumVisibleTask = nil
            canRevealContent = true
            if contentHasArrived {
                revealContent(animated: true)
            }
        }
    }

    private func revealContent(animated: Bool) {
        cancelPending()
        isSkeletonVisible = false
        canRevealContent = false

        guard animated, timing.dissolve > 0, !UIAccessibility.isReduceMotionEnabled else {
            setVisible(content, true, animated: false)
            setVisible(skeleton, false, animated: false)
            return
        }

        UIView.animate(
            withDuration: timing.dissolve,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.content.alpha = 1
            self.skeleton.alpha = 0
        }
    }

    private func setVisible(_ view: UIView, _ isVisible: Bool, animated: Bool = true) {
        let target: CGFloat = isVisible ? 1 : 0
        guard view.alpha != target else { return }
        guard animated, timing.dissolve > 0, !UIAccessibility.isReduceMotionEnabled else {
            view.alpha = target
            return
        }
        UIView.animate(
            withDuration: timing.dissolve,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            view.alpha = target
        }
    }

    private func cancelPending() {
        appearanceTask?.cancel()
        appearanceTask = nil
        minimumVisibleTask?.cancel()
        minimumVisibleTask = nil
        canRevealContent = false
    }
}
