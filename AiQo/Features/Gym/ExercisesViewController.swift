import UIKit
import HealthKit

// MARK: - Delegate
protocol ExercisesViewControllerDelegate: AnyObject {
    func didSelectExercise(name: String, activityType: HKWorkoutActivityType, location: HKWorkoutSessionLocationType)
}

// MARK: - Model
struct GymExercise {
    let title: String
    let icon: String
    let color: UIColor
    let type: HKWorkoutActivityType
    let location: HKWorkoutSessionLocationType
}

// MARK: - VC
final class ExercisesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    weak var delegate: ExercisesViewControllerDelegate?

    private let exercises: [GymExercise] = [
        GymExercise(title: "Gratitude", icon: "sparkles",
                    color: UIColor(red: 0.93, green: 0.82, blue: 0.63, alpha: 1.0),
                    type: .mindAndBody, location: .unknown),

        GymExercise(title: "Walk inside", icon: "figure.walk",
                    color: UIColor(red: 0.77, green: 0.93, blue: 0.87, alpha: 1.0),
                    type: .walking, location: .indoor),

        GymExercise(title: "Walking outside", icon: "figure.walk",
                    color: UIColor(red: 0.93, green: 0.82, blue: 0.63, alpha: 1.0),
                    type: .walking, location: .outdoor),

        GymExercise(title: "Running indoor", icon: "figure.run",
                    color: UIColor(red: 0.77, green: 0.93, blue: 0.87, alpha: 1.0),
                    type: .running, location: .indoor),

        GymExercise(title: "Running outside", icon: "figure.run",
                    color: UIColor(red: 0.93, green: 0.82, blue: 0.63, alpha: 1.0),
                    type: .running, location: .outdoor)
    ]

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupTable()
    }

    private func setupTable() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delaysContentTouches = false
        tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 16, right: 0)

        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(ExerciseCell.self, forCellReuseIdentifier: ExerciseCell.reuseID)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        exercises.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExerciseCell.reuseID, for: indexPath) as! ExerciseCell
        cell.configure(with: exercises[indexPath.row])
        return cell
    }

    // MARK: - Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let ex = exercises[indexPath.row]
        delegate?.didSelectExercise(name: ex.title, activityType: ex.type, location: ex.location)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        104 // قريب من الصورة (كارت طويل شوي)
    }
}

// MARK: - Cell (Pill Card)
final class ExerciseCell: UITableViewCell {

    static let reuseID = "ExerciseCell"

    private let card = UIView()
    private let iconBubble = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    // subtle border
    private let stroke = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        // Card
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.masksToBounds = false

        // Shadow like screenshot
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 18
        card.layer.shadowOffset = CGSize(width: 0, height: 10)

        contentView.addSubview(card)

        // Stroke (thin border, very light)
        stroke.translatesAutoresizingMaskIntoConstraints = false
        stroke.isUserInteractionEnabled = false
        stroke.backgroundColor = .clear
        stroke.layer.cornerRadius = 28
        stroke.layer.cornerCurve = .continuous
        stroke.layer.borderWidth = 1
        stroke.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        card.addSubview(stroke)

        // Icon bubble
        iconBubble.translatesAutoresizingMaskIntoConstraints = false
        iconBubble.layer.cornerRadius = 18
        iconBubble.layer.cornerCurve = .continuous
        iconBubble.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        card.addSubview(iconBubble)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .black
        iconBubble.addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .black
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        card.addSubview(titleLabel)

        // Tap feel (press animation)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        card.addGestureRecognizer(press)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            stroke.topAnchor.constraint(equalTo: card.topAnchor),
            stroke.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stroke.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stroke.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            iconBubble.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconBubble.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBubble.widthAnchor.constraint(equalToConstant: 36),
            iconBubble.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconBubble.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBubble.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconBubble.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -18),
            titleLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // improve shadow shape performance
        card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: card.layer.cornerRadius).cgPath
    }

    func configure(with model: GymExercise) {
        card.backgroundColor = model.color

        titleLabel.text = model.title
        iconView.image = UIImage(systemName: model.icon)

        // make icon match theme but still readable
        iconView.tintColor = .black

        // tiny dynamic contrast tweak for very light colors
        let isVeryLight = model.color.isVeryLight
        titleLabel.textColor = isVeryLight ? .black : .white
        iconView.tintColor = isVeryLight ? .black : .white
        iconBubble.backgroundColor = isVeryLight
            ? UIColor.white.withAlphaComponent(0.35)
            : UIColor.black.withAlphaComponent(0.12)

        stroke.layer.borderColor = UIColor.white.withAlphaComponent(isVeryLight ? 0.55 : 0.22).cgColor
    }

    @objc private func handlePress(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began:
            UIView.animate(withDuration: 0.12) {
                self.card.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                self.card.layer.shadowOpacity = 0.05
            }
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.18) {
                self.card.transform = .identity
                self.card.layer.shadowOpacity = 0.08
            }
        default: break
        }
    }
}

// MARK: - Color helper
private extension UIColor {
    var isVeryLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        // perceived luminance
        let lum = 0.2126*r + 0.7152*g + 0.0722*b
        return lum > 0.78
    }
}
