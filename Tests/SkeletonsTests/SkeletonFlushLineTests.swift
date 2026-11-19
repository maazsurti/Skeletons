import Testing
import UIKit
@testable import Skeletons

/// Lines with nothing between them draw as one surface; a gap of any size keeps them apart.
@MainActor
struct SkeletonFlushLineTests {

    private func withTheme(_ body: () throws -> Void) rethrows {
        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(
            cornerRadius: 8,
            spacing: 8,
            cardRadius: 16,
            shadow: .none,
            lineHeight: { ceil($0 * 1.2) }
        )
        try body()
        SkeletonTheme.current = original
    }

    private func height(of view: UIView) -> CGFloat? {
        view.constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }?.constant
    }

    private func absoluteWidth(of view: UIView) -> CGFloat? {
        view.constraints.first { $0.firstAttribute == .width && $0.secondItem == nil }?.constant
    }

    /// The constraint tying the block to its superview's width lives on that superview.
    private func fractionWidth(of view: UIView) -> NSLayoutConstraint? {
        (view.superview?.constraints ?? []).first {
            ($0.firstItem as? UIView) === view
                && $0.firstAttribute == .width
                && $0.secondItem != nil
        }
    }

    @Test func flushLinesDrawAsOneBlock() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.headline)
                    SkeletonLine(.custom(14))
                }.makeView() as? UIStackView
            )

            #expect(column.arrangedSubviews.count == 1)
            let block = try #require(column.arrangedSubviews.first as? SkeletonView)
            #expect(height(of: block) == 38)
        }
    }

    @Test func aFusedBlockRoundsOnlyWhereItEnds() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.headline)
                    SkeletonLine(.custom(14))
                }.makeView() as? UIStackView
            )
            let block = try #require(column.arrangedSubviews.first)
            let fill = try #require(block.subviews.first)

            #expect(fill.layer.maskedCorners == CACornerMask.skeletonAllCorners)
            #expect(fill.layer.cornerRadius == 8.5)
        }
    }

    @Test func aGapKeepsLinesApart() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 4) {
                    SkeletonLine(.headline)
                    SkeletonLine(.custom(14))
                }.makeView() as? UIStackView
            )

            #expect(column.arrangedSubviews.count == 2)
            #expect(column.arrangedSubviews.allSatisfy { $0 is SkeletonView })
        }
    }

    /// Lines of different widths still read as one rectangle, at the widest width they ask for.
    @Test func aFlushRunOfAbsoluteWidthsIsOneRectangleAtTheWidestWidth() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.custom(14), width: 224)
                    SkeletonLine(.custom(14), width: 168)
                }.makeView() as? UIStackView
            )

            #expect(column.arrangedSubviews.count == 1)
            let block = try #require(column.arrangedSubviews.first as? SkeletonView)
            #expect(height(of: block) == 34)
            #expect(absoluteWidth(of: block) == 224)

            let fill = try #require(block.subviews.first)
            #expect(fill.layer.maskedCorners == CACornerMask.skeletonAllCorners)
        }
    }

    @Test func aFlushRunOfFractionsIsOneRectangleAtTheWidestFraction() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.custom(14), widthFraction: 0.5)
                    SkeletonLine(.custom(14), widthFraction: 0.9)
                }.makeView() as? UIStackView
            )

            #expect(column.arrangedSubviews.count == 1)
            let block = try #require(column.arrangedSubviews.first as? SkeletonView)
            #expect(height(of: block) == 34)
            #expect(absoluteWidth(of: block) == nil)
            let width = try #require(fractionWidth(of: block))
            #expect(abs(width.multiplier - 0.9) < 0.001)
        }
    }

    @Test func aFlushRunWithAFillingLineFills() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.custom(14), width: 168)
                    SkeletonLine(.custom(14))
                }.makeView() as? UIStackView
            )

            let block = try #require(column.arrangedSubviews.first as? SkeletonView)
            #expect(column.arrangedSubviews.count == 1)
            #expect(absoluteWidth(of: block) == nil)
            #expect(fractionWidth(of: block) == nil)
        }
    }

    /// A mixed run takes the fraction: it is the wider of the two scales.
    @Test func aFlushRunOfMixedWidthsTakesTheWidestFraction() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.custom(14), width: 200)
                    SkeletonLine(.custom(14), widthFraction: 0.6)
                }.makeView() as? UIStackView
            )

            let block = try #require(column.arrangedSubviews.first as? SkeletonView)
            #expect(column.arrangedSubviews.count == 1)
            #expect(absoluteWidth(of: block) == nil)
            let width = try #require(fractionWidth(of: block))
            #expect(abs(width.multiplier - 0.6) < 0.001)
        }
    }

    @Test func aFusedRectangleTakesTheLargerRadius() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.custom(14), width: 224).radius(4)
                    SkeletonLine(.custom(14), width: 168).radius(10)
                }.makeView() as? UIStackView
            )

            let block = try #require(column.arrangedSubviews.first as? SkeletonView)
            let fill = try #require(block.subviews.first)
            #expect(fill.layer.cornerRadius == 10)
        }
    }

    /// A line with padding around it has a gap, so it keeps to itself.
    @Test func aPaddedLineDoesNotFuse() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.headline)
                    SkeletonLine(.custom(14)).padding(2)
                }.makeView() as? UIStackView
            )

            #expect(column.arrangedSubviews.count == 2)
        }
    }
}
