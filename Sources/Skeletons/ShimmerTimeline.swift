import QuartzCore

/// The shared sweep clock. Every block derives its highlight position from the same absolute
/// timeline, so all the blocks on screen read as one band crossing them together.
@MainActor
enum ShimmerTimeline {

    /// The instant every sweep counts from. Read on the first sweep, so later blocks join the
    /// phase already running.
    private static let epoch = CACurrentMediaTime()

    /// A start time at or before now that sits on a whole number of sweeps after `epoch`, so an
    /// animation added now is in the same phase as every other one.
    static func startTime(duration: TimeInterval) -> CFTimeInterval {
        let now = CACurrentMediaTime()
        let elapsed = (now - epoch).truncatingRemainder(dividingBy: duration)
        return now - elapsed
    }
}
