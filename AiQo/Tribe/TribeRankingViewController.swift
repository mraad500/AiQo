import UIKit

// MARK: - Models

struct AiQoTribeMember /*: Sendable*/ {
    let id: UUID
    var rank: Int
    var name: String
    var score: Int
    var country: String
    var avatar: String?
}

// MARK: - Controller

public final class AiQoTribeRankingViewController: UIViewController {

    // UI
    private var headerView: UIView?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private lazy var refresh = UIRefreshControl()

    // Data
    private var members: [AiQoTribeMember] = []
    private var memberLookup: [UUID: AiQoTribeMember] = [:]   // حتى نجيب الـ member من الـ ID بسرعة
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!

    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSheet()
        setupHeader()
        setupTable()
        setupDataSource()
        Task { await loadAndApply(animated: false) }
    }

    // MARK: - UI Setup

    private func setupSheet() {
        view.backgroundColor = .systemBackground
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
    }

    private func setupHeader() {
        let effectView: UIVisualEffectView = {
            if #available(iOS 18.0, *) {
                return UIVisualEffectView(effect: UIGlassEffect())
            } else {
                return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
            }
        }()

        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 22
        effectView.layer.masksToBounds = true
        view.addSubview(effectView)
        headerView = effectView

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            effectView.heightAnchor.constraint(equalToConstant: 86)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Global Tribe Ranking"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .black)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Top AiQo athletes worldwide"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let headerStack = UIStackView(arrangedSubviews: [textStack, closeButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .equalSpacing
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        effectView.contentView.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -16),
            headerStack.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor)
        ])
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(AiQoTribeCell.self, forCellReuseIdentifier: AiQoTribeCell.reuse)

        refresh.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refresh

        view.addSubview(tableView)

        let topAnchor = headerView?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, UUID>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, id in
            guard
                let self,
                let member = self.memberLookup[id],
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: AiQoTribeCell.reuse,
                    for: indexPath
                ) as? AiQoTribeCell
            else {
                return UITableViewCell()
            }

            cell.configure(with: member)
            return cell
        }
    }

    // MARK: - Data / Snapshot

    private func syncLookup() {
        memberLookup = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
    }

    private func applySnapshot(animated: Bool) {
        var snap = NSDiffableDataSourceSnapshot<Int, UUID>()
        snap.appendSections([0])
        let ids = members.map { $0.id }
        snap.appendItems(ids, toSection: 0)
        dataSource.apply(snap, animatingDifferences: animated)
    }

    @objc private func refreshPulled() {
        Task {
            await loadAndApply(animated: true)
            refresh.endRefreshing()
        }
    }

    private func reorderByScore() {
        members.sort { $0.score > $1.score }
        for i in 0..<members.count {
            members[i].rank = i + 1
        }
        syncLookup()
    }

    private func animateRankChanges(old: [UUID: Int], new: [UUID: Int]) {
        for cell in tableView.visibleCells {
            guard let c = cell as? AiQoTribeCell, let id = c.currentID else { continue }
            let oldR = old[id] ?? 0
            let newR = new[id] ?? 0
            if newR < oldR {
                c.animateUp()
            } else if newR > oldR {
                c.animateDown()
            }
        }
    }

    private func rankMap(_ arr: [AiQoTribeMember]) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0.rank) })
    }

    // MARK: - Demo / Fetch

    private func seedDemoIfNeeded() {
        guard members.isEmpty else { return }

        let base: [(String, String)] = [
            ("Hamoodi", "🇮🇶"), ("Aisha", "🇦🇪"), ("Liam", "🇬🇧"), ("Sofia", "🇪🇸"),
            ("Kenji", "🇯🇵"), ("Maya", "🇮🇳"), ("Jon", "🇺🇸"), ("Luca", "🇮🇹")
        ]

        members = base.enumerated().map { i, p in
            AiQoTribeMember(
                id: UUID(),
                rank: i + 1,
                name: p.0,
                score: Int.random(in: 900...2400),
                country: p.1,
                avatar: String(p.0.prefix(1))
            )
        }

        reorderByScore()    // جوّاها syncLookup()
    }

    private func bumpRandomScoresForDemo() {
        guard !members.isEmpty else { return }
        for i in 0..<members.count where Int.random(in: 0...4) == 0 {
            members[i].score += Int.random(in: 5...60)
        }
        reorderByScore()
    }

    /// اربطها لاحقًا بـ Supabase
    private func fetchFromServer() async -> [AiQoTribeMember]? {
        nil
    }

    private func loadAndApply(animated: Bool) async {
        if let remote = await fetchFromServer() {
            members = remote
        } else {
            if members.isEmpty {
                seedDemoIfNeeded()
            } else {
                bumpRandomScoresForDemo()
            }
        }

        let oldMap = rankMap(members)
        reorderByScore()
        let newMap = rankMap(members)

        applySnapshot(animated: animated)

        if animated {
            animateRankChanges(old: oldMap, new: newMap)
        }
    }

    // MARK: - Actions

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// MARK: - Table Delegate

