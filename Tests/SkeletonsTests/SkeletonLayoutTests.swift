import Testing
import UIKit
@testable import Skeletons

@MainActor
struct SkeletonLayoutTests {

    /// A theme with the numbers a layout test can check without depending on the system's font.
    private func withTheme(_ body: () -> Void) {
        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(
            cornerRadius: 8,
            spacing: 7,
            cardRadius: 16,
            shadow: .none,
            lineHeight: { $0 * 1.2 }
        )
        body()
        SkeletonTheme.current = original
    }

    @Test func lineTakesItsHeightFromTheTheme() {
        withTheme {
            let line = SkeletonLine(.custom(20)).makeView()

            #expect(line.heightConstraint == 24)
        }
    }

    @Test func overridesBeatTheThemeDefaults() {
        withTheme {
            let block = SkeletonBlock(height: 54).radius(12).makeView()

            #expect(block.heightConstraint == 54)
            let fill = block.subviews.first
            #expect(fill?.layer.cornerRadius == 12)
        }
    }

    @Test func photoKeepsTheAspectItIsGiven() {
        withTheme {
            let photo = SkeletonPhoto(width: 120, aspect: 0.5).makeView()

            #expect(photo.heightConstraint == nil)
            #expect(photo.constraints.contains { $0.firstAttribute == .height && $0.multiplier == 0.5 })
        }
    }

    @Test func columnUsesTheThemesSpacingAndItsOwnPadding() {
        withTheme {
            let column = SkeletonColumn(padding: 8) {
                SkeletonLine(.body)
                SkeletonLine(.body)
            }.makeView() as? UIStackView

            #expect(column?.spacing == 7)
            #expect(column?.layoutMargins == UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
            #expect(column?.arrangedSubviews.count == 2)
        }
    }

    @Test func rowsRepeatOneShapeTheCountTimes() {
        withTheme {
            let rows = SkeletonRows(count: 5, spacing: 12, padding: 4, .listRow).makeView() as? UIStackView

            #expect(rows?.arrangedSubviews.count == 5)
            #expect(rows?.spacing == 12)
            #expect(rows?.layoutMargins == UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        }
    }

    @Test func rowsCanRepeatAShapeWrittenAtTheCallSite() {
        withTheme {
            let rows = SkeletonRows(count: 3, spacing: 8) {
                SkeletonBlock(height: 54, radius: 12)
            }.makeView() as? UIStackView

            #expect(rows?.arrangedSubviews.count == 3)
        }
    }

    @Test func cardCarriesItsOwnRadiusPaddingAndBorder() {
        withTheme {
            let card = SkeletonCard(padding: 14, radius: 20, background: .white, border: .lightGray) {
                SkeletonLine(.body)
            }.makeView()

            #expect(card.layer.cornerRadius == 20)
            #expect(card.layer.borderWidth == 1)
            let body = card.subviews.first as? UIStackView
            #expect(body?.layoutMargins == UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        }
    }

    /// A screen gets one "Loading" element, with the blocks themselves kept out of VoiceOver.
    @Test func layoutIsOneLoadingElement() {
        withTheme {
            let layout = SkeletonLayout {
                SkeletonLine(.title)
                SkeletonRows(count: 2, .listRow)
            }.makeView()

            #expect(layout is SkeletonContainerView)
            #expect(layout.isAccessibilityElement)
            #expect(layout.accessibilityLabel == SkeletonTheme.current.loadingText)
        }
    }

    /// The real copy a screen keeps on screen is not a block and is not shimmering.
    @Test func realViewsArePassedThroughUntouched() {
        withTheme {
            let label = UILabel()
            label.text = "Wallet packages"

            let layout = SkeletonLayout {
                SkeletonReal(label)
                SkeletonLine(.body)
            }.makeView()

            #expect(label.superview != nil)
            #expect(layout.accessibilityLabel == SkeletonTheme.current.loadingText)
        }
    }
}

private extension UIView {
    /// The fixed height this view was given, so a test can check a size before anything lays out.
    var heightConstraint: CGFloat? {
        constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }?.constant
    }
}
