// Features/Kitchen/KitchenViewController.swift

import UIKit
import SwiftUI

final class KitchenViewController: BaseViewController {

    // MARK: - SwiftUI Hosting

    private lazy var hostingController: UIHostingController<KitchenScreen> = {
        // هنا نستخدم الوجبات المحلية بدل Supabase
        let repository: MealsRepository = LocalMealsRepository()
        let viewModel = KitchenViewModel(repository: repository)

        let rootView = KitchenScreen(
            viewModel: viewModel,
            onEditDietTapped: { [weak self] in
                self?.openDietSettings()
            }
        )

        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        return host
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.bg
        embedSwiftUIView()
    }

    // MARK: - Private helpers

    private func embedSwiftUIView() {
        addChild(hostingController)

        guard let hostedView = hostingController.view else { return }
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostedView)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func openDietSettings() {
        // TODO: اربطها بشاشة "تعديل النظام الغذائي" لما تجهز
    }
}
