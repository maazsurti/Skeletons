import Skeletons
import UIKit

/// One post in the feed: a card with an avatar, a name, two lines of copy and a photo.
final class PostCell: UIView {

    let avatar = UIImageView()
    let name = UILabel()
    let headline = UILabel()
    let body = UILabel()
    let photo = UIImageView()

    init(post: Post) {
        super.init(frame: .zero)

        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        avatar.backgroundColor = .tertiarySystemFill
        avatar.layer.cornerRadius = 22
        avatar.clipsToBounds = true

        name.text = post.author
        name.font = .preferredFont(forTextStyle: .headline)

        headline.text = post.headline
        headline.font = .preferredFont(forTextStyle: .subheadline)
        headline.textColor = .secondaryLabel
        headline.numberOfLines = 0

        body.text = post.body
        body.font = .preferredFont(forTextStyle: .body)
        body.textColor = .secondaryLabel
        body.numberOfLines = 0

        photo.backgroundColor = .tertiarySystemFill
        photo.layer.cornerRadius = 12
        photo.clipsToBounds = true

        let copy = UIStackView(arrangedSubviews: [name, headline, body])
        copy.axis = .vertical
        copy.spacing = 4

        let header = UIStackView(arrangedSubviews: [avatar, copy])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .top

        let column = UIStackView(arrangedSubviews: [header, photo])
        column.axis = .vertical
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),
            photo.heightAnchor.constraint(equalToConstant: 140),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

struct Post {
    let author: String
    let headline: String
    let body: String

    static let samples = [
        Post(author: "Amina", headline: "A quiet morning", body: "Coffee, a notebook and an hour with nothing to do."),
        Post(author: "Jonas", headline: "New headphones", body: "The sound is warm and the case fits in a coat pocket."),
        Post(author: "Priya", headline: "Back from the coast", body: "Three days of wind, and the best fish I have eaten all year."),
        Post(author: "Tomas", headline: "Late light", body: "The sun came through the kitchen window and stayed for an hour."),
    ]
}

/// The demo's one screen: a feed of cards with a loading toggle, and the theme options the README
/// describes. A theme change rebuilds the skeleton, because a block reads the theme when it is
/// built.
final class FeedViewController: UIViewController {

    private let scroll = UIScrollView()
    private let host = UIView()
    private let page = UIStackView()
    private let controls = UIStackView()

    private let alignmentControl = UISegmentedControl(items: ["Component", "Window"])
    private let angleSlider = UISlider()
    private let angleLabel = UILabel()
    private let rtlSwitch = UISwitch()
    private let coloursSwitch = UISwitch()

    private var switcher: SkeletonSwitcher?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        buildControls()
        buildFeed()
        applyTheme()
    }

    // MARK: - Feed

    private func buildFeed() {
        page.axis = .vertical
        page.spacing = 16
        page.translatesAutoresizingMaskIntoConstraints = false
        page.addArrangedSubview(host)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(page)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            scroll.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -12),
            page.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            page.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            page.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
    }

    /// The skeleton and the content in one frame, one over the other, with a switcher between them.
    private func buildSwitcher() {
        host.subviews.forEach { $0.removeFromSuperview() }

        let skeleton = FeedViewController.skeletonView()
        let content = FeedViewController.contentView()
        for view in [skeleton, content] {
            view.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: host.topAnchor),
                view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
        }

        let switcher = SkeletonSwitcher(skeleton: skeleton, content: content)
        self.switcher = switcher
        switcher.startLoading()

        guard ProcessInfo.processInfo.arguments.contains("--demo-auto") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak switcher] in
            switcher?.showContent()
        }
    }

    /// The screen's own feed, filled with sample data and skeletonized: the real layout, without a
    /// second copy of it.
    private static func skeletonView() -> UIView {
        feedStack().skeletonized()
    }

    private static func contentView() -> UIView {
        feedStack()
    }

    private static func feedStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        for post in Post.samples {
            stack.addArrangedSubview(PostCell(post: post))
        }
        return stack
    }

    // MARK: - Controls

    private func buildControls() {
        let loadingButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
            self?.toggleLoading()
        })
        loadingButton.setTitle("Toggle loading", for: .normal)
        loadingButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)

        alignmentControl.selectedSegmentIndex = 1
        alignmentControl.addAction(UIAction { [weak self] _ in self?.applyTheme() }, for: .valueChanged)

        angleSlider.minimumValue = -80
        angleSlider.maximumValue = 80
        angleSlider.value = 20
        angleSlider.addAction(UIAction { [weak self] _ in self?.applyTheme() }, for: .valueChanged)
        angleLabel.font = .preferredFont(forTextStyle: .caption1)
        angleLabel.textColor = .secondaryLabel

        rtlSwitch.addAction(UIAction { [weak self] _ in self?.applyTheme() }, for: .valueChanged)
        coloursSwitch.addAction(UIAction { [weak self] _ in self?.applyTheme() }, for: .valueChanged)

        let angleRow = UIStackView(arrangedSubviews: [angleLabel, angleSlider])
        angleRow.axis = .vertical
        angleRow.spacing = 2

        controls.axis = .vertical
        controls.spacing = 10
        controls.isLayoutMarginsRelativeArrangement = true
        controls.layoutMargins = UIEdgeInsets(top: 12, left: 18, bottom: 18, right: 18)
        controls.backgroundColor = .secondarySystemGroupedBackground
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.addArrangedSubview(loadingButton)
        controls.addArrangedSubview(alignmentControl)
        controls.addArrangedSubview(angleRow)
        controls.addArrangedSubview(row(title: "Right to left", control: rtlSwitch))
        controls.addArrangedSubview(row(title: "Custom colours", control: coloursSwitch))

        view.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func row(title: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline)
        let row = UIStackView(arrangedSubviews: [label, UIView(), control])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    private func toggleLoading() {
        guard let switcher else { return }
        if switcher.isSkeletonVisible {
            switcher.showContent()
        } else {
            switcher.startLoading()
        }
    }

    // MARK: - Theme

    private func applyTheme() {
        let isRightToLeft = rtlSwitch.isOn
        let angle = CGFloat(angleSlider.value.rounded())
        angleLabel.text = "Stripe angle: \(Int(angle))°"
        view.semanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight

        SkeletonTheme.current = SkeletonTheme(
            base: coloursSwitch.isOn
                ? UIColor(red: 0.15, green: 0.24, blue: 0.42, alpha: 1)
                : SkeletonTheme.defaultBase,
            highlight: coloursSwitch.isOn
                ? UIColor(red: 0.55, green: 0.75, blue: 1, alpha: 1)
                : SkeletonTheme.defaultHighlight,
            shimmerAlignment: alignmentControl.selectedSegmentIndex == 1 ? .window : .component,
            shimmerAngle: angle,
            isRightToLeft: { isRightToLeft }
        )

        buildSwitcher()
    }
}
