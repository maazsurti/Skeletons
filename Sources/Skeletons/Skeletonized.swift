import UIKit
import ObjectiveC

/// How a real view becomes a placeholder: the automatic rules, one block for the whole view, the
/// real view kept as it is, or the view's space kept with nothing in it.
public enum SkeletonMode {
    case automatic
    case block
    case `static`
    case ignored
}

public extension UIView {

    /// The mode this view states for itself. Nil inherits from the walk.
    var skeletonMode: SkeletonMode? {
        get { skeletonModeBox.flatMap(SkeletonMode.init(storedValue:)) }
        set { skeletonModeBox = newValue?.storedValue }
    }

    /// States this view's mode and returns it.
    @discardableResult
    func skeletonMode(_ mode: SkeletonMode) -> Self {
        skeletonMode = mode
        return self
    }

    /// A skeleton in this view's own geometry, ready to place where the content goes. The view is
    /// filled with sample data; the returned container reads that layout and stands in for it.
    ///
    /// - Parameters:
    ///   - only: the views to skeletonize. Anything else is left real.
    ///   - keeping: views left real, in place.
    ///   - ignoring: views that keep their space and show nothing.
    func skeletonized(
        only: [UIView] = [],
        keeping: [UIView] = [],
        ignoring: [UIView] = []
    ) -> SkeletonContainerView {
        let content = Skeletonizer.prepare(self, lists: Skeletonizer.Lists(only: only, keeping: keeping, ignoring: ignoring))
        return SkeletonContainerView(content: content)
    }
}

/// A real view built at the call site, skeletonized by the automatic rules, for use inside a
/// `SkeletonLayout` or any other element tree.
@MainActor
public struct Skeletonized: SkeletonElement {
    private let make: () -> UIView

    public init(_ make: @escaping () -> UIView) {
        self.make = make
    }

    public func makeView() -> UIView {
        Skeletonizer.prepare(make(), lists: Skeletonizer.Lists(only: [], keeping: [], ignoring: []))
    }
}

// MARK: - The walk

@MainActor
enum Skeletonizer {

    struct Lists {
        let only: [UIView]
        let keeping: [UIView]
        let ignoring: [UIView]
    }

