import SwiftUI

struct BriefingSettingsView: View {
    @State private var morningHeroEnabled: Bool
    @State private var middayPulseEnabled: Bool
    @State private var eveningReflectionEnabled: Bool
    @State private var windDownEnabled: Bool
    @State private var workoutSummaryEnabled: Bool

    private var language: BriefingLanguage {
        BriefingLanguage.from(AppSettingsStore.shared.appLanguage)
    }

    private var isRTL: Bool {
        language == .arabic
    }

    init() {
        let store = BriefingSettingsStore.shared
        _morningHeroEnabled = State(initialValue: store.isEnabled(.morningHero))
        _middayPulseEnabled = State(initialValue: store.isEnabled(.middayPulse))
        _eveningReflectionEnabled = State(initialValue: store.isEnabled(.eveningReflection))
        _windDownEnabled = State(initialValue: store.isEnabled(.windDown))
        _workoutSummaryEnabled = State(initialValue: store.isEnabled(.workoutSummary))
    }

    var body: some View {
        List {
            Section {
                slotToggle(slot: .morningHero, isOn: $morningHeroEnabled)
                slotToggle(slot: .middayPulse, isOn: $middayPulseEnabled)
                slotToggle(slot: .eveningReflection, isOn: $eveningReflectionEnabled)
                slotToggle(slot: .windDown, isOn: $windDownEnabled)
                slotToggle(slot: .workoutSummary, isOn: $workoutSummaryEnabled)
            }

            Section {
                Text(language == .arabic
                     ? "الكابتن يحترم وقتك. أربع رسائل باليوم كحد أقصى."
                     : "Captain respects your time. Maximum 4 messages per day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .navigationTitle(language == .arabic ? "إشعارات الكابتن" : "Captain Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func slotToggle(
        slot: BriefingSlot,
        isOn: Binding<Bool>
    ) -> some View {
        let lang = language
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.displayName(language: lang))
                    .font(.system(.body, design: .rounded, weight: .bold))

                Text(slot.description(language: lang))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(slot.timeLabel(language: lang))
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "B7E5D2"))
            }
            .padding(.vertical, 4)
        }
        .tint(Color(hex: "B7E5D2"))
        .onChange(of: isOn.wrappedValue) { _, enabled in
            BriefingSettingsStore.shared.setEnabled(enabled, for: slot)
            Task {
                await CaptainBriefingScheduler.shared.rescheduleAll()
            }
        }
    }
}

#Preview {
    NavigationStack {
        BriefingSettingsView()
    }
}
