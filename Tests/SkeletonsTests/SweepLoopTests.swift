import Testing
import UIKit
import QuartzCore
@testable import Skeletons

/// The sweep loops without a visible seam: the band is clear of the window at both ends of its
/// travel, it crosses at a constant speed, and a scroll or a relayout that re-attaches the
/// animation leaves the band exactly where it was.
@MainActor
struct SweepLoopTests {

    private struct Shape {
        let windowWidth: CGFloat
        let blockWidth: CGFloat
        let originX: CGFloat
    }

    private let shapes = [
        Shape(windowWidth: 402, blockWidth: 340, originX: 20),
        Shape(windowWidth: 402, blockWidth: 200, originX: 0),
        Shape(windowWidth: 402, blockWidth: 120, originX: 282),
        Shape(windowWidth: 402, blockWidth: 200, originX: -30),
        Shape(windowWidth: 402, blockWidth: 520, originX: -40),
    ]

    @Test func theTravelClearsTheWindowAtBothEnds() {
        let band: CGFloat = 140.7
        for shape in shapes {
            for isRightToLeft in [false, true] {
                let travel = SkeletonView.sweepTravel(
                    windowWidth: shape.windowWidth,
                    bandWidth: band,
                    originX: shape.originX,
                    isRightToLeft: isRightToLeft
                )
                let distance = abs(travel.to - travel.from)
                #expect(abs(distance - (shape.windowWidth + band)) < 0.001)

                let edge = shape.windowWidth
                let start = travel.from + shape.originX
                let end = travel.to + shape.originX
                #expect(start + band <= 0.001 || start >= edge - 0.001, "the band is on the window at the start")
                #expect(end + band <= 0.001 || end >= edge - 0.001, "the band is on the window at the end")
                if isRightToLeft {
                    #expect(start >= edge - 0.001)
                    #expect(end + band <= 0.001)
                } else {
                    #expect(start + band <= 0.001)
                    #expect(end >= edge - 0.001)
                }
            }
        }
    }

    @Test func anOnScreenBlockStartsOffTheWindow() {
        let travel = SkeletonView.sweepTravel(
            windowWidth: 402,
            bandWidth: 140,
            originX: 20,
            isRightToLeft: false
        )
        #expect(travel.from == -160)
        #expect(travel.to == 382)
    }

