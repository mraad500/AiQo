import SwiftUI
import UIKit

enum ClubChromeLayout {
    static let headerLeadingInset: CGFloat = 16
    static let headerTrailingInset: CGFloat = 2
    static let headerTopPadding: CGFloat = 8
    static let headerBottomPadding: CGFloat = 12
    static let topTabsControlHeight: CGFloat = 52
    static let topTabsInnerHeight: CGFloat = 40
    static let topTabsTopSpacing: CGFloat = 6
    static let topTabsMinWidth: CGFloat = 220
    static let topTabsMaxWidth: CGFloat = 340
    static let topChromeHeight: CGFloat =
        headerTopPadding + headerBottomPadding + topTabsTopSpacing + topTabsControlHeight

    static let railWidth: CGFloat = 46
    static let trailingLaneWidth: CGFloat = 78
    static let trailingScreenInset: CGFloat = 2
    static let railRightShift: CGFloat = 13
    static let railLocalScreenOffsetX: CGFloat = 1
    static let contentTrailingPadding: CGFloat =
        trailingScreenInset + (trailingLaneWidth / 2) - railRightShift + (railWidth / 2) + 10
    static let contentTopPadding: CGFloat = 12
}

struct SlimRightSideRailConfiguration: Equatable {
    var maxVisibleItems: Int?
    var railWidth: CGFloat
    var itemHeight: CGFloat
    var titleFontSize: CGFloat
    var titleLineCount: Int
    var symbolPointSize: CGFloat
    var stackSpacing: CGFloat
    var contentInsets: NSDirectionalEdgeInsets
    var horizontalPositionOffset: CGFloat
    var verticalCenterRatio: CGFloat

    static let standard = SlimRightSideRailConfiguration(
        maxVisibleItems: nil,
        railWidth: 46,
        itemHeight: 64,
        titleFontSize: 11,
        titleLineCount: 2,
        symbolPointSize: 14,
        stackSpacing: 10,
        contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2),
        horizontalPositionOffset: 0,
        verticalCenterRatio: 0.78
    )

    static let stageSelector = SlimRightSideRailConfiguration(
        maxVisibleItems: 5,
        railWidth: 32,
        itemHeight: 52,
        titleFontSize: 9,
        titleLineCount: 2,
        symbolPointSize: 11,
        stackSpacing: 7,
        contentInsets: NSDirectionalEdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0),
        horizontalPositionOffset: -12,
        verticalCenterRatio: 0.68
    )
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
    var configuration: SlimRightSideRailConfiguration = .standard

    var body: some View {
        GeometryReader { proxy in
            let railHeight = calculatedRailHeight(for: items.count)
            let availableHeight = proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
            let preferredY = proxy.safeAreaInsets.top + (availableHeight * configuration.verticalCenterRatio)
            let clampedY = min(
                max(preferredY, proxy.safeAreaInsets.top + (railHeight / 2) + 20),
                proxy.size.height - proxy.safeAreaInsets.bottom - (railHeight / 2) - 20
            )

            AppleVerticalRailControl(
                items: items,
                selection: $selection,
                configuration: configuration
            )
            .frame(width: configuration.railWidth)
            .position(
                x: proxy.size.width - ClubChromeLayout.trailingScreenInset - (ClubChromeLayout.trailingLaneWidth / 2) + ClubChromeLayout.railRightShift + configuration.horizontalPositionOffset,
                y: clampedY
            )
        }
    }

    private func calculatedRailHeight(for itemCount: Int) -> CGFloat {
        let visibleItemCount = max(1, min(itemCount, configuration.maxVisibleItems ?? itemCount))
        let spacing = configuration.stackSpacing * CGFloat(max(visibleItemCount - 1, 0))
        return (CGFloat(visibleItemCount) * configuration.itemHeight) + spacing + 12
    }
}

struct ClubStandardRightRailContainer<Content: View>: View {
    let items: [RailItem]
    @Binding var selection: Int
    let accessibilityLabel: Text
    @ViewBuilder let content: () -> Content

    init(
        items: [RailItem],
        selection: Binding<Int>,
        accessibilityLabel: Text,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.items = items
        _selection = selection
        self.accessibilityLabel = accessibilityLabel
        self.content = content
    }

