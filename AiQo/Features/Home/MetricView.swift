import UIKit

final class MetricView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        let bg = GlassCardView()
        addSubview(bg); bg.pinToEdges(of: self)
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        valueLabel.font = .systemFont(ofSize: 28, weight: .black)
        valueLabel.text = "--"
        valueLabel.textColor = Colors.text

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical; stack.spacing = 6; stack.alignment = .leading
        bg.contentView.addSubview(stack); stack.pinToEdges(of: bg.contentView,
            insets: .init(top: 12, leading: 12, bottom: 12, trailing: 12))

        heightAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        layer.cornerRadius = 16; clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func updateValue(_ v: String) { valueLabel.text = v }
}
