import UIKit

final class CardDetailViewController: UIViewController {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    private func setupView() {
        view.backgroundColor = .clear
        
        let effectView: UIVisualEffectView
        if #available(iOS 18.0, *) {
            effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 24
        effectView.layer.masksToBounds = true
        view.addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        titleLabel.text = "Card Details"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = "More info about this metric"
        valueLabel.textColor = .secondaryLabel
        valueLabel.font = .systemFont(ofSize: 16)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        effectView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor)
        ])
    }
}
