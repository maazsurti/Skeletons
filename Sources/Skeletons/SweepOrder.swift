import UIKit

/// The ordinals of the sweep on screen. Every placeholder that is live takes the next place in
/// reading order, and a fused run of lines takes one place however many blocks draw it.
@MainActor
enum SweepOrder {

    private static var live: [SkeletonView] = []
    private static var isRenumbering = false

    /// The ordinal of the group `view` draws with: its rank among the groups on screen, top to
    /// bottom and then leading to trailing.
    static func ordinal(of view: SkeletonView) -> Int {
        groups().firstIndex { $0 === view.sweepRoot } ?? 0
    }

    /// Adds a placeholder to the wave and tells the blocks already in it to take their new phase.
    static func register(_ view: SkeletonView) {
        live.removeAll { $0.window == nil }
        guard !live.contains(where: { $0 === view }) else { return }
        live.append(view)
        renumber()
    }

    static func unregister(_ view: SkeletonView) {
        let before = live.count
        live.removeAll { $0 === view || $0.window == nil }
        guard live.count != before else { return }
        renumber()
    }

    /// The one block of each group, in reading order.
    private static func groups() -> [SkeletonView] {
        var seen = Set<ObjectIdentifier>()
        var roots: [SkeletonView] = []
        for view in live where view.isSweeping {
            let root = view.sweepRoot
            if seen.insert(ObjectIdentifier(root)).inserted {
                roots.append(root)
            }
        }
        return roots.sorted(by: precedes)
    }

    private static func precedes(_ first: SkeletonView, _ second: SkeletonView) -> Bool {
        guard let window = first.window else { return false }
        let a = first.convert(first.bounds, to: window)
        let b = second.convert(second.bounds, to: window)
        if abs(a.minY - b.minY) > 0.5 { return a.minY < b.minY }
        let isRightToLeft = SkeletonTheme.current.isRightToLeft()
        return isRightToLeft ? a.maxX > b.maxX : a.minX < b.minX
    }

    private static func renumber() {
        guard !isRenumbering else { return }
        isRenumbering = true
        defer { isRenumbering = false }
        for view in live {
            view.sweepGroupDidMove()
        }
    }
}
