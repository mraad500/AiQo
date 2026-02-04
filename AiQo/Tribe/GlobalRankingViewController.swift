import UIKit
import SwiftUI

final class GlobalRankingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tribe"
        view.backgroundColor = .systemBackground

        let screen = TribeRankingScreen()
        let host = UIHostingController(rootView: screen)

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        host.didMove(toParent: self)
    }
}
