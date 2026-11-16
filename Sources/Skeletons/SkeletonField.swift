import UIKit

// MARK: - Elements

/// A text field at the geometry of the loaded one, waiting for the value the response fills: the
/// real surface, 1 pt border, corner radius, height and inner padding, any accessory the field
/// already leads with, and a shimmering line only where the typed value goes. The field's own
/// placeholder copy is never drawn: the value line stands in for the text.
@MainActor
public struct SkeletonField: SkeletonElement {
    private let placeholder: String?
    private let icon: UIImage?
    private let leading: SkeletonElement?
    private let showsChevron: Bool
    private let valueWidthFraction: CGFloat?
    private let height: CGFloat?
    private let radius: CGFloat?
    private let padding: CGFloat?

    /// - Parameters:
    ///   - placeholder: the field's own placeholder copy. Never drawn; when `valueWidthFraction`
    ///     is nil it sets the value line's width to the width that copy takes.
    ///   - icon: the field's real leading icon, drawn in the theme's field text colour; used only
    ///     when `leading` is nil.
    ///   - leading: an accessory the field already has at its leading edge, as `SkeletonReal(view)`
    ///     — a country picker. It keeps its own width and the field's full height, and the value
    ///     area takes the rest. Pass a skeleton element instead when the accessory's own content
    ///     is fetched.
    ///   - showsChevron: draws the field's own chevron before the trailing edge.
    ///   - valueWidthFraction: the share of the value area the shimmering line takes; the
    ///     placeholder's width when it is given, 0.55 otherwise.
    ///   - height: the field's height; the theme's `fieldHeight` when nil.
    ///   - radius: the field's corner radius; the theme's `fieldRadius` when nil.
    ///   - padding: the inset from the leading and trailing edges, and the gap after a leading
    ///     accessory; the theme's `fieldPadding` when nil.
    public init(
        placeholder: String? = nil,
        icon: UIImage? = nil,
        leading: SkeletonElement? = nil,
        showsChevron: Bool = false,
        valueWidthFraction: CGFloat? = nil,
        height: CGFloat? = nil,
        radius: CGFloat? = nil,
        padding: CGFloat? = nil
    ) {
        self.placeholder = placeholder
        self.icon = icon
        self.leading = leading
        self.showsChevron = showsChevron
        self.valueWidthFraction = valueWidthFraction
        self.height = height
        self.radius = radius
        self.padding = padding
    }

    public func makeView() -> UIView {
        SkeletonFieldChrome(
            label: nil,
            valueWidthHint: placeholder,
            icon: icon,
            leading: leading?.makeView(),
            showsChevron: showsChevron,
            valuePlacement: .behind,
            valueWidthFraction: valueWidthFraction,
            height: height,
            radius: radius,
            padding: padding
        )
    }
}

/// A field whose value is chosen elsewhere — a governorate, an area, a date: the same chrome, its
/// real label and chevron in place, any leading accessory kept real, and only the value area
/// shimmering.
@MainActor
public struct SkeletonPickerRow: SkeletonElement {
    private let label: String?
    private let icon: UIImage?
    private let leading: SkeletonElement?
    private let showsChevron: Bool
    private let valueWidthFraction: CGFloat?
    private let height: CGFloat?
    private let radius: CGFloat?
    private let padding: CGFloat?

    /// - Parameters:
    ///   - label: the label the row shows before its value, drawn as real text.
    ///   - icon: the row's real leading icon; its presence sets the label's leading edge.
    ///   - leading: an accessory the row already has at its leading edge, as `SkeletonReal(view)`.
    ///     It keeps its own width and the row's full height, and the label and the value take the
    ///     rest. Pass a skeleton element instead when the accessory's own content is fetched.
    ///   - showsChevron: draws the row's chevron; true by default, as a picker has one.
    ///   - valueWidthFraction: the share of the value area the shimmering line takes; 0.4 when nil.
    ///   - height: the row's height; the theme's `fieldHeight` when nil.
    ///   - radius: the row's corner radius; the theme's `fieldRadius` when nil.
    ///   - padding: the inset from the leading and trailing edges, and the gap after a leading
    ///     accessory; the theme's `fieldPadding` when nil.
    public init(
        label: String? = nil,
        icon: UIImage? = nil,
        leading: SkeletonElement? = nil,
        showsChevron: Bool = true,
        valueWidthFraction: CGFloat? = nil,
        height: CGFloat? = nil,
        radius: CGFloat? = nil,
        padding: CGFloat? = nil
    ) {
        self.label = label
        self.icon = icon
        self.leading = leading
        self.showsChevron = showsChevron
        self.valueWidthFraction = valueWidthFraction
        self.height = height
        self.radius = radius
        self.padding = padding
    }

