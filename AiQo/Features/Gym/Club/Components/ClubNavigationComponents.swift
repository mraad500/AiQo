import SwiftUI
import UIKit

private func makeTopGlassEffect() -> UIVisualEffect {
    if #available(iOS 26.0, *) {
        return UIGlassEffect()
    }

    return UIBlurEffect(style: .systemUltraThinMaterial)
}

struct GlobalTopCapsuleTabsView: View {
    let tabs: [String]
    let selectedTints: [Color]
    @Binding var selection: Int

    var body: some View {
        AppleTopRailLikeTabsControl(
            titles: tabs,
            selectedTints: selectedTints,
            selection: $selection
        )
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }
}

private struct AppleTopRailLikeTabsControl: UIViewRepresentable {
    let titles: [String]
    let selectedTints: [Color]
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> AppleTopRailLikeTabsView {
        let view = AppleTopRailLikeTabsView()
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

    func updateUIView(_ uiView: AppleTopRailLikeTabsView, context: Context) {
        uiView.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            DispatchQueue.main.async {
                guard context.coordinator.selection != index else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                context.coordinator.selection = index
            }
        }
        uiView.update(
            titles: titles,
            selectedTints: selectedTints,
            selection: selection
        )
    }

    final class Coordinator {
        @Binding var selection: Int

        init(selection: Binding<Int>) {
            _selection = selection
        }
    }
}

private final class AppleTopRailLikeTabsView: UIView {
    private let glassView = UIVisualEffectView(effect: makeTopGlassEffect())
    private let stackView = UIStackView()

    private var buttons: [UIButton] = []
    private var currentTitles: [String] = []
    private var currentSelectedTints: [UIColor] = []

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.clipsToBounds = true
        addSubview(glassView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 8
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
        CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = bounds.height / 2
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.borderWidth = 1
        glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func update(titles: [String], selectedTints: [Color], selection: Int) {
        if titles != currentTitles {
            rebuildButtons(with: titles)
        }

        currentSelectedTints = selectedTints.map(UIColor.init)
        applySelectionState(selection: selection)
    }

    @objc
    private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard currentTitles.indices.contains(index) else { return }
        onSelectionChanged?(index)
    }

    private func rebuildButtons(with titles: [String]) {
        currentTitles = titles

        buttons.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            $0.removeFromSuperview()
        }
        buttons.removeAll()

        for (index, title) in titles.enumerated() {
            let button = makeButton(title: title, index: index)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }

    private func makeButton(title: String, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.clipsToBounds = true
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 20
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.minimumScaleFactor = 0.85
        button.titleLabel?.adjustsFontSizeToFitWidth = true

        var configuration = UIButton.Configuration.glass()
        configuration.title = title
        configuration.titleAlignment = .center
        configuration.baseForegroundColor = .secondaryLabel
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 6, bottom: 10, trailing: 6)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            return outgoing
        }

        button.configuration = configuration
        return button
    }

    private func applySelectionState(selection: Int) {
        guard !buttons.isEmpty else { return }

        let activeIndex = min(max(selection, 0), buttons.count - 1)

        for (index, button) in buttons.enumerated() {
            let isSelected = index == activeIndex
            let selectedTint = resolvedSelectedTint(for: index)

            var configuration = isSelected ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
            configuration.title = currentTitles[index]
            configuration.titleAlignment = .center
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 6, bottom: 10, trailing: 6)
            configuration.baseForegroundColor = isSelected ? UIColor.label : .secondaryLabel
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 16, weight: isSelected ? .semibold : .medium)
                return outgoing
            }
            if isSelected {
                configuration.baseBackgroundColor = selectedTint.withAlphaComponent(0.78)
            }

            button.configuration = configuration
        }
    }

    private func resolvedSelectedTint(for index: Int) -> UIColor {
        guard currentSelectedTints.indices.contains(index) else {
            return UIColor(AiQoColors.mint)
        }

        return currentSelectedTints[index]
    }
}
