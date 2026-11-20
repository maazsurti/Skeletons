import Testing
import UIKit
@testable import Skeletons

/// The sweep runs as a wave over the screen's components: each piece the eye reads as one — a card,
/// a row, a field — starts one stagger after the one above it, and every block inside it shares
/// that phase.
@MainActor
struct SkeletonStaggerTests {

    private let pass: TimeInterval = 1.7
    private let stagger: TimeInterval = 0.1

    @Test func offsetsAreCumulativeFromTheTop() {
        #expect(ShimmerTimeline.offset(ordinal: 0, stagger: 0.15) == 0)
        #expect(abs(ShimmerTimeline.offset(ordinal: 1, stagger: 0.15) - 0.15) < 0.000_001)
        #expect(abs(ShimmerTimeline.offset(ordinal: 2, stagger: 0.15) - 0.30) < 0.000_001)
        #expect(abs(ShimmerTimeline.offset(ordinal: 7, stagger: 0.15) - 1.05) < 0.000_001)
    }

    /// A late component keeps its own offset instead of wrapping back onto the first component.
    @Test func aLateComponentNeverJoinsAnEarlierPhase() {
        let late = ShimmerTimeline.offset(ordinal: 17, stagger: stagger)
        #expect(abs(late - 1.7) < 0.000_001)
        #expect(late != 0)

        let offsets = (0..<20).map { ShimmerTimeline.offset(ordinal: $0, stagger: stagger) }
        #expect(Set(offsets).count == 20)
    }

    /// The screen's cycle is one pass, the band's rest, and the time the wave takes to reach its
    /// last component.
    @Test func theCycleCoversTheScreensWholeSpread() {
        #expect(abs(ShimmerTimeline.period(pass: pass, rest: 0.25, components: 1, stagger: stagger) - 1.95) < 0.000_001)
        #expect(abs(ShimmerTimeline.period(pass: pass, rest: 0.25, components: 3, stagger: stagger) - 2.15) < 0.000_001)
        #expect(abs(ShimmerTimeline.period(pass: pass, rest: 0.25, components: 4, stagger: stagger) - 2.25) < 0.000_001)
        #expect(abs(ShimmerTimeline.period(pass: pass, rest: 0.25, components: 20, stagger: stagger) - 3.85) < 0.000_001)
    }

    /// A rest of zero leaves the cycle as the wave alone, and a negative rest cannot shorten it.
    @Test func aRestOfZeroOrLessNeverShortensTheCycle() {
        #expect(abs(ShimmerTimeline.period(pass: pass, components: 1, stagger: stagger) - 1.7) < 0.000_001)
        #expect(abs(ShimmerTimeline.period(pass: pass, rest: -0.4, components: 1, stagger: stagger) - 1.7) < 0.000_001)
    }

    /// The layout's own pieces take the places: a bare line is one, a card and everything inside it
    /// is one, and every copy of a repeated row is one.
    @Test func componentsTakeTheirPlaceTopToBottom() {
        let layout = SkeletonLayout(spacing: 10) {
            SkeletonLine(.title)
            SkeletonCard(padding: 12) {
                SkeletonLine(.headline)
                SkeletonLine(.body, widthFraction: 0.8)
            }
            SkeletonRows(count: 2, spacing: 8) {
                SkeletonBlock(height: 60)
            }
        }.makeView()

        let all = blocks(in: layout)
        #expect(all.count == 5)
        #expect(places(of: all).map(\.ordinal) == [0, 1, 1, 2, 3])
        #expect(places(of: all).map(\.count) == [4, 4, 4, 4, 4])
    }

    /// An order card is one component however many blocks draw it: three cards make a wave of
    /// three, 0 then 0.1 then 0.2.
    @Test func aCardIsOneComponent() {
        let layout = SkeletonLayout(spacing: 12) {
            SkeletonRows(count: 3, spacing: 12) {
                SkeletonCard(padding: 14) {
                    SkeletonRow(spacing: 10) {
                        SkeletonPhoto(width: 82, height: 40, radius: 20)
                        SkeletonColumn(spacing: 2) {
                            SkeletonLine(.custom(16), width: 96)
                            SkeletonLine(.caption, width: 128)
                        }
                        SkeletonSpacer()
                        SkeletonBlock(height: 28, width: 88, radius: 15)
                    }
                    SkeletonRow(spacing: 4, distribution: .fillEqually) {
                        SkeletonBlock(height: 5, radius: 2.5)
                        SkeletonBlock(height: 5, radius: 2.5)
                        SkeletonBlock(height: 5, radius: 2.5)
                        SkeletonBlock(height: 5, radius: 2.5)
                        SkeletonBlock(height: 5, radius: 2.5)
                    }
                    SkeletonLine(.caption, width: 136)
                    SkeletonReal(UIView())
                    SkeletonRow(spacing: 16) {
                        SkeletonColumn(spacing: 2) {
                            SkeletonLine(.custom(12), width: 48)
                            SkeletonLine(.custom(14), width: 104)
                        }
                        SkeletonColumn(spacing: 2) {
                            SkeletonLine(.custom(12), width: 32)
                            SkeletonLine(.custom(14), width: 72)
                        }
                    }
                }
            }
        }.makeView()

        let all = blocks(in: layout)
        let placed = places(of: all)
        // 14 blocks a card, three cards, three components.
        #expect(all.count == 42)
        #expect(Set(placed.map(\.count)) == [3])
        #expect(Set(placed.map(\.ordinal)) == [0, 1, 2])
        #expect(placed.prefix(14).allSatisfy { $0.ordinal == 0 })
        #expect(placed.dropFirst(14).prefix(14).allSatisfy { $0.ordinal == 1 })
        #expect(placed.suffix(14).allSatisfy { $0.ordinal == 2 })
    }

