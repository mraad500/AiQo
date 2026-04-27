import Foundation

struct WorkoutHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let durationSeconds: Int
    let activeCalories: Double
    let heartRate: Double?
    let distanceMeters: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String,
        durationSeconds: Int,
        activeCalories: Double,
        heartRate: Double?,
        distanceMeters: Double
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.durationSeconds = durationSeconds
        self.activeCalories = activeCalories
        self.heartRate = heartRate
        self.distanceMeters = distanceMeters
    }
}

/// Rolling-window store for the last 7 completed workouts.
///
/// Persists locally to `UserDefaults`, and mirrors a compiled Arabic-friendly
/// summary into `MemoryStore` under category `workout_history` so the Captain's
/// cognitive pipeline can retrieve it when the user asks "how was my workout today?".
@MainActor
final class WorkoutHistoryStore {
    static let shared = WorkoutHistoryStore()

    private let maxEntries = 7
    private let minimumDurationSeconds = 60
    private let storageKey = "aiqo.workoutHistory.v1"
    private let memoryKey = "recent_workouts"
    private let memoryCategory = "workout_history"

    private init() {}

    // MARK: - Public API

    func recordCompletion(
        title: String,
        durationSeconds: Int,
        activeCalories: Double,
        heartRate: Double?,
        distanceMeters: Double,
        at date: Date = Date()
    ) {
        guard durationSeconds >= minimumDurationSeconds else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty
            ? NSLocalizedString("memory.workout.genericTitle", value: "Workout", comment: "")
            : trimmedTitle

        let entry = WorkoutHistoryEntry(
            date: date,
            title: resolvedTitle,
            durationSeconds: durationSeconds,
            activeCalories: max(0, activeCalories),
            heartRate: (heartRate ?? 0) > 0 ? heartRate : nil,
            distanceMeters: max(0, distanceMeters)
        )

        var entries = loadEntries()
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save(entries)
        syncToMemoryStore(entries: entries)
    }

    func recentEntries() -> [WorkoutHistoryEntry] {
        loadEntries()
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        MemoryStore.shared.remove(memoryKey)
    }

    // MARK: - Persistence

    private func loadEntries() -> [WorkoutHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WorkoutHistoryEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [WorkoutHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - LLM Memory Sync

    private func syncToMemoryStore(entries: [WorkoutHistoryEntry]) {
        guard !entries.isEmpty else { return }
        let summary = buildMemorySummary(entries: entries)
        MemoryStore.shared.set(
            memoryKey,
            value: summary,
            category: memoryCategory,
            source: "system",
            confidence: 0.95
        )
    }

    private func buildMemorySummary(entries: [WorkoutHistoryEntry]) -> String {
        let isArabic = AppSettingsStore.shared.appLanguage == .arabic
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isArabic ? "ar" : "en")
        formatter.dateFormat = "d MMM"

        let header = isArabic
            ? "آخر \(entries.count) تمارين للمستخدم (من الأحدث للأقدم):"
            : "User's last \(entries.count) workouts (newest first):"

        var lines: [String] = [header]
        for (index, entry) in entries.enumerated() {
            let dateStr = formatter.string(from: entry.date)
            let minutes = max(1, entry.durationSeconds / 60)

            var parts: [String] = []
            parts.append("\(index + 1). \(dateStr) — \(entry.title)")
            parts.append(isArabic ? "\(minutes) دقيقة" : "\(minutes) min")
            if entry.activeCalories > 0 {
                parts.append(isArabic ? "\(Int(entry.activeCalories)) سعرة" : "\(Int(entry.activeCalories)) kcal")
            }
            if let hr = entry.heartRate, hr > 0 {
                parts.append(isArabic ? "ن \(Int(hr))" : "HR \(Int(hr))")
            }
            if entry.distanceMeters >= 100 {
                let km = entry.distanceMeters / 1000
                parts.append(String(format: isArabic ? "%.2f كم" : "%.2f km", km))
            }
            lines.append(parts.joined(separator: isArabic ? "، " : ", "))
        }
        return lines.joined(separator: "\n")
    }
}
