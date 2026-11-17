import UIKit

// MARK: - Element

/// One piece of a skeleton. A screen describes the shape it is waiting for as a tree of elements;
/// `SkeletonLayout` at the root turns that tree into views and gives VoiceOver a single "Loading"
/// element.
@MainActor
public protocol SkeletonElement {
    /// The view this element draws.
    func makeView() -> UIView

    /// The line this element draws, when it is a plain line. Flush lines in a column fuse into
    /// one block, which is why the layout reads this before making the views.
    var lineMetrics: SkeletonLineMetrics? { get }
}

public extension SkeletonElement {
    var lineMetrics: SkeletonLineMetrics? { nil }
}

/// One line's geometry, so adjacent lines can fuse without losing what they each asked for.
public struct SkeletonLineMetrics {
    public let height: CGFloat
    public let width: CGFloat?
    public let widthFraction: CGFloat?
    public let radius: CGFloat

    /// Whether another line asks for the same width, so the two can draw as one rectangle.
    func matchesWidth(of other: SkeletonLineMetrics) -> Bool {
        width == other.width && widthFraction == other.widthFraction
    }
}

/// A group of elements, as returned by a `@SkeletonContentBuilder` closure.
public struct SkeletonContent {
    public let elements: [SkeletonElement]

    public init(_ elements: [SkeletonElement]) {
        self.elements = elements
    }
}

/// Collects the elements declared inside a layout container.
@resultBuilder
public enum SkeletonContentBuilder {
    public static func buildBlock(_ components: SkeletonContent...) -> SkeletonContent {
        SkeletonContent(components.flatMap(\.elements))
    }

    public static func buildExpression(_ element: SkeletonElement) -> SkeletonContent {
        SkeletonContent([element])
    }

    public static func buildExpression(_ list: [SkeletonElement]) -> SkeletonContent {
        SkeletonContent(list)
    }


    public static func buildOptional(_ component: SkeletonContent?) -> SkeletonContent {
        component ?? SkeletonContent([])
    }

    public static func buildEither(first component: SkeletonContent) -> SkeletonContent {
        component
    }

    public static func buildEither(second component: SkeletonContent) -> SkeletonContent {
        component
    }

    public static func buildArray(_ components: [SkeletonContent]) -> SkeletonContent {
        SkeletonContent(components.flatMap(\.elements))
    }
}

// MARK: - Style

/// The text a placeholder line stands in for. The height of the line box comes from the theme, so a
/// block lands exactly where the label will.
public struct SkeletonTextStyle: Equatable {
    public let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    /// A screen title.
    public static let title = SkeletonTextStyle(size: 30)
    /// A section heading or card title.
    public static let headline = SkeletonTextStyle(size: 17)
    /// Body copy and row titles.
    public static let body = SkeletonTextStyle(size: 15)
    /// Captions, meta and secondary lines.
    public static let caption = SkeletonTextStyle(size: 13)
    /// Any other size a real label uses.
    public static func custom(_ size: CGFloat) -> SkeletonTextStyle {
        SkeletonTextStyle(size: size)
    }

    /// The height of one line box at this style, from the theme.
    @MainActor
    public var lineHeight: CGFloat {
        SkeletonTheme.current.lineHeight(size)
    }

    /// The line's corner radius: a pill at half the type size, as text reads.
    public var lineRadius: CGFloat { size / 2 }
}

/// How the children of a container line up across its axis.
public enum SkeletonAxisAlignment {
    case fill
    case leading
    case center
    case trailing
}

// MARK: - Layout

/// A skeleton, root and all: a vertical arrangement of elements that the screen can drop where the
/// content will go. It is one `SkeletonContainerView`, so VoiceOver reads a single "Loading" while
/// the individual blocks stay hidden.
@MainActor
public struct SkeletonLayout: SkeletonElement {
    private let content: SkeletonContent
    private let spacing: CGFloat?
    private let padding: UIEdgeInsets
    private let alignment: SkeletonAxisAlignment

