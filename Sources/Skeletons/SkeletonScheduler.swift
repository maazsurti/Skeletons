import Foundation

/// Runs the delayed steps that swap a skeleton for its content. The default uses the main queue;
/// tests inject one they advance by hand.
@MainActor
public protocol SkeletonScheduler {

    /// Runs `action` once, `delay` seconds from now. The returned task cancels it.
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> SkeletonScheduledTask
}

/// A scheduled step the switcher can still call off.
@MainActor
public final class SkeletonScheduledTask {

    private let onCancel: @MainActor () -> Void

    init(onCancel: @escaping @MainActor () -> Void) {
        self.onCancel = onCancel
    }

    /// Drops the step without running it. Cancelling a finished step does nothing.
    public func cancel() {
        onCancel()
    }
}

/// Schedules on the main queue, the scheduler a running app uses.
@MainActor
public final class MainQueueSkeletonScheduler: SkeletonScheduler {

    nonisolated public init() {}

    public func schedule(
        after delay: TimeInterval,
        _ action: @escaping @MainActor () -> Void
    ) -> SkeletonScheduledTask {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(delay, 0)))
            guard !Task.isCancelled else { return }
            action()
        }
        return SkeletonScheduledTask { task.cancel() }
    }
}
