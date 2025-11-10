import UIKit

final class HomeViewController: UIViewController {
    private let health = HealthKitService.shared
    private let scroll = UIScrollView()
    private let grid = UIStackView()
    private let profileButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = Colors.bg
        navigationController?.navigationBar.prefersLargeTitles = true

        scroll.alwaysBounceVertical = true
        view.addSubview(scroll); scroll.pinToEdges(of: view)

        grid.axis = .vertical
        grid.spacing = 12
        grid.isLayoutMarginsRelativeArrangement = true
        grid.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 32, trailing: 16)
        scroll.addSubview(grid); grid.pinToEdges(of: scroll)
        grid.widthAnchor.constraint(equalTo: scroll.widthAnchor).isActive = true

        // profile button (يظهر ورقة من الأسفل)
        profileButton.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
        profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: profileButton)

        // بطاقات
        let steps = MetricView(title: "Steps")
        let kcal  = MetricView(title: "Calories")
        let row = UIStackView(arrangedSubviews: [steps, kcal])
        row.axis = .horizontal; row.spacing = 12; row.distribution = .fillEqually
        grid.addArrangedSubview(row)

        Task { await loadData(steps: steps, kcal: kcal) }
    }

    @objc private func openProfile() {
        Haptics.tap()
        let vc = ProfileViewController()
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    private func loadData(steps: MetricView, kcal: MetricView) async {
        do {
            let s = try await health.todaySteps()
            await MainActor.run {
                steps.updateValue("\(s)")
                kcal.updateValue("—") // placeholder
            }
        } catch {
            Logger.error("Health error: \(error.localizedDescription)")
        }
    }
}