extension AiQoTribeRankingViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView,
                          heightForRowAt indexPath: IndexPath) -> CGFloat {
        74
    }
}

// MARK: - Cell

final class AiQoTribeCell: UITableViewCell {
    static let reuse = "AiQoTribeCell"
    var currentID: UUID?

    private let rankBadge = UILabel()
    private let avatar = UILabel()
    private let nameLabel = UILabel()
    private let scoreLabel = AiQoCountingLabel()
    private let countryLabel = UILabel()
    private let glassBG = UIVisualEffectView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        let effect: UIVisualEffect = {
            if #available(iOS 18.0, *) {
                return UIGlassEffect()
            } else {
                return UIBlurEffect(style: .systemThinMaterial)
            }
        }()

        glassBG.effect = effect
        glassBG.layer.cornerRadius = 18
        glassBG.layer.masksToBounds = true
        glassBG.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassBG)

        NSLayoutConstraint.activate([
            glassBG.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            glassBG.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            glassBG.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            glassBG.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        rankBadge.font = .boldSystemFont(ofSize: 18)
        rankBadge.textAlignment = .center
        rankBadge.widthAnchor.constraint(equalToConstant: 36).isActive = true

        avatar.font = .boldSystemFont(ofSize: 18)
        avatar.textAlignment = .center
        avatar.backgroundColor = UIColor(white: 0.95, alpha: 1)
        avatar.layer.cornerRadius = 16
        avatar.layer.masksToBounds = true
        avatar.widthAnchor.constraint(equalToConstant: 32).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 32).isActive = true

        nameLabel.font = .boldSystemFont(ofSize: 17)
        countryLabel.font = .systemFont(ofSize: 13)
        countryLabel.textColor = .secondaryLabel

        scoreLabel.font = .boldSystemFont(ofSize: 20)
        scoreLabel.textAlignment = .right

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, countryLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 2

        let h = UIStackView(arrangedSubviews: [
            rankBadge,
            avatar,
            nameStack,
            UIView(),
            scoreLabel
        ])

        h.alignment = .center
        h.spacing = 12
        h.translatesAutoresizingMaskIntoConstraints = false
        glassBG.contentView.addSubview(h)

        NSLayoutConstraint.activate([
            h.leadingAnchor.constraint(equalTo: glassBG.leadingAnchor, constant: 12),
            h.trailingAnchor.constraint(equalTo: glassBG.trailingAnchor, constant: -12),
            h.topAnchor.constraint(equalTo: glassBG.topAnchor, constant: 10),
            h.bottomAnchor.constraint(equalTo: glassBG.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: AiQoTribeMember) {
        currentID = item.id
        rankBadge.text = "\(item.rank)"
        avatar.text = item.avatar ?? "🙂"
        nameLabel.text = item.name
        countryLabel.text = item.country
        scoreLabel.setValue(item.score, animated: true)
    }

    func animateUp() {
        UIView.animate(withDuration: 0.22, animations: {
            self.transform = CGAffineTransform(translationX: 0, y: -6)
                .scaledBy(x: 1.02, y: 1.02)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18) {
                self.transform = .identity
            }
        })
    }

    func animateDown() {
        UIView.animate(withDuration: 0.22, animations: {
            self.transform = CGAffineTransform(translationX: 0, y: 6)
                .scaledBy(x: 0.98, y: 0.98)
            self.contentView.alpha = 0.96
        }, completion: { _ in
            UIView.animate(withDuration: 0.18) {
                self.transform = .identity
                self.contentView.alpha = 1
            }
        })
    }
}

// MARK: - Counting Label

final class AiQoCountingLabel: UILabel {
    private var displayLink: CADisplayLink?
    private var startValue: Double = 0
    private var endValue: Double = 0
    private var startTime: CFTimeInterval = 0
    private let duration: CFTimeInterval = 0.45

    func setValue(_ new: Int, animated: Bool) {
        if !animated {
            text = "\(new)"
            return
        }

        displayLink?.invalidate()
        startValue = Double(Int(text ?? "0") ?? 0)
        endValue = Double(new)
        startTime = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .default)
        displayLink = link
    }

    @objc private func step() {
        let t = min(1, (CACurrentMediaTime() - startTime) / duration)
        let eased = 1 - pow(1 - t, 3) // easeOutCubic
        let value = startValue + (endValue - startValue) * eased
        text = "\(Int(value.rounded()))"

        if t >= 1 {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}