    /// A piece the response does not fill — the wardrobe's real banner and search box — takes no
    /// place, so the first block on screen still starts the wave.
    @Test func aRealWrapperWithNoBlocksTakesNoPlace() {
        let chips = SkeletonRow(spacing: 8) {
            SkeletonBlock(height: 40, width: 86, radius: 20)
            SkeletonBlock(height: 40, width: 112, radius: 20)
            SkeletonBlock(height: 40, width: 120, radius: 20)
            SkeletonSpacer()
        }.makeView()
        let rows = SkeletonRows(count: 3, spacing: 12) {
            SkeletonBlock(height: 116, radius: 18)
        }.makeView()

        let layout = SkeletonLayout(spacing: 0) {
            SkeletonReal(UILabel())
            SkeletonReal(chips)
            SkeletonReal(UILabel())
            SkeletonReal(rows)
        }.makeView()

        let all = blocks(in: layout)
        #expect(all.count == 6)
        #expect(places(of: all).map(\.ordinal) == [0, 0, 0, 1, 2, 3])
        #expect(places(of: all).map(\.count) == [4, 4, 4, 4, 4, 4])
    }

    /// A block keeps its own place while an unrelated block comes and goes.
    @Test func aBlockKeepsItsPlaceWhileAnotherComesAndGoes() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let first = SkeletonView.block(height: 40)
        let second = SkeletonView.block(height: 40)
        for (view, offset) in [(first, 0.0), (second, 100.0)] {
            view.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: window.topAnchor, constant: offset),
                view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
                view.widthAnchor.constraint(equalToConstant: 200),
            ])
        }
        window.layoutIfNeeded()

        #expect(SweepOrder.place(of: first).ordinal == 0)
        #expect(SweepOrder.place(of: second).ordinal == 1)

        second.isHidden = true
        #expect(SweepOrder.place(of: first).ordinal == 0)

        second.isHidden = false
        window.layoutIfNeeded()
        #expect(SweepOrder.place(of: first).ordinal == 0)
        #expect(SweepOrder.place(of: second).ordinal == 1)
    }

    /// Two blocks in a window cross one stagger apart, and each keeps its own place when the other
    /// leaves.
    @Test func twoComponentsInAWindowSweepOneStaggerApart() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let theme = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(shimmerStagger: 0.15)
        defer { SkeletonTheme.current = theme }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let first = SkeletonView.block(height: 40)
        let second = SkeletonView.block(height: 40)
        for (view, offset) in [(first, 0.0), (second, 100.0)] {
            view.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: window.topAnchor, constant: offset),
                view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
                view.widthAnchor.constraint(equalToConstant: 200),
            ])
        }
        window.layoutIfNeeded()

        let a = try #require((first.activeSweep as? CAKeyframeAnimation)?.beginTime)
        let b = try #require((second.activeSweep as? CAKeyframeAnimation)?.beginTime)
        let period = ShimmerTimeline.period(pass: pass, rest: 0.25, components: 2, stagger: 0.15)
        let delta = b - a
        let wrapped = delta - (delta / period).rounded() * period
        #expect(abs(abs(wrapped) - 0.15) < 0.01)
    }

    /// A stored place does not change when the block's geometry changes under it.
    @Test func aBlocksPlaceDoesNotMoveUnderIt() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        let layout = SkeletonLayout(spacing: 10) {
            SkeletonCard(padding: 12) { SkeletonLine(.body) }
            SkeletonCard(padding: 12) { SkeletonLine(.body) }
        }.makeView()
        layout.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.topAnchor.constraint(equalTo: window.topAnchor),
            layout.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            layout.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])
        window.layoutIfNeeded()

        let all = blocks(in: layout)
        let before = places(of: all)
        layout.layoutIfNeeded()
        let after = places(of: all)
        #expect(before.map(\.ordinal) == after.map(\.ordinal))
        #expect(before.map(\.count) == after.map(\.count))
    }

    // MARK: - Helpers

    private func blocks(in view: UIView) -> [SkeletonView] {
        var found: [SkeletonView] = []
        if let block = view as? SkeletonView { found.append(block) }
        for subview in view.subviews {
            found.append(contentsOf: blocks(in: subview))
        }
        return found
    }

    private func places(of blocks: [SkeletonView]) -> [SweepOrder.Place] {
        blocks.map { SweepOrder.place(of: $0) }
    }
}
