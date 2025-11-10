import UIKit

final class LiveMetricsHeader: UIView {
    private let stack = UIStackView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        let bg = GlassCardView()
        addSubview(bg); bg.pinToEdges(of: self)
        stack.axis = .horizontal; stack.spacing = 12; stack.alignment = .center
        bg.contentView.addSubview(stack); stack.pinToEdges(of: bg.contentView,
            insets: .init(top: 8, leading: 12, bottom: 8, trailing: 12))
    }
    required init?(coder: NSCoder) { fatalError() }
}
