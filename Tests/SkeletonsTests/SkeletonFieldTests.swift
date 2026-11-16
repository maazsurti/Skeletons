import Testing
import UIKit
@testable import Skeletons

@MainActor
struct SkeletonFieldTests {

    /// A theme with the numbers a field test can check without depending on the system's font.
    private func withTheme(_ body: () -> Void) {
        let original = SkeletonTheme.current
        SkeletonTheme.current = SkeletonTheme(
            lineHeight: { ceil($0 * 1.2) },
            fieldSurface: .white,
            fieldBorder: .lightGray,
            fieldText: .gray,
            fieldTextFont: .systemFont(ofSize: 16),
            fieldHeight: 54,
            fieldRadius: 12,
            fieldPadding: 14
        )
        body()
        SkeletonTheme.current = original
    }

    /// The field at a fixed width, laid out so its parts sit where the reader sees them.
    private func laidOut(_ field: SkeletonFieldChrome, width: CGFloat = 320) {
        field.frame = CGRect(x: 0, y: 0, width: width, height: field.resolvedHeight)
        field.setNeedsLayout()
        field.layoutIfNeeded()
    }

    private func frame(of view: UIView?, in container: UIView) -> CGRect {
        guard let view else { return .zero }
        return view.convert(view.bounds, to: container)
    }

    /// Every shimmering block inside the field.
    private func skeletonViews(in view: UIView) -> [SkeletonView] {
        view.subviews.flatMap { subview in
            (subview as? SkeletonView).map { [$0] } ?? []
        } + view.subviews.flatMap(skeletonViews(in:))
    }

    /// Every piece of text drawn inside the field.
    private func labels(in view: UIView) -> [UILabel] {
        view.subviews.flatMap { subview in
            (subview as? UILabel).map { [$0] } ?? []
        } + view.subviews.flatMap(labels(in:))
    }

    /// A leading accessory at the width a country picker takes, filled so its box can be checked.
    private func accessory(width: CGFloat = 104) -> UIView {
        let view = UIView()
        view.backgroundColor = .darkGray
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        return view
    }

    @Test func fieldKeepsTheChromesOwnGeometry() {
        withTheme {
            let field = SkeletonField().makeView() as? SkeletonFieldChrome

            #expect(field?.backgroundColor == .white)
            #expect(field?.layer.borderWidth == 1)
            #expect(field?.layer.borderColor == UIColor.lightGray.cgColor)
            #expect(field?.layer.cornerRadius == 12)
            #expect(field?.resolvedHeight == 54)
            #expect(field?.resolvedPadding == 14)
        }
    }

    /// A loading field says nothing of its own: the value line is the text.
    @Test func placeholderIsNeverDrawn() {
        withTheme {
            let field = SkeletonField(placeholder: "Full name").makeView() as! SkeletonFieldChrome
            laidOut(field)

            #expect(field.label == nil)
            #expect(labels(in: field).isEmpty)
        }
    }

