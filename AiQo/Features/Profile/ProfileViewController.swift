import UIKit

final class ProfileViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.bg
        let sheet = ProfileSheetView()
        view.addSubview(sheet); sheet.pinToEdges(of: view)
    }
}
