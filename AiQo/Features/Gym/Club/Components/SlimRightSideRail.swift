import SwiftUI
import UIKit

enum ClubChromeLayout {
    static let headerLeadingInset: CGFloat = 16
    static let headerTrailingInset: CGFloat = 2
    static let headerTopPadding: CGFloat = 14
    static let headerBottomPadding: CGFloat = 8

    static let railWidth: CGFloat = 46
    static let trailingLaneWidth: CGFloat = 78
    static let trailingScreenInset: CGFloat = 2
    static let railRightShift: CGFloat = 13
    static let railLocalScreenOffsetX: CGFloat = 1
    static let contentTrailingPadding: CGFloat =
        trailingScreenInset + (trailingLaneWidth / 2) - railRightShift + (railWidth / 2) + 10
    static let railVerticalOffset: CGFloat = 240
}

private func makeRailGlassEffect() -> UIVisualEffect {
    if #available(iOS 26.0, *) {
        return UIGlassEffect()
    }

    return UIBlurEffect(style: .systemUltraThinMaterial)
}

struct SlimRightSideRail: View {
    let items: [RailItem]
    @Binding var selection: Int

    var body: some View {
        GeometryReader { proxy in
            AppleVerticalRailControl(
                items: items,
                selection: $selection
            )
            .frame(width: ClubChromeLayout.railWidth)
            .position(
                x: proxy.size.width - ClubChromeLayout.trailingScreenInset - (ClubChromeLayout.trailingLaneWidth / 2) + ClubChromeLayout.railRightShift,
                y: (proxy.size.height / 2) + ClubChromeLayout.railVerticalOffset
            )
        }
    }
}

private struct AppleVerticalRailControl: UIViewRepresentable {
    let items: [RailItem]
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> AppleVerticalRailControlView {
        let view = AppleVerticalRailControlView()
        view.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                context.coordinator.selection = index
            }
        }
        return view
    }

    func updateUIView(_ uiView: AppleVerticalRailControlView, context: Context) {
        uiView.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                context.coordinator.selection = index
            }
        }
        uiView.update(items: items, selection: selection)
    }

    final class Coordinator {
        @Binding var selection: Int

        init(selection: Binding<Int>) {
            _selection = selection
        }
    }
}

private final class AppleVerticalRailControlView: UIView {
    private let glassView = UIVisualEffectView(effect: makeRailGlassEffect())
    private let stackView = UIStackView()

    private var buttons: [UIButton] = []
    private var currentItems: [RailItem] = []

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.clipsToBounds = true
        addSubview(glassView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        glassView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -6),
            stackView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -6)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let itemHeight: CGFloat = 64
        let spacing = stackView.spacing * CGFloat(max(currentItems.count - 1, 0))
        let height = CGFloat(currentItems.count) * itemHeight + spacing + 12
        return CGSize(width: ClubChromeLayout.railWidth, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = bounds.width / 2
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.borderWidth = 1
        glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.05).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 7)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func update(items: [RailItem], selection: Int) {
        if needsRebuild(for: items) {
            rebuildButtons(with: items)
        }

        currentItems = items
        invalidateIntrinsicContentSize()
        applySelectionState(selection: selection)
    }

    @objc
    private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard currentItems.indices.contains(index), !currentItems[index].isLocked else { return }
        onSelectionChanged?(index)
    }

    private func needsRebuild(for items: [RailItem]) -> Bool {
        guard items.count == currentItems.count else { return true }

        for (lhs, rhs) in zip(items, currentItems) {
            if lhs.id != rhs.id || lhs.title != rhs.title || lhs.icon != rhs.icon {
                return true
            }
        }

        return false
    }

    private func rebuildButtons(with items: [RailItem]) {
        buttons.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            $0.removeFromSuperview()
        }
        buttons.removeAll()

        for (index, item) in items.enumerated() {
            let button = makeButton(for: item, index: index)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }

    private func makeButton(for item: RailItem, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: item.icon)
        configuration.title = item.title
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.baseForegroundColor = UIColor.black.withAlphaComponent(0.82)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
        configuration.titleAlignment = .center
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 14,
            weight: .semibold
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            return outgoing
        }

        button.configuration = configuration
        button.clipsToBounds = true
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 20

        return button
    }

    private func applySelectionState(selection: Int) {
        for (index, button) in buttons.enumerated() {
            guard currentItems.indices.contains(index) else { continue }

            let item = currentItems[index]
            let isSelected = index == selection
            let tint = UIColor(item.tint ?? Color.aiqoAccent)
            let foreground = UIColor.black.withAlphaComponent(isSelected ? 0.90 : 0.82)

            var configuration = isSelected ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: item.icon)
            configuration.title = item.title
            configuration.imagePlacement = .top
            configuration.imagePadding = 5
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
            configuration.titleAlignment = .center
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: 14,
                weight: isSelected ? .bold : .semibold
            )
            configuration.baseForegroundColor = foreground
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 11, weight: isSelected ? .semibold : .medium)
                return outgoing
            }
            if isSelected {
                configuration.baseBackgroundColor = tint.withAlphaComponent(0.74)
            }

            button.configuration = configuration
            button.isEnabled = !item.isLocked
            button.alpha = item.isLocked ? 0.45 : 1
        }
    }
}
