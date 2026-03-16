import SwiftUI
import UIKit

struct GlobalTopCapsuleTabsView: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        ClubNativeTopTabsControl(
            tabs: tabs,
            selection: $selection
        )
        .frame(height: ClubChromeLayout.topTabsControlHeight)
        .padding(.top, ClubChromeLayout.topTabsTopSpacing)
        .accessibilityLabel(Text(verbatim: L10n.t("club_top_tabs_accessibility")))
    }
}

private struct ClubNativeTopTabsControl: UIViewRepresentable {
    let tabs: [String]
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> ClubNativeTopTabsControlView {
        let view = ClubNativeTopTabsControlView()
        view.onSelectionChanged = { index in
            guard context.coordinator.selection != index else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            context.coordinator.selection = index
        }
        view.update(tabs: tabs, selection: selection)
        return view
    }

    func updateUIView(_ uiView: ClubNativeTopTabsControlView, context: Context) {
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

private final class ClubNativeTopTabsControlView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let control = UISegmentedControl()
    private var currentTabs: [String] = []
    private var widthConstraint: NSLayoutConstraint?

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.clipsToBounds = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.apportionsSegmentWidthsByContent = true
        control.semanticContentAttribute = .forceRightToLeft
        control.selectedSegmentTintColor = Colors.accent
        control.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.78)
        control.setContentPositionAdjustment(
            .init(horizontal: 0, vertical: -1),
            forSegmentType: .any,
            barMetrics: .default
        )
        control.addTarget(self, action: #selector(selectionDidChange(_:)), for: .valueChanged)

        addSubview(blurView)
        blurView.contentView.addSubview(control)

        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            control.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 6),
            control.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -6),
            control.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 6),
            control.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -6),
            control.heightAnchor.constraint(equalToConstant: ClubChromeLayout.topTabsInnerHeight)
        ])

        widthConstraint = blurView.widthAnchor.constraint(equalToConstant: 240)
        widthConstraint?.isActive = true

        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let capsuleRadius = min(bounds.height / 2, 26)
        blurView.layer.cornerCurve = .continuous
        blurView.layer.cornerRadius = capsuleRadius

        control.layer.cornerCurve = .continuous
        control.layer.cornerRadius = min(control.bounds.height / 2, 20)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
    }

    func update(tabs: [String], selection: Int) {
        if currentTabs != tabs {
            rebuildSegments(using: tabs)
        } else {
            syncTitles(with: tabs)
        }

        applyAppearance()
        updatePreferredWidth()

        if tabs.indices.contains(selection) {
            if control.selectedSegmentIndex != selection {
                control.selectedSegmentIndex = selection
            }
        } else {
            control.selectedSegmentIndex = UISegmentedControl.noSegment
        }
    }

    private func rebuildSegments(using tabs: [String]) {
        control.removeAllSegments()

        for (index, title) in tabs.enumerated() {
            control.insertSegment(withTitle: title, at: index, animated: false)
        }

        currentTabs = tabs
    }

    private func syncTitles(with tabs: [String]) {
        for (index, title) in tabs.enumerated() where control.titleForSegment(at: index) != title {
            control.setTitle(title, forSegmentAt: index)
        }
    }

    private func updatePreferredWidth() {
        control.layoutIfNeeded()

        let fittingSize = CGSize(width: UIView.layoutFittingCompressedSize.width, height: ClubChromeLayout.topTabsControlHeight)
        let controlWidth = control.systemLayoutSizeFitting(fittingSize).width
        let targetWidth = min(max(controlWidth + 12, ClubChromeLayout.topTabsMinWidth), ClubChromeLayout.topTabsMaxWidth)

        widthConstraint?.constant = targetWidth
        layoutIfNeeded()
    }

    private func applyAppearance() {
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: Self.segmentFont(size: 17, weight: .semibold)
        ]

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: Self.segmentFont(size: 17, weight: .bold)
        ]

        control.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.78)
        control.selectedSegmentTintColor = Colors.accent
        control.setTitleTextAttributes(normalAttributes, for: .normal)
        control.setTitleTextAttributes(selectedAttributes, for: .selected)
    }

    private static func segmentFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        let roundedDescriptor = descriptor.withDesign(.rounded) ?? descriptor
        let baseFont = UIFont(descriptor: roundedDescriptor, size: size)
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: baseFont)
    }

    @objc
    private func selectionDidChange(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard index != UISegmentedControl.noSegment else { return }
        onSelectionChanged?(index)
    }
}