    @Test func thePassLastsTheThemedDuration() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0)
        defer { SkeletonTheme.current = original }

        let block = try blockInAWindow()
        let sweep = try #require(block.activeSweep as? CAKeyframeAnimation)
        let keyTimes = try #require(sweep.keyTimes)

        #expect(sweep.repeatCount == .infinity)
        #expect(sweep.calculationMode == .linear)
        // One component and no stagger: the pass fills the cycle.
        #expect(abs(sweep.duration - 1.7) < 0.000_001)
        #expect(keyTimes.map(\.doubleValue) == [0, 1])
    }

    /// A pass and the hold after it add up to one wave of the screen's components.
    @Test func theCycleCoversTheWholeScreensSpread() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0.1)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let container = cardLayout(count: 4)
        container.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: window.topAnchor),
            container.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])
        window.layoutIfNeeded()

        let block = try #require(firstBlock(in: container))
        let sweep = try #require(block.activeSweep as? CAKeyframeAnimation)
        let keyTimes = try #require(sweep.keyTimes)

        // Four components: the wave lasts 1.7 + 0.3.
        #expect(abs(sweep.duration - 2.0) < 0.000_001)
        #expect(abs(keyTimes[1].doubleValue * sweep.duration - 1.7) < 0.000_001)
        #expect(keyTimes[2].doubleValue == 1)
        #expect(sweep.values?.count == 3)
    }

    @Test func aRelayoutKeepsThePhase() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0.1)
        defer { SkeletonTheme.current = original }

        let (block, window) = try blockInAWindowWithWindow()
        let first = try #require((block.activeSweep as? CAKeyframeAnimation)?.beginTime)

        let width = block.widthAnchor.constraint(equalToConstant: 240)
        width.isActive = true
        window.layoutIfNeeded()
        block.layoutIfNeeded()

        let second = try #require((block.activeSweep as? CAKeyframeAnimation)?.beginTime)
        let period = 1.7
        let cycle = (first - second).truncatingRemainder(dividingBy: period)
        #expect(abs(cycle) < 0.001 || abs(cycle + period) < 0.001 || abs(cycle - period) < 0.001)
    }

    /// A block that moves carries its band with it: nothing re-attaches the animation mid-pass, so
    /// the band neither jumps nor changes speed when the block's place in the window changes.
    @Test func aScrollCarriesTheBandWithItsBlock() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let block = SkeletonView.block(height: 40)
        block.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(block)
        let leading = block.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            leading,
            block.widthAnchor.constraint(equalToConstant: 300),
        ])
        window.layoutIfNeeded()

        let before = try bandPosition(block)
        let sweepBefore = try #require(block.activeSweep as? CAKeyframeAnimation)
        let beginBefore = sweepBefore.beginTime

        leading.constant = -30
        window.layoutIfNeeded()
        block.layoutIfNeeded()

        let sweepAfter = try #require(block.activeSweep as? CAKeyframeAnimation)
        #expect(sweepAfter === sweepBefore, "the sweep was re-attached when the block moved")

        let after = try bandPosition(block)
        let step = (402 + 140.7) * (1.0 / 60.0) / 1.7 + 5
        #expect(abs((after - before) + 50) <= step, "the band moved \(after - before) pt while the block moved 50")
        #expect(abs(sweepAfter.beginTime - beginBefore) < 0.000_001)
    }

    // MARK: - Helpers

    private func blockInAWindow() throws -> SkeletonView {
        try blockInAWindowWithWindow().0
    }

    private func blockInAWindowWithWindow() throws -> (SkeletonView, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let block = SkeletonView.block(height: 40)
        block.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            block.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            block.widthAnchor.constraint(equalToConstant: 200),
        ])
        window.layoutIfNeeded()
        return (block, window)
    }

    private func cardLayout(count: Int) -> UIView {
        SkeletonLayout(spacing: 10) {
            SkeletonRows(count: count, spacing: 10) {
                SkeletonCard(padding: 14) {
                    SkeletonRow(spacing: 10) {
                        SkeletonPhoto(width: 40, height: 40)
                        SkeletonLine(.body, width: 120)
                    }
                }
            }
        }.makeView()
    }

    private func firstBlock(in view: UIView) -> SkeletonView? {
        if let block = view as? SkeletonView { return block }
        for subview in view.subviews {
            if let block = firstBlock(in: subview) { return block }
        }
        return nil
    }

    /// Where the band's leading edge sits in the window right now, read from the animation the
    /// block is running.
    private func bandPosition(_ block: SkeletonView) throws -> CGFloat {
        let sweep = try #require(block.activeSweep as? CAKeyframeAnimation)
        let values = try #require(sweep.values)
        let keyTimes = try #require(sweep.keyTimes)
        let from = try #require(number(values[0]))
        let to = try #require(number(values[1]))
        let window = try #require(block.window)

        var local = (CACurrentMediaTime() - sweep.beginTime).truncatingRemainder(dividingBy: sweep.duration)
        if local < 0 { local += sweep.duration }
        let holdStart = keyTimes.count > 1 ? keyTimes[1].doubleValue : 1
        let progress = holdStart > 0 ? min(local / sweep.duration / holdStart, 1) : 0
        let originX = block.convert(block.bounds, to: window).minX
        return originX + from + CGFloat(progress) * (to - from)
    }

    private func number(_ value: Any) -> CGFloat? {
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        if let cgFloat = value as? CGFloat { return cgFloat }
        return nil
    }
}
