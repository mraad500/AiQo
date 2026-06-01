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

    // MARK: - Task Generation (week-adaptive periodization)

    /// Real periodization for a Legendary week: volume/intensity ramps with
    /// the week, every 4th week is a deload (recovery), and the final week
    /// tapers to peak for the benchmark. Deterministic — same week → same plan.
    private struct WeekProgression {
        let week: Int
        let total: Int
        let progress: Double   // 0.0 at week 1 → 1.0 at the final week
        let isDeload: Bool
        let isTaper: Bool
        let phaseAr: String

        /// Scales a metric from `base` (week 1) toward `peak` (final week),
        /// pulling volume back on deload weeks and trimming it on the taper.
        func scaled(_ base: Int, _ peak: Int) -> Int {
            let ramped = Double(base) + (Double(peak) - Double(base)) * progress
            if isDeload { return max(base, Int((ramped * 0.70).rounded())) }
            if isTaper { return max(base, Int((ramped * 0.85).rounded())) }
            return Int(ramped.rounded())
        }
    }

    private func progression(week: Int, totalWeeks rawTotal: Int) -> WeekProgression {
        let total = max(rawTotal, 1)
        let w = min(max(week, 1), total)
        let progress = total > 1 ? Double(w - 1) / Double(total - 1) : 0
        let isTaper = w == total && total >= 4
        let isDeload = !isTaper && total >= 4 && w % 4 == 0
        let phaseAr: String
        if isTaper {
            phaseAr = "ذروة واختبار"
        } else if isDeload {
            phaseAr = "استشفاء"
        } else {
            switch Int((progress * 3).rounded()) {
            case 0: phaseAr = "تأسيس"
            case 1: phaseAr = "بناء"
            case 2: phaseAr = "تكثيف"
            default: phaseAr = "ذروة"
            }
        }
        return WeekProgression(
            week: w, total: total, progress: progress,
            isDeload: isDeload, isTaper: isTaper, phaseAr: phaseAr
        )
    }

    private func generateWeeklyTasks(for record: LegendaryRecord, week: Int) -> [DailyTask] {
        let p = progression(week: week, totalWeeks: record.estimatedWeeks)
        let tag = "أسبوع \(p.week)/\(p.total) · \(p.phaseAr)"
        let prev = max(1, p.week - 1)
        func task(_ day: Int, _ titleAr: String, _ target: String) -> DailyTask {
            DailyTask(id: UUID().uuidString, dayNumber: day, titleAr: titleAr, targetValue: target, isCompleted: false)
        }
        let testAr = p.isTaper ? "اختبار نهائي: أقصى أداء" : "اختبار الأسبوع: أقصى أداء"
        let testTarget = p.week > 1 ? "قِس وقارن بأسبوع \(prev)" : "قياس خط الأساس"

        switch record.category {
        case .strength:
            let sets = p.scaled(3, 5)
            let reps = p.scaled(10, 18)
            let speedSets = p.scaled(4, 6)
            let coreReps = p.scaled(15, 25)
            let walk = p.scaled(20, 30)
            return [
                task(1, "\(tag) — إحماء + \(record.titleAr)", "\(sets) مجاميع × \(reps)"),
                task(2, "تمارين مساعدة للعضلات", "\(sets) مجاميع × \(reps + 2)"),
                task(3, "راحة نشطة — مشي خفيف", "\(walk) دقيقة"),
                task(4, "\(record.titleAr) — قوة متفجّرة", "\(speedSets) مجاميع × \(max(6, reps - 4))"),
                task(5, "تمارين جذع وتوازن", "3 مجاميع × \(coreReps)"),
                task(6, testAr, testTarget),
                task(7, "راحة كاملة", "استشفاء"),
            ]
        case .cardio:
            let easy = p.scaled(20, 35)
            let main = p.scaled(30, 50)
            let long = p.scaled(45, 90)
            let hiit = p.scaled(12, 28)
            return [
                task(1, "\(tag) — مشي/جري سريع", "\(main) دقيقة"),
                task(2, "كارديو ثابت الإيقاع", "\(easy) دقيقة"),
                task(3, "راحة نشطة — تمدد", "15 دقيقة"),
                task(4, "مسافة طويلة متواصلة", "\(long) دقيقة"),
                task(5, "HIIT — فترات شدّة عالية", "\(hiit) دقيقة"),
                task(6, testAr.replacingOccurrences(of: "أقصى أداء", with: "أقصى مسافة"), testTarget),
                task(7, "راحة كاملة", "استشفاء"),
            ]
        case .endurance:
            let holdSec = p.scaled(30, 90)
            let sets = p.scaled(3, 5)
            let coreReps = p.scaled(15, 25)
            return [
                task(1, "\(tag) — ثبات بوضعية البلانك", "\(sets) مجاميع × \(holdSec) ثانية"),
                task(2, "تمارين جذع", "\(sets) مجاميع × \(coreReps)"),
                task(3, "راحة نشطة — تنفس عميق", "10 دقائق"),
                task(4, "بلانك مع تبديل", "\(sets + 1) مجاميع × \(max(20, holdSec - 10)) ثانية"),
                task(5, "تمارين ثبات وتوازن", "3 مجاميع × \(coreReps)"),
                task(6, testAr.replacingOccurrences(of: "أقصى أداء", with: "أقصى ثبات"), testTarget),
                task(7, "راحة كاملة", "استشفاء"),
            ]
        case .clarity:
            let med = p.scaled(10, 30)
            let rounds = p.scaled(3, 7)
            let holdSec = p.scaled(15, 60)
            let box = p.scaled(4, 8)
            return [
                task(1, "\(tag) — تمرين تنفس صندوقي", "\(rounds) جولات × \(box) ثوانٍ"),
                task(2, "تأمّل مع تركيز على النَفَس", "\(med) دقيقة"),
                task(3, "تنفس ويم هوف", "\(rounds) جولات"),
                task(4, "حبس نَفَس تدريجي", "\(rounds) محاولات × \(holdSec) ثانية"),
                task(5, "تأمّل عميق", "\(med + 5) دقيقة"),
                task(6, testAr.replacingOccurrences(of: "أقصى أداء", with: "أقصى حبس نَفَس"), testTarget),
                task(7, "راحة كاملة", "استشفاء"),
            ]
        }
    }
}
