import UIKit

final class ProfileSheetView: UIView {
    private let name = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        let bg = GlassCardView()
        addSubview(bg); bg.pinToEdges(of: self)
        name.text = "حمّودي"
        name.font = .systemFont(ofSize: 22, weight: .bold)
        bg.contentView.addSubview(name)
        name.pinToEdges(of: bg.contentView, insets: .init(top: 24, leading: 20, bottom: 24, trailing: 20))
    }
    required init?(coder: NSCoder) { fatalError() }
}
