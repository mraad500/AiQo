
import UIKit
import HealthKit

// MARK: - TimeScope + Detail Views + Sheet
extension HomeViewController {

    // MARK: TimeScope
    enum TimeScope: Int {
        case day = 0, week, month, year, allTime

        var title: String {
            switch self {
            case .day:     return "Day"
            case .week:    return "Week"
            case .month:   return "Month"
            case .year:    return "Year"
            case .allTime: return "ALL"   // ✅ التعديل هنا
            }
        }

        static var orderedCases: [TimeScope] {
            return [.day, .week, .month, .year, .allTime]
        }

        static var titles: [String] {
            return orderedCases.map { $0.title }
        }
    }

    // MARK: SimpleBarChartView
    final class SimpleBarChartView: UIView {
        private let shape = CAShapeLayer()
        private var values: [Double] = []
        private var maxValue: Double { values.max() ?? 1 }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            layer.addSublayer(shape)
            shape.fillColor = UIColor.label.withAlphaComponent(0.15).cgColor
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setValues(_ v: [Double]) {
            values = v
            setNeedsLayout()
            setNeedsDisplay()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            redraw()
        }

        private func redraw() {
            let p = UIBezierPath()
            guard !values.isEmpty else {
                shape.path = p.cgPath
                return
            }

            let w = bounds.width
            let h = bounds.height
            let gap: CGFloat = 6
            let barW = max(2, (w - gap * CGFloat(values.count + 1)) / CGFloat(values.count))

            for (i, v) in values.enumerated() {
                let x = gap + CGFloat(i) * (barW + gap)
                let ratio = max(0, CGFloat(v / maxValue))
                let bh = ratio * h
                let rect = CGRect(x: x, y: h - bh, width: barW, height: bh).integral
                p.append(UIBezierPath(roundedRect: rect,
                                      cornerRadius: min(barW, 6)))
            }

            shape.path = p.cgPath
        }
    }

    // MARK: MetricDetailCardView
    final class MetricDetailCardView: UIView {
        let kind: MetricKind
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()
        // ✅ نستخدم عناوين الـ TimeScope حتى تبقى موحدة
        private let scopeControl = UISegmentedControl(items: TimeScope.titles)
        private let chart = SimpleBarChartView()
        private let closeButton = UIButton(type: .system)

        var onClose: (() -> Void)?
        var onScopeChange: ((TimeScope) -> Void)?

        init(kind: MetricKind, tint: UIColor) {
            self.kind = kind
            super.init(frame: .zero)
            layer.cornerRadius = 16
            layer.masksToBounds = true

            let effectView: UIVisualEffectView = {
                if #available(iOS 18.0, *) {
                    return UIVisualEffectView(effect: UIGlassEffect())
                } else {
                    return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
                }
            }()
            effectView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(effectView)

            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: topAnchor),
                effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
                effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            titleLabel.text = kind.title
            titleLabel.font = .systemFont(ofSize: 18, weight: .heavy)
            valueLabel.font = .systemFont(ofSize: 28, weight: .heavy)

            closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

            scopeControl.selectedSegmentIndex = 0
            scopeControl.addTarget(self,
                                   action: #selector(scopeChanged),
                                   for: .valueChanged)
            if #available(iOS 15.0, *) {
                scopeControl.selectedSegmentTintColor = tint.withAlphaComponent(0.25)
            }

            let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), closeButton])
            headerStack.axis = .horizontal
            headerStack.alignment = .center

            let vstack = UIStackView(arrangedSubviews: [
                headerStack,
                valueLabel,
                scopeControl,
                chart
            ])
            vstack.axis = .vertical
            vstack.spacing = 12
            vstack.translatesAutoresizingMaskIntoConstraints = false

            effectView.contentView.addSubview(vstack)

            NSLayoutConstraint.activate([
                chart.heightAnchor.constraint(equalToConstant: 120),
                closeButton.widthAnchor.constraint(equalToConstant: 28),
                closeButton.heightAnchor.constraint(equalToConstant: 28),

                vstack.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 14),
                vstack.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 12),
                vstack.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -12),
                vstack.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -14)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setHeaderValue(_ text: String) {
            valueLabel.text = text
        }

        func setSeries(_ values: [Double]) {
            chart.setValues(values)
        }

        @objc private func closeTapped() {
            onClose?()
        }

        @objc private func scopeChanged() {
            let scope = TimeScope(rawValue: scopeControl.selectedSegmentIndex) ?? .day
            onScopeChange?(scope)
        }
    }

    // MARK: MetricSheetController
    final class MetricSheetController: UIViewController {
        private let kind: MetricKind
        private let detail: MetricDetailCardView
        var onScopeChange: ((TimeScope) -> Void)?

        init(kind: MetricKind) {
            self.kind = kind
            self.detail = MetricDetailCardView(kind: kind,
                                               tint: .secondarySystemBackground)
            super.init(nibName: nil, bundle: nil)
            modalPresentationStyle = .pageSheet
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground

            detail.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(detail)

            NSLayoutConstraint.activate([
                detail.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
                detail.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                detail.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                detail.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24),
                detail.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
            ])

            detail.onClose = { [weak self] in
                self?.dismiss(animated: true)
            }
            detail.onScopeChange = { [weak self] scope in
                self?.onScopeChange?(scope)
            }
        }

        func setHeaderText(_ text: String) {
            detail.setHeaderValue(text)
        }

        func update(header: String, series: [Double]) {
            detail.setHeaderValue(header)
            detail.setSeries(series)
        }
    }

    // MARK: - Present Bottom Sheet
    func presentMetricSheet(for kind: MetricKind) {
        let vc = MetricSheetController(kind: kind)

        if let s = currentSummaryCache {
            vc.setHeaderText(formattedHeader(for: kind, from: s))
        }

        vc.onScopeChange = { [weak self, weak vc] scope in
            guard let self, let vc else { return }
            self.loadSeries(for: kind, scope: scope) { values, totalText in
                vc.update(header: totalText, series: values)
            }
        }

        loadSeries(for: kind, scope: .day) { [weak vc] values, totalText in
            vc?.update(header: totalText, series: values)
        }

        presentAsSheet(vc, detents: [.medium(), .large()], initial: .medium())
    }
}
