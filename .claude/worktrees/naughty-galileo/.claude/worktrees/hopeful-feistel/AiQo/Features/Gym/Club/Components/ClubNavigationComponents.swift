import SwiftUI
import UIKit

struct GlobalTopCapsuleTabsView: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        GeometryReader { proxy in
            let controlWidth = TopTabsMetrics.controlWidth(for: proxy.size.width)

            NativeTopCapsuleTabsControl(
                tabs: tabs,
                selection: $selection
            )
            .frame(width: controlWidth, height: TopTabsMetrics.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(x: TopTabsMetrics.horizontalOffset)
            .padding(.top, TopTabsMetrics.topPadding)
        }
        .frame(height: TopTabsMetrics.containerHeight)
        .accessibilityLabel(Text(verbatim: L10n.t("club_top_tabs_accessibility")))
    }
}

private struct NativeTopCapsuleTabsControl: UIViewRepresentable {
    let tabs: [String]
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> NativeTopCapsuleTabsControlView {
        let view = NativeTopCapsuleTabsControlView()
        view.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            context.coordinator.selection = index
        }
        view.update(tabs: tabs, selection: selection)
        return view
    }

    func updateUIView(_ uiView: NativeTopCapsuleTabsControlView, context: Context) {
        uiView.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            context.coordinator.selection = index
        }
        uiView.update(tabs: tabs, selection: selection)
    }

    final class Coordinator {
        @Binding var selection: Int

        init(selection: Binding<Int>) {
            _selection = selection
        }
    }
}

private final class NativeTopCapsuleTabsControlView: UIView {
    private let backgroundBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let segmentedControl = UISegmentedControl()
    private var currentTabs: [String] = []

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        setupBackground()
        setupSegmentedControl()
        setupLayout()
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerCurve = .continuous
        layer.cornerRadius = bounds.height / 2

        backgroundBlurView.layer.cornerCurve = .continuous
        backgroundBlurView.layer.cornerRadius = backgroundBlurView.bounds.height / 2

        segmentedControl.layer.cornerCurve = .continuous
        segmentedControl.layer.cornerRadius = segmentedControl.bounds.height / 2
    }

    func update(tabs: [String], selection: Int) {
        if currentTabs != tabs {
            rebuildSegments(with: tabs)
        } else {
            syncTitles(with: tabs)
        }

        if tabs.indices.contains(selection) {
            if segmentedControl.selectedSegmentIndex != selection {
                segmentedControl.selectedSegmentIndex = selection
            }
        } else {
            segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }

        applyAppearance()
    }

    private func setupBackground() {
        backgroundBlurView.translatesAutoresizingMaskIntoConstraints = false
        backgroundBlurView.clipsToBounds = true
        backgroundBlurView.isUserInteractionEnabled = false
        addSubview(backgroundBlurView)
    }

    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.semanticContentAttribute = .forceRightToLeft
        segmentedControl.apportionsSegmentWidthsByContent = false
        segmentedControl.clipsToBounds = true
        segmentedControl.addTarget(self, action: #selector(selectionDidChange), for: .valueChanged)

        segmentedControl.setContentPositionAdjustment(
            UIOffset(horizontal: 0, vertical: -1),
            forSegmentType: .any,
            barMetrics: .default
        )

        addSubview(segmentedControl)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            backgroundBlurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBlurView.topAnchor.constraint(equalTo: topAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TopTabsMetrics.innerHorizontalInset),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TopTabsMetrics.innerHorizontalInset),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor, constant: TopTabsMetrics.innerVerticalInset),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -TopTabsMetrics.innerVerticalInset)
        ])
    }

    private func rebuildSegments(with tabs: [String]) {
        segmentedControl.removeAllSegments()

        for (index, title) in tabs.enumerated() {
            segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }

        currentTabs = tabs
    }

    private func syncTitles(with tabs: [String]) {
        for (index, title) in tabs.enumerated() where segmentedControl.titleForSegment(at: index) != title {
            segmentedControl.setTitle(title, forSegmentAt: index)
        }
    }

    private func applyAppearance() {
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.48),
            .font: Self.segmentFont(size: 19, weight: .semibold)
        ]

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: Self.segmentFont(size: 20, weight: .bold)
        ]

        segmentedControl.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.78)
        segmentedControl.selectedSegmentTintColor = Colors.accent
        segmentedControl.setTitleTextAttributes(normalAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedAttributes, for: .selected)
    }

    private static func segmentFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        let roundedDescriptor = descriptor.withDesign(.rounded) ?? descriptor
        let font = UIFont(descriptor: roundedDescriptor, size: size)
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: font)
    }

    @objc
    private func selectionDidChange() {
        let index = segmentedControl.selectedSegmentIndex
        guard index != UISegmentedControl.noSegment else { return }
        onSelectionChanged?(index)
    }
}

private enum TopTabsMetrics {
    static let containerHeight: CGFloat = 96
    static let height: CGFloat = 78
    static let maxWidth: CGFloat = 445
    static let horizontalSafetyPadding: CGFloat = 140
    static let topPadding: CGFloat = 10
    static let horizontalOffset: CGFloat = -128

    static let innerHorizontalInset: CGFloat = 7
    static let innerVerticalInset: CGFloat = 7

    static func controlWidth(for availableWidth: CGFloat) -> CGFloat {
        guard availableWidth.isFinite else { return maxWidth }
        let paddedWidth = availableWidth - horizontalSafetyPadding
        return min(max(paddedWidth, 0), maxWidth)
    }
}
