import Testing
import UIKit
@testable import Skeletons

@MainActor
struct SkeletonSwitcherTests {

    // A load that finishes in under the appearance delay must not flash a skeleton at all.
    @Test func fastContentNeverShowsTheSkeleton() {
        let harness = Harness()

        harness.switcher.startLoading()
        harness.scheduler.advance(by: 0.1)
        harness.switcher.showContent()
        harness.scheduler.advance(by: 1)

        #expect(harness.switcher.isSkeletonVisible == false)
        #expect(harness.skeleton.alpha == 0)
        #expect(harness.content.alpha == 1)
    }

    // A slow load shows the skeleton once the delay has passed.
    @Test func slowContentShowsTheSkeleton() {
        let harness = Harness()

        harness.switcher.startLoading()
        harness.scheduler.advance(by: 0.15)

        #expect(harness.switcher.isSkeletonVisible)
        #expect(harness.skeleton.alpha == 1)
        #expect(harness.content.alpha == 0)
    }

    // Content that arrives immediately after the skeleton appeared waits out the minimum, so the
    // screen never blinks a skeleton in and straight back out.
    @Test func skeletonStaysForItsMinimum() {
        let harness = Harness()

        harness.switcher.startLoading()
        harness.scheduler.advance(by: 0.15)
        harness.switcher.showContent()

        harness.scheduler.advance(by: 0.2)
        #expect(harness.switcher.isSkeletonVisible)

        harness.scheduler.advance(by: 0.1)
        #expect(harness.switcher.isSkeletonVisible == false)
        #expect(harness.content.alpha == 1)
        #expect(harness.skeleton.alpha == 0)
    }

    // A retry puts the skeleton back up and re-runs the same timings.
    @Test func retryShowsTheSkeletonAgain() {
        let harness = Harness()

        harness.switcher.startLoading()
        harness.scheduler.advance(by: 0.5)
        harness.switcher.showContent()
        harness.scheduler.advance(by: 1)
        #expect(harness.switcher.isSkeletonVisible == false)

        harness.switcher.startLoading()
        harness.scheduler.advance(by: 0.15)
        #expect(harness.switcher.isSkeletonVisible)
        #expect(harness.skeleton.alpha == 1)
    }

    // Nothing is left scheduled once content is on screen.
    @Test func contentArrivalLeavesNoPendingWork() {
        let harness = Harness()

        harness.switcher.startLoading()
        harness.scheduler.advance(by: 0.5)
        harness.switcher.showContent()
        harness.scheduler.advance(by: 1)

        #expect(harness.scheduler.pendingCount == 0)
    }

    @MainActor
    private final class Harness {
        let skeleton = UIView()
        let content = UIView()
        let scheduler = ManualScheduler()
        let switcher: SkeletonSwitcher

        init() {
            switcher = SkeletonSwitcher(skeleton: skeleton, content: content, scheduler: scheduler)
        }
    }
}

/// A scheduler the tests advance by hand, so the timings are checked without waiting for them.
@MainActor
final class ManualScheduler: SkeletonScheduler {

    private final class Entry {
        let due: TimeInterval
        let action: @MainActor () -> Void
        var isCancelled = false

        init(due: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.due = due
            self.action = action
        }
    }

    private var entries: [Entry] = []
    private var now: TimeInterval = 0

    var pendingCount: Int {
        entries.filter { !$0.isCancelled }.count
    }

    func schedule(
        after delay: TimeInterval,
        _ action: @escaping @MainActor () -> Void
    ) -> SkeletonScheduledTask {
        let entry = Entry(due: now + max(delay, 0), action: action)
        entries.append(entry)
        return SkeletonScheduledTask { entry.isCancelled = true }
    }

    /// Runs every step due inside `interval`, earliest first.
    func advance(by interval: TimeInterval) {
        let target = now + interval

        while true {
            let next = entries
                .filter { !$0.isCancelled && $0.due <= target }
                .min { $0.due < $1.due }
            guard let next else { break }
            now = next.due
            entries.removeAll { $0 === next }
            next.action()
        }

        now = target
        entries.removeAll { $0.isCancelled }
    }
}
