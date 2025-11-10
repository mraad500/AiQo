import UIKit

final class GymViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gym"
        view.backgroundColor = Colors.bg
        let empty = EmptyStateView()
        view.addSubview(empty); empty.pinToEdges(of: view)
    }
}
