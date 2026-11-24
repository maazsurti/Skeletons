import UIKit
import ObjectiveC

/// The place each component takes in its screen's wave. A component is one piece the eye reads as
/// a whole — a card, a row, a field, a section — and every block inside it shares that place, so a
/// card's blocks cross together instead of drawing a diagonal inside the card.
///
/// The layout builder marks the pieces it lays out: every direct child of a `SkeletonLayout` and
/// every copy of a `SkeletonRows`. A component's place is its document order among the components
/// that hold a block of their own, so a real banner or a heading that is already text takes no
/// place and the topmost block on screen is always first.
@MainActor
enum SweepOrder {

    /// Where a block sits in its screen's wave.
    struct Place {
        /// The component's rank, 0 for the topmost component on screen.
        let ordinal: Int
        /// How many components the screen's wave crosses.
        let count: Int
        /// The instant the screen's wave starts.
        let start: CFTimeInterval
    }

    // MARK: - Marking

    /// Marks `view` as one component of the screen it is built for.
    static func markComponent(_ view: UIView) {
        view.skeletonComponentRoot = true
    }

    /// Gives every component inside `container` its place in document order. A screen built by
    /// hand, with no marked pieces, takes each child of its content as one component.
    static func placeComponents(in container: UIView) {
        guard container.skeletonComponentCount == nil else { return }
        let content = container.subviews.first ?? container
        var roots: [UIView] = []
        collectComponents(in: content, into: &roots)
        if roots.isEmpty {
            roots = content.subviews.isEmpty ? [content] : content.subviews
        }
        let placed = roots.filter(holdsBlocks)
        for (index, root) in placed.enumerated() {
            root.skeletonOrdinal = index
        }
        container.skeletonComponentCount = placed.count
    }

    // MARK: - Looking a place up

    /// The place `view` takes in its screen's wave, read once and kept for as long as the block
    /// stays on screen, so a scroll, a re-register or a relayout cannot move it.
    static func place(of view: SkeletonView) -> Place {
        if let cached = view.sweepPlace { return cached }
        let place = resolve(view)
        view.sweepPlace = place
        return place
    }

    /// The piece `view` draws for: the nearest marked component, or the block itself when the
    /// screen places blocks by hand. The blocks of one component share a phase, so they also share
    /// one slanted band.
    static func component(of view: SkeletonView) -> UIView {
        var candidate: UIView? = view
        while let current = candidate {
            if current.skeletonOrdinal != nil { return current }
            candidate = current.superview
        }
        return view
    }

    private static func resolve(_ view: SkeletonView) -> Place {
        var candidate: UIView? = view
        while let current = candidate {
            if let ordinal = current.skeletonOrdinal {
                let container = container(above: current)
                return Place(
                    ordinal: ordinal,
                    count: max(container?.skeletonComponentCount ?? 1, 1),
                    start: start(of: container)
                )
            }
            candidate = current.superview
        }
        return loose(view)
    }

    /// The view that states how many components the screen a component sits in sweeps.
    private static func container(above component: UIView) -> UIView? {
        var candidate: UIView? = component
        while let current = candidate {
            if current.skeletonComponentCount != nil { return current }
            candidate = current.superview
        }
        return nil
    }

    /// The instant a container's wave starts, set by the first block that asks while the container
    /// has none, so every block in it shares one start.
    private static func start(of container: UIView?) -> CFTimeInterval {
        guard let container else { return CACurrentMediaTime() }
        if let start = container.skeletonSweepStart { return start }
        let start = CACurrentMediaTime()
        container.skeletonSweepStart = start
        return start
    }

    // MARK: - Blocks placed by hand

    /// A block whose screen has no container takes the next place in its window's group, once, in
    /// reading order, so its phase stays put while it is on screen.
    private static func loose(_ view: SkeletonView) -> Place {
        guard let window = view.window else {
            return Place(ordinal: 0, count: 1, start: CACurrentMediaTime())
        }
        let group = group(for: window)
        view.looseGroup = group
        let start = group.start ?? CACurrentMediaTime()
        group.start = start
        let existing = group.ledger.index(of: view)
        if existing != NSNotFound {
            return Place(ordinal: existing, count: max(group.ledger.count, 1), start: start)
        }
        let index = insertionIndex(of: view, in: group.ledger)
        group.ledger.insert(view, at: index)
        for later in group.ledger.dropFirst(index + 1) {
            guard let block = later as? SkeletonView else { continue }
            block.sweepPlace = nil
            block.rephase()
        }
        return Place(ordinal: index, count: max(group.ledger.count, 1), start: start)
    }

