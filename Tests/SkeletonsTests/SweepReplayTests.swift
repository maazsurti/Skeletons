import Testing
import UIKit
import QuartzCore
@testable import Skeletons

/// The sweep replayed on a synthetic clock: one pass at the themed pace, held off screen while the
/// wave crosses the rest of the screen, and repeated from the screen's start. The band's place is a
/// pure function of the clock, so three cycles can be stepped frame by frame and compared.
@MainActor
struct SweepReplayTests {

    /// The block shapes this package's presets draw: a full-width card, a narrow chip, a block
    /// scrolled partly off the leading edge, a block wider than the window, and a block flush to
    /// the window's leading edge.
    private struct Shape: CustomStringConvertible {
        let name: String
        let windowWidth: CGFloat
        let blockWidth: CGFloat
        let blockHeight: CGFloat
        let originX: CGFloat

        var description: String { name }
    }

    private let shapes = [
        Shape(name: "full-width card", windowWidth: 402, blockWidth: 362, blockHeight: 120, originX: 20),
        Shape(name: "narrow chip", windowWidth: 402, blockWidth: 120, blockHeight: 40, originX: 282),
        Shape(name: "flush to the leading edge", windowWidth: 402, blockWidth: 200, blockHeight: 14, originX: 0),
        Shape(name: "scrolled off the leading edge", windowWidth: 402, blockWidth: 200, blockHeight: 64, originX: -30),
        Shape(name: "wider than the window", windowWidth: 402, blockWidth: 520, blockHeight: 210, originX: -40),
    ]

    private let band: CGFloat = 140.7
    private let pass: TimeInterval = 1.7
    private let stagger: TimeInterval = 0.1
    private let frame: TimeInterval = 1.0 / 60.0

    /// Where the container carrying the band sits in the block's own coordinates at a fraction of a
    /// pass.
    private func blockX(_ shape: Shape, progress: Double, isRightToLeft: Bool) -> CGFloat {
        let travel = SkeletonView.sweepTravel(
            windowWidth: shape.windowWidth,
            bandWidth: band,
            height: shape.blockHeight,
            reach: shape.blockHeight,
            anchor: shape.originX,
            isRightToLeft: isRightToLeft
        )
        return travel.from + CGFloat(progress) * (travel.to - travel.from)
    }

    /// The band's leading edge in window coordinates at a fraction of a pass.
    private func windowX(_ shape: Shape, progress: Double, isRightToLeft: Bool) -> CGFloat {
        blockX(shape, progress: progress, isRightToLeft: isRightToLeft) + shape.originX
    }

    /// The horizontal span the band covers in the window at a fraction of a pass. A stripe leaning
    /// 45° covers its own width and the block's height, half of that height past each end.
    private func bandSpan(
        _ shape: Shape,
        progress: Double,
        isRightToLeft: Bool
    ) -> ClosedRange<CGFloat> {
        let low = windowX(shape, progress: progress, isRightToLeft: isRightToLeft) - shape.blockHeight / 2
        return low...(low + band + shape.blockHeight)
    }

    /// The part of the block the reader can see, in window coordinates.
    private func visibleSpan(_ shape: Shape) -> ClosedRange<CGFloat> {
        max(0, shape.originX)...min(shape.windowWidth, shape.originX + shape.blockWidth)
    }

    /// Whether any of the band is inside the window.
    private func isOnScreen(_ shape: Shape, progress: Double, isRightToLeft: Bool) -> Bool {
        let span = bandSpan(shape, progress: progress, isRightToLeft: isRightToLeft)
        let visible = visibleSpan(shape)
        return span.upperBound > visible.lowerBound && span.lowerBound < visible.upperBound
    }

    /// A band at the start of a pass sits clear beyond the edge the pass begins from, and at the
    /// end clear beyond the edge it finishes at: in a left-to-right screen, left then right.
    @Test func aPassBeginsAndEndsClearOfTheWindow() {
        for shape in shapes {
            for isRightToLeft in [false, true] {
                let first = bandSpan(shape, progress: 0, isRightToLeft: isRightToLeft)
                let last = bandSpan(shape, progress: 1, isRightToLeft: isRightToLeft)
                let visible = visibleSpan(shape)

                #expect(!isOnScreen(shape, progress: 0, isRightToLeft: isRightToLeft), "\(shape) begins on the block")
                #expect(!isOnScreen(shape, progress: 1, isRightToLeft: isRightToLeft), "\(shape) ends on the block")

                if isRightToLeft {
                    #expect(first.lowerBound >= visible.upperBound)
                    #expect(last.upperBound <= visible.lowerBound)
                } else {
                    #expect(first.upperBound <= visible.lowerBound)
                    #expect(last.lowerBound >= visible.upperBound)
                }
            }
        }
    }

