import Testing
import UIKit
@testable import Skeletons

@MainActor
struct SkeletonShimmerTests {

    // A sweep crosses the window, not the block, so neighbouring blocks light up as one band.
    @Test func sweepTravelsAcrossTheWholeWindow() {
        let travel = SkeletonView.sweepTravel(
            windowWidth: 400,
            bandWidth: 140,
            originX: 20,
            isRightToLeft: false
        )
        #expect(travel.from == -160)
        #expect(travel.to == 380)
    }

    // Right to left runs the same distance the other way, so the band enters from the trailing edge.
    @Test func rightToLeftSweepIsMirrored() {
        let leftToRight = SkeletonView.sweepTravel(
            windowWidth: 400,
            bandWidth: 140,
            originX: 20,
            isRightToLeft: false
        )
        let rightToLeft = SkeletonView.sweepTravel(
            windowWidth: 400,
            bandWidth: 140,
            originX: 20,
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

    // The start time is always in the past and never more than one sweep behind, which is what
    // puts a block added later in the same phase as the blocks already on screen.
    @Test func startTimeSitsWithinTheSweepAlreadyRunning() {
        let duration: TimeInterval = 1.2
        let start = ShimmerTimeline.startTime(duration: duration)
        let now = CACurrentMediaTime()

        #expect(start <= now)
        #expect(now - start < duration)
    }
}
