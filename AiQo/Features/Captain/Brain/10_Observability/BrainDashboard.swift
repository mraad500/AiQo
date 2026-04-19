#if DEBUG
import Foundation
import SwiftUI

struct BrainDashboard: View {
    @State private var semanticCount = 0
    @State private var episodicCount = 0
    @State private var emotionalCount = 0
    @State private var relationshipCount = 0
    @State private var proceduralCount = 0
    @State private var tier = "-"
    @State private var safetySignals24h = 0
    @State private var notificationsSentToday = 0
    @State private var auditEntries = 0
    @State private var triggerSnapshots: [TriggerEvaluator.DebugSnapshot] = []
    @State private var referralRegion = "-"
    @State private var refreshing = false

    var body: some View {
        List {
            Section("Brain State") {
                LabeledContent("Tier", value: tier)
                LabeledContent("Dev Override", value: DevOverride.unlockAllFeatures ? "ON" : "OFF")
                LabeledContent("Referral Region", value: referralRegion)
            }

            Section("Memory Stores") {
                LabeledContent("Semantic facts", value: "\(semanticCount)")
                LabeledContent("Episodic entries", value: "\(episodicCount)")
                LabeledContent("Emotional memories", value: "\(emotionalCount)")
                LabeledContent("Relationships", value: "\(relationshipCount)")
                LabeledContent("Procedural patterns", value: "\(proceduralCount)")
            }

            Section("Safety") {
                LabeledContent("Signals in 24h", value: "\(safetySignals24h)")
                LabeledContent("Audit entries", value: "\(auditEntries)")
            }

            Section("Triggers") {
                LabeledContent("Registered", value: "\(triggerSnapshots.count)")

                ForEach(triggerSnapshots.prefix(12)) { snapshot in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(snapshot.id)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(snapshot.score.map { String(format: "%.2f", $0) } ?? "silent")
                                .foregroundStyle(.secondary)
                        }

                        Text(snapshot.kind)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let reason = snapshot.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Feature Flags") {
                LabeledContent("MEMORY_V4_ENABLED", value: FeatureFlags.memoryV4Enabled ? "true" : "false")
                LabeledContent("CAPTAIN_BRAIN_V2_ENABLED", value: FeatureFlags.brainV2Enabled ? "true" : "false")
                LabeledContent("HAMOUDI_BLEND_ENABLED", value: FeatureFlags.hamoudiBlendEnabled ? "true" : "false")
                LabeledContent("TRIBE_SUB_GATE_ENABLED", value: FeatureFlags.tribeSubscriptionGateEnabled ? "true" : "false")
                LabeledContent("Notifications today", value: "\(notificationsSentToday)")
            }

            Section {
                Button(refreshing ? "Refreshing..." : "Refresh") {
                    Task { await refresh() }
                }
                .disabled(refreshing)
            }
        }
        .navigationTitle("Brain Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        refreshing = true
        defer { refreshing = false }

        async let semantic = SemanticStore.shared.count()
        async let episodic = EpisodicStore.shared.count()
        async let emotional = EmotionalStore.shared.count()
        async let relationship = RelationshipStore.shared.count()
        async let procedural = ProceduralStore.shared.count()
        async let triggerData = TriggerEvaluator.shared.debugSnapshot()
        async let sentToday = GlobalBudget.shared.sentTodayCount()
        async let safetyCount = SafetyNet.shared.signalCount(
            in: 24 * 60 * 60,
            minimumSeverity: .watchful
        )
        async let auditCount = AuditLogger.shared.recentEntries(limit: 200).count

        semanticCount = await semantic
        episodicCount = await episodic
        emotionalCount = await emotional
        relationshipCount = await relationship
        proceduralCount = await procedural
        triggerSnapshots = await triggerData
        notificationsSentToday = await sentToday
        safetySignals24h = await safetyCount
        auditEntries = await auditCount
        referralRegion = ProfessionalReferral.detectRegion().rawValue.uppercased()
        tier = TierGate.shared.currentTier.displayName
    }
}

#Preview {
    NavigationStack {
        BrainDashboard()
    }
}
#endif
