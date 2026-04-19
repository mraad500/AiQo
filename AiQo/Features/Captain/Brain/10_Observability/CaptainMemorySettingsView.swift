import SwiftUI

/// شاشة إعدادات ذاكرة الكابتن — تعرض كل المعلومات المحفوظة
struct CaptainMemorySettingsView: View {
    @State private var memories: [CaptainMemorySnapshot] = []
    @State private var isEnabled: Bool = MemoryStore.shared.isEnabled
    @State private var showClearConfirmation = false
    @State private var weeklyReports: [WeeklyReportEntry] = []

    private var memoryLimitText: String {
        String(TierGate.shared.currentTier.memoryFactLimit)
    }

    private var groupedMemories: [(String, [CaptainMemorySnapshot])] {
        let grouped = Dictionary(grouping: memories, by: { $0.category })
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            headerSection
            toggleSection

            if isEnabled {
                if !weeklyReports.isEmpty {
                    Section {
                        ForEach(weeklyReports, id: \.id) { report in
                            WeeklyReportRow(report: report)
                        }
                    } header: {
                        Text(NSLocalizedString("memory.cat.weekly", comment: ""))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                }

                ForEach(groupedMemories, id: \.0) { category, items in
                    Section(categoryLabel(category)) {
                        ForEach(items, id: \.id) { memory in
                            memoryRow(memory)
                        }
                        .onDelete { indexSet in
                            deleteMemories(at: indexSet, in: items)
                        }
                    }
                }

                clearSection
            }
        }
        .navigationTitle(NSLocalizedString("memory.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            loadMemories()
            weeklyReports = WeeklyMemoryConsolidator.shared.allReports()
        }
        .alert(NSLocalizedString("memory.clearAll", comment: ""), isPresented: $showClearConfirmation) {
            Button(NSLocalizedString("memory.cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("memory.clearAllButton", comment: ""), role: .destructive) {
                MemoryStore.shared.clearAll()
                loadMemories()
            }
        } message: {
            Text(NSLocalizedString("memory.clearConfirmMessage", comment: ""))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("🧠")
                    .font(.system(size: 40))

                Text(NSLocalizedString("memory.title", comment: ""))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text(NSLocalizedString("memory.subtitle", comment: ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .multilineTextAlignment(.center)

                if !memories.isEmpty {
                    Text(verbatim: "\(memories.count) / \(memoryLimitText)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(GymTheme.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(GymTheme.mint.opacity(0.12)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Toggle

    private var toggleSection: some View {
        Section {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("memory.enable", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                    Text(NSLocalizedString("memory.enableSubtitle", comment: ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: isEnabled) { _, newValue in
                MemoryStore.shared.isEnabled = newValue
            }
        }
    }

    // MARK: - Memory Row

    private func memoryRow(_ memory: CaptainMemorySnapshot) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                confidenceBadge(memory.confidence)
                Spacer()
                Text(keyLabel(memory.key))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }

            Text(valueLabel(memory))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.trailing)

            Text(memory.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.3))
        }
        .padding(.vertical, 4)
    }

    private func confidenceBadge(_ confidence: Double) -> some View {
        Text("\(Int(confidence * 100))%")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(confidence > 0.7 ? GymTheme.mint : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill((confidence > 0.7 ? GymTheme.mint : Color.orange).opacity(0.15))
            )
    }

    // MARK: - Clear Section

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("memory.clearAll", comment: ""))
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadMemories() {
        memories = MemoryStore.shared.allMemories()
    }

    private func deleteMemories(at offsets: IndexSet, in items: [CaptainMemorySnapshot]) {
        for index in offsets {
            let memory = items[index]
            MemoryStore.shared.remove(memory.key)
        }
        loadMemories()
    }

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "identity": return NSLocalizedString("memory.cat.identity", comment: "")
        case "goal": return NSLocalizedString("memory.cat.goal", comment: "")
        case "body": return NSLocalizedString("memory.cat.body", comment: "")
        case "preference": return NSLocalizedString("memory.cat.preference", comment: "")
        case "mood": return NSLocalizedString("memory.cat.mood", comment: "")
        case "injury": return NSLocalizedString("memory.cat.injury", comment: "")
        case "nutrition": return NSLocalizedString("memory.cat.nutrition", comment: "")
        case "workout_history": return NSLocalizedString("memory.cat.workoutHistory", comment: "")
        case "sleep": return NSLocalizedString("memory.cat.sleep", comment: "")
        case "insight": return NSLocalizedString("memory.cat.insight", comment: "")
        case "active_record_project": return NSLocalizedString("memory.cat.recordProject", comment: "")
        case "weekly": return NSLocalizedString("memory.cat.weekly", comment: "")
        default: return category
        }
    }

    private func keyLabel(_ key: String) -> String {
        switch key {
        case "user_name": return NSLocalizedString("memory.key.name", comment: "")
        case "weight": return NSLocalizedString("memory.key.weight", comment: "")
        case "height": return NSLocalizedString("memory.key.height", comment: "")
        case "age": return NSLocalizedString("memory.key.age", comment: "")
        case "goal": return NSLocalizedString("memory.key.goal", comment: "")
        case "sleep_hours": return NSLocalizedString("memory.key.sleepHours", comment: "")
        case "fitness_level": return NSLocalizedString("memory.key.fitnessLevel", comment: "")
        case "training_days": return NSLocalizedString("memory.key.trainingDays", comment: "")
        case "mood": return NSLocalizedString("memory.key.mood", comment: "")
        case "diet_preference": return NSLocalizedString("memory.key.dietPreference", comment: "")
        case "preferred_workout": return NSLocalizedString("memory.key.preferredWorkout", comment: "")
        case "preferred_training_time": return NSLocalizedString("memory.key.preferredTrainingTime", comment: "")
        case "available_equipment": return NSLocalizedString("memory.key.equipment", comment: "")
        case "water_intake": return NSLocalizedString("memory.key.waterIntake", comment: "")
        case "bedtime_preference": return NSLocalizedString("memory.key.bedtimePreference", comment: "")
        case "wake_time_preference": return NSLocalizedString("memory.key.wakeTimePreference", comment: "")
        case "smart_wake_recommended_time": return NSLocalizedString("memory.key.smartWakeRecommendedTime", comment: "")
        case "active_project_record_id": return NSLocalizedString("memory.key.projectId", comment: "")
        case "active_project_title": return NSLocalizedString("memory.key.projectTitle", comment: "")
        case "steps_avg": return NSLocalizedString("memory.key.stepsAvg", comment: "")
        case "sleep_avg": return NSLocalizedString("memory.key.sleepAvg", comment: "")
        case "active_calories_avg": return NSLocalizedString("memory.key.caloriesAvg", comment: "")
        case "resting_heart_rate": return NSLocalizedString("memory.key.heartRate", comment: "")
        default:
            if key.hasPrefix("injury_") { return NSLocalizedString("memory.key.injury", comment: "") }
            return key
        }
    }

    private func valueLabel(_ memory: CaptainMemorySnapshot) -> String {
        switch memory.key {
        case "goal":
            return CaptainPrimaryGoal.localizedValue(forStoredValue: memory.value) ?? memory.value
        case "preferred_workout":
            return CaptainSportPreference.localizedValue(forStoredValue: memory.value) ?? memory.value
        case "preferred_training_time":
            return CaptainWorkoutTimePreference.localizedValue(forStoredValue: memory.value) ?? memory.value
        default:
            return memory.value
        }
    }
}

// MARK: - Weekly Report Row

private struct WeeklyReportRow: View {
    let report: WeeklyReportEntry
    @State private var expanded = false

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var titleText: String {
        isArabic ? "تقرير الأسبوع \(report.weekNumber)" : "Week \(report.weekNumber) report"
    }

    private var summaryText: String {
        isArabic ? report.summaryAr : report.summaryEn
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Text(titleText)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                metricChip(value: "\(report.avgSteps)", label: isArabic ? "خطوة" : "steps")
                metricChip(value: String(format: "%.1f", report.avgSleepHours), label: isArabic ? "ساعة" : "hours")
                metricChip(value: "\(report.workoutCount)", label: isArabic ? "تمرين" : "workouts")
            }

            if expanded {
                Text(summaryText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                expanded.toggle()
            }
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func metricChip(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(red: 0.718, green: 0.898, blue: 0.824).opacity(0.25))
        )
    }
}
