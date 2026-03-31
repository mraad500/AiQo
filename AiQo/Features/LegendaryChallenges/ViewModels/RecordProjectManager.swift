import Foundation
import SwiftData
import os.log

/// مدير مشاريع كسر الأرقام القياسية
@MainActor
@Observable
final class RecordProjectManager {
    static let shared = RecordProjectManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AiQo", category: "RecordProjectManager")
    private var container: ModelContainer?
    private var context: ModelContext?

    private init() {}

    /// ربط الـ ModelContainer
    func configure(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    // MARK: - التحقق من المشروع النشط

    /// هل يقدر يبدأ مشروع جديد (ما عنده مشروع نشط)
    func canStartNewProject() -> Bool {
        return activeProject() == nil
    }

    /// المشروع النشط الحالي
    func activeProject() -> RecordProject? {
        guard let context else { return nil }

        do {
            let activeStatus = "active"
            let descriptor = FetchDescriptor<RecordProject>(
                predicate: #Predicate { $0.status == activeStatus }
            )
            return try context.fetch(descriptor).first
        } catch {
            logger.error("record_project_fetch_error error=\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - إنشاء مشروع

    /// إنشاء مشروع جديد مع الخطة من الكابتن
    // CHANGED: Added hrrPeakHR, hrrRecoveryHR, hrrLevel parameters
    func createProject(
        record: LegendaryRecord,
        userBestAtStart: Double,
        totalWeeks: Int,
        planJSON: String,
        difficulty: String,
        userWeight: Double? = nil,
        fitnessLevel: String? = nil,
        hrrPeakHR: Double? = nil,
        hrrRecoveryHR: Double? = nil,
        hrrLevel: String? = nil
    ) -> RecordProject? {
        guard let context, canStartNewProject() else { return nil }

        let project = RecordProject(
            recordID: record.id,
            recordTitle: record.titleAr,
            recordCategory: record.category.rawValue,
            targetValue: record.targetValue,
            unit: record.unit,
            currentRecordHolder: record.recordHolderAr,
            holderCountryFlag: record.country,
            userWeightAtStart: userWeight,
            userFitnessLevelAtStart: fitnessLevel,
            userBestAtStart: userBestAtStart,
            totalWeeks: totalWeeks,
            planJSON: planJSON,
            difficulty: difficulty
        )
        // CHANGED: Store HRR assessment data
        project.hrrPeakHR = hrrPeakHR
        project.hrrRecoveryHR = hrrRecoveryHR
        project.hrrLevel = hrrLevel

        do {
            context.insert(project)
            try context.save()

            // حفظ بالذاكرة
            MemoryStore.shared.set(
                "active_project_record_id",
                value: project.id.uuidString,
                category: "active_record_project",
                source: "user_explicit",
                confidence: 1.0
            )
            MemoryStore.shared.set(
                "active_project_title",
                value: record.titleAr,
                category: "active_record_project",
                source: "user_explicit",
                confidence: 1.0
            )

            logger.info("record_project_created record=\(record.id) weeks=\(totalWeeks)")
            return project
        } catch {
            logger.error("record_project_create_error error=\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - تحديث المشروع

    /// تسجيل أداء أسبوعي
    func logPerformance(_ value: Double, for project: RecordProject) {
        if value > project.bestPerformance {
            project.bestPerformance = value
        }
        saveContext()
    }

    /// إضافة مراجعة أسبوعية
    func addWeeklyLog(_ log: WeeklyLog, to project: RecordProject) {
        log.project = project
        project.weeklyLogs.append(log)
        project.lastReviewDate = Date()
        project.lastReviewNotes = log.captainNotes
        project.currentWeek = min(project.currentWeek + 1, project.totalWeeks)

        if let performance = log.performanceThisWeek, performance > project.bestPerformance {
            project.bestPerformance = performance
        }

        saveContext()
    }

    /// تحديث الخطة بعد مراجعة
    func updatePlan(for project: RecordProject, newPlanJSON: String, newTotalWeeks: Int?) {
        project.planJSON = newPlanJSON
        if let newTotalWeeks {
            project.totalWeeks = newTotalWeeks
        }
        saveContext()
    }

    // MARK: - إنهاء المشروع

    /// إنهاء المشروع (abandon)
    func abandonProject(_ project: RecordProject) {
        project.status = "abandoned"
        project.endDate = Date()
        project.isPinnedToPlan = false

        MemoryStore.shared.remove("active_project_record_id")
        MemoryStore.shared.remove("active_project_title")

        saveContext()
        logger.info("record_project_abandoned id=\(project.id)")
    }

    /// إكمال المشروع بنجاح
    func completeProject(_ project: RecordProject) {
        project.status = "completed"
        project.endDate = Date()
        project.isPinnedToPlan = false

        MemoryStore.shared.remove("active_project_record_id")
        MemoryStore.shared.remove("active_project_title")

        saveContext()
        logger.info("record_project_completed id=\(project.id)")
    }

    // MARK: - توليد خطة افتراضية

    /// يولّد خطة تدريب افتراضية بناءً على الرقم القياسي
    // CHANGED: Added hrrLevel parameter to customize plan based on fitness assessment
    static func generateDefaultPlan(for record: LegendaryRecord, totalWeeks: Int, hrrLevel: String = "good") -> String {
        var weeks: [[String: Any]] = []

        // CHANGED: Adjust starting intensity based on HRR level
        let startFraction: Double
        switch hrrLevel {
        case "excellent": startFraction = 0.25
        case "needsWork": startFraction = 0.10
        default: startFraction = 0.15
        }

        // CHANGED: Extra rest days in early weeks for needsWork
        let needsWorkEarlyRestWeeks = hrrLevel == "needsWork" ? 4 : 0

        for weekNum in 1...totalWeeks {
            let phase: String
            let intensityFraction = Double(weekNum) / Double(totalWeeks)

            if intensityFraction <= 0.25 {
                phase = "تأسيس"
            } else if intensityFraction <= 0.6 {
                phase = "بناء"
            } else if intensityFraction <= 0.85 {
                phase = "تكثيف"
            } else {
                phase = "ذروة"
            }

            // CHANGED: Use startFraction instead of hardcoded 0.15
            let weeklyTarget = record.targetValue * (startFraction + intensityFraction * (1.0 - startFraction))
            let title = "الأسبوع \(weekNum) — \(phase)"

            var days: [[String: Any]] = []
            // CHANGED: Training days count adjusts for needsWork early weeks
            let isEarlyNeedsWork = weekNum <= needsWorkEarlyRestWeeks
            let trainingDaysPerWeek = isEarlyNeedsWork ? 4 : 5

            for day in 1...7 {
                // CHANGED: Day 3 becomes rest for needsWork in early weeks
                let isRestDay = day == 4 || day == 7 || (isEarlyNeedsWork && day == 3)

                if isRestDay {
                    days.append([
                        "day": day,
                        "title": "راحة نشطة",
                        "details": "مشي خفيف 20 دقيقة + إطالات",
                        "type": "rest"
                    ])
                } else if day == 6 {
                    days.append([
                        "day": day,
                        "title": "اختبار أسبوعي",
                        "details": "سجّل أفضل أداء لك — \(record.unit)",
                        "type": "test"
                    ])
                } else {
                    let setCount = min(3 + weekNum / 4, 6)
                    let repsPerSet = Int(weeklyTarget / Double(trainingDaysPerWeek) / Double(setCount))
                    days.append([
                        "day": day,
                        "title": "تمرين \(record.category.rawValue)",
                        "details": "\(setCount) مجموعات × \(max(repsPerSet, 5)) \(record.unit) — راحة 90 ثانية",
                        "type": "training"
                    ])
                }
            }

            let nutritionTips = [
                "ركّز على البروتين: 1.6-2 غرام لكل كيلو من وزنك",
                "اشرب 3 لتر ماء على الأقل يومياً",
                "كل كربوهيدرات معقدة قبل التمرين بساعتين",
                "وجبة بروتين خلال 30 دقيقة بعد التمرين"
            ]

            let week: [String: Any] = [
                "week": weekNum,
                "title": title,
                "weeklyTarget": Int(weeklyTarget),
                "days": days,
                "nutritionTip": nutritionTips[(weekNum - 1) % nutritionTips.count]
            ]
            weeks.append(week)
        }

        let plan: [String: Any] = ["weeklyPlan": weeks]
        guard let data = try? JSONSerialization.data(withJSONObject: plan),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    /// تحديث حالة إنجاز المهام اليومية (legacy bridge للـ LegendaryProject)
    func updateCompletedTasks(for project: RecordProject, completedTaskIDsJSON: String) {
        project.completedTaskIDsJSON = completedTaskIDsJSON
        saveContext()
    }

    // MARK: - مساعدات

    /// استخراج خطة الأسبوع الحالي من JSON
    func currentWeekPlan(for project: RecordProject) -> WeekPlanData? {
        guard let data = project.planJSON.data(using: .utf8),
              let plan = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let weeklyPlan = plan["weeklyPlan"] as? [[String: Any]] else {
            return nil
        }

        let weekIndex = project.currentWeek - 1
        guard weekIndex >= 0, weekIndex < weeklyPlan.count else { return nil }

        let weekData = weeklyPlan[weekIndex]
        return WeekPlanData(from: weekData)
    }

    /// كل المشاريع (للتاريخ)
    func allProjects() -> [RecordProject] {
        guard let context else { return [] }

        do {
            let descriptor = FetchDescriptor<RecordProject>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("record_project_all_error error=\(error.localizedDescription)")
            return []
        }
    }

    private func saveContext() {
        do {
            try context?.save()
        } catch {
            logger.error("record_project_save_error error=\(error.localizedDescription)")
        }
    }
}

// MARK: - Week Plan Data Model

/// بيانات خطة أسبوع واحد (parsed from JSON)
struct WeekPlanData {
    let week: Int
    let title: String
    let weeklyTarget: Double
    let days: [DayPlanData]
    let nutritionTip: String?
    let injuryNote: String?

    init?(from dict: [String: Any]) {
        guard let week = dict["week"] as? Int,
              let title = dict["title"] as? String else { return nil }

        self.week = week
        self.title = title
        self.weeklyTarget = (dict["weeklyTarget"] as? Double) ?? Double(dict["weeklyTarget"] as? Int ?? 0)
        self.nutritionTip = dict["nutritionTip"] as? String
        self.injuryNote = dict["injuryNote"] as? String

        if let daysArray = dict["days"] as? [[String: Any]] {
            self.days = daysArray.compactMap { DayPlanData(from: $0) }
        } else {
            self.days = []
        }
    }
}

/// بيانات يوم واحد من الخطة
struct DayPlanData: Identifiable {
    let id: Int
    let day: Int
    let title: String
    let details: String
    let type: String // "training", "rest", "test"

    init?(from dict: [String: Any]) {
        guard let day = dict["day"] as? Int,
              let title = dict["title"] as? String,
              let details = dict["details"] as? String else { return nil }

        self.id = day
        self.day = day
        self.title = title
        self.details = details
        self.type = (dict["type"] as? String) ?? "training"
    }
}