    /// A pass carries the window's width, the band and the block's own slant, whatever the block's
    /// width or origin, so the window is crossed by the band rather than by each block's edges.
    @Test func aPassCrossesTheWindowPlusTheBandsSlant() {
        for shape in shapes {
            for isRightToLeft in [false, true] {
                let travel = SkeletonView.sweepTravel(
                    windowWidth: shape.windowWidth,
                    bandWidth: band,
                    height: shape.blockHeight,
                    reach: shape.blockHeight,
                    anchor: shape.originX,
                    isRightToLeft: isRightToLeft
                )
                let distance = abs(travel.to - travel.from)
                #expect(
                    abs(distance - (shape.windowWidth + band + shape.blockHeight)) < 0.001,
                    "\(shape) crosses the window and its own slant"
                )
            }
        }
    }

    /// Stepped at 60 Hz, the band never moves more than one frame's travel while it is on screen.
    @Test func theBandNeverJumpsWhileItIsOnScreen() {
        for shape in shapes {
            let step = (shape.windowWidth + band + shape.blockHeight) * CGFloat(frame) / CGFloat(pass)
            for isRightToLeft in [false, true] {
                let samples = Int((3 * pass) / frame) + 1
                for index in 1..<samples {
                    let previousProgress = ShimmerTimeline.passProgress(
                        at: Double(index - 1) * frame,
                        pass: pass,
                        period: pass
                    )
                    let progress = ShimmerTimeline.passProgress(
                        at: Double(index) * frame,
                        pass: pass,
                        period: pass
                    )
                    let previous = windowX(shape, progress: previousProgress, isRightToLeft: isRightToLeft)
                    let current = windowX(shape, progress: progress, isRightToLeft: isRightToLeft)
                    // The wrap is covered by everyWrapHappensOffScreen: it moves the band between
                    // two places that are both clear of the window.
                    guard progress >= previousProgress else { continue }
                    let visible = isOnScreen(shape, progress: previousProgress, isRightToLeft: isRightToLeft)
                        || isOnScreen(shape, progress: progress, isRightToLeft: isRightToLeft)
                    if visible {
                        #expect(abs(current - previous) <= step + 0.5, "\(shape) jumps at frame \(index)")
                    }
                }
            }
        }
    }

    /// The wrap happens with the band outside the window at both ends, so the eye never sees it
    /// leave one edge and arrive at the other.
    @Test func everyWrapHappensOffScreen() {
        for shape in shapes {
            for isRightToLeft in [false, true] {
                #expect(!isOnScreen(shape, progress: 1, isRightToLeft: isRightToLeft))
                #expect(!isOnScreen(shape, progress: 0, isRightToLeft: isRightToLeft))
            }
        }
    }

    /// Three cycles of the same component are the same frame for frame, hold included, so the seam
    /// carries no step of its own.
    @Test func threeCyclesReplayIdentically() {
        let period = ShimmerTimeline.period(pass: pass, components: 4, stagger: stagger)
        let cycleLength = Int((period / frame).rounded())
        for shape in shapes {
            for isRightToLeft in [false, true] {
                for offset in [0.0, 0.3] {
                    let samples = Int((3 * period) / frame)
                    var positions: [CGFloat] = []
                    for index in 0..<samples {
                        let progress = ShimmerTimeline.passProgress(
                            at: offset + (Double(index) + 0.5) * frame,
                            pass: pass,
                            period: period,
                            offset: offset
                        )
                        positions.append(windowX(shape, progress: progress, isRightToLeft: isRightToLeft))
                    }
                    for index in 0..<(samples - 2 * cycleLength) {
                        #expect(abs(positions[index] - positions[index + cycleLength]) < 0.000_1)
                        #expect(abs(positions[index] - positions[index + 2 * cycleLength]) < 0.000_1)
                    }
                }
            }
        }
    }

    /// A component's pass starts later than the one above it and never lands in the same phase,
    /// however many components a screen has.
    @Test func noTwoComponentsOfAScreenShareAPhase() {
        let components = 20
        let period = ShimmerTimeline.period(pass: pass, components: components, stagger: stagger)
        var starts: [TimeInterval] = []
        for ordinal in 0..<components {
            starts.append(ShimmerTimeline.offset(ordinal: ordinal, stagger: stagger))
        }
        for (index, start) in starts.enumerated() {
            #expect(abs(start - Double(index) * stagger) < 0.000_001)
        }
        #expect(Set(starts).count == components)
        // The last component starts inside the cycle and finishes its pass exactly as the next
        // wave's first component starts.
        #expect(starts[components - 1] + pass <= period + 0.000_001)
        #expect(abs(starts[components - 1] + pass - period) < 0.000_001)
    }
}
