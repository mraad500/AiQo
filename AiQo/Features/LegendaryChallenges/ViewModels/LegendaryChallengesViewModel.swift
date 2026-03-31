import SwiftUI
import Combine

// MARK: - Legendary Challenges ViewModel

final class LegendaryChallengesViewModel: ObservableObject {

    // MARK: - Published State

    @Published var records: [LegendaryRecord] = LegendaryRecord.seedRecords
    @Published var activeProject: LegendaryProject?

    // MARK: - Persistence Keys

    /// One-time migration flag — set to true after old UserDefaults data is moved to SwiftData.
    private static let migrationFlagKey = "aiqo.legendaryChallengesMigrated"

    /// Legacy UserDefaults key — read ONLY during one-time migration, never written again.
    private static let legacyProjectKey = "aiqo.legendary.activeProject"

    // MARK: - Init

    init() {
        migrateIfNeeded()
        loadProject()
    }

    // MARK: - One-Time Migration (UserDefaults → SwiftData)

    /// Runs once on first launch after this code ships.
    /// Reads any existing LegendaryProject from UserDefaults, inserts it as a
    /// RecordProject into SwiftData via RecordProjectManager, then deletes the old key.
    private func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.migrationFlagKey) else { return }
        // Mark migration complete immediately so it never runs again, even if it fails.
        UserDefaults.standard.set(true, forKey: Self.migrationFlagKey)

        // Read legacy blob.
        guard let data = UserDefaults.standard.data(forKey: Self.legacyProjectKey),
              let old = try? JSONDecoder().decode(LegendaryProject.self, from: data) else {
            // Nothing to migrate.
            UserDefaults.standard.removeObject(forKey: Self.legacyProjectKey)
            return
        }

        // Don't overwrite a project already present in SwiftData.
        guard RecordProjectManager.shared.canStartNewProject() else {
            UserDefaults.standard.removeObject(forKey: Self.legacyProjectKey)
            return
        }

        // Find the matching seed record.
        guard let record = LegendaryRecord.seedRecords.first(where: { $0.id == old.recordId }) else {
            UserDefaults.standard.removeObject(forKey: Self.legacyProjectKey)
            return
        }

        // Carry over the best performance recorded across all weekly checkpoints.
        let personalBest = old.weeklyCheckpoints.compactMap(\.recordedValue).max() ?? old.personalBest

        // Generate a default plan covering the full project duration.
        let planJSON = RecordProjectManager.generateDefaultPlan(
            for: record,
            totalWeeks: old.targetWeeks
        )

        // Insert into SwiftData.
        _ = RecordProjectManager.shared.createProject(
            record: record,
            userBestAtStart: personalBest,
            totalWeeks: old.targetWeeks,
            planJSON: planJSON,
            difficulty: record.difficulty.labelAr
        )

        // Retire the UserDefaults key.
        UserDefaults.standard.removeObject(forKey: Self.legacyProjectKey)
    }

    // MARK: - Project Lifecycle

    /// Creates an in-memory LegendaryProject bridge for the legacy ProjectView.
    ///
    /// Note: this method intentionally does NOT write to SwiftData.
    /// The canonical SwiftData RecordProject is created by FitnessAssessmentView →
    /// RecordProjectManager.createProject(), which runs immediately after this call.
    /// Writing here would conflict with that creation (canStartNewProject() would return false).
    func startProject(for record: LegendaryRecord) {
        let weeklyCheckpoints = (1...record.estimatedWeeks).map { week in
            WeeklyCheckpoint(id: UUID().uuidString, weekNumber: week)
        }
        // Use deterministic IDs (w<week>d<day>) so completion state survives if this
        // bridge is ever reconciled against an existing SwiftData project.
        let dailyTasks = generateWeeklyTasks(for: record, week: 1).map { task in
            DailyTask(
                id: "w1d\(task.dayNumber)",
                dayNumber: task.dayNumber,
                titleAr: task.titleAr,
                targetValue: task.targetValue,
                isCompleted: false
            )
        }
        activeProject = LegendaryProject(
            id: UUID().uuidString,
            recordId: record.id,
            startDate: Date(),
            targetWeeks: record.estimatedWeeks,
            weeklyCheckpoints: weeklyCheckpoints,
            dailyTasks: dailyTasks,
            personalBest: 0,
            isCompleted: false
        )
        // No UserDefaults write — SwiftData is now the persistence layer.
    }

    /// Toggles task completion. Persists completed-task IDs to SwiftData when a matching
    /// active RecordProject exists (i.e. after FitnessAssessmentView creates it).
    func toggleTask(_ taskId: String) {
        guard let index = activeProject?.dailyTasks.firstIndex(where: { $0.id == taskId }) else { return }
        activeProject?.dailyTasks[index].isCompleted.toggle()
        persistCompletedTasks()
    }

    /// Records a weekly checkpoint value.
    /// Updates bestPerformance in SwiftData when a matching RecordProject exists.
    func logCheckpoint(weekNumber: Int, value: Double) {
        guard let index = activeProject?.weeklyCheckpoints.firstIndex(where: { $0.weekNumber == weekNumber }) else { return }
        activeProject?.weeklyCheckpoints[index].recordedValue = value
        activeProject?.weeklyCheckpoints[index].date = Date()

        if let current = activeProject?.personalBest, value > current {
            activeProject?.personalBest = value
        }

        // Persist to SwiftData if a matching project exists.
        if let rp = RecordProjectManager.shared.activeProject(),
           rp.recordID == activeProject?.recordId {
            RecordProjectManager.shared.logPerformance(value, for: rp)
        }
    }

    func record(for project: LegendaryProject) -> LegendaryRecord? {
        records.first(where: { $0.id == project.recordId })
    }

    // MARK: - Persistence (SwiftData-backed via RecordProjectManager)

    /// Loads the active project from SwiftData and converts it to the legacy bridge type.
    /// ModelContext access is delegated to RecordProjectManager (which holds the container
    /// reference configured at app launch) — no direct @Environment(\.modelContext) needed here.
    private func loadProject() {
        guard let rp = RecordProjectManager.shared.activeProject() else {
            activeProject = nil
            return
        }
        activeProject = legacyProject(from: rp)
    }

    /// Saves the current set of completed task IDs to the corresponding RecordProject in SwiftData.
    private func persistCompletedTasks() {
        guard let project = activeProject,
              let rp = RecordProjectManager.shared.activeProject(),
              rp.recordID == project.recordId else { return }

        let completedIDs = project.dailyTasks.filter(\.isCompleted).map(\.id)
        guard let jsonData = try? JSONEncoder().encode(completedIDs),
              let json = String(data: jsonData, encoding: .utf8) else { return }

        RecordProjectManager.shared.updateCompletedTasks(for: rp, completedTaskIDsJSON: json)
    }

    // MARK: - Bridge: RecordProject → LegendaryProject

    /// Converts a SwiftData RecordProject into the legacy LegendaryProject struct consumed
    /// by ProjectView. Task IDs are deterministic ("w<week>d<day>") so completion state
    /// persisted in completedTaskIDsJSON survives app relaunch.
    private func legacyProject(from rp: RecordProject) -> LegendaryProject {
        let completedIDs: Set<String> = {
            guard let data = rp.completedTaskIDsJSON.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(ids)
        }()

        let currentWeek = rp.currentWeek

        let bridgeTasks: [DailyTask]
        if let record = LegendaryRecord.seedRecords.first(where: { $0.id == rp.recordID }) {
            bridgeTasks = generateWeeklyTasks(for: record, week: currentWeek).map { task in
                let deterministicID = "w\(currentWeek)d\(task.dayNumber)"
                return DailyTask(
                    id: deterministicID,
                    dayNumber: task.dayNumber,
                    titleAr: task.titleAr,
                    targetValue: task.targetValue,
                    isCompleted: completedIDs.contains(deterministicID)
                )
            }
        } else {
            bridgeTasks = []
        }

        let checkpoints = rp.weeklyLogs.map { log in
            WeeklyCheckpoint(
                id: log.id.uuidString,
                weekNumber: log.weekNumber,
                recordedValue: log.performanceThisWeek,
                date: log.date
            )
        }

        return LegendaryProject(
            id: rp.id.uuidString,
            recordId: rp.recordID,
            startDate: rp.startDate,
            targetWeeks: rp.totalWeeks,
            weeklyCheckpoints: checkpoints,
            dailyTasks: bridgeTasks,
            personalBest: rp.bestPerformance,
            isCompleted: rp.status == "completed"
        )
    }

    // MARK: - Task Generation (unchanged)

    private func generateWeeklyTasks(for record: LegendaryRecord, week: Int) -> [DailyTask] {
        switch record.category {
        case .strength:
            return [
                DailyTask(id: UUID().uuidString, dayNumber: 1, titleAr: "إحماء + \(record.titleAr)", targetValue: "3 مجاميع × 10", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 2, titleAr: "تمارين مساعدة للعضلات", targetValue: "3 مجاميع × 12", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 3, titleAr: "راحة نشطة — مشي خفيف", targetValue: "20 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 4, titleAr: "\(record.titleAr) — سرعة", targetValue: "4 مجاميع × 8", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 5, titleAr: "تمارين جذع وتوازن", targetValue: "3 مجاميع × 15", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 6, titleAr: "اختبار: أقصى عدد بدقيقة", targetValue: "قياس أقصى أداء", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 7, titleAr: "راحة كاملة", targetValue: "استشفاء", isCompleted: false),
            ]
        case .cardio:
            return [
                DailyTask(id: UUID().uuidString, dayNumber: 1, titleAr: "مشي سريع", targetValue: "30 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 2, titleAr: "تمارين كارديو خفيفة", targetValue: "20 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 3, titleAr: "راحة نشطة — تمدد", targetValue: "15 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 4, titleAr: "مشي طويل متوسط السرعة", targetValue: "45 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 5, titleAr: "تمارين HIIT خفيفة", targetValue: "15 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 6, titleAr: "اختبار: قياس المسافة", targetValue: "قياس أقصى أداء", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 7, titleAr: "راحة كاملة", targetValue: "استشفاء", isCompleted: false),
            ]
        case .endurance:
            return [
                DailyTask(id: UUID().uuidString, dayNumber: 1, titleAr: "ثبات بوضعية البلانك", targetValue: "3 مجاميع × 30 ثانية", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 2, titleAr: "تمارين جذع", targetValue: "3 مجاميع × 15", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 3, titleAr: "راحة نشطة — تنفس عميق", targetValue: "10 دقائق", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 4, titleAr: "بلانك مع تبديل", targetValue: "4 مجاميع × 20 ثانية", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 5, titleAr: "تمارين ثبات وتوازن", targetValue: "3 مجاميع × 12", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 6, titleAr: "اختبار: أقصى ثبات", targetValue: "قياس أقصى أداء", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 7, titleAr: "راحة كاملة", targetValue: "استشفاء", isCompleted: false),
            ]
        case .clarity:
            return [
                DailyTask(id: UUID().uuidString, dayNumber: 1, titleAr: "تمرين تنفس — صندوقي", targetValue: "4 جولات × 4 ثوانٍ", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 2, titleAr: "تأمّل مع تركيز على النَفَس", targetValue: "10 دقائق", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 3, titleAr: "تنفس ويم هوف", targetValue: "3 جولات", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 4, titleAr: "حبس نَفَس تدريجي", targetValue: "5 محاولات", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 5, titleAr: "تأمّل عميق", targetValue: "15 دقيقة", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 6, titleAr: "اختبار: أقصى حبس نَفَس", targetValue: "قياس أقصى أداء", isCompleted: false),
                DailyTask(id: UUID().uuidString, dayNumber: 7, titleAr: "راحة كاملة", targetValue: "استشفاء", isCompleted: false),
            ]
        }
    }
}
