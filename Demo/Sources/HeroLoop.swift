import Skeletons
import UIKit

/// Runs the screen on a loop for the README's opening recording: the skeleton shimmers, the content
/// fades in, the content holds, and the skeleton fades back in as the cycle ends, so the recording
/// starts over from the frame it ended on.
///
/// The cycle is a whole number of shimmer periods, so the band sits in the same place in the first
/// and last frame.
@MainActor
final class HeroLoop {

    private let skeleton: UIView
    private let content: UIView
    private let cycle: TimeInterval
    private let contentIn: TimeInterval

    private var link: CADisplayLink?
    private var startedAt: CFTimeInterval = 0

    /// How long the skeleton shows before the content starts to fade in.
    private static let skeletonHold: TimeInterval = 2.0

    /// How long the content stays once it is fully in.
    private static let contentHold: TimeInterval = 1.0

    /// One fade.
    private static let fade: TimeInterval = 0.25

    /// - Parameter components: how many pieces the skeleton sweeps, which sets the wave's length.
    init(skeleton: UIView, content: UIView, components: Int) {
        self.skeleton = skeleton
        self.content = content

        let theme = SkeletonTheme.current
        let rest = max(theme.shimmerMinRest, 0)
        let period: TimeInterval
        switch theme.shimmerAlignment {
        case .window:
            period = theme.shimmerDuration + rest
        case .component:
            // The wave crosses every component a stagger apart, so its cycle is longer than one pass.
            let spread = Double(max(components - 1, 0)) * theme.shimmerStagger
            period = theme.shimmerDuration + rest + spread
        }

        let needed = Self.skeletonHold + Self.fade + Self.contentHold + Self.fade
        let length = max(period, 0.01)
        cycle = length * max(ceil(needed / length), 1)
        contentIn = Self.skeletonHold
    }

    func start() {
        skeleton.alpha = 1
        content.alpha = 0
        startedAt = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step() {
        let elapsed = (CACurrentMediaTime() - startedAt).truncatingRemainder(dividingBy: cycle)
        let shown = contentAlpha(at: elapsed)
        content.alpha = shown
        skeleton.alpha = 1 - shown
    }

    /// The content's opacity through one cycle. The fade back ends on the cycle's last frame, so the
    /// frame the recording starts on is the one the cycle ends towards.
    private func contentAlpha(at elapsed: TimeInterval) -> CGFloat {
        let holdEnds = cycle - Self.fade
        if elapsed < contentIn { return 0 }
        if elapsed < contentIn + Self.fade {
            return Self.ease((elapsed - contentIn) / Self.fade)
        }
        if elapsed < holdEnds { return 1 }
        return 1 - Self.ease((elapsed - holdEnds) / Self.fade)
    }

    private static func ease(_ value: Double) -> CGFloat {
        let t = min(max(value, 0), 1)
        return CGFloat(t * t * (3 - 2 * t))
    }
}