    static func prepare(_ root: UIView, lists: Lists) -> UIView {
        let host = SkeletonizedHostView()
        root.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: host.topAnchor),
            root.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        walk(root, lists: lists, automatic: lists.only.isEmpty, inScope: lists.only.isEmpty)
        markComponents(in: host)
        return host
    }

    private static func walk(_ view: UIView, lists: Lists, automatic: Bool, inScope: Bool) {
        let scope = inScope || lists.only.contains(view)
        let applies = automatic || lists.only.contains(view)
        switch mode(of: view, lists: lists, inScope: scope) {
        case .ignored:
            view.alpha = 0
        case .block:
            view.alpha = 0
            overlay(view)
        case .static:
            view.skeletonKeptStatic = true
            descend(view, lists: lists, automatic: false, inScope: scope)
        case .automatic:
            rules(view, lists: lists, inScope: scope)
        case nil:
            if !lists.only.isEmpty && !scope {
                view.skeletonKeptStatic = true
                descend(view, lists: lists, automatic: false, inScope: scope)
            } else if applies {
                rules(view, lists: lists, inScope: scope)
            } else {
                descend(view, lists: lists, automatic: false, inScope: scope)
            }
        }
    }

    private static func mode(of view: UIView, lists: Lists, inScope: Bool) -> SkeletonMode? {
        if lists.ignoring.contains(view) { return .ignored }
        if lists.keeping.contains(view) { return .static }
        if let stated = view.skeletonMode { return stated }
        if !lists.only.isEmpty && !inScope { return .static }
        return nil
    }

    // MARK: - Rules

    private static func rules(_ view: UIView, lists: Lists, inScope: Bool) {
        if view.isHidden || view.alpha == 0 { return }
        if view is SkeletonView { return }

        if let label = view as? UILabel {
            blockOut(label)
            return
        }

        if let stack = view as? UIStackView, isTextStack(stack) {
            stack.alpha = 0
            overlay(stack)
            return
        }

        if let image = view as? UIImageView {
            image.alpha = 0
            overlay(image, radius: image.layer.cornerRadius, corners: image.layer.maskedCorners)
            return
        }

        if let field = view as? UITextField {
            field.text = nil
            field.placeholder = nil
            shimmerValue(in: field, font: field.font)
            return
        }

        if let text = view as? UITextView {
            text.text = ""
            shimmerValue(in: text, font: text.font)
            return
        }

        if view is UIControl {
            view.alpha = 0
            overlay(view)
            return
        }

        if isThinSeparator(view) { return }

        if let effect = view as? UIVisualEffectView {
            walk(effect.contentView, lists: lists, automatic: true, inScope: inScope)
            return
        }

        if view is UIScrollView {
            descend(view, lists: lists, automatic: true, inScope: inScope)
            return
        }

        if hasChrome(view) {
            if contentLeafCount(view) > 1 && !hasFixedSize(view) {
                descend(view, lists: lists, automatic: true, inScope: inScope)
            } else {
                view.alpha = 0
                overlay(view)
            }
            return
        }

        if view.subviews.isEmpty {
            if isDrawn(view) {
                view.alpha = 0
                overlay(view)
            }
            return
        }

        descend(view, lists: lists, automatic: true, inScope: inScope)
    }

    private static func descend(_ view: UIView, lists: Lists, automatic: Bool, inScope: Bool) {
        for subview in view.subviews where !isPrivate(subview) {
            walk(subview, lists: lists, automatic: automatic, inScope: inScope)
        }
    }

    // MARK: - Blocks

    private static func blockOut(_ label: UILabel) {
        label.alpha = 0

        guard label.numberOfLines == 1 else {
            overlay(label)
            return
        }

        if label.text?.isEmpty != false && label.attributedText == nil {
            label.text = "\u{00A0}"
        }

        let size = label.intrinsicContentSize
        guard let host = label.superview else { return }
        let block = SkeletonView(cornerRadius: label.font.pointSize / 2)
        block.translatesAutoresizingMaskIntoConstraints = false
        host.insertSubview(block, aboveSubview: label)

        let width = block.widthAnchor.constraint(equalToConstant: size.width)
        width.priority = UILayoutPriority(999)
        let height = block.heightAnchor.constraint(equalToConstant: size.height)
        height.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            width,
            height,
            block.widthAnchor.constraint(lessThanOrEqualTo: label.widthAnchor),
            block.heightAnchor.constraint(lessThanOrEqualTo: label.heightAnchor),
            block.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            alignment(of: label, block: block),
        ])
    }

    private static func alignment(of label: UILabel, block: SkeletonView) -> NSLayoutConstraint {
        switch label.textAlignment {
        case .left:
            return block.leftAnchor.constraint(equalTo: label.leftAnchor)
        case .right:
            return block.rightAnchor.constraint(equalTo: label.rightAnchor)
        case .center:
            return block.centerXAnchor.constraint(equalTo: label.centerXAnchor)
        default:
            return block.leadingAnchor.constraint(equalTo: label.leadingAnchor)
        }
    }

    @discardableResult
    private static func overlay(
        _ view: UIView,
        radius: CGFloat? = nil,
        corners: CACornerMask = .skeletonAllCorners
    ) -> SkeletonView {
        let block = SkeletonView(cornerRadius: radius ?? view.layer.cornerRadius, corners: corners)
        guard let host = view.superview else { return block }
        block.translatesAutoresizingMaskIntoConstraints = false
        host.insertSubview(block, aboveSubview: view)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: view.topAnchor),
            block.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            block.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            block.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return block
    }

    private static func shimmerValue(in field: UIView, font: UIFont?) {
        let theme = SkeletonTheme.current
        let height = theme.lineHeight(font?.pointSize ?? theme.fieldTextFont.pointSize)
        let line = SkeletonView.line(height: height, radius: height / 2)
        line.translatesAutoresizingMaskIntoConstraints = false
        field.addSubview(line)
        let width = line.widthAnchor.constraint(equalTo: field.widthAnchor, multiplier: 0.55)
        width.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: theme.fieldPadding),
            line.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            line.trailingAnchor.constraint(lessThanOrEqualTo: field.trailingAnchor, constant: -theme.fieldPadding),
            width,
        ])
    }

    // MARK: - Reading the view

    private static func isTextStack(_ stack: UIStackView) -> Bool {
        guard stack.axis == .vertical, stack.spacing == 0, !stack.arrangedSubviews.isEmpty else {
            return false
        }
        return stack.arrangedSubviews.allSatisfy { $0 is UILabel && !$0.isHidden && $0.alpha > 0 }
    }

    private static func hasChrome(_ view: UIView) -> Bool {
        if let background = view.backgroundColor, background.cgColor.alpha > 0 { return true }
        if view.layer.borderWidth > 0 { return true }
        return view.layer.shadowOpacity > 0
    }

    private static func isDrawn(_ view: UIView) -> Bool {
        if hasChrome(view) { return true }
        if !(view.layer.sublayers ?? []).isEmpty { return true }
        return isCustomType(view)
    }

    private static func isCustomType(_ view: UIView) -> Bool {
        let name = NSStringFromClass(type(of: view))
        return !name.hasPrefix("UI") && !name.hasPrefix("_")
    }

    private static func isPrivate(_ view: UIView) -> Bool {
        NSStringFromClass(type(of: view)).hasPrefix("_")
    }

    private static func contentLeafCount(_ view: UIView) -> Int {
        if view.isHidden || view.alpha == 0 { return 0 }
        if view is SkeletonView { return 0 }
        if view is UILabel || view is UIImageView || view is UIControl { return 1 }
        if view.subviews.isEmpty { return isDrawn(view) ? 1 : 0 }
        return view.subviews.reduce(0) { $0 + contentLeafCount($1) }
    }

    private static func hasFixedSize(_ view: UIView) -> Bool {
        var width = false
        var height = false
        for constraint in view.constraints where isOwnFixed(constraint, of: view) {
            if constraint.firstAttribute == .width { width = true }
            if constraint.firstAttribute == .height { height = true }
        }
        return width && height
    }

    private static func isThinSeparator(_ view: UIView) -> Bool {
        view.constraints.contains { constraint in
            guard isOwnFixed(constraint, of: view), constraint.constant > 0, constraint.constant <= 2 else {
                return false
            }
            return constraint.firstAttribute == .height || constraint.firstAttribute == .width
        }
    }

    private static func isOwnFixed(_ constraint: NSLayoutConstraint, of view: UIView) -> Bool {
        constraint.firstItem === view
            && constraint.secondItem == nil
            && constraint.relation == .equal
            && constraint.multiplier == 1
    }

    // MARK: - Sweep

    private static func markComponents(in host: UIView) {
        guard let root = host.subviews.first(where: { !($0 is SkeletonView) }) else { return }
        let rows = root.subviews.filter(containsBlock)
        if rows.isEmpty {
            if containsBlock(root) { SweepOrder.markComponent(root) }
            return
        }
        for row in rows {
            SweepOrder.markComponent(row)
        }
    }

    private static func containsBlock(_ view: UIView) -> Bool {
        if view is SkeletonView { return true }
        return view.subviews.contains(where: containsBlock)
    }
}

