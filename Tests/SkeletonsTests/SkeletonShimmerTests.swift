import Testing
import UIKit
@testable import Skeletons

@MainActor
struct SkeletonShimmerTests {

    // A sweep crosses the window, not the block, so neighbouring blocks light up as one band. The
    // band leans 45°, so the pass also carries the slant's reach, half of it past each end.
    @Test func sweepTravelsAcrossTheWholeWindow() {
        let travel = SkeletonView.sweepTravel(
            windowWidth: 400,
            bandWidth: 140,
            height: 80,
            reach: 80,
            anchor: 20,
            tangent: 1,
            isRightToLeft: false
        )
        #expect(travel.from == -200)
        #expect(travel.to == 420)
        #expect(abs((travel.to - travel.from) - 620) < 0.000_001)
    }

    /// The stripe covers the block's height as well as the band's own width, so a pass starts and
    /// finishes with the whole stripe, corners included, clear of the block.
    @Test func theSlantIsClearOfTheBlockAtBothEnds() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerAngle: 45)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let block = SkeletonView.block(height: 150)
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
        let from = try #require(number(values[0]))
        let to = try #require(number(values[1]))
        let container = try #require(block.subviews.first?.layer.sublayers?.first)
        let bandWidth = container.bounds.width
        let height = block.bounds.height
        let originX: CGFloat = 20

        // The stripe's top corner leads the band and its bottom corner trails it.
        #expect(from + originX + bandWidth + height / 2 <= 0.001)
        #expect(to + originX - height / 2 >= 402 - 0.001)
    }

    /// The stripe leans by the theme's angle towards the way the pass runs, and mirrors when the
    /// layout does.
    @Test func theBandLeansByItsAngleAndMirrorsForRightToLeft() throws {
        let leaning = try bandTransform(isRightToLeft: false)
        #expect(abs(abs(leaning.m12) - sin(CGFloat.pi / 4)) < 0.000_001)
        #expect(abs(abs(leaning.m11) - cos(CGFloat.pi / 4)) < 0.000_001)
        #expect(leaning.m12 * leaning.m21 <= 0)

        let mirrored = try bandTransform(isRightToLeft: true)
        #expect(mirrored.m12 == -leaning.m12)
        #expect(mirrored.m21 == -leaning.m21)
        #expect(mirrored.m11 == leaning.m11)
        #expect(mirrored.m22 == leaning.m22)
    }

    private func bandTransform(isRightToLeft: Bool) throws -> CATransform3D {
        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(
            shimmerDuration: original.shimmerDuration,
            shimmerStagger: original.shimmerStagger,
            shimmerAngle: 45,
            isRightToLeft: { isRightToLeft }
        )
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let block = SkeletonView.block(height: 150)
        block.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            block.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            block.widthAnchor.constraint(equalToConstant: 300),
        ])
        window.layoutIfNeeded()

        let stripe = try #require(block.subviews.first?.layer.sublayers?.first?.sublayers?.first)
        return stripe.transform
    }

    /// The blocks of one card draw one stripe: at any window y their bands sit at the same place,
    /// so a card's lines read one slash rather than a stepped band on each line.
    @Test func aCardsBlocksShareOneSlantedLine() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerAngle: 45)
        defer { SkeletonTheme.current = original }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let layout = SkeletonLayout(spacing: 0) {
            SkeletonCard(padding: 12) {
                SkeletonLine(.body, width: 300)
                SkeletonLine(.body, width: 240)
                SkeletonBlock(height: 120)
            }
        }.makeView()
        layout.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.topAnchor.constraint(equalTo: window.topAnchor, constant: 40),
            layout.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            layout.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -20),
        ])
        window.layoutIfNeeded()

        let blocks = blocks(in: layout)
        #expect(blocks.count == 3)

        // The stripe's leading edge at the card's top edge, wherever each block sits inside it.
        let cardTop = layout.convert(layout.bounds, to: window).minY
        let edges = try blocks.map { block -> CGFloat in
            let sweep = try #require(block.activeSweep as? CAKeyframeAnimation)
            let values = try #require(sweep.values)
            let translation = try #require(number(values[0]))
            let container = try #require(block.subviews.first?.layer.sublayers?.first)
            let frame = block.convert(block.bounds, to: window)
            return frame.minX + translation + container.bounds.width
                + block.bounds.height / 2 + frame.minY - cardTop
        }
        for edge in edges {
            #expect(abs(edge - edges[0]) < 0.001, "a block draws its own line")
        }
    }

    private func blocks(in view: UIView) -> [SkeletonView] {
        var found: [SkeletonView] = []
        if let block = view as? SkeletonView { found.append(block) }
        for subview in view.subviews { found += blocks(in: subview) }
        return found
    }

    private func number(_ value: Any) -> CGFloat? {
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        if let cgFloat = value as? CGFloat { return cgFloat }
        return nil
    }

    // Right to left runs the same distance the other way, so the band enters from the trailing edge.
    @Test func rightToLeftSweepIsMirrored() {
        let leftToRight = SkeletonView.sweepTravel(
            windowWidth: 400,
            bandWidth: 140,
            height: 80,
            reach: 80,
            anchor: 20,
            tangent: 1,
            isRightToLeft: false
        )
        let rightToLeft = SkeletonView.sweepTravel(
            windowWidth: 400,
            bandWidth: 140,
            height: 80,
            reach: 80,
            anchor: 20,
            tangent: 1,
            isRightToLeft: true
        )

        #expect(rightToLeft.from == leftToRight.to)
        #expect(rightToLeft.to == leftToRight.from)
    }

    // A block on screen sweeps, and stops the moment it is hidden.
    @Test func sweepRunsInAWindowAndStopsWhenHidden() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let block = SkeletonView.block(height: 40)
        block.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            block.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            block.widthAnchor.constraint(equalToConstant: 200),
        ])
        window.layoutIfNeeded()

        #expect(block.activeSweep != nil)

        block.isHidden = true
        #expect(block.activeSweep == nil)
    }

    // The sweep begins at the screen's start plus the component's offset and holds at the band's
    // `from` until then, so a component whose turn has not come stays off the window.
    @Test func sweepBeginsAtTheStartPlusTheComponentOffset() {
        let start: CFTimeInterval = 1_000
        let sweep = ShimmerTimeline.sweepAnimation(
            from: -100,
            to: 400,
            pass: 1.2,
            period: 1.5,
            offset: 0.3,
            start: start
        )

        #expect(abs(sweep.beginTime - (start + 0.3)) < 0.000_001)
        #expect(sweep.fillMode == .backwards)
        #expect(ShimmerTimeline.passProgress(at: start, pass: 1.2, period: 1.5, offset: 0.3, start: start) == 0)
    }

    // Reduce Motion replaces the sweep with the pulse on the block's fill, and the sweep stays off.
    @Test func reduceMotionPulsesInsteadOfSweeping() throws {
        SkeletonView.reduceMotionOverride = true
        defer { SkeletonView.reduceMotionOverride = nil }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let block = SkeletonView.block(height: 40)
        block.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(block)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
            block.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            block.widthAnchor.constraint(equalToConstant: 200),
        ])
        window.layoutIfNeeded()

        #expect(block.activeSweep == nil)
        let pulse = try #require(block.activePulse)
        #expect(pulse.repeatCount > 1_000)
        #expect(pulse.autoreverses)
    }
}