    public func makeView() -> UIView {
        SkeletonFieldChrome(
            label: label,
            valueWidthHint: nil,
            icon: icon,
            leading: leading?.makeView(),
            showsChevron: showsChevron,
            valuePlacement: .after,
            valueWidthFraction: valueWidthFraction,
            height: height,
            radius: radius,
            padding: padding
        )
    }
}

// MARK: - Chrome

/// Where the value sits relative to the real text.
enum SkeletonFieldValuePlacement {
    /// A text field: the value occupies the whole area after the leading edge.
    case behind
    /// A picker: the value starts after the label.
    case after
}

/// The field's chrome and its parts: the real accessory, the real label of a picker row, and the
/// shimmering value area inside it.
@MainActor
final class SkeletonFieldChrome: UIView {

    /// The value area's blinking line, sized from the theme.
    private(set) var valueLine: SkeletonView!

    /// The real label of a picker row, or nil when the field shows no text of its own.
    private(set) var label: UILabel?

    private(set) var iconView: UIImageView?
    private(set) var chevronView: UIView?

    /// The real view the field leads with, when it has one.
    private(set) var leadingView: UIView?

    /// The fixed height this field was given.
    let resolvedHeight: CGFloat
    /// The corner radius this field was given.
    let resolvedRadius: CGFloat
    /// The inset from the leading and trailing edges.
    let resolvedPadding: CGFloat
    /// The share of the value area the line takes.
    let resolvedValueWidthFraction: CGFloat

    /// The line's width, as a share of the value area, so a test can check the region it covers.
    private(set) var valueWidthConstraint: NSLayoutConstraint?

    init(
        label: String?,
        valueWidthHint: String?,
        icon: UIImage?,
        leading: UIView?,
        showsChevron: Bool,
        valuePlacement: SkeletonFieldValuePlacement,
        valueWidthFraction: CGFloat?,
        height: CGFloat?,
        radius: CGFloat?,
        padding: CGFloat?
    ) {
        let theme = SkeletonTheme.current
        resolvedHeight = height ?? theme.fieldHeight
        resolvedRadius = radius ?? theme.fieldRadius
        resolvedPadding = padding ?? theme.fieldPadding
        resolvedValueWidthFraction = valueWidthFraction
            ?? (valuePlacement == .behind ? 0.55 : 0.4)

        super.init(frame: .zero)

        backgroundColor = theme.fieldSurface
        layer.cornerRadius = resolvedRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = theme.fieldBorder.cgColor
        // The loaded field clips its own content, so an accessory's fill stops at the corner.
        clipsToBounds = true
        heightAnchor.constraint(equalToConstant: resolvedHeight).isActive = true

        // The row runs from the leading accessory to the chevron, one item after another.
        var textLeading: NSLayoutXAxisAnchor = leadingAnchor
        var textLeadingInset = resolvedPadding
        if let leading {
            add(leading, to: self)
            NSLayoutConstraint.activate([
                leading.leadingAnchor.constraint(equalTo: leadingAnchor),
                leading.topAnchor.constraint(equalTo: topAnchor),
                leading.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            leadingView = leading
            textLeading = leading.trailingAnchor
            textLeadingInset = resolvedPadding
        } else if let icon {
            let image = UIImageView(image: icon.withRenderingMode(.alwaysTemplate))
            image.tintColor = theme.fieldText
            image.contentMode = .scaleAspectFit
            addPinned(image)
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: leadingAnchor, constant: resolvedPadding),
                image.centerYAnchor.constraint(equalTo: centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: Self.iconSide),
                image.heightAnchor.constraint(equalToConstant: Self.iconSide),
            ])
            iconView = image
            textLeading = image.trailingAnchor
            textLeadingInset = Self.gap
        }

        let textArea = UIView()
        addPinned(textArea)

