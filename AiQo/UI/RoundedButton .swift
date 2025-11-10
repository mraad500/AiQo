import UIKit
final class RoundedButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configuration = .tinted()
        layer.cornerRadius = 14
    }
    required init?(coder: NSCoder) { fatalError() }
}
