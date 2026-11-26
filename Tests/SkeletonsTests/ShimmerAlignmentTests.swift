import Testing
import UIKit
import QuartzCore
@testable import Skeletons

/// `.window` alignment puts every skeleton on one window on one clock and one line, so the bands
/// make a single stripe across cards, sections and containers.
@MainActor
struct ShimmerAlignmentTests {

    private let pass: TimeInterval = 1.7

    /// Two containers on one window share the wave: no stagger, and the same instant under every
    /// block.
    @Test func everyContainerOnAWindowSharesOneClock() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerAlignment: .window)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
        let first = cards(count: 2)
        let second = cards(count: 3)
        place([first, second], in: window)

        let begins = blocks(in: window).compactMap {
            ($0.activeSweep as? CAKeyframeAnimation)?.beginTime
        }
        #expect(begins.count == blocks(in: window).count)
        #expect(begins.count == 15)
        #expect(begins.allSatisfy { abs($0 - begins[0]) < 0.000_001 })

        let starts = Set(blocks(in: window).map { SweepOrder.place(of: $0).start })
        #expect(starts.count == 1)
    }

    /// A component's blocks and a neighbouring container's blocks are placed on one 45° line: the
    /// share across plus the share down is the same for every block on the window.
    @Test func everyBlockOnTheWindowSitsOnOneDiagonal() {
        let window = CGRect(x: 0, y: 0, width: 402, height: 800)
        let frames = [
            CGRect(x: 20, y: 40, width: 360, height: 80),
            CGRect(x: 20, y: 220, width: 200, height: 14),
            CGRect(x: 120, y: 420, width: 262, height: 120),
            CGRect(x: 20, y: 700, width: 360, height: 40),
        ]

        let lines = frames.map {
            SkeletonView.sweepLine(
                blockFrame: $0,
                lineOriginY: window.minY,
                lineHeight: window.height,
                tangent: 1
            )
        }

        for (frame, line) in zip(frames, lines) {
            #expect(abs((line.anchor - frame.minX) - frame.minY) < 0.000_001)
            #expect(abs(line.reach - window.height) < 0.000_001)
        }
        // One stripe: the anchor plus the block's share across is the line's place on the window.
        let places = zip(frames, lines).map { $0.minX + $0.minY - $1.anchor }
        #expect(Set(places.map { ($0 * 1000).rounded() }).count == 1)
    }

    /// A window-wide wave keeps the screen's rhythm: the band crosses the window's width in the
    /// themed duration, and the lean's extra travel only lengthens the pass.
    @Test func theWindowWaveKeepsTheThemedCrossing() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(
            shimmerDuration: 1.7,
            shimmerStagger: 0.1,
            shimmerMinRest: 0.4,
            shimmerAlignment: .window
        )
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
        place([cards(count: 3)], in: window)

        let block = try #require(firstBlock(in: window))
        let sweep = try #require(block.activeSweep as? CAKeyframeAnimation)
        let keyTimes = try #require(sweep.keyTimes)
        let values = try #require(sweep.values)
        let from = try #require(number(values[0]))
        let to = try #require(number(values[1]))
        let container = try #require(block.subviews.first?.layer.sublayers?.first)
        let bandWidth = container.bounds.width
        let reach = abs(to - from) - 402 - bandWidth
        let expected = 1.7 * (402 + bandWidth + reach) / (402 + bandWidth)

        #expect(abs(sweep.duration - (expected + 0.4)) < 0.001)
        #expect(abs(keyTimes[1].doubleValue * sweep.duration - expected) < 0.001)
    }

    private func number(_ value: Any) -> CGFloat? {
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        if let cgFloat = value as? CGFloat { return cgFloat }
        return nil
    }

    /// Restarting one container while another is sweeping leaves the neighbour where it was: the
    /// shared wave is not moved.
    @Test func restartingOneContainerLeavesTheOtherInStep() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerAlignment: .window)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
        let first = cards(count: 2)
        let second = cards(count: 2)
        place([first, second], in: window)
        let before = try begins(in: window)

        first.restartSweep()

        #expect(try begins(in: window) == before)
    }

    /// A window with one skeleton restarts its wave from the leading edge.
    @Test func theOnlyContainerRestartsTheWave() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerAlignment: .window)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
        let only = cards(count: 2)
        place([only], in: window)
        let before = try begins(in: window)

        only.restartSweep()

        let after = try begins(in: window)
        #expect(after[0] > before[0])
        #expect(after.allSatisfy { abs($0 - after[0]) < 0.000_001 })
    }

    /// The wave is dropped with its clock once the last block stops, so the next screen starts from
    /// the leading edge on a fresh clock.
    @Test func aWindowDropsTheWaveWhenNothingSweeps() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerAlignment: .window)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
        let container = cards(count: 2)
        place([container], in: window)
        let before = try begins(in: window)

        container.removeFromSuperview()
        window.addSubview(container)
        window.layoutIfNeeded()

        let after = try begins(in: window)
        #expect(after[0] > before[0])
    }

    // MARK: - Helpers

    private func cards(count: Int) -> SkeletonContainerView {
        let layout = SkeletonLayout(spacing: 12) {
            SkeletonRows(count: count, spacing: 12) {
                SkeletonCard(padding: 14) {
                    SkeletonRow(spacing: 10) {
                        SkeletonPhoto(width: 40, height: 40)
                        SkeletonColumn(spacing: 2) {
                            SkeletonLine(.body, widthFraction: 0.6)
                            SkeletonLine(.caption, widthFraction: 0.8)
                        }
                    }
                }
            }
        }.makeView()
        return layout as! SkeletonContainerView
    }

    private func place(_ views: [UIView], in window: UIWindow) {
        for view in views { view.translatesAutoresizingMaskIntoConstraints = false }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -20),
        ])
        window.layoutIfNeeded()
    }

    private func begins(in view: UIView) throws -> [CFTimeInterval] {
        blocks(in: view).compactMap { ($0.activeSweep as? CAKeyframeAnimation)?.beginTime }
    }

    private func firstBlock(in view: UIView) -> SkeletonView? {
        if let block = view as? SkeletonView { return block }
        for subview in view.subviews {
            if let block = firstBlock(in: subview) { return block }
        }
        return nil
    }

    private func blocks(in view: UIView) -> [SkeletonView] {
        var found: [SkeletonView] = []
        if let block = view as? SkeletonView { found.append(block) }
        for subview in view.subviews {
            found.append(contentsOf: blocks(in: subview))
        }
        return found
    }
}