    /// - Parameters:
    ///   - spacing: the gap between elements; the theme's spacing when nil.
    ///   - padding: room inside the layout, all sides.
    ///   - alignment: how the elements line up; `.fill` stretches them to the width.
    public init(
        spacing: CGFloat? = nil,
        padding: CGFloat = 0,
        alignment: SkeletonAxisAlignment = .fill,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.init(spacing: spacing, padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding), alignment: alignment, content: content)
    }

    /// The same layout with each side's padding named.
    public init(
        spacing: CGFloat? = nil,
        padding: UIEdgeInsets,
        alignment: SkeletonAxisAlignment = .fill,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.content = content()
        self.spacing = spacing
        self.padding = padding
        self.alignment = alignment
    }

    public func makeView() -> UIView {
        let stack = SkeletonStack.make(
            axis: .vertical,
            content: content,
            spacing: spacing,
            padding: padding,
            alignment: alignment,
            tagsComponents: true
        )
        return SkeletonContainerView(content: stack)
    }
}

/// Elements stacked top to bottom.
@MainActor
public struct SkeletonColumn: SkeletonElement {
    private let content: SkeletonContent
    private let spacing: CGFloat?
    private let padding: UIEdgeInsets
    private let alignment: SkeletonAxisAlignment

    public init(
        spacing: CGFloat? = nil,
        padding: CGFloat = 0,
        alignment: SkeletonAxisAlignment = .leading,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.init(
            spacing: spacing,
            padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
            alignment: alignment,
            content: content
        )
    }

    public init(
        spacing: CGFloat? = nil,
        padding: UIEdgeInsets,
        alignment: SkeletonAxisAlignment = .leading,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.content = content()
        self.spacing = spacing
        self.padding = padding
        self.alignment = alignment
    }

    /// A column over elements that are already collected.
    public init(
        spacing: CGFloat? = nil,
        padding: UIEdgeInsets = .zero,
        alignment: SkeletonAxisAlignment = .leading,
        content: SkeletonContent
    ) {
        self.content = content
        self.spacing = spacing
        self.padding = padding
        self.alignment = alignment
    }

    public func makeView() -> UIView {
        SkeletonStack.make(axis: .vertical, content: content, spacing: spacing, padding: padding, alignment: alignment)
    }
}

/// Elements side by side. The tallest element sets the row's height and the others keep their
/// own, so a short copy column beside a tall photo is a row that lays out.
@MainActor
public struct SkeletonRow: SkeletonElement {
    private let content: SkeletonContent
    private let spacing: CGFloat?
    private let padding: UIEdgeInsets
    private let alignment: SkeletonAxisAlignment
    private let distribution: SkeletonDistribution

    public init(
        spacing: CGFloat? = nil,
        padding: CGFloat = 0,
        alignment: SkeletonAxisAlignment = .center,
        distribution: SkeletonDistribution = .fill,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.init(
            spacing: spacing,
            padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
            alignment: alignment,
            distribution: distribution,
            content: content
        )
    }

    public init(
        spacing: CGFloat? = nil,
        padding: UIEdgeInsets,
        alignment: SkeletonAxisAlignment = .center,
        distribution: SkeletonDistribution = .fill,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.content = content()
        self.spacing = spacing
        self.padding = padding
        self.alignment = alignment
        self.distribution = distribution
    }

    public func makeView() -> UIView {
        SkeletonStack.make(
            axis: .horizontal,
            content: content,
            spacing: spacing,
            padding: padding,
            alignment: alignment,
            distribution: distribution
        )
    }
}

/// How a row shares its spare width between its elements.
public enum SkeletonDistribution {
    case fill
    case fillEqually
}

/// Takes the spare width in a row so the elements around it keep their own size.
@MainActor
public struct SkeletonSpacer: SkeletonElement {
    public init() {}

    public func makeView() -> UIView {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }
}

// MARK: - Blocks

/// A line of text: as tall as the line box of the style it stands in for.
@MainActor
public struct SkeletonLine: SkeletonElement {
    private let style: SkeletonTextStyle
    private let width: CGFloat?
    private let widthFraction: CGFloat?
    private let radius: CGFloat?

    public init(_ style: SkeletonTextStyle = .body, width: CGFloat? = nil, widthFraction: CGFloat? = nil) {
        self.style = style
        self.width = width
        self.widthFraction = widthFraction
        self.radius = nil
    }

    /// A line at a size no style names.
    public init(fontSize: CGFloat, width: CGFloat? = nil, widthFraction: CGFloat? = nil) {
        self.init(.custom(fontSize), width: width, widthFraction: widthFraction)
    }

    private init(style: SkeletonTextStyle, width: CGFloat?, widthFraction: CGFloat?, radius: CGFloat?) {
        self.style = style
        self.width = width
        self.widthFraction = widthFraction
        self.radius = radius
    }

