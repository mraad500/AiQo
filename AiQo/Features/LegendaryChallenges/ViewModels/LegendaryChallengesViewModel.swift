import SwiftUI
internal import Combine

// MARK: - Legendary Challenges ViewModel

final class LegendaryChallengesViewModel: ObservableObject {

    // MARK: - Published State

    @Published var records: [LegendaryRecord] = LegendaryRecord.seedRecords
    @Published var activeProject: LegendaryProject?

    // MARK: - Persistence Key

    private static let projectKey = "aiqo.legendary.activeProject"

    // MARK: - Init

    init() {
        loadProject()
    }

    // MARK: - Project Lifecycle

    func startProject(for record: LegendaryRecord) {
        let weeklyCheckpoints = (1...record.estimatedWeeks).map { week in
            WeeklyCheckpoint(id: UUID().uuidString, weekNumber: week)
        }

        // DESIGN: Generate a realistic first-week plan based on difficulty
        let dailyTasks = generateWeeklyTasks(for: record, week: 1)

        let project = LegendaryProject(
            id: UUID().uuidString,
            recordId: record.id,
            startDate: Date(),
            targetWeeks: record.estimatedWeeks,
            weeklyCheckpoints: weeklyCheckpoints,
            dailyTasks: dailyTasks,
            personalBest: 0,
            isCompleted: false
        )

        activeProject = project
        saveProject()
    }

    func toggleTask(_ taskId: String) {
        guard let index = activeProject?.dailyTasks.firstIndex(where: { $0.id == taskId }) else { return }
        activeProject?.dailyTasks[index].isCompleted.toggle()
        saveProject()
    }

    func logCheckpoint(weekNumber: Int, value: Double) {
        guard let index = activeProject?.weeklyCheckpoints.firstIndex(where: { $0.weekNumber == weekNumber }) else { return }
        activeProject?.weeklyCheckpoints[index].recordedValue = value
        activeProject?.weeklyCheckpoints[index].date = Date()

        // Update personal best
        if let current = activeProject?.personalBest, value > current {
            activeProject?.personalBest = value
        }

        saveProject()
    }

    func record(for project: LegendaryProject) -> LegendaryRecord? {
        records.first(where: { $0.id == project.recordId })
    }

    // MARK: - Persistence

    private func saveProject() {
        guard let project = activeProject,
              let data = try? JSONEncoder().encode(project) else {
            UserDefaults.standard.removeObject(forKey: Self.projectKey)
            return
        }
        UserDefaults.standard.set(data, forKey: Self.projectKey)
    }

    private func loadProject() {
        guard let data = UserDefaults.standard.data(forKey: Self.projectKey),
              let project = try? JSONDecoder().decode(LegendaryProject.self, from: data) else { return }
        activeProject = project
    }

    // MARK: - Task Generation

    private func generateWeeklyTasks(for record: LegendaryRecord, week: Int) -> [DailyTask] {
        // DESIGN: Simple progressive plan for week 1, scales per category
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
