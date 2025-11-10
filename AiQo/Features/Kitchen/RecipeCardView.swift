import UIKit

final class RecipeCardView: UIView {
    private let title = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        let bg = GlassCardView()
        addSubview(bg); bg.pinToEdges(of: self)
        title.font = .boldSystemFont(ofSize: 18)
        title.text = "AI Meal"
        bg.contentView.addSubview(title)
        title.pinToEdges(of: bg.contentView, insets: .init(top: 16, leading: 16, bottom: 16, trailing: 16))
        heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
}
