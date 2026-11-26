import Skeletons
import UIKit

/// The README's "what turns into a block" picture: one card as the app draws it, and the same card
/// skeletonized, side by side. Open it with `-screen mapping`.
final class MappingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let real = MappingViewController.card()
        let skeleton = MappingViewController.card().skeletonized()

        let row = UIStackView(arrangedSubviews: [real, skeleton])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .top
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    /// A card with one of each thing the README lists: a label, a photo and a button.
    private static func card() -> UIView {
        let name = UILabel()
        name.text = "Amina"
        name.font = .preferredFont(forTextStyle: .headline)

        let copy = UILabel()
        copy.text = "Coffee and an hour to spare."
        copy.font = .preferredFont(forTextStyle: .subheadline)
        copy.textColor = .secondaryLabel
        copy.numberOfLines = 2

        let photo = UIImageView()
        photo.backgroundColor = .tertiarySystemFill
        photo.layer.cornerRadius = 10
        photo.clipsToBounds = true

        let button = UIButton(type: .system, primaryAction: nil)
        button.setTitle("Read", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.backgroundColor = .secondarySystemFill
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        let column = UIStackView(arrangedSubviews: [name, copy, photo, button])
        column.axis = .vertical
        column.spacing = 10
        column.alignment = .fill

        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)

        NSLayoutConstraint.activate([
            photo.heightAnchor.constraint(equalToConstant: 110),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }
}
