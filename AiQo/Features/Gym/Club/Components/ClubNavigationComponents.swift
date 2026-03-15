import SwiftUI

struct GlobalTopCapsuleTabsView: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .tag(index)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.regular)
        .tint(Color.aiqoAccent)
        .scaleEffect(y: 1.12)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityLabel(Text(verbatim: L10n.t("club_top_tabs_accessibility")))
        .sensoryFeedback(.selection, trigger: selection)
    }
}
