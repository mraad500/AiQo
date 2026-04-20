import SwiftUI

struct DeveloperPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accessManager = AccessManager.shared

    var body: some View {
        NavigationStack {
            Form {
                if accessManager.allowsDeveloperOverrides {
                    previewSection
                    statusSection
                    #if DEBUG
                    brainSection
                    #endif
                } else {
                    Section {
                        Text("debug.preview.unavailable".localized)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("debug.preview.navigation".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        Section("debug.preview.section".localized) {
            Toggle(
                "debug.preview.enable".localized,
                isOn: Binding(
                    get: { accessManager.isPreviewModeActive },
                    set: { accessManager.setPreviewEnabled($0) }
                )
            )

            Picker(
                "debug.preview.plan".localized,
                selection: Binding(
                    get: { accessManager.selectedPreviewPlan },
                    set: { accessManager.setSelectedPreviewPlan($0) }
                )
            ) {
                ForEach(PremiumPlan.allCases) { plan in
                    Text(plan.title).tag(plan)
                }
            }
            .disabled(!accessManager.isPreviewModeActive)

            Button(role: .destructive) {
                accessManager.resetPreviewData()
            } label: {
                Text("debug.preview.reset".localized)
            }
        }
    }

    private var statusSection: some View {
        Section("debug.preview.status".localized) {
            statusRow(
                title: "debug.preview.status.tribe".localized,
                value: accessManager.canAccessTribe ? "debug.preview.on".localized : "debug.preview.off".localized
            )
            statusRow(
                title: "debug.preview.status.family".localized,
                value: accessManager.canCreateTribe ? "debug.preview.on".localized : "debug.preview.off".localized
            )
            statusRow(
                title: "debug.preview.status.data".localized,
                value: "debug.preview.liveData".localized
            )
        }
    }

    #if DEBUG
    private var brainSection: some View {
        Section("Brain") {
            NavigationLink("Open Brain Dashboard") {
                BrainDashboard()
            }
        }
    }
    #endif

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DeveloperPanelView()
}
