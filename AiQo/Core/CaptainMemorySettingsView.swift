import SwiftUI

/// شاشة إعدادات ذاكرة الكابتن — تعرض كل المعلومات المحفوظة
struct CaptainMemorySettingsView: View {
    @State private var memories: [CaptainMemory] = []
    @State private var isEnabled: Bool = MemoryStore.shared.isEnabled
    @State private var showClearConfirmation = false

    private var groupedMemories: [(String, [CaptainMemory])] {
        let grouped = Dictionary(grouping: memories, by: { $0.category })
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            headerSection
            toggleSection

            if isEnabled {
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
        .navigationTitle("ذاكرة الكابتن")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { loadMemories() }
        .alert("مسح كل الذاكرة", isPresented: $showClearConfirmation) {
            Button("إلغاء", role: .cancel) {}
            Button("مسح الكل", role: .destructive) {
                MemoryStore.shared.clearAll()
                loadMemories()
            }
        } message: {
            Text("متأكد تبي تمسح كل ذاكرة الكابتن؟ هالخطوة ما تنعكس.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("🧠")
                    .font(.system(size: 40))

                Text("ذاكرة الكابتن")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text("المعلومات اللي يتذكرها الكابتن عشان يساعدك أحسن")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .multilineTextAlignment(.center)

                if !memories.isEmpty {
                    Text("\(memories.count) / 200")
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
                    Text("تفعيل ذاكرة الكابتن")
                        .font(.system(size: 15, weight: .semibold))
                    Text("يوقف حفظ واستخراج المعلومات")
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

    private func memoryRow(_ memory: CaptainMemory) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                confidenceBadge(memory.confidence)
                Spacer()
                Text(keyLabel(memory.key))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }

            Text(memory.value)
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
                    Text("مسح كل الذاكرة")
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

    private func deleteMemories(at offsets: IndexSet, in items: [CaptainMemory]) {
        for index in offsets {
            let memory = items[index]
            MemoryStore.shared.remove(memory.key)
        }
        loadMemories()
    }

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "identity": return "الهوية"
        case "goal": return "الأهداف"
        case "body": return "الجسم"
        case "preference": return "التفضيلات"
        case "mood": return "المزاج"
        case "injury": return "الإصابات"
        case "nutrition": return "التغذية"
        case "workout_history": return "تاريخ التمارين"
        case "sleep": return "النوم"
        case "insight": return "ملاحظات"
        case "active_record_project": return "مشروع كسر الرقم"
        default: return category
        }
    }

    private func keyLabel(_ key: String) -> String {
        switch key {
        case "user_name": return "الاسم"
        case "weight": return "الوزن"
        case "height": return "الطول"
        case "age": return "العمر"
        case "goal": return "الهدف"
        case "sleep_hours": return "ساعات النوم"
        case "fitness_level": return "مستوى اللياقة"
        case "training_days": return "أيام التمرين"
        case "mood": return "المزاج"
        case "diet_preference": return "تفضيل غذائي"
        case "preferred_workout": return "تمرين مفضل"
        case "available_equipment": return "معدات متاحة"
        case "water_intake": return "شرب الماء"
        case "active_project_record_id": return "معرّف المشروع"
        case "active_project_title": return "اسم المشروع"
        case "steps_avg": return "معدل الخطوات"
        case "sleep_avg": return "معدل النوم"
        case "active_calories_avg": return "معدل السعرات"
        case "resting_heart_rate": return "معدل النبض"
        default:
            if key.hasPrefix("injury_") { return "إصابة" }
            return key
        }
    }
}
