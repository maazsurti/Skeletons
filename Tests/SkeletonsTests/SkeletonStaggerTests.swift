import Testing
import UIKit
@testable import Skeletons

/// The sweep runs as a wave: each placeholder starts `shimmerStagger` after the one before it.
@MainActor
struct SkeletonStaggerTests {

    @Test func anOrdinalSetsItsPhase() {
        #expect(ShimmerTimeline.phaseOffset(ordinal: 0, stagger: 0.15, duration: 1.2) == 0)
        #expect(ShimmerTimeline.phaseOffset(ordinal: 1, stagger: 0.15, duration: 1.2) == 0.15)
        #expect(ShimmerTimeline.phaseOffset(ordinal: 2, stagger: 0.15, duration: 1.2) == 0.3)
    }

    /// A late ordinal wraps into the sweep that is already running, so no block waits a cycle.
    @Test func aLateOrdinalWraps() {
        let wrapped = ShimmerTimeline.phaseOffset(ordinal: 9, stagger: 0.15, duration: 1.2)
        #expect(abs(wrapped - 0.15) < 0.000_001)
        #expect(wrapped < 1.2)
    }

    @Test func theStaggerIsWhatSeparatesNeighbouringBlocks() {
        let duration: TimeInterval = 1.2
        let stagger: TimeInterval = 0.15
        let first = ShimmerTimeline.startTime(duration: duration, ordinal: 0, stagger: stagger)
        let second = ShimmerTimeline.startTime(duration: duration, ordinal: 1, stagger: stagger)

        let gap = abs(first.magnitude > second.magnitude ? first - second : second - first)
        let modulo = gap.truncatingRemainder(dividingBy: duration)
        #expect(abs(gap - stagger) < 0.02 || abs(modulo - (duration - stagger)) < 0.02)
    }

    @Test func twoBlocksInAWindowSweepOutOfPhase() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let theme = SkeletonTheme.current
        let stagger: TimeInterval = 0.15
        SkeletonTheme.current = SkeletonTheme(shimmerStagger: stagger)
        defer { SkeletonTheme.current = theme }

        let first = SkeletonView.block(height: 40)
        let second = SkeletonView.block(height: 40)
        for (view, offset) in [(first, 0.0), (second, 100.0)] {
            view.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: window.topAnchor, constant: offset),
                view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
                view.widthAnchor.constraint(equalToConstant: 200),
            ])
        }
        window.layoutIfNeeded()

        let a = try #require(first.activeSweep?.beginTime)
        let b = try #require(second.activeSweep?.beginTime)
        #expect(abs(abs(a - b) - stagger) < 0.02)
    }

    /// A block keeps its own place while an unrelated block comes and goes.
    @Test func aBlockKeepsItsOrdinalWhileAnotherComesAndGoes() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let first = SkeletonView.block(height: 40)
        let second = SkeletonView.block(height: 40)
        for (view, offset) in [(first, 0.0), (second, 100.0)] {
            view.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: window.topAnchor, constant: offset),
                view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
                view.widthAnchor.constraint(equalToConstant: 200),
            ])
        }
        window.layoutIfNeeded()

        #expect(SweepOrder.ordinal(of: first) == 0)
        #expect(SweepOrder.ordinal(of: second) == 1)

        second.isHidden = true
        #expect(SweepOrder.ordinal(of: first) == 0)

        second.isHidden = false
        window.layoutIfNeeded()
        #expect(SweepOrder.ordinal(of: first) == 0)
        #expect(SweepOrder.ordinal(of: second) == 1)
    }
}
