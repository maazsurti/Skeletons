import Testing
import UIKit
@testable import Skeletons

@MainActor
struct SkeletonThemeTests {

    // A theme is usable with no setup at all, so a screen can show a skeleton before launch
    // configures anything.
    @Test func defaultThemeIsUsableAsIs() {
        let theme = SkeletonTheme()
        #expect(theme.cornerRadius == 8)
        #expect(theme.shimmerDuration == 1.7)
        #expect(theme.loadingText == "Loading")
    }

    // Placeholders sit on dark surfaces as well as light ones, so both colours have to answer the
    // trait collection rather than pin one appearance.
    @Test func defaultColoursFollowBothAppearances() {
        let theme = SkeletonTheme()
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)

        #expect(theme.base.resolvedColor(with: light) != theme.base.resolvedColor(with: dark))
        #expect(theme.highlight.resolvedColor(with: light) != theme.highlight.resolvedColor(with: dark))
    }

    // The app replaces the copy it localises and keeps every other default.
    @Test func appThemeOverridesOnlyWhatItSets() {
        let original = SkeletonTheme.current
        defer { SkeletonTheme.current = original }

        SkeletonTheme.current = SkeletonTheme(loadingText: "جارٍ التحميل", isRightToLeft: { true })
        #expect(SkeletonTheme.current.loadingText == "جارٍ التحميل")
        #expect(SkeletonTheme.current.isRightToLeft() == true)
        #expect(SkeletonTheme.current.shimmerDuration == 1.7)
    }
}
