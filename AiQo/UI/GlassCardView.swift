import UIKit

final class GlassCardView: UIVisualEffectView {

    init() {
        let effect = UIBlurEffect(style: .systemThinMaterial)
        super.init(effect: effect)
        layer.cornerRadius = 22
        layer.masksToBounds = true
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        contentView.layer.borderWidth = 0.6
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
    }
}
