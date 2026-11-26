import Skeletons
import UIKit

/// The skeleton the README builds by hand, drawn on its own: `-screen manual`.
final class ManualSkeletonViewController: UIViewController {

    /// The README's sample, unchanged.
    static var layout: SkeletonLayout {
        SkeletonLayout {
            SkeletonLine(.title)
            SkeletonCard(padding: 14) {
                SkeletonRow(spacing: 14) {
                    SkeletonPhoto(width: 84, height: 64, radius: 12)
                    SkeletonColumn(spacing: 2) {
                        SkeletonLine(.headline, widthFraction: 0.6)
                        SkeletonLine(.body, widthFraction: 0.9)
                    }
                }
            }
            SkeletonRows(count: 5, .listRow, spacing: 12)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let skeleton = ManualSkeletonViewController.layout.makeView()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skeleton)

        NSLayoutConstraint.activate([
            skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            skeleton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            skeleton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
        ])
    }
}