    /// The line's corner radius; half the type size when it is not named.
    public func radius(_ value: CGFloat) -> SkeletonLine {
        SkeletonLine(style: style, width: width, widthFraction: widthFraction, radius: value)
    }

    public func width(_ value: CGFloat) -> SkeletonLine {
        SkeletonLine(style: style, width: value, widthFraction: nil, radius: radius)
    }

    public func makeView() -> UIView {
        SkeletonView.line(
            height: style.lineHeight,
            width: width,
            widthFraction: widthFraction,
            radius: radius ?? style.lineRadius
        )
    }

    public var lineMetrics: SkeletonLineMetrics? {
        SkeletonLineMetrics(
            height: style.lineHeight,
            width: width,
            widthFraction: widthFraction,
            radius: radius ?? style.lineRadius
        )
    }
}

/// A plain block: a photo, a chart, a button's shape, anything no other element names.
@MainActor
public struct SkeletonBlock: SkeletonElement {
    private let height: CGFloat?
    private let width: CGFloat?
    private let radius: CGFloat?

    public init(height: CGFloat? = nil, width: CGFloat? = nil, radius: CGFloat? = nil) {
        self.height = height
        self.width = width
        self.radius = radius
    }

    public func radius(_ value: CGFloat) -> SkeletonBlock {
        SkeletonBlock(height: height, width: width, radius: value)
    }

    public func makeView() -> UIView {
        let block = SkeletonView(cornerRadius: radius ?? SkeletonTheme.current.cornerRadius)
        if let height {
            block.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        if let width {
            block.setPreferredWidth(width)
        }
        return block
    }
}

/// A photo or thumbnail: a fixed size, or a width and the aspect its image keeps.
@MainActor
public struct SkeletonPhoto: SkeletonElement {
    private let width: CGFloat
    private let height: CGFloat?
    private let aspect: CGFloat?
    private let radius: CGFloat?

    public init(width: CGFloat, height: CGFloat? = nil, aspect: CGFloat? = nil, radius: CGFloat? = nil) {
        self.width = width
        self.height = height
        self.aspect = aspect
        self.radius = radius
    }

    public func radius(_ value: CGFloat) -> SkeletonPhoto {
        SkeletonPhoto(width: width, height: height, aspect: aspect, radius: value)
    }

    public func makeView() -> UIView {
        let photo = SkeletonView(cornerRadius: radius ?? SkeletonTheme.current.cornerRadius)
        photo.setPreferredWidth(width)
        if let height {
            photo.heightAnchor.constraint(equalToConstant: height).isActive = true
        } else if let aspect {
            photo.heightAnchor.constraint(equalTo: photo.widthAnchor, multiplier: aspect).isActive = true
        }
        return photo
    }
}

/// An avatar or round icon.
@MainActor
public struct SkeletonCircle: SkeletonElement {
    private let diameter: CGFloat

    public init(diameter: CGFloat) {
        self.diameter = diameter
    }

    public func makeView() -> UIView {
        SkeletonView.circle(diameter: diameter)
    }
}

/// A real view inside the shape — copy, a heading or a control the screen already knows.
@MainActor
public struct SkeletonReal: SkeletonElement {
    private let view: UIView

    public init(_ view: UIView) {
        self.view = view
    }

    public func makeView() -> UIView {
        view
    }
}

// MARK: - Cards

/// A card around its content, at the real card's background, border, radius and padding.
@MainActor
public struct SkeletonCard: SkeletonElement {
    private let content: SkeletonContent
    private let padding: UIEdgeInsets
    private let spacing: CGFloat?
    private let radius: CGFloat?
    private let background: UIColor?
    private let border: UIColor?
    private let shadow: Bool

    public init(
        padding: CGFloat = 0,
        spacing: CGFloat? = nil,
        radius: CGFloat? = nil,
        background: UIColor? = nil,
        border: UIColor? = nil,
        shadow: Bool = false,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.init(
            padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
            spacing: spacing,
            radius: radius,
            background: background,
            border: border,
            shadow: shadow,
            content: content
        )
    }

