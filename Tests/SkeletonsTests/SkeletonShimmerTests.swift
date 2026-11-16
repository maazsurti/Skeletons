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
