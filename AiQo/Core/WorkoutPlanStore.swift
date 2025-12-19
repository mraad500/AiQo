import Foundation

struct WorkoutExercise: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

final class WorkoutPlanStore {

    static let shared = WorkoutPlanStore()

    private let templatesKey = "aiqo.workout.templates"
    private let completionPrefix = "aiqo.workout.completed."
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Templates

    var templates: [WorkoutExercise] {
        get {
            guard let data = defaults.data(forKey: templatesKey),
                  let items = try? JSONDecoder().decode([WorkoutExercise].self, from: data) else {
                return []
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: templatesKey)
            }
        }
    }

    @discardableResult
    func addTemplate(named name: String) -> WorkoutExercise {
        var list = templates
        let item = WorkoutExercise(name: name)
        list.append(item)
        templates = list
        return item
    }

    func removeTemplate(id: UUID) {
        var list = templates
        list.removeAll { $0.id == id }
        templates = list
        // لما نحذف تمرين، نشيله من إكمال اليوم الحالي
        var completed = completedIdsForToday()
        completed.remove(id)
        saveCompletedToday(completed)
    }

    // MARK: - Today completion

    private func todayKey() -> String {
        let d = Date()
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 0,
                      comps.month ?? 0,
                      comps.day ?? 0)
    }

    private func completionKeyForToday() -> String {
        completionPrefix + todayKey()
    }

    func completedIdsForToday() -> Set<UUID> {
        let key = completionKeyForToday()
        guard let data = defaults.data(forKey: key),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    private func saveCompletedToday(_ set: Set<UUID>) {
        let ids = Array(set)
        if let data = try? JSONEncoder().encode(ids) {
            defaults.set(data, forKey: completionKeyForToday())
        }
    }

    func toggleCompletedToday(id: UUID) {
        var set = completedIdsForToday()
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        saveCompletedToday(set)
    }
}