    public init(
        padding: UIEdgeInsets,
        spacing: CGFloat? = nil,
        radius: CGFloat? = nil,
        background: UIColor? = nil,
        border: UIColor? = nil,
        shadow: Bool = false,
        @SkeletonContentBuilder content: () -> SkeletonContent
    ) {
        self.content = content()
        self.padding = padding
        self.spacing = spacing
        self.radius = radius
        self.background = background
        self.border = border
        self.shadow = shadow
    }

    public func padding(_ value: CGFloat) -> SkeletonCard {
        padding(UIEdgeInsets(top: value, left: value, bottom: value, right: value))
    }

    public func padding(_ insets: UIEdgeInsets) -> SkeletonCard {
        SkeletonCard(padding: insets, spacing: spacing, radius: radius, background: background, border: border, shadow: shadow, content: content)
    }

    /// A card over elements that are already collected.
    public init(
        padding: UIEdgeInsets,
        spacing: CGFloat? = nil,
        radius: CGFloat? = nil,
        background: UIColor? = nil,
        border: UIColor? = nil,
        shadow: Bool = false,
        content: SkeletonContent
    ) {
        self.content = content
        self.padding = padding
        self.spacing = spacing
        self.radius = radius
        self.background = background
        self.border = border
        self.shadow = shadow
    }

    public func makeView() -> UIView {
        let theme = SkeletonTheme.current
        let card = UIView()
        if background != nil || border != nil || radius != nil {
            card.layer.cornerRadius = radius ?? theme.cardRadius
            card.layer.cornerCurve = .continuous
            card.clipsToBounds = !shadow
        }
        card.backgroundColor = background
        if let border {
            card.layer.borderWidth = 1
            card.layer.borderColor = border.cgColor
        }
        if shadow {
            theme.shadow.apply(to: card)
        }

        let body = SkeletonStack.make(
            axis: .vertical,
            content: content,
            spacing: spacing ?? theme.spacing,
            padding: padding,
            alignment: .fill
        )
        body.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: card.topAnchor),
            body.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }
}

// MARK: - Repeats

/// N copies of one shape: a list of rows is a single line.
@MainActor
public struct SkeletonRows: SkeletonElement {
    private let count: Int
    private let spacing: CGFloat
    private let padding: UIEdgeInsets
    private let makeRow: () -> SkeletonElement

    /// Repeats a preset row.
    public init(count: Int, _ preset: SkeletonPreset, spacing: CGFloat = 0, padding: CGFloat = 0) {
        self.init(count: count, spacing: spacing, padding: padding) { preset.element }
    }

    /// Repeats a shape written at the call site.
    public init(
        count: Int,
        spacing: CGFloat = 0,
        padding: CGFloat = 0,
        @SkeletonContentBuilder row: @escaping () -> SkeletonContent
    ) {
        self.count = count
        self.spacing = spacing
        self.padding = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        self.makeRow = {
            let content = row()
            return content.elements.count == 1
                ? content.elements[0]
                : SkeletonColumn(spacing: 0, alignment: .fill, content: content)
        }
    }

    private init(count: Int, spacing: CGFloat, padding: UIEdgeInsets, makeRow: @escaping () -> SkeletonElement) {
        self.count = count
        self.spacing = spacing
        self.padding = padding
        self.makeRow = makeRow
    }

    public func makeView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.alignment = .fill
        for _ in 0..<max(count, 0) {
            let row = makeRow().makeView()
            SweepOrder.markComponent(row)
            stack.addArrangedSubview(row)
        }
        if padding != .zero {
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = padding
        }
        return stack
    }
}

// MARK: - Presets

/// The shapes this package's screens keep repeating. A preset is the whole row or field, at the
/// geometry the loaded screen uses, and can be used anywhere an element can.
public enum SkeletonPreset: SkeletonElement {
    /// A list row: 40pt photo, a title and a caption, and the amount on the trailing edge.
    case listRow
    /// A card row: an 84 × 64 tile, two lines of copy, and a 64 × 40 button.
    case cardRow
    /// A trailing price column: the small "from" over the price and a count.
    case priceColumn
    /// One text field at its real chrome, its placeholder and its value area.
    case formField
    /// One field whose value is chosen elsewhere, with its chevron.
    case pickerRow

    @MainActor
    public func makeView() -> UIView {
        element.makeView()
    }