    var body: some View {
        ZStack {
            content()

            SlimRightSideRail(
                items: items,
                selection: $selection
            )
            .offset(x: ClubChromeLayout.railLocalScreenOffsetX)
            .zIndex(1)
            .accessibilityLabel(accessibilityLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct AppleVerticalRailControl: UIViewRepresentable {
    let items: [RailItem]
    @Binding var selection: Int
    let configuration: SlimRightSideRailConfiguration

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> AppleVerticalRailControlView {
        let view = AppleVerticalRailControlView(configuration: configuration)
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
        uiView.update(items: items, selection: selection, configuration: configuration)
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
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private var buttons: [UIButton] = []
    private var currentItems: [RailItem] = []
    private var itemHeightConstraints: [NSLayoutConstraint] = []
    private var railConfiguration: SlimRightSideRailConfiguration
    private var lastAppliedSelection: Int?

    var onSelectionChanged: ((Int) -> Void)?

    init(configuration: SlimRightSideRailConfiguration) {
        railConfiguration = configuration
        super.init(frame: .zero)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.clipsToBounds = true
        addSubview(glassView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.contentInsetAdjustmentBehavior = .never
        glassView.contentView.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -6),
            scrollView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -6),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        applyConfiguration(configuration)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let visibleCount = visibleItemCount
        let spacing = stackView.spacing * CGFloat(max(visibleCount - 1, 0))
        let height = CGFloat(visibleCount) * railConfiguration.itemHeight + spacing + 12
        return CGSize(width: railConfiguration.railWidth, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = bounds.width / 2
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.borderWidth = 1
        glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.035).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func update(items: [RailItem], selection: Int, configuration: SlimRightSideRailConfiguration) {
        if railConfiguration != configuration {
            railConfiguration = configuration
            applyConfiguration(configuration)
            updateButtonMetrics()
            invalidateIntrinsicContentSize()
        }

        if needsRebuild(for: items) {
            rebuildButtons(with: items)
        }

        currentItems = items
        scrollView.isScrollEnabled = shouldEnableScrolling(for: items.count)
        scrollView.alwaysBounceVertical = scrollView.isScrollEnabled
        invalidateIntrinsicContentSize()
        applySelectionState(selection: selection)
        centerSelectedButtonIfNeeded(selection: selection, animated: lastAppliedSelection != nil && lastAppliedSelection != selection)
        lastAppliedSelection = selection
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
        itemHeightConstraints.forEach { $0.isActive = false }
        itemHeightConstraints.removeAll()

        for (index, item) in items.enumerated() {
            let button = makeButton(for: item, index: index)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        updateButtonMetrics()
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
        configuration.contentInsets = railConfiguration.contentInsets
        configuration.titleAlignment = .center
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: railConfiguration.symbolPointSize,
            weight: .semibold
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: self.railConfiguration.titleFontSize, weight: .medium)
            return outgoing
        }

        button.configuration = configuration
        button.clipsToBounds = true
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 20
        button.titleLabel?.numberOfLines = railConfiguration.titleLineCount
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        button.titleLabel?.lineBreakMode = .byWordWrapping

        let heightConstraint = button.heightAnchor.constraint(equalToConstant: railConfiguration.itemHeight)
        heightConstraint.isActive = true
        itemHeightConstraints.append(heightConstraint)

        return button
    }

    private func applySelectionState(selection: Int) {
        for (index, button) in buttons.enumerated() {
            guard currentItems.indices.contains(index) else { continue }

            let item = currentItems[index]
            let isSelected = index == selection
            _ = UIColor(item.tint ?? Color.aiqoAccent)
            let foreground = UIColor.black.withAlphaComponent(isSelected ? 0.90 : 0.82)

            var configuration = isSelected ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: item.icon)
            configuration.title = item.title
            configuration.imagePlacement = .top
            configuration.imagePadding = 5
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
            configuration.titleAlignment = .center
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: railConfiguration.symbolPointSize,
                weight: isSelected ? .bold : .semibold
            )
            configuration.baseForegroundColor = foreground
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(
                    ofSize: self.railConfiguration.titleFontSize,
                    weight: isSelected ? .semibold : .medium
                )
                return outgoing
            }
            configuration.contentInsets = railConfiguration.contentInsets
            if isSelected {
                configuration.baseBackgroundColor = UIColor(red: 1.0, green: 0.902, blue: 0.549, alpha: 0.85) // #FFE68C
            }

            button.configuration = configuration
            button.isEnabled = !item.isLocked
            button.alpha = item.isLocked ? 0.45 : 1
            button.titleLabel?.numberOfLines = railConfiguration.titleLineCount
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.adjustsFontSizeToFitWidth = false
            button.titleLabel?.lineBreakMode = .byWordWrapping
        }
    }

    private var visibleItemCount: Int {
        let maxVisibleItems = railConfiguration.maxVisibleItems ?? currentItems.count
        return max(1, min(currentItems.count, maxVisibleItems))
    }

    private func shouldEnableScrolling(for itemCount: Int) -> Bool {
        guard let maxVisibleItems = railConfiguration.maxVisibleItems else { return false }
        return itemCount > maxVisibleItems
    }

    private func applyConfiguration(_ configuration: SlimRightSideRailConfiguration) {
        stackView.spacing = configuration.stackSpacing
    }

    private func updateButtonMetrics() {
        for constraint in itemHeightConstraints {
            constraint.constant = railConfiguration.itemHeight
        }
    }

    private func centerSelectedButtonIfNeeded(selection: Int, animated: Bool) {
        guard scrollView.isScrollEnabled, buttons.indices.contains(selection) else { return }

        layoutIfNeeded()

        let selectedButton = buttons[selection]
        let targetOffsetY = max(
            0,
            min(
                selectedButton.frame.midY - (scrollView.bounds.height / 2),
                scrollView.contentSize.height - scrollView.bounds.height
            )
        )

        scrollView.setContentOffset(CGPoint(x: 0, y: targetOffsetY), animated: animated)
    }
}
