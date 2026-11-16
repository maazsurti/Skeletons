import QuartzCore

/// The shared sweep clock. Every block counts from the same epoch, so a block carries the phase its
/// ordinal gives it and the blocks on screen read as one wave crossing them in turn.
@MainActor
enum ShimmerTimeline {

    /// The instant every sweep counts from. Read on the first sweep, so later blocks join the
    /// phase already running.
    private static let epoch = CACurrentMediaTime()

    /// A start time at or before now that sits on a whole number of sweeps after `epoch` and on
    /// this block's own phase, so a block added now begins mid-wave rather than waiting.
    static func startTime(
        duration: TimeInterval,
        ordinal: Int = 0,
        stagger: TimeInterval = 0
    ) -> CFTimeInterval {
        let now = CACurrentMediaTime()
        let elapsed = (now - epoch).truncatingRemainder(dividingBy: duration)
        return now - elapsed - phaseOffset(ordinal: ordinal, stagger: stagger, duration: duration)
    }

    /// How far into its sweep a block at `ordinal` already is. The offset wraps inside one sweep,
    /// so a late ordinal never sits still for a whole cycle.
    static func phaseOffset(ordinal: Int, stagger: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard stagger > 0, duration > 0 else { return 0 }
        let offset = Double(max(ordinal, 0)) * stagger
        return offset.truncatingRemainder(dividingBy: duration)
    }
}