    @MainActor
    var element: SkeletonElement {
        switch self {
        case .listRow:
            return SkeletonRow(spacing: 12, padding: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)) {
                SkeletonPhoto(width: 40, height: 40, radius: 12)
                SkeletonColumn(spacing: 2) {
                    SkeletonLine(.custom(15), width: 108)
                    SkeletonLine(.caption, width: 132)
                }
                SkeletonSpacer()
                SkeletonLine(.custom(15), width: 76).hugging
            }
        case .cardRow:
            return SkeletonRow(spacing: 14, padding: 14) {
                SkeletonPhoto(width: 84, height: 64, radius: 12)
                SkeletonColumn(spacing: 2) {
                    SkeletonLine(.custom(19), width: 96)
                    SkeletonLine(.caption, width: 128)
                }
                SkeletonSpacer()
                SkeletonBlock(height: 40, width: 64, radius: 20)
            }
        case .priceColumn:
            return SkeletonColumn(spacing: 4, alignment: .trailing) {
                SkeletonLine(.custom(11), width: 34)
                SkeletonLine(.custom(17), width: 56)
                SkeletonLine(.caption, width: 44)
            }
        case .formField:
            return SkeletonField()
        case .pickerRow:
            return SkeletonPickerRow()
        }
    }
}

// MARK: - Modifiers

public extension SkeletonElement {
    /// Gives the element a fixed width. It keeps that width in a row, and stays on the leading edge
    /// inside a filling column.
    @MainActor
    func width(_ value: CGFloat) -> SkeletonElement {
        SkeletonSized(base: self, width: value, height: nil, widthFraction: nil, padsInFraction: false)
    }

    /// Gives the element a fixed height.
    @MainActor
    func height(_ value: CGFloat) -> SkeletonElement {
        SkeletonSized(base: self, width: nil, height: value, widthFraction: nil, padsInFraction: false)
    }

    /// Takes this share of its container's width.
    @MainActor
    func widthFraction(_ value: CGFloat) -> SkeletonElement {
        SkeletonSized(base: self, width: nil, height: nil, widthFraction: value, padsInFraction: false)
    }

    /// Room around the element, all sides.
    @MainActor
    func padding(_ value: CGFloat) -> SkeletonElement {
        SkeletonSized(
            base: self,
            width: nil,
            height: nil,
            widthFraction: nil,
            padsInFraction: false,
            insets: UIEdgeInsets(top: value, left: value, bottom: value, right: value)
        )
    }

    /// Room around the element, each side named.
    @MainActor
    func padding(_ insets: UIEdgeInsets) -> SkeletonElement {
        SkeletonSized(base: self, width: nil, height: nil, widthFraction: nil, padsInFraction: false, insets: insets)
    }

    /// Gives the element an aspect ratio: its height follows its width.
    @MainActor
    func aspect(_ ratio: CGFloat) -> SkeletonElement {
        SkeletonSized(base: self, width: nil, height: nil, widthFraction: nil, padsInFraction: false, aspect: ratio)
    }

    /// Keeps the element at its own width and height instead of stretching into the container.
    @MainActor
    var hugging: SkeletonElement {
        SkeletonSized(base: self, width: nil, height: nil, widthFraction: nil, padsInFraction: false, hugging: true)
    }
}

/// Wraps one element with a size, a width fraction or padding.
@MainActor
private struct SkeletonSized: SkeletonElement {
    let base: SkeletonElement
    let width: CGFloat?
    let height: CGFloat?
    let widthFraction: CGFloat?
    let padsInFraction: Bool
    var insets: UIEdgeInsets = .zero
    var hugging = false
    var aspect: CGFloat? = nil

    func makeView() -> UIView {
        let view = base.makeView()
        if let width {
            view.setPreferredWidth(width)
        }
        if let height {
            view.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        if let aspect {
            view.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: aspect).isActive = true
        }
        if hugging {
            view.setContentHuggingPriority(.required, for: .horizontal)
        }
        let container: UIView
        if let widthFraction, width == nil {
            container = FractionalWidthView(fraction: widthFraction)
        } else {
            container = UIView()
        }
        container.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets.left),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets.bottom),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -insets.right),
        ])
        if hugging {
            container.setContentHuggingPriority(.required, for: .horizontal)
        }
        return container
    }
}

// MARK: - Stack

