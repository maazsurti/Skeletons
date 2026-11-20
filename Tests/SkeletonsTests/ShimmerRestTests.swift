import Testing
import UIKit
import QuartzCore
@testable import Skeletons

/// The band is off the window between two repeats for at least the themed rest, so the repeat is a
/// pause rather than the band arriving the instant it left.
@MainActor
struct ShimmerRestTests {

    private let frame = 1.0 / 240.0

    @Test func theBandIsOffTheWindowForTheThemedRest() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        for rest in [0.0, 0.25, 0.4, 0.75] {
            let gap = try gapBetweenRepeats(rest: rest)
            #expect(
                gap >= rest,
                "rest \(rest) left the band off the window for \(gap)"
            )
            #expect(
                gap < rest + 3 * frame,
                "rest \(rest) left the band off the window for \(gap), more than the rest"
            )
        }
    }

    /// Without a rest the band leaves and returns on the same frame: the seam is only the pass's
    /// own end.
    @Test func noRestLeavesNoVisiblePause() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let gap = try gapBetweenRepeats(rest: 0)
        #expect(gap < 3 * frame)
    }

    /// The measure: one pass across a window, stepped at 240 Hz, and the run of samples with no
    /// part of the stripe inside the window around the wrap.
    private func gapBetweenRepeats(rest: TimeInterval) throws -> TimeInterval {
        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0, shimmerMinRest: rest)
        defer { SkeletonTheme.current = original }

        let windowWidth: CGFloat = 402
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: windowWidth, height: 600))
        let block = SkeletonView.block(height: 40)
        block.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            block.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            block.widthAnchor.constraint(equalToConstant: 300),
        ])
        window.layoutIfNeeded()

        let sweep = try #require(block.activeSweep as? CAKeyframeAnimation)
        let values = try #require(sweep.values)
        let keyTimes = try #require(sweep.keyTimes)
        let from = try #require(number(values[0]))
        let to = try #require(number(values[1]))
        let holdStart = keyTimes[1].doubleValue * sweep.duration
        let originX = block.convert(block.bounds, to: window).minX
        let bandWidth = try #require(block.subviews.first?.layer.sublayers?.first?.bounds.width)
        let height = block.bounds.height

        var samples: [Bool] = []
        var time = 0.0
        while time < sweep.duration {
            let progress = time < holdStart ? time / holdStart : 1
            let x = originX + from + CGFloat(progress) * (to - from)
            let low = x - height / 2
            samples.append(low + bandWidth + height > 0 && low < windowWidth)
            time += frame
        }

        // The wrap's own run: the samples at the end of one cycle join the samples at the start of
        // the next, so the pause between two repeats is their sum.
        var head = 0
        while head < samples.count, !samples[head] { head += 1 }
        var tail = 0
        while tail < samples.count, !samples[samples.count - 1 - tail] { tail += 1 }
        return Double(min(head + tail, samples.count)) * frame
    }

    private func number(_ value: Any) -> CGFloat? {
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        if let cgFloat = value as? CGFloat { return cgFloat }
        return nil
    }
}
