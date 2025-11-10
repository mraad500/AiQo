import UIKit

final class KitchenViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kitchen"
        view.backgroundColor = Colors.bg
        let card = RecipeCardView()
        view.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }
}
