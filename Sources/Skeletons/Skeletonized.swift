import UIKit
import ObjectiveC

public enum SkeletonMode: Int {
    case automatic = 0
    case block = 1
    case `static` = 2
    case ignored = 3
}

public extension UIView {

    var skeletonMode: SkeletonMode? {
        get {
            (objc_getAssociatedObject(self, &SkeletonizedAssociation.mode) as? NSNumber)
                .flatMap { SkeletonMode(rawValue: $0.intValue) }
        }
        set {
            objc_setAssociatedObject(
                self,
                &SkeletonizedAssociation.mode,
                newValue.map { NSNumber(value: $0.rawValue) },
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    @discardableResult
    func skeletonMode(_ mode: SkeletonMode) -> Self {
        skeletonMode = mode
        return self
    }

    func skeletonized(
        only: [UIView] = [],
        keeping: [UIView] = [],
        ignoring: [UIView] = []
    ) -> SkeletonContainerView {
        let lists = Skeletonizer.Lists(only: only, keeping: keeping, ignoring: ignoring)
        return SkeletonContainerView(content: Skeletonizer.prepare(self, lists: lists, marking: true))
    }
}

@MainActor
public struct Skeletonized: SkeletonElement {
    private let make: () -> UIView

    public init(_ make: @escaping () -> UIView) {
        self.make = make
    }

    public func makeView() -> UIView {
        let lists = Skeletonizer.Lists(only: [], keeping: [], ignoring: [])
        return Skeletonizer.prepare(make(), lists: lists, marking: false)
    }
}

@MainActor
enum Skeletonizer {

    struct Lists {
        let only: [UIView]
        let keeping: [UIView]
        let ignoring: [UIView]
    }

    static func prepare(_ root: UIView, lists: Lists, marking: Bool) -> UIView {
        let host = SkeletonizedHostView()
        root.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: host.topAnchor),
            root.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        walk(root, lists: lists, inherited: lists.only.isEmpty ? .automatic : .static)
        if marking { mark(host) }
        return host
    }

    private static func walk(_ view: UIView, lists: Lists, inherited: SkeletonMode) {
        if view.isHidden || view.alpha == 0 { return }
        let mode = mode(of: view, lists: lists, inherited: inherited)
        view.skeletonTouchable = mode == .static
        switch mode {
        case .ignored:
            view.alpha = 0
        case .block:
            view.alpha = 0
            overlay(view)
        case .static:
            descend(view, lists: lists, inherited: .static)
        case .automatic:
            if !(view is UIScrollView) {
                view.gestureRecognizers?.forEach(view.removeGestureRecognizer)
            }
            rules(view, lists: lists)
        }
    }

    private static func mode(of view: UIView, lists: Lists, inherited: SkeletonMode) -> SkeletonMode {
        if lists.ignoring.contains(view) { return .ignored }
        if lists.keeping.contains(view) { return .static }
        if lists.only.contains(view) { return .automatic }
        if let stated = view.skeletonMode { return stated }
        return inherited
    }

    private static func descend(_ view: UIView, lists: Lists, inherited: SkeletonMode) {
        for subview in view.subviews where !isPrivate(subview) {
            walk(subview, lists: lists, inherited: inherited)
        }
    }

    private static func rules(_ view: UIView, lists: Lists) {
        if view is SkeletonView { return }
        if view is UISearchTextField || view is UISearchBar { return }

        if let label = view as? UILabel {
            blockOut(label, lists: lists)
            return
        }

        if let stack = view as? UIStackView, isTextStack(stack) {
            let first = stack.arrangedSubviews.first as? UILabel
            collapse(stack, lists: lists, textRadius: first.map { $0.font.pointSize / 2 })
            return
        }

        if let image = view as? UIImageView {
            collapse(image, lists: lists)
            return
        }

        if let field = view as? UITextField {
            field.text = nil
            field.placeholder = nil
            shimmerValue(in: field, font: field.font)
            return
        }

        if let text = view as? UITextView {
            if text.isEditable {
                text.textColor = .clear
                shimmerValue(in: text, font: text.font)
            } else {
                let size = text.font?.pointSize ?? SkeletonTheme.current.fieldTextFont.pointSize
                collapse(text, lists: lists, textRadius: size / 2)
            }
            return
        }

        if let control = view as? UIControl, !isTappableCard(control) {
            collapse(control, lists: lists, textRadius: textRadius(of: control))
            return
        }

        if isThinSeparator(view) { return }

        if let effect = view as? UIVisualEffectView {
            walk(effect.contentView, lists: lists, inherited: .automatic)
            return
        }

        if view is UIScrollView {
            descend(view, lists: lists, inherited: .automatic)
            return
        }

        if hasChrome(view) {
            if contentsLeafCount(view) > 1 && !hasFixedSize(view) {
                descend(view, lists: lists, inherited: .automatic)
            } else {
                collapse(view, lists: lists)
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

        descend(view, lists: lists, inherited: .automatic)
    }

    private static func collapse(_ view: UIView, lists: Lists, textRadius: CGFloat? = nil) {
        guard !holdsKeptView(view, lists: lists) else {
            descend(view, lists: lists, inherited: .automatic)
            return
        }
        view.alpha = 0
        overlay(view, textRadius: textRadius)
    }

    private static func holdsKeptView(_ view: UIView, lists: Lists) -> Bool {
        view.subviews.contains { isKept($0, lists: lists) }
    }

    private static func isKept(_ view: UIView, lists: Lists) -> Bool {
        if view.isHidden || view.alpha == 0 { return false }
        if lists.ignoring.contains(view) { return true }
        if lists.keeping.contains(view) { return true }
        if lists.only.contains(view) { return true }
        if view.skeletonMode != nil { return true }
        return view.subviews.contains { isKept($0, lists: lists) }
    }

    private static func blockOut(_ label: UILabel, lists: Lists) {
        if label.text?.isEmpty ?? true {
            label.text = String(repeating: "\u{00A0}", count: 12)
        }

        guard label.numberOfLines == 1 else {
            collapse(label, lists: lists, textRadius: label.font.pointSize / 2)
            return
        }

        guard !holdsKeptView(label, lists: lists) else {
            descend(label, lists: lists, inherited: .automatic)
            return
        }

        label.alpha = 0
        guard let host = label.superview else { return }

        let size = label.intrinsicContentSize
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

    private static func overlay(_ view: UIView, textRadius: CGFloat? = nil) {
        let block: SkeletonView
        if let textRadius {
            block = SkeletonView(cornerRadius: textRadius)
        } else {
            block = SkeletonView(cornerRadius: view.layer.cornerRadius, corners: view.layer.maskedCorners)
            block.cornerSource = view
        }
        guard let host = view.superview else { return }
        block.translatesAutoresizingMaskIntoConstraints = false
        host.insertSubview(block, aboveSubview: view)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: view.topAnchor),
            block.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            block.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            block.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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

    private static func isTextStack(_ stack: UIStackView) -> Bool {
        guard stack.axis == .vertical, stack.spacing == 0, !stack.arrangedSubviews.isEmpty else {
            return false
        }
        guard stack.arrangedSubviews.allSatisfy({ $0 is UILabel && !$0.isHidden && $0.alpha > 0 }) else {
            return false
        }
        return !stack.arrangedSubviews.contains { arranged in
            let spacing = stack.customSpacing(after: arranged)
            return spacing != 0 && spacing != CGFloat(Float.greatestFiniteMagnitude)
        }
    }

    private static func textRadius(of control: UIControl) -> CGFloat? {
        guard let button = control as? UIButton, button.layer.cornerRadius == 0, !hasChrome(button) else {
            return nil
        }
        let size = button.titleLabel?.font.pointSize ?? SkeletonTheme.current.fieldTextFont.pointSize
        return size / 2
    }

    private static func isTappableCard(_ control: UIControl) -> Bool {
        guard nearestSystemClass(type(of: control)) == UIControl.self else { return false }
        return contentsLeafCount(control) > 1
    }

    private static func hasChrome(_ view: UIView) -> Bool {
        if let background = view.backgroundColor, background.cgColor.alpha > 0 { return true }
        if view.layer.borderWidth > 0 { return true }
        return view.layer.shadowOpacity > 0
    }

    private static func isCard(_ view: UIView) -> Bool {
        if view.layer.borderWidth > 0 { return true }
        if view.layer.shadowOpacity > 0 { return true }
        guard let background = view.backgroundColor, background.cgColor.alpha > 0 else { return false }
        return view.layer.cornerRadius > 0
    }

    private static func isDrawn(_ view: UIView) -> Bool {
        if hasChrome(view) { return true }
        if !(view.layer.sublayers ?? []).isEmpty { return true }
        return isCustom(view)
    }

    private static func isSystemClass(_ type: AnyClass) -> Bool {
        Bundle(for: type).bundleURL == Bundle(for: UIView.self).bundleURL
    }

    private static func isSystem(_ view: UIView) -> Bool {
        isSystemClass(type(of: view))
    }

    private static func isPrivate(_ view: UIView) -> Bool {
        isSystem(view) && NSStringFromClass(type(of: view)).hasPrefix("_")
    }

    private static func isCustom(_ view: UIView) -> Bool {
        !isSystem(view)
    }

    private static func nearestSystemClass(_ type: AnyClass) -> AnyClass? {
        var current: AnyClass? = type
        while let candidate = current {
            if isSystemClass(candidate) { return candidate }
            current = class_getSuperclass(candidate)
        }
        return nil
    }

    private static func contentsLeafCount(_ view: UIView) -> Int {
        view.subviews.reduce(0) { $0 + (isPrivate($1) ? 0 : contentLeafCount($1)) }
    }

    private static func contentLeafCount(_ view: UIView) -> Int {
        if view.isHidden || view.alpha == 0 { return 0 }
        if view is SkeletonView { return 0 }
        if view is UILabel || view is UIImageView || view is UIControl || view is UITextView { return 1 }
        if let effect = view as? UIVisualEffectView { return contentLeafCount(effect.contentView) }
        if view.subviews.isEmpty { return isDrawn(view) ? 1 : 0 }
        return contentsLeafCount(view)
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

    static func mark(_ view: UIView) {
        guard containsBlock(view) else { return }
        if view is SkeletonView || isCard(view) {
            SweepOrder.markComponent(view)
            return
        }
        let kids = view.subviews.filter(containsBlock)
        if kids.count == 1 || isVerticalStack(view) || view is UIScrollView || kids.contains(where: containsCard) {
            for kid in kids {
                mark(kid)
            }
            return
        }
        SweepOrder.markComponent(view)
    }

    private static func isVerticalStack(_ view: UIView) -> Bool {
        (view as? UIStackView)?.axis == .vertical
    }

    private static func containsCard(_ view: UIView) -> Bool {
        if isCard(view) && containsBlock(view) { return true }
        return view.subviews.contains(where: containsCard)
    }

    private static func containsBlock(_ view: UIView) -> Bool {
        if view is SkeletonView { return true }
        return view.subviews.contains(where: containsBlock)
    }
}

@MainActor
final class SkeletonizedHostView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        var candidate: UIView? = hit
        while let view = candidate, view !== self {
            if let touchable = view.skeletonTouchable {
                return touchable ? hit : nil
            }
            candidate = view.superview
        }
        return nil
    }
}

extension UIView {
    fileprivate var skeletonTouchable: Bool? {
        get { (objc_getAssociatedObject(self, &SkeletonizedAssociation.touchable) as? NSNumber)?.boolValue }
        set { objc_setAssociatedObject(self, &SkeletonizedAssociation.touchable, newValue.map { NSNumber(value: $0) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private enum SkeletonizedAssociation {
    nonisolated(unsafe) static var mode: UInt8 = 0
    nonisolated(unsafe) static var touchable: UInt8 = 0
}