    /// Takes `view` out of its window's group once it stops, and drops the group with its clock when
    /// no block left in it is still sweeping, so the next screen starts at the first place on a
    /// fresh start.
    static func leftTheWave(_ view: SkeletonView) {
        guard let group = view.looseGroup, group.ledger.index(of: view) != NSNotFound else {
            return
        }
        group.ledger.remove(view)
        view.looseGroup = nil
        guard !group.ledger.contains(where: { ($0 as? SkeletonView)?.isSweeping == true }) else {
            return
        }
        if let window = group.window { looseByWindow.removeObject(forKey: window) }
        group.ledger.removeAllObjects()
    }

    private static func group(for window: UIWindow) -> LooseSweepGroup {
        if let group = looseByWindow.object(forKey: window) { return group }
        let group = LooseSweepGroup()
        group.window = window
        looseByWindow.setObject(group, forKey: window)
        return group
    }

    private static func insertionIndex(of view: SkeletonView, in ledger: NSMutableArray) -> Int {
        guard let window = view.window else { return ledger.count }
        let frame = view.convert(view.bounds, to: window)
        for (index, other) in (ledger as? [SkeletonView] ?? []).enumerated() {
            guard let otherWindow = other.window else { continue }
            let otherFrame = other.convert(other.bounds, to: otherWindow)
            let before = abs(otherFrame.minY - frame.minY) > 0.5
                ? otherFrame.minY > frame.minY
                : otherFrame.minX > frame.minX
            if before { return index }
        }
        return ledger.count
    }

    private static let looseByWindow = NSMapTable<UIWindow, LooseSweepGroup>(
        keyOptions: .weakMemory,
        valueOptions: .strongMemory
    )

    // MARK: - Document order

    private static func collectComponents(in view: UIView, into roots: inout [UIView]) {
        if view.skeletonComponentRoot {
            roots.append(view)
        }
        for subview in view.subviews {
            collectComponents(in: subview, into: &roots)
        }
    }

    /// Whether this component holds a block of its own, rather than only the blocks of the
    /// components nested inside it.
    private static func holdsBlocks(_ root: UIView) -> Bool {
        if root is SkeletonView { return true }
        for subview in root.subviews {
            if subview.skeletonComponentRoot { continue }
            if subview is SkeletonView { return true }
            if holdsBlocks(subview) { return true }
        }
        return false
    }
}

// MARK: - Storage on the view tree

/// The blocks one window places by hand, and the instant their wave starts.
final class LooseSweepGroup {
    let ledger = NSMutableArray()
    weak var window: UIWindow?
    var start: CFTimeInterval?
}

extension UIView {

    /// Whether this view is one component of its screen.
    fileprivate var skeletonComponentRoot: Bool {
        get { skeletonComponentRootBox?.boolValue ?? false }
        set { skeletonComponentRootBox = newValue ? true : nil }
    }

    /// This component's place in document order, once its screen has placed it.
    var skeletonOrdinal: Int? {
        get { skeletonOrdinalBox?.intValue }
        set { skeletonOrdinalBox = newValue.map { NSNumber(value: $0) } }
    }

    /// How many components the screen inside this container sweeps.
    var skeletonComponentCount: Int? {
        get { skeletonComponentCountBox?.intValue }
        set { skeletonComponentCountBox = newValue.map { NSNumber(value: $0) } }
    }

    /// The instant the wave of the screen inside this container starts.
    var skeletonSweepStart: CFTimeInterval? {
        get { skeletonSweepStartBox?.doubleValue }
        set { skeletonSweepStartBox = newValue.map { NSNumber(value: $0) } }
    }

    private var skeletonComponentRootBox: NSNumber? {
        get { objc_getAssociatedObject(self, &SweepAssociation.componentRoot) as? NSNumber }
        set { objc_setAssociatedObject(self, &SweepAssociation.componentRoot, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var skeletonOrdinalBox: NSNumber? {
        get { objc_getAssociatedObject(self, &SweepAssociation.ordinal) as? NSNumber }
        set { objc_setAssociatedObject(self, &SweepAssociation.ordinal, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var skeletonComponentCountBox: NSNumber? {
        get { objc_getAssociatedObject(self, &SweepAssociation.count) as? NSNumber }
        set { objc_setAssociatedObject(self, &SweepAssociation.count, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var skeletonSweepStartBox: NSNumber? {
        get { objc_getAssociatedObject(self, &SweepAssociation.sweepStart) as? NSNumber }
        set { objc_setAssociatedObject(self, &SweepAssociation.sweepStart, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private enum SweepAssociation {
    nonisolated(unsafe) static var componentRoot: UInt8 = 0
    nonisolated(unsafe) static var ordinal: UInt8 = 0
    nonisolated(unsafe) static var count: UInt8 = 0
    nonisolated(unsafe) static var sweepStart: UInt8 = 0
}
