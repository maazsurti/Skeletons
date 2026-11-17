import Testing
import UIKit
import QuartzCore
@testable import Skeletons

/// The sweep loops without a visible seam: the band is off the block at both ends of its travel,
/// it crosses at a constant speed, and a relayout does not restart its phase.
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

    @Test func theTravelClearsTheBlockAtBothEnds() {
        let band: CGFloat = 140.7
        for shape in shapes {
            for isRightToLeft in [false, true] {
                let travel = SkeletonView.sweepTravel(
                    windowWidth: shape.windowWidth,
                    bandWidth: band,
                    originX: shape.originX,
                    blockWidth: shape.blockWidth,
                    isRightToLeft: isRightToLeft
                )
                let start = isRightToLeft ? travel.to : travel.from
                let end = isRightToLeft ? travel.from : travel.to

                #expect(start + band <= 0, "the band is still on the block at the start")
                #expect(end >= shape.blockWidth, "the band is still on the block at the end")
            }
        }
    }

    @Test func anOnScreenBlockStartsOffTheWindow() {
        let travel = SkeletonView.sweepTravel(
            windowWidth: 402,
            bandWidth: 140,
            originX: 20,
            blockWidth: 340,
            isRightToLeft: false
        )
        #expect(travel.from == -160)
        #expect(travel.to == 382)
    }

    @Test func theLoopLastsTheThemedDuration() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0)
        defer { SkeletonTheme.current = original }

        let block = try blockInAWindow()
        let sweep = try #require(block.activeSweep as? CABasicAnimation)

        #expect(sweep.duration == 1.7)
        #expect(sweep.repeatCount == .infinity)
        #expect(isLinear(sweep.timingFunction))
    }

    @Test func aRelayoutKeepsThePhase() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerDuration: 1.7, shimmerStagger: 0.1)
        defer { SkeletonTheme.current = original }

        let (block, window) = try blockInAWindowWithWindow()
        let first = try #require((block.activeSweep as? CABasicAnimation)?.beginTime)

        let width = block.widthAnchor.constraint(equalToConstant: 240)
        width.isActive = true
        window.layoutIfNeeded()

        let second = try #require((block.activeSweep as? CABasicAnimation)?.beginTime)
        let cycle = (first - second).truncatingRemainder(dividingBy: 1.7)
        #expect(abs(cycle) < 0.001 || abs(cycle + 1.7) < 0.001 || abs(cycle - 1.7) < 0.001)
    }

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

    private func isLinear(_ function: CAMediaTimingFunction?) -> Bool {
        guard let function else { return false }
        var first = [Float](repeating: 0, count: 2)
        var second = [Float](repeating: 0, count: 2)
        function.getControlPoint(at: 1, values: &first)
        function.getControlPoint(at: 2, values: &second)
        return abs(first[0]) < 0.001 && abs(first[1]) < 0.001
            && abs(second[0] - 1) < 0.001 && abs(second[1] - 1) < 0.001
    }
}
