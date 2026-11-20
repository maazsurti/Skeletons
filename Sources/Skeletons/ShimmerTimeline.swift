import QuartzCore
import UIKit

/// The shared sweep clock: every block on every screen reads the same time, so the band's place on
/// a block is a function of the clock and the block's component, never of when the block happened
/// to join or of the last time its animation was attached.
@MainActor
enum ShimmerTimeline {

    /// The instant the sweep counts from.
    private static let epoch = CACurrentMediaTime()

    /// The delay a component at `ordinal` takes behind the topmost component on its screen. It is
    /// cumulative and never reduced modulo the pass, so no two components of a screen can land in
    /// the same phase.
    static func offset(ordinal: Int, stagger: TimeInterval) -> TimeInterval {
        guard stagger > 0 else { return 0 }
        return Double(max(ordinal, 0)) * stagger
    }

    /// How far behind the last component of a screen the first one is.
    static func spread(components: Int, stagger: TimeInterval) -> TimeInterval {
        guard stagger > 0, components > 1 else { return 0 }
        return Double(components - 1) * stagger
    }

    /// One full wave of a screen: one pass, the rest the band takes off the window, and the time the
    /// wave takes to reach the last component. The band is held outside the window for the rest of
    /// the cycle, so the wave loops once the last component has crossed and the band has rested.
    static func period(
        pass: TimeInterval,
        rest: TimeInterval = 0,
        components: Int,
        stagger: TimeInterval
    ) -> TimeInterval {
        pass + max(rest, 0) + spread(components: components, stagger: stagger)
    }

    /// The start of the pass `offset` is in, at or before now, on the shared clock. Adding an
    /// animation again therefore lands exactly where the old one was.
    static func startTime(period: TimeInterval, offset: TimeInterval = 0) -> CFTimeInterval {
        guard period > 0 else { return CACurrentMediaTime() }
        return CACurrentMediaTime() - cycleElapsed(period: period, offset: offset)
    }

    /// How far through its pass a component at `offset` is at `time`: 0 at the leading edge, 1 once
    /// the band has left the window, and pinned at 1 while the wave works down the screen.
    static func passProgress(
        at time: CFTimeInterval,
        pass: TimeInterval,
        period: TimeInterval,
        offset: TimeInterval = 0
    ) -> Double {
        guard pass > 0, period > 0 else { return 0 }
        let elapsed = cycleElapsed(period: period, offset: offset, at: time)
        return min(max(elapsed / pass, 0), 1)
    }

    /// The sweep a block runs: a pass across the window at a constant speed, a hold outside the
    /// window for the rest and the time the rest of the wave crosses, and a repeat on the shared
    /// clock. Both ends of the pass sit clear of the window, so the repeat cannot be seen.
    static func sweepAnimation(
        from: CGFloat,
        to: CGFloat,
        pass: TimeInterval,
        period: TimeInterval,
        offset: TimeInterval
    ) -> CAAnimation {
        let sweep = CAKeyframeAnimation(keyPath: "transform.translation.x")
        let passFraction = period > 0 ? min(pass / period, 1) : 1
        if passFraction < 1 {
            sweep.values = [from, to, to]
            sweep.keyTimes = [0, NSNumber(value: passFraction), 1]
        } else {
            sweep.values = [from, to]
            sweep.keyTimes = [0, 1]
        }
        sweep.duration = period
        sweep.repeatCount = .infinity
        sweep.calculationMode = .linear
        sweep.isRemovedOnCompletion = false
        sweep.beginTime = startTime(period: period, offset: offset)
        return sweep
    }

    /// How far into the cycle a component at `offset` sits at `time`.
    private static func cycleElapsed(
        period: TimeInterval,
        offset: TimeInterval,
        at time: CFTimeInterval = CACurrentMediaTime()
    ) -> TimeInterval {
        guard period > 0 else { return 0 }
        let elapsed = (time - epoch - offset).truncatingRemainder(dividingBy: period)
        return elapsed < 0 ? elapsed + period : elapsed
    }
}
