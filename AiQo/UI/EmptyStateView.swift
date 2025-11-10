import UIKit
final class EmptyStateView: UIView {
    private let title = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        title.text = "No data yet"
        title.textColor = .secondaryLabel
        title.textAlignment = .center
        addSubview(title); title.pinToEdges(of: self, insets: .init(top: 24, leading: 16, bottom: 24, trailing: 16))
    }
    required init?(coder: NSCoder) { fatalError() }
}