@MainActor
enum SkeletonStack {
    static func make(
        axis: NSLayoutConstraint.Axis,
        content: SkeletonContent,
        spacing: CGFloat?,
        padding: UIEdgeInsets,
        alignment: SkeletonAxisAlignment,
        distribution: SkeletonDistribution = .fill,
        tagsComponents: Bool = false
    ) -> UIStackView {
        let stack = UIStackView()
        stack.axis = axis
        stack.spacing = spacing ?? SkeletonTheme.current.spacing
        stack.alignment = alignment.ui(axis: axis)
        stack.distribution = distribution == .fillEqually ? .fillEqually : .fill
        // A stack inside a placeholder card has no intrinsic size of its own, so keep a parent
        // column from compressing it to nothing.
        stack.setContentHuggingPriority(.required, for: .vertical)
        stack.setContentCompressionResistancePriority(.required, for: .vertical)
        for view in views(for: content.elements, axis: axis, spacing: stack.spacing) {
            if tagsComponents {
                SweepOrder.markComponent(view)
            }
            stack.addArrangedSubview(view)
        }
        if padding != .zero {
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = padding
        }
        return stack
    }

    /// The views a stack holds, with a flush run of lines in a vertical stack drawn as one block.
    private static func views(
        for elements: [SkeletonElement],
        axis: NSLayoutConstraint.Axis,
        spacing: CGFloat
    ) -> [UIView] {
        guard axis == .vertical, spacing == 0 else {
            return elements.map { $0.makeView() }
        }
        var views: [UIView] = []
        var run: [SkeletonLineMetrics] = []
        for element in elements {
            guard let metrics = element.lineMetrics else {
                views.append(contentsOf: fused(run))
                run.removeAll()
                views.append(element.makeView())
                continue
            }
            run.append(metrics)
        }
        views.append(contentsOf: fused(run))
        return views
    }

    private static func fused(_ run: [SkeletonLineMetrics]) -> [UIView] {
        guard !run.isEmpty else { return [] }
        return [SkeletonLineRun.makeView(run)]
    }
}

// MARK: - Fused runs

/// A run of lines with nothing between them, drawn as one surface: one block when they share a
/// width, and a stepped block of flush segments when they do not.
@MainActor
enum SkeletonLineRun {

    static func makeView(_ run: [SkeletonLineMetrics]) -> UIView {
        let first = run[0]
        let last = run[run.count - 1]
        let radius = max(first.radius, last.radius)

        guard run.allSatisfy({ $0.matchesWidth(of: first) }) else {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 0
            stack.alignment = .leading
            var blocks: [SkeletonView] = []
            for (index, line) in run.enumerated() {
                let corners: CACornerMask = index == 0
                    ? .skeletonTopCorners
                    : (index == run.count - 1 ? .skeletonBottomCorners : [])
                let block = SkeletonView.line(
                    height: line.height,
                    width: line.width,
                    widthFraction: line.widthFraction,
                    radius: line.radius,
                    corners: corners
                )
                blocks.append(block)
                stack.addArrangedSubview(block)
            }
            return stack
        }

        return SkeletonView.line(
            height: run.reduce(0) { $0 + $1.height },
            width: first.width,
            widthFraction: first.widthFraction,
            radius: radius,
            corners: .skeletonAllCorners
        )
    }
}

private extension SkeletonAxisAlignment {
    func ui(axis: NSLayoutConstraint.Axis) -> UIStackView.Alignment {
        switch (self, axis) {
        case (.fill, .vertical): return .fill
        // A row's height is its tallest element; nothing in a skeleton row asks a block to
        // stretch vertically, and stretching a short column to a photo's height cannot lay out.
        case (.fill, .horizontal): return .center
        case (.leading, .vertical): return .leading
        case (.leading, .horizontal): return .top
        case (.center, _): return .center
        case (.trailing, .vertical): return .trailing
        case (.trailing, .horizontal): return .bottom
        default: return .center
        }
    }
}

// MARK: - Width fractions

/// A view that keeps a share of whatever superview it lands in, so a block can take a fraction of
/// its row without the layout having to know the width yet.
@MainActor
final class FractionalWidthView: UIView {
    private let fraction: CGFloat
    private var widthConstraint: NSLayoutConstraint?

    init(fraction: CGFloat) {
        self.fraction = fraction
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The app builds its UI in code; init(coder:) is not supported")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        widthConstraint?.isActive = false
        widthConstraint = nil
        guard let superview else { return }
        let constraint = widthAnchor.constraint(equalTo: superview.widthAnchor, multiplier: fraction)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        widthConstraint = constraint
    }
}
