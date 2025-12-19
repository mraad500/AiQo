import UIKit

final class GlobalRankingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tribe"
        view.backgroundColor = .systemBackground

        // خلفية زجاجية/بلور
        let effectView: UIVisualEffectView = {
            if #available(iOS 18.0, *) {
                return UIVisualEffectView(effect: UIGlassEffect())
            } else {
                return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
            }
        }()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 22
        effectView.layer.masksToBounds = true
        view.addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            effectView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            effectView.heightAnchor.constraint(equalToConstant: 120)
        ])

        // لابل مؤقت (placeholder)
        let label = UILabel()
        label.text = "Global Ranking (placeholder)"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 22, weight: UIFont.Weight.black) // <-- بدل rounded/black
        label.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -16)
        ])
    }
}