    /// The placeholder copy only sizes the line, so it lands where that copy would have.
    @Test func placeholderSetsTheLinesWidth() {
        withTheme {
            let field = SkeletonField(placeholder: "Email").makeView() as! SkeletonFieldChrome
            laidOut(field)

            let expected = ceil(("Email" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 16)]).width)
            #expect(abs(frame(of: field.valueLine, in: field).width - expected) < 0.001)
            #expect(frame(of: field.valueLine, in: field).width < 320 - 28)
        }
    }

    /// Only the value region shimmers: one block, its own width, inside the field's chrome.
    @Test func onlyTheValueAreaShimmers() {
        withTheme {
            let field = SkeletonField().makeView() as! SkeletonFieldChrome
            laidOut(field)

            #expect(skeletonViews(in: field).count == 1)
            #expect(skeletonViews(in: field).first === field.valueLine)
            #expect(abs((field.valueWidthConstraint?.multiplier ?? 0) - 0.55) < 0.001)
            #expect(abs((field.valueWidthConstraint?.constant ?? 0)) < 0.001)

            let line = frame(of: field.valueLine, in: field)
            #expect(abs(line.minX - 14) < 0.001)
            #expect(line.midY == 27)
            #expect(abs(line.width - (320 - 28) * 0.55) < 0.5)
        }
    }

    /// An accessory the app already has — a country picker — stays real at its own size, and the
    /// value line takes what is left of the field.
    @Test func leadingAccessoryStaysReal() {
        withTheme {
            let picker = accessory()
            let field = SkeletonField(leading: SkeletonReal(picker), valueWidthFraction: 0.4)
                .makeView() as! SkeletonFieldChrome
            laidOut(field)

            #expect(field.leadingView === picker)
            #expect(field.iconView == nil)

            let box = frame(of: picker, in: field)
            #expect(box.minX == 0)
            #expect(box.midY == 27)
            #expect(abs(box.width - 104) < 0.001)
            #expect(abs(box.height - 54) < 0.001)

            #expect(skeletonViews(in: picker).isEmpty)
            #expect(skeletonViews(in: field).count == 1)
            #expect(skeletonViews(in: field).first === field.valueLine)

            let line = frame(of: field.valueLine, in: field)
            #expect(abs(line.minX - (104 + 14)) < 0.001)
            #expect(abs(line.width - ((320 - 104 - 28) * 0.4)) < 0.5)
        }
    }

    /// A picker row keeps its real label after a leading accessory.
    @Test func pickerRowKeepsItsLabelAfterALeadingAccessory() {
        withTheme {
            let picker = accessory()
            let row = SkeletonPickerRow(label: "Code", leading: SkeletonReal(picker))
                .makeView() as! SkeletonFieldChrome
            laidOut(row)

            #expect(row.leadingView === picker)
            #expect(row.label?.text == "Code")
            #expect(abs(frame(of: row.label, in: row).minX - (104 + 14)) < 0.001)
            #expect(frame(of: row.valueLine, in: row).minX > frame(of: row.label, in: row).maxX)
            #expect(skeletonViews(in: row).count == 1)
        }
    }

    /// The value line is the field's one animation: the accessory draws no sweep of its own.
    @Test func valueLineShimmersAndTheAccessoryDoesNot() throws {
        try #require(!UIAccessibility.isReduceMotionEnabled)

        withTheme {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
            let picker = accessory()
            let field = SkeletonField(leading: SkeletonReal(picker)).makeView() as! SkeletonFieldChrome
            field.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(field)
            NSLayoutConstraint.activate([
                field.topAnchor.constraint(equalTo: window.topAnchor, constant: 20),
                field.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
                field.widthAnchor.constraint(equalToConstant: 320),
            ])
            window.layoutIfNeeded()

            #expect(field.valueLine.activeSweep != nil)
            #expect(skeletonViews(in: picker).isEmpty)
        }
    }

    /// A picker keeps its own label and chevron; the value after the label is what shimmers.
    @Test func pickerKeepsItsLabelAndChevron() {
        withTheme {
            let row = SkeletonPickerRow(label: "Area").makeView() as! SkeletonFieldChrome
            laidOut(row)

            #expect(row.label?.text == "Area")
            #expect(row.chevronView != nil)
            #expect(frame(of: row.label, in: row).minX == 14)
            #expect(abs(frame(of: row.chevronView, in: row).maxX - (320 - 14)) < 0.001)

            let line = frame(of: row.valueLine, in: row)
            let label = frame(of: row.label, in: row)
            #expect(line.minX > label.maxX)
            #expect(line.maxX <= frame(of: row.chevronView, in: row).minX)
            #expect(abs((row.valueWidthConstraint?.multiplier ?? 0) - 0.4) < 0.001)
        }
    }

    @Test func overridesBeatTheThemeDefaults() {
        withTheme {
            let field = SkeletonField(
                valueWidthFraction: 0.3,
                height: 40,
                radius: 8,
                padding: 6
            ).makeView() as! SkeletonFieldChrome
            laidOut(field)

            #expect(field.resolvedHeight == 40)
            #expect(field.layer.cornerRadius == 8)
            #expect(frame(of: field.valueLine, in: field).minX == 6)
            #expect(abs((field.valueWidthConstraint?.multiplier ?? 0) - 0.3) < 0.001)
        }
    }

    @Test func presetsKeepTheFieldsChrome() {
        withTheme {
            #expect(SkeletonPreset.formField.makeView() is SkeletonFieldChrome)

            let picker = SkeletonPreset.pickerRow.makeView() as? SkeletonFieldChrome
            #expect(picker?.chevronView != nil)
        }
    }

    /// The field's own text does not add a second VoiceOver element: the layout stays one "Loading".
    @Test func layoutStaysOneLoadingElement() {
        withTheme {
            let layout = SkeletonLayout {
                SkeletonField(placeholder: "Full name")
                SkeletonPickerRow(label: "Area")
            }.makeView()

            #expect(layout.isAccessibilityElement)
            #expect(layout.accessibilityLabel == SkeletonTheme.current.loadingText)
        }
    }

    @Test func defaultFieldColoursFollowBothAppearances() {
        let theme = SkeletonTheme()
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)

        #expect(theme.fieldSurface.resolvedColor(with: light) != theme.fieldSurface.resolvedColor(with: dark))
        #expect(theme.fieldBorder.resolvedColor(with: light) != theme.fieldBorder.resolvedColor(with: dark))
    }
}
