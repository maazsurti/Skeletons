import Testing
import UIKit
@testable import Skeletons

/// `SkeletonTheme.shimmerAngle` leans the stripe by degrees: `0` draws one upright line, `20` the
/// default lean, `45` a quarter-turn diagonal, and the lean decides how far across a block's height
/// the line travels.
@MainActor
struct ShimmerAngleTests {

    private let band: CGFloat = 140.7

    /// The default keeps today's geometry: the anchor moves one point across per point down, and the
    /// reach is the line's height.
    @Test func fortyFiveKeepsTheDiagonal() {
        let theme = SkeletonTheme(shimmerAngle: 45)
        #expect(abs(theme.shimmerTangent - 1) < 0.000_001)

        let line = SkeletonView.sweepLine(
            blockFrame: CGRect(x: 20, y: 140, width: 300, height: 40),
            lineOriginY: 100,
            lineHeight: 120,
            tangent: theme.shimmerTangent
        )
        #expect(abs(line.anchor - 60) < 0.000_001)
        #expect(abs(line.reach - 120) < 0.000_001)
    }

    /// A theme that names no angle leans gently: the line gains less across than it travels down.
    @Test func theDefaultLeanIsTwentyDegrees() {
        let theme = SkeletonTheme()
        #expect(theme.shimmerAngle == 20)
        #expect(abs(theme.shimmerTangent - 0.363_970) < 0.000_001)
    }

    /// A straight stripe puts every block at its own x, whatever its height on the line.
    @Test func aZeroAngleDrawsOneUprightStripe() {
        let tangent = SkeletonTheme(shimmerAngle: 0).shimmerTangent
        #expect(tangent == 0)

        let frames = [
            CGRect(x: 40, y: 20, width: 300, height: 40),
            CGRect(x: 40, y: 300, width: 120, height: 14),
            CGRect(x: 140, y: 600, width: 200, height: 90),
        ]
        for frame in frames {
            let line = SkeletonView.sweepLine(
                blockFrame: frame,
                lineOriginY: 0,
                lineHeight: 800,
                tangent: tangent
            )
            #expect(line.anchor == frame.minX)
            #expect(line.reach == 0)
        }
    }

    /// A lean of 30° shifts the line by `tan(30°)` of the distance down, not one for one.
    @Test func aLeanOfThirtyDegreesShiftsByItsTangent() {
        let tangent = SkeletonTheme(shimmerAngle: 30).shimmerTangent
        #expect(abs(tangent - 0.577_350) < 0.000_001)

        let line = SkeletonView.sweepLine(
            blockFrame: CGRect(x: 40, y: 300, width: 200, height: 40),
            lineOriginY: 100,
            lineHeight: 600,
            tangent: tangent
        )
        #expect(abs(line.anchor - (40 + 200 * tangent)) < 0.000_001)
        #expect(abs(line.reach - 600 * tangent) < 0.000_001)
    }

    /// A negative angle leans the other way: the line moves back as it goes down.
    @Test func aNegativeAngleLeansTheOtherWay() {
        let line = SkeletonView.sweepLine(
            blockFrame: CGRect(x: 240, y: 300, width: 140, height: 40),
            lineOriginY: 100,
            lineHeight: 600,
            tangent: SkeletonTheme(shimmerAngle: -30).shimmerTangent
        )
        #expect(line.anchor < 240)
        #expect(abs(line.anchor - (240 - 200 * tan(30 * .pi / 180))) < 0.000_001)
        #expect(line.reach > 0)
    }

    /// The lean is read as at most 80° either way, and set the same way through the property.
    @Test func theAngleIsClampedEitherWay() {
        #expect(SkeletonTheme(shimmerAngle: 120).shimmerAngle == 80)
        #expect(SkeletonTheme(shimmerAngle: -120).shimmerAngle == -80)

        var theme = SkeletonTheme()
        theme.shimmerAngle = 95
        #expect(theme.shimmerAngle == 80)
        theme.shimmerAngle = -95
        #expect(theme.shimmerAngle == -80)
        theme.shimmerAngle = 30
        #expect(theme.shimmerAngle == 30)
    }

    /// A pass carries the lean's reach, so the stripe starts and finishes clear of the window at
    /// any angle.
    @Test func thePassCarriesTheLeansReach() {
        for angle in [-60, -30, 0, 30, 45, 70] as [CGFloat] {
            let tangent = SkeletonTheme(shimmerAngle: angle).shimmerTangent
            let line = SkeletonView.sweepLine(
                blockFrame: CGRect(x: 20, y: 220, width: 360, height: 120),
                lineOriginY: 0,
                lineHeight: 800,
                tangent: tangent
            )
            let travel = SkeletonView.sweepTravel(
                windowWidth: 402,
                bandWidth: band,
                height: 120,
                reach: line.reach,
                anchor: line.anchor,
                tangent: tangent,
                isRightToLeft: false
            )
            let distance = travel.to - travel.from
            #expect(abs(distance - (402 + band + line.reach)) < 0.000_001, "angle \(angle)")
        }
    }

    /// The band keeps one speed as the angle changes: a lean that adds travel lengthens the pass.
    @Test func theBandKeepsItsSpeedAtEveryAngle() {
        let themed: TimeInterval = 1.7
        let window: CGFloat = 402
        let height: CGFloat = 800

        let straight = SkeletonView.sweepPass(
            themed: themed,
            travelled: window + band,
            reference: window + band + height
        )
        let diagonal = SkeletonView.sweepPass(
            themed: themed,
            travelled: window + band + height,
            reference: window + band + height
        )
        #expect(abs(diagonal - themed) < 0.000_001)
        #expect(straight < diagonal)

        let straightSpeed = (window + band) / CGFloat(straight)
        let diagonalSpeed = (window + band + height) / CGFloat(diagonal)
        #expect(abs(straightSpeed - diagonalSpeed) < 0.001)
    }

    /// Right to left mirrors the lean, so the stripe leans the way the pass runs.
    @Test func rightToLeftMirrorsTheLean() {
        let tangent: CGFloat = 0.577_350
        let frame = CGRect(x: 40, y: 300, width: 200, height: 40)
        let reading = SkeletonView.sweepLine(
            blockFrame: frame,
            lineOriginY: 0,
            lineHeight: 600,
            tangent: tangent
        )
        let mirrored = SkeletonView.sweepLine(
            blockFrame: frame,
            lineOriginY: 0,
            lineHeight: 600,
            tangent: -tangent
        )
        #expect(abs(reading.anchor - frame.minX - 300 * tangent) < 0.000_001)
        #expect(abs(mirrored.anchor - frame.minX + 300 * tangent) < 0.000_001)
        #expect(reading.reach == mirrored.reach)
    }
}