        var textTrailing: NSLayoutXAxisAnchor = trailingAnchor
        var textTrailingInset = -resolvedPadding
        if showsChevron {
            let chevron = makeChevron(theme: theme)
            addPinned(chevron)
            NSLayoutConstraint.activate([
                chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -resolvedPadding),
                chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
                chevron.widthAnchor.constraint(equalToConstant: Self.chevronSide),
                chevron.heightAnchor.constraint(equalToConstant: Self.chevronSide),
            ])
            chevronView = chevron
            textTrailing = chevron.leadingAnchor
            textTrailingInset = -Self.gap
        }

        NSLayoutConstraint.activate([
            textArea.leadingAnchor.constraint(equalTo: textLeading, constant: textLeadingInset),
            textArea.trailingAnchor.constraint(equalTo: textTrailing, constant: textTrailingInset),
            textArea.topAnchor.constraint(equalTo: topAnchor),
            textArea.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let lineHeight = theme.lineHeight(theme.fieldTextFont.pointSize)
        let line = SkeletonView.line(height: lineHeight, radius: lineHeight / 2)
        valueLine = line

        var valueArea = textArea
        if valuePlacement == .after, let label {
            let labelView = makeLabel(label, theme: theme)
            add(labelView, to: textArea)
            NSLayoutConstraint.activate([
                labelView.leadingAnchor.constraint(equalTo: textArea.leadingAnchor),
                labelView.centerYAnchor.constraint(equalTo: textArea.centerYAnchor),
            ])
            self.label = labelView

            let area = UIView()
            add(area, to: textArea)
            NSLayoutConstraint.activate([
                area.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: Self.gap),
                area.trailingAnchor.constraint(equalTo: textArea.trailingAnchor),
                area.topAnchor.constraint(equalTo: textArea.topAnchor),
                area.bottomAnchor.constraint(equalTo: textArea.bottomAnchor),
            ])
            valueArea = area
        }

        add(line, to: valueArea)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: valueArea.leadingAnchor),
            line.centerYAnchor.constraint(equalTo: valueArea.centerYAnchor),
            line.trailingAnchor.constraint(lessThanOrEqualTo: valueArea.trailingAnchor),
        ])

        if let valueWidthFraction {
            let width = line.widthAnchor.constraint(
                equalTo: valueArea.widthAnchor,
                multiplier: valueWidthFraction
            )
            width.isActive = true
            valueWidthConstraint = width
        } else if let valueWidthHint, let hintWidth = textWidth(of: valueWidthHint, in: theme.fieldTextFont) {
            let width = line.widthAnchor.constraint(equalToConstant: hintWidth)
            width.priority = UILayoutPriority(999)
            width.isActive = true
        } else {
            let width = line.widthAnchor.constraint(
                equalTo: valueArea.widthAnchor,
                multiplier: resolvedValueWidthFraction
            )
            width.isActive = true
            valueWidthConstraint = width
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The app builds its UI in code; init(coder:) is not supported")
    }

    /// The picker's own affordance, drawn at a fixed size so its box is the box the loaded row
    /// gives it.
    private func makeChevron(theme: SkeletonTheme) -> UIView {
        let box = UIView()
        let side = Self.chevronSide
        let shape = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: side * 0.15, y: side * 0.38))
        path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.68))
        path.addLine(to: CGPoint(x: side * 0.85, y: side * 0.38))
        shape.path = path.cgPath
        shape.fillColor = nil
        shape.strokeColor = theme.fieldText.resolvedColor(with: traitCollection).cgColor
        shape.lineWidth = 1.5
        shape.lineCap = .round
        shape.lineJoin = .round
        box.layer.addSublayer(shape)
        return box
    }

    /// Adds a subview laid out by constraints. The flag is cleared first: a view added with its
    /// own frame keeps that frame as a required constraint.
    private func addPinned(_ view: UIView) {
        add(view, to: self)
    }

    private func add(_ view: UIView, to host: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(view)
    }

    /// The real label: text, never a block.
    private func makeLabel(_ text: String, theme: SkeletonTheme) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = theme.fieldTextFont
        label.textColor = theme.fieldText
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    /// The width the placeholder copy takes in the field's font, so the value line stands where
    /// that copy would.
    private func textWidth(of text: String, in font: UIFont) -> CGFloat? {
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return width > 0 ? ceil(width) : nil
    }

    private static let iconSide: CGFloat = 18
    private static let chevronSide: CGFloat = 12
    private static let gap: CGFloat = 8
}