// MARK: - Touches

/// The wrapper the skeletonized tree hangs from. Only a view inside a subtree the caller kept
/// static receives a touch, so a template's gestures never fire on sample data.
@MainActor
final class SkeletonizedHostView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        var candidate: UIView? = hit
        while let view = candidate, view !== self {
            if view.skeletonKeptStatic { return hit }
            candidate = view.superview
        }
        return nil
    }
}

// MARK: - Storage on the view tree

private extension SkeletonMode {
    var storedValue: UInt8 {
        switch self {
        case .automatic: return 0
        case .block: return 1
        case .static: return 2
        case .ignored: return 3
        }
    }

    init?(storedValue: UInt8) {
        switch storedValue {
        case 0: self = .automatic
        case 1: self = .block
        case 2: self = .static
        case 3: self = .ignored
        default: return nil
        }
    }
}

extension UIView {
    fileprivate var skeletonModeBox: UInt8? {
        get { (objc_getAssociatedObject(self, &SkeletonizedAssociation.mode) as? NSNumber)?.uint8Value }
        set { objc_setAssociatedObject(self, &SkeletonizedAssociation.mode, newValue.map { NSNumber(value: $0) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var skeletonKeptStatic: Bool {
        get { (objc_getAssociatedObject(self, &SkeletonizedAssociation.keptStatic) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &SkeletonizedAssociation.keptStatic, newValue ? NSNumber(value: true) : nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private enum SkeletonizedAssociation {
    nonisolated(unsafe) static var mode: UInt8 = 0
    nonisolated(unsafe) static var keptStatic: UInt8 = 0
}
