import UIKit

final class GlassCardView: UIVisualEffectView {
    init() {
        if #available(iOS 18.0, *) {
            super.init(effect: UIGlassEffect())
        } else {
            super.init(effect: UIBlurEffect(style: .systemThinMaterial))
        }
        layer.cornerRadius = 16
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
}
