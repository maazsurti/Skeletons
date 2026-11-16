import Testing
import UIKit
@testable import Skeletons

@MainActor
struct LoopCheck {
    @Test func loopInsideCardBuildsEveryRow() {
        let card = SkeletonCard(padding: 4) {
            for index in 0..<3 {
                if index > 0 { SkeletonReal(UIView()) }
                SkeletonPreset.listRow
            }
        }.makeView()
        let body = card.subviews.first as? UIStackView
        #expect(body?.arrangedSubviews.count == 5)
    }
}

@MainActor
struct CardSizeCheck {
    @Test func aCardTakesTheHeightOfItsRows() {
        let card = SkeletonCard(padding: 14) {
            SkeletonRows(count: 3, spacing: 12) { SkeletonPreset.listRow }
        }.makeView()
        #expect(card.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height > 100)
    }
}
