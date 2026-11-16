import Testing
import UIKit
@testable import Skeletons

/// The shapes a host screen builds have to lay out in the width the screen gives them: a
/// placeholder states what it wants, and a row keeps every child at the size that child asked for.
@MainActor
struct SkeletonLayoutConflictTests {

    /// The theme the app uses: a line box of one and a fifth of the type size, rounded up.
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

    private func row(in window: UIWindow, width: CGFloat) -> UIStackView {
        let row = SkeletonRow(spacing: 14, alignment: .fill) {
            SkeletonPhoto(width: 84, height: 84, radius: 10)
            SkeletonColumn(spacing: 4) {
                SkeletonLine(.headline, width: 132)
                SkeletonLine(.custom(14), width: 190)
            }
            SkeletonSpacer()
            SkeletonPreset.priceColumn
        }.makeView() as! UIStackView
        row.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: window.topAnchor),
            row.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            row.widthAnchor.constraint(equalToConstant: width),
        ])
        window.layoutIfNeeded()
        return row
    }

    /// A `.fill` row that holds a tall photo beside a two-line copy column, in the 340 pt a card
    /// leaves on a phone: the photo keeps 84, the lines keep their own heights, and nothing is
    /// stretched to the row.
    @Test func aFillRowWithATallPhotoKeepsItsColumnNatural() throws {
        try withTheme {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 340, height: 600))
            let row = row(in: window, width: 340)
            window.layoutIfNeeded()

            let photo = try #require(row.arrangedSubviews.first as? SkeletonView)
            #expect(photo.bounds.size == CGSize(width: 84, height: 84))

            let column = try #require(row.arrangedSubviews.dropFirst().first as? UIStackView)
            #expect(column.bounds.height == 42)

            let lines = column.arrangedSubviews.compactMap { $0 as? SkeletonView }
            #expect(lines.count == 2)
            #expect(lines.first?.bounds.height == 21)
            #expect(lines.last?.bounds.height == 17)

            #expect(row.bounds.height == 84)
            #expect(row.bounds.width == 340)
        }
    }

    /// A stated width is a preference: in a row too narrow for every block, the lines give way
    /// instead of pushing the row's content past its trailing edge.
    @Test func statedWidthsGiveWayToANarrowRow() throws {
        try withTheme {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 340, height: 600))
            let row = row(in: window, width: 340)
            window.layoutIfNeeded()

            let column = try #require(row.arrangedSubviews.dropFirst().first as? UIStackView)
            let lines = column.arrangedSubviews.compactMap { $0 as? SkeletonView }
            for line in lines {
                #expect(line.bounds.width > 0)
                #expect(line.bounds.width <= 190.5)
            }

            let widest = row.arrangedSubviews.map(\.frame.maxX).max() ?? 0
            #expect(widest <= row.bounds.width + 0.5)
        }
    }

    /// The photo keeps the height it asserted even though the copy column beside it is shorter.
    @Test func aPhotoKeepsItsStatedHeight() throws {
        try withTheme {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
            let row = row(in: window, width: 400)
            window.layoutIfNeeded()

            let photo = try #require(row.arrangedSubviews.first as? SkeletonView)
            #expect(photo.bounds.height == 84)
        }
    }

    /// A stated width is a preference, not a requirement; a stated height still is.
    @Test func aStatedWidthIsNotRequired() {
        let line = SkeletonView.line(height: 21, width: 190)
        let photo = SkeletonPhoto(width: 84, height: 64).makeView()

        #expect(widthConstraint(of: line)?.priority == UILayoutPriority(999))
        #expect(widthConstraint(of: photo)?.priority == UILayoutPriority(999))
        #expect(line.constraints.contains { $0.firstAttribute == .height && $0.priority == .required })
        #expect(photo.constraints.contains { $0.firstAttribute == .height && $0.priority == .required })
    }

    /// Every placeholder in a row narrower than the sum of what they ask for gives way together:
    /// no block collapses to nothing, and the row still ends inside its own bounds.
    @Test func everyPlaceholderGivesWayInANarrowRow() throws {
        try withTheme {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            let row = row(in: window, width: 300)
            window.layoutIfNeeded()

            let blocks = row.blocks
            #expect(!blocks.isEmpty)
            for block in blocks {
                #expect(block.bounds.width > 0)
                #expect(block.bounds.height > 0)
            }
            let widest = row.arrangedSubviews.map(\.frame.maxX).max() ?? 0
            #expect(widest <= row.bounds.width + 0.5)
        }
    }

    private func widthConstraint(of view: UIView) -> NSLayoutConstraint? {
        view.constraints.first { $0.firstAttribute == .width && $0.secondItem == nil }
    }
}

private extension UIView {
    /// Every placeholder block under this view.
    var blocks: [SkeletonView] {
        subviews.flatMap { view -> [SkeletonView] in
            (view as? SkeletonView).map { [$0] } ?? view.blocks
        }
    }
}
