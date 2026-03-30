import SwiftUI
import UIKit

protocol ClubSegmentedTabItem: Hashable {
    var titleKey: String { get }
    var accessibilityLabelKey: String { get }
    var accessibilityHintKey: String { get }
}

extension ClubSegmentedTabItem {
    var localizedTitle: String { L10n.t(titleKey) }
    var localizedAccessibilityLabel: String { L10n.t(accessibilityLabelKey) }
    var localizedAccessibilityHint: String { L10n.t(accessibilityHintKey) }
}

struct PrimarySegmentedTabs: View {
    let tabs: [ClubTopTab]
    @Binding var selection: ClubTopTab

    var body: some View {
        ClubNativeSegmentedControl(
            items: tabs,
            selection: $selection,
            title: \.localizedTitle,
            accessibilityLabel: L10n.t("club_top_tabs_accessibility")
        )
        .frame(maxWidth: .infinity)
    }
}

struct SecondarySegmentedTabs: View {
    @Binding var selection: ImpactSubTab

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(ImpactSubTab.allCases) { tab in
                Text(verbatim: tab.localizedTitle)
                    .accessibilityLabel(Text(verbatim: tab.localizedAccessibilityLabel))
                    .accessibilityHint(Text(verbatim: tab.localizedAccessibilityHint))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .frame(maxWidth: .infinity)
        .tint(Color.aiqoAccent)
        .accessibilityLabel(Text(verbatim: L10n.t("club.impact_tabs.accessibility.label")))
    }
}

// MARK: - Tall UISegmentedControl subclass

final class TallSegmentedControl: UISegmentedControl {
    private let fixedHeight: CGFloat = 50

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = fixedHeight
        return size
    }
}

// MARK: - Native UISegmentedControl wrapper

struct ClubNativeSegmentedControl<Item: Hashable>: UIViewRepresentable {
    let items: [Item]
    @Binding var selection: Item
    let title: KeyPath<Item, String>
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, items: items)
    }

    func makeUIView(context: Context) -> TallSegmentedControl {
        let control = TallSegmentedControl(items: items.map { $0[keyPath: title] })
        control.apportionsSegmentWidthsByContent = false
        control.accessibilityLabel = accessibilityLabel
        applyStyle(to: control)

        if let selectedIndex = items.firstIndex(of: selection) {
            control.selectedSegmentIndex = selectedIndex
        }

        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        return control
    }

    func updateUIView(_ control: TallSegmentedControl, context: Context) {
        context.coordinator.items = items

        for (index, item) in items.enumerated() {
            let newTitle = item[keyPath: title]
            if control.titleForSegment(at: index) != newTitle {
                control.setTitle(newTitle, forSegmentAt: index)
            }
        }

        if let selectedIndex = items.firstIndex(of: selection),
           control.selectedSegmentIndex != selectedIndex {
            control.selectedSegmentIndex = selectedIndex
        }

        control.accessibilityLabel = accessibilityLabel
    }

    private func applyStyle(to control: UISegmentedControl) {
        // Background: light gray
        control.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.9)

        // Selected bubble
        control.selectedSegmentTintColor = UIColor(Color(hex: "F9E697"))

        // Typography — sized for 5 tabs
        let normalFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        let selectedFont = UIFont.systemFont(ofSize: 13, weight: .bold)

        control.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: normalFont
        ], for: .normal)

        control.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: selectedFont
        ], for: .selected)

        // Rounded corners
        control.layer.cornerCurve = .continuous
        control.layer.cornerRadius = 14
        control.layer.masksToBounds = true
    }

    final class Coordinator: NSObject {
        @Binding var selection: Item
        var items: [Item]

        init(selection: Binding<Item>, items: [Item]) {
            _selection = selection
            self.items = items
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            let index = sender.selectedSegmentIndex
            guard items.indices.contains(index) else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = items[index]
            }
        }
    }
}
