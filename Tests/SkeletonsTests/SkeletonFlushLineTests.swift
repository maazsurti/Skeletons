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

    /// Lines of different widths still read as one shape, and each keeps the width it asked for.
    @Test func aFlushRunOfDifferentWidthsIsOneSteppedShape() throws {
        try withTheme {
            let column = try #require(
                SkeletonColumn(spacing: 0) {
                    SkeletonLine(.custom(14), width: 224)
                    SkeletonLine(.custom(14), width: 168)
                }.makeView() as? UIStackView
            )

            let run = try #require(column.arrangedSubviews.first as? UIStackView)
            #expect(column.arrangedSubviews.count == 1)
            #expect(run.axis == .vertical)
            #expect(run.spacing == 0)
            #expect(run.arrangedSubviews.count == 2)

            let widths = run.arrangedSubviews.map { view in
                view.constraints.first { $0.firstAttribute == .width }?.constant
            }
            #expect(widths == [224, 168])

            let top = try #require(run.arrangedSubviews.first?.subviews.first)
            let bottom = try #require(run.arrangedSubviews.last?.subviews.first)
            #expect(top.layer.maskedCorners == CACornerMask.skeletonTopCorners)
            #expect(bottom.layer.maskedCorners == CACornerMask.skeletonBottomCorners)
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
