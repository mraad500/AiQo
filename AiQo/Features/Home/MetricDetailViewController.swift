import UIKit

final class MetricDetailViewController: UIViewController {

    private let kind: MetricKind

    init(kind: MetricKind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        // خلفية زجاجية ناعمة
        let effectView: UIVisualEffectView = {
            if #available(iOS 18.0, *) {
                return UIVisualEffectView(effect: UIGlassEffect())
            } else {
                return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
            }
        }()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 28
        effectView.layer.masksToBounds = true
        view.addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // العنوان
        let title = UILabel()
        title.text = kind.title
        title.font = UIFont.systemFont(ofSize: 28, weight: .black)
        title.numberOfLines = 1

        // النص الثانوي
        let sub = UILabel()
        sub.text = "Today's details from HealthKit"
        sub.textColor = .secondaryLabel
        sub.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        sub.numberOfLines = 0

        // القيمة
        let value = UILabel()
        value.text = "0 \(kind.unit)"
        value.font = UIFont.systemFont(ofSize: 36, weight: .black)
        value.textColor = .label

        // الأيقونة
        let icon = UIImageView(image: UIImage(systemName: kind.icon))
        icon.contentMode = UIView.ContentMode.scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let head = UIStackView(arrangedSubviews: [icon, title])
        head.axis = NSLayoutConstraint.Axis.horizontal
        head.spacing = 10
        head.alignment = UIStackView.Alignment.center

        // كل العناصر داخل عمود
        let stack = UIStackView(arrangedSubviews: [head, sub, value])
        stack.axis = NSLayoutConstraint.Axis.vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        effectView.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -20)
        ])
    }
}
