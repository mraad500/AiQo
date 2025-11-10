import UIKit

final class CaptainViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Captain"
        view.backgroundColor = Colors.bg
        view.addSubview(EmptyStateView())
        view.subviews.first?.pinToEdges(of: view)
    }
}
