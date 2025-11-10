import UIKit

final class MetricDetailViewController: UIViewController {
    private let metricTitle: String
    init(title: String) { self.metricTitle = title; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.bg
        title = metricTitle
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(EmptyStateView())
        view.subviews.first?.pinToEdges(of: view)
    }
}
