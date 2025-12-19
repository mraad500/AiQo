import UIKit

final class AppSettingsViewController: UIViewController {
    
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    
    private enum Row: Int, CaseIterable {
        case notifications
        case units
        case language
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Settings"
        view.backgroundColor = .systemBackground
        
        table.dataSource = self
        table.delegate = self
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension AppSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "AiQo Settings"
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        guard let row = Row(rawValue: indexPath.row) else { return cell }
        
        switch row {
        case .notifications:
            cell.textLabel?.text = "Notifications"
            cell.detailTextLabel?.text = "Reminders from Captain Hamoudi"
            cell.accessoryType = .disclosureIndicator
        case .units:
            cell.textLabel?.text = "Units"
            cell.detailTextLabel?.text = "kg, cm (coming soon)"
            cell.accessoryType = .disclosureIndicator
        case .language:
            cell.textLabel?.text = "Language"
            cell.detailTextLabel?.text = "Arabic / English (soon)"
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // حالياً بس نعرض Alert لحد ما تكمل المزايا
        let alert = UIAlertController(
            title: "Soon",
            message: "راح نضيف إعدادات تفصيلية هنا بالنسخ الجاية من AiQo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
