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
    @Binding var selection: ClubTopTab

    var body: some View {
        NativeSegmentedControl(
            items: ClubTopTab.allCases,
            selection: $selection,
            title: \.localizedTitle,
            accessibilityLabel: L10n.t("club_top_tabs_accessibility"),
            controlScaleY: 1.18
        )
        .frame(maxWidth: .infinity, minHeight: 42)
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

private struct NativeSegmentedControl<Item: Hashable>: UIViewRepresentable {
    let items: [Item]
    @Binding var selection: Item
    let title: KeyPath<Item, String>
    let accessibilityLabel: String
    let controlScaleY: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, items: items)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: items.map { $0[keyPath: title] })
        control.apportionsSegmentWidthsByContent = false
        control.accessibilityLabel = accessibilityLabel
        applyColors(to: control)
        if let selectedIndex = items.firstIndex(of: selection) {
            control.selectedSegmentIndex = selectedIndex
        }
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.secondaryLabel,
            .font: ClubSegmentedControlAppearance.segmentedFont(weight: .heavy)
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: ClubSegmentedControlAppearance.segmentedFont(weight: .black)
        ], for: .selected)
        control.transform = CGAffineTransform(scaleX: 1, y: controlScaleY)
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.items = items

        for (index, item) in items.enumerated() {
            let newTitle = item[keyPath: title]
            if control.titleForSegment(at: index) != newTitle {
                control.setTitle(newTitle, forSegmentAt: index)
            }
        }

        if let selectedIndex = items.firstIndex(of: selection), control.selectedSegmentIndex != selectedIndex {
            control.selectedSegmentIndex = selectedIndex
        }

        control.accessibilityLabel = accessibilityLabel
        applyColors(to: control)
    }

    private func applyColors(to control: UISegmentedControl) {
        let baseColor = UIColor.systemGray6.withAlphaComponent(0.95)
        let selectedColor = Colors.accent

        control.backgroundColor = baseColor
        control.selectedSegmentTintColor = selectedColor
        control.tintColor = selectedColor
        control.setBackgroundImage(nil, for: .normal, barMetrics: .default)
        control.setBackgroundImage(nil, for: .selected, barMetrics: .default)
        control.setBackgroundImage(nil, for: .highlighted, barMetrics: .default)
        control.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        control.setDividerImage(nil, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        control.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
        control.layer.cornerCurve = .continuous
        control.layer.cornerRadius = 16
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
            selection = items[index]
        }
    }
}

struct ClubSegmentedControlStyleScope: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                ClubSegmentedControlAppearance.apply()
            }
            .onDisappear {
                ClubSegmentedControlAppearance.reset()
            }
    }
}

extension View {
    func clubSegmentedControlStyleScope() -> some View {
        modifier(ClubSegmentedControlStyleScope())
    }
}

private enum ClubSegmentedControlAppearance {
    private struct Snapshot {
        let backgroundColor: UIColor?
        let selectedSegmentTintColor: UIColor?
        let normalAttributes: [NSAttributedString.Key: Any]?
        let selectedAttributes: [NSAttributedString.Key: Any]?
    }

    private static var baseSnapshot: Snapshot?
    private static var navigationSnapshot: Snapshot?
    private static var activeScopes = 0

    static func apply() {
        activeScopes += 1
        guard activeScopes == 1 else { return }

        let baseAppearance = UISegmentedControl.appearance()
        let navigationAppearance = UISegmentedControl.appearance(whenContainedInInstancesOf: [UINavigationBar.self])

        baseSnapshot = capture(from: baseAppearance)
        navigationSnapshot = capture(from: navigationAppearance)

        applyStyle(to: baseAppearance, heightScale: 1.0)
        applyStyle(to: navigationAppearance, heightScale: 1.08)
    }

    static func reset() {
        guard activeScopes > 0 else { return }
        activeScopes -= 1
        guard activeScopes == 0 else { return }

        let baseAppearance = UISegmentedControl.appearance()
        let navigationAppearance = UISegmentedControl.appearance(whenContainedInInstancesOf: [UINavigationBar.self])

        restore(baseAppearance, from: baseSnapshot)
        restore(navigationAppearance, from: navigationSnapshot)

        baseSnapshot = nil
        navigationSnapshot = nil
    }

    static func segmentedFont(weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: 17, weight: weight).fontDescriptor
        let roundedDescriptor = descriptor.withDesign(.rounded) ?? descriptor
        let baseFont = UIFont(descriptor: roundedDescriptor, size: 17)
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: baseFont)
    }

    private static func capture(from appearance: UISegmentedControl) -> Snapshot {
        Snapshot(
            backgroundColor: appearance.backgroundColor,
            selectedSegmentTintColor: appearance.selectedSegmentTintColor,
            normalAttributes: appearance.titleTextAttributes(for: .normal),
            selectedAttributes: appearance.titleTextAttributes(for: .selected)
        )
    }

    private static func applyStyle(to appearance: UISegmentedControl, heightScale: CGFloat) {
        let baseColor = UIColor.systemGray6.withAlphaComponent(0.95)
        let selectedColor = Colors.accent

        appearance.selectedSegmentTintColor = selectedColor
        appearance.backgroundColor = baseColor
        appearance.setBackgroundImage(nil, for: .normal, barMetrics: .default)
        appearance.setBackgroundImage(nil, for: .selected, barMetrics: .default)
        appearance.setBackgroundImage(nil, for: .highlighted, barMetrics: .default)
        appearance.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        appearance.setDividerImage(nil, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        appearance.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.secondaryLabel,
            .font: segmentedFont(weight: .heavy)
        ], for: .normal)
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: segmentedFont(weight: .black)
        ], for: .selected)
        appearance.setContentPositionAdjustment(.init(horizontal: 0, vertical: heightScale > 1 ? -1 : 0), forSegmentType: .any, barMetrics: .default)
    }

    private static func restore(_ appearance: UISegmentedControl, from snapshot: Snapshot?) {
        appearance.backgroundColor = snapshot?.backgroundColor
        appearance.selectedSegmentTintColor = snapshot?.selectedSegmentTintColor
        appearance.setBackgroundImage(nil, for: .normal, barMetrics: .default)
        appearance.setBackgroundImage(nil, for: .selected, barMetrics: .default)
        appearance.setBackgroundImage(nil, for: .highlighted, barMetrics: .default)
        appearance.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        appearance.setDividerImage(nil, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        appearance.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
        appearance.setTitleTextAttributes(snapshot?.normalAttributes, for: .normal)
        appearance.setTitleTextAttributes(snapshot?.selectedAttributes, for: .selected)
    }
}
